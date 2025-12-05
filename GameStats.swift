import Foundation
import Combine

// Centralized aggregator for all game counters and derived Gamer Score.
// Reads UserDefaults-backed counters (which are synced via iCloudSyncCoordinator)
// and computes totals and percentage consistently for all views.
@MainActor
final class GameStats: ObservableObject {
    static let shared = GameStats()

    // Simple version token to force SwiftUI refreshes when external sync merges occur.
    @Published private(set) var version: Int = 0

    private var cancellable: Any?

    private init() {
        // Listen for iCloud KVS merges of game counters
        cancellable = NotificationCenter.default.addObserver(
            forName: .gameStatsExternallyUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.version &+= 1
        }
    }

    // MARK: - Public API

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

    // MARK: - Aggregation

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
        return GameStat(correct: c, answered: a, bestStreak: best)
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
        return GameStat(correct: c, answered: a, bestStreak: best)
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
