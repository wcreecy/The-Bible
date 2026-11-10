import SwiftData
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
            SettingsNotificationsAndPermissionsSection()
                .listRowBackground(HeroCardListRowBackground())
            SettingsDataManagementLinksSection()
                .listRowBackground(HeroCardListRowBackground())
            SettingsAboutSection()
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
    @AppStorage(AppStorageKey.contextualTipsEnabled) private var contextualTipsEnabled = false
    @AppStorage(AppStorageKey.contextualTipsResetGeneration) private var contextualTipsResetGeneration = 0
    @State private var homeVisibleCardCount = 0
    @State private var homeHiddenCardCount = 0

    var body: some View {
        Section {
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
                    status: homeLayoutSummary,
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
        } header: {
            Text("App")
        } footer: {
            Text("Tips appear near features such as favorites, reader gestures, verse actions, stats, widgets, timers, Health, and Home customization.")
        }
        .onAppear(perform: updateHomeLayoutSummary)
        .onReceive(NotificationCenter.default.publisher(for: .homeLayoutChanged)) { _ in
            updateHomeLayoutSummary()
        }
    }

    private var homeLayoutSummary: String {
        String(
            localized: "\(homeVisibleCardCount) cards shown · \(homeHiddenCardCount) hidden",
            comment: "Home Layout summary; the values are the number of visible and hidden Home cards."
        )
    }

    private func updateHomeLayoutSummary() {
        let layout = HomeLayoutStore().load()
        homeVisibleCardCount = layout.order.count - layout.hidden.count
        homeHiddenCardCount = layout.hidden.count
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
        case "favorites": "Saved favorite verses"
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
        case "favorites": String(localized: "Saved Favorites")
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
            TranslationSettingsPicker()

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
            .listRowBackground(HeroCardListRowBackground())

            Toggle(isOn: $italicizesSuppliedWords) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Supplied Words in Italics")
                        Text("Italicize words the KJV translators added for clarity (KJV only)")
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

private struct SettingsNotificationsAndPermissionsSection: View {
    @AppStorage(AppStorageKey.verseOfDayRefreshNotificationsEnabled) private var verseNotificationsEnabled = false
    @AppStorage(StreakReminderScheduler.enabledKey) private var streakNotificationsEnabled = false

    var body: some View {
        Section("Notifications & Permissions") {
            NavigationLink {
                SettingsNotificationsDetailView()
            } label: {
                SettingsNavigationRow(
                    title: "Notifications",
                    subtitle: "Verse of the Day, streak reminder, and timer alarms",
                    status: notificationSummary,
                    systemImage: "bell.badge"
                )
            }
            .accessibilityIdentifier("notificationsSettingsLink")

            NavigationLink {
                SettingsPermissionsDetailView()
            } label: {
                SettingsNavigationRow(
                    title: "Permissions",
                    subtitle: "Notifications and photo access",
                    systemImage: "hand.raised"
                )
            }
        }
    }

    private var notificationSummary: String {
        let enabledCount = [verseNotificationsEnabled, streakNotificationsEnabled].filter { $0 }.count
        switch enabledCount {
        case 0: return String(localized: "No reminders enabled")
        case 1: return String(localized: "1 reminder enabled")
        default: return String(localized: "\(enabledCount) reminders enabled")
        }
    }
}

private struct SettingsDataManagementLinksSection: View {
    @Environment(CloudKitManager.self) private var cloudKitManager
    @State private var lastSyncActivity: Date?

    var body: some View {
        Section("Data") {
            NavigationLink {
                SettingsiCloudDetailView()
            } label: {
                SettingsNavigationRow(
                    title: "iCloud Sync",
                    subtitle: iCloudSubtitle,
                    systemImage: "icloud"
                )
            }

            // Last, and neutral: the destructive buttons (and their typed confirmation) are on the detail page.
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

private struct SettingsAboutSection: View {
    var body: some View {
        Section("About") {
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

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("STEPBible and Tyndale House, Cambridge")
                        .font(.headline)
                    Text("The Hebrew and Greek words, Strong’s numbers, and dictionary entries in Word Study come from STEPBible-Data by STEPBible.org and Tyndale House, Cambridge, used under the Creative Commons Attribution 4.0 license. The data was reformatted for this app: punctuation was removed from word endings, long dictionary entries were shortened, and morphology codes were left out.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)

                if let url = URL(string: "https://STEPBible.github.io/STEPBible-Data") {
                    Link(destination: url) {
                        Label("STEPBible-Data", systemImage: "safari")
                    }
                }
            } header: {
                Text("Hebrew and Greek Words")
            }

            Section {
                ForEach(BibleTranslation.available) { translation in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(translation.name) (\(translation.abbreviation))")
                            .font(.headline)
                        Text(translation.notice)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text("Bible Translations")
            } footer: {
                Text("Study content, such as key verses and quotations in chapter insights, quotes the King James Version.")
            }
        }
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
private struct SettingsDeveloperSection: View {
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

private struct SettingsNotificationsDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "Notifications") {
            SettingsNotificationsSection()
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
