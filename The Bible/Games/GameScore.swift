import Foundation

/// The score, streak and best-game bookkeeping that the question games share.
///
/// A game keeps one of these in its view model and tells it what happened. The streak rules
/// live here so every game follows them:
/// - The session streak carries from one game to the next (Play Again, Change Settings).
/// - Leaving the screen clears it.
/// - The saved streak (`PersistentGameStreak`) ends only on a wrong answer, never on leaving.
///
/// The caller passes in the saved streak and the best-score key because both depend on the
/// game's current difficulty, and the stored keys must stay exactly as they are.
struct GameScore {
    private(set) var score = 0
    private(set) var answered = 0
    /// Correct answers in a row since the screen opened.
    private(set) var streak = 0
    /// The longest session streak since the screen opened.
    private(set) var sessionBestStreak = 0
    /// The best saved streak for the current difficulty, raised as the player extends it.
    /// This is what the all-time stats receive.
    private(set) var savedBestStreak = 0
    private(set) var bestGameScore = 0
    private(set) var isNewBestGame = false

    // Round summary bookkeeping
    /// Every answer in the current game, in order, for the end-of-round summary.
    private(set) var entries: [GameRoundEntry] = []
    /// The saved run of correct answers, which carries between games and app launches.
    private(set) var savedCurrentStreak = 0
    /// The saved best when the game began, so the summary can tell when it was beaten.
    private(set) var savedBestStreakAtStart = 0
    /// False when the game has no time limit or the timer was turned off at any point.
    private(set) var wasTimed = true
    /// How long the game took from the first question to the end.
    private(set) var gameDuration: Duration?
    private var gameStartedAt: ContinuousClock.Instant?
    private var questionStartedAt: ContinuousClock.Instant?

    /// Starts a game. The score clears; the streak carries over from the last one.
    /// Pass `isTimed: false` for games or difficulties without a time limit.
    mutating func beginGame(savedStreak: PersistentGameStreak, isTimed: Bool = true) {
        score = 0
        answered = 0
        isNewBestGame = false
        savedBestStreak = savedStreak.best
        savedBestStreakAtStart = savedStreak.best
        savedCurrentStreak = savedStreak.current
        entries = []
        wasTimed = isTimed
        gameDuration = nil
        gameStartedAt = .now
        questionStartedAt = .now
    }

    /// Marks when a new question is shown, so the summary can time each answer.
    mutating func startQuestion() {
        questionStartedAt = .now
    }

    /// Notes that the player turned the timer off, so the summary labels the round as untimed.
    mutating func noteTimerTurnedOff() {
        wasTimed = false
    }

    /// Refreshes the saved best, for example when the screen appears or the difficulty changes.
    mutating func syncSavedBest(from savedStreak: PersistentGameStreak) {
        savedBestStreak = savedStreak.best
    }

    /// Counts one answered question and updates the session and saved streaks.
    mutating func record(correct: Bool, savedStreak: PersistentGameStreak) {
        answered += 1
        if correct {
            score += 1
            streak += 1
            sessionBestStreak = max(sessionBestStreak, streak)
            let saved = savedStreak.recordWin()
            savedBestStreak = max(savedBestStreak, saved.best)
            savedCurrentStreak = saved.current
        } else {
            streak = 0
            savedStreak.reset()
            savedCurrentStreak = 0
        }
    }

    /// Counts one answered question like `record(correct:savedStreak:)` and keeps it, with the
    /// time taken since `startQuestion()`, for the end-of-round summary.
    mutating func record(_ entry: GameRoundEntry, savedStreak: PersistentGameStreak) {
        var entry = entry
        if let questionStartedAt {
            entry.duration = questionStartedAt.duration(to: .now)
        }
        questionStartedAt = nil
        entries.append(entry)
        record(correct: entry.outcome == .correct, savedStreak: savedStreak)
    }

    /// Stops the game clock. `finishGame(bestScoreKey:)` calls this; games without a saved
    /// best score call it directly when the last question is done.
    mutating func endGame() {
        if let gameStartedAt, gameDuration == nil {
            gameDuration = gameStartedAt.duration(to: .now)
        }
    }

    /// Ends the game and works out whether it beat the saved best score.
    mutating func finishGame(bestScoreKey: String, defaults: UserDefaults = .standard) {
        endGame()
        let previousBest = defaults.integer(forKey: bestScoreKey)
        isNewBestGame = score > previousBest
        bestGameScore = max(previousBest, score)
        if isNewBestGame {
            defaults.set(score, forKey: bestScoreKey)
        }
    }

    /// Clears the score and answered count, for Change Settings or an abandoned game.
    /// The streak is kept so the next game can continue it.
    mutating func clearGame() {
        score = 0
        answered = 0
        entries = []
        gameDuration = nil
        gameStartedAt = nil
        questionStartedAt = nil
    }

    /// Clears the session streak when the player leaves the screen.
    mutating func clearStreak() {
        streak = 0
        sessionBestStreak = 0
    }
}
