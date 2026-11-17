import SwiftUI

struct WeeklyReadingSummaryCard: View {
    let thisWeekSeconds: Int
    let lastWeekSeconds: Int
    let activeDays: Int
    let topBook: String?
    let formatSeconds: (Int) -> String

    private var weekSeconds: Int { max(0, thisWeekSeconds) }
    private var previousWeekSeconds: Int { max(0, lastWeekSeconds) }
    private var comparisonPercent: Int? {
        ReadingInsights.comparisonPercent(recent: weekSeconds, previous: previousWeekSeconds)
    }

    var body: some View {
        HeroCard(
            title: "Your Week",
            subtitle: "Your last 7 days of reading",
            icon: "sparkles",
            tint: .teal
        ) {
            VStack(alignment: .leading, spacing: 14) {
                summaryHeadline

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        activeDaysMetric
                        topBookMetric
                        comparisonMetric
                    }

                    VStack(spacing: 10) {
                        activeDaysMetric
                        topBookMetric
                        comparisonMetric
                    }
                }
            }
        }
    }

    private var summaryHeadline: some View {
        VStack(alignment: .leading, spacing: 4) {
            if weekSeconds > 0 {
                Text("You read \(formatSeconds(weekSeconds)) in the last 7 days.")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()

                Text(headlineDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Your reading week starts with one session.")
                    .font(.title3.weight(.bold))

                Text("Open the Bible to begin building your weekly picture.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var activeDaysMetric: some View {
        WeeklyReadingMetric(
            title: "Active Days",
            value: "\(activeDays)",
            detail: "of the last 7 days",
            systemImage: "calendar",
            tint: .blue
        )
    }

    private var topBookMetric: some View {
        WeeklyReadingMetric(
            title: "Most Read",
            value: topBook ?? "—",
            detail: topBook == nil ? "Keep reading to see it" : "last 7 days",
            systemImage: "book.closed.fill",
            tint: .orange
        )
    }

    private var comparisonMetric: some View {
        let comparison = comparisonPercent

        return WeeklyReadingMetric(
            title: "Vs. Previous 7 Days",
            value: comparisonValue(for: comparison),
            detail: comparisonDetail(for: comparison),
            systemImage: comparisonSystemImage(for: comparison),
            tint: comparisonTint(for: comparison)
        )
    }

    private var headlineDetail: String {
        guard let topBook else {
            return "Keep reading to discover your most-read book."
        }

        return "You spent the most time in \(topBook)."
    }

    private func comparisonValue(for comparison: Int?) -> String {
        guard let comparison else { return "—" }
        return comparison == 0 ? "Even" : "\(abs(comparison))%"
    }

    private func comparisonDetail(for comparison: Int?) -> String {
        guard let comparison else { return "No previous activity" }
        if comparison == 0 { return "same as before" }
        return comparison > 0 ? "more reading" : "less reading"
    }

    private func comparisonSystemImage(for comparison: Int?) -> String {
        guard let comparison else { return "minus" }
        if comparison == 0 { return "equal" }
        return comparison > 0 ? "arrow.up.right" : "arrow.down.right"
    }

    private func comparisonTint(for comparison: Int?) -> Color {
        guard let comparison else { return .secondary }
        if comparison == 0 { return .teal }
        return comparison > 0 ? .green : .orange
    }
}

private struct WeeklyReadingMetric: View {
    let title: LocalizedStringResource
    let value: String
    let detail: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)

            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(minWidth: 96, maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .accessibilityElement(children: .combine)
    }
}
