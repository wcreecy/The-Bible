import Foundation
import Testing
@testable import Bible

@Suite(.serialized)
@MainActor
struct ScrambleGameViewModelTests {
    private let settingKeys = ["scrambleDifficulty", "scrambleSessionLength", "scramblePracticeMode"]

    /// Runs `body` with a Normal, 5-word game, then puts back every default it changed
    /// (settings, stats, streaks and word history). Missed words go to an in-memory store.
    private func withNormalGame(
        missed: MissedGameQuestionStore? = nil,
        isEnglishWord: @escaping (String) -> Bool = { _ in false },
        verseText: String? = nil,
        _ body: (ScrambleGameViewModel, ManualSleeper) async -> Void
    ) async {
        let before = UserDefaults.standard.dictionaryRepresentation()
        defer {
            let defaults = UserDefaults.standard
            let after = defaults.dictionaryRepresentation()
            for key in Set(before.keys).union(after.keys) {
                let old = before[key].map { $0 as AnyObject }
                let new = after[key].map { $0 as AnyObject }
                guard old?.isEqual(new) != true else { continue }
                if let old { defaults.set(old, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
        }

        let clock = ManualSleeper()
        let game = ScrambleGameViewModel(
            missedQuestions: missed ?? MissedGameQuestionStore(entries: []),
            sleep: clock.sleep(for:),
            now: { clock.date },
            isEnglishWord: isEnglishWord,
            loadVerseText: { _ in verseText }
        )
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
                game.shuffledLetters[$0] == letter && !game.usedTileIndices.contains($0)
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

    /// A Hard game whose current word is `word`, outside a session, with settings put back after.
    private func withHardWord(_ word: String, _ body: (ScrambleGameViewModel) -> Void) {
        // Loading a word records it in the word history, so that's put back too.
        let keys = ["scrambleDifficulty", AppStorageKey.gameQuestionRecency]
        let saved = keys.map { UserDefaults.standard.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, saved) {
                if let value { UserDefaults.standard.set(value, forKey: key) } else { UserDefaults.standard.removeObject(forKey: key) }
            }
        }

        let game = ScrambleGameViewModel(missedQuestions: MissedGameQuestionStore(entries: []), loadVerseText: { _ in nil })
        game.difficulty = .hard
        game.deck = [ScrambleGameViewModel.ScrambleWord(
            ScrambleWordEntry(word: word, category: "Roles", difficulty: "hard", reference: nil)
        )!]
        game.loadNextWord()
        body(game)
    }

    @Test
    func hardHintsPlaceTheOpeningThenADifferentInteriorLetter() {
        withHardWord("Shepherd") { game in
            let answer = Array(game.currentWord!.answer)
            // Eight letters allow two hints, one per three letters.
            #expect(game.maxHintLevel == 2)

            game.showHint()
            #expect(game.hintLevel == 1)
            #expect(game.hintPositions == [0])
            #expect(game.placedLetters[0] == answer[0])

            game.showHint()
            game.showHint()
            #expect(game.hintLevel == 2)
            #expect(game.hintPositions.count == 2)
            for position in game.hintPositions {
                #expect(position < answer.count - 1)
                #expect(game.hintedLetters[position] == answer[position])
                #expect(game.placedLetters[position] == answer[position])
            }

            game.recordWordResult(.correct, givenAnswer: String(answer))
            #expect(game.session.entries.last?.hintCount == 2)
        }
    }

    @Test
    func shortHardWordsGetOneHint() {
        withHardWord("Isaac") { game in
            #expect(game.maxHintLevel == 1)
        }
    }

    @Test
    func aHintSendsAWrongLetterBackAndKeepsItsGhostWhenRemoved() {
        withHardWord("Moses") { game in
            // Put a letter other than M in the first square.
            let wrong = game.shuffledLetters.indices.first { game.shuffledLetters[$0] != "M" }!
            game.placeTile(wrong, at: 0)

            game.showHint()
            #expect(game.placedLetters[0] == "M")
            #expect(!game.usedTileIndices.contains(wrong))

            game.returnToTray(0)
            #expect(game.placedLetters[0] == nil)
            #expect(game.hintedLetters[0] == "M")
        }
    }

    @Test
    func aHintTakesItsLetterFromASquareWhereItIsWrong() {
        withHardWord("Moses") { game in
            let m = game.shuffledLetters.firstIndex(of: "M")!
            game.placeTile(m, at: 3)

            game.showHint()
            #expect(game.placedLetters[0] == "M")
            #expect(game.placedLetters[3] == nil)
        }
    }

    @Test
    func practiceModeRemovesThePerWordTimer() {
        let game = ScrambleGameViewModel()
        game.difficulty = .hard
        game.isPracticeMode = true

        #expect(game.currentTimeLimit == nil)
    }

    // MARK: - Anagrams, leaving, pausing and rotation

    /// A game whose only word is EARTH, with HEART and HATER as other answers on the list.
    private func withEarthGame(
        isEnglishWord: @escaping (String) -> Bool = { _ in false },
        _ body: (ScrambleGameViewModel, ManualSleeper) async -> Void
    ) async {
        await withNormalGame(isEnglishWord: isEnglishWord) { game, clock in
            game.wordBank = [
                ScrambleWordEntry(word: "Earth", category: "Creation", difficulty: "normal", reference: "Genesis 1:1"),
                ScrambleWordEntry(word: "Heart", category: "Faith", difficulty: "hard", reference: "Proverbs 3:5")
            ].compactMap(ScrambleGameViewModel.ScrambleWord.init)
            await body(game, clock)
        }
    }

    @Test
    func anotherListWordFromTheSameLettersIsAccepted() async {
        await withEarthGame { game, _ in
            game.startSession()
            #expect(game.currentWord?.answer == "EARTH")

            type("HEART", into: game)
            game.checkAnswer()
            #expect(game.answerFeedback == .correct)
            #expect(game.acceptedAlternate == "HEART")
            #expect(game.session.score == 1)
            // The word and its reference stay the puzzle's own.
            #expect(game.currentWord?.reference == "Genesis 1:1")
            #expect(game.session.entries.last?.givenAnswer == "HEART")
            #expect(game.session.entries.last?.correctAnswer == "EARTH")
        }
    }

    @Test
    func anyRealEnglishWordFromTheSameLettersIsAccepted() async {
        await withEarthGame(isEnglishWord: { $0 == "HATER" }) { game, _ in
            game.startSession()
            type("HATER", into: game)
            game.checkAnswer()
            #expect(game.answerFeedback == .correct)
            #expect(game.acceptedAlternate == "HATER")
        }
    }

    @Test
    func aNonWordFromTheSameLettersIsStillWrong() async {
        await withEarthGame { game, _ in
            game.startSession()
            type("TRAEH", into: game)
            game.checkAnswer()
            #expect(game.answerFeedback == .incorrect)
            #expect(game.strikes == 1)
        }
    }

    @Test
    func theScrambleNeverAlreadySpellsAnAcceptedWord() async {
        await withEarthGame(isEnglishWord: { $0 == "HATER" }) { game, _ in
            for _ in 0..<200 {
                let tiles = String(game.scrambledLetters(for: "EARTH"))
                #expect(tiles.sorted() == "EARTH".sorted())
                #expect(!["EARTH", "HEART", "HATER"].contains(tiles))
            }
        }
    }

    @Test
    func leavingATimedWordCountsAsTimeUp() async {
        let missed = MissedGameQuestionStore(entries: [])
        await withNormalGame(missed: missed) { game, _ in
            game.startSession()
            let answer = try! #require(game.currentWord?.answer)

            game.onDisappear()
            #expect(game.phase == .setup)
            #expect(missed.containsMiss(game: .scramble, questionID: answer))
        }
    }

    @Test
    func leavingAPracticeWordCostsNothing() async {
        let missed = MissedGameQuestionStore(entries: [])
        await withNormalGame(missed: missed) { game, _ in
            game.isPracticeMode = true
            game.startSession()
            let answer = try! #require(game.currentWord?.answer)

            game.onDisappear()
            #expect(game.phase == .setup)
            #expect(!missed.containsMiss(game: .scramble, questionID: answer))
        }
    }

    @Test
    func pausingDoesNotGiveBackPartOfASecond() async {
        await withNormalGame { game, clock in
            game.startSession()
            let timer = Task { await game.runTimer() }

            // Play 0.9 seconds of each second, pausing just before it would tick. With the old
            // timer each resume restarted a full second, so the clock never moved.
            for _ in 0..<10 {
                await clock.advance(by: 0.9)
                game.isPaused = true
                game.isPaused = false
            }
            timer.cancel()

            let resumed = Task { await game.runTimer() }
            await clock.advance(by: 0.1)
            // 9 seconds have been played in all.
            #expect(game.timeRemaining == 30 - 9)
            resumed.cancel()
        }
    }

    @Test
    func everyWordAtADifficultyComesUpBeforeAnyRepeats() async {
        await withNormalGame { game, _ in
            UserDefaults.standard.removeObject(forKey: AppStorageKey.gameQuestionRecency)
            game.isPracticeMode = true
            game.wordBank = ["Moses", "Aaron", "Miriam", "Joshua", "Caleb", "Gideon", "Samson", "Samuel", "Saul", "David"]
                .map { ScrambleWordEntry(word: $0, category: "People", difficulty: "normal", reference: nil) }
                .compactMap(ScrambleGameViewModel.ScrambleWord.init)

            // Two 5-word games cover all ten words without a repeat.
            var asked: [String] = []
            for _ in 0..<2 {
                game.startSession()
                while game.phase == .playing, let word = game.currentWord {
                    asked.append(word.answer)
                    game.revealAnswer()
                    game.loadNextWord()
                }
            }
            #expect(asked.count == 10)
            #expect(Set(asked).count == 10)
        }
    }

    // MARK: - Placing letters

    @Test
    func aTrayTapFillsTheFirstEmptySquare() async {
        await withNormalGame { game, _ in
            game.startSession()
            game.selectLetter(2)
            game.selectLetter(0)
            #expect(game.slots.prefix(2) == [2, 0])
            #expect(game.slots.dropFirst(2).allSatisfy { $0 == nil })
        }
    }

    @Test
    func choosingAnEmptySquareSendsTheNextLetterThere() async {
        await withNormalGame { game, _ in
            game.startSession()
            game.tapSquare(3)
            #expect(game.cursorPosition == 3)

            game.selectLetter(0)
            #expect(game.slots[3] == 0)
            // The cursor moves on to the next empty square.
            #expect(game.cursorPosition == 4)
        }
    }

    @Test
    func pickingUpALetterAndDroppingItOnAnotherSwapsThem() async {
        await withNormalGame { game, _ in
            game.startSession()
            game.selectLetter(0)
            game.selectLetter(1)

            game.tapSquare(0)
            #expect(game.heldTile == .slot(0))
            game.tapSquare(1)
            #expect(game.heldTile == nil)
            #expect(game.slots.prefix(2) == [1, 0])

            // Moving to an empty square leaves the old one empty.
            game.moveLetter(from: 0, to: 4)
            #expect(game.slots[0] == nil)
            #expect(game.slots[4] == 1)
        }
    }

    @Test
    func aHeldLetterGoesBackToTheTrayWhenTheTrayIsTapped() async {
        await withNormalGame { game, _ in
            game.startSession()
            game.selectLetter(0)
            game.selectLetter(1)
            game.tapSquare(0)

            game.selectLetter(2)
            #expect(game.slots[0] == nil)
            // The tapped tile isn't placed; the tap only put the held letter back.
            #expect(!game.usedTileIndices.contains(2))
        }
    }

    @Test
    func undoPutsBackEachMoveInTurn() async {
        await withNormalGame { game, _ in
            game.startSession()
            game.selectLetter(0)
            game.selectLetter(1)
            game.moveLetter(from: 0, to: 1)

            game.undo()
            #expect(game.slots.prefix(2) == [0, 1])
            game.undo()
            game.undo()
            #expect(!game.hasPlacedLetters)
            #expect(!game.canUndo)
        }
    }

    @Test
    func deleteClearsTheLastLetterBeforeTheCursor() async {
        await withNormalGame { game, _ in
            game.startSession()
            game.placeTile(0, at: 0)
            game.placeTile(1, at: 3)

            game.deleteBackward()
            #expect(game.slots[3] == nil)
            game.deleteBackward()
            #expect(!game.hasPlacedLetters)
        }
    }

    @Test
    func anAnswerWithAGapCannotBeChecked() async {
        await withNormalGame { game, _ in
            game.startSession()
            let answer = try! #require(game.currentWord?.answer)
            type(answer, into: game)
            game.returnToTray(1)

            #expect(!game.canCheckAnswer)
            game.checkAnswer()
            #expect(game.answerFeedback == nil)
        }
    }

    @Test
    func revealingFillsTheSquaresWithTheWord() async {
        await withNormalGame { game, _ in
            game.startSession()
            let answer = try! #require(game.currentWord?.answer)
            game.placeTile(0, at: 2)

            game.revealAnswer()
            #expect(game.typedAnswer == answer)
            #expect(game.usedTileIndices.count == answer.count)
        }
    }

    // MARK: - Verse clue

    @Test
    func theVerseClueBlanksTheWordAndCountsAsAHint() async {
        await withNormalGame(verseText: "And the child grew, and he called his name Moses.") { game, _ in
            game.wordBank = [
                ScrambleWordEntry(word: "Moses", category: "People", difficulty: "normal", reference: "Exodus 2:10")
            ].compactMap(ScrambleGameViewModel.ScrambleWord.init)
            game.startSession()
            await game.loadVerse()
            #expect(game.displayedVerse == nil)

            game.showVerseClue()
            #expect(game.displayedVerse?.isClue == true)
            #expect(game.displayedVerse?.text == "And the child grew, and he called his name _____.")

            game.revealAnswer()
            // Once the word is over, the whole verse shows.
            #expect(game.displayedVerse?.text.hasSuffix("Moses.") == true)
            #expect(game.session.entries.last?.hintCount == 1)
        }
    }

    @Test
    func blankingIgnoresCase() {
        let text = ScrambleGameViewModel.blankingOut("LORD", in: "The Lord is my shepherd; the lordship")
        #expect(text == "The ____ is my shepherd; the ____ship")
    }
}
