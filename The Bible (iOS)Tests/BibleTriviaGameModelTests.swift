import Foundation
import Testing
@testable import Bible

/// Trivia: leaving mid-question and the saved difficulty. Missed questions and pool progress
/// go to in-memory stores, and every default the game writes is put back when each test ends.
@Suite(.serialized)
@MainActor
struct BibleTriviaGameModelTests {
    /// Runs `body`, then puts back every default it added, changed or removed.
    private func withRestoredDefaults(_ body: () async throws -> Void) async rethrows {
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

    @Test func leavingMidQuestionCountsAsTimeUp() async throws {
        try await withRestoredDefaults {
            let missed = MissedGameQuestionStore(entries: [])
            let progress = BibleTriviaProgressStore(inMemory: [:])
            let game = BibleTriviaGameModel(missedQuestions: missed, progressStore: progress)
            await game.load()
            game.startRound()
            let question = try #require(game.currentQuestion)

            game.onDisappear()
            // The unanswered question is recorded as missed and as asked, and the game ends.
            #expect(game.phase == .setup)
            #expect(missed.containsMiss(game: .bibleTrivia, questionID: String(question.id)))
            #expect(progress.progress(for: game.difficulty).completedQuestionIDs.contains(question.id))
        }
    }

    @Test func theChosenDifficultyIsRemembered() async {
        await withRestoredDefaults {
            BibleTriviaGameModel(progressStore: BibleTriviaProgressStore(inMemory: [:])).difficulty = .hard
            #expect(BibleTriviaGameModel(progressStore: BibleTriviaProgressStore(inMemory: [:])).difficulty == .hard)
        }
    }
}
