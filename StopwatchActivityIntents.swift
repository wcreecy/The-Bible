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
        guard let activity = Self.currentActivity() else {
            return .result()
        }

        if #available(iOS 17.0, *) {
            let finalState = StopwatchAttributes.ContentState(
                status: "Stopped",
                elapsed: 0
            )
            let finalContent = ActivityContent(state: finalState, staleDate: nil)
            await activity.end(finalContent, dismissalPolicy: .immediate)
        } else {
            let finalContent = StopwatchAttributes.ContentState(
                status: "Stopped",
                elapsed: 0
            )
            await activity.end(using: finalContent)
        }
        return .result()
    }
    
    @MainActor
    private static func currentActivity() -> Activity<StopwatchAttributes>? {
        Activity<StopwatchAttributes>.activities.first
    }
}
