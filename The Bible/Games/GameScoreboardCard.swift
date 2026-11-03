import SwiftUI

struct GameScoreboardCard: View {
    enum Style {
        case compact
        case dashboard
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
        switch style {
        case .compact:
            GameScoreboardCompactContent(
                currentCorrect: currentCorrect,
                currentAnswered: currentAnswered,
                currentStreak: currentStreak,
                currentAccuracy: percentString(correct: currentCorrect, answered: currentAnswered)
            )
        case .dashboard:
            dashboardScoreboard(
                allTime: stats.scorecardStats(for: game, wordMode: wordMode)
            )
        }
    }

    private func dashboardScoreboard(allTime: GameStats.ScorecardStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    dashboardTitle
                    Spacer()
                    allTimeSummary(allTime)
                }

                VStack(alignment: .leading, spacing: 4) {
                    dashboardTitle
                    allTimeSummary(allTime)
                }
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    dashboardMetric(title: "Correct", value: "\(currentCorrect)", systemImage: "checkmark.circle.fill", tint: .green)
                    dashboardMetric(title: "Attempts", value: "\(currentAnswered)", systemImage: "scope", tint: .blue)
                    dashboardMetric(title: "Accuracy", value: percentString(correct: currentCorrect, answered: currentAnswered), systemImage: "percent", tint: .purple)
                    dashboardMetric(title: "Streak", value: "\(currentStreak)", systemImage: "flame.fill", tint: .orange)
                }
            } else {
                HStack(spacing: 10) {
                    dashboardMetric(title: "Correct", value: "\(currentCorrect)", systemImage: "checkmark.circle.fill", tint: .green)
                    dashboardMetric(title: "Attempts", value: "\(currentAnswered)", systemImage: "scope", tint: .blue)
                    dashboardMetric(title: "Accuracy", value: percentString(correct: currentCorrect, answered: currentAnswered), systemImage: "percent", tint: .purple)
                    dashboardMetric(title: "Streak", value: "\(currentStreak)", systemImage: "flame.fill", tint: .orange)
                }
            }
        }
        .padding(16)
        .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous))
    }

    private var dashboardTitle: some View {
        Label("This Game", systemImage: "chart.bar.fill")
            .font(.headline.weight(.bold))
    }

    private func allTimeSummary(_ allTime: GameStats.ScorecardStats) -> some View {
        Text("All time: \(allTime.correct)/\(allTime.attempts)  •  Best streak \(allTime.bestStreak)")
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
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

    var body: some View {
        HStack(spacing: 14) {
            if currentAnswered == 0 {
                Label("No answers yet", systemImage: "play.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            } else {
                Label {
                    Text("\(currentCorrect) / \(currentAnswered)")
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                .font(.headline.weight(.bold))

                Spacer(minLength: 0)

                Label(currentAccuracy, systemImage: "percent")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if currentStreak > 0 {
                Label("\(currentStreak)", systemImage: "flame.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .heroCardSurface()
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
