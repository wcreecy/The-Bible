import SwiftUI

struct TopBooksThisMonthCardView: View {
    let top3: [(book: String, seconds: Int)]
    let totalSeconds: Int
    let formatSeconds: (Int) -> String

    // Equatable animation key for top3 changes
    private struct TopBookAnimKey: Equatable {
        let book: String
        let seconds: Int
    }
    private var animationKey: [TopBookAnimKey] {
        top3.map { TopBookAnimKey(book: $0.book, seconds: $0.seconds) }
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Top Books This Month")
                        .font(.headline)
                    Spacer()
                    if totalSeconds > 0 {
                        Text(formatSeconds(totalSeconds))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                if top3.isEmpty {
                    ContentUnavailableView("No reading yet this month", systemImage: "books.vertical")
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    let maxSeconds = max(1, top3.map { $0.seconds }.max() ?? 1)

                    VStack(spacing: 10) {
                        ForEach(Array(top3.enumerated()), id: \.offset) { idx, entry in
                            TopBookRow(
                                rank: idx + 1,
                                title: entry.book,
                                seconds: entry.seconds,
                                maxSeconds: maxSeconds,
                                formatSeconds: formatSeconds
                            )
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(idx + 1). \(entry.book), \(formatSeconds(entry.seconds)) this month")
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: animationKey)
                }
            }
            .padding(.top, 2)
        }
    }
}

// MARK: - Polished Top Book Row

private struct TopBookRow: View {
    let rank: Int
    let title: String
    let seconds: Int
    let maxSeconds: Int
    let formatSeconds: (Int) -> String

    // Layout constants for polish
    private let barHeight: CGFloat = 12
    private let barCorner: CGFloat = 6
    private let valueLabelWidth: CGFloat = 72 // reserved space so bars never overlap values
    private let minVisibleBarWidth: CGFloat = 8 // ensure tiny values still show a chip
    private let rowSpacing: CGFloat = 6

    private var rankColor: Color {
        switch rank {
        case 1: return .accentColor
        case 2: return .teal
        default: return .indigo
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            HStack(spacing: 10) {
                // Rank chip
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(rankColor.opacity(0.15))
                    Text("\(rank)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(rankColor)
                }
                .frame(width: 28, height: 24)

                // Title left, value right
                HStack(spacing: 8) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 8)

                    Text(formatSeconds(seconds))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: valueLabelWidth, alignment: .trailing)
                }
            }

            GeometryReader { geo in
                let available = max(0, geo.size.width - valueLabelWidth - 10 /* spacing fudge */)
                let frac = CGFloat(max(0, seconds)) / CGFloat(max(1, maxSeconds))
                let width = max(minVisibleBarWidth, available * frac)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: barCorner, style: .continuous)
                        .fill(Color(.secondarySystemFill))
                    RoundedRectangle(cornerRadius: barCorner, style: .continuous)
                        .fill(LinearGradient(
                            colors: [rankColor.opacity(0.85), rankColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: width)
                        .shadow(color: rankColor.opacity(0.15), radius: 3, x: 0, y: 1)
                }
            }
            .frame(height: barHeight)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
