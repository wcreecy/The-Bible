#if DEBUG
import Foundation
import SwiftData

@MainActor
enum DeveloperSampleData {
    static func generate(in context: ModelContext) async {
        let books = await BibleRepository.shared.loadAllBooks()
        generateReadingStats(books: books)
        generateGameStats()
        generateAppUsageSplit()

        do {
            try generateStudyData(books: books, in: context)
        } catch {
            print("Unable to save developer study samples: \(error.localizedDescription)")
        }

        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

    /// Seeds enough saved verses and notes for the study-focused screens to have useful content.
    private static func generateStudyData(books: [Book], in context: ModelContext) throws {
        let favoriteTargets = [
            ("Genesis", 1, 1),
            ("Joshua", 1, 9),
            ("Psalms", 23, 1),
            ("Psalms", 46, 1),
            ("Proverbs", 3, 5),
            ("Isaiah", 41, 10),
            ("Matthew", 5, 16),
            ("John", 3, 16),
            ("Romans", 8, 28),
            ("Philippians", 4, 13)
        ]
        let existingFavorites = try context.fetch(FetchDescriptor<Favorite>())
        var favoriteLocations = Set(existingFavorites.map {
            "\($0.bookName)|\($0.chapterNumber)|\($0.verseNumber)"
        })

        for target in favoriteTargets where favoriteLocations.count < 10 {
            guard let verse = books.first(where: { $0.name == target.0 })?
                .chapters.first(where: { $0.number == target.1 })?
                .verses.first(where: { $0.number == target.2 }) else {
                continue
            }

            let location = "\(target.0)|\(target.1)|\(target.2)"
            guard favoriteLocations.insert(location).inserted else { continue }
            context.insert(Favorite(
                bookName: target.0,
                chapterNumber: target.1,
                verseNumber: target.2,
                verseText: verse.text
            ))
        }

        let existingVerseNoteTitles = Set(try context.fetch(FetchDescriptor<VerseNote>()).map(\.title))
        if !existingVerseNoteTitles.contains("Living with courage") {
            let note = VerseNote(
                bookName: "Joshua",
                chapterNumber: 1,
                verseNumber: 9,
                verseText: books.first(where: { $0.name == "Joshua" })?
                    .chapters.first(where: { $0.number == 1 })?
                    .verses.first(where: { $0.number == 9 })?.text ?? ""
            )
            note.title = "Living with courage"
            note.content = "A reminder to take the next faithful step, trusting that God is present in every place and season."
            note.highlightColor = VerseHighlightColor.yellow.rawValue
            note.isFavorite = true
            context.insert(note)
        }

        let existingUserNoteTitles = Set(try context.fetch(FetchDescriptor<UserNote>()).map(\.title))
        if !existingUserNoteTitles.contains("Morning reflection") {
            let note = UserNote()
            note.title = "Morning reflection"
            note.content = "Today I want to begin with gratitude, listen carefully, and carry peace into each conversation."
            note.categoryRawValue = NoteCategory.personal.rawValue
            note.passageReference = "Psalms 46:1"
            note.isFavorite = true
            context.insert(note)
        }

        if !existingUserNoteTitles.contains("Grace in everyday life") {
            let note = UserNote()
            note.title = "Grace in everyday life"
            note.content = "Grace meets us before we have everything figured out and equips us to serve with humility."
            note.categoryRawValue = NoteCategory.sermon.rawValue
            note.passageReference = "Ephesians 2:8-10"
            note.sermonSpeaker = "Pastor Jordan"
            note.sermonLocation = "Sunday gathering"
            note.sermonDate = Calendar.autoupdatingCurrent.date(byAdding: .day, value: -7, to: Date())
            context.insert(note)
        }

        if context.hasChanges {
            try context.save()
        }
    }

    private static func generateReadingStats(books: [Book]) {
        let store = BibleStatsStore.shared
        let calendar = Calendar.autoupdatingCurrent
        guard !books.isEmpty else { return }

        let now = Date()
        var contributions = store.loadReadingContributions()
        var sessions: [ReadingSessionsStore.Session] = []

        for dayOffset in 0..<90 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else {
                continue
            }

            // Leave occasional gaps so streak and activity charts look believable.
            if Int.random(in: 0..<10) < 2 {
                continue
            }

            let dayKey = BibleStatsStore.isoDateString(date, calendar: calendar)
            let sessionCount = Int.random(in: 1...3)
            let startOfDay = calendar.startOfDay(for: date)
            let latestEnd = dayOffset == 0
                ? now
                : calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

            for _ in 0..<sessionCount {
                guard let book = books.randomElement() else { continue }
                let seconds = Int.random(in: 4...32) * 60
                let availableStartSeconds = max(
                    0,
                    Int(latestEnd.timeIntervalSince(startOfDay)) - seconds
                )
                let startOffset = availableStartSeconds > 0
                    ? Int.random(in: 0...availableStartSeconds)
                    : 0
                let sessionStart = startOfDay.addingTimeInterval(TimeInterval(startOffset))
                let sessionEnd = min(
                    sessionStart.addingTimeInterval(TimeInterval(seconds)),
                    latestEnd
                )

                contributions[dayKey, default: [:]][book.name, default: [:]][
                    "developer-sample",
                    default: 0
                ] += seconds
                sessions.append(.init(
                    readingSessionID: UUID(),
                    start: sessionStart,
                    end: sessionEnd,
                    book: book.name,
                    chapter: book.chapters.randomElement()?.number
                ))
            }
        }

        store.cacheReadingContributions = contributions
        store.saveJSON(contributions, key: BibleStatsStore.Defaults.keyReadingContributions)
        ReadingSessionsStore.shared.appendSessions(sessions)

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
            "quiz": "Quiz",
            "hangman": "Hangman",
            "beatclock": "Countdown",
            "versematch": "Verses",
            "bookorder": "Book Order",
            "whoami": "Who?",
            "word": "Word"
        ]
        defaults.set(displayNames[lastGame], forKey: "gamesLastPlayedGameName")
        defaults.set(
            Date().addingTimeInterval(-Double.random(in: 300...10_800)).timeIntervalSince1970,
            forKey: "gamesLastPlayedAt"
        )
    }

    private static func generateAppUsageSplit() {
        let defaults = UserDefaults.standard
        let calendar = Calendar.autoupdatingCurrent
        var gamesByDay: [String: Int] = [:]

        // Seed a month of game play time so today's value is a true subset of all-time.
        for dayOffset in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else {
                continue
            }

            let dayKey = BibleStatsStore.isoDateString(date, calendar: calendar)
            gamesByDay[dayKey] = Int.random(in: 15...90) * 60
        }

        // Reading time comes from the reading stats seeded elsewhere; seed game play time here.
        if let data = try? JSONEncoder().encode(gamesByDay) {
            defaults.set(data, forKey: GameStats.dailyPlaySecondsKey)
        }
        defaults.set(gamesByDay.values.reduce(0, +), forKey: GameStats.allTimePlaySecondsKey)
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
