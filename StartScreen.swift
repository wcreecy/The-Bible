import SwiftUI

struct WordSearchStartScreen: View {
    @Binding var difficulty: WordSearchEngine.Difficulty
    @Binding var verseSource: WordSearchViewModel.VerseSource
    @Binding var isBlindMode: Bool
    @Binding var isTimedMode: Bool
    let wordCountRange: ClosedRange<Int>
    let timePerWord: String
    let hasFavorites: Bool
    let onStart: () -> Void

    private var needsFavorites: Bool { verseSource == .favorites && !hasFavorites }

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

    private var verseSourceTitle: String {
        switch verseSource {
        case .popular: "Popular"
        case .random: "Any verse"
        case .favorites: "Favorites"
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
                isStartEnabled: !needsFavorites,
                startAction: onStart
            ) {
                GameLobbyPreview(kind: .wordSearch)
            } configuration: {
                WordSearchSetupCard(
                    difficulty: difficulty,
                    verseSource: verseSource,
                    isBlindMode: isBlindMode,
                    isTimedMode: isTimedMode,
                    timePerWord: timePerWord
                )

                WordSearchSetupControls(
                    verseSource: $verseSource,
                    needsFavorites: needsFavorites
                )

                VStack(spacing: 10) {
                    WordSearchOptionToggle(title: "Blind", systemImage: "eye.slash", tint: .purple, isOn: $isBlindMode)
                    WordSearchOptionToggle(title: "Timed Mode", systemImage: "timer", tint: .orange, isOn: $isTimedMode)
                }
            } facts: {
                GameSplashFacts(
                    first: ("square.grid.3x3", "\(wordCountRange.lowerBound)–\(wordCountRange.upperBound)", "Words"),
                    second: ("timer", isTimedMode ? timePerWord : "Untimed", "Time limit"),
                    third: ("text.quote", verseSourceTitle, "Verses")
                )
            }

            Spacer(minLength: 24)
        }
        .gameStartScreenStyle()
    }
}

private struct WordSearchOptionToggle: View {
    let title: LocalizedStringResource
    let systemImage: String
    let tint: Color
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Label(title, systemImage: systemImage)
                .font(.headline)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Capsule(style: .continuous).fill(tint.opacity(0.10)))
        .overlay(Capsule(style: .continuous).stroke(tint.opacity(0.25), lineWidth: 1))
        .frame(maxWidth: 620)
        .padding(.horizontal)
    }
}

private struct WordSearchSetupCard: View {
    let difficulty: WordSearchEngine.Difficulty
    let verseSource: WordSearchViewModel.VerseSource
    let isBlindMode: Bool
    let isTimedMode: Bool
    let timePerWord: String

    private var difficultySummary: LocalizedStringResource {
        switch difficulty {
        case .easy:
            "Easy: a 10×10 grid with 3–6 words running forward across, down, or diagonally."
        case .medium:
            "Normal: a 12×12 grid with 4–7 words running forward across, down, or diagonally."
        case .hard:
            "Hard: a 14×14 grid with 5–8 words running in any direction, including backwards."
        case .expert:
            "Expert: a 14×14 grid with 6–10 words in any direction. Words can cross and share a letter, and look-alike fragments are hidden among them."
        }
    }

    private var verseSummary: LocalizedStringResource {
        switch verseSource {
        case .popular: "Puzzles come from well-known verses."
        case .random: "Puzzles come from any verse in the Bible."
        case .favorites: "Puzzles come from your saved favorite verses."
        }
    }

    private var timerSummary: LocalizedStringResource {
        isTimedMode
            ? "You get \(timePerWord) to finish."
            : "There is no time limit."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Your Game", systemImage: "checklist")
                .font(.headline)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 6) {
                Text(difficultySummary)
                Text(verseSummary)
                if isBlindMode {
                    Text("Blind hides the word list and the verse until you finish. You can show the list if you get stuck.")
                }
                Text(timerSummary)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: 620, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        }
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
    }
}

private struct WordSearchSetupControls: View {
    @Binding var verseSource: WordSearchViewModel.VerseSource
    let needsFavorites: Bool

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Verses")
                    .font(.headline)

                Picker("Verses", selection: $verseSource) {
                    Text("Popular").tag(WordSearchViewModel.VerseSource.popular)
                    Text("Any Verse").tag(WordSearchViewModel.VerseSource.random)
                    Text("Favorites").tag(WordSearchViewModel.VerseSource.favorites)
                }
                .pickerStyle(.segmented)

                if needsFavorites {
                    Label("Save a verse as a favorite to use it here.", systemImage: "heart")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: 620)
        .padding(.horizontal)
    }
}
