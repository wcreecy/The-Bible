import SwiftUI
import Charts

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

    // Drill-down: Bible Quiz genre -> per-book sheet
    @State private var showGenreDrill: Bool = false
    @State private var selectedGenre: String? = nil

    // MARK: - Play Now routing

    private func postSwitchToGamesTab() {
        NotificationCenter.default.post(
            name: .switchToTab,
            object: nil,
            userInfo: ["tabName": "games"]
        )
    }

    private func openSelectedGame() {
        // If "All Games", just switch to the Games tab list.
        guard selectedGame != "All Games" else {
            postSwitchToGamesTab()
            return
        }
        postSwitchToGamesTab()
        // Small async hop to allow tab switch before routing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NotificationCenter.default.post(
                name: .openGameStart,
                object: nil,
                userInfo: ["gameName": selectedGame]
            )
        }
    }

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

                    // Play button next to the title on larger screens only
                    if hSizeClass != .compact {
                        GamesOverviewPlayButton(openAction: openSelectedGame, selectedGame: selectedGame)
                            .padding(.leading, 10) // add horizontal space between title and Play button
                    }

                    Spacer(minLength: 8)

                    // Picker remains fully tappable
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

                // On iPhone, move Play button to its own row so it doesn’t crowd the picker
                if hSizeClass == .compact {
                    Button(action: openSelectedGame) {
                        Label("Play", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }

                // Keep a horizontal line between the header and stats
                Divider()

                if !isEmpty {
                    // KPIs reflect selected game (and WORD scope when applicable)
                    HStack(spacing: 8) {
                        MetricChip(title: "Accuracy", value: "\(Int(round(kpiAccuracyPct)))%", tint: kpiAccuracyTint)
                        MetricChip(title: "Played", value: "\(kpiPlayed)", tint: .blue)
                        MetricChip(title: "Correct", value: "\(kpiCorrect)", tint: .green)
                        MetricChip(title: "Best Streak", value: (kpiBestStreak > 0 ? "\(kpiBestStreak)" : "—"), tint: .orange)
                    }

                    // NEW: Activity & Trend row for Overview — scoped to selectedGame
                    // UPDATED: WORD respects mode scope (Combined/Normal/Hard)
                    let series30: [(date: Date, answered: Int, correct: Int)] = {
                        if selectedGame == "All Games" {
                            return GameStats.shared.dailySeriesLast(days: 30)
                        } else if selectedGame == "WORD" {
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
                        } else if selectedGame == "WORD" {
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
                        } else if selectedGame == "WORD" {
                            switch wordScope {
                            case 0: return GameStats.shared.accuracy7DayTrend(forWordMode: .normal)
                            case 1: return GameStats.shared.accuracy7DayTrend(forWordMode: .hard)
                            default: return GameStats.shared.accuracy7DayTrend(forDisplayName: selectedGame)
                            }
                        } else {
                            return GameStats.shared.accuracy7DayTrend(forDisplayName: selectedGame)
                        }
                    }()
                    let trendTint: Color = trend7.deltaVsPrev >= 0 ? .green : .red
                    let trendArrow: String = trend7.deltaVsPrev >= 0 ? "arrow.up.right" : "arrow.down.right"
                    let hasRecentActivity30 = series30.contains { $0.answered > 0 }

                    // Make this KPI row horizontally scrollable so 7D chip has normal size
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            MetricChip(title: "Active Days (30D)", value: "\(activeDays30)", tint: .purple)
                            MetricChip(title: "Qs/Day", value: "\(avgPerActive)", tint: .teal)
                            MetricChip(title: "Current Streak", value: streaksInfo.current > 0 ? "\(streaksInfo.current)" : "—", tint: .orange)
                            MetricChip(title: "Longest Streak", value: "\(streaksInfo.longest)", tint: .orange)
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
                    // NEW: For WORD, overlay gold dots on days with a Daily solve.
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

                        // Overlay: only when WORD is selected (any scope). We use the combined solved-day map.
                        if selectedGame == "WORD" {
                            // Build the last-30-day solved day key set once
                            let solvedKeys: Set<String> = GameStats.shared.wordleDailySolvedDayKeysLast(days: 30)
                            ForEach(series30, id: \.date) { point in
                                // Match by local yyyy-MM-dd key
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
                                    .symbolSize(28) // small dot
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
                                MetricChip(
                                    title: "OT",
                                    value: "\(Int(round(summary.otPct)))% (\(summary.otCorrect)/\(summary.otAnswered))",
                                    tint: .blue
                                )
                                MetricChip(
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
                                        Button {
                                            selectedGenre = row.genre
                                            showGenreDrill = true
                                        } label: {
                                            MetricChip(
                                                title: row.genre,
                                                value: "\(Int(round(row.pct)))% (\(row.correct)/\(row.answered))",
                                                tint: tint
                                            )
                                            .fixedSize(horizontal: true, vertical: false)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Show accuracy by book for \(row.genre)")
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                        }
                    }

                    // NEW: Hangman specific — Accuracy by Category (People/Places/Books)
                    if selectedGame == "Hangman" {
                        let rows = GameStats.shared.hangmanAccuracyByCategory()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Accuracy by Category")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                                    let tint: Color = {
                                        switch row.category {
                                        case "People": return .orange
                                        case "Places": return .teal
                                        case "Books": return .purple
                                        default: return .gray
                                        }
                                    }()
                                    MetricChip(
                                        title: row.category,
                                        value: "\(Int(round(row.pct)))% (\(row.correct)/\(row.answered))",
                                        tint: tint
                                    )
                                }
                            }
                        }
                    }

                    // NEW: Beat the Clock specific — Accuracy by Type (People/Places)
                    if selectedGame == "Beat the Clock" {
                        let rows = GameStats.shared.beatclockAccuracyByType()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Accuracy by Type")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                                    let tint: Color = {
                                        switch row.type {
                                        case "People": return .orange
                                        case "Places": return .teal
                                        default: return .gray
                                        }
                                    }()
                                    MetricChip(
                                        title: row.type,
                                        value: "\(Int(round(row.pct)))% (\(row.correct)/\(row.answered))",
                                        tint: tint
                                    )
                                }
                            }
                        }
                    }

                    // NEW: Verse Match specific — Accuracy by Testament
                    if selectedGame == "Verse Match" {
                        let summary = GameStats.shared.verseMatchOTNTSummary()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Accuracy by Testament (OT vs NT)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                MetricChip(
                                    title: "OT",
                                    value: "\(Int(round(summary.otPct)))% (\(summary.otCorrect)/\(summary.otAnswered))",
                                    tint: .blue
                                )
                                MetricChip(
                                    title: "NT",
                                    value: "\(Int(round(summary.ntPct)))% (\(summary.ntCorrect)/\(summary.ntAnswered))",
                                    tint: .green
                                )
                            }
                        }
                    }

                    // NEW: Verse Match specific — Accuracy by Genre (summary chips)
                    if selectedGame == "Verse Match" {
                        let rows = GameStats.shared.verseMatchAccuracyByGenre()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Accuracy by Genre")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
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
                                        MetricChip(
                                            title: row.genre,
                                            value: "\(Int(round(row.pct)))% (\(row.correct)/\(row.answered))",
                                            tint: tint
                                        )
                                        .fixedSize(horizontal: true, vertical: false)
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
            // Compact, icon-only Play button overlay removed — now in header row
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
        // Drill-down sheet for Bible Quiz genre -> per-book accuracy
        .sheet(isPresented: $showGenreDrill) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    if let g = selectedGenre {
                        let rows = GameStats.shared.quizAccuracyByBook(inGenre: g)
                        if rows.isEmpty {
                            ContentUnavailableView("No data for \(g)", systemImage: "book")
                        } else {
                            List {
                                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                                    HStack {
                                        Text(row.book)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text("\(Int(round(row.pct)))%")
                                            .font(.footnote.weight(.semibold))
                                            .monospacedDigit()
                                            .foregroundStyle(Color.gamerScoreColor(for: row.pct))
                                            .frame(width: 56, alignment: .trailing)
                                        Text("(\(row.correct)/\(row.answered))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 88, alignment: .trailing)
                                    }
                                }
                            }
                            .listStyle(.insetGrouped)
                        }
                    } else {
                        ContentUnavailableView("No genre selected", systemImage: "tag")
                    }
                }
                .navigationTitle(selectedGenre ?? "Genre")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showGenreDrill = false }
                    }
                }
            }
        }
    }

    // Removed local metricChip/labeledValue; using shared MetricChip/LabeledValue instead.

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

