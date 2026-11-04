import Foundation
import SwiftData

@Model
final class Favorite {
    var bookName: String = ""
    var chapterNumber: Int = 0
    var verseNumber: Int = 0
    var verseText: String = ""
    /// Raw value of the `BibleTranslation` `verseText` is in. Records saved before there
    /// were translations are KJV.
    var translation: String = "kjv"
    // Non-optional with a default so it can be used in SwiftData sort descriptors
    var createdAt: Date = Date()

    init() {
        translation = BibleRepository.shared.activeTranslation.rawValue
    }

    // Convenience initializer
    init(bookName: String, chapterNumber: Int, verseNumber: Int, verseText: String, createdAt: Date = Date()) {
        self.bookName = bookName
        self.chapterNumber = chapterNumber
        self.verseNumber = verseNumber
        self.verseText = verseText
        self.createdAt = createdAt
        self.translation = BibleRepository.shared.activeTranslation.rawValue
    }
}
