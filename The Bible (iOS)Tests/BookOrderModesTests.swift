import Foundation
import Testing
@testable import Bible

/// Book Order's ways to play: Tap in Order, Before or After?, Missing Book and Which Section?.
/// Missed books go to an in-memory store, and every default the game writes is put back.
@Suite(.serialized)
@MainActor
struct BookOrderModesTests {
    private func withRestoredDefaults(_ body: () async throws -> Void) async rethrows {
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
        try await body()
    }

    // MARK: - Tap in Order

    private func tapGame(_ difficulty: BookOrderDifficulty = .normal, source: BookSourceScope = .both) -> BookOrderGameViewModel {
        let game = BookOrderGameViewModel()
        game.difficulty = difficulty
        game.source = source
        game.preparePuzzle(.tapInOrder)
        game.startGame()
        return game
    }

    @Test func tapInOrderUsesShortPuzzlesThatFitTheScreen() async {
        await withRestoredDefaults {
            #expect(tapGame(.easy).correctOrder.count == 5)
            #expect(tapGame(.normal).correctOrder.count == 7)
            #expect(tapGame(.hard).correctOrder.count == 9)
            // There's no full-Bible Tap in Order puzzle; it plays as Hard.
            #expect(tapGame(.fullBible).correctOrder.count == 9)
            // A section smaller than the level plays every book it has.
            #expect(tapGame(.hard, source: .gospels).correctOrder.count == 4)
        }
    }

    @Test func tappingInOrderFinishesAPerfectPuzzle() async {
        await withRestoredDefaults {
            let game = tapGame()
            for book in game.correctOrder {
                game.tap(book, elapsedSeconds: 12)
            }
            #expect(game.showResult)
            #expect(game.wasCorrect)
            #expect(game.booksInOrder == game.correctOrder.count)
        }
    }

    @Test func aWrongTapSaysWhereTheBookGoesAndCountsAsMissed() async {
        await withRestoredDefaults {
            let game = tapGame()
            let order = game.correctOrder
            game.tap(order[2], elapsedSeconds: 1)
            #expect(game.tapPlaced.isEmpty)
            #expect(game.wrongTapHint == "\(order[2]) comes after \(order[1])")

            for book in order {
                game.tap(book, elapsedSeconds: 20)
            }
            #expect(game.showResult)
            #expect(!game.wasCorrect)
            #expect(game.booksInOrder == order.count - 1)
            #expect(game.booksToReview.map(\.book) == [order[2]])
        }
    }

    @Test func aTapPuzzleLeftHalfDoneComesBackWhereItWas() async {
        await withRestoredDefaults {
            let game = tapGame()
            let order = game.correctOrder
            game.tap(order[0], elapsedSeconds: 3)
            game.tap(order[1], elapsedSeconds: 5)
            game.savePuzzle(elapsedSeconds: 5)

            let resumed = BookOrderGameViewModel()
            resumed.difficulty = .normal
            resumed.source = .both
            resumed.preparePuzzle(.tapInOrder)
            #expect(resumed.hasSavedPuzzle)
            #expect(resumed.startGame() == 5)
            #expect(resumed.tapPlaced == Array(order.prefix(2)))
        }
    }

    @Test func classicOnIPhonePlaysAsTapInOrder() async {
        await withRestoredDefaults {
            let game = BookOrderGameViewModel()
            game.mode = .classic
            #expect(game.playMode(isWide: false) == .tapInOrder)
            #expect(game.playMode(isWide: true) == .classic)
            #expect(!BookOrderMode.available(isWide: false).contains(.classic))
        }
    }

    // MARK: - Quick rounds

    private func round(_ mode: BookOrderMode, _ difficulty: BookOrderDifficulty = .normal, missed: MissedGameQuestionStore, reviewBooks: [String] = []) -> BookOrderQuickRound {
        let round = BookOrderQuickRound(mode: mode, difficulty: difficulty, source: .both, reviewBooks: reviewBooks, missedQuestions: missed)
        round.start()
        return round
    }

    private func canonIndex(_ book: String) -> Int {
        BibleCanon.fallbackCanon.firstIndex(of: book)!
    }

    @Test func beforeOrAfterAsksForTheEarlierBookAndMovesStraightOn() async {
        let missed = MissedGameQuestionStore(entries: [])
        await withRestoredDefaults {
            let game = round(.beforeAfter, .hard, missed: missed)
            for _ in 0..<5 {
                let question = game.current!
                guard case .beforeAfter(let a, let b) = question.kind else { Issue.record("Wrong kind"); return }
                // Hard pairs are next to each other, or one apart.
                #expect(abs(canonIndex(a) - canonIndex(b)) <= 2)
                #expect(canonIndex(question.correctAnswer) == min(canonIndex(a), canonIndex(b)))
                game.choose(question.correctAnswer)
            }
            #expect(game.session.score == 5)
            #expect(game.currentIndex == 5)
            #expect(game.lastFeedback?.isCorrect == true)
        }
    }

