import Foundation
import Observation
import SwiftUI

enum BeatTheClockDifficulty: String, CaseIterable, Identifiable {
    case easy
    case normal
    case hard

    /// Seconds a clue costs on Normal and Hard.
    static let hintCost = 3
    /// Seconds the Testament hint costs, on every level.
    static let testamentHintCost = 1
    /// Seconds a wrong book takes off Survival's clock.
    static let survivalPenalty = 5
    /// Seconds a wrong pick takes off Higher or Lower's clock.
    static let higherOrLowerPenalty = 3

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .easy: "Easy"
        case .normal: "Normal"
        case .hard: "Hard"
        }
    }

    /// Seconds for each Classic question.
    var roundTime: Int {
        switch self {
        case .easy: 30
        case .normal: 25
        case .hard: 20
        }
    }

    /// Seconds for each First Appearance question, a little longer for weighing four books.
    var firstAppearanceTime: Int { roundTime + 5 }

    /// The seconds Survival's clock starts with.
    var survivalStartTime: Int {
        switch self {
        case .easy: 45
        case .normal: 40
        case .hard: 30
        }
    }

    /// Seconds each right answer adds to Survival's clock.
    var survivalTimeBonus: Int {
        switch self {
        case .easy: 5
        case .normal: 4
        case .hard: 3
        }
    }

    /// The seconds for a whole game of Higher or Lower.
    var higherOrLowerTime: Int {
        switch self {
        case .easy: 75
        case .normal: 60
        case .hard: 45
        }
    }

    /// How many more books the right pick in Higher or Lower is in, at least.
    var higherOrLowerGap: Int {
        switch self {
        case .easy: 4
        case .normal: 2
        case .hard: 1
        }
    }

    /// Easy draws wrong books from anywhere; Hard from the same part of the Bible.
    var decoyScope: BeatTheClockChoiceBuilder.DecoyScope {
        switch self {
        case .easy: .anywhere
        case .normal: .sameTestament
        case .hard: .sameSection
        }
    }

    var firstAppearanceSpread: BeatTheClockChoiceBuilder.Spread {
        switch self {
        case .easy: .far
        case .normal: .random
        case .hard: .near
        }
    }

    /// Easy always shows each question's clue; the other levels charge time for it.
    var showsClueAutomatically: Bool { self == .easy }

    var statsDifficulty: GameStats.Difficulty {
        switch self {
        case .easy: .easy
        case .normal: .normal
        case .hard: .hard
        }
    }

    var experienceLevel: GameExperienceLevel {
        switch self {
        case .easy: .learn
        case .normal: .standard
        case .hard: .challenge
        }
    }

    init(experienceLevel: GameExperienceLevel) {
        self = switch experienceLevel {
        case .learn: .easy
        case .standard: .normal
        case .challenge: .hard
        }
    }
}

/// The ways to play Countdown. Each one comes with the clock that suits it: Classic and First
/// Appearance time each question, while Survival and Higher or Lower race one clock for the game.
enum BeatTheClockMode: String, CaseIterable, Identifiable {
    // Raw values are stored in settings, stats and missed questions.
    case survival
    case classic
    case firstAppearance
    case higherOrLower

    /// The modes a review round can replay. Survival's misses are reviewed as Classic, which
    /// asks the same question, and Higher or Lower's pairs aren't worth replaying.
    static let reviewableCases: [BeatTheClockMode] = [.classic, .firstAppearance]

    /// The saved setting. Rapid Fire, which Survival replaced, opens as Survival.
    init(storedValue: String?) {
        self = storedValue == "rapidFire" ? .survival : Self(rawValue: storedValue ?? "") ?? .survival
    }

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .survival: "Survival"
        case .classic: "Classic"
        case .firstAppearance: "First Appearance"
        case .higherOrLower: "Higher or Lower"
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .survival: "Pick a book that mentions each name. Right answers add time; wrong ones take it away."
        case .classic: "Pick a book that mentions each name, with a fresh timer for each question."
        case .firstAppearance: "Pick the book where each person or place first appears."
        case .higherOrLower: "Pick which of two names is found in more books."
        }
    }

    var systemImage: String {
        switch self {
        case .survival: "heart.fill"
        case .classic: "hourglass"
        case .firstAppearance: "flag.fill"
        case .higherOrLower: "arrow.up.arrow.down"
        }
    }

    /// One clock for the whole game, rather than a fresh one for each question.
    var usesGameClock: Bool { self == .survival || self == .higherOrLower }

    /// Only a timer that restarts each question can reward a quick answer.
    var awardsSpeedBonus: Bool { !usesGameClock }

    /// The mode misses are saved and reviewed under, or nil when they aren't saved.
    var reviewModeName: String? {
        switch self {
        case .survival, .classic: BeatTheClockMode.classic.rawValue
        case .firstAppearance: rawValue
        case .higherOrLower: nil
        }
    }

    /// Each mode scores on its own scale, so each keeps its own best.
    var bestScoreKind: GameBestScore.Kind {
        switch self {
        case .survival: .countdownSurvival
        case .classic: .countdown
        case .firstAppearance: .countdownFirstAppearance
        case .higherOrLower: .countdownHigherOrLower
        }
    }
}

