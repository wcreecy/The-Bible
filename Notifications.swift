import Foundation

extension Notification.Name {
    // MARK: - Data sync / stats

    // Posted when KVS merges BibleStats-related keys; UI can refresh.
    static let bibleStatsExternallyUpdated = Notification.Name("bibleStatsExternallyUpdated")

    // Posted when game counters merge via KVS; UI scoreboards can refresh.
    static let gameStatsExternallyUpdated = Notification.Name("gameStatsExternallyUpdated")

    // Posted when chapter read/verse progress changes anywhere in the app.
    static let chapterProgressChanged = Notification.Name("chapterProgressChanged")

    // MARK: - Navigation / tabs

    // Posted to request switching to a particular tab.
    // userInfo: ["tab": Int]
    static let switchToTab = Notification.Name("switchToTab")

    // Posted to request opening destinations now nested inside primary tabs.
    static let openSettingsTab = Notification.Name("OpenSettingsTab")
    static let openStats = Notification.Name("OpenStats")
    static let openBibleSearch = Notification.Name("OpenBibleSearch")

    // Posted to request resetting the Bible tab's navigation stack to the root (Books list).
    static let resetBibleNavigation = Notification.Name("ResetBibleNavigation")

    // MARK: - Deep links / routing

    // Posted to request opening a specific Bible reference.
    // userInfo: ["book": String, "chapter": Int, "verse": Int, "relayed": Bool?]
    static let openBibleReference = Notification.Name("OpenBibleReference")

    /// Relays a tapped scripture URL back to an active in-app scripture preview.
    /// The notification object is the URL that was selected.
    static let openScripturePreview = Notification.Name("OpenScripturePreview")

    // Posted after the user opens a Verse of the Day notification.
    static let openVerseOfDayNotification = Notification.Name("OpenVerseOfDayNotification")

    // MARK: - Home layout

    // Posted when the Home layout order/visibility changes.
    static let homeLayoutChanged = Notification.Name("homeLayoutChanged")

    // Posted by the debug settings reset to stop an active prayer timer.
    static let resetPrayerTimer = Notification.Name("resetPrayerTimer")
}
