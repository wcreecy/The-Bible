import Foundation
import Testing
@testable import Bible

/// Standard Quiz (verse → book): review rounds and leaving mid-question.
@Suite(.serialized)
@MainActor
struct QuizStandardModeTests {
    private let settingKeys = [AppStorageKey.quizDifficulty, AppStorageKey.quizSections, AppStorageKey.quizVersePool]

    /// Runs `body`, then puts back the Quiz settings it changed.
    private func withRestoredSettings(_ body: () async throws -> Void) async rethrows {
        let saved = settingKeys.map { UserDefaults.standard.object(forKey: $0) }
        defer {
            for (key, value) in zip(settingKeys, saved) {
                if let value {
                    UserDefaults.standard.set(value, forKey: key)
                } else {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
        }
        try await body()
    }

    @Test func reviewIncludesMissedVersesOutsideTheChosenCategories() async throws {
        _ = await BibleRepository.shared.loadAllBooks()
        try await withRestoredSettings {
            // Only the Law is chosen, but the missed verse is in John.
            QuizGameViewModel().selectedSections = [.law]

            let review = QuizGameViewModel(reviewQuestionIDs: ["John|3|16"], mode: .standard)
            await review.prepareFilter()
            review.startQuiz()

            let question = try #require(review.current)
            #expect(question.correctBook == "John")
            #expect(question.chapter == 3)
            #expect(question.verse == 16)
            review.resetToSetup()
        }
    }

    @Test func leavingAnUntimedQuestionCostsNothing() async throws {
        _ = await BibleRepository.shared.loadAllBooks()
        try await withRestoredSettings {
            let game = QuizGameViewModel(mode: .standard)
            game.difficulty = .easy
            game.pool = .any
            await game.prepareFilter()
            game.startQuiz()
            #expect(game.phase == .playing)

            game.onDisappear()
            // Nothing was recorded, so the question is still waiting.
            #expect(game.phase == .playing)
            #expect(!game.isAnswered)
            #expect(game.session.answered == 0)
            game.resetToSetup()
        }
    }

    @Test func pausingDoesNotGiveBackTime() async throws {
        _ = await BibleRepository.shared.loadAllBooks()
        try await withRestoredSettings {
            let game = QuizGameViewModel(mode: .standard)
            game.difficulty = .normal
            game.pool = .any
            await game.prepareFilter()
            game.startQuiz()

            // Pause and resume quickly, many times. The clock keeps the time already used,
            // so the question doesn't gain time from the restarts.
            for _ in 0..<5 {
                game.pause()
                game.resume()
            }
            #expect(game.isTimerRunning)
            #expect(game.remainingSeconds <= (game.timeLimit ?? 0))
            game.resetToSetup()
        }
    }
}