enum BeatTheClockCategory: String, CaseIterable, Identifiable {
    case people = "People"
    case places = "Places"
    case both = "Both"

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .people: "People"
        case .places: "Places"
        case .both: "Mixed"
        }
    }
}

enum BeatTheClockRoundOutcome {
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

struct BeatTheClockQuestion: Identifiable {
    enum Subject {
        case person
        case place
    }

    let id: String
    let subject: Subject
    let label: String
    let clue: String
    let acceptableBooks: Set<String>
    /// The verse the entry was written from, shown when the round ends.
    let scriptureReference: String?
    /// Where the name appears in each book of the KJV text, for counts and links.
    var mentions: [String: BeatTheClockMention] = [:]
    /// Books that are, or might be, about this name, so they're never offered as wrong: the
    /// right answers, every book that has the name, and books with another spelling of it.
    var unsafeDecoyBooks: Set<String> = []

    /// The accepted book that mentions the name most, when there's a clear one.
    var bestKnownBook: String? {
        let counted = acceptableBooks.compactMap { book in mentions[book].map { (book, $0.verseCount) } }
        guard let best = counted.max(by: { $0.1 < $1.1 }), best.1 > 0 else { return nil }
        // A tie for most means no single book is the obvious answer.
        guard counted.filter({ $0.1 == best.1 }).count == 1 else { return nil }
        return best.0
    }

    /// "Old Testament", "New Testament" or both, from the accepted books.
    var testamentHint: String {
        let testaments = Set(acceptableBooks.map { BibleBookGroup.group(for: $0).testament })
        switch (testaments.contains(.old), testaments.contains(.new)) {
        case (true, false): return String(localized: "Found in the Old Testament.")
        case (false, true): return String(localized: "Found in the New Testament.")
        default: return String(localized: "Found in both Testaments.")
        }
    }
}

@MainActor
@Observable
final class BeatTheClockGameViewModel {
    enum Phase {
        case setup
        case playing
        case results
    }

    static let questionsPerGame = 10
    /// The most questions a game on one clock can ask before it runs out of fresh ones.
    static let gameClockQuestionLimit = 40
    /// Names drawn for a game of Higher or Lower, enough to pair up a full game.
    private static let higherOrLowerCandidates = 80

    private static let difficultyKey = AppStorageKey.beatTheClockDifficulty
    private static let categoryKey = AppStorageKey.beatTheClockCategory
    private static let modeKey = AppStorageKey.beatTheClockMode

    /// Questions to replay from the missed-questions list; empty for a normal game.
    let reviewQuestionIDs: Set<String>
    /// Where missed questions are recorded; tests pass a store that never touches disk or iCloud.
    private let missedQuestions: MissedGameQuestionStore
    /// Waits between timer ticks; tests pass a manual clock.
    @ObservationIgnored private let sleep: (Duration) async throws -> Void
    /// The current time for the round clock; tests pass the manual clock's time.
    @ObservationIgnored private let now: () -> Date
    /// Loads the passage a round cites; tests pass a fixed one.
    @ObservationIgnored private let loadPassageForReference: (String) async -> GamePassage?

    /// `missedQuestions` and `loadPassage` default to the shared store and the Bible text.
    /// They're resolved here rather than as default arguments, which would be evaluated
    /// outside the main actor.
    /// A review plays the mode its questions were missed in, without changing the saved setting.
    init(
        reviewQuestionIDs: Set<String> = [],
        reviewMode: BeatTheClockMode? = nil,
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
        if let reviewMode { mode = reviewMode }
    }

    // MARK: - Settings

    var difficulty: BeatTheClockDifficulty = BeatTheClockDifficulty(
        rawValue: UserDefaults.standard.string(forKey: BeatTheClockGameViewModel.difficultyKey) ?? ""
    ) ?? .normal {
        didSet {
            // A review plays at its own timer without changing the game's saved difficulty.
            if reviewQuestionIDs.isEmpty {
                UserDefaults.standard.set(difficulty.rawValue, forKey: Self.difficultyKey)
            }
            session.syncSavedBest(from: persistentStreak)
        }
    }

    var category: BeatTheClockCategory = BeatTheClockCategory(
        rawValue: UserDefaults.standard.string(forKey: BeatTheClockGameViewModel.categoryKey) ?? ""
    ) ?? .people {
        didSet { UserDefaults.standard.set(category.rawValue, forKey: Self.categoryKey) }
    }

    var mode = BeatTheClockMode(
        storedValue: UserDefaults.standard.string(forKey: BeatTheClockGameViewModel.modeKey)
    ) {
        didSet {
            // A review plays the mode it's reviewing without changing the saved setting.
            guard reviewQuestionIDs.isEmpty else { return }
            UserDefaults.standard.set(mode.rawValue, forKey: Self.modeKey)
        }
    }

    var experienceLevel: GameExperienceLevel {
        get { difficulty.experienceLevel }
        set { difficulty = BeatTheClockDifficulty(experienceLevel: newValue) }
    }

    // MARK: - Data

