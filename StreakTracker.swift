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

    // Local-day date formatter for keys (yyyy-MM-dd in the user's current time zone)
    private static let localDayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar.current
        df.timeZone = Calendar.current.timeZone
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

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

    /// Local-day key used for daily totals (yyyy-MM-dd in the user's current time zone).
    private static func localDayKey(for date: Date) -> String {
        // Normalize to local start of day to avoid 23:00/01:00 boundary issues around DST
        let start = calendar.startOfDay(for: date)
        return localDayFormatter.string(from: start)
    }

    /// Whether the goal was met on a given local day, derived from daily reading totals.
    static func isGoalMet(on date: Date) -> Bool {
        let key = localDayKey(for: date)
        let seconds = dailyReadingTotals()[key, default: 0]
        return seconds >= dailyGoalSeconds
    }

    /// The most recent local day for which the goal was met (or nil if never).
    static var lastVisitDate: Date? {
        let dict = dailyReadingTotals()
        guard !dict.isEmpty else { return nil }

        // Collect all keys that meet goal and convert back to local Date (startOfDay)
        let metDates: [Date] = dict.compactMap { key, value in
            guard value >= dailyGoalSeconds,
                  let day = localDayFormatter.date(from: key) else { return nil }
            return day
        }
        return metDates.max()
    }

    /// Current consecutive-day streak ending today (or yesterday if today not met yet).
    static var currentStreak: Int {
        var count = 0
        var day = Date()
        // If today not met, allow the streak to end yesterday (local)
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

        // Days (as keys) that met the goal
        let metDays: Set<String> = Set(dict.filter { $0.value >= dailyGoalSeconds }.map { $0.key })
        if metDays.isEmpty { return 0 }

        // Build sorted list of all days present (as Dates at local startOfDay)
        let allDates: [Date] = dict.keys.compactMap { localDayFormatter.date(from: $0) }.sorted()
        guard let minDay = allDates.first, let maxDay = allDates.last else { return 0 }

        var best = 0
        var current = 0
        var cursor = minDay
        while cursor <= maxDay {
            let key = localDayKey(for: cursor)
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
