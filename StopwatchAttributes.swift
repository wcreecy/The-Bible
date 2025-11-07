import Foundation
import ActivityKit

struct StopwatchAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var status: String // "Running" or "Paused"
        var elapsed: Int   // seconds elapsed
    }
    var sessionName: String // e.g., "Stopwatch"
}
