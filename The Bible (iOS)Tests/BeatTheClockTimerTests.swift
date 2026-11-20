import Foundation
import Testing
@testable import Bible

/// Countdown (Beat the Clock): the timer, pausing and turning the timer off, leaving
/// mid-game, bonuses, hints, Rapid Fire, and the verse after a round.
///
/// The timer runs on a manual clock, so no test waits on the real one. Missed questions go
/// to a store that never touches disk or iCloud, and any defaults the game writes (stats,
/// streaks, settings) are put back when each test ends.
@Suite(.serialized)
@MainActor
struct BeatTheClockTimerTests {
    private static let passage = GamePassage(
        bookName: "Exodus",
        chapter: 4,
        verses: [.init(number: 14, text: "And the anger of the LORD was kindled against Moses")],
        isTruncated: true
    )

    /// A game with its people, places and book index loaded, on the manual clock.
    private func loadedGame(
        missedQuestions: MissedGameQuestionStore = MissedGameQuestionStore(entries: []),
        clock: ManualSleeper
    ) async -> BeatTheClockGameViewModel {
        let game = BeatTheClockGameViewModel(
            missedQuestions: missedQuestions,
            sleep: clock.sleep(for:),
            now: { clock.date },
            loadPassage: { _ in Self.passage }
        )
        await game.loadData()
        game.mode = .classic
        game.category = .people
        return game
    }

    /// Runs the timer for `seconds`, the way the view's timer task does.
    private func play(_ game: BeatTheClockGameViewModel, for seconds: TimeInterval, on clock: ManualSleeper) async {
        let timer = Task { await game.runTimer() }
        await clock.advance(by: seconds)
        timer.cancel()
        await clock.settle()
    }

    @Test
    func runningOutOfTimeTimesOutTheRound() async {
        let missed = MissedGameQuestionStore(entries: [])
        let clock = ManualSleeper()
        let game = await loadedGame(missedQuestions: missed, clock: clock)

        await withRestoredDefaults {
            game.difficulty = .hard
            game.startGame()
            #expect(game.remainingSeconds == BeatTheClockDifficulty.hard.roundTime)

            await play(game, for: Double(BeatTheClockDifficulty.hard.roundTime - 1), on: clock)
            #expect(game.remainingSeconds == 1)
            #expect(game.roundOutcome == nil)

            await play(game, for: 1, on: clock)
            #expect(game.remainingSeconds == 0)
            #expect(game.roundOutcome == .timedOut)
            #expect(game.session.answered == 1)
            #expect(missed.reviewCount(for: .beatTheClock) == 1)
        }
    }

    @Test
    func pausingStopsTheClockAndBlocksAnswersUntilResume() async {
        let clock = ManualSleeper()
        let game = await loadedGame(clock: clock)

        await withRestoredDefaults {
            game.difficulty = .hard
            game.startGame()
            await play(game, for: 2, on: clock)
            let secondsLeft = game.remainingSeconds

            game.pause()
            #expect(game.isPaused)
            await clock.advance(by: 30)
            await game.runTimer()
            #expect(game.remainingSeconds == secondsLeft)

            // Answers and hints wait for Resume.
            game.searchText = "Genesis"
            #expect(!game.canSubmit)
            #expect(!game.canRequestTestamentHint)
            game.submitCurrentEntry()
            #expect(game.roundOutcome == nil)

            game.resume()
            #expect(game.canSubmit)
            await play(game, for: 1, on: clock)
            #expect(game.remainingSeconds == secondsLeft - 1)
        }
    }

    @Test
    func timeWithTheTimerOffNeverCountsAgainstTheRound() async {
        let clock = ManualSleeper()
        let game = await loadedGame(clock: clock)

        await withRestoredDefaults {
            game.difficulty = .hard
            game.startGame()
            game.toggleTimer()
            game.debugWin()
            game.nextRound()

            // A long time with the timer off, on a round that started with it off.
            await clock.advance(by: 60)
            game.toggleTimer()
            await play(game, for: 1, on: clock)
            #expect(game.roundOutcome == nil)
            #expect(game.remainingSeconds == BeatTheClockDifficulty.hard.roundTime - 1)
        }
    }

    @Test
    func playAgainStartsWithTheTimerOn() async {
        let clock = ManualSleeper()
        let game = await loadedGame(clock: clock)

        await withRestoredDefaults {
            game.difficulty = .hard
            game.startGame()
            game.toggleTimer()
            #expect(game.isTimerDisabled)
            while game.phase == .playing {
                game.debugWin()
                game.nextRound()
            }

            game.startGame()
            #expect(!game.isTimerDisabled)
        }
    }

    @Test
    func onlyARunningQuestionCanBePaused() async {
        let clock = ManualSleeper()
        let game = await loadedGame(clock: clock)

        await withRestoredDefaults {
            game.difficulty = .hard
            game.pause()
            #expect(!game.isPaused)

            game.startGame()
            game.debugWin()
            #expect(!game.canPause)

            game.nextRound()
            game.pause()
            #expect(game.isPaused)
            game.resetToSetup()
            #expect(!game.isPaused)
        }
    }

    @Test
    func leavingMidQuestionCountsAsTimeUp() async {
        let missed = MissedGameQuestionStore(entries: [])
        let clock = ManualSleeper()
        let game = await loadedGame(missedQuestions: missed, clock: clock)

        await withRestoredDefaults {
            game.difficulty = .hard
            game.startGame()
            let questionID = game.currentQuestion?.id

            game.onDisappear()
            #expect(game.phase == .setup)
            if let questionID {
                #expect(missed.containsMiss(game: .beatTheClock, questionID: questionID))
            }
        }
    }

