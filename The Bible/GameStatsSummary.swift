import SwiftUI
import Charts

/// The headline numbers at the top of the Games card: for all games, one game, or one Word mode.
struct GameStatsKPI {
    let accuracyPct: Double
    let played: Int
    let correct: Int
    let bestStreak: Int

    init(selectedGame: String, wordScope: Int, breakdown: GameStats.GameBreakdown) {
        let entries = breakdown.entries

        if selectedGame == "Word" {
            let scoped = Self.wordScoped(wordScope: wordScope)
            accuracyPct = scoped.accPct
            played = scoped.played
            correct = scoped.correct
            bestStreak = scoped.bestStreak
        } else if selectedGame == "All Games" {
            accuracyPct = breakdown.percentage
            played = breakdown.totalAnswered
            correct = breakdown.totalCorrect
            bestStreak = entries.map { $0.bestStreak ?? 0 }.max() ?? 0
        } else {
            let selectedEntry = entries.first(where: { $0.name == selectedGame })
            let answered = selectedEntry?.answered ?? 0
            accuracyPct = answered > 0 ? (Double(selectedEntry?.correct ?? 0) / Double(answered)) * 100.0 : 0
            played = answered
            correct = selectedEntry?.correct ?? 0
            bestStreak = selectedEntry?.bestStreak ?? 0
        }
    }

    /// Word is split by Normal and Hard, with a combined view.
    private static func wordScoped(wordScope: Int) -> (accPct: Double, played: Int, correct: Int, bestStreak: Int) {
        let n = GameStats.shared.wordleCounts(mode: .normal)
        let h = GameStats.shared.wordleCounts(mode: .hard)

        let bestN = UserDefaults.standard.integer(forKey: "wordleAllTimeBestStreak_normal")
        let bestH = UserDefaults.standard.integer(forKey: "wordleAllTimeBestStreak_hard")
        let bestAll = UserDefaults.standard.integer(forKey: "wordleAllTimeBestStreak_all")

        switch wordScope {
        case 0:
            let a = n.answered
            let w = n.wins
            let pct = a > 0 ? min(100, max(0, (Double(w) / Double(a)) * 100.0)) : 0
            return (pct, a, w, bestN)
        case 1:
            let a = h.answered
            let w = h.wins
            let pct = a > 0 ? min(100, max(0, (Double(w) / Double(a)) * 100.0)) : 0
            return (pct, a, w, bestH)
        default:
            let a = n.answered + h.answered
            let w = n.wins + h.wins
            let pct = a > 0 ? min(100, max(0, (Double(w) / Double(a)) * 100.0)) : 0
            let best = max(bestN, bestH, bestAll)
            return (pct, a, w, best)
        }
    }
}

/// The metrics grid and the 30-day activity chart, for all games or one game.
struct GameStatsActivitySummary: View {
    let selectedGame: String
    let wordScope: Int
    let version: Int
    let kpi: GameStatsKPI

