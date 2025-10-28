import Foundation
import SwiftData

@Model
final class ReaderSettings {
    var fontSize: Double
    // theme values: "system", "light", "dark", "sepia"
    var theme: String

    init(fontSize: Double = 17.0, theme: String = "system") {
        self.fontSize = fontSize
        self.theme = theme
    }
}

@Model
final class ReadingProgress {
    var bookName: String
    var chapterNumber: Int
    var verseNumber: Int

    init(bookName: String, chapterNumber: Int, verseNumber: Int) {
        self.bookName = bookName
        self.chapterNumber = chapterNumber
        self.verseNumber = verseNumber
    }
}
