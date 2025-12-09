import Foundation
import Combine
import SwiftUI

@MainActor
final class StreaksViewModel: ObservableObject {
    // UI state
    @Published var isExpanded: Bool = false
    @Published var monthAnchor: Date = Date()

    // Calendar dependencies
    private var cal: Calendar {
        var c = Calendar.autoupdatingCurrent
        c.timeZone = TimeZone.autoupdatingCurrent
        return c
    }

    private var cancellable: AnyCancellable?

    init() {
        // Keep calendar view reactive to external stats updates (sessions/daily totals)
        cancellable = NotificationCenter.default
            .publisher(for: .bibleStatsExternallyUpdated)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                // Publishing monthAnchor will recompute grid in views that depend on it.
                // We don't need to change the value; nudging objectWillChange is enough.
                self?.objectWillChange.send()
            }
    }

    // MARK: - Calendar computations

    func startOfMonth(for date: Date) -> Date {
        let comps = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: comps) ?? date
    }

    // Grid of weeks; each week is 7 entries (Date? with leading/trailing nils)
    func daysGrid(for month: Date) -> [[Date?]] {
        let start = startOfMonth(for: month)
        guard let range = cal.range(of: .day, in: .month, for: start) else { return [] }
        let firstWeekday = cal.component(.weekday, from: start)
        let daysCount = range.count

        var grid: [[Date?]] = []
        var row: [Date?] = []

        let leading = (firstWeekday - cal.firstWeekday + 7) % 7
        for _ in 0..<leading { row.append(nil) }

        for day in 1...daysCount {
            if let d = cal.date(byAdding: .day, value: day - 1, to: start) {
                row.append(d)
                if row.count == 7 {
                    grid.append(row)
                    row = []
                }
            }
        }
        if !row.isEmpty {
            while row.count < 7 { row.append(nil) }
            grid.append(row)
        }
        return grid
    }

    var weekdayShortSymbols: [String] {
        cal.shortWeekdaySymbols
    }

    var friendlyMonthYear: String {
        monthAnchor.formatted(.dateTime.month().year())
    }

    // MARK: - Navigation

    func goToPreviousMonth() {
        if let prev = cal.date(byAdding: .month, value: -1, to: monthAnchor) {
            monthAnchor = prev
        }
    }

    func goToNextMonth() {
        if let next = cal.date(byAdding: .month, value: 1, to: monthAnchor) {
            monthAnchor = next
        }
    }

    // MARK: - Day status helpers

    func isFuture(_ date: Date, relativeTo today: Date = Date()) -> Bool {
        if cal.isDate(date, inSameDayAs: today) { return false }
        return date > today
    }

    func goalMet(for date: Date) -> Bool {
        StreakTracker.isGoalMet(on: date)
    }

    // MARK: - Friendly date (for "Last read:" line if needed elsewhere)

    func friendlyDate(_ date: Date) -> String {
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
