import SwiftUI
import UserNotifications

struct SettingsAppLinksSection: View {
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
                    subtitle: homeLayoutSummary,
                    systemImage: "rectangle.grid.1x2"
                )
            }

            NavigationLink {
                SettingsLaunchTabDetailView()
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

    private var homeLayoutSummary: LocalizedStringResource {
        LocalizedStringResource(
            "\(homeVisibleCardCount) cards shown · \(homeHiddenCardCount) hidden",
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

struct SettingsReadingAndPrayerLinksSection: View {
    @AppStorage(ReaderDisplaySettings.showsReadProgressKey) private var showsReadProgress = false
    @AppStorage(AppStorageKey.focusReadingEnabled) private var focusReadingEnabled = false
    @AppStorage(AppStorageKey.dailyGoalMinutes) private var dailyGoalMinutes = 30
    @AppStorage(AppStorageKey.verseOfDayScope) private var verseScopeRaw = "whole"
    @AppStorage(AppStorageKey.timerSoundSelection) private var timerSoundSelection = TimerSound.default.rawValue

    var body: some View {
        Section("Reading & Prayer") {
            NavigationLink {
                SettingsBibleReaderDetailView()
            } label: {
                SettingsNavigationRow(
                    title: "Bible Reader",
                    subtitle: bibleReaderSummary,
                    systemImage: "book"
                )
            }

            NavigationLink {
                SettingsDailyGoalDetailView()
            } label: {
                SettingsNavigationRow(
                    title: "Daily Goal",
                    subtitle: LocalizedStringResource(
                        "\(dailyGoalMinutes) minutes of reading per day",
                        comment: "Daily Goal summary; the value is the configured number of reading minutes."
                    ),
                    systemImage: "target"
                )
            }

            NavigationLink {
                SettingsVerseOfTheDayDetailView()
            } label: {
                SettingsNavigationRow(
                    title: "Verse of the Day",
                    subtitle: verseOfTheDaySummary,
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

    private var verseOfTheDaySummary: LocalizedStringResource {
        switch verseScopeRaw {
        case "old": "Old Testament"
        case "new": "New Testament"
        case "book": "A selected book"
        case "favorites": "Saved favorite verses"
        default: "Whole Bible"
        }
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

struct SettingsReadingProgressSection: View {
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
                Text("Choose which bookmark, pinned verse, favorite, note, and Scripture connection icons appear beside each verse reference. Tap a note or Scripture connection icon to open it.")
                Text("Read progress reflects your reading statistics and disappears when they are reset.")
                Text("Printed King James Bibles set supplied words in italics, such as “ye *are* the branches.”")
            }
        }
    }
}

struct SettingsVerseMarkersCard: View {
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
                        Text("Show your bookmark, pinned verse, favorites, notes, and Scripture connections beside each reference")
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

                Toggle("Scripture Connections", isOn: $showsCrossReferenceMarkers)
                    .accessibilityIdentifier("crossReferenceMarkerToggle")
            }
            .padding(.leading, 36)
            .disabled(!showsVerseMarkers)
        }
        .padding(.vertical, 4)
    }
}

struct SettingsNotificationsAndPermissionsSection: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppStorageKey.verseOfDayRefreshNotificationsEnabled) private var verseNotificationsEnabled = false
    @AppStorage(StreakReminderScheduler.enabledKey) private var streakNotificationsEnabled = false
    @State private var notificationsDenied = false
    @State private var timerAlarmsAllowed = false

    var body: some View {
        Section("Notifications & Permissions") {
            NavigationLink {
                SettingsNotificationsDetailView()
            } label: {
                SettingsNavigationRow(
                    title: "Notifications",
                    subtitle: notificationSummary,
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
        .task {
            await updateAccessStatus()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await updateAccessStatus()
            }
        }
    }

    private var notificationSummary: LocalizedStringResource {
        let remindersOn = verseNotificationsEnabled || streakNotificationsEnabled
        // Reminders can't be delivered while notifications are denied, so say that instead of a
        // count. Timer alarms use AlarmKit, which doesn't need notification access.
        if notificationsDenied && remindersOn {
            return "Notifications are off in iOS Settings"
        }
        let enabledCount = [verseNotificationsEnabled, streakNotificationsEnabled, timerAlarmsAllowed]
            .filter { $0 }
            .count
        switch enabledCount {
        case 0: return "No alerts on"
        case 1: return "1 alert on"
        default: return LocalizedStringResource(
            "\(enabledCount) alerts on",
            comment: "Notifications summary; the value is how many of Verse of the Day, streak reminder, and timer alarms are on."
        )
        }
    }

    private func updateAccessStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsDenied = settings.authorizationStatus == .denied
        timerAlarmsAllowed = PrayerTimerAlarmScheduler.authorizationStatus() == .authorized
    }
}

struct SettingsDataManagementLinksSection: View {
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
