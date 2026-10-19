import Foundation
import Observation
import SwiftUI

struct BibleTriviaQuestion: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let question: String
    let correctAnswer: String
    let incorrectAnswers: [String]
    let reference: String
    let difficulty: String
}

enum BibleTriviaDifficulty: String, CaseIterable, Identifiable, Codable {
    case easy
    case normal
    case hard

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .easy: "Learn"
        case .normal: "Standard"
        case .hard: "Challenge"
        }
    }

    var timerSeconds: Int {
        switch self {
        case .easy: 30
        case .normal: 15
        case .hard: 10
        }
    }

    var statsDifficulty: GameStats.Difficulty {
        switch self {
        case .easy: .easy
        case .normal: .normal
        case .hard: .hard
        }
    }

    func includes(_ question: BibleTriviaQuestion) -> Bool {
        switch self {
        case .easy:
            question.difficulty == "easy"
        case .normal:
            question.difficulty == "easy" || question.difficulty == "normal"
        case .hard:
            true
        }
    }
}

struct BibleTriviaDifficultyProgress: Codable, Equatable {
    var completedQuestionIDs: Set<Int> = []
}

@MainActor
@Observable
final class BibleTriviaProgressStore {
    static let shared = BibleTriviaProgressStore()

    private static let storageKey = "bibleTriviaProgress"

    private var progressByDifficulty: [String: BibleTriviaDifficultyProgress]
    @ObservationIgnored private var observer: NSObjectProtocol?

    private init() {
        progressByDifficulty = Self.decode(UserDefaults.standard.data(forKey: Self.storageKey))
        observer = NotificationCenter.default.addObserver(
            forName: .gameStatsExternallyUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reload()
            }
        }
    }

    private func reload() {
        progressByDifficulty = Self.decode(UserDefaults.standard.data(forKey: Self.storageKey))
    }

    private static func decode(_ data: Data?) -> [String: BibleTriviaDifficultyProgress] {
        guard let data,
              let decoded = try? JSONDecoder().decode([String: BibleTriviaDifficultyProgress].self, from: data) else {
            return [:]
        }
        return decoded
    }

    static func mergedData(local: Data?, remote: Data?) -> Data? {
        let localProgress = decode(local)
        let remoteProgress = decode(remote)
        let keys = Set(localProgress.keys).union(remoteProgress.keys)
        var merged: [String: BibleTriviaDifficultyProgress] = [:]

        for key in keys {
            let localValue = localProgress[key] ?? BibleTriviaDifficultyProgress()
            let remoteValue = remoteProgress[key] ?? BibleTriviaDifficultyProgress()
            merged[key] = BibleTriviaDifficultyProgress(
                completedQuestionIDs: localValue.completedQuestionIDs.union(remoteValue.completedQuestionIDs)
            )
        }

        return try? JSONEncoder().encode(merged)
    }

    func progress(for difficulty: BibleTriviaDifficulty) -> BibleTriviaDifficultyProgress {
        progressByDifficulty[difficulty.rawValue] ?? BibleTriviaDifficultyProgress()
    }

    func record(questionID: Int, difficulty: BibleTriviaDifficulty) {
        var progress = progress(for: difficulty)
        progress.completedQuestionIDs.insert(questionID)
        progressByDifficulty[difficulty.rawValue] = progress
        save()
    }

    func resetCompletedPool(for difficulty: BibleTriviaDifficulty) {
        var progress = progress(for: difficulty)
        progress.completedQuestionIDs = []
        progressByDifficulty[difficulty.rawValue] = progress
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(progressByDifficulty) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
        iCloudSyncCoordinator.shared.pushKey(Self.storageKey)
    }
}

@MainActor
@Observable
final class BibleTriviaGameModel {
    enum Phase {
        case loading
        case setup
        case playing
        case results
        case unavailable
    }

    private static let questionsPerRound = 10

    private struct RoundQuestion: Identifiable {
        let question: BibleTriviaQuestion
        let options: [String]
        var selectedAnswer: String?
        var timedOut = false

        var id: Int { question.id }
        var isAnswered: Bool { selectedAnswer != nil || timedOut }
    }

