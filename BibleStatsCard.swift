import SwiftUI

struct BibleStatsCard: View {
    let bibleVM: HomeBibleStatsViewModel
    let scenePhase: ScenePhase
    let onOpenReadingStats: () -> Void
    let onOpenGameStats: () -> Void

    // Reading time is active reading in the Bible reader (the same source as Stats and
    // the daily goal). Game time is time spent with a game open. Both sync per device.
    @State private var todayGameSeconds = 0
    @State private var allTimeGameSeconds = 0

    @ViewBuilder
    private var statsButtons: some View {
        Button(action: onOpenReadingStats) {
            Label("Reading Stats", systemImage: "book.pages")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .heroCardSurface()
        }
        .buttonStyle(.plain)

        Button(action: onOpenGameStats) {
            Label("Game Stats", systemImage: "gamecontroller")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .heroCardSurface()
        }
        .buttonStyle(.plain)
    }

    /// Progress through the Bible, this week's reading, and the most-read book, which
    /// the Stats page charts in full.
    @ViewBuilder
    private var highlights: some View {
        StatHighlightTile(
            title: "Bible Read",
            value: "\(bibleVM.completionPercent)%",
            caption: "\(bibleVM.visitedCount) of \(bibleVM.totalChapters) chapters",
            systemImage: "book.closed.fill",
            tint: .teal
        )

        StatHighlightTile(
            title: "This Week",
            value: StatHighlightTile.formattedDuration(bibleVM.thisWeekSeconds),
            caption: "Reading time",
            systemImage: "calendar",
            tint: .blue
        )

        StatHighlightTile(
            title: "Top Book",
            value: bibleVM.topBooks.first?.book ?? "—",
            caption: "Most time read",
            systemImage: "star.fill",
            tint: .orange
        )
    }

    var body: some View {
        HeroCard(
            title: HomeCardID.bibleStats.title,
            subtitle: "Reading progress and activity",
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
            VStack(alignment: .leading, spacing: 14) {
                // Three across when there's room; stacked in a narrow dashboard column.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 10) { highlights }
                    VStack(spacing: 10) { highlights }
                }

                ActivityTimeGraph(
                    title: "Today",
                    readingSeconds: bibleVM.todaySeconds,
                    gameSeconds: todayGameSeconds
                )

                ActivityTimeGraph(
                    title: "All Time",
                    readingSeconds: bibleVM.totalSeconds,
                    gameSeconds: allTimeGameSeconds
                )

                // Side by side when there's room; stacked in a narrow dashboard column.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { statsButtons }
                    VStack(spacing: 10) { statsButtons }
                }
            }
            .onAppear {
                bibleVM.refresh()
                refreshGameTime()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    bibleVM.refresh()
                    refreshGameTime()
                }
            }
            .onNotification(.gameStatsExternallyUpdated) {
                refreshGameTime()
            }
        }
    }

    private func refreshGameTime() {
        todayGameSeconds = GameStats.shared.playSeconds()
        allTimeGameSeconds = GameStats.shared.allTimePlaySeconds
    }
}

private struct StatHighlightTile: View {
    let title: LocalizedStringResource
    let value: String
    let caption: LocalizedStringResource
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)

            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(minWidth: 96, maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .accessibilityElement(children: .combine)
    }

    /// "45s", "12m", or "1h 5m".
    static func formattedDuration(_ seconds: Int) -> String {
        let safeSeconds = max(0, seconds)
        if safeSeconds < 60 {
            return "\(safeSeconds)s"
        }

        let hours = safeSeconds / 3_600
        let minutes = (safeSeconds % 3_600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}

private struct ActivityTimeGraph: View {
    let title: LocalizedStringResource
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
                Label(title, systemImage: "chart.bar.xaxis")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text(formattedUsage(total))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
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
                "\(title). Reading \(formattedUsage(reading)). Games \(formattedUsage(games))."
            )

            // Side by side when there's room; stacked in a narrow dashboard column.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { legends }
                VStack(alignment: .leading, spacing: 4) { legends }
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

    @ViewBuilder
    private var legends: some View {
        ActivityTimeLegend(
            title: "Reading",
            seconds: reading,
            fraction: readingFraction,
            showsPercentage: total > 0,
            tint: .blue
        )

        ActivityTimeLegend(
            title: "Games",
            seconds: games,
            fraction: gameFraction,
            showsPercentage: total > 0,
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

private struct ActivityTimeLegend: View {
    let title: LocalizedStringResource
    let seconds: Int
    let fraction: Double
    let showsPercentage: Bool
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Text(formattedUsage)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            if showsPercentage {
                Text("\(Int(round(fraction * 100)))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
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
        return hours > 0 ? "\(hours)h\u{00A0}\(minutes)m" : "\(minutes)m"
    }
}
