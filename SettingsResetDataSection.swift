import SwiftUI

struct SettingsResetDataSection: View {
    @State private var showingResetQuizAlert: Bool = false
    @State private var showingResetReadingAlert: Bool = false

    var body: some View {
        Section(header: Text("Reset Data"), footer: Text("Reset your all-time game statistics or reading stats. These actions cannot be undone.").font(.footnote).foregroundStyle(.secondary)) {
            Button(role: .destructive) {
                showingResetQuizAlert = true
            } label: {
                Label("Reset All Game Stats", systemImage: "trash")
            }
            .alert("Reset All Game Stats?", isPresented: $showingResetQuizAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    // Full wipe: counters, daily maps (overall + per-game), last played
                    iCloudSyncCoordinator.shared.resetAllGameDataToZero()
                }
            } message: {
                Text("This will remove all game-related data: all-time counters, daily activity, streaks, accuracy trends, per-game charts, and last played. This cannot be undone. Continue?")
            }

            Button(role: .destructive) {
                showingResetReadingAlert = true
            } label: {
                Label("Reset All Reading Stats", systemImage: "trash")
            }
            .alert("Reset All Reading Stats?", isPresented: $showingResetReadingAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    let defaults = BibleStatsStore.Defaults.provider
                    // Local removals
                    defaults.removeObject(forKey: BibleStatsStore.Defaults.keyTotals)
                    defaults.removeObject(forKey: BibleStatsStore.Defaults.keyDailyTotals)
                    defaults.removeObject(forKey: BibleStatsStore.Defaults.keyDailyTotalsByBook)
                    defaults.removeObject(forKey: BibleStatsStore.Defaults.keyVisitedChapters)
                    defaults.removeObject(forKey: BibleStatsStore.Defaults.keyLastRead)
                    defaults.removeObject(forKey: BibleStatsStore.Defaults.keySeenVersesByChapter)
                    defaults.removeObject(forKey: BibleStatsStore.Defaults.keyChapterCompletionDates)
                    defaults.removeObject(forKey: "readingSessions")

                    // Mirror deletions to iCloud KVS so other devices clear too
                    let kvs = iCloudSyncCoordinator.shared.kvs
                    var keys = iCloudSyncCoordinator.bibleStatsKeys
                    for key in keys {
                        kvs.removeObject(forKey: key)
                    }
                    // Ensure sessions deletion is also mirrored (now in bibleStatsKeys, but keep explicit for safety)
                    kvs.removeObject(forKey: "readingSessions")
                    if !keys.contains("readingSessions") {
                        keys.append("readingSessions")
                    }

                    // Reset caches and notify UI locally
                    BibleStatsStore.shared.resetCaches()
                    NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)

                    // Enqueue these keys and push now so deletions propagate immediately
                    iCloudSyncCoordinator.shared.enqueueKeysForSync(keys)
                    iCloudSyncCoordinator.shared.pushAllNow()
                }
            } message: {
                Text("All reading statistics, progress, and sessions will be removed. This cannot be undone. Do you want to continue?")
            }
        }
        .headerProminence(.increased)
    }
}
