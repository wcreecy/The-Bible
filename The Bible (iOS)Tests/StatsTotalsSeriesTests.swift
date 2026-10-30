import Foundation
import Testing
@testable import Bible

struct StatsTotalsSeriesTests {
    /// A fixed calendar and clock so the buckets never depend on where or when the tests run.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? Date()
    }

    private func key(_ year: Int, _ month: Int, _ day: Int) -> String {
        BibleStatsStore.isoDateString(date(year, month, day), calendar: calendar)
    }

    @Test
    func lastSevenDaysIsSevenDailyBarsOldestFirstWithGapsAsZero() {
        let now = date(2026, 10, 15)
        let daily = [key(2026, 10, 15): 600, key(2026, 10, 13): 300, key(2026, 10, 1): 999]

        let chart = StatsTotalsSeries.chart(scope: .last7, dailyTotals: daily, yearlyArchive: [:], now: now, calendar: calendar)

        #expect(chart.aggregation == .daily)
        #expect(chart.points.count == 7)
        #expect(chart.points.map(\.seconds) == [0, 0, 0, 0, 300, 0, 600])
        #expect(chart.points.first?.date == calendar.startOfDay(for: date(2026, 10, 9)))
        #expect(chart.points.last?.date == calendar.startOfDay(for: date(2026, 10, 15)))
    }

    @Test
    func thisMonthStopsAtToday() {
        let now = date(2026, 10, 15)
        let daily = [key(2026, 10, 1): 60, key(2026, 10, 15): 120, key(2026, 10, 20): 500]

        let chart = StatsTotalsSeries.chart(scope: .thisMonth, dailyTotals: daily, yearlyArchive: [:], now: now, calendar: calendar)

        #expect(chart.aggregation == .weekly)
        #expect(chart.points.count == 15)
        #expect(chart.points.first?.seconds == 60)
        #expect(chart.points.last?.seconds == 120)
        #expect(chart.points.map(\.seconds).reduce(0, +) == 180)
    }

    @Test
    func allTimeWithinAYearGroupsByMonthIncludingEmptyMonths() {
        let now = date(2026, 10, 15)
        let daily = [key(2026, 8, 20): 100, key(2026, 8, 25): 50, key(2026, 10, 2): 70]

        let chart = StatsTotalsSeries.chart(scope: .allTime, dailyTotals: daily, yearlyArchive: [:], now: now, calendar: calendar)

        #expect(chart.aggregation == .monthly)
        #expect(chart.points.map(\.seconds) == [150, 0, 70])
    }

    @Test
    func allTimeOverAYearGroupsByYearAndIncludesTheArchive() {
        let now = date(2026, 10, 15)
        let daily = [key(2025, 2, 10): 40, key(2026, 10, 1): 60]

        let chart = StatsTotalsSeries.chart(scope: .allTime, dailyTotals: daily, yearlyArchive: ["2023": 500], now: now, calendar: calendar)

        #expect(chart.aggregation == .yearly)
        #expect(chart.points.map(\.seconds) == [500, 0, 40, 60])
    }

    @Test
    func allTimeWithNoReadingIsEmpty() {
        let chart = StatsTotalsSeries.chart(scope: .allTime, dailyTotals: [:], yearlyArchive: [:], now: date(2026, 10, 15), calendar: calendar)

        #expect(chart.points.isEmpty)
        #expect(chart.aggregation == .daily)
    }

    @Test
    func theArchiveIsOnlyReadForTheAllTimeScope() {
        var archiveWasRead = false
        func archive() -> [String: Int] {
            archiveWasRead = true
            return ["2023": 500]
        }

        _ = StatsTotalsSeries.chart(scope: .last7, dailyTotals: [:], yearlyArchive: archive(), now: date(2026, 10, 15), calendar: calendar)
        _ = StatsTotalsSeries.chart(scope: .thisMonth, dailyTotals: [:], yearlyArchive: archive(), now: date(2026, 10, 15), calendar: calendar)

        #expect(!archiveWasRead)
    }

    @Test
    func summaryNumbersCountOnlyBarsWithReading() {
        let points: [(date: Date, seconds: Int)] = [
            (date(2026, 10, 13), 0), (date(2026, 10, 14), 300), (date(2026, 10, 15), 100)
        ]

        #expect(StatsTotalsSeries.activeBuckets(in: points) == 2)
        #expect(StatsTotalsSeries.averageSecondsPerActiveBucket(in: points) == 200)
        #expect(StatsTotalsSeries.averageSecondsPerActiveBucket(in: []) == 0)
    }

    @Test
    func topBookBreaksTiesByNameAndSaysNothingWhenNothingWasRead() {
        #expect(StatsTotalsSeries.topBook(in: ["Mark": 60, "John": 60, "Acts": 10]) == "John")
        #expect(StatsTotalsSeries.topBook(in: ["Mark": 0]) == "—")
        #expect(StatsTotalsSeries.topBook(in: [:]) == "—")
    }
}
