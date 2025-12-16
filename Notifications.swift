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

    // Posted to request opening the Settings tab.
    static let openSettingsTab = Notification.Name("OpenSettingsTab")

    // Posted to request resetting the Bible tab's navigation stack to the root (Books list).
    static let resetBibleNavigation = Notification.Name("ResetBibleNavigation")

    // MARK: - Deep links / routing

    // Posted to request opening a specific Bible reference.
    // userInfo: ["book": String, "chapter": Int, "verse": Int, "relayed": Bool?]
    static let openBibleReference = Notification.Name("OpenBibleReference")

    // MARK: - Home layout

    // Posted when the Home layout order/visibility changes.
    static let homeLayoutChanged = Notification.Name("homeLayoutChanged")
}
