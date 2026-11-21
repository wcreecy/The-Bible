import Foundation
import Observation
import SwiftUI

enum QuizMode: String, CaseIterable, Identifiable {
    case standard
    case reverse

    var id: Self { self }
    var title: LocalizedStringResource { self == .standard ? "Standard" : "Reverse" }
}

enum QuizDifficulty: String, CaseIterable, Identifiable {
    case easy
    case normal
    case hard

    /// Seconds the previous verse costs on a timed difficulty.
    static let contextCost = 3

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
        case .normal: 18
        case .hard: 15
        }
    }

    /// Seconds the previous verse costs; free when there's no timer.
    var contextCost: Int { timeLimit == nil ? 0 : Self.contextCost }

    var detail: LocalizedStringResource {
        switch self {
        case .easy:
            "No time limit. Wrong choices come from other parts of the Bible."
        case .normal:
            "18 seconds per verse. Wrong choices come from anywhere in your categories."
        case .hard:
            "15 seconds per verse. Wrong choices come from the same part of the Bible, such as all four Gospels."
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

/// Parts of the Bible a verse can be drawn from. Also used by Hangman.
enum QuizVerseSection: String, CaseIterable, Identifiable {
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
    var hardFamily: [QuizVerseSection] {
        switch self {
        case .acts: [.gospels, .acts]
        case .revelation: [.epistles, .revelation]
        default: [self]
        }
    }

    /// How the Section Hint names this part of the Bible: "It's from \(hintPhrase)."
    /// Acts and Revelation are one book each, so naming them would give the answer away. Their
    /// hints name a neighbor too, the same grouping Hard uses for wrong choices.
    var hintPhrase: String {
        switch self {
        case .law: String(localized: "the Law")
        case .history: String(localized: "the History books")
        case .poetry: String(localized: "the Poetry books")
        case .majorProphets: String(localized: "the Major Prophets")
        case .minorProphets: String(localized: "the Minor Prophets")
        case .gospels: String(localized: "the Gospels")
        case .acts: String(localized: "the Gospels or Acts")
        case .epistles: String(localized: "the Epistles")
        case .revelation: String(localized: "the Epistles or Revelation")
        }
    }

    static func containing(_ bookName: String) -> QuizVerseSection? {
        allCases.first { $0.bookNames.contains(bookName) }
    }
}

enum QuizOutcome {
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

struct QuizQuestion: Identifiable {
    let id = UUID()
    let verseText: String
    let correctBook: String
    let chapter: Int
    let verse: Int
    /// The verse before this one, offered as a hint.
    let contextText: String?
    let options: [String]
    var mode: QuizMode = .standard
    /// Full verse metadata in the same order as the Reverse answer texts.
    var optionVerses: [QuizVerse] = []
    var correctAnswer: String { mode == .reverse ? verseText : correctBook }
    var reference: String { "\(correctBook) \(chapter):\(verse)" }
    var prompt: String { mode == .reverse ? reference : "“\(verseText)”" }
    var selected: String?
    var outcome: QuizOutcome?
    var contextRevealed = false
    /// Wrong answers taken away by 50/50.
    var removedOptions: Set<String> = []
    var lifelinesUsed: Set<QuizLifeline> = []
    /// Seconds the extra-time lifeline added to this question.
    var bonusSeconds = 0
    /// The timer was off at some point, so the answer can't earn a speed bonus.
    var wasTimerOff = false
    var earnedSpeedBonus = false
    /// The chapter's one-line summary from the Study notes, shown after answering.
    /// Chapters offered for the bonus after a correct book; empty when there's no bonus.
    var chapterOptions: [Int] = []
    var chapterGuess: Int?

    /// Identifies the verse for missed-question review.
    var reviewID: String { mode == .reverse ? reference : "\(correctBook)|\(chapter)|\(verse)" }

    var earnedChapterBonus: Bool { chapterGuess == chapter }

    /// Help used on this question, for the round summary: lifelines and the previous verse.
    var hintCount: Int { lifelinesUsed.count + (contextRevealed ? 1 : 0) }
}

/// Help a player can use once per round.
enum QuizLifeline: CaseIterable, Hashable {
    /// Removes two wrong answers.
    case fiftyFifty
    /// Names the part of the Bible the verse is from. Standard mode only.
    case sectionHint
    /// Adds ten seconds to the clock. Not on Easy, which has no timer.
    case extraTime

    static let extraSeconds = 10
}

@MainActor
@Observable
final class QuizGameViewModel {
    enum Phase {
        case setup
        case playing
        case results
    }

    fileprivate struct VerseCandidate {
        let text: String
        let bookName: String
        let chapter: Int
        let verse: Int
        let contextText: String?

        var reviewID: String { "\(bookName)|\(chapter)|\(verse)" }
    }

    static let questionsPerGame = 10

    private static let difficultyKey = AppStorageKey.quizDifficulty
    private static let sectionsKey = AppStorageKey.quizSections
    /// Replaced by the category quick picks; read once to carry an old choice over.
    private static let legacyScopeKey = AppStorageKey.quizScope

    /// Verses to replay from the missed-questions list; empty for a normal game.
    let reviewQuestionIDs: Set<String>
    /// Where missed questions are recorded; tests pass a store that never touches disk or iCloud.
    private let missedQuestions: MissedGameQuestionStore

    /// Waits between timer ticks; tests pass a manual clock.
    @ObservationIgnored private let sleep: (Duration) async throws -> Void
    /// The current time for the question clock; tests pass the manual clock's time.
    @ObservationIgnored private let now: () -> Date

    /// `missedQuestions` defaults to the shared store. It's resolved here rather than as a
    /// default argument, which would be evaluated outside the main actor.
    init(
        reviewQuestionIDs: Set<String> = [],
        mode: QuizMode = .standard,
        missedQuestions: MissedGameQuestionStore? = nil,
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        now: @escaping () -> Date = Date.init
    ) {
        self.reviewQuestionIDs = reviewQuestionIDs
        self.mode = mode
        self.missedQuestions = missedQuestions ?? .shared
        self.sleep = sleep
        self.now = now
    }

    var mode: QuizMode
    var pool: QuizVersePool = QuizVersePool(
        rawValue: UserDefaults.standard.string(forKey: AppStorageKey.quizVersePool) ?? ""
    ) ?? .wellKnown {
        didSet { UserDefaults.standard.set(pool.rawValue, forKey: AppStorageKey.quizVersePool) }
    }
    var favoriteVerses: [QuizVerse] = []
    private var reverseSource: QuizReverseQuestionSource?
    private var reverseBag: [QuizVerse] = []

    private var configuredReverseSource: QuizReverseQuestionSource {
        QuizReverseQuestionSource(difficulty: difficulty, pool: pool,
                                  selectedSections: selectedSections, favoriteVerses: favoriteVerses)
    }

    var isFavoritesAvailable: Bool { configuredReverseSource.isFavoritesAvailable }
    var canStart: Bool {
        isFilterReady && (!reviewQuestionIDs.isEmpty || pool != .favorites || isFavoritesAvailable)
    }

    // MARK: - Settings

    var difficulty: QuizDifficulty = QuizDifficulty(
        rawValue: UserDefaults.standard.string(forKey: QuizGameViewModel.difficultyKey) ?? ""
    ) ?? .normal {
        didSet {
            UserDefaults.standard.set(difficulty.rawValue, forKey: Self.difficultyKey)
            session.syncSavedBest(from: persistentStreak)
        }
    }

    var experienceLevel: GameExperienceLevel {
        get { difficulty.experienceLevel }
        set { difficulty = QuizDifficulty(experienceLevel: newValue) }
    }

    private var sectionsRaw: String = UserDefaults.standard.string(forKey: QuizGameViewModel.sectionsKey) ?? "" {
        didSet { UserDefaults.standard.set(sectionsRaw, forKey: Self.sectionsKey) }
    }

    private var storedSections: Set<QuizVerseSection> {
        Set(sectionsRaw.split(separator: ",").compactMap { QuizVerseSection(rawValue: String($0)) })
    }

    /// The chosen categories. An empty stored selection means every category, and
    /// clearing every category is ignored.
    var selectedSections: Set<QuizVerseSection> {
        get { storedSections.isEmpty ? Set(QuizVerseSection.allCases) : storedSections }
        set {
            guard !newValue.isEmpty else { return }
            if newValue == Set(QuizVerseSection.allCases) {
                sectionsRaw = ""
            } else {
                sectionsRaw = QuizVerseSection.allCases
                    .filter { newValue.contains($0) }
                    .map(\.rawValue)
                    .joined(separator: ",")
            }
        }
    }

    private var poolBookNames: Set<String> {
        Set(selectedSections.flatMap(\.bookNames))
    }

    // MARK: - Game state

    private(set) var phase: Phase = .setup
    private(set) var isFilterReady = QuizVerseFilter.isReady
    private var questionBag: [VerseCandidate] = []
    private(set) var history: [QuizQuestion] = []
    private(set) var currentIndex: Int = -1
    private(set) var totalQuestions: Int = 0

    /// Score, streaks and best game; see `GameScore` for the rules.
    private(set) var session = GameScore()

    // Timer
    private(set) var remainingSeconds: Int = 0 {
        didSet { updateRedZone() }
    }
    /// Changes whenever the countdown should restart, so the view can restart its timer task.
    private(set) var timerID: Int = 0
    private(set) var isTimerDisabled = false
    private(set) var isPulsing = false
    /// True while the question is paused: the timer stops and the question is hidden.
    private(set) var isPaused = false
    private var wasInRedZone = false
    @ObservationIgnored private var pulseTask: Task<Void, Never>?
    /// Time spent on the current question. It's the authority for the countdown, so pausing
    /// and resuming can't give back part of a second.
    @ObservationIgnored private var questionClock = GameActiveClock()
    /// Seconds taken off the current question for revealing the previous verse.
    private var contextPenaltySeconds = 0

    // MARK: - Derived state

    private var persistentStreak: PersistentGameStreak {
        PersistentGameStreak(game: "quiz", variant: difficulty.rawValue)
    }

    /// Standard and Reverse score differently (only Standard has the chapter bonus), so each
    /// keeps its own best for every difficulty.
    private var bestGameScoreKey: String {
        (mode == .reverse ? GameBestScore.Kind.quizReverse : .quiz).key(difficulty: difficulty.rawValue)
    }

    /// A review of missed questions isn't comparable with a full game.
    private var roundCountsTowardBest: Bool { reviewQuestionIDs.isEmpty }

    /// The saved best in points for the chosen mode and difficulty, for the start screen.
    var bestPoints: Int { GameBestScore.value(forKey: bestGameScoreKey) }

    /// How the round just played compares with the saved best, for the summary.
    var roundBest: RoundBest? {
        guard roundCountsTowardBest, session.bestGameScore > 0 else { return nil }
        return RoundBest(points: session.bestGameScore, isNew: session.isNewBestGame)
    }

    var current: QuizQuestion? {
        history.indices.contains(currentIndex) ? history[currentIndex] : nil
    }

    var isAnswered: Bool { current?.outcome != nil }

    var timeLimit: Int? {
        guard mode == .reverse else { return difficulty.timeLimit }
        switch difficulty {
        case .easy: return nil
        case .normal: return 25
        case .hard: return 35
        }
    }

    var isTimed: Bool { timeLimit != nil }

    /// The current question's time, including any seconds the extra-time lifeline added.
    /// The speed bonus window still follows the base time.
    private var currentTimeLimit: Int? {
        timeLimit.map { $0 + (current?.bonusSeconds ?? 0) }
    }

    var isTimerRunning: Bool {
        phase == .playing && isTimed && !isTimerDisabled && !isAnswered && !isPaused
    }

    /// Only a question with its timer running can be paused. With "Timer Off" the question
    /// stays on screen and untimed, so there's nothing to pause.
    var canPause: Bool { isTimerRunning }

    var canGoNext: Bool { isAnswered }

    var isOnLastQuestion: Bool { history.count >= totalQuestions }

    var canRevealContext: Bool {
        guard mode == .standard, let current, current.contextText != nil, !current.contextRevealed,
              !isAnswered, !isPaused else { return false }
        return !isTimed || isTimerDisabled || remainingSeconds > difficulty.contextCost
    }

    var progressText: String {
        String(localized: "Question \(currentIndex + 1) of \(totalQuestions)")
    }

    /// Green, then yellow, then red as the question runs down, scaled to the time limit.
    var timerColor: Color {
        guard let timeLimit = currentTimeLimit else { return .secondary }
        let fraction = Double(remainingSeconds) / Double(max(1, timeLimit))
        if fraction <= 0.3 { return .red }
        if fraction <= 0.6 { return .yellow }
        return .green
    }

    // MARK: - Lifecycle

    func onAppear() {
        migrateLegacyScope()
        session.syncSavedBest(from: persistentStreak)
    }

    /// Sorts out list and repeated verses while the start screen is showing.
    func prepareFilter() async {
        await QuizVerseFilter.prepare()
        await Self.buildCandidateCache()
        isFilterReady = true
    }

    // MARK: - Verse cache

    /// Every quizzable verse, sorted out once per translation while the start screen shows, so
    /// starting an "Any verse" game doesn't check all 31,000 verses on the main thread.
    /// `standard` is for Easy and Normal; `hard` also leaves out verses too long for its timer.
    private static var candidateCache: (translation: BibleTranslation, standard: [VerseCandidate], hard: [VerseCandidate])?

    /// Builds the cache a book at a time, letting the screen draw in between.
    private static func buildCandidateCache() async {
        let translation = BibleRepository.shared.activeTranslation
        guard QuizVerseFilter.isReady, candidateCache?.translation != translation else { return }
        var standard: [VerseCandidate] = []
        var hard: [VerseCandidate] = []
        for book in BibleData.books {
            standard += candidates(in: book, difficultyKey: QuizDifficulty.normal.rawValue)
            hard += candidates(in: book, difficultyKey: QuizDifficulty.hard.rawValue)
            await Task.yield()
        }
        guard BibleRepository.shared.activeTranslation == translation, !standard.isEmpty else { return }
        candidateCache = (translation, standard, hard)
    }

    /// The quizzable verses in one book, each with the verse before it as context.
    private static func candidates(in book: Book, difficultyKey: String) -> [VerseCandidate] {
        book.chapters.flatMap { chapter in
            chapter.verses.indices.compactMap { index -> VerseCandidate? in
                let verse = chapter.verses[index]
                guard !verse.isOmitted, QuizVerseFilter.isQuizzable(
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
                    contextText: index > 0 && !chapter.verses[index - 1].isOmitted ? chapter.verses[index - 1].text : nil
                )
            }
        }
    }

    /// Every quizzable verse at a difficulty, from the cache when it's ready.
    private static func allCandidates(difficultyKey: String) -> [VerseCandidate] {
        if let cache = candidateCache, cache.translation == BibleRepository.shared.activeTranslation {
            return difficultyKey == QuizDifficulty.hard.rawValue ? cache.hard : cache.standard
        }
        return BibleData.books.flatMap { candidates(in: $0, difficultyKey: difficultyKey) }
    }

    func onDisappear() {
        // Leaving a timed question counts as running out of time, so backing out can't skip a
        // hard verse and keep the streak. Easy has no timer, so leaving it costs nothing.
        if phase == .playing, isTimed, current != nil, !isAnswered {
            finishQuestion(.timedOut, selected: nil)
        }
        // Leaving after answering begins a new game on return.
        if phase != .setup && session.answered > 0 {
            resetToSetup()
        }
        session.clearStreak()
    }

    /// Counts down the current question. Run from a task keyed on `timerID`, which changes for
    /// each question and each resume. The clock is the authority; the short polling interval
    /// only keeps the display current.
    func runTimer() async {
        while !Task.isCancelled, isTimerRunning, remainingSeconds > 0 {
            try? await sleep(.milliseconds(100))
            guard !Task.isCancelled, isTimerRunning else { return }
            updateRemainingTime()
        }
    }

    private func updateRemainingTime() {
        guard let timeLimit = currentTimeLimit else { return }
        let remaining = max(0, timeLimit - contextPenaltySeconds - Int(questionClock.elapsed(at: now())))
        guard remaining != remainingSeconds else { return }
        remainingSeconds = remaining
        if remainingSeconds == 0 {
            finishQuestion(.timedOut, selected: nil)
        }
    }

    /// The Testament picker was folded into the categories; apply an old choice once.
    private func migrateLegacyScope() {
        let defaults = UserDefaults.standard
        let legacyScope = defaults.string(forKey: Self.legacyScopeKey) ?? "whole"
        guard legacyScope == "old" || legacyScope == "new" else { return }
        let testamentSections = Set(QuizVerseSection.allCases.filter { $0.isOldTestament == (legacyScope == "old") })
        let kept = storedSections.intersection(testamentSections)
        selectedSections = kept.isEmpty ? testamentSections : kept
        defaults.set("whole", forKey: Self.legacyScopeKey)
    }

    // MARK: - Questions

    private func buildQuestionBag() -> [VerseCandidate] {
        // Explicit pools share Reverse's selection rules. Keep Standard's existing
        // difficulty filtering for Any verse and its separate missed-question review.
        if reviewQuestionIDs.isEmpty, pool != .any {
            var source = configuredReverseSource
            source.prepare()
            return source.buildQuestionBag().map { verse in
                let chapter = BibleData.books.first { $0.name == verse.bookName }?
                    .chapters.first { $0.number == verse.chapterNumber }
                let previousText = chapter?.verses.first { $0.number == verse.verseNumber - 1 }?.text
                return VerseCandidate(
                    text: verse.verseText, bookName: verse.bookName,
                    chapter: verse.chapterNumber, verse: verse.verseNumber,
                    contextText: previousText
                )
            }
        }
        let pool = poolBookNames
        let difficultyKey = reviewQuestionIDs.isEmpty ? difficulty.rawValue : QuizDifficulty.hard.rawValue
        // A review round replays every missed verse. The categories can't be changed while
        // reviewing, so filtering by them would hide verses missed under other categories.
        let isReview = !reviewQuestionIDs.isEmpty
        return Self.allCandidates(difficultyKey: difficultyKey)
            .filter { isReview || pool.contains($0.bookName) }
            .shuffled()
    }

    /// Picks three wrong books, drawing from each list in turn until there are enough.
    private func wrongChoices(for correctBook: String) -> [String] {
        let canon = BibleCanon.fallbackCanon
        let pool = poolBookNames
        let section = QuizVerseSection.containing(correctBook)
        let isOld = section?.isOldTestament ?? true
        let sameTestament = canon.filter { QuizVerseSection.containing($0)?.isOldTestament == isOld }

        let tiers: [[String]]
        switch difficulty {
        case .easy:
            let otherSections = canon.filter { QuizVerseSection.containing($0) != section }
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
        if mode == .reverse {
            while let verse = reverseBag.popLast() {
                guard let wrong = reverseSource?.wrongChoices(for: verse), wrong.count == 3 else { continue }
                let options = (wrong + [verse]).shuffled()
                return QuizQuestion(
                    verseText: verse.verseText, correctBook: verse.bookName,
                    chapter: verse.chapterNumber, verse: verse.verseNumber, contextText: nil,
                    options: options.map(\.verseText),
                    mode: .reverse,
                    optionVerses: options
                )
            }
            return nil
        }
        guard let candidate = questionBag.popLast() else { return nil }
        var question = QuizQuestion(
            verseText: candidate.text,
            correctBook: candidate.bookName,
            chapter: candidate.chapter,
            verse: candidate.verse,
            contextText: candidate.contextText,
            options: (wrongChoices(for: candidate.bookName) + [candidate.bookName]).shuffled()
        )
        if difficulty != .easy {
            question.chapterOptions = chapterChoices(for: candidate)
        }
        return question
    }

    /// The right chapter and up to three others close to it, in order. Empty for a book with
    /// one chapter, which would make the bonus free.
    private func chapterChoices(for candidate: VerseCandidate) -> [Int] {
        let chapterCount = BibleData.books.first { $0.name == candidate.bookName }?.chapters.count ?? 0
        guard chapterCount > 1 else { return [] }
        let others = Array(1...chapterCount).filter { $0 != candidate.chapter }
        // Nearby chapters first, so the bonus asks for real knowledge rather than a rough guess.
        let nearby = others.filter { abs($0 - candidate.chapter) <= 5 }.shuffled()
        let rest = others.filter { abs($0 - candidate.chapter) > 5 }.shuffled()
        return (Array((nearby + rest).prefix(3)) + [candidate.chapter]).sorted()
    }

    // MARK: - Game flow

    /// Starts a game from the chosen settings.
    func startQuiz() {
        beginQuiz()
    }

    private func beginQuiz() {
        guard canStart else { return }
        if mode == .reverse {
            var source = configuredReverseSource
            source.prepare()
            reverseSource = source
            reverseBag = reviewQuestionIDs.isEmpty
                ? selectQuestions(from: source.buildQuestionBag(), id: \.reference)
                : source.reviewVerses().filter { reviewQuestionIDs.contains($0.reference) }.shuffled()
            guard !reverseBag.isEmpty else { return }
            totalQuestions = min(Self.questionsPerGame, reverseBag.count)
        } else {
            questionBag = buildQuestionBag()
            if reviewQuestionIDs.isEmpty {
                questionBag = selectQuestions(from: questionBag, id: \.reviewID)
            } else {
                questionBag = questionBag.filter { reviewQuestionIDs.contains($0.reviewID) }
            }
            guard !questionBag.isEmpty else { return }
            totalQuestions = min(Self.questionsPerGame, questionBag.count)
        }
        history = []
        currentIndex = -1
        session.beginGame(savedStreak: persistentStreak, isTimed: isTimed)
        isTimerDisabled = false
        phase = .playing
        appendNextQuestion()
    }

    /// Where shown questions are remembered. Well-known and Favorites are small enough to go
    /// through in full, so each mode, pool and set of categories keeps its own pass. Any verse
    /// has thousands, so it keeps the original short cooldown per mode.
    private var recencyGameKey: String {
        guard pool != .any else { return "quiz-\(mode.rawValue)" }
        let sections = QuizVerseSection.allCases
            .filter { selectedSections.contains($0) }
            .map(\.rawValue)
            .joined(separator: ",")
        return "quiz-\(mode.rawValue).\(pool.rawValue).\(sections)"
    }

    private func selectQuestions<T>(from candidates: [T], id: (T) -> String) -> [T] {
        if pool == .any {
            return RecentGameQuestionStore.shared.select(
                from: candidates,
                game: recencyGameKey,
                count: Self.questionsPerGame,
                cooldown: Self.questionsPerGame * 7,
                id: id
            )
        }
        return RecentGameQuestionStore.shared.selectCycling(
            from: candidates,
            game: recencyGameKey,
            count: Self.questionsPerGame,
            id: id
        )
    }

    private func appendNextQuestion() {
        guard let question = makeQuestion() else {
            totalQuestions = history.count
            showResults()
            return
        }
        history.append(question)
        RecentGameQuestionStore.shared.record([question.reviewID], game: recencyGameKey)
        currentIndex = history.count - 1
        session.startQuestion()
        remainingSeconds = timeLimit ?? 0
        contextPenaltySeconds = 0
        questionClock.start(at: now())
        if isTimerDisabled {
            questionClock.pause(at: now())
            history[currentIndex].wasTimerOff = true
        }
        wasInRedZone = false
        stopTimerPulse()
        isPaused = false
        timerID += 1
    }

    private func showResults() {
        session.finishGame(bestScoreKey: bestGameScoreKey, points: points, savesBest: roundCountsTowardBest)
        phase = .results
    }

    func resetToSetup() {
        questionClock.pause(at: now())
        phase = .setup
        isPaused = false
        history = []
        currentIndex = -1
        questionBag = []
        reverseBag = []
        reverseSource = nil
        remainingSeconds = 0
        session.clearGame()
    }

    func showNext() {
        if history.count >= totalQuestions {
            showResults()
        } else {
            appendNextQuestion()
        }
    }

    func revealContext() {
        guard canRevealContext else { return }
        history[currentIndex].contextRevealed = true
        if !isTimerDisabled {
            contextPenaltySeconds += difficulty.contextCost
            updateRemainingTime()
        }
    }

    // MARK: - Pausing

    /// Stops the clock and hides the question until `resume()`.
    func pause() {
        guard canPause else { return }
        questionClock.pause(at: now())
        isPaused = true
        stopTimerPulse()
    }

    /// Carries on from the time already used.
    func resume() {
        guard isPaused else { return }
        isPaused = false
        questionClock.resume(at: now())
        timerID += 1
    }

    func toggleTimer() {
        guard isTimed else { return }
        isTimerDisabled.toggle()
        if isTimerDisabled {
            session.noteTimerTurnedOff()
            questionClock.pause(at: now())
            if history.indices.contains(currentIndex) {
                history[currentIndex].wasTimerOff = true
            }
        } else {
            questionClock.resume(at: now())
        }
        stopTimerPulse()
        timerID += 1
    }

    func selectOption(_ name: String) {
        guard let current, current.options.contains(name), !current.removedOptions.contains(name), !isPaused else { return }
        finishQuestion(name == current.correctAnswer ? .correct : .incorrect, selected: name)
    }

    /// Records the answer (or timeout) on the latest question, so it can't be answered again.
    private func finishQuestion(_ outcome: QuizOutcome, selected: String?) {
        guard phase == .playing, let current, current.outcome == nil else { return }
        history[currentIndex].outcome = outcome
        history[currentIndex].selected = selected
        questionClock.pause(at: now())
        stopTimerPulse()

        let correct = outcome == .correct
        // A quick answer with the timer on the whole time earns a bonus point.
        if correct, let timeLimit, !history[currentIndex].wasTimerOff {
            history[currentIndex].earnedSpeedBonus = questionClock.elapsed(at: now()) <= Double(timeLimit) / 3
        }
        // The chapter bonus only follows a correct book.
        if !correct {
            history[currentIndex].chapterOptions = []
        }
        session.record(
            GameRoundEntry(
                prompt: current.prompt,
                outcome: correct ? .correct : (outcome == .timedOut ? .timedOut : .wrong),
                givenAnswer: selected,
                correctAnswer: current.correctAnswer,
                category: QuizVerseSection.containing(current.correctBook).map { String(localized: $0.title) },
                bookName: current.correctBook,
                reference: "\(current.correctBook) \(current.chapter):\(current.verse)",
                hintCount: current.hintCount
            ),
            savedStreak: persistentStreak
        )

        GameStats.shared.recordRound(
            game: .quiz,
            difficulty: difficulty.statsDifficulty,
            correct: correct ? 1 : 0,
            answered: 1,
            currentBestStreak: session.savedBestStreak
        )
        GameStats.shared.recordQuizPerBook(bookName: current.correctBook, answered: 1, correct: correct ? 1 : 0)
        GameStats.shared.recordModeAnswer(.quiz, mode: current.mode.rawValue, correct: correct)
        if correct, !reviewQuestionIDs.isEmpty {
            missedQuestions.resolveReviewQuestion(
                game: mode == .reverse ? .quizReverse : .bibleQuiz,
                questionID: current.reviewID
            )
        } else if !correct {
            missedQuestions.record(
                game: mode == .reverse ? .quizReverse : .bibleQuiz,
                bookNames: [current.correctBook],
                chapterNumber: current.chapter,
                topic: mode == .reverse ? "Verse matching" : "Book identification",
                questionID: current.reviewID
            )
        }

        switch outcome {
        case .correct: Haptics.success()
        case .incorrect: Haptics.error()
        case .timedOut: Haptics.warning()
        }
    }

    // MARK: - Lifelines

    /// Lifelines already used this round; each can be used once.
    var usedLifelines: Set<QuizLifeline> {
        history.reduce(into: []) { $0.formUnion($1.lifelinesUsed) }
    }

    /// The lifelines a round will offer in the current mode and difficulty, for the start screen.
    var lifelinesForRound: [QuizLifeline] {
        QuizLifeline.allCases.filter { lifeline in
            // On Hard every choice is from the same part of the Bible, so that hint says nothing.
            offers(lifeline) && !(lifeline == .sectionHint && difficulty == .hard)
        }
    }

    /// The lifelines still in the row: offered by this game and not yet used.
    var availableLifelines: [QuizLifeline] {
        QuizLifeline.allCases.filter { offers($0) && !usedLifelines.contains($0) }
    }

    /// Whether this kind of game has the lifeline at all, used or not.
    func offers(_ lifeline: QuizLifeline) -> Bool {
        switch lifeline {
        case .fiftyFifty: true
        case .sectionHint: mode == .standard
        case .extraTime: isTimed
        }
    }

    func canUse(_ lifeline: QuizLifeline) -> Bool {
        guard phase == .playing, let current, !isAnswered, !isPaused,
              offers(lifeline), !usedLifelines.contains(lifeline) else { return false }
        switch lifeline {
        case .fiftyFifty:
            return current.options.count - current.removedOptions.count > 2
        case .sectionHint:
            // On Hard every choice is from the same part of the Bible, so the hint says nothing.
            let sections = Set(current.options.compactMap(QuizVerseSection.containing))
            return sections.count > 1
        case .extraTime:
            return !isTimerDisabled
        }
    }

    func use(_ lifeline: QuizLifeline) {
        guard canUse(lifeline), let current else { return }
        history[currentIndex].lifelinesUsed.insert(lifeline)
        if lifeline == .fiftyFifty {
            let wrong = current.options.filter { $0 != current.correctAnswer }.shuffled()
            history[currentIndex].removedOptions = Set(wrong.prefix(2))
        }
        if lifeline == .extraTime {
            history[currentIndex].bonusSeconds += QuizLifeline.extraSeconds
            updateRemainingTime()
        }
        Haptics.selection()
    }

    /// "It's from the Gospels", once the section hint is used on this question.
    var sectionHint: String? {
        guard let current, current.lifelinesUsed.contains(.sectionHint),
              let section = QuizVerseSection.containing(current.correctBook) else { return nil }
        return String(localized: "It's from \(section.hintPhrase).")
    }

    // MARK: - After answering

    /// For a wrong book that was close: the right part of the Bible, or on Hard, where every
    /// choice is from that part, a book right next to the answer.
    var closeGuessNote: String? {
        guard let current, mode == .standard, current.outcome == .incorrect, let selected = current.selected,
              let section = QuizVerseSection.containing(current.correctBook) else { return nil }
        if difficulty == .hard {
            let canon = BibleCanon.fallbackCanon
            guard let guessIndex = canon.firstIndex(of: selected),
                  let answerIndex = canon.firstIndex(of: current.correctBook),
                  abs(guessIndex - answerIndex) == 1 else { return nil }
            return String(localized: "So close: \(selected) is right next to \(current.correctBook).")
        }
        guard QuizVerseSection.containing(selected) == section else { return nil }
        return String(localized: "Right section: \(String(localized: section.title)).")
    }

    /// The chapter bonus is offered after a correct book, until a chapter is picked.
    var isChapterBonusOpen: Bool {
        guard let current else { return false }
        return current.outcome == .correct && !current.chapterOptions.isEmpty && current.chapterGuess == nil
    }

    func guessChapter(_ chapter: Int) {
        guard isChapterBonusOpen, let current, current.chapterOptions.contains(chapter) else { return }
        history[currentIndex].chapterGuess = chapter
        if chapter == current.chapter { Haptics.success() } else { Haptics.error() }
    }

    // MARK: - Points

    var speedBonusCount: Int { history.count(where: \.earnedSpeedBonus) }
    var chapterBonusCount: Int { history.count(where: \.earnedChapterBonus) }

    /// Correct books plus speed and chapter bonuses.
    var points: Int { session.score + speedBonusCount + chapterBonusCount }

    /// How the points add up, for the summary. Nil when there were no bonuses.
    var roundPoints: RoundPoints? {
        RoundPoints(
            correct: session.score,
            bonuses: [RoundPoints.speed(speedBonusCount), RoundPoints.chapter(chapterBonusCount)]
        )
    }

    // MARK: - Timer pulse

    /// Starts the pulse the moment a running timer crosses into the red zone.
    private func updateRedZone() {
        guard isTimerRunning, let timeLimit = currentTimeLimit else { return }
        // The same threshold as `timerColor`'s red, worked out from the time rather than the color.
        let inRed = Double(remainingSeconds) / Double(max(1, timeLimit)) <= 0.3
        if inRed && !wasInRedZone {
            startTimerPulse()
        }
        wasInRedZone = inRed
    }

    /// Flashes the timer when it enters the red zone; the timer views animate the change.
    /// The task is cancelled when the question ends or the timer is reset, so a late toggle
    /// can't leave the timer lit.
    private func startTimerPulse() {
        pulseTask?.cancel()
        pulseTask = Task { @MainActor [weak self] in
            for _ in 0..<6 {
                guard let self, !Task.isCancelled else { return }
                isPulsing.toggle()
                try? await sleep(.milliseconds(250))
            }
            guard let self else { return }
            guard !Task.isCancelled else { return }
            isPulsing = false
        }
    }

    private func stopTimerPulse() {
        pulseTask?.cancel()
        pulseTask = nil
        isPulsing = false
    }
}
