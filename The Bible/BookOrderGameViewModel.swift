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

    var started: Bool = false
    var currentItems: [String] = []
    var correctOrder: [String] = []
    /// Score and streaks; see `GameScore` for the rules. The session streak counts correct
    /// puzzles in a row during this visit.
    private(set) var session = GameScore()
    var showResult: Bool = false
    var wasCorrect: Bool = false

    // Result of the last check
    var booksInPlace: Int = 0
    var lastTimeSeconds: Int = 0
    var bestTimeSeconds: Int?
    var isNewBestTime: Bool = false

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
        didSet { UserDefaults.standard.set(source.rawValue, forKey: Self.sourceKey) }
    }

    /// Books in each puzzle for the current settings.
    var roundBookCount: Int {
        let available = source.bookNames.count
        return min(difficulty.runLength ?? available, available)
    }

    // MARK: - Persistent streak and best time (per difficulty)

    private var persistentStreak: PersistentGameStreak {
        PersistentGameStreak(game: "bookorder", variant: difficulty.rawValue)
    }

    var persistentBestStreak: Int { persistentStreak.best }

    private var bestTimeKey: String { "bookorderBestTime_\(source.rawValue)_\(difficulty.rawValue)" }

    /// Fastest fully correct puzzle for the current settings.
    var savedBestTime: Int? {
        let value = UserDefaults.standard.integer(forKey: bestTimeKey)
        return value > 0 ? value : nil
    }

    // MARK: - Game flow

    func startGame() {
        // The session streak carries from one game to the next.
        // Do NOT reset persistent streaks here; seed from persistence
        session.beginGame(savedStreak: persistentStreak)
        started = true
        nextRound()
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

    /// Picks a run of books in a row from the chosen part and shuffles it.
    func nextRound() {
        showResult = false
        wasCorrect = false
        booksInPlace = 0
        isNewBestTime = false

        let books = source.bookNames
        guard !books.isEmpty else {
            currentItems = []
            correctOrder = []
            return
        }

        let length = roundBookCount
        let start = Int.random(in: 0...(books.count - length))
        let run = Array(books[start..<(start + length)])
        correctOrder = run

        var shuffled = run.shuffled()
        while shuffled == run && run.count > 1 {
            shuffled.shuffle()
        }
        currentItems = shuffled
    }

    /// The book that belongs at each position, used to mark wrong rows after a check.
    func correctBook(at index: Int) -> String? {
        correctOrder.indices.contains(index) ? correctOrder[index] : nil
    }

    func checkOrder(elapsedSeconds: Int) {
        guard !showResult, !currentItems.isEmpty, !correctOrder.isEmpty else { return }

        booksInPlace = zip(currentItems, correctOrder).filter { $0 == $1 }.count
        wasCorrect = currentItems == correctOrder
        lastTimeSeconds = elapsedSeconds
        session.record(correct: wasCorrect, savedStreak: persistentStreak)

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
            difficulty: difficulty.statsDifficulty,
            correct: wasCorrect ? 1 : 0,
            answered: 1,
            currentBestStreak: session.savedBestStreak
        )

        showResult = true
    }

    func move(from source: IndexSet, to destination: Int) {
        guard !showResult else { return }
        currentItems.move(fromOffsets: source, toOffset: destination)
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
