import SwiftUI
import UIKit
import UserNotifications
import WidgetKit

struct SettingsView: View {
    @AppStorage("colorSchemePreference") private var colorSchemePreferenceRaw: String = "system"
    var body: some View {
        Form {
            SettingsPersonalizeLinksSection()
                .listRowBackground(HeroCardListRowBackground())
            SettingsReadingLinksSection()
                .listRowBackground(HeroCardListRowBackground())
            SettingsPrayerLinksSection()
                .listRowBackground(HeroCardListRowBackground())
            SettingsPrivacyAndSyncLinksSection()
                .listRowBackground(HeroCardListRowBackground())
            SettingsHelpSection()
                .listRowBackground(HeroCardListRowBackground())
            SettingsDataManagementLinksSection()
                .listRowBackground(HeroCardListRowBackground())

            #if DEBUG
            SettingsDeveloperSection()
                .listRowBackground(HeroCardListRowBackground())
            #endif
        }
        .scrollContentBackground(.hidden)
        .background(AppBackgroundView(tab: .more))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .formStyle(.grouped)
        .defaultScrollAnchor(.top)
        .preferredColorScheme((ColorSchemePreference(rawValue: colorSchemePreferenceRaw) ?? .system).colorScheme)
    }
}

private struct SettingsPersonalizeLinksSection: View {
    var body: some View {
        Section("Personalize") {
            NavigationLink {
                SettingsAppearanceDetailView()
            } label: {
                SettingsNavigationRow(
                    title: "Appearance",
                    subtitle: "Theme and Home background",
                    systemImage: "paintbrush"
                )
            }

            NavigationLink {
                SettingsHomeLayoutSection()
            } label: {
                SettingsNavigationRow(
                    title: "Home Layout",
                    subtitle: "Choose what appears on Home",
                    systemImage: "rectangle.grid.1x2"
                )
            }

            NavigationLink {
                SettingsLaunchTabSection()
            } label: {
                SettingsNavigationRow(
                    title: "Launch Page",
                    subtitle: "Choose where the app opens on this device",
                    systemImage: "rectangle.on.rectangle"
                )
            }

            NavigationLink {
                SettingsWidgetAppearanceDetailView()
            } label: {
                SettingsNavigationRow(
                    title: "Widgets",
                    subtitle: "Choose backgrounds for your widgets",
                    systemImage: "rectangle.3.group"
                )
            }
        }
    }
}

private struct SettingsReadingLinksSection: View {
    var body: some View {
        Section("Reading") {
            NavigationLink {
                SettingsBibleReaderDetailView()
            } label: {
                SettingsNavigationRow(
                    title: "Bible Reader",
                    subtitle: "Focus Reading and verse indicators",
                    systemImage: "book"
                )
            }

            NavigationLink {
                SettingsDailyGoalDetailView()
            } label: {
                SettingsNavigationRow(
                    title: "Daily Goal",
                    subtitle: "Set your daily reading target",
                    systemImage: "target"
                )
            }

            NavigationLink {
                SettingsVerseOfTheDayDetailView()
            } label: {
                SettingsNavigationRow(
                    title: "Verse of the Day",
                    subtitle: "Source, refresh schedule, and notifications",
                    systemImage: "book.pages"
                )
            }
        }
    }
}

private struct SettingsPrayerLinksSection: View {
    var body: some View {
        Section("Prayer") {
            NavigationLink {
                SettingsTimerDetailView()
            } label: {
                SettingsNavigationRow(
                    title: "Prayer Timer",
                    subtitle: "Sound, alarms, Live Activities, and Mindful Minutes",
                    systemImage: "timer"
                )
            }
        }
    }
}

private struct SettingsReadingProgressSection: View {
    @AppStorage(ReaderDisplaySettings.showsVerseMarkersKey) private var showsVerseMarkers = true
    @AppStorage(ReaderDisplaySettings.showsReadProgressKey) private var showsReadProgress = false
    @AppStorage("focusReadingEnabled") private var focusReadingEnabled = false
    @AppStorage(RedLetterText.suppliedWordsInItalicsKey) private var italicizesSuppliedWords = false

