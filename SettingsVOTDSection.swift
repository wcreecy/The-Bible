import SwiftUI
import UIKit
import UserNotifications

struct SettingsVOTDSection: View {
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("verseOfDayScope") private var verseScopeRaw: String = "whole"
    @AppStorage("verseOfDaySpecificBook") private var verseSpecificBook: String = ""

    @AppStorage("votdRefreshFrequency") private var refreshFrequencyRaw: String = VOTDRefreshFrequency.custom.rawValue
    @AppStorage("votdRefresh1Hour") private var votdRefresh1Hour: Int = 6
    @AppStorage("votdRefresh1Minute") private var votdRefresh1Minute: Int = 0
    @AppStorage("votdRefresh2Hour") private var votdRefresh2Hour: Int = 18
    @AppStorage("votdRefresh2Minute") private var votdRefresh2Minute: Int = 0
    @AppStorage("votdRefreshNotificationsEnabled") private var notificationsEnabled: Bool = false
    @AppStorage("verseOfDayPaused") private var verseOfDayPaused: Bool = false
    @State private var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showsNotificationPermissionAlert = false

    private var refresh1DateBinding: Binding<Date> {
        Binding<Date>(
            get: {
                let now = Date()
                return VOTDSchedule.dateForToday(hour: votdRefresh1Hour, minute: votdRefresh1Minute, from: now) ?? now
            },
            set: { newDate in
                let cal = Calendar.autoupdatingCurrent
                let c = cal.dateComponents([.hour, .minute], from: newDate)
                votdRefresh1Hour = c.hour ?? 6
                votdRefresh1Minute = c.minute ?? 0
                updateNotificationSchedule()
            }
        )
    }

    private var refresh2DateBinding: Binding<Date> {
        Binding<Date>(
            get: {
                let now = Date()
                return VOTDSchedule.dateForToday(hour: votdRefresh2Hour, minute: votdRefresh2Minute, from: now) ?? now
            },
            set: { newDate in
                let cal = Calendar.autoupdatingCurrent
                let c = cal.dateComponents([.hour, .minute], from: newDate)
                votdRefresh2Hour = c.hour ?? 18
                votdRefresh2Minute = c.minute ?? 0
                updateNotificationSchedule()
            }
        )
    }

    private var refreshFrequency: VOTDRefreshFrequency {
        VOTDRefreshFrequency(rawValue: refreshFrequencyRaw) ?? .custom
    }

    private var nextVOTDDescription: String {
        VOTDSchedule.nextAutoRefreshDescription(
            frequency: refreshFrequency,
            first: (votdRefresh1Hour, votdRefresh1Minute),
            second: (votdRefresh2Hour, votdRefresh2Minute)
        )
    }