    private var loadedPeople: [BibleCharacter] = []
    private var loadedPlaces: [BibleLocationChallenge] = []
    /// Where each person and place is mentioned in the KJV text, keyed by question ID. Nil until indexed.
    private var mentionIndex: [String: [String: BeatTheClockMention]]?
    /// The books with another spelling of each name, keyed by question ID; see `BeatTheClockNameVariants`.
    private var variantBookIndex: [String: Set<String>] = [:]
    private var questionDeck: [BeatTheClockQuestion] = []
    private var pairDeck: [(BeatTheClockQuestion, BeatTheClockQuestion)] = []
    /// Times the current question, or the whole game in a mode with one clock.
    @ObservationIgnored private var roundClock = GameActiveClock()
    /// Seconds taken off the clock: clues, the Testament hint, and wrong answers on a game clock.
    private var penaltySeconds = 0
    /// Seconds Survival's right answers have added to its clock.
    private var bonusSeconds = 0
    @ObservationIgnored private var pulseTask: Task<Void, Never>?
    /// Moves a game on one clock to its next question after a moment to see the answer.
    @ObservationIgnored private var advanceTask: Task<Void, Never>?

    // MARK: - Game state

    private(set) var phase: Phase = .setup
    private(set) var currentQuestion: BeatTheClockQuestion?
    /// The second name in Higher or Lower; nil in the other modes.
    private(set) var rival: BeatTheClockQuestion?
    /// The books on the board; nil in Higher or Lower, which shows two names instead.
    private(set) var choices: BeatTheClockChoices?
    private(set) var questionNumber = 0
    private(set) var totalQuestions = 0
    /// Changes whenever a round starts, so the view can restart its timer task.
    private(set) var roundID = 0
    private(set) var remainingSeconds = 0
    private(set) var roundOutcome: BeatTheClockRoundOutcome?
    private(set) var submittedBook: String?
    /// The name picked in Higher or Lower.
    private(set) var chosenQuestionID: String?
    /// What the last answer did to a game clock, e.g. +4 or −5, shown beside the answer.
    private(set) var lastClockChange: Int?
    private(set) var hintRevealed = false
    private(set) var testamentHintRevealed = false
    private(set) var isPulsing = false
    /// True while the round is paused. The timer stops and the question is hidden.
    private(set) var isPaused = false
    /// True when the timer is turned off while leaving the question visible.
    private(set) var isTimerDisabled = false
    /// The timer was off at some point this round, so it can't earn a speed bonus.
    private var wasTimerOffThisRound = false
    /// A game on one clock has run out; it ends once the last answer has been seen.
    private var isOutOfTime = false
    /// The verses the round cites, once loaded.
    private(set) var passage: GamePassage?

    private(set) var earnedSpeedBonus = false
    private(set) var speedBonusCount = 0

    /// Score, streaks and best game; see `GameScore` for the rules.
    private(set) var session = GameScore()

    // MARK: - Derived state

    private var persistentStreak: PersistentGameStreak {
        PersistentGameStreak(game: "beatclock", variant: difficulty.rawValue)
    }

    private var bestGameScoreKey: String {
        mode.bestScoreKind.key(difficulty: difficulty.rawValue)
    }

    /// A review of missed questions isn't comparable with a full game.
    private var roundCountsTowardBest: Bool { reviewQuestionIDs.isEmpty }

    /// The saved best for the chosen mode and difficulty, for the start screen.
    var bestPoints: Int { GameBestScore.value(forKey: bestGameScoreKey) }

    /// How the round just played compares with the saved best, for the summary.
    var roundBest: RoundBest? {
        guard roundCountsTowardBest, session.bestGameScore > 0 else { return nil }
        return RoundBest(points: session.bestGameScore, isNew: session.isNewBestGame)
    }

    /// Each difficulty, category and mode has its own pool, so each keeps its own pass through it.
    private var recencyGameKey: String {
        let base = "countdown.\(difficulty.rawValue).\(category.rawValue)"
        return mode == .classic ? base : base + ".\(mode.rawValue)"
    }

    /// The seconds on the clock when a question (or, on a game clock, the game) starts.
    var roundTime: Int {
        switch mode {
        case .survival: difficulty.survivalStartTime
        case .classic: difficulty.roundTime
        case .firstAppearance: difficulty.firstAppearanceTime
        case .higherOrLower: difficulty.higherOrLowerTime
        }
    }

    var selectionLocked: Bool { roundOutcome != nil }

    /// Whether a tap on the board counts right now.
    var canAnswer: Bool { phase == .playing && !selectionLocked && !isPaused }

    /// A running question can be paused, and so can a game clock's pause between questions.
    var canPause: Bool {
        phase == .playing && !isPaused && !isTimerDisabled && (roundOutcome == nil || mode.usesGameClock)
    }

    /// A game clock is the whole game, so it can't be switched off.
    var canToggleTimer: Bool { !mode.usesGameClock }

    var isLoadingData: Bool {
        loadedPeople.isEmpty || loadedPlaces.isEmpty || mentionIndex == nil
    }

    /// Higher or Lower compares two names, so a clue about one doesn't help.
    var offersClue: Bool { mode != .higherOrLower }

    /// Every book on a First Appearance board mentions the name, so its Testament gives nothing away.
    var offersTestamentHint: Bool { mode == .classic || mode == .survival }

    var showsClue: Bool {
        offersClue && (difficulty.showsClueAutomatically || hintRevealed || selectionLocked)
    }

    var canRequestHint: Bool {
        offersClue && canAnswer && !showsClue && remainingSeconds > BeatTheClockDifficulty.hintCost
    }

