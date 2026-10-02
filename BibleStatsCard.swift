import SwiftUI

struct BibleStatsCard: View {
    let bibleVM: HomeBibleStatsViewModel
    let scenePhase: ScenePhase
    let onOpenReadingStats: () -> Void
    let onOpenGameStats: () -> Void

    @AppStorage("dailyUsageReadingSeconds") private var readingUsageSeconds: Int = 0
    @AppStorage("dailyUsageGameSeconds") private var gameUsageSeconds: Int = 0
    @AppStorage("allTimeUsageReadingSeconds") private var allTimeReadingSeconds: Int = 0
    @AppStorage("allTimeUsageGameSeconds") private var allTimeGameSeconds: Int = 0

    var body: some View {
        HeroCard(
            title: "App Activity",
            subtitle: "How you spend your time",
            icon: "chart.bar.fill",
            tint: .teal
        ) {
            VStack(alignment: .leading, spacing: 14) {
                ActivityTimeGraph(
                    title: "Today’s App Time",
                    readingSeconds: readingUsageSeconds,
                    gameSeconds: gameUsageSeconds
                )

                ActivityTimeGraph(
                    title: "All-Time App Time",
                    readingSeconds: allTimeReadingSeconds,
                    gameSeconds: allTimeGameSeconds
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

            HStack(spacing: 16) {
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

            Text(formattedUsage)
                .font(.caption.weight(.semibold))
                .monospacedDigit()

            if showsPercentage {
                Text("\(Int(round(fraction * 100)))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
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
