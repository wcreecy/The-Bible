import Foundation
import ActivityKit

@MainActor
final class StopwatchActivityController {
    static let shared = StopwatchActivityController()
    private init() {}

    private var activity: Activity<StopwatchAttributes>?

    func start(sessionName: String = "Stopwatch", initialElapsed: Int = 0) {
        guard #available(iOS 16.1, *), ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = StopwatchAttributes(sessionName: sessionName)
        let state = StopwatchAttributes.ContentState(status: "Running", elapsed: initialElapsed)
        do {
            if #available(iOS 17.0, *) {
                let content = ActivityContent(state: state, staleDate: nil)
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
            if #available(iOS 17.0, *) {
                let content = ActivityContent(state: state, staleDate: nil)
                await activity.update(content)
            } else {
                await activity.update(using: state)
            }
        }
    }

    func finish(finalStatus: String = "Stopped") {
        guard #available(iOS 16.1, *), let activity else { return }
        let final = StopwatchAttributes.ContentState(status: finalStatus, elapsed: 0)
        Task {
            if #available(iOS 17.0, *) {
                let content = ActivityContent(state: final, staleDate: nil)
                await activity.end(content, dismissalPolicy: .immediate)
            } else {
                await activity.end(using: final, dismissalPolicy: .immediate)
            }
        }
        self.activity = nil
    }

    func cancel() {
        guard #available(iOS 16.1, *), let activity else { return }
        Task { await activity.end(dismissalPolicy: .immediate) }
        self.activity = nil
    }
}
