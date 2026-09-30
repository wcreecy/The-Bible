import SwiftUI

struct GameScoreboardCard: View {
    @ObservedObject private var stats = GameStats.shared

    let currentCorrect: Int
    let currentAnswered: Int
    let currentStreak: Int
    let game: GameStats.GameID
    let wordMode: GameStats.WordMode?

    init(
        currentCorrect: Int,
        currentAnswered: Int,
        currentStreak: Int,
        game: GameStats.GameID,
        wordMode: GameStats.WordMode? = nil
    ) {
        self.currentCorrect = currentCorrect
        self.currentAnswered = currentAnswered
        self.currentStreak = currentStreak
        self.game = game
        self.wordMode = wordMode
    }

    var body: some View {
        let allTime = stats.scorecardStats(for: game, wordMode: wordMode)

        VStack(spacing: 14) {
            scoreSection(
                title: "This Game",
                systemImage: "play.circle.fill",
                correct: currentCorrect,
                attempts: currentAnswered,
                streak: currentStreak,
                percent: percentString(correct: currentCorrect, answered: currentAnswered),
                highlightedStreak: currentStreak >= max(1, allTime.bestStreak)
            )

            Divider()

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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
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
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                stat(title: "Correct", value: "\(correct)")

                metricDivider

                stat(title: "Attempts", value: "\(attempts)")

                metricDivider

                stat(
                    title: "Streak",
                    value: usesPlaceholderForEmptyStreak && streak == 0 ? "—" : "\(streak)",
                    valueColor: highlightedStreak ? .green : .primary
                )

                metricDivider

                stat(title: "Percent", value: percent)
            }
        }
    }

    private func stat(
        title: LocalizedStringKey,
        value: String,
        valueColor: Color = .primary
    ) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var metricDivider: some View {
        Divider()
            .frame(height: 34)
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
