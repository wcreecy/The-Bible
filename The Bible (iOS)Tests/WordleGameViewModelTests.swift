import Foundation
import Testing
@testable import Bible

@MainActor
struct WordleGameViewModelTests {
    private let settingKeys = [
        "wordleMode",
        AppStorageKey.wordleHardModeEnabled,
        AppStorageKey.wordlePracticeWordBag,
        AppStorageKey.wordleLastPracticeWord,
        AppStorageKey.wordlePracticeProgress,
        AppStorageKey.wordleColorBlindMode,
        "wordlePersistentStreak_practice",
        "wordlePersistentBestStreak_practice"
    ]

    /// Runs `body` with a Practice round whose answer is GRACE, then restores the saved settings.
    private func withPracticeRound(_ body: (WordleGameViewModel) -> Void) {
        let saved = settingKeys.map { UserDefaults.standard.object(forKey: $0) }
        defer {
            for (key, value) in zip(settingKeys, saved) {
                UserDefaults.standard.set(value, forKey: key)
            }
        }

        UserDefaults.standard.removeObject(forKey: AppStorageKey.wordlePracticeProgress)
        let game = WordleGameViewModel()
        game.mode = .practice
        game.hardModeEnabled = false
        game.startNewRound(practice: true)
        game.target = "GRACE"
        // The round saved its drawn word on start; save again so a resumed round finds GRACE.
        game.saveProgress()
        body(game)
    }

    /// An answer that has a verse, so the verse hint is available, and isn't one of the
    /// words guessed before it.
    private var answerWithVerse: String? {
        WordleGameViewModel.verseIndex.keys.sorted().first { !["FAITH", "HEART", "LIGHT"].contains($0) }
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

    @Test
    func leavingAPracticeRoundResumesTheSameBoard() {
        withPracticeRound { game in
            guess("FAITH", in: game)

            // A new screen (as after leaving and coming back) picks the round back up.
            let returning = WordleGameViewModel()
            #expect(returning.hasRoundToResume(practice: true))
            returning.startNewRound(practice: true)
            #expect(returning.target == "GRACE")
            #expect(returning.rowIndex == 1)
            #expect(returning.guesses[0] == "FAITH")
        }
    }

    @Test
    func aPracticeRoundIsSavedBeforeTheFirstGuess() {
        withPracticeRound { game in
            let returning = WordleGameViewModel()
            #expect(returning.hasRoundToResume(practice: true))
            returning.startNewRound(practice: true)
            #expect(returning.target == game.target)
            #expect(returning.rowIndex == 0)
        }
    }

    @Test
    func finishingAPracticeRoundClearsItsSavedBoard() {
        withPracticeRound { game in
            guess("GRACE", in: game)
            #expect(game.roundOver)
            #expect(!WordleGameViewModel().hasRoundToResume(practice: true))
        }
    }

    @Test
    func changeSettingsReturnsToTheStartScreen() {
        withPracticeRound { game in
            guess("GRACE", in: game)
            game.returnToSetup()
            #expect(!game.started)
            #expect(!game.roundOver)
        }
    }

    // MARK: - Verse hint

    @Test
    func theVerseHintIsOfferedInPracticeAfterTheThirdGuess() throws {
        let answer = try #require(answerWithVerse)
        withPracticeRound { game in
            game.target = answer
            #expect(!game.isDailyRound)
            #expect(!game.canShowVerseHint)

            for word in ["FAITH", "HEART", "LIGHT"] {
                guess(word, in: game)
            }
            #expect(game.canShowVerseHint)

            game.showVerseHint()
            #expect(game.verseHintUsed)
            #expect(!game.canShowVerseHint)
            #expect(game.verseHint?.text.localizedCaseInsensitiveContains(answer) == false)
        }
    }

    @Test
    func theDailyNeverOffersTheVerseHint() throws {
        let answer = try #require(answerWithVerse)
        withPracticeRound { game in
            game.target = answer
            game.roundDayKey = "2026-11-20"
            for word in ["FAITH", "HEART", "LIGHT"] {
                guess(word, in: game)
            }
            #expect(game.isDailyRound)
            #expect(!game.canShowVerseHint)
            game.showVerseHint()
            #expect(!game.verseHintUsed)
            #expect(game.verseHint == nil)
        }
    }

    @Test
    func aWinWithTheVerseHintLeavesThePracticeStreakAsItWas() throws {
        let answer = try #require(answerWithVerse)
        withPracticeRound { game in
            game.target = answer
            let streakBefore = game.practicePersistentStreak.current
            for word in ["FAITH", "HEART", "LIGHT"] {
                guess(word, in: game)
            }
            game.showVerseHint()
            guess(answer, in: game)

            #expect(game.roundOver)
            #expect(game.didWin)
            #expect(game.practicePersistentStreak.current == streakBefore)
            #expect(game.practiceStreak == streakBefore)
        }
    }

    @Test
    func aWinWithoutTheHintAddsToThePracticeStreak() {
        withPracticeRound { game in
            let streakBefore = game.practicePersistentStreak.current
            guess("GRACE", in: game)
            #expect(game.practicePersistentStreak.current == streakBefore + 1)
        }
    }

    @Test
    func aResumedRoundRemembersTheVerseHint() throws {
        let answer = try #require(answerWithVerse)
        withPracticeRound { game in
            game.target = answer
            game.saveProgress()
            for word in ["FAITH", "HEART", "LIGHT"] {
                guess(word, in: game)
            }
            game.showVerseHint()

            let resumed = WordleGameViewModel()
            resumed.mode = .practice
            resumed.startNewRound(practice: true)
            #expect(resumed.verseHintUsed)
            #expect(resumed.rowIndex == 3)
        }
    }

    @Test
    func blankingOutCoversTheWordAndLongerFormsOnly() {
        let text = WordleGameViewModel.blankingOut("PRAY", in: "Pray always; he prayed. Spray it.")
        #expect(text == "____ always; he ______. Spray it.")
    }

    // MARK: - Color-blind mode and Daily results

    @Test
    func colorBlindModeChangesTheShareGrid() {
        #expect(WordleKeyState.correct.emoji(colorBlind: false) == "🟩")
        #expect(WordleKeyState.present.emoji(colorBlind: false) == "🟨")
        #expect(WordleKeyState.correct.emoji(colorBlind: true) == "🟧")
        #expect(WordleKeyState.present.emoji(colorBlind: true) == "🟦")
        #expect(WordleKeyState.absent.emoji(colorBlind: true) == "⬛")
    }

    @Test
    func dailyResultsReadTheSavedMap() throws {
        let defaults = try #require(UserDefaults(suiteName: "WordleDailyResultsTests"))
        defer { defaults.removePersistentDomain(forName: "WordleDailyResultsTests") }
        let json = #"{"2026-11-19":{"won":true,"guesses":4,"elapsed":95,"word":"GRACE"},"2026-11-18":{"won":false,"guesses":6,"elapsed":300,"word":"MERCY"}}"#
        defaults.set(Data(json.utf8), forKey: AppStorageKey.wordleDailyResultMap)

        let results = WordleGameViewModel.dailyResults(defaults: defaults)
        #expect(results["2026-11-19"] == WordleDailyResult(won: true, guesses: 4, elapsed: 95, word: "GRACE"))
        #expect(results["2026-11-18"]?.won == false)
        #expect(results.count == 2)
    }
}
