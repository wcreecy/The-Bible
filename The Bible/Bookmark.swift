import Foundation
import SwiftData

@Model
final class Bookmark {
    var bookName: String = ""
    var chapterNumber: Int = 0
    var verseNumber: Int = 0
    var verseText: String = ""
    var createdAt: Date = Date()

    init() {}
}

extension Bookmark {
    /// There is a single bookmark (the Continue Reading point), so setting one replaces any others.
    /// The caller saves the context.
    static func move(
        to bookName: String,
        chapter: Int,
        verse: Int,
        verseText: String,
        in context: ModelContext
    ) throws {
        try context.fetch(FetchDescriptor<Bookmark>()).forEach(context.delete)

        let bookmark = Bookmark()
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
            verseText: verseText
        )
    }

    /// Keeps the Bookmark widget independent from the reader's automatic last-read position.
    static func mirrorToWidget(in context: ModelContext) {
        let descriptor = FetchDescriptor<Bookmark>(
            sortBy: [SortDescriptor(\Bookmark.createdAt, order: .reverse)]
        )
        guard let bookmark = try? context.fetch(descriptor).first else {
            clearWidget()
            return
        }

        mirrorToWidget(
            bookName: bookmark.bookName,
            chapter: bookmark.chapterNumber,
            verse: bookmark.verseNumber,
            verseText: bookmark.verseText
        )
    }

    static func clearWidget() {
        let shared = UserDefaults(suiteName: "group.bible.app") ?? .standard
        ["bookmarkBook", "bookmarkChapter", "bookmarkVerse", "bookmarkText"].forEach {
            shared.removeObject(forKey: $0)
        }
        DebouncedWidgetReloader.shared.reload(kind: "LastReadWidget")
    }

    private static func mirrorToWidget(
        bookName: String,
        chapter: Int,
        verse: Int,
        verseText: String
    ) {
        let shared = UserDefaults(suiteName: "group.bible.app") ?? .standard
        shared.set(bookName, forKey: "bookmarkBook")
        shared.set(chapter, forKey: "bookmarkChapter")
        shared.set(verse, forKey: "bookmarkVerse")
        shared.set(verseText, forKey: "bookmarkText")
        DebouncedWidgetReloader.shared.reload(kind: "LastReadWidget")
    }
}
