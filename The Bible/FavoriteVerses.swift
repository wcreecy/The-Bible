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
        favorites: [Favorite],
        in context: ModelContext
    ) throws -> Bool {
        let existing = matching(favorites, bookName: bookName, chapterNumber: chapterNumber, verseNumber: verseNumber)
        if existing.isEmpty {
            context.insert(
                Favorite(bookName: bookName, chapterNumber: chapterNumber, verseNumber: verseNumber, verseText: verseText)
            )
        } else {
            // Removing just one copy would leave the verse favorited.
            for favorite in existing {
                context.delete(favorite)
            }
        }
        try context.save()
        return existing.isEmpty
    }
}

extension Favorite {
    /// "John 3:16"
    var reference: String {
        "\(bookName) \(chapterNumber):\(verseNumber)"
    }

    /// The verse as the reader shows it now, falling back to the text saved with the
    /// favorite (for example while the Bible is still loading).
    @MainActor
    var currentVerseText: String {
        BibleData.books.first { $0.name == bookName }?
            .chapters.first { $0.number == chapterNumber }?
            .verses.first { $0.number == verseNumber }?
            .text ?? verseText
    }

    /// Same format as sharing a verse from the reader.
    @MainActor
    var shareText: String {
        "\(currentVerseText)\n\(reference)"
    }
}
