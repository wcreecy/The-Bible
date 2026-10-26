import Foundation
import Testing
@testable import Bible

@MainActor
struct StatsBoundaryTests {
    @Test
    func daylightSavingTransitionsPreserveAllTrackedSeconds() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))

        let springStart = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 23, minute: 30)))
        let springEnd = try #require(calendar.date(byAdding: .hour, value: 1, to: springStart))
        let fallStart = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 23, minute: 30)))
        let fallEnd = try #require(calendar.date(byAdding: .hour, value: 1, to: fallStart))

        let spring = ReadingTimeTracker.dailyAllocations(seconds: 3_600, from: springStart, to: springEnd, calendar: calendar)
        let fall = ReadingTimeTracker.dailyAllocations(seconds: 3_600, from: fallStart, to: fallEnd, calendar: calendar)

        #expect(spring.reduce(0) { $0 + $1.seconds } == 3_600)
        #expect(fall.reduce(0) { $0 + $1.seconds } == 3_600)
        #expect(spring.count == 2)
        #expect(fall.count == 2)
    }

    @Test
    func longSessionSpanningSeveralDaysRetainsItsExactTotal() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 12)))
        let end = try #require(calendar.date(byAdding: .hour, value: 72, to: start))

        let allocations = ReadingTimeTracker.dailyAllocations(
            seconds: 72 * 60 * 60,
            from: start,
            to: end,
            calendar: calendar
        )

        #expect(allocations.reduce(0) { $0 + $1.seconds } == 72 * 60 * 60)
        #expect(allocations.count == 4)
        #expect(allocations.allSatisfy { $0.seconds > 0 })
    }

    @Test
    func calendarChangeDoesNotLoseTrackedSeconds() throws {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        var losAngeles = Calendar(identifier: .gregorian)
        losAngeles.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))

        let start = Date(timeIntervalSince1970: 1_780_832_400)
        let end = start.addingTimeInterval(3 * 60 * 60)

        let east = ReadingTimeTracker.dailyAllocations(seconds: 10_800, from: start, to: end, calendar: newYork)
        let west = ReadingTimeTracker.dailyAllocations(seconds: 10_800, from: start, to: end, calendar: losAngeles)

        #expect(east.reduce(0) { $0 + $1.seconds } == 10_800)
        #expect(west.reduce(0) { $0 + $1.seconds } == 10_800)
    }

    @Test
    func invalidIntervalsAndNonpositiveDurationsDoNotCreateStats() {
        let start = Date(timeIntervalSince1970: 1_000)
        #expect(ReadingTimeTracker.dailyAllocations(seconds: 0, from: start, to: start.addingTimeInterval(60)).isEmpty)
        #expect(ReadingTimeTracker.dailyAllocations(seconds: -1, from: start, to: start.addingTimeInterval(60)).isEmpty)
        #expect(ReadingTimeTracker.dailyAllocations(seconds: 60, from: start, to: start).isEmpty)
        #expect(ReadingTimeTracker.dailyAllocations(seconds: 60, from: start.addingTimeInterval(60), to: start).isEmpty)
    }
}
