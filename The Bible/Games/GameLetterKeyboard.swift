import SwiftUI

/// How one key looks: the usual tinted key, or a solid key for a letter the game has marked
/// (WORD's green and yellow, for example).
enum GameKeyAppearance {
    case standard(tint: Color)
    case filled(fill: Color, foreground: Color)

    static let plain = GameKeyAppearance.standard(tint: .accentColor)
}

/// The Enter key under the letters, for games that submit a whole word.
struct GameKeyboardEnterKey {
    var isEnabled: Bool
    let action: () -> Void
}

/// The on-screen keyboard every word game shares (WORD, Hangman, Crossword): the same rows,
/// key sizes, Delete key, and A–Z / QWERTY switch, which is remembered across games.
struct GameLetterKeyboard: View {
    @AppStorage(AppStorageKey.gameKeyboardUsesABCLayout) private var usesABCLayout = false

    let keyHeight: CGFloat
    /// `false` once the round is over: keys dim and stop typing.
    var isActive = true
    /// Whether letter keys accept taps right now (WORD stops at a full row).
    var acceptsLetters = true
    var appearance: (Character) -> GameKeyAppearance = { _ in .plain }
    /// Read by VoiceOver after the letter, such as "In the word".
    var keyValue: (Character) -> String = { _ in "" }
    let onLetter: (Character) -> Void
    /// Adds the Delete key when set.
    var onDelete: (() -> Void)?
    var canDelete = true
    var enterKey: GameKeyboardEnterKey?

    private var rows: [[Character]] {
        usesABCLayout
            ? [Array("ABCDEFGHIJ"), Array("KLMNOPQRS"), Array("TUVWXYZ")]
            : [Array("QWERTYUIOP"), Array("ASDFGHJKL"), Array("ZXCVBNM")]
    }

    private var rowSpacing: CGFloat { keyHeight <= 32 ? 5 : 8 }
    private var keySpacing: CGFloat { keyHeight <= 32 ? 4 : 6 }
    private var letterFont: Font { (keyHeight > 40 ? Font.title3 : Font.headline).weight(.semibold) }

    var body: some View {
        VStack(spacing: rowSpacing) {
            letterRow(rows[0])
            letterRow(rows[1])

            HStack(spacing: keySpacing) {
                layoutSwitch
                ForEach(rows[2], id: \.self, content: letterKey)
                if let onDelete {
                    deleteKey(onDelete)
                }
            }

            if let enterKey {
                Button(action: enterKey.action) {
                    Label("Enter", systemImage: "return")
                        .labelStyle(.titleAndIcon)
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: keyHeight)
                }
                .buttonStyle(GameKeyButtonStyle(tint: enterKey.isEnabled ? .green : .gray))
                .disabled(!isActive || !enterKey.isEnabled)
            }
        }
        .opacity(isActive ? 1 : 0.6)
        .accessibilityElement(children: .contain)
    }

    private func letterRow(_ letters: [Character]) -> some View {
        HStack(spacing: keySpacing) {
            ForEach(letters, id: \.self, content: letterKey)
        }
    }

    @ViewBuilder
    private func letterKey(_ letter: Character) -> some View {
        let button = Button {
            onLetter(letter)
        } label: {
            Text(String(letter))
                .font(letterFont)
                .frame(maxWidth: .infinity, minHeight: keyHeight)
        }
        .disabled(!isActive || !acceptsLetters)
        .accessibilityLabel(Text("Letter \(String(letter))"))
        .accessibilityValue(keyValue(letter))

        switch appearance(letter) {
        case .standard(let tint):
            button.buttonStyle(GameKeyButtonStyle(tint: tint))
        case .filled(let fill, let foreground):
            button.buttonStyle(FilledGameKeyButtonStyle(fill: fill, foreground: foreground))
        }
    }

    private var layoutSwitch: some View {
        Button {
            usesABCLayout.toggle()
        } label: {
            Text(usesABCLayout ? "QWERTY" : "A–Z")
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, minHeight: keyHeight)
        }
        .buttonStyle(GameKeyButtonStyle(tint: .secondary))
        .frame(maxWidth: 64)
        .accessibilityLabel(usesABCLayout ? "Switch to QWERTY layout" : "Switch to A to Z layout")
    }

    private func deleteKey(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "delete.left")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: keyHeight)
        }
        .buttonStyle(GameKeyButtonStyle(tint: .red))
        .frame(maxWidth: 64)
        .disabled(!isActive || !canDelete)
        .accessibilityLabel("Delete")
    }
}

#Preview {
    VStack(spacing: 24) {
        GameLetterKeyboard(keyHeight: 44, onLetter: { _ in }, onDelete: {})
        GameLetterKeyboard(
            keyHeight: 44,
            appearance: { $0 == "E" ? .filled(fill: .green, foreground: .white) : .plain },
            onLetter: { _ in },
            onDelete: {},
            enterKey: GameKeyboardEnterKey(isEnabled: true) {}
        )
    }
    .padding()
}
