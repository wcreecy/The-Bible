import Foundation
import Testing
@testable import Bible

@MainActor
struct GamePuzzleResultTests {
    // MARK: - Best time

    @Test
    func firstSolvedTimeIsANewBest() {
        let comparison = GameBestTimeComparison(seconds: 40, previousBest: nil, isSolved: true)
        #expect(comparison.result == .firstBest)
        #expect(comparison.isNewBest)
    }

    @Test
    func fasterTimeBeatsTheBestByTheDifference() {
        let comparison = GameBestTimeComparison(seconds: 30, previousBest: 42, isSolved: true)
        #expect(comparison.result == .newBest(fasterBy: 12))
        #expect(comparison.isNewBest)
    }

    @Test
    func equalAndSlowerTimesAreNotNewBests() {
        #expect(GameBestTimeComparison(seconds: 42, previousBest: 42, isSolved: true).result == .tied)

        let slower = GameBestTimeComparison(seconds: 50, previousBest: 42, isSolved: true)
        #expect(slower.result == .slower(by: 8, best: 42))
        #expect(!slower.isNewBest)
    }

    @Test
    func unsolvedPuzzlesNeverSetABest() {
        let unsolved = GameBestTimeComparison(seconds: 5, previousBest: 42, isSolved: false)
        #expect(unsolved.result == .notEligible(best: 42))
        #expect(!unsolved.isNewBest)
        #expect(GameBestTimeComparison(seconds: 5, previousBest: nil, isSolved: false).message == nil)
    }

    // MARK: - Book Order review items

    @Test
    func reviewItemsListMisplacedBooksInBibleOrder() {
        let correct = ["Micah", "Nahum", "Habakkuk", "Zephaniah"]
        let current = ["Micah", "Habakkuk", "Nahum", "Zephaniah"]

        let items = BookOrderGameViewModel.reviewItems(current: current, correct: correct)

        #expect(items.map(\.book) == ["Nahum", "Habakkuk"])
        #expect(items.map(\.previousBook) == ["Micah", "Nahum"])
    }

    @Test
    func aMisplacedFirstBookIsDescribedByTheBookAfterIt() {
        let items = BookOrderGameViewModel.reviewItems(current: ["Exodus", "Genesis"], correct: ["Genesis", "Exodus"])
        #expect(items.first?.previousBook == nil)
        #expect(items.first?.nextBook == "Exodus")
        #expect(items.first?.hint == String(localized: "Genesis comes before Exodus"))
    }

    @Test
    func aCorrectOrderHasNothingToReview() {
        let order = ["Genesis", "Exodus", "Leviticus"]
        #expect(BookOrderGameViewModel.reviewItems(current: order, correct: order).isEmpty)
    }

    // MARK: - Missed question history

    @Test
    func bookOrderMissesAreKeptButNeverReviewable() {
        let entries = (0..<12).map { index in
            MissedGameQuestionStore.Entry(
                id: UUID(),
                game: .bookOrder,
                bookNames: ["Book \(index)"],
                chapterNumber: nil,
                topic: "Book order",
                questionID: "Book \(index)",
                date: Date()
            )
        }
        let store = MissedGameQuestionStore(entries: entries)

        #expect(store.containsMiss(game: .bookOrder, questionID: "Book 3"))
        #expect(store.reviewCount(for: .bookOrder) == 0)
        #expect(!store.reviewableGames().contains(.bookOrder))
        #expect(!MissedGameQuestionStore.Entry.Game.reviewableCases.contains(.bookOrder))
    }

    @Test
    func reverseQuizMissesAreKeptButNotOfferedForReview() {
        let entries = (0..<12).map { index in
            MissedGameQuestionStore.Entry(
                id: UUID(),
                game: .quizReverse,
                bookNames: ["Book \(index)"],
                chapterNumber: nil,
                topic: "Verse matching",
                questionID: "Verse \(index)",
                date: Date()
            )
        }
        let store = MissedGameQuestionStore(entries: entries)

        #expect(store.containsMiss(game: .quizReverse, questionID: "Verse 3"))
        #expect(store.reviewCount(for: .quizReverse) == 0)
        #expect(!store.reviewableGames().contains(.quizReverse))
        #expect(!MissedGameQuestionStore.Entry.Game.reviewableCases.contains(.quizReverse))
        #expect(store.questionIDsForReview(game: .quizReverse).count == 10)
    }

    @Test
    func placingABookCorrectlyRetiresItsMiss() {
        let store = MissedGameQuestionStore(entries: [
            MissedGameQuestionStore.Entry(
                id: UUID(),
                game: .bookOrder,
                bookNames: ["Nahum"],
                chapterNumber: nil,
                topic: "Book order",
                questionID: "Nahum",
                date: Date()
            )
        ])

        store.resolveReviewQuestion(game: .bookOrder, questionID: "Nahum")

        #expect(!store.containsMiss(game: .bookOrder, questionID: "Nahum"))
    }
}
