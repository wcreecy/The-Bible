import Foundation

/// Tracks a daily streak based on meeting the daily time goal.
/// A day counts only when the user meets their Daily Goal minutes (Settings).
/// Comparison uses the current Calendar and respects the user's locale/timezone.
enum StreakTracker {
    // UserDefaults keys
    private static let lastVisitKey = "bibleStreak_lastVisit"
    private static let currentStreakKey = "bibleStreak_current"
    private static let bestStreakKey = "bibleStreak_best"

    // Per-day goal-met flag prefix: goalMet_YYYY-MM-DD -> Bool
    private static func dayKey(for date: Date) -> String {
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month, .day], from: date)
        let y = c.year ?? 0, m = c.month ?? 0, d = c.day ?? 0
        return String(format: "goalMet_%04d-%02d-%02d", y, m, d)
    }

    private static var defaults: UserDefaults { .standard }
    private static var calendar: Calendar { Calendar.current }

    /// Returns the last day we marked as goal-met (if any).
    static var lastVisitDate: Date? {
        let ts = defaults.double(forKey: lastVisitKey)
        guard ts > 0 else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    /// Current consecutive-day streak count.
    static var currentStreak: Int {
        defaults.integer(forKey: currentStreakKey)
    }

    /// Best (max) consecutive-day streak.
    static var bestStreak: Int {
        defaults.integer(forKey: bestStreakKey)
    }

    /// Returns true if the lastVisitDate is the same calendar day as `date`.
    private static func isSameDay(_ a: Date, _ b: Date) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }

    /// Returns true if `b` is exactly the day after `a` in the current calendar.
    private static func isNextDay(after a: Date, _ b: Date) -> Bool {
        guard let next = calendar.date(byAdding: .day, value: 1, to: a) else { return false }
        return isSameDay(next, b)
    }

    /// Query if the daily goal was met on a date (local day).
    static func isGoalMet(on date: Date) -> Bool {
        let key = dayKey(for: date)
        return defaults.bool(forKey: key)
    }

    /// Mark the daily goal as met on a specific date (defaults to today).
    /// Updates streak counters and lastVisitDate accordingly.
    static func markGoalMet(on date: Date = Date()) {
        // If already marked for that day, no-op
        if isGoalMet(on: date) {
            // Still ensure lastVisit/current/best reflect this day
            updateStreakCountersIfNeeded(for: date)
            return
        }
        // Persist the day flag
        defaults.set(true, forKey: dayKey(for: date))
        // Update streak counters
        updateStreakCountersIfNeeded(for: date)
    }

    /// Deprecated: Viewing/visiting content no longer awards streak credit.
    /// Streak should be awarded only when the daily goal is met via `markGoalMet`.
    @available(*, deprecated, message: "No-op. Use markGoalMet(on:) when the daily goal is reached.")
    static func markVisitedToday(now: Date = Date()) {
        // Intentionally no-op to prevent accidental early streak awards.
        // Streak credit is granted exclusively by markGoalMet(on:).
    }

    private static func updateStreakCountersIfNeeded(for date: Date) {
        let today = date
        let last = lastVisitDate

        if let last {
            if isSameDay(last, today) {
                // Already counted today; do nothing.
                return
            } else if isNextDay(after: last, today) {
                // Consecutive day: increment current streak.
                let newCurrent = max(0, currentStreak) + 1
                defaults.set(newCurrent, forKey: currentStreakKey)
                defaults.set(max(bestStreak, newCurrent), forKey: bestStreakKey)
            } else {
                // Missed at least one day: reset to 1 for today.
                defaults.set(1, forKey: currentStreakKey)
                defaults.set(max(bestStreak, 1), forKey: bestStreakKey)
            }
        } else {
            // First-ever met day: start at 1.
            defaults.set(1, forKey: currentStreakKey)
            defaults.set(max(bestStreak, 1), forKey: bestStreakKey)
        }

        defaults.set(today.timeIntervalSince1970, forKey: lastVisitKey)
    }

    /// Reset all streak data (for debug or settings reset).
    static func reset() {
        // Remove counters and last visit
        defaults.removeObject(forKey: lastVisitKey)
        defaults.removeObject(forKey: currentStreakKey)
        defaults.removeObject(forKey: bestStreakKey)
        // Remove all recorded day flags
        // Note: We cannot enumerate arbitrary keys in UserDefaults reliably.
        // If you add a "Clear Streak History" UI, store a list of dates to remove.
    }
}
