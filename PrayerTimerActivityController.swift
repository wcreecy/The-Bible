import Foundation
import ActivityKit

@MainActor
final class PrayerTimerActivityController {
    static let shared = PrayerTimerActivityController()
    private init() {}

    private var activity: Activity<PrayerTimerAttributes>?

    func start(sessionName: String, totalSeconds: Int, remainingSeconds: Int, isPaused: Bool) {
        guard #available(iOS 16.1, *), ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        self.cancel()
        let attributes = PrayerTimerAttributes(sessionName: sessionName)
        let status = isPaused ? "Paused" : "In progress"
        let shared = UserDefaults(suiteName: "group.bible.app")
        let focus = shared?.string(forKey: "focusTitle")
        let body = shared?.string(forKey: "focusBody")
        let state = PrayerTimerAttributes.ContentState(status: status, remaining: remainingSeconds, total: totalSeconds, focusTitle: focus, focusBody: body)
        do {
            if #available(iOS 17.0, *) {
                let content = ActivityContent(state: state, staleDate: nil)
                activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
            } else {
                activity = try Activity.request(attributes: attributes, contentState: state, pushType: nil)
            }
        } catch {
            print("Failed to start PrayerTimer Live Activity: \(error)")
        }
    }

    func update(remainingSeconds: Int, totalSeconds: Int, isPaused: Bool) {
        guard #available(iOS 16.1, *), let activity else { return }
        let status = isPaused ? "Paused" : "In progress"
        let shared = UserDefaults(suiteName: "group.bible.app")
        let focus = shared?.string(forKey: "focusTitle")
        let body = shared?.string(forKey: "focusBody")
        let state = PrayerTimerAttributes.ContentState(status: status, remaining: remainingSeconds, total: totalSeconds, focusTitle: focus, focusBody: body)
        Task {
            if #available(iOS 17.0, *) {
                let content = ActivityContent(state: state, staleDate: nil)
                await activity.update(content)
            } else {
                await activity.update(using: state)
            }
        }
    }
    
    func updateFocus(title: String?, body: String?) {
        guard #available(iOS 16.1, *), let activity else { return }
        Task {
            if #available(iOS 17.0, *) {
                let current = activity.content.state
                let newState = PrayerTimerAttributes.ContentState(
                    status: current.status,
                    remaining: current.remaining,
                    total: current.total,
                    focusTitle: title,
                    focusBody: body
                )
                let content = ActivityContent(state: newState, staleDate: nil)
                await activity.update(content)
            } else {
                let current = activity.contentState
                let newState = PrayerTimerAttributes.ContentState(
                    status: current.status,
                    remaining: current.remaining,
                    total: current.total,
                    focusTitle: title,
                    focusBody: body
                )
                await activity.update(using: newState)
            }
        }
    }

    func ensureActivityForFocus(title: String?, body: String?) {
        guard #available(iOS 16.1, *) else { return }
        // Enforce single-active: stop other activities
        self.cancel()
        let attributes = PrayerTimerAttributes(sessionName: "Prayer/Study")
        let state = PrayerTimerAttributes.ContentState(status: "Focus", remaining: 0, total: 0, focusTitle: title, focusBody: body)
        do {
            if #available(iOS 17.0, *) {
                let content = ActivityContent(state: state, staleDate: nil)
                activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
            } else {
                activity = try Activity.request(attributes: attributes, contentState: state, pushType: nil)
            }
        } catch {
            print("Failed to start Focus Live Activity: \(error)")
        }
    }

    func finish(finalStatus: String = "Finished") {
        guard #available(iOS 16.1, *), let activity else { return }
        let final = PrayerTimerAttributes.ContentState(status: finalStatus, remaining: 0, total: 0, focusTitle: nil, focusBody: nil)
        Task {
            if #available(iOS 17.0, *) {
                let content = ActivityContent(state: final, staleDate: nil)
                await activity.end(content, dismissalPolicy: ActivityUIDismissalPolicy.immediate)
            } else {
                await activity.end(using: final, dismissalPolicy: ActivityUIDismissalPolicy.immediate)
            }
        }
        self.activity = nil
    }

    func cancel() {
        guard #available(iOS 16.1, *), let activity else { return }
        Task {
            await activity.end(dismissalPolicy: ActivityUIDismissalPolicy.immediate)
        }
        self.activity = nil
    }
}