    var phase: Phase = .loading
    var difficulty: BibleTriviaDifficulty = .normal
    private(set) var questions: [BibleTriviaQuestion] = []
    private var round: [RoundQuestion] = []
    private(set) var currentIndex = 0
    private var furthestPresentedIndex = 0
    private(set) var score = 0
    private(set) var answered = 0
    private(set) var remainingSeconds = 0
    @ObservationIgnored private var timerTask: Task<Void, Never>?

    let progressStore = BibleTriviaProgressStore.shared

    private var currentRoundQuestion: RoundQuestion? {
        round.indices.contains(currentIndex) ? round[currentIndex] : nil
    }

    var currentQuestion: BibleTriviaQuestion? {
        currentRoundQuestion?.question
    }

    var roundCount: Int {
        round.count
    }

    var options: [String] {
        currentRoundQuestion?.options ?? []
    }

    var selectedAnswer: String? {
        currentRoundQuestion?.selectedAnswer
    }

    var isAnswered: Bool {
        currentRoundQuestion?.isAnswered ?? false
    }

    var timedOut: Bool {
        currentRoundQuestion?.timedOut ?? false
    }

    var eligibleQuestions: [BibleTriviaQuestion] {
        questions.filter(difficulty.includes)
    }

    var completedInPool: Int {
        min(progressStore.progress(for: difficulty).completedQuestionIDs.count, eligibleQuestions.count)
    }

    var isPoolComplete: Bool {
        !eligibleQuestions.isEmpty && completedInPool == eligibleQuestions.count
    }

    var accuracy: Int {
        guard answered > 0 else { return 0 }
        return Int((Double(score) / Double(answered) * 100).rounded())
    }

    var isLastQuestion: Bool {
        currentIndex == round.count - 1
    }

    var isViewingPrevious: Bool {
        currentIndex < furthestPresentedIndex
    }

    var canGoPrevious: Bool {
        currentIndex > 0 && (isAnswered || isViewingPrevious)
    }

    var canGoNext: Bool {
        isViewingPrevious || isAnswered
    }

    func load() {
        guard questions.isEmpty else {
            phase = .setup
            return
        }

        guard let url = Bundle.main.url(forResource: "BibleTriviaQuestions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let loadedQuestions = try? JSONDecoder().decode([BibleTriviaQuestion].self, from: data),
              !loadedQuestions.isEmpty else {
            phase = .unavailable
            return
        }

        questions = loadedQuestions
        phase = .setup
    }

    func startRound() {
        let eligible = eligibleQuestions
        guard eligible.count >= Self.questionsPerRound else {
            phase = .unavailable
            return
        }

        var progress = progressStore.progress(for: difficulty)
        let remainingPool = eligible.filter { !progress.completedQuestionIDs.contains($0.id) }
        if remainingPool.isEmpty {
            progressStore.resetCompletedPool(for: difficulty)
            progress = progressStore.progress(for: difficulty)
        }

        let available = eligible.filter { !progress.completedQuestionIDs.contains($0.id) }
        round = Array(available.shuffled().prefix(Self.questionsPerRound)).map(makeRoundQuestion)
        guard round.count == Self.questionsPerRound else {
            phase = .unavailable
            return
        }

        currentIndex = 0
        furthestPresentedIndex = 0
        score = 0
        answered = 0
        phase = .playing
        prepareCurrentQuestion()
    }

    func choose(_ answer: String) {
        guard !isViewingPrevious, !isAnswered, options.contains(answer), let question = currentQuestion else { return }
        finishAnswer(answer, question: question)
    }

    func advance() {
        guard canGoNext else { return }
        if isViewingPrevious {
            currentIndex += 1
        } else if isLastQuestion {
            phase = .results
        } else {
            currentIndex += 1
            furthestPresentedIndex = currentIndex
            prepareCurrentQuestion()
        }
    }

    func showPrevious() {
        guard canGoPrevious else { return }
        timerTask?.cancel()
        currentIndex -= 1
    }

    func returnToSetup() {
        timerTask?.cancel()
        phase = .setup
    }

    private func prepareCurrentQuestion() {
        guard !isViewingPrevious, !isAnswered else { return }
        remainingSeconds = difficulty.timerSeconds
        startTimer()
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !self.isViewingPrevious, !self.isAnswered else { return }
                guard self.remainingSeconds > 1 else {
                    if let question = self.currentQuestion {
                        self.finishAnswer(nil, question: question)
                    }
                    return
                }
                self.remainingSeconds -= 1
            }
        }
    }

    private func finishAnswer(_ answer: String?, question: BibleTriviaQuestion) {
        guard !isViewingPrevious, !isAnswered else { return }
        timerTask?.cancel()
        round[currentIndex].selectedAnswer = answer
        round[currentIndex].timedOut = answer == nil
        answered += 1
        let isCorrect = answer == question.correctAnswer
        score += isCorrect ? 1 : 0
        progressStore.record(questionID: question.id, difficulty: difficulty)
        GameStats.shared.recordRound(
            game: .trivia,
            difficulty: difficulty.statsDifficulty,
            correct: isCorrect ? 1 : 0,
            answered: 1,
            currentBestStreak: 0
        )
    }

    private func makeRoundQuestion(_ question: BibleTriviaQuestion) -> RoundQuestion {
        let distractors = Array(Set(question.incorrectAnswers.filter { $0 != question.correctAnswer }))
        return RoundQuestion(
            question: question,
            options: (Array(distractors.shuffled().prefix(3)) + [question.correctAnswer]).shuffled()
        )
    }
}

