import Foundation
import Testing
@testable import Bible

/// Trivia: leaving mid-question and the saved difficulty. Missed questions and pool progress
/// go to in-memory stores, and every default the game writes is put back when each test ends.
@Suite(.serialized)
@MainActor
struct BibleTriviaGameModelTests {
    /// Runs `body`, then puts back every default it added, changed or removed.
    private func withRestoredDefaults(_ body: () async throws -> Void) async rethrows {
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
        try await body()
    }

    @Test func leavingMidQuestionCountsAsTimeUp() async throws {
        try await withRestoredDefaults {
            let missed = MissedGameQuestionStore(entries: [])
            let progress = BibleTriviaProgressStore(inMemory: [:])
            let game = BibleTriviaGameModel(missedQuestions: missed, progressStore: progress)
            await game.load()
            game.startRound()
            let question = try #require(game.currentQuestion)

            game.onDisappear()
            // The unanswered question is recorded as missed and as asked, and the game ends.
            #expect(game.phase == .setup)
            #expect(missed.containsMiss(game: .bibleTrivia, questionID: String(question.id)))
            #expect(progress.progress(for: game.difficulty).completedQuestionIDs.contains(question.id))
        }
    }

    @Test func theChosenDifficultyIsRemembered() async {
        await withRestoredDefaults {
            BibleTriviaGameModel(progressStore: BibleTriviaProgressStore(inMemory: [:])).difficulty = .hard
            #expect(BibleTriviaGameModel(progressStore: BibleTriviaProgressStore(inMemory: [:])).difficulty == .hard)
        }
    }

    // MARK: - Playing a round

    private static let passage = GamePassage(
        bookName: "Genesis",
        chapter: 6,
        verses: [
            .init(number: 13, text: "And God said unto Noah, The end of all flesh is come before me"),
            .init(number: 14, text: "Make thee an ark of gopher wood")
        ],
        isTruncated: true
    )

    /// A loaded Normal game on the manual clock, with in-memory stores, and defaults put back after.
    private func withGame(
        difficulty: BibleTriviaDifficulty = .normal,
        topic: BibleTriviaTopic = .mixed,
        missed: MissedGameQuestionStore? = nil,
        progress: BibleTriviaProgressStore? = nil,
        _ body: (BibleTriviaGameModel, ManualSleeper) async throws -> Void
    ) async throws {
        try await withRestoredDefaults {
            let clock = ManualSleeper()
            let game = BibleTriviaGameModel(
                missedQuestions: missed ?? MissedGameQuestionStore(entries: []),
                progressStore: progress ?? BibleTriviaProgressStore(inMemory: [:]),
                sleep: clock.sleep(for:),
                now: { clock.date },
                loadPassage: { _ in Self.passage }
            )
            game.difficulty = difficulty
            game.topic = topic
            await game.load()
            try await body(game, clock)
        }
    }

    private func wrongAnswer(in game: BibleTriviaGameModel) -> String {
        game.options.first { $0 != game.currentQuestion?.correctAnswer && !game.removedOptions.contains($0) }!
    }

