import SwiftUI

struct PlayerStatSheetCardView: View {
    private var stats = GameStats.shared
    @State private var version: Int = 0

    private enum Sort: String, CaseIterable, Identifiable {
        case name = "Game"
        case attempts = "Attempts"
        case avg = "Avg"
        case streak = "Streak"
        var id: String { rawValue }
    }
    @State private var sort: Sort = .avg

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
        cardBody
    }

    /// Keeps the detailed stat table behind an opaque result boundary for the Swift type checker.
    private var cardBody: some View {
        HeroCard(title: "Player Stat Sheet", icon: "tablecells", tint: .indigo) {
            let _ = stats.version

            let breakdown = GameStats.shared.breakdownSnapshot()
            let totalAnswered = breakdown.totalAnswered
            let isEmpty = (totalAnswered == 0)
            let entries = breakdown.entries

            let attempts: [Int] = entries.map(\.answered)
            let avgs: [Double?] = entries.map { s in s.answered > 0 ? (Double(s.correct) / Double(s.answered)) * 100.0 : nil }
            let streaks: [Int] = entries.map { s in s.bestStreak ?? 0 }

            let bestAttemptsIndex = uniqueMaxIndex(attempts)
            let accuracyIndices = entries.indices.filter { avgs[$0] != nil }
            let accuracies = accuracyIndices.map { avgs[$0] ?? 0 }
            let bestAvgIndex = uniqueMaxIndex(accuracies).map { accuracyIndices[$0] }
            let rankedAccuracyIndices = entries.indices.filter { entries[$0].answered >= 5 }
            let rankedAccuracies = rankedAccuracyIndices.map { avgs[$0] ?? 0 }
            let bestStreakIndex = uniqueMaxIndex(streaks)

            let worstAttemptsIndex = uniqueMinIndex(attempts)
            let worstAvgIndex = uniqueMinIndex(rankedAccuracies).map { rankedAccuracyIndices[$0] }
            let worstStreakIndex = uniqueMinIndex(streaks.map { $0 == 0 ? Int.max : $0 })

            VStack(alignment: .leading, spacing: 8) {
                StatsSortPicker(selection: $sort)

                if isEmpty {
                    Text("Play any game to see your stats.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    let sortedIndices: [Int] = {
                        let indices = Array(entries.indices)
                        switch sort {
                        case .name:
                            return indices.sorted { entries[$0].name < entries[$1].name }
                        case .attempts:
                            return indices.sorted {
                                if attempts[$0] == attempts[$1] { return entries[$0].name < entries[$1].name }
                                return attempts[$0] > attempts[$1]
                            }
                        case .avg:
                            return indices.sorted {
                                if avgs[$0] == avgs[$1] { return entries[$0].name < entries[$1].name }
                                return (avgs[$0] ?? -1) > (avgs[$1] ?? -1)
                            }
                        case .streak:
                            return indices.sorted {
                                if streaks[$0] == streaks[$1] { return entries[$0].name < entries[$1].name }
                                return streaks[$0] > streaks[$1]
                            }
                        }
                    }()

                    if dynamicTypeSize.isAccessibilitySize {
                        ForEach(sortedIndices, id: \.self) { idx in
                            let s = entries[idx]
                            let attemptCount = attempts[idx]
                            let avg = avgs[idx]
                            let best = streaks[idx]

                            VStack(alignment: .leading, spacing: 8) {
                                Text(s.name)
                                    .font(.headline)
                                LabeledContent("Attempts", value: "\(attemptCount)")
                                LabeledContent("Average", value: avg.map { "\(Int(round($0)))%" } ?? "—")
                                LabeledContent("Best Streak", value: best > 0 ? "\(best)" : "—")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(s.answered == 0 ? .secondary : .primary)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                            .accessibilityElement(children: .combine)
                        }
                    } else {
                        // A Grid sizes each number column to its widest value, and the game
                        // name takes the rest, so nothing is cut off at larger text sizes.
                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                            GridRow {
                                columnHeader("Game")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                columnHeader("Attempts")
                                columnHeader("Avg")
                                columnHeader("Streak")
                            }
                            .accessibilityHidden(true)

                            ForEach(sortedIndices, id: \.self) { idx in
                                let s = entries[idx]
                                let attemptCount = attempts[idx]
                                let avg = avgs[idx]
                                let best = streaks[idx]

                                Divider()

                                GridRow {
                                    Text(s.name)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(2)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    labeledValue("\(attemptCount)",
                                                 isBest: bestAttemptsIndex == idx,
                                                 isWorst: worstAttemptsIndex == idx)
                                        .gridColumnAlignment(.trailing)

                                    labeledValue(avg.map { "\(Int(round($0)))%" } ?? "—",
                                                 isBest: bestAvgIndex == idx,
                                                 isWorst: worstAvgIndex == idx)
                                        .gridColumnAlignment(.trailing)

                                    labeledValue(best > 0 ? "\(best)" : "—",
                                                 isBest: best > 0 && bestStreakIndex == idx,
                                                 isWorst: best > 0 && worstStreakIndex == idx)
                                        .gridColumnAlignment(.trailing)
                                }
                                .foregroundStyle(s.answered == 0 ? .secondary : .primary)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(
                                    {
                                        var parts: [String] = [s.name]
                                        parts.append("\(attemptCount) attempts")
                                        if let avg { parts.append("Accuracy \(Int(round(avg))) percent") }
                                        if let bs = s.bestStreak, bs > 0 {
                                            parts.append("Best streak \(bs)")
                                        }
                                        return parts.joined(separator: ". ") + "."
                                    }()
                                )
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: sort)
                    }
                }
            }
            .padding(.top, 2)
        }
        .onAppear { version &+= 1 }
        .onChange(of: stats.version) { _, _ in version &+= 1 }
    }

    private func columnHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private func labeledValue(_ text: String, isBest: Bool, isWorst: Bool) -> some View {
        Text(text)
            .font(.footnote)
            .monospacedDigit()
            .lineLimit(1)
            .foregroundStyle(isBest ? .green : (isWorst ? .red : .primary))
    }
}