    @Test
    func reviewRoundsIncludeMissedQuestionsFromEveryCategory() async {
        let clock = ManualSleeper()
        let setup = await loadedGame(clock: clock)
        await withRestoredDefaults {
            setup.category = .places
            setup.startGame()
            let placeID = try? #require(setup.currentQuestion?.id)
            setup.resetToSetup()
            setup.category = .people

            guard let placeID else { return }
            let review = BeatTheClockGameViewModel(
                reviewQuestionIDs: [placeID],
                missedQuestions: MissedGameQuestionStore(entries: [])
            )
            await review.loadData()
            review.startGame()
            #expect(review.currentQuestion?.id == placeID)
        }
    }

    // MARK: - Bonuses and hints

    @Test
    func aQuickRightAnswerEarnsASpeedBonus() async throws {
        let clock = ManualSleeper()
        let game = await loadedGame(clock: clock)

        try await withRestoredDefaults {
            game.difficulty = .normal
            game.startGame()
            await play(game, for: 2, on: clock)
            game.submit(bookName: try #require(game.currentQuestion?.acceptableBooks.first))
            #expect(game.earnedSpeedBonus)

            game.nextRound()
            game.toggleTimer()
            game.toggleTimer()
            game.submit(bookName: try #require(game.currentQuestion?.acceptableBooks.first))
            // The timer was off during the round, so no bonus.
            #expect(!game.earnedSpeedBonus)
            #expect(game.speedBonusCount == 1)
        }
    }

    @Test
    func aRightBookOtherThanTheBestKnownEarnsABonus() async throws {
        let clock = ManualSleeper()
        let game = await loadedGame(clock: clock)

        try await withRestoredDefaults {
            game.difficulty = .hard
            // Start games until the first name has a clear best-known book and others.
            for _ in 0..<50 {
                game.startGame()
                if let question = game.currentQuestion, question.bestKnownBook != nil, question.acceptableBooks.count > 1 { break }
                game.resetToSetup()
            }
            let question = try #require(game.currentQuestion)
            let bestKnown = try #require(question.bestKnownBook)
            let other = try #require(question.acceptableBooks.first { $0 != bestKnown })

            game.submit(bookName: other)
            #expect(game.earnedLessKnownBonus)
            #expect(game.booksByMentions.first?.book == bestKnown)
            #expect(game.firstMention(in: bestKnown) != nil)
        }
    }

    @Test
    func theTestamentHintCostsASecondAndCountsAsAHint() async throws {
        let clock = ManualSleeper()
        let game = await loadedGame(clock: clock)

        try await withRestoredDefaults {
            game.difficulty = .hard
            game.startGame()
            game.revealTestamentHint()
            #expect(game.showsTestamentHint)
            #expect(game.remainingSeconds == BeatTheClockDifficulty.hard.roundTime - BeatTheClockDifficulty.testamentHintCost)

            game.submit(bookName: try #require(game.currentQuestion?.acceptableBooks.first))
            #expect(game.session.entries.last?.hintCount == 1)
        }
    }

    @Test
    func theVerseShowsOnceTheRoundIsOver() async throws {
        let clock = ManualSleeper()
        let game = await loadedGame(clock: clock)

        try await withRestoredDefaults {
            game.startGame()
            #expect(game.currentQuestion?.scriptureReference != nil)
            await game.loadPassage()
            #expect(game.displayedVerse == nil)

            game.submit(bookName: try #require(game.currentQuestion?.acceptableBooks.first))
            #expect(game.displayedVerse?.reference == "Exodus 4:14")
        }
    }

    // MARK: - Rapid Fire

    @Test
    func rapidFireCountsEachNewBookAndChargesForWrongOnes() async throws {
        let clock = ManualSleeper()
        let game = await loadedGame(clock: clock)

        try await withRestoredDefaults {
            game.mode = .rapidFire
            game.difficulty = .normal
            game.startGame()
            #expect(game.totalQuestions == BeatTheClockGameViewModel.rapidFireSubjectsPerGame)
            #expect(game.remainingSeconds == BeatTheClockDifficulty.normal.rapidFireTime)

            let question = try #require(game.currentQuestion)
            #expect(question.acceptableBooks.count >= 4)
            let books = question.acceptableBooks.sorted()

            game.submit(bookName: books[0])
            game.submit(bookName: books[1])
            game.submit(bookName: books[0])
            #expect(game.foundBooks == [books[0], books[1]])
            #expect(game.roundOutcome == nil)

            let wrong = try #require(BibleCanon.fallbackCanon.first { !question.acceptableBooks.contains($0) })
            game.submit(bookName: wrong)
            #expect(game.remainingSeconds == BeatTheClockDifficulty.normal.rapidFireTime - BeatTheClockDifficulty.rapidFirePenalty)

            // Running out of time ends the round; the books found still count.
            await play(game, for: Double(BeatTheClockDifficulty.normal.rapidFireTime), on: clock)
            #expect(game.roundOutcome == .correct)
            #expect(game.points == 2)
        }
    }

    // MARK: - Defaults

    /// Runs `body`, then puts back every default it added, changed or removed.
    private func withRestoredDefaults(_ body: () async throws -> Void) async rethrows {
        let before = UserDefaults.standard.dictionaryRepresentation()
        defer { restore(before) }
        try await body()
    }

    private func restore(_ before: [String: Any]) {
        let defaults = UserDefaults.standard
        let after = defaults.dictionaryRepresentation()
        for key in Set(before.keys).union(after.keys) {
            let old = before[key].map { $0 as AnyObject }
            let new = after[key].map { $0 as AnyObject }
            guard old?.isEqual(new) != true else { continue }
            if let old { defaults.set(old, forKey: key) } else { defaults.removeObject(forKey: key) }
        }
    }
}
