import Foundation

/// The default for every app preference, in one place. Registered at launch, so these win over
/// the inline default on any `@AppStorage` or plain `UserDefaults` read of the same key, and
/// the debug "Reset Permissions & Settings" restores them.
///
/// Game settings are stored as the raw value of their enum, so each must be a real raw value;
/// `DeveloperSettingsResetTests` checks this.
enum AppSettingsDefaults {
    static var preferences: [String: Any] {
        [
            "colorSchemePreference": "system",
            AppShare.includesLinkKey: true,
            "dailyGoalMinutes": 30,
            StreakReminderScheduler.enabledKey: false,
            StreakReminderScheduler.hourKey: StreakReminderScheduler.defaultHour,
            StreakReminderScheduler.minuteKey: 0,
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
            AppStorageKey.contextualTipsEnabled: true,
            "readerFontSize": 17.0,
            // Verse rows start quiet: a short "Verse 1" label, with only the note and Scripture
            // connection icons, which open something when tapped. Installs from before this
            // keep their previous look (see `keepPreviousReaderDefaultsIfNeeded`).
            AppStorageKey.readerShowsFullReferences: false,
            ReaderDisplaySettings.showsReadProgressKey: false,
            ReaderDisplaySettings.showsVerseMarkersKey: true,
            ReaderDisplaySettings.showsNoteMarkersKey: true,
            ReaderDisplaySettings.showsCrossReferenceMarkersKey: true,
            ReaderDisplaySettings.showsBookmarkMarkersKey: false,
            ReaderDisplaySettings.showsFavoriteMarkersKey: false,
            ReaderDisplaySettings.showsPinnedVerseMarkerKey: false,
            "focusReadingEnabled": false,
            "homeCustomizeButtonVisible": true,
            "noteEditorTextSizeStep": 0,
            "notesTabSortField": "modified",
            "notesTabSortAscending": false,
            "bibleBooksSortAlphabetical": false,
            "statsSelectedMode": "Reading Stats",
            "statsSelectedGame": "All Games",
            AppStorageKey.beatTheClockCategory: BeatTheClockCategory.people.rawValue,
            AppStorageKey.beatTheClockDifficulty: BeatTheClockDifficulty.normal.rawValue,
            AppStorageKey.beatTheClockMode: BeatTheClockMode.classic.rawValue,
            AppStorageKey.whoAmIMode: WhoAmIGameViewModel.Mode.clueToName.rawValue,
            AppStorageKey.bookOrderMode: BookOrderMode.tapInOrder.rawValue,
            AppStorageKey.whoAmIDifficulty: WhoAmIGameViewModel.Difficulty.normal.rawValue,
            AppStorageKey.hangmanDifficulty: HangmanDifficulty.normal.rawValue,
            AppStorageKey.hangmanTheme: HangmanTheme.all.rawValue,
            "scrambleDifficulty": "normal",
            "crosswordDifficulty": "normal",
            // Both start off.
            "crosswordShowsMistakesAsYouType": false,
            "crosswordShowsVerseAfterAnswer": false,
            "quizDifficulty": "normal",
            AppStorageKey.triviaDifficulty: BibleTriviaDifficulty.normal.rawValue,
            AppStorageKey.triviaTopic: BibleTriviaTopic.mixed.rawValue,
            "quizScope": "whole",
            "quizSections": "",
            "wordleAllowDailyReplay": false,
            "wordleHardModeEnabled": false,
            PrayerTimerKind.preferenceKey: PrayerTimerKind.prayer.rawValue,
            "prayerTimerVerseSource": PrayerVerseSource.verseOfDay.rawValue,
        ]
    }

    /// `domainName` is where `defaults` stores its values: the app's bundle identifier for
    /// `.standard`, or the suite name for a suite.
    static func register(
        in defaults: UserDefaults = .standard,
        domainName: String? = Bundle.main.bundleIdentifier
    ) {
        keepPreviousReaderDefaultsIfNeeded(in: defaults, domainName: domainName)
        defaults.register(defaults: preferences)
    }

    /// The reader's verse row defaults before they were made quieter. Registered defaults
    /// apply to anyone who never changed a setting, so without this, existing readers would
    /// see their verse rows change too.
    static let previousReaderDefaults: [String: Bool] = [
        AppStorageKey.readerShowsFullReferences: true,
        ReaderDisplaySettings.showsBookmarkMarkersKey: true,
        ReaderDisplaySettings.showsFavoriteMarkersKey: true,
        ReaderDisplaySettings.showsPinnedVerseMarkerKey: true
    ]

    /// Once, on an install that has opened the app before, saves the previous verse row
    /// defaults for any setting the person never changed, so only new installs get the
    /// quieter defaults. Only values stored on the device count as a choice; registered
    /// defaults are shared by the whole process, so they're ignored.
    static func keepPreviousReaderDefaultsIfNeeded(in defaults: UserDefaults, domainName: String?) {
        guard !defaults.bool(forKey: AppStorageKey.didKeepPreviousReaderDefaultsV1) else { return }
        defaults.set(true, forKey: AppStorageKey.didKeepPreviousReaderDefaultsV1)

        // Set the first time the app opens, so a new install hasn't set it yet.
        guard defaults.bool(forKey: AppStorageKey.didCleanupAppTimeKeys) else { return }
        let stored = domainName.flatMap(defaults.persistentDomain(forName:)) ?? [:]
        for (key, value) in previousReaderDefaults where stored[key] == nil {
            defaults.set(value, forKey: key)
        }
    }
}
