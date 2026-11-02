import Foundation
import Testing
@testable import Bible

@Suite(.serialized)
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

    @Test func timerLimitsFollowModeAndDifficulty() async throws {
        let defaults = UserDefaults.standard
        let savedDifficulty = defaults.object(forKey: AppStorageKey.quizDifficulty)
        defer {
            if let savedDifficulty {
                defaults.set(savedDifficulty, forKey: AppStorageKey.quizDifficulty)
            } else {
                defaults.removeObject(forKey: AppStorageKey.quizDifficulty)
            }
        }
        _ = await BibleRepository.shared.loadAllBooks()
        let model = QuizGameViewModel(reviewQuestionIDs: ["John 3:16"], mode: .reverse)
        await model.prepareFilter()
        for (difficulty, seconds) in [(QuizDifficulty.easy, nil), (.normal, 20), (.hard, 30)] {
            model.difficulty = difficulty
            model.startQuiz()
            #expect(model.phase == .playing)
            #expect(model.timeLimit == seconds)
            #expect(model.remainingSeconds == (seconds ?? 0))
            #expect(model.isTimerRunning == (seconds != nil))
            if let seconds {
                model.pause()
                await model.runTimer()
                #expect(model.remainingSeconds == seconds)
                #expect(!model.isTimerRunning)
                model.resume()
                #expect(model.isTimerRunning)
                model.toggleTimer()
                #expect(!model.isTimerRunning)
            }
            model.resetToSetup()
        }
        model.mode = .standard
        model.difficulty = .normal
        #expect(model.timeLimit == 15)
        model.difficulty = .hard
        #expect(model.timeLimit == 12)
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

    @Test func legacyReviewPreservesAnswerReferencesWithoutAHint() async throws {
        _ = await BibleRepository.shared.loadAllBooks()
        let model = QuizGameViewModel(reviewQuestionIDs: ["John 3:16"], mode: .reverse)
        await model.prepareFilter()
        model.startQuiz()
        let question = try #require(model.current)
        #expect(question.reference == "John 3:16")
        #expect(question.options.count == 4)
        #expect(question.options.contains(question.verseText))
        #expect(question.optionVerses.map(\.verseText) == question.options)
        #expect(Set(question.optionVerses.map(\.reference)).count == 4)
        #expect(question.optionVerses.first { $0.verseText == question.correctAnswer }?.reference == question.reference)
        for option in question.optionVerses {
            let book = try #require(BibleData.books.first { $0.name == option.bookName })
            let chapter = try #require(book.chapters.first { $0.number == option.chapterNumber })
            #expect(chapter.verses.contains { $0.number == option.verseNumber })
        }
        #expect(model.remainingSeconds == (model.timeLimit ?? 0))
        #expect(model.isTimerRunning == model.isTimed)
        #expect(!model.canRevealContext)
        #expect(model.totalQuestions == 1)
        model.selectOption("not an answer")
        #expect(!model.isAnswered)
        model.resetToSetup()
        #expect(model.current == nil)
    }
}
