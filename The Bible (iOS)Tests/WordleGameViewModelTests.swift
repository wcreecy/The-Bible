import Foundation
import Testing
@testable import Bible

@MainActor
struct WordleGameViewModelTests {
    private let settingKeys = [
        "wordleMode",
        AppStorageKey.wordleHardModeEnabled,
        AppStorageKey.wordlePracticeWordBag,
        AppStorageKey.wordleLastPracticeWord
    ]

    /// Runs `body` with a Practice round whose answer is GRACE, then restores the saved settings.
    private func withPracticeRound(_ body: (WordleGameViewModel) -> Void) {
        let saved = settingKeys.map { UserDefaults.standard.object(forKey: $0) }
        defer {
            for (key, value) in zip(settingKeys, saved) {
                UserDefaults.standard.set(value, forKey: key)
            }
        }

        let game = WordleGameViewModel()
        game.mode = .practice
        game.hardModeEnabled = false
        game.startNewRound(practice: true)
        game.target = "GRACE"
        body(game)
    }

    private func guess(_ word: String, in game: WordleGameViewModel) {
        word.forEach(game.tapLetter)
        game.submitGuess()
    }

    @Test
    func aNewRoundStartsWithAnEmptyBoard() {
        withPracticeRound { game in
            #expect(game.started)
            #expect(game.rowIndex == 0)
            #expect(game.guesses.allSatisfy { $0.isEmpty })
            #expect(!game.roundOver)
        }
    }

    @Test
    func solvingTheWordEndsTheRoundAsAWin() {
        withPracticeRound { game in
            guess("FAITH", in: game)
            #expect(game.rowIndex == 1)
            #expect(!game.roundOver)

            guess("GRACE", in: game)
            #expect(game.roundOver)
            #expect(game.didWin)
            #expect(game.evaluations[1] == Array(repeating: .correct, count: 5))
        }
    }

    @Test
    func aGuessThatIsNotAWordIsRejectedWithoutUsingARow() {
        withPracticeRound { game in
            guess("XQZVB", in: game)
            #expect(game.message == "Not in word list")
            #expect(game.rowIndex == 0)
        }
    }

    @Test
    func sixMissesEndTheRoundAsALoss() {
        withPracticeRound { game in
            for word in ["FAITH", "HEART", "LIGHT", "PEACE", "MERCY", "GLORY"] {
                guess(word, in: game)
            }
            #expect(game.roundOver)
            #expect(!game.didWin)
            #expect(game.message == "Out of guesses.")
        }
    }
}
