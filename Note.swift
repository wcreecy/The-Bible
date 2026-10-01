import SwiftData
import Foundation

@Model
final class VerseNote {
    var bookName: String = ""
    var chapterNumber: Int = 0
    var verseNumber: Int = 0
    var verseText: String = ""
    var content: String = ""
    /// Encoded `AttributedString` data. `content` remains the searchable plain-text copy.
    var formattedContent: Data?
    /// Raw value of `VerseHighlightColor`. An empty value means no highlight.
    var highlightColor: String = ""
    // Optionals for CloudKit schema
    var createdAt: Date?
    var updatedAt: Date?

    init() {
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    convenience init(
        bookName: String,
        chapterNumber: Int,
        verseNumber: Int,
        verseText: String,
        content: String = "",
        highlightColor: String = ""
    ) {
        self.init()
        self.bookName = bookName
        self.chapterNumber = chapterNumber
        self.verseNumber = verseNumber
        self.verseText = verseText
        self.content = content
        self.highlightColor = highlightColor
    }
}

@Model
final class UserNote {
    var title: String = ""
    var content: String = ""
    /// Encoded `AttributedString` data. `content` remains the searchable plain-text copy.
    var formattedContent: Data?
    // Optionals keep the model compatible with the app's CloudKit-backed store.
    var createdAt: Date?
    var updatedAt: Date?

    init() {
        createdAt = Date()
        updatedAt = Date()
    }
}
