import SwiftUI

/// Short game times: "8s" under a minute, "1m 42s" after.
enum GameTimeFormat {
    nonisolated static func short(seconds: Int) -> String {
        Duration.seconds(max(1, seconds)).formatted(.units(allowed: [.minutes, .seconds], width: .narrow))
    }

    nonisolated static func short(_ duration: Duration) -> String {
        let components = duration.components
        let exactSeconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
        return short(seconds: Int(exactSeconds.rounded()))
    }
}

/// This puzzle's time against the saved best. Only solved puzzles can set a best.
struct GameBestTimeComparison: Equatable {
    enum Result: Equatable {
        /// The first solved time for these settings.
        case firstBest
        case newBest(fasterBy: Int)
        case tied
        case slower(by: Int, best: Int)
        /// Unsolved puzzles don't count; shows the best to aim for, if there is one.
        case notEligible(best: Int?)
    }

    let seconds: Int
    /// The best before this puzzle was played.
    let previousBest: Int?
    let isSolved: Bool

    var result: Result {
        guard isSolved else { return .notEligible(best: previousBest) }
        guard let previousBest else { return .firstBest }
        if seconds < previousBest { return .newBest(fasterBy: previousBest - seconds) }
        if seconds == previousBest { return .tied }
        return .slower(by: seconds - previousBest, best: previousBest)
    }

    var isNewBest: Bool {
        switch result {
        case .firstBest, .newBest: true
        default: false
        }
    }

    var message: String? {
        switch result {
        case .firstBest:
            String(localized: "New best time!")
        case .newBest(let fasterBy):
            String(localized: "New best time! \(GameTimeFormat.short(seconds: fasterBy)) faster")
        case .tied:
            String(localized: "Tied your best time")
        case .slower(let by, let best):
            String(localized: "\(GameTimeFormat.short(seconds: by)) off your best of \(GameTimeFormat.short(seconds: best))")
        case .notEligible(let best):
            best.map { String(localized: "Your best is \(GameTimeFormat.short(seconds: $0))") }
        }
    }
}

/// The streak line on a puzzle result.
struct GamePuzzleStreak {
    let current: Int
    /// Nil when the game doesn't keep a best streak.
    var best: Int?
    var isNewBest = false
    /// Extra context, such as "This visit: 3 of 4 puzzles".
    var caption: String?
}

/// The passage a puzzle came from, with a way to open it.
struct GamePuzzleScripture {
    let reference: String
    var text: String?
    let onOpen: () -> Void
}

/// The end-of-puzzle card shared by the single-puzzle games (Book Order, Word Search, WORD).
/// It sits under the finished board, which still shows the details, and summarizes the
/// outcome, a few facts, best time and streak, a game-specific detail, and the Scripture.
struct GamePuzzleResultCard<Detail: View>: View {
    let title: String
    var subtitle: String?
    let systemImage: String
    let tint: Color
    /// Three or four facts for the strip under the header.
    let facts: [GameSplashFacts.Fact]
    var bestTime: GameBestTimeComparison?
    var streak: GamePuzzleStreak?
    var scripture: GamePuzzleScripture?
    @ViewBuilder var detail: () -> Detail

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if facts.count >= 3 {
                GameSplashFacts(
                    first: facts[0],
                    second: facts[1],
                    third: facts[2],
                    fourth: facts.count > 3 ? facts[3] : nil
                )
            }

            if let bestTime, let message = bestTime.message {
                Label(message, systemImage: bestTime.isNewBest ? "trophy.fill" : "stopwatch")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(bestTime.isNewBest ? Color.orange : Color.secondary)
                    .monospacedDigit()
            }

            detail()

            if let streak {
                GamePuzzleStreakRow(streak: streak)
            }

            if let scripture {
                Divider()
                GamePuzzleScriptureView(scripture: scripture)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.15), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.bold))
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

extension GamePuzzleResultCard where Detail == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        tint: Color,
        facts: [GameSplashFacts.Fact],
        bestTime: GameBestTimeComparison? = nil,
        streak: GamePuzzleStreak? = nil,
        scripture: GamePuzzleScripture? = nil
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            systemImage: systemImage,
            tint: tint,
            facts: facts,
            bestTime: bestTime,
            streak: streak,
            scripture: scripture,
            detail: { EmptyView() }
        )
    }
}

/// A titled group inside a puzzle result, such as "Books to Review" or "Missed Words".
struct GamePuzzleResultSection<Content: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    var tint: Color = .secondary
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct GamePuzzleStreakRow: View {
    let streak: GamePuzzleStreak

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 16) {
                Label {
                    Text("Streak \(streak.current)")
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                }
                .font(.subheadline.weight(.semibold))

                if let best = streak.best {
                    Text("Best \(best)")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if streak.isNewBest {
                    Label("New best!", systemImage: "trophy.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }

            if let caption = streak.caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct GamePuzzleScriptureView: View {
    let scripture: GamePuzzleScripture

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(scripture.reference)
                .font(.headline)
            if let text = scripture.text, !text.isEmpty {
                Text("“\(text)”")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Read in Context", systemImage: "book", action: scripture.onOpen)
                .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
        }
    }
}

#Preview {
    ScrollView {
        GamePuzzleResultCard(
            title: "4 of 6 in place",
            subtitle: "Two books were out of order.",
            systemImage: "list.number",
            tint: .purple,
            facts: [
                ("stopwatch", "42s", "Time"),
                ("checkmark.circle", "4/6", "In place"),
                ("trophy", "31s", "Best time")
            ],
            bestTime: GameBestTimeComparison(seconds: 42, previousBest: 31, isSolved: false),
            streak: GamePuzzleStreak(current: 0, best: 9, caption: "This visit: 3 of 4 puzzles")
        ) {
            GamePuzzleResultSection(title: "Books to Review", systemImage: "arrow.uturn.backward.circle", tint: .red) {
                Text("Nahum comes after Micah")
                Text("Habakkuk comes after Nahum")
            }
        }
        .padding()
    }
}
