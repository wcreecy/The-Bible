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
    }
}
