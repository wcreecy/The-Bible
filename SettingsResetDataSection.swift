import SwiftUI

struct SettingsResetDataSection: View {
    @State private var showingResetQuizAlert: Bool = false
    @State private var showingResetReadingAlert: Bool = false

    var body: some View {
        Section(header: Text("Reset Data"), footer: Text("Reset your all-time game statistics or reading stats. These actions cannot be undone.").font(.footnote).foregroundStyle(.secondary)) {
            Button(role: .destructive) {
                showingResetQuizAlert = true
            } label: {
                Label("Reset All-time Game Stats", systemImage: "trash")
            }
            .alert("Reset All-time Stats?", isPresented: $showingResetQuizAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    iCloudSyncCoordinator.shared.resetAllGameCountersToZero()
                }
            } message: {
                Text("Your all-time game scores will be reset. Would you like to continue?")
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
                    defaults.removeObject(forKey: BibleStatsStore.Defaults.keyTotals)
                    defaults.removeObject(forKey: BibleStatsStore.Defaults.keyDailyTotals)
                    defaults.removeObject(forKey: BibleStatsStore.Defaults.keyDailyTotalsByBook)
                    defaults.removeObject(forKey: BibleStatsStore.Defaults.keyVisitedChapters)
                    defaults.removeObject(forKey: BibleStatsStore.Defaults.keyLastRead)
                    defaults.removeObject(forKey: BibleStatsStore.Defaults.keySeenVersesByChapter)
                    defaults.removeObject(forKey: BibleStatsStore.Defaults.keyChapterCompletionDates)
                    defaults.removeObject(forKey: "readingSessions")

                    BibleStatsStore.shared.resetCaches()
                    NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
                    iCloudSyncCoordinator.shared.pushAllNow()
                }
            } message: {
                Text("All reading statistics, progress, and sessions will be removed. This cannot be undone. Do you want to continue?")
            }
        }
        .headerProminence(.increased)
    }
}
