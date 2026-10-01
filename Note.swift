import SwiftData
import Foundation

@Model
final class VerseNote {
    var bookName: String = ""
    var chapterNumber: Int = 0
    var verseNumber: Int = 0
    var verseText: String = ""
    var content: String = ""
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
