import Foundation
import ActivityKit

@MainActor
final class StopwatchActivityController {
    static let shared = StopwatchActivityController()
    private init() {}

    private var activity: Activity<StopwatchAttributes>?

    func start(sessionName: String = "Stopwatch", initialElapsed: Int = 0) {
        guard #available(iOS 16.1, *), ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // Enforce single-activity policy: end all PrayerTimer and Stopwatch activities first
        Self.endAllPrayerActivities()
        Self.endAllStopwatchActivities()

        let attributes = StopwatchAttributes(sessionName: sessionName)
        let state = StopwatchAttributes.ContentState(status: "Running", elapsed: initialElapsed)
        do {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: state, staleDate: .now.addingTimeInterval(60))
                activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
            } else {
                activity = try Activity.request(attributes: attributes, contentState: state, pushType: nil)
            }
        } catch {
            print("Failed to start Stopwatch Live Activity: \(error)")
        }
    }

    func update(elapsed: Int, isRunning: Bool) {
        guard #available(iOS 16.1, *), let activity else { return }
        let status = isRunning ? "Running" : "Paused"
        let state = StopwatchAttributes.ContentState(status: status, elapsed: elapsed)
        Task {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: state, staleDate: .now.addingTimeInterval(60))
                await activity.update(content)
            } else {
                await activity.update(using: state)
            }
        }
    }

    func finish(finalStatus: String = "Stopped") {
        guard #available(iOS 16.1, *) else { return }
        // End all Stopwatch activities to avoid any lingering instances
        Self.endAllStopwatchActivities(finalStatus: finalStatus)
        self.activity = nil
    }

    func cancel() {
        guard #available(iOS 16.1, *) else { return }
        // End all Stopwatch activities immediately
        Self.endAllStopwatchActivities()
        self.activity = nil
    }

    // MARK: - End-all helpers

    static func endAllStopwatchActivities(finalStatus: String? = nil) {
        guard #available(iOS 16.1, *) else { return }
        let activities = Activity<StopwatchAttributes>.activities
        guard !activities.isEmpty else { return }

        Task {
            for act in activities {
                if #available(iOS 17.0, *) {
                    let current = act.content.state
                    let final = StopwatchAttributes.ContentState(
                        status: finalStatus ?? current.status,
                        elapsed: finalStatus == nil ? current.elapsed : 0
                    )
                    let content = ActivityContent(state: final, staleDate: nil)
                    await act.end(content, dismissalPolicy: .immediate)
                } else {
                    // iOS 16.x
                    let current = act.contentState
                    let final = StopwatchAttributes.ContentState(
                        status: finalStatus ?? current.status,
                        elapsed: finalStatus == nil ? current.elapsed : 0
                    )
                    // On iOS 16.x, always use the basic end(using:) to avoid redundant availability checks
                    await act.end(using: final)
                }
            }
        }
    }

    static func endAllPrayerActivities() {
        guard #available(iOS 16.1, *) else { return }
        let activities = Activity<PrayerTimerAttributes>.activities
        guard !activities.isEmpty else { return }

        Task {
            for act in activities {
                if #available(iOS 17.0, *) {
                    let content = ActivityContent(state: act.content.state, staleDate: nil)
                    await act.end(content, dismissalPolicy: .immediate)
                } else {
                    // iOS 16.x
                    let state = act.contentState
                    // On iOS 16.x, always use the basic end(using:) to avoid redundant availability checks
                    await act.end(using: state)
                }
            }
        }
    }
}
