import Foundation

/// The bars and summary numbers on the Reading Stats Totals card.
///
/// The chart shows one bar per day, week, month or year depending on the scope. Everything
/// the builder reads is passed in, so it doesn't depend on the clock or on stored data.
enum StatsTotalsSeries {
    struct Chart {
        let points: [(date: Date, seconds: Int)]
        let aggregation: StatsSeriesBuilder.Aggregation
    }

    /// - Parameters:
    ///   - dailyTotals: Seconds read per day, keyed `yyyy-MM-dd`.
    ///   - yearlyArchive: Seconds read per year for reading older than the retention cutoff.
    ///     Only read for the all-time scope.
    static func chart(
        scope: StatsTimeScope,
        dailyTotals dailyMap: [String: Int],
        yearlyArchive: @autoclosure () -> [String: Int],
        now: Date,
        calendar cal: Calendar
    ) -> Chart {
        let startOfToday = cal.startOfDay(for: now)

        switch scope {
        case .last7:
            var series: [(date: Date, seconds: Int)] = []
            for i in stride(from: 6, through: 0, by: -1) {
                if let d = cal.date(byAdding: .day, value: -i, to: startOfToday) {
                    let key = BibleStatsStore.isoDateString(d, calendar: cal)
                    series.append((d, max(0, dailyMap[key, default: 0])))
                }
            }
            return Chart(points: series, aggregation: .daily)

        case .thisMonth:
            var series: [(date: Date, seconds: Int)] = []
            // Enumerate all days in this month using isoKeysForMonth for consistency
            let keys = BibleStatsStore.isoKeysForMonth(containing: now, calendar: cal)
            for key in keys {
                // Rebuild Date from key using calendar startOfDay
                let comps = key.split(separator: "-").compactMap { Int($0) }
                if comps.count == 3, let date = cal.date(from: DateComponents(year: comps[0], month: comps[1], day: comps[2])) {
                    if date <= startOfToday {
                        series.append((date, max(0, dailyMap[key, default: 0])))
                    }
                }
            }
            return Chart(points: series, aggregation: .weekly)

        case .allTime:
            // Aggregate daily totals into monthly or yearly buckets based on span, similar to StatsSeriesBuilder
            // Build a [Date: Int] map of all known daily entries as Dates
            var entries: [(date: Date, seconds: Int)] = []
            for (key, seconds) in dailyMap {
                let parts = key.split(separator: "-").compactMap { Int($0) }
                if parts.count == 3, let date = cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) {
                    entries.append((cal.startOfDay(for: date), max(0, seconds)))
                }
            }
            // Reading older than the retention cutoff is kept as yearly totals. It always
            // spans more than a year, so the chart uses yearly bars and stays exact.
            for (year, seconds) in yearlyArchive() {
                if let year = Int(year), let date = cal.date(from: DateComponents(year: year, month: 1, day: 1)) {
                    entries.append((date, max(0, seconds)))
                }
            }
            guard !entries.isEmpty else {
                return Chart(points: [], aggregation: .daily)
            }
            let start = entries.map { $0.date }.min() ?? startOfToday
            let end = startOfToday
            let monthsSpan = cal.dateComponents([.month], from: start, to: end).month ?? 0
            let aggregation: StatsSeriesBuilder.Aggregation = (monthsSpan <= 12) ? .monthly : .yearly

            func bucketStart(for date: Date) -> Date {
                switch aggregation {
                case .monthly:
                    let comps = cal.dateComponents([.year, .month], from: date)
                    return cal.date(from: comps) ?? cal.startOfDay(for: date)
                case .yearly:
                    let comps = cal.dateComponents([.year], from: date)
                    return cal.date(from: comps) ?? cal.startOfDay(for: date)
                default:
                    return cal.startOfDay(for: date)
                }
            }

            var buckets: [Date: Int] = [:]
            for e in entries {
                let key = bucketStart(for: e.date)
                buckets[key, default: 0] += e.seconds
            }

            var series: [(date: Date, seconds: Int)] = []
            var cursor: Date = {
                switch aggregation {
                case .monthly:
                    let comps = cal.dateComponents([.year, .month], from: start)
                    return cal.date(from: comps) ?? start
                case .yearly:
                    let comps = cal.dateComponents([.year], from: start)
                    return cal.date(from: comps) ?? start
                default:
                    return start
                }
            }()

            func step(_ date: Date) -> Date {
                switch aggregation {
                case .monthly: return cal.date(byAdding: .month, value: 1, to: date) ?? date
                case .yearly: return cal.date(byAdding: .year, value: 1, to: date) ?? date
                default: return date
                }
            }

            while cursor <= end {
                let val = buckets[cursor, default: 0]
                series.append((cursor, val))
                cursor = step(cursor)
            }

            return Chart(points: series, aggregation: aggregation)
        }
    }

    /// Bars with any reading in them.
    static func activeBuckets(in points: [(date: Date, seconds: Int)]) -> Int {
        points.reduce(0) { $0 + ($1.seconds > 0 ? 1 : 0) }
    }

    /// Average seconds across the bars that have any reading, or 0 when none do.
    static func averageSecondsPerActiveBucket(in points: [(date: Date, seconds: Int)]) -> Int {
        let active = activeBuckets(in: points)
        let total = points.reduce(0) { $0 + $1.seconds }
        return active > 0 ? total / active : 0
    }

    /// The most-read book. Ties go to the earlier name, and "—" means nothing was read.
    static func topBook(in perBookTotals: [String: Int]) -> String {
        if let top = perBookTotals.sorted(by: { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key < rhs.key }
            return lhs.value > rhs.value
        }).first, top.value > 0 {
            return top.key
        }
        return "—"
    }
}
