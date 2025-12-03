import Foundation
import ActivityKit

@MainActor
final class PrayerTimerActivityController {
    static let shared = PrayerTimerActivityController()
    private init() {}

    private var activity: Activity<PrayerTimerAttributes>?

    // MARK: - Public API

    func start(sessionName: String, totalSeconds: Int, remainingSeconds: Int, isPaused: Bool) {
        guard #available(iOS 16.1, *), ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // Enforce single-activity policy: end all Stopwatch and PrayerTimer activities first
        Self.endAllStopwatchActivities()
        Self.endAllPrayerActivities()

        let attributes = PrayerTimerAttributes(sessionName: sessionName)
        let status = isPaused ? "Paused" : "In progress"
        let shared = UserDefaults(suiteName: "group.bible.app")
        let focus = shared?.string(forKey: "focusTitle")
        let body = shared?.string(forKey: "focusBody")
        let state = PrayerTimerAttributes.ContentState(status: status, remaining: remainingSeconds, total: totalSeconds, focusTitle: focus, focusBody: body)
        do {
            if #available(iOS 17.0, *) {
                let content = ActivityContent(state: state, staleDate: .now.addingTimeInterval(1))
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
                let content = ActivityContent(state: state, staleDate: .now.addingTimeInterval(1))
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
                let content = ActivityContent(state: newState, staleDate: .now.addingTimeInterval(1))
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
        // Enforce single-active: end all Stopwatch and PrayerTimer activities first
        Self.endAllStopwatchActivities()
        Self.endAllPrayerActivities()

        let attributes = PrayerTimerAttributes(sessionName: "Prayer/Study")
        let state = PrayerTimerAttributes.ContentState(status: "Focus", remaining: 0, total: 0, focusTitle: title, focusBody: body)
        do {
            if #available(iOS 17.0, *) {
                let content = ActivityContent(state: state, staleDate: .now.addingTimeInterval(1))
                activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
            } else {
                activity = try Activity.request(attributes: attributes, contentState: state, pushType: nil)
            }
        } catch {
            print("Failed to start Focus Live Activity: \(error)")
        }
    }

    func finish(finalStatus: String = "Finished") {
        guard #available(iOS 16.1, *) else { return }
        // End all PrayerTimer activities to avoid any lingering instances
        Self.endAllPrayerActivities(finalStatus: finalStatus)
        self.activity = nil
    }

    func cancel() {
        guard #available(iOS 16.1, *) else { return }
        // End all PrayerTimer activities immediately
        Self.endAllPrayerActivities()
        self.activity = nil
    }
    
    func ensureFocusIfNone(title: String?, body: String?) {
        guard #available(iOS 16.1, *) else { return }
        // If any activity exists (either type), do nothing
        if !Activity<PrayerTimerAttributes>.activities.isEmpty { return }
        if !Activity<StopwatchAttributes>.activities.isEmpty { return }
        // Otherwise, start a Focus activity with provided title/body
        let attributes = PrayerTimerAttributes(sessionName: "Prayer/Study")
        let state = PrayerTimerAttributes.ContentState(status: "Focus", remaining: 0, total: 0, focusTitle: title, focusBody: body)
        do {
            if #available(iOS 17.0, *) {
                let content = ActivityContent(state: state, staleDate: .now.addingTimeInterval(1))
                self.activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
            } else {
                self.activity = try Activity.request(attributes: attributes, contentState: state, pushType: nil)
            }
        } catch {
            print("Failed to start Focus Live Activity (ensureIfNone): \(error)")
        }
    }

    // MARK: - End-all helpers

    static func endAllPrayerActivities(finalStatus: String? = nil) {
        guard #available(iOS 16.1, *) else { return }
        let activities = Activity<PrayerTimerAttributes>.activities
        guard !activities.isEmpty else { return }

        Task {
            for act in activities {
                if #available(iOS 17.0, *) {
                    let state = act.content.state
                    let finalState = PrayerTimerAttributes.ContentState(
                        status: finalStatus ?? state.status,
                        remaining: finalStatus == nil ? state.remaining : 0,
                        total: finalStatus == nil ? state.total : 0,
                        focusTitle: finalStatus == nil ? state.focusTitle : nil,
                        focusBody: finalStatus == nil ? state.focusBody : nil
                    )
                    let content = ActivityContent(state: finalState, staleDate: nil)
                    await act.end(content, dismissalPolicy: .immediate)
                } else if #available(iOS 16.2, *) {
                    let state = act.contentState
                    let finalState = PrayerTimerAttributes.ContentState(
                        status: finalStatus ?? state.status,
                        remaining: finalStatus == nil ? state.remaining : 0,
                        total: finalStatus == nil ? state.total : 0,
                        focusTitle: finalStatus == nil ? state.focusTitle : nil,
                        focusBody: finalStatus == nil ? state.focusBody : nil
                    )
                    await act.end(using: finalState, dismissalPolicy: .immediate)
                } else {
                    // iOS 16.1: no dismissalPolicy API; end all explicitly
                    let state = act.contentState
                    let finalState = PrayerTimerAttributes.ContentState(
                        status: finalStatus ?? state.status,
                        remaining: finalStatus == nil ? state.remaining : 0,
                        total: finalStatus == nil ? state.total : 0,
                        focusTitle: finalStatus == nil ? state.focusTitle : nil,
                        focusBody: finalStatus == nil ? state.focusBody : nil
                    )
                    await act.end(using: finalState)
                }
            }
        }
    }

    static func endAllStopwatchActivities() {
        guard #available(iOS 16.1, *) else { return }
        let activities = Activity<StopwatchAttributes>.activities
        guard !activities.isEmpty else { return }

        Task {
            for act in activities {
                if #available(iOS 17.0, *) {
                    await act.end(act.content, dismissalPolicy: .immediate)
                } else if #available(iOS 16.2, *) {
                    await act.end(act.content, dismissalPolicy: .immediate)
                } else {
                    // iOS 16.1
                    await act.end()
                }
            }
        }
    }
}

