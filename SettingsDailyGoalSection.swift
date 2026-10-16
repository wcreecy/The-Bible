import SwiftUI
import UserNotifications

struct SettingsDailyGoalSection: View {
    @AppStorage("dailyGoalMinutes") private var dailyGoalMinutes: Int = 30
    @AppStorage(StreakReminderScheduler.enabledKey) private var reminderEnabled = false
    @AppStorage(StreakReminderScheduler.hourKey) private var reminderHour = StreakReminderScheduler.defaultHour
    @AppStorage(StreakReminderScheduler.minuteKey) private var reminderMinute = 0

    @State private var isDailyGoalSheetPresented: Bool = false
    @State private var showsNotificationPermissionAlert = false

    var body: some View {
        Section(
            header: Text("Daily Goal").foregroundStyle(.primary),
            footer: Text("Set the number of minutes you want to spend in the app each day. Your reading streak is based on meeting this goal. The reminder is skipped on days you've already met your goal.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        ) {
            // Wrap in a container and attach .sheet here to avoid Section-hosting conflicts
            VStack(spacing: 0) {
                Button {
                    guard !isDailyGoalSheetPresented else { return }
                    isDailyGoalSheetPresented = true
                } label: {
                    HStack {
                        Label("Daily Goal", systemImage: "target")
                            .foregroundStyle(Color.accentColor)
                        Spacer()
                        Text("\(dailyGoalMinutes) min")
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("dailyGoalMinutesPickerLink")
            }
            .sheet(isPresented: $isDailyGoalSheetPresented) {
                DailyGoalEditorView()
            }

            Toggle(isOn: reminderBinding) {
                Label("Streak Reminder", systemImage: "bell.badge")
            }
            .accessibilityIdentifier("streakReminderToggle")

            if reminderEnabled {
                DatePicker(
                    "Remind Me At",
                    selection: reminderTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                .accessibilityIdentifier("streakReminderTimePicker")
            }
        }
        .headerProminence(.increased)
        .onAppear {
            // Ensure there is a baseline history so older days evaluate consistently
            DailyGoalHistoryStore.shared.ensureSeededIfNeeded()
        }
        .alert("Notifications Are Off", isPresented: $showsNotificationPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow notifications for this app in Settings to get streak reminders.")
        }
    }

    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { reminderEnabled },
            set: { newValue in
                guard newValue else {
                    reminderEnabled = false
                    Task { await StreakReminderScheduler.cancel() }
                    return
                }
                Task {
                    let allowed = await VOTDNotificationScheduler.requestAuthorizationIfNeeded()
                    reminderEnabled = allowed
                    if allowed {
                        await StreakReminderScheduler.refresh()
                    } else {
                        showsNotificationPermissionAlert = true
                    }
                }
            }
        )
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: Date()) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reminderHour = components.hour ?? StreakReminderScheduler.defaultHour
                reminderMinute = components.minute ?? 0
                Task { await StreakReminderScheduler.refresh() }
            }
        )
    }
}

/// Schedules an evening reminder on days the reading goal isn't met yet.
///
/// Local notifications can't check the goal when they fire, so one is scheduled for
/// each of the next few days, and today's is left out once the goal is met. The app
/// calls `refresh()` whenever it becomes active or moves to the background.
@MainActor
enum StreakReminderScheduler {
    static let enabledKey = "streakReminderEnabled"
    static let hourKey = "streakReminderHour"
    static let minuteKey = "streakReminderMinute"
    static let defaultHour = 20
    /// `userInfo["destination"]` value, so tapping the reminder opens Home.
    static let destination = "readingStreak"

    private static let identifierPrefix = "reading-streak-reminder-"
    private static let daysAhead = 7

    static func refresh(now: Date = Date()) async {
        await cancel()

        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: enabledKey) else { return }

        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            break
        default:
            return
        }

        let hour = defaults.object(forKey: hourKey) as? Int ?? defaultHour
        let minute = defaults.object(forKey: minuteKey) as? Int ?? 0
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: now)
        let summary = StreakTracker.summary(now: now)

        for offset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fireDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  fireDate > now else { continue }
            if offset == 0 && summary.todayGoalMet { continue }

            let content = UNMutableNotificationContent()
            if offset == 0 && summary.current > 0 {
                // Today's progress is known, so this one can be specific.
                let minutesLeft = max(1, Int((Double(summary.todayRemainingSeconds) / 60).rounded(.up)))
                content.title = String(localized: "Keep your \(summary.current)-day streak going")
                content.body = String(localized: "Read \(minutesLeft) more min today to reach your goal.")
            } else {
                content.title = String(localized: "Time in the Word")
                content.body = String(localized: "A few minutes of reading today keeps your streak going.")
            }
            content.sound = .default
            content.userInfo = ["destination": destination]

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let identifier = identifierPrefix + BibleStatsStore.isoDateString(day)
            try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        }
    }

    static func cancel() async {
        let center = UNUserNotificationCenter.current()
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

struct DailyGoalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("dailyGoalMinutes") private var dailyGoalMinutes: Int = 30

    @State private var selectedMinutes: Int = 30

    var body: some View {
        NavigationStack {
            Picker("Daily Goal", selection: $selectedMinutes) {
                ForEach(1...240, id: \.self) { minutes in
                    Text("\(minutes) minute\(minutes == 1 ? "" : "s")").tag(minutes)
                }
            }
            .pickerStyle(.wheel)
            .accessibilityIdentifier("dailyGoalMinutesWheel")
            .navigationTitle("Daily Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dailyGoalMinutes = selectedMinutes
                        DailyGoalHistoryStore.shared.recordChange(minutes: selectedMinutes, at: Date())
                        iCloudSyncCoordinator.shared.pushKey("dailyGoalMinutes")
                        dismiss()
                    }
                }
            }
            .onAppear {
                selectedMinutes = dailyGoalMinutes
            }
        }
        .presentationDetents([.medium, .large])
    }
}
