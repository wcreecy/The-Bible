import SwiftUI

struct ReadingInsightsCardView: View {
    let insights: ReadingInsights
    let formatSeconds: (Int) -> String

    private let heatColumns = Array(repeating: GridItem(.fixed(12), spacing: 3), count: 13)

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                Text("Reading Insights")
                    .font(.headline)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    metric(title: "Current goal streak", value: "\(insights.currentStreak) days")
                    metric(title: "Longest goal streak", value: "\(insights.bestStreak) days")
                    metric(title: "Goal completion", value: goalCompletionText)
                    metric(title: "Usual reading time", value: insights.consistentTimeLabel)
                }

                comparison

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Reading Days")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("Last 13 weeks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    LazyVGrid(columns: heatColumns, spacing: 3) {
                        ForEach(insights.heatMapDays) { day in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(heatColor(seconds: day.seconds))
                                .frame(width: 12, height: 12)
                                .accessibilityLabel("\(day.date.formatted(date: .abbreviated, time: .omitted)), \(formatSeconds(day.seconds))")
                        }
                    }
                    .accessibilityElement(children: .contain)
                }
            }
        }
    }

    private var goalCompletionText: String {
        guard insights.evaluatedGoalDays > 0 else { return "—" }
        let percent = Int((Double(insights.goalDaysMet) / Double(insights.evaluatedGoalDays) * 100).rounded())
        return "\(percent)% (\(insights.goalDaysMet)/\(insights.evaluatedGoalDays))"
    }

    private var comparison: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last 7 days vs previous 7")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Text(formatSeconds(insights.recentSeconds))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                Spacer()
                if let percent = insights.comparisonPercent {
                    Label("\(abs(percent))% \(percent >= 0 ? "more" : "less")", systemImage: percent >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(percent >= 0 ? Color.green : Color.orange)
                } else {
                    Text("No previous activity")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func heatColor(seconds: Int) -> Color {
        switch seconds {
        case ...0: return Color.secondary.opacity(0.12)
        case 1..<300: return Color.accentColor.opacity(0.25)
        case 300..<900: return Color.accentColor.opacity(0.45)
        case 900..<1800: return Color.accentColor.opacity(0.7)
        default: return Color.accentColor
        }
    }
}