struct BibleTriviaGameView: View {
    @State private var model = BibleTriviaGameModel()

    var body: some View {
        Group {
            switch model.phase {
            case .loading:
                ProgressView("Loading trivia questions…")
            case .setup:
                BibleTriviaSetupScreen(
                    difficulty: $model.difficulty,
                    questionsPerRound: 10,
                    eligibleQuestionCount: model.eligibleQuestions.count,
                    progressStore: model.progressStore,
                    onStart: model.startRound
                )
            case .playing:
                BibleTriviaPlayScreen(
                    question: model.currentQuestion,
                    options: model.options,
                    questionNumber: model.currentIndex + 1,
                    questionCount: model.roundCount,
                    score: model.score,
                    answered: model.answered,
                    accuracy: model.accuracy,
                    remainingSeconds: model.remainingSeconds,
                    timerSeconds: model.difficulty.timerSeconds,
                    selectedAnswer: model.selectedAnswer,
                    isAnswered: model.isAnswered,
                    timedOut: model.timedOut,
                    isViewingPrevious: model.isViewingPrevious,
                    canGoPrevious: model.canGoPrevious,
                    canGoNext: model.canGoNext,
                    isLastQuestion: model.isLastQuestion,
                    onChoose: model.choose,
                    onPrevious: model.showPrevious,
                    onAdvance: model.advance
                )
            case .results:
                BibleTriviaResultsScreen(
                    score: model.score,
                    questionCount: model.roundCount,
                    accuracy: model.accuracy,
                    difficulty: model.difficulty,
                    completedInPool: model.completedInPool,
                    totalInPool: model.eligibleQuestions.count,
                    progressStore: model.progressStore,
                    onPlayAgain: model.startRound,
                    onBackToSetup: model.returnToSetup
                )
            case .unavailable:
                ContentUnavailableView(
                    "Trivia questions unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text("The trivia catalog could not be loaded.")
                )
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if model.phase == .playing || model.phase == .results {
                    GameNavigationTitle(title: "Bible Trivia", systemImage: "questionmark.text.page.fill", tint: .cyan)
                }
            }
        }
        .task {
            model.load()
        }
    }
}

private struct BibleTriviaSetupScreen: View {
    @Binding var difficulty: BibleTriviaDifficulty
    let questionsPerRound: Int
    let eligibleQuestionCount: Int
    let progressStore: BibleTriviaProgressStore
    let onStart: () -> Void

