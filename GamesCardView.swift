import SwiftUI
import Charts

struct GamesCardView: View {
    // Observe central stats so any change to its @Published `version` re-renders this card.
    @ObservedObject private var stats = GameStats.shared

    // Local animation/version nudge for Charts and micro-animations
    @State private var version: Int = 0

    // Sorting for the Player Stat Sheet
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

    // Basic tiering by overall accuracy
    private enum Tier {
        case bronze, silver, gold, platinum
        var symbol: String {
            switch self {
            case .bronze: return "medal"
            case .silver: return "medal.fill"
            case .gold: return "trophy.fill"
            case .platinum: return "star.circle.fill"
            }
        }
        var name: String {
            switch self {
            case .bronze: return "Bronze"
            case .silver: return "Silver"
            case .gold: return "Gold"
            case .platinum: return "Platinum"
            }
        }
        var color: Color {
            switch self {
            case .bronze: return Color.brown
            case .silver: return Color.gray
            case .gold: return Color.yellow
            case .platinum: return Color.cyan
            }
        }
    }

    private func tier(for pct: Double) -> Tier {
        switch pct {
        case ..<60: return .bronze
        case ..<75: return .silver
        case ..<90: return .gold
        default: return .platinum
        }
    }

    var body: some View {
        GroupBox {
            // Force a dependency on the published version so any change re-renders.
            let _ = stats.version

            // Snapshot once per render pass
            let breakdown = GameStats.shared.breakdownSnapshot()
            let totalAnswered = breakdown.totalAnswered
            let totalCorrect = breakdown.totalCorrect
            let gamerPct = breakdown.percentage
            let gamerColor = Color.gamerScoreColor(for: gamerPct)
            let isEmpty = (totalAnswered == 0)
            let entries = breakdown.entries

            // Derived
            let shares: [Double] = entries.map { s in
                totalAnswered > 0 ? (Double(s.answered) / Double(totalAnswered)) * 100.0 : 0
            }
            let avgs: [Double] = entries.map { s in
                s.answered > 0 ? (Double(s.correct) / Double(s.answered)) * 100.0 : 0
            }
            let streaks: [Int] = entries.map { s in s.bestStreak ?? 0 }

            let bestShareIndex = uniqueMaxIndex(shares)
            let bestAvgIndex = uniqueMaxIndex(avgs)
            let bestStreakIndex = uniqueMaxIndex(streaks)

            let worstShareIndex = uniqueMinIndex(shares)
            let worstAvgIndex = uniqueMinIndex(avgs)
            let worstStreakIndex = uniqueMinIndex(streaks.map { $0 == 0 ? Int.max : $0 })

            VStack(alignment: .leading, spacing: 12) {
                // HEADER: Progress ring (tier chip removed)
                HStack(spacing: 12) {
                    if isEmpty {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.accentColor.opacity(0.08))
                            .frame(width: 64, height: 64)
                            .overlay(
                                Image(systemName: "gamecontroller")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            )
                            .accessibilityHidden(true)
                    } else {
                        GamesProgressRing(
                            progress: Double(gamerPct) / 100.0,
                            lineWidth: 7,
                            size: 64,
                            tint: gamerColor,
                            track: Color.primary.opacity(0.12),
                            label: {
                                Text("\(Int(round(gamerPct)))%")
                                    .font(.footnote.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(gamerColor)
                            }
                        )
                        .accessibilityLabel(Text("Gamer Score \(Int(round(gamerPct))) percent"))
                        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: gamerPct)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("Gamer Score")
                                .font(.headline)
                            // Medal/tier chip removed
                        }
                        // Removed the "X correct out of Y total" subtitle
                    }
                    Spacer()
                }

                // KPIs
                if !isEmpty {
                    HStack(spacing: 8) {
                        metricChip(title: "Accuracy", value: "\(Int(round(gamerPct)))%", tint: gamerColor)
                        metricChip(title: "Played", value: "\(totalAnswered)", tint: .blue)
                        metricChip(title: "Correct", value: "\(totalCorrect)", tint: .green)
                        let overallBestStreak = entries.map { $0.bestStreak ?? 0 }.max() ?? 0
                        metricChip(title: "Best Streak", value: overallBestStreak > 0 ? "\(overallBestStreak)" : "—", tint: .orange)
                    }
                }

                // Distribution mini chart
                if !isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Where you play")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Chart {
                            ForEach(Array(entries.enumerated()), id: \.offset) { pair in
                                let idx = pair.offset
                                let entry = pair.element
                                let share = shares[idx]
                                BarMark(
                                    x: .value("Game", entry.name),
                                    y: .value("Share", Int(round(share)))
                                )
                                .foregroundStyle(Color.accentColor.opacity(0.85))
                                .cornerRadius(4)
                                .annotation(position: .top, alignment: .center) {
                                    Text("\(Int(round(share)))%")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .chartYAxis(.hidden)
                        .frame(height: 120)
                        .animation(.easeInOut(duration: 0.35), value: version)
                    }
                }

                // Badges / highlights — removed entirely (Sharpshooter, Specialist, etc.)

                // Player Stat Sheet with sorting
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
                    }
                }
                .padding(.top, 4)
            }
            .padding(.top, 2)
        } label: {
            Label("Games", systemImage: "gamecontroller")
        }
        .onAppear {
            // Nudge a refresh when the card becomes visible
            version &+= 1
        }
        // Drive animation refresh whenever stats.version changes (covers iPad tab caching)
        .onChange(of: stats.version) {
            version &+= 1
        }
        // Still listen for explicit notifications
        .onReceive(NotificationCenter.default.publisher(for: .gameStatsExternallyUpdated)) { _ in
            version &+= 1
        }
    }

    // MARK: - Subviews

    private func metricChip(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
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

// MARK: - Local small progress ring

private struct GamesProgressRing<Label: View>: View {
    let progress: Double
    let lineWidth: CGFloat
    let size: CGFloat
    let tint: Color
    let track: Color
    let label: Label

    init(progress: Double, lineWidth: CGFloat = 8, size: CGFloat = 56, tint: Color = .accentColor, track: Color = Color.primary.opacity(0.12), @ViewBuilder label: () -> Label) {
        self.progress = max(0, min(1, progress))
        self.lineWidth = lineWidth
        self.size = size
        self.tint = tint
        self.track = track
        self.label = label()
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            label
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Completion \(Int(round(progress * 100))) percent"))
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
