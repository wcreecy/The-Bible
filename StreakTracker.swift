import Foundation

/// Tracks a daily streak based on meeting the daily time goal from Bible reading only.
/// A day counts only when the user meets their Daily Goal minutes (Settings),
/// computed from BibleStatsStore's daily reading totals (i.e., time spent in the Bible tab).
enum StreakTracker {
    // Legacy keys kept only for backward compatibility (no longer used for computation)
    private static let lastVisitKey = "bibleStreak_lastVisit"
    private static let currentStreakKey = "bibleStreak_current"
    private static let bestStreakKey = "bibleStreak_best"

    private static var defaults: UserDefaults { .standard }
    private static var calendar: Calendar { Calendar.current }

    // MARK: - Settings

    /// Returns the daily goal in seconds from Settings (defaults to 30 minutes if unset).
    private static var dailyGoalSeconds: Int {
        let mins = defaults.integer(forKey: "dailyGoalMinutes")
        let clamped = max(1, mins) // avoid zero
        return clamped * 60
    }

    // MARK: - Source data

    /// Returns the map of ISO yyyy-MM-dd -> seconds read (BibleStatsStore daily totals).
    private static func dailyReadingTotals() -> [String: Int] {
        BibleStatsStore.shared.loadDailyTotals()
    }

    /// Formats a local date as the ISO key used by BibleStatsStore (UTC-normalized).
    private static func isoKey(for date: Date) -> String {
        BibleStatsStore.isoDateString(date)
    }

    /// Whether the goal was met on a given local day, derived from daily reading totals.
    static func isGoalMet(on date: Date) -> Bool {
        let key = isoKey(for: date)
        let seconds = dailyReadingTotals()[key, default: 0]
        return seconds >= dailyGoalSeconds
    }

    /// The most recent local day for which the goal was met (or nil if never).
    static var lastVisitDate: Date? {
        let dict = dailyReadingTotals()
        guard !dict.isEmpty else { return nil }
        // Find the latest date whose total meets the goal
        let keys = dict.keys
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let metDates: [Date] = keys.compactMap { key in
            guard let d = formatter.date(from: key) else { return nil }
            return dict[key, default: 0] >= dailyGoalSeconds ? d : nil
        }
        return metDates.max()
    }

    /// Current consecutive-day streak ending today (or yesterday if today not met yet).
    static var currentStreak: Int {
        // Walk backward from today; count consecutive days meeting the goal
        var count = 0
        var day = Date()
        // If today not met, allow the streak to end yesterday
        if !isGoalMet(on: day) {
            if let y = calendar.date(byAdding: .day, value: -1, to: day) {
                day = y
            }
        }
        while isGoalMet(on: day) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    /// Best (max) consecutive-day streak over all recorded history.
    static var bestStreak: Int {
        let dict = dailyReadingTotals()
        guard !dict.isEmpty else { return 0 }

        // Convert keys to Dates and filter days meeting goal
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let metDays: Set<String> = Set(dict.filter { $0.value >= dailyGoalSeconds }.map { $0.key })

        // If nothing met, best is 0
        if metDays.isEmpty { return 0 }

        // Build a sorted list of all dates present in daily totals
        let allDates: [Date] = dict.keys.compactMap { formatter.date(from: $0) }.sorted()
        guard let minDay = allDates.first, let maxDay = allDates.last else { return 0 }

        // Walk from min to max, count consecutive met days
        var best = 0
        var current = 0
        var cursor = minDay
        while cursor <= maxDay {
            let key = isoKey(for: cursor)
            if metDays.contains(key) {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return best
    }

    // MARK: - Deprecated mutation APIs

    /// Deprecated: Streak is computed from Bible reading time; explicit marking is no longer needed.
    @available(*, deprecated, message: "No-op. Streak is computed from Bible reading totals.")
    static func markGoalMet(on date: Date = Date()) {
        // No-op by design to avoid divergence from BibleStatsStore totals.
        // Left here for backward compatibility if older code still calls it.
        // We also clear legacy counters to avoid confusion.
        defaults.removeObject(forKey: lastVisitKey)
        defaults.removeObject(forKey: currentStreakKey)
        defaults.removeObject(forKey: bestStreakKey)
    }

    /// Deprecated: Viewing/visiting content no longer awards streak credit.
    @available(*, deprecated, message: "No-op. Streak is computed from Bible reading totals.")
    static func markVisitedToday(now: Date = Date()) {
        // No-op
    }

    /// Reset legacy streak data (has no effect on computed streaks).
    static func reset() {
        defaults.removeObject(forKey: lastVisitKey)
        defaults.removeObject(forKey: currentStreakKey)
        defaults.removeObject(forKey: bestStreakKey)
        // Note: BibleStatsStore daily totals remain intact; computed streaks will still reflect actual reading history.
    }
}
