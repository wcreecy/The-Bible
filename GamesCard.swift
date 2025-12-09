import SwiftUI
import Combine

struct GamesCard: View {
    // Local token to re-render on external sync merges
    @State private var gameStatsVersion: Int = 0

    let onOpenGames: () -> Void
    let onOpenStats: () -> Void

    private func colorForPercent(_ pct: Double) -> Color {
        if pct < 60 { return .red }
        else if pct < 75 { return .orange }
        else if pct < 90 { return .purple }
        else { return .green }
    }

    var body: some View {
        // Pull a fresh snapshot; reading version in the view ties it to state updates
        let _ = gameStatsVersion
        let snap = GameStats.shared.snapshot()
        let gamerPct = snap.percentage
        let gamerColor = colorForPercent(gamerPct)
        let isEmpty = (snap.totalAnswered == 0)

        HeroCard(
            title: "Games",
            subtitle: nil,
            icon: "gamecontroller",
            tint: isEmpty ? .secondary : gamerColor,
            backgroundColor: nil,
            strokeColor: nil
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Text("Gamer Score:")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if isEmpty {
                        Text("Let’s play!")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(Int(round(gamerPct)))%")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(gamerColor)
                            .accessibilityHidden(true)
                            .overlay(
                                Color.clear
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel("Gamer Score \(Int(round(gamerPct))) percent.")
                            )
                    }
                }

                HStack(spacing: 10) {
                    Button(action: onOpenGames) {
                        Label("Games", systemImage: "gamecontroller")
                    }
                    .buttonStyle(ModernPillButtonStyle(tint: .blue))

                    Button(action: onOpenStats) {
                        Label("Stats", systemImage: "chart.bar")
                    }
                    .buttonStyle(ModernPillButtonStyle(tint: .teal))
                }
                .padding(.top, 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpenGames)
        .onReceive(NotificationCenter.default.publisher(for: .gameStatsExternallyUpdated)) { _ in
            gameStatsVersion &+= 1
        }
    }
}