    var canRequestTestamentHint: Bool {
        offersTestamentHint && canAnswer && !testamentHintRevealed
            && remainingSeconds > BeatTheClockDifficulty.testamentHintCost
    }

    var showsTestamentHint: Bool { offersTestamentHint && (testamentHintRevealed || selectionLocked) }

    /// The accepted books in canonical order.
    var sortedAcceptableBooks: [String] {
        guard let currentQuestion else { return [] }
        let order = Dictionary(uniqueKeysWithValues: BibleCanon.canonicalOrder().enumerated().map { ($1, $0) })
        return currentQuestion.acceptableBooks.sorted { (order[$0] ?? Int.max) < (order[$1] ?? Int.max) }
    }

    /// The accepted books, most mentions first, for the result's list.
    var booksByMentions: [(book: String, verses: Int)] {
        guard let currentQuestion else { return [] }
        let counted: [(book: String, verses: Int)] = sortedAcceptableBooks.map { book in
            (book: book, verses: currentQuestion.mentions[book]?.verseCount ?? 0)
        }
        // A stable sort, so books with the same count stay in canonical order.
        return counted.enumerated()
            .sorted { lhs, rhs in
                lhs.element.verses == rhs.element.verses ? lhs.offset < rhs.offset : lhs.element.verses > rhs.element.verses
            }
            .map(\.element)
    }

    /// The first verse that mentions the name in `book`, for its link in the books list.
    func firstMention(in book: String) -> String? {
        guard let mention = currentQuestion?.mentions[book] else { return nil }
        return "\(book) \(mention.firstChapter):\(mention.firstVerse)"
    }

    /// The name in more books, the right pick in Higher or Lower.
    var higherOrLowerWinner: BeatTheClockQuestion? {
        guard let first = currentQuestion, let second = rival else { return nil }
        return first.acceptableBooks.count > second.acceptableBooks.count ? first : second
    }

    var isLastQuestion: Bool {
        isOutOfTime || (mode == .higherOrLower ? pairDeck.isEmpty : questionDeck.isEmpty)
    }

    var progressText: String {
        mode.usesGameClock
            ? String(localized: "Question \(questionNumber)")
            : String(localized: "Question \(questionNumber) of \(totalQuestions)")
    }

    var targetType: String {
        currentQuestion?.subject == .place ? String(localized: "Place") : String(localized: "Person")
    }

    /// What to do with the board, e.g. "Which of these books mentions this person?"
    var instruction: String {
        let isPlace = currentQuestion?.subject == .place
        return switch mode {
        case .survival, .classic:
            isPlace
                ? String(localized: "Which of these books mentions this place?")
                : String(localized: "Which of these books mentions this person?")
        case .firstAppearance:
            isPlace
                ? String(localized: "Where does this place first appear?")
                : String(localized: "Where does this person first appear?")
        case .higherOrLower:
            isPlace
                ? String(localized: "Which place is found in more books?")
                : String(localized: "Who is found in more books?")
        }
    }

    /// Green, then yellow, then red as the clock runs down, scaled to its starting time.
    var timerColor: Color {
        guard !isTimerDisabled else { return .secondary }
        let fraction = Double(remainingSeconds) / Double(max(1, roundTime))
        if fraction <= 0.3 { return .red }
        if fraction <= 0.6 { return .yellow }
        return .green
    }

    /// Right answers, plus speed bonuses in the modes that time each question.
    var points: Int {
        mode.awardsSpeedBonus ? session.score + speedBonusCount : session.score
    }

    /// How the points add up, for the summary.
    var roundPoints: RoundPoints {
        RoundPoints(
            correct: session.score,
            bonuses: mode.awardsSpeedBonus ? [RoundPoints.speed(speedBonusCount)] : []
        )
    }

    // MARK: - Lifecycle

    func onAppear() {
        session.syncSavedBest(from: persistentStreak)
    }

    func onDisappear() {
        // Leaving mid-question counts as running out of time, so backing out can't be used
        // to skip a hard question and keep the streak.
        if phase == .playing, roundOutcome == nil, currentQuestion != nil {
            finishRound(.timedOut)
        }
        // Leaving after answering begins a new game session on return.
        if phase != .setup && session.answered > 0 {
            resetToSetup()
        }
        advanceTask?.cancel()
        session.clearStreak()
    }

    func loadData() async {
        if loadedPeople.isEmpty {
            loadedPeople = await GameDataLoaders.loadCharactersAsync()
        }
        if loadedPlaces.isEmpty {
            loadedPlaces = await GameDataLoaders.loadLocationChallengesAsync()
        }
        if mentionIndex == nil {
            let places = loadedPlaces.map { (id: $0.id, name: $0.locationName) }
            let people = loadedPeople.map { (id: $0.id, name: $0.name) }
            let variantPlaces = BeatTheClockNameVariants.variantNames(for: places)
            let variantPeople = BeatTheClockNameVariants.variantNames(for: people)
            // The catalog's names are the KJV's spellings ("Beersheba", "Bethel"), which other
            // translations write differently ("Beer-sheba", "Beth-el"). Matching against the
            // active translation would mark right answers wrong, so it always uses the KJV.
            let books = await BibleRepository.shared.loadBooksWithoutCaching(for: .kjv)
            let (mentions, variants) = await Task.detached(priority: .userInitiated) {
                var mentions: [String: [String: BeatTheClockMention]] = [:]
                for (id, found) in BeatTheClockAnswerIndex.mentions(of: places, in: books) {
                    mentions["place-\(id)"] = found
                }
                for (id, found) in BeatTheClockAnswerIndex.mentions(of: people, in: books) {
                    mentions["person-\(id)"] = found
                }
                var variants: [String: Set<String>] = [:]
                for (id, found) in BeatTheClockAnswerIndex.booksMentioning(variantPlaces, in: books) {
                    variants["place-\(id)"] = found
                }
                for (id, found) in BeatTheClockAnswerIndex.booksMentioning(variantPeople, in: books) {
                    variants["person-\(id)"] = found
                }
                return (mentions, variants)
            }.value
            variantBookIndex = variants
            mentionIndex = mentions
        }
    }

