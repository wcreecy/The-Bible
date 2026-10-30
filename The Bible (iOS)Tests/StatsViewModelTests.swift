import Foundation
import Testing
@testable import Bible

/// The scoped-card behavior that used to live in `StatsView`. These drive the view model's
/// per-book maps directly and avoid the Totals chart, which reads the stored daily totals.
@MainActor
struct StatsViewModelTests {
    private func seconds(_ rows: [(book: String, seconds: Int)], for book: String) -> Int? {
        rows.first { $0.book == book }?.seconds
    }

    @Test
    func totalsRowsListEveryBookInCanonicalOrderOrMostReadFirst() {
        let model = StatsViewModel()
        model.perBookAllTimeSessionTotals = ["Mark": 100, "John": 100, "Genesis": 5]

        let canonical = model.totalsScopedRows(sortedBy: .canonical)
        #expect(canonical.count == model.orderedBookNames.count)
        #expect(canonical.first?.book == "Genesis")
        #expect(seconds(canonical, for: "Mark") == 100)

        // Ties keep canonical order, so Mark comes before John.
        let mostRead = model.totalsScopedRows(sortedBy: .mostRead)
        #expect(mostRead.prefix(3).map(\.book) == ["Mark", "John", "Genesis"])
        #expect(mostRead.dropFirst(3).allSatisfy { $0.seconds == 0 })
    }

    @Test
    func totalsSecondsFollowTheTotalsScope() {
        let model = StatsViewModel()
        model.perBookAllTimeSessionTotals = ["Genesis": 300]
        model.perBookMonthTotals = ["Genesis": 120]

        #expect(model.totalsScopedTotalSeconds == 300)
    }

    @Test
    func testamentCardFollowsItsOwnScope() {
        let model = StatsViewModel()
        model.perBookAllTimeSessionTotals = ["Genesis": 500]
        model.perBookLast7Totals = ["Genesis": 60, "Matthew": 40]

        model.timeScopeOTNT = .last7

        #expect(model.otSeconds == 60)
        #expect(model.ntSeconds == 40)
    }

    @Test
    func genreCardAndItsDetailRowsFollowTheGenreScope() {
        let model = StatsViewModel()
        model.perBookAllTimeSessionTotals = ["Genesis": 500]
        model.perBookMonthTotals = ["Genesis": 60, "Exodus": 30]

        model.timeScopeGenre = .thisMonth

        let law = model.perGenreTotals.first { $0.genre == StatsSeriesBuilder.Genre.Law.rawValue }
        #expect(law?.seconds == 90)

        let rows = model.genreDetailRows(for: .Law)
        #expect(rows.map(\.book) == ["Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy"])
        #expect(seconds(rows, for: "Genesis") == 60)
        #expect(seconds(rows, for: "Leviticus") == 0)
    }

    @Test
    func theCardsKeepTheirScopesIndependent() {
        let model = StatsViewModel()
        model.perBookMonthTotals = ["Matthew": 70]

        model.timeScopeOTNT = .thisMonth

        #expect(model.ntSeconds == 70)
        #expect(model.timeScopeGenre == .allTime)
        #expect(model.perGenreTotals.isEmpty)
    }

    @Test
    func topBookThisWeekBreaksTiesByNameAndIsNilWhenNothingWasRead() {
        let model = StatsViewModel()
        #expect(model.topBookThisWeek == nil)

        model.perBookLast7Totals = ["Mark": 0, "John": 0]
        #expect(model.topBookThisWeek == nil)

        model.perBookLast7Totals = ["Mark": 60, "John": 60, "Acts": 10]
        #expect(model.topBookThisWeek == "John")
    }

    @Test
    func activeReadingDaysCountsOnlyDaysWithReading() {
        let model = StatsViewModel()
        let today = Date()
        model.last7Daily = [(today, 0), (today, 120), (today, 0), (today, 30)]

        #expect(model.activeReadingDaysThisWeek == 2)
    }
}