    var body: some View {
        Section {
            Toggle(isOn: $focusReadingEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Focus Reading")
                        Text("Open the reader with one verse on screen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .foregroundStyle(.tint)
                }
            }
            .accessibilityIdentifier("focusReadingToggle")

            Toggle(isOn: $showsVerseMarkers) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Verse Markers")
                        Text("Show your bookmark, favorites, and notes beside each reference")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "bookmark")
                        .foregroundStyle(.tint)
                }
            }
            .accessibilityIdentifier("verseMarkersToggle")

            Toggle(isOn: $showsReadProgress) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Read Progress")
                        Text("Mark verses you've read with a faint edge")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.tint)
                }
            }
            .accessibilityIdentifier("readVerseCheckmarksToggle")

            Toggle(isOn: $italicizesSuppliedWords) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Supplied Words in Italics")
                        Text("Italicize words the KJV translators added for clarity")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "italic")
                        .foregroundStyle(.tint)
                }
            }
            .accessibilityIdentifier("suppliedWordsItalicsToggle")
        } header: {
            Text("Bible Reader")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Bookmark, heart, and note icons appear beside the verse reference. Tap a note icon to open the note.")
                Text("Read progress reflects your reading statistics and disappears when they are reset.")
                Text("Printed King James Bibles set supplied words in italics, such as “ye *are* the branches.”")
            }
        }
    }
}

private struct SettingsPrivacyAndSyncLinksSection: View {
    @Environment(CloudKitManager.self) private var cloudKitManager
    @State private var lastSyncActivity: Date?

    var body: some View {
        Section("Privacy & Sync") {
            NavigationLink {
                SettingsPermissionsDetailView()
            } label: {
                SettingsNavigationRow(
                    title: "Permissions",
                    subtitle: "Notifications and photo access",
                    systemImage: "hand.raised"
                )
            }

            NavigationLink {
                SettingsiCloudDetailView()
            } label: {
                SettingsNavigationRow(
                    title: "iCloud Sync",
                    subtitle: iCloudSubtitle,
                    systemImage: "icloud"
                )
            }

        }
        .task {
            updateLastSyncActivity()
            for await _ in NotificationCenter.default.notifications(
                named: UserDefaults.didChangeNotification
            ) {
                updateLastSyncActivity()
            }
        }
    }

    private var iCloudSubtitle: LocalizedStringResource {
        switch cloudKitManager.accountState {
        case .available where lastSyncActivity != nil:
            "Available · Synced recently"
        case .available:
            "Available · No sync activity yet"
        case .noAccount:
            "No iCloud account"
        case .restricted:
            "iCloud restricted"
        case .couldNotDetermine:
            "iCloud unavailable"
        case .unknown:
            "Checking iCloud status"
        }
    }

    private func updateLastSyncActivity() {
        let coordinator = iCloudSyncCoordinator.shared
        lastSyncActivity = [coordinator.lastPushDate, coordinator.lastMergeDate]
            .compactMap { $0 }
            .max()
    }
}

private struct SettingsDataManagementLinksSection: View {
    var body: some View {
        Section {
            NavigationLink {
                SettingsResetDataDetailView()
            } label: {
                SettingsNavigationRow(
                    title: "Reset Data",
                    subtitle: "Permanently reset game or reading statistics",
                    systemImage: "trash"
                )
            }
        }
    }
}

private struct SettingsHelpSection: View {
    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false
    @AppStorage("contextualTipsResetGeneration") private var contextualTipsResetGeneration = 0

    var body: some View {
        Section {
            Toggle(isOn: $contextualTipsEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Contextual Tips")
                        Text("Show helpful hints while exploring features")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "lightbulb")
                        .foregroundStyle(.tint)
                }
            }
            .accessibilityIdentifier("contextualTipsToggle")
            .onChange(of: contextualTipsEnabled) { wasEnabled, isEnabled in
                if !wasEnabled && isEnabled {
                    contextualTipsResetGeneration &+= 1
                }
            }

            NavigationLink {
                FeedbackView()
            } label: {
                SettingsNavigationRow(
                    title: "Share Feedback",
                    subtitle: "Send comments, suggestions, or report a problem",
                    systemImage: "envelope"
                )
            }
            .accessibilityIdentifier("shareFeedbackLink")

