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
    /// Increments each time every question in the pool has been asked and the pool restarts.
    /// Merges keep the higher cycle so a restart on one device isn't undone by another's history.
    var cycle = 0

    init(completedQuestionIDs: Set<Int> = [], cycle: Int = 0) {
        self.completedQuestionIDs = completedQuestionIDs
        self.cycle = cycle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        completedQuestionIDs = try container.decodeIfPresent(Set<Int>.self, forKey: .completedQuestionIDs) ?? []
        cycle = try container.decodeIfPresent(Int.self, forKey: .cycle) ?? 0
    }
}

@MainActor
@Observable
final class BibleTriviaProgressStore {
    static let shared = BibleTriviaProgressStore()

    // V3: the updated catalog revises existing questions, so prior completion history is ignored.
    nonisolated static let storageKey = "bibleTriviaProgressV3"

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
              let decoded = PersistedDecoding.decode([String: BibleTriviaDifficultyProgress].self, from: data, name: "bibleTriviaProgress") else {
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
            if localValue.cycle == remoteValue.cycle {
                merged[key] = BibleTriviaDifficultyProgress(
                    completedQuestionIDs: localValue.completedQuestionIDs.union(remoteValue.completedQuestionIDs),
                    cycle: localValue.cycle
                )
            } else {
                merged[key] = localValue.cycle > remoteValue.cycle ? localValue : remoteValue
            }
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
        progress.cycle += 1
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
    private static let bestScoreKeyPrefix = "bibleTriviaBestScore"

    private let reviewQuestionIDs: Set<String>

    init(reviewQuestionIDs: Set<String> = []) {
        self.reviewQuestionIDs = reviewQuestionIDs
    }

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
    private var carryoverQuestionIDs: Set<Int> = []
    private(set) var currentIndex = 0
    private var furthestPresentedIndex = 0
    private(set) var score = 0
    private(set) var answered = 0
    private(set) var bestScore = 0
    private(set) var currentStreak = 0
    private(set) var currentBestStreak = 0
    private(set) var remainingSeconds = 0
    var isTimerDisabled = false
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
        guard !reviewQuestionIDs.isEmpty else {
            return questions.filter(difficulty.includes)
        }
        return questions.filter { reviewQuestionIDs.contains(String($0.id)) }
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

    private var persistentStreak: PersistentGameStreak {
        PersistentGameStreak(game: "trivia", variant: difficulty.rawValue)
    }

    func load() async {
        guard questions.isEmpty else {
            phase = .setup
            return
        }

        // The catalog is large; decode it off the main actor so the screen stays responsive.
        let loadedQuestions = await Task.detached(priority: .userInitiated) { () -> [BibleTriviaQuestion] in
            guard let url = Bundle.main.url(forResource: "BibleTriviaQuestions", withExtension: "json"),
                  let data = try? Data(contentsOf: url, options: .mappedIfSafe),
                  let decoded = PersistedDecoding.decode([BibleTriviaQuestion].self, from: data, name: "BibleTriviaQuestions.json") else {
                return []
            }
            return decoded
        }.value

        guard !loadedQuestions.isEmpty else {
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

        round = selectRoundQuestions(from: eligible).map(makeRoundQuestion)
        guard round.count == Self.questionsPerRound else {
            phase = .unavailable
            return
        }

        currentIndex = 0
        furthestPresentedIndex = 0
        score = 0
        answered = 0
        bestScore = UserDefaults.standard.integer(forKey: bestScoreKey)
        currentStreak = persistentStreak.current
        currentBestStreak = persistentStreak.best
        isTimerDisabled = false
        phase = .playing
        prepareCurrentQuestion()
    }

    /// Draws questions at random from those not yet asked in the current cycle. When fewer than a
    /// round's worth remain, the leftovers are used, the pool restarts, and the round is topped up
    /// from the rest so no question repeats until every question in the pool has been asked.
    private func selectRoundQuestions(from eligible: [BibleTriviaQuestion]) -> [BibleTriviaQuestion] {
        carryoverQuestionIDs = []
        guard reviewQuestionIDs.isEmpty else {
            return Array(eligible.shuffled().prefix(Self.questionsPerRound))
        }

        let completed = progressStore.progress(for: difficulty).completedQuestionIDs
        var selected = Array(eligible.filter { !completed.contains($0.id) }.shuffled().prefix(Self.questionsPerRound))
        guard selected.count < Self.questionsPerRound else { return selected }

        // Leftovers belong to the finished cycle, so they aren't recorded against the new one.
        carryoverQuestionIDs = Set(selected.map(\.id))
        progressStore.resetCompletedPool(for: difficulty)
        let refill = eligible.filter { !carryoverQuestionIDs.contains($0.id) }.shuffled()
        selected += refill.prefix(Self.questionsPerRound - selected.count)
        return selected.shuffled()
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
            savePersonalBest()
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
        guard !isTimerDisabled else { return }
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

    func toggleTimer() {
        isTimerDisabled.toggle()
        if !isTimerDisabled, !isViewingPrevious, !isAnswered {
            startTimer()
        } else {
            timerTask?.cancel()
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
        if isCorrect {
            let streak = persistentStreak.recordWin()
            currentStreak = streak.current
            currentBestStreak = max(currentBestStreak, streak.best)
        } else {
            persistentStreak.reset()
            currentStreak = 0
        }
        if !carryoverQuestionIDs.contains(question.id) {
            progressStore.record(questionID: question.id, difficulty: difficulty)
        }
        GameStats.shared.recordRound(
            game: .trivia,
            difficulty: difficulty.statsDifficulty,
            correct: isCorrect ? 1 : 0,
            answered: 1,
            currentBestStreak: currentBestStreak
        )
        let scriptureReference = BibleReferenceLinker.parse(question.reference)
        if let bookName = scriptureReference?.bookName {
            GameStats.shared.recordTriviaPerBook(
                bookName: bookName,
                answered: 1,
                correct: isCorrect ? 1 : 0
            )
        }
        if isCorrect, !reviewQuestionIDs.isEmpty {
            MissedGameQuestionStore.shared.resolveReviewQuestion(
                game: .bibleTrivia,
                questionID: String(question.id)
            )
        } else if !isCorrect {
            MissedGameQuestionStore.shared.record(
                game: .bibleTrivia,
                bookNames: scriptureReference.map { [$0.bookName] } ?? [],
                chapterNumber: scriptureReference?.chapter,
                topic: "Bible trivia",
                questionID: String(question.id)
            )
        }
    }

    private func makeRoundQuestion(_ question: BibleTriviaQuestion) -> RoundQuestion {
        let distractors = Array(Set(question.incorrectAnswers.filter { $0 != question.correctAnswer }))
        return RoundQuestion(
            question: question,
            options: (Array(distractors.shuffled().prefix(3)) + [question.correctAnswer]).shuffled()
        )
    }

    private var bestScoreKey: String {
        "\(Self.bestScoreKeyPrefix).\(difficulty.rawValue)"
    }

    private func savePersonalBest() {
        guard score > bestScore else { return }
        bestScore = score
        UserDefaults.standard.set(score, forKey: bestScoreKey)
        iCloudSyncCoordinator.shared.pushKey(bestScoreKey)
    }
}

struct BibleTriviaGameView: View {
    @State private var model: BibleTriviaGameModel
    private let isReviewRound: Bool

    init(reviewQuestionIDs: Set<String> = []) {
        isReviewRound = !reviewQuestionIDs.isEmpty
        _model = State(initialValue: BibleTriviaGameModel(reviewQuestionIDs: reviewQuestionIDs))
    }

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
                    isReviewRound: isReviewRound,
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
                    currentStreak: model.currentStreak,
                    accuracy: model.accuracy,
                    remainingSeconds: model.remainingSeconds,
                    timerSeconds: model.difficulty.timerSeconds,
                    isTimerDisabled: model.isTimerDisabled,
                    selectedAnswer: model.selectedAnswer,
                    isAnswered: model.isAnswered,
                    timedOut: model.timedOut,
                    isViewingPrevious: model.isViewingPrevious,
                    canGoPrevious: model.canGoPrevious,
                    canGoNext: model.canGoNext,
                    isLastQuestion: model.isLastQuestion,
                    onChoose: model.choose,
                    onToggleTimer: model.toggleTimer,
                    onPrevious: model.showPrevious,
                    onAdvance: model.advance
                )
            case .results:
                BibleTriviaResultsScreen(
                    score: model.score,
                    questionCount: model.roundCount,
                    accuracy: model.accuracy,
                    difficulty: model.difficulty,
                    bestScore: model.bestScore,
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
                    GameNavigationTitle(title: "Trivia", systemImage: "questionmark.text.page.fill", tint: .cyan)
                }
            }
        }
        .task {
            await model.load()
        }
    }
}

