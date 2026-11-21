import Foundation
import Testing
@testable import Bible

/// Standard Quiz on the manual clock: the timer, lifelines, close guesses, and bonuses.
/// Missed verses go to an in-memory store, and every default the game writes is put back when
/// each test ends.
@Suite(.serialized)
@MainActor
struct QuizGameplayTests {
    private func withGame(
        difficulty: QuizDifficulty = .normal,
        _ body: (QuizGameViewModel, ManualSleeper) async throws -> Void
    ) async throws {
        _ = await BibleRepository.shared.loadAllBooks()
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

        let clock = ManualSleeper()
        let game = QuizGameViewModel(
            mode: .standard,
            missedQuestions: MissedGameQuestionStore(entries: []),
            sleep: clock.sleep(for:),
            now: { clock.date }
        )
        game.difficulty = difficulty
        game.pool = .any
        game.selectedSections = Set(QuizVerseSection.allCases)
        await game.prepareFilter()
        try await body(game, clock)
        game.resetToSetup()
    }

    /// Starts games until `isWanted` holds for the first question, for checks that need a
    /// particular kind of verse.
    private func startUntil(_ game: QuizGameViewModel, _ isWanted: (QuizQuestion) -> Bool) throws {
        for _ in 0..<50 {
            game.startQuiz()
            if let current = game.current, isWanted(current) { return }
            game.resetToSetup()
        }
        Issue.record("No question matched after 50 games")
    }

    private func wrongAnswer(in game: QuizGameViewModel) -> String {
        let current = game.current!
        return current.options.first { $0 != current.correctAnswer && !current.removedOptions.contains($0) }!
    }

    @Test func theTimerRunsOutAndPausingStopsIt() async throws {
        try await withGame { game, clock in
            game.startQuiz()
            let limit = try #require(game.timeLimit)
            let timer = Task { await game.runTimer() }
            await clock.advance(by: 5)
            #expect(game.remainingSeconds == limit - 5)

            game.pause()
            timer.cancel()
            await clock.advance(by: 30)
            game.resume()
            let resumed = Task { await game.runTimer() }
            await clock.advance(by: Double(limit - 5))
            #expect(game.current?.outcome == .timedOut)
            resumed.cancel()
        }
    }

    @Test func fiftyFiftyRemovesTwoWrongBooksOncePerGame() async throws {
        try await withGame { game, _ in
            game.startQuiz()
            let current = try #require(game.current)
            game.use(.fiftyFifty)

            let removed = try #require(game.current?.removedOptions)
            #expect(removed.count == 2)
            #expect(!removed.contains(current.correctAnswer))
            // A removed answer can't be chosen.
            game.selectOption(try #require(removed.first))
            #expect(!game.isAnswered)

            game.selectOption(current.correctAnswer)
            game.showNext()
            #expect(!game.canUse(.fiftyFifty))
        }
    }

    @Test func theSectionHintNamesThePartOfTheBible() async throws {
        try await withGame(difficulty: .easy) { game, _ in
            game.startQuiz()
            let book = try #require(game.current?.correctBook)
            let section = try #require(QuizVerseSection.containing(book))
            #expect(game.canUse(.sectionHint))
            game.use(.sectionHint)
            #expect(game.sectionHint?.contains(String(localized: section.title)) == true)
        }
    }

    @Test func extraTimeAddsTenSecondsOncePerGameAndIsNotOnEasy() async throws {
        try await withGame { game, clock in
            game.startQuiz()
            let timer = Task { await game.runTimer() }
            await clock.advance(by: 5)
            let limit = try #require(game.timeLimit)
            #expect(game.remainingSeconds == limit - 5)

            #expect(game.canUse(.extraTime))
            game.use(.extraTime)
            #expect(game.remainingSeconds == limit - 5 + QuizLifeline.extraSeconds)
            #expect(!game.canUse(.extraTime))
            #expect(!game.availableLifelines.contains(.extraTime))
            timer.cancel()
        }

        try await withGame(difficulty: .easy) { game, _ in
            game.startQuiz()
            #expect(!game.offers(.extraTime))
            #expect(!game.availableLifelines.contains(.extraTime))
        }
    }

    @Test func extraTimeDoesNotWidenTheSpeedBonusWindow() async throws {
        try await withGame { game, clock in
            game.startQuiz()
            let limit = try #require(game.timeLimit)
            // Past the first third of the base time, so no speed bonus, even with ten more seconds.
            await clock.advance(by: Double(limit) / 3 + 1)
            game.use(.extraTime)
            game.selectOption(try #require(game.current?.correctAnswer))
            #expect(game.current?.earnedSpeedBonus == false)
        }
    }

    @Test func theSectionHintNeverNamesTheOnlyBookInASection() {
        // Acts and Revelation are one book each, so their hints name a neighboring section too.
        for section in QuizVerseSection.allCases where section.bookNames.count == 1 {
            let book = section.bookNames[0]
            #expect(section.hintPhrase != book)
            #expect(section.hintPhrase.contains(" or "))
            #expect(section.hintPhrase.contains(book))
        }
        // Everything else names the whole section, which is more than one book.
        for section in QuizVerseSection.allCases where section.bookNames.count > 1 {
            #expect(!section.hintPhrase.contains(" or "))
        }
        #expect(QuizVerseSection.acts.hintPhrase == "the Gospels or Acts")
        #expect(QuizVerseSection.revelation.hintPhrase == "the Epistles or Revelation")
    }

    @Test func hardHasNoSectionHint() async throws {
        try await withGame(difficulty: .hard) { game, _ in
            // Every Hard choice is from the same part of the Bible, so the hint would say nothing.
            try startUntil(game) { question in
                Set(question.options.compactMap(QuizVerseSection.containing)).count == 1
            }
            #expect(!game.canUse(.sectionHint))
        }
    }

    @Test func aWrongBookInTheRightSectionIsCalledClose() async throws {
        try await withGame { game, _ in
            try startUntil(game) { question in
                let section = QuizVerseSection.containing(question.correctBook)
                return question.options.contains { $0 != question.correctBook && QuizVerseSection.containing($0) == section }
            }
            let current = try #require(game.current)
            let section = try #require(QuizVerseSection.containing(current.correctBook))
            let close = try #require(current.options.first {
                $0 != current.correctBook && QuizVerseSection.containing($0) == section
            })
            game.selectOption(close)
            #expect(game.closeGuessNote?.contains(String(localized: section.title)) == true)
        }
    }

