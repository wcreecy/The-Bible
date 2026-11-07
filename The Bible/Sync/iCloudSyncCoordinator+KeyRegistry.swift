import Foundation

// MARK: - Key sets (union)

extension iCloudSyncCoordinator {
    /// Every key this coordinator syncs. The lists are fixed, so the set is built once.
    var allKnownKeys: Set<String> { Self.allKnownKeySet }

    private static let allKnownKeySet: Set<String> = {
        Set(
            bibleStatsKeys
            + sessionKeys
            + prayerStatsKeys
            + missedQuestionKeys
            + settingsKeys
            + gamePlayTimeCounterKeys
            + gamePlayTimeMapKeys
            + hangmanKeys
            + beatClockKeys
            + refMatchKeys
            + verseMatchKeys
            + quizKeys
            + quizPerBookMapKeys
            + quizPerBookDailyMapKeys
            + verseMatchPerBookDailyMapKeys
            + verseMatchPerBookMapKeys
            + hangmanPerCategoryMapKeys
            + beatClockPerTypeMapKeys
            + bookOrderKeys
            + whoAmIKeys
            + wordleKeys
            + wordSearchKeys
            + gameDailyAndLastPlayedKeys
            + wordleSolvedMapKeys
            + wordleDailyResultKeys
            + wordleDailyFlagKeys
            + perGameDailyMapKeys
            + allPersistentStreakKeys
        )
    }()
}

// MARK: - Last Read widget keys
// The widget copy is written by ReadingPositionStore; resets also clear values older
// versions wrote directly to iCloud.
extension iCloudSyncCoordinator {
    static let lastReadWidgetKeys: Set<String> = [
        "lastReadBook",
        "lastReadChapter",
        "lastReadVerse",
        "lastReadText"
    ]
}