            LabeledContent {
                Text(appVersion)
            } label: {
                Label {
                    Text("Version")
                } icon: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.tint)
                }
            }
            .accessibilityIdentifier("appVersionRow")
        } header: {
            Text("Help")
        } footer: {
            Text("Tips appear near features such as favorites, reader gestures, verse actions, stats, widgets, timers, Health, and Home customization.")
        }
    }

    /// Marketing version and build number, e.g. "1.2 (45)".
    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        guard let build = info?["CFBundleVersion"] as? String else { return version }
        return "\(version) (\(build))"
    }
}

#if DEBUG
private struct SettingsDeveloperSection: View {
    @State private var showingConfirmation = false
    @State private var showingCompletion = false
    @State private var showingResetConfirmation = false
    @State private var showingResetCompletion = false

    var body: some View {
        Section {
            Button {
                showingConfirmation = true
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Generate Sample Stats")
                        Text("Fill reading and game charts with randomized data")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "wand.and.stars")
                        .foregroundStyle(.purple)
                }
            }
            .accessibilityIdentifier("generateDeveloperSampleStatsButton")
            .confirmationDialog(
                "Generate Sample Statistics?",
                isPresented: $showingConfirmation,
                titleVisibility: .visible
            ) {
                Button("Generate Data") {
                    Task {
                        await DeveloperSampleData.generate()
                        showingCompletion = true
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This adds about 90 days of randomized reading and game activity. You can remove it later from Reset Data.")
            }
            .alert("Sample Data Created", isPresented: $showingCompletion) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The Home and Stats views now have randomized reading and game activity to display.")
            }

            Button(role: .destructive) {
                showingResetConfirmation = true
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reset Permissions & Settings")
                        Text("Restore app defaults and cancel permission-based features")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "arrow.counterclockwise.circle")
                }
            }
            .accessibilityIdentifier("resetDeveloperPermissionsAndSettingsButton")
            .confirmationDialog(
                "Reset Permissions and Settings?",
                isPresented: $showingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    DeveloperSettingsReset.perform()
                    showingResetCompletion = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This restores every app preference to its default, cancels pending notifications and prayer alarms, and ends Live Activities. iOS authorization decisions must still be changed in System Settings.")
            }
            .alert("App Settings Reset", isPresented: $showingResetCompletion) {
                Button("Open System Settings") {
                    DeveloperSettingsReset.openSystemSettings()
                }
                Button("Done", role: .cancel) {}
            } message: {
                Text("App settings are back to their defaults. To make Notifications, Prayer Timer Alarms, Mindful Minutes, or Live Activities appear not requested again, reset them in iOS Settings or reset privacy on the simulator. Photo Selection uses the system picker and has no persistent library permission.")
            }
        } header: {
            Label("Developer", systemImage: "hammer")
        } footer: {
            Text("Debug builds only. This section is not included in App Store builds.")
        }
    }
}