    private var experienceLevel: Binding<GameExperienceLevel> {
        Binding(
            get: {
                switch difficulty {
                case .easy: .learn
                case .normal: .standard
                case .hard: .challenge
                }
            },
            set: { level in
                difficulty = switch level {
                case .learn: .easy
                case .standard: .normal
                case .challenge: .hard
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 24)

            Text("Answer Bible knowledge questions with Scripture support after every answer.")
                .gameStartDescriptionStyle(
                    title: "Bible Trivia",
                    systemImage: "questionmark.text.page.fill",
                    tint: .cyan
                )

            GameSplashLaunchLayout(
                tint: .cyan,
                experienceLevel: experienceLevel,
                experienceDetails: GameExperienceDetails(
                    learn: "Easy questions with 30 seconds for each answer.",
                    standard: "Easy and normal questions with 15 seconds each.",
                    challenge: "All questions with 10 seconds for each answer."
                ),
                startAction: onStart
            ) {
                GameLobbyPreview(kind: .trivia)
            } configuration: {
                BibleTriviaProgressCard(
                    progressStore: progressStore,
                    selectedDifficulty: difficulty
                )
                .padding(.horizontal)
            } facts: {
                GameSplashFacts(
                    first: ("number", "\(questionsPerRound)", "Questions"),
                    second: ("timer", "\(difficulty.timerSeconds) sec", "Per question"),
                    third: ("square.stack.3d.up", "\(eligibleQuestionCount)", "Question pool")
                )
            }

            Spacer(minLength: 24)
        }
        .gameStartScreenStyle()
    }
}

private struct BibleTriviaProgressCard: View {
    let progressStore: BibleTriviaProgressStore
    let selectedDifficulty: BibleTriviaDifficulty

