import Foundation
import Testing
@testable import Bible

/// Timer lifecycle for Countdown (Beat the Clock): ticking, timing out, and leaving mid-game.
///
/// Ticks are driven directly with `tick()`, so no test waits on the real one-second clock.
/// Missed questions go to a store that never touches disk or iCloud, and any defaults
/// the game writes (stats, streaks, difficulty) are put back when each test ends.
@MainActor
struct BeatTheClockTimerTests {
    /// A game with its people, places and book index loaded, ready to start.
    private func loadedGame(missedQuestions: MissedGameQuestionStore) async -> BeatTheClockGameViewModel {
        let game = BeatTheClockGameViewModel(missedQuestions: missedQuestions)
        await game.loadData()
        return game
    }

    @Test
    func tickingDownToZeroTimesOutTheRound() async {
        let missed = MissedGameQuestionStore(entries: [])
        let game = await loadedGame(missedQuestions: missed)

        await withRestoredDefaults {
            game.difficulty = .hard
            game.startGame()
            #expect(game.phase == .playing)
            #expect(game.remainingSeconds == BeatTheClockDifficulty.hard.roundTime)

            for _ in 1..<BeatTheClockDifficulty.hard.roundTime {
                game.tick()
            }
            #expect(game.remainingSeconds == 1)
            #expect(game.roundOutcome == nil)

            game.tick()
            #expect(game.remainingSeconds == 0)
            #expect(game.roundOutcome == .timedOut)
            #expect(game.selectionLocked)
            #expect(game.session.answered == 1)
            #expect(missed.reviewCount(for: .beatTheClock) == 1)

            // A stray tick after the timeout changes nothing.
            game.tick()
            #expect(game.remainingSeconds == 0)
            #expect(game.session.answered == 1)
        }
    }

    @Test
    func pausingStopsTheClockAndBlocksAnswersUntilResume() async {
        let game = await loadedGame(missedQuestions: MissedGameQuestionStore(entries: []))

        await withRestoredDefaults {
            game.difficulty = .hard
            game.startGame()
            game.tick()
            let secondsLeft = game.remainingSeconds
            #expect(game.canPause)

            game.pause()
            #expect(game.isPaused)
            #expect(!game.canPause)

            // No time passes while paused, from a tick or from the timer loop.
            game.tick()
            await game.runTimer()
            #expect(game.remainingSeconds == secondsLeft)

            // Answers and hints wait for Resume.
            game.searchText = "Genesis"
            #expect(!game.canSubmit)
            #expect(!game.canRequestHint)
            game.submitCurrentEntry()
            #expect(game.roundOutcome == nil)
            #expect(game.session.answered == 0)

            game.resume()
            #expect(!game.isPaused)
            #expect(game.canSubmit)
            game.tick()
            #expect(game.remainingSeconds == secondsLeft - 1)
        }
    }

    @Test
    func onlyARunningQuestionCanBePaused() async {
        let game = await loadedGame(missedQuestions: MissedGameQuestionStore(entries: []))

        await withRestoredDefaults {
            game.difficulty = .hard
            // Nothing to pause before the game starts.
            game.pause()
            #expect(!game.isPaused)

            game.startGame()
            game.debugWin()
            // The answer is showing and the clock has stopped, so there's nothing to pause.
            #expect(!game.canPause)
            game.pause()
            #expect(!game.isPaused)

            // A paused game that's reset or moves on starts unpaused.
            game.nextRound()
            game.pause()
            #expect(game.isPaused)
            game.resetToSetup()
            #expect(!game.isPaused)
        }
    }

    @Test
    func theTimerStopsOnceTheRoundIsAnsweredAndRestartsForTheNextRound() async {
        let game = await loadedGame(missedQuestions: MissedGameQuestionStore(entries: []))

        await withRestoredDefaults {
            game.difficulty = .hard
            game.startGame()
            game.tick()
            game.debugWin()
            let secondsLeft = game.remainingSeconds
            let firstRoundID = game.roundID

            // With an outcome recorded, the timer loop exits without counting down.
            await game.runTimer()
            #expect(game.remainingSeconds == secondsLeft)
            #expect(game.roundOutcome == .correct)

            game.nextRound()
            #expect(game.roundID == firstRoundID + 1)
            #expect(game.roundOutcome == nil)
            #expect(game.remainingSeconds == BeatTheClockDifficulty.hard.roundTime)
        }
    }

    @Test
    func disablingTheTimerPersistsForTheRestOfTheGame() async {
        let game = await loadedGame(missedQuestions: MissedGameQuestionStore(entries: []))

        await withRestoredDefaults {
            game.difficulty = .hard
            game.startGame()
            game.toggleTimer()
            #expect(game.isTimerDisabled)

            game.debugWin()
            game.nextRound()
            #expect(game.isTimerDisabled)

            let secondsLeft = game.remainingSeconds
            game.tick()
            #expect(game.remainingSeconds == secondsLeft)
        }
    }

    @Test
    func leavingAfterAnsweringResetsTheGameAndStopsTheTimer() async {
        let game = await loadedGame(missedQuestions: MissedGameQuestionStore(entries: []))

        await withRestoredDefaults {
            game.difficulty = .hard
            game.startGame()
            game.debugWin()
            game.nextRound()

            game.onDisappear()
            #expect(game.phase == .setup)
            #expect(game.currentQuestion == nil)
            #expect(game.remainingSeconds == 0)
            #expect(game.session.answered == 0)
            #expect(game.session.streak == 0)

            // A timer task still running after the reset exits immediately.
            await game.runTimer()
            #expect(game.remainingSeconds == 0)
        }
    }

    @Test
    func leavingMidQuestionCountsAsTimeUp() async {
        let missed = MissedGameQuestionStore(entries: [])
        let game = await loadedGame(missedQuestions: missed)

        await withRestoredDefaults {
            game.difficulty = .hard
            game.startGame()
            game.tick()
            let questionID = try? #require(game.currentQuestion?.id)

            game.onDisappear()
            // The unanswered question is recorded as missed, and the game ends.
            #expect(game.phase == .setup)
            #expect(game.currentQuestion == nil)
            if let questionID {
                #expect(missed.containsMiss(game: .beatTheClock, questionID: questionID))
            }
        }
    }

    @Test
    func reviewRoundsIncludeMissedQuestionsFromEveryCategory() async {
        let setup = await loadedGame(missedQuestions: MissedGameQuestionStore(entries: []))
        await withRestoredDefaults {
            setup.category = .places
            setup.startGame()
            let placeID = try? #require(setup.currentQuestion?.id)
            setup.resetToSetup()
            // Saved category is People, but the missed question is a place.
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

    // MARK: - Defaults

    /// Runs `body`, then puts back every default it added, changed or removed.
    private func withRestoredDefaults(_ body: () async -> Void) async {
        let before = UserDefaults.standard.dictionaryRepresentation()
        defer { restore(before) }
        await body()
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
