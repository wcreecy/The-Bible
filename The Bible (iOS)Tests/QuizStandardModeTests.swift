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

    // MARK: - Leaving, hints and rotation

    /// Runs `body`, then puts back every default it added, changed or removed (settings,
    /// stats, streaks and question history).
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

    @Test func leavingATimedQuestionCountsAsTimeUp() async throws {
        _ = await BibleRepository.shared.loadAllBooks()
        try await withRestoredDefaults {
            let missed = MissedGameQuestionStore(entries: [])
            let game = QuizGameViewModel(mode: .standard, missedQuestions: missed)
            game.difficulty = .normal
            game.pool = .any
            await game.prepareFilter()
            game.startQuiz()
            let question = try #require(game.current)

            game.onDisappear()
            // The unanswered verse is recorded as missed, and the game ends.
            #expect(game.phase == .setup)
            #expect(missed.containsMiss(game: .bibleQuiz, questionID: question.reviewID))
        }
    }

    @Test func thePreviousVerseCostsTimeOnlyWhenTimed() async throws {
        _ = await BibleRepository.shared.loadAllBooks()
        try await withRestoredDefaults {
            let game = QuizGameViewModel(mode: .standard, missedQuestions: MissedGameQuestionStore(entries: []))
            game.pool = .any
            await game.prepareFilter()

            for difficulty in [QuizDifficulty.normal, .easy] {
                game.difficulty = difficulty
                // Most verses have one before them; start again until this one does.
                game.startQuiz()
                for _ in 0..<20 where game.current?.contextText == nil {
                    game.resetToSetup()
                    game.startQuiz()
                }
                #expect(game.canRevealContext)

                game.revealContext()
                #expect(game.current?.contextRevealed == true)
                if let timeLimit = game.timeLimit {
                    #expect(game.remainingSeconds == timeLimit - QuizDifficulty.contextCost)
                } else {
                    // Easy has no timer, so the previous verse is free.
                    #expect(game.remainingSeconds == 0)
                }
                game.resetToSetup()
            }
        }
    }

    @Test func wellKnownVersesAllComeUpBeforeAnyRepeats() async throws {
        _ = await BibleRepository.shared.loadAllBooks()
        try await withRestoredDefaults {
            // Start from no history, so an unfinished pass on this device can't affect the result.
            UserDefaults.standard.removeObject(forKey: AppStorageKey.gameQuestionRecency)

            let game = QuizGameViewModel(mode: .standard, missedQuestions: MissedGameQuestionStore(entries: []))
            game.difficulty = .easy
            game.pool = .wellKnown
            game.selectedSections = [.gospels]
            await game.prepareFilter()

            // The same source the game draws from, so the count matches what it can ask.
            var source = QuizReverseQuestionSource(
                difficulty: .easy, pool: .wellKnown, selectedSections: [.gospels], favoriteVerses: []
            )
            source.prepare()
            let poolSize = Set(source.buildQuestionBag().map(\.reference)).count
            // With fewer than a game's worth, other verses are mixed in, so there's no fixed pool.
            try #require(poolSize > QuizGameViewModel.questionsPerGame)

            // Play whole games, answering each verse, until every well-known Gospel verse has been asked.
            var asked: [String] = []
            while asked.count < poolSize {
                game.startQuiz()
                try #require(game.phase == .playing)
                while game.phase == .playing, let question = game.current {
                    asked.append(question.reference)
                    game.selectOption(question.correctAnswer)
                    game.showNext()
                }
            }

            // Whole games before the pass runs out never repeat a verse. The game that finishes
            // the pass mixes its last verses with the start of the next pass, in random order,
            // so by the end of that game every verse has been asked.
            let perGame = QuizGameViewModel.questionsPerGame
            let gamesBeforeWrap = poolSize / perGame
            let beforeWrap = Array(asked.prefix(gamesBeforeWrap * perGame))
            #expect(Set(beforeWrap).count == beforeWrap.count)
            #expect(Set(asked.prefix((gamesBeforeWrap + 1) * perGame)).count >= poolSize)
        }
    }
}
