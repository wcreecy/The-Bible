import Foundation
import SwiftData

@Model
final class ReaderSettings {
    var fontSize: Double = 17.0
    // theme values: "system", "light", "dark", "sepia"
    var theme: String = "system"

    init() {}
}

@Model
final class ReadingProgress {
    var bookName: String = ""
    var chapterNumber: Int = 0
    var verseNumber: Int = 0

    init() {}
}
