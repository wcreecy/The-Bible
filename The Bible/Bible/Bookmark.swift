import Foundation
import SwiftData

@Model
final class Bookmark {
    var bookName: String = ""
    var chapterNumber: Int = 0
    var verseNumber: Int = 0
    var verseText: String = ""
    /// Raw value of the `BibleTranslation` `verseText` is in. Records saved before there
    /// were translations are KJV.
    var translation: String = "kjv"
    var createdAt: Date = Date()

    init() {
        translation = BibleRepository.shared.activeTranslation.rawValue
    }
}

extension Bookmark {
    /// There is a single bookmark, like a bookmark in a book: one exact place the reader marks.
    /// Setting it replaces any other. Continue Reading shows it until the reader moves on to
    /// another chapter (see `ContinueReadingTarget`). The caller saves the context.
    @MainActor
    static func move(
        to bookName: String,
        chapter: Int,
        verse: Int,
        verseText: String,
        translation: BibleTranslation = BibleRepository.shared.activeTranslation,
        in context: ModelContext
    ) throws {
        try context.fetch(FetchDescriptor<Bookmark>()).forEach(context.delete)

        let bookmark = Bookmark()
        bookmark.translation = translation.rawValue
        bookmark.bookName = bookName
        bookmark.chapterNumber = chapter
        bookmark.verseNumber = verse
        bookmark.verseText = verseText
        bookmark.createdAt = Date()
        context.insert(bookmark)
        mirrorToWidget(
            bookName: bookName,
            chapter: chapter,
            verse: verse,
            verseText: verseText,
            translation: translation.rawValue,
            savedAt: bookmark.createdAt
        )
    }

    // MARK: - Widget copy
    // The Continue Reading widget can't read SwiftData, so the bookmark is copied into the app
    // group. `ContinueReadingWidgetMirror` combines it with the reading position.

    /// Copies the newest bookmark, or clears the copy when there is none. Run at launch so a
    /// bookmark that arrived through iCloud reaches the widget.
    @MainActor
    static func mirrorToWidget(in context: ModelContext) {
        var descriptor = FetchDescriptor<Bookmark>(
            sortBy: [SortDescriptor(\Bookmark.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let bookmark = try? context.fetch(descriptor).first else {
            clearWidget()
            return
        }

        mirrorToWidget(
            bookName: bookmark.bookName,
            chapter: bookmark.chapterNumber,
            verse: bookmark.verseNumber,
            verseText: bookmark.verseText,
            translation: bookmark.translation,
            savedAt: bookmark.createdAt
        )
    }

    @MainActor
    static func clearWidget() {
        let shared = UserDefaults(suiteName: "group.bible.app") ?? .standard
        [
            AppStorageKey.bookmarkBook, AppStorageKey.bookmarkChapter, AppStorageKey.bookmarkVerse,
            AppStorageKey.bookmarkText, AppStorageKey.bookmarkTranslation, ContinueReadingWidgetMirror.bookmarkSavedAtKey
        ].forEach { shared.removeObject(forKey: $0) }
        ContinueReadingWidgetMirror.update()
    }

    @MainActor
    private static func mirrorToWidget(
        bookName: String,
        chapter: Int,
        verse: Int,
        verseText: String,
        translation: String,
        savedAt: Date
    ) {
        let shared = UserDefaults(suiteName: "group.bible.app") ?? .standard
        shared.set(bookName, forKey: AppStorageKey.bookmarkBook)
        shared.set(chapter, forKey: AppStorageKey.bookmarkChapter)
        shared.set(verse, forKey: AppStorageKey.bookmarkVerse)
        shared.set(verseText, forKey: AppStorageKey.bookmarkText)
        shared.set(translation, forKey: AppStorageKey.bookmarkTranslation)
        shared.set(savedAt, forKey: ContinueReadingWidgetMirror.bookmarkSavedAtKey)
        ContinueReadingWidgetMirror.update()
    }
}
