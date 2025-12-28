import Foundation

@MainActor
extension BibleStatsStore {
    // MARK: - Daily totals (overall)

    func loadDailyTotals() -> [String: Int] {
        if let cached = cacheDailyTotals { return cached }
        let decoded: [String: Int] = loadJSON(key: Defaults.keyDailyTotals, default: [:])
        cacheDailyTotals = decoded
        return decoded
    }

    func saveDailyTotals(_ dict: [String: Int]) {
        cacheDailyTotals = dict
        saveJSON(dict, key: Defaults.keyDailyTotals)
        // Push and notify
        iCloudSyncCoordinator.shared.pushKey(Defaults.keyDailyTotals)
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
    }

    func addToToday(seconds: Int, calendar: Calendar = .autoupdatingCurrent) {
        guard seconds > 0 else { return }
        var dict = loadDailyTotals()
        let today = Self.isoDateString(Date(), calendar: calendar)
        dict[today, default: 0] += seconds
        saveDailyTotals(dict)
    }

    func totalForLast(days: Int, including today: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> Int {
        guard days > 0 else { return 0 }
        let dict = loadDailyTotals()
        var sum = 0
        for i in 0..<days {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let key = Self.isoDateString(date, calendar: calendar)
                sum += dict[key, default: 0]
            }
        }
        return sum
    }

    // MARK: - Month totals (overall)

    // Sum of all daily totals for the calendar month containing `date` (local time).
    func totalForMonth(containing date: Date, calendar: Calendar = .autoupdatingCurrent) -> Int {
        var cal = calendar
        cal.timeZone = .autoupdatingCurrent

        let daily = loadDailyTotals()
        let keys = Self.isoKeysForMonth(containing: date, calendar: cal)
        var sum = 0
        for k in keys {
            sum += max(0, daily[k, default: 0])
        }
        return sum
    }

    // Convenience: sum for the current month.
    func totalForCurrentMonth(calendar: Calendar = .autoupdatingCurrent) -> Int {
        totalForMonth(containing: Date(), calendar: calendar)
    }
}
