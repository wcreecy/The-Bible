import SwiftUI

public struct GameScoreboardCard: View {
    // Current session (live)
    let currentCorrect: Int
    let currentAnswered: Int
    let currentStreak: Int
    // All-time
    let allTimeCorrect: Int
    let allTimeAnswered: Int
    let allTimeBestStreak: Int

    @Environment(\.horizontalSizeClass) private var hSize

    // Treat iPad (or any regular width) as “roomier” for bigger UI
    private var isPadLike: Bool {
        UIDevice.current.userInterfaceIdiom == .pad || hSize == .regular
    }

    // Typography and layout metrics that scale on iPad
    private var sectionLabelFont: Font { isPadLike ? .headline : .caption }
    private var pillTitleFont: Font { isPadLike ? .footnote : .caption2 }
    private var pillValueFont: Font { isPadLike ? .title3.weight(.semibold) : .subheadline.weight(.semibold) }
    private var rowSpacing: CGFloat { isPadLike ? 16 : 10 }
    private var containerPadding: CGFloat { isPadLike ? 14 : 8 }
    private var pillPadding: CGFloat { isPadLike ? 10 : 6 }
    private var sectionLabelWidth: CGFloat { isPadLike ? 90 : 60 }
    private var pillCornerRadius: CGFloat { isPadLike ? 14 : 12 }
    private var cardCornerRadius: CGFloat { isPadLike ? 18 : 16 }
    private var cardStrokeOpacity: Double { 0.06 }

    public init(
        currentCorrect: Int,
        currentAnswered: Int,
        currentStreak: Int,
        allTimeCorrect: Int,
        allTimeAnswered: Int,
        allTimeBestStreak: Int
    ) {
        self.currentCorrect = currentCorrect
        self.currentAnswered = currentAnswered
        self.currentStreak = currentStreak
        self.allTimeCorrect = allTimeCorrect
        self.allTimeAnswered = allTimeAnswered
        self.allTimeBestStreak = allTimeBestStreak
    }

    public var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: rowSpacing) {
                // Current session stats
                HStack(spacing: rowSpacing) {
                    Text("Current")
                        .font(sectionLabelFont)
                        .foregroundStyle(.secondary)
                        .frame(width: sectionLabelWidth, alignment: .leading)
                    statPill(title: "Correct", value: "\(currentCorrect)")
                    statPill(title: "Total", value: "\(currentAnswered)")
                    streakPill(title: "Streak", current: currentStreak, allTimeBest: allTimeBestStreak)
                    statPill(title: "Percent", value: percentString(correct: currentCorrect, answered: currentAnswered))
                }
                // All-time stats
                HStack(spacing: rowSpacing) {
                    Text("All-time")
                        .font(sectionLabelFont)
                        .foregroundStyle(.secondary)
                        .frame(width: sectionLabelWidth, alignment: .leading)
                    statPill(title: "Correct", value: "\(allTimeCorrect)")
                    statPill(title: "Total", value: "\(allTimeAnswered)")
                    statPill(title: "Streak", value: "\(allTimeBestStreak)")
                    statPill(title: "Percent", value: percentString(correct: allTimeCorrect, answered: allTimeAnswered))
                }
            }
            .padding(containerPadding)
        }
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(UIColor.systemBackground), Color(UIColor.secondarySystemBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .stroke(Color.black.opacity(cardStrokeOpacity), lineWidth: 1)
        )
    }

    // Neutral stat pill (no per-category color)
    @ViewBuilder
    private func statPill(title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(pillTitleFont)
                .foregroundStyle(.secondary)
            Text(value)
                .font(pillValueFont)
                .foregroundStyle(.primary)
        }
        .padding(pillPadding)
        .background(
            RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // Current streak pill with special green highlight when tying/exceeding all-time best streak
    @ViewBuilder
    private func streakPill(title: String, current: Int, allTimeBest: Int) -> some View {
        let highlightThreshold = max(1, allTimeBest)
        let isHighlighted = current >= highlightThreshold
        VStack(spacing: 3) {
            Text(title)
                .font(pillTitleFont)
                .foregroundStyle(.secondary)
            Text("\(current)")
                .font(pillValueFont)
                .foregroundStyle(isHighlighted ? Color.green : Color.primary)
                .animation(.default, value: isHighlighted)
        }
        .padding(pillPadding)
        .background(
            RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .accessibilityHint(isHighlighted ? "Tied or exceeded all-time best streak" : "")
    }

    private func percentString(correct: Int, answered: Int) -> String {
        guard answered > 0 else { return "0%" }
        let raw = (Double(correct) / Double(answered)) * 100.0
        let clamped = min(100.0, max(0.0, raw))
        let pct = Int(round(clamped))
        return "\(pct)%"
    }
}

#Preview {
    VStack(spacing: 20) {
        GameScoreboardCard(
            currentCorrect: 7,
            currentAnswered: 10,
            currentStreak: 9,
            allTimeCorrect: 120,
            allTimeAnswered: 200,
            allTimeBestStreak: 9
        )
        .padding()
    }
}
