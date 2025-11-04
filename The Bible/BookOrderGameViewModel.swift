import Foundation
import Combine

enum BookOrderDifficulty: String, CaseIterable, Identifiable {
    case easy, normal, hard, all
    var id: String { rawValue }
}

enum BookSourceScope: String, CaseIterable, Identifiable {
    case ot = "OT", nt = "NT", both = "Both"
    var id: String { rawValue }
}

struct BibleCanon {
    /// Hardcoded fallback Protestant canonical 66 books in order
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
    
    /// Returns the canonical order of books using BibleData if available, else fallback
    static func canonicalOrder() -> [String] {
        if !BibleData.books.isEmpty {
            return BibleData.books.map { $0.name }
        }
        return fallbackCanon
    }
}

/// Represents a single round of the Book Order game
struct BookOrderRound {
    let prompt: String
    let shuffled: [String]
    let correctOrder: [String]
}

@MainActor
final class BookOrderGameViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var started: Bool = false
    @Published var currentItems: [String] = []
    @Published var correctOrder: [String] = []
    @Published var score: Int = 0
    @Published var answered: Int = 0
    @Published var currentStreak: Int = 0
    @Published var currentBestStreak: Int = 0
    @Published var showResult: Bool = false
    @Published var wasCorrect: Bool = false
    @Published var showingCorrectOrder: Bool = false
    
    @Published var difficulty: BookOrderDifficulty = .normal
    @Published var source: BookSourceScope = .both
    
    // MARK: - Round info for prompt display
    
    private var sliceFirst: String? = nil
    private var sliceLast: String? = nil
    
    // MARK: - Persistence keys
    
    private let keyAllTimeCorrect = "bookorderAllTimeCorrect"
    private let keyAllTimeAnswered = "bookorderAllTimeAnswered"
    private let keyAllTimeBestStreak = "bookorderAllTimeBestStreak"
    
    // MARK: - Computed persisted all-time stats
    
    var allTimeCorrect: Int {
        get { UserDefaults.standard.integer(forKey: keyAllTimeCorrect) }
        set { UserDefaults.standard.set(newValue, forKey: keyAllTimeCorrect) }
    }
    
    var allTimeAnswered: Int {
        get { UserDefaults.standard.integer(forKey: keyAllTimeAnswered) }
        set { UserDefaults.standard.set(newValue, forKey: keyAllTimeAnswered) }
    }
    
    var allTimeBestStreak: Int {
        get { UserDefaults.standard.integer(forKey: keyAllTimeBestStreak) }
        set { UserDefaults.standard.set(newValue, forKey: keyAllTimeBestStreak) }
    }
    
    // MARK: - Game logic
    
    func startGame() {
        score = 0
        answered = 0
        currentStreak = 0
        currentBestStreak = 0
        showResult = false
        wasCorrect = false
        showingCorrectOrder = false
        started = true
        nextRound()
    }
    
    private func workingCanon() -> [String] {
        let canon = BibleCanon.canonicalOrder()
        switch source {
        case .both:
            return canon
        case .ot:
            // Old Testament is first 39 in the fallback list; if BibleData order is used and differs, prefer names up to the first 39 that match fallback
            let fallback = BibleCanon.fallbackCanon
            let otSet = Set(fallback.prefix(39))
            return canon.filter { otSet.contains($0) }
        case .nt:
            let fallback = BibleCanon.fallbackCanon
            let ntSet = Set(fallback.suffix(27))
            return canon.filter { ntSet.contains($0) }
        }
    }
    
    func nextRound() {
        let canon = workingCanon()
        guard !canon.isEmpty else {
            // Not enough books to play
            currentItems = []
            correctOrder = []
            sliceFirst = nil
            sliceLast = nil
            return
        }
        
        let length: Int
        switch difficulty {
        case .easy:
            length = 5
        case .normal:
            length = 10
        case .hard:
            length = 15
        case .all:
            length = canon.count
        }
        
        let maxStart = max(0, canon.count - length)
        let start = (maxStart > 0) ? Int.random(in: 0...maxStart) : 0
        
        let slice = Array(canon[start..<(start + length)])
        correctOrder = slice
        sliceFirst = slice.first
        sliceLast = slice.last
        
        var shuffled = slice.shuffled()
        if shuffled == slice && shuffled.count > 1 {
            shuffled.swapAt(0, 1)
        }
        currentItems = shuffled
        
        showResult = false
        wasCorrect = false
        showingCorrectOrder = false
    }
    
    var prompt: String {
        let base = "Arrange these books in canonical order"
        let scope: String
        switch source {
        case .both: scope = "(Whole Bible)"
        case .ot: scope = "(Old Testament)"
        case .nt: scope = "(New Testament)"
        }
        if let a = sliceFirst, let b = sliceLast, difficulty != .all {
            return "\(base) \(scope) — \(a) to \(b)"
        } else {
            return "\(base) \(scope)"
        }
    }
    
    func checkOrder() {
        guard !currentItems.isEmpty, !correctOrder.isEmpty else {
            wasCorrect = false
            showResult = true
            return
        }
        
        if currentItems == correctOrder {
            wasCorrect = true
            score += 1
            currentStreak += 1
            if currentStreak > currentBestStreak {
                currentBestStreak = currentStreak
            }
        } else {
            wasCorrect = false
            currentStreak = 0
            showingCorrectOrder = true
        }
        
        answered += 1
        
        updateAllTime(correct: wasCorrect ? 1 : 0, answered: 1, streak: currentStreak)
        
        showResult = true
    }
    
    private func updateAllTime(correct: Int, answered: Int, streak: Int) {
        allTimeCorrect += correct
        allTimeAnswered += answered
        if streak > allTimeBestStreak {
            allTimeBestStreak = streak
        }
    }
    
    func move(from source: IndexSet, to destination: Int) {
        currentItems.move(fromOffsets: source, toOffset: destination)
    }
}

#if DEBUG
import SwiftUI
extension BookOrderGameViewModel {
    static func preview() -> BookOrderGameViewModel {
        let vm = BookOrderGameViewModel()
        let canon = BibleCanon.canonicalOrder()
        // Fixed slice for preview: first 6 books
        let sliceLength = 6
        let startIndex = 0
        let slice = Array(canon[startIndex..<(startIndex+sliceLength)])
        vm.correctOrder = slice
        vm.currentItems = slice.shuffled()
        vm.sliceFirst = slice.first
        vm.sliceLast = slice.last
        vm.started = true
        return vm
    }
}
#endif
