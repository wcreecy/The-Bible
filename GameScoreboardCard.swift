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
