import SwiftUI

/// Every notification and alarm the app can send, in one place. Each control is the same one
/// shown in its feature's settings, using the same saved setting, so the two always agree.
struct SettingsNotificationsSection: View {
    var body: some View {
        Section {
            NotificationAccessRow()
        } header: {
            Text("Access")
                .foregroundStyle(.primary)
        } footer: {
            Text("Notifications must be allowed for the reminders below.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        Section {
            VOTDNotificationToggle(showsIcon: true)
        } header: {
            Text("Verse of the Day")
                .foregroundStyle(.primary)
        } footer: {
            Text("Sent at your refresh times, which you can change in Verse of the Day settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        Section {
            StreakReminderRows()
        } header: {
            Text("Reading Streak")
                .foregroundStyle(.primary)
        } footer: {
            Text("Skipped on days you've already met your daily goal.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        if #available(iOS 26.1, *) {
            Section {
                PrayerTimerAlarmToggle()
            } header: {
                Text("Prayer & Study Timer")
                    .foregroundStyle(.primary)
            } footer: {
                Text("Lets the timer ring as an alarm when it finishes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
