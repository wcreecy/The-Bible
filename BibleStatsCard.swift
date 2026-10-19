import SwiftUI

struct BibleStatsCard: View {
    let bibleVM: HomeBibleStatsViewModel
    let scenePhase: ScenePhase
    let onOpenReadingStats: () -> Void
    let onOpenGameStats: () -> Void

    @State private var todayGameSeconds = 0
    @State private var todayGameAnswered = 0
    @State private var todayGameAccuracy = 0

    var body: some View {
        HeroCard(
            title: HomeCardID.bibleStats.title,
            subtitle: "A quick look at today's reading and games",
            icon: HomeCardID.bibleStats.systemImage,
            tint: .teal,
            trailingAccessory: {
                Button(action: onOpenReadingStats) {
                    Label("See All", systemImage: "chevron.right")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.teal)
                .accessibilityLabel("See all stats")
            }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                DailyActivityTimeCard(
                    readingSeconds: bibleVM.todaySeconds,
                    gameSeconds: todayGameSeconds
                )

                ReadingActivitySummary(
                    seconds: bibleVM.todaySeconds,
                    lastReadBookChapter: bibleVM.lastReadBookChapter,
                    lastReadRelativeTime: bibleVM.lastReadRelativeTime
                )

                GameActivitySummary(
                    seconds: todayGameSeconds,
                    answered: todayGameAnswered,
                    accuracy: todayGameAccuracy
                )

                StatsDestinationButtons(
                    onOpenReadingStats: onOpenReadingStats,
                    onOpenGameStats: onOpenGameStats
                )
            }
            .onAppear {
                refreshActivity()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    refreshActivity()
                }
            }
            .onNotification(.gameStatsExternallyUpdated) {
                refreshGameActivity()
            }
        }
    }

    private func refreshActivity() {
        bibleVM.refresh()
        refreshGameActivity()
    }

    private func refreshGameActivity() {
        let gameStats = GameStats.shared.todayStats()
        todayGameSeconds = GameStats.shared.playSeconds()
        todayGameAnswered = gameStats.answered
        todayGameAccuracy = Int(gameStats.pct.rounded())
    }
}

private struct DailyActivityTimeCard: View {
    let readingSeconds: Int
    let gameSeconds: Int

    private var reading: Int { max(0, readingSeconds) }
    private var games: Int { max(0, gameSeconds) }
    private var total: Int { reading + games }
    private var readingFraction: Double {
        total > 0 ? Double(reading) / Double(total) : 0
    }
    private var gameFraction: Double {
        total > 0 ? Double(games) / Double(total) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("Today", systemImage: "chart.bar.xaxis")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text(formattedUsage(total))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                let hasBothCategories = reading > 0 && games > 0
                let spacing: CGFloat = hasBothCategories ? 3 : 0
                let availableWidth = max(0, proxy.size.width - spacing)

                HStack(spacing: spacing) {
                    if reading > 0 {
                        Rectangle()
                            .fill(Color.blue.gradient)
                            .frame(width: availableWidth * readingFraction)
                    }

                    if games > 0 {
                        Rectangle()
                            .fill(Color.indigo.gradient)
                            .frame(width: availableWidth * gameFraction)
                    }

                    if total == 0 {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.15))
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 12)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "Today. Reading (formattedUsage(reading)). Games (formattedUsage(games))."
            )

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    ActivityTimeLegend(title: "Reading", seconds: reading, tint: .blue)
                    ActivityTimeLegend(title: "Games", seconds: games, tint: .indigo)
                }
                VStack(alignment: .leading, spacing: 4) {
                    ActivityTimeLegend(title: "Reading", seconds: reading, tint: .blue)
                    ActivityTimeLegend(title: "Games", seconds: games, tint: .indigo)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.teal.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.teal.opacity(0.2), lineWidth: 1)
        )
    }

    private func formattedUsage(_ seconds: Int) -> String {
        let safeSeconds = max(0, seconds)
        if safeSeconds < 60 {
            return "\(safeSeconds)s"
        }

        let hours = safeSeconds / 3_600
        let minutes = (safeSeconds % 3_600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}

private struct ReadingActivitySummary: View {
    let seconds: Int
    let lastReadBookChapter: String
    let lastReadRelativeTime: String

    var body: some View {
        ActivitySummaryRow(
            title: "Reading",
            detail: seconds > 0 ? "\(formattedUsage(seconds)) today" : "No reading time yet",
            context: lastReadBookChapter == "—"
                ? nil
                : "Last read \(lastReadBookChapter) \(lastReadRelativeTime)",
            systemImage: "book.pages",
            tint: .blue
        )
    }

    private func formattedUsage(_ seconds: Int) -> String {
        let safeSeconds = max(0, seconds)
        if safeSeconds < 60 {
            return "\(safeSeconds)s"
        }

        let hours = safeSeconds / 3_600
        let minutes = (safeSeconds % 3_600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}

private struct GameActivitySummary: View {
    let seconds: Int
    let answered: Int
    let accuracy: Int

    var body: some View {
        ActivitySummaryRow(
            title: "Games",
            detail: answered > 0
                ? "\(answered) answers · \(accuracy)% correct"
                : "No answers yet",
            context: seconds > 0 ? "\(formattedUsage(seconds)) played" : nil,
            systemImage: "gamecontroller",
            tint: .indigo
        )
    }

    private func formattedUsage(_ seconds: Int) -> String {
        let safeSeconds = max(0, seconds)
        if safeSeconds < 60 {
            return "\(safeSeconds)s"
        }

        let hours = safeSeconds / 3_600
        let minutes = (safeSeconds % 3_600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}

private struct ActivitySummaryRow: View {
    let title: LocalizedStringResource
    let detail: String
    let context: String?
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let context {
                    Text(context)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .accessibilityElement(children: .combine)
    }
}

private struct StatsDestinationButtons: View {
    let onOpenReadingStats: () -> Void
    let onOpenGameStats: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                readingButton
                gameButton
            }
            VStack(spacing: 10) {
                readingButton
                gameButton
            }
        }
    }

    private var readingButton: some View {
        Button(action: onOpenReadingStats) {
            Label("Reading Stats", systemImage: "book.pages")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .heroCardSurface()
        }
        .buttonStyle(.plain)
    }

    private var gameButton: some View {
        Button(action: onOpenGameStats) {
            Label("Game Stats", systemImage: "gamecontroller")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .heroCardSurface()
        }
        .buttonStyle(.plain)
    }
}

private struct ActivityTimeLegend: View {
    let title: LocalizedStringResource
    let seconds: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(formattedUsage)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formattedUsage: String {
        let safeSeconds = max(0, seconds)
        if safeSeconds < 60 {
            return "\(safeSeconds)s"
        }

        let hours = safeSeconds / 3_600
        let minutes = (safeSeconds % 3_600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}
