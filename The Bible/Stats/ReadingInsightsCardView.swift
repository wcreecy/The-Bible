import SwiftUI

struct ReadingInsightsCardView: View {
    let insights: ReadingInsights
    /// Average session length per active day over the last 7 days.
    let dailyAverageSessions: [(date: Date, seconds: Int)]
    let averageSessionSeconds: Int
    let formatSeconds: (Int) -> String

    var body: some View {
        // Which days had reading lives in the Reading History card, so this one sticks to
        // the numbers.
        HeroCard(title: "Reading Insights", icon: "lightbulb", tint: .yellow) {
            VStack(alignment: .leading, spacing: 14) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    metric(title: "Goal streak", value: dayCount(insights.currentStreak),
                           accessibilityTitle: "Current goal streak")
                    metric(title: "Best streak", value: dayCount(insights.bestStreak),
                           accessibilityTitle: "Longest goal streak")
                    metric(title: "Goals met", value: goalCompletionText,
                           accessibilityTitle: "Daily goals met in the last 30 days")
                    metric(title: "Usual time", value: insights.consistentTimeLabel,
                           accessibilityTitle: "Usual reading time")
                }

                Divider()

                AverageSessionSection(
                    dailyAverages: dailyAverageSessions,
                    avgSessionSeconds: averageSessionSeconds,
                    formatSeconds: formatSeconds
                )
            }
        }
    }

    private func dayCount(_ days: Int) -> String {
        days == 1 ? "1 day" : "\(days) days"
    }

    private var goalCompletionText: String {
        guard insights.evaluatedGoalDays > 0 else { return "—" }
        let percent = Int((Double(insights.goalDaysMet) / Double(insights.evaluatedGoalDays) * 100).rounded())
        return "\(percent)% (\(insights.goalDaysMet)/\(insights.evaluatedGoalDays))"
    }

    /// A short label over its value. `accessibilityTitle` is the full name VoiceOver reads.
    private func metric(title: String, value: String, accessibilityTitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(accessibilityTitle): \(value)")
    }
}
