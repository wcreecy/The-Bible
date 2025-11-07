//
//  LiveActivityManager.swift
//  The Bible (iOS)
//
//  Created by William Creecy on 11/7/25.
//

import Foundation
import ActivityKit

// MARK: - Activity Attributes
struct BibleActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String            // e.g., "Verse of the Day"
        var reference: String        // e.g., "John 3:16"
        var snippet: String          // e.g., "For God so loved the world..."
        var progress: Double?        // Optional reading progress (0.0...1.0)
        var lastUpdated: Date
    }

    // Static properties that don't change during the activity lifetime
    var context: String // e.g., "Daily Devotional", "Reading Plan"
}

// MARK: - Live Activity Manager
@MainActor
final class LiveActivityManager {

    static let shared = LiveActivityManager()

    private init() {}

    // Store active activities by an app-defined id
    private var activeActivities: [String: Activity<BibleActivityAttributes>] = [:]

    // MARK: - Capability Checks
    var isLiveActivitiesAvailable: Bool {
        if #available(iOS 16.1, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        } else {
            return false
        }
    }

    // MARK: - Start
    /// Starts a new Live Activity and stores it under the provided identifier.
    func startActivity(
        id: String,
        context: String,
        initial: BibleActivityAttributes.ContentState
    ) async -> Activity<BibleActivityAttributes>? {
        guard isLiveActivitiesAvailable else {
            print("Live Activities are not available or not authorized.")
            return nil
        }
        guard #available(iOS 16.1, *) else { return nil }

        let attributes = BibleActivityAttributes(context: context)

        do {
            let activity: Activity<BibleActivityAttributes>
            if #available(iOS 17.0, *) {
                let content = ActivityContent(state: initial, staleDate: nil)
                activity = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
            } else {
                activity = try Activity.request(
                    attributes: attributes,
                    contentState: initial,
                    pushType: nil
                )
            }
            activeActivities[id] = activity
            return activity
        } catch {
            print("Failed to start Live Activity: \(error)")
            return nil
        }
    }

    // MARK: - Update
    func updateActivity(
        id: String,
        newState: BibleActivityAttributes.ContentState
    ) async {
        guard #available(iOS 16.1, *) else { return }
        guard let activity = activeActivities[id] else {
            print("No active Live Activity found for id '\(id)'")
            return
        }

        if #available(iOS 17.0, *) {
            let content = ActivityContent(state: newState, staleDate: nil)
            await activity.update(content)
        } else {
            await activity.update(using: newState)
        }
    }

    /// Convenience helper
    func updateVerseOfTheDay(
        id: String,
        title: String,
        reference: String,
        snippet: String,
        progress: Double? = nil
    ) async {
        let state = BibleActivityAttributes.ContentState(
            title: title,
            reference: reference,
            snippet: snippet,
            progress: progress,
            lastUpdated: Date()
        )
        await updateActivity(id: id, newState: state)
    }

    // MARK: - End
    func endActivity(
        id: String,
        finalState: BibleActivityAttributes.ContentState? = nil,
        dismissalPolicy: ActivityUIDismissalPolicy = .immediate
    ) async {
        guard #available(iOS 16.1, *) else { return }
        guard let activity = activeActivities[id] else { return }

        if let finalState {
            if #available(iOS 17.0, *) {
                let content = ActivityContent(state: finalState, staleDate: nil)
                await activity.end(content, dismissalPolicy: dismissalPolicy)
            } else {
                await activity.end(using: finalState, dismissalPolicy: dismissalPolicy)
            }
        } else {
            await activity.end(dismissalPolicy: dismissalPolicy)
        }

        activeActivities.removeValue(forKey: id)
    }

    /// Ends all active activities managed by this instance.
    func endAllActivities(
        finalStateBuilder: ((String) -> BibleActivityAttributes.ContentState)? = nil,
        dismissalPolicy: ActivityUIDismissalPolicy = .immediate
    ) async {
        guard #available(iOS 16.1, *) else { return }
        for (id, activity) in activeActivities {
            if let finalStateBuilder = finalStateBuilder {
                let finalState = finalStateBuilder(id)
                if #available(iOS 17.0, *) {
                    let content = ActivityContent(state: finalState, staleDate: nil)
                    await activity.end(content, dismissalPolicy: dismissalPolicy)
                } else {
                    await activity.end(using: finalState, dismissalPolicy: dismissalPolicy)
                }
            } else {
                await activity.end(dismissalPolicy: dismissalPolicy)
            }
        }
        activeActivities.removeAll()
    }

    // MARK: - Recovery
    /// Call this on app launch/foreground to recover system-tracked activities.
    func reloadSystemActivities() {
        guard #available(iOS 16.1, *) else { return }
        let current = Activity<BibleActivityAttributes>.activities
        var newMap: [String: Activity<BibleActivityAttributes>] = [:]
        for activity in current {
            newMap[activity.id] = activity
        }
        activeActivities = newMap
    }
}
