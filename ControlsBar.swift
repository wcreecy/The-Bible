import SwiftUI

struct WordSearchControlsBar: View {
    let roundOver: Bool
    /// Blind round whose word list is still hidden.
    let canShowWordList: Bool

    let onHint: () -> Void
    let onReveal: () -> Void
    let onShowWordList: () -> Void
    let onNewPuzzle: () -> Void
    let onChangeSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if !roundOver {
                Button("Hint", systemImage: "lightbulb", action: onHint)
                    .buttonStyle(ModernPillButtonStyle(tint: .yellow))
                    .accessibilityHint("Briefly highlights the first letter of a word you haven't found")

                if canShowWordList {
                    Button("Word List", systemImage: "list.bullet", action: onShowWordList)
                        .buttonStyle(ModernPillButtonStyle(tint: .orange))
                        .accessibilityHint("Shows the word list for the rest of this puzzle")
                }

                Button("Reveal", systemImage: "eye", action: onReveal)
                    .buttonStyle(ModernPillButtonStyle(tint: .red))
                    .accessibilityHint("Shows every word and ends the puzzle")
            } else {
                Button("Settings", systemImage: "slider.horizontal.3", action: onChangeSettings)
                    .buttonStyle(GameProminentButtonStyle(tint: .gray))

                Button("Next Puzzle", systemImage: "arrow.right", action: onNewPuzzle)
                    .buttonStyle(GameProminentButtonStyle(tint: .accentColor))
            }
        }
    }
}
