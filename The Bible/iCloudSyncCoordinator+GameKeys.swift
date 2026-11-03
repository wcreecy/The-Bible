import Foundation

// Every UserDefaults key the game stats sync covers, grouped by game.

@MainActor
extension iCloudSyncCoordinator {
    // Game keys: Hangman
    static let hangmanKeys: [String] = {
        // Include both legacy "medium" and new "normal", plus combined "all"
        let diffs = ["easy", "normal", "medium", "hard", "all"]
        var keys: [String] = []
        for d in diffs {
            keys.append("hangmanAllTimeCorrect_\(d)")
            keys.append("hangmanAllTimeAnswered_\(d)")
            keys.append("hangmanAllTimeBestStreak_\(d)")
        }
        // Include legacy unsuffixed keys for backward compatibility
        keys.append(contentsOf: ["hangmanAllTimeCorrect", "hangmanAllTimeAnswered", "hangmanAllTimeBestStreak"])
        return keys
    }()

    // Hangman per-category maps mirrored via KVS (JSON [String:Int])
    static let hangmanPerCategoryMapKeys: [String] = [
        "hangmanPerCategoryAnsweredMap",
        "hangmanPerCategoryCorrectMap"
    ]

    // Hangman persistent streak keys (local-only; used by HangmanGameView)
    static let hangmanPersistentStreakKeys: [String] = {
        var keys: [String] = []
        for d in ["easy","normal","hard"] {
            keys.append("hangmanPersistentStreak_\(d)")
            keys.append("hangmanPersistentBestStreak_\(d)")
        }
        return keys
    }()

    // Game keys: Beat the Clock
    static let beatClockKeys: [String] = {
        // Include both legacy "medium" and new "normal", plus combined "all"
        let diffs = ["easy", "normal", "medium", "hard", "all"]
        var keys: [String] = []
        for d in diffs {
            keys.append("beatclockAllTimeCorrect_\(d)")
            keys.append("beatclockAllTimeAnswered_\(d)")
            keys.append("beatclockAllTimeBestStreak_\(d)")
        }
        return keys
    }()

    // Beat the Clock persistent streak keys (local-only; used to seed streaks on launch)
    static let beatClockPersistentStreakKeys: [String] = {
        var keys: [String] = []
        for d in ["easy","normal","hard"] {
            keys.append("beatclockPersistentStreak_\(d)")
            keys.append("beatclockPersistentBestStreak_\(d)")
        }
        return keys
    }()

    // Beat the Clock per-type maps mirrored via KVS (JSON [String:Int])
    static let beatClockPerTypeMapKeys: [String] = [
        "beatclockPerTypeAnsweredMap",
        "beatclockPerTypeCorrectMap"
    ]

    // Game keys: Reference Match (legacy)
    static let refMatchKeys: [String] = {
        // Include both legacy "medium" and new "normal"
        let diffs = ["easy", "normal", "medium", "hard"]
        var keys: [String] = []
        for d in diffs {
            keys.append("refmatchAllTimeCorrect_\(d)")
            keys.append("refmatchAllTimeAnswered_\(d)")
            keys.append("refmatchAllTimeBestStreak_\(d)")
        }
        // Include legacy unsuffixed keys for backward compatibility
        keys.append(contentsOf: ["refmatchAllTimeCorrect", "refmatchAllTimeAnswered", "refmatchAllTimeBestStreak"])
        return keys
    }()

    // Legacy Verse Match history: Quiz aggregates these original keys on read.
    // Keep sync/reset support for existing ledgers and late updates from older devices.
    static let verseMatchKeys: [String] = {
        // Include "easy/normal/medium/hard" and combined "all" to match UI's aggregated reads
        let diffs = ["easy", "normal", "medium", "hard", "all"]
        var keys: [String] = []
        for d in diffs {
            keys.append("versematchAllTimeCorrect_\(d)")
            keys.append("versematchAllTimeAnswered_\(d)")
            keys.append("versematchAllTimeBestStreak_\(d)")
        }
        // Include legacy unsuffixed keys for safety
        keys.append(contentsOf: ["versematchAllTimeCorrect", "versematchAllTimeAnswered", "versematchAllTimeBestStreak"])
        return keys
    }()

