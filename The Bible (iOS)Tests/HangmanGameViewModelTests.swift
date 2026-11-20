import Foundation
import Testing
@testable import Bible

@Suite(.serialized)
@MainActor
struct HangmanGameViewModelTests {
    /// Runs `body` with a game at `difficulty`, then puts back every default it changed
    /// (settings, stats, streaks and word history). Missed words go to an in-memory store.
    private func withGame(
        difficulty: HangmanDifficulty = .normal,
        missed: MissedGameQuestionStore? = nil,
        verses: [HangmanVerse] = [],
        _ body: (HangmanGameViewModel) async -> Void
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

        let game = HangmanGameViewModel(
            missedQuestions: missed ?? MissedGameQuestionStore(entries: []),
            loadVerses: { _ in verses }
        )
        game.difficulty = difficulty
        await body(game)
    }

    private func word(
        _ answer: String,
        category: HangmanTheme = .people,
        reference: String? = "Exodus 2:10"
    ) -> HangmanWord {
        HangmanWord(answer: answer, category: category, clue: "A clue", qualifier: nil, reference: reference)
    }

    @Test
    func guessesReportWhatHappened() async {
        await withGame { game in
            game.startGame(with: [word("Moses")])
            #expect(game.guess("m") == .correct)
            #expect(game.guess("M") == .alreadyGuessed)
            #expect(game.guess("z") == .wrong)
            #expect(game.guess("1") == .ignored)
            #expect(game.wrongGuesses == 1)
        }
    }

    @Test
    func findingEveryLetterWinsAndRunningOutLoses() async {
        let missed = MissedGameQuestionStore(entries: [])
        await withGame(missed: missed) { game in
            game.startGame(with: [word("Abel"), word("Noah")])
            for letter in "NOAH" { game.guess(letter) }
            #expect(game.roundOver && game.didWin)

            game.nextWord()
            for letter in "ZXQWVJ" { game.guess(letter) }
            #expect(game.roundOver && !game.didWin)
            #expect(missed.containsMiss(game: .hangman, questionID: "ABEL"))
            #expect(game.guess("A") == .ignored)
        }
    }

    @Test
    func theWordShowsAsSquaresSplitAtSpaces() async {
        await withGame { game in
            game.startGame(with: [word("John Mark")])
            game.guess("o")

            let letters = game.displayLetters
            #expect(letters.count == 9)
            #expect(letters[1] == HangmanDisplayLetter(character: "O", state: .found))
            #expect(letters[0].state == .hidden)
            #expect(letters[4].state == .punctuation)

            game.giveUp()
            #expect(game.displayLetters[0].state == .missed)
        }
    }

    @Test
    func aLetterHintFillsALetterForAMistake() async {
        await withGame { game in
            game.startGame(with: [word("Moses")])
            game.revealLetter()

            #expect(game.wrongGuesses == 1)
            #expect(game.hintedLetters.count == 1)
            let hinted = try! #require(game.hintedLetters.first)
            #expect("MOSE".contains(hinted))
            #expect(game.displayLetters.contains { $0.state == .hinted })
        }
    }

    @Test
    func aLetterHintNeverFinishesTheWord() async {
        await withGame { game in
            game.startGame(with: [word("Moses")])
            for letter in "MOS" { game.guess(letter) }
            // Only E is left, so a hint would solve it.
            #expect(!game.canRevealLetter)
        }
    }

    @Test
    func hardHasNoLetterHints() async {
        await withGame(difficulty: .hard) { game in
            game.startGame(with: [word("Moses")])
            #expect(!game.canRevealLetter)
        }
    }

    @Test
    func theVerseClueBlanksTheNameAndCostsMistakesByDifficulty() async {
        let verse = HangmanVerse(reference: "Exodus 2:10", text: "And she called his name Moses: and she said...")
        await withGame(difficulty: .hard, verses: [verse]) { game in
            game.startGame(with: [word("Moses")])
            await game.loadVerse()
            #expect(game.displayedVerse == nil)
            #expect(game.canShowVerseClue)

            game.showVerseClue()
            #expect(game.wrongGuesses == 2)
            #expect(game.displayedVerse?.text == "And she called his name _____: and she said...")

            game.giveUp()
            // After the round, the whole verse shows, and the clue counts as a hint.
            #expect(game.displayedVerse?.isClue == false)
            #expect(game.session.entries.last?.hintCount == 1)
        }
    }

    @Test
    func aVerseThatDoesNotNameTheAnswerIsNotUsed() async {
        let verse = HangmanVerse(reference: "Exodus 2:11", text: "And it came to pass in those days...")
        await withGame(verses: [verse]) { game in
            game.startGame(with: [word("Moses")])
            await game.loadVerse()
            #expect(game.verse == nil)
            #expect(!game.canShowVerseClue)
        }
    }

    @Test
    func theVersesThemeShowsTheVerseFreeFromTheStart() async {
        let verse = HangmanVerse(reference: "Matthew 6:9", text: "After this manner therefore pray ye")
        await withGame(verses: [verse]) { game in
            game.startGame(with: [word("Pray", category: .verses)])
            await game.loadVerse()

            #expect(game.displayedVerse?.text == "After this manner therefore ____ ye")
            #expect(game.wrongGuesses == 0)
            #expect(game.hintsUsed == 0)
        }
    }

    @Test
    func aVersesWordWithoutAVerseShowsItsDescriptionInstead() async {
        await withGame(difficulty: .hard) { game in
            game.startGame(with: [word("Pray", category: .verses)])
            #expect(!game.showsClue)
            await game.loadVerse()
            #expect(game.showsClue)
        }
    }

    @Test
    func namesAreBlankedAsWholeWordsAndOtherWordsWithTheirEndings() {
        let name = word("Eve")
        #expect(name.blankingOut(in: "Eve was even there") == "___ was even there")

        let multiWord = word("Herod Agrippa I")
        #expect(multiWord.blankingOut(in: "Then Agrippa said") == "Then _______ said")

        let bibleWord = word("Pray", category: .bibleWords)
        #expect(bibleWord.blankingOut(in: "He prayed and prays") == "He ______ and _____")
    }

    @Test
    func cluesNeverCostTheLastMistake() async {
        await withGame { game in
            game.startGame(with: [word("Moses")])
            for letter in "ZXQWV" { game.guess(letter) }
            // One mistake is left on Normal.
            #expect(game.isOneGuessRemaining)
            #expect(!game.canRevealClue)
            #expect(!game.canRevealLetter)
        }
    }

    @Test
    func peopleKeepTheirScriptureReferences() async {
        let people = await GameDataLoaders.loadCharactersAsync()
        #expect(!people.isEmpty)
        #expect(people.allSatisfy { $0.scriptureReferences?.isEmpty == false })
    }
}
