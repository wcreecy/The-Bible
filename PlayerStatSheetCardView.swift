import SwiftUI
import Charts

struct PlayerStatSheetCardView: View {
    @ObservedObject private var stats = GameStats.shared
    @State private var version: Int = 0

    private enum Sort: String, CaseIterable, Identifiable {
        case name = "Game"
        case share = "Played"
        case avg = "Avg"
        case streak = "Streak"
        var id: String { rawValue }
    }
    @State private var sort: Sort = .avg

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
            let _ = stats.version

            let breakdown = GameStats.shared.breakdownSnapshot()
            let totalAnswered = breakdown.totalAnswered
            let isEmpty = (totalAnswered == 0)
            let entries = breakdown.entries

            let shares: [Double] = {
                guard totalAnswered > 0 else { return Array(repeating: 0, count: entries.count) }
                return entries.map { s in (Double(s.answered) / Double(totalAnswered)) * 100.0 }
            }()
            let avgs: [Double] = entries.map { s in s.answered > 0 ? (Double(s.correct) / Double(s.answered)) * 100.0 : 0 }
            let streaks: [Int] = entries.map { s in s.bestStreak ?? 0 }

            let bestShareIndex = uniqueMaxIndex(shares)
            let bestAvgIndex = uniqueMaxIndex(avgs)
            let bestStreakIndex = uniqueMaxIndex(streaks)

            let worstShareIndex = uniqueMinIndex(shares)
            let worstAvgIndex = uniqueMinIndex(avgs)
            let worstStreakIndex = uniqueMinIndex(streaks.map { $0 == 0 ? Int.max : $0 })

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Player Stat Sheet")
                        .font(.subheadline).bold()
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Sort", selection: $sort) {
                        ForEach(Sort.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 280)
                }

                if isEmpty {
                    Text("Play any game to build your Gamer Score.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
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

                    let sortedIndices: [Int] = {
                        let indices = Array(entries.indices)
                        switch sort {
                        case .name:
                            return indices.sorted { entries[$0].name < entries[$1].name }
                        case .share:
                            return indices.sorted {
                                if shares[$0] == shares[$1] { return entries[$0].name < entries[$1].name }
                                return shares[$0] > shares[$1]
                            }
                        case .avg:
                            return indices.sorted {
                                if avgs[$0] == avgs[$1] { return entries[$0].name < entries[$1].name }
                                return avgs[$0] > avgs[$1]
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
                        let share = shares[idx]
                        let avg = avgs[idx]
                        let best = streaks[idx]

                        HStack(spacing: 10) {
                            Text(s.name)
                                .font(.subheadline.weight(.semibold))
                                .frame(width: nameWidth, alignment: .leading)

                            Spacer(minLength: 0)

                            labeledValue("\(Int(round(share)))%",
                                         isBest: bestShareIndex == idx,
                                         isWorst: worstShareIndex == idx)
                                .frame(width: colWidth, alignment: .center)

                            labeledValue("\(Int(round(avg)))%",
                                         isBest: bestAvgIndex == idx,
                                         isWorst: worstAvgIndex == idx)
                                .frame(width: colWidth, alignment: .center)

                            labeledValue(s.bestStreak != nil && s.bestStreak! > 0 ? "\(best)" : "—",
                                         isBest: s.bestStreak != nil && s.bestStreak! > 0 && bestStreakIndex == idx,
                                         isWorst: s.bestStreak != nil && s.bestStreak! > 0 && worstStreakIndex == idx)
                                .frame(width: colWidth, alignment: .center)
                        }
                        .foregroundStyle(s.answered == 0 ? .secondary : .primary)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            {
                                var parts: [String] = [s.name]
                                parts.append("Played share \(Int(round(share))) percent")
                                parts.append("Average \(Int(round(avg))) percent")
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

                    // Where you play at the bottom of the Player Stat Sheet
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Where you play")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Chart {
                            ForEach(Array(entries.enumerated()), id: \.offset) { pair in
                                let entry = pair.element
                                BarMark(
                                    x: .value("Game", entry.name),
                                    y: .value("Played", entry.answered)
                                )
                                .foregroundStyle(Color.accentColor.opacity(0.85))
                                .cornerRadius(4)
                                .annotation(position: .top, alignment: .center) {
                                    if entry.answered > 0 {
                                        Text("\(entry.answered)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .monospacedDigit()
                                    }
                                }
                            }
                        }
                        .chartYAxis(.hidden)
                        .frame(height: 120)
                        .animation(.easeInOut(duration: 0.35), value: version)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.top, 2)
        } label: {
            Label("Player Stat Sheet", systemImage: "tablecells")
        }
        .onAppear { version &+= 1 }
        .onChange(of: stats.version) { _, _ in version &+= 1 }
    }

    private func labeledValue(_ text: String, isBest: Bool, isWorst: Bool) -> some View {
        HStack(spacing: 4) {
            if isBest {
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(.green)
            } else if isWorst {
                Image(systemName: "arrow.down.right")
                    .foregroundStyle(.red)
            }
            Text(text)
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(isBest ? .green : (isWorst ? .red : .primary))
        }
    }
}
