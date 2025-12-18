import SwiftUI
import Charts

struct AverageSessionCardView: View {
    let title: String
    let sessionsSeries: [(index: Int, minutes: Int)]
    let avgSessionSeconds: Int
    let formatSeconds: (Int) -> String

    init(
        title: String = "Average Session Length",
        sessionsSeries: [(index: Int, minutes: Int)],
        avgSessionSeconds: Int,
        formatSeconds: @escaping (Int) -> String
    ) {
        self.title = title
        self.sessionsSeries = sessionsSeries
        self.avgSessionSeconds = avgSessionSeconds
        self.formatSeconds = formatSeconds
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Text("Avg (last 7 days): \(formatSeconds(avgSessionSeconds))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                if !sessionsSeries.isEmpty {
                    Chart {
                        ForEach(sessionsSeries, id: \.index) { point in
                            LineMark(
                                x: .value("Session", point.index),
                                y: .value("Minutes", point.minutes)
                            )
                            .foregroundStyle(.teal)
                            PointMark(
                                x: .value("Session", point.index),
                                y: .value("Minutes", point.minutes)
                            )
                            .foregroundStyle(.teal)
                        }
                    }
                    // Ensure a non-zero y-domain even when all points are zero
                    .chartYScale(domain: 0...max(1, maxMinutes))
                    .chartYAxisLabel("Minutes")
                    .chartXAxisLabel("Sessions")
                    .frame(height: 180)
                } else {
                    ContentUnavailableView("No recent sessions", systemImage: "chart.line.uptrend.xyaxis")
                }
            }
        }
    }

    private var maxMinutes: Int {
        guard !sessionsSeries.isEmpty else { return 0 }
        return sessionsSeries.map { max(0, $0.minutes) }.max() ?? 0
    }
}