    // Retired local streak keys, retained only so resetting game history clears them.
    static let verseMatchPersistentStreakKeys: [String] = {
        var keys: [String] = []
        for d in ["easy","normal","hard"] {
            keys.append("versematchPersistentStreak_\(d)")
            keys.append("versematchPersistentBestStreak_\(d)")
        }
        return keys
    }()

    // Legacy per-book maps, still included in Quiz's combined history.
    static let verseMatchPerBookMapKeys: [String] = [
        "versematchPerBookAnsweredMap",
        "versematchPerBookCorrectMap"
    ]

    // Game keys: Quiz — now includes combined "all" variants for shared all-time stats
    /// Game keys: Bible Trivia — per-difficulty and combined all-time statistics.
    static let bibleTriviaKeys: [String] = {
        let diffs = ["easy", "normal", "hard", "all"]
        var keys: [String] = []
        for difficulty in diffs {
            keys.append("triviaAllTimeCorrect_\(difficulty)")
            keys.append("triviaAllTimeAnswered_\(difficulty)")
            keys.append("triviaAllTimeBestStreak_\(difficulty)")
        }
        return keys
    }()

    /// Bible Trivia completion state. Within a cycle this is union-merged so completed questions
    /// don't reappear after the same account has used another device.
    static let bibleTriviaProgressKeys = [BibleTriviaProgressStore.storageKey]

    static let quizKeys: [String] = {
        let diffs = ["easy", "normal", "hard", "all"]
        var keys: [String] = []
        for d in diffs {
            keys.append("quizAllTimeCorrect_\(d)")
            keys.append("quizAllTimeAnswered_\(d)")
            keys.append("quizAllTimeBestStreak_\(d)")
        }
        // Include legacy unsuffixed keys so reset clears older installs and fallbacks
        keys.append(contentsOf: ["quizAllTimeCorrect", "quizAllTimeAnswered", "quizAllTimeBestStreak"])
        return keys
    }()

    // Bible Quiz per-book maps mirrored via KVS (JSON [String:Int])
    static let quizPerBookMapKeys: [String] = [
        "quizPerBookAnsweredMap",
        "quizPerBookCorrectMap"
    ]

    static let triviaPerBookMapKeys: [String] = [
        "triviaPerBookAnsweredMap",
        "triviaPerBookCorrectMap"
    ]

    // Per-book daily maps used by the detailed Quiz statistics screen.
    static let quizPerBookDailyMapKeys: [String] = [
        "quizPerBookDailyAnswered",
        "quizPerBookDailyCorrect"
    ]

    static let triviaPerBookDailyMapKeys: [String] = [
        "triviaPerBookDailyAnswered",
        "triviaPerBookDailyCorrect"
    ]

    // Legacy daily book maps, still included in Quiz's combined history.
    static let verseMatchPerBookDailyMapKeys: [String] = [
        "versematchPerBookDailyAnswered",
        "versematchPerBookDailyCorrect"
    ]

    // Time spent with a game screen open: all-time seconds and a per-day map.
    static let gamePlayTimeCounterKeys: [String] = ["allTimeUsageGameSeconds"]
    static let gamePlayTimeMapKeys: [String] = ["gamesDailyPlaySeconds"]

    // Game keys: Word Search (easy/normal/hard + combined "all")
    static let wordSearchKeys: [String] = {
        var keys: [String] = []
        for d in ["easy", "normal", "hard", "all"] {
            keys.append("wordsearchAllTimeCorrect_\(d)")
            keys.append("wordsearchAllTimeAnswered_\(d)")
            keys.append("wordsearchAllTimeBestStreak_\(d)")
        }
        return keys
    }()

    // Game keys: Scramble (easy/normal/hard + combined "all")
    static let scrambleKeys: [String] = {
        var keys: [String] = []
        for difficulty in ["easy", "normal", "hard", "all"] {
            keys.append("scrambleAllTimeCorrect_\(difficulty)")
            keys.append("scrambleAllTimeAnswered_\(difficulty)")
            keys.append("scrambleAllTimeBestStreak_\(difficulty)")
        }
        return keys
    }()

