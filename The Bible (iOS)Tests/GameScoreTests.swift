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

    @Test
    func theBestScoreCountsBonusPointsWhenAGamePassesThem() throws {
        let suiteName = "gamescoretest.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let saved = makeSavedStreak()
        defer { discard(saved) }
        let key = "bestGameScore"
        var score = GameScore()

        // Two right answers plus three bonus points is a 5-point game.
        score.beginGame(savedStreak: saved)
        score.record(correct: true, savedStreak: saved)
        score.record(correct: true, savedStreak: saved)
        score.finishGame(bestScoreKey: key, points: 5, defaults: defaults)
        #expect(score.isNewBestGame)
        #expect(score.bestGameScore == 5)
        #expect(defaults.integer(forKey: key) == 5)

        // Three right answers and no bonuses is fewer points, so it isn't a new best.
        score.beginGame(savedStreak: saved)
        for _ in 0..<3 { score.record(correct: true, savedStreak: saved) }
        score.finishGame(bestScoreKey: key, points: 3, defaults: defaults)
        #expect(!score.isNewBestGame)
        #expect(defaults.integer(forKey: key) == 5)
    }

    @Test
    func roundPointsAddEachBonusToTheCorrectAnswers() throws {
        let points = try #require(RoundPoints(
            correct: 10,
            bonuses: [RoundPoints.speed(3), RoundPoints.chapter(2), RoundPoints.lessKnown(0)]
        ))
        #expect(points.total == 15)
        #expect(points.correct == 10)
        // Bonuses that weren't earned don't show.
        #expect(points.bonuses.map(\.count) == [3, 2])
    }

    @Test
    func roundPointsAreNilWhenNoBonusWasEarned() {
        #expect(RoundPoints(correct: 8, bonuses: [RoundPoints.speed(0), RoundPoints.chapter(0)]) == nil)
        #expect(RoundPoints(correct: 8, bonuses: []) == nil)
    }

    @Test
    func bonusTitlesAgreeWithTheirCount() {
        #expect(RoundPoints.speed(1).title == "1 speed bonus")
        #expect(RoundPoints.speed(2).title == "2 speed bonuses")
        #expect(RoundPoints.chapter(1).title == "1 chapter bonus")
        #expect(RoundPoints.lessKnown(3).title == "3 less-known books")
    }
}
