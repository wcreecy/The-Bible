import SwiftUI
import Charts

/// The Word game's extra statistics: how many guesses wins take, and how long puzzles take.
struct WordStatsSection: View {
    @Binding var wordScope: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Scope", selection: $wordScope) {
                Text("Combined").tag(2)
                Text("Normal").tag(0)
                Text("Hard").tag(1)
            }
            .pickerStyle(.segmented)

            let averageAndDist: (avg: Double, dist: [Int]) = {
                switch wordScope {
                case 0:
                    let (avg, dist) = GameStats.shared.wordleWinGuessStats(mode: .normal)
                    return (avg, dist)
                case 1:
                    let (avg, dist) = GameStats.shared.wordleWinGuessStats(mode: .hard)
                    return (avg, dist)
                default:
                    let (avg, dist) = GameStats.shared.wordleWinGuessStatsModesCombined()
                    return (avg, dist)
                }
            }()

            Text(String(format: "Average guesses per win: %.1f", averageAndDist.avg))
                .font(.headline)
                .monospacedDigit()

            Chart {
                ForEach(Array(zip(1...6, averageAndDist.dist)), id: \.0) { guess, count in
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
            .chartXScale(domain: 0.5...6.5)
            .chartPlotStyle { plot in
                plot.padding(.horizontal, 6)
            }
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
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartYAxisLabel(position: .leading, alignment: .center) {
                Text("Wins").rotationEffect(.degrees(180))
            }
            .frame(height: 180)

            let timeStats: (total: Int, wins: Int, losses: Int) = {
                switch wordScope {
                case 0: return GameStats.shared.wordleTimeStats(mode: .normal)
                case 1: return GameStats.shared.wordleTimeStats(mode: .hard)
                default: return GameStats.shared.wordleTimeStatsModesCombined()
                }
            }()

            let counts: (answered: Int, wins: Int, losses: Int) = {
                switch wordScope {
                case 0:
                    let c = GameStats.shared.wordleCounts(mode: .normal)
                    return (c.answered, c.wins, max(0, c.answered - c.wins))
                case 1:
                    let c = GameStats.shared.wordleCounts(mode: .hard)
                    return (c.answered, c.wins, max(0, c.answered - c.wins))
                default:
                    let n = GameStats.shared.wordleCounts(mode: .normal)
                    let h = GameStats.shared.wordleCounts(mode: .hard)
                    let answered = n.answered + h.answered
                    let wins = n.wins + h.wins
                    let losses = max(0, answered - wins)
                    return (answered, wins, losses)
                }
            }()

            let avgPerWinSeconds = (counts.wins > 0) ? max(0, timeStats.wins / max(1, counts.wins)) : 0
            let avgPerLossSeconds = (counts.losses > 0) ? max(0, timeStats.losses / max(1, counts.losses)) : 0
            let avgPerPuzzleSeconds = (counts.answered > 0) ? max(0, timeStats.total / max(1, counts.answered)) : 0

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
}
