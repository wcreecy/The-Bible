#if DEBUG
import Foundation
import SwiftData

@MainActor
enum DeveloperSampleData {
    static func generate(in context: ModelContext) async {
        let books = await BibleRepository.shared.loadAllBooks()
        generateReadingStats(books: books)
        generateGameStats()
        generateMissedQuestions()
        generateAppUsageSplit()
        generateTimerStats()

        do {
            try generateStudyData(books: books, in: context)
        } catch {
            print("Unable to save developer study samples: \(error.localizedDescription)")
        }

        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
        NotificationCenter.default.post(name: .studyTimeUpdated, object: nil)
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

        let existingHighlights = try context.fetch(FetchDescriptor<VerseNote>()).filter { !$0.highlightColor.isEmpty }
        var highlightLocations = Set(existingHighlights.map {
            "\($0.bookName)|\($0.chapterNumber)|\($0.verseNumber)"
        })

        for target in favoriteTargets where highlightLocations.count < 10 {
            guard let verse = books.first(where: { $0.name == target.0 })?
                .chapters.first(where: { $0.number == target.1 })?
                .verses.first(where: { $0.number == target.2 }) else {
                continue
            }

            let location = "\(target.0)|\(target.1)|\(target.2)"
            guard highlightLocations.insert(location).inserted else { continue }

            let note = VerseNote(
                bookName: target.0,
                chapterNumber: target.1,
                verseNumber: target.2,
                verseText: verse.text
            )
            note.title = "Sample highlight \(target.0) \(target.1):\(target.2)"
            note.content = "A sample highlighted verse for exploring Saved Verses."
            note.highlightColor = VerseHighlightColor.yellow.rawValue
            context.insert(note)
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

        // Add a guaranteed valid session on each of the last seven calendar days.
        // The average-session chart intentionally reads ReadingSessionsStore rather
        // than the daily reading totals, so these must be persisted as sessions.
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else {
                continue
            }

            let dayStart = calendar.startOfDay(for: date)
            let sessionStart = dayOffset == 0
                ? now.addingTimeInterval(-1_200)
                : dayStart.addingTimeInterval(9 * 60 * 60)
            let duration = 10 * 60 + dayOffset * 60
            sessions.append(.init(
                readingSessionID: UUID(),
                start: sessionStart,
                end: sessionStart.addingTimeInterval(TimeInterval(duration)),
                book: books[dayOffset % books.count].name,
                chapter: books[dayOffset % books.count].chapters.first?.number
            ))
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

    /// Internal rather than private so tests can check every game gets sample stats.
    static func generateGameStats() {
        let defaults = UserDefaults.standard
        let calendar = Calendar.autoupdatingCurrent
        let games: [(dailyKey: String, storagePrefix: String)] = [
            ("quiz", "quiz"),
            ("trivia", "trivia"),
            ("hangman", "hangman"),
            ("beatclock", "beatclock"),
            ("bookorder", "bookorder"),
            ("whoami", "whoami"),
            ("wordsearch", "wordsearch"),
            ("scramble", "scramble"),
            ("crossword", "crossword"),
            ("word", "wordle")
        ]

        // One Word Search or Crossword is a whole puzzle that takes minutes, so those games
        // get far fewer plays per day than the question games.
        func dailyPlays(for game: (dailyKey: String, storagePrefix: String), questionGames: ClosedRange<Int>) -> Int {
            switch game.dailyKey {
            case "wordsearch", "crossword": Int.random(in: 1...10)
            default: Int.random(in: questionGames)
            }
        }

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
                let answered = dailyPlays(for: game, questionGames: 4...24)
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

        // Guarantee every game has sample activity, even if random selection skipped it.
        let todayKey = GameStats.localDayKey(for: Date(), calendar: calendar)
        for game in games where allTimeByPrefix[game.storagePrefix] == nil {
            let answered = dailyPlays(for: game, questionGames: 8...20)
            let correct = Int((Double(answered) * Double.random(in: 0.60...0.92)).rounded())

            totalAnsweredByDay[todayKey, default: 0] += answered
            totalCorrectByDay[todayKey, default: 0] += correct
            perGameAnswered[game.dailyKey, default: [:]][todayKey, default: 0] += answered
            perGameCorrect[game.dailyKey, default: [:]][todayKey, default: 0] += correct
            allTimeByPrefix[game.storagePrefix] = (answered, correct, Int.random(in: 2...12))
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
            "trivia": "Trivia",
            "hangman": "Hangman",
            "beatclock": "Countdown",
            "bookorder": "Book Order",
            "whoami": "Who?",
            "wordsearch": "Word Search",
            "scramble": "Scramble",
            "crossword": "Crossword",
            "word": "Word"
        ]
        defaults.set(displayNames[lastGame], forKey: "gamesLastPlayedGameName")
        defaults.set(
            Date().addingTimeInterval(-Double.random(in: 300...10_800)).timeIntervalSince1970,
            forKey: "gamesLastPlayedAt"
        )
    }

    private static func generateMissedQuestions() {
        let store = MissedGameQuestionStore.shared
        let sampleQuestions: [(id: String, book: String, chapter: Int)] = [
            ("1", "Genesis", 6),
            ("2", "Genesis", 8),
            ("3", "Genesis", 9),
            ("4", "Genesis", 12),
            ("5", "Genesis", 19),
            ("6", "Genesis", 41),
            ("7", "Genesis", 25),
            ("8", "Genesis", 32),
            ("9", "Joshua", 2),
            ("10", "Joshua", 3)
        ]

        for (offset, sample) in sampleQuestions.enumerated() {
            store.record(
                game: .bibleTrivia,
                bookNames: [sample.book],
                chapterNumber: sample.chapter,
                topic: "Sample Trivia miss",
                questionID: sample.id,
                date: Date().addingTimeInterval(-Double((offset + 1) * 3_600))
            )
        }
    }

    private static func generateAppUsageSplit() {
        let defaults = UserDefaults.standard
        let calendar = Calendar.autoupdatingCurrent
        var gamesByDay = loadMap(GameStats.dailyPlaySecondsKey)
        var addedGameSeconds = 0
        var studyAllocations: [(date: Date, seconds: Int)] = []

        // Add a month of game and study time on top of any existing totals so today's
        // values are nonzero and the comparison chart has a realistic history.
        for dayOffset in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else {
                continue
            }

            let dayKey = BibleStatsStore.isoDateString(date, calendar: calendar)
            let gameSeconds = Int.random(in: 15...90) * 60
            gamesByDay[dayKey, default: 0] += gameSeconds
            addedGameSeconds += gameSeconds
            studyAllocations.append((date, Int.random(in: 8...45) * 60))
        }

        saveMap(gamesByDay, key: GameStats.dailyPlaySecondsKey)
        defaults.set(
            max(0, defaults.integer(forKey: GameStats.allTimePlaySecondsKey)) + addedGameSeconds,
            forKey: GameStats.allTimePlaySecondsKey
        )
        // Play time syncs through the game ledger, which records the increase as this device's contribution.
        iCloudSyncCoordinator.shared.pushKey(GameStats.allTimePlaySecondsKey)

        StudyTimeTracker.shared.add(studyAllocations)
    }

    /// Seeds the Prayer & Study Timer card: a month of sessions for each kind, with
    /// every one of the last seven days filled so this week's bars and streaks show.
    private static func generateTimerStats() {
        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        let timers: [(store: PrayerStatsStore, minutes: ClosedRange<Int>, hour: Int)] = [
            (PrayerStatsStore.shared, 5...20, 7),
            (PrayerStatsStore.study, 10...40, 19)
        ]

        for timer in timers {
            var lastSession: (seconds: Int, end: Date)?

            for dayOffset in stride(from: 29, through: 0, by: -1) {
                // Leave occasional gaps before the last week so best and current streaks differ.
                if dayOffset >= 7, Int.random(in: 0..<10) < 3 {
                    continue
                }

                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else {
                    continue
                }

                let seconds = Int.random(in: timer.minutes) * 60
                let scheduledStart = calendar.startOfDay(for: date)
                    .addingTimeInterval(TimeInterval(timer.hour * 3_600))
                // Today's session must already be finished, so end it shortly before now.
                let start = dayOffset == 0
                    ? min(scheduledStart, now.addingTimeInterval(-TimeInterval(seconds + 300)))
                    : scheduledStart
                let end = start.addingTimeInterval(TimeInterval(seconds))

                timer.store.record(from: start, to: end)
                lastSession = (seconds, end)
            }

            if let lastSession {
                timer.store.recordSessionEnded(seconds: lastSession.seconds, at: lastSession.end)
            }
        }
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
