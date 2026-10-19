import SwiftUI

struct GameScoreboardCard: View {
    enum Style {
        case compact
        case dashboard
    }

    private var stats = GameStats.shared

    let currentCorrect: Int
    let currentAnswered: Int
    let currentStreak: Int
    let game: GameStats.GameID
    let wordMode: GameStats.WordMode?
    let style: Style

    init(
        currentCorrect: Int,
        currentAnswered: Int,
        currentStreak: Int,
        game: GameStats.GameID,
        wordMode: GameStats.WordMode? = nil,
        style: Style = .compact
    ) {
        self.currentCorrect = currentCorrect
        self.currentAnswered = currentAnswered
        self.currentStreak = currentStreak
        self.game = game
        self.wordMode = wordMode
        self.style = style
    }

    var body: some View {
        let allTime = stats.scorecardStats(for: game, wordMode: wordMode)

        switch style {
        case .compact:
            GameScoreboardCompactContent(
                currentCorrect: currentCorrect,
                currentAnswered: currentAnswered,
                currentStreak: currentStreak,
                currentAccuracy: percentString(correct: currentCorrect, answered: currentAnswered),
                allTimeCorrect: allTime.correct,
                allTimeAnswered: allTime.attempts,
                allTimeBestStreak: allTime.bestStreak,
                allTimeAccuracy: percentString(correct: allTime.correct, answered: allTime.attempts)
            )
        case .dashboard:
            dashboardScoreboard(allTime: allTime)
        }
    }

    private func dashboardScoreboard(allTime: GameStats.ScorecardStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("This Game", systemImage: "chart.bar.fill")
                    .font(.headline.weight(.bold))

                Spacer()

                Text("All time: \(allTime.correct)/\(allTime.attempts)  •  Best streak \(allTime.bestStreak)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                dashboardMetric(title: "Correct", value: "\(currentCorrect)", systemImage: "checkmark.circle.fill", tint: .green)
                dashboardMetric(title: "Attempts", value: "\(currentAnswered)", systemImage: "scope", tint: .blue)
                dashboardMetric(title: "Accuracy", value: percentString(correct: currentCorrect, answered: currentAnswered), systemImage: "percent", tint: .purple)
                dashboardMetric(title: "Streak", value: "\(currentStreak)", systemImage: "flame.fill", tint: .orange)
            }
        }
        .padding(16)
        .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous))
    }

    private func dashboardMetric(
        title: LocalizedStringKey,
        value: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)

            Text(value)
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }

    private func percentString(correct: Int, answered: Int) -> String {
        guard answered > 0 else { return "—" }
        let raw = (Double(correct) / Double(answered)) * 100.0
        let clamped = min(100.0, max(0.0, raw))
        return "\(Int(round(clamped)))%"
    }
}

private struct GameScoreboardCompactContent: View {
    let currentCorrect: Int
    let currentAnswered: Int
    let currentStreak: Int
    let currentAccuracy: String
    let allTimeCorrect: Int
    let allTimeAnswered: Int
    let allTimeBestStreak: Int
    let allTimeAccuracy: String

    var body: some View {
        VStack(spacing: 12) {
            GameScoreboardRoundSummary(
                correct: currentCorrect,
                answered: currentAnswered,
                streak: currentStreak,
                accuracy: currentAccuracy
            )

            Divider()

            GameScoreboardAllTimeSummary(
                correct: allTimeCorrect,
                answered: allTimeAnswered,
                bestStreak: allTimeBestStreak,
                accuracy: allTimeAccuracy
            )
        }
        .padding(12)
        .heroCardSurface()
    }
}

private struct GameScoreboardRoundSummary: View {
    let correct: Int
    let answered: Int
    let streak: Int
    let accuracy: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("This Round", systemImage: "play.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if answered == 0 {
                Text("No answers yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(correct) / \(answered) correct")
                        .font(.title3.weight(.bold))
                        .monospacedDigit()

                    Spacer()

                    Text("\(accuracy) accuracy")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            if streak > 0 {
                Label("\(streak) in a row", systemImage: "flame.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.orange)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct GameScoreboardAllTimeSummary: View {
    let correct: Int
    let answered: Int
    let bestStreak: Int
    let accuracy: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Label("All Time", systemImage: "trophy.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            if answered == 0 {
                Text("No answers yet")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(accuracy) accuracy · \(correct) correct")
                        .font(.footnote.weight(.medium))
                        .monospacedDigit()

                    if bestStreak > 0 {
                        Text("Best streak \(bestStreak)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    GameScoreboardCard(
        currentCorrect: 7,
        currentAnswered: 10,
        currentStreak: 9,
        game: .quiz
    )
    .padding()
}
