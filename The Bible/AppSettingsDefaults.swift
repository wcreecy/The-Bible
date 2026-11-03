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
            AppStorageKey.readerShowsFullReferences: true,
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
            "statsSelectedMode": "Reading Stats",
            "statsSelectedGame": "All Games",
            AppStorageKey.beatTheClockCategory: BeatTheClockCategory.people.rawValue,
            AppStorageKey.beatTheClockDifficulty: BeatTheClockDifficulty.normal.rawValue,
            AppStorageKey.hangmanDifficulty: HangmanDifficulty.normal.rawValue,
            AppStorageKey.hangmanTheme: HangmanTheme.all.rawValue,
            "scrambleDifficulty": "normal",
            "crosswordDifficulty": "normal",
            "quizDifficulty": "normal",
            "quizScope": "whole",
            "quizSections": "",
            "wordleAllowDailyReplay": false,
            "wordleHardModeEnabled": false,
            PrayerTimerKind.preferenceKey: PrayerTimerKind.prayer.rawValue,
            "prayerTimerVerseSource": PrayerVerseSource.verseOfDay.rawValue,
        ]
    }

    static func register(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: preferences)
    }
}
