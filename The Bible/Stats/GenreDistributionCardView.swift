import SwiftUI

struct GenreDistributionCardView: View {
    struct Row: Identifiable {
        let id = UUID()
        let genre: String
        let seconds: Int
    }

    @Binding var timeScope: StatsTimeScope
    let perGenreTotals: [(genre: String, seconds: Int)]
    /// The Old and New Testament split for the same scope.
    let otSeconds: Int
    let ntSeconds: Int
    @Binding var selectedGenre: StatsSeriesBuilder.Genre?
    let onSelectGenre: (StatsSeriesBuilder.Genre) -> Void
    let genreColor: (String) -> Color
    let formatSeconds: (Int) -> String

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false

    private var segmentedTint: Color {
        colorScheme == .light ? Color.black.opacity(0.85) : Color.accentColor
    }

    var body: some View {
        // The scope picker names the period, so the title doesn't repeat it.
        HeroCard(title: "Genre Distribution", icon: "chart.bar.doc.horizontal", tint: .teal) {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Scope", selection: $timeScope) {
                    ForEach(StatsTimeScope.allCases) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .tint(segmentedTint)

                TestamentSplitBar(otSeconds: otSeconds, ntSeconds: ntSeconds, formatSeconds: formatSeconds)

                Divider()

                let maxValRaw = perGenreTotals.map { max(0, $0.seconds) }.max() ?? 0
                let maxVal = max(1, maxValRaw)

                // Name and time share a line with the bar beneath, so long genre names and
                // large text sizes fit without fixed column widths.
                VStack(spacing: 10) {
                    ForEach(perGenreTotals, id: \.genre) { item in
                        let safeSeconds = max(0, item.seconds)
                        Button {
                            if let g = StatsSeriesBuilder.Genre(rawValue: item.genre) {
                                selectedGenre = g
                                onSelectGenre(g)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.genre)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer(minLength: 8)
                                    Text(formatSeconds(safeSeconds))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                GeometryReader { geo in
                                    let raw = CGFloat(safeSeconds) / CGFloat(maxVal)
                                    let frac = raw.isFinite ? min(max(0, raw), 1) : 0
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(genreColor(item.genre).opacity(0.7))
                                        .frame(width: max(0, geo.size.width * frac), height: 10, alignment: .leading)
                                }
                                .frame(height: 10)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item.genre) \(formatSeconds(safeSeconds))")
                    }
                }

                if contextualTipsEnabled {
                    ContextualTipView(
                        id: "stats.genre",
                        title: "Explore a genre",
                        message: "Tap a genre to see its books and reading time.",
                        systemImage: "chart.bar.xaxis"
                    )
                    .padding(.top, 6)
                }
            }
        }
    }
}
