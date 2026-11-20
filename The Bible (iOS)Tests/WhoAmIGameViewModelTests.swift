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
            #expect(missed.containsMiss(game: .whoAmI, questionID: String(person.id)))
        }
    }

    @Test func leavingAnUntimedQuestionCostsNothing() async throws {
        let missed = MissedGameQuestionStore(entries: [])
        try await withGame(difficulty: .easy, missed: missed) { game, _ in
            game.startGame()
            let person = try #require(game.current)

            game.endRoundWhenLeavingScreen()
            #expect(!missed.containsMiss(game: .whoAmI, questionID: String(person.id)))
            #expect(!game.roundOver)
        }
    }

    @Test func theClueToNameHintSaysWhereTheyAppearAndCostsFiveSeconds() async throws {
        try await withGame { game, _ in
            game.startGame()
            game.useHint()
            #expect(game.hintText?.isEmpty == false)
            #expect(game.remainingSeconds == 30 - WhoAmIGameViewModel.hintCost)

            game.select(game.correctChoice)
            #expect(game.session.entries.last?.hintCount == 1)
        }
    }

    @Test func theNameToClueHintRemovesAWrongClue() async throws {
        try await withGame(mode: .nameToClue) { game, _ in
            game.startGame()
            game.useHint()
            let removed = try #require(game.removedChoices.first)
            #expect(removed != game.correctChoice)
            #expect(game.hintText == nil)

            // A removed clue can't be chosen.
            game.select(removed)
            #expect(!game.roundOver)
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
}
