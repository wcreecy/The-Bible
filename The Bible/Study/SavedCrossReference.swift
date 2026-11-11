import Foundation
import SwiftData

/// A curated cross-reference the reader wants to revisit.
@Model
final class SavedCrossReference {
    /// The stable identifier from the bundled Cross Reference database.
    var entryID: Int = 0
    var savedAt: Date?
    /// No longer shown or edited. Kept so the iCloud store keeps its shape;
    /// `SavedConnectionTakeawayMigration` moves any text here into a note.
    var takeaway: String = ""

    init(entryID: Int, savedAt: Date = Date()) {
        self.entryID = entryID
        self.savedAt = savedAt
    }
}
