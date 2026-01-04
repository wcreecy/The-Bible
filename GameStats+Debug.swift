#if DEBUG
import Foundation

extension GameStats {
    // Seeds random stats across all games and difficulties for today only.
    // Kept for convenience; the Settings button now uses seedRandomStatsAllGamesLastNDays(days:).
    func seedRandomStatsAllGames(roundsPerGame: Int = 6) {
        // Helper to roll a round with sane constraints
        func rollRound(maxQ: Int = 10) -> (correct: Int, answered: Int, bestStreak: Int) {
            let answered = Int.random(in: 3...maxQ)
            let correct = Int.random(in: 0...answered)
            let bestStreak = Int.random(in: 0...max(1, answered))
            return (correct, answered, bestStreak)
        }

        // Quiz (easy/normal/hard)
        for _ in 0..<roundsPerGame {
            let diffs: [Difficulty] = [.easy, .normal, .hard]
            let d = diffs.randomElement() ?? .easy
            let r = rollRound(maxQ: 12)
            recordRound(game: .quiz, difficulty: d, correct: r.correct, answered: r.answered, currentBestStreak: r.bestStreak)
        }

        // Hangman (easy/normal/hard) — was medium, now normal
        for _ in 0..<roundsPerGame {
            let diffs: [Difficulty] = [.easy, .normal, .hard]
            let d = diffs.randomElement() ?? .easy
            let r = rollRound(maxQ: 10)
            recordRound(game: .hangman, difficulty: d, correct: r.correct, answered: r.answered, currentBestStreak: r.bestStreak)
        }

        // Beat the Clock (easy/normal/hard) — was medium, now normal
        // UPDATED: Also write to combined all-time keys (_all) so stats are shared across difficulties.
        for _ in 0..<roundsPerGame {
            let diffs: [Difficulty] = [.easy, .normal, .hard]
            let d = diffs.randomElement() ?? .easy
            let r = rollRound(maxQ: 15)

            // Existing path (kept): writes per-difficulty via recordRound.
            recordRound(game: .beatclock, difficulty: d, correct: r.correct, answered: r.answered, currentBestStreak: r.bestStreak)

            // NEW: Mirror to combined Beat the Clock all-time keys.
            let defaults = UserDefaults.standard
            func setInt(_ key: String, _ value: Int) {
                defaults.set(max(0, value), forKey: key)
                iCloudSyncCoordinator.shared.pushKey(key)
            }
            func incInt(_ key: String, by delta: Int) {
                let old = defaults.integer(forKey: key)
                setInt(key, old + max(0, delta))
            }
            func maxInt(_ key: String, candidate: Int) {
                let old = defaults.integer(forKey: key)
                if candidate > old { setInt(key, candidate) }
            }
            incInt("beatclockAllTimeCorrect_all", by: r.correct)
            incInt("beatclockAllTimeAnswered_all", by: r.answered)
            maxInt("beatclockAllTimeBestStreak_all", candidate: r.bestStreak)
        }

        // Verse Match (easy/normal/hard) — was medium, now normal
        for _ in 0..<roundsPerGame {
            let diffs: [Difficulty] = [.easy, .normal, .hard]
            let d = diffs.randomElement() ?? .easy
            let r = rollRound(maxQ: 10)
            recordRound(game: .versematch, difficulty: d, correct: r.correct, answered: r.answered, currentBestStreak: r.bestStreak)
        }

        // Book Order (easy/normal/hard/all)
        for _ in 0..<roundsPerGame {
            let diffs: [Difficulty] = [.easy, .normal, .hard, .none] // .none maps to "all"
            let d = diffs.randomElement() ?? .none
            let r = rollRound(maxQ: 10)
            recordRound(game: .bookorder, difficulty: d, correct: r.correct, answered: r.answered, currentBestStreak: r.bestStreak)
        }

        // Who am I? (easy/normal/hard)
        for _ in 0..<roundsPerGame {
            let diffs: [Difficulty] = [.easy, .normal, .hard]
            let d = diffs.randomElement() ?? .easy
            let r = rollRound(maxQ: 10)
            recordRound(game: .whoami, difficulty: d, correct: r.correct, answered: r.answered, currentBestStreak: r.bestStreak)
        }

        // Wordle (daily/free): simulate wins/losses and guesses 1...6 on wins
        for _ in 0..<roundsPerGame {
            let types: [WordleType] = [.daily, .free]
            let t = types.randomElement() ?? .free
            let won = Bool.random()
            let guesses = won ? Int.random(in: 1...6) : 6
            let bestStreak = Int.random(in: 0...roundsPerGame)
            recordWordleResult(type: t, won: won, guesses: guesses, currentBestStreak: bestStreak)

            // NEW: also seed timing for wins/losses (today-only variant)
            let elapsed = Int.random(in: 20...300)
            recordWordleTime(type: t, won: won, elapsedSeconds: elapsed)
        }
    }

