import Foundation

extension Notification.Name {
    // Posted when KVS merges BibleStats-related keys; UI can refresh.
    static let bibleStatsExternallyUpdated = Notification.Name("bibleStatsExternallyUpdated")

    // Posted when game counters merge via KVS; UI scoreboards can refresh.
    static let gameStatsExternallyUpdated = Notification.Name("gameStatsExternallyUpdated")

    // Posted when chapter read/verse progress changes anywhere in the app.
    static let chapterProgressChanged = Notification.Name("chapterProgressChanged")

    // Posted to request switching to a particular tab (used to close sheets, etc.).
    static let switchToTab = Notification.Name("switchToTab")

    // If you deep link to a passage elsewhere, you already have:
    // static let openBibleReference = Notification.Name("openBibleReference")
}
