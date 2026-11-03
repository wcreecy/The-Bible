import Foundation
import Observation

enum ReadingWeekStatus {
    case completed
    case missed
    case today
    case future
}

/// Streak counts reached for a milestone celebration. After a year, every further year counts.
enum StreakMilestone {
    static let fixed = [7, 30, 100, 365]

    /// The largest milestone at or below `streak`, or 0 if none.
    static func reached(by streak: Int) -> Int {
        if streak >= 365 { return (streak / 365) * 365 }
        return fixed.last { $0 <= streak } ?? 0
    }

    /// The next milestone above `streak`.
    static func next(after streak: Int) -> Int {
        if let next = fixed.first(where: { $0 > streak }) { return next }
        return ((streak / 365) + 1) * 365
    }

    static func title(for milestone: Int) -> String {
        if milestone >= 365, milestone % 365 == 0 {
            let years = milestone / 365
            return years == 1 ? "1-year streak" : "\(years)-year streak"
        }
        return "\(milestone)-day streak"
    }
}

@MainActor
@Observable
final class StreaksViewModel {
    private var calendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        calendar.firstWeekday = 1
        return calendar
    }

    /// Bumped when reading stats change; the card reads it so it redraws.
    private(set) var revision = 0

    init() {
        NotificationCenter.observe(.bibleStatsExternallyUpdated, for: self) { model in
            model.revision &+= 1
        }
    }

    func currentWeekDates(relativeTo date: Date = Date()) -> [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return []
        }

        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: interval.start)
        }
    }

    /// Status for a day in the week row, using an already computed summary so no
    /// history is reloaded per day.
    func weekStatus(
        for date: Date,
        summary: StreakSummary,
        relativeTo today: Date = Date()
    ) -> ReadingWeekStatus {
        Self.status(for: date, summary: summary, calendar: calendar, today: today)
    }

    static func status(
        for date: Date,
        summary: StreakSummary,
        calendar: Calendar,
        today: Date = Date()
    ) -> ReadingWeekStatus {
        let goalMet = StreakTracker.isGoalMet(on: date, dailyTotals: summary.dailyTotals, calendar: calendar)

        if calendar.isDate(date, inSameDayAs: today) {
            return goalMet ? .completed : .today
        }

        if date > today {
            return .future
        }

        return goalMet ? .completed : .missed
    }
}
