import ActivityKit
import HealthKit
import SwiftUI
import UIKit
import UserNotifications

struct SettingsPermissionsSection: View {
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("liveActivitiesEnabled") private var liveActivitiesEnabled: Bool = true
    @AppStorage("healthKitMindfulMinutesEnabled") private var mindfulMinutesEnabled: Bool = false

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var alarmStatus: PrayerTimerAlarmScheduler.AuthorizationStatus = .unavailable
    @State private var isRequestingAlarmAuthorization = false
    @State private var showAlarmSettingsAlert = false
    @State private var mindfulMinutesStatus: HKAuthorizationStatus?
    @State private var areSystemLiveActivitiesEnabled = true

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

            if #available(iOS 26.1, *) {
                Toggle(isOn: alarmAuthorizationBinding) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Prayer Timer Alarms")
                            Text(alarmStatusText)
                                .font(.caption)
                                .foregroundStyle(alarmStatusColor)
                        }
                    } icon: {
                        Image(systemName: "alarm")
                    }
                }
                .accessibilityIdentifier("alarmKitPermissionRow")
            }

            Toggle(isOn: $mindfulMinutesEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mindful Minutes")
                        Text(mindfulMinutesStatusText)
                            .font(.caption)
                            .foregroundStyle(mindfulMinutesStatusColor)
                    }
                } icon: {
                    Image(systemName: "heart.text.square")
                }
            }
            .disabled(mindfulMinutesStatus == nil)
            .accessibilityIdentifier("mindfulMinutesToggle")
            .onChange(of: mindfulMinutesEnabled) { _, enabled in
                handleMindfulMinutesToggle(enabled)
            }

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
                }
            }

            if !areSystemLiveActivitiesEnabled {
                Button("Open System Settings", action: openSystemSettings)
                    .accessibilityIdentifier("liveActivitiesSystemSettingsButton")
            }

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
            Text("Health access is requested only when you turn on Mindful Minutes here. Photo backgrounds use the system picker, so the app only receives photos you select.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .headerProminence(.increased)
        .alert("Alarm Access Is Managed by iOS", isPresented: $showAlarmSettingsAlert) {
            Button("Open Settings", action: openSystemSettings)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The Bible can only show the AlarmKit permission prompt once. To change a previous decision, allow Prayer Timer Alarms in iOS Settings.")
        }
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

    private var alarmStatusText: LocalizedStringKey {
        if isRequestingAlarmAuthorization {
            return "Requesting Access"
        }
        return switch alarmStatus {
        case .authorized: "Allowed"
        case .denied: "Denied"
        case .notDetermined: "Not Requested"
        case .unavailable: "Unavailable"
        }
    }

    private var alarmStatusColor: Color {
        switch alarmStatus {
        case .authorized: .green
        case .denied: .orange
        case .notDetermined, .unavailable: .secondary
        }
    }

    private var mindfulMinutesStatusText: LocalizedStringKey {
        guard let mindfulMinutesStatus else { return "Unavailable" }
        guard mindfulMinutesEnabled else {
            return mindfulMinutesStatus == .sharingDenied ? "Denied" : "Off"
        }
        return switch mindfulMinutesStatus {
        case .sharingAuthorized: "Allowed"
        case .sharingDenied: "Denied"
        case .notDetermined: "Requesting Access"
        @unknown default: "Unknown"
        }
    }

    private var mindfulMinutesStatusColor: Color {
        guard mindfulMinutesEnabled else {
            return mindfulMinutesStatus == .sharingDenied ? .orange : .secondary
        }
        return switch mindfulMinutesStatus {
        case .sharingAuthorized: .green
        case .sharingDenied: .orange
        case .notDetermined, nil: .secondary
        @unknown default: .secondary
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

    private var alarmAuthorizationBinding: Binding<Bool> {
        Binding(
            get: { alarmStatus == .authorized || isRequestingAlarmAuthorization },
            set: { enabled in handleAlarmToggle(enabled) }
        )
    }

    private func handleAlarmToggle(_ enabled: Bool) {
        guard !isRequestingAlarmAuthorization else { return }

        guard enabled else {
            if alarmStatus == .authorized {
                showAlarmSettingsAlert = true
            }
            return
        }

        switch alarmStatus {
        case .notDetermined:
            isRequestingAlarmAuthorization = true
            Task {
                alarmStatus = await PrayerTimerAlarmScheduler.requestAuthorization()
                isRequestingAlarmAuthorization = false
            }
        case .denied:
            showAlarmSettingsAlert = true
        case .authorized, .unavailable:
            break
        }
    }

    private func handleMindfulMinutesToggle(_ enabled: Bool) {
        guard enabled else { return }
        guard mindfulMinutesStatus != nil else {
            mindfulMinutesEnabled = false
            return
        }

        if mindfulMinutesStatus == .sharingDenied {
            mindfulMinutesEnabled = false
            openSystemSettings()
            return
        }

        HealthKitManager.shared.requestAuthorizationIfNeeded { _ in
            mindfulMinutesStatus = HealthKitManager.shared.mindfulMinutesAuthorizationStatus()
            if mindfulMinutesStatus != .sharingAuthorized {
                mindfulMinutesEnabled = false
            }
        }
    }

    @MainActor
    private func updateStatuses() async {
        notificationStatus = await UNUserNotificationCenter.current()
            .notificationSettings()
            .authorizationStatus
        alarmStatus = PrayerTimerAlarmScheduler.authorizationStatus()
        mindfulMinutesStatus = HealthKitManager.shared.mindfulMinutesAuthorizationStatus()
        if mindfulMinutesStatus == nil || mindfulMinutesStatus == .sharingDenied {
            mindfulMinutesEnabled = false
        }
        areSystemLiveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
