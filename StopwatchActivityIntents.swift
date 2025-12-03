import AppIntents
import ActivityKit
import Foundation

@available(iOS 16.0, *)
struct PauseStopwatchIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause Stopwatch"
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let activity = Self.currentActivity() else {
            return .result()
        }

        if #available(iOS 17.0, *) {
            let current = activity.content.state
            let updatedState = StopwatchAttributes.ContentState(
                status: "Paused",
                elapsed: current.elapsed
            )
            let updatedContent = ActivityContent(state: updatedState, staleDate: nil)
            await activity.update(updatedContent)
        } else {
            let current = activity.contentState
            let updatedContent = StopwatchAttributes.ContentState(
                status: "Paused",
                elapsed: current.elapsed
            )
            await activity.update(using: updatedContent)
        }
        return .result()
    }
    
    @MainActor
    private static func currentActivity() -> Activity<StopwatchAttributes>? {
        Activity<StopwatchAttributes>.activities.first
    }
}

@available(iOS 16.0, *)
struct ResumeStopwatchIntent: AppIntent {
    static var title: LocalizedStringResource = "Resume Stopwatch"
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let activity = Self.currentActivity() else {
            return .result()
        }

        if #available(iOS 17.0, *) {
            let current = activity.content.state
            let updatedState = StopwatchAttributes.ContentState(
                status: "Running",
                elapsed: current.elapsed
            )
            let updatedContent = ActivityContent(state: updatedState, staleDate: nil)
            await activity.update(updatedContent)
        } else {
            let current = activity.contentState
            let updatedContent = StopwatchAttributes.ContentState(
                status: "Running",
                elapsed: current.elapsed
            )
            await activity.update(using: updatedContent)
        }
        return .result()
    }
    
    @MainActor
    private static func currentActivity() -> Activity<StopwatchAttributes>? {
        Activity<StopwatchAttributes>.activities.first
    }
}

@available(iOS 16.0, *)
struct StopStopwatchIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Stopwatch"
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        // End ALL stopwatch activities to ensure immediate dismissal across versions
        await Self.endAllStopwatchActivitiesViaIntent()
        return .result()
    }
    
    @MainActor
    private static func currentActivity() -> Activity<StopwatchAttributes>? {
        Activity<StopwatchAttributes>.activities.first
    }

    @MainActor
    private static func endAllStopwatchActivitiesViaIntent() async {
        guard #available(iOS 16.1, *) else { return }
        let activities = Activity<StopwatchAttributes>.activities
        for activity in activities {
            if #available(iOS 17.0, *) {
                let finalState = StopwatchAttributes.ContentState(status: "Stopped", elapsed: 0)
                let finalContent = ActivityContent(state: finalState, staleDate: nil)
                await activity.end(finalContent, dismissalPolicy: .immediate)
            } else if #available(iOS 16.2, *) {
                let finalState = StopwatchAttributes.ContentState(status: "Stopped", elapsed: 0)
                await activity.end(using: finalState, dismissalPolicy: .immediate)
            } else {
                // iOS 16.1: no dismissalPolicy; still end all explicitly
                let finalState = StopwatchAttributes.ContentState(status: "Stopped", elapsed: 0)
                await activity.end(using: finalState)
            }
        }
    }
}

