import SwiftUI

struct PlayerStatSheetCardView: View {
    @ObservedObject private var stats = GameStats.shared
    @State private var version: Int = 0

    private enum Sort: String, CaseIterable, Identifiable {
        case name = "Game"
        case attempts = "Attempts"
        case avg = "Avg"
        case streak = "Streak"
        var id: String { rawValue }
    }
    @State private var sort: Sort = .avg

    @Environment(\.colorScheme) private var colorScheme
    private var segmentedTint: Color {
        colorScheme == .light ? Color.black.opacity(0.85) : Color.accentColor
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
                Picker("Sort", selection: $sort) {
                    ForEach(Sort.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .tint(segmentedTint)
                .frame(maxWidth: 280, alignment: .trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)

                if isEmpty {
                    Text("Play any game to build your Gamer Score.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    let nameWidth: CGFloat = 88
                    let percentageWidth: CGFloat = 60
                    let streakWidth: CGFloat = 46

                    HStack(spacing: 8) {
                        Text("Game")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: nameWidth, alignment: .leading)
                        Spacer(minLength: 0)
                        Text("Attempts")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: percentageWidth, alignment: .center)
                        Text("Avg")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: percentageWidth, alignment: .center)
                        Text("Streak")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: streakWidth, alignment: .center)
                    }

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

                    ForEach(sortedIndices, id: \.self) { idx in
                        let s = entries[idx]
                        let attemptCount = attempts[idx]
                        let avg = avgs[idx]
                        let best = streaks[idx]

                        HStack(spacing: 8) {
                            Text(s.name)
                                .font(.subheadline.weight(.semibold))
                                .frame(width: nameWidth, alignment: .leading)

                            Spacer(minLength: 0)

                            labeledValue("\(attemptCount)",
                                         isBest: bestAttemptsIndex == idx,
                                         isWorst: worstAttemptsIndex == idx)
                                .frame(width: percentageWidth, alignment: .center)

                            labeledValue(avg.map { "\(Int(round($0)))%" } ?? "—",
                                         isBest: bestAvgIndex == idx,
                                         isWorst: worstAvgIndex == idx)
                                .frame(width: percentageWidth, alignment: .center)

                            labeledValue(best > 0 ? "\(best)" : "—",
                                         isBest: best > 0 && bestStreakIndex == idx,
                                         isWorst: best > 0 && worstStreakIndex == idx)
                                .frame(width: streakWidth, alignment: .center)
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
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )
                    }
                    .animation(.easeInOut(duration: 0.2), value: sort)
                }
            }
            .padding(.top, 2)
        }
        .onAppear { version &+= 1 }
        .onChange(of: stats.version) { _, _ in version &+= 1 }
    }

    private func labeledValue(_ text: String, isBest: Bool, isWorst: Bool) -> some View {
        Text(text)
            .font(.footnote)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .foregroundStyle(isBest ? .green : (isWorst ? .red : .primary))
    }
}
