import Foundation
import Testing
@testable import Bible

/// Who? on the manual clock: the timer, pausing, leaving mid-question, the hint, the speed
/// bonus and the verse after answering. Missed questions go to an in-memory store, and every
/// default the game writes is put back when each test ends.
@Suite(.serialized)
@MainActor
struct WhoAmIGameViewModelTests {
    private static let passage = GamePassage(
        bookName: "Exodus",
        chapter: 4,
        verses: [.init(number: 14, text: "Is not Aaron the Levite thy brother?")],
        isTruncated: false
    )

    private func withGame(
        difficulty: WhoAmIGameViewModel.Difficulty = .normal,
        mode: WhoAmIGameViewModel.Mode = .clueToName,
        missed: MissedGameQuestionStore? = nil,
        _ body: (WhoAmIGameViewModel, ManualSleeper) async throws -> Void
    ) async throws {
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
        let game = WhoAmIGameViewModel(
            missedQuestions: missed ?? MissedGameQuestionStore(entries: []),
            sleep: clock.sleep(for:),
            now: { clock.date },
            loadPassage: { _ in Self.passage }
        )
        game.difficulty = difficulty
        game.mode = mode
        await game.loadData()
        try #require(game.isReady)
        try await body(game, clock)
        game.returnToSetup()
    }

    private func wrongChoice(in game: WhoAmIGameViewModel) -> String {
        game.choices.first { $0 != game.correctChoice && !game.removedChoices.contains($0) }!
    }

    @Test func theTimerRunsOutOnTheClock() async throws {
        try await withGame { game, clock in
            game.startGame()
            await clock.advance(by: 10)
            #expect(game.remainingSeconds == 20)

            await clock.advance(by: 20)
            #expect(game.roundOver)
            #expect(game.wasTimedOut)
        }
    }

    @Test func pausingDoesNotGiveBackPartOfASecond() async throws {
        try await withGame { game, clock in
            game.startGame()
            // Play 0.9 seconds of each second, pausing just before it would tick. A timer that
            // counted whole seconds would restart each one and never move.
            for _ in 0..<10 {
                await clock.advance(by: 0.9)
                game.pause()
                game.resume()
            }
            await clock.advance(by: 0.1)
            #expect(game.remainingSeconds == 30 - 9)
        }
    }

    @Test func timeWithTheTimerOffNeverCounts() async throws {
        try await withGame { game, clock in
            game.startGame()
            game.toggleTimer()
            await clock.advance(by: 60)
            game.toggleTimer()
            await clock.advance(by: 1)
            #expect(!game.roundOver)
            #expect(game.remainingSeconds == 29)
        }
    }

    @Test func leavingATimedQuestionCountsAsTimeUp() async throws {
        let missed = MissedGameQuestionStore(entries: [])
        try await withGame(missed: missed) { game, _ in
            game.startGame()
            let person = try #require(game.current)

            game.endRoundWhenLeavingScreen()
            #expect(!game.started)
            #expect(missed.containsMiss(game: .whoAmI, questionID: person.questionID))
        }
    }

    @Test func leavingAnUntimedQuestionCostsNothing() async throws {
        let missed = MissedGameQuestionStore(entries: [])
        try await withGame(difficulty: .easy, missed: missed) { game, _ in
            game.startGame()
            let person = try #require(game.current)

            game.endRoundWhenLeavingScreen()
            #expect(!missed.containsMiss(game: .whoAmI, questionID: person.questionID))
            #expect(!game.roundOver)
        }
    }

    @Test func theClueToNameHintSaysWhereTheyAppearAndIsFree() async throws {
        try await withGame { game, _ in
            game.startGame()
            let limit = game.remainingSeconds
            game.use(.hint)
            #expect(game.hintText?.isEmpty == false)
            #expect(game.remainingSeconds == limit)

            game.select(game.correctChoice)
            #expect(game.session.entries.last?.hintCount == 1)
        }
    }

    @Test func theNameToClueHintShowsTheVerseAndKeepsEveryChoice() async throws {
        try await withGame(mode: .nameToClue) { game, _ in
            game.startGame()
            await game.loadPassage()
            #expect(game.hintVerse == nil)

            game.use(.hint)
            let verse = try #require(game.hintVerse)
            #expect(verse.isClue)
            #expect(game.hintText == nil)
            #expect(game.removedChoices.isEmpty)

            // The verse goes once the question is answered; the usual verse card takes over.
            game.select(game.correctChoice)
            #expect(game.hintVerse == nil)
        }
    }

    @Test func theHintAfterFiftyFiftyStillLeavesTwoChoices() async throws {
        try await withGame(mode: .nameToClue) { game, _ in
            game.startGame()
            await game.loadPassage()
            game.use(.fiftyFifty)
            game.use(.hint)
            #expect(game.removedChoices.count == 2)
            #expect(game.hintVerse != nil)
            #expect(game.choices.count - game.removedChoices.count == 2)
        }
    }

