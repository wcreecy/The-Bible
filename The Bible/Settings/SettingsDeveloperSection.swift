import SwiftUI
import UIKit
import UserNotifications
import WidgetKit

#if DEBUG
struct SettingsDeveloperSection: View {
    var body: some View {
        Section {
            NavigationLink {
                SettingsDeveloperToolsView()
            } label: {
                SettingsNavigationRow(
                    title: "Developer Tools",
                    subtitle: "Sample data, resets, streaks, notifications, sync, and diagnostics",
                    systemImage: "wrench.and.screwdriver"
                )
            }
        } header: {
            Label("Developer", systemImage: "hammer")
        } footer: {
            Text("Debug builds only. This section is not included in App Store builds.")
        }
    }
}

@MainActor
enum DeveloperSettingsReset {
    /// What each setting is reset to: every preference's default, plus the timer and
    /// onboarding state that a fresh install starts without.
    static var defaultValues: [String: Any] {
        AppSettingsDefaults.preferences.merging(runtimeStateDefaults) { preference, _ in preference }
    }

    private static var runtimeStateDefaults: [String: Any] {
        [
            "streakCelebratedMilestone": 0,
            "didRequestNotifications": false,
            "bibleRecentSearches": "",
            "debugAutoWinEnabled": false,
            "debugForcedStoreMode": "",
            "prayerTimerRunning": false,
            "prayerTimerPaused": false,
            "prayerTimerTotalSeconds": 0,
            "prayerTimerRemainingWhenPaused": 0,
            "prayerTimerEndDate": 0.0,
            "prayerTimerStartDate": 0.0,
            PrayerTimerController.lastMinutesKey: 0,
            "prayerTimerActiveKind": PrayerTimerKind.prayer.rawValue,
            "prayerSegmentStartDate": 0.0,
            "prayerSessionSeconds": 0,
            "mindfulSessionStartDate": 0.0
        ]
    }

    static func perform() {
        let defaults = UserDefaults.standard

        for (key, value) in defaultValues {
            defaults.set(value, forKey: key)
        }

        let homeLayoutKeys = [
            "homeCardOrder",
            "homeCardHidden",
            "homeCardMain",
            "homeShowMoreVisible",
            "homeCardFavoriteOrder",
            "homeCardFavoriteHidden",
            "homeCardFavoriteMain",
            "homeCardFavoriteShowMoreVisible",
            HomeLayoutStore.keyColumns,
            HomeLayoutStore.keyFavColumns,
            HomeLayoutStore.keyFavBibleReaderColumn,
            HomeLayoutStore.legacyKeyBibleReaderOnLeft,
            HomeLayoutStore.legacyKeyFavBibleReaderOnLeft
        ]
        homeLayoutKeys.forEach(defaults.removeObject(forKey:))

        for tab in AppTab.allCases {
            defaults.set(
                AppBackgroundMode.defaultStyle.rawValue,
                forKey: AppBackgroundStorage.modeKey(for: tab)
            )
            defaults.set("#F2F2F7", forKey: AppBackgroundStorage.colorKey(for: tab))
            defaults.set("", forKey: AppBackgroundStorage.photoKey(for: tab))
        }
        AppBackgroundStorage.removeUnusedPhotos(defaults: defaults)

        NotificationCenter.default.post(name: .resetPrayerTimer, object: nil)
        NotificationCenter.default.post(name: .homeLayoutChanged, object: nil)
        VOTDNotificationScheduler.cancel()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        PrayerTimerAlarmScheduler.cancel()
        PrayerTimerActivityController.shared.cancel()
        iCloudSyncCoordinator.shared.pushKey("dailyGoalMinutes")
        WidgetCenter.shared.reloadAllTimelines()
        Haptics.success()
    }

    static func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
#endif
