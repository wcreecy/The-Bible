import Foundation
import SwiftData

@Model
final class Favorite {
    var bookName: String
    var chapterNumber: Int
    var verseNumber: Int
    var verseText: String
    var createdAt: Date

    init(bookName: String, chapterNumber: Int, verseNumber: Int, verseText: String, createdAt: Date = Date()) {
        self.bookName = bookName
        self.chapterNumber = chapterNumber
        self.verseNumber = verseNumber
        self.verseText = verseText
        self.createdAt = createdAt
    }
}