    @Test func aCorrectAnswerScoresAndAWrongOneIsRecordedAsMissed() async throws {
        let missed = MissedGameQuestionStore(entries: [])
        try await withGame(missed: missed) { game, _ in
            game.startRound()
            game.choose(try #require(game.currentQuestion?.correctAnswer))
            #expect(game.session.score == 1)

            game.advance()
            let question = try #require(game.currentQuestion)
            game.choose(wrongAnswer(in: game))
            #expect(game.session.score == 1)
            #expect(game.session.answered == 2)
            #expect(missed.containsMiss(game: .bibleTrivia, questionID: String(question.id)))
        }
    }

    @Test func theTimerRunsOutAndPausingStopsIt() async throws {
        try await withGame { game, clock in
            game.startRound()
            await clock.advance(by: 5)
            #expect(game.remainingSeconds == 10)

            game.pause()
            await clock.advance(by: 30)
            game.resume()
            await clock.advance(by: 0.1)
            #expect(game.remainingSeconds == 10)

            await clock.advance(by: 10)
            #expect(game.timedOut)
        }
    }

    @Test func extraTimeAddsTenSecondsOncePerRound() async throws {
        try await withGame { game, clock in
            game.startRound()
            await clock.advance(by: 5)
            game.use(.extraTime)
            #expect(game.remainingSeconds == 20)
            #expect(!game.canUse(.extraTime))

            game.choose(wrongAnswer(in: game))
            game.advance()
            #expect(!game.canUse(.extraTime))
        }
    }

    @Test func easyHasNoExtraTime() async throws {
        try await withGame(difficulty: .easy) { game, _ in
            game.startRound()
            #expect(!game.offers(.extraTime))
            #expect(!game.canUse(.extraTime))
        }
    }

    @Test func fiftyFiftyRemovesTwoWrongAnswers() async throws {
        try await withGame { game, _ in
            game.startRound()
            let correct = try #require(game.currentQuestion?.correctAnswer)
            game.use(.fiftyFifty)

            #expect(game.removedOptions.count == 2)
            #expect(!game.removedOptions.contains(correct))
            // A removed answer can't be chosen.
            game.choose(try #require(game.removedOptions.first))
            #expect(!game.isAnswered)
        }
    }

    @Test func theVerseHintBlanksTheAnswerAndCountsAsAHint() async throws {
        try await withGame { game, _ in
            game.startRound()
            #expect(!game.canUse(.verseHint))
            await game.loadPassage()
            game.use(.verseHint)

            let hint = try #require(game.displayedVerse)
            #expect(hint.isClue)
            #expect(hint.reference == "Genesis 6:13")

            game.choose(try #require(game.currentQuestion?.correctAnswer))
            // After answering, the passage shows in full.
            #expect(game.displayedVerse?.isClue == false)
            #expect(game.displayedVerse?.text.hasPrefix("13 And God said") == true)
            #expect(game.session.entries.last?.hintCount == 1)
        }
    }

    @Test func blankingTakesOutTheAnswerAndItsWords() {
        let text = BibleTriviaGameModel.blankingOut("Forty days", in: "It rained forty days and forty nights.")
        #expect(text == "It rained _____ ____ and _____ nights.")
        #expect(BibleTriviaGameModel.blankingOut("Noah", in: "God said unto Noah") == "God said unto ____")
    }

    @Test func aQuickCorrectAnswerEarnsASpeedBonus() async throws {
        try await withGame { game, clock in
            game.startRound()
            await clock.advance(by: 4)
            game.choose(try #require(game.currentQuestion?.correctAnswer))
            #expect(game.earnedSpeedBonus)

            game.advance()
            await clock.advance(by: 6)
            game.choose(try #require(game.currentQuestion?.correctAnswer))
            #expect(!game.earnedSpeedBonus)

            game.advance()
            game.toggleTimer()
            game.choose(try #require(game.currentQuestion?.correctAnswer))
            // The timer was off, so there's no bonus however quick it was.
            #expect(!game.earnedSpeedBonus)
            #expect(game.points == 4)
        }
    }

    @Test func topicsKeepToTheirBooks() async throws {
        try await withGame(topic: .newTestament) { game, _ in
            let newTestament = game.eligibleQuestions
            #expect(!newTestament.isEmpty)
            #expect(newTestament.allSatisfy { Canon.new.contains($0.bookName ?? "") })

            game.topic = .oldTestament
            let oldTestament = game.eligibleQuestions.count
            game.topic = .mixed
            #expect(oldTestament + newTestament.count == game.eligibleQuestions.count)
        }
    }

    @Test func questionsKnowTheirBook() {
        func book(_ reference: String) -> String? {
            BibleTriviaQuestion(id: 0, question: "", correctAnswer: "", incorrectAnswers: [], reference: reference, difficulty: "easy").bookName
        }
        #expect(book("1 John 2:1") == "1 John")
        #expect(book("John 3:16") == "John")
        #expect(book("Psalm 23:1") == "Psalms")
        #expect(book("Song of Solomon 2:1") == "Song of Solomon")
    }

    @Test func noQuestionRepeatsUntilTheTopicPoolIsUsedUp() async throws {
        try await withGame(difficulty: .easy, topic: .prophets) { game, _ in
            let poolSize = game.eligibleQuestions.count
            var asked: [Int] = []
            for _ in 0..<(poolSize / 10) {
                game.startRound()
                while game.phase == .playing, let question = game.currentQuestion {
                    asked.append(question.id)
                    game.choose(question.correctAnswer)
                    game.advance()
                }
            }
            #expect(asked.count == poolSize / 10 * 10)
            #expect(Set(asked).count == asked.count)
            #expect(game.completedInPool == asked.count)
        }
    }

    @Test func theBookMissedMostCanBePracticedWithoutTouchingThePool() async throws {
        let progress = BibleTriviaProgressStore(inMemory: [:])
        try await withGame(progress: progress) { game, _ in
            game.startRound()
            while game.phase == .playing {
                game.choose(wrongAnswer(in: game))
                game.advance()
            }
            let book = try #require(game.bookToPractice)
            let recorded = progress.progress(for: game.difficulty).completedQuestionIDs

            game.practice(book: book)
            #expect(game.phase == .playing)
            #expect(game.practiceBook == book)
            game.choose(try #require(game.currentQuestion?.correctAnswer))
            #expect(game.currentQuestion?.bookName == book)
            #expect(progress.progress(for: game.difficulty).completedQuestionIDs == recorded)
            #expect(game.poolProgress == nil)

            // Play Again goes back to the chosen topic.
            game.startRound()
            #expect(game.practiceBook == nil)
        }
    }
}