    /// Updates the clock from active elapsed time. The short polling interval keeps the
    /// display responsive while the clock itself is authoritative, so scheduling delays do
    /// not add extra time.
    func runTimer() async {
        while !Task.isCancelled, phase == .playing, roundOutcome == nil, !isPaused, !isTimerDisabled, remainingSeconds > 0 {
            try? await sleep(.milliseconds(100))
            guard !Task.isCancelled, phase == .playing, roundOutcome == nil, !isPaused, !isTimerDisabled else { return }
            updateRemainingTime()
        }
    }

    private var currentRemainingSeconds: Int {
        max(0, roundTime + bonusSeconds - penaltySeconds - Int(roundClock.elapsed(at: now())))
    }

    private func updateRemainingTime() {
        let updatedRemaining = currentRemainingSeconds
        guard updatedRemaining != remainingSeconds else { return }

        remainingSeconds = updatedRemaining
        if remainingSeconds > 0 {
            pulseTimer()
        } else if mode.usesGameClock {
            // The question on screen when the game clock runs out isn't counted as a miss.
            Haptics.warning()
            showResults()
        } else {
            finishRound(.timedOut)
        }
    }

    /// A short pulse on the timer each second, with a firm tap in the last five.
    private func pulseTimer() {
        isPulsing = true
        if remainingSeconds <= 5 {
            Haptics.warning()
        }
        pulseTask?.cancel()
        pulseTask = Task { [weak self] in
            try? await self?.sleep(.milliseconds(200))
            guard !Task.isCancelled else { return }
            self?.isPulsing = false
        }
    }

    // MARK: - Pausing

    /// Stops the clock and hides the question. Called by the Pause button and whenever the
    /// app stops being active (a call, switching apps, locking the phone).
    func pause() {
        guard canPause else { return }
        if roundOutcome == nil {
            roundClock.pause(at: now())
        } else {
            // Between questions on a game clock, the clock is already stopped; hold the
            // next question until Resume.
            advanceTask?.cancel()
            advanceTask = nil
        }
        isPaused = true
    }

    /// Restarts the clock without resetting the time already played.
    func resume() {
        guard phase == .playing, isPaused else { return }
        isPaused = false
        if roundOutcome == nil {
            roundClock.resume(at: now())
        } else {
            nextRound()
        }
    }

    func toggleTimer() {
        guard canToggleTimer, phase == .playing, roundOutcome == nil, !isPaused else { return }
        isTimerDisabled.toggle()
        if isTimerDisabled {
            roundClock.pause(at: now())
            wasTimerOffThisRound = true
            session.noteTimerTurnedOff()
        } else {
            roundClock.resume(at: now())
        }
    }

    // MARK: - Questions

    private func matchesSelectedDifficulty(_ questionDifficulty: String) -> Bool {
        let normalizedDifficulty = questionDifficulty.lowercased()

        switch difficulty {
        case .easy:
            return normalizedDifficulty == "easy"
        case .normal:
            // The catalog currently uses "Medium" for the Normal tier.
            return normalizedDifficulty == "easy"
                || normalizedDifficulty == "normal"
                || normalizedDifficulty == "medium"
        case .hard:
            return true
        }
    }

    private func makeQuestionDeck() -> [BeatTheClockQuestion] {
        let sourcePeople = reviewQuestionIDs.isEmpty
            ? loadedPeople.filter { matchesSelectedDifficulty($0.difficulty) }
            : loadedPeople
        let sourcePlaces = reviewQuestionIDs.isEmpty
            ? loadedPlaces.filter { matchesSelectedDifficulty($0.difficulty) }
            : loadedPlaces
        let people = sourcePeople.map { entry in
            let id = "person-\(entry.id)"
            let mentions = mentionIndex?[id] ?? [:]
            let books = Set(entry.books)
            return BeatTheClockQuestion(
                id: id,
                subject: .person,
                label: entry.name,
                clue: entry.shortDescription,
                acceptableBooks: books,
                scriptureReference: entry.scriptureReferences.flatMap { $0.isEmpty ? nil : $0 },
                mentions: mentions,
                unsafeDecoyBooks: books.union(mentions.keys).union(variantBookIndex[id] ?? [])
            )
        }
        let places = sourcePlaces.map { entry in
            let id = "place-\(entry.id)"
            let mentions = mentionIndex?[id] ?? [:]
            let books = Self.acceptableBooks(for: entry, indexedBooks: Set(mentions.keys))
            return BeatTheClockQuestion(
                id: id,
                subject: .place,
                label: entry.locationName,
                clue: entry.shortDescription,
                acceptableBooks: books,
                scriptureReference: entry.scriptureMentioned.isEmpty ? nil : entry.scriptureMentioned,
                mentions: mentions,
                unsafeDecoyBooks: books.union(variantBookIndex[id] ?? [])
            )
        }

        // A review round replays every missed question. The category can't be changed while
        // reviewing, so filtering by it would hide missed questions from the other category.
        let deck: [BeatTheClockQuestion] = if !reviewQuestionIDs.isEmpty {
            people + places
        } else {
            switch category {
            case .people: people
            case .places: places
            case .both: people + places
            }
        }
        // First Appearance needs four books that mention the name to fill its board.
        guard mode == .firstAppearance else { return deck.shuffled() }
        let canon = Set(BibleCanon.canonicalOrder())
        return deck.filter { $0.acceptableBooks.intersection(canon).count >= BeatTheClockChoiceBuilder.choiceCount }.shuffled()
    }

