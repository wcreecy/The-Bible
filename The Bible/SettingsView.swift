import SwiftUI
import UIKit
import UserNotifications
import WidgetKit

struct SettingsView: View {
    @AppStorage(AppStorageKey.colorSchemePreference) private var colorSchemePreferenceRaw: String = "system"
    var body: some View {
        Form {
            SettingsAppLinksSection()
                .listRowBackground(HeroCardListRowBackground())
            SettingsReadingAndPrayerLinksSection()
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

private struct SettingsAppLinksSection: View {
    @AppStorage(AppStorageKey.colorSchemePreference) private var colorSchemePreferenceRaw = ColorSchemePreference.system.rawValue
    @AppStorage(LaunchTabPreference.defaultsKey) private var launchTabRaw = LaunchTabPreference.home.rawValue

    var body: some View {
        Section("App") {
            NavigationLink {
                SettingsAppearanceDetailView()
            } label: {
                SettingsNavigationRow(
                    title: "Appearance",
                    subtitle: appearanceSummary,
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
                    subtitle: launchPageSummary,
                    systemImage: "rectangle.on.rectangle"
                )
            }

        }
    }

    private var appearanceSummary: LocalizedStringResource {
        switch ColorSchemePreference(rawValue: colorSchemePreferenceRaw) ?? .system {
        case .system: "System appearance"
        case .light: "Light appearance"
        case .dark: "Dark appearance"
        }
    }

    private var launchPageSummary: LocalizedStringResource {
        switch LaunchTabPreference(rawValue: launchTabRaw) ?? .home {
        case .home: "Opens to Home"
        case .bible: "Opens to Bible"
        case .notes: "Opens to Notes"
        case .games: "Opens to Games"
        }
    }
}

private struct SettingsReadingAndPrayerLinksSection: View {
    @AppStorage(ReaderDisplaySettings.showsReadProgressKey) private var showsReadProgress = false
    @AppStorage(ReaderDisplaySettings.showsVerseMarkersKey) private var showsVerseMarkers = true
    @AppStorage(AppStorageKey.focusReadingEnabled) private var focusReadingEnabled = false
    @AppStorage(AppStorageKey.dailyGoalMinutes) private var dailyGoalMinutes = 30
    @AppStorage(AppStorageKey.verseOfDayScope) private var verseScopeRaw = "whole"
    @AppStorage(AppStorageKey.verseOfDayRefreshFrequency) private var refreshFrequencyRaw = VOTDRefreshFrequency.custom.rawValue
    @AppStorage(AppStorageKey.verseOfDayRefreshNotificationsEnabled) private var verseOfDayNotificationsEnabled = false
    @AppStorage(AppStorageKey.timerSoundSelection) private var timerSoundSelection = TimerSound.default.rawValue

    var body: some View {
        Section("Reading & Prayer") {
            NavigationLink {
                SettingsBibleReaderDetailView()
            } label: {
                SettingsNavigationRow(
                    title: "Bible Reader",
                    subtitle: bibleReaderSummary,
                    status: bibleReaderStatus,
                    systemImage: "book"
                )
            }

            NavigationLink {
                SettingsDailyGoalDetailView()
            } label: {
                SettingsNavigationRow(
                    title: "Daily Goal",
                    subtitle: "Daily reading target",
                    systemImage: "target",
                    value: dailyGoalMinutes
                )
            }

            NavigationLink {
                SettingsVerseOfTheDayDetailView()
            } label: {
                SettingsNavigationRow(
                    title: "Verse of the Day",
                    subtitle: verseOfTheDaySummary,
                    status: verseOfTheDayStatus,
                    systemImage: "book.pages"
                )
            }

            NavigationLink {
                SettingsTimerDetailView()
            } label: {
                SettingsNavigationRow(
                    title: "Prayer & Study Timer",
                    subtitle: prayerTimerSummary,
                    systemImage: "timer"
                )
            }
        }
    }

    private var bibleReaderSummary: LocalizedStringResource {
        if focusReadingEnabled {
            "Focus Reading on"
        } else if showsReadProgress {
            "Reading progress on"
        } else {
            "Standard reading view"
        }
    }

    private var bibleReaderStatus: String {
        String(
            localized: "Focus \(settingStatus(focusReadingEnabled)) · Progress \(settingStatus(showsReadProgress)) · Markers \(settingStatus(showsVerseMarkers))",
            comment: "Bible Reader settings summary; the values are whether Focus Reading, reading progress, and verse markers are enabled."
        )
    }

    private var verseOfTheDaySummary: LocalizedStringResource {
        switch verseScopeRaw {
        case "old": "Old Testament"
        case "new": "New Testament"
        case "book": "A selected book"
        default: "Whole Bible"
        }
    }

    private var verseOfTheDayStatus: String {
        String(
            localized: "\(verseOfTheDayScopeStatus) · \(refreshFrequencyStatus) · Alerts \(settingStatus(verseOfDayNotificationsEnabled))",
            comment: "Verse of the Day settings summary; the values are the selected source, refresh schedule, and whether refresh alerts are enabled."
        )
    }

    private var verseOfTheDayScopeStatus: String {
        switch verseScopeRaw {
        case "old": String(localized: "Old Testament")
        case "new": String(localized: "New Testament")
        case "book": String(localized: "Selected Book")
        default: String(localized: "Whole Bible")
        }
    }

    private var refreshFrequencyStatus: String {
        switch VOTDRefreshFrequency(rawValue: refreshFrequencyRaw) ?? .custom {
        case .custom: String(localized: "Twice Daily")
        case .hourly: String(localized: "Hourly")
        case .daily: String(localized: "Daily")
        }
    }

    private func settingStatus(_ isEnabled: Bool) -> String {
        isEnabled ? String(localized: "On") : String(localized: "Off")
    }

    private var prayerTimerSummary: LocalizedStringResource {
        switch TimerSound(rawValue: timerSoundSelection) ?? .default {
        case .bell: "Bell sound"
        case .chime: "Chime sound"
        case .glass: "Glass sound"
        case .horn: "Horn sound"
        case .piano: "Piano sound"
        case .pop: "Pop sound"
        case .synth: "Synth sound"
        }
    }
}

private struct SettingsReadingProgressSection: View {
    let highlightFocusReading: Bool

    init(highlightFocusReading: Bool = false) {
        self.highlightFocusReading = highlightFocusReading
    }
    @AppStorage(ReaderDisplaySettings.showsVerseMarkersKey) private var showsVerseMarkers = true
    @AppStorage(ReaderDisplaySettings.showsBookmarkMarkersKey) private var showsBookmarkMarkers = true
    @AppStorage(ReaderDisplaySettings.showsPinnedVerseMarkerKey) private var showsPinnedVerseMarker = true
    @AppStorage(ReaderDisplaySettings.showsFavoriteMarkersKey) private var showsFavoriteMarkers = true
    @AppStorage(ReaderDisplaySettings.showsNoteMarkersKey) private var showsNoteMarkers = true
    @AppStorage(ReaderDisplaySettings.showsCrossReferenceMarkersKey) private var showsCrossReferenceMarkers = true
    @AppStorage(ReaderDisplaySettings.showsReadProgressKey) private var showsReadProgress = false
    @AppStorage(AppStorageKey.focusReadingEnabled) private var focusReadingEnabled = false
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
            .listRowBackground(
                highlightFocusReading
                    ? Color.orange.opacity(0.16)
                    : Color.clear
            )

            SettingsVerseMarkersCard(
                showsVerseMarkers: $showsVerseMarkers,
                showsBookmarkMarkers: $showsBookmarkMarkers,
                showsPinnedVerseMarker: $showsPinnedVerseMarker,
                showsFavoriteMarkers: $showsFavoriteMarkers,
                showsNoteMarkers: $showsNoteMarkers,
                showsCrossReferenceMarkers: $showsCrossReferenceMarkers
            )

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
                Text("Choose which bookmark, pinned verse, favorite, note, and cross-reference icons appear beside each verse reference. Tap a note or cross-reference icon to open it.")
                Text("Read progress reflects your reading statistics and disappears when they are reset.")
                Text("Printed King James Bibles set supplied words in italics, such as “ye *are* the branches.”")
            }
        }
    }
}