    private let poolSizes: [BibleTriviaDifficulty: Int] = [
        .easy: 300,
        .normal: 1_050,
        .hard: 1_500
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Progress by Difficulty", systemImage: "chart.bar.fill")
                .font(.headline)
                .foregroundStyle(.cyan)

            ForEach(BibleTriviaDifficulty.allCases) { difficulty in
                let progress = progressStore.progress(for: difficulty)
                let stats = GameStats.shared.triviaCounts(difficulty: difficulty.statsDifficulty)
                let poolSize = poolSizes[difficulty, default: 0]
                let accuracy = stats.answered > 0
                    ? Int((Double(stats.correct) / Double(stats.answered) * 100).rounded())
                    : 0

                HStack(spacing: 12) {
                    Image(systemName: difficulty == selectedDifficulty ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(difficulty == selectedDifficulty ? .cyan : .secondary)

                    Text(difficulty.title)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("\(stats.answered) answered")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(accuracy)%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.cyan)
                }

                ProgressView(value: Double(progress.completedQuestionIDs.count), total: Double(poolSize))
                    .tint(.cyan)
                    .accessibilityLabel("\(difficulty.title) pool progress")
                    .accessibilityValue("\(progress.completedQuestionIDs.count) of \(poolSize) completed")
            }
        }
        .padding(16)
        .frame(maxWidth: 620, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct BibleTriviaPlayScreen: View {
    let question: BibleTriviaQuestion?
    let options: [String]
    let questionNumber: Int
    let questionCount: Int
    let score: Int
    let answered: Int
    let accuracy: Int
    let remainingSeconds: Int
    let timerSeconds: Int
    let selectedAnswer: String?
    let isAnswered: Bool
    let timedOut: Bool
    let isViewingPrevious: Bool
    let canGoPrevious: Bool
    let canGoNext: Bool
    let isLastQuestion: Bool
    let onChoose: (String) -> Void
    let onPrevious: () -> Void
    let onAdvance: () -> Void

    @State private var timerOnLeft = false
    @State private var usesMutedTimerStyle = false

    private var timerTint: Color {
        let fraction = Double(remainingSeconds) / Double(max(1, timerSeconds))
        if fraction <= 0.3 { return .red }
        if fraction <= 0.6 { return .yellow }
        return .green
    }

    private var outcome: BibleTriviaAnswerOutcome? {
        guard isAnswered, let question else {
            return nil
        }
        if timedOut {
            return .timedOut
        }
        return selectedAnswer == question.correctAnswer ? .correct : .incorrect
    }

    var body: some View {
        GeometryReader { geometry in
            let usesSplitLayout = geometry.size.width >= 700

            ZStack {
                ScrollView {
                    if let question {
                        if usesSplitLayout {
                            BibleTriviaDashboard(
                                question: question.question,
                                correctAnswer: question.correctAnswer,
                                options: options,
                                questionNumber: questionNumber,
                                questionCount: questionCount,
                                score: score,
                                answered: answered,
                                selectedAnswer: selectedAnswer,
                                isAnswered: isAnswered,
                                isViewingPrevious: isViewingPrevious,
                                onChoose: onChoose,
                                revealedQuestion: isAnswered ? question : nil,
                                timedOut: timedOut,
                                canGoPrevious: canGoPrevious,
                                canGoNext: canGoNext,
                                isLastQuestion: isLastQuestion,
                                onPrevious: onPrevious,
                                onAdvance: onAdvance
                            )
                            .frame(minHeight: geometry.size.height - 32, alignment: .top)
                        } else {
                            BibleTriviaCompactBoard(
                                question: question.question,
                                correctAnswer: question.correctAnswer,
                                options: options,
                                questionNumber: questionNumber,
                                questionCount: questionCount,
                                score: score,
                                answered: answered,
                                remainingSeconds: remainingSeconds,
                                timerTint: timerTint,
                                selectedAnswer: selectedAnswer,
                                isAnswered: isAnswered,
                                isViewingPrevious: isViewingPrevious,
                                onChoose: onChoose,
                                revealedQuestion: isAnswered ? question : nil,
                                timedOut: timedOut,
                                canGoPrevious: canGoPrevious,
                                canGoNext: canGoNext,
                                isLastQuestion: isLastQuestion,
                                onPrevious: onPrevious,
                                onAdvance: onAdvance
                            )
                        }
                    }
                }
                .tabBarContentClearance()
                .background {
                    if usesSplitLayout {
                        Color.clear
                            .heroCardSurface()
                            .padding(12)
                    }
                }
                .frame(width: usesSplitLayout ? geometry.size.width / 2 : geometry.size.width)
                .frame(
                    maxWidth: .infinity,
                    alignment: usesSplitLayout && timerOnLeft ? .trailing : .leading
                )

                if usesSplitLayout {
                    BibleTriviaLargeTimerView(
                        remainingSeconds: remainingSeconds,
                        tint: timerTint,
                        outcome: outcome,
                        usesMutedStyle: $usesMutedTimerStyle,
                        onSwapSides: {
                            withAnimation(.snappy) {
                                timerOnLeft.toggle()
                            }
                        }
                    )
                    .frame(width: geometry.size.width / 2)
                    .frame(maxWidth: .infinity, alignment: timerOnLeft ? .leading : .trailing)
                }
            }
        }
        .background(AppBackgroundView(tab: .games))
    }
}

private struct BibleTriviaCompactBoard: View {
    let question: String
    let correctAnswer: String
    let options: [String]
    let questionNumber: Int
    let questionCount: Int
    let score: Int
    let answered: Int
    let remainingSeconds: Int
    let timerTint: Color
    let selectedAnswer: String?
    let isAnswered: Bool
    let isViewingPrevious: Bool
    let onChoose: (String) -> Void
    let revealedQuestion: BibleTriviaQuestion?
    let timedOut: Bool
    let canGoPrevious: Bool
    let canGoNext: Bool
    let isLastQuestion: Bool
    let onPrevious: () -> Void
    let onAdvance: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            GameScoreboardCard(
                currentCorrect: score,
                currentAnswered: answered,
                currentStreak: 0,
                game: .trivia
            )

            BibleTriviaQuestionBoard(
                question: question,
                correctAnswer: correctAnswer,
                questionNumber: questionNumber,
                questionCount: questionCount,
                options: options,
                selectedAnswer: selectedAnswer,
                isAnswered: isAnswered,
                isViewingPrevious: isViewingPrevious,
                onChoose: onChoose
            )

            if !isAnswered {
                GameTimerCard(remainingSeconds: remainingSeconds, tint: timerTint, isPulsing: false)
            }

            if let revealedQuestion {
                BibleTriviaRevealCard(question: revealedQuestion, timedOut: timedOut)
                BibleTriviaNavigationButtons(
                    canGoPrevious: canGoPrevious,
                    canGoNext: canGoNext,
                    isLastQuestion: isLastQuestion,
                    onPrevious: onPrevious,
                    onNext: onAdvance
                )
            }
        }
        .padding(.horizontal)
        .padding(.vertical)
    }
}

private struct BibleTriviaDashboard: View {
    let question: String
    let correctAnswer: String
    let options: [String]
    let questionNumber: Int
    let questionCount: Int
    let score: Int
    let answered: Int
    let selectedAnswer: String?
    let isAnswered: Bool
    let isViewingPrevious: Bool
    let onChoose: (String) -> Void
    let revealedQuestion: BibleTriviaQuestion?
    let timedOut: Bool
    let canGoPrevious: Bool
    let canGoNext: Bool
    let isLastQuestion: Bool
    let onPrevious: () -> Void
    let onAdvance: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            GameScoreboardCard(
                currentCorrect: score,
                currentAnswered: answered,
                currentStreak: 0,
                game: .trivia,
                style: .dashboard
            )