@MainActor
private enum DeveloperSettingsReset {
    static func perform() {
        let defaults = UserDefaults.standard
        let defaultValues: [String: Any] = [
            "colorSchemePreference": "system",
            "dailyGoalMinutes": 30,
            StreakTracker.graceDaysEnabledKey: true,
            StreakReminderScheduler.enabledKey: false,
            StreakReminderScheduler.hourKey: StreakReminderScheduler.defaultHour,
            StreakReminderScheduler.minuteKey: 0,
            "streakCelebratedMilestone": 0,
            "timerSoundSelection": TimerSound.default.rawValue,
            "verseOfDayScope": "whole",
            "verseOfDaySpecificBook": "",
            "votdRefreshFrequency": VOTDRefreshFrequency.custom.rawValue,
            "votdRefresh1Hour": 6,
            "votdRefresh1Minute": 0,
            "votdRefresh2Hour": 18,
            "votdRefresh2Minute": 0,
            "votdRefreshNotificationsEnabled": false,
            "verseOfDayPaused": false,
            "liveActivitiesEnabled": true,
            "healthKitMindfulMinutesEnabled": false,
            "didRequestNotifications": false,
            "contextualTipsEnabled": false,
            "readerFontSize": 17.0,
            ReaderDisplaySettings.showsReadProgressKey: false,
            ReaderDisplaySettings.showsVerseMarkersKey: true,
            "focusReadingEnabled": false,
            "homeCustomizeButtonVisible": true,
            "homeBibleReaderVisible": HomeLayoutStore.defaultBibleReaderVisible,
            "noteEditorTextSizeStep": 0,
            "notesTabSortField": "modified",
            "notesTabSortAscending": false,
            "bibleBooksSortAlphabetical": false,
            "bibleRecentSearches": "",
            "lastReadWidgetBackground": "system",
            "pinnedVerseWidgetBackground": "system",
            "verseWidgetBackground": "system",
            "statsSelectedMode": "Reading Stats",
            "statsSelectedGame": "All Games",
            "debugAutoWinEnabled": false,
            "beatTheClockCategory": "people",
            "beatTheClockDifficulty": "medium",
            "hangmanDifficulty": "medium",
            "hangmanTheme": "people",
            "quizDifficulty": "normal",
            "quizScope": "whole",
            "quizSections": "",
            "verseMatchDifficulty": "medium",
            "versematchScope": "whole",
            "versematchSections": "",
            "wordleAllowDailyReplay": false,
            "wordleHardModeEnabled": false,
            "prayerTimerRunning": false,
            "prayerTimerPaused": false,
            "prayerTimerTotalSeconds": 0,
            "prayerTimerRemainingWhenPaused": 0,
            "prayerTimerEndDate": 0.0,
            "prayerTimerStartDate": 0.0,
            "prayerTimerLastActionToken": "",
            PrayerTimerController.lastMinutesKey: 0,
            "prayerTimerVerseSource": PrayerVerseSource.verseOfDay.rawValue,
            "prayerSegmentStartDate": 0.0,
            "prayerSessionSeconds": 0,
            "mindfulSessionStartDate": 0.0
        ]

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
            "homeCardFavoriteShowMoreVisible"
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

private struct SettingsNavigationRow: View {
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
        }
    }
}

private struct SettingsAppearanceDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "Appearance") {
            SettingsAppearanceSection()
            SettingsBackgroundSection()
        }
    }
}

private struct SettingsWidgetAppearanceDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "Widgets") {
            SettingsWidgetAppearanceSection()
        }
    }
}

private struct SettingsWidgetAppearanceSection: View {
    private static let sharedDefaults = UserDefaults(suiteName: "group.bible.app") ?? .standard

    @AppStorage("verseWidgetBackground", store: sharedDefaults)
    private var verseBackgroundRaw = WidgetBackgroundStyle.black.rawValue

    @AppStorage("lastReadWidgetBackground", store: sharedDefaults)
    private var lastReadBackgroundRaw = WidgetBackgroundStyle.black.rawValue

    @AppStorage("pinnedVerseWidgetBackground", store: sharedDefaults)
    private var pinnedVerseBackgroundRaw = WidgetBackgroundStyle.black.rawValue

    var body: some View {
        Section {
            backgroundPicker(
                title: "Verse of the Day",
                systemImage: "sun.max.fill",
                selection: $verseBackgroundRaw,
                accessibilityIdentifier: "verseWidgetBackgroundPicker"
            )

            backgroundPicker(
                title: "Last Read",
                systemImage: "bookmark.fill",
                selection: $lastReadBackgroundRaw,
                accessibilityIdentifier: "lastReadWidgetBackgroundPicker"
            )

            backgroundPicker(
                title: "Pinned Verse",
                systemImage: "pin.fill",
                selection: $pinnedVerseBackgroundRaw,
                accessibilityIdentifier: "pinnedVerseWidgetBackgroundPicker"
            )
        } header: {
            Text("Widget Backgrounds")
        } footer: {
            Text("Your choices apply to every Verse of the Day, Last Read, and Pinned Verse widget. The system may adapt colors when widgets are tinted.")
        }
        .onChange(of: verseBackgroundRaw) { _, _ in
            WidgetCenter.shared.reloadTimelines(ofKind: "VerseWidget")
        }
        .onChange(of: lastReadBackgroundRaw) { _, _ in
            WidgetCenter.shared.reloadTimelines(ofKind: "LastReadWidget")
        }
        .onChange(of: pinnedVerseBackgroundRaw) { _, _ in
            WidgetCenter.shared.reloadTimelines(ofKind: "PinnedVerseWidget")
        }
    }

