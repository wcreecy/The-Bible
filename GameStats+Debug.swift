#if DEBUG
import Foundation

extension GameStats {
    // Seeds random stats across all games and difficulties.
    // Each call simulates a handful of rounds per game using the same write API the games use.
    // It will also update daily maps and "last played" keys via recordRound.
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

        // Hangman (easy/medium/hard)
        for _ in 0..<roundsPerGame {
            let diffs: [Difficulty] = [.easy, .medium, .hard]
            let d = diffs.randomElement() ?? .easy
            let r = rollRound(maxQ: 10)
            recordRound(game: .hangman, difficulty: d, correct: r.correct, answered: r.answered, currentBestStreak: r.bestStreak)
        }

        // Beat the Clock (easy/medium/hard)
        for _ in 0..<roundsPerGame {
            let diffs: [Difficulty] = [.easy, .medium, .hard]
            let d = diffs.randomElement() ?? .easy
            let r = rollRound(maxQ: 15)
            recordRound(game: .beatclock, difficulty: d, correct: r.correct, answered: r.answered, currentBestStreak: r.bestStreak)
        }

        // Verse Match (easy/medium/hard)
        for _ in 0..<roundsPerGame {
            let diffs: [Difficulty] = [.easy, .medium, .hard]
            let d = diffs.randomElement() ?? .easy
            let r = rollRound(maxQ: 10)
            recordRound(game: .refmatch, difficulty: d, correct: r.correct, answered: r.answered, currentBestStreak: r.bestStreak)
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
    }
}
#endif
