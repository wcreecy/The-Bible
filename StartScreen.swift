import SwiftUI

struct WordSearchStartScreen: View {
    @Binding var difficulty: WordSearchEngine.Difficulty
    @Binding var verseSource: WordSearchViewModel.VerseSource
    @Binding var isBlindMode: Bool
    @Binding var isTimedMode: Bool
    let wordCountRange: ClosedRange<Int>
    let timePerWord: String
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
                    eligibleFavoriteCount: eligibleFavoriteCount
                )

                WordSearchPuzzleOptionsCard(
                    isBlindMode: $isBlindMode,
                    isTimedMode: $isTimedMode
                )
            } facts: {
                VStack(alignment: .leading, spacing: 10) {
                    GameSplashFacts(
                    first: ("puzzlepiece.extension", "1 puzzle", "This session"),
                    second: ("square.grid.3x3", "\(gridSize)×\(gridSize)", "Grid · \(wordCountRange.lowerBound)–\(wordCountRange.upperBound) target words"),
                    third: ("eye", isBlindMode ? "Blind" : "Visible", "Verse and word list")
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

private struct WordSearchPuzzleOptionsCard: View {
    @Binding var isBlindMode: Bool
    @Binding var isTimedMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Puzzle Options", systemImage: "slider.horizontal.3")
                .font(.headline)
                .foregroundStyle(.green)

            HStack(alignment: .top, spacing: 8) {
                WordSearchOptionCard(
                    title: "Blind Mode",
                    detail: "Hide the verse and word list.",
                    systemImage: "eye.slash",
                    isSelected: isBlindMode
                ) {
                    isBlindMode.toggle()
                }

                WordSearchOptionCard(
                    title: "Timed Mode",
                    detail: "Race against the clock.",
                    systemImage: "timer",
                    isSelected: isTimedMode
                ) {
                    isTimedMode.toggle()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: 620, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        }
        .padding(.horizontal)
    }
}

private struct WordSearchOptionCard: View {
    let title: LocalizedStringResource
    let detail: LocalizedStringResource
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                Image(systemName: systemImage)
                    .foregroundStyle(isSelected ? .white : .green)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .gameSplashOptionCardSize()
            .background(
                isSelected ? Color.green : Color.green.opacity(0.09),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.green : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct WordSearchSetupControls: View {
    @Binding var verseSource: WordSearchViewModel.VerseSource
    let eligibleFavoriteCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Choose verses", systemImage: "text.quote")
                .font(.headline)
                .foregroundStyle(.green)

            HStack(alignment: .top, spacing: 8) {
                ForEach(WordSearchViewModel.VerseSource.allCases) { option in
                    let isSelected = verseSource == option
                    let isEnabled = option != .favorites || eligibleFavoriteCount > 0

                    Button {
                        verseSource = option
                    } label: {
                        sourceCard(option, isSelected: isSelected)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isEnabled)
                    .accessibilityLabel(option.title)
                    .accessibilityValue(isSelected ? "Selected" : "Not selected")
                    .accessibilityHint(
                        isEnabled
                            ? ""
                            : "Save favorite verses while reading to unlock this option."
                    )
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }

            if verseSource == .favorites {
                Text("Eligible saved verses: \(eligibleFavoriteCount)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if verseSource == .favorites && eligibleFavoriteCount == 0 {
                Label("Save a verse as a favorite to use it here.", systemImage: "heart")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: 620)
        .padding(.horizontal)
    }

    private func sourceCard(
        _ option: WordSearchViewModel.VerseSource,
        isSelected: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: option.icon)
                .foregroundStyle(isSelected ? .white : .green)
            Text(option.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .white : .primary)
            Text(option.detail)
                .font(.caption2)
                .foregroundStyle(isSelected ? .white.opacity(0.9) : .secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .gameSplashOptionCardSize()
        .background(
            isSelected ? Color.green : Color.green.opacity(0.09),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? Color.green : .clear, lineWidth: 2)
        }
    }
}
