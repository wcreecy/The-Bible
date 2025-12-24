import SwiftUI
import Charts

struct AllGamesComparisonCardView: View {
    @ObservedObject private var stats = GameStats.shared
    @State private var version: Int = 0

    // Sort options for the comparison
    private enum Sort: String, CaseIterable, Identifiable {
        case name = "Game"
        case played = "Played"
        case accuracy = "Accuracy"
        var id: String { rawValue }
    }
    @State private var sort: Sort = .played

    var body: some View {
        GroupBox {
            let _ = stats.version

            let breakdown = GameStats.shared.breakdownSnapshot()
            let entries = breakdown.entries
            let totalAnswered = breakdown.totalAnswered
            let isEmpty = (totalAnswered == 0)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("All Games Comparison")
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
                    // Derived metrics
                    let rows: [(name: String, played: Int, accuracy: Double)] = entries.map { e in
                        let played = max(0, e.answered)
                        let acc = played > 0 ? min(100, max(0, (Double(max(0, e.correct)) / Double(played)) * 100.0)) : 0
                        return (e.name, played, acc)
                    }

                    let sorted: [(name: String, played: Int, accuracy: Double)] = {
                        switch sort {
                        case .name:
                            return rows.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                        case .played:
                            return rows.sorted {
                                if $0.played == $1.played { return $0.name < $1.name }
                                return $0.played > $1.played
                            }
                        case .accuracy:
                            return rows.sorted {
                                if $0.accuracy == $1.accuracy { return $0.name < $1.name }
                                return $0.accuracy > $1.accuracy
                            }
                        }
                    }()

                    // Dual-axis style: bars for Played, line for Accuracy
                    Chart {
                        ForEach(sorted, id: \.name) { row in
                            BarMark(
                                x: .value("Game", row.name),
                                y: .value("Played", row.played)
                            )
                            .foregroundStyle(Color.accentColor.opacity(0.85))
                            .cornerRadius(4)
                            .annotation(position: .top, alignment: .center) {
                                if row.played > 0 {
                                    Text("\(row.played)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }

                            LineMark(
                                x: .value("Game", row.name),
                                y: .value("Accuracy", row.accuracy)
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Color.green.opacity(0.8))

                            PointMark(
                                x: .value("Game", row.name),
                                y: .value("Accuracy", row.accuracy)
                            )
                            .foregroundStyle(Color.green.opacity(0.9))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartYAxis {
                        AxisMarks(position: .trailing)
                    }
                    .frame(height: 180)
                    .animation(.easeInOut(duration: 0.35), value: version)

                    // Legend-like caption
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 3).fill(Color.accentColor.opacity(0.85)).frame(width: 12, height: 12)
                            Text("Played")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 6) {
                            Circle().fill(Color.green.opacity(0.9)).frame(width: 8, height: 8)
                            Text("Accuracy (%)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.top, 2)
        } label: {
            Label("All Games Comparison", systemImage: "chart.bar.xaxis")
        }
        .onAppear { version &+= 1 }
        .onChange(of: stats.version) { _, _ in version &+= 1 }
        .onReceive(NotificationCenter.default.publisher(for: .gameStatsExternallyUpdated)) { _ in version &+= 1 }
    }
}
