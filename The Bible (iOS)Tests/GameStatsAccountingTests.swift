import Foundation
import Testing
@testable import Bible

@MainActor
struct GameStatsAccountingTests {
    private let defaults = UserDefaults.standard

    @Test
    func everyStandardGameRoundUpdatesLifetimeAndDailyTotalsExactlyOnce() {
        let cases: [(game: GameStats.GameID, storageKey: String, displayName: String)] = [
            (.quiz, "quiz", "Quiz"),
            (.trivia, "trivia", "Trivia"),
            (.hangman, "hangman", "Hangman"),
            (.beatclock, "beatclock", "Countdown"),
            (.versematch, "versematch", "Verses"),
            (.bookorder, "bookorder", "Book Order"),
            (.whoami, "whoami", "Who?"),
            (.wordsearch, "wordsearch", "Word Search"),
            (.scramble, "scramble", "Scramble")
        ]
        let dayKey = GameStats.localDayKey(for: Date())

        for testCase in cases {
            let prefix = testCase.storageKey
            let keys = [
                "\(prefix)AllTimeCorrect_normal",
                "\(prefix)AllTimeAnswered_normal",
                "\(prefix)AllTimeBestStreak_normal",
                "\(prefix)AllTimeCorrect_all",
                "\(prefix)AllTimeAnswered_all",
                "\(prefix)AllTimeBestStreak_all",
                "gamesDailyAnswered",
                "gamesDailyCorrect",
                "gamesDailyAnswered_\(prefix)",
                "gamesDailyCorrect_\(prefix)",
                "gamesLastPlayedAt",
                "gamesLastPlayedGameName"
            ]
            let savedValues = savedValues(for: keys)
            clear(keys)
            defer { restore(savedValues, for: keys) }

            GameStats.shared.recordRound(
                game: testCase.game,
                difficulty: .normal,
                correct: 2,
                answered: 3,
                currentBestStreak: 4
            )

            #expect(defaults.integer(forKey: "\(prefix)AllTimeCorrect_normal") == 2)
            #expect(defaults.integer(forKey: "\(prefix)AllTimeAnswered_normal") == 3)
            #expect(defaults.integer(forKey: "\(prefix)AllTimeBestStreak_normal") == 4)
            #expect(defaults.integer(forKey: "\(prefix)AllTimeCorrect_all") == 2)
            #expect(defaults.integer(forKey: "\(prefix)AllTimeAnswered_all") == 3)
            #expect(defaults.integer(forKey: "\(prefix)AllTimeBestStreak_all") == 4)
            #expect(map(named: "gamesDailyAnswered")[dayKey] == 3)
            #expect(map(named: "gamesDailyCorrect")[dayKey] == 2)
            #expect(map(named: "gamesDailyAnswered_\(prefix)")[dayKey] == 3)
            #expect(map(named: "gamesDailyCorrect_\(prefix)")[dayKey] == 2)
            #expect(defaults.string(forKey: "gamesLastPlayedGameName") == testCase.displayName)
        }
    }

    @Test
    func wordleResultUpdatesTypeModeAndDailyTotalsExactlyOnce() {
        let dayKey = GameStats.localDayKey(for: Date())
        let keys = [
            "wordleAllTimeCorrect_daily",
            "wordleAllTimeAnswered_daily",
            "wordleAllTimeBestStreak_daily",
            "wordleAllTimeCorrect_normal",
            "wordleAllTimeAnswered_normal",
            "wordleAllTimeBestStreak_normal",
            "wordleWinsGuessSum_daily",
            "wordleWinsOnGuess3_daily",
            "wordleWinsGuessSum_normal",
            "wordleWinsOnGuess3_normal",
            "wordleDailySolvedDays",
            "gamesDailyAnswered",
            "gamesDailyCorrect",
            "gamesDailyAnswered_word",
            "gamesDailyCorrect_word",
            "gamesDailyAnswered_word_normal",
            "gamesDailyCorrect_word_normal"
        ]
        let savedValues = savedValues(for: keys)
        clear(keys)
        defer { restore(savedValues, for: keys) }

        GameStats.shared.recordWordleResult(
            type: .daily,
            mode: .normal,
            won: true,
            guesses: 3,
            currentBestStreak: 5
        )

        #expect(defaults.integer(forKey: "wordleAllTimeCorrect_daily") == 1)
        #expect(defaults.integer(forKey: "wordleAllTimeAnswered_daily") == 1)
        #expect(defaults.integer(forKey: "wordleAllTimeBestStreak_daily") == 5)
        #expect(defaults.integer(forKey: "wordleAllTimeCorrect_normal") == 1)
        #expect(defaults.integer(forKey: "wordleAllTimeAnswered_normal") == 1)
        #expect(defaults.integer(forKey: "wordleAllTimeBestStreak_normal") == 5)
        #expect(defaults.integer(forKey: "wordleWinsGuessSum_daily") == 3)
        #expect(defaults.integer(forKey: "wordleWinsOnGuess3_daily") == 1)
        #expect(map(named: "wordleDailySolvedDays")[dayKey] == 1)
        #expect(map(named: "gamesDailyAnswered")[dayKey] == 1)
        #expect(map(named: "gamesDailyCorrect")[dayKey] == 1)
        #expect(map(named: "gamesDailyAnswered_word")[dayKey] == 1)
        #expect(map(named: "gamesDailyCorrect_word")[dayKey] == 1)
        #expect(map(named: "gamesDailyAnswered_word_normal")[dayKey] == 1)
        #expect(map(named: "gamesDailyCorrect_word_normal")[dayKey] == 1)
    }

