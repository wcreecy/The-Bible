import Foundation
import Observation
import SwiftUI

enum BeatTheClockDifficulty: String, CaseIterable, Identifiable {
    case easy
    case normal
    case hard

    /// Seconds a clue costs on Normal and Hard.
    static let hintCost = 3

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .easy: "Easy"
        case .normal: "Normal"
        case .hard: "Hard"
        }
    }

    var roundTime: Int {
        switch self {
        case .easy: 30
        case .normal: 25
        case .hard: 20
        }
    }

    /// Seconds the Testament hint costs, on every level.
    static let testamentHintCost = 1
    /// Seconds a wrong book costs in Rapid Fire.
    static let rapidFirePenalty = 3

    /// Seconds for each Rapid Fire subject, a little longer on Easy.
    var rapidFireTime: Int {
        switch self {
        case .easy: 75
        case .normal: 60
        case .hard: 45
        }
    }

    /// Easy always shows each question's clue; the other levels charge time for it.
    var showsClueAutomatically: Bool { self == .easy }

    var detail: LocalizedStringResource {
        switch self {
        case .easy:
            "\(roundTime) seconds per question. Well-known names, with a clue shown for each one."
        case .normal:
            "\(roundTime) seconds per question. Adds less familiar names. A clue costs \(Self.hintCost) seconds."
        case .hard:
            "\(roundTime) seconds per question. Every name in the game. A clue costs \(Self.hintCost) seconds."
        }
    }

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