    // NEW: Seed random stats across all games for the last N days (default 31).
    // Ensures per-day coverage for all difficulties per game, and seeds WORD across types and modes.
    // Writes all-time counters and daily maps (overall + per-game + per-WORD-mode), and pushes keys to iCloud KVS.
    func seedRandomStatsAllGamesLastNDays(days: Int = 31) {
        let defaults = UserDefaults.standard
        let kvs = iCloudSyncCoordinator.shared

        // Helpers
        func localDayKey(for date: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
            var cal = calendar
            cal.timeZone = .autoupdatingCurrent
            let start = cal.startOfDay(for: date)
            let comps = cal.dateComponents([.year, .month, .day], from: start)
            let y = comps.year ?? 1970
            let m = comps.month ?? 1
            let d = comps.day ?? 1
            return String(format: "%04d-%02d-%02d", y, m, d)
        }

        func loadIntMap(forKey key: String) -> [String: Int] {
            guard let data = defaults.data(forKey: key),
                  let map = try? JSONDecoder().decode([String: Int].self, from: data) else {
                return [:]
            }
            return map
        }

        func saveIntMap(_ map: [String: Int], forKey key: String, pushToKVS: Bool) {
            if let data = try? JSONEncoder().encode(map) {
                defaults.set(data, forKey: key)
                if pushToKVS {
                    kvs.pushKey(key)
                }
            }
        }

        func loadNestedIntMap(forKey key: String) -> [String: [String: Int]] {
            guard let data = defaults.data(forKey: key),
                  let map = try? JSONDecoder().decode([String: [String: Int]].self, from: data) else {
                return [:]
            }
            return map
        }

        func saveNestedIntMap(_ map: [String: [String: Int]], forKey key: String, pushToKVS: Bool) {
            if let data = try? JSONEncoder().encode(map) {
                defaults.set(data, forKey: key)
                if pushToKVS {
                    kvs.pushKey(key)
                }
            }
        }

        func incInt(_ key: String, by delta: Int) {
            let old = defaults.integer(forKey: key)
            let newVal = max(0, old + max(0, delta))
            defaults.set(newVal, forKey: key)
            kvs.pushKey(key)
        }

        func maxInt(_ key: String, candidate: Int) {
            let old = defaults.integer(forKey: key)
            if candidate > old {
                defaults.set(candidate, forKey: key)
                kvs.pushKey(key)
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
                // not used here
                return nil
            }
        }

        func gameKey(for game: GameID) -> String {
            switch game {
            case .quiz: return "quiz"
            case .hangman: return "hangman"
            case .beatclock: return "beatclock"
            case .versematch: return "versematch"
            case .bookorder: return "bookorder"
            case .whoami: return "whoami"
            case .wordle: return "word" // combined/overall Wordle
            }
        }

        func rollRound(maxQ: Int = 10) -> (correct: Int, answered: Int, bestStreak: Int) {
            let answered = Int.random(in: 3...maxQ)
            let correct = Int.random(in: 0...answered)
            let bestStreak = Int.random(in: 0...max(1, answered))
            return (correct, answered, bestStreak)
        }

        func addToPerGameDaily(gameKey: String, dayKey: String, answered addA: Int, correct addC: Int) {
            var aMap = loadIntMap(forKey: "gamesDailyAnswered_\(gameKey)")
            aMap[dayKey, default: 0] = max(0, (aMap[dayKey] ?? 0) + max(0, addA))
            saveIntMap(aMap, forKey: "gamesDailyAnswered_\(gameKey)", pushToKVS: true)

            var cMap = loadIntMap(forKey: "gamesDailyCorrect_\(gameKey)")
            cMap[dayKey, default: 0] = max(0, (cMap[dayKey] ?? 0) + max(0, addC))
            saveIntMap(cMap, forKey: "gamesDailyCorrect_\(gameKey)", pushToKVS: true)
        }

        let cal = Calendar.autoupdatingCurrent
        let startOfToday = cal.startOfDay(for: Date())

        // Canonical Bible book names for per-book seeding
        let allBooks: [String] = BibleData.books.map { $0.name }

        for dayOffset in 0..<max(31, days) {
            guard let date = cal.date(byAdding: .day, value: -dayOffset, to: startOfToday) else { continue }
            let dayKey = localDayKey(for: date, calendar: cal)

            var overallAnsweredForDay = 0
            var overallCorrectForDay = 0

            // Seed standard games — ensure at least one round per difficulty each day, plus random extras.
            let standardGames: [(GameID, [Difficulty], Int)] = [
                (.quiz,      [.easy, .normal, .hard], 12),
                (.hangman,   [.easy, .normal, .hard], 10),
                (.beatclock, [.easy, .normal, .hard], 15),
                (.versematch,[.easy, .normal, .hard], 10),
                (.bookorder, [.easy, .normal, .hard, .none], 10), // .none -> "all"
                (.whoami,    [.easy, .normal, .hard], 10)
            ]

            for (game, diffs, maxQ) in standardGames {
                var gameAnswered = 0
                var gameCorrect = 0
                let gKey = gameKey(for: game)

                // Guarantee coverage: one round per difficulty
                for d in diffs {
                    let r = rollRound(maxQ: maxQ)

                    // Determine prefix and suffix for all-time keys, forcing Beat the Clock to "_all"
                    let pfx: String
                    switch game {
                    case .quiz: pfx = "quiz"
                    case .hangman: pfx = "hangman"
                    case .beatclock: pfx = "beatclock"
                    case .versematch: pfx = "versematch"
                    case .bookorder: pfx = "bookorder"
                    case .whoami: pfx = "whoami"
                    case .wordle: pfx = "wordle"
                    }

                    let baseSuffix = suffix(for: game, difficulty: d)
                    let s = (game == .beatclock) ? "all" : (baseSuffix ?? "")

                    if game == .beatclock {
                        // Combined all-time keys
                        incInt("\(pfx)AllTimeCorrect_\(s)", by: r.correct)
                        incInt("\(pfx)AllTimeAnswered_\(s)", by: r.answered)
                        maxInt("\(pfx)AllTimeBestStreak_\(s)", candidate: r.bestStreak)
                    } else if let sfx = baseSuffix {
                        incInt("\(pfx)AllTimeCorrect_\(sfx)", by: r.correct)
                        incInt("\(pfx)AllTimeAnswered_\(sfx)", by: r.answered)
                        maxInt("\(pfx)AllTimeBestStreak_\(sfx)", candidate: r.bestStreak)
                    }

                    gameAnswered += r.answered
                    gameCorrect += r.correct
                }

                // Extra random rounds for variability (0...2)
                let extraRounds = Int.random(in: 0...2)
                for _ in 0..<extraRounds {
                    let d = diffs.randomElement() ?? diffs.first!
                    let r = rollRound(maxQ: maxQ)

                    let pfx: String
                    switch game {
                    case .quiz: pfx = "quiz"
                    case .hangman: pfx = "hangman"
                    case .beatclock: pfx = "beatclock"
                    case .versematch: pfx = "versematch"
                    case .bookorder: pfx = "bookorder"
                    case .whoami: pfx = "whoami"
                    case .wordle: pfx = "wordle"
                    }

                    let baseSuffix = suffix(for: game, difficulty: d)
                    let s = (game == .beatclock) ? "all" : (baseSuffix ?? "")

                    if game == .beatclock {
                        incInt("\(pfx)AllTimeCorrect_\(s)", by: r.correct)
                        incInt("\(pfx)AllTimeAnswered_\(s)", by: r.answered)
                        maxInt("\(pfx)AllTimeBestStreak_\(s)", candidate: r.bestStreak)
                    } else if let sfx = baseSuffix {
                        incInt("\(pfx)AllTimeCorrect_\(sfx)", by: r.correct)
                        incInt("\(pfx)AllTimeAnswered_\(sfx)", by: r.answered)
                        maxInt("\(pfx)AllTimeBestStreak_\(sfx)", candidate: r.bestStreak)
                    }

                    gameAnswered += r.answered
                    gameCorrect += r.correct
                }

                // Per-game daily maps
                addToPerGameDaily(gameKey: gKey, dayKey: dayKey, answered: gameAnswered, correct: gameCorrect)
                overallAnsweredForDay += gameAnswered
                overallCorrectForDay += gameCorrect
            }

            // Seed WORD (Wordle): both types (daily/free) and both modes (normal/hard).
            do {
                enum Mode { case normal, hard }
                func modeSuffix(_ m: Mode) -> String { m == .normal ? "normal" : "hard" }

                var wordAnsweredCombined = 0
                var wordCorrectCombined = 0

                // Track best daily win (fewest guesses) for the result map
                var bestDailyWin: (guesses: Int, elapsed: Int, word: String)? = nil
                var anyDailyWin = false

                let types: [WordleType] = [.daily, .free]

                for t in types {
                    let typeSuf = (t == .daily) ? "daily" : "free"

                    // Guarantee at least one round for each mode per type
                    let baseModes: [Mode] = [.normal, .hard]
                    for m in baseModes {
                        let won = Bool.random()
                        let guesses = won ? Int.random(in: 1...6) : 6
                        let bestStreak = Int.random(in: 0...6)
                        let elapsed = Int.random(in: 20...300)

                        // Per-type counters
                        incInt("wordleAllTimeCorrect_\(typeSuf)", by: won ? 1 : 0)
                        incInt("wordleAllTimeAnswered_\(typeSuf)", by: 1)
                        maxInt("wordleAllTimeBestStreak_\(typeSuf)", candidate: bestStreak)

                        // Per-mode counters (aggregates across types)
                        let mSuf = modeSuffix(m)
                        incInt("wordleAllTimeCorrect_\(mSuf)", by: won ? 1 : 0)
                        incInt("wordleAllTimeAnswered_\(mSuf)", by: 1)
                        maxInt("wordleAllTimeBestStreak_\(mSuf)", candidate: bestStreak)

                        // Guess histograms on wins (per-type + per-mode)
                        if won {
                            let g = max(1, min(6, guesses))
                            incInt("wordleWinsGuessSum_\(typeSuf)", by: g)
                            incInt("wordleWinsOnGuess\(g)_\(typeSuf)", by: 1)

                            incInt("wordleWinsGuessSum_\(mSuf)", by: g)
                            incInt("wordleWinsOnGuess\(g)_\(mSuf)", by: 1)
                        }

                        // Timing totals (per-type + per-mode)
                        incInt("wordleTimeTotal_seconds_\(typeSuf)", by: elapsed)
                        if won {
                            incInt("wordleTimeWins_seconds_\(typeSuf)", by: elapsed)
                        } else {
                            incInt("wordleTimeLosses_seconds_\(typeSuf)", by: elapsed)
                        }

                        incInt("wordleTimeTotal_seconds_\(mSuf)", by: elapsed)
                        if won {
                            incInt("wordleTimeWins_seconds_\(mSuf)", by: elapsed)
                        } else {
                            incInt("wordleTimeLosses_seconds_\(mSuf)", by: elapsed)
                        }

                        // Per-game daily maps (combined WORD)
                        wordAnsweredCombined += 1
                        wordCorrectCombined += (won ? 1 : 0)

                        // Per-mode daily maps
                        let perModeKey = (m == .normal) ? "word_normal" : "word_hard"
                        addToPerGameDaily(gameKey: perModeKey, dayKey: dayKey, answered: 1, correct: (won ? 1 : 0))

                        // Track daily solved/result for Daily type
                        if t == .daily, won {
                            anyDailyWin = true
                            if bestDailyWin == nil || guesses < bestDailyWin!.guesses {
                                // Use a simple placeholder target for debug seeding
                                let targetWord = ["JESUS","GRACE","FAITH","ANGEL","CROSS","ABRAM","SARAH","JONAH","MOSES","DAVID"].randomElement() ?? "JESUS"
                                bestDailyWin = (guesses, elapsed, targetWord)
                            }
                        }
                    }

                    // Extra random rounds per type (0...2), random mode
                    let extraRounds = Int.random(in: 0...2)
                    for _ in 0..<extraRounds {
                        let m: Mode = Bool.random() ? .normal : .hard
                        let won = Bool.random()
                        let guesses = won ? Int.random(in: 1...6) : 6
                        let bestStreak = Int.random(in: 0...6)
                        let elapsed = Int.random(in: 20...300)
                        let mSuf = modeSuffix(m)

                        // Per-type counters
                        incInt("wordleAllTimeCorrect_\(typeSuf)", by: won ? 1 : 0)
                        incInt("wordleAllTimeAnswered_\(typeSuf)", by: 1)
                        maxInt("wordleAllTimeBestStreak_\(typeSuf)", candidate: bestStreak)

                        // Per-mode counters
                        incInt("wordleAllTimeCorrect_\(mSuf)", by: won ? 1 : 0)
                        incInt("wordleAllTimeAnswered_\(mSuf)", by: 1)
                        maxInt("wordleAllTimeBestStreak_\(mSuf)", candidate: bestStreak)

                        // Guess histograms on wins
                        if won {
                            let g = max(1, min(6, guesses))
                            incInt("wordleWinsGuessSum_\(typeSuf)", by: g)
                            incInt("wordleWinsOnGuess\(g)_\(typeSuf)", by: 1)

                            incInt("wordleWinsGuessSum_\(mSuf)", by: g)
                            incInt("wordleWinsOnGuess\(g)_\(mSuf)", by: 1)
                        }

                        // Timings
                        incInt("wordleTimeTotal_seconds_\(typeSuf)", by: elapsed)
                        if won {
                            incInt("wordleTimeWins_seconds_\(typeSuf)", by: elapsed)
                        } else {
                            incInt("wordleTimeLosses_seconds_\(typeSuf)", by: elapsed)
                        }

                        incInt("wordleTimeTotal_seconds_\(mSuf)", by: elapsed)
                        if won {
                            incInt("wordleTimeWins_seconds_\(mSuf)", by: elapsed)
                        } else {
                            incInt("wordleTimeLosses_seconds_\(mSuf)", by: elapsed)
                        }

                        // Combined and per-mode daily maps
                        wordAnsweredCombined += 1
                        wordCorrectCombined += (won ? 1 : 0)
                        let perModeKey = (m == .normal) ? "word_normal" : "word_hard"
                        addToPerGameDaily(gameKey: perModeKey, dayKey: dayKey, answered: 1, correct: (won ? 1 : 0))

                        if t == .daily, won {
                            anyDailyWin = true
                            if bestDailyWin == nil || guesses < bestDailyWin!.guesses {
                                let targetWord = ["JESUS","GRACE","FAITH","ANGEL","CROSS","ABRAM","SARAH","JONAH","MOSES","DAVID"].randomElement() ?? "JESUS"
                                bestDailyWin = (guesses, elapsed, targetWord)
                            }
                        }
                    }
                }

                // Per-game daily maps for WORD (combined key "word")
                addToPerGameDaily(gameKey: "word", dayKey: dayKey, answered: wordAnsweredCombined, correct: wordCorrectCombined)
                overallAnsweredForDay += wordAnsweredCombined
                overallCorrectForDay += wordCorrectCombined

                // Daily solved map flag when any daily win occurred
                var solvedMap: [String: Int] = loadIntMap(forKey: "wordleDailySolvedDays")
                solvedMap[dayKey] = anyDailyWin ? 1 : (solvedMap[dayKey] ?? 0)
                saveIntMap(solvedMap, forKey: "wordleDailySolvedDays", pushToKVS: true)

                // Daily result map: store best daily win (if any)
                if anyDailyWin, let best = bestDailyWin {
                    struct DailyResult: Codable { let won: Bool; let guesses: Int; let elapsed: Int; let word: String }
                    var resultMap: [String: DailyResult] = [:]
                    if let data = defaults.data(forKey: "wordleDailyResultMap"),
                       let decoded = try? JSONDecoder().decode([String: DailyResult].self, from: data) {
                        resultMap = decoded
                    }
                    resultMap[dayKey] = DailyResult(won: true, guesses: best.guesses, elapsed: best.elapsed, word: best.word)
                    if let data = try? JSONEncoder().encode(resultMap) {
                        defaults.set(data, forKey: "wordleDailyResultMap")
                        kvs.pushKey("wordleDailyResultMap")
                    }
                }
            }

            // NEW: Seed Bible Quiz per-book (all-time + daily nested) for OT/NT, Genre, Weak/Strong
            do {
                // All-time per-book maps
                var quizPerBookA = loadIntMap(forKey: "quizPerBookAnsweredMap")
                var quizPerBookC = loadIntMap(forKey: "quizPerBookCorrectMap")
                // Daily nested maps
                var quizDailyA = loadNestedIntMap(forKey: "quizPerBookDailyAnswered")
                var quizDailyC = loadNestedIntMap(forKey: "quizPerBookDailyCorrect")
                var dayA = quizDailyA[dayKey] ?? [:]
                var dayC = quizDailyC[dayKey] ?? [:]

                // Pick a handful of books each day and attribute some attempts
                let countBooks = Int.random(in: 4...10)
                let chosen = allBooks.shuffled().prefix(min(countBooks, allBooks.count))
                for book in chosen {
                    let attempts = Int.random(in: 2...6)
                    let correct = Int.random(in: 0...attempts)

                    // All-time
                    quizPerBookA[book, default: 0] += attempts
                    quizPerBookC[book, default: 0] += correct

                    // Daily nested
                    dayA[book, default: 0] += attempts
                    dayC[book, default: 0] += correct
                }

                // Save back
                saveIntMap(quizPerBookA, forKey: "quizPerBookAnsweredMap", pushToKVS: true)
                saveIntMap(quizPerBookC, forKey: "quizPerBookCorrectMap", pushToKVS: true)
                quizDailyA[dayKey] = dayA
                quizDailyC[dayKey] = dayC
                saveNestedIntMap(quizDailyA, forKey: "quizPerBookDailyAnswered", pushToKVS: true)
                saveNestedIntMap(quizDailyC, forKey: "quizPerBookDailyCorrect", pushToKVS: true)
            }

            // NEW: Seed Verse Match per-book (all-time) for OT/NT + Genre
            do {
                var vmPerBookA = loadIntMap(forKey: "versematchPerBookAnsweredMap")
                var vmPerBookC = loadIntMap(forKey: "versematchPerBookCorrectMap")

                let countBooks = Int.random(in: 4...10)
                let chosen = allBooks.shuffled().prefix(min(countBooks, allBooks.count))
                for book in chosen {
                    let attempts = Int.random(in: 1...5)
                    let correct = Int.random(in: 0...attempts)
                    vmPerBookA[book, default: 0] += attempts
                    vmPerBookC[book, default: 0] += correct
                }

                saveIntMap(vmPerBookA, forKey: "versematchPerBookAnsweredMap", pushToKVS: true)
                saveIntMap(vmPerBookC, forKey: "versematchPerBookCorrectMap", pushToKVS: true)
            }

            // NEW: Seed Hangman per-category (People/Places/Books) — all-time
            do {
                var hA = loadIntMap(forKey: "hangmanPerCategoryAnsweredMap")
                var hC = loadIntMap(forKey: "hangmanPerCategoryCorrectMap")
                for cat in ["People","Places","Books"] {
                    // Not every category every day
                    if Bool.random() {
                        let attempts = Int.random(in: 1...6)
                        let correct = Int.random(in: 0...attempts)
                        hA[cat, default: 0] += attempts
                        hC[cat, default: 0] += correct
                    }
                }
                saveIntMap(hA, forKey: "hangmanPerCategoryAnsweredMap", pushToKVS: true)
                saveIntMap(hC, forKey: "hangmanPerCategoryCorrectMap", pushToKVS: true)
            }

            // NEW: Seed Beat the Clock per-type (People/Places) — all-time
            do {
                var bcA = loadIntMap(forKey: "beatclockPerTypeAnsweredMap")
                var bcC = loadIntMap(forKey: "beatclockPerTypeCorrectMap")
                for t in ["People","Places"] {
                    if Bool.random() {
                        let attempts = Int.random(in: 2...8)
                        let correct = Int.random(in: 0...attempts)
                        bcA[t, default: 0] += attempts
                        bcC[t, default: 0] += correct
                    }
                }
                saveIntMap(bcA, forKey: "beatclockPerTypeAnsweredMap", pushToKVS: true)
                saveIntMap(bcC, forKey: "beatclockPerTypeCorrectMap", pushToKVS: true)
            }

            // Update overall daily maps for this day (push to KVS)
            var dailyA = loadIntMap(forKey: "gamesDailyAnswered")
            dailyA[dayKey, default: 0] = max(0, (dailyA[dayKey] ?? 0) + overallAnsweredForDay)
            saveIntMap(dailyA, forKey: "gamesDailyAnswered", pushToKVS: true)

            var dailyC = loadIntMap(forKey: "gamesDailyCorrect")
            dailyC[dayKey, default: 0] = max(0, (dailyC[dayKey] ?? 0) + overallCorrectForDay)
            saveIntMap(dailyC, forKey: "gamesDailyCorrect", pushToKVS: true)
        }

        // Notify UI
        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }
}
#endif
