import SwiftUI
import Charts

struct StatsChartConfig {
    // A lightweight scope the helper can use without depending on StatsView.
    enum Scope {
        case allTime, thisMonth, last7
    }

    typealias Aggregation = StatsSeriesBuilder.Aggregation

    static func subtitle(for scope: Scope, allTimeAggregation: Aggregation) -> String {
        switch scope {
        case .last7:
            return "Daily minutes — Last 7 days"
        case .thisMonth:
            return "Daily minutes — This month"
        case .allTime:
            switch allTimeAggregation {
            case .monthly: return "Monthly minutes — All-time"
            case .yearly:  return "Yearly minutes — All-time"
            case .weekly:  return "Weekly minutes — All-time"
            case .daily:   return "Daily minutes — All-time"
            }
        }
    }

    static func currentXAxisAggregation(for scope: Scope, allTimeAggregation: Aggregation) -> Aggregation {
        switch scope {
        case .allTime:
            return allTimeAggregation
        case .thisMonth:
            return .weekly
        case .last7:
            return .daily
        }
    }

    static func currentBarUnit(for scope: Scope, allTimeAggregation: Aggregation) -> Calendar.Component {
        switch scope {
        case .last7, .thisMonth:
            return .day
        case .allTime:
            switch allTimeAggregation {
            case .monthly: return .month
            case .yearly:  return .year
            case .weekly:  return .weekOfYear
            case .daily:   return .day
            }
        }
    }

    static func shouldShowBarValueLabels(for scope: Scope,
                                         allTimeAggregation: Aggregation,
                                         count: Int,
                                         isRegular: Bool) -> Bool {
        // Always show labels for "This Month" as requested
        if case .thisMonth = scope { return true }

        let agg = currentXAxisAggregation(for: scope, allTimeAggregation: allTimeAggregation)
        switch agg {
        case .daily:
            return count <= (isRegular ? 24 : 14)
        case .weekly:
            return count <= (isRegular ? 26 : 12)
        case .monthly:
            return count <= (isRegular ? 24 : 12)
        case .yearly:
            return count <= (isRegular ? 20 : 10)
        }
    }

    // Moved label helpers here
    static func activeBucketLabel(for unit: Calendar.Component) -> String {
        switch unit {
        case .day:        return "Active Days"
        case .weekOfYear: return "Active Weeks"
        case .month:      return "Active Months"
        case .year:       return "Active Years"
        default:          return "Active"
        }
    }

    static func avgPerActiveBucketLabel(for unit: Calendar.Component) -> String {
        switch unit {
        case .day:        return "Avg per active day"
        case .weekOfYear: return "Avg per active week"
        case .month:      return "Avg per active month"
        case .year:       return "Avg per active year"
        default:          return "Avg per active period"
        }
    }

    @AxisContentBuilder
    static func xAxisMarks(for aggregation: Aggregation) -> some AxisContent {
        switch aggregation {
        case .daily:
            AxisMarks(values: .stride(by: .day, count: 1)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        case .weekly:
            AxisMarks(values: .stride(by: .weekOfYear, count: 1)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        case .monthly:
            AxisMarks(values: .stride(by: .month, count: 1)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.month(.abbreviated).year())
            }
        case .yearly:
            AxisMarks(values: .stride(by: .year, count: 1)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.year())
            }
        }
    }
}