/// Classic asks for one book per name; Rapid Fire asks for as many as you can find.
enum BeatTheClockMode: String, CaseIterable, Identifiable {
    // Raw values are stored in settings.
    case classic
    case rapidFire

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .classic: "Classic"
        case .rapidFire: "Rapid Fire"
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .classic: "Name one book that mentions each person or place."
        case .rapidFire: "Name as many books as you can for each of three names. A wrong book costs \(BeatTheClockDifficulty.rapidFirePenalty) seconds."
        }
    }

    var systemImage: String {
        switch self {
        case .classic: "hourglass"
        case .rapidFire: "flame.fill"
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
    static let rapidFireSubjectsPerGame = 3
    /// A Rapid Fire subject needs at least this many books to make a round of it.
    private static let rapidFireMinimumBooks = 4

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

    // MARK: - Settings

    var difficulty: BeatTheClockDifficulty = BeatTheClockDifficulty(
        rawValue: UserDefaults.standard.string(forKey: BeatTheClockGameViewModel.difficultyKey) ?? ""
    ) ?? .normal {
        didSet {
            UserDefaults.standard.set(difficulty.rawValue, forKey: Self.difficultyKey)
            session.syncSavedBest(from: persistentStreak)
        }
    }

    var category: BeatTheClockCategory = BeatTheClockCategory(
        rawValue: UserDefaults.standard.string(forKey: BeatTheClockGameViewModel.categoryKey) ?? ""
    ) ?? .people {
        didSet { UserDefaults.standard.set(category.rawValue, forKey: Self.categoryKey) }
    }

    var mode: BeatTheClockMode = BeatTheClockMode(
        rawValue: UserDefaults.standard.string(forKey: BeatTheClockGameViewModel.modeKey) ?? ""
    ) ?? .classic {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Self.modeKey) }
    }

    /// Review rounds replay single questions, so they're always Classic.
    var isRapidFire: Bool { mode == .rapidFire && reviewQuestionIDs.isEmpty }

    /// The mode actually being played: review games are always played as Classic.
    private var playedMode: BeatTheClockMode { isRapidFire ? .rapidFire : .classic }

    var experienceLevel: GameExperienceLevel {
        get { difficulty.experienceLevel }
        set { difficulty = BeatTheClockDifficulty(experienceLevel: newValue) }
    }

    // MARK: - Data

    private var loadedPeople: [BibleCharacter] = []
    private var loadedPlaces: [BibleLocationChallenge] = []
    /// Where each person and place is mentioned in the KJV text, keyed by question ID. Nil until indexed.
    private var mentionIndex: [String: [String: BeatTheClockMention]]?
    private var questionDeck: [BeatTheClockQuestion] = []
    @ObservationIgnored private var roundClock = GameActiveClock()
    /// Seconds taken off the round: clues, the Testament hint, and wrong Rapid Fire books.
    private var penaltySeconds = 0
    @ObservationIgnored private var pulseTask: Task<Void, Never>?

    // MARK: - Game state

    private(set) var phase: Phase = .setup
    private(set) var currentQuestion: BeatTheClockQuestion?
    private(set) var questionNumber = 0
    private(set) var totalQuestions = 0
    /// Changes whenever a round starts, so the view can restart its timer task.
    private(set) var roundID = 0
    private(set) var remainingSeconds = 0
    private(set) var roundOutcome: BeatTheClockRoundOutcome?
    private(set) var submittedBook: String?
    private(set) var hintRevealed = false
    private(set) var testamentHintRevealed = false
    private(set) var isPulsing = false
    /// True while the round is paused. The timer stops and the question is hidden.
    private(set) var isPaused = false
    /// True when the timer is turned off while leaving the question visible.
    private(set) var isTimerDisabled = false
    /// The timer was off at some point this round, so it can't earn a speed bonus.
    private var wasTimerOffThisRound = false
    /// The verses the round cites, once loaded.
    private(set) var passage: GamePassage?
    /// Books found so far for the Rapid Fire subject, in the order they were named.
    private(set) var foundBooks: [String] = []

    // Bonuses and points across the game.
    private(set) var earnedSpeedBonus = false
    private(set) var earnedLessKnownBonus = false
    private(set) var speedBonusCount = 0
    private(set) var lessKnownBonusCount = 0
    private(set) var rapidFireBookCount = 0

    /// Score, streaks and best game; see `GameScore` for the rules.
    private(set) var session = GameScore()

    // Answer entry
    var searchText = "" {
        didSet {
            if searchText != oldValue { inputMessage = nil }
        }
    }
    private(set) var inputMessage: String?

    // MARK: - Derived state

    private var persistentStreak: PersistentGameStreak {
        PersistentGameStreak(game: "beatclock", variant: difficulty.rawValue)
    }

    /// Classic scores points and Rapid Fire scores books found, so each keeps its own best.
    private var bestGameScoreKey: String {
        (isRapidFire ? GameBestScore.Kind.countdownRapidFire : .countdown).key(difficulty: difficulty.rawValue)
    }

    /// A review of missed questions isn't comparable with a full game.
    private var roundCountsTowardBest: Bool { reviewQuestionIDs.isEmpty }

    /// The saved best for the chosen mode and difficulty, for the start screen.
    var bestPoints: Int {
        let kind = mode == .rapidFire ? GameBestScore.Kind.countdownRapidFire : .countdown
        return GameBestScore.value(forKey: kind.key(difficulty: difficulty.rawValue))
    }

    /// How the round just played compares with the saved best, for the summary.
    var roundBest: RoundBest? {
        guard roundCountsTowardBest, session.bestGameScore > 0 else { return nil }
        return RoundBest(points: session.bestGameScore, isNew: session.isNewBestGame)
    }

    /// Each difficulty, category and mode has its own pool, so each keeps its own pass through it.
    private var recencyGameKey: String {
        let base = "countdown.\(difficulty.rawValue).\(category.rawValue)"
        return isRapidFire ? base + ".rapidFire" : base
    }

    /// The time a round starts with in this mode.
    var roundTime: Int { isRapidFire ? difficulty.rapidFireTime : difficulty.roundTime }

    var selectionLocked: Bool { roundOutcome != nil }

    /// Only a question with time running can be paused.
    var canPause: Bool { phase == .playing && roundOutcome == nil && !isPaused && !isTimerDisabled }

    var isLoadingData: Bool {
        loadedPeople.isEmpty || loadedPlaces.isEmpty || mentionIndex == nil
    }

    var filteredBooks: [String] {
        let suggestions = BibleBookNameMatcher.suggestions(for: searchText, in: BibleCanon.canonicalOrder())
        // Rapid Fire doesn't suggest books already found.
        return suggestions.filter { !foundBooks.contains($0) }
    }

    var canSubmit: Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !selectionLocked && !isPaused && !trimmed.isEmpty
    }

    var showsClue: Bool {
        difficulty.showsClueAutomatically || hintRevealed || selectionLocked
    }

    var canRequestHint: Bool {
        !selectionLocked && !isPaused && !showsClue && remainingSeconds > BeatTheClockDifficulty.hintCost
    }

    var canRequestTestamentHint: Bool {
        !selectionLocked && !isPaused && !testamentHintRevealed
            && remainingSeconds > BeatTheClockDifficulty.testamentHintCost
    }

    var showsTestamentHint: Bool { testamentHintRevealed || selectionLocked }

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

    var isLastQuestion: Bool { questionDeck.isEmpty }

    var progressText: String {
        isRapidFire
            ? String(localized: "Name \(questionNumber) of \(totalQuestions)")
            : String(localized: "Question \(questionNumber) of \(totalQuestions)")
    }

    var targetType: String {
        currentQuestion?.subject == .place ? String(localized: "Place") : String(localized: "Person")
    }

    /// Green, then yellow, then red as the round runs down, scaled to the round length.
    var timerColor: Color {
        guard !isTimerDisabled else { return .secondary }
        let fraction = Double(remainingSeconds) / Double(max(1, roundTime))
        if fraction <= 0.3 { return .red }
        if fraction <= 0.6 { return .yellow }
        return .green
    }

    /// Correct answers plus bonuses in Classic; books found in Rapid Fire.
    var points: Int {
        isRapidFire ? rapidFireBookCount : session.score + speedBonusCount + lessKnownBonusCount
    }

    /// How the points add up, for the summary. Nil in Rapid Fire, which scores books found, and
    /// when no bonus was earned.
    var roundPoints: RoundPoints? {
        guard !isRapidFire else { return nil }
        return RoundPoints(
            correct: session.score,
            bonuses: [RoundPoints.speed(speedBonusCount), RoundPoints.lessKnown(lessKnownBonusCount)]
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
            // The catalog's names are the KJV's spellings ("Beersheba", "Bethel"), which other
            // translations write differently ("Beer-sheba", "Beth-el"). Matching against the
            // active translation would mark right answers wrong, so it always uses the KJV.
            let books = await BibleRepository.shared.loadBooksWithoutCaching(for: .kjv)
            mentionIndex = await Task.detached(priority: .userInitiated) {
                var index: [String: [String: BeatTheClockMention]] = [:]
                for (id, mentions) in BeatTheClockAnswerIndex.mentions(of: places, in: books) {
                    index["place-\(id)"] = mentions
                }
                for (id, mentions) in BeatTheClockAnswerIndex.mentions(of: people, in: books) {
                    index["person-\(id)"] = mentions
                }
                return index
            }.value
        }
    }

    /// Updates the current round from active elapsed time. The short polling interval keeps
    /// the display responsive while the clock itself is authoritative, so scheduling delays do
    /// not add extra time to a round.
    func runTimer() async {
        while !Task.isCancelled, phase == .playing, roundOutcome == nil, !isPaused, !isTimerDisabled, remainingSeconds > 0 {
            try? await sleep(.milliseconds(100))
            guard !Task.isCancelled, phase == .playing, roundOutcome == nil, !isPaused, !isTimerDisabled else { return }
            updateRemainingTime()
        }
    }

    private func updateRemainingTime() {
        let elapsedSeconds = Int(roundClock.elapsed(at: now()))
        let updatedRemaining = max(0, roundTime - penaltySeconds - elapsedSeconds)
        guard updatedRemaining != remainingSeconds else { return }

        remainingSeconds = updatedRemaining
        if remainingSeconds == 0 {
            finishRound(isRapidFire && !foundBooks.isEmpty ? .correct : .timedOut)
        } else {
            pulseTimer()
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
        roundClock.pause(at: now())
        isPaused = true
    }

    /// Restarts the clock without resetting the time already played.
    func resume() {
        guard phase == .playing, roundOutcome == nil, isPaused else { return }
        roundClock.resume(at: now())
        isPaused = false
    }

    func toggleTimer() {
        guard phase == .playing, roundOutcome == nil, !isPaused else { return }
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
            return BeatTheClockQuestion(
                id: id,
                subject: .person,
                label: entry.name,
                clue: entry.shortDescription,
                acceptableBooks: Set(entry.books),
                scriptureReference: entry.scriptureReferences.flatMap { $0.isEmpty ? nil : $0 },
                mentions: mentionIndex?[id] ?? [:]
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
                mentions: mentions
            )
        }

        // A review round replays every missed question. The category can't be changed while
        // reviewing, so filtering by it would hide missed questions from the other category.
        guard reviewQuestionIDs.isEmpty else {
            return (people + places).shuffled()
        }

        let deck: [BeatTheClockQuestion] = switch category {
        case .people: people
        case .places: places
        case .both: people + places
        }
        // Rapid Fire needs names found in several books.
        return isRapidFire
            ? deck.filter { $0.acceptableBooks.count >= Self.rapidFireMinimumBooks }.shuffled()
            : deck.shuffled()
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

    // MARK: - Game flow

    func startGame() {
        guard !isLoadingData else { return }
        let count = isRapidFire ? Self.rapidFireSubjectsPerGame : Self.questionsPerGame
        let availableQuestions = reviewQuestionIDs.isEmpty
            ? RecentGameQuestionStore.shared.selectCycling(
                from: makeQuestionDeck(),
                game: recencyGameKey,
                count: count,
                id: \.id
            )
            : makeQuestionDeck().filter { reviewQuestionIDs.contains($0.id) }
        let deck = Array(availableQuestions.prefix(count))
        guard !deck.isEmpty else { return }
        questionDeck = deck
        totalQuestions = deck.count
        questionNumber = 0
        // Each game starts timed; turning the timer off lasts only for the game it's turned off in.
        isTimerDisabled = false
        speedBonusCount = 0
        lessKnownBonusCount = 0
        rapidFireBookCount = 0
        session.beginGame(savedStreak: persistentStreak)
        phase = .playing
        nextRound()
    }

    func nextRound() {
        guard let question = questionDeck.popLast() else {
            showResults()
            return
        }

        currentQuestion = question
        RecentGameQuestionStore.shared.record(question, game: recencyGameKey, id: \.id)
        questionNumber += 1
        roundOutcome = nil
        submittedBook = nil
        hintRevealed = false
        testamentHintRevealed = false
        earnedSpeedBonus = false
        earnedLessKnownBonus = false
        foundBooks = []
        passage = nil
        searchText = ""
        inputMessage = nil
        remainingSeconds = roundTime
        penaltySeconds = 0
        roundClock.start(at: now())
        // With the timer off, the clock waits too, so turning it back on doesn't count the
        // time spent with it off.
        wasTimerOffThisRound = isTimerDisabled
        if isTimerDisabled {
            roundClock.pause(at: now())
        }
        isPulsing = false
        isPaused = false
        roundID += 1
        session.startQuestion()
    }

    private func showResults() {
        roundClock.pause(at: now())
        session.finishGame(bestScoreKey: bestGameScoreKey, points: points, savesBest: roundCountsTowardBest)
        // Review games use only missed questions, so their scores aren't comparable.
        if reviewQuestionIDs.isEmpty {
            GameStats.shared.recordModeRound(.beatclock, mode: playedMode.rawValue, score: points)
        }
        currentQuestion = nil
        phase = .results
    }

    func resetToSetup() {
        roundClock.pause(at: now())
        phase = .setup
        isPaused = false
        isTimerDisabled = false
        roundOutcome = nil
        currentQuestion = nil
        remainingSeconds = 0
        questionDeck = []
        foundBooks = []
        searchText = ""
        inputMessage = nil
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

    func clearInput() {
        searchText = ""
    }

    func submitCurrentEntry() {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !selectionLocked, !isPaused else { return }

        // Accept an exact name (or common variant), or the only suggestion left.
        let suggestions = filteredBooks
        guard let bookName = BibleBookNameMatcher.canonicalName(for: text, in: BibleCanon.canonicalOrder())
                ?? (suggestions.count == 1 ? suggestions.first : nil) else {
            inputMessage = String(localized: "“\(text)” isn’t a book of the Bible.")
            Haptics.warning()
            return
        }
        submit(bookName: bookName)
    }

    func submit(bookName: String) {
        guard !selectionLocked, !isPaused, let currentQuestion else { return }
        if isRapidFire {
            submitRapidFire(bookName: bookName, for: currentQuestion)
            return
        }
        searchText = bookName
        let correct = currentQuestion.acceptableBooks.contains(bookName)
        if correct {
            // A quick answer with the timer on the whole round earns a bonus point.
            earnedSpeedBonus = !wasTimerOffThisRound
                && roundClock.elapsed(at: now()) <= Double(difficulty.roundTime) / 3
            // So does a right book other than the one that mentions the name most.
            if let bestKnown = currentQuestion.bestKnownBook, currentQuestion.acceptableBooks.count > 1 {
                earnedLessKnownBonus = bookName != bestKnown
            }
            if earnedSpeedBonus { speedBonusCount += 1 }
            if earnedLessKnownBonus { lessKnownBonusCount += 1 }
        }
        finishRound(correct ? .correct : .incorrect, submittedBook: bookName)
    }

    /// Rapid Fire: a right book is added and play goes on; a wrong one costs time.
    private func submitRapidFire(bookName: String, for question: BeatTheClockQuestion) {
        searchText = ""
        if foundBooks.contains(bookName) {
            inputMessage = String(localized: "You already named \(bookName).")
            Haptics.selection()
        } else if question.acceptableBooks.contains(bookName) {
            foundBooks.append(bookName)
            rapidFireBookCount += 1
            Haptics.success()
            if foundBooks.count == question.acceptableBooks.count {
                finishRound(.correct)
            }
        } else {
            inputMessage = String(localized: "\(bookName) doesn’t mention \(question.label) (−\(BeatTheClockDifficulty.rapidFirePenalty) sec).")
            penaltySeconds += BeatTheClockDifficulty.rapidFirePenalty
            Haptics.error()
            updateRemainingTime()
        }
    }

    /// Ends the round as a miss. In Rapid Fire, the books already found still count.
    func giveUp() {
        guard !selectionLocked, currentQuestion != nil else { return }
        finishRound(isRapidFire && !foundBooks.isEmpty ? .correct : .incorrect)
    }

    /// Debug-only shortcut that counts the current round as correct.
    func debugWin() {
        finishRound(.correct)
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
        let entryOutcome: GameRoundEntry.Outcome = switch outcome {
        case .correct: .correct
        case .incorrect: .wrong
        case .timedOut: .timedOut
        }
        session.record(
            GameRoundEntry(
                prompt: currentQuestion.label,
                outcome: entryOutcome,
                givenAnswer: isRapidFire ? foundBooks.formatted(.list(type: .and)) : submittedBook,
                correctAnswer: sortedAcceptableBooks.formatted(.list(type: isRapidFire ? .and : .or)),
                category: currentQuestion.subject == .person ? String(localized: "People") : String(localized: "Places"),
                reference: currentQuestion.scriptureReference,
                hintCount: hintsUsed
            ),
            savedStreak: persistentStreak
        )

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
        GameStats.shared.recordModeAnswer(.beatclock, mode: playedMode.rawValue, correct: correct)
        if correct, !reviewQuestionIDs.isEmpty {
            missedQuestions.resolveReviewQuestion(game: .beatTheClock, questionID: currentQuestion.id)
        } else if !correct {
            // A place is tied to the book it's cited from; a person to every book they're in.
            let scriptureReference = currentQuestion.subject == .place
                ? currentQuestion.scriptureReference.flatMap { BibleReferenceLinker.parse($0) }
                : nil
            missedQuestions.record(
                game: .beatTheClock,
                bookNames: scriptureReference.map { [$0.bookName] } ?? Array(currentQuestion.acceptableBooks),
                chapterNumber: scriptureReference?.chapter,
                topic: currentQuestion.subject == .person ? "Bible people" : "Bible places",
                questionID: currentQuestion.id
            )
        }

        if correct { Haptics.success() } else { Haptics.error() }
    }

    // MARK: - Passages

    /// Loads the verses the round cites, ready for showing when it ends.
    func loadPassage() async {
        guard let question = currentQuestion, let reference = question.scriptureReference, passage == nil else { return }
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
