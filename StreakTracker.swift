import Foundation

/// Steps through days in order and keeps the goal streak.
///
/// Each day the goal is met adds to the run; any missed day ends it. The same rules
/// are used for live streaks and archived history.
struct StreakRunner {
    private(set) var run: Int
    private(set) var best: Int

    init(run: Int = 0, best: Int = 0) {
        self.run = run
        self.best = max(best, run)
    }

    mutating func advance(goalMet: Bool) {
        if goalMet {
            run += 1
            best = max(best, run)
        } else {
            run = 0
        }
    }
}

/// Everything the streak UI needs, computed in a single pass over reading history.
struct StreakSummary {
    var current: Int = 0
    var best: Int = 0
    var todaySeconds: Int = 0
    var todayGoalSeconds: Int = 60
    /// The per-day totals the summary was built from, for callers that need day lookups.
    var dailyTotals: [String: Int] = [:]

    var todayGoalMet: Bool { todaySeconds >= todayGoalSeconds }
    var todayRemainingSeconds: Int { max(0, todayGoalSeconds - todaySeconds) }
}

/// Tracks a daily streak based on meeting the daily time goal from Bible reading only.
/// A day counts only when the user meets their Daily Goal minutes, evaluated against
/// the goal that was in effect on that day (using DailyGoalHistoryStore).
/// Updated to use BibleStatsStore's synced daily totals (yyyy-MM-dd local keys) instead of sessions,
/// for consistent cross-device behavior via iCloud KVS.
enum StreakTracker {
    /// How far back streaks are evaluated when no archive covers older days.
    private static let maxHistoryDays = 1825

    private static var calendar: Calendar {
        var cal = Calendar.autoupdatingCurrent
        cal.timeZone = TimeZone.autoupdatingCurrent
        return cal
    }

    /// Reading older than the retention cutoff is summarized in the archive; streaks
    /// continue from its saved run instead of from per-day records.
    private static var archivedStreak: (cutoff: Date, runAtCutoff: Int, best: Int)? {
        guard let archive = BibleStatsStore.shared.loadReadingHistoryArchive(),
              let cutoff = StatsHistoryRetention.date(fromDayKey: archive.cutoff) else { return nil }
        return (calendar.startOfDay(for: cutoff), archive.streakRunAtCutoff, archive.bestStreak)
    }

    // MARK: - Settings (history-aware)

    /// Returns the daily goal in seconds for the given local day, using goal history.
    static func dailyGoalSeconds(on date: Date) -> Int {
        DailyGoalHistoryStore.shared.goalSeconds(on: date)
    }

    // MARK: - Daily totals (synced via BibleStatsStore)

    /// Whether the goal was met on a given local day, derived from synced daily totals
    /// and the goal that was in effect on that day.
    static func isGoalMet(on date: Date) -> Bool {
        isGoalMet(on: date, dailyTotals: BibleStatsStore.shared.loadDailyTotals())
    }

    static func isGoalMet(
        on date: Date,
        dailyTotals: [String: Int],
        calendar: Calendar = .autoupdatingCurrent
    ) -> Bool {
        let key = BibleStatsStore.isoDateString(date, calendar: calendar)
        return max(0, dailyTotals[key, default: 0]) >= dailyGoalSeconds(on: date)
    }

    // MARK: - Summary

    /// Walks reading history forward once and returns the current and best streaks,
    /// and today's goal progress. Pass `dailyTotals` when already loaded.
    static func summary(
        dailyTotals: [String: Int]? = nil,
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> StreakSummary {
        var cal = calendar
        cal.timeZone = TimeZone.autoupdatingCurrent
        let totals = dailyTotals ?? BibleStatsStore.shared.loadDailyTotals()
        let today = cal.startOfDay(for: now)

        var summary = StreakSummary()
        summary.dailyTotals = totals
        summary.todaySeconds = max(0, totals[BibleStatsStore.isoDateString(today, calendar: cal), default: 0])
        summary.todayGoalSeconds = max(1, dailyGoalSeconds(on: today))

        var runner = StreakRunner()
        var cursor = cal.date(byAdding: .day, value: -maxHistoryDays, to: today) ?? today

        if let archived = archivedStreak, archived.cutoff > cursor {
            cursor = archived.cutoff
            runner = StreakRunner(run: archived.runAtCutoff, best: archived.best)
        } else if let earliest = totals.keys.min(),
                  let earliestDate = StatsHistoryRetention.date(fromDayKey: earliest, calendar: cal),
                  earliestDate > cursor {
            // Nothing was read before the first recorded day, so start there.
            cursor = cal.startOfDay(for: earliestDate)
        }

        while cursor < today {
            runner.advance(goalMet: isGoalMet(on: cursor, dailyTotals: totals, calendar: cal))
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        // Today only adds to the streak once its goal is met; until then it can't break it.
        if summary.todayGoalMet {
            runner.advance(goalMet: true)
        }

        summary.current = runner.run
        summary.best = runner.best
        return summary
    }

    // MARK: - Convenience

    static func currentStreak(
        dailyTotals: [String: Int],
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> Int {
        summary(dailyTotals: dailyTotals, now: now, calendar: calendar).current
    }

    static func bestStreak(
        dailyTotals: [String: Int],
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> Int {
        summary(dailyTotals: dailyTotals, now: now, calendar: calendar).best
    }

    /// Current consecutive-day streak ending today (or yesterday if today not met yet), totals-based.
    static var currentStreak: Int {
        summary().current
    }

    /// Best (max) consecutive-day streak over all recorded history, totals-based.
    static var bestStreak: Int {
        summary().best
    }
}