private struct BibleTriviaSetupScreen: View {
    @Binding var difficulty: BibleTriviaDifficulty
    let questionsPerRound: Int
    let eligibleQuestionCount: Int
    let isReviewRound: Bool
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
        ScrollView {
            VStack(spacing: 16) {
                Spacer(minLength: 24)

                Text("Answer Bible knowledge questions with Scripture support after every answer.")
                    .gameStartDescriptionStyle(
                        title: "Trivia",
                        systemImage: "questionmark.text.page.fill",
                        tint: .cyan
                    )

                GameSplashLaunchLayout(
                    tint: .cyan,
                    experienceLevel: experienceLevel,
                    experienceDetails: GameExperienceDetails(
                        learn: "30 seconds for each answer.",
                        standard: "15 seconds for each answer and questions are a little more challenging",
                        challenge: "10 seconds for each answer and the most challenging questions."
                    ),
                    experienceTitle: isReviewRound ? "Timer" : "How you’ll play",
                    isConfigurationEnabled: !isReviewRound,
                    startAction: onStart
                ) {
                    GameLobbyPreview(kind: .trivia)
                } configuration: {
                    EmptyView()
                } facts: {
                    GameSplashFacts(
                        first: ("number", "\(questionsPerRound) questions", "This session"),
                        second: ("timer", "\(difficulty.timerSeconds) sec", "Per question"),
                        third: ("square.stack.3d.up", "\(eligibleQuestionCount)", "Question pool")
                    )
                }

                Spacer(minLength: 24)
            }
            .gameStartScreenStyle()
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
    let currentStreak: Int
    let accuracy: Int
    let remainingSeconds: Int
    let timerSeconds: Int
    let isTimerDisabled: Bool
    let selectedAnswer: String?
    let isAnswered: Bool
    let timedOut: Bool
    let isViewingPrevious: Bool
    let canGoPrevious: Bool
    let canGoNext: Bool
    let isLastQuestion: Bool
    let onChoose: (String) -> Void
    let onToggleTimer: () -> Void
    let onPrevious: () -> Void
    let onAdvance: () -> Void

    @State private var timerOnLeft = false
    @State private var usesMutedTimerStyle = false
    @State private var verseToast = VerseActionToastState()

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
                                currentStreak: currentStreak,
                                outcome: outcome,
                                reference: question.reference,
                                selectedAnswer: selectedAnswer,
                                isAnswered: isAnswered,
                                isViewingPrevious: isViewingPrevious,
                                onChoose: onChoose,
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
                                currentStreak: currentStreak,
                                remainingSeconds: remainingSeconds,
                                timerTint: timerTint,
                                isTimerDisabled: isTimerDisabled,
                                outcome: outcome,
                                reference: question.reference,
                                selectedAnswer: selectedAnswer,
                                isAnswered: isAnswered,
                                isViewingPrevious: isViewingPrevious,
                                onChoose: onChoose,
                                onToggleTimer: onToggleTimer,
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
                        tint: isTimerDisabled ? .secondary : timerTint,
                        isTimerDisabled: isTimerDisabled,
                        outcome: outcome,
                        usesMutedStyle: $usesMutedTimerStyle,
                        onToggleTimer: onToggleTimer,
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
        .verseActionToast($verseToast)
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
    let currentStreak: Int
    let remainingSeconds: Int
    let timerTint: Color
    let isTimerDisabled: Bool
    let outcome: BibleTriviaAnswerOutcome?
    let reference: String
    let selectedAnswer: String?
    let isAnswered: Bool
    let isViewingPrevious: Bool
    let onChoose: (String) -> Void
    let onToggleTimer: () -> Void
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
                currentStreak: currentStreak,
                game: .trivia
            )

