import Foundation
#if canImport(AppIntents)
import AppIntents

// Shared App Group key to communicate an action back to the app
private let prayerTimerActionKey = "prayerTimerPendingAction"
private let appGroupSuite = "group.bible.app"

@available(iOS 17.0, *)
struct PauseOrResumePrayerTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause/Resume Prayer Timer"
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        let shared = UserDefaults(suiteName: appGroupSuite)
        shared?.set("togglePause", forKey: prayerTimerActionKey)
        return .result()
    }
}

@available(iOS 17.0, *)
struct StopPrayerTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Prayer Timer"
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        let shared = UserDefaults(suiteName: appGroupSuite)
        shared?.set("stop", forKey: prayerTimerActionKey)
        return .result()
    }
}

@available(iOS 17.0, *)
struct AddFiveMinutesPrayerTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "+5 Minutes"
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        let shared = UserDefaults(suiteName: appGroupSuite)
        shared?.set("add5", forKey: prayerTimerActionKey)
        return .result()
    }
}

#endif
