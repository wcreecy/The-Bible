import Foundation
import ActivityKit

// Shared attributes for the Prayer/Study timer Live Activity
struct PrayerTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var status: String // e.g., "In progress", "Paused", "Finished"
        var remaining: Int // seconds remaining
        var total: Int // total seconds
        var focusTitle: String? // optional focus title to show in Dynamic Island
        var focusBody: String? // optional focus body to show in expanded views
    }
    var sessionName: String // e.g., "Prayer/Study"
}