    @Test func fiftyFiftyRemovesTwoWrongChoicesOncePerGame() async throws {
        try await withGame { game, _ in
            game.startGame()
            #expect(game.canUse(.fiftyFifty))
            game.use(.fiftyFifty)
            #expect(game.removedChoices.count == 2)
            #expect(!game.removedChoices.contains(game.correctChoice))
            #expect(!game.availableLifelines.contains(.fiftyFifty))

            // Used for the game, so the next question doesn't offer it again.
            game.select(game.correctChoice)
            game.nextRound()
            #expect(!game.canUse(.fiftyFifty))
            #expect(game.removedChoices.isEmpty)
        }
    }

    @Test func extraTimeAddsTenSecondsAndIsNotOnEasy() async throws {
        try await withGame { game, clock in
            game.startGame()
            let limit = game.remainingSeconds
            await clock.advance(by: 5)
            game.use(.extraTime)
            #expect(game.remainingSeconds == limit - 5 + WhoLifeline.extraSeconds)
            #expect(!game.canUse(.extraTime))
        }
        try await withGame(difficulty: .easy) { game, _ in
            game.startGame()
            #expect(!game.offers(.extraTime))
            #expect(game.lifelinesForRound == [.fiftyFifty, .hint])
        }
    }

    @Test func normalAndHardOfferAllThreeLifelines() async throws {
        try await withGame { game, _ in
            #expect(game.lifelinesForRound == [.fiftyFifty, .hint, .extraTime])
        }
    }


    @Test func aQuickCorrectAnswerEarnsASpeedBonus() async throws {
        try await withGame { game, clock in
            game.startGame()
            await clock.advance(by: 5)
            game.select(game.correctChoice)
            #expect(game.earnedSpeedBonus)

            game.nextRound()
            await clock.advance(by: 15)
            game.select(game.correctChoice)
            #expect(!game.earnedSpeedBonus)

            game.nextRound()
            game.toggleTimer()
            game.select(game.correctChoice)
            // The timer was off, so there's no bonus however quick it was.
            #expect(!game.earnedSpeedBonus)
            #expect(game.points == 3 + 1)
        }
    }

    @Test func theVerseShowsOnceTheQuestionIsOver() async throws {
        try await withGame { game, _ in
            game.startGame()
            await game.loadPassage()
            #expect(game.displayedVerse == nil)

            game.select(wrongChoice(in: game))
            #expect(game.displayedVerse?.reference == "Exodus 4:14")
        }
    }

    // MARK: - Review

    /// A loaded review game for `ids`, with an in-memory missed store.
    private func reviewGame(ids: Set<String>, missed: MissedGameQuestionStore) async -> WhoAmIGameViewModel {
        let game = WhoAmIGameViewModel(reviewQuestionIDs: ids, missedQuestions: missed, loadPassage: { _ in nil })
        await game.loadData()
        return game
    }

    @Test func aMissIsSavedForTheQuestionNotThePerson() async throws {
        let missed = MissedGameQuestionStore(entries: [])
        try await withGame(missed: missed) { game, _ in
            game.startGame()
            let person = try #require(game.current)
            game.select(wrongChoice(in: game))

            #expect(person.questionID.hasPrefix("who-"))
            #expect(missed.containsMiss(game: .whoAmI, questionID: person.questionID))
            #expect(!missed.containsMiss(game: .whoAmI, questionID: String(person.id)))
        }
    }

    @Test func aReviewShowsOnlyTheQuestionsThatWereMissed() async throws {
        let loader = WhoAmIGameViewModel(missedQuestions: MissedGameQuestionStore(entries: []))
        await loader.loadData()
        // Ten Clue → Name questions, from ten different people.
        let missedIDs = Set(loader.entries.filter { $0.questionMode == .factToPerson }.prefix(10).map(\.questionID))

        let review = await reviewGame(ids: missedIDs, missed: MissedGameQuestionStore(entries: []))
        #expect(review.isReady)
        review.startGame()
        var asked: Set<String> = []
        while review.started, !review.isComplete, let current = review.current {
            asked.insert(current.questionID)
            review.select(review.correctChoice)
            review.nextRound()
        }
        #expect(asked == missedIDs)
    }

    @Test func aReviewNeedsTenMissedQuestions() async throws {
        let loader = WhoAmIGameViewModel(missedQuestions: MissedGameQuestionStore(entries: []))
        await loader.loadData()
        let nineIDs = Set(loader.entries.prefix(9).map(\.questionID))

        let review = await reviewGame(ids: nineIDs, missed: MissedGameQuestionStore(entries: []))
        #expect(!review.isReady)
    }

    @Test func anOlderMissSavedByPersonBringsBackBothQuestionsAndEitherClearsIt() async throws {
        let loader = WhoAmIGameViewModel(missedQuestions: MissedGameQuestionStore(entries: []))
        await loader.loadData()
        let personIDs = Array(Set(loader.entries.map(\.id))).sorted().prefix(5).map { String($0) }

        let missed = MissedGameQuestionStore(entries: [])
        for id in personIDs {
            missed.record(game: .whoAmI, bookNames: [], topic: "Bible people", questionID: id)
        }
        // Five people saved the old way stand for both of their questions: ten in all.
        let review = await reviewGame(ids: Set(personIDs), missed: missed)
        #expect(review.isReady)

        review.startGame()
        let first = try #require(review.current)
        review.select(review.correctChoice)
        #expect(!missed.containsMiss(game: .whoAmI, questionID: String(first.id)))
    }
}
