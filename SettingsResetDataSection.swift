import SwiftUI

struct SettingsResetDataSection: View {
    @State private var showingResetQuizAlert: Bool = false
    @State private var showingResetReadingAlert: Bool = false
    @State private var pendingReset: AppActivityCategory?
    @State private var resetConfirmationText: String = ""

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
                    requestTypedConfirmation(for: .games)
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
                    requestTypedConfirmation(for: .reading)
                }
            } message: {
                Text("All reading statistics, progress, and sessions will be removed. This cannot be undone. Do you want to continue?")
            }
        }
        .headerProminence(.increased)
        .alert("Final Confirmation", item: $pendingReset) { category in
            TextField("Type reset", text: $resetConfirmationText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button("Cancel", role: .cancel) {
                resetConfirmationText = ""
            }

            Button("Reset Permanently", role: .destructive) {
                performReset(category)
            }
            .disabled(resetConfirmationText != "reset")
        } message: { category in
            Text("To permanently delete all \(category.displayName), type reset below.")
        }
    }

    private func requestTypedConfirmation(for category: AppActivityCategory) {
        resetConfirmationText = ""
        Task { @MainActor in
            pendingReset = category
        }
    }

    private func performReset(_ category: AppActivityCategory) {
        switch category {
        case .games:
            // Full wipe: counters, daily maps (overall + per-game), and last played.
            iCloudSyncCoordinator.shared.resetAllGameDataToZero()
        case .reading:
            // Clears local data and iCloud copies, then stamps a reset epoch so
            // older devices cannot restore the deleted reading history.
            iCloudSyncCoordinator.shared.resetAllBibleStatsAndSessions()
        }

        resetAppActivity(category: category)
        resetConfirmationText = ""
        Haptics.success()
    }

    private func resetAppActivity(category: AppActivityCategory) {
        let keys: [String]
        switch category {
        case .reading:
            keys = [
                "dailyUsageReadingSeconds",
                "allTimeUsageReadingSeconds"
            ]
        case .games:
            keys = [
                "dailyUsageGameSeconds",
                "allTimeUsageGameSeconds"
            ]
        }

        iCloudSyncCoordinator.shared.resetAppActivity(keys: keys)
    }
}

private enum AppActivityCategory: Identifiable {
    case reading
    case games

    var id: Self { self }

    var displayName: String {
        switch self {
        case .reading: "reading statistics"
        case .games: "game statistics"
        }
    }
}
