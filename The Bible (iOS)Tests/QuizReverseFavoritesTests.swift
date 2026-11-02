import Foundation
import Testing
@testable import Bible

/// Whether the Favorites pool can be chosen must follow the saved verses, not whichever pool
/// happens to be selected.
@Suite(.serialized)
@MainActor
struct QuizReverseFavoritesTests {
    private let genesis = QuizVerse(bookName: "Genesis", chapterNumber: 1, verseNumber: 1, verseText: "In the beginning God created the heaven and the earth.")
    private let john = QuizVerse(bookName: "John", chapterNumber: 3, verseNumber: 16, verseText: "For God so loved the world.")

    /// Runs `body` with the Quiz Reverse settings set as given, then puts the stored settings back.
    private func withSettings(
        pool: QuizReversePool,
        sections: Set<QuizVerseSection>? = nil,
        _ body: (QuizGameViewModel) -> Void
    ) {
        let defaults = UserDefaults.standard
        let keys = [AppStorageKey.quizVersePool, AppStorageKey.quizSections, AppStorageKey.quizScope]
        let saved = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, saved) {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
        }

        defaults.set(pool.rawValue, forKey: AppStorageKey.quizVersePool)
        defaults.removeObject(forKey: AppStorageKey.quizSections)
        defaults.removeObject(forKey: AppStorageKey.quizScope)

        let model = QuizGameViewModel(mode: .reverse)
        if let sections { model.selectedSections = sections }
        body(model)
    }

    @Test
    func withNoSavedVersesFavoritesIsUnavailableEvenWhenWellKnownVersesExist() {
        withSettings(pool: .wellKnown) { model in
            model.onAppear()
            model.favoriteVerses = []

            #expect(!model.isFavoritesAvailable)
        }
    }

    @Test
    func savedVersesMakeFavoritesAvailableInEveryPool() {
        for pool in QuizReversePool.allCases {
            withSettings(pool: pool) { model in
                model.favoriteVerses = [genesis]

                #expect(model.isFavoritesAvailable, "Favorites should be available with the \(pool.rawValue) pool selected")
            }
        }
    }

    @Test
    func favoritesOutsideTheChosenCategoriesDoNotCount() {
        withSettings(pool: .any, sections: [.gospels]) { model in
            model.favoriteVerses = [genesis]
            #expect(!model.isFavoritesAvailable)

            model.favoriteVerses = [genesis, john]
            #expect(model.isFavoritesAvailable)
        }
    }

    @Test
    func standardUsesOnlyFavoritesInTheSelectedCategories() async throws {
        _ = await BibleRepository.shared.loadAllBooks()
        await QuizVerseFilter.prepare()
        withSettings(pool: .favorites, sections: [.gospels]) { model in
            model.mode = .standard
            #expect(!model.canStart)
            model.favoriteVerses = [genesis, john, john]
            #expect(model.canStart)
            model.startQuiz()
            #expect(model.totalQuestions == 1)
            #expect(model.current?.reference == "John 3:16")
            #expect(model.current?.correctAnswer == "John")
            #expect(model.current?.options.count == 4)
            #expect(model.current?.contextText != nil)
            model.resetToSetup()
        }
    }

    @Test
    func standardWellKnownPoolAndAnyVerseCanStart() async throws {
        _ = await BibleRepository.shared.loadAllBooks()
        await QuizVerseFilter.prepare()
        for pool in [QuizReversePool.wellKnown, .any] {
            withSettings(pool: pool) { model in
                model.mode = .standard
                model.startQuiz()
                #expect(model.phase == .playing)
                #expect(model.totalQuestions == QuizGameViewModel.questionsPerGame)
                #expect(model.current?.options.contains(model.current?.correctBook ?? "") == true)
                model.resetToSetup()
            }
        }
    }

    @Test
    func theSameSavedVerseAppearingTwiceStillCountsOnce() {
        withSettings(pool: .favorites, sections: [.gospels]) { model in
            model.favoriteVerses = [john, john]

            #expect(model.isFavoritesAvailable)
        }
    }
}
