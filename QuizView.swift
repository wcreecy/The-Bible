import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct QuizView: View {
    enum Difficulty: String, CaseIterable, Identifiable {
        case easy
        case normal
        case hard

        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .easy: "Easy"
            case .normal: "Normal"
            case .hard: "Hard"
            }
        }

        /// Seconds per verse, or nil for no time limit.
        var timeLimit: Int? {
            switch self {
            case .easy: nil
            case .normal: 15
            case .hard: 12
            }
        }

        /// Seconds the previous verse costs; free when there's no timer.
        var contextCost: Int { timeLimit == nil ? 0 : QuizView.contextCost }

        var detail: LocalizedStringResource {
            switch self {
            case .easy:
                "No time limit. Wrong choices come from other parts of the Bible."
            case .normal:
                "15 seconds per verse. Wrong choices come from anywhere in your categories."
            case .hard:
                "12 seconds per verse. Wrong choices come from the same part of the Bible, such as all four Gospels."
            }
        }

        var statsDifficulty: GameStats.Difficulty {
            switch self {
            case .easy: .easy
            case .normal: .normal
            case .hard: .hard
            }
        }
    }

    enum VerseSection: String, CaseIterable, Identifiable {
        case law
        case history
        case poetry
        case majorProphets
        case minorProphets
        case gospels
        case acts
        case epistles
        // Stored as "apocalypse" in existing settings.
        case revelation = "apocalypse"

        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .law: "Law"
            case .history: "History"
            case .poetry: "Poetry"
            case .majorProphets: "Major Prophets"
            case .minorProphets: "Minor Prophets"
            case .gospels: "Gospels"
            case .acts: "Acts"
            case .epistles: "Epistles"
            case .revelation: "Revelation"
            }
        }

        var isOldTestament: Bool {
            switch self {
            case .law, .history, .poetry, .majorProphets, .minorProphets: true
            case .gospels, .acts, .epistles, .revelation: false
            }
        }

        /// Positions in the 66-book canon.
        private var canonRange: Range<Int> {
            switch self {
            case .law: 0..<5
            case .history: 5..<17
            case .poetry: 17..<22
            case .majorProphets: 22..<27
            case .minorProphets: 27..<39
            case .gospels: 39..<43
            case .acts: 43..<44
            case .epistles: 44..<65
            case .revelation: 65..<66
            }
        }

        var bookNames: [String] { Array(BibleCanon.fallbackCanon[canonRange]) }

        /// Hard draws wrong choices from these sections. Acts and Revelation are single
        /// books, so they share with their closest neighbors.
        var hardFamily: [VerseSection] {
            switch self {
            case .acts: [.gospels, .acts]
            case .revelation: [.epistles, .revelation]
            default: [self]
            }
        }

        static func containing(_ bookName: String) -> VerseSection? {
            allCases.first { $0.bookNames.contains(bookName) }
        }
    }

    static let questionsPerGame = 10
    static let contextCost = 3

    private enum Phase {
        case setup
        case playing
        case results
    }

    private struct VerseCandidate {
        let text: String
        let bookName: String
        let chapter: Int
        let verse: Int
        let contextText: String?
    }

    private struct QuizQuestion: Identifiable {
        let id = UUID()
        let verseText: String
        let correctBook: String
        let chapter: Int
        let verse: Int
        /// The verse before this one, offered as a hint.
        let contextText: String?
        let options: [String]
        var selected: String?
        var outcome: QuizOutcome?
        var contextRevealed = false
    }

    // Replaced by the category quick picks; read once to carry an old choice over.
    @AppStorage("quizScope") private var legacyScope: String = "whole"
    @AppStorage("quizSections") private var quizSectionsRaw: String = ""
    @AppStorage("quizDifficulty") private var difficulty: Difficulty = .normal

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

    // Global Auto‑Win debug toggle
    @AppStorage("debugAutoWinEnabled") private var debugAutoWinEnabled: Bool = false

    @State private var phase: Phase = .setup
    @State private var isFilterReady = QuizVerseFilter.isReady
    @State private var questionBag: [VerseCandidate] = []
    @State private var history: [QuizQuestion] = []
    @State private var currentIndex: Int = -1
    @State private var totalQuestions: Int = 0

    // Scoring
    @State private var score = 0
    @State private var answered = 0
    @State private var sessionStreak = 0
    @State private var sessionBestStreak = 0
    @State private var bestStreak = 0
    @State private var bestGameScore = 0
    @State private var isNewBestGame = false

    // Timer
    @State private var remainingSeconds: Int = 0
    @State private var timerID: Int = 0
    @State private var wasInRedZone: Bool = false
    @State private var pulseOn: Bool = false
    @State private var timerOnLeft: Bool = false
    @State private var usesMutedTimerStyle: Bool = false

    // MARK: - Derived state

    private var persistentStreak: PersistentGameStreak {
        PersistentGameStreak(game: "quiz", variant: difficulty.rawValue)
    }

    private var bestGameScoreKey: String { "quizBestGameScore_\(difficulty.rawValue)" }

    private var selectedSections: Set<VerseSection> {
        Set(quizSectionsRaw.split(separator: ",").compactMap { VerseSection(rawValue: String($0)) })
    }

    /// An empty stored selection means every category.
    private var displayedSelectedSections: Set<VerseSection> {
        selectedSections.isEmpty ? Set(VerseSection.allCases) : selectedSections
    }

    private var poolBookNames: Set<String> {
        Set(displayedSelectedSections.flatMap(\.bookNames))
    }

    private var current: QuizQuestion? {
        history.indices.contains(currentIndex) ? history[currentIndex] : nil
    }

    private var isViewingPrevious: Bool { currentIndex < history.count - 1 }

    private var isAnswered: Bool { current?.outcome != nil }

    private var isTimerRunning: Bool {
        phase == .playing && difficulty.timeLimit != nil && !isViewingPrevious && !isAnswered
    }

    private var canGoPrevious: Bool {
        currentIndex > 0 && (isAnswered || isViewingPrevious || difficulty.timeLimit == nil)
    }

    private var canGoNext: Bool { isViewingPrevious || isAnswered }

    private var isOnLastQuestion: Bool { !isViewingPrevious && history.count >= totalQuestions }

    private var canRevealContext: Bool {
        guard let current, current.contextText != nil, !current.contextRevealed,
              !isAnswered, !isViewingPrevious else { return false }
        return difficulty.timeLimit == nil || remainingSeconds > difficulty.contextCost
    }

    private var progressText: String {
        String(localized: "Question \(currentIndex + 1) of \(totalQuestions)")
    }

    var body: some View {
        GeometryReader { geometry in
            let usesSplitLayout = phase == .playing && geometry.size.width >= 700

            ZStack {
                ScrollView {
                    VStack(spacing: 16) {
                        switch phase {
                        case .setup:
                            setupContent
                        case .playing:
                            if usesSplitLayout {
                                dashboard(availableHeight: geometry.size.height - 32)
                            } else {
                                compactGameContent
                            }
                        case .results:
                            Spacer(minLength: 32)
                            QuizResultsCard(
                                score: score,
                                total: totalQuestions,
                                bestStreak: sessionBestStreak,
                                bestGameScore: bestGameScore,
                                isNewBest: isNewBestGame,
                                onPlayAgain: startQuiz,
                                onChangeSettings: resetToSetup
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal)
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
                    QuizLargeTimerView(
                        remainingSeconds: remainingSeconds,
                        tint: timerColor,
                        isPulsing: pulseOn,
                        isTimed: difficulty.timeLimit != nil,
                        outcome: current?.outcome,
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
        // Restarts with each question so the first second is a full second.
        .task(id: timerID) {
            while !Task.isCancelled, isTimerRunning, remainingSeconds > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, isTimerRunning else { return }
                remainingSeconds -= 1
                if remainingSeconds == 0 {
                    finishQuestion(.timedOut, selected: nil)
                }
            }
        }
        .onChange(of: remainingSeconds) { _, _ in
            guard isTimerRunning else { return }
            let inRed = timerColor == .red
            if inRed && !wasInRedZone {
                startTimerPulse()
            }
            wasInRedZone = inRed
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if phase != .setup {
                    GameNavigationTitle(title: "Bible Quiz", systemImage: "questionmark.circle.fill", tint: .blue)
                }
            }
        }
        .onAppear {
            migrateLegacyScope()
            bestStreak = persistentStreak.best
        }
        // Sort out list and repeated verses while the start screen is showing.
        .task {
            await QuizVerseFilter.prepare()
            isFilterReady = true
        }
        .onChange(of: difficulty) { _, _ in
            bestStreak = persistentStreak.best
        }
        .onDisappear {
            // Leaving after answering begins a new game on return.
            if phase != .setup && answered > 0 {
                resetToSetup()
            }
        }
    }

    // MARK: - Setup

    @ViewBuilder
    private var setupContent: some View {
        Text("Test your knowledge by guessing the book of the Bible from a given verse.")
            .gameStartDescriptionStyle(title: "Bible Quiz", systemImage: "questionmark.circle.fill", tint: .blue)

        GameSplashLaunchLayout(
            tint: .blue,
            experienceLevel: experienceLevel,
            isStartEnabled: isFilterReady,
            startAction: startQuiz
        ) {
            GameLobbyPreview(kind: .quiz)
        } configuration: {
            VStack(alignment: .leading, spacing: 8) {
                QuizCategoryQuickPicks(selection: sectionSelection)

                GameStartMultiPickerCard(
                    title: "Biblical Categories",
                    selection: sectionSelection,
                    options: VerseSection.allCases
                ) { section in
                    Text(section.title)
                }
            }
            .frame(maxWidth: 620)
            .padding(.horizontal)

            if !isFilterReady {
                Label {
                    Text("Preparing verses…")
                } icon: {
                    ProgressView()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            }
        } facts: {
            GameSplashFacts(
                first: ("number", "\(Self.questionsPerGame)", String(localized: "Questions")),
                second: (
                    "timer",
                    difficulty.timeLimit.map { String(localized: "\($0) sec") } ?? String(localized: "No limit"),
                    String(localized: "Per verse")
                ),
                third: (
                    "text.alignleft",
                    difficulty.contextCost == 0 ? String(localized: "Free") : String(localized: "−\(difficulty.contextCost) sec"),
                    String(localized: "Previous verse")
                )
            )
        }
        Spacer(minLength: 48)
    }

    private var sectionSelection: Binding<Set<VerseSection>> {
        Binding(
            get: { displayedSelectedSections },
            set: storeSelectedSections
        )
    }

    private func storeSelectedSections(_ sections: Set<VerseSection>) {
        guard !sections.isEmpty else { return }
        if sections == Set(VerseSection.allCases) {
            quizSectionsRaw = ""
        } else {
            quizSectionsRaw = VerseSection.allCases
                .filter { sections.contains($0) }
                .map(\.rawValue)
                .joined(separator: ",")
        }
    }

    /// The Testament picker was folded into the categories; apply an old choice once.
    private func migrateLegacyScope() {
        guard legacyScope == "old" || legacyScope == "new" else { return }
        let testamentSections = Set(VerseSection.allCases.filter { $0.isOldTestament == (legacyScope == "old") })
        let kept = selectedSections.intersection(testamentSections)
        storeSelectedSections(kept.isEmpty ? testamentSections : kept)
        legacyScope = "whole"
    }

    // MARK: - Gameplay layouts

    private var contextRow: QuizContextRow? {
        guard let current, let contextText = current.contextText else { return nil }
        return QuizContextRow(
            contextText: contextText,
            isRevealed: current.contextRevealed || current.outcome != nil,
            cost: difficulty.contextCost,
            canReveal: canRevealContext,
            onReveal: revealContext
        )
    }

    @ViewBuilder
    private var answerReveal: some View {
        if let current, let outcome = current.outcome {
            QuizAnswerReveal(
                outcome: outcome,
                bookName: current.correctBook,
                chapterNumber: current.chapter,
                verseNumber: current.verse,
                verseText: current.verseText
            )
        }
    }

    private var navigationButtons: some View {
        QuizNavigationButtons(
            canGoPrevious: canGoPrevious,
            canGoNext: canGoNext,
            isLastQuestion: isOnLastQuestion,
            onPrevious: showPrevious,
            onNext: showNext
        )
    }

    @ViewBuilder
    private var compactGameContent: some View {
        if let current {
            VStack(spacing: 16) {
                GameScoreboardCard(
                    currentCorrect: score,
                    currentAnswered: answered,
                    currentStreak: sessionStreak,
                    game: .quiz
                )

                // Verse card
                VStack(alignment: .leading, spacing: 12) {
                    Text(progressText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text("“\(current.verseText)”")
                        .italic()
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)

                    contextRow
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(UIColor.secondarySystemBackground), Color(UIColor.systemBackground)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            isTimerRunning ? timerColor : Color.primary.opacity(0.12),
                            lineWidth: isTimerRunning ? 2 : 1
                        )
                )
                .animation(.easeInOut(duration: 0.25), value: remainingSeconds)
                .padding(.horizontal)

                if isTimerRunning {
                    GameTimerCard(
                        remainingSeconds: remainingSeconds,
                        tint: timerColor,
                        isPulsing: pulseOn
                    )
                    .padding(.horizontal)
                }

                if !isAnswered {
                    Text("Which book is this from?")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(current.options, id: \.self) { option in
                        Button {
                            selectOption(option)
                        } label: {
                            Text(option)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .foregroundStyle(.primary)
                        }
                        .disabled(isAnswered || isViewingPrevious)
                        .background(buttonBackground(for: option, in: current))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(
                                    isAnswered && option == current.correctBook ? Color.green : Color.black.opacity(0.15),
                                    lineWidth: isAnswered && option == current.correctBook ? 3 : 1
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .font(.body)
                    }
                }
                .padding(.horizontal)

                if isAnswered {
                    answerReveal
                        .padding(.horizontal)

                    navigationButtons
                        .padding(.horizontal)
                }

                // DEBUG: WIN button
                if debugAutoWinEnabled, !isAnswered, !isViewingPrevious {
                    Button("WIN") {
                        selectOption(current.correctBook)
                    }
                    .buttonStyle(ModernPillButtonStyle(tint: .red))
                    .controlSize(.large)
                    .padding(.top, 4)
                    .accessibilityLabel("Win this round")
                }
            }
            .padding(.vertical)
        }
    }

    @ViewBuilder
    private func dashboard(availableHeight: CGFloat) -> some View {
        if let current {
            VStack(spacing: 18) {
                GameScoreboardCard(
                    currentCorrect: score,
                    currentAnswered: answered,
                    currentStreak: sessionStreak,
                    game: .quiz,
                    style: .dashboard
                )

                QuizDashboardQuestion(
                    progressText: progressText,
                    verseText: current.verseText,
                    contextRow: contextRow,
                    options: current.options,
                    selectedOption: current.selected,
                    correctBookName: current.correctBook,
                    isAnswered: isAnswered,
                    isViewingPrevious: isViewingPrevious,
                    onSelectOption: selectOption
                )

                answerReveal

                Spacer(minLength: 0)

                if debugAutoWinEnabled && !isAnswered && !isViewingPrevious {
                    Button("Win", systemImage: "checkmark.seal.fill") {
                        selectOption(current.correctBook)
                    }
                    .buttonStyle(GameProminentButtonStyle(tint: .red))
                } else {
                    navigationButtons
                }
            }
            .padding(AppDesignMetrics.cardPadding)
            .padding(.top, 12)
            .frame(maxWidth: .infinity, minHeight: availableHeight, alignment: .top)
        }
    }

    // MARK: - Questions

    private func buildQuestionBag() -> [VerseCandidate] {
        let pool = poolBookNames
        let difficultyKey = difficulty.rawValue
        return BibleData.books
            .filter { pool.contains($0.name) }
            .flatMap { book in
                book.chapters.flatMap { chapter in
                    chapter.verses.indices.compactMap { index -> VerseCandidate? in
                        let verse = chapter.verses[index]
                        guard QuizVerseFilter.isQuizzable(
                            book: book.name,
                            chapter: chapter.number,
                            verse: verse.number,
                            difficulty: difficultyKey
                        ) else { return nil }
                        return VerseCandidate(
                            text: verse.text,
                            bookName: book.name,
                            chapter: chapter.number,
                            verse: verse.number,
                            contextText: index > 0 ? chapter.verses[index - 1].text : nil
                        )
                    }
                }
            }
            .shuffled()
    }

    /// Picks three wrong books, drawing from each list in turn until there are enough.
    private func wrongChoices(for correctBook: String) -> [String] {
        let canon = BibleCanon.fallbackCanon
        let pool = poolBookNames
        let section = VerseSection.containing(correctBook)
        let isOld = section?.isOldTestament ?? true
        let sameTestament = canon.filter { VerseSection.containing($0)?.isOldTestament == isOld }

        let tiers: [[String]]
        switch difficulty {
        case .easy:
            let otherSections = canon.filter { VerseSection.containing($0) != section }
            tiers = [otherSections.filter(pool.contains), otherSections]
        case .normal:
            tiers = [canon.filter(pool.contains), sameTestament, canon]
        case .hard:
            let family = Set((section?.hardFamily ?? []).flatMap(\.bookNames))
            tiers = [
                canon.filter { family.contains($0) && pool.contains($0) },
                canon.filter(family.contains),
                sameTestament
            ]
        }

        var picks: [String] = []
        for tier in tiers {
            for name in tier.shuffled() where picks.count < 3 && name != correctBook && !picks.contains(name) {
                picks.append(name)
            }
        }
        return picks
    }

    private func makeQuestion() -> QuizQuestion? {
        guard let candidate = questionBag.popLast() else { return nil }
        return QuizQuestion(
            verseText: candidate.text,
            correctBook: candidate.bookName,
            chapter: candidate.chapter,
            verse: candidate.verse,
            contextText: candidate.contextText,
            options: (wrongChoices(for: candidate.bookName) + [candidate.bookName]).shuffled()
        )
    }

    // MARK: - Game flow

    private func startQuiz() {
        guard isFilterReady else { return }
        questionBag = buildQuestionBag()
        guard !questionBag.isEmpty else { return }
        totalQuestions = min(Self.questionsPerGame, questionBag.count)
        history = []
        currentIndex = -1
        score = 0
        answered = 0
        sessionStreak = 0
        sessionBestStreak = 0
        isNewBestGame = false
        bestStreak = persistentStreak.best
        phase = .playing
        appendNextQuestion()
    }

    private func appendNextQuestion() {
        guard let question = makeQuestion() else {
            showResults()
            return
        }
        history.append(question)
        currentIndex = history.count - 1
        remainingSeconds = difficulty.timeLimit ?? 0
        wasInRedZone = false
        pulseOn = false
        timerID += 1
    }

    private func showResults() {
        let previousBest = UserDefaults.standard.integer(forKey: bestGameScoreKey)
        isNewBestGame = score > previousBest
        bestGameScore = max(previousBest, score)
        if isNewBestGame {
            UserDefaults.standard.set(score, forKey: bestGameScoreKey)
        }
        phase = .results
    }

    private func resetToSetup() {
        phase = .setup
        history = []
        currentIndex = -1
        questionBag = []
        remainingSeconds = 0
        score = 0
        answered = 0
        sessionStreak = 0
    }

    private func showPrevious() {
        guard canGoPrevious else { return }
        currentIndex -= 1
    }

    private func showNext() {
        if isViewingPrevious {
            currentIndex += 1
        } else if history.count >= totalQuestions {
            showResults()
        } else {
            appendNextQuestion()
        }
    }

    private func revealContext() {
        guard canRevealContext else { return }
        history[currentIndex].contextRevealed = true
        remainingSeconds -= difficulty.contextCost
    }

    private func selectOption(_ name: String) {
        guard let current else { return }
        finishQuestion(name == current.correctBook ? .correct : .incorrect, selected: name)
    }

    /// Records the answer (or timeout) on the latest question, so it can't be answered again.
    private func finishQuestion(_ outcome: QuizOutcome, selected: String?) {
        guard phase == .playing, !isViewingPrevious, let current, current.outcome == nil else { return }
        history[currentIndex].outcome = outcome
        history[currentIndex].selected = selected
        pulseOn = false
        answered += 1

        let correct = outcome == .correct
        if correct {
            score += 1
            sessionStreak += 1
            sessionBestStreak = max(sessionBestStreak, sessionStreak)
            // Persistent streak: extend on correct
            let streak = persistentStreak.recordWin()
            bestStreak = max(bestStreak, streak.best)
        } else {
            // Persistent streak: reset on incorrect or timeout
            sessionStreak = 0
            persistentStreak.reset()
        }

        GameStats.shared.recordRound(
            game: .quiz,
            difficulty: difficulty.statsDifficulty,
            correct: correct ? 1 : 0,
            answered: 1,
            currentBestStreak: bestStreak
        )
        GameStats.shared.recordQuizPerBook(bookName: current.correctBook, answered: 1, correct: correct ? 1 : 0)

        #if canImport(UIKit)
        switch outcome {
        case .correct: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .incorrect: UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .timedOut: UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        #endif
    }

    // MARK: - UI helpers

    private func buttonBackground(for option: String, in question: QuizQuestion) -> Color {
        guard question.outcome != nil, question.selected == option else { return .clear }
        return option == question.correctBook ? Color.green.opacity(0.3) : Color.red.opacity(0.3)
    }

    /// Green, then yellow, then red as the question runs down, scaled to the time limit.
    private var timerColor: Color {
        guard let timeLimit = difficulty.timeLimit else { return .secondary }
        let fraction = Double(remainingSeconds) / Double(max(1, timeLimit))
        if fraction <= 0.3 { return .red }
        if fraction <= 0.6 { return .yellow }
        return .green
    }

    private func startTimerPulse() {
        let pulses = 3
        for i in 0..<(pulses * 2) {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.25) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.pulseOn.toggle()
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(pulses * 2) * 0.25 + 0.01) {
            self.pulseOn = false
        }
    }
}

private enum QuizOutcome {
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

// MARK: - Setup views

/// One-tap shortcuts for the whole Bible or one Testament. Also used by Verse Match.
struct QuizCategoryQuickPicks: View {
    @Binding var selection: Set<QuizView.VerseSection>

    private var oldTestament: Set<QuizView.VerseSection> {
        Set(QuizView.VerseSection.allCases.filter(\.isOldTestament))
    }

    private var newTestament: Set<QuizView.VerseSection> {
        Set(QuizView.VerseSection.allCases.filter { !$0.isOldTestament })
    }

    var body: some View {
        HStack(spacing: 8) {
            pick("Whole Bible", sections: Set(QuizView.VerseSection.allCases))
            pick("Old Testament", sections: oldTestament)
            pick("New Testament", sections: newTestament)
        }
    }

    private func pick(_ title: LocalizedStringKey, sections: Set<QuizView.VerseSection>) -> some View {
        let isSelected = selection == sections
        return Button {
            selection = sections
        } label: {
            Text(title)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(isSelected ? .accentColor : .secondary)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Gameplay views

private struct QuizContextRow: View {
    let contextText: String
    let isRevealed: Bool
    let cost: Int
    let canReveal: Bool
    let onReveal: () -> Void

    var body: some View {
        if isRevealed {
            VStack(alignment: .leading, spacing: 4) {
                Text("Previous verse")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(contextText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Button(action: onReveal) {
                Label {
                    if cost > 0 {
                        Text("Show previous verse (−\(cost) sec)")
                    } else {
                        Text("Show previous verse")
                    }
                } icon: {
                    Image(systemName: "text.alignleft")
                }
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.borderless)
            .disabled(!canReveal)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct QuizAnswerReveal: View {
    let outcome: QuizOutcome
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
    let verseText: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: outcome.systemImage)
                .font(.title2.weight(.bold))
                .foregroundStyle(outcome.tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(outcome.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(outcome.tint)

                Text("\(bookName) \(chapterNumber):\(verseNumber)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 8)

            VerseActionMenu(
                verse: VerseActionReference(
                    bookName: bookName,
                    chapterNumber: chapterNumber,
                    verseNumber: verseNumber,
                    verseText: verseText
                )
            )
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 64)
        .glassEffect(.regular.tint(outcome.tint.opacity(0.35)), in: .rect(cornerRadius: AppDesignMetrics.compactControlCornerRadius))
        .accessibilityElement(children: .combine)
    }
}

private struct QuizNavigationButtons: View {
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
                    .buttonStyle(GameProminentButtonStyle(tint: .blue))
                    .disabled(!canGoNext)
            } else {
                Button("Next", systemImage: "arrow.right", action: onNext)
                    .buttonStyle(GameProminentButtonStyle(tint: .accentColor))
                    .disabled(!canGoNext)
            }
        }
    }
}

private struct QuizDashboardQuestion: View {
    let progressText: String
    let verseText: String
    let contextRow: QuizContextRow?
    let options: [String]
    let selectedOption: String?
    let correctBookName: String
    let isAnswered: Bool
    let isViewingPrevious: Bool
    let onSelectOption: (String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                HStack {
                    Label("Which book is this from?", systemImage: "text.book.closed.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tint)

                    Spacer()

                    Text(progressText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Text("“\(verseText)”")
                    .italic()
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                contextRow
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(options, id: \.self) { option in
                    Button {
                        onSelectOption(option)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: optionIcon(for: option))
                            Text(option)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                    }
                    .buttonStyle(.glass(optionGlass(for: option)))
                    .disabled(isAnswered || isViewingPrevious)
                }
            }
        }
    }

    private func optionGlass(for option: String) -> Glass {
        guard isAnswered else { return .clear }
        if option == correctBookName { return .regular.tint(.green.opacity(0.28)) }
        if option == selectedOption { return .regular.tint(.red.opacity(0.28)) }
        return .clear
    }

    private func optionIcon(for option: String) -> String {
        guard isAnswered else { return "book.closed.fill" }
        if option == correctBookName { return "checkmark.circle.fill" }
        if option == selectedOption { return "xmark.circle.fill" }
        return "book.closed.fill"
    }
}

private struct QuizResultsCard: View {
    let score: Int
    let total: Int
    let bestStreak: Int
    let bestGameScore: Int
    let isNewBest: Bool
    let onPlayAgain: () -> Void
    let onChangeSettings: () -> Void

    private var accuracy: Int {
        guard total > 0 else { return 0 }
        return Int((Double(score) / Double(total) * 100).rounded())
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isNewBest ? "trophy.fill" : "flag.checkered")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(isNewBest ? Color.yellow : Color.blue)

            VStack(spacing: 6) {
                Text(isNewBest ? "New Best Game!" : "Game Over")
                    .font(.title.weight(.bold))

                Text("\(score) of \(total) correct")
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            GameSplashFacts(
                first: ("percent", "\(accuracy)%", String(localized: "Accuracy")),
                second: ("flame.fill", "\(bestStreak)", String(localized: "Best streak")),
                third: ("trophy", "\(bestGameScore)/\(total)", String(localized: "Best game"))
            )

            VStack(spacing: 10) {
                Button("Play Again", systemImage: "arrow.clockwise", action: onPlayAgain)
                    .buttonStyle(GameProminentButtonStyle(tint: .blue))

                Button("Change Settings", systemImage: "slider.horizontal.3", action: onChangeSettings)
                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
            }
        }
        .padding(24)
        .frame(maxWidth: 520)
        .heroCardSurface()
    }
}

private struct QuizLargeTimerView: View {
    let remainingSeconds: Int
    let tint: Color
    let isPulsing: Bool
    let isTimed: Bool
    let outcome: QuizOutcome?
    @Binding var usesMutedStyle: Bool
    let onSwapSides: () -> Void

    private var isActive: Bool {
        isTimed && outcome == nil
    }

    private var displayTint: Color {
        outcome?.tint ?? tint
    }

    private var vividTextColor: Color {
        isActive && tint == .yellow ? .black : .white
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            VStack(spacing: 24) {
                Image(systemName: statusSystemImage)
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(usesMutedStyle ? displayTint : vividTextColor.opacity(0.85))

                Text(statusTitle)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(usesMutedStyle ? displayTint : vividTextColor.opacity(0.85))

                if outcome == nil {
                    Text(isTimed ? "\(remainingSeconds)s" : "∞")
                        .font(.largeTitle.weight(.bold))
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .foregroundStyle(usesMutedStyle ? displayTint : vividTextColor)
                }
            }
            .scaleEffect(isPulsing ? 1.04 : 1)
            .animation(.easeOut(duration: 0.18), value: isPulsing)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(statusTitle)
            .accessibilityValue(isActive ? "\(remainingSeconds) seconds" : outcome == nil ? "No time limit" : "")

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

    private var statusTitle: LocalizedStringKey {
        if let outcome { return outcome.title }
        return isTimed ? "Time Remaining" : "Untimed Mode"
    }

    private var statusSystemImage: String {
        if let outcome { return outcome.systemImage }
        return isTimed ? "timer" : "infinity"
    }
}

#Preview {
    NavigationStack {
        QuizView()
    }
}
