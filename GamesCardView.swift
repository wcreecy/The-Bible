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
            // New: raw counts for the mini chart (number of games played per game)
            let counts: [Int] = entries.map { s in s.answered }

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

                // NEW: Activity & Trend (last 30 days + 7D accuracy delta)
                if !isEmpty {
                    let series30 = GameStats.shared.dailySeriesLast(days: 30)
                    let activeDays30 = series30.filter { $0.answered > 0 }.count
                    let totalPlayed30 = series30.reduce(0) { $0 + max(0, $1.answered) }
                    let avgPerActive = activeDays30 > 0 ? totalPlayed30 / activeDays30 : 0
                    let streaksInfo = GameStats.shared.activityStreaks()
                    let trend7 = GameStats.shared.accuracy7DayTrend()
                    let trendTint: Color = trend7.deltaVsPrev >= 0 ? .green : .red
                    let trendArrow: String = trend7.deltaVsPrev >= 0 ? "arrow.up.right" : "arrow.down.right"
                    let hasRecentActivity30 = series30.contains { $0.answered > 0 }

                    VStack(alignment: .leading, spacing: 8) {
                        // Make this KPI row horizontally scrollable
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                metricChip(title: "Active Days (30D)", value: "\(activeDays30)", tint: .purple)
                                metricChip(title: "Qs/Day", value: "\(avgPerActive)", tint: .teal)
                                metricChip(title: "Current Streak", value: streaksInfo.current > 0 ? "\(streaksInfo.current)" : "—", tint: .orange)
                                metricChip(title: "Longest Streak", value: streaksInfo.longest > 0 ? "\(streaksInfo.longest)" : "—", tint: .orange)
                                // 7D accuracy with delta (keep normal size)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("7D Accuracy")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    HStack(spacing: 6) {
                                        Text("\(Int(round(trend7.currentPct)))%")
                                            .font(.footnote.weight(.semibold))
                                            .monospacedDigit()
                                        Image(systemName: trendArrow)
                                            .foregroundStyle(trendTint)
                                        Text("\(Int(round(abs(trend7.deltaVsPrev))))%")
                                            .font(.caption.weight(.semibold))
                                            .monospacedDigit()
                                            .foregroundStyle(trendTint)
                                    }
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(trendTint.opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(trendTint.opacity(0.25), lineWidth: 1)
                                )
                            }
                            .padding(.horizontal, 2)
                        }

                        if !hasRecentActivity30 {
                            Text("No recent activity")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        }

                        // 30-day sparkline of Played (answered)
                        Chart {
                            ForEach(series30, id: \.date) { point in
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Played", point.answered)
                                )
                                .interpolationMethod(.monotone)
                                .foregroundStyle(Color.accentColor.opacity(hasRecentActivity30 ? 0.9 : 0.35))
                                AreaMark(
                                    x: .value("Date", point.date),
                                    y: .value("Played", point.answered)
                                )
                                .interpolationMethod(.monotone)
                                .foregroundStyle(Color.accentColor.opacity(hasRecentActivity30 ? 0.18 : 0.08))
                            }
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .frame(height: 56)
                        .accessibilityLabel("Played per day in the last 30 days")
                        .animation(.easeInOut(duration: 0.35), value: version)

                        // Caption clarifying the sparkline
                        Text("Questions per day (last 30 days)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // 7D accuracy with delta (kept below for accessibility summary)
                        HStack(spacing: 6) {
                            Text("7D Accuracy")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(Int(round(trend7.currentPct)))%")
                                .font(.footnote.weight(.semibold))
                                .monospacedDigit()
                            Image(systemName: trendArrow)
                                .foregroundStyle(trendTint)
                            Text("\(Int(round(abs(trend7.deltaVsPrev))))%")
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(trendTint)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("7 day accuracy \(Int(round(trend7.currentPct))) percent, \(trend7.deltaVsPrev >= 0 ? "up" : "down") \(Int(round(abs(trend7.deltaVsPrev)))) percent from prior 7 days")
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
                                let count = counts[idx]
                                BarMark(
                                    x: .value("Game", entry.name),
                                    y: .value("Played", count)
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
                        .chartYAxis(.hidden)
                        .frame(height: 120)
                        .animation(.easeInOut(duration: 0.35), value: version)
                    }
                }

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

// MARK: - Split cards (Overview + Player Stat Sheet)

struct GamesOverviewCardView: View {
    @ObservedObject private var stats = GameStats.shared
    @State private var version: Int = 0

    // Size class to adapt header layout on iPhone
    @Environment(\.horizontalSizeClass) private var hSizeClass

    // Persist the selected game across launches
    @AppStorage("statsSelectedGame") private var selectedGame: String = "All Games"

    // Sleek icon for each game
    private func gameIcon(for name: String) -> String {
        switch name {
        case "All Games":    return "sparkles"
        case "Bible Quiz":   return "questionmark.circle"
        case "Hangman":      return "figure"
        case "Verse Match":  return "text.badge.checkmark"
        case "Beat the Clock": return "timer"
        case "Book Order":   return "books.vertical"
        case "Who am I?":    return "person.crop.circle.badge.questionmark"
        case "WORD":         return "square.grid.3x3"
        default:             return "gamecontroller"
        }
    }

    // Custom sort key: treat "WORD" as "Who am I?" for ordering.
    private func sortKey(for name: String) -> String {
        let key = (name == "WORD") ? "Who am I?" : name
        return key.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .autoupdatingCurrent)
    }

    // Stable comparator that forces "Who am I?" above "WORD" when keys tie.
    private func gameNameComparator(_ lhs: String, _ rhs: String) -> Bool {
        let l = sortKey(for: lhs)
        let r = sortKey(for: rhs)
        if l == r {
            // Explicit priority: Who am I? first, then WORD, then deterministic fallback
            let priority: [String: Int] = ["Who am I?": 0, "WORD": 1]
            let pl = priority[lhs] ?? 2
            let pr = priority[rhs] ?? 2
            if pl != pr { return pl < pr }
            // Deterministic fallback to avoid instability
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
        return l.localizedCompare(r) == .orderedAscending
    }

    // WORD scope picker state (0=Normal, 1=Hard, 2=Combined)
    @State private var wordScope: Int = 2

    // Bible Quiz: weak books controls
    @State private var weakBooksScope: Int = 0 // 0=30 days, 1=60 days
    @State private var weakBooksMinAttempts: Int = 5

    var body: some View {
        GroupBox {
            let _ = stats.version

            let breakdown = GameStats.shared.breakdownSnapshot()
            let entries = breakdown.entries
            let totalAnswered = breakdown.totalAnswered
            let totalCorrect = breakdown.totalCorrect
            let overallPct = breakdown.percentage
            let isEmpty = (totalAnswered == 0)

            // Alphabetical picker options, case/diacritic-insensitive, with a stable tiebreaker:
            // "Who am I?" must always appear above "WORD".
            let availableNames = Array(Set(entries.map { $0.name }))
            let pickerOptions = ["All Games"] + availableNames.sorted(by: gameNameComparator)

            // Resolve selected entry (if any)
            let selectedEntry = entries.first(where: { $0.name == selectedGame })

            // WORD-scoped KPIs and ring values when selected
            let wordScoped: (accPct: Double, played: Int, correct: Int, bestStreak: Int)? = {
                guard selectedGame == "WORD" else { return nil }

                // Per-mode counts
                let n = GameStats.shared.wordleCounts(mode: .normal)
                let h = GameStats.shared.wordleCounts(mode: .hard)

                // Best streaks from persisted keys (include legacy _all for combined)
                let bestN = UserDefaults.standard.integer(forKey: "wordleAllTimeBestStreak_normal")
                let bestH = UserDefaults.standard.integer(forKey: "wordleAllTimeBestStreak_hard")
                let bestAll = UserDefaults.standard.integer(forKey: "wordleAllTimeBestStreak_all")

                switch wordScope {
                case 0: // Normal
                    let a = n.answered
                    let w = n.wins
                    let pct = a > 0 ? min(100, max(0, (Double(w) / Double(a)) * 100.0)) : 0
                    return (pct, a, w, bestN)
                case 1: // Hard
                    let a = h.answered
                    let w = h.wins
                    let pct = a > 0 ? min(100, max(0, (Double(w) / Double(a)) * 100.0)) : 0
                    return (pct, a, w, bestH)
                default: // Combined
                    let a = n.answered + h.answered
                    let w = n.wins + h.wins
                    let pct = a > 0 ? min(100, max(0, (Double(w) / Double(a)) * 100.0)) : 0
                    let best = max(bestN, bestH, bestAll)
                    return (pct, a, w, best)
                }
            }()

            // KPIs per selection (falls back to generic for non-WORD)
            let kpiAccuracyPct: Double = {
                if selectedGame == "WORD", let scoped = wordScoped { return scoped.accPct }
                if selectedGame == "All Games" { return overallPct }
                let ans = selectedEntry?.answered ?? 0
                guard ans > 0 else { return 0 }
                return (Double(selectedEntry?.correct ?? 0) / Double(ans)) * 100.0
            }()
            let kpiAccuracyTint = Color.gamerScoreColor(for: kpiAccuracyPct)

            let kpiPlayed: Int = {
                if selectedGame == "WORD", let scoped = wordScoped { return scoped.played }
                return (selectedGame == "All Games") ? totalAnswered : (selectedEntry?.answered ?? 0)
            }()

            let kpiCorrect: Int = {
                if selectedGame == "WORD", let scoped = wordScoped { return scoped.correct }
                return (selectedGame == "All Games") ? totalCorrect : (selectedEntry?.correct ?? 0)
            }()

            let kpiBestStreak: Int = {
                if selectedGame == "WORD", let scoped = wordScoped { return scoped.bestStreak }
                if selectedGame == "All Games" {
                    return entries.map { $0.bestStreak ?? 0 }.max() ?? 0
                } else {
                    return selectedEntry?.bestStreak ?? 0
                }
            }()

            // Displayed gamer score in the ring (overall vs per-game or WORD-scoped)
            let displayPct: Double = {
                if selectedGame == "WORD", let scoped = wordScoped { return scoped.accPct }
                return (selectedGame == "All Games") ? overallPct : kpiAccuracyPct
            }()
            let displayTint: Color = Color.gamerScoreColor(for: displayPct)

            VStack(alignment: .leading, spacing: 10) {
                // Single-row header with picker (compact tweaks)
                HStack(spacing: hSizeClass == .compact ? 10 : 12) {
                    if isEmpty {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.accentColor.opacity(0.08))
                            .frame(width: hSizeClass == .compact ? 52 : 64,
                                   height: hSizeClass == .compact ? 52 : 64)
                            .overlay(
                                Image(systemName: "gamecontroller")
                                    .font(hSizeClass == .compact ? .title3 : .title2)
                                    .foregroundStyle(.secondary)
                            )
                            .accessibilityHidden(true)
                    } else {
                        GamesProgressRing(
                            progress: Double(displayPct) / 100.0,
                            lineWidth: hSizeClass == .compact ? 6 : 7,
                            size: hSizeClass == .compact ? 52 : 64,
                            tint: displayTint,
                            track: Color.primary.opacity(0.12)
                        ) {
                            Text("\(Int(round(displayPct)))%")
                                .font(hSizeClass == .compact ? .caption2.weight(.semibold) : .footnote.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(displayTint)
                        }
                        .accessibilityLabel(Text("Gamer Score \(Int(round(displayPct))) percent"))
                        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: displayPct)
                    }

                    Text("Gamer Score")
                        .font(.headline)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Picker(selection: $selectedGame) {
                        ForEach(pickerOptions, id: \.self) { name in
                            Label(name, systemImage: gameIcon(for: name))
                                .font(.caption2)
                                .tag(name)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: gameIcon(for: selectedGame))
                            Text(selectedGame)
                                .lineLimit(1)
                                .minimumScaleFactor(hSizeClass == .compact ? 0.6 : 0.7)
                                .allowsTightening(true)
                            Image(systemName: "chevron.down")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption2.weight(.semibold))
                        .padding(.vertical, hSizeClass == .compact ? 1 : 2)
                        .padding(.horizontal, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                        .contentShape(Capsule())
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Select Game")
                        .accessibilityValue(selectedGame)
                    }
                    .pickerStyle(.menu)
                    .controlSize(.mini)
                    .animation(.easeInOut(duration: 0.2), value: selectedGame)
                }

                // Keep a horizontal line between the header and stats
                Divider()

                if !isEmpty {
                    // KPIs reflect selected game (and WORD scope when applicable)
                    HStack(spacing: 8) {
                        metricChip(title: "Accuracy", value: "\(Int(round(kpiAccuracyPct)))%", tint: kpiAccuracyTint)
                        metricChip(title: "Played", value: "\(kpiPlayed)", tint: .blue)
                        metricChip(title: "Correct", value: "\(kpiCorrect)", tint: .green)
                        metricChip(title: "Best Streak", value: (kpiBestStreak > 0 ? "\(kpiBestStreak)" : "—"), tint: .orange)
                    }

                    // NEW: Activity & Trend row for Overview — scoped to selectedGame
                    let series30 = (selectedGame == "All Games")
                        ? GameStats.shared.dailySeriesLast(days: 30)
                        : GameStats.shared.dailySeriesLast(days: 30, forDisplayName: selectedGame)
                    let activeDays30 = series30.filter { $0.answered > 0 }.count
                    let totalPlayed30 = series30.reduce(0) { $0 + max(0, $1.answered) }
                    let avgPerActive = activeDays30 > 0 ? totalPlayed30 / activeDays30 : 0
                    let streaksInfo = (selectedGame == "All Games")
                        ? GameStats.shared.activityStreaks()
                        : GameStats.shared.activityStreaks(forDisplayName: selectedGame)
                    let trend7 = (selectedGame == "All Games")
                        ? GameStats.shared.accuracy7DayTrend()
                        : GameStats.shared.accuracy7DayTrend(forDisplayName: selectedGame)
                    let trendTint: Color = trend7.deltaVsPrev >= 0 ? .green : .red
                    let trendArrow: String = trend7.deltaVsPrev >= 0 ? "arrow.up.right" : "arrow.down.right"
                    let hasRecentActivity30 = series30.contains { $0.answered > 0 }

                    // Make this KPI row horizontally scrollable so 7D chip has normal size
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            metricChip(title: "Active Days (30D)", value: "\(activeDays30)", tint: .purple)
                            metricChip(title: "Qs/Day", value: "\(avgPerActive)", tint: .teal)
                            metricChip(title: "Current Streak", value: streaksInfo.current > 0 ? "\(streaksInfo.current)" : "—", tint: .orange)
                            metricChip(title: "Longest Streak", value: streaksInfo.longest > 0 ? "\(streaksInfo.longest)" : "—", tint: .orange)
                            // 7D Accuracy with delta (normal size chip)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("7D Accuracy")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 4) {
                                    Text("\(Int(round(trend7.currentPct)))%")
                                        .font(.footnote.weight(.semibold))
                                        .monospacedDigit()
                                    Image(systemName: trendArrow)
                                        .foregroundStyle(trendTint)
                                    Text("\(Int(round(abs(trend7.deltaVsPrev))))%")
                                        .font(.caption.weight(.semibold))
                                        .monospacedDigit()
                                        .foregroundStyle(trendTint)
                                }
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(trendTint.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(trendTint.opacity(0.25), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 2)
                    }

                    if !hasRecentActivity30 {
                        Text("No recent activity")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }

                    // 30-day sparkline — scoped to selected game
                    Chart {
                        ForEach(series30, id: \.date) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Played", point.answered)
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Color.accentColor.opacity(hasRecentActivity30 ? 0.9 : 0.35))
                            AreaMark(
                                x: .value("Date", point.date),
                                y: .value("Played", point.answered)
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Color.accentColor.opacity(hasRecentActivity30 ? 0.18 : 0.08))
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 56)
                    .accessibilityLabel("Played per day in the last 30 days")
                    .animation(.easeInOut(duration: 0.35), value: version)

                    // Caption clarifying the sparkline
                    Text("Questions per day (last 30 days)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // NEW: Bible Quiz specific — Accuracy by Testament
                    if selectedGame == "Bible Quiz" {
                        let summary = GameStats.shared.quizOTNTSummary()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Accuracy by Testament (OT vs NT)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                metricChip(
                                    title: "OT",
                                    value: "\(Int(round(summary.otPct)))% (\(summary.otCorrect)/\(summary.otAnswered))",
                                    tint: .blue
                                )
                                metricChip(
                                    title: "NT",
                                    value: "\(Int(round(summary.ntPct)))% (\(summary.ntCorrect)/\(summary.ntAnswered))",
                                    tint: .green
                                )
                            }
                        }
                    }

                    // NEW: Bible Quiz specific — Accuracy by Genre (summary chips with horizontal scroll)
                    if selectedGame == "Bible Quiz" {
                        let rows = GameStats.shared.quizAccuracyByGenre()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Accuracy by Genre")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                                        // Choose a gentle tint per genre (fixed palette)
                                        let tint: Color = {
                                            switch row.genre {
                                            case "Law": return .blue
                                            case "History": return .teal
                                            case "Poetry": return .purple
                                            case "Major Prophets": return .orange
                                            case "Minor Prophets": return .pink
                                            case "Gospels": return .green
                                            case "Acts": return .indigo
                                            case "Epistles": return .cyan
                                            case "Apocalypse": return .red
                                            default: return .gray
                                            }
                                        }()
                                        metricChip(
                                            title: row.genre,
                                            value: "\(Int(round(row.pct)))% (\(row.correct)/\(row.answered))",
                                            tint: tint
                                        )
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                        }
                    }

                    // NEW: Bible Quiz specific — Top weak books (last 30/60 days)
                    if selectedGame == "Bible Quiz" {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Top Weak Books")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Picker("Scope", selection: $weakBooksScope) {
                                    Text("30D").tag(0)
                                    Text("60D").tag(1)
                                }
                                .pickerStyle(.segmented)
                                .frame(maxWidth: 140)
                            }

                            // Min attempts threshold control
                            HStack(spacing: 10) {
                                Text("Min attempts")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Stepper(value: $weakBooksMinAttempts, in: 1...50) {
                                    Text("\(weakBooksMinAttempts)")
                                        .font(.footnote.weight(.semibold))
                                        .monospacedDigit()
                                }
                                .frame(maxWidth: 180, alignment: .leading)
                                Spacer()
                            }

                            let days = (weakBooksScope == 0) ? 30 : 60
                            let allRows = GameStats.shared.quizWeakBooks(lastNDays: days, minAttempts: weakBooksMinAttempts)
                            let rows = Array(allRows.prefix(5)) // top 5 weakest

                            if rows.isEmpty {
                                Text("Not enough recent Bible Quiz activity.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                                    HStack {
                                        Text(row.book)
                                            .font(.subheadline.weight(.semibold))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text("\(Int(round(row.pct)))%")
                                            .font(.footnote.weight(.semibold))
                                            .monospacedDigit()
                                            .foregroundStyle(.red)
                                            .frame(width: 56, alignment: .trailing)
                                        Text("(\(row.correct)/\(row.answered))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 88, alignment: .trailing)
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color(.secondarySystemBackground))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(.top, 4)
                    }

                    // WORD-only section: move WordleStatsCardView content here when selected
                    if selectedGame == "WORD" {
                        // Segmented picker scope (Combined/Normal/Hard) — Combined default (tag 2)
                        Picker("Scope", selection: $wordScope) {
                            Text("Combined").tag(2)
                            Text("Normal").tag(0)
                            Text("Hard").tag(1)
                        }
                        .pickerStyle(.segmented)

                        // Average guesses + distribution (per mode)
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

                        // Timing stats (per mode)
                        let timeStats: (total: Int, wins: Int, losses: Int) = {
                            switch wordScope {
                            case 0: return GameStats.shared.wordleTimeStats(mode: .normal)
                            case 1: return GameStats.shared.wordleTimeStats(mode: .hard)
                            default: return GameStats.shared.wordleTimeStatsModesCombined()
                            }
                        }()

                        // Counts for denominators (per mode)
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
                } else {
                    Text("Play any game to build your Gamer Score.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 2)
        } label: {
            Label("Games", systemImage: "gamecontroller")
        }
        .onAppear { version &+= 1 }
        .onChange(of: stats.version) { _, _ in
            version &+= 1
            // Ensure selection remains valid after a stats refresh
            let names = Array(Set(GameStats.shared.breakdownSnapshot().entries.map { $0.name }))
            if selectedGame != "All Games" && !names.contains(selectedGame) {
                selectedGame = "All Games"
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gameStatsExternallyUpdated)) { _ in
            version &+= 1
        }
    }

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