    static func acceptableBooks(
        for entry: BibleLocationChallenge,
        indexedBooks: Set<String>
    ) -> Set<String> {
        var books = indexedBooks
        if let referenceBook = parseBookName(from: entry.scriptureMentioned) {
            books.insert(referenceBook)
        }
        return books
    }

    private static func parseBookName(from reference: String?) -> String? {
        guard let ref = reference, !ref.isEmpty else { return nil }
        let parts = ref.split { $0.isWhitespace }
        guard parts.count >= 2 else { return nil }
        return parts.dropLast().joined(separator: " ")
    }

    /// The board for one question, or nil when one can't be built for it.
    private func makeChoices(for question: BeatTheClockQuestion) -> BeatTheClockChoices? {
        var generator = SystemRandomNumberGenerator()
        let canon = BibleCanon.canonicalOrder()
        return switch mode {
        case .firstAppearance:
            BeatTheClockChoiceBuilder.firstAppearanceChoices(
                for: question, spread: difficulty.firstAppearanceSpread, canon: canon, using: &generator
            )
        case .survival, .classic, .higherOrLower:
            BeatTheClockChoiceBuilder.mentionChoices(
                for: question,
                scope: difficulty.decoyScope,
                // Easy asks about the book a name is best known from.
                prefersBestKnownBook: difficulty == .easy,
                canon: canon,
                using: &generator
            )
        }
    }

    // MARK: - Game flow

    func startGame() {
        guard !isLoadingData else { return }
        advanceTask?.cancel()
        let isReview = !reviewQuestionIDs.isEmpty

        if mode == .higherOrLower {
            var generator = SystemRandomNumberGenerator()
            let candidates = RecentGameQuestionStore.shared.selectCycling(
                from: makeQuestionDeck(),
                game: recencyGameKey,
                count: Self.higherOrLowerCandidates,
                id: \.id
            )
            pairDeck = BeatTheClockChoiceBuilder.higherOrLowerPairs(
                from: candidates,
                minimumGap: difficulty.higherOrLowerGap,
                limit: Self.gameClockQuestionLimit,
                using: &generator
            )
            guard !pairDeck.isEmpty else { return }
            questionDeck = []
            totalQuestions = pairDeck.count
        } else {
            // A review replays every missed name it drew.
            let count = mode.usesGameClock && !isReview ? Self.gameClockQuestionLimit : Self.questionsPerGame
            let availableQuestions = isReview
                ? makeQuestionDeck().filter { reviewQuestionIDs.contains($0.id) }
                : RecentGameQuestionStore.shared.selectCycling(
                    from: makeQuestionDeck(),
                    game: recencyGameKey,
                    count: count,
                    id: \.id
                )
            let deck = Array(availableQuestions.prefix(count))
            guard !deck.isEmpty else { return }
            questionDeck = deck
            pairDeck = []
            totalQuestions = deck.count
        }

        questionNumber = 0
        // Each game starts timed; turning the timer off lasts only for the game it's turned off in.
        isTimerDisabled = false
        isOutOfTime = false
        speedBonusCount = 0
        penaltySeconds = 0
        bonusSeconds = 0
        if mode.usesGameClock {
            // One clock for the game. It runs while a question is up, and waits between them.
            roundClock.start(at: now())
            roundClock.pause(at: now())
            remainingSeconds = roundTime
        }
        session.beginGame(savedStreak: persistentStreak)
        phase = .playing
        nextRound()
    }

    func nextRound() {
        advanceTask?.cancel()
        advanceTask = nil
        guard !isOutOfTime, setUpNextQuestion() else {
            showResults()
            return
        }

        questionNumber += 1
        roundOutcome = nil
        submittedBook = nil
        chosenQuestionID = nil
        lastClockChange = nil
        hintRevealed = false
        testamentHintRevealed = false
        earnedSpeedBonus = false
        passage = nil
        isPulsing = false
        isPaused = false
        if mode.usesGameClock {
            roundClock.resume(at: now())
            remainingSeconds = currentRemainingSeconds
        } else {
            remainingSeconds = roundTime
            penaltySeconds = 0
            roundClock.start(at: now())
            // With the timer off, the clock waits too, so turning it back on doesn't count the
            // time spent with it off.
            wasTimerOffThisRound = isTimerDisabled
            if isTimerDisabled {
                roundClock.pause(at: now())
            }
        }
        roundID += 1
        session.startQuestion()
    }

