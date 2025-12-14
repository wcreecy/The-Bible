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
    // Remove unique constraint for CloudKit compatibility
    var singletonKey: String = "global"

    var bookName: String = ""
    var chapterNumber: Int = 0
    var verseNumber: Int = 0

    // Used to resolve cross-device conflicts (latest write wins in UI).
    var updatedAt: Date = Foundation.Date.distantPast

    init() {}
}
