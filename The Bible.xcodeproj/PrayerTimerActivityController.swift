import Foundation
import ActivityKit

@MainActor
final class PrayerTimerActivityController {
    static let shared = PrayerTimerActivityController()
    private init() {}

    private var activity: Activity<PrayerTimerAttributes>?

    func start(sessionName: String, totalSeconds: Int, remainingSeconds: Int, isPaused: Bool) {
        guard #available(iOS 16.1, *), ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = PrayerTimerAttributes(sessionName: sessionName)
        let status = isPaused ? "Paused" : "In progress"
        let state = PrayerTimerAttributes.ContentState(status: status, remaining: remainingSeconds, total: totalSeconds)
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
        let state = PrayerTimerAttributes.ContentState(status: status, remaining: remainingSeconds, total: totalSeconds)
        Task {
            if #available(iOS 17.0, *) {
                let content = ActivityContent(state: state, staleDate: nil)
                await activity.update(content)
            } else {
                await activity.update(using: state)
            }
        }
    }

    func finish(finalStatus: String = "Finished") {
        guard #available(iOS 16.1, *), let activity else { return }
        let final = PrayerTimerAttributes.ContentState(status: finalStatus, remaining: 0, total: 0)
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
        Task {
            await activity.end(dismissalPolicy: .immediate)
        }
        self.activity = nil
    }
}
