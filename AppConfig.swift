import Foundation

enum AppGroupID {
    static let identifier = "group.bible.app"
}

enum DefaultsKeys {
    // Verse of Day
    static let verseBook = "verseOfDayBook"
    static let verseChapter = "verseOfDayChapter"
    static let verseNumber = "verseOfDayNumber"
    static let verseText = "verseOfDayText"

    // Prayer Timer
    static let prayerMode = "prayerMode"
    static let prayerTimerPendingAction = "prayerTimerPendingAction"
    static let stopwatchPendingAction = "stopwatchPendingAction"

    // Focus Live Activity
    static let focusTitle = "focusTitle"
    static let focusBody = "focusBody"
}

extension UserDefaults {
    static var appGroup: UserDefaults? { UserDefaults(suiteName: AppGroupID.identifier) }
}
