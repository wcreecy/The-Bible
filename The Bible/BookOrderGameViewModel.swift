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
    
    @Published var difficulty: BookOrderDifficulty = .normal {
        didSet { seedStreakFromPersistence() }
    }
    @Published var source: BookSourceScope = .both
    
    private var sliceFirst: String? = nil
    private var sliceLast: String? = nil
    
    // Per-difficulty suffix (used for persistence keys for streaks and writes via GameStats)
    private var keySuffix: String {
        switch difficulty {
        case .easy: return "easy"
        case .normal: return "normal"
        case .hard: return "hard"
        case .all: return "all"
        }
    }
    private var keyAllTimeCorrect: String { "bookorderAllTimeCorrect_\(keySuffix)" }
    private var keyAllTimeAnswered: String { "bookorderAllTimeAnswered_\(keySuffix)" }
    private var keyAllTimeBestStreak: String { "bookorderAllTimeBestStreak_\(keySuffix)" }
    
    // NEW: Aggregate getters for the in-game scoreboard that avoid double-counting.
    private func readInt(_ key: String) -> Int { max(0, UserDefaults.standard.integer(forKey: key)) }
    private var diffsNoAll: [String] { ["easy", "normal", "hard"] }

    // Prefer combined "_all" when present; otherwise sum easy/normal/hard only.
    private func combinedOrSum(_ base: String) -> Int {
        let combined = readInt("\(base)_all")
        if combined > 0 {
            return combined
        } else {
            return diffsNoAll.reduce(0) { acc, suf in acc + readInt("\(base)_\(suf)") }
        }
    }

    // Prefer combined best streak when present; otherwise max across easy/normal/hard.
    private func combinedOrMax(_ base: String) -> Int {
        let combined = readInt("\(base)_all")
        if combined > 0 {
            return combined
        } else {
            return diffsNoAll.map { readInt("\(base)_\($0)") }.max() ?? 0
        }
    }

    // Displayed on the scoreboard “All-time” row (aggregate without double-counting)
    var allTimeCorrect: Int {
        combinedOrSum("bookorderAllTimeCorrect")
    }
    
    var allTimeAnswered: Int {
        combinedOrSum("bookorderAllTimeAnswered")
    }
    
    var allTimeBestStreak: Int {
        combinedOrMax("bookorderAllTimeBestStreak")
    }

    // MARK: - Persistent streak helpers (per difficulty)
    private var persistentStreakKey: String { "bookorderPersistentStreak_\(keySuffix)" }
    private var persistentBestKey: String { "bookorderPersistentBestStreak_\(keySuffix)" }

    private func readPersistentStreak() -> Int {
        max(0, UserDefaults.standard.integer(forKey: persistentStreakKey))
    }
    private func writePersistentStreak(_ value: Int) {
        let v = max(0, value)
        UserDefaults.standard.set(v, forKey: persistentStreakKey)
        iCloudSyncCoordinator.shared.pushKey(persistentStreakKey)
    }
    private func readPersistentBest() -> Int {
        max(0, UserDefaults.standard.integer(forKey: persistentBestKey))
    }
    private func writePersistentBest(_ value: Int) {
        let v = max(0, value)
        UserDefaults.standard.set(v, forKey: persistentBestKey)
        iCloudSyncCoordinator.shared.pushKey(persistentBestKey)
    }
    private func seedStreakFromPersistence() {
        let persisted = readPersistentStreak()
        currentStreak = persisted
        let persistedBest = readPersistentBest()
        currentBestStreak = max(currentBestStreak, persistedBest)
    }
    
    func startGame() {
        score = 0
        answered = 0
        // Do NOT reset persistent streaks here; seed from persistence
        seedStreakFromPersistence()
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
        case .easy:   length = 5
        case .normal: length = 10
        case .hard:   length = 15
        case .all:    length = canon.count
        }
        
        // Helper: OT/NT split based on full canonical list (uses "Matthew" boundary)
        let full = BibleCanon.canonicalOrder()
        let indexMap = Dictionary(uniqueKeysWithValues: full.enumerated().map { ($1, $0) })
        let matthewIdx = indexMap["Matthew"] ?? Int.max
        func isOT(_ name: String) -> Bool { (indexMap[name] ?? Int.max) < matthewIdx }
        func isNT(_ name: String) -> Bool { (indexMap[name] ?? Int.max) >= matthewIdx }
        
        // For Source .both and difficulty != .all, switch to non‑contiguous uniform sampling across the whole canon.
        if source == .both && difficulty != .all {
            var picks = Array(Set(canon)).shuffled()
            if picks.count > length { picks = Array(picks.prefix(length)) }
            
            // Ensure at least one OT and one NT for variety (if possible)
            let hasOT = picks.contains(where: isOT)
            let hasNT = picks.contains(where: isNT)
            if !(hasOT && hasNT) {
                // Try to fix by swapping one item if both testaments exist in the full canon
                let otPool = canon.filter(isOT)
                let ntPool = canon.filter(isNT)
                if !otPool.isEmpty, !ntPool.isEmpty, picks.count >= 1 {
                    if !hasOT, let replacement = otPool.randomElement() {
                        // Replace a random NT pick
                        if let idx = picks.firstIndex(where: isNT) { picks[idx] = replacement }
                    } else if !hasNT, let replacement = ntPool.randomElement() {
                        // Replace a random OT pick
                        if let idx = picks.firstIndex(where: isOT) { picks[idx] = replacement }
                    }
                }
            }
            
            // Correct order is canonical; UI shows shuffled
            let orderPos = Dictionary(uniqueKeysWithValues: full.enumerated().map { ($1, $0) })
            let ordered = picks.sorted { (orderPos[$0] ?? .max) < (orderPos[$1] ?? .max) }
            correctOrder = ordered
            currentItems = ordered.shuffled()
            sliceFirst = ordered.first
            sliceLast = ordered.last
            
            showResult = false
            wasCorrect = false
            showingCorrectOrder = false
            lastSubmittedOrder = nil
            return
        }
        
        // Existing contiguous-slice behavior for OT/NT scopes, and for "All Books" in any scope.
        let maxStart = max(0, canon.count - length)
        
        func isMixedSlice(_ slice: [String]) -> Bool {
            // If Matthew not found (edge case), treat as mixed to avoid infinite rerolls.
            guard matthewIdx != Int.max else { return true }
            var hasOT = false
            var hasNT = false
            for name in slice {
                let idx = indexMap[name] ?? Int.max
                if idx < matthewIdx { hasOT = true } else { hasNT = true }
                if hasOT && hasNT { return true }
            }
            return false
        }
        
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
                    continue
                }
            } else {
                chosenSlice = candidate
                break
            }
        } while attempts < maxAttempts
        
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
        case .ot:   scope = "(Old Testament)"
        case .nt:   scope = "(New Testament)"
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

            // Persistent streak: increment on correct
            let persisted = readPersistentStreak() + 1
            writePersistentStreak(persisted)
            currentStreak = persisted

            // Update persistent best if needed
            let bestPersisted = readPersistentBest()
            if persisted > bestPersisted {
                writePersistentBest(persisted)
            }
            currentBestStreak = max(currentBestStreak, persisted, readPersistentBest())
        } else {
            wasCorrect = false

            // Persistent streak: reset on incorrect
            writePersistentStreak(0)
            currentStreak = 0

            showingCorrectOrder = true
        }
        
        answered += 1
        
        updateAllTime(correct: wasCorrect ? 1 : 0, answered: 1, streak: currentBestStreak)
        
        showResult = true
    }
    
    // Single source of truth: delegate all writes to GameStats to avoid double-counting.
    private func updateAllTime(correct: Int, answered: Int, streak: Int) {
        // Map BookOrderDifficulty to GameStats.Difficulty
        let statsDifficulty: GameStats.Difficulty = {
            switch difficulty {
            case .easy: return .easy
            case .normal: return .normal
            case .hard: return .hard
            case .all: return .none // treated as "all" by GameStats suffix mapping
            }
        }()
        GameStats.shared.recordRound(
            game: .bookorder,
            difficulty: statsDifficulty,
            correct: correct,
            answered: answered,
            currentBestStreak: streak
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
