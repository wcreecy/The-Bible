import SwiftUI

struct BibleStatsCard: View {
    let bibleVM: HomeBibleStatsViewModel
    let scenePhase: ScenePhase
    let onOpenReadingStats: () -> Void
    let onOpenGameStats: () -> Void

    @ObservedObject private var gameStats = GameStats.shared
    @AppStorage("dailyUsageReadingSeconds") private var readingUsageSeconds: Int = 0
    @AppStorage("dailyUsageGameSeconds") private var gameUsageSeconds: Int = 0

    private func statTile(
        title: String,
        value: String,
        subtitle: String? = nil,
        systemImage: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(0.24), lineWidth: 1)
        )
    }

    private func contextRow(
        systemImage: String,
        title: String,
        detail: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 18)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 4)

            Text(detail)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.07))
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

    private func usageBreakdown(readingSeconds: Int, gameSeconds: Int) -> some View {
        let reading = max(0, readingSeconds)
        let games = max(0, gameSeconds)
        let total = reading + games
        let readingFraction = total > 0 ? Double(reading) / Double(total) : 0
        let gameFraction = total > 0 ? Double(games) / Double(total) : 0

        return VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("Today’s App Time", systemImage: "chart.bar.xaxis")
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
                "Today’s app time. Reading \(formattedUsage(reading)). Games \(formattedUsage(games))."
            )

            HStack(spacing: 16) {
                usageLegend(
                    title: "Reading",
                    seconds: reading,
                    fraction: readingFraction,
                    tint: .blue
                )

                usageLegend(
                    title: "Games",
                    seconds: games,
                    fraction: gameFraction,
                    tint: .indigo
                )
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

    private func usageLegend(
        title: String,
        seconds: Int,
        fraction: Double,
        tint: Color
    ) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(formattedUsage(seconds))
                .font(.caption.weight(.semibold))
                .monospacedDigit()

            if readingUsageSeconds + gameUsageSeconds > 0 {
                Text("\(Int(round(fraction * 100)))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionHeader(_ title: String, systemImage: String, tint: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        let gameSnapshot = gameStats.breakdownSnapshot()
        let bestGameStreak = gameSnapshot.entries.compactMap(\.bestStreak).max() ?? 0
        let lastPlayed = gameStats.lastPlayedSummary()
        let lastPlayedDetail: String = {
            if let name = lastPlayed.name, let relative = lastPlayed.relative {
                return "\(name) • \(relative)"
            }
            return "No games played yet"
        }()

        HeroCard(
            title: "Bible Stats",
            subtitle: "Reading + games at a glance",
            icon: "chart.bar.fill",
            tint: .teal
        ) {
            VStack(alignment: .leading, spacing: 14) {
                usageBreakdown(
                    readingSeconds: readingUsageSeconds,
                    gameSeconds: gameUsageSeconds
                )

                sectionHeader("Reading", systemImage: "book.fill", tint: .blue)

                HStack(alignment: .top, spacing: 10) {
                    statTile(
                        title: "Today",
                        value: bibleVM.formatted(bibleVM.todaySeconds),
                        subtitle: "vs yesterday \(bibleVM.todayDeltaOnlyValue)",
                        systemImage: "sun.max.fill",
                        tint: .blue
                    )
                    statTile(
                        title: "This Week",
                        value: bibleVM.formatted(bibleVM.thisWeekSeconds),
                        subtitle: "vs last week \(bibleVM.weekDeltaOnlyValue)",
                        systemImage: "calendar",
                        tint: .green
                    )
                    statTile(
                        title: "All Time",
                        value: bibleVM.formatted(bibleVM.totalSeconds),
                        systemImage: "clock.fill",
                        tint: .purple
                    )
                }

                contextRow(
                    systemImage: "bookmark.fill",
                    title: "Last read",
                    detail: "\(bibleVM.lastReadBookChapter) • \(bibleVM.lastReadRelativeTime)",
                    tint: .orange
                )

                Divider()

                sectionHeader("Games", systemImage: "gamecontroller.fill", tint: .indigo)

                HStack(alignment: .top, spacing: 10) {
                    statTile(
                        title: "Gamer Score",
                        value: gameSnapshot.totalAnswered > 0
                            ? "\(Int(round(gameSnapshot.percentage)))%"
                            : "—",
                        systemImage: "target",
                        tint: gameSnapshot.totalAnswered > 0
                            ? Color.gamerScoreColor(for: gameSnapshot.percentage)
                            : .secondary
                    )
                    statTile(
                        title: "Correct",
                        value: gameSnapshot.totalAnswered > 0
                            ? "\(gameSnapshot.totalCorrect)/\(gameSnapshot.totalAnswered)"
                            : "—",
                        systemImage: "checkmark.circle.fill",
                        tint: .green
                    )
                    statTile(
                        title: "Best Streak",
                        value: bestGameStreak > 0 ? "\(bestGameStreak)" : "—",
                        systemImage: "flame.fill",
                        tint: .orange
                    )
                }

                contextRow(
                    systemImage: "clock.arrow.circlepath",
                    title: "Last played",
                    detail: lastPlayedDetail,
                    tint: .indigo
                )

                HStack(spacing: 10) {
                    Button(action: onOpenReadingStats) {
                        Label("Reading Stats", systemImage: "book.pages")
                            .frame(maxWidth: .infinity)
                    }

                    Button(action: onOpenGameStats) {
                        Label("Game Stats", systemImage: "gamecontroller")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(ClearGlassPillButtonStyle())
            }
            .onAppear {
                bibleVM.refresh()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    bibleVM.refresh()
                }
            }
        }
    }
}
