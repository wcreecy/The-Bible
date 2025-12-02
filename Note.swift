import SwiftData
import Foundation

@Model
final class VerseNote {
    var bookName: String = ""
    var chapterNumber: Int = 0
    var verseNumber: Int = 0
    var verseText: String = ""
    var content: String = ""
    // Optionals for CloudKit schema
    var createdAt: Date?
    var updatedAt: Date?

    init() {
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
