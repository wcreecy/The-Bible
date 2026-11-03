import Foundation
import Observation

/// Announces that saved data changed, so whatever shows it can refresh.
///
/// Views read the counters (`bibleStats`, `gameStats`, …), so SwiftUI redraws them after a
/// change, and a burst of changes causes one refresh. Each call also posts the matching
/// notification for the stores that listen for it. Some of those stores rely on being told
/// during the post itself: `ReadingSessionsStore` ignores its own announcements by setting a
/// flag around the call.
@MainActor
@Observable
final class AppDataChanges {
    static let shared = AppDataChanges()

    private(set) var bibleStats = 0
    private(set) var gameStats = 0
    private(set) var prayerStats = 0
    private(set) var studyTime = 0
    private(set) var chapterProgress = 0
    private(set) var syncStatus = 0

    private init() {}

    /// Reading time, progress, sessions, or the reading position changed, here or from iCloud.
    func bibleStatsChanged() {
        bibleStats &+= 1
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
    }

    /// A game round was recorded, or game stats were merged or reset.
    func gameStatsChanged() {
        gameStats &+= 1
        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

    /// Prayer or study timer time changed.
    func prayerStatsChanged() {
        prayerStats &+= 1
        NotificationCenter.default.post(name: .prayerStatsUpdated, object: nil)
    }

    /// Study Bible time changed.
    func studyTimeChanged() {
        studyTime &+= 1
        NotificationCenter.default.post(name: .studyTimeUpdated, object: nil)
    }

    /// A chapter was marked read or unread.
    func chapterProgressChanged() {
        chapterProgress &+= 1
        NotificationCenter.default.post(name: .chapterProgressChanged, object: nil)
    }

    /// iCloud sync state, errors, or storage usage changed.
    func syncStatusChanged() {
        syncStatus &+= 1
        NotificationCenter.default.post(name: .iCloudSyncStatusChanged, object: nil)
    }
}
