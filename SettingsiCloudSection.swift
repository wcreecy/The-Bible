import SwiftUI
import CloudKit
import UIKit

struct SettingsiCloudSection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var cloudKitManager: CloudKitManager
    @State private var isRefreshingCloudStatus: Bool = false
    @State private var lastSyncActivity: Date?
    @State private var statsSyncState: iCloudSyncCoordinator.SyncState = .notStarted
    @State private var statsSyncError: String?
    @State private var statsCloudBytes: Int = 0
    @State private var statsCloudKeyCount: Int = 0

    private var iCloudStatusText: String {
        switch cloudKitManager.accountState {
        case .available: return "Available"
        case .noAccount: return "No Account"
        case .restricted: return "Restricted"
        case .couldNotDetermine: return "Unavailable"
        case .unknown: return "Unknown"
        }
    }

    private var iCloudStatusColor: Color {
        switch cloudKitManager.accountState {
        case .available: return .green
        case .noAccount, .restricted, .couldNotDetermine: return .orange
        case .unknown: return .secondary
        }
    }

    var body: some View {
        Section {
            HStack {
                Label("CloudKit", systemImage: "icloud")
                Spacer()
                Text(iCloudStatusText)
                    .foregroundStyle(iCloudStatusColor)
                    .accessibilityIdentifier("icloudStatusText")
            }
            HStack {
                Label("Stats Sync", systemImage: "arrow.triangle.2.circlepath.icloud")
                Spacer()
                Text(statsSyncStatusText)
                    .foregroundStyle(statsSyncStatusColor)
                    .accessibilityIdentifier("statsSyncStatusText")
            }
            if let statsSyncError {
                Text(statsSyncError)
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("statsSyncErrorText")
            }
            HStack {
                Text("Stats Cloud Usage")
                Spacer()
                Text(statsCloudUsageText)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Last Sync Activity")
                Spacer()
                if let lastSyncActivity {
                    Text(
                        lastSyncActivity,
                        format: .dateTime
                            .month(.abbreviated)
                            .day()
                            .year()
                            .hour()
                            .minute()
                    )
                } else {
                    Text("Never")
                }
            }
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("icloudLastSyncedAt")
            if let id = cloudKitManager.userRecordID {
                HStack {
                    Text("User Record")
                    Spacer()
                    Text(id.recordName)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .accessibilityIdentifier("icloudUserRecord")
            }
            Button {
                Haptics.selection()

                isRefreshingCloudStatus = true
                Task {
                    await cloudKitManager.refresh()
                    iCloudSyncCoordinator.shared.refreshNow()
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    await MainActor.run {
                        updateSyncStatus()
                        isRefreshingCloudStatus = false
                    }
                }
            } label: {
                Label {
                    Text(isRefreshingCloudStatus ? "Refreshing…" : "Refresh Status")
                } icon: {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(isRefreshingCloudStatus ? .degrees(360) : .degrees(0))
                        .animation(
                            isRefreshingCloudStatus && !reduceMotion
                            ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                            : .default,
                            value: isRefreshingCloudStatus
                        )
                }
            }
            .disabled(isRefreshingCloudStatus)
            .accessibilityIdentifier("icloudRefreshButton")
        } header: {
            Text("iCloud").foregroundStyle(.primary)
        } footer: {
            Text("""
            iCloud keeps your data up to date across your devices using CloudKit.
            Status meanings:
            • Available: Signed in to iCloud and CloudKit is ready.
            • No Account: Not signed in to iCloud on this device.
            • Restricted: iCloud is restricted by system settings or parental controls.
            • Unavailable: The status couldn’t be determined right now.
            Stats Sync reports the separate iCloud key-value channel used for game and reading statistics.
            """)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .headerProminence(.increased)
        .task {
            updateSyncStatus()

            for await _ in NotificationCenter.default.notifications(named: .iCloudSyncStatusChanged) {
                updateSyncStatus()
            }
        }
    }

    private var statsSyncStatusText: String {
        switch statsSyncState {
        case .notStarted: "Not Started"
        case .downloading: "Downloading"
        case .ready: "Ready"
        case .unavailable: "Unavailable"
        case .quotaExceeded: "Storage Full"
        }
    }

    private var statsSyncStatusColor: Color {
        switch statsSyncState {
        case .ready: .green
        case .downloading, .notStarted: .secondary
        case .unavailable, .quotaExceeded: .orange
        }
    }

    private var statsCloudUsageText: String {
        let formattedBytes = ByteCountFormatter.string(fromByteCount: Int64(statsCloudBytes), countStyle: .file)
        return "\(formattedBytes) · \(statsCloudKeyCount) keys"
    }

    private func updateSyncStatus() {
        let coordinator = iCloudSyncCoordinator.shared
        lastSyncActivity = [coordinator.lastPushDate, coordinator.lastMergeDate]
            .compactMap { $0 }
            .max()
        statsSyncState = coordinator.syncState
        statsSyncError = coordinator.lastErrorMessage
        statsCloudBytes = coordinator.approximateCloudBytes
        statsCloudKeyCount = coordinator.cloudKeyCount
    }
}
