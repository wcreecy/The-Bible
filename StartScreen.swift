import SwiftUI

struct WordSearchStartScreen: View {
    @Binding var difficulty: WordSearchEngine.Difficulty
    @Binding var verseSource: WordSearchViewModel.VerseSource
    @Binding var isBlindMode: Bool
    @Binding var isTimedMode: Bool
    let wordCountRange: ClosedRange<Int>
    let totalTime: String
    let eligibleFavoriteCount: Int
    let onStart: () -> Void

    private var needsFavorites: Bool { verseSource == .favorites && eligibleFavoriteCount == 0 }

    private var experienceLevel: Binding<GameExperienceLevel> {
        Binding(
            get: {
                switch difficulty {
                case .easy: .learn
                case .medium: .standard
                case .hard, .expert: .challenge
                }
            },
            set: { level in
                difficulty = switch level {
                case .learn: .easy
                case .standard: .medium
                case .challenge: .hard
                }
            }
        )
    }

    private var gridSize: Int {
        switch difficulty {
        case .easy: 10
        case .medium: 12
        case .hard, .expert: 14
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 24)
            Text("Find the hidden words from a Bible verse.")
                .gameStartDescriptionStyle(title: "Word Search", systemImage: "square.grid.3x3.topleft.filled", tint: .green)

            GameSplashLaunchLayout(
                tint: .green,
                experienceLevel: experienceLevel,
                experienceDetails: GameExperienceDetails(
                    learn: "10×10 grid with 3–6 words in forward directions.",
                    standard: "12×12 grid with 4–7 words in forward directions.",
                    challenge: "14×14 grid with 5–8 words in any direction."
                ),
                isStartEnabled: !needsFavorites,
                startAction: onStart
            ) {
                GameLobbyPreview(kind: .wordSearch)
            } configuration: {
                WordSearchSetupControls(
                    verseSource: $verseSource,
                    isBlindMode: $isBlindMode,
                    isTimedMode: $isTimedMode,
                    eligibleFavoriteCount: eligibleFavoriteCount
                )
            } facts: {
                VStack(alignment: .leading, spacing: 10) {
                    GameSplashFacts(
                    first: ("puzzlepiece.extension", "1 puzzle", "This session"),
                    second: ("square.grid.3x3", "\(gridSize)×\(gridSize)", "Grid · \(wordCountRange.lowerBound)–\(wordCountRange.upperBound) target words"),
                    third: ("eye", isBlindMode ? "Blind" : "Visible", "Verse and word list"),
                    fourth: isTimedMode ? ("timer", totalTime, "Time to solve") : nil
                    )

                    Label(
                        eligibleFavoriteCount > 0
                            ? "Favorites ready: \(eligibleFavoriteCount) eligible verses"
                            : "Favorites unavailable: save a verse to unlock them",
                        systemImage: eligibleFavoriteCount > 0 ? "heart.fill" : "heart.slash"
                    )
                    .font(.footnote)
                    .foregroundStyle(eligibleFavoriteCount > 0 ? Color.secondary : Color.orange)
                }
            }

            Spacer(minLength: 24)
        }
        .gameStartScreenStyle()
    }
}

private struct WordSearchSetupControls: View {
    @Binding var verseSource: WordSearchViewModel.VerseSource
    @Binding var isBlindMode: Bool
    @Binding var isTimedMode: Bool
    let eligibleFavoriteCount: Int

    var body: some View {
        GameSettingsGroup {
            GameChoiceSetting(
                title: "Verses",
                systemImage: "text.quote",
                tint: .green,
                selection: $verseSource,
                choices: WordSearchViewModel.VerseSource.allCases.map {
                    GameChoice(
                        value: $0,
                        title: $0.title,
                        detail: $0.detail,
                        icon: $0.icon,
                        isEnabled: $0 != .favorites || eligibleFavoriteCount > 0
                    )
                }
            )

            GameToggleSetting(
                title: "Blind Mode",
                detail: "Hide the verse and word list.",
                systemImage: "eye.slash",
                tint: .green,
                isOn: $isBlindMode
            )

            GameToggleSetting(
                title: "Timed Mode",
                detail: "Race against the clock.",
                systemImage: "timer",
                tint: .green,
                isOn: $isTimedMode
            )
        }
    }
}
