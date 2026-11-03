import Foundation

extension Notification.Name {
    // MARK: - Data sync / stats

    // Posted when KVS merges BibleStats-related keys; UI can refresh.
    static let bibleStatsExternallyUpdated = Notification.Name("bibleStatsExternallyUpdated")

    // Posted when game counters merge via KVS; UI scoreboards can refresh.
    static let gameStatsExternallyUpdated = Notification.Name("gameStatsExternallyUpdated")

    // Posted when foreground study time changes, so the usage comparison can refresh.
    static let studyTimeUpdated = Notification.Name("studyTimeUpdated")

    // Posted when chapter read/verse progress changes anywhere in the app.
    static let chapterProgressChanged = Notification.Name("chapterProgressChanged")

    // Navigation requests go through `AppRouter`, not notifications.

    // MARK: - Home layout

    // Posted when the Home layout order/visibility changes.
    static let homeLayoutChanged = Notification.Name("homeLayoutChanged")

    // Posted by the debug settings reset to stop an active prayer timer.
    static let resetPrayerTimer = Notification.Name("resetPrayerTimer")
}
