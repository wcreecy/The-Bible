import Foundation

/// Stable identifiers for values persisted in `UserDefaults` or the shared app-group defaults.
///
/// Keep these values unchanged once released. Renaming a Swift property is safe; changing its
/// value requires an explicit migration so existing devices and iCloud sync retain their data.
enum AppStorageKey {
    // Appearance and reading
    static let colorSchemePreference = "colorSchemePreference"
    static let fontFamilyPreference = "fontFamilyPreference"
    static let readerFontSize = "readerFontSize"
    static let readerShowsFullReferences = "readerShowsFullReferences"
    static let contextualTipsEnabled = "contextualTipsEnabled"
    static let contextualTipsResetGeneration = "contextualTipsResetGeneration"
    static let focusReadingEnabled = "focusReadingEnabled"
    static let keepScreenOn = "keepScreenOn"
    static let hasSeenFocusModeControlsHint = "hasSeenFocusModeControlsHint"
    static let showsVerseMarkers = "showVerseMarkers"
    static let showsBookmarkMarkers = "showBookmarkMarkers"
    static let showsPinnedVerseMarker = "showPinnedVerseMarker"
    static let showsFavoriteMarkers = "showFavoriteMarkers"
    static let showsNoteMarkers = "showNoteMarkers"
    static let showsCrossReferenceMarkers = "showCrossReferenceMarkers"
    static let showsReadVerseCheckmarks = "showReadVerseCheckmarks"
    /// The active Bible translation's `BibleTranslation` raw value, in the shared app-group
    /// defaults so the widgets show the same translation.
    static let bibleTranslation = "bibleTranslation"

    // Navigation, search, and study
    static let bibleRecentSearches = "bibleRecentSearches"
    static let bibleBooksSortAlphabetical = "bibleBooksSortAlphabetical"
    static let studyBooksSortAlphabetical = "studyBooksSortAlphabetical"
    static let lastStudiedBook = "lastStudiedBook"
    /// Word Study hides articles, conjunctions, and the Hebrew object marker when on.
    static let wordStudyHidesSmallWords = "wordStudyHidesSmallWords"
    static let lastStudiedChapter = "lastStudiedChapter"
    static let bookStoryProgress = "bookStoryProgress"
    static let statsSelectedMode = "statsSelectedMode"
    static let chapterListLayout = "chapterListLayout"
    static let noteEditorTextSizeStep = "noteEditorTextSizeStep"
    static let verseOfDayWidth = "verseOfDayWidth"

    // Reading and saved verses
    static let readerPositionBook = "readerPositionBook"
    static let readerPositionChapter = "readerPositionChapter"
    static let readerPositionVerse = "readerPositionVerse"
    static let lastReadBook = "lastReadBook"
    static let lastReadChapter = "lastReadChapter"
    static let lastReadVerse = "lastReadVerse"
    static let lastReadText = "lastReadText"
    static let bookmarkBook = "bookmarkBook"
    static let bookmarkChapter = "bookmarkChapter"
    static let bookmarkVerse = "bookmarkVerse"
    static let bookmarkText = "bookmarkText"
    static let bookmarkTranslation = "bookmarkTranslation"
    static let pinnedVerseBook = "pinnedVerseBook"
    static let pinnedVerseChapter = "pinnedVerseChapter"
    static let pinnedVerseNumber = "pinnedVerseNumber"
    static let pinnedVerseText = "pinnedVerseText"
    static let pinnedVerseTranslation = "pinnedVerseTranslation"
    static let verseOfDayBook = "verseOfDayBook"
    static let verseOfDayChapter = "verseOfDayChapter"
    static let verseOfDayNumber = "verseOfDayNumber"
    static let verseOfDayText = "verseOfDayText"
    static let pendingVerseOfDayNotification = "pendingVerseOfDayNotification"

    // Focus and activity
    static let focusTitle = "focusTitle"
    static let focusBody = "focusBody"
    static let appActiveStart = "appActiveStart"
    static let appTotalActiveSeconds = "appTotalActiveSeconds"
    static let lastBackgroundedAt = "lastBackgroundedAt"
    static let didCleanupAppTimeKeys = "didCleanupAppTimeKeys"
    static let didCleanupKeepScreenOnKey = "didCleanupKeepScreenOnKey"

    // Settings
    static let dailyGoalMinutes = "dailyGoalMinutes"
    static let verseOfDayScope = "verseOfDayScope"
    static let verseOfDayRefreshFrequency = "votdRefreshFrequency"
    static let verseOfDayRefreshNotificationsEnabled = "votdRefreshNotificationsEnabled"
    static let timerSoundSelection = "timerSoundSelection"
    static let favoritesSortOrder = "favoritesSortOrder"
    static let verseOfDayRefresh1Hour = "votdRefresh1Hour"
    static let verseOfDayRefresh1Minute = "votdRefresh1Minute"
    static let verseOfDayRefresh2Hour = "votdRefresh2Hour"
    static let verseOfDayRefresh2Minute = "votdRefresh2Minute"
    static let verseOfDaySpecificBook = "verseOfDaySpecificBook"
    static let verseOfDayPaused = "verseOfDayPaused"
    static let liveActivitiesEnabled = "liveActivitiesEnabled"
    static let healthKitMindfulMinutesEnabled = "healthKitMindfulMinutesEnabled"
    static let didRequestNotifications = "didRequestNotifications"

