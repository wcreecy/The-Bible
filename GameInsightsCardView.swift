import SwiftUI

struct GameInsightsCardView: View {
    @ObservedObject private var stats = GameStats.shared

    private var entries: [GameStats.GameBreakdown.Entry] {
        stats.breakdownSnapshot().entries
    }

    private var playedEntries: [GameStats.GameBreakdown.Entry] {
        entries.filter { $0.answered > 0 }
    }

    private var favoriteGame: String? {
        playedEntries.max { $0.answered < $1.answered }?.name
    }

    private var suggestedGame: String? {
        entries.min {
            if $0.answered == $1.answered { return $0.name < $1.name }
            return $0.answered < $1.answered
        }?.name
    }

    private var mostImproved: (name: String, delta: Int)? {
        entries.compactMap { entry -> (String, Int)? in
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

    private var nextMilestone: (remaining: Int, target: Int) {
        let correct = stats.breakdownSnapshot().totalCorrect
        let target = max(25, ((correct / 25) + 1) * 25)
        return (target - correct, target)
    }

    private var dailyChallenge: String {
        let challenges = [
            "Get 5 correct answers in any game.",
            "Try a game you have played the least.",
            "Play 3 different games.",
            "Earn 80% accuracy across 10 attempts.",
            "Improve your best streak by one."
        ]
        let day = Calendar.autoupdatingCurrent.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return challenges[day % challenges.count]
    }

    private var activity: [(date: Date, answered: Int, correct: Int)] {
        stats.dailySeriesLast(days: 84)
    }

    private var earnedBadges: [(String, String)] {
        let snapshot = stats.breakdownSnapshot()
        let streak = stats.activityStreaks().longest
        var badges: [(String, String)] = []
        if snapshot.totalAnswered >= 10 { badges.append(("gamecontroller.fill", "Getting Started")) }
        if snapshot.totalCorrect >= 100 { badges.append(("star.fill", "Century")) }
        if streak >= 7 { badges.append(("flame.fill", "Seven-Day Streak")) }
        if entries.allSatisfy({ $0.answered > 0 }) { badges.append(("square.grid.2x2.fill", "Well Rounded")) }
        return badges
    }

    var body: some View {
        HeroCard(title: "Game Insights", icon: "sparkles", tint: .purple) {
            let _ = stats.version
            VStack(alignment: .leading, spacing: 16) {
                MetricChip(
                    title: "Next Milestone",
                    value: "\(nextMilestone.remaining) correct \(nextMilestone.remaining == 1 ? "answer" : "answers") to reach \(nextMilestone.target)",
                    tint: .orange,
                    fillsWidth: true,
                    scrollsValue: true
                )

                insightRow(icon: "scope", title: "Daily Challenge", detail: dailyChallenge)
                if let favoriteGame {
                    insightRow(icon: "heart.fill", title: "Favorite Game", detail: favoriteGame)
                }
                if let suggestedGame {
                    insightRow(icon: "shuffle", title: "Try Something Different", detail: suggestedGame)
                }
                if let mostImproved {
                    insightRow(icon: "chart.line.uptrend.xyaxis", title: "Most Improved", detail: "\(mostImproved.name) (+\(mostImproved.delta) pts)")
                }

                let streak = stats.activityStreaks()
                if streak.current > 0, activity.last?.answered == 0 {
                    insightRow(icon: "flame", title: "Streak Grace", detail: "Play today to keep your \(streak.current)-day streak going.")
                }

                activityHeatMap
                masterySection
                difficultySection
                badgeSection
            }
        }
    }

    private var activityHeatMap: some View {
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

    private var masterySection: some View {
        let mastery = stats.bookMastery()
        return VStack(alignment: .leading, spacing: 6) {
            Text("Book Mastery")
                .font(.subheadline.weight(.semibold))
            if mastery.isEmpty {
                Text("Answer at least 5 Quiz or Verse Match questions for a book to see mastery.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(mastery.prefix(3)), id: \.book) { item in
                    insightRow(icon: "book.closed.fill", title: item.book, detail: "\(Int(item.pct.rounded()))% · \(item.answered) attempts")
                }
            }
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

    private var badgeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Badges")
                .font(.subheadline.weight(.semibold))
            if earnedBadges.isEmpty {
                Text("Your first badge unlocks after 10 attempts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(earnedBadges, id: \.1) { badge in
                        Label(badge.1, systemImage: badge.0)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.purple.opacity(0.1), in: Capsule())
                    }
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
