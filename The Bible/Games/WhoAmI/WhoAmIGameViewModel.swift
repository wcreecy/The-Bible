import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class WhoAmIGameViewModel {
    enum Mode: String, CaseIterable, Identifiable {
        case clueToName     // prompt: clue -> choices: names
        case nameToClue     // prompt: name -> choices: clues

        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .clueToName: "Clue → Name"
            case .nameToClue: "Name → Clue"
            }
        }

        var detail: LocalizedStringResource {
            switch self {
            case .clueToName: "Read a clue and pick the person it describes."
            case .nameToClue: "See a name and pick the clue that describes them."
            }
        }

        var icon: String {
            switch self {
            case .clueToName: "text.quote"
            case .nameToClue: "person.fill"
            }
        }
    }

    enum Difficulty: String, CaseIterable, Identifiable {
        case easy, normal, hard
        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .easy: "Easy"
            case .normal: "Normal"
            case .hard: "Hard"
            }
        }

        var timeLimit: Int {
            switch self {
            case .easy: return 0
            case .normal: return 30
            case .hard: return 15
            }
        }

        var detail: LocalizedStringResource {
            switch self {
            case .easy: "Well-known people, no timer, and curated choices."
            case .normal: "Adds less familiar people. 30 seconds and curated choices."
            case .hard: "Everyone in the game. 15 seconds and curated choices."
            }
        }

        var statsDifficulty: GameStats.Difficulty {
            switch self {
            case .easy: return .easy
            case .normal: return .normal
            case .hard: return .hard
            }
        }
    }

    struct Entry: Hashable {
        /// The person's ID. Each person has one question in each direction.
        let id: Int
        /// The question's own ID, e.g. "who-person-001", used for missed-question review.
        var questionID: String = ""
        let questionMode: WhoGameQuestion.Mode
        /// The name without the description in parentheses, e.g. "Joseph".
        let name: String
        /// The description in parentheses in the data, e.g. "son of Jacob". Shown only in the reveal.
        let qualifier: String?
        let clue: String
        let books: [String]
        let difficulty: String
        let incorrectAnswers: [String]
        /// Where the person appears, e.g. "Exodus 4:14–16; 28:1", for the verse after answering.
        var reference: String = ""

        func matchesDifficulty(_ selectedDifficulty: Difficulty) -> Bool {
            switch difficulty.lowercased() {
            case "easy": true
            case "medium", "normal": selectedDifficulty != .easy
            default: selectedDifficulty == .hard
            }
        }
    }

    static let questionsPerGame = 10
    /// Seconds the hint costs on a timed difficulty.
    static let hintCost = 5

    private let reviewQuestionIDs: Set<String>
    /// Where missed questions are recorded; tests pass a store that never touches disk or iCloud.
    private let missedQuestions: MissedGameQuestionStore
    /// Waits between timer ticks; tests pass a manual clock.
    @ObservationIgnored private let sleep: (Duration) async throws -> Void
    /// The current time for the question clock; tests pass the manual clock's time.
    @ObservationIgnored private let now: () -> Date
    /// Loads the verses a person's reference points to; tests pass a fixed passage.
    @ObservationIgnored private let loadPassageForReference: (String) async -> GamePassage?

    /// The stores, clock and Bible text default to the real ones. They're resolved here rather
    /// than as default arguments, which would be evaluated outside the main actor.
    init(
        reviewQuestionIDs: Set<String> = [],
        missedQuestions: MissedGameQuestionStore? = nil,
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        now: @escaping () -> Date = Date.init,
        loadPassage: ((String) async -> GamePassage?)? = nil
    ) {
        self.reviewQuestionIDs = reviewQuestionIDs
        self.missedQuestions = missedQuestions ?? .shared
        self.sleep = sleep
        self.now = now
        self.loadPassageForReference = loadPassage ?? { await GamePassage.load(for: $0) }
    }

    // Start screen state
    var started: Bool = false
    var isComplete: Bool = false
    var mode: Mode = Mode(rawValue: UserDefaults.standard.string(forKey: AppStorageKey.whoAmIMode) ?? "") ?? .clueToName {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: AppStorageKey.whoAmIMode) }
    }
    var difficulty: Difficulty = Difficulty(rawValue: UserDefaults.standard.string(forKey: AppStorageKey.whoAmIDifficulty) ?? "") ?? .normal {
        didSet {
            UserDefaults.standard.set(difficulty.rawValue, forKey: AppStorageKey.whoAmIDifficulty)
            session.syncSavedBest(from: persistentStreak)
        }
    }

    // Data
    private(set) var entries: [Entry] = []
    private var questionQueue: [Entry] = []

    private var eligibleEntries: [Entry] {
        entries.filter {
            $0.questionMode == questionMode && $0.matchesDifficulty(difficulty)
        }
    }

    /// A review needs a full game's worth of missed questions, like every game's Review Round.
    var isReady: Bool {
        reviewQuestionIDs.isEmpty ? eligibleEntries.count >= 4 : reviewEntries.count >= MissedGameQuestionStore.reviewRoundSize
    }

    /// The missed questions. Misses saved before questions had their own IDs hold only the
    /// person's ID, so for those both of the person's questions come back.
    private var reviewEntries: [Entry] {
        entries.filter { reviewQuestionIDs.contains($0.questionID) || reviewQuestionIDs.contains(Self.legacyReviewID(for: $0)) }
    }

    /// The ID misses were saved under before each question had its own: the person's ID.
    private static func legacyReviewID(for entry: Entry) -> String {
        String(describing: entry.id)
    }

    // Current round
    private(set) var current: Entry?
    private(set) var choiceEntries: [String] = []
    var selectedChoice: String? = nil
    private(set) var questionNumber: Int = 0
    private(set) var totalQuestions: Int = 0
    /// A wrong clue taken away by the Name → Clue hint.
    private(set) var removedChoices: Set<String> = []

    var promptTitle: String {
        guard let current else { return "" }
        return mode(for: current) == .clueToName ? current.clue : current.name
    }

    var choices: [String] {
        choiceEntries
    }

    var correctChoice: String {
        guard let current else { return "" }
        return mode(for: current) == .clueToName ? current.name : current.clue
    }

    /// A review can contain misses from both directions, so it uses each entry's source mode.
    var currentPromptIsName: Bool {
        guard let current else { return mode == .nameToClue }
        return mode(for: current) == .nameToClue
    }

    var isLastQuestion: Bool { questionQueue.isEmpty }

    // Timer
    private(set) var remainingSeconds: Int = 0
    private(set) var isTimerDisabled = false
    /// True while the question is paused: the timer stops and the question is hidden.
    private(set) var isPaused = false
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var pulseTask: Task<Void, Never>?
    /// Time spent on the current question. It's the authority for the countdown, so pausing
    /// and resuming can't give back part of a second.
    @ObservationIgnored private var questionClock = GameActiveClock()
    /// Seconds taken off the question for the hint.
    private var penaltySeconds = 0
    /// The timer was off at some point this question, so it can't earn a speed bonus.
    private var wasTimerOffThisQuestion = false
    /// Flashes the timer in the last five seconds; the timer views animate the change.
    private(set) var pulseOn: Bool = false

    /// Score, streaks and best game; see `GameScore` for the rules.
    private(set) var session = GameScore()

    var roundOver: Bool = false
    var wasTimedOut: Bool = false
    private(set) var hintUsed = false
    private(set) var timeoutCount = 0
    private(set) var correctTimeRemaining: [Int] = []
    private(set) var earnedSpeedBonus = false
    private(set) var speedBonusCount = 0
    /// The verses the current person's reference points to, once loaded.
    private(set) var passage: GamePassage?

    // MARK: - Persistent streak (per difficulty)
    private var persistentStreak: PersistentGameStreak {
        PersistentGameStreak(game: "whoami", variant: difficulty.rawValue)
    }

    private var bestGameScoreKey: String { "whoamiBestGameScore_\(difficulty.rawValue)" }
    /// Each mode and difficulty has its own pool, so each keeps its own pass through the questions.
    private var recencyGameKey: String { "whoAmI.\(mode.rawValue).\(difficulty.rawValue)" }

    var isTimed: Bool { difficulty.timeLimit > 0 }

    // Load data
    func onAppear() {
        session.syncSavedBest(from: persistentStreak)
        Task { await loadData() }
    }

    /// Loads the people and their questions, once.
    func loadData() async {
        guard entries.isEmpty else { return }
        async let characters = GameDataLoaders.loadCharactersAsync()
        async let questions = GameDataLoaders.loadWhoQuestionsAsync()
        let charactersByID = Dictionary(
            uniqueKeysWithValues: await characters.map { ($0.id, $0) }
        )
        let loaded = await questions.compactMap { question -> Entry? in
            guard let character = charactersByID[question.sourcePersonID] else { return nil }

            let nameAndClue: (name: String, clue: String)
            switch question.mode {
            case .factToPerson:
                nameAndClue = (question.correctAnswer, question.question)
            case .personToFact:
                nameAndClue = (question.question, question.correctAnswer)
            }

            let parts = Self.split(nameAndClue.name)
            let clue = nameAndClue.clue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !parts.name.isEmpty, !clue.isEmpty, question.incorrectAnswers.count >= 3 else {
                return nil
            }

            return Entry(
                id: question.sourcePersonID,
                questionID: question.id,
                questionMode: question.mode,
                name: parts.name,
                qualifier: parts.qualifier,
                clue: clue,
                books: character.books,
                difficulty: question.difficulty,
                incorrectAnswers: question.incorrectAnswers,
                reference: question.reference
            )
        }
        guard entries.isEmpty else { return }
        entries = loaded
    }

    private var questionMode: WhoGameQuestion.Mode {
        switch mode {
        case .clueToName: .factToPerson
        case .nameToClue: .personToFact
        }
    }

    private func mode(for entry: Entry) -> Mode {
        guard !reviewQuestionIDs.isEmpty else { return mode }
        switch entry.questionMode {
        case .factToPerson: return .clueToName
        case .personToFact: return .nameToClue
        }
    }

    private func rankedDistractors(for target: Entry) -> [String] {
        guard difficulty == .hard, mode(for: target) == .clueToName else {
            return target.incorrectAnswers.shuffled()
        }

        return target.incorrectAnswers.shuffled().sorted { lhs, rhs in
            let lhsBooks = entries.first { $0.name.caseInsensitiveCompare(lhs) == .orderedSame }?.books ?? []
            let rhsBooks = entries.first { $0.name.caseInsensitiveCompare(rhs) == .orderedSame }?.books ?? []
            let lhsScore = Set(lhsBooks).intersection(target.books).count
            let rhsScore = Set(rhsBooks).intersection(target.books).count
            return lhsScore > rhsScore
        }
    }

    /// Removes a trailing description in parentheses: "Joseph (son of Jacob)" → ("Joseph", "son of Jacob").
    private static func split(_ name: String) -> (name: String, qualifier: String?) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let open = trimmed.firstIndex(of: "("), trimmed.hasSuffix(")") else { return (trimmed, nil) }
        let base = trimmed[..<open].trimmingCharacters(in: .whitespaces)
        let qualifier = trimmed[trimmed.index(after: open)..<trimmed.index(before: trimmed.endIndex)]
            .trimmingCharacters(in: .whitespaces)
        return (base.isEmpty ? trimmed : base, qualifier.isEmpty ? nil : qualifier)
    }

    // MARK: - Game flow

    func startGame() {
        guard isReady else { return }
        session.beginGame(savedStreak: persistentStreak, isTimed: isTimed)
        let candidates = reviewQuestionIDs.isEmpty
            ? RecentGameQuestionStore.shared.selectCycling(
                from: eligibleEntries,
                game: recencyGameKey,
                count: Self.questionsPerGame,
                id: { String($0.id) }
            )
            : Array(reviewEntries.shuffled().prefix(Self.questionsPerGame))
        questionQueue = candidates
        totalQuestions = questionQueue.count
        questionNumber = 0
        timeoutCount = 0
        correctTimeRemaining = []
        speedBonusCount = 0
        isComplete = false
        isTimerDisabled = false
        started = true
        nextRound()
    }

    /// Moves to the next question, or to the results once all are answered.
    func nextRound() {
        stopTimer()
        guard !questionQueue.isEmpty else {
            finishGame()
            return
        }

        let target = questionQueue.removeFirst()
        current = target
        RecentGameQuestionStore.shared.record(target, game: recencyGameKey, id: { String($0.id) })
        let correct = mode(for: target) == .clueToName ? target.name : target.clue
        choiceEntries = (Array(rankedDistractors(for: target).prefix(3)) + [correct]).shuffled()
        questionNumber += 1
        selectedChoice = nil
        removedChoices = []
        roundOver = false
        wasTimedOut = false
        hintUsed = false
        earnedSpeedBonus = false
        passage = nil
        isPaused = false
        penaltySeconds = 0
        session.startQuestion()

        remainingSeconds = difficulty.timeLimit
        questionClock.start(at: now())
        // With the timer off, the clock waits too, so turning it back on doesn't count the
        // time spent with it off.
        wasTimerOffThisQuestion = isTimerDisabled
        if isTimerDisabled {
            questionClock.pause(at: now())
        }
        startTimer()
    }

    func select(_ choice: String) {
        guard !roundOver, !isPaused, choices.contains(choice), !removedChoices.contains(choice) else { return }
        selectedChoice = choice
        finishRound(correct: choice == correctChoice)
    }

    private func timeOut() {
        guard !roundOver else { return }
        wasTimedOut = true
        timeoutCount += 1
        finishRound(correct: false)
    }

    private func finishRound(correct: Bool) {
        questionClock.pause(at: now())
        stopTimer()
        roundOver = true
        if correct, isTimed, !isTimerDisabled {
            correctTimeRemaining.append(remainingSeconds)
        }
        // A quick answer with the timer on the whole question earns a bonus point.
        if correct, isTimed, !wasTimerOffThisQuestion,
           questionClock.elapsed(at: now()) <= Double(difficulty.timeLimit) / 3 {
            earnedSpeedBonus = true
            speedBonusCount += 1
        }
        if let current {
            session.record(
                GameRoundEntry(
                    prompt: promptTitle,
                    outcome: correct ? .correct : (wasTimedOut ? .timedOut : .wrong),
                    givenAnswer: wasTimedOut ? nil : selectedChoice,
                    correctAnswer: correctChoice,
                    category: String(localized: mode(for: current).title),
                    reference: current.reference.isEmpty ? nil : current.reference,
                    hintCount: hintUsed ? 1 : 0,
                    relatedBookNames: current.books
                ),
                savedStreak: persistentStreak
            )
        } else {
            session.record(correct: correct, savedStreak: persistentStreak)
        }

        GameStats.shared.recordRound(
            game: .whoami,
            difficulty: difficulty.statsDifficulty,
            correct: correct ? 1 : 0,
            answered: 1,
            currentBestStreak: session.savedBestStreak
        )
        if correct, !reviewQuestionIDs.isEmpty, let current {
            missedQuestions.resolveReviewQuestion(game: .whoAmI, questionID: current.questionID)
            // An older miss saved under the person's ID is cleared by either of their questions.
            let legacyID = Self.legacyReviewID(for: current)
            if reviewQuestionIDs.contains(legacyID) {
                missedQuestions.resolveReviewQuestion(game: .whoAmI, questionID: legacyID)
            }
        } else if !correct, let current {
            missedQuestions.record(
                game: .whoAmI,
                bookNames: current.books,
                topic: "Bible people",
                questionID: current.questionID
            )
        }
        if correct { Haptics.success() } else { Haptics.error() }
    }

    private func finishGame() {
        session.finishGame(bestScoreKey: bestGameScoreKey)
        current = nil
        isComplete = true
    }

    /// Back to the start screen, e.g. from the results or when leaving mid-game.
    func returnToSetup() {
        stopTimer()
        questionClock.pause(at: now())
        isPaused = false
        questionQueue = []
        current = nil
        choiceEntries = []
        selectedChoice = nil
        removedChoices = []
        remainingSeconds = 0
        roundOver = false
        isComplete = false
        started = false
        session.clearGame()
    }

    func endRoundWhenLeavingScreen() {
        // Leaving a timed question counts as running out of time, so backing out can't skip a
        // hard question and keep the streak. Easy has no timer, so leaving it costs nothing.
        if started, !isComplete, isTimed, current != nil, !roundOver {
            timeOut()
        }
        // Leaving after answering begins a new game on return.
        if started, session.answered > 0 {
            returnToSetup()
        }
        session.clearStreak()
    }

    // MARK: - Points

    /// Correct answers plus speed bonuses.
    var points: Int { session.score + speedBonusCount }

    /// How the points add up, for the summary. Nil when there were no bonuses.
    var bonusNote: String? {
        guard speedBonusCount > 0 else { return nil }
        let bonuses = speedBonusCount == 1
            ? String(localized: "1 speed bonus")
            : String(localized: "\(speedBonusCount) speed bonuses")
        return String(localized: "\(session.score) correct + \(bonuses) = \(points) points")
    }

    // MARK: - Hint

    var canUseHint: Bool {
        guard difficulty != .easy, !hintUsed, !roundOver, !isPaused, current != nil else { return false }
        // The hint costs time, so it can't be the thing that runs the clock out.
        return isTimerDisabled || remainingSeconds > Self.hintCost
    }

    /// Clue → Name tells you where the person appears. Name → Clue already names them, so
    /// the hint takes away a wrong clue instead.
    var hintTitle: LocalizedStringKey {
        currentPromptIsName
            ? "Remove a wrong clue (−\(Self.hintCost) sec)"
            : "Where do they appear? (−\(Self.hintCost) sec)"
    }

    var hintText: String? {
        guard let current, hintUsed, !currentPromptIsName else { return nil }
        if !current.books.isEmpty {
            return String(localized: "Appears in \(current.books.prefix(2).formatted())")
        }
        return current.qualifier
    }

    func useHint() {
        guard canUseHint, let current else { return }
        hintUsed = true
        if mode(for: current) == .nameToClue,
           let wrong = choiceEntries.filter({ $0 != correctChoice }).randomElement() {
            removedChoices = [wrong]
        }
        if !isTimerDisabled {
            penaltySeconds += Self.hintCost
            updateRemainingTime()
        }
        Haptics.selection()
    }

    // MARK: - Verse

    /// Loads the verses where the current person appears, ready for after answering.
    func loadPassage() async {
        guard let current, !current.reference.isEmpty, passage == nil else { return }
        let loaded = await loadPassageForReference(current.reference)
        // The player may have moved on while the Bible loaded.
        guard self.current == current else { return }
        passage = loaded
    }

    /// The person's verses, once the question is over.
    var displayedVerse: GameVerse? {
        guard roundOver, let passage else { return nil }
        return GameVerse(text: passage.text, reference: passage.title, isClue: false)
    }

    // MARK: - Pausing

    /// Only a question with its timer running can be paused. With "Timer Off" (or on an
    /// untimed difficulty) the question stays on screen, so there's nothing to pause.
    var canPause: Bool {
        started && !isComplete && current != nil && !roundOver
            && isTimed && !isTimerDisabled && !isPaused
    }

    /// Stops the clock and hides the question until `resume()`.
    func pause() {
        guard canPause else { return }
        isPaused = true
        questionClock.pause(at: now())
        stopTimer()
    }

    /// Carries on from the time already used.
    func resume() {
        guard isPaused else { return }
        isPaused = false
        questionClock.resume(at: now())
        startTimer()
    }

    // MARK: - Timer

    private func updateRemainingTime() {
        guard isTimed else { return }
        let remaining = max(0, difficulty.timeLimit - penaltySeconds - Int(questionClock.elapsed(at: now())))
        guard remaining != remainingSeconds else { return }
        remainingSeconds = remaining
        if remainingSeconds == 0 {
            timeOut()
        } else if remainingSeconds <= 5 {
            pulse()
        }
    }

    /// Updates the countdown from the question clock. The clock is the authority, so pausing and
    /// resuming can't give back part of a second; the short interval only keeps the display current.
    private func startTimer() {
        stopTimer()
        guard isTimed, !isTimerDisabled, !isPaused, !roundOver else { return }
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await self?.sleep(.milliseconds(100))
                guard let self, !Task.isCancelled, !self.roundOver, !self.isPaused, !self.isTimerDisabled else { return }
                self.updateRemainingTime()
            }
        }
    }

    private func pulse() {
        pulseOn = true
        pulseTask?.cancel()
        pulseTask = Task { [weak self] in
            try? await self?.sleep(.milliseconds(250))
            guard !Task.isCancelled else { return }
            self?.pulseOn = false
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
        pulseTask?.cancel()
        pulseOn = false
    }

    func toggleTimer() {
        guard isTimed, !roundOver else { return }
        isTimerDisabled.toggle()
        if isTimerDisabled {
            session.noteTimerTurnedOff()
            questionClock.pause(at: now())
            wasTimerOffThisQuestion = true
            stopTimer()
        } else {
            questionClock.resume(at: now())
            startTimer()
        }
    }
}
