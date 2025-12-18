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
        case whoami // NEW
        case wordle // NEW
    }

    // Canonical difficulty for the write API (maps to per-game suffixes)
    enum Difficulty {
        case easy
        case normal     // quiz "normal"
        case medium     // legacy for hangman/beatclock/refmatch — now maps to "normal"
        case hard
        case none       // bookorder (no per-difficulty keys), wordle (no difficulty)
    }

    // Wordle type (split Daily vs Free Play)
    enum WordleType {
        case daily
        case free
    }

    private init() {
        // One-time: wipe legacy unsuffixed keys to avoid double-counting with suffixed data.
        migrateLegacyGameKeysIfNeeded()

        // Listen for iCloud KVS merges of game counters
        observer = NotificationCenter.default.addObserver(
            forName: .gameStatsExternallyUpdated,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                GameStats.shared.version &+= 1
            }
        }
    }

    // MARK: - One-time migration (wipe legacy unsuffixed keys)

    private static let legacyWipeFlagKey = "didWipeLegacyUnsuffixedGameKeys_v1"

    private func migrateLegacyGameKeysIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.legacyWipeFlagKey) else { return }

        // Legacy unsuffixed keys to remove (Book Order intentionally retained as unsuffixed)
        let legacyKeys: [String] = [
            // Quiz (old unsuffixed)
            "quizAllTimeCorrect",
            "quizAllTimeAnswered",
            "quizAllTimeBestStreak",

            // Hangman (old unsuffixed)
            "hangmanAllTimeCorrect",
            "hangmanAllTimeAnswered",
            "hangmanAllTimeBestStreak",

            // Beat the Clock (old unsuffixed)
            "beatclockAllTimeCorrect",
            "beatclockAllTimeAnswered",
            "beatclockAllTimeBestStreak",

            // Verse Match (old unsuffixed)
            "refmatchAllTimeCorrect",
            "refmatchAllTimeAnswered",
            "refmatchAllTimeBestStreak"

            // Who am I? shipped only suffixed keys — nothing to wipe here.
            // Book Order is intentionally unsuffixed — do not wipe.
            // Wordle is new — no legacy unsuffixed keys here.
        ]

        for key in legacyKeys {
            defaults.removeObject(forKey: key)
        }

        // Mark migration complete
        defaults.set(true, forKey: Self.legacyWipeFlagKey)

        // Nudge listeners that totals may have changed due to cleanup
        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
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
            let raw = (Double(totalCorrect) / Double(totalAnswered)) * 100.0
            return min(100, max(0, raw))
        }
    }

    func breakdownSnapshot() -> GameBreakdown {
        let q = quiz
        let h = hangman
        let r = refmatch
        let b = beatclock
        let o = bookorder
        let w = whoami // NEW

        // Wordle: include both types + legacy "_all" for overall breakdown
        let wdDaily = wordle(type: .daily)
        let wdFree = wordle(type: .free)
        let wdLegacyAll = wordleLegacyAll
        let wdCombined = GameStat(
            correct: wdDaily.correct + wdFree.correct + wdLegacyAll.correct,
            answered: wdDaily.answered + wdFree.answered + wdLegacyAll.answered,
            bestStreak: max((wdDaily.bestStreak ?? 0), (wdFree.bestStreak ?? 0), (wdLegacyAll.bestStreak ?? 0))
        )

        let entries: [GameBreakdown.Entry] = [
            .init(name: "Bible Quiz", correct: q.correct, answered: q.answered, bestStreak: q.bestStreak),
            .init(name: "Hangman", correct: h.correct, answered: h.answered, bestStreak: h.bestStreak),
            .init(name: "Verse Match", correct: r.correct, answered: r.answered, bestStreak: r.bestStreak),
            .init(name: "Beat the Clock", correct: b.correct, answered: b.answered, bestStreak: b.bestStreak),
            .init(name: "Book Order", correct: o.correct, answered: o.answered, bestStreak: o.bestStreak),
            .init(name: "Who am I?", correct: w.correct, answered: w.answered, bestStreak: w.bestStreak),
            .init(name: "Wordle (Bible)", correct: wdCombined.correct, answered: wdCombined.answered, bestStreak: wdCombined.bestStreak)
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
                // Change: treat both .normal and legacy .medium as "normal" suffix
                switch difficulty {
                case .easy: return "easy"
                case .normal: return "normal"
                case .medium: return "normal" // legacy callers now write to "normal"
                case .hard: return "hard"
                case .none: return nil
                }
            case .bookorder:
                // Now per-difficulty (easy/normal/hard/all) — map none->all for "All Books" mode
                switch difficulty {
                case .easy: return "easy"
                case .normal: return "normal"
                case .hard: return "hard"
                case .medium: return nil
                case .none: return "all"
                }
            case .whoami:
                switch difficulty {
                case .easy: return "easy"
                case .normal: return "normal"
                case .hard: return "hard"
                case .medium, .none: return nil
                }
            case .wordle:
                // Legacy generic writer — keep writing to "_all" for back-compat (deprecated)
                switch difficulty {
                case .none: return "all"
                default: return "all"
                }
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
            guard let s = suf else { return }
            incInt("bookorderAllTimeCorrect_\(s)", by: addCorrect)
            incInt("bookorderAllTimeAnswered_\(s)", by: addAnswered)
            maxInt("bookorderAllTimeBestStreak_\(s)", candidate: currentBestStreak)

        case .whoami:
            guard let s = suf else { return }
            incInt("whoamiAllTimeCorrect_\(s)", by: addCorrect)
            incInt("whoamiAllTimeAnswered_\(s)", by: addAnswered)
            maxInt("whoamiAllTimeBestStreak_\(s)", candidate: currentBestStreak)

        case .wordle:
            // Deprecated: generic recordRound for Wordle writes to legacy "_all"
            guard let s = suf else { return }
            incInt("wordleAllTimeCorrect_\(s)", by: addCorrect)
            incInt("wordleAllTimeAnswered_\(s)", by: addAnswered)
            maxInt("wordleAllTimeBestStreak_\(s)", candidate: currentBestStreak)
        }

        // NEW: Append to per-day maps and stamp last played
        do {
            // Local yyyy-MM-dd key
            let dayKey = Self.localDayKey(for: Date())

            // Update daily answered map
            var dailyAnswered: [String: Int] = loadJSONMap(forKey: "gamesDailyAnswered")
            dailyAnswered[dayKey, default: 0] = max(0, (dailyAnswered[dayKey] ?? 0) + max(0, addAnswered))
            saveJSONMap(dailyAnswered, forKey: "gamesDailyAnswered")

            // Update daily correct map
            var dailyCorrect: [String: Int] = loadJSONMap(forKey: "gamesDailyCorrect")
            dailyCorrect[dayKey, default: 0] = max(0, (dailyCorrect[dayKey] ?? 0) + max(0, addCorrect))
            saveJSONMap(dailyCorrect, forKey: "gamesDailyCorrect")

            // Stamp last played time and game name
            let nowTS = Date().timeIntervalSince1970
            let defaults = UserDefaults.standard
            defaults.set(nowTS, forKey: "gamesLastPlayedAt")
            defaults.set(Self.gameDisplayName(for: game), forKey: "gamesLastPlayedGameName")
        }

        // Push changed keys to iCloud KVS
        let kvs = iCloudSyncCoordinator.shared
        for key in changedKeys {
            kvs.pushKey(key)
        }

        // Notify UI (Home games card, Stats) to refresh gamer score
        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

    // New: Wordle type-aware writer
    func recordWordleRound(type: WordleType, correct addCorrect: Int, answered addAnswered: Int, currentBestStreak: Int) {
        let defaults = UserDefaults.standard
        let suf = (type == .daily) ? "daily" : "free"
        func setInt(_ key: String, _ value: Int) {
            defaults.set(max(0, value), forKey: key)
            iCloudSyncCoordinator.shared.pushKey(key)
        }
        func incInt(_ key: String, by delta: Int) {
            let old = defaults.integer(forKey: key)
            setInt(key, old + delta)
        }
        func maxInt(_ key: String, candidate: Int) {
            let old = defaults.integer(forKey: key)
            if candidate > old { setInt(key, candidate) }
        }

        incInt("wordleAllTimeCorrect_\(suf)", by: addCorrect)
        incInt("wordleAllTimeAnswered_\(suf)", by: addAnswered)
        maxInt("wordleAllTimeBestStreak_\(suf)", candidate: currentBestStreak)

        // Keep legacy “_all” untouched for back-compat. Do not auto-aggregate to "_all".

        // Daily progress maps + last played metadata (same as generic path)
        do {
            let dayKey = Self.localDayKey(for: Date())
            var dailyAnswered: [String: Int] = loadJSONMap(forKey: "gamesDailyAnswered")
            dailyAnswered[dayKey, default: 0] = max(0, (dailyAnswered[dayKey] ?? 0) + max(0, addAnswered))
            saveJSONMap(dailyAnswered, forKey: "gamesDailyAnswered")

            var dailyCorrect: [String: Int] = loadJSONMap(forKey: "gamesDailyCorrect")
            dailyCorrect[dayKey, default: 0] = max(0, (dailyCorrect[dayKey] ?? 0) + max(0, addCorrect))
            saveJSONMap(dailyCorrect, forKey: "gamesDailyCorrect")

            let nowTS = Date().timeIntervalSince1970
            let defaults = UserDefaults.standard
            defaults.set(nowTS, forKey: "gamesLastPlayedAt")
            defaults.set(Self.gameDisplayName(for: .wordle), forKey: "gamesLastPlayedGameName")
        }

        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

    // NEW: Wordle result writer with guesses + histogram tracking
    func recordWordleResult(type: WordleType, won: Bool, guesses: Int, currentBestStreak: Int) {
        // First, update the standard per-type counters (correct/answered/streak)
        recordWordleRound(
            type: type,
            correct: won ? 1 : 0,
            answered: 1,
            currentBestStreak: currentBestStreak
        )

        // Only track guess distribution and average on wins
        guard won else { return }

        let defaults = UserDefaults.standard
        let suf = (type == .daily) ? "daily" : "free"
        let clamped = max(1, min(6, guesses))

        func setInt(_ key: String, _ value: Int) {
            defaults.set(max(0, value), forKey: key)
            iCloudSyncCoordinator.shared.pushKey(key)
        }
        func incInt(_ key: String, by delta: Int) {
            let old = defaults.integer(forKey: key)
            setInt(key, old + delta)
        }

        // Sum of guesses across wins (for average = sum / totalWins)
        incInt("wordleWinsGuessSum_\(suf)", by: clamped)

        // Histogram bucket for this guess number
        incInt("wordleWinsOnGuess\(clamped)_\(suf)", by: 1)

        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

    // MARK: - Aggregation (reads)

    private func readInt(_ key: String) -> Int {
        UserDefaults.standard.integer(forKey: key)
    }

    // Prefer suffixed keys; only use legacy if all suffixed are zero.
    private func sumAcross(prefix: String, parts: [String], legacyKey: String?) -> Int {
        let partValues = parts.map { readInt("\(prefix)\($0)") }
        let sumParts = partValues.reduce(0) { $0 + max(0, $1) }
        let hasAnySuffixed = partValues.contains { $0 > 0 }
        if hasAnySuffixed {
            return max(0, sumParts)
        } else {
            let legacy = legacyKey.map { readInt($0) } ?? 0
            return max(0, sumParts + legacy)
        }
    }

    private func maxAcross(prefix: String, parts: [String], legacyKey: String?) -> Int {
        let partValues = parts.map { readInt("\(prefix)\($0)") }
        let hasAnySuffixed = partValues.contains { $0 > 0 }
        let bestParts = partValues.max() ?? 0
        if hasAnySuffixed {
            return max(0, bestParts)
        } else {
            let legacy = legacyKey.map { readInt($0) } ?? 0
            return max(0, max(bestParts, legacy))
        }
    }

    private struct GameStat {
        let correct: Int
        let answered: Int
        let bestStreak: Int?
    }

    // Updated: aggregate suffixed + conditional legacy for Quiz
    private var quiz: GameStat {
        let c = sumAcross(prefix: "quizAllTimeCorrect", parts: ["_easy","_normal","_hard"], legacyKey: "quizAllTimeCorrect")
        let a = sumAcross(prefix: "quizAllTimeAnswered", parts: ["_easy","_normal","_hard"], legacyKey: "quizAllTimeAnswered")
        let best = maxAcross(prefix: "quizAllTimeBestStreak", parts: ["_easy","_normal","_hard"], legacyKey: "quizAllTimeBestStreak")
        return GameStat(correct: c, answered: a, bestStreak: best == 0 ? nil : best)
    }

    private var hangman: GameStat {
        // Change: read both "_normal" and legacy "_medium"
        let c = sumAcross(prefix: "hangmanAllTimeCorrect", parts: ["_easy","_normal","_hard","_medium"], legacyKey: "hangmanAllTimeCorrect")
        let a = sumAcross(prefix: "hangmanAllTimeAnswered", parts: ["_easy","_normal","_hard","_medium"], legacyKey: "hangmanAllTimeAnswered")
        let best = maxAcross(prefix: "hangmanAllTimeBestStreak", parts: ["_easy","_normal","_hard","_medium"], legacyKey: "hangmanAllTimeBestStreak")
        return GameStat(correct: c, answered: a, bestStreak: best == 0 ? nil : best)
    }

    private var refmatch: GameStat {
        let c = sumAcross(prefix: "refmatchAllTimeCorrect", parts: ["_easy","_normal","_hard","_medium"], legacyKey: "refmatchAllTimeCorrect")
        let a = sumAcross(prefix: "refmatchAllTimeAnswered", parts: ["_easy","_normal","_hard","_medium"], legacyKey: "refmatchAllTimeAnswered")
        let best = maxAcross(prefix: "refmatchAllTimeBestStreak", parts: ["_easy","_normal","_hard","_medium"], legacyKey: "refmatchAllTimeBestStreak")
        return GameStat(correct: c, answered: a, bestStreak: best == 0 ? nil : best)
    }

    // Updated: aggregate suffixed + conditional legacy for Beat the Clock
    private var beatclock: GameStat {
        let c = sumAcross(prefix: "beatclockAllTimeCorrect", parts: ["_easy","_normal","_hard","_medium"], legacyKey: "beatclockAllTimeCorrect")
        let a = sumAcross(prefix: "beatclockAllTimeAnswered", parts: ["_easy","_normal","_hard","_medium"], legacyKey: "beatclockAllTimeAnswered")
        let best = maxAcross(prefix: "beatclockAllTimeBestStreak", parts: ["_easy","_normal","_hard","_medium"], legacyKey: "beatclockAllTimeBestStreak")
        return GameStat(correct: c, answered: a, bestStreak: best == 0 ? nil : best)
    }

    private var bookorder: GameStat {
        // New per-difficulty suffixes: easy/normal/hard/all
        let c = sumAcross(prefix: "bookorderAllTimeCorrect", parts: ["_easy","_normal","_hard","_all"], legacyKey: "bookorderAllTimeCorrect")
        let a = sumAcross(prefix: "bookorderAllTimeAnswered", parts: ["_easy","_normal","_hard","_all"], legacyKey: "bookorderAllTimeAnswered")
        let best = maxAcross(prefix: "bookorderAllTimeBestStreak", parts: ["_easy","_normal","_hard","_all"], legacyKey: "bookorderAllTimeBestStreak")
        return GameStat(correct: c, answered: a, bestStreak: best == 0 ? nil : best)
    }

    // NEW: aggregate for Who am I? (easy/normal/hard) — keep consistent helper
    private var whoami: GameStat {
        let c = sumAcross(prefix: "whoamiAllTimeCorrect", parts: ["_easy","_normal","_hard"], legacyKey: "whoamiAllTimeCorrect")
        let a = sumAcross(prefix: "whoamiAllTimeAnswered", parts: ["_easy","_normal","_hard"], legacyKey: "whoamiAllTimeAnswered")
        let best = maxAcross(prefix: "whoamiAllTimeBestStreak", parts: ["_easy","_normal","_hard"], legacyKey: "whoamiAllTimeBestStreak")
        return GameStat(correct: c, answered: a, bestStreak: best == 0 ? nil : best)
    }

    // NEW: Wordle per-type readers + legacy
    private func wordle(type: WordleType) -> GameStat {
        let suf = (type == .daily) ? "_daily" : "_free"
        let c = readInt("wordleAllTimeCorrect\(suf)")
        let a = readInt("wordleAllTimeAnswered\(suf)")
        let best = readInt("wordleAllTimeBestStreak\(suf)")
        return GameStat(correct: max(0, c), answered: max(0, a), bestStreak: (best == 0 ? nil : best))
    }
    private var wordleLegacyAll: GameStat {
        let c = readInt("wordleAllTimeCorrect_all")
        let a = readInt("wordleAllTimeAnswered_all")
        let best = readInt("wordleAllTimeBestStreak_all")
        return GameStat(correct: max(0, c), answered: max(0, a), bestStreak: (best == 0 ? nil : best))
    }

    // NEW: Wordle win-guess stats readers
    func wordleWinGuessStats(type: WordleType) -> (averageGuessesOnWins: Double, winsByGuess: [Int]) {
        let suf = (type == .daily) ? "daily" : "free"
        let totalWins = max(0, readInt("wordleAllTimeCorrect_\(suf)"))
        let sumGuesses = max(0, readInt("wordleWinsGuessSum_\(suf)"))
        let dist = (1...6).map { idx in max(0, readInt("wordleWinsOnGuess\(idx)_\(suf)")) }
        let avg: Double = totalWins > 0 ? Double(sumGuesses) / Double(totalWins) : 0
        return (avg, dist)
    }

    func wordleWinGuessStatsCombined() -> (averageGuessesOnWins: Double, winsByGuess: [Int]) {
        // Combine daily + free (ignore legacy "_all" for these new stats)
        let (avgDaily, distDaily) = wordleWinGuessStats(type: .daily)
        let (avgFree, distFree) = wordleWinGuessStats(type: .free)

        // Average needs to be recomputed from totals to be correct:
        let winsDaily = max(0, readInt("wordleAllTimeCorrect_daily"))
        let winsFree = max(0, readInt("wordleAllTimeCorrect_free"))
        let sumDaily = max(0, readInt("wordleWinsGuessSum_daily"))
        let sumFree = max(0, readInt("wordleWinsGuessSum_free"))
        let totalWins = winsDaily + winsFree
        let totalSum = sumDaily + sumFree
        let avg = totalWins > 0 ? Double(totalSum) / Double(totalWins) : 0

        let dist = zip(distDaily, distFree).map(+)
        return (avg, dist)
    }

    private func aggregateAll() -> (correct: Int, answered: Int) {
        let stats = [quiz, hangman, refmatch, beatclock, bookorder, whoami]
        let wordleCombined = GameStat(
            correct: wordle(type: .daily).correct + wordle(type: .free).correct + wordleLegacyAll.correct,
            answered: wordle(type: .daily).answered + wordle(type: .free).answered + wordleLegacyAll.answered,
            bestStreak: nil
        )
        let totalCorrect = stats.reduce(0) { $0 + max(0, $1.correct) } + wordleCombined.correct
        let totalAnswered = stats.reduce(0) { $0 + max(0, $1.answered) } + wordleCombined.answered
        return (totalCorrect, totalAnswered)
    }

    private func percentage(correct: Int, answered: Int) -> Double {
        guard answered > 0 else { return 0 }
        let raw = (Double(correct) / Double(answered)) * 100.0
        return min(100, max(0, raw))
    }

    // MARK: - New daily helpers and last played

    // Local-day key formatter
    private static func localDayKey(for date: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        var cal = calendar
        cal.timeZone = .autoupdatingCurrent
        let start = cal.startOfDay(for: date)
        let comps = cal.dateComponents([.year, .month, .day], from: start)
        let y = comps.year ?? 1970
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    // Load/save JSON map [String: Int] in UserDefaults
    private func loadJSONMap(forKey key: String) -> [String: Int] {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: key),
              let map = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return map
    }

    private func saveJSONMap(_ map: [String: Int], forKey key: String) {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(map) {
            defaults.set(data, forKey: key)
        }
    }

    private static func gameDisplayName(for id: GameID) -> String {
        switch id {
        case .quiz: return "Bible Quiz"
        case .hangman: return "Hangman"
        case .beatclock: return "Beat the Clock"
        case .refmatch: return "Verse Match"
        case .bookorder: return "Book Order"
        case .whoami: return "Who am I?"
        case .wordle: return "Wordle (Bible)"
        }
    }

    // Returns today's (answered, correct, pct)
    func todayStats(now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> (answered: Int, correct: Int, pct: Double) {
        let key = Self.localDayKey(for: now, calendar: calendar)
        let answeredMap: [String: Int] = loadJSONMap(forKey: "gamesDailyAnswered")
        let correctMap: [String: Int] = loadJSONMap(forKey: "gamesDailyCorrect")
        let ans = max(0, answeredMap[key] ?? 0)
        let cor = max(0, correctMap[key] ?? 0)
        let pct = ans > 0 ? min(100, max(0, (Double(cor) / Double(ans)) * 100.0)) : 0
        return (ans, cor, pct)
    }

    var lastPlayedGameName: String? {
        UserDefaults.standard.string(forKey: "gamesLastPlayedGameName")
    }
}