            BibleTriviaQuestionBoard(
                question: question,
                correctAnswer: correctAnswer,
                questionNumber: questionNumber,
                questionCount: questionCount,
                options: options,
                remainingSeconds: isAnswered ? nil : remainingSeconds,
                timerTint: timerTint,
                isTimerDisabled: isTimerDisabled,
                selectedAnswer: selectedAnswer,
                isAnswered: isAnswered,
                isViewingPrevious: isViewingPrevious,
                onChoose: onChoose
            )

            if !isAnswered {
                Button(isTimerDisabled ? "Timer On" : "Timer Off", systemImage: isTimerDisabled ? "play.fill" : "pause.fill", action: onToggleTimer)
                    .buttonStyle(.bordered)
            }

            if isAnswered {
                if let outcome {
                    BibleTriviaAnswerReveal(outcome: outcome, reference: reference)
                }

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
    let currentStreak: Int
    let outcome: BibleTriviaAnswerOutcome?
    let reference: String
    let selectedAnswer: String?
    let isAnswered: Bool
    let isViewingPrevious: Bool
    let onChoose: (String) -> Void
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
                currentStreak: currentStreak,
                game: .trivia,
                style: .dashboard
            )

            BibleTriviaQuestionBoard(
                question: question,
                correctAnswer: correctAnswer,
                questionNumber: questionNumber,
                questionCount: questionCount,
                options: options,
                remainingSeconds: nil,
                timerTint: .cyan,
                isTimerDisabled: false,
                selectedAnswer: selectedAnswer,
                isAnswered: isAnswered,
                isViewingPrevious: isViewingPrevious,
                onChoose: onChoose
            )

