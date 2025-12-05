import SwiftUI

struct GamesCardView: View {
    // Collapsible state
    @State private var expanded: Bool = false
    @State private var version: Int = 0 // tie to GameStats version for refresh

    private func colorForPercent(_ pct: Double) -> Color {
        if pct < 60 { return .red }
        else if pct < 75 { return .orange }
        else if pct < 90 { return .purple }
        else { return .green }
    }

    private func uniqueMaxIndex<T: Comparable & Equatable>(_ values: [T]) -> Int? {
        guard let maxVal = values.max() else { return nil }
        let indices = values.enumerated().filter { $0.element == maxVal }.map { $0.offset }
        return indices.count == 1 ? indices.first : nil
    }

    private func uniqueMinIndex<T: Comparable & Equatable>(_ values: [T]) -> Int? {
        guard let minVal = values.min() else { return nil }
        let indices = values.enumerated().filter { $0.element == minVal }.map { $0.offset }
        return indices.count == 1 ? indices.first : nil
    }

    var body: some View {
        GroupBox {
            let breakdown = GameStats.shared.breakdownSnapshot()
            let totalAnswered = breakdown.totalAnswered
            let totalCorrect = breakdown.totalCorrect
            let gamerPct = breakdown.percentage
            let gamerColor = colorForPercent(gamerPct)
            let isEmpty = (totalAnswered == 0)

            VStack(alignment: .leading, spacing: 12) {
                DisclosureGroup(isExpanded: $expanded) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 12) {
                            if isEmpty {
                                Text("Play any game to build your Gamer Score.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                Divider()

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Player Stat Sheet")
                                        .font(.subheadline).bold()
                                        .foregroundStyle(.secondary)

                                    let nameWidth: CGFloat = 140
                                    let colWidth: CGFloat = 72

                                    HStack(spacing: 10) {
                                        Text("Game")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .frame(width: nameWidth, alignment: .leading)
                                        Spacer(minLength: 0)
                                        Text("Played")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .frame(width: colWidth, alignment: .center)
                                        Text("Avg")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .frame(width: colWidth, alignment: .center)
                                        Text("Streak")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .frame(width: colWidth, alignment: .center)
                                    }

                                    let stats = breakdown.entries

                                    let shares: [Double] = stats.map { s in
                                        totalAnswered > 0 ? (Double(s.answered) / Double(totalAnswered)) * 100.0 : 0
                                    }
                                    let avgs: [Double] = stats.map { s in
                                        s.answered > 0 ? (Double(s.correct) / Double(s.answered)) * 100.0 : 0
                                    }
                                    let streaks: [Int] = stats.map { s in
                                        s.bestStreak ?? 0
                                    }

                                    let bestShareIndex = uniqueMaxIndex(shares)
                                    let bestAvgIndex = uniqueMaxIndex(avgs)
                                    let bestStreakIndex = uniqueMaxIndex(streaks)

                                    let worstShareIndex = uniqueMinIndex(shares)
                                    let worstAvgIndex = uniqueMinIndex(avgs)
                                    let streaksForMin: [Int] = streaks.map { $0 == 0 ? Int.max : $0 }
                                    let worstStreakIndex = uniqueMinIndex(streaksForMin)

                                    ForEach(Array(stats.enumerated()), id: \.offset) { pair in
                                        let idx = pair.offset
                                        let s = pair.element
                                        let share = shares[idx]
                                        let avg = avgs[idx]
                                        let best = streaks[idx]

                                        HStack(spacing: 10) {
                                            Text(s.name)
                                                .font(.subheadline.weight(.semibold))
                                                .frame(width: nameWidth, alignment: .leading)

                                            Spacer(minLength: 0)

                                            Text("\(Int(round(share)))%")
                                                .font(.footnote)
                                                .monospacedDigit()
                                                .frame(width: colWidth, alignment: .center)
                                                .foregroundStyle(
                                                    bestShareIndex == idx ? Color.green :
                                                    (worstShareIndex == idx ? Color.red : Color.primary)
                                                )

                                            Text("\(Int(round(avg)))%")
                                                .font(.footnote)
                                                .monospacedDigit()
                                                .frame(width: colWidth, alignment: .center)
                                                .foregroundStyle(
                                                    bestAvgIndex == idx ? Color.green :
                                                    (worstAvgIndex == idx ? Color.red : Color.primary)
                                                )

                                            Text(s.bestStreak != nil && s.bestStreak! > 0 ? "\(best)" : "—")
                                                .font(.footnote)
                                                .monospacedDigit()
                                                .frame(width: colWidth, alignment: .center)
                                                .foregroundStyle(
                                                    s.bestStreak != nil && s.bestStreak! > 0
                                                    ? (bestStreakIndex == idx ? Color.green :
                                                       (worstStreakIndex == idx ? Color.red : Color.primary))
                                                    : Color.primary
                                                )
                                        }
                                        .foregroundStyle(s.answered == 0 ? .secondary : .primary)
                                        .accessibilityElement(children: .ignore)
                                        .accessibilityLabel(
                                            {
                                                var parts: [String] = [s.name]
                                                parts.append("Share \(Int(round(share))) percent")
                                                parts.append("Average \(Int(round(avg))) percent")
                                                if let bs = s.bestStreak, bs > 0 {
                                                    parts.append("Best streak \(bs)")
                                                }
                                                return parts.joined(separator: ". ") + "."
                                            }()
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.trailing, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Text("Gamer Score:")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if isEmpty {
                                Text("Let’s play!")
                                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("\(Int(round(gamerPct)))%")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(gamerColor)
                                    .accessibilityHidden(true)
                                    .overlay(
                                        Color.clear
                                            .accessibilityElement(children: .ignore)
                                            .accessibilityLabel("Gamer Score \(Int(round(gamerPct))) percent.")
                                    )
                            }
                        }
                    }
                }
                .animation(.spring(response: 0.25, dampingFraction: 0.9), value: expanded)
            }
        } label: {
            Label("Games", systemImage: "gamecontroller")
        }
        .onReceive(NotificationCenter.default.publisher(for: .gameStatsExternallyUpdated)) { _ in
            version &+= 1 // trigger refresh
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            GamesCardView()
        }
        .padding()
    }
}