    // Game keys: Crossword (easy/normal/hard + combined "all")
    static let crosswordKeys: [String] = {
        var keys: [String] = []
        for difficulty in ["easy", "normal", "hard", "all"] {
            keys.append("crosswordAllTimeCorrect_\(difficulty)")
            keys.append("crosswordAllTimeAnswered_\(difficulty)")
            keys.append("crosswordAllTimeBestStreak_\(difficulty)")
        }
        return keys
    }()

    // Game keys: Book Order — per-difficulty (easy/normal/hard/expert), combined "all", + legacy unsuffixed for reset/back-compat
    static let bookOrderKeys: [String] = {
        let diffs = ["easy", "normal", "hard", "expert", "all"]
        var keys: [String] = []
        for d in diffs {
            keys.append("bookorderAllTimeCorrect_\(d)")
            keys.append("bookorderAllTimeAnswered_\(d)")
            keys.append("bookorderAllTimeBestStreak_\(d)")
        }
        // Include legacy unsuffixed keys so reset clears older installs too
        keys.append(contentsOf: ["bookorderAllTimeCorrect", "bookorderAllTimeAnswered", "bookorderAllTimeBestStreak"])
        return keys
    }()

    // Book Order persistent streak keys (local-only; used by BookOrderGameViewModel)
    static let bookOrderPersistentStreakKeys: [String] = {
        var keys: [String] = []
        for d in ["easy","normal","hard","all"] {
            keys.append("bookorderPersistentStreak_\(d)")
            keys.append("bookorderPersistentBestStreak_\(d)")
        }
        return keys
    }()

    // Streak values stored separately from the all-time counters by the remaining games.
    // These are local-only today, but still form part of the user's game history.
    static let additionalPersistentStreakKeys: [String] = {
        var keys = [
            "wordlePersistentStreak", "wordlePersistentBestStreak",
            "wordlePersistentStreak_practice", "wordlePersistentBestStreak_practice",
            "wordsearchCurrentStreak", "crosswordCurrentStreak"
        ]
        for difficulty in ["easy", "normal", "hard"] {
            keys.append("quizPersistentStreak_\(difficulty)")
            keys.append("quizPersistentBestStreak_\(difficulty)")
            keys.append("whoamiPersistentStreak_\(difficulty)")
            keys.append("whoamiPersistentBestStreak_\(difficulty)")
            keys.append("triviaPersistentStreak_\(difficulty)")
            keys.append("triviaPersistentBestStreak_\(difficulty)")
            keys.append("scramblePersistentStreak_\(difficulty)")
            keys.append("scramblePersistentBestStreak_\(difficulty)")
        }
        return keys
    }()

    static var allPersistentStreakKeys: [String] {
        beatClockPersistentStreakKeys
            + verseMatchPersistentStreakKeys
            + hangmanPersistentStreakKeys
            + bookOrderPersistentStreakKeys
            + additionalPersistentStreakKeys
    }

    var allKnownGameDataKeys: Set<String> { Self.allKnownGameDataKeySet }

    // Built once; also read by the timestamped-key set in iCloudSyncCoordinator+Games.
    static let allKnownGameDataKeySet: Set<String> = {
        Set(
            hangmanKeys + beatClockKeys + refMatchKeys
                + verseMatchKeys + quizKeys + bibleTriviaKeys + bookOrderKeys
                + whoAmIKeys + wordleKeys + wordSearchKeys + scrambleKeys + crosswordKeys
                + bibleTriviaProgressKeys
                + gamePlayTimeCounterKeys + gamePlayTimeMapKeys
                + gameDailyAndLastPlayedKeys + quizPerBookMapKeys + triviaPerBookMapKeys
                + quizPerBookDailyMapKeys + triviaPerBookDailyMapKeys + verseMatchPerBookDailyMapKeys
                + verseMatchPerBookMapKeys + beatClockPerTypeMapKeys
                + hangmanPerCategoryMapKeys + perGameDailyMapKeys
                + wordleSolvedMapKeys + wordleDailyResultKeys
                + wordleDailyFlagKeys + allPersistentStreakKeys
        )
    }()

