import SwiftUI

public struct GameScoreboardCard: View {
    // Current session
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
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .leading)
                    statPill(title: "Correct", value: "\(currentCorrect)", tint: .blue)
                    statPill(title: "Total", value: "\(currentAnswered)", tint: .orange)
                    statPill(title: "Streak", value: "\(currentStreak)", tint: .green)
                    statPill(title: "Percent", value: percentString(correct: currentCorrect, answered: currentAnswered), tint: .purple)
                }
                // All-time stats
                HStack(spacing: 10) {
                    Text("All-time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .leading)
                    statPill(title: "Correct", value: "\(allTimeCorrect)", tint: .blue)
                    statPill(title: "Total", value: "\(allTimeAnswered)", tint: .orange)
                    statPill(title: "Streak", value: "\(allTimeBestStreak)", tint: .green)
                    statPill(title: "Percent", value: percentString(correct: allTimeCorrect, answered: allTimeAnswered), tint: .purple)
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

    @ViewBuilder
    private func statPill(title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(tint)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.12))
        )
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
            currentStreak: 3,
            allTimeCorrect: 120,
            allTimeAnswered: 200,
            allTimeBestStreak: 9
        )
        .padding()
    }
}