    /// Puts the next question (or pair) on screen. False when there are none left.
    private func setUpNextQuestion() -> Bool {
        if mode == .higherOrLower {
            guard let pair = pairDeck.popLast() else { return false }
            currentQuestion = pair.0
            rival = pair.1
            choices = nil
            RecentGameQuestionStore.shared.record(pair.0, game: recencyGameKey, id: \.id)
            RecentGameQuestionStore.shared.record(pair.1, game: recencyGameKey, id: \.id)
            return true
        }
        // A name whose board can't be filled is skipped.
        while let question = questionDeck.popLast() {
            guard let board = makeChoices(for: question) else { continue }
            currentQuestion = question
            rival = nil
            choices = board
            RecentGameQuestionStore.shared.record(question, game: recencyGameKey, id: \.id)
            return true
        }
        return false
    }

    private func showResults() {
        roundClock.pause(at: now())
        advanceTask?.cancel()
        advanceTask = nil
        pulseTask?.cancel()
        isPulsing = false
        session.finishGame(bestScoreKey: bestGameScoreKey, points: points, savesBest: roundCountsTowardBest)
        // Review games use only missed questions, so their scores aren't comparable.
        if reviewQuestionIDs.isEmpty {
            GameStats.shared.recordModeRound(.beatclock, mode: mode.rawValue, score: points)
        }
        currentQuestion = nil
        rival = nil
        choices = nil
        phase = .results
    }

    func resetToSetup() {
        roundClock.pause(at: now())
        advanceTask?.cancel()
        advanceTask = nil
        phase = .setup
        isPaused = false
        isTimerDisabled = false
        isOutOfTime = false
        roundOutcome = nil
        currentQuestion = nil
        rival = nil
        choices = nil
        remainingSeconds = 0
        questionDeck = []
        pairDeck = []
        session.clearGame()
    }

    func revealHint() {
        guard canRequestHint else { return }
        hintRevealed = true
        penaltySeconds += BeatTheClockDifficulty.hintCost
        updateRemainingTime()
    }

    func revealTestamentHint() {
        guard canRequestTestamentHint else { return }
        testamentHintRevealed = true
        penaltySeconds += BeatTheClockDifficulty.testamentHintCost
        updateRemainingTime()
    }

    /// Clues and the Testament hint asked for this round. Easy's automatic clue isn't counted.
    private var hintsUsed: Int {
        (hintRevealed ? 1 : 0) + (testamentHintRevealed ? 1 : 0)
    }

    // MARK: - Answers

    /// A tapped book. In First Appearance only the earliest is right; otherwise any book
    /// that mentions the name.
    func submit(bookName: String) {
        guard canAnswer, mode != .higherOrLower, let currentQuestion, let choices else { return }
        let correct = mode == .firstAppearance
            ? bookName == choices.answer
            : currentQuestion.acceptableBooks.contains(bookName)
        if correct, mode.awardsSpeedBonus {
            // A quick answer with the timer on the whole round earns a bonus point.
            earnedSpeedBonus = !wasTimerOffThisRound
                && roundClock.elapsed(at: now()) <= Double(roundTime) / 3
            if earnedSpeedBonus { speedBonusCount += 1 }
        }
        finishRound(correct ? .correct : .incorrect, submittedBook: bookName)
    }

    /// A tapped name in Higher or Lower.
    func choose(questionID: String) {
        guard canAnswer, mode == .higherOrLower, let winner = higherOrLowerWinner,
              [currentQuestion?.id, rival?.id].contains(questionID) else { return }
        chosenQuestionID = questionID
        finishRound(questionID == winner.id ? .correct : .incorrect)
    }

    /// On a game clock, ends the game now; otherwise ends the question as a miss.
    func giveUp() {
        guard !selectionLocked, currentQuestion != nil else { return }
        if mode.usesGameClock {
            showResults()
        } else {
            finishRound(.incorrect)
        }
    }

    /// Debug-only shortcut that answers the current question correctly.
    func debugWin() {
        if mode == .higherOrLower {
            if let winner = higherOrLowerWinner { choose(questionID: winner.id) }
        } else if let answer = choices?.answer {
            submit(bookName: answer)
        }
    }