    // Game keys: Who am I? (easy/normal/hard + combined "all")
    static let whoAmIKeys: [String] = {
        let diffs = ["easy", "normal", "hard", "all"]
        var keys: [String] = []
        for d in diffs {
            keys.append("whoamiAllTimeCorrect_\(d)")
            keys.append("whoamiAllTimeAnswered_\(d)")
            keys.append("whoamiAllTimeBestStreak_\(d)")
        }
        // Include legacy unsuffixed keys for safety because the read path can fall back to them
        keys.append(contentsOf: ["whoamiAllTimeCorrect", "whoamiAllTimeAnswered", "whoamiAllTimeBestStreak"])
        return keys
    }()

    // Game keys: Wordle — split by type (daily/free) and keep legacy "all"
    static let wordleKeys: [String] = {
        var keys: [String] = []

        // Core per-type counters
        let typeDiffs = ["daily", "free", "all"] // include legacy "all" for back-compat
        for d in typeDiffs {
            keys.append("wordleAllTimeCorrect_\(d)")
            keys.append("wordleAllTimeAnswered_\(d)")
            keys.append("wordleAllTimeBestStreak_\(d)")
        }

        // Per-type win-guess stats (no legacy "_all" variants)
        for d in ["daily", "free"] {
            keys.append("wordleWinsGuessSum_\(d)")
            for i in 1...6 {
                keys.append("wordleWinsOnGuess\(i)_\(d)")
            }
        }

        // Per-type timing keys (total, wins, losses) so they mirror/reset via KVS
        for d in ["daily", "free"] {
            keys.append("wordleTimeTotal_seconds_\(d)")
            keys.append("wordleTimeWins_seconds_\(d)")
            keys.append("wordleTimeLosses_seconds_\(d)")
        }

        // Per-mode aggregates (normal/hard)
        for m in ["normal", "hard"] {
            // Counts + best streak
            keys.append("wordleAllTimeCorrect_\(m)")
            keys.append("wordleAllTimeAnswered_\(m)")
            keys.append("wordleAllTimeBestStreak_\(m)")

            // Win-guess stats
            keys.append("wordleWinsGuessSum_\(m)")
            for i in 1...6 {
                keys.append("wordleWinsOnGuess\(i)_\(m)")
            }

            // Timing totals
            keys.append("wordleTimeTotal_seconds_\(m)")
            keys.append("wordleTimeWins_seconds_\(m)")
            keys.append("wordleTimeLosses_seconds_\(m)")
        }

        return keys
    }()

    // WORD daily solved flags (JSON [String:Int] dayKey -> 1)
    static let wordleSolvedMapKeys: [String] = [
        "wordleDailySolvedDays"
    ]

    // WORD daily result summary map (JSON Data [String: DailyResult])
    // We treat it as a raw Data key like other JSON maps, but with custom merge below.
    static let wordleDailyResultKeys: [String] = [
        "wordleDailyResultMap"
    ]

    // WORD daily completion flags (String values)
    static let wordleDailyFlagKeys: [String] = [
        "wordleDailyCompletedDay",  // yyyy-MM-dd
        "wordleDailyTarget"        // answer word
    ]

    // Game daily + last played keys
    static let gameDailyAndLastPlayedKeys: [String] = [
        "gamesDailyAnswered",      // JSON [String: Int]
        "gamesDailyCorrect",       // JSON [String: Int]
        "gamesLastPlayedAt",       // Double
        "gamesLastPlayedGameName"  // String
    ]

    // Per-game (and per-WORD-mode) daily maps (JSON [String:Int]) — now mirrored via KVS
    static let perGameDailyMapKeys: [String] = {
        let gameKeys = ["quiz","trivia","hangman","beatclock","versematch","bookorder","whoami","wordsearch","scramble","crossword","word"]
        var keys: [String] = []
        for g in gameKeys {
            keys.append("gamesDailyAnswered_\(g)")
            keys.append("gamesDailyCorrect_\(g)")
        }
        // WORD per-mode daily maps (Normal/Hard)
        for modeKey in ["word_normal", "word_hard"] {
            keys.append("gamesDailyAnswered_\(modeKey)")
            keys.append("gamesDailyCorrect_\(modeKey)")
        }
        return keys
    }()
}