private struct SettingsVerseMarkersCard: View {
    @Binding private var showsVerseMarkers: Bool
    @Binding private var showsBookmarkMarkers: Bool
    @Binding private var showsPinnedVerseMarker: Bool
    @Binding private var showsFavoriteMarkers: Bool
    @Binding private var showsNoteMarkers: Bool
    @Binding private var showsCrossReferenceMarkers: Bool

    init(
        showsVerseMarkers: Binding<Bool>,
        showsBookmarkMarkers: Binding<Bool>,
        showsPinnedVerseMarker: Binding<Bool>,
        showsFavoriteMarkers: Binding<Bool>,
        showsNoteMarkers: Binding<Bool>,
        showsCrossReferenceMarkers: Binding<Bool>
    ) {
        _showsVerseMarkers = showsVerseMarkers
        _showsBookmarkMarkers = showsBookmarkMarkers
        _showsPinnedVerseMarker = showsPinnedVerseMarker
        _showsFavoriteMarkers = showsFavoriteMarkers
        _showsNoteMarkers = showsNoteMarkers
        _showsCrossReferenceMarkers = showsCrossReferenceMarkers
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $showsVerseMarkers) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Verse Markers")
                        Text("Show your bookmark, pinned verse, favorites, notes, and cross-references beside each reference")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "bookmark")
                        .foregroundStyle(.tint)
                }
            }
            .accessibilityIdentifier("verseMarkersToggle")

            Divider()
                .padding(.leading, 36)

            VStack(spacing: 10) {
                Toggle("Bookmark", isOn: $showsBookmarkMarkers)
                    .accessibilityIdentifier("bookmarkMarkerToggle")

                Toggle("Pinned Verse", isOn: $showsPinnedVerseMarker)
                    .accessibilityIdentifier("pinnedVerseMarkerToggle")

                Toggle("Favorites", isOn: $showsFavoriteMarkers)
                    .accessibilityIdentifier("favoriteMarkerToggle")

                Toggle("Notes", isOn: $showsNoteMarkers)
                    .accessibilityIdentifier("noteMarkerToggle")

                Toggle("Cross-References", isOn: $showsCrossReferenceMarkers)
                    .accessibilityIdentifier("crossReferenceMarkerToggle")
            }
            .padding(.leading, 36)
            .disabled(!showsVerseMarkers)
        }
        .padding(.vertical, 4)
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
    @AppStorage(AppStorageKey.contextualTipsEnabled) private var contextualTipsEnabled = false
    @AppStorage(AppStorageKey.contextualTipsResetGeneration) private var contextualTipsResetGeneration = 0

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

            NavigationLink {
                AcknowledgementsView()
            } label: {
                SettingsNavigationRow(
                    title: "Acknowledgements",
                    subtitle: "Sources and credits",
                    systemImage: "heart.text.square"
                )
            }
            .accessibilityIdentifier("acknowledgementsLink")

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
            Text("Support")
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