    /// Records the answer (or timeout) on the current question, so it can't be answered again.
    private func finishRound(_ outcome: BeatTheClockRoundOutcome, submittedBook: String? = nil) {
        guard !selectionLocked, let currentQuestion else { return }
        roundClock.pause(at: now())
        pulseTask?.cancel()
        isPulsing = false
        roundOutcome = outcome
        self.submittedBook = submittedBook

        let correct = outcome == .correct
        // A game clock moves with each answer.
        switch mode {
        case .survival:
            let change = correct ? difficulty.survivalTimeBonus : -BeatTheClockDifficulty.survivalPenalty
            if correct { bonusSeconds += change } else { penaltySeconds -= change }
            lastClockChange = change
        case .higherOrLower where !correct:
            penaltySeconds += BeatTheClockDifficulty.higherOrLowerPenalty
            lastClockChange = -BeatTheClockDifficulty.higherOrLowerPenalty
        case .higherOrLower, .classic, .firstAppearance:
            break
        }
        if mode.usesGameClock {
            remainingSeconds = currentRemainingSeconds
            isOutOfTime = remainingSeconds == 0
        }

        session.record(roundEntry(for: currentQuestion, outcome: outcome), savedStreak: persistentStreak)

        GameStats.shared.recordRound(
            game: .beatclock,
            difficulty: difficulty.statsDifficulty,
            correct: correct ? 1 : 0,
            answered: 1,
            currentBestStreak: session.savedBestStreak
        )
        GameStats.shared.recordBeatClockType(
            type: currentQuestion.subject == .person ? "People" : "Places",
            answered: 1,
            correct: correct ? 1 : 0
        )
        GameStats.shared.recordModeAnswer(.beatclock, mode: mode.rawValue, correct: correct)
        if let reviewModeName = mode.reviewModeName {
            if correct, !reviewQuestionIDs.isEmpty {
                missedQuestions.resolveReviewQuestion(game: .beatTheClock, mode: reviewModeName, questionID: currentQuestion.id)
            } else if !correct {
                // A place is tied to the book it's cited from; a person to every book they're in.
                let scriptureReference = currentQuestion.subject == .place
                    ? currentQuestion.scriptureReference.flatMap { BibleReferenceLinker.parse($0) }
                    : nil
                missedQuestions.record(
                    game: .beatTheClock,
                    mode: reviewModeName,
                    bookNames: scriptureReference.map { [$0.bookName] } ?? Array(currentQuestion.acceptableBooks),
                    chapterNumber: scriptureReference?.chapter,
                    topic: currentQuestion.subject == .person ? "Bible people" : "Bible places",
                    questionID: currentQuestion.id
                )
            }
        }

        if correct { Haptics.success() } else { Haptics.error() }
        if mode.usesGameClock { scheduleAdvance() }
    }

    /// The answer for the end-of-round review.
    private func roundEntry(for question: BeatTheClockQuestion, outcome: BeatTheClockRoundOutcome) -> GameRoundEntry {
        let entryOutcome: GameRoundEntry.Outcome = switch outcome {
        case .correct: .correct
        case .incorrect: .wrong
        case .timedOut: .timedOut
        }
        let category = question.subject == .person ? String(localized: "People") : String(localized: "Places")

        switch mode {
        case .higherOrLower:
            let rivalLabel = rival?.label ?? ""
            let chosen = [question, rival].compactMap(\.self).first { $0.id == chosenQuestionID }
            let winner = higherOrLowerWinner ?? question
            return GameRoundEntry(
                prompt: String(localized: "\(question.label) or \(rivalLabel)?"),
                outcome: entryOutcome,
                givenAnswer: chosen?.label,
                correctAnswer: String(localized: "\(winner.label) (\(winner.acceptableBooks.count) books)"),
                category: category
            )
        case .firstAppearance:
            let answer = choices?.answer ?? ""
            return GameRoundEntry(
                prompt: String(localized: "Where does \(question.label) first appear?"),
                outcome: entryOutcome,
                givenAnswer: submittedBook,
                correctAnswer: answer,
                category: category,
                reference: firstMention(in: answer) ?? question.scriptureReference,
                hintCount: hintsUsed
            )
        case .survival, .classic:
            return GameRoundEntry(
                prompt: question.label,
                outcome: entryOutcome,
                givenAnswer: submittedBook,
                correctAnswer: choices?.answer ?? sortedAcceptableBooks.formatted(.list(type: .or)),
                category: category,
                reference: question.scriptureReference,
                hintCount: hintsUsed
            )
        }
    }

    /// On a game clock, the answer shows for a moment, then the next question comes up.
    private func scheduleAdvance() {
        advanceTask?.cancel()
        let delay: Duration = mode == .higherOrLower ? .milliseconds(1400) : .milliseconds(900)
        let sleep = self.sleep
        advanceTask = Task { [weak self] in
            do { try await sleep(delay) } catch { return }
            guard !Task.isCancelled, let self, self.phase == .playing, self.roundOutcome != nil, !self.isPaused else { return }
            self.nextRound()
        }
    }

    // MARK: - Passages

    /// The verse a round's answer comes from: the first mention for First Appearance, or the
    /// verse the entry was written from.
    private var passageReference: String? {
        guard let question = currentQuestion else { return nil }
        if mode == .firstAppearance, let answer = choices?.answer, let first = firstMention(in: answer) {
            return first
        }
        return question.scriptureReference
    }

    /// Loads the verses the round cites, ready for showing when it ends. A game clock moves on
    /// before there's time to read them, so it skips this.
    func loadPassage() async {
        guard !mode.usesGameClock, let question = currentQuestion, let reference = passageReference, passage == nil else { return }
        let loaded = await loadPassageForReference(reference)
        // The player may have moved on while the Bible loaded.
        guard currentQuestion?.id == question.id else { return }
        passage = loaded
    }

    /// The cited verses, shown once the round is over.
    var displayedVerse: GameVerse? {
        guard selectionLocked, let passage else { return nil }
        return GameVerse(text: passage.text, reference: passage.title, isClue: false)
    }
}
