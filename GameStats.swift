import Foundation
import Combine

// Centralized aggregator and writer for all game counters and derived Gamer Score.
// Uses UserDefaults-backed counters (synced via iCloudSyncCoordinator) and exposes
// a single write API for all games. Also provides a per-game breakdown snapshot for UI.
@MainActor
final class GameStats: ObservableObject {
    static let shared = GameStats()

    // Simple version token to force SwiftUI refreshes when external sync merges occur.
    @Published private(set) var version: Int = 0

    private var observer: Any?

    // Canonical game identifiers
    enum GameID {
        case quiz
        case hangman
        case beatclock
        case refmatch
        case bookorder
    }

    // Canonical difficulty for the write API (maps to per-game suffixes)
    enum Difficulty {
        case easy
        case normal     // quiz "normal"
        case medium     // hangman/beatclock/refmatch "medium"
        case hard
        case none       // bookorder (no per-difficulty keys)
    }

    private init() {
        // Listen for iCloud KVS merges of game counters
        observer = NotificationCenter.default.addObserver(
            forName: .gameStatsExternallyUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.version &+= 1
        }
    }

    // MARK: - Public read API

    struct Snapshot {
        let totalCorrect: Int
        let totalAnswered: Int
        let percentage: Double // 0...100
    }

    func snapshot() -> Snapshot {
        let totals = aggregateAll()
        let pct = percentage(correct: totals.correct, answered: totals.answered)
        return Snapshot(totalCorrect: totals.correct, totalAnswered: totals.answered, percentage: pct)
    }

    // Public breakdown for Stats tab
    struct GameBreakdown {
        struct Entry {
            let name: String
            let correct: Int
            let answered: Int
            let bestStreak: Int?
        }
        let entries: [Entry]
        var totalCorrect: Int { entries.reduce(0) { $0 + max(0, $1.correct) } }
        var totalAnswered: Int { entries.reduce(0) { $0 + max(0, $1.answered) } }
        var percentage: Double {
            guard totalAnswered > 0 else { return 0 }
            return (Double(totalCorrect) / Double(totalAnswered)) * 100.0
        }
    }

    func breakdownSnapshot() -> GameBreakdown {
        let q = quiz
        let h = hangman
        let r = refmatch
        let b = beatclock
        let o = bookorder
        let entries: [GameBreakdown.Entry] = [
            .init(name: "Quiz", correct: q.correct, answered: q.answered, bestStreak: q.bestStreak),
            .init(name: "Hangman", correct: h.correct, answered: h.answered, bestStreak: h.bestStreak),
            .init(name: "Verse Match", correct: r.correct, answered: r.answered, bestStreak: r.bestStreak),
            .init(name: "Beat the Clock", correct: b.correct, answered: b.answered, bestStreak: b.bestStreak),
            .init(name: "Book Order", correct: o.correct, answered: o.answered, bestStreak: o.bestStreak)
        ]
        return GameBreakdown(entries: entries)
    }

    // MARK: - Public write API