    var body: some View {
        Section(
            header: Text("Verse of the Day").foregroundStyle(.primary),
            footer: Text("Choose where verses come from and how often they refresh. Auto-refresh remains disabled while the verse is paused on the Home page.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        ) {
            VStack(spacing: 8) {
                HStack(spacing: 0) {
                    segmentButton(title: "OT", tag: "old")
                    verticalSeparator()
                    segmentButton(title: "NT", tag: "new")
                    verticalSeparator()
                    segmentButton(title: "OT/NT", tag: "whole")
                    verticalSeparator()
                    segmentButton(title: "Book", tag: "book")
                }
                .frame(maxWidth: .infinity)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.gray.opacity(0.25), lineWidth: 1)
                )
                .accessibilityIdentifier("verseOfDayScopePicker")

                if verseScopeRaw == "book" {
                    BookSelectionLink(
                        selectedBookName: Binding<String?>(
                            get: { verseSpecificBook.isEmpty ? nil : verseSpecificBook },
                            set: { verseSpecificBook = $0 ?? "" }
                        )
                    )
                    .accessibilityIdentifier("verseOfDaySpecificBookPicker")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label("Auto-Refresh", systemImage: "clock.arrow.2.circlepath")
                        .font(.headline)

                    Picker("Refresh Frequency", selection: $refreshFrequencyRaw) {
                        ForEach(VOTDRefreshFrequency.allCases) { frequency in
                            Text(frequency.title).tag(frequency.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("votdRefreshFrequency")
                    .onChange(of: refreshFrequencyRaw) { _, _ in
                        updateNotificationSchedule()
                    }

                    if refreshFrequency == .custom {
                        DatePicker("Morning Refresh", selection: refresh1DateBinding, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .accessibilityIdentifier("votdRefreshTime1")

                        DatePicker("Evening Refresh", selection: refresh2DateBinding, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .accessibilityIdentifier("votdRefreshTime2")
                    } else if refreshFrequency == .daily {
                        DatePicker("Daily Refresh Time", selection: refresh1DateBinding, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .accessibilityIdentifier("votdDailyRefreshTime")
                    }

                    Text(nextVOTDDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("votdNextRefreshDescription")

                    Toggle("Notify When Verse Refreshes", isOn: notificationBinding)
                        .accessibilityIdentifier("votdRefreshNotifications")

                    LabeledContent("Notification Access") {
                        Text(notificationPermissionStatus)
                            .foregroundStyle(notificationPermissionStatusColor)
                    }

                    if notificationAuthorizationStatus == .denied {
                        Button("Open System Settings", action: openSystemSettings)
                    }
                }
                .padding(.top, 8)
            }
        }
        .headerProminence(.increased)
        .onChange(of: verseOfDayPaused) { _, _ in
            updateNotificationSchedule()
        }
        .task {
            await updateNotificationAuthorizationStatus()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await updateNotificationAuthorizationStatus()
            }
        }
        .alert("Notifications Are Off", isPresented: $showsNotificationPermissionAlert) {
            Button("Open System Settings", action: openSystemSettings)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Allow notifications for The Bible in Settings to be notified when the verse refreshes.")
        }
    }

    private var notificationPermissionStatus: LocalizedStringResource {
        switch notificationAuthorizationStatus {
        case .authorized:
            "Allowed"
        case .denied:
            "Off in System Settings"
        case .notDetermined:
            "Not Requested"
        case .provisional:
            "Provisional"
        case .ephemeral:
            "Temporary"
        @unknown default:
            "Unknown"
        }
    }

    private var notificationPermissionStatusColor: Color {
        switch notificationAuthorizationStatus {
        case .authorized, .provisional, .ephemeral:
            .green
        case .denied:
            .orange
        case .notDetermined:
            .secondary
        @unknown default:
            .secondary
        }
    }

    private var notificationBinding: Binding<Bool> {
        Binding(
            get: { notificationsEnabled },
            set: { newValue in
                if newValue {
                    Task { await enableNotifications() }
                } else {
                    notificationsEnabled = false
                    VOTDNotificationScheduler.cancel()
                }
            }
        )
    }

    @MainActor
    private func enableNotifications() async {
        let allowed = await VOTDNotificationScheduler.requestAuthorizationIfNeeded()
        await updateNotificationAuthorizationStatus()
        notificationsEnabled = allowed

        if allowed {
            updateNotificationSchedule()
        } else {
            showsNotificationPermissionAlert = true
        }
    }

    @MainActor
    private func updateNotificationAuthorizationStatus() async {
        notificationAuthorizationStatus = await UNUserNotificationCenter.current()
            .notificationSettings()
            .authorizationStatus
    }

    private func updateNotificationSchedule() {
        guard notificationsEnabled, !verseOfDayPaused else {
            VOTDNotificationScheduler.cancel()
            return
        }

        Task {
            await VOTDNotificationScheduler.schedule(
                frequency: refreshFrequency,
                first: (votdRefresh1Hour, votdRefresh1Minute),
                second: (votdRefresh2Hour, votdRefresh2Minute)
            )
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func segmentButton(title: String, tag: String) -> some View {
        Button(action: { verseScopeRaw = tag }) {
            Text(title)
                .font(.subheadline)
                .fontWeight(verseScopeRaw == tag ? .semibold : .regular)
                .foregroundStyle(verseScopeRaw == tag ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if verseScopeRaw == tag {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentColor.opacity(0.15))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    private func verticalSeparator() -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.25))
            .frame(width: 1, height: 24)
    }
}

enum VOTDNotificationScheduler {
    private static let hourlyIdentifiers = (0..<24).map { "verse-of-day-refresh-hourly-\($0)" }
    private static let identifiers = hourlyIdentifiers + [
        "verse-of-day-refresh-first",
        "verse-of-day-refresh-second"
    ]

    static func notificationTitles(forHour hour: Int) -> [String] {
        switch hour {
        case 5..<12:
            [
                String(localized: "☀ Start your day in the Word"),
                String(localized: "Good morning—today’s verse is ready"),
                String(localized: "A verse for the start of your day"),
                String(localized: "Begin with a moment of Scripture")
            ]
        case 12..<17:
            [
                String(localized: "☀ Pause for a verse"),
                String(localized: "A moment of Scripture for your day"),
                String(localized: "Take a breath—today’s verse is here"),
                String(localized: "A little encouragement for your afternoon")
            ]
        default:
            [
                String(localized: "🌙 End your day with Scripture"),
                String(localized: "A verse for a quiet moment tonight"),
                String(localized: "Wind down with today’s verse"),
                String(localized: "Before you rest, a word of encouragement")
            ]
        }
    }

    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) == true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    static func schedule(
        frequency: VOTDRefreshFrequency,
        first: (hour: Int, minute: Int),
        second: (hour: Int, minute: Int)
    ) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        let times: [(identifier: String, hour: Int, minute: Int)]
        switch frequency {
        case .hourly:
            // Repeating notifications have fixed content. Scheduling one for each hour
            // lets the wording reflect the time it is actually delivered.
            times = (0..<24).map { hour in
                (hourlyIdentifiers[hour], hour, 0)
            }
        case .daily:
            times = [("verse-of-day-refresh-first", first.hour, first.minute)]
        case .custom:
            times = [
                ("verse-of-day-refresh-first", first.hour, first.minute),
                ("verse-of-day-refresh-second", second.hour, second.minute)
            ]
        }

        for time in times {
            let content = UNMutableNotificationContent()
            content.title = notificationTitles(forHour: time.hour).randomElement() ?? "Verse of the Day"
            content.body = String(localized: "Verse of the Day")
            content.sound = .default
            content.userInfo = ["destination": "verseOfDay"]

            var components = DateComponents()
            components.hour = time.hour
            components.minute = time.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: time.identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
