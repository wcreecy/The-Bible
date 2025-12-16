import Foundation

// Shared notifications for the Journal feature
enum JournalNotifications {
    static let openScripturePreview = Notification.Name("OpenScripturePreview")
    static let entryCreated = Notification.Name("JournalEntryCreated")
    static let entryUpdated = Notification.Name("JournalEntryUpdated")
    // NEW: request Journal tab (iPad) to start a new inline entry from a Bible reference
    static let startInlineNewFromBible = Notification.Name("JournalStartInlineNewFromBible")
}
