import Foundation
import Observation

@MainActor
@Observable
final class GameStats {
    static let shared = GameStats()

    /// Bumped whenever game stats change, so views reading it refresh.
    private(set) var version: Int = 0

    @ObservationIgnored private var observer: Any?

    enum GameID {
        case quiz
        case trivia
        case hangman
        case beatclock
        case versematch
        case bookorder
        case whoami
        case wordsearch
        case scramble
        case wordle
    }

    enum Difficulty {
        case easy
        case normal
        case medium
        case hard
        case none
    }

    enum WordleType {
        case daily
        case free
    }

    enum WordMode {
        case normal
        case hard
    }

    private init() {
        GameStatsMigrations.runAll()

        observer = NotificationCenter.default.addObserver(
            forName: .gameStatsExternallyUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Important: mutate the existing instance; do NOT touch GameStats.shared here.
            // Hop to the main actor explicitly to satisfy Sendable closure constraints.
            Task { @MainActor [weak self] in
                self?.version &+= 1
            }
        }
    }

    /// Games were once shown as "Verses", "Who?" and "WORD". Those names are still found in
    /// stored values (last played, saved Today Challenges, other devices), so every lookup
    /// by display name goes through this first.
    static func canonicalDisplayName(_ name: String) -> String {
        switch name {
        case "Bible Quiz": return "Quiz"
        case "Beat the Clock": return "Countdown"
        case "Verse Match": return "Verses"
        case "Who Am I?": return "Who?"
        case "WORD", "Wordle (Bible)": return "Word"
        default: return name
        }
    }

    static func storageKeyForWord(mode: WordMode) -> String {
        switch mode {
        case .normal: return "word_normal"
        case .hard:   return "word_hard"
        }
    }

    /// The four stored maps behind a game's per-book accuracy: all-time and per-day, answered and correct.
    struct PerBookKeys {
        let answered: String
        let correct: String
        let dailyAnswered: String
        let dailyCorrect: String

        static let quiz = PerBookKeys(
            answered: "quizPerBookAnsweredMap", correct: "quizPerBookCorrectMap",
            dailyAnswered: "quizPerBookDailyAnswered", dailyCorrect: "quizPerBookDailyCorrect"
        )
        static let trivia = PerBookKeys(
            answered: "triviaPerBookAnsweredMap", correct: "triviaPerBookCorrectMap",
            dailyAnswered: "triviaPerBookDailyAnswered", dailyCorrect: "triviaPerBookDailyCorrect"
        )
        static let verseMatch = PerBookKeys(
            answered: "versematchPerBookAnsweredMap", correct: "versematchPerBookCorrectMap",
            dailyAnswered: "versematchPerBookDailyAnswered", dailyCorrect: "versematchPerBookDailyCorrect"
        )
    }

    func readInt(_ key: String) -> Int {
        UserDefaults.standard.integer(forKey: key)
    }

    static func localDayKey(for date: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        var cal = calendar
        cal.timeZone = .autoupdatingCurrent
        let start = cal.startOfDay(for: date)
        let comps = cal.dateComponents([.year, .month, .day], from: start)
        let y = comps.year ?? 1970
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    // MARK: - Decoded map cache
    //
    // Stats screens read the same JSON maps dozens of times per render. Each cache entry keeps
    // the exact bytes it was decoded from and is reused only while UserDefaults still holds
    // identical bytes. Writes from anywhere (ledger reconcile, iCloud merge, reset) therefore
    // can't leave a stale map behind, and no explicit invalidation is needed.
    private struct CachedMap<Value> {
        let data: Data
        let map: Value
    }

    @ObservationIgnored private var flatMapCache: [String: CachedMap<[String: Int]>] = [:]
    @ObservationIgnored private var nestedMapCache: [String: CachedMap<[String: [String: Int]]>] = [:]

    func loadJSONMap(forKey key: String) -> [String: Int] {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            flatMapCache[key] = nil
            return [:]
        }
        if let cached = flatMapCache[key], cached.data == data { return cached.map }
        guard let map = PersistedDecoding.decode([String: Int].self, from: data, key: key, keepingUnreadableIn: .standard) else {
            flatMapCache[key] = nil
            return [:]
        }
        flatMapCache[key] = CachedMap(data: data, map: map)
        return map
    }

    func saveJSONMap(_ map: [String: Int], forKey key: String) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        UserDefaults.standard.set(data, forKey: key)
        flatMapCache[key] = CachedMap(data: data, map: map)
    }

    func loadNestedJSONMap(forKey key: String) -> [String: [String: Int]] {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            nestedMapCache[key] = nil
            return [:]
        }
        if let cached = nestedMapCache[key], cached.data == data { return cached.map }
        guard let map = PersistedDecoding.decode([String: [String: Int]].self, from: data, key: key, keepingUnreadableIn: .standard) else {
            nestedMapCache[key] = nil
            return [:]
        }
        nestedMapCache[key] = CachedMap(data: data, map: map)
        return map
    }

    func saveNestedJSONMap(_ map: [String: [String: Int]], forKey key: String) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        UserDefaults.standard.set(data, forKey: key)
        nestedMapCache[key] = CachedMap(data: data, map: map)
    }
}