    @Test func beforeOrAfterEndsWhenTheMinuteRunsOut() async {
        let missed = MissedGameQuestionStore(entries: [])
        await withRestoredDefaults {
            // A best score left from earlier play would outrank this round's single answer.
            UserDefaults.standard.removeObject(forKey: "bookorderBestScore_beforeAfter_both_easy")
            let clock = ManualSleeper()
            let game = BookOrderQuickRound(mode: .beforeAfter, difficulty: .easy, source: .both, missedQuestions: missed,
                                           sleep: clock.sleep(for:), now: { clock.date })
            game.start()
            game.choose(game.current!.correctAnswer)
            await clock.advance(by: 30)
            #expect(game.remainingSeconds == 30)
            #expect(!game.isFinished)

            await clock.advance(by: 30)
            #expect(game.isFinished)
            #expect(game.bestBeforeAfterScore == 1)
        }
    }

    @Test func missingBookLeavesOneBookOutOfARunOfFour() async {
        let missed = MissedGameQuestionStore(entries: [])
        await withRestoredDefaults {
            let game = round(.missingBook, .hard, missed: missed)
            #expect(game.questions.count == BookOrderQuickRound.questionsPerRound)
            for question in game.questions {
                guard case .missingBook(let run) = question.kind else { Issue.record("Wrong kind"); return }
                #expect(run.count == 4)
                #expect(run.filter { $0 == nil }.count == 1)
                #expect(question.options.count == 4)
                #expect(Set(question.options).count == 4)
                #expect(question.options.contains(question.correctAnswer))
                // No wrong choice is a book already shown in the run.
                #expect(question.options.allSatisfy { $0 == question.correctAnswer || !run.contains($0) })
            }
        }
    }

    @Test func aMissIsSavedByBookAndARightAnswerClearsIt() async {
        let missed = MissedGameQuestionStore(entries: [])
        await withRestoredDefaults {
            let game = round(.missingBook, missed: missed)
            let question = game.current!
            let wrong = question.options.first { $0 != question.correctAnswer }!
            game.choose(wrong)
            #expect(missed.containsMiss(game: .bookOrder, questionID: question.book))

            let review = round(.missingBook, missed: missed, reviewBooks: [question.book])
            #expect(review.questions.count == 1)
            #expect(review.current?.correctAnswer == question.book)
            review.choose(question.book)
            #expect(!missed.containsMiss(game: .bookOrder, questionID: question.book))
        }
    }

    @Test func aBeforeOrAfterReviewAsksOnePairPerMissedBookWithNoClock() async {
        let missed = MissedGameQuestionStore(entries: [])
        // Includes the first and last books, whose pairs can only go one way.
        let books = ["Genesis", "Ruth", "Psalms", "Matthew", "Revelation"]
        await withRestoredDefaults {
            let review = round(.beforeAfter, .hard, missed: missed, reviewBooks: books)
            #expect(!review.isTimed)
            #expect(review.questions.count == books.count)
            #expect(Set(review.questions.map(\.book)) == Set(books))
            for question in review.questions {
                guard case .beforeAfter(let a, let b) = question.kind else { Issue.record("Wrong kind"); return }
                #expect([a, b].contains(question.book))
                #expect(a != b)
                #expect(abs(canonIndex(a) - canonIndex(b)) <= 2)
                #expect(canonIndex(question.correctAnswer) == min(canonIndex(a), canonIndex(b)))
            }

            // Like the other rounds, an answer waits for Next.
            let first = review.current!
            review.choose(first.correctAnswer)
            #expect(review.isAnswered)
            #expect(review.currentIndex == 0)
            review.next()
            #expect(review.currentIndex == 1)
        }
    }

    @Test func aBeforeOrAfterReviewClearsAMissAnsweredRight() async {
        let missed = MissedGameQuestionStore(entries: [])
        missed.record(game: .bookOrder, mode: "beforeAfter", bookNames: ["Ruth"], topic: "Book order", questionID: "Ruth")
        await withRestoredDefaults {
            let review = round(.beforeAfter, missed: missed, reviewBooks: ["Ruth"])
            review.choose(review.current!.correctAnswer)
            #expect(!missed.containsMiss(game: .bookOrder, mode: "beforeAfter", questionID: "Ruth"))
        }
    }

    @Test func aWhichSectionReviewAsksAboutTheMissedBooks() async {
        let missed = MissedGameQuestionStore(entries: [])
        let books = ["Ruth", "Romans", "Jude"]
        await withRestoredDefaults {
            let review = round(.whichSection, missed: missed, reviewBooks: books)
            #expect(review.questions.count == books.count)
            #expect(Set(review.questions.map(\.book)) == Set(books))
        }
    }

    @Test func whichSectionOffersEveryPartOfTheBible() async {
        let missed = MissedGameQuestionStore(entries: [])
        await withRestoredDefaults {
            let game = round(.whichSection, missed: missed)
            let question = game.current!
            guard case .whichSection(let book) = question.kind else { Issue.record("Wrong kind"); return }
            #expect(question.options.count == BibleBookGroup.allCases.count)
            #expect(question.correctAnswer == BibleBookGroup.group(for: book).title)
            #expect(BookOrderQuickRound.books(inSection: question.correctAnswer).contains(book))

            game.choose(question.correctAnswer)
            #expect(game.isAnswered)
            for _ in 1..<game.questions.count {
                game.next()
                game.choose(game.current!.correctAnswer)
            }
            game.next()
            #expect(game.isFinished)
            #expect(game.session.score == BookOrderQuickRound.questionsPerRound)
        }
    }
}
