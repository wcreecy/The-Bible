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
        for _ in 0..<roundsPerGame {
            let diffs: [Difficulty] = [.easy, .normal, .hard]
            let d = diffs.randomElement() ?? .easy
            let r = rollRound(maxQ: 15)
            recordRound(game: .beatclock, difficulty: d, correct: r.correct, answered: r.answered, currentBestStreak: r.bestStreak)
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
    // This writes both all-time counters and daily maps (overall + per-game).
    // For WORD (daily/free), it also seeds timing totals for wins and losses.
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

        let cal = Calendar.autoupdatingCurrent
        let startOfToday = cal.startOfDay(for: Date())

        for dayOffset in 0..<max(31, days) {
            guard let date = cal.date(byAdding: .day, value: -dayOffset, to: startOfToday) else { continue }
            let dayKey = localDayKey(for: date, calendar: cal)

            var overallAnsweredForDay = 0
            var overallCorrectForDay = 0

            // Helper to add to per-game daily maps
            func addToPerGameDaily(gameKey: String, answered addA: Int, correct addC: Int) {
                // Answered
                var aMap = loadIntMap(forKey: "gamesDailyAnswered_\(gameKey)")
                aMap[dayKey, default: 0] = max(0, (aMap[dayKey] ?? 0) + max(0, addA))
                saveIntMap(aMap, forKey: "gamesDailyAnswered_\(gameKey)", pushToKVS: false)

                // Correct
                var cMap = loadIntMap(forKey: "gamesDailyCorrect_\(gameKey)")
                cMap[dayKey, default: 0] = max(0, (cMap[dayKey] ?? 0) + max(0, addC))
                saveIntMap(cMap, forKey: "gamesDailyCorrect_\(gameKey)", pushToKVS: false)

                overallAnsweredForDay += max(0, addA)
                overallCorrectForDay += max(0, addC)
            }

            // Seed standard games
            let standardGames: [(GameID, [Difficulty], Int)] = [
                (.quiz,      [.easy, .normal, .hard], 12),
                (.hangman,   [.easy, .normal, .hard], 10),
                (.beatclock, [.easy, .normal, .hard], 15),
                (.versematch,[.easy, .normal, .hard], 10),
                (.bookorder, [.easy, .normal, .hard, .none], 10), // .none -> "all"
                (.whoami,    [.easy, .normal, .hard], 10)
            ]

            for (game, diffs, maxQ) in standardGames {
                let rounds = Int.random(in: 1...3)
                var gameAnswered = 0
                var gameCorrect = 0
                let gKey = gameKey(for: game)

                for _ in 0..<rounds {
                    let d = diffs.randomElement() ?? diffs.first!
                    let r = rollRound(maxQ: maxQ)

                    // Increment all-time counters
                    if let suf = suffix(for: game, difficulty: d) {
                        let pfx: String
                        switch game {
                        case .quiz: pfx = "quiz"
                        case .hangman: pfx = "hangman"
                        case .beatclock: pfx = "beatclock"
                        case .versematch: pfx = "versematch"
                        case .bookorder: pfx = "bookorder"
                        case .whoami: pfx = "whoami"
                        case .wordle: pfx = "wordle" // not used here
                        }
                        incInt("\(pfx)AllTimeCorrect_\(suf)", by: r.correct)
                        incInt("\(pfx)AllTimeAnswered_\(suf)", by: r.answered)
                        maxInt("\(pfx)AllTimeBestStreak_\(suf)", candidate: r.bestStreak)
                    }

                    gameAnswered += r.answered
                    gameCorrect += r.correct
                }

                // Per-game daily maps
                addToPerGameDaily(gameKey: gKey, answered: gameAnswered, correct: gameCorrect)
            }

            // Seed WORD (Wordle) daily + free
            do {
                let types: [WordleType] = [.daily, .free]
                var wordAnswered = 0
                var wordCorrect = 0

                for t in types {
                    let rounds = Int.random(in: 0...2) // some days may have no games of a type
                    let suf = (t == .daily) ? "daily" : "free"

                    for _ in 0..<rounds {
                        let won = Bool.random()
                        let guesses = won ? Int.random(in: 1...6) : 6
                        let bestStreak = Int.random(in: 0...6)

                        // All-time counters
                        incInt("wordleAllTimeCorrect_\(suf)", by: won ? 1 : 0)
                        incInt("wordleAllTimeAnswered_\(suf)", by: 1)
                        maxInt("wordleAllTimeBestStreak_\(suf)", candidate: bestStreak)

                        // Guess stats on wins
                        if won {
                            incInt("wordleWinsGuessSum_\(suf)", by: guesses)
                            incInt("wordleWinsOnGuess\(max(1, min(6, guesses)))_\(suf)", by: 1)
                        }

                        // NEW: timing totals for wins and losses
                        let elapsed = Int.random(in: 20...300)
                        incInt("wordleTimeTotal_seconds_\(suf)", by: elapsed)
                        if won {
                            incInt("wordleTimeWins_seconds_\(suf)", by: elapsed)
                        } else {
                            incInt("wordleTimeLosses_seconds_\(suf)", by: elapsed)
                        }

                        wordAnswered += 1
                        wordCorrect += won ? 1 : 0
                    }
                }

                // Per-game daily maps for WORD (combined key "word")
                addToPerGameDaily(gameKey: "word", answered: wordAnswered, correct: wordCorrect)
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