            BibleTriviaQuestionBoard(
                question: question,
                correctAnswer: correctAnswer,
                questionNumber: questionNumber,
                questionCount: questionCount,
                options: options,
                selectedAnswer: selectedAnswer,
                isAnswered: isAnswered,
                isViewingPrevious: isViewingPrevious,
                onChoose: onChoose
            )

            if let revealedQuestion {
                BibleTriviaRevealCard(question: revealedQuestion, timedOut: timedOut)
                BibleTriviaNavigationButtons(
                    canGoPrevious: canGoPrevious,
                    canGoNext: canGoNext,
                    isLastQuestion: isLastQuestion,
                    onPrevious: onPrevious,
                    onNext: onAdvance
                )
            }

            Spacer(minLength: 0)
        }
        .padding(AppDesignMetrics.cardPadding)
        .padding(.top, 12)
    }
}

private struct BibleTriviaQuestionBoard: View {
    let question: String
    let correctAnswer: String
    let questionNumber: Int
    let questionCount: Int
    let options: [String]
    let selectedAnswer: String?
    let isAnswered: Bool
    let isViewingPrevious: Bool
    let onChoose: (String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                HStack {
                    Label("Choose the correct answer", systemImage: "questionmark.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.cyan)

                    Spacer()

                    Text("Question \(questionNumber) of \(questionCount)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Text(question)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(.cyan.opacity(0.08), in: RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(options, id: \.self) { option in
                    BibleTriviaAnswerOption(
                        title: option,
                        isCorrect: isAnswered && option == correctAnswer,
                        isIncorrectSelection: isAnswered && option == selectedAnswer && option != correctAnswer,
                        isDisabled: isAnswered || isViewingPrevious
                    ) {
                        onChoose(option)
                    }
                }
            }
        }
    }

}

private struct BibleTriviaAnswerOption: View {
    let title: String
    let isCorrect: Bool
    let isIncorrectSelection: Bool
    let isDisabled: Bool
    let action: () -> Void

    private var glass: Glass {
        if isCorrect { return .regular.tint(.green.opacity(0.28)) }
        if isIncorrectSelection { return .regular.tint(.red.opacity(0.28)) }
        return .clear
    }

    private var icon: String {
        if isCorrect { return "checkmark.circle.fill" }
        if isIncorrectSelection { return "xmark.circle.fill" }
        return "circle"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        }
        .buttonStyle(.glass(glass))
        .disabled(isDisabled)
    }
}

private struct BibleTriviaNavigationButtons: View {
    let canGoPrevious: Bool
    let canGoNext: Bool
    let isLastQuestion: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button("Previous", systemImage: "arrow.left", action: onPrevious)
                .buttonStyle(GameProminentButtonStyle(tint: .accentColor))
                .disabled(!canGoPrevious)

            if isLastQuestion {
                Button("See Results", systemImage: "flag.checkered", action: onNext)
                    .buttonStyle(GameProminentButtonStyle(tint: .cyan))
                    .disabled(!canGoNext)
            } else {
                Button("Next", systemImage: "arrow.right", action: onNext)
                    .buttonStyle(GameProminentButtonStyle(tint: .accentColor))
                    .disabled(!canGoNext)
            }
        }
    }
}

private enum BibleTriviaAnswerOutcome {
    case correct
    case incorrect
    case timedOut

    var title: LocalizedStringKey {
        switch self {
        case .correct: "Correct"
        case .incorrect: "Incorrect"
        case .timedOut: "Time’s Up"
        }
    }

    var systemImage: String {
        switch self {
        case .correct: "checkmark.circle.fill"
        case .incorrect: "xmark.circle.fill"
        case .timedOut: "hourglass.bottomhalf.filled"
        }
    }