/// Credits for data the app includes, as their licenses require.
private struct AcknowledgementsView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("OpenBible.info")
                        .font(.headline)
                    Text("Cross references in Chapter Insights are selected from the OpenBible.info cross-reference dataset, used under the Creative Commons Attribution license.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)

                if let url = URL(string: "https://www.openbible.info") {
                    Link(destination: url) {
                        Label("openbible.info", systemImage: "safari")
                    }
                }
            } header: {
                Text("Cross References")
            }
        }
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
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
                Text("App settings are back to their defaults. To make Notifications, Prayer & Study Timer Alarms, Mindful Minutes, or Live Activities appear not requested again, reset them in iOS Settings or reset privacy on the simulator. Photo Selection uses the system picker and has no persistent library permission.")
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
    /// What each setting is reset to. Game settings are stored as the raw value of their enum,
    /// so each one must be a real raw value; the tests check this.
    static var defaultValues: [String: Any] {
        [
            "colorSchemePreference": "system",
            "dailyGoalMinutes": 30,
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
            ReaderDisplaySettings.showsPinnedVerseMarkerKey: true,
            "focusReadingEnabled": false,
            "homeCustomizeButtonVisible": true,
            "homeBibleReaderVisible": HomeLayoutStore.defaultBibleReaderVisible,
            HomeLayoutStore.keyBibleReaderColumn: HomeLayoutStore.defaultBibleReaderColumn.rawValue,
            "noteEditorTextSizeStep": 0,
            "notesTabSortField": "modified",
            "notesTabSortAscending": false,
            "bibleBooksSortAlphabetical": false,
            "bibleRecentSearches": "",
            "statsSelectedMode": "Reading Stats",
            "statsSelectedGame": "All Games",
            "debugAutoWinEnabled": false,
            AppStorageKey.beatTheClockCategory: BeatTheClockCategory.people.rawValue,
            AppStorageKey.beatTheClockDifficulty: BeatTheClockDifficulty.normal.rawValue,
            AppStorageKey.hangmanDifficulty: HangmanDifficulty.normal.rawValue,
            AppStorageKey.hangmanTheme: HangmanTheme.all.rawValue,
            "scrambleDifficulty": "normal",
            "quizDifficulty": "normal",
            "quizScope": "whole",
            "quizSections": "",
            AppStorageKey.verseMatchDifficulty: VerseMatchDifficulty.normal.rawValue,
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
            PrayerTimerController.lastMinutesKey: 0,
            PrayerTimerKind.preferenceKey: PrayerTimerKind.prayer.rawValue,
            "prayerTimerActiveKind": PrayerTimerKind.prayer.rawValue,
            "prayerTimerVerseSource": PrayerVerseSource.verseOfDay.rawValue,
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

private struct SettingsNavigationRow: View {
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    var status: String? = nil
    let systemImage: String
    var value: Int? = nil

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let value {
                    Text("\(value) minutes per day", comment: "Daily Goal summary; the value is the configured number of minutes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let status {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
        }
    }
}

struct SettingsAppearanceDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "Appearance") {
            SettingsAppearanceSection()
            SettingsBackgroundSection()
        }
    }
}

struct SettingsBibleReaderDetailView: View {
    let highlightFocusReading: Bool

    init(highlightFocusReading: Bool = false) {
        self.highlightFocusReading = highlightFocusReading
    }

    var body: some View {
        SettingsDetailForm(title: "Bible Reader") {
            SettingsReadingProgressSection(highlightFocusReading: highlightFocusReading)
        }
    }
}

struct SettingsVerseOfTheDayDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "Verse of the Day") {
            SettingsVOTDSection()
        }
    }
}

struct SettingsDailyGoalDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "Daily Goal") {
            SettingsDailyGoalSection()
        }
    }
}

private struct SettingsTimerDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "Prayer & Study Timer") {
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

struct SettingsiCloudDetailView: View {
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
