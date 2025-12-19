import SwiftUI

struct GenreDistributionCardView: View {
    enum TimeScope: String, CaseIterable, Identifiable {
        case allTime = "All Time"
        case thisMonth = "This Month"
        case last7 = "Last 7 Days"
        var id: String { rawValue }
    }

    struct Row: Identifiable {
        let id = UUID()
        let genre: String
        let seconds: Int
    }

    @Binding var timeScope: TimeScope
    let perGenreTotals: [(genre: String, seconds: Int)]
    @Binding var selectedGenre: StatsSeriesBuilder.Genre?
    let onSelectGenre: (StatsSeriesBuilder.Genre) -> Void
    let genreColor: (String) -> Color
    let formatSeconds: (Int) -> String

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Genre Distribution — \(timeScope.rawValue)")
                        .font(.headline)
                    Spacer()
                }

                Picker("Scope", selection: $timeScope) {
                    ForEach(TimeScope.allCases) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)

                let maxValRaw = perGenreTotals.map { max(0, $0.seconds) }.max() ?? 0
                let maxVal = max(1, maxValRaw)

                VStack(spacing: 8) {
                    ForEach(perGenreTotals, id: \.genre) { item in
                        let safeSeconds = max(0, item.seconds)
                        Button {
                            if let g = StatsSeriesBuilder.Genre(rawValue: item.genre) {
                                selectedGenre = g
                                onSelectGenre(g)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(item.genre)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 110, alignment: .leading)
                                GeometryReader { geo in
                                    let raw = CGFloat(safeSeconds) / CGFloat(maxVal)
                                    let frac = raw.isFinite ? min(max(0, raw), 1) : 0
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(genreColor(item.genre).opacity(0.7))
                                        .frame(width: max(0, geo.size.width * frac), height: 10, alignment: .leading)
                                }
                                .frame(height: 10)
                                Text(formatSeconds(safeSeconds))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                    .frame(width: 60, alignment: .trailing)
                            }
                            .frame(height: 16)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item.genre) \(formatSeconds(safeSeconds))")
                    }
                }

                // Small tip to indicate interactivity
                Text("Tip: Tap a genre to see the books in it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
                    .accessibilityHint("Opens a list of books for the selected genre.")
            }
        }
    }
}
