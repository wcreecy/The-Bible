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

    /// Starts a game. The score clears; the streak carries over from the last one.
    mutating func beginGame(savedStreak: PersistentGameStreak) {
        score = 0
        answered = 0
        isNewBestGame = false
        savedBestStreak = savedStreak.best
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
        } else {
            streak = 0
            savedStreak.reset()
        }
    }

    /// Ends the game and works out whether it beat the saved best score.
    mutating func finishGame(bestScoreKey: String, defaults: UserDefaults = .standard) {
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
    }

    /// Clears the session streak when the player leaves the screen.
    mutating func clearStreak() {
        streak = 0
        sessionBestStreak = 0
    }
}
