import SwiftUI
import Charts

/// Average reading session length over the last 7 days, shown inside the Reading Insights card.
struct AverageSessionSection: View {
    let dailyAverages: [(date: Date, seconds: Int)]
    let avgSessionSeconds: Int
    let formatSeconds: (Int) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Average Session Length")
                        .font(.subheadline.weight(.semibold))
                    Text("Daily averages for active days · Sessions ≥ 1 min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("7-day average")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatSeconds(avgSessionSeconds))
                        .font(.subheadline)
                        .monospacedDigit()
                }
            }

            if !dailyAverages.isEmpty {
                Chart {
                    ForEach(dailyAverages, id: \.date) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Average minutes", Double(point.seconds) / 60.0)
                        )
                        .foregroundStyle(.teal)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Average minutes", Double(point.seconds) / 60.0)
                        )
                        .foregroundStyle(.teal)
                        .symbolSize(45)
                    }
                }
                .chartYScale(domain: 0...max(1, maxMinutes * 1.1))
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                .chartYAxisLabel("Minutes")
                .chartXAxisLabel("Date")
                .frame(height: 180)
            } else {
                ContentUnavailableView("No recent sessions", systemImage: "chart.line.uptrend.xyaxis")
            }
        }
    }

    private var maxMinutes: Double {
        guard !dailyAverages.isEmpty else { return 0 }
        return dailyAverages.map { Double(max(0, $0.seconds)) / 60.0 }.max() ?? 0
    }
}
