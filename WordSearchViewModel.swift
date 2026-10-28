import Foundation
import SwiftUI
import Observation
import SwiftData

@MainActor
@Observable
final class WordSearchViewModel {
    // Public UI state
    var started: Bool = false
    var difficulty: WordSearchEngine.Difficulty = .medium {
        didSet { UserDefaults.standard.set(difficulty.rawValue, forKey: Self.difficultyKey) }
    }

    /// Where the puzzle's verse comes from.
    enum VerseSource: String, CaseIterable, Identifiable {
        case popular
        case random
        case favorites

        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .popular: "Popular"
            case .random: "Any verse"
            case .favorites: "Favorites"
            }
        }

        var detail: LocalizedStringResource {
            switch self {
            case .popular: "Well-known verses"
            case .random: "Any eligible passage"
            case .favorites: "Your saved verses"
            }
        }

        var icon: String {
            switch self {
            case .popular: "star.fill"
            case .random: "shuffle"
            case .favorites: "heart.fill"
            }
        }
    }
    var verseSource: VerseSource = .popular {
        didSet { UserDefaults.standard.set(verseSource.rawValue, forKey: Self.verseSourceKey) }
    }

    /// Blind hides the word list and the verse text until the round ends.
    var isBlindMode: Bool = false {
        didSet { UserDefaults.standard.set(isBlindMode, forKey: Self.blindModeKey) }
    }

    /// How a finished round ended.
    enum RoundResult {
        case won, timeUp, revealed
    }

    // Timer
    var isTimedMode: Bool = false {
        didSet { UserDefaults.standard.set(isTimedMode, forKey: Self.timedModeKey) }
    }
    var remainingSeconds: Int = 0
    var timeUp: Bool = false
    var didWin: Bool = false
    var pulseOn: Bool = false
    var roundOver: Bool = false
    var roundResult: RoundResult?
    /// Shown when no eligible word-search puzzle could be generated.
    var puzzleGenerationError: String?
    /// Seconds spent playing this round; pauses while the game is off screen.
    var elapsedSeconds: Int = 0

    // Grid
    var grid: [[Character]] = Array(repeating: Array(repeating: " ", count: 10), count: 10)
    var targetWords: [String] = []
    var placed: [WordSearchEngine.PlacedWord] = []
    var verseRef: String = ""
    var verseText: String = ""

    // Selection/found
    var selectionStart: (row: Int, col: Int)? = nil
    var selectionEnd: (row: Int, col: Int)? = nil
    var foundCells: Set<String> = []
    var foundWords: Set<String> = []
    var revealedWords: Set<String> = []
    /// In Blind mode, true once the person chose to show the word list (it stays shown).
    var showBlindWordList: Bool = false
    var tapStart: (row: Int, col: Int)? = nil

    // Colors: each word gets its own color, and found cells take their word's color.
    private(set) var colorIndexForWord: [String: Int] = [:]
    private(set) var colorIndexForCell: [String: Int] = [:]

    // Hints
    /// The cell currently flashing as a hint (the first letter of an unfound word).
    private(set) var hintCell: (row: Int, col: Int)?
    private(set) var hintsUsed: Int = 0
    @ObservationIgnored private var hintClearTask: Task<Void, Never>?

    /// Set when adding or removing a favorite couldn't be saved.
    var favoriteSaveFailure: PersistenceFailure?

    // Favorites resolution context
    var favBookName: String = ""
    var favChapterNumber: Int = 0
    var favVerseNumber: Int = 0

    // Dependencies
    private var modelContext: ModelContext
    private var favoritesFetch: () -> [Favorite]
    @ObservationIgnored private var clockTask: Task<Void, Never>?
    private var hasRecordedCurrentRound = false

    private static let currentStreakKey = "wordsearchCurrentStreak"
    private static let difficultyKey = "wordsearchDifficulty"
    private static let verseSourceKey = "wordsearchVerseSource"
    private static let blindModeKey = "wordsearchBlindMode"
    private static let timedModeKey = "wordsearchTimedMode"

    // Engine
    private var engine: WordSearchEngine {
        WordSearchEngine(size: size, difficulty: difficulty)
    }

    init(modelContext: ModelContext, favoritesFetch: @escaping () -> [Favorite]) {
        self.modelContext = modelContext
        self.favoritesFetch = favoritesFetch

        let defaults = UserDefaults.standard
        difficulty = WordSearchEngine.Difficulty(
            rawValue: defaults.string(forKey: Self.difficultyKey) ?? ""
        ) ?? .medium
        verseSource = VerseSource(
            rawValue: defaults.string(forKey: Self.verseSourceKey) ?? ""
        ) ?? .popular
        isBlindMode = defaults.bool(forKey: Self.blindModeKey)
        isTimedMode = defaults.bool(forKey: Self.timedModeKey)
    }

    // Allow rebinding dependencies after construction (e.g., once the environment is available)
    func rebind(modelContext: ModelContext, favoritesFetch: @escaping () -> [Favorite]) {
        self.modelContext = modelContext
        self.favoritesFetch = favoritesFetch
    }

    // MARK: - Derived

    var size: Int {
        switch difficulty {
        case .easy: return 10
        case .medium: return 12
        case .hard, .expert: return 14
        }
    }

    /// How many words a puzzle at this difficulty asks for.
    var wordCountRange: ClosedRange<Int> {
        switch difficulty {
        case .easy: return 3...6
        case .medium: return 4...7
        case .hard: return 5...8
        case .expert: return 6...10
        }
    }

    /// True while the word list (and verse text) should stay hidden.
    var hidesWordList: Bool { isBlindMode && !showBlindWordList && !roundOver }

    // MARK: - Intents

    func start() {
        newPuzzle()
        started = puzzleGenerationError == nil
    }

    func newPuzzle() {
        hasRecordedCurrentRound = false
        generatePuzzle()
        guard puzzleGenerationError == nil else {
            stopTimer()
            return
        }
        startClock()
    }

    func changeSettings() {
        started = false
        stopTimer()
        roundOver = false
        showBlindWordList = false
        puzzleGenerationError = nil
    }

    func reveal() {
        guard !roundOver else { return }
        revealOverlay()
        finishRound(.revealed)
    }

    /// Shows the word list for the rest of a Blind round.
    func showWordList() {
        showBlindWordList = true
    }

    /// Briefly highlights the first letter of a word that hasn't been found yet.
    func hint() {
        guard !roundOver,
              let word = placed.filter({ !foundWords.contains($0.originalWord) }).randomElement(),
              let first = engine.cellsForPlacedWord(word).first else { return }
        hintsUsed += 1
        hintCell = first
        hintClearTask?.cancel()
        hintClearTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            self?.hintCell = nil
        }
    }

    func handleTap(row: Int, col: Int) {
        guard !roundOver else { return }
        if tapStart == nil {
            tapStart = (row, col)
            selectionStart = tapStart
            selectionEnd = tapStart
            return
        }
        if let start = tapStart {
            let constrained = engine.constrainToAllowedLine(from: start, to: (row, col))
            selectionStart = start
            selectionEnd = constrained
            validateSelection()
            selectionStart = nil
            selectionEnd = nil
            tapStart = nil
        }
    }

    func dragChanged(to cell: (row: Int, col: Int)) {
        guard !roundOver else { return }
        if selectionStart == nil {
            selectionStart = cell
            selectionEnd = cell
        } else if let start = selectionStart {
            selectionEnd = engine.constrainToAllowedLine(from: start, to: cell)
        }
    }

    func dragEnded() {
        guard !roundOver else { return }
        validateSelection()
        selectionStart = nil
        selectionEnd = nil
        tapStart = nil
    }

    // MARK: - Timer

    /// Seconds allowed per word in Timed mode. Blind gets half again as long.
    private var secondsPerWord: Int {
        let base: Int
        switch difficulty {
        case .easy: base = 15
        case .medium: base = 20
        case .hard: base = 25
        case .expert: base = 30
        }
        return isBlindMode ? base * 3 / 2 : base
    }

    /// Time allowed for a puzzle with `wordCount` words (at least 45 seconds).
    private func timeLimitSeconds(wordCount: Int) -> Int {
        max(45, secondsPerWord * wordCount)
    }

    /// Shown on the start screen before a puzzle exists, e.g. "20 sec per word".
    func timePerWordString() -> String {
        "\(secondsPerWord) sec per word"
    }

    func formattedTime(_ secs: Int) -> String {
        let m = secs / 60
        let s = secs % 60
        return String(format: "%d:%02d", m, s)
    }

    /// Starts a fresh clock for a new round.
    private func startClock() {
        elapsedSeconds = 0
        pulseOn = false
        remainingSeconds = isTimedMode ? timeLimitSeconds(wordCount: targetWords.count) : 0
        resumeTimer()
    }

    /// Restarts the clock where it left off, e.g. when returning to the game.
    func resumeTimer() {
        stopTimer()
        guard started, !roundOver else { return }
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                self.tickTimer()
            }
        }
    }

    func stopTimer() {
        clockTask?.cancel()
        clockTask = nil
    }

    private func tickTimer() {
        guard !roundOver else { return }
        elapsedSeconds += 1
        guard isTimedMode, remainingSeconds > 0 else { return }
        remainingSeconds -= 1
        if remainingSeconds == 0 {
            handleTimeUp()
        } else if remainingSeconds == 10 {
            startPulse()
        }
    }

    private func startPulse() {
        let pulses = 4
        for i in 0..<(pulses * 2) {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.25) { [weak self] in
                guard let self else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.pulseOn.toggle()
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(pulses * 2) * 0.25 + 0.05) { [weak self] in
            self?.pulseOn = false
        }
    }

    private func handleTimeUp() {
        revealOverlay()
        finishRound(.timeUp)
        #if canImport(UIKit)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.warning)
        #endif
    }

    func timerTint(for seconds: Int) -> Color {
        if seconds > 30 { return .green }
        else if seconds > 10 { return .yellow }
        else { return .red }
    }

    // MARK: - Round end

    private func finishRound(_ result: RoundResult) {
        stopTimer()
        roundResult = result
        timeUp = result == .timeUp
        didWin = result == .won
        roundOver = true
        selectionStart = nil
        selectionEnd = nil
        tapStart = nil
        hintClearTask?.cancel()
        hintCell = nil
        recordCompletedRound(won: result == .won)
    }

    // MARK: - Puzzle generation

    private func resetState() {
        grid = Array(repeating: Array(repeating: " ", count: size), count: size)
        placed = []
        targetWords = []
        foundCells.removeAll()
        foundWords.removeAll()
        revealedWords.removeAll()
        colorIndexForWord.removeAll()
        colorIndexForCell.removeAll()
        selectionStart = nil
        selectionEnd = nil
        tapStart = nil
        showBlindWordList = false
        hintClearTask?.cancel()
        hintCell = nil
        hintsUsed = 0
        timeUp = false
        didWin = false
        roundOver = false
        roundResult = nil
        puzzleGenerationError = nil
    }

    private struct VerseChoice {
        let book: String
        let chapter: Int
        let verse: Int
        let text: String
    }

    private func generatePuzzle() {
        resetState()

        // Short verses can yield only a word or two, so try a few verses and keep the
        // first that gives a full puzzle (or the best non-empty one found).
        var best: (choice: VerseChoice, puzzle: (grid: [[Character]], placed: [WordSearchEngine.PlacedWord], target: [String]))?
        for _ in 0..<12 {
            guard let choice = nextVerse() else { break }
            let puzzle = engine.generatePuzzle(from: choice.text, countRange: wordCountRange)
            if best == nil || puzzle.target.count > best!.puzzle.target.count {
                best = (choice, puzzle)
            }
            if puzzle.target.count >= wordCountRange.lowerBound { break }
        }
        guard let best, !best.puzzle.target.isEmpty else {
            puzzleGenerationError = "We couldn't make a word-search puzzle from the available verses. Please try again."
            return
        }

        verseRef = "\(best.choice.book) \(best.choice.chapter):\(best.choice.verse)"
        verseText = best.choice.text
        favBookName = best.choice.book
        favChapterNumber = best.choice.chapter
        favVerseNumber = best.choice.verse
        grid = best.puzzle.grid
        placed = best.puzzle.placed
        targetWords = best.puzzle.target
        for (index, word) in targetWords.enumerated() {
            colorIndexForWord[word] = index
        }
    }

    private func nextVerse() -> VerseChoice? {
        switch verseSource {
        case .favorites:
            return favoritesFetch().compactMap { favorite in
                guard let (book, chapter, verse) = resolveFavorite(favorite) else { return nil }
                return VerseChoice(book: book.name, chapter: chapter.number, verse: verse.number, text: verse.text)
            }
            .randomElement()
        case .popular:
            return Self.popularVerses.randomElement().map(resolvePopular) ?? randomVerse()
        case .random:
            return randomVerse()
        }
    }

    private func randomVerse() -> VerseChoice? {
        guard let book = BibleData.books.randomElement(),
              let chapter = book.chapters.randomElement(),
              let verse = chapter.verses.randomElement() else { return nil }
        return VerseChoice(book: book.name, chapter: chapter.number, verse: verse.number, text: verse.text)
    }

    // MARK: - Popular verses

    /// Well-known verses shared with the lock-screen widget (`LockScreenVerses.json`).
    private struct PopularVerse: Decodable {
        let book: String
        let chapter: Int
        let verse: Int
        let text: String
    }

    private static let popularVerses: [PopularVerse] = {
        guard let url = Bundle.main.url(forResource: "LockScreenVerses", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([PopularVerse].self, from: data)) ?? []
    }()

    /// Prefers the app's own text for the verse so it matches the reader exactly.
    private func resolvePopular(_ entry: PopularVerse) -> VerseChoice {
        let text = BibleData.books.first { $0.name == entry.book }?
            .chapters.first { $0.number == entry.chapter }?
            .verses.first { $0.number == entry.verse }?
            .text ?? entry.text
        return VerseChoice(book: entry.book, chapter: entry.chapter, verse: entry.verse, text: text)
    }

    // MARK: - Validation

    private func keyFor(row: Int, col: Int) -> String { "\(row),\(col)" }

    private func validateSelection() {
        guard let start = selectionStart, let end = selectionEnd else { return }
        let result = engine.validateSelection(grid: grid, placed: placed, start: start, end: end)
        guard let originalWord = result.matchedWordOriginal, !result.matchedPath.isEmpty,
              !foundWords.contains(originalWord) else { return }

        for cell in result.matchedPath {
            let key = keyFor(row: cell.row, col: cell.col)
            foundCells.insert(key)
            colorIndexForCell[key] = colorIndexForWord[originalWord]
        }
        foundWords.insert(originalWord)
        revealedWords.remove(originalWord)

        if foundWords.count == targetWords.count {
            finishRound(.won)
        }
    }

    private func recordCompletedRound(won: Bool) {
        guard !hasRecordedCurrentRound else { return }
        hasRecordedCurrentRound = true

        let defaults = UserDefaults.standard
        let currentStreak: Int
        if won {
            currentStreak = defaults.integer(forKey: Self.currentStreakKey) + 1
        } else {
            currentStreak = 0
        }
        defaults.set(currentStreak, forKey: Self.currentStreakKey)

        GameStats.shared.recordRound(
            game: .wordsearch,
            difficulty: statsDifficulty,
            correct: won ? 1 : 0,
            answered: 1,
            currentBestStreak: currentStreak
        )
    }

    private var statsDifficulty: GameStats.Difficulty {
        switch difficulty {
        case .easy: .easy
        case .medium: .normal
        case .hard, .expert: .hard
        }
    }

    // MARK: - Reveal

    private func revealOverlay() {
        var newRevealed = revealedWords
        for pw in placed {
            if !foundWords.contains(pw.originalWord) {
                newRevealed.insert(pw.originalWord)
            }
        }
        revealedWords = newRevealed
    }

    // MARK: - Favorites

    func isCurrentFavorited() -> Bool {
        guard !favBookName.isEmpty, favChapterNumber > 0, favVerseNumber > 0 else { return false }
        return favoritesFetch().contains { fav in
            fav.bookName == favBookName && fav.chapterNumber == favChapterNumber && fav.verseNumber == favVerseNumber
        }
    }

    /// Saved verses whose book, chapter, and verse still resolve in the bundled Bible.
    func eligibleFavoriteCount() -> Int {
        favoritesFetch().count { resolveFavorite($0) != nil }
    }

    func toggleFavoriteCurrent() {
        guard !favBookName.isEmpty, favChapterNumber > 0, favVerseNumber > 0 else { return }
        let context = modelContext
        let (book, chapter, verse, text) = (favBookName, favChapterNumber, favVerseNumber, verseText)
        let favorites = favoritesFetch()
        ModelContextPersistence.perform(
            in: context,
            operation: {
                try FavoriteVerses.toggle(
                    bookName: book,
                    chapterNumber: chapter,
                    verseNumber: verse,
                    verseText: text,
                    favorites: favorites,
                    in: context
                )
            },
            onSuccess: {},
            onFailure: { [weak self] in self?.favoriteSaveFailure = $0 }
        )
    }

    private func resolveFavorite(_ fav: Favorite) -> (Book, Chapter, Verse)? {
        func insertSpaceBetweenLeadingDigitsAndLetters(_ s: String) -> String {
            guard let first = s.first, first.isNumber else { return s }
            let digits = String(s.prefix { $0.isNumber })
            let rest = String(s.drop { $0.isNumber })
            if rest.first?.isLetter == true { return digits + " " + rest }
            return s
        }

        let raw = fav.bookName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let b = BibleData.books.first(where: { $0.name.compare(raw, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            if let c = b.chapters.first(where: { $0.number == fav.chapterNumber }),
               let v = c.verses.first(where: { $0.number == fav.verseNumber }) {
                return (b, c, v)
            }
        }
        let spaced = insertSpaceBetweenLeadingDigitsAndLetters(raw)
        if let b = BibleData.books.first(where: { $0.name.compare(spaced, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            if let c = b.chapters.first(where: { $0.number == fav.chapterNumber }),
               let v = c.verses.first(where: { $0.number == fav.verseNumber }) {
                return (b, c, v)
            }
        }
        let collapsed = raw.replacingOccurrences(of: " ", with: "")
        if let b = BibleData.books.first(where: { $0.name.replacingOccurrences(of: " ", with: "").compare(collapsed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            if let c = b.chapters.first(where: { $0.number == fav.chapterNumber }),
               let v = c.verses.first(where: { $0.number == fav.verseNumber }) {
                return (b, c, v)
            }
        }
        return nil
    }
}
