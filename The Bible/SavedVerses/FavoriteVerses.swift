import Foundation
import SwiftData

/// Shared rules for favorite verses, used by the reader, Favorites, flashcards, and games.
@MainActor
enum FavoriteVerses {
    /// Every saved favorite for a verse. Synced devices can briefly hold more than one.
    static func matching(
        _ favorites: [Favorite],
        bookName: String,
        chapterNumber: Int,
        verseNumber: Int
    ) -> [Favorite] {
        favorites.filter {
            $0.bookName == bookName && $0.chapterNumber == chapterNumber && $0.verseNumber == verseNumber
        }
    }

    /// Adds the verse as a favorite, or removes every copy if it's already one, then saves.
    /// Returns true when the verse was added. Throws if saving fails.
    @discardableResult
    static func toggle(
        bookName: String,
        chapterNumber: Int,
        verseNumber: Int,
        verseText: String,
        translation: BibleTranslation = BibleRepository.shared.activeTranslation,
        favorites: [Favorite],
        in context: ModelContext
    ) throws -> Bool {
        let existing = matching(favorites, bookName: bookName, chapterNumber: chapterNumber, verseNumber: verseNumber)
        if existing.isEmpty {
            let favorite = Favorite(bookName: bookName, chapterNumber: chapterNumber, verseNumber: verseNumber, verseText: verseText)
            favorite.translation = translation.rawValue
            context.insert(favorite)
        } else {
            // Removing just one copy would leave the verse favorited.
            for favorite in existing {
                context.delete(favorite)
            }
        }
        try context.save()
        if existing.isEmpty {
            TodayChallengeStore.shared.recordFavoriteVerseSaved()
        }
        return existing.isEmpty
    }
}

extension Favorite {
    /// "John 3:16"
    var reference: String {
        "\(bookName) \(chapterNumber):\(verseNumber)"
    }

    /// The verse as the reader shows it now, so corrections to the bundled text reach older
    /// favorites. A favorite saved in another translation keeps the text it was saved with,
    /// as does any favorite while the Bible is still loading.
    @MainActor
    var currentVerseText: String {
        guard translation == BibleRepository.shared.activeTranslation.rawValue,
              let text = BibleData.books.first(where: { $0.name == bookName })?
                .chapters.first(where: { $0.number == chapterNumber })?
                .verses.first(where: { $0.number == verseNumber })?
                .text,
              !text.isEmpty else { return verseText }
        return text
    }

    /// "KJV", for showing beside the reference.
    var translationAbbreviation: String {
        BibleTranslation.abbreviation(for: translation)
    }

    /// Same format as sharing a verse from the reader.
    @MainActor
    var shareText: String {
        "\(currentVerseText)\n\(reference) \(translationAbbreviation)"
    }
}
