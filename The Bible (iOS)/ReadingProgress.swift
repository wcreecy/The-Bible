#if false
import Foundation
import SwiftData

@Model
final class ReadingProgress {
    var bookName: String
    var chapterNumber: Int
    var verseNumber: Int
    var updatedAt: Date

    init(bookName: String, chapterNumber: Int, verseNumber: Int, updatedAt: Date = Date()) {
        self.bookName = bookName
        self.chapterNumber = chapterNumber
        self.verseNumber = verseNumber
        self.updatedAt = updatedAt
    }
}
#endif
