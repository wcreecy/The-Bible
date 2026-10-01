import Foundation
import SwiftUI
import Combine
import Observation
import SwiftData

@MainActor
@Observable
final class WordSearchViewModel {
    // Public UI state
    var started: Bool = false
    var howToExpanded: Bool = false
    var difficultyExpanded: Bool = false
    var difficulty: WordSearchEngine.Difficulty = .medium
    enum GameMode: String, CaseIterable, Identifiable { case normal, blind, favorites; var id: String { rawValue }; var displayName: String { switch self { case .normal: return "Normal"; case .blind: return "Blind"; case .favorites: return "Favorites" } } }
    var gameMode: GameMode = .normal

    // Timer
    var isTimedMode: Bool = false
    var remainingSeconds: Int = 0
    var timeUp: Bool = false
    var didWin: Bool = false
    var pulseOn: Bool = false
    var roundOver: Bool = false

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
    var showBlindWordList: Bool = false
    var tapStart: (row: Int, col: Int)? = nil

    // Favorites resolution context
    var favBookName: String = ""
    var favChapterNumber: Int = 0
    var favVerseNumber: Int = 0

    // Dependencies
    private var modelContext: ModelContext
    private var favoritesFetch: () -> [Favorite]
    private var timerSubscription: AnyCancellable?

    // Engine
    private var engine: WordSearchEngine {
        WordSearchEngine(size: size, difficulty: difficulty)
    }

    init(modelContext: ModelContext, favoritesFetch: @escaping () -> [Favorite]) {
        self.modelContext = modelContext
        self.favoritesFetch = favoritesFetch
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

    // MARK: - Intents

    func start() {
        started = true
        timeUp = false
        didWin = false
        roundOver = false
        showBlindWordList = false
        generatePuzzle()
        startTimerIfNeeded()
    }

    func newPuzzle() {
        generatePuzzle()
        timeUp = false
        didWin = false
        roundOver = false
        showBlindWordList = false
        startTimerIfNeeded()
    }

    func changeSettings() {
        started = false
        stopTimer()
        roundOver = false
        showBlindWordList = false
    }

    func reveal() {
        revealOverlay()
        stopTimer()
        roundOver = true
    }

    func handleTap(row: Int, col: Int) {
        guard !timeUp && !didWin && !roundOver else { return }
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
        guard !timeUp && !didWin && !roundOver else { return }
        if selectionStart == nil {
            selectionStart = cell
            selectionEnd = cell
        } else if let start = selectionStart {
            selectionEnd = engine.constrainToAllowedLine(from: start, to: cell)
        }
    }

    func dragEnded() {
        guard !timeUp && !didWin && !roundOver else { return }
        validateSelection()
        selectionStart = nil
        selectionEnd = nil
        tapStart = nil
    }

    // MARK: - Timer

    private func timeLimitSeconds() -> Int {
        guard isTimedMode else { return 0 }
        if gameMode == .blind {
            switch difficulty {
            case .easy: return 120
            case .medium: return 150
            case .hard: return 240
            case .expert: return 270
            }
        } else {
            switch difficulty {
            case .easy: return 60
            case .medium: return 90
            case .hard: return 120
            case .expert: return 150
            }
        }
    }

    func timeLimitString() -> String {
        formattedTime(timeLimitSeconds())
    }

    func formattedTime(_ secs: Int) -> String {
        let m = secs / 60
        let s = secs % 60
        return String(format: "%d:%02d", m, s)
    }

    private func startTimerIfNeeded() {
        stopTimer()
        guard isTimedMode else { return }
        remainingSeconds = timeLimitSeconds()
        pulseOn = false
        timeUp = false
        didWin = false
        timerSubscription = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tickTimer() }
    }

    func stopTimer() {
        timerSubscription?.cancel()
        timerSubscription = nil
    }

    private func tickTimer() {
        guard isTimedMode, !timeUp, !didWin, !roundOver, remainingSeconds > 0 else { return }
        remainingSeconds -= 1
        if remainingSeconds == 0 {
            handleTimeUp()
        } else {
            let threshold = 10
            if remainingSeconds == threshold {
                startPulse()
            }
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
        timeUp = true
        stopTimer()
        revealOverlay()
        selectionStart = nil
        selectionEnd = nil
        tapStart = nil
        roundOver = true
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

    // MARK: - Puzzle generation

    private func resetState() {
        grid = Array(repeating: Array(repeating: " ", count: size), count: size)
        placed = []
        targetWords = []
        foundCells.removeAll()
        foundWords.removeAll()
        revealedWords.removeAll()
        selectionStart = nil
        selectionEnd = nil
        tapStart = nil
        showBlindWordList = false
        timeUp = false
        didWin = false
        roundOver = false
    }

    private func generatePuzzle() {
        resetState()

        // Resolve verse
        if gameMode == .favorites, let fav = favoritesFetch().randomElement(), let resolved = resolveFavorite(fav) {
            let (book, chapter, verse) = resolved
            verseRef = "\(book.name) \(chapter.number):\(verse.number)"
            verseText = verse.text
            favBookName = book.name; favChapterNumber = chapter.number; favVerseNumber = verse.number
        } else {
            guard let book = BibleData.books.randomElement(),
                  let chapter = book.chapters.randomElement(),
                  let verse = chapter.verses.randomElement()
            else { return }
            verseRef = "\(book.name) \(chapter.number):\(verse.number)"
            verseText = verse.text
            favBookName = book.name; favChapterNumber = chapter.number; favVerseNumber = verse.number
        }

        let countRange: ClosedRange<Int> = {
            switch difficulty {
            case .easy: return 3...6
            case .medium: return 4...7
            case .hard, .expert: return 5...8
            }
        }()

        let result = engine.generatePuzzle(from: verseText, countRange: countRange)
        grid = result.grid
        placed = result.placed
        targetWords = result.target
    }

    // MARK: - Validation

    private func keyFor(row: Int, col: Int) -> String { "\(row),\(col)" }

    private func validateSelection() {
        guard let start = selectionStart, let end = selectionEnd else { return }
        let result = engine.validateSelection(grid: grid, placed: placed, start: start, end: end)
        guard let originalWord = result.matchedWordOriginal, !result.matchedPath.isEmpty else { return }

        for cell in result.matchedPath {
            foundCells.insert(keyFor(row: cell.row, col: cell.col))
        }
        foundWords.insert(originalWord)
        revealedWords.remove(originalWord)

        if foundWords.count == targetWords.count {
            stopTimer()
            didWin = true
            roundOver = true
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

    func toggleFavoriteCurrent() {
        guard !favBookName.isEmpty, favChapterNumber > 0, favVerseNumber > 0 else { return }
        if let existing = favoritesFetch().first(where: { $0.bookName == favBookName && $0.chapterNumber == favChapterNumber && $0.verseNumber == favVerseNumber }) {
            modelContext.delete(existing)
            try? modelContext.save()
        } else {
            let fav = Favorite(bookName: favBookName, chapterNumber: favChapterNumber, verseNumber: favVerseNumber, verseText: verseText)
            modelContext.insert(fav)
            try? modelContext.save()
        }
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
