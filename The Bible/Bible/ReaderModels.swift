import Foundation
import SwiftData

/// Legacy manual "Continue Reading" bookmark. Kept in the CloudKit-backed schema so
/// existing stores open unchanged; it is only read once to seed `ReadingPositionStore`.
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
