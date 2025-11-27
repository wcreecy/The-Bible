import Foundation

/// Tracks a daily "Bible reading" streak.
/// A day counts if the user visits Bible verses at least once that day.
/// Comparison uses the current Calendar and respects the user's locale/timezone.
enum StreakTracker {
    // UserDefaults keys
    private static let lastVisitKey = "bibleStreak_lastVisit"
    private static let currentStreakKey = "bibleStreak_current"
    private static let bestStreakKey = "bibleStreak_best"

    private static var defaults: UserDefaults { .standard }
    private static var calendar: Calendar { Calendar.current }

    /// Returns the last day the user visited (if any).
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

    /// Call when the user has visited Bible verses today.
    /// This will update current/best streak appropriately.
    static func markVisitedToday(now: Date = Date()) {
        let today = now
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
            // First-ever visit: start at 1.
            defaults.set(1, forKey: currentStreakKey)
            defaults.set(max(bestStreak, 1), forKey: bestStreakKey)
        }

        defaults.set(today.timeIntervalSince1970, forKey: lastVisitKey)
    }

    /// Reset all streak data (for debug or settings reset).
    static func reset() {
        defaults.removeObject(forKey: lastVisitKey)
        defaults.removeObject(forKey: currentStreakKey)
        defaults.removeObject(forKey: bestStreakKey)
    }
}
