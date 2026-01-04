// the entire code of the file with your changes goes here.
// Do not skip over anything.
import Foundation
import Combine

@MainActor
final class GameStats: ObservableObject {
    static let shared = GameStats()

    @Published private(set) var version: Int = 0

    private var observer: Any?

    enum GameID {
        case quiz
        case hangman
        case beatclock
        case versematch
        case bookorder
        case whoami
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
        migrateLegacyGameKeysIfNeeded()
        migrateQuizCombinedIfNeeded()
        migrateBookOrderCombinedIfNeeded()
        migrateHangmanCombinedIfNeeded() // NEW: backfill combined “_all” for Hangman
        migrateVerseMatchCombinedIfNeeded() // NEW: backfill combined “_all” for Verse Match
        migrateWhoAmICombinedIfNeeded() // NEW: backfill combined “_all” for Who am I?

        observer = NotificationCenter.default.addObserver(
            forName: .gameStatsExternallyUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Important: mutate the existing instance; do NOT touch GameStats.shared here.
            self?.version &+= 1
        }
    }

    private static let legacyWipeFlagKey = "didWipeLegacyUnsuffixedGameKeys_v1"
    private static let quizCombinedMigrationFlagKey = "didMigrateQuizCombinedAll_v1"
    private static let bookOrderCombinedMigrationFlagKey = "didMigrateBookOrderCombinedAll_v1"
    private static let hangmanCombinedMigrationFlagKey = "didMigrateHangmanCombinedAll_v1" // NEW
    private static let verseMatchCombinedMigrationFlagKey = "didMigrateVerseMatchCombinedAll_v1" // NEW
    private static let whoamiCombinedMigrationFlagKey = "didMigrateWhoAmICombinedAll_v1" // NEW

    private func migrateLegacyGameKeysIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.legacyWipeFlagKey) else { return }

        let legacyKeys: [String] = [
            "quizAllTimeCorrect",
            "quizAllTimeAnswered",
            "quizAllTimeBestStreak",
            "hangmanAllTimeCorrect",
            "hangmanAllTimeAnswered",
            "hangmanAllTimeBestStreak",
            "beatclockAllTimeCorrect",
            "beatclockAllTimeAnswered",
            "beatclockAllTimeBestStreak",
            "refmatchAllTimeCorrect",
            "refmatchAllTimeAnswered",
            "refmatchAllTimeBestStreak"
        ]

        for key in legacyKeys {
            defaults.removeObject(forKey: key)
        }

        defaults.set(true, forKey: Self.legacyWipeFlagKey)
        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

    // One-time migration: combine existing per-difficulty Quiz stats into combined "_all" keys.
    private func migrateQuizCombinedIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.quizCombinedMigrationFlagKey) else { return }

        // Sum across easy/normal/hard; also consider legacy unsuffixed as fallback
        func readInt(_ key: String) -> Int { max(0, defaults.integer(forKey: key)) }

        let cEasy = readInt("quizAllTimeCorrect_easy")
        let cNorm = readInt("quizAllTimeCorrect_normal")
        let cHard = readInt("quizAllTimeCorrect_hard")
        let aEasy = readInt("quizAllTimeAnswered_easy")
        let aNorm = readInt("quizAllTimeAnswered_normal")
        let aHard = readInt("quizAllTimeAnswered_hard")
        let bEasy = readInt("quizAllTimeBestStreak_easy")
        let bNorm = readInt("quizAllTimeBestStreak_normal")
        let bHard = readInt("quizAllTimeBestStreak_hard")

        let legacyC = readInt("quizAllTimeCorrect")
        let legacyA = readInt("quizAllTimeAnswered")
        let legacyB = readInt("quizAllTimeBestStreak")

        let sumCorrect = cEasy + cNorm + cHard + legacyC
        let sumAnswered = aEasy + aNorm + aHard + legacyA
        let bestStreak = max(bEasy, bNorm, bHard, legacyB)

        let existingAllC = readInt("quizAllTimeCorrect_all")
        let existingAllA = readInt("quizAllTimeAnswered_all")
        let existingAllB = readInt("quizAllTimeBestStreak_all")

        // Only write if the combined keys are currently zero to avoid clobbering user progress
        if existingAllC == 0 && sumCorrect > 0 {
            defaults.set(sumCorrect, forKey: "quizAllTimeCorrect_all")
            iCloudSyncCoordinator.shared.pushKey("quizAllTimeCorrect_all")
        }
        if existingAllA == 0 && sumAnswered > 0 {
            defaults.set(sumAnswered, forKey: "quizAllTimeAnswered_all")
            iCloudSyncCoordinator.shared.pushKey("quizAllTimeAnswered_all")
        }
        if existingAllB == 0 && bestStreak > 0 {
            defaults.set(bestStreak, forKey: "quizAllTimeBestStreak_all")
            iCloudSyncCoordinator.shared.pushKey("quizAllTimeBestStreak_all")
        }

        defaults.set(true, forKey: Self.quizCombinedMigrationFlagKey)
        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

    // One-time migration: combine existing per-difficulty Book Order stats into combined "_all" keys.
    private func migrateBookOrderCombinedIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.bookOrderCombinedMigrationFlagKey) else { return }

        func readInt(_ key: String) -> Int { max(0, defaults.integer(forKey: key)) }

        let cEasy = readInt("bookorderAllTimeCorrect_easy")
        let cNorm = readInt("bookorderAllTimeCorrect_normal")
        let cHard = readInt("bookorderAllTimeCorrect_hard")
        let aEasy = readInt("bookorderAllTimeAnswered_easy")
        let aNorm = readInt("bookorderAllTimeAnswered_normal")
        let aHard = readInt("bookorderAllTimeAnswered_hard")
        let bEasy = readInt("bookorderAllTimeBestStreak_easy")
        let bNorm = readInt("bookorderAllTimeBestStreak_normal")
        let bHard = readInt("bookorderAllTimeBestStreak_hard")

        // Legacy unsuffixed fallback
        let legacyC = readInt("bookorderAllTimeCorrect")
        let legacyA = readInt("bookorderAllTimeAnswered")
        let legacyB = readInt("bookorderAllTimeBestStreak")

        let sumCorrect = cEasy + cNorm + cHard + legacyC
        let sumAnswered = aEasy + aNorm + aHard + legacyA
        let bestStreak = max(bEasy, bNorm, bHard, legacyB)

        let existingAllC = readInt("bookorderAllTimeCorrect_all")
        let existingAllA = readInt("bookorderAllTimeAnswered_all")
        let existingAllB = readInt("bookorderAllTimeBestStreak_all")

        if existingAllC == 0 && sumCorrect > 0 {
            defaults.set(sumCorrect, forKey: "bookorderAllTimeCorrect_all")
            iCloudSyncCoordinator.shared.pushKey("bookorderAllTimeCorrect_all")
        }
        if existingAllA == 0 && sumAnswered > 0 {
            defaults.set(sumAnswered, forKey: "bookorderAllTimeAnswered_all")
            iCloudSyncCoordinator.shared.pushKey("bookorderAllTimeAnswered_all")
        }
        if existingAllB == 0 && bestStreak > 0 {
            defaults.set(bestStreak, forKey: "bookorderAllTimeBestStreak_all")
            iCloudSyncCoordinator.shared.pushKey("bookorderAllTimeBestStreak_all")
        }

        defaults.set(true, forKey: Self.bookOrderCombinedMigrationFlagKey)
        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

    // NEW: One-time migration: combine existing per-difficulty Hangman stats into combined "_all" keys.
    private func migrateHangmanCombinedIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.hangmanCombinedMigrationFlagKey) else { return }

        func readInt(_ key: String) -> Int { max(0, defaults.integer(forKey: key)) }

        // Include legacy “medium” mapped to “normal” era; sum all that exist.
        let cEasy = readInt("hangmanAllTimeCorrect_easy")
        let cNorm = readInt("hangmanAllTimeCorrect_normal")
        let cMed  = readInt("hangmanAllTimeCorrect_medium")
        let cHard = readInt("hangmanAllTimeCorrect_hard")

        let aEasy = readInt("hangmanAllTimeAnswered_easy")
        let aNorm = readInt("hangmanAllTimeAnswered_normal")
        let aMed  = readInt("hangmanAllTimeAnswered_medium")
        let aHard = readInt("hangmanAllTimeAnswered_hard")

        let bEasy = readInt("hangmanAllTimeBestStreak_easy")
        let bNorm = readInt("hangmanAllTimeBestStreak_normal")
        let bMed  = readInt("hangmanAllTimeBestStreak_medium")
        let bHard = readInt("hangmanAllTimeBestStreak_hard")

        // Legacy unsuffixed fallback
        let legacyC = readInt("hangmanAllTimeCorrect")
        let legacyA = readInt("hangmanAllTimeAnswered")
        let legacyB = readInt("hangmanAllTimeBestStreak")

        let sumCorrect = cEasy + cNorm + cMed + cHard + legacyC
        let sumAnswered = aEasy + aNorm + aMed + aHard + legacyA
        let bestStreak = max(bEasy, bNorm, bMed, bHard, legacyB)

        let existingAllC = readInt("hangmanAllTimeCorrect_all")
        let existingAllA = readInt("hangmanAllTimeAnswered_all")
        let existingAllB = readInt("hangmanAllTimeBestStreak_all")

        if existingAllC == 0 && sumCorrect > 0 {
            defaults.set(sumCorrect, forKey: "hangmanAllTimeCorrect_all")
            iCloudSyncCoordinator.shared.pushKey("hangmanAllTimeCorrect_all")
        }
        if existingAllA == 0 && sumAnswered > 0 {
            defaults.set(sumAnswered, forKey: "hangmanAllTimeAnswered_all")
            iCloudSyncCoordinator.shared.pushKey("hangmanAllTimeAnswered_all")
        }
        if existingAllB == 0 && bestStreak > 0 {
            defaults.set(bestStreak, forKey: "hangmanAllTimeBestStreak_all")
            iCloudSyncCoordinator.shared.pushKey("hangmanAllTimeBestStreak_all")
        }

        defaults.set(true, forKey: Self.hangmanCombinedMigrationFlagKey)
        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

    // NEW: One-time migration: combine existing per-difficulty Verse Match stats into combined "_all" keys.
    private func migrateVerseMatchCombinedIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.verseMatchCombinedMigrationFlagKey) else { return }

        func readInt(_ key: String) -> Int { max(0, defaults.integer(forKey: key)) }

        // New Verse Match keys
        let cEasy = readInt("versematchAllTimeCorrect_easy")
        let cNorm = readInt("versematchAllTimeCorrect_normal")
        let cMed  = readInt("versematchAllTimeCorrect_medium")
        let cHard = readInt("versematchAllTimeCorrect_hard")

        let aEasy = readInt("versematchAllTimeAnswered_easy")
        let aNorm = readInt("versematchAllTimeAnswered_normal")
        let aMed  = readInt("versematchAllTimeAnswered_medium")
        let aHard = readInt("versematchAllTimeAnswered_hard")

        let bEasy = readInt("versematchAllTimeBestStreak_easy")
        let bNorm = readInt("versematchAllTimeBestStreak_normal")
        let bMed  = readInt("versematchAllTimeBestStreak_medium")
        let bHard = readInt("versematchAllTimeBestStreak_hard")

        // Legacy Reference Match fallback
        let legacyC = readInt("refmatchAllTimeCorrect")
        let legacyA = readInt("refmatchAllTimeAnswered")
        let legacyB = readInt("refmatchAllTimeBestStreak")

        let sumCorrect = cEasy + cNorm + cMed + cHard + legacyC
        let sumAnswered = aEasy + aNorm + aMed + aHard + legacyA
        let bestStreak = max(bEasy, bNorm, bMed, bHard, legacyB)

        let existingAllC = readInt("versematchAllTimeCorrect_all")
        let existingAllA = readInt("versematchAllTimeAnswered_all")
        let existingAllB = readInt("versematchAllTimeBestStreak_all")

        if existingAllC == 0 && sumCorrect > 0 {
            defaults.set(sumCorrect, forKey: "versematchAllTimeCorrect_all")
            iCloudSyncCoordinator.shared.pushKey("versematchAllTimeCorrect_all")
        }
        if existingAllA == 0 && sumAnswered > 0 {
            defaults.set(sumAnswered, forKey: "versematchAllTimeAnswered_all")
            iCloudSyncCoordinator.shared.pushKey("versematchAllTimeAnswered_all")
        }
        if existingAllB == 0 && bestStreak > 0 {
            defaults.set(bestStreak, forKey: "versematchAllTimeBestStreak_all")
            iCloudSyncCoordinator.shared.pushKey("versematchAllTimeBestStreak_all")
        }

        defaults.set(true, forKey: Self.verseMatchCombinedMigrationFlagKey)
        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

    // NEW: One-time migration: combine existing per-difficulty Who am I? stats into combined "_all" keys.
    private func migrateWhoAmICombinedIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.whoamiCombinedMigrationFlagKey) else { return }

        func readInt(_ key: String) -> Int { max(0, defaults.integer(forKey: key)) }

        let cEasy = readInt("whoamiAllTimeCorrect_easy")
        let cNorm = readInt("whoamiAllTimeCorrect_normal")
        let cHard = readInt("whoamiAllTimeCorrect_hard")

        let aEasy = readInt("whoamiAllTimeAnswered_easy")
        let aNorm = readInt("whoamiAllTimeAnswered_normal")
        let aHard = readInt("whoamiAllTimeAnswered_hard")

        let bEasy = readInt("whoamiAllTimeBestStreak_easy")
        let bNorm = readInt("whoamiAllTimeBestStreak_normal")
        let bHard = readInt("whoamiAllTimeBestStreak_hard")

        let sumCorrect = cEasy + cNorm + cHard
        let sumAnswered = aEasy + aNorm + aHard
        let bestStreak = max(bEasy, bNorm, bHard)

        let existingAllC = readInt("whoamiAllTimeCorrect_all")
        let existingAllA = readInt("whoamiAllTimeAnswered_all")
        let existingAllB = readInt("whoamiAllTimeBestStreak_all")

        if existingAllC == 0 && sumCorrect > 0 {
            defaults.set(sumCorrect, forKey: "whoamiAllTimeCorrect_all")
            iCloudSyncCoordinator.shared.pushKey("whoamiAllTimeCorrect_all")
        }
        if existingAllA == 0 && sumAnswered > 0 {
            defaults.set(sumAnswered, forKey: "whoamiAllTimeAnswered_all")
            iCloudSyncCoordinator.shared.pushKey("whoamiAllTimeAnswered_all")
        }
        if existingAllB == 0 && bestStreak > 0 {
            defaults.set(bestStreak, forKey: "whoamiAllTimeBestStreak_all")
            iCloudSyncCoordinator.shared.pushKey("whoamiAllTimeBestStreak_all")
        }

        defaults.set(true, forKey: Self.whoamiCombinedMigrationFlagKey)
        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

    struct Snapshot {
        let totalCorrect: Int
        let totalAnswered: Int
        let percentage: Double
    }

    func snapshot() -> Snapshot {
        let totals = aggregateAll()
        let pct = percentage(correct: totals.correct, answered: totals.answered)
        return Snapshot(totalCorrect: totals.correct, totalAnswered: totals.answered, percentage: pct)
    }

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
        let r = versematch
        let b = beatclock
        let o = bookorder
        let w = whoami

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
            .init(name: "WORD", correct: wdCombined.correct, answered: wdCombined.answered, bestStreak: wdCombined.bestStreak)
        ]
        return GameBreakdown(entries: entries)
    }

    private static func storageKey(for game: GameID) -> String {
        switch game {
        case .quiz: return "quiz"
        case .hangman: return "hangman"
        case .beatclock: return "beatclock"
        case .versematch: return "versematch"
        case .bookorder: return "bookorder"
        case .whoami: return "whoami"
        case .wordle: return "word"
        }
    }

    private static func storageKey(forDisplayName name: String) -> String? {
        switch name {
        case "Bible Quiz": return "quiz"
        case "Hangman": return "hangman"
        case "Verse Match": return "versematch"
        case "Beat the Clock": return "beatclock"
        case "Book Order": return "bookorder"
        case "Who am I?": return "whoami"
        case "WORD": return "word"
        default: return nil
        }
    }

    private static func storageKeyForWord(mode: WordMode) -> String {
        switch mode {
        case .normal: return "word_normal"
        case .hard:   return "word_hard"
        }
    }

    private func updateDailyMaps(addAnswered: Int, addCorrect: Int, forGameKey key: String) {
        let dayKey = Self.localDayKey(for: Date())

        var dailyAnswered: [String: Int] = loadJSONMap(forKey: "gamesDailyAnswered")
        dailyAnswered[dayKey, default: 0] = max(0, (dailyAnswered[dayKey] ?? 0) + max(0, addAnswered))
        saveJSONMap(dailyAnswered, forKey: "gamesDailyAnswered")

        var dailyCorrect: [String: Int] = loadJSONMap(forKey: "gamesDailyCorrect")
        dailyCorrect[dayKey, default: 0] = max(0, (dailyCorrect[dayKey] ?? 0) + max(0, addCorrect))
        saveJSONMap(dailyCorrect, forKey: "gamesDailyCorrect")

        var perAnswered: [String: Int] = loadJSONMap(forKey: "gamesDailyAnswered_\(key)")
        perAnswered[dayKey, default: 0] = max(0, (perAnswered[dayKey] ?? 0) + max(0, addAnswered))
        saveJSONMap(perAnswered, forKey: "gamesDailyAnswered_\(key)")

        var perCorrect: [String: Int] = loadJSONMap(forKey: "gamesDailyCorrect_\(key)")
        perCorrect[dayKey, default: 0] = max(0, (perCorrect[dayKey] ?? 0) + max(0, addCorrect))
        saveJSONMap(perCorrect, forKey: "gamesDailyCorrect_\(key)")
    }

    func recordQuizPerBook(bookName: String, answered addAnswered: Int, correct addCorrect: Int) {
        guard !bookName.isEmpty, (addAnswered != 0 || addCorrect != 0) else { return }
        let _ = UserDefaults.standard

        var answeredMap: [String: Int] = loadJSONMap(forKey: "quizPerBookAnsweredMap")
        if addAnswered != 0 {
            answeredMap[bookName, default: 0] = max(0, (answeredMap[bookName] ?? 0) + max(0, addAnswered))
            saveJSONMap(answeredMap, forKey: "quizPerBookAnsweredMap")
            iCloudSyncCoordinator.shared.pushKey("quizPerBookAnsweredMap")
        }

        var correctMap: [String: Int] = loadJSONMap(forKey: "quizPerBookCorrectMap")
        if addCorrect != 0 {
            correctMap[bookName, default: 0] = max(0, (correctMap[bookName] ?? 0) + max(0, addCorrect))
            saveJSONMap(correctMap, forKey: "quizPerBookCorrectMap")
            iCloudSyncCoordinator.shared.pushKey("quizPerBookCorrectMap")
        }

        let dayKey = Self.localDayKey(for: Date())

        var dailyAnsweredNested: [String: [String: Int]] = loadNestedJSONMap(forKey: "quizPerBookDailyAnswered")
        var dayAnswered = dailyAnsweredNested[dayKey] ?? [:]
        if addAnswered != 0 {
            dayAnswered[bookName, default: 0] = max(0, (dayAnswered[bookName] ?? 0) + max(0, addAnswered))
            dailyAnsweredNested[dayKey] = dayAnswered
            saveNestedJSONMap(dailyAnsweredNested, forKey: "quizPerBookDailyAnswered")
            iCloudSyncCoordinator.shared.pushKey("quizPerBookDailyAnswered")
        }

        var dailyCorrectNested: [String: [String: Int]] = loadNestedJSONMap(forKey: "quizPerBookDailyCorrect")
        var dayCorrect = dailyCorrectNested[dayKey] ?? [:]
        if addCorrect != 0 {
            dayCorrect[bookName, default: 0] = max(0, (dayCorrect[bookName] ?? 0) + max(0, addCorrect))
            dailyCorrectNested[dayKey] = dayCorrect
            saveNestedJSONMap(dailyCorrectNested, forKey: "quizPerBookDailyCorrect")
            iCloudSyncCoordinator.shared.pushKey("quizPerBookDailyCorrect")
        }

        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

    // UPDATED: Verse Match per-book maps writer — now writes all-time + daily nested maps
    func recordVerseMatchPerBook(bookName: String, answered addAnswered: Int, correct addCorrect: Int) {
        let trimmed = bookName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, (addAnswered != 0 || addCorrect != 0) else { return }

        var answeredMap: [String: Int] = loadJSONMap(forKey: "versematchPerBookAnsweredMap")
        if addAnswered != 0 {
            answeredMap[trimmed, default: 0] = max(0, (answeredMap[trimmed] ?? 0) + max(0, addAnswered))
            saveJSONMap(answeredMap, forKey: "versematchPerBookAnsweredMap")
            iCloudSyncCoordinator.shared.pushKey("versematchPerBookAnsweredMap")
        }

        var correctMap: [String: Int] = loadJSONMap(forKey: "versematchPerBookCorrectMap")
        if addCorrect != 0 {
            correctMap[trimmed, default: 0] = max(0, (correctMap[trimmed] ?? 0) + max(0, addCorrect))
            saveJSONMap(correctMap, forKey: "versematchPerBookCorrectMap")
            iCloudSyncCoordinator.shared.pushKey("versematchPerBookCorrectMap")
        }

        // NEW: Daily nested maps (local-only; not mirrored to KVS, same as Quiz)
        let dayKey = Self.localDayKey(for: Date())

        var vmDailyA: [String: [String: Int]] = loadNestedJSONMap(forKey: "versematchPerBookDailyAnswered")
        var vmDayA = vmDailyA[dayKey] ?? [:]
        if addAnswered != 0 {
            vmDayA[trimmed, default: 0] = max(0, (vmDayA[trimmed] ?? 0) + max(0, addAnswered))
            vmDailyA[dayKey] = vmDayA
            saveNestedJSONMap(vmDailyA, forKey: "versematchPerBookDailyAnswered")
        }

        var vmDailyC: [String: [String: Int]] = loadNestedJSONMap(forKey: "versematchPerBookDailyCorrect")
        var vmDayC = vmDailyC[dayKey] ?? [:]
        if addCorrect != 0 {
            vmDayC[trimmed, default: 0] = max(0, (vmDayC[trimmed] ?? 0) + max(0, addCorrect))
            vmDailyC[dayKey] = vmDayC
            saveNestedJSONMap(vmDailyC, forKey: "versematchPerBookDailyCorrect")
        }

        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

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

        func suffix(for game: GameID, difficulty: Difficulty) -> String? {
            switch game {
            case .quiz:
                switch difficulty {
                case .easy: return "easy"
                case .normal: return "normal"
                case .hard: return "hard"
                case .medium, .none: return nil
                }
            case .hangman, .beatclock, .versematch:
                switch difficulty {
                case .easy: return "easy"
                case .normal: return "normal"
                case .medium: return "normal"
                case .hard: return "hard"
                case .none: return nil
                }
            case .bookorder:
                switch difficulty {
                case .easy: return "easy"
                case .normal: return "normal"
                case .hard: return "hard"
                case .medium: return "normal" // FIX: treat “medium” as “normal” for Book Order
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
                switch difficulty {
                case .none: return "all"
                default: return "all"
                }
            }
        }

        let suf = suffix(for: game, difficulty: difficulty)

        switch game {
        case .quiz:
            guard let s = suf else { return }
            // Keep per-difficulty keys for back-compat/analytics
            incInt("quizAllTimeCorrect_\(s)", by: addCorrect)
            incInt("quizAllTimeAnswered_\(s)", by: addAnswered)
            maxInt("quizAllTimeBestStreak_\(s)", candidate: currentBestStreak)
            // NEW: Mirror to combined keys so all difficulties share the same all-time stats
            incInt("quizAllTimeCorrect_all", by: addCorrect)
            incInt("quizAllTimeAnswered_all", by: addAnswered)
            maxInt("quizAllTimeBestStreak_all", candidate: currentBestStreak)

        case .hangman:
            guard let s = suf else { return }
            incInt("hangmanAllTimeCorrect_\(s)", by: addCorrect)
            incInt("hangmanAllTimeAnswered_\(s)", by: addAnswered)
            maxInt("hangmanAllTimeBestStreak_\(s)", candidate: currentBestStreak)
            // NEW: Mirror to combined keys so all difficulties share the same all-time stats
            incInt("hangmanAllTimeCorrect_all", by: addCorrect)
            incInt("hangmanAllTimeAnswered_all", by: addAnswered)
            maxInt("hangmanAllTimeBestStreak_all", candidate: currentBestStreak)

        case .beatclock:
            guard let s = suf else { return }
            // Keep per-difficulty keys for back-compat/analytics
            incInt("beatclockAllTimeCorrect_\(s)", by: addCorrect)
            incInt("beatclockAllTimeAnswered_\(s)", by: addAnswered)
            maxInt("beatclockAllTimeBestStreak_\(s)", candidate: currentBestStreak)
            // NEW: Always mirror to combined keys so all difficulties share the same all-time stats
            incInt("beatclockAllTimeCorrect_all", by: addCorrect)
            incInt("beatclockAllTimeAnswered_all", by: addAnswered)
            maxInt("beatclockAllTimeBestStreak_all", candidate: currentBestStreak)

        case .versematch:
            guard let s = suf else { return }
            // Keep per-difficulty keys for back-compat/analytics
            incInt("versematchAllTimeCorrect_\(s)", by: addCorrect)
            incInt("versematchAllTimeAnswered_\(s)", by: addAnswered)
            maxInt("versematchAllTimeBestStreak_\(s)", candidate: currentBestStreak)
            // NEW: Mirror to combined keys so all difficulties share the same all-time stats
            incInt("versematchAllTimeCorrect_all", by: addCorrect)
            incInt("versematchAllTimeAnswered_all", by: addAnswered)
            maxInt("versematchAllTimeBestStreak_all", candidate: currentBestStreak)

        case .bookorder:
            guard let s = suf else { return }
            // Write per-difficulty (or "all" if difficulty == .none)
            incInt("bookorderAllTimeCorrect_\(s)", by: addCorrect)
            incInt("bookorderAllTimeAnswered_\(s)", by: addAnswered)
            maxInt("bookorderAllTimeBestStreak_\(s)", candidate: currentBestStreak)
            // NEW: Mirror to combined keys when not already writing to "_all"
            if s != "all" {
                incInt("bookorderAllTimeCorrect_all", by: addCorrect)
                incInt("bookorderAllTimeAnswered_all", by: addAnswered)
                maxInt("bookorderAllTimeBestStreak_all", candidate: currentBestStreak)
            }

        case .whoami:
            guard let s = suf else { return }
            // Keep per-difficulty keys for back-compat/analytics
            incInt("whoamiAllTimeCorrect_\(s)", by: addCorrect)
            incInt("whoamiAllTimeAnswered_\(s)", by: addAnswered)
            maxInt("whoamiAllTimeBestStreak_\(s)", candidate: currentBestStreak)
            // NEW: Mirror to combined keys so all difficulties share the same all-time stats
            incInt("whoamiAllTimeCorrect_all", by: addCorrect)
            incInt("whoamiAllTimeAnswered_all", by: addAnswered)
            maxInt("whoamiAllTimeBestStreak_all", candidate: currentBestStreak)

        case .wordle:
            guard let s = suf else { return }
            incInt("wordleAllTimeCorrect_\(s)", by: addCorrect)
            incInt("wordleAllTimeAnswered_\(s)", by: addAnswered)
            maxInt("wordleAllTimeBestStreak_\(s)", candidate: currentBestStreak)
        }

        do {
            let key = Self.storageKey(for: game)
            updateDailyMaps(addAnswered: addAnswered, addCorrect: addCorrect, forGameKey: key)

            let nowTS = Date().timeIntervalSince1970
            let defaults = UserDefaults.standard
            defaults.set(nowTS, forKey: "gamesLastPlayedAt")
            defaults.set(Self.gameDisplayName(for: game), forKey: "gamesLastPlayedGameName")
        }

        let kvs = iCloudSyncCoordinator.shared
        for key in changedKeys {
            kvs.pushKey(key)
        }

        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

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

        do {
            updateDailyMaps(addAnswered: addAnswered, addCorrect: addCorrect, forGameKey: "word")

            let nowTS = Date().timeIntervalSince1970
            let defaults = UserDefaults.standard
            defaults.set(nowTS, forKey: "gamesLastPlayedAt")
            defaults.set(Self.gameDisplayName(for: .wordle), forKey: "gamesLastPlayedGameName")
        }

        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

    func recordWordleResult(type: WordleType, mode: WordMode, won: Bool, guesses: Int, currentBestStreak: Int) {
        recordWordleRound(
            type: type,
            correct: won ? 1 : 0,
            answered: 1,
            currentBestStreak: currentBestStreak
        )

        let perModeKey = Self.storageKeyForWord(mode: mode)
        updateDailyMaps(addAnswered: 1, addCorrect: won ? 1 : 0, forGameKey: perModeKey)

        let defaults = UserDefaults.standard
        let typeSuf = (type == .daily) ? "daily" : "free"
        let modeSuf = (mode == .normal) ? "normal" : "hard"
        let clamped = max(1, min(6, guesses))

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

        incInt("wordleAllTimeCorrect_\(modeSuf)", by: won ? 1 : 0)
        incInt("wordleAllTimeAnswered_\(modeSuf)", by: 1)
        maxInt("wordleAllTimeBestStreak_\(modeSuf)", candidate: currentBestStreak)

        if won {
            incInt("wordleWinsGuessSum_\(typeSuf)", by: clamped)
            incInt("wordleWinsOnGuess\(clamped)_\(typeSuf)", by: 1)
            incInt("wordleWinsGuessSum_\(modeSuf)", by: clamped)
            incInt("wordleWinsOnGuess\(clamped)_\(modeSuf)", by: 1)
        }

        if type == .daily && won {
            let dayKey = Self.localDayKey(for: Date())
            var solved: [String: Int] = loadJSONMap(forKey: "wordleDailySolvedDays")
            if solved[dayKey] != 1 {
                solved[dayKey] = 1
                saveJSONMap(solved, forKey: "wordleDailySolvedDays")
                iCloudSyncCoordinator.shared.pushKey("wordleDailySolvedDays")
            }
        }

        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

    func recordWordleResult(type: WordleType, won: Bool, guesses: Int, currentBestStreak: Int) {
        recordWordleResult(type: type, mode: .normal, won: won, guesses: guesses, currentBestStreak: currentBestStreak)
    }

    func recordWordleTime(type: WordleType, mode: WordMode, won: Bool, elapsedSeconds: Int) {
        let defaults = UserDefaults.standard
        let typeSuf = (type == .daily) ? "daily" : "free"
        let modeSuf = (mode == .normal) ? "normal" : "hard"

        func setInt(_ key: String, _ value: Int) {
            defaults.set(max(0, value), forKey: key)
            iCloudSyncCoordinator.shared.pushKey(key)
        }
        func incInt(_ key: String, by delta: Int) {
            let old = defaults.integer(forKey: key)
            setInt(key, old + max(0, delta))
        }

        incInt("wordleTimeTotal_seconds_\(typeSuf)", by: elapsedSeconds)
        if won {
            incInt("wordleTimeWins_seconds_\(typeSuf)", by: elapsedSeconds)
        } else {
            incInt("wordleTimeLosses_seconds_\(typeSuf)", by: elapsedSeconds)
        }

        incInt("wordleTimeTotal_seconds_\(modeSuf)", by: elapsedSeconds)
        if won {
            incInt("wordleTimeWins_seconds_\(modeSuf)", by: elapsedSeconds)
        } else {
            incInt("wordleTimeLosses_seconds_\(modeSuf)", by: elapsedSeconds)
        }

        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

    func recordWordleTime(type: WordleType, won: Bool, elapsedSeconds: Int) {
        recordWordleTime(type: type, mode: .normal, won: won, elapsedSeconds: elapsedSeconds)
    }

    private func readInt(_ key: String) -> Int {
        UserDefaults.standard.integer(forKey: key)
    }

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

    private var quiz: GameStat {
        // Prefer combined keys if present; otherwise fall back to summing per-difficulty/legacy
        let combinedC = max(0, readInt("quizAllTimeCorrect_all"))
        let combinedA = max(0, readInt("quizAllTimeAnswered_all"))
        let combinedB = max(0, readInt("quizAllTimeBestStreak_all"))
        if (combinedC + combinedA + combinedB) > 0 {
            return GameStat(correct: combinedC, answered: combinedA, bestStreak: combinedB == 0 ? nil : combinedB)
        }

        let c = sumAcross(prefix: "quizAllTimeCorrect", parts: ["_easy","_normal","_hard"], legacyKey: "quizAllTimeCorrect")
        let a = sumAcross(prefix: "quizAllTimeAnswered", parts: ["_easy","_normal","_hard"], legacyKey: "quizAllTimeAnswered")
        let best = maxAcross(prefix: "quizAllTimeBestStreak", parts: ["_easy","_normal","_hard"], legacyKey: "quizAllTimeBestStreak")
        return GameStat(correct: c, answered: a, bestStreak: best == 0 ? nil : best)
    }

    private var hangman: GameStat {
        // NEW: Prefer combined keys if present; otherwise fall back to summing per-difficulty/legacy
        let combinedC = max(0, readInt("hangmanAllTimeCorrect_all"))
        let combinedA = max(0, readInt("hangmanAllTimeAnswered_all"))
        let combinedB = max(0, readInt("hangmanAllTimeBestStreak_all"))
        if (combinedC + combinedA + combinedB) > 0 {
            return GameStat(correct: combinedC, answered: combinedA, bestStreak: combinedB == 0 ? nil : combinedB)
        }

        let c = sumAcross(prefix: "hangmanAllTimeCorrect", parts: ["_easy","_normal","_hard","_medium"], legacyKey: "hangmanAllTimeCorrect")
        let a = sumAcross(prefix: "hangmanAllTimeAnswered", parts: ["_easy","_normal","_hard","_medium"], legacyKey: "hangmanAllTimeAnswered")
        let best = maxAcross(prefix: "hangmanAllTimeBestStreak", parts: ["_easy","_normal","_hard","_medium"], legacyKey: "hangmanAllTimeBestStreak")
        return GameStat(correct: c, answered: a, bestStreak: best == 0 ? nil : best)
    }

    private var versematch: GameStat {
        // NEW: Prefer combined keys if present; otherwise fall back to new per-difficulty or legacy refmatch
        let combinedC = max(0, readInt("versematchAllTimeCorrect_all"))
        let combinedA = max(0, readInt("versematchAllTimeAnswered_all"))
        let combinedB = max(0, readInt("versematchAllTimeBestStreak_all"))
        if (combinedC + combinedA + combinedB) > 0 {
            return GameStat(correct: combinedC, answered: combinedA, bestStreak: combinedB == 0 ? nil : combinedB)
        }

        let cNew = sumAcross(prefix: "versematchAllTimeCorrect", parts: ["_easy","_normal","_hard","_medium"], legacyKey: nil)
        let aNew = sumAcross(prefix: "versematchAllTimeAnswered", parts: ["_easy","_normal","_hard","_medium"], legacyKey: nil)
        let bestNew = maxAcross(prefix: "versematchAllTimeBestStreak", parts: ["_easy","_normal","_hard","_medium"], legacyKey: nil)

        let hasNew = (cNew + aNew + (bestNew)) > 0
        if hasNew {
            return GameStat(correct: cNew, answered: aNew, bestStreak: bestNew == 0 ? nil : bestNew)
        } else {
            let cLegacy = sumAcross(prefix: "refmatchAllTimeCorrect", parts: ["_easy","_normal","_hard","_medium"], legacyKey: "refmatchAllTimeCorrect")
            let aLegacy = sumAcross(prefix: "refmatchAllTimeAnswered", parts: ["_easy","_normal","_hard","_medium"], legacyKey: "refmatchAllTimeAnswered")
            let bestLegacy = maxAcross(prefix: "refmatchAllTimeBestStreak", parts: ["_easy","_normal","_hard","_medium"], legacyKey: "refmatchAllTimeBestStreak")
            return GameStat(correct: cLegacy, answered: aLegacy, bestStreak: bestLegacy == 0 ? nil : bestLegacy)
        }
    }

    private var beatclock: GameStat {
        let c = sumAcross(prefix: "beatclockAllTimeCorrect", parts: ["_easy","_normal","_hard","_medium"], legacyKey: "beatclockAllTimeCorrect")
        let a = sumAcross(prefix: "beatclockAllTimeAnswered", parts: ["_easy","_normal","_hard","_medium"], legacyKey: "beatclockAllTimeAnswered")
        let best = maxAcross(prefix: "beatclockAllTimeBestStreak", parts: ["_easy","_normal","_hard","_medium"], legacyKey: "beatclockAllTimeBestStreak")
        return GameStat(correct: c, answered: a, bestStreak: best == 0 ? nil : best)
    }

    private var bookorder: GameStat {
        // Prefer combined keys if present; otherwise fall back to summing per-difficulty/legacy
        let combinedC = max(0, readInt("bookorderAllTimeCorrect_all"))
        let combinedA = max(0, readInt("bookorderAllTimeAnswered_all"))
        let combinedB = max(0, readInt("bookorderAllTimeBestStreak_all"))
        if (combinedC + combinedA + combinedB) > 0 {
            return GameStat(correct: combinedC, answered: combinedA, bestStreak: combinedB == 0 ? nil : combinedB)
        }

        let c = sumAcross(prefix: "bookorderAllTimeCorrect", parts: ["_easy","_normal","_hard"], legacyKey: "bookorderAllTimeCorrect")
        let a = sumAcross(prefix: "bookorderAllTimeAnswered", parts: ["_easy","_normal","_hard"], legacyKey: "bookorderAllTimeAnswered")
        let best = maxAcross(prefix: "bookorderAllTimeBestStreak", parts: ["_easy","_normal","_hard"], legacyKey: "bookorderAllTimeBestStreak")
        return GameStat(correct: c, answered: a, bestStreak: best == 0 ? nil : best)
    }

    private var whoami: GameStat {
        // NEW: Prefer combined keys if present; otherwise fall back to summing per-difficulty
        let combinedC = max(0, readInt("whoamiAllTimeCorrect_all"))
        let combinedA = max(0, readInt("whoamiAllTimeAnswered_all"))
        let combinedB = max(0, readInt("whoamiAllTimeBestStreak_all"))
        if (combinedC + combinedA + combinedB) > 0 {
            return GameStat(correct: combinedC, answered: combinedA, bestStreak: combinedB == 0 ? nil : combinedB)
        }

        let c = sumAcross(prefix: "whoamiAllTimeCorrect", parts: ["_easy","_normal","_hard"], legacyKey: "whoamiAllTimeCorrect")
        let a = sumAcross(prefix: "whoamiAllTimeAnswered", parts: ["_easy","_normal","_hard"], legacyKey: "whoamiAllTimeAnswered")
        let best = maxAcross(prefix: "whoamiAllTimeBestStreak", parts: ["_easy","_normal","_hard"], legacyKey: "whoamiAllTimeBestStreak")
        return GameStat(correct: c, answered: a, bestStreak: best == 0 ? nil : best)
    }

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

    func wordleWinGuessStats(type: WordleType) -> (averageGuessesOnWins: Double, winsByGuess: [Int]) {
        let suf = (type == .daily) ? "daily" : "free"
        let totalWins = max(0, readInt("wordleAllTimeCorrect_\(suf)"))
        let sumGuesses = max(0, readInt("wordleWinsGuessSum_\(suf)"))
        let dist = (1...6).map { idx in max(0, readInt("wordleWinsOnGuess\(idx)_\(suf)")) }
        let avg: Double = totalWins > 0 ? Double(sumGuesses) / Double(totalWins) : 0
        return (avg, dist)
    }

    func wordleWinGuessStatsCombined() -> (averageGuessesOnWins: Double, winsByGuess: [Int]) {
        let (_, distDaily) = wordleWinGuessStats(type: .daily)
        let (_, distFree) = wordleWinGuessStats(type: .free)

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

    func wordleWinGuessStats(mode: WordMode) -> (averageGuessesOnWins: Double, winsByGuess: [Int]) {
        let suf = (mode == .normal) ? "normal" : "hard"
        let totalWins = max(0, readInt("wordleAllTimeCorrect_\(suf)"))
        let sumGuesses = max(0, readInt("wordleWinsGuessSum_\(suf)"))
        let dist = (1...6).map { idx in max(0, readInt("wordleWinsOnGuess\(idx)_\(suf)")) }
        let avg: Double = totalWins > 0 ? Double(sumGuesses) / Double(totalWins) : 0
        return (avg, dist)
    }

    func wordleWinGuessStatsModesCombined() -> (averageGuessesOnWins: Double, winsByGuess: [Int]) {
        let (avgN, distN) = wordleWinGuessStats(mode: .normal)
        let (avgH, distH) = wordleWinGuessStats(mode: .hard)

        let winsN = max(0, readInt("wordleAllTimeCorrect_normal"))
        let winsH = max(0, readInt("wordleAllTimeCorrect_hard"))
        let sumN = max(0, readInt("wordleWinsGuessSum_normal"))
        let sumH = max(0, readInt("wordleWinsGuessSum_hard"))
        let totalWins = winsN + winsH
        let totalSum = sumN + sumH
        let avg = totalWins > 0 ? Double(totalSum) / Double(totalWins) : max(avgN, avgH)

        let dist = zip(distN, distH).map(+)
        return (avg, dist)
    }

    func wordleTimeStats(type: WordleType) -> (total: Int, wins: Int, losses: Int) {
        let suf = (type == .daily) ? "daily" : "free"
        let total = max(0, readInt("wordleTimeTotal_seconds_\(suf)"))
        let wins = max(0, readInt("wordleTimeWins_seconds_\(suf)"))
        let losses = max(0, readInt("wordleTimeLosses_seconds_\(suf)"))
        return (total, wins, losses)
    }

    func wordleTimeStatsCombined() -> (total: Int, wins: Int, losses: Int) {
        let d = wordleTimeStats(type: .daily)
        let f = wordleTimeStats(type: .free)
        return (d.total + f.total, d.wins + f.wins, d.losses + f.losses)
    }

    func wordleTimeStats(mode: WordMode) -> (total: Int, wins: Int, losses: Int) {
        let suf = (mode == .normal) ? "normal" : "hard"
        let total = max(0, readInt("wordleTimeTotal_seconds_\(suf)"))
        let wins = max(0, readInt("wordleTimeWins_seconds_\(suf)"))
        let losses = max(0, readInt("wordleTimeLosses_seconds_\(suf)"))
        return (total, wins, losses)
    }

    func wordleTimeStatsModesCombined() -> (total: Int, wins: Int, losses: Int) {
        let n = wordleTimeStats(mode: .normal)
        let h = wordleTimeStats(mode: .hard)
        return (n.total + h.total, n.wins + h.wins, n.losses + h.losses)
    }

    func wordleCounts(mode: WordMode) -> (answered: Int, wins: Int) {
        let suf = (mode == .normal) ? "normal" : "hard"
        let wins = max(0, readInt("wordleAllTimeCorrect_\(suf)"))
        let answered = max(0, readInt("wordleAllTimeAnswered_\(suf)"))
        return (answered, wins)
    }

    private func aggregateAll() -> (correct: Int, answered: Int) {
        let stats = [quiz, hangman, versematch, beatclock, bookorder, whoami]
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

    private func loadNestedJSONMap(forKey key: String) -> [String: [String: Int]] {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: key),
              let map = try? JSONDecoder().decode([String: [String: Int]].self, from: data) else {
            return [:]
        }
        return map
    }

    private func saveNestedJSONMap(_ map: [String: [String: Int]], forKey key: String) {
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
        case .versematch: return "Verse Match"
        case .bookorder: return "Book Order"
        case .whoami: return "Who am I?"
        case .wordle: return "WORD"
        }
    }

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
        if let raw = UserDefaults.standard.string(forKey: "gamesLastPlayedGameName") {
            if raw == "Wordle (Bible)" { return "WORD" }
            return raw
        }
               return nil
    }

    func dailySeriesLast(days: Int, now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> [(date: Date, answered: Int, correct: Int)] {
        var cal = calendar
        cal.timeZone = .autoupdatingCurrent
        let startOfToday = cal.startOfDay(for: now)

        let answeredMap: [String: Int] = loadJSONMap(forKey: "gamesDailyAnswered")
        let correctMap: [String: Int] = loadJSONMap(forKey: "gamesDailyCorrect")

        var series: [(Date, Int, Int)] = []
        for i in stride(from: days - 1, through: 0, by: -1) {
            if let d = cal.date(byAdding: .day, value: -i, to: startOfToday) {
                let key = Self.localDayKey(for: d, calendar: cal)
                let a = max(0, answeredMap[key] ?? 0)
                let c = max(0, correctMap[key] ?? 0)
                series.append((d, a, c))
            }
        }
        return series
    }

    func dailySeriesLast(days: Int, forDisplayName name: String, now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> [(date: Date, answered: Int, correct: Int)] {
        if name == "All Games" { return dailySeriesLast(days: days, now: now, calendar: calendar) }
        guard let gameKey = Self.storageKey(forDisplayName: name) else {
            return dailySeriesLast(days: days, now: now, calendar: calendar)
        }

        var cal = calendar
        cal.timeZone = .autoupdatingCurrent
        let startOfToday = cal.startOfDay(for: now)

        let answeredMap: [String: Int] = loadJSONMap(forKey: "gamesDailyAnswered_\(gameKey)")
        let correctMap: [String: Int] = loadJSONMap(forKey: "gamesDailyCorrect_\(gameKey)")

        var series: [(Date, Int, Int)] = []
        for i in stride(from: days - 1, through: 0, by: -1) {
            if let d = cal.date(byAdding: .day, value: -i, to: startOfToday) {
                let key = Self.localDayKey(for: d, calendar: cal)
                let a = max(0, answeredMap[key] ?? 0)
                let c = max(0, correctMap[key] ?? 0)
                series.append((d, a, c))
            }
        }
        return series
    }

    func dailySeriesLast(days: Int, forWordMode mode: WordMode, now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> [(date: Date, answered: Int, correct: Int)] {
        let gameKey = Self.storageKeyForWord(mode: mode)

        var cal = calendar
        cal.timeZone = .autoupdatingCurrent
        let startOfToday = cal.startOfDay(for: now)

        let answeredMap: [String: Int] = loadJSONMap(forKey: "gamesDailyAnswered_\(gameKey)")
        let correctMap: [String: Int] = loadJSONMap(forKey: "gamesDailyCorrect_\(gameKey)")

        var series: [(Date, Int, Int)] = []
        for i in stride(from: days - 1, through: 0, by: -1) {
            if let d = cal.date(byAdding: .day, value: -i, to: startOfToday) {
                let key = Self.localDayKey(for: d, calendar: cal)
                let a = max(0, answeredMap[key] ?? 0)
                let c = max(0, correctMap[key] ?? 0)
                series.append((d, a, c))
            }
        }
        return series
    }

    func activityStreaks(now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> (current: Int, longest: Int) {
        var cal = calendar
        cal.timeZone = .autoupdatingCurrent

        let series = dailySeriesLast(days: 1825, now: now, calendar: cal)
        var longest = 0
        var currentRun = 0
        for (_, a, _) in series {
            if a > 0 {
                currentRun += 1
                longest = max(longest, currentRun)
            } else {
                currentRun = 0
            }
        }

        var current = 0
        for (_, a, _) in series.reversed() {
            if a > 0 { current += 1 } else { break }
        }

        return (current, longest)
    }

    func activityStreaks(forDisplayName name: String, now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> (current: Int, longest: Int) {
        if name == "All Games" { return activityStreaks(now: now, calendar: calendar) }

        var cal = calendar
        cal.timeZone = .autoupdatingCurrent
        let series = dailySeriesLast(days: 1825, forDisplayName: name, now: now, calendar: cal)

        var longest = 0
        var currentRun = 0
        for (_, a, _) in series {
            if a > 0 {
                currentRun += 1
                longest = max(longest, currentRun)
            } else {
                currentRun = 0
            }
        }

        var current = 0
        for (_, a, _) in series.reversed() {
            if a > 0 { current += 1 } else { break }
        }

        return (current, longest)
    }

    func activityStreaks(forWordMode mode: WordMode, now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> (current: Int, longest: Int) {
        var cal = calendar
        cal.timeZone = .autoupdatingCurrent
        let series = dailySeriesLast(days: 1825, forWordMode: mode, now: now, calendar: cal)

        var longest = 0
        var currentRun = 0
        for (_, a, _) in series {
            if a > 0 {
                currentRun += 1
                longest = max(longest, currentRun)
            } else {
                currentRun = 0
            }
        }

        var current = 0
        for (_, a, _) in series.reversed() {
            if a > 0 { current += 1 } else { break }
        }

        return (current, longest)
    }

    func accuracy7DayTrend(now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> (currentPct: Double, deltaVsPrev: Double) {
        let s14 = dailySeriesLast(days: 14, now: now, calendar: calendar)
        let last7 = s14.suffix(7)
        let prev7 = s14.prefix(max(0, s14.count - 7))

        func pct(for slice: ArraySlice<(date: Date, answered: Int, correct: Int)>) -> Double {
            let a = slice.reduce(0) { $0 + max(0, $1.answered) }
            let c = slice.reduce(0) { $0 + max(0, $1.correct) }
            guard a > 0 else { return 0 }
            return min(100, max(0, (Double(c) / Double(a)) * 100.0))
        }

        let cur = pct(for: last7)
        let prev = pct(for: prev7)
        return (cur, cur - prev)
    }

    func accuracy7DayTrend(forDisplayName name: String, now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> (currentPct: Double, deltaVsPrev: Double) {
        if name == "All Games" { return accuracy7DayTrend(now: now, calendar: calendar) }

        let s14 = dailySeriesLast(days: 14, forDisplayName: name, now: now, calendar: calendar)
        let last7 = s14.suffix(7)
        let prev7 = s14.prefix(max(0, s14.count - 7))

        func pct(for slice: ArraySlice<(date: Date, answered: Int, correct: Int)>) -> Double {
            let a = slice.reduce(0) { $0 + max(0, $1.answered) }
            let c = slice.reduce(0, { $0 + max(0, $1.correct) })
            guard a > 0 else { return 0 }
            return min(100, max(0, (Double(c) / Double(a)) * 100.0))
        }

        let cur = pct(for: last7)
        let prev = pct(for: prev7)
        return (cur, cur - prev)
    }

    func accuracy7DayTrend(forWordMode mode: WordMode, now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> (currentPct: Double, deltaVsPrev: Double) {
        let s14 = dailySeriesLast(days: 14, forWordMode: mode, now: now, calendar: calendar)
        let last7 = s14.suffix(7)
        let prev7 = s14.prefix(max(0, s14.count - 7))

        func pct(for slice: ArraySlice<(date: Date, answered: Int, correct: Int)>) -> Double {
            let a = slice.reduce(0) { $0 + max(0, $1.answered) }
            let c = slice.reduce(0, { $0 + max(0, $1.correct) })
            guard a > 0 else { return 0 }
            return min(100, max(0, (Double(c) / Double(a)) * 100.0))
        }

        let cur = pct(for: last7)
        let prev = pct(for: prev7)
        return (cur, cur - prev)
    }

    func lastPlayedSummary(now: Date = Date()) -> (name: String?, relative: String?) {
        let defaults = UserDefaults.standard
        let name = lastPlayedGameName
        let ts = defaults.double(forKey: "gamesLastPlayedAt")
        guard ts > 0 else { return (name, nil) }
        let date = Date(timeIntervalSince1970: ts)
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return (name, f.localizedString(for: date, relativeTo: now))
    }

    private func loadQuizPerBookMaps() -> (answered: [String: Int], correct: [String: Int]) {
        let a: [String: Int] = loadJSONMap(forKey: "quizPerBookAnsweredMap")
        let c: [String: Int] = loadJSONMap(forKey: "quizPerBookCorrectMap")
        return (a, c)
    }

    private func loadQuizPerBookDailyMaps() -> (answered: [String: [String: Int]], correct: [String: [String: Int]]) {
        let a: [String: [String: Int]] = loadNestedJSONMap(forKey: "quizPerBookDailyAnswered")
        let c: [String: [String: Int]] = loadNestedJSONMap(forKey: "quizPerBookDailyCorrect")
        return (a, c)
    }

    private func isOT(bookName: String) -> Bool? {
        let books = BibleData.books
        let indexMap = Dictionary(uniqueKeysWithValues: books.enumerated().map { ($1.name, $0) })
        guard let mattIdx = indexMap["Matthew"], let idx = indexMap[bookName] else {
            return nil
        }
        return idx < mattIdx
    }

    func quizOTNTSummary() -> (otAnswered: Int, otCorrect: Int, ntAnswered: Int, ntCorrect: Int, otPct: Double, ntPct: Double) {
        let (answeredMap, correctMap) = loadQuizPerBookMaps()
        var otA = 0, otC = 0, ntA = 0, ntC = 0

        let allBooks = Set(answeredMap.keys).union(correctMap.keys)
        for b in allBooks {
            let a = max(0, answeredMap[b] ?? 0)
            let c = max(0, correctMap[b] ?? 0)
            if let ot = isOT(bookName: b) {
                if ot {
                    otA += a; otC += c
                } else {
                    ntA += a; ntC += c
                }
            }
        }

        let otPct = otA > 0 ? min(100, max(0, (Double(otC) / Double(otA)) * 100.0)) : 0
        let ntPct = ntA > 0 ? min(100, max(0, (Double(ntC) / Double(ntA)) * 100.0)) : 0
        return (otA, otC, ntA, ntC, otPct, ntPct)
    }

    func quizAccuracyByGenre() -> [(genre: String, answered: Int, correct: Int, pct: Double)] {
        let (answeredMap, correctMap) = loadQuizPerBookMaps()
        var buckets: [StatsSeriesBuilder.Genre: (a: Int, c: Int)] = [:]

        let allBooks = Set(answeredMap.keys).union(correctMap.keys)
        for b in allBooks {
            let a = max(0, answeredMap[b] ?? 0)
            let c = max(0, correctMap[b] ?? 0)
            guard a > 0 else { continue }
            let g = StatsSeriesBuilder.genreForBook(b)
            var cur = buckets[g] ?? (0, 0)
            cur.a += a
            cur.c += c
            buckets[g] = cur
        }

        let order: [StatsSeriesBuilder.Genre] = [.Law, .History, .Poetry, .MajorProphets, .MinorProphets, .Gospels, .Acts, .Epistles, .Apocalypse]
        return order.map { g in
            let vals = buckets[g] ?? (0, 0)
            let pct = vals.a > 0 ? min(100, max(0, (Double(vals.c) / Double(vals.a)) * 100.0)) : 0
            return (g.rawValue, vals.a, vals.c, pct)
        }
    }

    func quizWeakBooks(lastNDays: Int, minAttempts: Int) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        let (dailyA, dailyC) = loadQuizPerBookDailyMaps()

        var cal = Calendar.autoupdatingCurrent
        cal.timeZone = .autoupdatingCurrent
        let startOfToday = cal.startOfDay(for: Date())
        var keys: [String] = []
        for i in stride(from: lastNDays - 1, through: 0, by: -1) {
            if let d = cal.date(byAdding: .day, value: -i, to: startOfToday) {
                keys.append(Self.localDayKey(for: d, calendar: cal))
            }
        }

        var bookA: [String: Int] = [:]
        var bookC: [String: Int] = [:]
        for k in keys {
            if let perBookA = dailyA[k] {
                for (book, val) in perBookA {
                    bookA[book, default: 0] += max(0, val)
                }
            }
            if let perBookC = dailyC[k] {
                for (book, val) in perBookC {
                    bookC[book, default: 0] += max(0, val)
                }
            }
        }

        var rows: [(String, Int, Int, Double)] = []
        let allBooks = Set(bookA.keys).union(bookC.keys)
        for b in allBooks {
            let a = max(0, bookA[b] ?? 0)
            let c = max(0, bookC[b] ?? 0)
            guard a >= minAttempts else { continue }
            let pct = a > 0 ? min(100, max(0, (Double(c) / Double(a)) * 100.0)) : 0
            rows.append((b, a, c, pct))
        }

        rows.sort { lhs, rhs in
            if lhs.3 == rhs.3 { return lhs.0 < rhs.0 }
            return lhs.3 < rhs.3
        }
        return rows
    }

    func quizStrongBooks(lastNDays: Int, minAttempts: Int) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        let (dailyA, dailyC) = loadQuizPerBookDailyMaps()

        var cal = Calendar.autoupdatingCurrent
        cal.timeZone = .autoupdatingCurrent
        let startOfToday = cal.startOfDay(for: Date())
        var keys: [String] = []
        for i in stride(from: lastNDays - 1, through: 0, by: -1) {
            if let d = cal.date(byAdding: .day, value: -i, to: startOfToday) {
                keys.append(Self.localDayKey(for: d, calendar: cal))
            }
        }

        var bookA: [String: Int] = [:]
        var bookC: [String: Int] = [:]
        for k in keys {
            if let perBookA = dailyA[k] {
                for (book, val) in perBookA {
                    bookA[book, default: 0] += max(0, val)
                }
            }
            if let perBookC = dailyC[k] {
                for (book, val) in perBookC {
                    bookC[book, default: 0] += max(0, val)
                }
            }
        }

        var rows: [(String, Int, Int, Double)] = []
        let allBooks = Set(bookA.keys).union(bookC.keys)
        for b in allBooks {
            let a = max(0, bookA[b] ?? 0)
            let c = max(0, bookC[b] ?? 0)
            guard a >= minAttempts else { continue }
            let pct = a > 0 ? min(100, max(0, (Double(c) / Double(a)) * 100.0)) : 0
            rows.append((b, a, c, pct))
        }

        rows.sort { lhs, rhs in
            if lhs.3 == rhs.3 { return lhs.0 < rhs.0 }
            return lhs.3 > rhs.3
        }
        return rows
    }

    func wordleDailySolvedDayKeysLast(days: Int, now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> Set<String> {
        let solved: [String: Int] = loadJSONMap(forKey: "wordleDailySolvedDays")
        var cal = calendar
        cal.timeZone = .autoupdatingCurrent
        let startOfToday = cal.startOfDay(for: now)
        var keys: Set<String> = []
        for i in stride(from: days - 1, through: 0, by: -1) {
            if let d = cal.date(byAdding: .day, value: -i, to: startOfToday) {
                let k = Self.localDayKey(for: d, calendar: cal)
                if solved[k] == 1 {
                    keys.insert(k)
                }
            }
        }
        return keys
    }

    private func loadHangmanPerCategoryMaps() -> (answered: [String: Int], correct: [String: Int]) {
        let a: [String: Int] = loadJSONMap(forKey: "hangmanPerCategoryAnsweredMap")
        let c: [String: Int] = loadJSONMap(forKey: "hangmanPerCategoryCorrectMap")
        return (a, c)
    }

    func recordHangmanCategory(category: String, answered addAnswered: Int, correct addCorrect: Int) {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, (addAnswered != 0 || addCorrect != 0) else { return }

        var answeredMap: [String: Int] = loadJSONMap(forKey: "hangmanPerCategoryAnsweredMap")
        if addAnswered != 0 {
            answeredMap[trimmed, default: 0] = max(0, (answeredMap[trimmed] ?? 0) + max(0, addAnswered))
            saveJSONMap(answeredMap, forKey: "hangmanPerCategoryAnsweredMap")
            iCloudSyncCoordinator.shared.pushKey("hangmanPerCategoryAnsweredMap")
        }

        var correctMap: [String: Int] = loadJSONMap(forKey: "hangmanPerCategoryCorrectMap")
        if addCorrect != 0 {
            correctMap[trimmed, default: 0] = max(0, (correctMap[trimmed] ?? 0) + max(0, addCorrect))
            saveJSONMap(correctMap, forKey: "hangmanPerCategoryCorrectMap")
            iCloudSyncCoordinator.shared.pushKey("hangmanPerCategoryCorrectMap")
        }

        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

    func hangmanAccuracyByCategory() -> [(category: String, answered: Int, correct: Int, pct: Double)] {
        let (aMap, cMap) = loadHangmanPerCategoryMaps()
        let order = ["People", "Places", "Books"]
        return order.map { cat in
            let a = max(0, aMap[cat] ?? 0)
            let c = max(0, cMap[cat] ?? 0)
            let pct = a > 0 ? min(100, max(0, (Double(c) / Double(a)) * 100.0)) : 0
            return (cat, a, c, pct)
        }
    }

    func quizAccuracyByBook(inGenre genreName: String) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        let (answeredMap, correctMap) = loadQuizPerBookMaps()
        let allCanonicalBooks = BibleData.books.map { $0.name }
        var rows: [(String, Int, Int, Double)] = []
        for b in allCanonicalBooks {
            let genre = StatsSeriesBuilder.genreForBook(b).rawValue
            guard genre == genreName else { continue }
            let a = max(0, answeredMap[b] ?? 0)
            let c = max(0, correctMap[b] ?? 0)
            let pct = a > 0 ? min(100, max(0, (Double(c) / Double(a)) * 100.0)) : 0
            rows.append((b, a, c, pct))
        }
        let canonicalPos = Dictionary(uniqueKeysWithValues: allCanonicalBooks.enumerated().map { ($1, $0) })
        rows.sort { lhs, rhs in
            (canonicalPos[lhs.0] ?? .max) < (canonicalPos[rhs.0] ?? .max)
        }
        return rows
    }

    private func loadBeatClockPerTypeMaps() -> (answered: [String: Int], correct: [String: Int]) {
        let a: [String: Int] = loadJSONMap(forKey: "beatclockPerTypeAnsweredMap")
        let c: [String: Int] = loadJSONMap(forKey: "beatclockPerTypeCorrectMap")
        return (a, c)
    }

    func recordBeatClockType(type: String, answered addAnswered: Int, correct addCorrect: Int) {
        let trimmed = type.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, (addAnswered != 0 || addCorrect != 0) else { return }

        var aMap: [String: Int] = loadJSONMap(forKey: "beatclockPerTypeAnsweredMap")
        if addAnswered != 0 {
            aMap[trimmed, default: 0] = max(0, (aMap[trimmed] ?? 0) + max(0, addAnswered))
            saveJSONMap(aMap, forKey: "beatclockPerTypeAnsweredMap")
            iCloudSyncCoordinator.shared.pushKey("beatclockPerTypeAnsweredMap")
        }

        var cMap: [String: Int] = loadJSONMap(forKey: "beatclockPerTypeCorrectMap")
        if addCorrect != 0 {
            cMap[trimmed, default: 0] = max(0, (cMap[trimmed] ?? 0) + max(0, addCorrect))
            saveJSONMap(cMap, forKey: "beatclockPerTypeCorrectMap")
            iCloudSyncCoordinator.shared.pushKey("beatclockPerTypeCorrectMap")
        }

        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

    func beatclockAccuracyByType() -> [(type: String, answered: Int, correct: Int, pct: Double)] {
        let (aMap, cMap) = loadBeatClockPerTypeMaps()
        let order = ["People", "Places"]
        return order.map { t in
            let a = max(0, aMap[t] ?? 0)
            let c = max(0, cMap[t] ?? 0)
            let pct = a > 0 ? min(100, max(0, (Double(c) / Double(a)) * 100.0)) : 0
            return (t, a, c, pct)
        }
    }

    private func loadVerseMatchPerBookMaps() -> (answered: [String: Int], correct: [String: Int]) {
        let a: [String: Int] = loadJSONMap(forKey: "versematchPerBookAnsweredMap")
        let c: [String: Int] = loadJSONMap(forKey: "versematchPerBookCorrectMap")
        return (a, c)
    }

    // NEW: Verse Match daily nested per-book maps loader
    private func loadVerseMatchPerBookDailyMaps() -> (answered: [String: [String: Int]], correct: [String: [String: Int]]) {
        let a: [String: [String: Int]] = loadNestedJSONMap(forKey: "versematchPerBookDailyAnswered")
        let c: [String: [String: Int]] = loadNestedJSONMap(forKey: "versematchPerBookDailyCorrect")
        return (a, c)
    }

    func verseMatchOTNTSummary() -> (otAnswered: Int, otCorrect: Int, ntAnswered: Int, ntCorrect: Int, otPct: Double, ntPct: Double) {
        let (answeredMap, correctMap) = loadVerseMatchPerBookMaps()
        var otA = 0, otC = 0, ntA = 0, ntC = 0

        let allBooks = Set(answeredMap.keys).union(correctMap.keys)
        for b in allBooks {
            let a = max(0, answeredMap[b] ?? 0)
            let c = max(0, correctMap[b] ?? 0)
            if let ot = isOT(bookName: b) {
                if ot {
                    otA += a; otC += c
                } else {
                    ntA += a; ntC += c
                }
            }
        }

        let otPct = otA > 0 ? min(100, max(0, (Double(otC) / Double(otA)) * 100.0)) : 0
        let ntPct = ntA > 0 ? min(100, max(0, (Double(ntC) / Double(ntA)) * 100.0)) : 0
        return (otA, otC, ntA, ntC, otPct, ntPct)
    }

    func verseMatchAccuracyByGenre() -> [(genre: String, answered: Int, correct: Int, pct: Double)] {
        let (answeredMap, correctMap) = loadVerseMatchPerBookMaps()
        var buckets: [StatsSeriesBuilder.Genre: (a: Int, c: Int)] = [:]

        let allBooks = Set(answeredMap.keys).union(correctMap.keys)
        for b in allBooks {
            let a = max(0, answeredMap[b] ?? 0)
            let c = max(0, correctMap[b] ?? 0)
            guard a > 0 else { continue }
            let g = StatsSeriesBuilder.genreForBook(b)
            var cur = buckets[g] ?? (0, 0)
            cur.a += a
            cur.c += c
            buckets[g] = cur
        }

        let order: [StatsSeriesBuilder.Genre] = [.Law, .History, .Poetry, .MajorProphets, .MinorProphets, .Gospels, .Acts, .Epistles, .Apocalypse]
        return order.map { g in
            let vals = buckets[g] ?? (0, 0)
            let pct = vals.a > 0 ? min(100, max(0, (Double(vals.c) / Double(vals.a)) * 100.0)) : 0
            return (g.rawValue, vals.a, vals.c, pct)
        }
    }

    func verseMatchAccuracyByBook(inGenre genreName: String) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        let (answeredMap, correctMap) = loadVerseMatchPerBookMaps()
        let allCanonicalBooks = BibleData.books.map { $0.name }
        var rows: [(String, Int, Int, Double)] = []
        for b in allCanonicalBooks {
            let genre = StatsSeriesBuilder.genreForBook(b).rawValue
            guard genre == genreName else { continue }
            let a = max(0, answeredMap[b] ?? 0)
            let c = max(0, correctMap[b] ?? 0)
            let pct = a > 0 ? min(100, max(0, (Double(c) / Double(a)) * 100.0)) : 0
            rows.append((b, a, c, pct))
        }
        let canonicalPos = Dictionary(uniqueKeysWithValues: allCanonicalBooks.enumerated().map { ($1, $0) })
        rows.sort { lhs, rhs in
            (canonicalPos[lhs.0] ?? .max) < (canonicalPos[rhs.0] ?? .max)
        }
        return rows
    }

    // NEW: Verse Match weak/strong books over last N days (mirrors Quiz)
    func verseMatchWeakBooks(lastNDays: Int, minAttempts: Int) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        let (dailyA, dailyC) = loadVerseMatchPerBookDailyMaps()

        var cal = Calendar.autoupdatingCurrent
        cal.timeZone = .autoupdatingCurrent
        let startOfToday = cal.startOfDay(for: Date())
        var keys: [String] = []
        for i in stride(from: lastNDays - 1, through: 0, by: -1) {
            if let d = cal.date(byAdding: .day, value: -i, to: startOfToday) {
                keys.append(Self.localDayKey(for: d, calendar: cal))
            }
        }

        var bookA: [String: Int] = [:]
        var bookC: [String: Int] = [:]
        for k in keys {
            if let perBookA = dailyA[k] {
                for (book, val) in perBookA {
                    bookA[book, default: 0] += max(0, val)
                }
            }
            if let perBookC = dailyC[k] {
                for (book, val) in perBookC {
                    bookC[book, default: 0] += max(0, val)
                }
            }
        }

        var rows: [(String, Int, Int, Double)] = []
        let allBooks = Set(bookA.keys).union(bookC.keys)
        for b in allBooks {
            let a = max(0, bookA[b] ?? 0)
            let c = max(0, bookC[b] ?? 0)
            guard a >= minAttempts else { continue }
            let pct = a > 0 ? min(100, max(0, (Double(c) / Double(a)) * 100.0)) : 0
            rows.append((b, a, c, pct))
        }

        rows.sort { lhs, rhs in
            if lhs.3 == rhs.3 { return lhs.0 < rhs.0 }
            return lhs.3 < rhs.3
        }
        return rows
    }

    func verseMatchStrongBooks(lastNDays: Int, minAttempts: Int) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        let (dailyA, dailyC) = loadVerseMatchPerBookDailyMaps()

        var cal = Calendar.autoupdatingCurrent
        cal.timeZone = .autoupdatingCurrent
        let startOfToday = cal.startOfDay(for: Date())
        var keys: [String] = []
        for i in stride(from: lastNDays - 1, through: 0, by: -1) {
            if let d = cal.date(byAdding: .day, value: -i, to: startOfToday) {
                keys.append(Self.localDayKey(for: d, calendar: cal))
            }
        }

        var bookA: [String: Int] = [:]
        var bookC: [String: Int] = [:]
        for k in keys {
            if let perBookA = dailyA[k] {
                for (book, val) in perBookA {
                    bookA[book, default: 0] += max(0, val)
                }
            }
            if let perBookC = dailyC[k] {
                for (book, val) in perBookC {
                    bookC[book, default: 0] += max(0, val)
                }
            }
        }

        var rows: [(String, Int, Int, Double)] = []
        let allBooks = Set(bookA.keys).union(bookC.keys)
        for b in allBooks {
            let a = max(0, bookA[b] ?? 0)
            let c = max(0, bookC[b] ?? 0)
            guard a >= minAttempts else { continue }
            let pct = a > 0 ? min(100, max(0, (Double(c) / Double(a)) * 100.0)) : 0
            rows.append((b, a, c, pct))
        }

        rows.sort { lhs, rhs in
            if lhs.3 == rhs.3 { return lhs.0 < rhs.0 }
            return lhs.3 > rhs.3
        }
        return rows
    }
}