    // Games
    static let debugAutoWinEnabled = "debugAutoWinEnabled"
    static let wordleAllowDailyReplay = "wordleAllowDailyReplay"
    static let wordleHardModeEnabled = "wordleHardModeEnabled"
    static let wordleDailyCompletedDay = "wordleDailyCompletedDay"
    static let wordleDailyTarget = "wordleDailyTarget"
    static let wordleDailyProgress = "wordleDailyProgress"
    static let wordlePracticeProgress = "wordlePracticeProgress"
    static let wordleDailyResultMap = "wordleDailyResultMap"
    static let wordlePracticeWordBag = "wordlePracticeWordBag"
    static let wordleLastPracticeWord = "wordleLastPracticeWord"
    static let gameQuestionRecency = "gameQuestionRecency"
    static let bookOrderDifficulty = "bookOrderDifficulty"
    static let bookOrderSource = "bookOrderSource"
    static let bookOrderBookLastSeen = "bookOrderBookLastSeen"
    static let bookOrderSavedPuzzles = "bookOrderSavedPuzzles"
    static let quizDifficulty = "quizDifficulty"
    static let triviaDifficulty = "triviaDifficulty"
    static let quizSections = "quizSections"
    static let quizScope = "quizScope"
    static let beatTheClockDifficulty = "beatTheClockDifficulty"
    static let beatTheClockCategory = "beatTheClockCategory"
    static let hangmanTheme = "hangmanTheme"
    static let hangmanDifficulty = "hangmanDifficulty"
    // Shared Quiz pool; retain the stored key to preserve existing preferences.
    static let quizVersePool = "versematchPool"
    static let gameRecommendationPromptDayV1 = "gameRecommendationPromptDayV1"
    static let gameRecommendationPromptedRoutesV1 = "gameRecommendationPromptedRoutesV1"

    // One-time migrations and maintenance
    static let didMigrateReadingPositionV1 = "didMigrateReadingPositionV1"
    static let didCleanSavedVerseTextV1 = "didCleanSavedVerseTextV1"
    static let didKeepPreviousReaderDefaultsV1 = "didKeepPreviousReaderDefaultsV1"

    // Reading statistics
    static let bookReadingTimes = "bookReadingTimes"
    static let dailyReadingTimes = "dailyReadingTimes"
    static let dailyReadingTimesByBook = "dailyReadingTimesByBook"
    static let visitedChapters = "visitedChapters"
    static let lastReadEntry = "lastReadEntry"
    static let seenVersesByChapter = "seenVersesByChapter"
    static let chapterCompletionDates = "chapterCompletionDates"
    static let readingTimeContributionsV2 = "readingTimeContributionsV2"
    static let chapterResetDates = "chapterResetDates"
    static let seenVersesUpdatedAt = "seenVersesUpdatedAt"
    static let readingHistoryArchiveV1 = "readingHistoryArchiveV1"
    static let didMigrateDailyKeysToLocal = "didMigrateDailyKeysToLocal"

    // Today challenges
    static let todayChallengesSnapshotV1 = "todayChallengesSnapshotV1"
    static let todayChallengesSnapshotV2 = "todayChallengesSnapshotV2"
    static let todayChallengesHistoryV1 = "todayChallengesHistoryV1"

    // Statistics ledger
    static let gameStatsLedgerOwnPayloadV1 = "gameStatsLedgerOwnPayload_v1"
    static let gameStatsLedgerOwnInstallationV1 = "gameStatsLedgerOwnInstallation_v1"
    static let gameStatsLedgerSnapshotV1 = "gameStatsLedgerSnapshot_v1"
    /// When this device last saw each other installation's game ledger change.
    static let gameStatsLedgerActivityV1 = "gameStatsLedgerActivity_v1"
    static let gameStatsResetEpoch = "gameStatsResetEpoch"
    static let gameStatsLastSeenResetEpoch = "gameStatsLastSeenResetEpoch"
    static let gameStatsLedgerInstallationID = "gameStatsLedgerInstallationID"
    static let gameStatsLedgerInstallationVendorID = "gameStatsLedgerInstallationVendorID"

    // Home
    static let homeCardOrder = "homeCardOrder"
    static let homeQuickSearchVisible = "homeQuickSearchVisible"
    static let homeCustomizeButtonVisible = "homeCustomizeButtonVisible"
    static let homeSavedVersePinID = "homeSavedVersePinID"
    static let homeSavedVersePinDay = "homeSavedVersePinDay"
    static let streakCelebratedMilestone = "streakCelebratedMilestone"
    static let readingPlansNewTipDismissed = "readingPlansNewTipDismissed"
    static let focusLiveActivitiesHintDismissed = "focusLiveActivitiesHintDismissed"

    // Notes
    static let notesTabSortField = "notesTabSortField"
    static let notesTabSortAscending = "notesTabSortAscending"
    static let notesTabListColumnFraction = "notesTabListColumnFraction"

    // Stats
    static let statsSelectedGame = "statsSelectedGame"
    static let prayerStatsSelectedKind = "prayerStatsSelectedKind"

    // Prayer & Study Timer
    static let prayerTimerActiveKind = "prayerTimerActiveKind"
    static let prayerTimerRunning = "prayerTimerRunning"
    static let prayerTimerPaused = "prayerTimerPaused"
    static let prayerTimerStartDate = "prayerTimerStartDate"
    static let prayerTimerEndDate = "prayerTimerEndDate"
    static let prayerTimerTotalSeconds = "prayerTimerTotalSeconds"
    static let prayerTimerRemainingWhenPaused = "prayerTimerRemainingWhenPaused"
    static let prayerTimerVerseSource = "prayerTimerVerseSource"
    static let prayerSessionSeconds = "prayerSessionSeconds"
    static let prayerSegmentStartDate = "prayerSegmentStartDate"

    // Debug
    static let debugForcedStoreMode = "debugForcedStoreMode"
}
