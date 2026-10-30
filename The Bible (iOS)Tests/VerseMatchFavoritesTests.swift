import Foundation
import Testing
@testable import Bible

/// Whether the Favorites pool can be chosen must follow the saved verses, not whichever pool
/// happens to be selected.
@MainActor
struct VerseMatchFavoritesTests {
    private let genesis = VerseMatchVerse(bookName: "Genesis", chapterNumber: 1, verseNumber: 1, verseText: "In the beginning God created the heaven and the earth.")
    private let john = VerseMatchVerse(bookName: "John", chapterNumber: 3, verseNumber: 16, verseText: "For God so loved the world.")

    /// Runs `body` with the Verse Match settings set as given, then puts the stored settings back.
    private func withSettings(
        pool: VerseMatchPool,
        sections: Set<QuizVerseSection>? = nil,
        _ body: (VerseMatchGameViewModel) -> Void
    ) {
        let defaults = UserDefaults.standard
        let keys = [AppStorageKey.verseMatchPool, AppStorageKey.verseMatchSections, AppStorageKey.verseMatchScope]
        let saved = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, saved) {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
        }

        defaults.set(pool.rawValue, forKey: AppStorageKey.verseMatchPool)
        defaults.removeObject(forKey: AppStorageKey.verseMatchSections)
        defaults.removeObject(forKey: AppStorageKey.verseMatchScope)

        let model = VerseMatchGameViewModel()
        if let sections { model.selectedSections = sections }
        body(model)
    }

    @Test
    func withNoSavedVersesFavoritesIsUnavailableEvenWhenWellKnownVersesExist() {
        withSettings(pool: .wellKnown) { model in
            model.onAppear() // loads the well-known verses
            model.favoriteVerses = []

            #expect(!model.isFavoritesAvailable)
        }
    }

    @Test
    func savedVersesMakeFavoritesAvailableInEveryPool() {
        for pool in VerseMatchPool.allCases {
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
    func theSameSavedVerseAppearingTwiceStillCountsOnce() {
        withSettings(pool: .favorites, sections: [.gospels]) { model in
            model.favoriteVerses = [john, john]

            #expect(model.isFavoritesAvailable)
        }
    }
}
