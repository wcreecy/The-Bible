import SwiftUI

struct ReadingAndGamesComparisonCard: View {
    private struct Snapshot: Equatable {
        let todayReadingSeconds: Int
        let todayGameSeconds: Int
        let allTimeReadingSeconds: Int
        let allTimeGameSeconds: Int

        static let empty = Snapshot(
            todayReadingSeconds: 0,
            todayGameSeconds: 0,
            allTimeReadingSeconds: 0,
            allTimeGameSeconds: 0
        )
    }

    @State private var snapshot = Snapshot.empty

    var body: some View {
        HeroCard(
            title: "Reading & Games",
            subtitle: "How your time is divided",
            icon: "chart.bar.xaxis",
            tint: .teal
        ) {
            VStack(spacing: 12) {
                ActivityUsageBar(
                    title: "Today",
                    readingSeconds: snapshot.todayReadingSeconds,
                    gameSeconds: snapshot.todayGameSeconds
                )

                ActivityUsageBar(
                    title: "All Time",
                    readingSeconds: snapshot.allTimeReadingSeconds,
                    gameSeconds: snapshot.allTimeGameSeconds
                )
            }
            .onAppear {
                refresh()
            }
            .onNotification(.bibleStatsExternallyUpdated) {
                refresh()
            }
            .onNotification(.gameStatsExternallyUpdated) {
                refresh()
            }
        }
    }

    private func refresh(now: Date = .now) {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent

        let dailyReadingTotals = BibleStatsStore.shared.loadDailyTotals()
        let todayKey = BibleStatsStore.isoDateString(now, calendar: calendar)

        snapshot = Snapshot(
            todayReadingSeconds: max(0, dailyReadingTotals[todayKey, default: 0]),
            todayGameSeconds: GameStats.shared.playSeconds(on: now),
            allTimeReadingSeconds: dailyReadingTotals.values.reduce(0) { $0 + max(0, $1) },
            allTimeGameSeconds: GameStats.shared.allTimePlaySeconds
        )
    }
}

private struct ActivityUsageBar: View {
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

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    ActivityUsageLegend(title: "Reading", seconds: reading, tint: .blue)
                    ActivityUsageLegend(title: "Games", seconds: games, tint: .indigo)
                }

                VStack(alignment: .leading, spacing: 4) {
                    ActivityUsageLegend(title: "Reading", seconds: reading, tint: .blue)
                    ActivityUsageLegend(title: "Games", seconds: games, tint: .indigo)
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

private struct ActivityUsageLegend: View {
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
