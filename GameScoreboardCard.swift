import SwiftUI

struct GameScoreboardCard: View {
    enum Style {
        case compact
        case dashboard
    }

    @ObservedObject private var stats = GameStats.shared

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

        if style == .dashboard {
            dashboardScoreboard(allTime: allTime)
        } else {
            compactScoreboard(allTime: allTime)
        }
    }

    private func compactScoreboard(allTime: GameStats.ScorecardStats) -> some View {
        VStack(spacing: 0) {
            scoreSection(
                title: "This Game",
                systemImage: "play.fill",
                correct: currentCorrect,
                attempts: currentAnswered,
                streak: currentStreak,
                percent: percentString(correct: currentCorrect, answered: currentAnswered),
                highlightedStreak: currentStreak >= max(1, allTime.bestStreak)
            )

            Divider()
                .padding(.leading, 32)

            scoreSection(
                title: "All Time",
                systemImage: "trophy.fill",
                correct: allTime.correct,
                attempts: allTime.attempts,
                streak: allTime.bestStreak,
                percent: percentString(correct: allTime.correct, answered: allTime.attempts),
                usesPlaceholderForEmptyStreak: true
            )
        }
        .padding(.horizontal, 12)
        .heroCardSurface()
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
                .minimumScaleFactor(0.7)

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

    private func scoreSection(
        title: LocalizedStringKey,
        systemImage: String,
        correct: Int,
        attempts: Int,
        streak: Int,
        percent: String,
        highlightedStreak: Bool = false,
        usesPlaceholderForEmptyStreak: Bool = false
    ) -> some View {
        HStack(spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .labelStyle(.iconOnly)
                .frame(width: 20)
                .accessibilityLabel(title)

            stat(title: "Correct", value: "\(correct)")

            stat(title: "Attempts", value: "\(attempts)")

            stat(
                title: "Streak",
                value: usesPlaceholderForEmptyStreak && streak == 0 ? "—" : "\(streak)",
                valueColor: highlightedStreak ? .green : .primary
            )

            stat(title: "Percent", value: percent)
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private func stat(
        title: LocalizedStringKey,
        value: String,
        valueColor: Color = .primary
    ) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.headline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func percentString(correct: Int, answered: Int) -> String {
        guard answered > 0 else { return "—" }
        let raw = (Double(correct) / Double(answered)) * 100.0
        let clamped = min(100.0, max(0.0, raw))
        return "\(Int(round(clamped)))%"
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
