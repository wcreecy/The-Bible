import SwiftData
import Foundation

@Model
final class VerseNote {
    var bookName: String
    var chapterNumber: Int
    var verseNumber: Int
    var verseText: String
    var content: String
    var createdAt: Date
    var updatedAt: Date

    init(
        bookName: String,
        chapterNumber: Int,
        verseNumber: Int,
        verseText: String,
        content: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.bookName = bookName
        self.chapterNumber = chapterNumber
        self.verseNumber = verseNumber
        self.verseText = verseText
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
