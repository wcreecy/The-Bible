import SwiftUI

struct WordSearchStartScreen: View {
    @Binding var difficulty: WordSearchEngine.Difficulty
    @Binding var gameMode: WordSearchViewModel.GameMode
    @Binding var isTimedMode: Bool
    let timeLimitString: String
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 24)
            Text("Find hidden words from a random Bible verse.")
                .gameStartDescriptionStyle(title: "Word Search", systemImage: "square.grid.3x3.topleft.filled", tint: .green)

            WordSearchSetupCard(
                difficulty: difficulty,
                gameMode: gameMode,
                isTimedMode: isTimedMode,
                timeLimitString: timeLimitString
            )

            WordSearchSetupControls(
                difficulty: $difficulty,
                gameMode: $gameMode
            )

            HStack(spacing: 10) {
                Label {
                    Text("Timed Mode").font(.headline).foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "timer").foregroundStyle(.orange)
                }
                .labelStyle(.titleAndIcon)

                Spacer(minLength: 8)

                Toggle("", isOn: $isTimedMode).labelsHidden()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Capsule(style: .continuous).fill(Color.orange.opacity(0.10)))
            .overlay(Capsule(style: .continuous).stroke(Color.orange.opacity(0.25), lineWidth: 1))
            .padding(.horizontal)

            if isTimedMode {
                Text("Time limit: \(timeLimitString)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            GameLobbyPreview(kind: .wordSearch)

            GameStartActionBar(action: onStart)

            Spacer(minLength: 24)
        }
        .gameStartScreenStyle()
    }
}

private struct WordSearchSetupCard: View {
    let difficulty: WordSearchEngine.Difficulty
    let gameMode: WordSearchViewModel.GameMode
    let isTimedMode: Bool
    let timeLimitString: String

    private var difficultyTitle: LocalizedStringResource {
        switch difficulty {
        case .easy: "Easy"
        case .medium: "Normal"
        case .hard: "Hard"
        case .expert: "Expert"
        }
    }

    private var gameTypeTitle: LocalizedStringResource {
        switch gameMode {
        case .normal: "Standard"
        case .favorites: "Favorites"
        case .blind: "Blind"
        }
    }

    private var difficultySummary: LocalizedStringResource {
        switch difficulty {
        case .easy:
            "Easy uses a 10×10 grid with words placed forward horizontally, vertically, or diagonally."
        case .medium:
            "Normal uses a 12×12 grid with words placed forward horizontally, vertically, or diagonally."
        case .hard:
            "Hard uses a 14×14 grid with words placed in any direction, including backwards."
        case .expert:
            "Expert uses a 14×14 grid with every word reversed and placed in any direction."
        }
    }

    private var gameTypeSummary: LocalizedStringResource {
        switch gameMode {
        case .normal:
            "Standard creates the puzzle from a random Bible verse."
        case .favorites:
            "Favorites uses one of your saved verses when available."
        case .blind:
            "Blind hides the word list until you reveal it."
        }
    }

    private var timerSummary: LocalizedStringResource {
        isTimedMode
            ? "You have \(timeLimitString) to finish the puzzle."
            : "There is no time limit."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Your Game", systemImage: "checklist")
                .font(.headline)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 6) {
                Text(difficultySummary)
                Text(gameTypeSummary)
                Text(timerSummary)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Divider()

            LabeledContent("Difficulty") {
                Text(difficultyTitle)
                    .fontWeight(.semibold)
            }

            LabeledContent("Game Type") {
                Text(gameTypeTitle)
                    .fontWeight(.semibold)
            }

            LabeledContent("Timer") {
                if isTimedMode {
                    Text(timeLimitString)
                        .fontWeight(.semibold)
                } else {
                    Text("Off")
                        .fontWeight(.semibold)
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
        .accessibilityElement(children: .contain)
    }
}

private struct WordSearchSetupControls: View {
    @Binding var difficulty: WordSearchEngine.Difficulty
    @Binding var gameMode: WordSearchViewModel.GameMode

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Difficulty")
                    .font(.headline)

                Picker("Difficulty", selection: $difficulty) {
                    Text("Easy").tag(WordSearchEngine.Difficulty.easy)
                    Text("Normal").tag(WordSearchEngine.Difficulty.medium)
                    Text("Hard").tag(WordSearchEngine.Difficulty.hard)
                    Text("Expert").tag(WordSearchEngine.Difficulty.expert)
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Game Type")
                    .font(.headline)

                Picker("Game Type", selection: $gameMode) {
                    Text("Standard").tag(WordSearchViewModel.GameMode.normal)
                    Text("Favorites").tag(WordSearchViewModel.GameMode.favorites)
                    Text("Blind").tag(WordSearchViewModel.GameMode.blind)
                }
                .pickerStyle(.segmented)
            }
        }
        .frame(maxWidth: 620)
        .padding(.horizontal)
    }
}
