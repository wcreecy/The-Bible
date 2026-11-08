import Foundation
import Testing
@testable import Bible

@MainActor
struct ScrambleGameViewModelTests {
    private let settingKeys = ["scrambleDifficulty", "scrambleSessionLength", "scramblePracticeMode"]

    /// Runs `body` with a Normal, 5-word game, then restores the saved Scramble settings.
    private func withNormalGame(_ body: (ScrambleGameViewModel, ManualSleeper) async -> Void) async {
        let saved = settingKeys.map { UserDefaults.standard.object(forKey: $0) }
        defer {
            for (key, value) in zip(settingKeys, saved) {
                UserDefaults.standard.set(value, forKey: key)
            }
        }

        let clock = ManualSleeper()
        let game = ScrambleGameViewModel(sleep: clock.sleep(for:))
        game.difficulty = .normal
        game.sessionLength = .short
        game.isPracticeMode = false
        game.wordBank = [
            ScrambleWordEntry(word: "Moses", category: "People", difficulty: "normal", reference: "Exodus 2:10"),
            ScrambleWordEntry(word: "Bethel", category: "Places", difficulty: "normal", reference: nil),
            ScrambleWordEntry(word: "Ark", category: "Things", difficulty: "easy", reference: nil)
        ].compactMap(ScrambleGameViewModel.ScrambleWord.init)
        game.wordBankStatus = .ready
        await body(game, clock)
    }

    private func type(_ answer: String, into game: ScrambleGameViewModel) {
        for letter in answer {
            let index = game.shuffledLetters.indices.first {
                game.shuffledLetters[$0] == letter && !game.selectedIndices.contains($0)
            }
            if let index { game.selectLetter(index) }
        }
    }

    @Test
    func aSessionUsesOnlyWordsAtTheChosenDifficulty() async {
        await withNormalGame { game, _ in
            game.startSession()

            #expect(game.phase == .playing)
            #expect(game.currentNumber == 1)
            // Two Normal words; the Easy one is left out.
            #expect(game.deck.count == 1)
            #expect(game.currentWord?.answer != "ARK")
            #expect(game.timeRemaining == 30)
        }
    }

    @Test
    func aCorrectAnswerScoresAndMovesToTheNextWord() async {
        await withNormalGame { game, clock in
            game.startSession()
            let answer = try! #require(game.currentWord?.answer)

            type(answer, into: game)
            game.checkAnswer()
            #expect(game.answerFeedback == .correct)
            #expect(game.session.score == 1)

            // A solved word waits for Next Word; the delayed advance doesn't skip it.
            await clock.advance(by: 0.55)
            #expect(game.currentNumber == 1)

            game.loadNextWord()
            #expect(game.currentNumber == 2)
            #expect(game.answerFeedback == nil)
        }
    }

    @Test
    func aWrongAnswerCanBeRetried() async {
        await withNormalGame { game, _ in
            game.startSession()
            let answer = try! #require(game.currentWord?.answer)

            type(String(answer.reversed()), into: game)
            game.checkAnswer()

            #expect(game.answerFeedback == .incorrect)
            #expect(game.isCurrentWordResolved == false)
            #expect(game.session.answered == 0)
        }
    }

    @Test
    func theTimerRevealsTheAnswerWhenItRunsOut() async {
        await withNormalGame { game, clock in
            game.startSession()
            let answer = try! #require(game.currentWord?.answer)
            let timer = Task { await game.runTimer() }

            for _ in 0..<29 { await clock.advance(by: 1) }
            #expect(game.timeRemaining == 1)
            #expect(game.answerFeedback == nil)

            await clock.advance(by: 1)
            #expect(game.answerFeedback == .timedOut)
            #expect(game.typedAnswer == answer)
            #expect(game.session.answered == 1)
            timer.cancel()
        }
    }

    @Test
    func pausingStopsTheClock() async {
        await withNormalGame { game, clock in
            game.startSession()
            game.isPaused = true
            await game.runTimer()

            await clock.advance(by: 5)
            #expect(game.timeRemaining == 30)
        }
    }

    @Test
    func hardHintsRevealTheOpeningThenTwoDifferentInteriorLetters() {
        let savedDifficulty = UserDefaults.standard.object(forKey: "scrambleDifficulty")
        defer { UserDefaults.standard.set(savedDifficulty, forKey: "scrambleDifficulty") }

        let game = ScrambleGameViewModel()
        game.difficulty = .hard
        let word = ScrambleWordEntry(
            word: "Shepherd",
            category: "Roles",
            difficulty: "hard",
            reference: nil
        )
        game.currentWord = ScrambleGameViewModel.ScrambleWord(word)

        game.showHint()

        #expect(game.hintLevel == 1)
        #expect(game.hintPositions.isEmpty)
        #expect(game.hintedLetters.first! == game.currentWord?.answer.first)

        game.showHint()
        game.showHint()

        let answer = try! #require(game.currentWord?.answer)
        #expect(game.hintLevel == 3)
        #expect(game.hintPositions.count == 2)
        for position in game.hintPositions {
            #expect(position > 0)
            #expect(position < answer.count - 1)
            #expect(game.hintedLetters[position] != nil)
        }

        game.recordWordResult(.correct, givenAnswer: answer)
        #expect(game.session.entries.last?.hintCount == 3)
    }

    @Test
    func practiceModeRemovesThePerWordTimer() {
        let game = ScrambleGameViewModel()
        game.difficulty = .hard
        game.isPracticeMode = true

        #expect(game.currentTimeLimit == nil)
    }
}
