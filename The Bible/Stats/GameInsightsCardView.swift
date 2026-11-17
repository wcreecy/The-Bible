import SwiftUI

struct GameInsightsCardView: View {
    private var stats = GameStats.shared

    // Each insight reads from one breakdown and one activity series per redraw, instead of
    // asking GameStats for its own copy.

    private func favoriteGame(in entries: [GameStats.GameBreakdown.Entry]) -> String? {
        entries.filter { $0.answered > 0 }.max { $0.answered < $1.answered }?.name
    }

    private func suggestedGame(in entries: [GameStats.GameBreakdown.Entry]) -> String? {
        entries.min {
            if $0.answered == $1.answered { return $0.name < $1.name }
            return $0.answered < $1.answered
        }?.name
    }

    /// Only games played at least 5 times in each of the last two weeks can be compared.
    private func mostImproved(in entries: [GameStats.GameBreakdown.Entry]) -> (name: String, delta: Int)? {
        entries.filter { $0.answered >= 10 }.compactMap { entry -> (String, Int)? in
            let series = stats.dailySeriesLast(days: 14, forDisplayName: entry.name)
            let previous = series.prefix(7)
            let current = series.suffix(7)
            let previousAttempts = previous.reduce(0) { $0 + $1.answered }
            let currentAttempts = current.reduce(0) { $0 + $1.answered }
            guard previousAttempts >= 5, currentAttempts >= 5 else { return nil }
            let previousAccuracy = Double(previous.reduce(0) { $0 + $1.correct }) / Double(previousAttempts) * 100
            let currentAccuracy = Double(current.reduce(0) { $0 + $1.correct }) / Double(currentAttempts) * 100
            return (entry.name, Int((currentAccuracy - previousAccuracy).rounded()))
        }
        .filter { $0.1 > 0 }
        .max { $0.1 < $1.1 }
    }

    private func nextMilestone(totalCorrect correct: Int) -> (remaining: Int, target: Int) {
        let target = max(25, ((correct / 25) + 1) * 25)
        return (target - correct, target)
    }

    var body: some View {
        HeroCard(title: "Game Insights", icon: "sparkles", tint: .purple) {
            let _ = stats.version
            let breakdown = stats.breakdownSnapshot()
            let entries = breakdown.entries
            let activity = stats.dailySeriesLast(days: 84)
            let milestone = nextMilestone(totalCorrect: breakdown.totalCorrect)
            VStack(alignment: .leading, spacing: 16) {
                MetricChip(
                    title: "Next Milestone",
                    value: "\(milestone.remaining) correct \(milestone.remaining == 1 ? "answer" : "answers") to reach \(milestone.target)",
                    tint: .orange,
                    fillsWidth: true,
                    scrollsValue: true
                )

                if let favoriteGame = favoriteGame(in: entries) {
                    insightRow(icon: "heart.fill", title: "Favorite Game", detail: favoriteGame)
                }
                if let suggestedGame = suggestedGame(in: entries) {
                    insightRow(icon: "shuffle", title: "Try Something Different", detail: suggestedGame)
                }
                if let mostImproved = mostImproved(in: entries) {
                    insightRow(icon: "chart.line.uptrend.xyaxis", title: "Most Improved", detail: "\(mostImproved.name) (+\(mostImproved.delta) pts)")
                }

                let streak = stats.activityStreaks()
                if streak.current > 0, activity.last?.answered == 0 {
                    insightRow(icon: "flame", title: "Streak Grace", detail: "Play today to keep your \(streak.current)-day streak going.")
                }

                activityHeatMap(activity)
                difficultySection
            }
        }
    }

    private func activityHeatMap(_ activity: [(date: Date, answered: Int, correct: Int)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Game Activity · 12 Weeks")
                .font(.subheadline.weight(.semibold))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 14), spacing: 4) {
                ForEach(activity, id: \.date) { day in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(heatColor(for: day.answered))
                        .aspectRatio(1, contentMode: .fit)
                        .accessibilityLabel(day.date.formatted(date: .abbreviated, time: .omitted))
                        .accessibilityValue("\(day.answered) attempts")
                }
            }
            Text("Darker squares mean more attempts.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var difficultySection: some View {
        let rows = stats.accuracyByDifficulty().filter { $0.answered > 0 }
        return VStack(alignment: .leading, spacing: 6) {
            Text("Accuracy by Difficulty")
                .font(.subheadline.weight(.semibold))
            if rows.isEmpty {
                Text("Difficulty insights appear after you play.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rows, id: \.difficulty) { row in
                    insightRow(icon: "gauge.with.dots.needle.50percent", title: row.difficulty, detail: "\(Int(row.pct.rounded()))% · \(row.answered) attempts")
                }
            }
        }
    }

    private func insightRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.purple)
                .frame(width: 18)
            Text(title)
                .font(.caption.weight(.semibold))
            Spacer(minLength: 8)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func heatColor(for attempts: Int) -> Color {
        switch attempts {
        case 0: return Color.secondary.opacity(0.12)
        case 1...2: return Color.purple.opacity(0.3)
        case 3...5: return Color.purple.opacity(0.55)
        case 6...9: return Color.purple.opacity(0.75)
        default: return .purple
        }
    }
}
