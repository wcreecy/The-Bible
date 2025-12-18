import SwiftUI
import Charts

struct WordleStatsCardView: View {
    // Re-render when GameStats publishes changes (iCloud merges, writes, etc.)
    @ObservedObject private var stats = GameStats.shared

    // 0 = Daily, 1 = Free, 2 = Combined
    @State private var selection: Int = 2

    private var averageAndDist: (avg: Double, dist: [Int]) {
        switch selection {
        case 0:
            let (avg, dist) = GameStats.shared.wordleWinGuessStats(type: .daily)
            return (avg, dist)
        case 1:
            let (avg, dist) = GameStats.shared.wordleWinGuessStats(type: .free)
            return (avg, dist)
        default:
            let (avg, dist) = GameStats.shared.wordleWinGuessStatsCombined()
            return (avg, dist)
        }
    }

    var body: some View {
        GroupBox {
            // Depend on stats.version so external sync merges re-render
            let _ = stats.version

            VStack(alignment: .leading, spacing: 12) {
                // Scope picker
                Picker("Scope", selection: $selection) {
                    Text("Daily").tag(0)
                    Text("Free").tag(1)
                    Text("Combined").tag(2)
                }
                .pickerStyle(.segmented)

                let (avg, dist) = averageAndDist

                // Average
                Text(String(format: "Average guesses per win: %.1f", avg))
                    .font(.headline)
                    .monospacedDigit()

                // Bar chart for 1…6 guesses
                Chart {
                    ForEach(Array(zip(1...6, dist)), id: \.0) { guess, count in
                        BarMark(
                            x: .value("Guesses", guess),
                            y: .value("Wins", count)
                        )
                        .foregroundStyle(Color.accentColor.opacity(0.85))
                        .cornerRadius(4)
                        .annotation(position: .top, alignment: .center) {
                            if count > 0 {
                                Text("\(count)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                // Add small margins so bars 1 and 6 aren’t clipped
                .chartXScale(domain: 0.5...6.5)
                // Tighten plot area slightly to help labels fit
                .chartPlotStyle { plot in
                    plot
                        .padding(.horizontal, 6)
                }
                // X axis: 1…6 labeled and titled “Guesses”
                .chartXAxis {
                    AxisMarks(values: Array(1...6)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let g = value.as(Int.self) {
                                Text("\(g)").font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxisLabel("Guesses", alignment: .center)

                // Y axis: show ticks/labels and title “Wins” centered on the leading axis
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartYAxisLabel(position: .leading, alignment: .center) {
                    Text("Wins")
                        .rotationEffect(.degrees(180))
                }

                .frame(height: 180)
            }
            .padding(.top, 2)
        } label: {
            Text("Wordle")
        }
        // Still listen for explicit notifications (belt-and-suspenders)
        .onReceive(NotificationCenter.default.publisher(for: .gameStatsExternallyUpdated)) { _ in
            // @ObservedObject(stats) already triggers re-render
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            WordleStatsCardView()
        }
        .padding()
    }
}
