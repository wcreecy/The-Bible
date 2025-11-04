import Foundation
import Combine

struct BibleCanon {
    /// Hardcoded fallback Protestant canonical 66 books in order
    static let fallbackBooks: [String] = [
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
        return fallbackBooks
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
    
    // MARK: - Round info for prompt display
    
    private(set) var prompt: String = "Arrange these books in canonical order"
    private(set) var roundFirstBook: String = ""
    private(set) var roundLastBook: String = ""
    
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
    
    func nextRound() {
        let canon = BibleCanon.canonicalOrder()
        guard canon.count >= 8 else {
            // Not enough books to play
            currentItems = []
            correctOrder = []
            prompt = "Insufficient data for canonical order"
            roundFirstBook = ""
            roundLastBook = ""
            return
        }
        
        // Pick slice length 5 to 8
        let sliceLength = Int.random(in: 5...8)
        // Pick start index so slice fits
        let maxStart = canon.count - sliceLength
        let startIndex = Int.random(in: 0...maxStart)
        
        let slice = Array(canon[startIndex..<(startIndex + sliceLength)])
        correctOrder = slice
        
        // Shuffle until shuffled != correctOrder to avoid trivial order
        var shuffledSlice = slice.shuffled()
        while shuffledSlice == slice {
            shuffledSlice = slice.shuffled()
        }
        currentItems = shuffledSlice
        
        // Set prompt with range info
        roundFirstBook = slice.first ?? ""
        roundLastBook = slice.last ?? ""
        prompt = promptText(forFirst: roundFirstBook, last: roundLastBook)
        
        showResult = false
        wasCorrect = false
        showingCorrectOrder = false
    }
    
    /// Returns the prompt text, including range if possible
    private func promptText(forFirst first: String, last: String) -> String {
        if !first.isEmpty && !last.isEmpty && first != last {
            return "Arrange these books in canonical order\n(\(first) to \(last))"
        } else if !first.isEmpty {
            return "Arrange these books in canonical order\n(\(first))"
        } else {
            return "Arrange these books in canonical order"
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
        vm.roundFirstBook = slice.first ?? ""
        vm.roundLastBook = slice.last ?? ""
        vm.prompt = vm.promptText(forFirst: vm.roundFirstBook, last: vm.roundLastBook)
        vm.started = true
        return vm
    }
}
#endif
