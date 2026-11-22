import Foundation
import Testing
@testable import Bible

/// Quiz's Last Book Standing on the manual clock: the board, the order books leave, scoring by
/// books left, and the board running out. Missed verses go to an in-memory store, and every
/// default the game writes is put back when each test ends.
@Suite(.serialized)
@MainActor
struct QuizLastBookStandingTests {
    private func withGame(
        difficulty: QuizDifficulty = .normal,
        missed: MissedGameQuestionStore? = nil,
        _ body: (QuizGameViewModel, ManualSleeper) async throws -> Void
    ) async throws {
        _ = await BibleRepository.shared.loadAllBooks()
        await StandardDefaultsLock.lock()
        defer { StandardDefaultsLock.unlock() }
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
        let game = QuizGameViewModel(
            mode: .lastBookStanding,
            missedQuestions: missed ?? MissedGameQuestionStore(entries: []),
            sleep: clock.sleep(for:),
            now: { clock.date }
        )
        game.difficulty = difficulty
        game.pool = .any
        game.selectedSections = Set(QuizVerseSection.allCases)
        await game.prepareFilter()
        try await body(game, clock)
        game.resetToSetup()
    }

    /// Runs the timer for `seconds`, the way the view's timer task does.
    private func play(_ game: QuizGameViewModel, for seconds: TimeInterval, on clock: ManualSleeper) async {
        let timer = Task { await game.runTimer() }
        await clock.advance(by: seconds)
        timer.cancel()
        await clock.settle()
    }

    @Test(arguments: QuizDifficulty.allCases)
    func theBoardHoldsTheAnswerAndLeavesItForLast(_ difficulty: QuizDifficulty) async throws {
        try await withGame(difficulty: difficulty) { game, _ in
            game.startQuiz()
            let current = try #require(game.current)
            #expect(current.options.count == difficulty.boardSize)
            #expect(Set(current.options).count == current.options.count)
            #expect(current.options.contains(current.correctAnswer))
            #expect(Set(current.removalOrder) == Set(current.options).subtracting([current.correctAnswer]))
            #expect(game.availableLifelines.isEmpty)
            #expect(!game.canToggleTimer)
        }
    }

    @Test func booksFromTheOtherTestamentLeaveFirst() {
        let order = QuizGameViewModel.removalOrder(of: ["Matthew", "Exodus", "Romans", "Leviticus", "Isaiah"], answer: "Genesis")
        // The New Testament goes first, then other parts of the Old, then the Law with the answer.
        #expect(Set(order.prefix(2)) == ["Matthew", "Romans"])
        #expect(order[2] == "Isaiah")
        #expect(Set(order.suffix(2)) == ["Exodus", "Leviticus"])
    }

    @Test func aRightTapScoresTheWrongBooksStillStanding() async throws {
        try await withGame { game, clock in
            game.startQuiz()
            let difficulty = game.difficulty
            // Nothing leaves while the verse is being read.
            await play(game, for: difficulty.boardReadingSeconds - 0.5, on: clock)
            #expect(game.current?.removedOptions.isEmpty == true)
            #expect(game.boardPointsAvailable == difficulty.boardSize - 1)

            // Then one book for each interval.
            await play(game, for: 0.5 + difficulty.boardRemovalInterval * 2, on: clock)
            #expect(game.current?.removedOptions.count == 3)

            game.selectOption(try #require(game.current?.correctAnswer))
            #expect(game.current?.outcome == .correct)
            let scored = difficulty.boardSize - 4
            #expect(game.current?.boardPoints == scored)
            #expect(game.current?.earnedSpeedBonus == false)
            #expect(game.points == scored + game.chapterBonusCount)
            #expect(game.roundPoints.total == game.points)
        }
    }

    @Test func aBookThatJustLeftCantBeTapped() async throws {
        try await withGame { game, clock in
            game.startQuiz()
            let current = try #require(game.current)
            // The timer hasn't caught up, but the tap brings the board up to date first.
            await clock.advance(by: game.difficulty.boardReadingSeconds + 0.1)
            game.selectOption(current.removalOrder[0])
            #expect(game.current?.outcome == nil)
            #expect(game.current?.removedOptions == [current.removalOrder[0]])
        }
    }

    @Test func aWrongTapScoresNothingAndIsSavedForReview() async throws {
        let missed = MissedGameQuestionStore(entries: [])
        try await withGame(missed: missed) { game, _ in
            game.startQuiz()
            let current = try #require(game.current)
            game.selectOption(try #require(current.options.first { $0 != current.correctAnswer }))
            #expect(game.current?.outcome == .incorrect)
            #expect(game.points == 0)
            // Last Book Standing keeps its own misses, apart from Standard's.
            #expect(missed.containsMiss(game: .bibleQuiz, mode: QuizMode.lastBookStanding.rawValue, questionID: current.reviewID))
            #expect(!missed.containsMiss(game: .bibleQuiz, questionID: current.reviewID))
        }
    }

    @Test func aReviewReplaysMissedVersesOnTheBoardAndClearsTheRightOnes() async throws {
        let missed = MissedGameQuestionStore(entries: [])
        try await withGame(missed: missed) { game, _ in
            game.startQuiz()
            let current = try #require(game.current)
            game.selectOption(try #require(current.options.first { $0 != current.correctAnswer }))
            let mode = MissedGameQuestionStore.ReviewMode(game: .bibleQuiz, mode: QuizMode.lastBookStanding.rawValue)
            #expect(missed.reviewCount(for: mode) == 1)
            #expect(missed.reviewCount(for: MissedGameQuestionStore.ReviewMode(game: .bibleQuiz)) == 0)

            let review = QuizGameViewModel(reviewQuestionIDs: [current.reviewID], mode: .lastBookStanding, missedQuestions: missed)
            await review.prepareFilter()
            review.startQuiz()
            let question = try #require(review.current)
            #expect(question.reviewID == current.reviewID)
            #expect(question.options.count == review.difficulty.boardSize)

            review.selectOption(question.correctAnswer)
            #expect(missed.reviewCount(for: mode) == 0)
            review.resetToSetup()
        }
    }

    @Test func quizReviewOffersLastBookStandingAsItsOwnMode() {
        let modes = ReviewGame.quiz.modes.map(\.reviewMode)
        #expect(modes.contains(MissedGameQuestionStore.ReviewMode(game: .bibleQuiz, mode: QuizMode.lastBookStanding.rawValue)))
        // Standard misses saved before modes were recorded still count as Standard.
        #expect(modes.contains(MissedGameQuestionStore.ReviewMode(game: .bibleQuiz)))
        #expect(Set(modes).count == 3)
    }

    @Test func timeIsUpWhenOnlyTheAnswerIsLeft() async throws {
        try await withGame(difficulty: .hard) { game, clock in
            game.startQuiz()
            let limit = try #require(game.timeLimit)
            await play(game, for: Double(limit), on: clock)
            let current = try #require(game.current)
            #expect(current.outcome == .timedOut)
            #expect(current.booksLeft == 1)
            #expect(game.points == 0)
        }
    }

    @Test func aBoardFillsEvenWithOneCategory() async throws {
        try await withGame(difficulty: .hard) { game, _ in
            game.selectedSections = [.gospels]
            game.startQuiz()
            let current = try #require(game.current)
            #expect(current.options.count == QuizDifficulty.hard.boardSize)
            #expect(QuizVerseSection.gospels.bookNames.contains(current.correctBook))
        }
    }
}
