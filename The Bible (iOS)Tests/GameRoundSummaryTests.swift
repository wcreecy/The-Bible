import Foundation
import Testing
@testable import Bible

@MainActor
struct GameRoundSummaryTests {
    private func entry(
        _ outcome: GameRoundEntry.Outcome,
        book: String? = nil,
        category: String? = nil,
        seconds: Int? = nil
    ) -> GameRoundEntry {
        GameRoundEntry(
            prompt: "Prompt",
            outcome: outcome,
            givenAnswer: outcome == .wrong ? "Wrong" : nil,
            correctAnswer: "Right",
            category: category,
            bookName: book,
            duration: seconds.map { .seconds($0) }
        )
    }

    private func summary(_ entries: [GameRoundEntry]) -> GameRoundSummary {
        GameRoundSummary(
            entries: entries,
            roundDuration: .seconds(60),
            isTimed: true,
            currentStreak: 0,
            bestStreak: 0,
            isNewBestStreak: false
        )
    }

    @Test
    func countsEachOutcomeSeparately() {
        let result = summary([entry(.correct), entry(.correct), entry(.wrong), entry(.timedOut)])

        #expect(result.total == 4)
        #expect(result.correctCount == 2)
        #expect(result.wrongCount == 1)
        #expect(result.timedOutCount == 1)
        #expect(result.accuracy == 0.5)
        #expect(result.grade == .good)
    }

    @Test
    func gradesFollowAccuracy() {
        #expect(summary(Array(repeating: entry(.correct), count: 5)).grade == .perfect)
        #expect(summary([entry(.correct), entry(.correct), entry(.correct), entry(.correct), entry(.wrong)]).grade == .great)
        #expect(summary([entry(.correct), entry(.wrong), entry(.wrong)]).grade == .keepPracticing)
        #expect(summary([]).grade == .keepPracticing)
    }

    @Test
    func longestRunCountsOnlyThisRound() {
        let result = summary([entry(.correct), entry(.wrong), entry(.correct), entry(.correct), entry(.correct), entry(.timedOut)])
        #expect(result.longestRunThisRound == 3)
    }

    @Test
    func averageAndFastestUseTimedAnswers() {
        let result = summary([
            entry(.correct, seconds: 4),
            entry(.wrong, seconds: 2),
            entry(.correct, seconds: 9),
            entry(.correct)
        ])
        #expect(result.averageAnswerTime == .seconds(5))
        #expect(result.fastestCorrectAnswer == .seconds(4))
    }

    @Test
    func strongestAndWeakestBooksNeedRepeatedQuestions() {
        let result = summary([
            entry(.correct, book: "Genesis"),
            entry(.correct, book: "Genesis"),
            entry(.wrong, book: "Judges"),
            entry(.timedOut, book: "Judges"),
            entry(.wrong, book: "Acts")
        ])
        #expect(result.strongestBook?.name == "Genesis")
        #expect(result.weakestBook?.name == "Judges")
        #expect(result.missedBooks == ["Judges", "Acts"])
    }

    @Test
    func noStrongestOrWeakestWhenBooksTie() {
        let result = summary([
            entry(.correct, book: "Genesis"),
            entry(.correct, book: "Genesis"),
            entry(.correct, book: "Exodus"),
            entry(.correct, book: "Exodus"),
            entry(.wrong, book: "Acts")
        ])
        #expect(result.strongestBook == nil)
        #expect(result.weakestBook == nil)
        #expect(result.missedBooks == ["Acts"])
    }

    @Test
    func testamentSplitNeedsBothTestaments() {
        let mixed = summary([entry(.correct, book: "Genesis"), entry(.wrong, book: "Acts")])
        #expect(mixed.testamentTallies.map(\.name) == [String(localized: "Old Testament"), String(localized: "New Testament")])

        let oldOnly = summary([entry(.correct, book: "Genesis"), entry(.wrong, book: "Exodus")])
        #expect(oldOnly.testamentTallies.isEmpty)
    }

    @Test
    func categoriesNeedAtLeastTwoKinds() {
        let mixed = summary([entry(.correct, category: "People"), entry(.wrong, category: "Places"), entry(.correct, category: "People")])
        #expect(mixed.categoryTallies == [
            GameRoundSummary.Tally(name: "People", correct: 2, total: 2),
            GameRoundSummary.Tally(name: "Places", correct: 0, total: 1)
        ])

        let single = summary([entry(.correct, category: "People"), entry(.wrong, category: "People")])
        #expect(single.categoryTallies.isEmpty)
    }

    @Test
    func gameScoreKeepsEntriesStreakAndTiming() {
        let saved = PersistentGameStreak(game: "roundsummarytest\(UUID().uuidString)", variant: "normal")
        defer {
            UserDefaults.standard.removeObject(forKey: saved.currentKey)
            UserDefaults.standard.removeObject(forKey: saved.bestKey)
        }
        saved.recordWin(reaching: 2)

        var score = GameScore()
        score.beginGame(savedStreak: saved)
        score.record(entry(.correct), savedStreak: saved)
        score.noteTimerTurnedOff()
        score.record(entry(.correct), savedStreak: saved)
        score.endGame()

        let result = GameRoundSummary(score: score)
        #expect(result.total == 2)
        #expect(result.currentStreak == 4)
        #expect(result.bestStreak == 4)
        #expect(result.isNewBestStreak)
        #expect(!result.isTimed)
        #expect(result.roundDuration != nil)
        #expect(result.entries.allSatisfy { $0.duration != nil })

        score.record(entry(.wrong), savedStreak: saved)
        #expect(GameRoundSummary(score: score).currentStreak == 0)

        score.clearGame()
        #expect(score.entries.isEmpty)
    }
}
