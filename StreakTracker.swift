import Foundation

/// Steps through days in order and keeps the goal streak, including grace days.
///
/// With grace days on, one missed day per `graceWindowDays` keeps an active streak
/// going. The grace day doesn't add to the count, and a second miss inside the window
/// ends the streak. The same rules are used for live streaks and archived history.
struct StreakRunner {
    static let graceWindowDays = 7

    enum Outcome {
        case counted
        case grace
        case missed
    }

    let allowsGraceDays: Bool
    private(set) var run: Int
    private(set) var best: Int
    private(set) var lastGraceDay: Date?

    init(allowsGraceDays: Bool, run: Int = 0, best: Int = 0) {
        self.allowsGraceDays = allowsGraceDays
        self.run = run
        self.best = max(best, run)
    }

    /// Whether missing `day` would be covered by a grace day.
    func canUseGrace(on day: Date, calendar: Calendar) -> Bool {
        guard allowsGraceDays, run > 0 else { return false }
        guard let lastGraceDay else { return true }
        let gap = calendar.dateComponents([.day], from: lastGraceDay, to: day).day ?? 0
        return gap >= Self.graceWindowDays
    }

    @discardableResult
    mutating func advance(goalMet: Bool, on day: Date, calendar: Calendar) -> Outcome {
        if goalMet {
            run += 1
            best = max(best, run)
            return .counted
        }
        if canUseGrace(on: day, calendar: calendar) {
            lastGraceDay = day
            return .grace
        }
        run = 0
        lastGraceDay = nil
        return .missed
    }
}

/// Everything the streak UI needs, computed in a single pass over reading history.
struct StreakSummary {
    var current: Int = 0
    var best: Int = 0
    /// Missed days kept by a grace day, as `yyyy-MM-dd` keys.
    var graceDayKeys: Set<String> = []
    /// Whether missing today would be covered by a grace day.
    var graceAvailableToday: Bool = false
    /// Whether yesterday was a grace day, so today has to count.
    var usedGraceYesterday: Bool = false
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
    /// UserDefaults key for the grace day setting (on by default).
    static let graceDaysEnabledKey = "streakGraceDaysEnabled"

    static var allowsGraceDays: Bool {
        UserDefaults.standard.object(forKey: graceDaysEnabledKey) as? Bool ?? true
    }

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
    /// grace days, and today's goal progress. Pass `dailyTotals` when already loaded.
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

        var runner = StreakRunner(allowsGraceDays: allowsGraceDays)
        var cursor = cal.date(byAdding: .day, value: -maxHistoryDays, to: today) ?? today

        if let archived = archivedStreak, archived.cutoff > cursor {
            cursor = archived.cutoff
            runner = StreakRunner(
                allowsGraceDays: allowsGraceDays,
                run: archived.runAtCutoff,
                best: archived.best
            )
        } else if let earliest = totals.keys.min(),
                  let earliestDate = StatsHistoryRetention.date(fromDayKey: earliest, calendar: cal),
                  earliestDate > cursor {
            // Nothing was read before the first recorded day, so start there.
            cursor = cal.startOfDay(for: earliestDate)
        }

        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today
        while cursor < today {
            let outcome = runner.advance(
                goalMet: isGoalMet(on: cursor, dailyTotals: totals, calendar: cal),
                on: cursor,
                calendar: cal
            )
            if outcome == .grace {
                summary.graceDayKeys.insert(BibleStatsStore.isoDateString(cursor, calendar: cal))
                if cal.isDate(cursor, inSameDayAs: yesterday) {
                    summary.usedGraceYesterday = true
                }
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        // Today only adds to the streak once its goal is met; until then it can't break it.
        summary.graceAvailableToday = runner.canUseGrace(on: today, calendar: cal)
        if summary.todayGoalMet {
            runner.advance(goalMet: true, on: today, calendar: cal)
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
