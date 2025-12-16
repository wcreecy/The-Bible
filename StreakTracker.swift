import Foundation

/// Tracks a daily streak based on meeting the daily time goal from Bible reading only.
/// A day counts only when the user meets their Daily Goal minutes, evaluated against
/// the goal that was in effect on that day (using DailyGoalHistoryStore).
/// Updated to use BibleStatsStore's synced daily totals (yyyy-MM-dd local keys) instead of sessions,
/// for consistent cross-device behavior via iCloud KVS.
enum StreakTracker {
    // Legacy keys kept only for backward compatibility (no longer used for computation)
    private static let lastVisitKey = "bibleStreak_lastVisit"
    private static let currentStreakKey = "bibleStreak_current"
    private static let bestStreakKey = "bibleStreak_best"

    private static var defaults: UserDefaults { .standard }
    private static var calendar: Calendar {
        var cal = Calendar.autoupdatingCurrent
        cal.timeZone = TimeZone.autoupdatingCurrent
        return cal
    }

    // Local-day date formatter for keys (yyyy-MM-dd in the user's current time zone)
    private static let localDayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar.autoupdatingCurrent
        df.timeZone = TimeZone.autoupdatingCurrent
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    // MARK: - Settings (history-aware)

    /// Returns the daily goal in seconds for the given local day, using goal history.
    private static func dailyGoalSeconds(on date: Date) -> Int {
        DailyGoalHistoryStore.shared.goalSeconds(on: date)
    }

    // MARK: - Daily totals (synced via BibleStatsStore)

    /// Total seconds of Bible reading for the given local day, from BibleStatsStore's daily totals.
    /// This uses the synced per-day map keyed by yyyy-MM-dd (local time), merged via iCloud KVS.
    private static func dailyTotalsSeconds(on date: Date) -> Int {
        let key = BibleStatsStore.isoDateString(date, calendar: .autoupdatingCurrent)
        let map = BibleStatsStore.shared.loadDailyTotals()
        return max(0, map[key, default: 0])
    }

    /// Whether the goal was met on a given local day, derived from synced daily totals
    /// and the goal that was in effect on that day.
    static func isGoalMet(on date: Date) -> Bool {
        dailyTotalsSeconds(on: date) >= dailyGoalSeconds(on: date)
    }

    /// The most recent local day for which the goal was met (or nil if never), totals-based.
    static var lastVisitDate: Date? {
        let cal = calendar
        let now = Date()
        if isGoalMet(on: now) {
            return cal.startOfDay(for: now)
        }
        var cursor = cal.startOfDay(for: now)
        for _ in 0..<1825 {
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
            if isGoalMet(on: cursor) {
                return cursor
            }
        }
        return nil
    }

    /// Current consecutive-day streak ending today (or yesterday if today not met yet), totals-based.
    static var currentStreak: Int {
        let cal = calendar
        var count = 0
        var day = cal.startOfDay(for: Date())

        // If today not met, allow the streak to end yesterday (local)
        if !isGoalMet(on: day), let y = cal.date(byAdding: .day, value: -1, to: day) {
            day = y
        }

        // Walk back while each day meets the goal for its own day
        for _ in 0..<1825 {
            if isGoalMet(on: day) {
                count += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
                day = prev
            } else {
                break
            }
        }
        return count
    }

    /// Best (max) consecutive-day streak over all recorded history, totals-based.
    static var bestStreak: Int {
        let cal = calendar
        let today = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -1825, to: today) else { return 0 }

        var best = 0
        var current = 0
        var cursor = start
        while cursor <= today {
            if isGoalMet(on: cursor) {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return best
    }

    // MARK: - Deprecated mutation APIs

    @available(*, deprecated, message: "No-op. Streak is computed from synced daily totals.")
    static func markGoalMet(on date: Date = Date()) {
        defaults.removeObject(forKey: lastVisitKey)
        defaults.removeObject(forKey: currentStreakKey)
        defaults.removeObject(forKey: bestStreakKey)
    }

    @available(*, deprecated, message: "No-op. Streak is computed from synced daily totals.")
    static func markVisitedToday(now: Date = Date()) {
        // No-op
    }

    /// Reset legacy streak data (has no effect on computed streaks).
    static func reset() {
        defaults.removeObject(forKey: lastVisitKey)
        defaults.removeObject(forKey: currentStreakKey)
        defaults.removeObject(forKey: bestStreakKey)
    }
}
