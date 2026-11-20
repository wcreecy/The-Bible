import SwiftUI

struct WordSearchControlsBar: View {
    let roundOver: Bool
    let hintTitle: String
    /// Blind round whose word list is still hidden.
    let canShowWordList: Bool

    let onHint: () -> Void
    let onShowWordList: () -> Void
    let onNewPuzzle: () -> Void
    let onChangeSettings: () -> Void
    let showsNextPuzzle: Bool

    var body: some View {
        HStack(spacing: 12) {
            if !roundOver {
                Button(hintTitle, systemImage: "lightbulb", action: onHint)
                    .buttonStyle(.gameHint(tint: .green))
                    .accessibilityHint("Briefly highlights the first letter of a word you haven't found")

                if canShowWordList {
                    Button("Word List", systemImage: "list.bullet", action: onShowWordList)
                        .buttonStyle(.gameHint(tint: .green))
                        .accessibilityHint("Shows the word list for the rest of this puzzle")
                }
            } else {
                Button("Change Settings", systemImage: "slider.horizontal.3", action: onChangeSettings)
                    .buttonStyle(GameProminentButtonStyle(tint: .gray))

                if showsNextPuzzle {
                    Button("Next Puzzle", systemImage: "arrow.right", action: onNewPuzzle)
                        .buttonStyle(GameProminentButtonStyle(tint: .accentColor))
                }
            }
        }
    }
}