    @Test func theChapterBonusFollowsACorrectBook() async throws {
        try await withGame { game, _ in
            try startUntil(game) { !$0.chapterOptions.isEmpty }
            let current = try #require(game.current)
            #expect(current.chapterOptions.contains(current.chapter))
            #expect(!game.isChapterBonusOpen)

            game.selectOption(current.correctAnswer)
            #expect(game.isChapterBonusOpen)
            game.guessChapter(current.chapter)
            #expect(!game.isChapterBonusOpen)
            #expect(game.chapterBonusCount == 1)
        }
    }

    @Test func aWrongBookHasNoChapterBonusAndEasyNeverDoes() async throws {
        try await withGame { game, _ in
            try startUntil(game) { !$0.chapterOptions.isEmpty }
            game.selectOption(wrongAnswer(in: game))
            #expect(!game.isChapterBonusOpen)
        }
        try await withGame(difficulty: .easy) { game, _ in
            game.startQuiz()
            #expect(game.current?.chapterOptions.isEmpty == true)
        }
    }

    @Test func aQuickCorrectAnswerEarnsASpeedBonus() async throws {
        try await withGame { game, clock in
            game.startQuiz()
            await clock.advance(by: 3)
            game.selectOption(try #require(game.current?.correctAnswer))
            #expect(game.current?.earnedSpeedBonus == true)

            game.showNext()
            await clock.advance(by: 7)
            game.selectOption(try #require(game.current?.correctAnswer))
            #expect(game.current?.earnedSpeedBonus == false)

            game.showNext()
            game.toggleTimer()
            game.selectOption(try #require(game.current?.correctAnswer))
            // The timer was off, so there's no bonus however quick it was.
            #expect(game.current?.earnedSpeedBonus == false)
            #expect(game.speedBonusCount == 1)
            #expect(game.points == 3 + 1 + game.chapterBonusCount)
        }
    }

    @Test func helpUsedIsCountedAsHints() async throws {
        try await withGame { game, _ in
            try startUntil(game) { $0.contextText != nil }
            game.use(.fiftyFifty)
            game.revealContext()
            game.selectOption(try #require(game.current?.correctAnswer))
            #expect(game.session.entries.last?.hintCount == 2)
        }
    }

}
