import SwiftUI

struct WordSearchStartScreen: View {
    @Binding var howToExpanded: Bool
    @Binding var difficultyExpanded: Bool
    @Binding var difficulty: WordSearchEngine.Difficulty
    @Binding var gameMode: WordSearchViewModel.GameMode
    @Binding var isTimedMode: Bool
    let timeLimitString: String
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 24)
            Text("Find hidden words from a random Bible verse.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 10) {
                GroupBox {
                    DisclosureGroup(isExpanded: $howToExpanded) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("• Tap Start to generate a new puzzle.")
                            Text("• Drag across letters to select a word.")
                            Text("• Easy/Normal: words can be horizontal, vertical, or diagonal (forward only).")
                            Text("• Hard: words can be in any direction, forward or backwards.")
                            Text("• Expert: all words are reversed and can go in any direction.")
                            Text("• Blind Mode: the word list is hidden. Tap Healed to reveal the list, then find them.")
                            Text("• Tip: You can also tap a start letter, then tap an end letter to select the line between them.")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } label: {
                        Text("How to Play").font(.headline)
                    }
                }

                GroupBox {
                    DisclosureGroup(isExpanded: $difficultyExpanded) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("• Easy: 10×10 grid; words go horizontal, vertical, or diagonal (forward only).")
                            Text("• Normal: 12×12 grid; words go horizontal, vertical, or diagonal (forward only).")
                            Text("• Hard: 14×14 grid; words can be in any direction, including backwards.")
                            Text("• Expert: 14×14 grid; all words are reversed and can go in any direction.")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } label: {
                        Text("Difficulty Levels").font(.headline)
                    }
                }
            }
            .padding(.horizontal)

            Picker("Difficulty", selection: $difficulty) {
                ForEach(WordSearchEngine.Difficulty.allCases) { d in
                    Text(displayName(for: d)).tag(d)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Picker("Mode", selection: $gameMode) {
                ForEach(WordSearchViewModel.GameMode.allCases) { m in
                    Text(m.displayName).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

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

            Button("Start") { onStart() }
                .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                .controlSize(.large)
                .frame(maxWidth: 240)

            Spacer(minLength: 24)
        }
    }

    private func displayName(for d: WordSearchEngine.Difficulty) -> String {
        switch d {
        case .easy: return "Easy"
        case .medium: return "Normal"
        case .hard: return "Hard"
        case .expert: return "Expert"
        }
    }
}
