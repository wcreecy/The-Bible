import Foundation
import Testing
@testable import Bible

@MainActor
struct GameScoreTests {
    /// A saved streak under a throwaway game name, so tests never touch a real game's keys.
    private func makeSavedStreak() -> PersistentGameStreak {
        PersistentGameStreak(game: "gamescoretest\(UUID().uuidString)", variant: "normal")
    }

    private func discard(_ streak: PersistentGameStreak) {
        UserDefaults.standard.removeObject(forKey: streak.currentKey)
        UserDefaults.standard.removeObject(forKey: streak.bestKey)
    }

    @Test
    func correctAnswersExtendTheSessionAndSavedStreaks() {
        let saved = makeSavedStreak()
        defer { discard(saved) }
        var score = GameScore()
        score.beginGame(savedStreak: saved)

        score.record(correct: true, savedStreak: saved)
        score.record(correct: true, savedStreak: saved)

        #expect(score.score == 2)
        #expect(score.answered == 2)
        #expect(score.streak == 2)
        #expect(score.sessionBestStreak == 2)
        #expect(saved.current == 2)
        #expect(saved.best == 2)
        #expect(score.savedBestStreak == 2)
    }

    @Test
    func aMissEndsBothStreaksButKeepsTheBest() {
        let saved = makeSavedStreak()
        defer { discard(saved) }
        var score = GameScore()
        score.beginGame(savedStreak: saved)
        score.record(correct: true, savedStreak: saved)
        score.record(correct: true, savedStreak: saved)

        score.record(correct: false, savedStreak: saved)

        #expect(score.streak == 0)
        #expect(score.sessionBestStreak == 2)
        #expect(saved.current == 0)
        #expect(saved.best == 2)
        #expect(score.score == 2)
        #expect(score.answered == 3)
    }

    @Test
    func playingAgainClearsTheScoreButContinuesTheStreak() {
        let saved = makeSavedStreak()
        defer { discard(saved) }
        var score = GameScore()
        score.beginGame(savedStreak: saved)
        score.record(correct: true, savedStreak: saved)
        score.record(correct: true, savedStreak: saved)

        score.beginGame(savedStreak: saved)
        score.record(correct: true, savedStreak: saved)

        #expect(score.score == 1)
        #expect(score.answered == 1)
        #expect(score.streak == 3)
        #expect(score.sessionBestStreak == 3)
    }

    @Test
    func changingSettingsClearsTheScoreButKeepsTheStreak() {
        let saved = makeSavedStreak()
        defer { discard(saved) }
        var score = GameScore()
        score.beginGame(savedStreak: saved)
        score.record(correct: true, savedStreak: saved)

        score.clearGame()

        #expect(score.score == 0)
        #expect(score.answered == 0)
        #expect(score.streak == 1)
        #expect(score.sessionBestStreak == 1)
    }

    @Test
    func leavingTheScreenClearsTheSessionStreakButNotTheSavedOne() {
        let saved = makeSavedStreak()
        defer { discard(saved) }
        var score = GameScore()
        score.beginGame(savedStreak: saved)
        score.record(correct: true, savedStreak: saved)
        score.record(correct: true, savedStreak: saved)

        score.clearGame()
        score.clearStreak()

        #expect(score.streak == 0)
        #expect(score.sessionBestStreak == 0)
        #expect(saved.current == 2)
        #expect(saved.best == 2)
    }

    @Test
    func theSavedBestStartsFromStorageAndRisesWithTheStreak() {
        let saved = makeSavedStreak()
        defer { discard(saved) }
        saved.recordWin(reaching: 5)
        saved.reset()
        var score = GameScore()

        score.beginGame(savedStreak: saved)
        #expect(score.savedBestStreak == 5)

        for _ in 0..<6 {
            score.record(correct: true, savedStreak: saved)
        }
        #expect(score.savedBestStreak == 6)
        #expect(saved.best == 6)
    }

    @Test
    func syncingTheSavedBestFollowsADifferentDifficulty() {
        let easy = makeSavedStreak()
        let hard = makeSavedStreak()
        defer {
            discard(easy)
            discard(hard)
        }
        easy.recordWin(reaching: 9)
        hard.recordWin(reaching: 2)
        var score = GameScore()

        score.syncSavedBest(from: easy)
        #expect(score.savedBestStreak == 9)

        score.syncSavedBest(from: hard)
        #expect(score.savedBestStreak == 2)
    }

    @Test
    func aGameOnlyBecomesTheBestWhenItBeatsTheStoredScore() throws {
        let suiteName = "gamescoretest.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let saved = makeSavedStreak()
        defer { discard(saved) }
        let key = "bestGameScore"
        var score = GameScore()

        score.beginGame(savedStreak: saved)
        score.record(correct: true, savedStreak: saved)
        score.record(correct: true, savedStreak: saved)
        score.finishGame(bestScoreKey: key, defaults: defaults)
        #expect(score.isNewBestGame)
        #expect(score.bestGameScore == 2)
        #expect(defaults.integer(forKey: key) == 2)

        score.beginGame(savedStreak: saved)
        score.record(correct: true, savedStreak: saved)
        score.finishGame(bestScoreKey: key, defaults: defaults)
        #expect(!score.isNewBestGame)
        #expect(score.bestGameScore == 2)
        #expect(defaults.integer(forKey: key) == 2)

        score.beginGame(savedStreak: saved)
        score.record(correct: true, savedStreak: saved)
        score.record(correct: true, savedStreak: saved)
        score.finishGame(bestScoreKey: key, defaults: defaults)
        #expect(!score.isNewBestGame)
    }
}
