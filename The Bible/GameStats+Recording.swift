import Foundation

/// Everything that writes results: rounds, daily maps, per-book and per-category counts, and Word results.
extension GameStats {
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

    func recordHangmanCategory(category: String, answered addAnswered: Int, correct addCorrect: Int) {
        recordCategoryResult(
            answeredKey: "hangmanPerCategoryAnsweredMap", correctKey: "hangmanPerCategoryCorrectMap",
            category: category, answered: addAnswered, correct: addCorrect
        )
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
}
