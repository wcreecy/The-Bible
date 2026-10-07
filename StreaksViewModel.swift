import Combine
import Foundation

enum ReadingWeekMark {
    case check
    case x
}

enum ReadingWeekStatus {
    case completed
    case missed
    case today
    case future

    var mark: ReadingWeekMark? {
        switch self {
        case .completed:
            return .check
        case .missed:
            return .x
        case .today, .future:
            return nil
        }
    }
}

@MainActor
final class StreaksViewModel: ObservableObject {
    private var calendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        calendar.firstWeekday = 1
        return calendar
    }

    private var cancellable: AnyCancellable?

    init() {
        cancellable = NotificationCenter.default
            .publisher(for: .bibleStatsExternallyUpdated)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
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

    func weekStatus(for date: Date, relativeTo today: Date = Date()) -> ReadingWeekStatus {
        if calendar.isDate(date, inSameDayAs: today) {
            return StreakTracker.isGoalMet(on: date) ? .completed : .today
        }

        if date > today {
            return .future
        }

        return StreakTracker.isGoalMet(on: date) ? .completed : .missed
    }

    func friendlyDate(_ date: Date) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
