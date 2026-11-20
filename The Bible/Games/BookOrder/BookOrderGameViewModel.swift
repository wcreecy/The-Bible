import Foundation
import Observation
import SwiftUI

enum BookOrderDifficulty: String, CaseIterable, Identifiable {
    case easy, normal, hard
    /// All 66 books in canonical order. Stored as "all" to preserve existing settings and streaks.
    case fullBible = "all"

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .easy: "Easy"
        case .normal: "Normal"
        case .hard: "Hard"
        case .fullBible: "Full Bible"
        }
    }

    /// Books in a Tap in Order puzzle: enough to fill the screen without scrolling.
    var tapRunLength: Int {
        switch self {
        case .easy: 5
        case .normal: 7
        case .hard, .fullBible: 9
        }
    }

    /// Books in a round, or nil for the full Bible mode.
    var runLength: Int? {
        switch self {
        case .easy: 5
        case .normal: 10
        case .hard: 15
        case .fullBible: nil
        }
    }

    var statsDifficulty: GameStats.Difficulty {
        switch self {
        case .easy: .easy
        case .normal: .normal
        case .hard: .hard
        case .fullBible: .none
        }
    }
}

enum BookSourceScope: String, CaseIterable, Identifiable {
    case both, ot, nt
    case law, history, poetry, majorProphets, minorProphets
    case gospels, epistles

    var id: String { rawValue }

    var title: LocalizedStringResource {
        return switch self {
        case .both: "Whole Bible"
        case .ot: "Old Testament"
        case .nt: "New Testament"
        case .law: "Law"
        case .history: "History"
        case .poetry: "Poetry"
        case .majorProphets: "Major Prophets"
        case .minorProphets: "Minor Prophets"
        case .gospels: "Gospels"
        case .epistles: "Epistles"
        }
    }

    var isCategory: Bool {
        switch self {
        case .both, .ot, .nt: false
        default: true
        }
    }

    /// The books in this part of the Bible, in canonical order.
    var bookNames: [String] {
        let canon = BibleCanon.canonicalOrder()

        func books(from first: String, through last: String) -> [String] {
            guard let firstIndex = canon.firstIndex(of: first),
                  let lastIndex = canon.firstIndex(of: last),
                  firstIndex <= lastIndex else { return [] }
            return Array(canon[firstIndex...lastIndex])
        }

        return switch self {
        case .both: canon
        case .ot: books(from: "Genesis", through: "Malachi")
        case .nt: books(from: "Matthew", through: "Revelation")
        case .law: books(from: "Genesis", through: "Deuteronomy")
        case .history: books(from: "Joshua", through: "Esther")
        case .poetry: books(from: "Job", through: "Song of Solomon")
        case .majorProphets: books(from: "Isaiah", through: "Daniel")
        case .minorProphets: books(from: "Hosea", through: "Malachi")
        case .gospels: books(from: "Matthew", through: "John")
        case .epistles: books(from: "Romans", through: "Jude")
        }
    }

    var previewBookNames: [String] {
        Array(bookNames.prefix(3))
    }
}

struct BibleCanon {
    static let fallbackCanon: [String] = [
        "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy",
        "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel",
        "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra",
        "Nehemiah", "Esther", "Job", "Psalms", "Proverbs",
        "Ecclesiastes", "Song of Solomon", "Isaiah", "Jeremiah", "Lamentations",
        "Ezekiel", "Daniel", "Hosea", "Joel", "Amos",
        "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk",
        "Zephaniah", "Haggai", "Zechariah", "Malachi",
        "Matthew", "Mark", "Luke", "John", "Acts",
        "Romans", "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians",
        "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians", "1 Timothy",
        "2 Timothy", "Titus", "Philemon", "Hebrews", "James",
        "1 Peter", "2 Peter", "1 John", "2 John", "3 John",
        "Jude", "Revelation"
    ]

    static func canonicalOrder() -> [String] {
        if !BibleData.books.isEmpty {
            return BibleData.books.map { $0.name }
        }
        return fallbackCanon
    }
}

@MainActor
@Observable
final class BookOrderGameViewModel {
    private static let difficultyKey = AppStorageKey.bookOrderDifficulty
    private static let sourceKey = AppStorageKey.bookOrderSource
    private static let lastSeenKey = AppStorageKey.bookOrderBookLastSeen
    private static let savedPuzzlesKey = AppStorageKey.bookOrderSavedPuzzles
    private static let modeKey = AppStorageKey.bookOrderMode

