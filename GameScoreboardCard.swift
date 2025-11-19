import SwiftUI

public struct GameScoreboardCard: View {
    // Current session (live)
    let currentCorrect: Int
    let currentAnswered: Int
    let currentStreak: Int
    // All-time
    let allTimeCorrect: Int
    let allTimeAnswered: Int
    let allTimeBestStreak: Int

    public init(
        currentCorrect: Int,
        currentAnswered: Int,
        currentStreak: Int,
        allTimeCorrect: Int,
        allTimeAnswered: Int,
        allTimeBestStreak: Int
    ) {
        self.currentCorrect = currentCorrect
        self.currentAnswered = currentAnswered
        self.currentStreak = currentStreak
        self.allTimeCorrect = allTimeCorrect
        self.allTimeAnswered = allTimeAnswered
        self.allTimeBestStreak = allTimeBestStreak
    }

    public var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: 12) {
                // Current session stats
                HStack(spacing: 10) {
                    Text("Current")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .leading)
                    statPill(title: "Correct", value: "\(currentCorrect)")
                    statPill(title: "Total", value: "\(currentAnswered)")
                    streakPill(title: "Streak", current: currentStreak, allTimeBest: allTimeBestStreak)
                    statPill(title: "Percent", value: percentString(correct: currentCorrect, answered: currentAnswered))
                }
                // All-time stats
                HStack(spacing: 10) {
                    Text("All-time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .leading)
                    statPill(title: "Correct", value: "\(allTimeCorrect)")
                    statPill(title: "Total", value: "\(allTimeAnswered)")
                    statPill(title: "Streak", value: "\(allTimeBestStreak)")
                    statPill(title: "Percent", value: percentString(correct: allTimeCorrect, answered: allTimeAnswered))
                }
            }
            .padding(8)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(UIColor.systemBackground), Color(UIColor.secondarySystemBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    // Neutral stat pill (no per-category color)
    @ViewBuilder
    private func statPill(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // Current streak pill with special green highlight when tying/exceeding all-time best streak
    @ViewBuilder
    private func streakPill(title: String, current: Int, allTimeBest: Int) -> some View {
        let highlightThreshold = max(1, allTimeBest)
        let isHighlighted = current >= highlightThreshold
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(current)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isHighlighted ? Color.green : Color.primary)
                .animation(.default, value: isHighlighted)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .accessibilityHint(isHighlighted ? "Tied or exceeded all-time best streak" : "")
    }

    private func percentString(correct: Int, answered: Int) -> String {
        guard answered > 0 else { return "0%" }
        let pct = Int(round((Double(correct) / Double(answered)) * 100.0))
        return "\(pct)%"
    }
}

#Preview {
    VStack(spacing: 20) {
        GameScoreboardCard(
            currentCorrect: 7,
            currentAnswered: 10,
            currentStreak: 9,
            allTimeCorrect: 120,
            allTimeAnswered: 200,
            allTimeBestStreak: 9
        )
        .padding()
    }
}
