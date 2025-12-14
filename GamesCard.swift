import SwiftUI
import Combine

struct GamesCard: View {
    // External actions
    let onOpenGames: () -> Void
    let onOpenStats: () -> Void
    // NEW: Shuffle play callback
    let onShufflePlay: () -> Void

    // Observe central stats to refresh whenever its version changes
    @ObservedObject private var stats = GameStats.shared

    // Fade/rotation state for micro‑insight
    @State private var insightIndex: Int = 0
    @State private var fadeIn: Bool = true
    @State private var timerCancellable: AnyCancellable? = nil

    // Local version bump for explicit notifications
    @State private var version: Int = 0

    // UserDefaults keys for optional info/trend baselines
    private let lastPlayedKey = "gamesLastPlayedAt"
    private let lastWeekPctKey = "gamesLastWeekAccuracyPct" // optional baseline if you store it elsewhere
    // NEW: per-session baseline of all‑time Gamer Score captured on entering Games tab
    private let sessionBaselineKey = "gamesSessionBaselinePct"
    // Stored in GameStats.recordRound
    private let lastPlayedGameNameKey = "gamesLastPlayedGameName"

    // If overall stats have been cleared (no answers at all), wipe any persisted
    // insight baselines so the Home card shows a clean state.
    private func clearInsightStateIfStatsCleared() {
        let breakdown = GameStats.shared.breakdownSnapshot()
        let isCleared = (breakdown.totalAnswered == 0 && breakdown.totalCorrect == 0)
        guard isCleared else { return }
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: lastPlayedKey)
        defaults.removeObject(forKey: lastPlayedGameNameKey)
        defaults.removeObject(forKey: lastWeekPctKey)
        defaults.removeObject(forKey: sessionBaselineKey)
        // Reset local rotating insight state
        insightIndex = 0
    }

    private func tinyChevron(for delta: Int) -> (name: String, color: Color, a11y: String) {
        if delta > 0 {
            return ("chevron.up", .green, "Up \(delta) percent since session start")
        } else if delta < 0 {
            return ("chevron.down", .red, "Down \(abs(delta)) percent since session start")
        } else {
            return ("minus", .gray, "No change since session start")
        }
    }

    private func estimateCorrectNeededForNextPercent(totalCorrect: Int, totalAnswered: Int) -> Int? {
        guard totalAnswered > 0 else { return nil }
        let currentPct = (Double(totalCorrect) / Double(totalAnswered)) * 100.0
        let targetPct = min(100.0, floor(currentPct) + 1.0) // next whole percent
        if targetPct <= currentPct { return 0 }
        let A = targetPct / 100.0
        let denom = (1.0 - A)
        guard denom > 0 else { return nil }
        let rhs = A * Double(totalAnswered) - Double(totalCorrect)
        let x = ceil(rhs / denom)
        return max(0, Int(x))
    }

    private func relativeDaysString(since date: Date) -> String {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        let startOfThat = cal.startOfDay(for: date)
        let comps = cal.dateComponents([.day], from: startOfThat, to: startOfToday)
        let d = max(0, comps.day ?? 0)
        if d == 0 { return "today" }
        if d == 1 { return "1d ago" }
        return "\(d)d ago"
    }

    private func startInsightTimer() {
        timerCancellable?.cancel()
        // Show each insight for 4 seconds with 0.25s crossfade
        timerCancellable = Timer.publish(every: 4.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                withAnimation(.easeInOut(duration: 0.25)) {
                    fadeIn = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    insightIndex += 1
                    withAnimation(.easeInOut(duration: 0.25)) {
                        fadeIn = true
                    }
                }
            }
    }

    private func stopInsightTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    var body: some View {
        // Snapshot once per render pass
        _ = GameStats.shared.snapshot()
        let breakdown = GameStats.shared.breakdownSnapshot()
        let totalAnswered = breakdown.totalAnswered
        let totalCorrect = breakdown.totalCorrect
        let gamerPct = breakdown.percentage
        let gamerColor = Color.gamerScoreColor(for: gamerPct)
        let isEmpty = (totalAnswered == 0)

        // Optional: last played text
        let lastPlayedTimestamp = UserDefaults.standard.double(forKey: lastPlayedKey)
        let lastPlayedText: String? = {
            if lastPlayedTimestamp > 0 {
                let date = Date(timeIntervalSince1970: lastPlayedTimestamp)
                return "Last played \(relativeDaysString(since: date))"
            } else {
                return nil
            }
        }()

        // NEW: Trend chevron — compare current all‑time Gamer Score vs this session's baseline
        let sessionBaseline = UserDefaults.standard.double(forKey: sessionBaselineKey)
        let deltaTextAndIcon: (name: String, color: Color, a11y: String) = {
            if sessionBaseline > 0 {
                let diff = Int(round(gamerPct - sessionBaseline))
                return tinyChevron(for: diff)
            } else {
                // If no baseline captured yet, show neutral
                return tinyChevron(for: 0)
            }
        }()

        // Micro‑insights pool
        let entries = breakdown.entries
        let bestStreak = entries.map { $0.bestStreak ?? 0 }.max() ?? 0
        let bestGameByShare: String? = {
            guard totalAnswered > 0 else { return nil }
            let shares = entries.map { (name: $0.name, share: Double($0.answered) / Double(totalAnswered)) }
            return shares.max(by: { $0.share < $1.share })?.name
        }()
        let accuracyLastWeek: String? = {
            let lastWeekBaseline = UserDefaults.standard.double(forKey: lastWeekPctKey)
            if lastWeekBaseline > 0 {
                return "\(Int(round(lastWeekBaseline)))%"
            } else {
                return nil
            }
        }()
        let neededForNextPercent: String? = {
            if let x = estimateCorrectNeededForNextPercent(totalCorrect: totalCorrect, totalAnswered: totalAnswered), x > 0 {
                return "~\(x) correct to +1%"
            } else {
                return nil
            }
        }()

        // New derived insights
        let totalAnsweredInsight: String? = totalAnswered > 0 ? "Total answered \(totalAnswered)" : nil
        let totalCorrectInsight: String? = totalCorrect > 0 ? "Total correct \(totalCorrect)" : nil
        let bestAccuracyInsight: String? = {
            // Per-game accuracy, pick highest by percentage (answered > 0)
            let withPct = entries.compactMap { e -> (name: String, pct: Double)? in
                guard e.answered > 0 else { return nil }
                let p = min(100, max(0, (Double(e.correct) / Double(e.answered)) * 100.0))
                return (e.name, p)
            }
            guard let best = withPct.max(by: { $0.pct < $1.pct }) else { return nil }
            return "Best accuracy: \(best.name) \(Int(round(best.pct)))%"
        }()
        // UPDATED: Most played — show only a single top game; if tie, pick first from sorted order
        let mostPlayedInsight: String? = {
            guard totalAnswered > 0 else { return nil }
            let ranked = entries
                .map { (name: $0.name, share: Double($0.answered) / Double(totalAnswered)) }
                .sorted { lhs, rhs in
                    if lhs.share == rhs.share { return lhs.name < rhs.name } // deterministic tie-break
                    return lhs.share > rhs.share
                }
            guard let top = ranked.first else { return nil }
            return "Most played: \(top.name)"
        }()
        let lastPlayedInsight: String? = {
            if let text = lastPlayedText {
                return text.replacingOccurrences(of: "Last played ", with: "Played ")
            }
            return nil
        }()
        let scoreDeltaInsight: String? = {
            // Keep this “last week” insight as-is (uses the old key), separate from caret behavior
            let lastWeekBaseline = UserDefaults.standard.double(forKey: lastWeekPctKey)
            if lastWeekBaseline > 0 {
                let diff = Int(round(gamerPct - lastWeekBaseline))
                if diff == 0 { return "Gamer Score unchanged vs last week" }
                let sign = diff > 0 ? "+" : "−"
                return "Gamer Score change \(sign)\(abs(diff))% vs last week"
            }
            return nil
        }()

        // NEW: Today insights from GameStats (numeric only; no generic "Played today")
        let today = GameStats.shared.todayStats()
        let answeredTodayInsight: String? = today.answered > 0 ? "Answered today \(today.answered)" : nil
        let correctTodayInsight: String? = today.correct > 0 ? "Correct today \(today.correct)" : nil
        let accuracyTodayInsight: String? = today.answered > 0 ? "Accuracy today \(Int(round(today.pct)))%" : nil

        // NEW: Last played game name insight (fallback to existing relative text if missing)
        let lastPlayedGameName = GameStats.shared.lastPlayedGameName
        let lastPlayedNameInsight: String? = {
            if let name = lastPlayedGameName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Last played: \(name)"
            } else {
                return lastPlayedText
            }
        }()

        let insightLines: [String] = {
            let lines = [
                // Keep your originals first
                bestStreak > 0 ? "Longest streak \(bestStreak)" : nil,
                bestGameByShare.map { "Best game: \($0)" },
                accuracyLastWeek.map { "Accuracy last week \($0)" },
                neededForNextPercent,
                // New additions
                scoreDeltaInsight,
                totalAnsweredInsight,
                totalCorrectInsight,
                bestAccuracyInsight,
                // UPDATED: single “Most played” line
                mostPlayedInsight,
                lastPlayedInsight,
                // Today block — numeric only
                answeredTodayInsight,
                correctTodayInsight,
                accuracyTodayInsight,
                // Last played name (preferred over relative when available)
                lastPlayedNameInsight
            ].compactMap { $0 }
            return lines.isEmpty ? ["Play to build your Gamer Score"] : lines
        }()
        let currentInsight = insightLines[insightIndex % insightLines.count]

        // Explicit labels select the init with only content (no accessories)
        return HeroCard(
            title: "Games",
            subtitle: lastPlayedText,
            icon: "gamecontroller",
            tint: isEmpty ? .secondary : gamerColor,
            content: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text("Gamer Score")
                            .font(.headline)

                        Spacer()

                        if isEmpty {
                            Text("Let’s play!")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        } else {
                            HStack(spacing: 6) {
                                Text("\(Int(round(gamerPct)))%")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(gamerColor)
                                    .monospacedDigit()
                                    .accessibilityLabel("Gamer Score \(Int(round(gamerPct))) percent")

                                // Trend chevron moved next to the percentage — now based on session baseline
                                Image(systemName: deltaTextAndIcon.name)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(deltaTextAndIcon.color)
                                    .accessibilityHidden(true)
                                    .overlay(
                                        Color.clear
                                            .accessibilityElement(children: .ignore)
                                            .accessibilityLabel(deltaTextAndIcon.a11y)
                                    )
                            }
                        }
                    }

                    // Insight row: persistent icon + fading text
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "lightbulb")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.yellow)
                            .accessibilityHidden(true)

                        Text(currentInsight)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.9)
                            .opacity(fadeIn ? 1.0 : 0.0)
                            .animation(.easeInOut(duration: 0.25), value: fadeIn)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(.secondarySystemFill))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Insight: \(currentInsight)")

                    // Row of actions: Shuffle • Games • Stats (uniform size)
                    HStack(spacing: 10) {
                        Button(action: onShufflePlay) {
                            Label("Random", systemImage: "shuffle")
                        }
                        .buttonStyle(ModernPillButtonStyle(tint: .black))

                        Button(action: onOpenGames) {
                            Label("Games", systemImage: "gamecontroller")
                        }
                        .buttonStyle(ModernPillButtonStyle(tint: .black))

                        Button(action: onOpenStats) {
                            Label("Stats", systemImage: "chart.bar")
                        }
                        .buttonStyle(ModernPillButtonStyle(tint: .black))
                    }
                }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpenGames)
        .onAppear {
            clearInsightStateIfStatsCleared()
            startInsightTimer()
        }
        .onDisappear {
            stopInsightTimer()
        }
        // Tie identity to stats.version and local version to force refreshes without non-view statements
        .id(stats.version &+ version)
        .onChange(of: stats.version) {
            clearInsightStateIfStatsCleared()
        }
        .onReceive(NotificationCenter.default.publisher(for: .gameStatsExternallyUpdated)) { _ in
            version &+= 1
            clearInsightStateIfStatsCleared()
        }
    }
}