    /// How the game is played. Classic is iPad-only; `playMode(isWide:)` stands it in for
    /// Tap in Order on iPhone.
    var mode: BookOrderMode = BookOrderMode(
        rawValue: UserDefaults.standard.string(forKey: BookOrderGameViewModel.modeKey) ?? ""
    ) ?? .tapInOrder {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Self.modeKey) }
    }

    /// The mode to play on this screen size: Classic needs the room of an iPad.
    func playMode(isWide: Bool) -> BookOrderMode {
        mode == .classic && !isWide ? .tapInOrder : mode
    }

    /// The puzzle being played: Tap in Order or Classic.
    private(set) var puzzleMode: BookOrderMode = .tapInOrder

    // Tap in Order
    /// Books tapped in order so far.
    private(set) var tapPlaced: [String] = []
    /// Books tapped too early, which count as missed.
    private(set) var wrongTapBooks: Set<String> = []
    /// What the last wrong tap got wrong, e.g. "Amos comes after Joel".
    private(set) var wrongTapHint: String?
    /// Changes on each wrong tap, so the view can shake the tile.
    private(set) var wrongTapCount = 0

    var started: Bool = false
    var currentItems: [String] = []
    var correctOrder: [String] = []
    /// Score and streaks; see `GameScore` for the rules. The session streak counts correct
    /// puzzles in a row during this visit.
    private(set) var session = GameScore()
    var showResult: Bool = false
    var wasCorrect: Bool = false

    // Result of the last check
    /// Books already in Bible order relative to each other; the rest needed moving.
    var booksInOrder: Int = 0
    var lastTimeSeconds: Int = 0
    var bestTimeSeconds: Int?
    var isNewBestTime: Bool = false
    /// The last check's time against the best saved before it.
    private(set) var bestTimeComparison: GameBestTimeComparison?
    /// Books from the last check that needed moving, in Bible order.
    private(set) var booksToReview: [BookOrderReviewItem] = []
    /// True when the last check raised the saved best streak.
    private(set) var isNewBestStreak = false

    /// The difficulty the player picked. Kept when the section changes, even if the section is
    /// too small for it; rounds use `effectiveDifficulty`.
    var difficulty: BookOrderDifficulty = BookOrderDifficulty(
        rawValue: UserDefaults.standard.string(forKey: BookOrderGameViewModel.difficultyKey) ?? ""
    ) ?? .normal {
        didSet {
            UserDefaults.standard.set(difficulty.rawValue, forKey: Self.difficultyKey)
            session.syncSavedBest(from: persistentStreak)
        }
    }

    var source: BookSourceScope = BookSourceScope(
        rawValue: UserDefaults.standard.string(forKey: BookOrderGameViewModel.sourceKey) ?? ""
    ) ?? .both {
        didSet {
            UserDefaults.standard.set(source.rawValue, forKey: Self.sourceKey)
            session.syncSavedBest(from: persistentStreak)
        }
    }

    // MARK: - Difficulty for the chosen section

    private static let roundLevels: [BookOrderDifficulty] = [.easy, .normal, .hard]

    /// The level a round really plays at. When a section has no more books than a shorter
    /// level uses, every higher level is the same puzzle, so it counts as that shorter level.
    static func effectiveDifficulty(_ difficulty: BookOrderDifficulty, bookCount: Int) -> BookOrderDifficulty {
        guard let runLength = difficulty.runLength, runLength >= bookCount else { return difficulty }
        return roundLevels.first { ($0.runLength ?? 0) >= bookCount } ?? difficulty
    }

    var effectiveDifficulty: BookOrderDifficulty {
        puzzleMode == .tapInOrder
            ? Self.tapEffectiveDifficulty(difficulty, bookCount: source.bookNames.count)
            : Self.effectiveDifficulty(difficulty, bookCount: source.bookNames.count)
    }

    /// The same for Tap in Order, which has no full-Bible puzzle: a small section plays at the
    /// shortest level that uses all its books.
    static func tapEffectiveDifficulty(_ difficulty: BookOrderDifficulty, bookCount: Int) -> BookOrderDifficulty {
        let level = difficulty == .fullBible ? .hard : difficulty
        guard level.tapRunLength >= bookCount else { return level }
        return roundLevels.first { $0.tapRunLength >= bookCount } ?? level
    }

    /// The levels that give different puzzles for the chosen section. Gospels (4 books) has only Easy.
    var availableLevels: [BookOrderDifficulty] {
        let bookCount = source.bookNames.count
        return puzzleMode == .tapInOrder
            ? Self.roundLevels.filter { Self.tapEffectiveDifficulty($0, bookCount: bookCount) == $0 }
            : Self.roundLevels.filter { Self.effectiveDifficulty($0, bookCount: bookCount) == $0 }
    }

    /// Books in a puzzle at a level for the chosen section.
    func bookCount(for level: BookOrderDifficulty) -> Int {
        let available = source.bookNames.count
        let length = puzzleMode == .tapInOrder ? level.tapRunLength : (level.runLength ?? available)
        return min(length, available)
    }

    /// Sets which puzzle the settings describe, before starting it or showing its setup.
    func preparePuzzle(_ mode: BookOrderMode) {
        guard mode.isPuzzle else { return }
        puzzleMode = mode
        session.syncSavedBest(from: persistentStreak)
    }

    /// Books in each puzzle for the current settings.
    var roundBookCount: Int { bookCount(for: effectiveDifficulty) }

    // MARK: - Persistent streak and best time (per section and difficulty)

    /// Whole Bible keeps the original per-difficulty keys, so existing streaks carry over.
    private var settingsVariant: String {
        let classic = source == .both ? effectiveDifficulty.rawValue : "\(source.rawValue)_\(effectiveDifficulty.rawValue)"
        // Tap in Order keeps its own streak and best time; its puzzles are a different size.
        return puzzleMode == .tapInOrder ? "tap_\(source.rawValue)_\(effectiveDifficulty.rawValue)" : classic
    }

    private var persistentStreak: PersistentGameStreak {
        PersistentGameStreak(game: "bookorder", variant: settingsVariant)
    }

    var persistentBestStreak: Int { persistentStreak.best }

    private var bestTimeKey: String {
        puzzleMode == .tapInOrder
            ? "bookorderBestTime_tap_\(source.rawValue)_\(effectiveDifficulty.rawValue)"
            : "bookorderBestTime_\(source.rawValue)_\(effectiveDifficulty.rawValue)"
    }

    /// Fastest fully correct puzzle for the current settings.
    var savedBestTime: Int? {
        let value = UserDefaults.standard.integer(forKey: bestTimeKey)
        return value > 0 ? value : nil
    }

    // MARK: - Saved puzzles
    // An unchecked puzzle is saved when the player leaves, so leaving can't be used to skip a
    // hard one. Each section and difficulty keeps its own, so changing settings doesn't skip it either.

    struct SavedPuzzle: Codable, Equatable {
        let correctOrder: [String]
        let currentItems: [String]
        let elapsedSeconds: Int
        /// Tap in Order: how many books were tapped in order, and which were tapped too early.
        var placedCount: Int?
        var wrongTapBooks: [String]?
    }

    private var savedPuzzleKey: String {
        puzzleMode == .tapInOrder
            ? "tap_\(source.rawValue)_\(effectiveDifficulty.rawValue)"
            : "\(source.rawValue)_\(effectiveDifficulty.rawValue)"
    }

    private static func loadSavedPuzzles() -> [String: SavedPuzzle] {
        guard let data = UserDefaults.standard.data(forKey: savedPuzzlesKey) else { return [:] }
        return PersistedDecoding.decode(
            [String: SavedPuzzle].self, from: data, key: savedPuzzlesKey, keepingUnreadableIn: .standard
        ) ?? [:]
    }

    private static func storeSavedPuzzles(_ puzzles: [String: SavedPuzzle]) {
        guard let data = try? JSONEncoder().encode(puzzles) else { return }
        UserDefaults.standard.set(data, forKey: savedPuzzlesKey)
    }

    /// The saved puzzle for the current settings, if it still fits them.
    private var savedPuzzle: SavedPuzzle? {
        guard let puzzle = Self.loadSavedPuzzles()[savedPuzzleKey],
              puzzle.correctOrder.count == roundBookCount,
              Set(puzzle.currentItems) == Set(puzzle.correctOrder),
              puzzle.currentItems.count == puzzle.correctOrder.count,
              Set(puzzle.correctOrder).isSubset(of: source.bookNames) else { return nil }
        return puzzle
    }

    /// True when Start would resume an unchecked puzzle.
    var hasSavedPuzzle: Bool { savedPuzzle != nil }

    /// Saves the puzzle on screen if it hasn't been checked yet.
    func savePuzzle(elapsedSeconds: Int) {
        guard started, !showResult, !correctOrder.isEmpty else { return }
        var puzzles = Self.loadSavedPuzzles()
        puzzles[savedPuzzleKey] = SavedPuzzle(
            correctOrder: correctOrder,
            currentItems: currentItems,
            elapsedSeconds: elapsedSeconds,
            placedCount: puzzleMode == .tapInOrder ? tapPlaced.count : nil,
            wrongTapBooks: puzzleMode == .tapInOrder ? Array(wrongTapBooks) : nil
        )
        Self.storeSavedPuzzles(puzzles)
    }

    private func clearSavedPuzzle() {
        var puzzles = Self.loadSavedPuzzles()
        guard puzzles.removeValue(forKey: savedPuzzleKey) != nil else { return }
        Self.storeSavedPuzzles(puzzles)
    }

    // MARK: - Game flow

    /// Starts a game, resuming the saved puzzle for these settings if there is one.
    /// Returns the seconds already spent on the puzzle, so the clock can carry on from there.
    @discardableResult
    func startGame() -> Int {
        // The session streak carries from one game to the next.
        // Do NOT reset persistent streaks here; seed from persistence
        session.beginGame(savedStreak: persistentStreak)
        started = true

        if let puzzle = savedPuzzle {
            resetResult()
            correctOrder = puzzle.correctOrder
            currentItems = puzzle.currentItems
            tapPlaced = Array(puzzle.correctOrder.prefix(puzzle.placedCount ?? 0))
            wrongTapBooks = Set(puzzle.wrongTapBooks ?? [])
            return puzzle.elapsedSeconds
        }
        nextRound()
        return 0
    }

    func endGame() {
        started = false
        showResult = false
        session.clearGame()
    }

    func onDisappear() {
        // Leaving after answering begins a new game on return.
        if started, session.answered > 0 {
            endGame()
        }
        session.clearStreak()
    }

    private func resetResult() {
        showResult = false
        wasCorrect = false
        booksInOrder = 0
        isNewBestTime = false
        bestTimeComparison = nil
        booksToReview = []
        isNewBestStreak = false
        tapPlaced = []
        wrongTapBooks = []
        wrongTapHint = nil
    }

    /// Picks a run of books in a row from the chosen part and shuffles it.
    func nextRound() {
        resetResult()

        let books = source.bookNames
        guard !books.isEmpty else {
            currentItems = []
            correctOrder = []
            return
        }

        var generator = SystemRandomNumberGenerator()
        let length = roundBookCount
        let start = Self.runStart(books: books, length: length, lastSeen: Self.loadLastSeen(), using: &generator)
        let run = Array(books[start..<(start + length)])
        correctOrder = run
        currentItems = Self.scrambled(run, using: &generator)
        Self.recordSeen(run)
    }

    // MARK: - Choosing and shuffling a puzzle

    /// Where the next run starts. Each puzzle is built around the book shown longest ago, so every
    /// book comes up in turn. Without this, books near the ends (Genesis, Revelation) fit in so
    /// few runs that they'd rarely appear.
    static func runStart<G: RandomNumberGenerator>(
        books: [String],
        length: Int,
        lastSeen: [String: Int],
        using generator: inout G
    ) -> Int {
        let lastStart = books.count - length
        guard lastStart > 0 else { return 0 }

        // Never-shown books come first; ties are broken at random.
        let stalest = books.shuffled(using: &generator).min { (lastSeen[$0] ?? -1) < (lastSeen[$1] ?? -1) }
        guard let stalest, let index = books.firstIndex(of: stalest) else {
            return Int.random(in: 0...lastStart, using: &generator)
        }
        // Any run that includes it.
        let lowest = max(0, index - length + 1)
        let highest = min(lastStart, index)
        return Int.random(in: lowest...highest, using: &generator)
    }

    /// Shuffles a run so that at most half the books start out already in order.
    static func scrambled<G: RandomNumberGenerator>(_ run: [String], using generator: inout G) -> [String] {
        guard run.count > 1 else { return run }
        let limit = max(1, run.count / 2)
        for _ in 0..<200 {
            let shuffled = run.shuffled(using: &generator)
            if inOrderPositions(current: shuffled, correct: run).count <= limit {
                return shuffled
            }
        }
        return run.reversed()
    }

    /// When each book was last in a puzzle, as an increasing counter.
    private static func loadLastSeen() -> [String: Int] {
        (UserDefaults.standard.dictionary(forKey: lastSeenKey) as? [String: Int]) ?? [:]
    }

    private static func recordSeen(_ books: [String]) {
        var lastSeen = loadLastSeen()
        let tick = (lastSeen.values.max() ?? 0) + 1
        for book in books {
            lastSeen[book] = tick
        }
        UserDefaults.standard.set(lastSeen, forKey: lastSeenKey)
    }

    // MARK: - Checking

    /// Whether the book at a position needed moving, once checked.
    func needsMoving(_ book: String) -> Bool {
        booksToReview.contains { $0.book == book }
    }

    /// How to fix a misplaced book, e.g. "Goes after Micah", once checked.
    func moveHint(for book: String) -> String? {
        booksToReview.first { $0.book == book }?.placementHint
    }

    // MARK: - Tap in Order

    /// The next book to tap, or nil once the puzzle is done.
    var nextBookToTap: String? {
        correctOrder.indices.contains(tapPlaced.count) ? correctOrder[tapPlaced.count] : nil
    }

    /// A tap on a book tile. The right next book joins the row; any other is a mistake, and
    /// the puzzle says where that book goes. Tapping the last book finishes the puzzle.
    func tap(_ book: String, elapsedSeconds: Int) {
        guard puzzleMode == .tapInOrder, !showResult, !tapPlaced.contains(book), let next = nextBookToTap else { return }
        if book == next {
            tapPlaced.append(book)
            wrongTapHint = nil
            Haptics.selection()
            if tapPlaced.count == correctOrder.count {
                finishTapPuzzle(elapsedSeconds: elapsedSeconds)
            }
        } else {
            wrongTapBooks.insert(book)
            // Where the tapped book goes, by its neighbors in Bible order.
            if let index = correctOrder.firstIndex(of: book) {
                wrongTapHint = BookOrderReviewItem(
                    book: book,
                    previousBook: index > 0 ? correctOrder[index - 1] : nil,
                    nextBook: index + 1 < correctOrder.count ? correctOrder[index + 1] : nil
                ).hint
            } else {
                wrongTapHint = String(localized: "\(book) isn't next")
            }
            wrongTapCount += 1
            Haptics.error()
        }
    }

    private func finishTapPuzzle(elapsedSeconds: Int) {
        let missed = wrongTapBooks
        booksInOrder = correctOrder.count - missed.count
        booksToReview = correctOrder.indices.compactMap { index in
            guard missed.contains(correctOrder[index]) else { return nil }
            return BookOrderReviewItem(
                book: correctOrder[index],
                previousBook: index > 0 ? correctOrder[index - 1] : nil,
                nextBook: index + 1 < correctOrder.count ? correctOrder[index + 1] : nil
            )
        }
        finishPuzzle(elapsedSeconds: elapsedSeconds, wasCorrect: missed.isEmpty)
    }

    // MARK: - Classic

    func checkOrder(elapsedSeconds: Int) {
        guard !showResult, !currentItems.isEmpty, !correctOrder.isEmpty else { return }

        booksInOrder = Self.inOrderPositions(current: currentItems, correct: correctOrder).count
        booksToReview = Self.reviewItems(current: currentItems, correct: correctOrder)
        finishPuzzle(elapsedSeconds: elapsedSeconds, wasCorrect: currentItems == correctOrder)
    }

    /// Records a finished puzzle: the streak, stats, best time and missed books.
    private func finishPuzzle(elapsedSeconds: Int, wasCorrect: Bool) {
        self.wasCorrect = wasCorrect
        lastTimeSeconds = elapsedSeconds
        let bestStreakBefore = persistentStreak.best
        session.record(correct: wasCorrect, savedStreak: persistentStreak)
        isNewBestStreak = persistentStreak.best > bestStreakBefore
        bestTimeComparison = GameBestTimeComparison(
            seconds: max(1, elapsedSeconds),
            previousBest: savedBestTime,
            isSolved: wasCorrect
        )
        recordMissedBooks()
        clearSavedPuzzle()

        if wasCorrect {
            let previousBest = savedBestTime
            isNewBestTime = previousBest.map { elapsedSeconds < $0 } ?? true
            if isNewBestTime {
                UserDefaults.standard.set(max(1, elapsedSeconds), forKey: bestTimeKey)
            }
        }
        bestTimeSeconds = savedBestTime

        GameStats.shared.recordRound(
            game: .bookorder,
            difficulty: effectiveDifficulty.statsDifficulty,
            correct: wasCorrect ? 1 : 0,
            answered: 1,
            currentBestStreak: session.savedBestStreak
        )
        GameStats.shared.recordModeAnswer(.bookorder, mode: puzzleMode.rawValue, correct: wasCorrect)
        if wasCorrect {
            GameStats.shared.recordModeSolveTime(.bookorder, mode: puzzleMode.rawValue, seconds: elapsedSeconds)
        }

        showResult = true
    }

    /// Positions in `current` whose books are already in Bible order relative to each other:
    /// the longest such set, which may skip rows. Only the other books need moving, so one
    /// book out of place doesn't mark the rest wrong.
    static func inOrderPositions(current: [String], correct: [String]) -> Set<Int> {
        let rank = Dictionary(correct.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let ranks = current.map { rank[$0] }

        // Longest increasing run of ranks, by dynamic programming (puzzles are at most 66 books).
        var length = Array(repeating: 0, count: ranks.count)
        var previous = Array(repeating: -1, count: ranks.count)
        for i in ranks.indices {
            guard let rankI = ranks[i] else { continue }
            length[i] = 1
            for j in 0..<i {
                if let rankJ = ranks[j], rankJ < rankI, length[j] + 1 > length[i] {
                    length[i] = length[j] + 1
                    previous[i] = j
                }
            }
        }

        guard let longest = length.max(), longest > 0,
              var index = length.firstIndex(of: longest) else { return [] }
        var positions: Set<Int> = []
        while index >= 0 {
            positions.insert(index)
            index = previous[index]
        }
        return positions
    }

    /// The books that need moving, each with its neighbors in the correct order, in Bible order.
    static func reviewItems(current: [String], correct: [String]) -> [BookOrderReviewItem] {
        let inOrder = Set(inOrderPositions(current: current, correct: correct).map { current[$0] })
        return correct.indices.compactMap { index in
            guard current.contains(correct[index]), !inOrder.contains(correct[index]) else { return nil }
            return BookOrderReviewItem(
                book: correct[index],
                previousBook: index > 0 ? correct[index - 1] : nil,
                nextBook: index + 1 < correct.count ? correct[index + 1] : nil
            )
        }
    }

    /// Adds misplaced books to the missed-question history (study only, never a review round)
    /// and retires a book from it once it is placed correctly again.
    private func recordMissedBooks() {
        let store = MissedGameQuestionStore.shared
        let missed = Set(booksToReview.map(\.book))
        for book in correctOrder {
            if missed.contains(book) {
                store.record(game: .bookOrder, bookNames: [book], topic: "Book order", questionID: book)
            } else if store.containsMiss(game: .bookOrder, questionID: book) {
                store.resolveReviewQuestion(game: .bookOrder, questionID: book)
            }
        }
    }

    func move(from source: IndexSet, to destination: Int) {
        guard !showResult else { return }
        currentItems.move(fromOffsets: source, toOffset: destination)
    }
}

/// A book that needed moving, described by its neighbors in the correct order.
struct BookOrderReviewItem: Identifiable, Equatable {
    let book: String
    let previousBook: String?
    let nextBook: String?

    var id: String { book }

    var hint: String {
        if let previousBook {
            String(localized: "\(book) comes after \(previousBook)")
        } else if let nextBook {
            String(localized: "\(book) comes before \(nextBook)")
        } else {
            book
        }
    }

    /// The same advice for the book's own row, e.g. "Goes after Micah".
    var placementHint: String? {
        if let previousBook {
            String(localized: "Goes after \(previousBook)")
        } else if let nextBook {
            String(localized: "Goes before \(nextBook)")
        } else {
            nil
        }
    }
}

#if DEBUG
extension BookOrderGameViewModel {
    static func preview() -> BookOrderGameViewModel {
        let vm = BookOrderGameViewModel()
        let canon = BibleCanon.canonicalOrder()
        let slice = Array(canon.prefix(6))
        vm.correctOrder = slice
        vm.currentItems = slice.shuffled()
        vm.started = true
        return vm
    }
}
#endif