    // Call this when a round/question ends to update all-time stats and sync.
    func recordRound(game: GameID, difficulty: Difficulty, correct addCorrect: Int, answered addAnswered: Int, currentBestStreak: Int) {
        let defaults = UserDefaults.standard
        var changedKeys: [String] = []

        func setInt(_ key: String, _ value: Int) {
            let v = max(0, value)
            defaults.set(v, forKey: key)
            changedKeys.append(key)
        }

        func incInt(_ key: String, by delta: Int) {
            let old = defaults.integer(forKey: key)
            setInt(key, old + delta)
        }

        func maxInt(_ key: String, candidate: Int) {
            let old = defaults.integer(forKey: key)
            if candidate > old {
                setInt(key, candidate)
            }
        }

        // Map difficulty to per-game suffix
        func suffix(for game: GameID, difficulty: Difficulty) -> String? {
            switch game {
            case .quiz:
                switch difficulty {
                case .easy: return "easy"
                case .normal: return "normal"
                case .hard: return "hard"
                case .medium, .none: return nil
                }
            case .hangman, .beatclock, .refmatch:
                switch difficulty {
                case .easy: return "easy"
                case .medium: return "medium"
                case .hard: return "hard"
                case .normal, .none: return nil
                }
            case .bookorder:
                return nil // unsuffixed keys
            }
        }

        // Resolve keys and apply updates
        let suf = suffix(for: game, difficulty: difficulty)

        switch game {
        case .quiz:
            guard let s = suf else { return }
            incInt("quizAllTimeCorrect_\(s)", by: addCorrect)
            incInt("quizAllTimeAnswered_\(s)", by: addAnswered)
            maxInt("quizAllTimeBestStreak_\(s)", candidate: currentBestStreak)

        case .hangman:
            guard let s = suf else { return }
            incInt("hangmanAllTimeCorrect_\(s)", by: addCorrect)
            incInt("hangmanAllTimeAnswered_\(s)", by: addAnswered)
            maxInt("hangmanAllTimeBestStreak_\(s)", candidate: currentBestStreak)

        case .beatclock:
            guard let s = suf else { return }
            incInt("beatclockAllTimeCorrect_\(s)", by: addCorrect)
            incInt("beatclockAllTimeAnswered_\(s)", by: addAnswered)
            maxInt("beatclockAllTimeBestStreak_\(s)", candidate: currentBestStreak)

        case .refmatch:
            guard let s = suf else { return }
            incInt("refmatchAllTimeCorrect_\(s)", by: addCorrect)
            incInt("refmatchAllTimeAnswered_\(s)", by: addAnswered)
            maxInt("refmatchAllTimeBestStreak_\(s)", candidate: currentBestStreak)

        case .bookorder:
            incInt("bookorderAllTimeCorrect", by: addCorrect)
            incInt("bookorderAllTimeAnswered", by: addAnswered)
            maxInt("bookorderAllTimeBestStreak", candidate: currentBestStreak)
        }

        // Push changed keys to iCloud KVS
        let kvs = iCloudSyncCoordinator.shared
        for key in changedKeys {
            kvs.pushKey(key)
        }

        // Notify UI (Home games card, Stats) to refresh gamer score
        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

    // MARK: - Aggregation (reads)

    private func readInt(_ key: String) -> Int {
        UserDefaults.standard.integer(forKey: key)
    }

    // Prefer per-difficulty keys; fall back to legacy unsuffixed if all zeros
    private func sumWithFallback(prefix: String, parts: [String], legacyKey: String?) -> Int {
        let values = parts.map { readInt("\(prefix)\($0)") }
        let sum = values.reduce(0, +)
        if sum > 0 { return sum }
        if let legacy = legacyKey { return readInt(legacy) }
        return 0
    }

    private func maxWithFallback(prefix: String, parts: [String], legacyKey: String?) -> Int {
        let values = parts.map { readInt("\(prefix)\($0)") }
        let maxVal = values.max() ?? 0
        if maxVal > 0 { return maxVal }
        if let legacy = legacyKey { return readInt(legacy) }
        return 0
    }

    private struct GameStat {
        let correct: Int
        let answered: Int
        let bestStreak: Int?
    }

    private var quiz: GameStat {
        let c = readInt("quizAllTimeCorrect_easy")
              + readInt("quizAllTimeCorrect_normal")
              + readInt("quizAllTimeCorrect_hard")
        let a = readInt("quizAllTimeAnswered_easy")
              + readInt("quizAllTimeAnswered_normal")
              + readInt("quizAllTimeAnswered_hard")
        let best = max(
            readInt("quizAllTimeBestStreak_easy"),
            readInt("quizAllTimeBestStreak_normal"),
            readInt("quizAllTimeBestStreak_hard")
        )
        return GameStat(correct: c, answered: a, bestStreak: best == 0 ? nil : best)
    }

    private var hangman: GameStat {
        let c = sumWithFallback(prefix: "hangmanAllTimeCorrect", parts: ["_easy","_medium","_hard"], legacyKey: "hangmanAllTimeCorrect")
        let a = sumWithFallback(prefix: "hangmanAllTimeAnswered", parts: ["_easy","_medium","_hard"], legacyKey: "hangmanAllTimeAnswered")
        let best = maxWithFallback(prefix: "hangmanAllTimeBestStreak", parts: ["_easy","_medium","_hard"], legacyKey: "hangmanAllTimeBestStreak")
        return GameStat(correct: c, answered: a, bestStreak: best == 0 ? nil : best)
    }

    private var refmatch: GameStat {
        let c = sumWithFallback(prefix: "refmatchAllTimeCorrect", parts: ["_easy","_medium","_hard"], legacyKey: "refmatchAllTimeCorrect")
        let a = sumWithFallback(prefix: "refmatchAllTimeAnswered", parts: ["_easy","_medium","_hard"], legacyKey: "refmatchAllTimeAnswered")
        let best = maxWithFallback(prefix: "refmatchAllTimeBestStreak", parts: ["_easy","_medium","_hard"], legacyKey: "refmatchAllTimeBestStreak")
        return GameStat(correct: c, answered: a, bestStreak: best == 0 ? nil : best)
    }

    private var beatclock: GameStat {
        let c = readInt("beatclockAllTimeCorrect_easy")
              + readInt("beatclockAllTimeCorrect_medium")
              + readInt("beatclockAllTimeCorrect_hard")
        let a = readInt("beatclockAllTimeAnswered_easy")
              + readInt("beatclockAllTimeAnswered_medium")
              + readInt("beatclockAllTimeAnswered_hard")
        let best = max(
            readInt("beatclockAllTimeBestStreak_easy"),
            readInt("beatclockAllTimeBestStreak_medium"),
            readInt("beatclockAllTimeBestStreak_hard")
        )
        return GameStat(correct: c, answered: a, bestStreak: best == 0 ? nil : best)
    }

    private var bookorder: GameStat {
        let c = readInt("bookorderAllTimeCorrect")
        let a = readInt("bookorderAllTimeAnswered")
        let best = readInt("bookorderAllTimeBestStreak")
        return GameStat(correct: c, answered: a, bestStreak: best == 0 ? nil : best)
    }

    private func aggregateAll() -> (correct: Int, answered: Int) {
        let stats = [quiz, hangman, refmatch, beatclock, bookorder]
        let totalCorrect = stats.reduce(0) { $0 + max(0, $1.correct) }
        let totalAnswered = stats.reduce(0) { $0 + max(0, $1.answered) }
        return (totalCorrect, totalAnswered)
    }

    private func percentage(correct: Int, answered: Int) -> Double {
        guard answered > 0 else { return 0 }
        return (Double(correct) / Double(answered)) * 100.0
    }
}
