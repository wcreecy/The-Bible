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

    private var timeStats: (total: Int, wins: Int, losses: Int) {
        switch selection {
        case 0:
            return GameStats.shared.wordleTimeStats(type: .daily)
        case 1:
            return GameStats.shared.wordleTimeStats(type: .free)
        default:
            return GameStats.shared.wordleTimeStatsCombined()
        }
    }

    // Counts for denominators used by averages (wins, losses, answered)
    private var counts: (answered: Int, wins: Int, losses: Int) {
        let defaults = UserDefaults.standard
        switch selection {
        case 0: // Daily
            let wins = max(0, defaults.integer(forKey: "wordleAllTimeCorrect_daily"))
            let answered = max(0, defaults.integer(forKey: "wordleAllTimeAnswered_daily"))
            let losses = max(0, answered - wins)
            return (answered, wins, losses)
        case 1: // Free
            let wins = max(0, defaults.integer(forKey: "wordleAllTimeCorrect_free"))
            let answered = max(0, defaults.integer(forKey: "wordleAllTimeAnswered_free"))
            let losses = max(0, answered - wins)
            return (answered, wins, losses)
        default: // Combined (daily + free)
            let wins = max(0, defaults.integer(forKey: "wordleAllTimeCorrect_daily")) + max(0, defaults.integer(forKey: "wordleAllTimeCorrect_free"))
            let answered = max(0, defaults.integer(forKey: "wordleAllTimeAnswered_daily")) + max(0, defaults.integer(forKey: "wordleAllTimeAnswered_free"))
            let losses = max(0, answered - wins)
            return (answered, wins, losses)
        }
    }

    private func formatSeconds(_ s: Int) -> String {
        let seconds = max(0, s)
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let sec = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        } else {
            return String(format: "%d:%02d", m, sec)
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

                // Averages: per win, per loss, per puzzle
                let t = timeStats
                let c = counts
                let avgPerWinSeconds = (c.wins > 0) ? max(0, t.wins / max(1, c.wins)) : 0
                let avgPerLossSeconds = (c.losses > 0) ? max(0, t.losses / max(1, c.losses)) : 0
                let avgPerPuzzleSeconds = (c.answered > 0) ? max(0, t.total / max(1, c.answered)) : 0

                VStack(alignment: .leading, spacing: 6) {
                    Text("Average Time Spent")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        timingPill(title: "Per Win", value: formatSeconds(avgPerWinSeconds), tint: .green)
                        timingPill(title: "Per Loss", value: formatSeconds(avgPerLossSeconds), tint: .red)
                        timingPill(title: "Per Puzzle", value: formatSeconds(avgPerPuzzleSeconds), tint: .purple)
                    }
                }
                .padding(.top, 2)
            }
            .padding(.top, 2)
        } label: {
            Text("WORD")
        }
        // Still listen for explicit notifications (belt-and-suspenders)
        .onReceive(NotificationCenter.default.publisher(for: .gameStatsExternallyUpdated)) { _ in
            // @ObservedObject(stats) already triggers re-render
        }
    }

    private func timingPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
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
