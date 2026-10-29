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
        migrateLegacyGameKeysIfNeeded()
        migrateQuizCombinedIfNeeded()
        migrateBookOrderCombinedIfNeeded()
        migrateHangmanCombinedIfNeeded() // backfill combined “_all” for Hangman
        migrateVerseMatchCombinedIfNeeded() // backfill combined “_all” for Verses
        migrateWhoAmICombinedIfNeeded() // backfill combined “_all” for Who?

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

    private static let legacyWipeFlagKey = "didWipeLegacyUnsuffixedGameKeys_v1"
    private static let quizCombinedMigrationFlagKey = "didMigrateQuizCombinedAll_v1"
    private static let bookOrderCombinedMigrationFlagKey = "didMigrateBookOrderCombinedAll_v1"
    private static let hangmanCombinedMigrationFlagKey = "didMigrateHangmanCombinedAll_v1"
    private static let verseMatchCombinedMigrationFlagKey = "didMigrateVerseMatchCombinedAll_v1"
    private static let whoamiCombinedMigrationFlagKey = "didMigrateWhoAmICombinedAll_v1"

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

    // One-time migration: combine existing per-difficulty Hangman stats into combined "_all" keys.
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

    // One-time migration: combine existing per-difficulty Verses stats into combined "_all" keys.
    private func migrateVerseMatchCombinedIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.verseMatchCombinedMigrationFlagKey) else { return }

        func readInt(_ key: String) -> Int { max(0, defaults.integer(forKey: key)) }

        // New Verses keys
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

    // One-time migration: combine existing per-difficulty Who? stats into combined "_all" keys.
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
        let t = trivia
        let h = hangman
        let r = versematch
        let b = beatclock
        let o = bookorder
        let w = whoami
        let ws = wordsearch
        let s = scramble

        let wdDaily = wordle(type: .daily)
        let wdFree = wordle(type: .free)
        let wdLegacyAll = wordleLegacyAll
        let typedAnswered = wdDaily.answered + wdFree.answered
        let typedCorrect = wdDaily.correct + wdFree.correct
        let wdCombined = GameStat(
            correct: typedAnswered > 0 || typedCorrect > 0 ? typedCorrect : wdLegacyAll.correct,
            answered: typedAnswered > 0 || typedCorrect > 0 ? typedAnswered : wdLegacyAll.answered,
            bestStreak: max((wdDaily.bestStreak ?? 0), (wdFree.bestStreak ?? 0), (wdLegacyAll.bestStreak ?? 0))
        )

        let entries: [GameBreakdown.Entry] = [
            .init(name: "Quiz", correct: q.correct, answered: q.answered, bestStreak: q.bestStreak),
            .init(name: "Trivia", correct: t.correct, answered: t.answered, bestStreak: t.bestStreak),
            .init(name: "Hangman", correct: h.correct, answered: h.answered, bestStreak: h.bestStreak),
            .init(name: "Verses", correct: r.correct, answered: r.answered, bestStreak: r.bestStreak),
            .init(name: "Countdown", correct: b.correct, answered: b.answered, bestStreak: b.bestStreak),
            .init(name: "Book Order", correct: o.correct, answered: o.answered, bestStreak: o.bestStreak),
            .init(name: "Who?", correct: w.correct, answered: w.answered, bestStreak: w.bestStreak),
            .init(name: "Word Search", correct: ws.correct, answered: ws.answered, bestStreak: ws.bestStreak),
            .init(name: "Scramble", correct: s.correct, answered: s.answered, bestStreak: s.bestStreak),
            .init(name: "Word", correct: wdCombined.correct, answered: wdCombined.answered, bestStreak: wdCombined.bestStreak)
        ]
        return GameBreakdown(entries: entries)
    }

    struct ScorecardStats {
        let correct: Int
        let attempts: Int
        let bestStreak: Int
    }

    /// The canonical source used by both the Stats tab and every in-game scorecard.
    func scorecardStats(for game: GameID, wordMode: WordMode? = nil) -> ScorecardStats {
        let stat: GameStat
        switch game {
        case .quiz: stat = quiz
        case .trivia: stat = trivia
        case .hangman: stat = hangman
        case .beatclock: stat = beatclock
        case .versematch: stat = versematch
        case .bookorder: stat = bookorder
        case .whoami: stat = whoami
        case .wordsearch: stat = wordsearch
        case .scramble: stat = scramble
        case .wordle:
            if let wordMode {
                let counts = wordleCounts(mode: wordMode)
                let suffix = wordMode == .hard ? "hard" : "normal"
                return ScorecardStats(
                    correct: counts.wins,
                    attempts: counts.answered,
                    bestStreak: max(0, readInt("wordleAllTimeBestStreak_\(suffix)"))
                )
            }
            let entry = breakdownSnapshot().entries.first { $0.name == "Word" }
            return ScorecardStats(
                correct: entry?.correct ?? 0,
                attempts: entry?.answered ?? 0,
                bestStreak: entry?.bestStreak ?? 0
            )
        }
        return ScorecardStats(correct: stat.correct, attempts: stat.answered, bestStreak: stat.bestStreak ?? 0)
    }

    private static func storageKey(for game: GameID) -> String {
        switch game {
        case .quiz: return "quiz"
        case .trivia: return "trivia"
        case .hangman: return "hangman"
        case .beatclock: return "beatclock"
        case .versematch: return "versematch"
        case .bookorder: return "bookorder"
        case .whoami: return "whoami"
        case .wordsearch: return "wordsearch"
        case .scramble: return "scramble"
        case .wordle: return "word"
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

    private static func storageKey(forDisplayName rawName: String) -> String? {
        switch canonicalDisplayName(rawName) {
        case "Quiz": return "quiz"
        case "Trivia": return "trivia"
        case "Hangman": return "hangman"
        case "Verses": return "versematch"
        case "Countdown": return "beatclock"
        case "Book Order": return "bookorder"
        case "Who?": return "whoami"
        case "Word Search": return "wordsearch"
        case "Scramble": return "scramble"
        case "Word": return "word"
        default: return nil
        }
    }

    private static func storageKeyForWord(mode: WordMode) -> String {
        switch mode {
        case .normal: return "word_normal"
        case .hard:   return "word_hard"
        }
    }

    private func updateDailyMaps(addAnswered: Int, addCorrect: Int, forGameKey key: String, includeOverall: Bool = true) {
        let dayKey = Self.localDayKey(for: Date())

        if includeOverall {
            var dailyAnswered: [String: Int] = loadJSONMap(forKey: "gamesDailyAnswered")
            dailyAnswered[dayKey, default: 0] = max(0, (dailyAnswered[dayKey] ?? 0) + max(0, addAnswered))
            saveJSONMap(dailyAnswered, forKey: "gamesDailyAnswered")

            var dailyCorrect: [String: Int] = loadJSONMap(forKey: "gamesDailyCorrect")
            dailyCorrect[dayKey, default: 0] = max(0, (dailyCorrect[dayKey] ?? 0) + max(0, addCorrect))
            saveJSONMap(dailyCorrect, forKey: "gamesDailyCorrect")
        }

        var perAnswered: [String: Int] = loadJSONMap(forKey: "gamesDailyAnswered_\(key)")
        perAnswered[dayKey, default: 0] = max(0, (perAnswered[dayKey] ?? 0) + max(0, addAnswered))
        saveJSONMap(perAnswered, forKey: "gamesDailyAnswered_\(key)")

        var perCorrect: [String: Int] = loadJSONMap(forKey: "gamesDailyCorrect_\(key)")
        perCorrect[dayKey, default: 0] = max(0, (perCorrect[dayKey] ?? 0) + max(0, addCorrect))
        saveJSONMap(perCorrect, forKey: "gamesDailyCorrect_\(key)")
    }

    /// The four stored maps behind a game's per-book accuracy: all-time and per-day, answered and correct.
    private struct PerBookKeys {
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

    func recordQuizPerBook(bookName: String, answered addAnswered: Int, correct addCorrect: Int) {
        recordPerBook(.quiz, bookName: bookName, answered: addAnswered, correct: addCorrect)
    }

    func recordTriviaPerBook(bookName: String, answered addAnswered: Int, correct addCorrect: Int) {
        recordPerBook(.trivia, bookName: bookName, answered: addAnswered, correct: addCorrect)
    }

    func recordVerseMatchPerBook(bookName: String, answered addAnswered: Int, correct addCorrect: Int) {
        recordPerBook(.verseMatch, bookName: bookName, answered: addAnswered, correct: addCorrect)
    }

    /// Adds one round's result for a book to the all-time and today's maps.
    private func recordPerBook(_ keys: PerBookKeys, bookName: String, answered addAnswered: Int, correct addCorrect: Int) {
        let book = bookName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !book.isEmpty, addAnswered != 0 || addCorrect != 0 else { return }
        let dayKey = Self.localDayKey(for: Date())

        addToBookMap(keys.answered, book: book, delta: addAnswered)
        addToBookMap(keys.correct, book: book, delta: addCorrect)
        addToDailyBookMap(keys.dailyAnswered, dayKey: dayKey, book: book, delta: addAnswered)
        addToDailyBookMap(keys.dailyCorrect, dayKey: dayKey, book: book, delta: addCorrect)

        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

    private func addToBookMap(_ key: String, book: String, delta: Int) {
        guard delta != 0 else { return }
        var map = loadJSONMap(forKey: key)
        map[book] = max(0, (map[book] ?? 0) + max(0, delta))
        saveJSONMap(map, forKey: key)
        iCloudSyncCoordinator.shared.pushKey(key)
    }

    private func addToDailyBookMap(_ key: String, dayKey: String, book: String, delta: Int) {
        guard delta != 0 else { return }
        var days = loadNestedJSONMap(forKey: key)
        var books = days[dayKey] ?? [:]
        books[book] = max(0, (books[book] ?? 0) + max(0, delta))
        days[dayKey] = books
        saveNestedJSONMap(days, forKey: key)
        iCloudSyncCoordinator.shared.pushKey(key)
    }

    /// Writes game counters: increments, raises to a new best, or sets, never below zero.
    /// `didWrite` runs after each write so a caller can push the key to iCloud right away
    /// or collect the keys and push them together.
    private struct StatCounterWriter {
        let didWrite: (String) -> Void
        private let defaults = UserDefaults.standard

        init(didWrite: @escaping (String) -> Void) {
            self.didWrite = didWrite
        }

        func set(_ key: String, _ value: Int) {
            defaults.set(max(0, value), forKey: key)
            didWrite(key)
        }

        func increment(_ key: String, by delta: Int) {
            set(key, defaults.integer(forKey: key) + delta)
        }

        func raise(_ key: String, candidate: Int) {
            if candidate > defaults.integer(forKey: key) { set(key, candidate) }
        }

        /// A writer that pushes each key to iCloud as it is written.
        static var pushingEachKey: StatCounterWriter {
            StatCounterWriter { iCloudSyncCoordinator.shared.pushKey($0) }
        }
    }

    func recordRound(game: GameID, difficulty: Difficulty, correct addCorrect: Int, answered addAnswered: Int, currentBestStreak: Int) {
        var changedKeys: [String] = []

        let counters = StatCounterWriter { changedKeys.append($0) }



        func suffix(for game: GameID, difficulty: Difficulty) -> String? {
            switch game {
            case .quiz:
                switch difficulty {
                case .easy: return "easy"
                case .normal: return "normal"
                case .hard: return "hard"
                case .medium, .none: return nil
                }
            case .trivia, .hangman, .beatclock, .versematch, .wordsearch, .scramble:
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
                case .none: return "expert" // Expert (every book); also mirrored into "_all"
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
        case .trivia:
            guard let s = suf else { return }
            counters.increment("triviaAllTimeCorrect_\(s)", by: addCorrect)
            counters.increment("triviaAllTimeAnswered_\(s)", by: addAnswered)
            counters.raise("triviaAllTimeBestStreak_\(s)", candidate: currentBestStreak)
            counters.increment("triviaAllTimeCorrect_all", by: addCorrect)
            counters.increment("triviaAllTimeAnswered_all", by: addAnswered)
            counters.raise("triviaAllTimeBestStreak_all", candidate: currentBestStreak)

        case .quiz:
            guard let s = suf else { return }
            // Keep per-difficulty keys for back-compat/analytics
            counters.increment("quizAllTimeCorrect_\(s)", by: addCorrect)
            counters.increment("quizAllTimeAnswered_\(s)", by: addAnswered)
            counters.raise("quizAllTimeBestStreak_\(s)", candidate: currentBestStreak)
            // Mirror to combined keys so all difficulties share the same all-time stats
            counters.increment("quizAllTimeCorrect_all", by: addCorrect)
            counters.increment("quizAllTimeAnswered_all", by: addAnswered)
            counters.raise("quizAllTimeBestStreak_all", candidate: currentBestStreak)

        case .hangman:
            guard let s = suf else { return }
            counters.increment("hangmanAllTimeCorrect_\(s)", by: addCorrect)
            counters.increment("hangmanAllTimeAnswered_\(s)", by: addAnswered)
            counters.raise("hangmanAllTimeBestStreak_\(s)", candidate: currentBestStreak)
            // Mirror to combined keys so all difficulties share the same all-time stats
            counters.increment("hangmanAllTimeCorrect_all", by: addCorrect)
            counters.increment("hangmanAllTimeAnswered_all", by: addAnswered)
            counters.raise("hangmanAllTimeBestStreak_all", candidate: currentBestStreak)

        case .beatclock:
            guard let s = suf else { return }
            // Keep per-difficulty keys for back-compat/analytics
            counters.increment("beatclockAllTimeCorrect_\(s)", by: addCorrect)
            counters.increment("beatclockAllTimeAnswered_\(s)", by: addAnswered)
            counters.raise("beatclockAllTimeBestStreak_\(s)", candidate: currentBestStreak)
            // Always mirror to combined keys so all difficulties share the same all-time stats
            counters.increment("beatclockAllTimeCorrect_all", by: addCorrect)
            counters.increment("beatclockAllTimeAnswered_all", by: addAnswered)
            counters.raise("beatclockAllTimeBestStreak_all", candidate: currentBestStreak)

        case .versematch:
            guard let s = suf else { return }
            // Keep per-difficulty keys for back-compat/analytics
            counters.increment("versematchAllTimeCorrect_\(s)", by: addCorrect)
            counters.increment("versematchAllTimeAnswered_\(s)", by: addAnswered)
            counters.raise("versematchAllTimeBestStreak_\(s)", candidate: currentBestStreak)
            // Mirror to combined keys so all difficulties share the same all-time stats
            counters.increment("versematchAllTimeCorrect_all", by: addCorrect)
            counters.increment("versematchAllTimeAnswered_all", by: addAnswered)
            counters.raise("versematchAllTimeBestStreak_all", candidate: currentBestStreak)

        case .bookorder:
            guard let s = suf else { return }
            // Write per-difficulty ("expert" when difficulty == .none)
            counters.increment("bookorderAllTimeCorrect_\(s)", by: addCorrect)
            counters.increment("bookorderAllTimeAnswered_\(s)", by: addAnswered)
            counters.raise("bookorderAllTimeBestStreak_\(s)", candidate: currentBestStreak)
            // Mirror to combined keys when not already writing to "_all"
            if s != "all" {
                counters.increment("bookorderAllTimeCorrect_all", by: addCorrect)
                counters.increment("bookorderAllTimeAnswered_all", by: addAnswered)
                counters.raise("bookorderAllTimeBestStreak_all", candidate: currentBestStreak)
            }

        case .whoami:
            guard let s = suf else { return }
            // Keep per-difficulty keys for back-compat/analytics
            counters.increment("whoamiAllTimeCorrect_\(s)", by: addCorrect)
            counters.increment("whoamiAllTimeAnswered_\(s)", by: addAnswered)
            counters.raise("whoamiAllTimeBestStreak_\(s)", candidate: currentBestStreak)
            // Mirror to combined keys so all difficulties share the same all-time stats
            counters.increment("whoamiAllTimeCorrect_all", by: addCorrect)
            counters.increment("whoamiAllTimeAnswered_all", by: addAnswered)
            counters.raise("whoamiAllTimeBestStreak_all", candidate: currentBestStreak)

        case .wordsearch:
            guard let s = suf else { return }
            counters.increment("wordsearchAllTimeCorrect_\(s)", by: addCorrect)
            counters.increment("wordsearchAllTimeAnswered_\(s)", by: addAnswered)
            counters.raise("wordsearchAllTimeBestStreak_\(s)", candidate: currentBestStreak)
            counters.increment("wordsearchAllTimeCorrect_all", by: addCorrect)
            counters.increment("wordsearchAllTimeAnswered_all", by: addAnswered)
            counters.raise("wordsearchAllTimeBestStreak_all", candidate: currentBestStreak)

        case .scramble:
            guard let s = suf else { return }
            counters.increment("scrambleAllTimeCorrect_\(s)", by: addCorrect)
            counters.increment("scrambleAllTimeAnswered_\(s)", by: addAnswered)
            counters.raise("scrambleAllTimeBestStreak_\(s)", candidate: currentBestStreak)
            counters.increment("scrambleAllTimeCorrect_all", by: addCorrect)
            counters.increment("scrambleAllTimeAnswered_all", by: addAnswered)
            counters.raise("scrambleAllTimeBestStreak_all", candidate: currentBestStreak)

        case .wordle:
            guard let s = suf else { return }
            counters.increment("wordleAllTimeCorrect_\(s)", by: addCorrect)
            counters.increment("wordleAllTimeAnswered_\(s)", by: addAnswered)
            counters.raise("wordleAllTimeBestStreak_\(s)", candidate: currentBestStreak)
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
        let suf = (type == .daily) ? "daily" : "free"
        let counters = StatCounterWriter.pushingEachKey

        counters.increment("wordleAllTimeCorrect_\(suf)", by: addCorrect)
        counters.increment("wordleAllTimeAnswered_\(suf)", by: addAnswered)
        counters.raise("wordleAllTimeBestStreak_\(suf)", candidate: currentBestStreak)

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
        updateDailyMaps(addAnswered: 1, addCorrect: won ? 1 : 0, forGameKey: perModeKey, includeOverall: false)

        let typeSuf = (type == .daily) ? "daily" : "free"
        let modeSuf = (mode == .normal) ? "normal" : "hard"
        let clamped = max(1, min(6, guesses))

        let counters = StatCounterWriter.pushingEachKey

        counters.increment("wordleAllTimeCorrect_\(modeSuf)", by: won ? 1 : 0)
        counters.increment("wordleAllTimeAnswered_\(modeSuf)", by: 1)
        counters.raise("wordleAllTimeBestStreak_\(modeSuf)", candidate: currentBestStreak)

        if won {
            counters.increment("wordleWinsGuessSum_\(typeSuf)", by: clamped)
            counters.increment("wordleWinsOnGuess\(clamped)_\(typeSuf)", by: 1)
            counters.increment("wordleWinsGuessSum_\(modeSuf)", by: clamped)
            counters.increment("wordleWinsOnGuess\(clamped)_\(modeSuf)", by: 1)
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
        let typeSuf = (type == .daily) ? "daily" : "free"
        let modeSuf = (mode == .normal) ? "normal" : "hard"

        let counters = StatCounterWriter.pushingEachKey

        counters.increment("wordleTimeTotal_seconds_\(typeSuf)", by: max(0, elapsedSeconds))
        if won {
            counters.increment("wordleTimeWins_seconds_\(typeSuf)", by: max(0, elapsedSeconds))
        } else {
            counters.increment("wordleTimeLosses_seconds_\(typeSuf)", by: max(0, elapsedSeconds))
        }

        counters.increment("wordleTimeTotal_seconds_\(modeSuf)", by: max(0, elapsedSeconds))
        if won {
            counters.increment("wordleTimeWins_seconds_\(modeSuf)", by: max(0, elapsedSeconds))
        } else {
            counters.increment("wordleTimeLosses_seconds_\(modeSuf)", by: max(0, elapsedSeconds))
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

    private var trivia: GameStat {
        let correct = max(0, readInt("triviaAllTimeCorrect_all"))
        let answered = max(0, readInt("triviaAllTimeAnswered_all"))
        let bestStreak = max(0, readInt("triviaAllTimeBestStreak_all"))
        return GameStat(
            correct: correct,
            answered: answered,
            bestStreak: bestStreak == 0 ? nil : bestStreak
        )
    }

    func triviaCounts(difficulty: Difficulty) -> (correct: Int, answered: Int) {
        let suffix: String
        switch difficulty {
        case .easy: suffix = "easy"
        case .normal, .medium: suffix = "normal"
        case .hard: suffix = "hard"
        case .none: suffix = "all"
        }
        return (
            max(0, readInt("triviaAllTimeCorrect_\(suffix)")),
            max(0, readInt("triviaAllTimeAnswered_\(suffix)"))
        )
    }

    private var hangman: GameStat {
        // Prefer combined keys if present; otherwise fall back to summing per-difficulty/legacy
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
        // Prefer combined keys if present; otherwise fall back to new per-difficulty or legacy refmatch
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
        // Prefer combined keys if present; otherwise fall back to summing per-difficulty/legacy
        let combinedC = max(0, readInt("beatclockAllTimeCorrect_all"))
        let combinedA = max(0, readInt("beatclockAllTimeAnswered_all"))
        let combinedB = max(0, readInt("beatclockAllTimeBestStreak_all"))
        if (combinedC + combinedA + combinedB) > 0 {
            return GameStat(correct: combinedC, answered: combinedA, bestStreak: combinedB == 0 ? nil : combinedB)
        }

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
        // Prefer combined keys if present; otherwise fall back to summing per-difficulty
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

    private var wordsearch: GameStat {
        let combinedC = max(0, readInt("wordsearchAllTimeCorrect_all"))
        let combinedA = max(0, readInt("wordsearchAllTimeAnswered_all"))
        let combinedB = max(0, readInt("wordsearchAllTimeBestStreak_all"))
        if (combinedC + combinedA + combinedB) > 0 {
            return GameStat(correct: combinedC, answered: combinedA, bestStreak: combinedB == 0 ? nil : combinedB)
        }

        let c = sumAcross(prefix: "wordsearchAllTimeCorrect", parts: ["_easy", "_normal", "_hard"], legacyKey: nil)
        let a = sumAcross(prefix: "wordsearchAllTimeAnswered", parts: ["_easy", "_normal", "_hard"], legacyKey: nil)
        let best = maxAcross(prefix: "wordsearchAllTimeBestStreak", parts: ["_easy", "_normal", "_hard"], legacyKey: nil)
        return GameStat(correct: c, answered: a, bestStreak: best == 0 ? nil : best)
    }

    private var scramble: GameStat {
        let combinedC = max(0, readInt("scrambleAllTimeCorrect_all"))
        let combinedA = max(0, readInt("scrambleAllTimeAnswered_all"))
        let combinedB = max(0, readInt("scrambleAllTimeBestStreak_all"))
        if (combinedC + combinedA + combinedB) > 0 {
            return GameStat(correct: combinedC, answered: combinedA, bestStreak: combinedB == 0 ? nil : combinedB)
        }

        let c = sumAcross(prefix: "scrambleAllTimeCorrect", parts: ["_easy", "_normal", "_hard"], legacyKey: nil)
        let a = sumAcross(prefix: "scrambleAllTimeAnswered", parts: ["_easy", "_normal", "_hard"], legacyKey: nil)
        let best = maxAcross(prefix: "scrambleAllTimeBestStreak", parts: ["_easy", "_normal", "_hard"], legacyKey: nil)
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

    func wordleCounts(type: WordleType) -> (answered: Int, wins: Int) {
        let suf = (type == .daily) ? "daily" : "free"
        let wins = max(0, readInt("wordleAllTimeCorrect_\(suf)"))
        let answered = max(0, readInt("wordleAllTimeAnswered_\(suf)"))
        return (answered, wins)
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
        let stats = [quiz, trivia, hangman, versematch, beatclock, bookorder, whoami, wordsearch, scramble]
        let typedCorrect = wordle(type: .daily).correct + wordle(type: .free).correct
        let typedAnswered = wordle(type: .daily).answered + wordle(type: .free).answered
        let wordleCombined = GameStat(
            correct: typedCorrect > 0 || typedAnswered > 0 ? typedCorrect : wordleLegacyAll.correct,
            answered: typedCorrect > 0 || typedAnswered > 0 ? typedAnswered : wordleLegacyAll.answered,
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

    private func loadJSONMap(forKey key: String) -> [String: Int] {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            flatMapCache[key] = nil
            return [:]
        }
        if let cached = flatMapCache[key], cached.data == data { return cached.map }
        guard let map = try? JSONDecoder().decode([String: Int].self, from: data) else {
            flatMapCache[key] = nil
            return [:]
        }
        flatMapCache[key] = CachedMap(data: data, map: map)
        return map
    }

    private func saveJSONMap(_ map: [String: Int], forKey key: String) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        UserDefaults.standard.set(data, forKey: key)
        flatMapCache[key] = CachedMap(data: data, map: map)
    }

    private func loadNestedJSONMap(forKey key: String) -> [String: [String: Int]] {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            nestedMapCache[key] = nil
            return [:]
        }
        if let cached = nestedMapCache[key], cached.data == data { return cached.map }
        guard let map = try? JSONDecoder().decode([String: [String: Int]].self, from: data) else {
            nestedMapCache[key] = nil
            return [:]
        }
        nestedMapCache[key] = CachedMap(data: data, map: map)
        return map
    }

    private func saveNestedJSONMap(_ map: [String: [String: Int]], forKey key: String) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        UserDefaults.standard.set(data, forKey: key)
        nestedMapCache[key] = CachedMap(data: data, map: map)
    }

    private static func gameDisplayName(for id: GameID) -> String {
        switch id {
        case .quiz: return "Quiz"
        case .trivia: return "Trivia"
        case .hangman: return "Hangman"
        case .beatclock: return "Countdown"
        case .versematch: return "Verses"
        case .bookorder: return "Book Order"
        case .whoami: return "Who?"
        case .wordsearch: return "Word Search"
        case .scramble: return "Scramble"
        case .wordle: return "Word"
        }
    }

    // MARK: - Play time

    static let dailyPlaySecondsKey = "gamesDailyPlaySeconds"
    static let allTimePlaySecondsKey = "allTimeUsageGameSeconds"

    /// Adds time spent with a game screen open. Synced per device through the game ledger.
    func recordPlayTime(seconds: Int, endingAt end: Date = Date()) {
        guard seconds > 0 else { return }
        let start = end.addingTimeInterval(-TimeInterval(seconds))
        var daily: [String: Int] = loadJSONMap(forKey: Self.dailyPlaySecondsKey)
        for allocation in ReadingTimeTracker.dailyAllocations(seconds: seconds, from: start, to: end) {
            daily[Self.localDayKey(for: allocation.date), default: 0] += allocation.seconds
        }
        saveJSONMap(daily, forKey: Self.dailyPlaySecondsKey)

        let defaults = UserDefaults.standard
        defaults.set(max(0, defaults.integer(forKey: Self.allTimePlaySecondsKey)) + seconds, forKey: Self.allTimePlaySecondsKey)
        iCloudSyncCoordinator.shared.pushKey(Self.allTimePlaySecondsKey)
    }

    func playSeconds(on date: Date = Date()) -> Int {
        let daily: [String: Int] = loadJSONMap(forKey: Self.dailyPlaySecondsKey)
        return max(0, daily[Self.localDayKey(for: date)] ?? 0)
    }

    var allTimePlaySeconds: Int {
        max(0, UserDefaults.standard.integer(forKey: Self.allTimePlaySecondsKey))
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
            return Self.canonicalDisplayName(raw)
        }
               return nil
    }

    typealias DailyPoint = (date: Date, answered: Int, correct: Int)

    func dailySeriesLast(days: Int, now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> [(date: Date, answered: Int, correct: Int)] {
        dailySeries(days: days, answeredKey: "gamesDailyAnswered", correctKey: "gamesDailyCorrect", now: now, calendar: calendar)
    }

    func dailySeriesLast(days: Int, forDisplayName name: String, now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> [(date: Date, answered: Int, correct: Int)] {
        // "All Games" and names that match no game read the overall series.
        guard name != "All Games", let gameKey = Self.storageKey(forDisplayName: name) else {
            return dailySeriesLast(days: days, now: now, calendar: calendar)
        }
        return dailySeries(days: days, gameKey: gameKey, now: now, calendar: calendar)
    }

    func dailySeriesLast(days: Int, forWordMode mode: WordMode, now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> [(date: Date, answered: Int, correct: Int)] {
        dailySeries(days: days, gameKey: Self.storageKeyForWord(mode: mode), now: now, calendar: calendar)
    }

    private func dailySeries(days: Int, gameKey: String, now: Date, calendar: Calendar) -> [DailyPoint] {
        dailySeries(
            days: days,
            answeredKey: "gamesDailyAnswered_\(gameKey)",
            correctKey: "gamesDailyCorrect_\(gameKey)",
            now: now,
            calendar: calendar
        )
    }

    /// One point per day, oldest first, ending today.
    private func dailySeries(days: Int, answeredKey: String, correctKey: String, now: Date, calendar: Calendar) -> [DailyPoint] {
        var cal = calendar
        cal.timeZone = .autoupdatingCurrent
        let startOfToday = cal.startOfDay(for: now)

        let answeredMap = loadJSONMap(forKey: answeredKey)
        let correctMap = loadJSONMap(forKey: correctKey)

        var series: [DailyPoint] = []
        for i in stride(from: days - 1, through: 0, by: -1) {
            if let d = cal.date(byAdding: .day, value: -i, to: startOfToday) {
                let key = Self.localDayKey(for: d, calendar: cal)
                series.append((d, max(0, answeredMap[key] ?? 0), max(0, correctMap[key] ?? 0)))
            }
        }
        return series
    }

    /// The longest run of days with answers, and the run ending today. A today with no
    /// answers yet doesn't end the current run.
    private static func streaks(in series: [DailyPoint]) -> (current: Int, longest: Int) {
        var longest = 0
        var run = 0
        for point in series {
            if point.answered > 0 {
                run += 1
                longest = max(longest, run)
            } else {
                run = 0
            }
        }

        var current = 0
        var recent = series
        if recent.last?.answered == 0 { recent.removeLast() }
        for point in recent.reversed() {
            if point.answered > 0 { current += 1 } else { break }
        }
        return (current, longest)
    }

    /// Accuracy over the last 7 days, and how far it moved from the 7 days before.
    private static func accuracyTrend(in last14Days: [DailyPoint]) -> (currentPct: Double, deltaVsPrev: Double) {
        func pct(for slice: ArraySlice<DailyPoint>) -> Double {
            let a = slice.reduce(0) { $0 + max(0, $1.answered) }
            let c = slice.reduce(0) { $0 + max(0, $1.correct) }
            guard a > 0 else { return 0 }
            return min(100, max(0, (Double(c) / Double(a)) * 100.0))
        }

        let cur = pct(for: last14Days.suffix(7))
        let prev = pct(for: last14Days.prefix(max(0, last14Days.count - 7)))
        return (cur, cur - prev)
    }

    func activityStreaks(now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> (current: Int, longest: Int) {
        Self.streaks(in: dailySeriesLast(days: 1825, now: now, calendar: calendar))
    }

    func activityStreaks(forDisplayName name: String, now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> (current: Int, longest: Int) {
        Self.streaks(in: dailySeriesLast(days: 1825, forDisplayName: name, now: now, calendar: calendar))
    }

    func activityStreaks(forWordMode mode: WordMode, now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> (current: Int, longest: Int) {
        Self.streaks(in: dailySeriesLast(days: 1825, forWordMode: mode, now: now, calendar: calendar))
    }

    func accuracy7DayTrend(now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> (currentPct: Double, deltaVsPrev: Double) {
        Self.accuracyTrend(in: dailySeriesLast(days: 14, now: now, calendar: calendar))
    }

    func accuracy7DayTrend(forDisplayName name: String, now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> (currentPct: Double, deltaVsPrev: Double) {
        Self.accuracyTrend(in: dailySeriesLast(days: 14, forDisplayName: name, now: now, calendar: calendar))
    }

    func accuracy7DayTrend(forWordMode mode: WordMode, now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> (currentPct: Double, deltaVsPrev: Double) {
        Self.accuracyTrend(in: dailySeriesLast(days: 14, forWordMode: mode, now: now, calendar: calendar))
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

    // MARK: - Per-book analytics (Quiz, Trivia, Verse Match)
    //
    // The three games record the same four maps per book (see `PerBookKeys`), so one set of
    // helpers serves all of them.

    private func perBookMaps(_ keys: PerBookKeys) -> (answered: [String: Int], correct: [String: Int]) {
        (loadJSONMap(forKey: keys.answered), loadJSONMap(forKey: keys.correct))
    }

    private func perBookDailyMaps(_ keys: PerBookKeys) -> (answered: [String: [String: Int]], correct: [String: [String: Int]]) {
        (loadNestedJSONMap(forKey: keys.dailyAnswered), loadNestedJSONMap(forKey: keys.dailyCorrect))
    }

    private static func percentage(correct: Int, answered: Int) -> Double {
        guard answered > 0 else { return 0 }
        return min(100, max(0, (Double(correct) / Double(answered)) * 100))
    }

    /// Whether each Bible book is in the Old Testament (true) or New (false).
    private func testamentByBook() -> [String: Bool] {
        let books = BibleData.books
        guard let matthew = books.firstIndex(where: { $0.name == "Matthew" }) else { return [:] }
        return Dictionary(uniqueKeysWithValues: books.enumerated().map { ($1.name, $0 < matthew) })
    }

    private func perBookTestamentSummary(
        answeredMap: [String: Int],
        correctMap: [String: Int]
    ) -> (otAnswered: Int, otCorrect: Int, ntAnswered: Int, ntCorrect: Int, otPct: Double, ntPct: Double) {
        let isOldTestament = testamentByBook()
        var otA = 0, otC = 0, ntA = 0, ntC = 0
        for book in Set(answeredMap.keys).union(correctMap.keys) {
            let answered = max(0, answeredMap[book] ?? 0)
            let correct = max(0, correctMap[book] ?? 0)
            switch isOldTestament[book] {
            case true?: otA += answered; otC += correct
            case false?: ntA += answered; ntC += correct
            case nil: break
            }
        }
        return (otA, otC, ntA, ntC, Self.percentage(correct: otC, answered: otA), Self.percentage(correct: ntC, answered: ntA))
    }

    /// Accuracy for each genre, in canonical genre order. Verse Match counts every book it
    /// has recorded; the other games count only names found in the Bible.
    private func perBookGenreAccuracy(
        answeredMap: [String: Int],
        correctMap: [String: Int],
        requiresKnownBook: Bool
    ) -> [(genre: String, answered: Int, correct: Int, pct: Double)] {
        let knownBooks = Set(BibleData.books.map(\.name))
        var buckets: [StatsSeriesBuilder.Genre: (answered: Int, correct: Int)] = [:]
        for book in Set(answeredMap.keys).union(correctMap.keys) {
            let answered = max(0, answeredMap[book] ?? 0)
            guard answered > 0, !requiresKnownBook || knownBooks.contains(book) else { continue }
            let genre = StatsSeriesBuilder.genreForBook(book)
            var bucket = buckets[genre] ?? (0, 0)
            bucket.answered += answered
            bucket.correct += max(0, correctMap[book] ?? 0)
            buckets[genre] = bucket
        }
        let order: [StatsSeriesBuilder.Genre] = [.Law, .History, .Poetry, .MajorProphets, .MinorProphets, .Gospels, .Acts, .Epistles, .Apocalypse]
        return order.map { genre in
            let values = buckets[genre] ?? (0, 0)
            return (genre.rawValue, values.answered, values.correct, Self.percentage(correct: values.correct, answered: values.answered))
        }
    }

    /// Every book in a genre, in canonical order, with its all-time accuracy.
    private func perBookAccuracy(
        inGenre genreName: String,
        answeredMap: [String: Int],
        correctMap: [String: Int]
    ) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        BibleData.books.compactMap { book in
            guard StatsSeriesBuilder.genreForBook(book.name).rawValue == genreName else { return nil }
            let answered = max(0, answeredMap[book.name] ?? 0)
            let correct = max(0, correctMap[book.name] ?? 0)
            return (book.name, answered, correct, Self.percentage(correct: correct, answered: answered))
        }
    }

    /// Books ranked by accuracy over the last N days, ignoring books with too few attempts.
    private func rankedPerBookRows(
        dailyAnswered: [String: [String: Int]],
        dailyCorrect: [String: [String: Int]],
        lastNDays: Int,
        minAttempts: Int,
        strongestFirst: Bool
    ) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        let start = calendar.startOfDay(for: Date())
        var answered: [String: Int] = [:]
        var correct: [String: Int] = [:]
        for dayOffset in stride(from: lastNDays - 1, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: start) else { continue }
            let key = Self.localDayKey(for: date, calendar: calendar)
            dailyAnswered[key]?.forEach { answered[$0.key, default: 0] += max(0, $0.value) }
            dailyCorrect[key]?.forEach { correct[$0.key, default: 0] += max(0, $0.value) }
        }
        return Set(answered.keys).union(correct.keys).compactMap { book in
            let count = max(0, answered[book] ?? 0)
            guard count >= minAttempts else { return nil }
            let correctCount = max(0, correct[book] ?? 0)
            return (book, count, correctCount, Self.percentage(correct: correctCount, answered: count))
        }
        .sorted {
            if $0.pct == $1.pct { return $0.book < $1.book }
            return strongestFirst ? $0.pct > $1.pct : $0.pct < $1.pct
        }
    }

    // MARK: Trivia

    func triviaOTNTSummary() -> (otAnswered: Int, otCorrect: Int, ntAnswered: Int, ntCorrect: Int, otPct: Double, ntPct: Double) {
        let maps = perBookMaps(.trivia)
        return perBookTestamentSummary(answeredMap: maps.answered, correctMap: maps.correct)
    }

    func triviaAccuracyByGenre() -> [(genre: String, answered: Int, correct: Int, pct: Double)] {
        let maps = perBookMaps(.trivia)
        return perBookGenreAccuracy(answeredMap: maps.answered, correctMap: maps.correct, requiresKnownBook: true)
    }

    func triviaAccuracyByBook(inGenre genreName: String) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        let maps = perBookMaps(.trivia)
        return perBookAccuracy(inGenre: genreName, answeredMap: maps.answered, correctMap: maps.correct)
    }

    func triviaWeakBooks(lastNDays: Int, minAttempts: Int) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        let maps = perBookDailyMaps(.trivia)
        return rankedPerBookRows(dailyAnswered: maps.answered, dailyCorrect: maps.correct, lastNDays: lastNDays, minAttempts: minAttempts, strongestFirst: false)
    }

    func triviaStrongBooks(lastNDays: Int, minAttempts: Int) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        let maps = perBookDailyMaps(.trivia)
        return rankedPerBookRows(dailyAnswered: maps.answered, dailyCorrect: maps.correct, lastNDays: lastNDays, minAttempts: minAttempts, strongestFirst: true)
    }

    // MARK: Quiz

    func quizOTNTSummary() -> (otAnswered: Int, otCorrect: Int, ntAnswered: Int, ntCorrect: Int, otPct: Double, ntPct: Double) {
        let maps = perBookMaps(.quiz)
        return perBookTestamentSummary(answeredMap: maps.answered, correctMap: maps.correct)
    }

    func quizAccuracyByGenre() -> [(genre: String, answered: Int, correct: Int, pct: Double)] {
        let maps = perBookMaps(.quiz)
        return perBookGenreAccuracy(answeredMap: maps.answered, correctMap: maps.correct, requiresKnownBook: true)
    }

    func quizAccuracyByBook(inGenre genreName: String) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        let maps = perBookMaps(.quiz)
        return perBookAccuracy(inGenre: genreName, answeredMap: maps.answered, correctMap: maps.correct)
    }

    func quizWeakBooks(lastNDays: Int, minAttempts: Int) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        let maps = perBookDailyMaps(.quiz)
        return rankedPerBookRows(dailyAnswered: maps.answered, dailyCorrect: maps.correct, lastNDays: lastNDays, minAttempts: minAttempts, strongestFirst: false)
    }

    func quizStrongBooks(lastNDays: Int, minAttempts: Int) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        let maps = perBookDailyMaps(.quiz)
        return rankedPerBookRows(dailyAnswered: maps.answered, dailyCorrect: maps.correct, lastNDays: lastNDays, minAttempts: minAttempts, strongestFirst: true)
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

    /// Consecutive calendar days with a solved Daily WORD, ending today (or yesterday if
    /// today's Daily has not been played yet). A missed day or a loss ends the streak.
    /// - Parameter treatingTodayAsSolved: Counts today as solved before the result is recorded.
    func wordleDailyWinStreak(
        treatingTodayAsSolved: Bool = false,
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> Int {
        var cal = calendar
        cal.timeZone = .autoupdatingCurrent
        let solved: [String: Int] = loadJSONMap(forKey: "wordleDailySolvedDays")
        let todayKey = Self.localDayKey(for: now, calendar: cal)

        func isSolved(_ key: String) -> Bool {
            solved[key] == 1 || (treatingTodayAsSolved && key == todayKey)
        }

        var day = cal.startOfDay(for: now)
        if !isSolved(todayKey) {
            // A Daily loss today ends the streak immediately.
            if playedDailyWithoutWinning(on: todayKey) { return 0 }
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }

        var streak = 0
        while isSolved(Self.localDayKey(for: day, calendar: cal)) {
            streak += 1
            guard let previous = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    private func playedDailyWithoutWinning(on dayKey: String) -> Bool {
        struct DailyResult: Decodable { let won: Bool }
        guard let data = UserDefaults.standard.data(forKey: "wordleDailyResultMap"),
              let results = try? JSONDecoder().decode([String: DailyResult].self, from: data),
              let result = results[dayKey] else {
            return false
        }
        return !result.won
    }

    func recordHangmanCategory(category: String, answered addAnswered: Int, correct addCorrect: Int) {
        recordCategoryResult(
            answeredKey: "hangmanPerCategoryAnsweredMap", correctKey: "hangmanPerCategoryCorrectMap",
            category: category, answered: addAnswered, correct: addCorrect
        )
    }

    func hangmanAccuracyByCategory() -> [(category: String, answered: Int, correct: Int, pct: Double)] {
        let aMap = loadJSONMap(forKey: "hangmanPerCategoryAnsweredMap")
        let cMap = loadJSONMap(forKey: "hangmanPerCategoryCorrectMap")
        let order = ["People", "Places", "Books"]
        return order.map { cat in
            let a = max(0, aMap[cat] ?? 0)
            let c = max(0, cMap[cat] ?? 0)
            let pct = a > 0 ? min(100, max(0, (Double(c) / Double(a)) * 100.0)) : 0
            return (cat, a, c, pct)
        }
    }

    func recordBeatClockType(type: String, answered addAnswered: Int, correct addCorrect: Int) {
        recordCategoryResult(
            answeredKey: "beatclockPerTypeAnsweredMap", correctKey: "beatclockPerTypeCorrectMap",
            category: type, answered: addAnswered, correct: addCorrect
        )
    }

    /// Adds one round's result to a game's all-time answered and correct maps for a category.
    private func recordCategoryResult(answeredKey: String, correctKey: String, category: String, answered addAnswered: Int, correct addCorrect: Int) {
        let name = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, addAnswered != 0 || addCorrect != 0 else { return }
        addToBookMap(answeredKey, book: name, delta: addAnswered)
        addToBookMap(correctKey, book: name, delta: addCorrect)
        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

    func beatclockAccuracyByType() -> [(type: String, answered: Int, correct: Int, pct: Double)] {
        let aMap = loadJSONMap(forKey: "beatclockPerTypeAnsweredMap")
        let cMap = loadJSONMap(forKey: "beatclockPerTypeCorrectMap")
        let order = ["People", "Places"]
        return order.map { t in
            let a = max(0, aMap[t] ?? 0)
            let c = max(0, cMap[t] ?? 0)
            let pct = a > 0 ? min(100, max(0, (Double(c) / Double(a)) * 100.0)) : 0
            return (t, a, c, pct)
        }
    }

    // MARK: Verse Match

    func verseMatchOTNTSummary() -> (otAnswered: Int, otCorrect: Int, ntAnswered: Int, ntCorrect: Int, otPct: Double, ntPct: Double) {
        let maps = perBookMaps(.verseMatch)
        return perBookTestamentSummary(answeredMap: maps.answered, correctMap: maps.correct)
    }

    func verseMatchAccuracyByGenre() -> [(genre: String, answered: Int, correct: Int, pct: Double)] {
        let maps = perBookMaps(.verseMatch)
        return perBookGenreAccuracy(answeredMap: maps.answered, correctMap: maps.correct, requiresKnownBook: false)
    }

    func verseMatchAccuracyByBook(inGenre genreName: String) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        let maps = perBookMaps(.verseMatch)
        return perBookAccuracy(inGenre: genreName, answeredMap: maps.answered, correctMap: maps.correct)
    }

    func verseMatchWeakBooks(lastNDays: Int, minAttempts: Int) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        let maps = perBookDailyMaps(.verseMatch)
        return rankedPerBookRows(dailyAnswered: maps.answered, dailyCorrect: maps.correct, lastNDays: lastNDays, minAttempts: minAttempts, strongestFirst: false)
    }

    func verseMatchStrongBooks(lastNDays: Int, minAttempts: Int) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        let maps = perBookDailyMaps(.verseMatch)
        return rankedPerBookRows(dailyAnswered: maps.answered, dailyCorrect: maps.correct, lastNDays: lastNDays, minAttempts: minAttempts, strongestFirst: true)
    }

    /// Combined book mastery from the two games that record canonical Bible-book results.
    func bookMastery(minAttempts: Int = 5) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        let quizMaps = perBookMaps(.quiz)
        let verseMaps = perBookMaps(.verseMatch)
        return BibleData.books.compactMap { book in
            let name = book.name
            let answered = max(0, quizMaps.answered[name] ?? 0) + max(0, verseMaps.answered[name] ?? 0)
            guard answered >= minAttempts else { return nil }
            let correct = max(0, quizMaps.correct[name] ?? 0) + max(0, verseMaps.correct[name] ?? 0)
            return (name, answered, correct, min(100, max(0, Double(correct) / Double(answered) * 100)))
        }
        .sorted { lhs, rhs in
            if lhs.pct == rhs.pct { return lhs.book < rhs.book }
            return lhs.pct > rhs.pct
        }
    }

    func accuracyByDifficulty() -> [(difficulty: String, answered: Int, correct: Int, pct: Double)] {
        [
            (key: "easy", title: String(localized: "Learn")),
            (key: "normal", title: String(localized: "Standard")),
            (key: "hard", title: String(localized: "Challenge"))
        ].map { difficulty in
            let prefixes = ["quiz", "hangman", "versematch", "beatclock", "bookorder", "whoami"]
            let answered = prefixes.reduce(0) { $0 + max(0, readInt("\($1)AllTimeAnswered_\(difficulty.key)")) }
            let correct = prefixes.reduce(0) { $0 + max(0, readInt("\($1)AllTimeCorrect_\(difficulty.key)")) }
            let pct = answered > 0 ? Double(correct) / Double(answered) * 100 : 0
            return (difficulty.title, answered, correct, pct)
        }
    }
}
