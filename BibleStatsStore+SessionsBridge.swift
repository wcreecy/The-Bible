import Foundation

@MainActor
extension BibleStatsStore {
    // Sessions-only: compute month total strictly from ReadingSessionsStore (no fallback to daily totals)
    func totalForMonth(containing date: Date, calendar: Calendar = .autoupdatingCurrent) -> Int {
        return totalForMonthFromSessions(containing: date, calendar: calendar)
    }

    private func totalForMonthFromSessions(containing date: Date, calendar: Calendar = .autoupdatingCurrent) -> Int {
        let sessions = ReadingSessionsStore.shared.sessions(inMonthContaining: date, calendar: calendar)
        var total = 0
        for s in sessions {
            total += Int(max(0, s.end.timeIntervalSince(s.start)))
        }
        return total
    }

    // MARK: - Sessions-based "Today" helpers (authoritative for daily UI)

    func todayTotalSeconds(now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> Int {
        var cal = calendar
        cal.timeZone = TimeZone.autoupdatingCurrent
        let startOfDay = cal.startOfDay(for: now)
        guard let startOfTomorrow = cal.date(byAdding: .day, value: 1, to: startOfDay) else { return 0 }

        let monthSessions = ReadingSessionsStore.shared.sessions(inMonthContaining: now, calendar: cal)
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

    func isDailyGoalMet(goalSeconds: Int, now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> Bool {
        return todayTotalSeconds(now: now, calendar: calendar) >= max(1, goalSeconds)
    }
}
