import SwiftUI
import Charts

struct AllGamesComparisonCardView: View {
    @ObservedObject private var stats = GameStats.shared
    @State private var version: Int = 0

    // Sort options for the comparison
    fileprivate enum Sort: String, CaseIterable, Identifiable {
        case name = "Game"
        case played = "Played"
        case accuracy = "Accuracy"
        var id: String { rawValue }
    }
    @State private var sort: Sort = .played

    // Typed row model to simplify the chart builder
    fileprivate struct Row: Identifiable, Equatable {
        var id: String { name }
        let name: String
        let played: Int
        let accuracy: Double // 0...100
    }

    var body: some View {
        GroupBox {
            // Build a small, explicitly-typed data model first
            let breakdown = GameStats.shared.breakdownSnapshot()
            let entries = breakdown.entries
            let totalAnswered = breakdown.totalAnswered
            let isEmpty: Bool = (totalAnswered == 0)

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
                    // Derived metrics (typed rows)
                    let rows: [Row] = entries.map { e in
                        let played = max(0, e.answered)
                        let acc: Double = played > 0 ? min(100, max(0, (Double(max(0, e.correct)) / Double(played)) * 100.0)) : 0
                        return Row(name: e.name, played: played, accuracy: acc)
                    }

                    // Extract the chart into a small subview to keep the ViewBuilder simple
                    ChartView(rows: rows, sort: sort, version: version)

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
        .onChangeCompat(of: stats.version) { version &+= 1 }
        .onReceive(NotificationCenter.default.publisher(for: .gameStatsExternallyUpdated)) { _ in version &+= 1 }
    }
}

fileprivate extension AllGamesComparisonCardView {
    struct ChartView: View {
        let rows: [Row]
        let sort: Sort
        let version: Int

        private var sortedRows: [Row] {
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
        }

        private var maxPlayed: Int {
            max(1, sortedRows.map { $0.played }.max() ?? 1)
        }

        // Scale accuracy (0–100%) into the same Y-domain as "Played"
        private var scale: Double { Double(maxPlayed) / 100.0 }
        private var trailingAxisTicks: [Double] {
            Array(stride(from: 0, through: 100, by: 20)).map { Double($0) * scale }
        }
        private var yMax: Double { Double(maxPlayed) }

        var body: some View {
            Chart {
                ForEach(sortedRows) { row in
                    // Bars (Played)
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

                    // Line (Accuracy, scaled)
                    LineMark(
                        x: .value("Game", row.name),
                        y: .value("Accuracy (scaled)", row.accuracy * scale)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Color.green.opacity(0.8))

                    // Points (Accuracy, scaled)
                    PointMark(
                        x: .value("Game", row.name),
                        y: .value("Accuracy (scaled)", row.accuracy * scale)
                    )
                    .foregroundStyle(Color.green.opacity(0.9))
                }
            }
            // Left Y-axis: raw counts/minutes
            .chartYAxis {
                AxisMarks(position: .leading)
                // Right Y-axis: percentage labels aligned to the scaled accuracy line
                AxisMarks(position: .trailing, values: trailingAxisTicks) { value in
                    AxisTick()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            let pct = Int(round(v / scale))
                            Text("\(pct)%")
                        }
                    }
                }
            }
            .chartYScale(domain: 0...yMax)
            .frame(height: 180)
            .animation(.easeInOut(duration: 0.35), value: version)
        }
    }
}

// MARK: - Compatibility helper to silence iOS 17 deprecation while supporting earlier OS versions
fileprivate struct OnChangeCompatModifier<Value: Equatable>: ViewModifier {
    let value: Value
    let action: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) {
            content.onChange(of: value) {
                action()
            }
        } else {
            content.onChange(of: value) { _ in
                action()
            }
        }
    }
}

fileprivate extension View {
    func onChangeCompat<Value: Equatable>(of value: Value, _ action: @escaping () -> Void) -> some View {
        self.modifier(OnChangeCompatModifier(value: value, action: action))
    }
}