    var tint: Color {
        self == .correct ? .green : .red
    }
}

private struct BibleTriviaLargeTimerView: View {
    let remainingSeconds: Int
    let tint: Color
    let outcome: BibleTriviaAnswerOutcome?
    @Binding var usesMutedStyle: Bool
    let onSwapSides: () -> Void

    private var displayTint: Color {
        outcome?.tint ?? tint
    }

    private var vividTextColor: Color {
        outcome == nil && tint == .yellow ? .black : .white
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            VStack(spacing: 24) {
                Image(systemName: outcome?.systemImage ?? "timer")
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(usesMutedStyle ? displayTint : vividTextColor.opacity(0.85))

                Text(outcome?.title ?? "Time Remaining")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(usesMutedStyle ? displayTint : vividTextColor.opacity(0.85))

                if outcome == nil {
                    Text("\(remainingSeconds)s")
                        .font(.largeTitle.weight(.bold))
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .foregroundStyle(usesMutedStyle ? displayTint : vividTextColor)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(outcome?.title ?? "Time Remaining")
            .accessibilityValue(outcome == nil ? "\(remainingSeconds) seconds" : "")

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button("Swap card sides", systemImage: "arrow.left.arrow.right", action: onSwapSides)

                Button(
                    usesMutedStyle ? "Use vivid timer background" : "Use muted timer background",
                    systemImage: "circle.lefthalf.filled"
                ) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        usesMutedStyle.toggle()
                    }
                }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass(.clear))
            .controlSize(.small)
            .tint(usesMutedStyle ? displayTint : vividTextColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .background {
            if usesMutedStyle {
                Color.clear
                    .heroCardSurface()
            } else {
                RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous)
                    .fill(displayTint)
            }
        }
        .overlay {
            if !usesMutedStyle {
                RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous)
                    .strokeBorder(vividTextColor.opacity(0.22), lineWidth: 1)
            }
        }
        .shadow(color: usesMutedStyle ? .clear : displayTint.opacity(0.25), radius: 12, x: 0, y: 5)
        .padding(12)
        .animation(.easeInOut(duration: 0.25), value: remainingSeconds)
    }
}

private struct BibleTriviaRevealCard: View {
    let question: BibleTriviaQuestion
    let timedOut: Bool
    @State private var showsExplanation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                timedOut ? "Time’s up" : "Answer revealed",
                systemImage: timedOut ? "timer" : "checkmark.seal.fill"
            )
            .font(.headline)
            .foregroundStyle(timedOut ? .orange : .green)

            Text(question.correctAnswer)
                .font(.title3.weight(.bold))

            Label(question.reference, systemImage: "book.closed.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.cyan)

            DisclosureGroup("Why this is correct", isExpanded: $showsExplanation) {
                Text("\(question.reference) supports “\(question.correctAnswer).”")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            }

        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct BibleTriviaResultsScreen: View {
    let score: Int
    let questionCount: Int
    let accuracy: Int
    let difficulty: BibleTriviaDifficulty
    let completedInPool: Int
    let totalInPool: Int
    let progressStore: BibleTriviaProgressStore
    let onPlayAgain: () -> Void
    let onBackToSetup: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 24)

            Image(systemName: "trophy.fill")
                .font(.system(size: 54))
                .foregroundStyle(.cyan)

            Text("Round Complete")
                .font(.largeTitle.bold())

            Text("\(score) of \(questionCount) correct · \(accuracy)% accuracy")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                Label("\(completedInPool) of \(totalInPool) questions completed in this pool", systemImage: "chart.bar.fill")
                ProgressView(value: Double(completedInPool), total: Double(totalInPool))
                    .tint(.cyan)
            }
            .padding(16)
            .frame(maxWidth: 520)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            BibleTriviaProgressCard(
                progressStore: progressStore,
                selectedDifficulty: difficulty
            )

            HStack {
                Button("Change Difficulty", action: onBackToSetup)
                    .buttonStyle(.bordered)

                Button("Play Another Round", action: onPlayAgain)
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
            }

            Spacer()
        }
        .padding()
        .tabBarContentClearance()
    }
}

#Preview {
    NavigationStack {
        BibleTriviaGameView()
    }
}
