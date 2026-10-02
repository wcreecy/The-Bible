#if DEBUG
import Foundation

@MainActor
enum DeveloperSampleData {
    static func generate() {
        generateReadingStats()
        generateGameStats()
        generateAppUsageSplit()

        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

    private static func generateReadingStats() {
        let store = BibleStatsStore.shared
        let calendar = Calendar.autoupdatingCurrent
        let books = BibleData.books
        guard !books.isEmpty else { return }

        var contributions = store.loadReadingContributions()

        for dayOffset in 0..<90 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else {
                continue
            }

            // Leave occasional gaps so streak and activity charts look believable.
            if Int.random(in: 0..<10) < 2 {
                continue
            }

            let dayKey = BibleStatsStore.isoDateString(date, calendar: calendar)
            let sessionCount = Int.random(in: 1...3)

            for _ in 0..<sessionCount {
                guard let book = books.randomElement() else { continue }
                let seconds = Int.random(in: 4...32) * 60
                contributions[dayKey, default: [:]][book.name, default: [:]][
                    "developer-sample",
                    default: 0
                ] += seconds
            }
        }

        store.cacheReadingContributions = contributions
        store.saveJSON(contributions, key: BibleStatsStore.Defaults.keyReadingContributions)

        if let book = books.randomElement(), let chapter = book.chapters.randomElement() {
            store.saveLastRead(
                bookName: book.name,
                chapterNumber: chapter.number,
                date: Date().addingTimeInterval(-Double.random(in: 300...7_200))
            )
        }
    }

    private static func generateGameStats() {
        let defaults = UserDefaults.standard
        let calendar = Calendar.autoupdatingCurrent
        let games: [(dailyKey: String, storagePrefix: String)] = [
            ("quiz", "quiz"),
            ("hangman", "hangman"),
            ("beatclock", "beatclock"),
            ("versematch", "versematch"),
            ("bookorder", "bookorder"),
            ("whoami", "whoami"),
            ("word", "wordle")
        ]

        var totalAnsweredByDay = loadMap("gamesDailyAnswered")
        var totalCorrectByDay = loadMap("gamesDailyCorrect")
        var perGameAnswered = Dictionary(
            uniqueKeysWithValues: games.map { ($0.dailyKey, loadMap("gamesDailyAnswered_\($0.dailyKey)")) }
        )
        var perGameCorrect = Dictionary(
            uniqueKeysWithValues: games.map { ($0.dailyKey, loadMap("gamesDailyCorrect_\($0.dailyKey)")) }
        )
        var allTimeByPrefix: [String: (answered: Int, correct: Int, bestStreak: Int)] = [:]

        for dayOffset in 0..<90 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else {
                continue
            }

            if Int.random(in: 0..<10) < 3 {
                continue
            }

            let dayKey = GameStats.localDayKey(for: date, calendar: calendar)
            let gamesPlayed = games.shuffled().prefix(Int.random(in: 1...3))

            for game in gamesPlayed {
                let answered = Int.random(in: 4...24)
                let accuracy = Double.random(in: 0.52...0.96)
                let correct = min(answered, max(0, Int((Double(answered) * accuracy).rounded())))

                totalAnsweredByDay[dayKey, default: 0] += answered
                totalCorrectByDay[dayKey, default: 0] += correct
                perGameAnswered[game.dailyKey, default: [:]][dayKey, default: 0] += answered
                perGameCorrect[game.dailyKey, default: [:]][dayKey, default: 0] += correct

                let previous = allTimeByPrefix[game.storagePrefix] ?? (0, 0, 0)
                allTimeByPrefix[game.storagePrefix] = (
                    previous.answered + answered,
                    previous.correct + correct,
                    max(previous.bestStreak, Int.random(in: 2...18))
                )
            }
        }

        saveMap(totalAnsweredByDay, key: "gamesDailyAnswered")
        saveMap(totalCorrectByDay, key: "gamesDailyCorrect")

        for game in games {
            saveMap(perGameAnswered[game.dailyKey] ?? [:], key: "gamesDailyAnswered_\(game.dailyKey)")
            saveMap(perGameCorrect[game.dailyKey] ?? [:], key: "gamesDailyCorrect_\(game.dailyKey)")

            guard let totals = allTimeByPrefix[game.storagePrefix] else { continue }
            defaults.set(
                defaults.integer(forKey: "\(game.storagePrefix)AllTimeAnswered_all") + totals.answered,
                forKey: "\(game.storagePrefix)AllTimeAnswered_all"
            )
            defaults.set(
                defaults.integer(forKey: "\(game.storagePrefix)AllTimeCorrect_all") + totals.correct,
                forKey: "\(game.storagePrefix)AllTimeCorrect_all"
            )
            defaults.set(
                max(
                    defaults.integer(forKey: "\(game.storagePrefix)AllTimeBestStreak_all"),
                    totals.bestStreak
                ),
                forKey: "\(game.storagePrefix)AllTimeBestStreak_all"
            )
        }

        let lastGame = games.randomElement()?.dailyKey ?? "quiz"
        let displayNames = [
            "quiz": "Bible Quiz",
            "hangman": "Hangman",
            "beatclock": "Beat the Clock",
            "versematch": "Verse Match",
            "bookorder": "Book Order",
            "whoami": "Who am I?",
            "word": "WORD"
        ]
        defaults.set(displayNames[lastGame], forKey: "gamesLastPlayedGameName")
        defaults.set(
            Date().addingTimeInterval(-Double.random(in: 300...10_800)).timeIntervalSince1970,
            forKey: "gamesLastPlayedAt"
        )
    }

    private static func generateAppUsageSplit() {
        let defaults = UserDefaults.standard
        let readingSeconds = Int.random(in: 35...150) * 60
        let gameSeconds = Int.random(in: 15...90) * 60

        defaults.set(readingSeconds, forKey: "dailyUsageReadingSeconds")
        defaults.set(gameSeconds, forKey: "dailyUsageGameSeconds")
        defaults.set(readingSeconds + gameSeconds, forKey: "dailyUsageTodaySeconds")
        defaults.set(BibleStatsStore.isoDateString(Date()), forKey: "dailyUsageTodayKey")
    }

    private static func loadMap(_ key: String) -> [String: Int] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let map = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return map
    }

    private static func saveMap(_ map: [String: Int], key: String) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
#endif
