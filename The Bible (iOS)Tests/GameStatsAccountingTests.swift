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
            (.versematch, "versematch", "Verse Match"),
            (.bookorder, "bookorder", "Book Order"),
            (.whoami, "whoami", "Who Am I?"),
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

    @Test
    func previousGameNamesStillResolveToTheRenamedGames() {
        #expect(GameStats.canonicalDisplayName("Verses") == "Verse Match")
        #expect(GameStats.canonicalDisplayName("Who?") == "Who Am I?")
        #expect(GameStats.canonicalDisplayName("WORD") == "Word")
        #expect(GameStats.canonicalDisplayName("Wordle (Bible)") == "Word")
        #expect(GameStats.canonicalDisplayName("Quiz") == "Quiz")

        // A saved Today Challenge or a not-yet-updated device may still say "Who?".
        let key = "gamesLastPlayedGameName"
        let saved = defaults.object(forKey: key)
        defer { saved == nil ? defaults.removeObject(forKey: key) : defaults.set(saved, forKey: key) }
        defaults.set("Who?", forKey: key)
        #expect(GameStats.shared.lastPlayedGameName == "Who Am I?")
        #expect(GameStats.shared.dailySeriesLast(days: 3, forDisplayName: "Who?").count == 3)
        #expect(GameStats.shared.dailySeriesLast(days: 3, forDisplayName: "Who Am I?").count == 3)
    }

    /// Seeds known daily answers and checks the series, streaks and 7-day trend for the
    /// all-games, per-game and per-WORD-mode scopes. Expected values are worked out by hand.
    @Test
    func dailySeriesStreaksAndTrendFollowTheSelectedScope() throws {
        let overallKeys = ["gamesDailyAnswered", "gamesDailyCorrect"]
        let quizKeys = ["gamesDailyAnswered_quiz", "gamesDailyCorrect_quiz"]
        let wordKeys = ["gamesDailyAnswered_word_normal", "gamesDailyCorrect_word_normal"]
        let keys = overallKeys + quizKeys + wordKeys
        let savedValues = savedValues(for: keys)
        clear(keys)
        defer { restore(savedValues, for: keys) }

        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        let today = calendar.startOfDay(for: now)
        func dayKey(_ daysAgo: Int) -> String {
            GameStats.localDayKey(for: calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today)
        }
        func seed(_ answeredKey: String, _ correctKey: String, _ days: [Int: (answered: Int, correct: Int)]) throws {
            var answered: [String: Int] = [:]
            var correct: [String: Int] = [:]
            for (daysAgo, value) in days {
                answered[dayKey(daysAgo)] = value.answered
                correct[dayKey(daysAgo)] = value.correct
            }
            defaults.set(try JSONEncoder().encode(answered), forKey: answeredKey)
            defaults.set(try JSONEncoder().encode(correct), forKey: correctKey)
        }

        // All games: busy today, a gap yesterday, a four-day run before that.
        try seed("gamesDailyAnswered", "gamesDailyCorrect", [
            0: (10, 5), 2: (8, 4), 3: (6, 6), 4: (4, 1), 5: (2, 2), 7: (5, 5), 9: (4, 2)
        ])
        // Quiz: nothing today, the two days before it played.
        try seed("gamesDailyAnswered_quiz", "gamesDailyCorrect_quiz", [1: (3, 3), 2: (3, 1)])
        // WORD (normal): today only.
        try seed("gamesDailyAnswered_word_normal", "gamesDailyCorrect_word_normal", [0: (2, 1)])

        // Series
        let overall = GameStats.shared.dailySeriesLast(days: 14, now: now)
        #expect(overall.count == 14)
        #expect(overall.last?.answered == 10)
        #expect(overall[overall.count - 3].answered == 8) // two days ago
        #expect(overall.first?.answered == 0)
        #expect(GameStats.shared.dailySeriesLast(days: 3, forDisplayName: "Quiz", now: now).map(\.answered) == [3, 3, 0])
        #expect(GameStats.shared.dailySeriesLast(days: 2, forWordMode: .normal, now: now).map(\.correct) == [0, 1])
        // Unknown names and "All Games" read the overall series.
        #expect(GameStats.shared.dailySeriesLast(days: 1, forDisplayName: "All Games", now: now).first?.answered == 10)
        #expect(GameStats.shared.dailySeriesLast(days: 1, forDisplayName: "Nope", now: now).first?.answered == 10)

        // Streaks: today counts when played, and an unplayed today doesn't break the run.
        let allStreaks = GameStats.shared.activityStreaks(now: now)
        #expect(allStreaks.current == 1)
        #expect(allStreaks.longest == 4)
        let quizStreaks = GameStats.shared.activityStreaks(forDisplayName: "Quiz", now: now)
        #expect(quizStreaks.current == 2)
        #expect(quizStreaks.longest == 2)
        let wordStreaks = GameStats.shared.activityStreaks(forWordMode: .normal, now: now)
        #expect(wordStreaks.current == 1)
        #expect(wordStreaks.longest == 1)
        #expect(GameStats.shared.activityStreaks(forDisplayName: "All Games", now: now).longest == 4)

        // 7-day accuracy against the 7 days before it.
        let allTrend = GameStats.shared.accuracy7DayTrend(now: now)
        #expect(abs(allTrend.currentPct - 60) < 0.001)               // 18 of 30
        #expect(abs(allTrend.deltaVsPrev - (60 - 700.0 / 9)) < 0.001) // prior week: 7 of 9
        let quizTrend = GameStats.shared.accuracy7DayTrend(forDisplayName: "Quiz", now: now)
        #expect(abs(quizTrend.currentPct - 400.0 / 6) < 0.001)       // 4 of 6
        #expect(abs(quizTrend.deltaVsPrev - 400.0 / 6) < 0.001)      // nothing the week before
        let wordTrend = GameStats.shared.accuracy7DayTrend(forWordMode: .normal, now: now)
        #expect(abs(wordTrend.currentPct - 50) < 0.001)
        #expect(abs(GameStats.shared.accuracy7DayTrend(forDisplayName: "All Games", now: now).currentPct - 60) < 0.001)
    }

    /// Quiz, Trivia and Verse Match keep the same per-book maps, so identical data must give
    /// identical analytics for all three, and the values below are worked out by hand.
    @Test
    func perBookAnalyticsAgreeAcrossQuizTriviaAndVerseMatch() async throws {
        _ = await BibleRepository.shared.loadAllBooks()

        let prefixes = ["quiz", "trivia", "versematch"]
        let keys = prefixes.flatMap { p in
            ["\(p)PerBookAnsweredMap", "\(p)PerBookCorrectMap", "\(p)PerBookDailyAnswered", "\(p)PerBookDailyCorrect"]
        }
        let savedValues = savedValues(for: keys)
        clear(keys)
        defer { restore(savedValues, for: keys) }

        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: Date())
        func dayKey(_ daysAgo: Int) -> String {
            GameStats.localDayKey(for: calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today)
        }
        let allTimeAnswered = ["John": 10, "Genesis": 4, "Matthew": 6, "Psalms": 5]
        let allTimeCorrect = ["John": 8, "Genesis": 1, "Matthew": 6, "Psalms": 2]
        let dailyAnswered = [
            dayKey(0): ["John": 4, "Genesis": 3],
            dayKey(1): ["John": 2, "Psalms": 5],
            dayKey(5): ["Matthew": 9]
        ]
        let dailyCorrect = [
            dayKey(0): ["John": 4, "Genesis": 1],
            dayKey(1): ["John": 1, "Psalms": 2],
            dayKey(5): ["Matthew": 9]
        ]
        let encoder = JSONEncoder()
        for p in prefixes {
            defaults.set(try encoder.encode(allTimeAnswered), forKey: "\(p)PerBookAnsweredMap")
            defaults.set(try encoder.encode(allTimeCorrect), forKey: "\(p)PerBookCorrectMap")
            defaults.set(try encoder.encode(dailyAnswered), forKey: "\(p)PerBookDailyAnswered")
            defaults.set(try encoder.encode(dailyCorrect), forKey: "\(p)PerBookDailyCorrect")
        }

        let stats = GameStats.shared
        let testaments = [stats.quizOTNTSummary(), stats.triviaOTNTSummary(), stats.verseMatchOTNTSummary()]
        for t in testaments {
            #expect(t.otAnswered == 9 && t.otCorrect == 3)
            #expect(t.ntAnswered == 16 && t.ntCorrect == 14)
            #expect(abs(t.otPct - 100.0 / 3) < 0.001)
            #expect(abs(t.ntPct - 87.5) < 0.001)
        }

        let genreSets = [stats.quizAccuracyByGenre(), stats.triviaAccuracyByGenre(), stats.verseMatchAccuracyByGenre()]
        for genres in genreSets {
            #expect(genres.map(\.genre) == StatsSeriesBuilder.Genre.allCases.map(\.rawValue))
            let byName = Dictionary(uniqueKeysWithValues: genres.map { ($0.genre, $0) })
            #expect(byName["Law"]?.answered == 4 && byName["Law"]?.correct == 1)
            #expect(byName["Poetry"]?.answered == 5 && byName["Poetry"]?.correct == 2)
            #expect(byName["Gospels"]?.answered == 16 && byName["Gospels"]?.correct == 14)
            #expect(byName["History"]?.answered == 0 && byName["History"]?.pct == 0)
        }

        let weak = [stats.quizWeakBooks(lastNDays: 3, minAttempts: 3), stats.triviaWeakBooks(lastNDays: 3, minAttempts: 3), stats.verseMatchWeakBooks(lastNDays: 3, minAttempts: 3)]
        for rows in weak {
            #expect(rows.map(\.book) == ["Genesis", "Psalms", "John"])
            #expect(rows.map(\.answered) == [3, 5, 6])
            #expect(rows.map(\.correct) == [1, 2, 5])
        }
        let strong = [stats.quizStrongBooks(lastNDays: 3, minAttempts: 5), stats.triviaStrongBooks(lastNDays: 3, minAttempts: 5), stats.verseMatchStrongBooks(lastNDays: 3, minAttempts: 5)]
        for rows in strong {
            #expect(rows.map(\.book) == ["John", "Psalms"]) // Matthew's 9 answers are outside 3 days
        }

        let gospels = StatsSeriesBuilder.Genre.Gospels.rawValue
        let byBook = [stats.quizAccuracyByBook(inGenre: gospels), stats.triviaAccuracyByBook(inGenre: gospels), stats.verseMatchAccuracyByBook(inGenre: gospels)]
        for rows in byBook {
            #expect(rows.map(\.book) == ["Matthew", "Mark", "Luke", "John"]) // canonical order
            #expect(rows.map(\.answered) == [6, 0, 0, 10])
            #expect(abs(rows[3].pct - 80) < 0.001)
        }
    }

    @Test
    func perBookAndCategoryRecordersAddToAllTimeAndDailyMaps() {
        let prefixes = ["quiz", "trivia", "versematch"]
        let keys = prefixes.flatMap { p in
            ["\(p)PerBookAnsweredMap", "\(p)PerBookCorrectMap", "\(p)PerBookDailyAnswered", "\(p)PerBookDailyCorrect"]
        } + [
            "hangmanPerCategoryAnsweredMap", "hangmanPerCategoryCorrectMap",
            "beatclockPerTypeAnsweredMap", "beatclockPerTypeCorrectMap"
        ]
        let savedValues = savedValues(for: keys)
        clear(keys)
        defer { restore(savedValues, for: keys) }
        let dayKey = GameStats.localDayKey(for: Date())
        let stats = GameStats.shared

        stats.recordQuizPerBook(bookName: " John ", answered: 3, correct: 2)
        stats.recordQuizPerBook(bookName: "John", answered: 2, correct: 0)
        stats.recordTriviaPerBook(bookName: "Genesis", answered: 4, correct: 4)
        stats.recordVerseMatchPerBook(bookName: "Psalms", answered: 1, correct: 1)
        // Empty names and empty results are ignored; negative amounts never subtract
        // (they leave a zero entry, as before).
        stats.recordQuizPerBook(bookName: "  ", answered: 5, correct: 5)
        stats.recordQuizPerBook(bookName: "Acts", answered: 0, correct: 0)
        stats.recordQuizPerBook(bookName: "Acts", answered: -4, correct: 1)

        #expect(map(named: "quizPerBookAnsweredMap") == ["John": 5, "Acts": 0])
        #expect(map(named: "quizPerBookCorrectMap") == ["John": 2, "Acts": 1])
        #expect(nestedMap(named: "quizPerBookDailyAnswered")[dayKey] == ["John": 5, "Acts": 0])
        #expect(nestedMap(named: "quizPerBookDailyCorrect")[dayKey] == ["John": 2, "Acts": 1])
        #expect(map(named: "triviaPerBookAnsweredMap") == ["Genesis": 4])
        #expect(nestedMap(named: "triviaPerBookDailyCorrect")[dayKey] == ["Genesis": 4])
        #expect(map(named: "versematchPerBookCorrectMap") == ["Psalms": 1])
        #expect(nestedMap(named: "versematchPerBookDailyAnswered")[dayKey] == ["Psalms": 1])

        stats.recordHangmanCategory(category: "People", answered: 2, correct: 1)
        stats.recordBeatClockType(type: "Places", answered: 3, correct: 3)
        let hangman = stats.hangmanAccuracyByCategory()
        #expect(hangman.map(\.category) == ["People", "Places", "Books"])
        #expect(hangman.first?.answered == 2 && hangman.first?.correct == 1)
        #expect(abs((hangman.first?.pct ?? 0) - 50) < 0.001)
        let beatClock = stats.beatclockAccuracyByType()
        #expect(beatClock.last?.answered == 3 && beatClock.last?.pct == 100)
    }

    private func nestedMap(named key: String) -> [String: [String: Int]] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: [String: Int]].self, from: data) else { return [:] }
        return decoded
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
