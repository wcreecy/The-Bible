import SwiftUI

struct GameWeekSummaryCardView: View {
    private struct StrongestGame {
        let name: String
        let answered: Int
        let accuracy: Int
    }

    private let stats = GameStats.shared

    private var thisWeek: (answered: Int, correct: Int) {
        let series = stats.dailySeriesLast(days: 7)
        return (
            series.reduce(0) { $0 + $1.answered },
            series.reduce(0) { $0 + $1.correct }
        )
    }

    private var previousWeekAnswered: Int {
        stats.dailySeriesLast(days: 14)
            .prefix(7)
            .reduce(0) { $0 + $1.answered }
    }

    private var thisWeekAccuracy: Int {
        guard thisWeek.answered > 0 else { return 0 }
        return Int((Double(thisWeek.correct) / Double(thisWeek.answered) * 100).rounded())
    }

    private var momentumPercent: Int? {
        guard previousWeekAnswered > 0 else {
            return thisWeek.answered > 0 ? 100 : nil
        }

        return Int(
            ((Double(thisWeek.answered - previousWeekAnswered) / Double(previousWeekAnswered)) * 100)
                .rounded()
        )
    }

    private var strongestGame: StrongestGame? {
        stats.breakdownSnapshot().entries.compactMap { entry in
            let series = stats.dailySeriesLast(days: 7, forDisplayName: entry.name)
            let answered = series.reduce(0) { $0 + $1.answered }
            let correct = series.reduce(0) { $0 + $1.correct }
            guard answered >= 3 else { return nil }

            return StrongestGame(
                name: entry.name,
                answered: answered,
                accuracy: Int((Double(correct) / Double(answered) * 100).rounded())
            )
        }
        .max { lhs, rhs in
            if lhs.accuracy == rhs.accuracy {
                return lhs.answered < rhs.answered
            }
            return lhs.accuracy < rhs.accuracy
        }
    }

    var body: some View {
        HeroCard(
            title: "Your Game Week",
            subtitle: "Recent activity and momentum",
            icon: "sparkles",
            tint: .purple
        ) {
            let _ = stats.version
            let today = stats.todayStats()
            let streak = stats.activityStreaks().current

            VStack(alignment: .leading, spacing: 14) {
                headline

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        GameWeekMetric(
                            title: "Today",
                            value: "\(today.correct) correct",
                            detail: today.answered == 0
                                ? "answers"
                                : "of \(today.answered) answers · \(Int(today.pct.rounded()))% accuracy",
                            systemImage: "calendar",
                            tint: .blue
                        )

                        strongestGameMetric

                        GameWeekMetric(
                            title: "Activity Streak",
                            value: "\(streak)",
                            detail: streak == 1 ? "day" : "days",
                            systemImage: "flame.fill",
                            tint: .orange
                        )
                    }

                    VStack(spacing: 10) {
                        GameWeekMetric(
                            title: "Today",
                            value: "\(today.correct) correct",
                            detail: today.answered == 0
                                ? "answers"
                                : "of \(today.answered) answers · \(Int(today.pct.rounded()))% accuracy",
                            systemImage: "calendar",
                            tint: .blue
                        )

                        strongestGameMetric

                        GameWeekMetric(
                            title: "Activity Streak",
                            value: "\(streak)",
                            detail: streak == 1 ? "day" : "days",
                            systemImage: "flame.fill",
                            tint: .orange
                        )
                    }
                }
            }
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 4) {
            if thisWeek.answered > 0 {
                Text("You answered \(thisWeek.answered) questions at \(thisWeekAccuracy)% accuracy this week.")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()

                Text(momentumDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Your game week starts with one round.")
                    .font(.title3.weight(.bold))

                Text("Play any game to begin building your weekly picture.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var strongestGameMetric: GameWeekMetric {
        if let strongestGame {
            return GameWeekMetric(
                title: "Strongest Game",
                value: strongestGame.name,
                detail: "\(strongestGame.accuracy)% correct in \(strongestGame.answered) answers",
                systemImage: "trophy.fill",
                tint: .green
            )
        }

        return GameWeekMetric(
            title: "Strongest Game",
            value: "—",
            detail: "Play 3 answers to see it",
            systemImage: "trophy.fill",
            tint: .green
        )
    }

    private var momentumDetail: String {
        guard let momentumPercent else {
            return "No previous week to compare yet."
        }

        if momentumPercent == 0 {
            return "You matched last week's pace."
        }

        if momentumPercent > 0 {
            return "That's \(momentumPercent)% more activity than last week."
        }

        return "That's \(abs(momentumPercent))% less activity than last week."
    }
}

private struct GameWeekMetric: View {
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
                .minimumScaleFactor(0.7)

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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
