import SwiftUI

struct SettingsResetDataSection: View {
    @State private var showingResetQuizAlert: Bool = false
    @State private var showingResetReadingAlert: Bool = false

    var body: some View {
        Section(
            header: Text("Reset Data").foregroundStyle(.primary),
            footer: Text("Reset your all-time game statistics or reading stats. These actions cannot be undone.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        ) {
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
                    resetAppActivity(category: .games)
                    Haptics.success()
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
                    // Delegate to coordinator: clears local stats/sessions, removes KVS copies,
                    // stamps a reset epoch to prevent older devices from repopulating,
                    // and performs synchronize off-main.
                    iCloudSyncCoordinator.shared.resetAllBibleStatsAndSessions()
                    resetAppActivity(category: .reading)
                    Haptics.success()
                }
            } message: {
                Text("All reading statistics, progress, and sessions will be removed. This cannot be undone. Do you want to continue?")
            }
        }
        .headerProminence(.increased)
    }

    private func resetAppActivity(category: AppActivityCategory) {
        let defaults = UserDefaults.standard

        switch category {
        case .reading:
            defaults.set(0, forKey: "dailyUsageReadingSeconds")
            defaults.set(0, forKey: "allTimeUsageReadingSeconds")
        case .games:
            defaults.set(0, forKey: "dailyUsageGameSeconds")
            defaults.set(0, forKey: "allTimeUsageGameSeconds")
        }
    }
}

private enum AppActivityCategory {
    case reading
    case games
}