    var body: some View {
        let kpiAccuracyTint = Color.gamerScoreColor(for: kpi.accuracyPct)

        let series30: [(date: Date, answered: Int, correct: Int)] = {
            if selectedGame == "All Games" {
                return GameStats.shared.dailySeriesLast(days: 30)
            } else if selectedGame == "Word" {
                switch wordScope {
                case 0: return GameStats.shared.dailySeriesLast(days: 30, forWordMode: .normal)
                case 1: return GameStats.shared.dailySeriesLast(days: 30, forWordMode: .hard)
                default: return GameStats.shared.dailySeriesLast(days: 30, forDisplayName: selectedGame)
                }
            } else {
                return GameStats.shared.dailySeriesLast(days: 30, forDisplayName: selectedGame)
            }
        }()
        let activeDays30 = series30.filter { $0.answered > 0 }.count
        let totalPlayed30 = series30.reduce(0) { $0 + max(0, $1.answered) }
        let avgPerActive = activeDays30 > 0 ? totalPlayed30 / activeDays30 : 0
        let streaksInfo: (current: Int, longest: Int) = {
            if selectedGame == "All Games" {
                return GameStats.shared.activityStreaks()
            } else if selectedGame == "Word" {
                switch wordScope {
                case 0: return GameStats.shared.activityStreaks(forWordMode: .normal)
                case 1: return GameStats.shared.activityStreaks(forWordMode: .hard)
                default: return GameStats.shared.activityStreaks(forDisplayName: selectedGame)
                }
            } else {
                return GameStats.shared.activityStreaks(forDisplayName: selectedGame)
            }
        }()
        let trend7: (currentPct: Double, deltaVsPrev: Double) = {
            if selectedGame == "All Games" {
                return GameStats.shared.accuracy7DayTrend()
            } else if selectedGame == "Word" {
                switch wordScope {
                case 0: return GameStats.shared.accuracy7DayTrend(forWordMode: .normal)
                case 1: return GameStats.shared.accuracy7DayTrend(forWordMode: .hard)
                default: return GameStats.shared.accuracy7DayTrend(forDisplayName: selectedGame)
                }
            } else {
                return GameStats.shared.accuracy7DayTrend(forDisplayName: selectedGame)
            }
        }()
        let currentTrendAttempts = series30.suffix(7).reduce(0) { $0 + $1.answered }
        let previousTrendAttempts = series30.dropLast(7).suffix(7).reduce(0) { $0 + $1.answered }
        let hasTrendComparison = currentTrendAttempts > 0 && previousTrendAttempts > 0
        let trendTint: Color = trend7.deltaVsPrev >= 0 ? .green : .red
        let trendArrow: String = trend7.deltaVsPrev >= 0 ? "arrow.up.right" : "arrow.down.right"
        let hasRecentActivity30 = series30.contains { $0.answered > 0 }

        VStack(alignment: .leading, spacing: 10) {
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    MetricChip(title: "Accuracy", value: "\(Int(round(kpi.accuracyPct)))%", tint: kpiAccuracyTint, fillsWidth: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    MetricChip(title: "Attempts", value: "\(kpi.played)", tint: .blue, fillsWidth: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                GridRow {
                    MetricChip(title: "Correct", value: "\(kpi.correct)", tint: .green, fillsWidth: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    MetricChip(title: "Best Streak", value: kpi.bestStreak > 0 ? "\(kpi.bestStreak)" : "—", tint: .orange, fillsWidth: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                GridRow {
                    MetricChip(title: "Active Days (30D)", value: "\(activeDays30)", tint: .purple, fillsWidth: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    MetricChip(title: "Attempts / Active Day", value: "\(avgPerActive)", tint: .teal, fillsWidth: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                GridRow {
                    MetricChip(title: "Current Streak", value: streaksInfo.current > 0 ? "\(streaksInfo.current)" : "—", tint: .orange, fillsWidth: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    MetricChip(title: "Longest Streak", value: "\(streaksInfo.longest)", tint: .orange, fillsWidth: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                GridRow {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("7-Day Accuracy Trend")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Text(currentTrendAttempts > 0 ? "\(Int(round(trend7.currentPct)))%" : "No recent attempts")
                                .font(.footnote.weight(.semibold))
                                .monospacedDigit()
                            if hasTrendComparison {
                                Image(systemName: trendArrow)
                                    .foregroundStyle(trendTint)
                                Text("\(Int(round(abs(trend7.deltaVsPrev)))) pts")
                                    .font(.caption.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(trendTint)
                            } else if currentTrendAttempts > 0 {
                                Text("No previous data")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(trendTint.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(trendTint.opacity(0.25), lineWidth: 1)
                    )
                    .gridCellColumns(2)
                }
            }

            if !hasRecentActivity30 {
                Text("No recent activity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }

            Chart {
                ForEach(series30, id: \.date) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Attempts", point.answered)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Color.accentColor.opacity(hasRecentActivity30 ? 0.9 : 0.35))
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Attempts", point.answered)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Color.accentColor.opacity(hasRecentActivity30 ? 0.18 : 0.08))
                }

                if selectedGame == "Word" {
                    let solvedKeys: Set<String> = GameStats.shared.wordleDailySolvedDayKeysLast(days: 30)
                    ForEach(series30, id: \.date) { point in
                        let key = {
                            var cal = Calendar.autoupdatingCurrent
                            cal.timeZone = .autoupdatingCurrent
                            return GameStats.localDayKey(for: point.date, calendar: cal)
                        }()
                        if solvedKeys.contains(key) {
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Played", point.answered)
                            )
                            .symbolSize(28)
                            .foregroundStyle(Color.yellow.opacity(0.9))
                        }
                    }
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 56)
            .accessibilityLabel("Played per day in the last 30 days")
            .animation(.easeInOut(duration: 0.35), value: version)

            Text("Questions per day (last 30 days)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if selectedGame == "All Games", hasRecentActivity30 {
                let bestDay: (date: Date, answered: Int, accuracy: Double)? = {
                    let maxA = series30.map { $0.answered }.max() ?? 0
                    guard maxA > 0 else { return nil }
                    let candidates = series30.filter { $0.answered == maxA }
                    let withAccuracy = candidates.map { p -> (Date, Int, Double) in
                        let pct = p.answered > 0 ? (Double(p.correct) / Double(p.answered)) * 100.0 : 0
                        return (p.date, p.answered, pct)
                    }
                    let sorted = withAccuracy.sorted {
                        if $0.2 == $1.2 {
                            return $0.0 > $1.0
                        }
                        return $0.2 > $1.2
                    }
                    if let top = sorted.first {
                        return (top.0, top.1, top.2)
                    }
                    return nil
                }()

                if let best = bestDay {
                    Text("Best day in last 30 days: \(best.date.formatted(date: .abbreviated, time: .omitted)) — \(best.answered) questions, \(Int(round(best.accuracy)))% accuracy")
                        .font(.footnote)
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .padding(.top, 4)
                }
            }
        }
    }
}