    private func backgroundPicker(
        title: LocalizedStringResource,
        systemImage: String,
        selection: Binding<String>,
        accessibilityIdentifier: String
    ) -> some View {
        let selectedStyle = WidgetBackgroundStyle(rawValue: selection.wrappedValue) ?? .black

        return HStack {
            Label(title, systemImage: systemImage)

            Spacer()

            Menu {
                ForEach(WidgetBackgroundStyle.allCases) { style in
                    Button {
                        selection.wrappedValue = style.rawValue
                    } label: {
                        Label {
                            Text(style.title)
                        } icon: {
                            Image(systemName: selection.wrappedValue == style.rawValue
                                  ? "checkmark.circle.fill"
                                  : "circle.fill")
                                .foregroundStyle(style.previewStyle)
                        }
                    }
                }
            } label: {
                HStack(spacing: 7) {
                    Circle()
                        .fill(selectedStyle.previewStyle)
                        .frame(width: 14, height: 14)
                        .overlay {
                            Circle()
                                .strokeBorder(.secondary.opacity(0.35), lineWidth: 1)
                        }

                    Text(selectedStyle.title)
                        .foregroundStyle(.primary)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel(title)
            .accessibilityValue(Text(selectedStyle.title))
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private enum WidgetBackgroundStyle: String, CaseIterable, Identifiable {
    case black
    case midnight
    case forest
    case burgundy
    case indigo
    case sunset
    case blackToGray
    case blueToPurple

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .black: "Black"
        case .midnight: "Midnight"
        case .forest: "Forest"
        case .burgundy: "Burgundy"
        case .indigo: "Indigo"
        case .sunset: "Sunset"
        case .blackToGray: "Graphite"
        case .blueToPurple: "Aurora"
        }
    }

    var previewStyle: AnyShapeStyle {
        switch self {
        case .black:
            AnyShapeStyle(Color.black)
        case .midnight:
            AnyShapeStyle(Color(red: 0.04, green: 0.11, blue: 0.23))
        case .forest:
            AnyShapeStyle(Color(red: 0.05, green: 0.25, blue: 0.18))
        case .burgundy:
            AnyShapeStyle(Color(red: 0.35, green: 0.06, blue: 0.12))
        case .indigo:
            AnyShapeStyle(Color(red: 0.16, green: 0.12, blue: 0.40))
        case .sunset:
            AnyShapeStyle(Color(red: 0.48, green: 0.16, blue: 0.18))
        case .blackToGray:
            AnyShapeStyle(
                LinearGradient(
                    colors: [.black, .gray],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .blueToPurple:
            AnyShapeStyle(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
}

private struct SettingsBibleReaderDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "Bible Reader") {
            SettingsReadingProgressSection()
        }
    }
}

private struct SettingsVerseOfTheDayDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "Verse of the Day") {
            SettingsVOTDSection()
        }
    }
}

private struct SettingsDailyGoalDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "Daily Goal") {
            SettingsDailyGoalSection()
        }
    }
}

private struct SettingsTimerDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "Prayer Timer") {
            SettingsTimerSection()
            SettingsPrayerTimerAccessSection()
        }
    }
}

private struct SettingsPermissionsDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "Permissions") {
            SettingsPermissionsSection()
        }
    }
}

private struct SettingsiCloudDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "iCloud Sync") {
            SettingsiCloudSection()
        }
    }
}

private struct SettingsResetDataDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "Reset Data") {
            SettingsResetDataSection()
        }
    }
}

private struct SettingsDetailForm<Content: View>: View {
    let title: LocalizedStringResource
    let content: Content

    init(
        title: LocalizedStringResource,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        Form {
            content
                .listRowBackground(HeroCardListRowBackground())
        }
        .scrollContentBackground(.hidden)
        .background(AppBackgroundView(tab: .more))
        .navigationTitle(Text(title))
        .navigationBarTitleDisplayMode(.inline)
        .formStyle(.grouped)
        .defaultScrollAnchor(.top)
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(
            CloudKitManager(containerIdentifier: "iCloud.creecy.bible")
        )
}
