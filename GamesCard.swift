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

    // Local version bump for explicit notifications
    @State private var version: Int = 0

    // UserDefaults keys for optional info/trend baselines
    private let lastPlayedKey = "gamesLastPlayedAt"
    private let lastWeekPctKey = "gamesLastWeekAccuracyPct" // optional baseline if you store it elsewhere
    // NEW: per-session baseline of all‑time Gamer Score captured on entering Games tab
    private let sessionBaselineKey = "gamesSessionBaselinePct"
    // Stored in GameStats.recordRound
    private let lastPlayedGameNameKey = "gamesLastPlayedGameName"

    @Environment(\.scenePhase) private var scenePhase

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

    var body: some View {
        // Snapshot once per render pass
        _ = GameStats.shared.snapshot()
        let breakdown = GameStats.shared.breakdownSnapshot()
        let totalAnswered = breakdown.totalAnswered
        let totalCorrect = breakdown.totalCorrect
        let gamerPct = breakdown.percentage
        let gamerColor = Color.gamerScoreColor(for: gamerPct)
        let isEmpty = (totalAnswered == 0)

        // Fetch last played name + relative time (for footer)
        let lastPlayed = GameStats.shared.lastPlayedSummary()
        let lastPlayedName = lastPlayed.name
        let lastPlayedRelative = lastPlayed.relative

        // Trend chevron — compare current all‑time Gamer Score vs this session's baseline
        let sessionBaseline = UserDefaults.standard.double(forKey: sessionBaselineKey)
        let deltaTextAndIcon: (name: String, color: Color, a11y: String) = {
            if sessionBaseline > 0 {
                let diff = Int(round(gamerPct - sessionBaseline))
                return tinyChevron(for: diff)
            } else {
                return tinyChevron(for: 0)
            }
        }()

        // Keep computing these stats if you want to reuse elsewhere later
        let entries = breakdown.entries
        let bestStreak = entries.map { $0.bestStreak ?? 0 }.max() ?? 0
        _ = bestStreak
        _ = estimateCorrectNeededForNextPercent(totalCorrect: totalCorrect, totalAnswered: totalAnswered)

        return HeroCard(
            title: "Games",
            subtitle: nil,
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

                    // Actions
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

                    // Footer: Last played tag (moved under the 3 buttons)
                    if let name = lastPlayedName, let rel = lastPlayedRelative {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .foregroundStyle(.secondary)
                            Text("Last played:")
                                .foregroundStyle(.secondary)
                            Text(name)
                                .fontWeight(.semibold)
                            Text("•")
                                .foregroundStyle(.secondary)
                            Text(rel)
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                        .padding(.top, 2)
                    }
                }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpenGames)
        .onAppear {
            clearInsightStateIfStatsCleared()
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
