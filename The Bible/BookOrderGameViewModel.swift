import Foundation
import Combine
import SwiftUI

enum BookOrderDifficulty: String, CaseIterable, Identifiable {
    case easy, normal, hard, all
    var id: String { rawValue }
}

enum BookSourceScope: String, CaseIterable, Identifiable {
    case ot = "OT", nt = "NT", both = "Both"
    var id: String { rawValue }
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

struct BookOrderRound {
    let prompt: String
    let shuffled: [String]
    let correctOrder: [String]
}

@MainActor
final class BookOrderGameViewModel: ObservableObject {
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
    @Published var lastSubmittedOrder: [String]? = nil
    
    @Published var difficulty: BookOrderDifficulty = .normal
    @Published var source: BookSourceScope = .both
    
    private var sliceFirst: String? = nil
    private var sliceLast: String? = nil
    
    private let keyAllTimeCorrect = "bookorderAllTimeCorrect"
    private let keyAllTimeAnswered = "bookorderAllTimeAnswered"
    private let keyAllTimeBestStreak = "bookorderAllTimeBestStreak"
    
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
    
    func startGame() {
        score = 0
        answered = 0
        currentStreak = 0
        currentBestStreak = 0
        showResult = false
        wasCorrect = false
        showingCorrectOrder = false
        lastSubmittedOrder = nil
        started = true
        nextRound()
    }
    
    private func workingCanon() -> [String] {
        let canon = BibleCanon.canonicalOrder()
        switch source {
        case .both:
            return canon
        case .ot:
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
            currentItems = []
            correctOrder = []
            sliceFirst = nil
            sliceLast = nil
            lastSubmittedOrder = nil
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
        
        // Helper to check if a slice (by indices in full Bible order) has at least one OT and one NT book.
        func isMixedSlice(_ slice: [String]) -> Bool {
            // Build an index map from the full canonical list to detect OT vs NT by "Matthew" boundary.
            // Prefer live BibleData order; fall back to the static fallbackCanon if needed.
            let full = BibleCanon.canonicalOrder()
            let indexMap = Dictionary(uniqueKeysWithValues: full.enumerated().map { ($1, $0) })
            guard let mIdx = indexMap["Matthew"] else {
                // If Matthew not found (e.g., extremely limited dataset), we cannot judge;
                // treat as mixed to avoid infinite rerolls.
                return true
            }
            var hasOT = false
            var hasNT = false
            for name in slice {
                let idx = indexMap[name] ?? Int.max
                if idx < mIdx { hasOT = true } else { hasNT = true }
                if hasOT && hasNT { return true }
            }
            return false
        }
        
        // Choose a slice; if source == .both, try to guarantee a mix (at least one OT and one NT).
        var chosenSlice: [String] = []
        var attempts = 0
        let maxAttempts = 12
        
        repeat {
            attempts += 1
            let start = (maxStart > 0) ? Int.random(in: 0...maxStart) : 0
            let candidate = Array(canon[start..<(start + min(length, canon.count - start))])
            if source == .both {
                if isMixedSlice(candidate) || length >= canon.count {
                    chosenSlice = candidate
                    break
                } else {
                    // keep searching for a mixed slice
                    continue
                }
            } else {
                chosenSlice = candidate
                break
            }
        } while attempts < maxAttempts
        
        // If we failed to find a mixed slice after attempts (edge cases), just use the last candidate
        if chosenSlice.isEmpty {
            let start = (maxStart > 0) ? Int.random(in: 0...maxStart) : 0
            chosenSlice = Array(canon[start..<(start + min(length, canon.count - start))])
        }
        
        correctOrder = chosenSlice
        sliceFirst = chosenSlice.first
        sliceLast = chosenSlice.last
        
        var shuffled = chosenSlice.shuffled()
        if shuffled == chosenSlice && shuffled.count > 1 {
            shuffled.swapAt(0, 1)
        }
        currentItems = shuffled
        
        showResult = false
        wasCorrect = false
        showingCorrectOrder = false
        lastSubmittedOrder = nil
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
    
    var shouldShowComparison: Bool {
        showingCorrectOrder && lastSubmittedOrder != nil && !correctOrder.isEmpty
    }
    
    var comparisonRows: [(your: String, correct: String, isMatch: Bool)] {
        guard let submitted = lastSubmittedOrder else { return [] }
        let count = min(submitted.count, correctOrder.count)
        return (0..<count).map { idx in
            let your = submitted[idx]
            let correct = correctOrder[idx]
            return (your, correct, your == correct)
        }
    }
    
    func checkOrder() {
        guard !currentItems.isEmpty, !correctOrder.isEmpty else {
            wasCorrect = false
            showResult = true
            return
        }
        
        lastSubmittedOrder = currentItems
        
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
        // Keep local mirrors for UI (optional), but centralize authoritative write:
        allTimeCorrect += correct
        allTimeAnswered += answered
        if streak > allTimeBestStreak {
            allTimeBestStreak = streak
        }

        // Centralized write to sync + notify
        GameStats.shared.recordRound(
            game: .bookorder,
            difficulty: .none,
            correct: correct,
            answered: answered,
            currentBestStreak: max(streak, allTimeBestStreak)
        )
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