    @Test
    func corruptDailyStatsPayloadIsReplacedWhenAValidRoundCompletes() {
        let dayKey = GameStats.localDayKey(for: Date())
        let keys = [
            "quizAllTimeCorrect_normal",
            "quizAllTimeAnswered_normal",
            "quizAllTimeCorrect_all",
            "quizAllTimeAnswered_all",
            "gamesDailyAnswered",
            "gamesDailyCorrect",
            "gamesDailyAnswered_quiz",
            "gamesDailyCorrect_quiz"
        ]
        let savedValues = savedValues(for: keys)
        clear(keys)
        defer { restore(savedValues, for: keys) }

        defaults.set(Data([0xFF, 0x00, 0x01]), forKey: "gamesDailyAnswered")
        defaults.set(Data([0xFF, 0x00, 0x01]), forKey: "gamesDailyCorrect")
        defaults.set(Data([0xFF, 0x00, 0x01]), forKey: "gamesDailyAnswered_quiz")
        defaults.set(Data([0xFF, 0x00, 0x01]), forKey: "gamesDailyCorrect_quiz")

        GameStats.shared.recordRound(
            game: .quiz,
            difficulty: .normal,
            correct: 1,
            answered: 1,
            currentBestStreak: 1
        )

        #expect(map(named: "gamesDailyAnswered")[dayKey] == 1)
        #expect(map(named: "gamesDailyCorrect")[dayKey] == 1)
        #expect(map(named: "gamesDailyAnswered_quiz")[dayKey] == 1)
        #expect(map(named: "gamesDailyCorrect_quiz")[dayKey] == 1)
    }

    @Test
    func scrambleCountersAndDailyMapsUseTheSharedDeviceLedger() {
        let keys = Set(iCloudSyncCoordinator.scrambleKeys)

        #expect(GameStatsLedger.counterKeys.isSuperset(of: keys))
        #expect(iCloudSyncCoordinator.perGameDailyMapKeys.contains("gamesDailyAnswered_scramble"))
        #expect(iCloudSyncCoordinator.perGameDailyMapKeys.contains("gamesDailyCorrect_scramble"))
    }

    @Test
    func overallSnapshotCountsTriviaAndMatchesTheBreakdown() {
        let keys = [
            "triviaAllTimeCorrect_normal",
            "triviaAllTimeAnswered_normal",
            "triviaAllTimeBestStreak_normal",
            "triviaAllTimeCorrect_all",
            "triviaAllTimeAnswered_all",
            "triviaAllTimeBestStreak_all",
            "gamesDailyAnswered",
            "gamesDailyCorrect",
            "gamesDailyAnswered_trivia",
            "gamesDailyCorrect_trivia",
            "gamesLastPlayedAt",
            "gamesLastPlayedGameName"
        ]
        let savedValues = savedValues(for: keys)
        clear(keys)
        defer { restore(savedValues, for: keys) }

        GameStats.shared.recordRound(
            game: .trivia,
            difficulty: .normal,
            correct: 2,
            answered: 3,
            currentBestStreak: 2
        )

        let snapshot = GameStats.shared.snapshot()
        let breakdown = GameStats.shared.breakdownSnapshot()
        #expect(snapshot.totalAnswered >= 3)
        #expect(snapshot.totalAnswered == breakdown.totalAnswered)
        #expect(snapshot.totalCorrect == breakdown.totalCorrect)
    }

    @Test
    func cachedDailyMapsFollowWritesMadeOutsideGameStats() throws {
        let dayKey = GameStats.localDayKey(for: Date())
        let keys = ["gamesDailyAnswered", "gamesDailyCorrect"]
        let savedValues = savedValues(for: keys)
        clear(keys)
        defer { restore(savedValues, for: keys) }

        func write(answered: Int, correct: Int) throws {
            defaults.set(try JSONEncoder().encode([dayKey: answered]), forKey: "gamesDailyAnswered")
            defaults.set(try JSONEncoder().encode([dayKey: correct]), forKey: "gamesDailyCorrect")
        }

        try write(answered: 5, correct: 3)
        #expect(GameStats.shared.todayStats().answered == 5)
        #expect(GameStats.shared.todayStats().answered == 5) // Served from the cache.

        // An iCloud merge or ledger reconcile rewrites the key directly.
        try write(answered: 9, correct: 4)
        #expect(GameStats.shared.todayStats().answered == 9)
        #expect(GameStats.shared.todayStats().correct == 4)

        // A reset removes the key, and corrupt data reads as empty.
        clear(keys)
        #expect(GameStats.shared.todayStats().answered == 0)
        defaults.set(Data([0xFF, 0x00]), forKey: "gamesDailyAnswered")
        #expect(GameStats.shared.todayStats().answered == 0)
    }

    private func map(named key: String) -> [String: Int] {
        guard let data = defaults.data(forKey: key) else { return [:] }
        return (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
    }

    private func savedValues(for keys: [String]) -> [String: Any] {
        Dictionary(uniqueKeysWithValues: keys.compactMap { key in
            defaults.object(forKey: key).map { (key, $0) }
        })
    }

    private func clear(_ keys: [String]) {
        keys.forEach(defaults.removeObject(forKey:))
    }

    private func restore(_ savedValues: [String: Any], for keys: [String]) {
        for key in keys {
            if let value = savedValues[key] {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }
}
