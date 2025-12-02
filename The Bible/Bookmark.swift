import Foundation
import SwiftData

@Model
final class Bookmark {
    var bookName: String = ""
    var chapterNumber: Int = 0
    var verseNumber: Int = 0
    var verseText: String = ""
    var createdAt: Date = Date()

    init() {}
}
