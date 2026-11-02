import Foundation
import Testing
@testable import Bible

@MainActor
struct QuizReverseModeTests {
    @Test func reverseQuestionsUseReferencesAndFourDistinctTexts() async throws {
        _ = await BibleRepository.shared.loadAllBooks()
        await QuizVerseFilter.prepare()
        for difficulty in QuizDifficulty.allCases {
            var source = QuizReverseQuestionSource(
                difficulty: difficulty, pool: .any,
                selectedSections: Set(QuizVerseSection.allCases), favoriteVerses: []
            )
            source.prepare()
            let verses = source.buildQuestionBag()
            #expect(!verses.isEmpty)
            for verse in verses.prefix(20) {
                let wrong = source.wrongChoices(for: verse)
                #expect(wrong.count == 3)
                #expect(Set((wrong + [verse]).map(\.normalizedText)).count == 4)
                #expect(wrong.allSatisfy { $0.reference != verse.reference })
                if difficulty == .hard {
                    #expect(wrong.allSatisfy { $0.bookName == verse.bookName })
                }
            }
        }
    }

    @Test func questionAnswerAndReviewIdentityFollowTheMode() {
        let standard = QuizQuestion(
            verseText: "In the beginning God created the heaven and the earth.",
            correctBook: "Genesis", chapter: 1, verse: 1, contextText: nil,
            options: ["Genesis", "Exodus", "John", "Acts"]
        )
        var reverse = standard
        reverse.mode = .reverse
        #expect(standard.correctAnswer == "Genesis")
        #expect(standard.reviewID == "Genesis|1|1")
        #expect(reverse.prompt == "Genesis 1:1")
        #expect(reverse.correctAnswer == standard.verseText)
        #expect(reverse.reviewID == "Genesis 1:1")
    }

    @Test func legacyReviewStartsInReverseWithoutATimerOrHint() async throws {
        _ = await BibleRepository.shared.loadAllBooks()
        let model = QuizGameViewModel(reviewQuestionIDs: ["John 3:16"], mode: .reverse)
        await model.prepareFilter()
        model.startQuiz()
        let question = try #require(model.current)
        #expect(question.reference == "John 3:16")
        #expect(question.options.count == 4)
        #expect(question.options.contains(question.verseText))
        #expect(!model.isTimed)
        #expect(!model.isTimerRunning)
        #expect(!model.canRevealContext)
        #expect(model.totalQuestions == 1)
        model.selectOption("not an answer")
        #expect(!model.isAnswered)
        model.resetToSetup()
        #expect(model.current == nil)
    }
}