            if isAnswered {
                if let outcome {
                    BibleTriviaAnswerReveal(outcome: outcome, reference: reference)
                }

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
    let remainingSeconds: Int?
    let timerTint: Color
    let isTimerDisabled: Bool
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

            if let remainingSeconds, !isAnswered {
                GameTimerCard(
                    remainingSeconds: remainingSeconds,
                    tint: isTimerDisabled ? .secondary : timerTint,
                    isPulsing: false,
                    formattedTime: isTimerDisabled ? "Timer off" : nil,
                    isDisabled: isTimerDisabled
                )
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(options, id: \.self) { option in
                    BibleTriviaAnswerOption(
                        title: option,
                        isCorrect: isAnswered && option == correctAnswer,
                        isSelected: option == selectedAnswer,
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
    let isSelected: Bool
    let isIncorrectSelection: Bool
    let isDisabled: Bool
    let action: () -> Void

    private var backgroundColor: Color {
        guard isDisabled, isSelected else { return .clear }
        if isCorrect { return .green.opacity(0.3) }
        if isIncorrectSelection { return .red.opacity(0.3) }
        return .clear
    }

    var body: some View {
        Button {
            action()
        } label: {
            Text(title)
            .frame(maxWidth: .infinity)
            .padding()
            .foregroundStyle(.primary)
        }
        .disabled(isDisabled)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isCorrect && isDisabled ? Color.green : Color.black.opacity(0.15),
                    lineWidth: isCorrect && isDisabled ? 3 : 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .font(.body)
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

private struct BibleTriviaAnswerReveal: View {
    let outcome: BibleTriviaAnswerOutcome
    let reference: String

    private var passageReference: PassageReference? {
        PassageReferenceParser.parse(reference)
    }

    private var verseActionReference: VerseActionReference? {
        guard let parsedReference = BibleReferenceLinker.parse(reference),
              let verseText = BibleData.books
                .first(where: { $0.name == parsedReference.bookName })?
                .chapters.first(where: { $0.number == parsedReference.chapter })?
                .verses.first(where: { $0.number == parsedReference.startVerse })?
                .text else {
            return nil
        }

        return VerseActionReference(
            bookName: parsedReference.bookName,
            chapterNumber: parsedReference.chapter,
            verseNumber: parsedReference.startVerse,
            verseText: verseText
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: outcome.systemImage)
                .font(.title2.weight(.bold))
                .foregroundStyle(outcome.tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(outcome.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(outcome.tint)

                if let passageReference {
                    Link(destination: passageReference.url) {
                        Label(reference, systemImage: "book")
                            .font(.title3.weight(.bold))
                    }
                    .accessibilityHint("Shows a preview of the passage")
                } else if !reference.isEmpty {
                    Text(reference)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                }
            }

            Spacer(minLength: 8)

            if let verseActionReference {
                VerseActionMenu(verse: verseActionReference)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 64)
        .glassEffect(.regular.tint(outcome.tint.opacity(0.35)), in: .rect(cornerRadius: AppDesignMetrics.compactControlCornerRadius))
        .scripturePassagePreviews()
        .accessibilityElement(children: .contain)
    }
}

private struct BibleTriviaLargeTimerView: View {
    let remainingSeconds: Int
    let tint: Color
    let isTimerDisabled: Bool
    let outcome: BibleTriviaAnswerOutcome?
    @Binding var usesMutedStyle: Bool
    let onToggleTimer: () -> Void
    let onSwapSides: () -> Void

    private var displayTint: Color {
        isTimerDisabled && outcome == nil ? .secondary : outcome?.tint ?? tint
    }

    private var vividTextColor: Color {
        outcome == nil && tint == .yellow ? .black : .white
    }

    private var usesNeutralStyle: Bool {
        usesMutedStyle || isTimerDisabled
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            VStack(spacing: 24) {
                Image(systemName: outcome?.systemImage ?? (isTimerDisabled ? "timer.slash" : "timer"))
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(usesNeutralStyle ? displayTint : vividTextColor.opacity(0.85))

                Text(outcome?.title ?? (isTimerDisabled ? "Timer Off" : "Time Remaining"))
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(usesNeutralStyle ? displayTint : vividTextColor.opacity(0.85))

                if outcome == nil {
                    Text("\(remainingSeconds)s")
                        .font(.largeTitle.weight(.bold))
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .foregroundStyle(usesNeutralStyle ? displayTint : vividTextColor)
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

                if outcome == nil {
                    Button(isTimerDisabled ? "Timer On" : "Timer Off", systemImage: isTimerDisabled ? "play.fill" : "pause.fill", action: onToggleTimer)
                }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass(.clear))
            .controlSize(.small)
            .tint(usesNeutralStyle ? displayTint : vividTextColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .background {
            if usesNeutralStyle {
                Color.clear
                    .heroCardSurface()
            } else {
                RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous)
                    .fill(displayTint)
            }
        }
        .overlay {
            if !usesNeutralStyle {
                RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous)
                    .strokeBorder(vividTextColor.opacity(0.22), lineWidth: 1)
            }
        }
        .shadow(color: usesNeutralStyle ? .clear : displayTint.opacity(0.25), radius: 12, x: 0, y: 5)
        .padding(12)
        .animation(.easeInOut(duration: 0.25), value: remainingSeconds)
    }
}

private struct BibleTriviaResultsScreen: View {
    let score: Int
    let questionCount: Int
    let accuracy: Int
    let difficulty: BibleTriviaDifficulty
    let bestScore: Int
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

            BibleTriviaPersonalBestCard(
                score: bestScore,
                questionCount: questionCount,
                difficulty: difficulty
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

private struct BibleTriviaPersonalBestCard: View {
    let score: Int
    let questionCount: Int
    let difficulty: BibleTriviaDifficulty

    private var accuracy: Int {
        guard questionCount > 0 else { return 0 }
        return Int((Double(score) / Double(questionCount) * 100).rounded())
    }

    var body: some View {
        VStack(spacing: 8) {
            Label("Personal Best · \(Text(difficulty.title))", systemImage: "trophy.fill")
                .font(.headline)
                .foregroundStyle(.cyan)
            Text("\(score) of \(questionCount) correct · \(accuracy)% accuracy")
                .font(.title3.weight(.semibold))
        }
        .padding(16)
        .frame(maxWidth: 520)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        BibleTriviaGameView()
    }
}
