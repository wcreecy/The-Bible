import ActivityKit
import HealthKit
import SwiftUI
import UIKit
import UserNotifications

struct SettingsPermissionsSection: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var cloudKitManager: CloudKitManager

    @AppStorage("liveActivitiesEnabled") private var liveActivitiesEnabled: Bool = true

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var mindfulMinutesStatus: HKAuthorizationStatus?
    @State private var areSystemLiveActivitiesEnabled = true
    @State private var isRefreshing = false

    var body: some View {
        Section {
            permissionRow(
                title: "Notifications",
                systemImage: "bell.badge",
                status: notificationStatusText,
                statusColor: notificationStatusColor
            ) {
                handleNotificationsAction()
            }
            .accessibilityIdentifier("notificationsPermissionRow")

            permissionRow(
                title: "Mindful Minutes",
                systemImage: "heart.text.square",
                status: mindfulMinutesStatusText,
                statusColor: mindfulMinutesStatusColor
            ) {
                handleMindfulMinutesAction()
            }
            .disabled(mindfulMinutesStatus == nil)
            .accessibilityIdentifier("mindfulMinutesPermissionRow")

            Toggle(isOn: $liveActivitiesEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Live Activities")
                        Text(areSystemLiveActivitiesEnabled ? "Allowed by System" : "Disabled in System Settings")
                            .font(.caption)
                            .foregroundStyle(areSystemLiveActivitiesEnabled ? .green : .orange)
                    }
                } icon: {
                    Image(systemName: "livephoto.play")
                }
            }
            .accessibilityIdentifier("liveActivitiesToggle")
            .onChange(of: liveActivitiesEnabled) { _, enabled in
                if !enabled {
                    PrayerTimerActivityController.shared.cancel()
                    StopwatchActivityController.shared.cancel()
                }
            }

            if !areSystemLiveActivitiesEnabled {
                Button("Open System Settings", action: openSystemSettings)
                    .accessibilityIdentifier("liveActivitiesSystemSettingsButton")
            }

            HStack {
                Label("iCloud Sync", systemImage: "icloud")
                Spacer()
                Text(iCloudStatusText)
                    .foregroundStyle(iCloudStatusColor)
            }
            .accessibilityIdentifier("icloudStatusText")

            Button {
                refreshStatuses()
            } label: {
                Label(isRefreshing ? "Refreshing…" : "Refresh Status", systemImage: "arrow.clockwise")
            }
            .disabled(isRefreshing)
            .accessibilityIdentifier("permissionsRefreshButton")

            HStack {
                Label("Photo Selection", systemImage: "photo.on.rectangle")
                Spacer()
                Text("Ask When Used")
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityHint("The system photo picker shares only photos you select and does not require full library access.")
        } header: {
            Text("Permissions & Access")
                .foregroundStyle(.primary)
        } footer: {
            Text("Access is requested when you use a feature that needs it. Photo backgrounds use the system picker, so the app only receives photos you select.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .headerProminence(.increased)
        .task {
            await updateStatuses()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await updateStatuses()
            }
        }
    }

    private func permissionRow(
        title: LocalizedStringKey,
        systemImage: String,
        status: LocalizedStringKey,
        statusColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Text(status)
                    .foregroundStyle(statusColor)
            }
        }
        .buttonStyle(.plain)
    }

    private var notificationStatusText: LocalizedStringKey {
        switch notificationStatus {
        case .authorized: "Allowed"
        case .denied: "Denied"
        case .notDetermined: "Not Requested"
        case .provisional: "Provisional"
        case .ephemeral: "Temporary"
        @unknown default: "Unknown"
        }
    }

    private var notificationStatusColor: Color {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: .green
        case .denied: .orange
        case .notDetermined: .secondary
        @unknown default: .secondary
        }
    }

    private var mindfulMinutesStatusText: LocalizedStringKey {
        guard let mindfulMinutesStatus else { return "Unavailable" }
        return switch mindfulMinutesStatus {
        case .sharingAuthorized: "Allowed"
        case .sharingDenied: "Denied"
        case .notDetermined: "Not Requested"
        @unknown default: "Unknown"
        }
    }

    private var mindfulMinutesStatusColor: Color {
        switch mindfulMinutesStatus {
        case .sharingAuthorized: .green
        case .sharingDenied: .orange
        case .notDetermined, nil: .secondary
        @unknown default: .secondary
        }
    }

    private var iCloudStatusText: LocalizedStringKey {
        switch cloudKitManager.accountState {
        case .available: "Available"
        case .noAccount: "No Account"
        case .restricted: "Restricted"
        case .couldNotDetermine: "Unavailable"
        case .unknown: "Unknown"
        }
    }

    private var iCloudStatusColor: Color {
        switch cloudKitManager.accountState {
        case .available: .green
        case .noAccount, .restricted, .couldNotDetermine: .orange
        case .unknown: .secondary
        }
    }

    private func handleNotificationsAction() {
        if notificationStatus == .notDetermined {
            Task {
                _ = try? await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge])
                await updateStatuses()
            }
        } else {
            openSystemSettings()
        }
    }

    private func handleMindfulMinutesAction() {
        guard mindfulMinutesStatus != nil else { return }

        if mindfulMinutesStatus == .notDetermined {
            HealthKitManager.shared.requestAuthorizationIfNeeded { _ in
                mindfulMinutesStatus = HealthKitManager.shared.mindfulMinutesAuthorizationStatus()
            }
        } else {
            openSystemSettings()
        }
    }

    private func refreshStatuses() {
        isRefreshing = true
        Task {
            await cloudKitManager.refresh()
            await updateStatuses()
            isRefreshing = false
        }
    }

    @MainActor
    private func updateStatuses() async {
        notificationStatus = await UNUserNotificationCenter.current()
            .notificationSettings()
            .authorizationStatus
        mindfulMinutesStatus = HealthKitManager.shared.mindfulMinutesAuthorizationStatus()
        areSystemLiveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
