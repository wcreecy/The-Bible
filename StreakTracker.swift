import Foundation

/// Tracks a daily streak based on meeting the daily time goal from Bible reading only.
/// A day counts only when the user meets their Daily Goal minutes (Settings),
/// computed from reading sessions (ReadingSessionsStore) using local-day boundaries.
/// This aligns the calendar, big streak number, and progress bar on Home.
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

    // MARK: - Settings

    /// Returns the daily goal in seconds from Settings (defaults to 30 minutes if unset).
    private static var dailyGoalSeconds: Int {
        let mins = defaults.integer(forKey: "dailyGoalMinutes")
        let clamped = max(1, mins) // avoid zero
        return clamped * 60
    }

    // MARK: - Local-day helpers (sessions-based)

    /// Return the local-day start and exclusive end for a given date.
    private static func dayBounds(for date: Date, cal: Calendar = calendar) -> (start: Date, end: Date)? {
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return nil }
        return (start, end)
    }

    /// Total seconds of reading sessions overlapping the given local day.
    /// We count each session’s overlap with [startOfDay, startOfTomorrow).
    private static func sessionTotalSeconds(on date: Date, cal: Calendar = calendar) -> Int {
        guard let (startOfDay, startOfTomorrow) = dayBounds(for: date, cal: cal) else { return 0 }
        // Fetch sessions for the month containing this date to keep it efficient (same strategy as BibleStatsStore.todayTotalSeconds)
        let monthSessions = ReadingSessionsStore.shared.sessions(inMonthContaining: date, calendar: cal)
        var total = 0
        for s in monthSessions {
            let start = max(s.start, startOfDay)
            let end = min(s.end, startOfTomorrow)
            if end > start {
                total += Int(end.timeIntervalSince(start))
            }
        }
        return max(0, total)
    }

    /// Whether the goal was met on a given local day, derived strictly from session totals.
    static func isGoalMet(on date: Date) -> Bool {
        sessionTotalSeconds(on: date) >= dailyGoalSeconds
    }

    /// The most recent local day for which the goal was met (or nil if never), sessions-based.
    static var lastVisitDate: Date? {
        let cal = calendar
        // Look back a reasonable window (e.g., retention window of ReadingSessionsStore is ~5 years, but scanning month-by-month is fine)
        // Strategy: start from today and walk backwards until we find a hit or we run out of recent months with any sessions.
        let now = Date()
        // Quick check: if today met, return today's start-of-day
        if isGoalMet(on: now) {
            return cal.startOfDay(for: now)
        }
        // Otherwise walk back day by day until we hit a day that met the goal or we reach retention window
        // We cap to 1825 days (ReadingSessionsStore retention) to avoid unbounded loops.
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

    /// Current consecutive-day streak ending today (or yesterday if today not met yet), sessions-based.
    static var currentStreak: Int {
        let cal = calendar
        var count = 0
        var day = cal.startOfDay(for: Date())

        // If today not met, allow the streak to end yesterday (local)
        if !isGoalMet(on: day), let y = cal.date(byAdding: .day, value: -1, to: day) {
            day = y
        }

        // Walk back while each day meets the goal
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

    /// Best (max) consecutive-day streak over all recorded history, sessions-based.
    static var bestStreak: Int {
        let cal = calendar
        // Build a contiguous sequence over the retention window, then compute longest run.
        // To bound work, look back up to retention days from today.
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

    /// Deprecated: Streak is computed from Bible reading sessions; explicit marking is no longer needed.
    @available(*, deprecated, message: "No-op. Streak is computed from reading sessions.")
    static func markGoalMet(on date: Date = Date()) {
        // No-op by design to avoid divergence; clear legacy counters to avoid confusion.
        defaults.removeObject(forKey: lastVisitKey)
        defaults.removeObject(forKey: currentStreakKey)
        defaults.removeObject(forKey: bestStreakKey)
    }

    /// Deprecated: Viewing/visiting content no longer awards streak credit.
    @available(*, deprecated, message: "No-op. Streak is computed from reading sessions.")
    static func markVisitedToday(now: Date = Date()) {
        // No-op
    }

    /// Reset legacy streak data (has no effect on computed streaks).
    static func reset() {
        defaults.removeObject(forKey: lastVisitKey)
        defaults.removeObject(forKey: currentStreakKey)
        defaults.removeObject(forKey: bestStreakKey)
        // Reading sessions remain intact; computed streaks reflect actual reading history.
    }
}
