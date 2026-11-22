import Foundation
import Testing
@testable import Bible

/// Countdown (Beat the Clock): the timer, pausing and turning the timer off, leaving
/// mid-game, bonuses, hints, the tap-to-answer boards, each mode's rules, and the verse
/// after a round.
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
        missedQuestions: MissedGameQuestionStore? = nil,
        clock: ManualSleeper
    ) async -> BeatTheClockGameViewModel {
        let game = BeatTheClockGameViewModel(
            missedQuestions: missedQuestions ?? MissedGameQuestionStore(entries: []),
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
    func pausingStopsTheClockAndBlocksAnswersUntilResume() async throws {
        let clock = ManualSleeper()
        let game = await loadedGame(clock: clock)

        try await withRestoredDefaults {
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
            #expect(!game.canAnswer)
            #expect(!game.canRequestTestamentHint)
            game.submit(bookName: try #require(game.choices?.answer))
            #expect(game.roundOutcome == nil)

            game.resume()
            #expect(game.canAnswer)
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
            game.submit(bookName: try #require(game.choices?.answer))
            #expect(game.earnedSpeedBonus)

            game.nextRound()
            game.toggleTimer()
            game.toggleTimer()
            game.submit(bookName: try #require(game.choices?.answer))
            // The timer was off during the round, so no bonus.
            #expect(!game.earnedSpeedBonus)
            #expect(game.speedBonusCount == 1)
        }
    }

    @Test
    func theBoardHasOneRightBookAndThreeThatNeverMentionTheName() async throws {
        let clock = ManualSleeper()
        let game = await loadedGame(clock: clock)

        try await withRestoredDefaults {
            for difficulty in BeatTheClockDifficulty.allCases {
                game.difficulty = difficulty
                game.startGame()
                while game.phase == .playing {
                    let question = try #require(game.currentQuestion)
                    let choices = try #require(game.choices)
                    #expect(choices.books.count == BeatTheClockChoiceBuilder.choiceCount)
                    #expect(Set(choices.books).count == choices.books.count)
                    #expect(choices.books.filter { question.acceptableBooks.contains($0) } == [choices.answer])
                    // A wrong book never has the name, or another spelling of it.
                    #expect(choices.books.allSatisfy { $0 == choices.answer || !question.unsafeDecoyBooks.contains($0) })
                    game.debugWin()
                    game.nextRound()
                }
            }
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

            game.submit(bookName: try #require(game.choices?.answer))
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

            game.submit(bookName: try #require(game.choices?.answer))
            #expect(game.displayedVerse?.reference == "Exodus 4:14")
        }
    }

    // MARK: - Survival

    @Test
    func survivalAddsTimeForRightAnswersAndTakesItForWrongOnes() async throws {
        let clock = ManualSleeper()
        let game = await loadedGame(clock: clock)

        try await withRestoredDefaults {
            game.mode = .survival
            game.difficulty = .normal
            game.startGame()
            let start = BeatTheClockDifficulty.normal.survivalStartTime
            let bonus = BeatTheClockDifficulty.normal.survivalTimeBonus
            #expect(game.remainingSeconds == start)
            #expect(!game.canToggleTimer)

            await play(game, for: 2, on: clock)
            game.debugWin()
            #expect(game.remainingSeconds == start - 2 + bonus)
            #expect(game.lastClockChange == bonus)
            // The clock waits between questions.
            await clock.advance(by: 0.5)
            #expect(game.remainingSeconds == start - 2 + bonus)

            game.nextRound()
            let choices = try #require(game.choices)
            game.submit(bookName: try #require(choices.books.first { $0 != choices.answer }))
            #expect(game.remainingSeconds == start - 2 + bonus - BeatTheClockDifficulty.survivalPenalty)
            // One clock for the game, so no speed bonuses.
            #expect(game.speedBonusCount == 0)
            #expect(game.points == 1)
        }
    }

    @Test
    func survivalMovesOnByItselfAndEndsWhenTheClockRunsOut() async throws {
        let clock = ManualSleeper()
        let game = await loadedGame(clock: clock)

        await withRestoredDefaults {
            game.mode = .survival
            game.difficulty = .hard
            game.startGame()
            game.debugWin()
            await clock.advance(by: 1)
            await clock.settle()
            #expect(game.questionNumber == 2)
            #expect(game.roundOutcome == nil)

            await play(game, for: Double(BeatTheClockDifficulty.hard.survivalStartTime + BeatTheClockDifficulty.hard.survivalTimeBonus), on: clock)
            #expect(game.phase == .results)
            // The question on screen when time ran out isn't counted.
            #expect(game.session.answered == 1)
        }
    }

    @Test
    func aSurvivalMissIsReviewedAsClassic() async throws {
        let clock = ManualSleeper()
        let missed = MissedGameQuestionStore(entries: [])
        let game = await loadedGame(missedQuestions: missed, clock: clock)

        try await withRestoredDefaults {
            game.mode = .survival
            game.startGame()
            let question = try #require(game.currentQuestion)
            let choices = try #require(game.choices)
            game.submit(bookName: try #require(choices.books.first { $0 != choices.answer }))
            #expect(missed.containsMiss(game: .beatTheClock, mode: "classic", questionID: question.id))
        }
    }

    @Test
    func aSavedRapidFireSettingOpensAsSurvival() {
        #expect(BeatTheClockMode(storedValue: "rapidFire") == .survival)
        #expect(BeatTheClockMode(storedValue: nil) == .survival)
        #expect(BeatTheClockMode(storedValue: "classic") == .classic)
        #expect(BeatTheClockMode.reviewableCases == [.classic, .firstAppearance])
    }

    // MARK: - First Appearance

    @Test
    func firstAppearanceAsksForTheEarliestBook() async throws {
        let clock = ManualSleeper()
        let missed = MissedGameQuestionStore(entries: [])
        let game = await loadedGame(missedQuestions: missed, clock: clock)

        try await withRestoredDefaults {
            game.mode = .firstAppearance
            game.difficulty = .hard
            game.startGame()
            #expect(game.remainingSeconds == BeatTheClockDifficulty.hard.firstAppearanceTime)
            #expect(!game.offersTestamentHint)

            let question = try #require(game.currentQuestion)
            let choices = try #require(game.choices)
            let earliest = BibleCanon.canonicalOrder().first { question.acceptableBooks.contains($0) }
            #expect(choices.answer == earliest)
            // Every book on the board mentions the name.
            #expect(choices.books.allSatisfy { question.acceptableBooks.contains($0) })

            game.submit(bookName: try #require(choices.books.first { $0 != choices.answer }))
            #expect(game.roundOutcome == .incorrect)
            #expect(missed.containsMiss(game: .beatTheClock, mode: "firstAppearance", questionID: question.id))
            #expect(!missed.containsMiss(game: .beatTheClock, mode: "classic", questionID: question.id))
        }
    }

    // MARK: - Higher or Lower

    @Test
    func higherOrLowerPicksTheNameInMoreBooks() async throws {
        let clock = ManualSleeper()
        let missed = MissedGameQuestionStore(entries: [])
        let game = await loadedGame(missedQuestions: missed, clock: clock)

        try await withRestoredDefaults {
            game.mode = .higherOrLower
            game.difficulty = .normal
            game.startGame()
            #expect(game.remainingSeconds == BeatTheClockDifficulty.normal.higherOrLowerTime)
            #expect(!game.offersClue)

            let first = try #require(game.currentQuestion)
            let second = try #require(game.rival)
            #expect(first.subject == second.subject)
            #expect(abs(first.acceptableBooks.count - second.acceptableBooks.count) >= BeatTheClockDifficulty.normal.higherOrLowerGap)

            let winner = try #require(game.higherOrLowerWinner)
            let loser = winner.id == first.id ? second : first
            game.choose(questionID: loser.id)
            #expect(game.roundOutcome == .incorrect)
            #expect(game.remainingSeconds == BeatTheClockDifficulty.normal.higherOrLowerTime - BeatTheClockDifficulty.higherOrLowerPenalty)
            // Higher or Lower's pairs aren't saved for review.
            #expect(missed.isEmpty)

            game.nextRound()
            game.debugWin()
            #expect(game.roundOutcome == .correct)
            #expect(game.points == 1)
        }
    }

    // MARK: - Defaults

    /// Runs `body`, then puts back every default it added, changed or removed.
    private func withRestoredDefaults(_ body: () async throws -> Void) async rethrows {
        await StandardDefaultsLock.lock()
        defer { StandardDefaultsLock.unlock() }
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
