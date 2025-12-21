import SwiftUI

struct WordSearchControlsBar: View {
    let onNewPuzzle: () -> Void
    let onReveal: () -> Void
    let onChangeDifficultyOrMode: () -> Void

    let gameMode: WordSearchViewModel.GameMode
    let onToggleHealed: () -> Void
    let healedOn: Bool
    let roundOver: Bool

    var body: some View {
        HStack(spacing: 12) {
            if !roundOver {
                Button("Reveal") { onReveal() }
                    .buttonStyle(ModernPillButtonStyle(tint: .blue))

                if gameMode == .blind {
                    Button(healedOn ? "Hide" : "Word List") { onToggleHealed() }
                        .buttonStyle(ModernPillButtonStyle(tint: healedOn ? .green : .red))
                }
            } else {
                Button("New Puzzle") { onNewPuzzle() }
                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                Button("Change Settings") { onChangeDifficultyOrMode() }
                    .buttonStyle(ModernPillButtonStyle(tint: .orange))
            }
        }
    }
}
