import AppIntents
import Foundation

// Shared by the app and the widget extension: the app runs these intents, and the
// Live Activity buttons in the widget extension refer to them.

// MARK: - Live Activity controls

/// Connects the Live Activity buttons to the app's prayer timer. The app registers the
/// handler at launch; it stays nil in the widget extension, where the saved action is
/// instead picked up the next time the app becomes active.
@MainActor
enum PrayerTimerIntentBridge {
    static var handlePendingAction: (() -> Void)?

    /// Saves the command for the shared controller, then applies it right away when this
    /// code is running inside the app (Live Activity intents run there, even when the app
    /// is closed).
    static func send(_ action: String) {
        if let shared = UserDefaults(suiteName: "group.bible.app") {
            shared.set(action, forKey: "prayerTimerPendingAction")
            shared.set(UUID().uuidString, forKey: "prayerTimerActionToken")
        }
        handlePendingAction?()
    }
}

// LiveActivityIntent makes the system run `perform()` in the app's process without
// bringing the app to the foreground. The app owns the timer's persisted end date, Health
// session, and prayer stats, so the shared controller applies each command exactly once.
@available(iOS 17.0, *)
struct PrayerTimerTogglePauseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause/Resume Prayer Timer"
    func perform() async throws -> some IntentResult {
        await PrayerTimerIntentBridge.send("togglePause")
        return .result()
    }
}

@available(iOS 17.0, *)
struct PrayerTimerAddFiveMinutesIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "+5 Minutes"
    func perform() async throws -> some IntentResult {
        await PrayerTimerIntentBridge.send("add5")
        return .result()
    }
}

@available(iOS 17.0, *)
struct PrayerTimerStopIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Prayer Timer"
    func perform() async throws -> some IntentResult {
        await PrayerTimerIntentBridge.send("stop")
        return .result()
    }
}
