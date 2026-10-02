import SwiftUI
import Charts

struct AverageSessionCardView: View {
    let title: String
    let dailyAverages: [(date: Date, seconds: Int)]
    let avgSessionSeconds: Int
    let formatSeconds: (Int) -> String

    init(
        title: String = "Average Session Length",
        dailyAverages: [(date: Date, seconds: Int)],
        avgSessionSeconds: Int,
        formatSeconds: @escaping (Int) -> String
    ) {
        self.title = title
        self.dailyAverages = dailyAverages
        self.avgSessionSeconds = avgSessionSeconds
        self.formatSeconds = formatSeconds
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
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
    }

    private var maxMinutes: Double {
        guard !dailyAverages.isEmpty else { return 0 }
        return dailyAverages.map { Double(max(0, $0.seconds)) / 60.0 }.max() ?? 0
    }
}
