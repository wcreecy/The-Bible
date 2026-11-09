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

        // Swapping two neighbors only needs one of them moved.
        #expect(items.map(\.book) == ["Nahum"])
        #expect(items.map(\.previousBook) == ["Micah"])
    }

    @Test
    func oneBookOutOfPlaceDoesNotMarkTheRestWrong() {
        let correct = ["Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy"]
        let current = ["Exodus", "Leviticus", "Numbers", "Deuteronomy", "Genesis"]

        let inOrder = BookOrderGameViewModel.inOrderPositions(current: current, correct: correct)
        let items = BookOrderGameViewModel.reviewItems(current: current, correct: correct)

        #expect(inOrder == [0, 1, 2, 3])
        #expect(items.map(\.book) == ["Genesis"])
        #expect(items.first?.placementHint == String(localized: "Goes before Exodus"))
    }

    @Test
    func aReversedRunNeedsAllButOneBookMoved() {
        let correct = ["Matthew", "Mark", "Luke", "John"]
        let inOrder = BookOrderGameViewModel.inOrderPositions(current: correct.reversed(), correct: correct)
        #expect(inOrder.count == 1)
    }

    // MARK: - Book Order puzzles

    @Test
    func smallSectionsPlayEveryDifficultyAsTheShortestThatFits() {
        // Gospels has 4 books, so every level is the same 4-book puzzle.
        #expect(BookOrderGameViewModel.effectiveDifficulty(.hard, bookCount: 4) == .easy)
        #expect(BookOrderGameViewModel.effectiveDifficulty(.normal, bookCount: 5) == .easy)
        // History has 12: Hard uses all 12, Normal still uses 10.
        #expect(BookOrderGameViewModel.effectiveDifficulty(.hard, bookCount: 12) == .hard)
        #expect(BookOrderGameViewModel.effectiveDifficulty(.normal, bookCount: 12) == .normal)
        #expect(BookOrderGameViewModel.effectiveDifficulty(.fullBible, bookCount: 66) == .fullBible)
    }

    @Test
    func everyBookIncludingTheEndsComesUpInTurn() {
        let books = BibleCanon.fallbackCanon
        var lastSeen: [String: Int] = [:]
        var generator = SystemRandomNumberGenerator()
        var roundsSinceGenesis = 0
        var longestWait = 0
        // Easy rounds of 5. Each round includes the book shown longest ago, so no book waits
        // more than 66 rounds. Picked at random, Genesis (in only one possible run) often would.
        for tick in 1...600 {
            let start = BookOrderGameViewModel.runStart(books: books, length: 5, lastSeen: lastSeen, using: &generator)
            let run = books[start..<(start + 5)]
            for book in run {
                lastSeen[book] = tick
            }
            roundsSinceGenesis = run.contains("Genesis") ? 0 : roundsSinceGenesis + 1
            longestWait = max(longestWait, roundsSinceGenesis)
        }
        #expect(lastSeen.count == 66)
        #expect(longestWait <= 66)
    }

    @Test
    func shufflesLeaveAtMostHalfTheBooksInOrder() {
        let run = ["Matthew", "Mark", "Luke", "John"]
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let shuffled = BookOrderGameViewModel.scrambled(run, using: &generator)
            #expect(Set(shuffled) == Set(run))
            #expect(BookOrderGameViewModel.inOrderPositions(current: shuffled, correct: run).count <= 2)
        }
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
