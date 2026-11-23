import SwiftUI

/// The tile, board and keyboard views for the Word game. They are an extension of `WordleView`
/// so they keep using its `KeyState` and the shared key styles.
extension WordleView {
    /// A solid-colored board tile showing a letter and its evaluation.
    struct WordleTile: View {
        let letter: String
        let state: KeyState
        let tileSize: CGFloat
        let isNextInput: Bool
        @Environment(\.wordColorBlindMode) private var colorBlind

        private var background: Color { state.fill(colorBlind: colorBlind) }

        private var foreground: Color { state.foreground(colorBlind: colorBlind) }

        private var border: Color {
            if isNextInput { return .blue.opacity(0.85) }
            return state == .unknown ? Color.primary.opacity(0.08) : background
        }

        var body: some View {
            Text(letter)
                .font((tileSize > 48 ? Font.title : Font.title2).weight(.bold))
                .foregroundStyle(foreground)
                .frame(width: tileSize, height: tileSize)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(background))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(border, lineWidth: isNextInput ? 2 : 1)
                )
        }
    }

    struct WordleBoardView: View {
        let guesses: [String]
        let evaluations: [[KeyState]]
        let activeRow: [Character?]
        let rowIndex: Int
        let isRoundOver: Bool
        @Binding var pinned: [[Character?]]
        let nextInputColumn: Int?
        let tileSize: CGFloat
        let onReuseCorrectLetter: (Character, Int) -> Void

        /// The gap between tiles; larger tiles get a wider gap.
        static func spacing(forTileSize tileSize: CGFloat) -> CGFloat {
            tileSize > 48 ? 9 : 6
        }

        private var spacing: CGFloat {
            Self.spacing(forTileSize: tileSize)
        }

        var body: some View {
            VStack(spacing: spacing) {
                ForEach(0..<6, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<5, id: \.self) { column in
                            tile(
                                letter: letter(atRow: row, column: column),
                                state: row < rowIndex ? evaluations[row][column] : .unknown,
                                row: row,
                                column: column
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                reuseCorrectLetter(fromRow: row, column: column)
                            }
                        }
                    }
                }
            }
        }

        private func letter(atRow row: Int, column: Int) -> String {
            if row < rowIndex {
                let guess = guesses[row]
                guard column < guess.count else { return "" }
                return String(guess[guess.index(guess.startIndex, offsetBy: column)])
            }
            guard row == rowIndex, !isRoundOver, let letter = activeRow[column] else {
                return ""
            }
            return String(letter)
        }

        private func reuseCorrectLetter(fromRow row: Int, column: Int) {
            if row == rowIndex, !isRoundOver, pinned[row][column] != nil {
                pinned[row][column] = nil
                return
            }

            guard !isRoundOver,
                  row < rowIndex,
                  evaluations[row][column] == .correct,
                  let letter = letter(atRow: row, column: column).first else { return }

            onReuseCorrectLetter(letter, column)
            ContextualTipView.complete("wordle.reuseLetter")
        }

        private func tile(
            letter: String,
            state: KeyState,
            row: Int,
            column: Int
        ) -> some View {
            let isPinned = pinned[row][column] != nil
            let isNextInput = row == rowIndex && column == nextInputColumn && !isRoundOver

            return WordleTile(
                letter: letter,
                state: isPinned ? .correct : state,
                tileSize: tileSize,
                isNextInput: isNextInput
            )
            .monospaced()
            .accessibilityLabel(accessibilityLabel(letter: letter, row: row, column: column, isPinned: isPinned, isNextInput: isNextInput))
            .accessibilityHint(
                isPinned
                    ? "Tap to remove this locked letter."
                    : (state == .correct && row < rowIndex && !isRoundOver
                        ? "Tap to place and lock this letter in the current guess."
                        : "")
            )
        }

        private func accessibilityLabel(
            letter: String,
            row: Int,
            column: Int,
            isPinned: Bool,
            isNextInput: Bool
        ) -> String {
            var parts = ["Row \(row + 1), column \(column + 1)", letter.isEmpty ? "empty" : letter]
            if isPinned { parts.append("locked") }
            if isNextInput { parts.append("next letter") }
            return parts.joined(separator: ", ")
        }
    }

    /// WORD's keys on the shared game keyboard, colored by what each guess revealed.
    struct WordleKeyboardView: View {
        let keyStates: [Character: KeyState]
        let isRoundOver: Bool
        let isCurrentRowFull: Bool
        let canDelete: Bool
        let keyHeight: CGFloat
        let onLetter: (Character) -> Void
        let onDelete: () -> Void
        let onEnter: () -> Void
        @Environment(\.wordColorBlindMode) private var colorBlind

        var body: some View {
            GameLetterKeyboard(
                keyHeight: keyHeight,
                isActive: !isRoundOver,
                acceptsLetters: !isCurrentRowFull,
                appearance: appearance(for:),
                keyValue: keyValue(for:),
                onLetter: onLetter,
                onDelete: onDelete,
                canDelete: canDelete,
                enterKey: GameKeyboardEnterKey(isEnabled: isCurrentRowFull, action: onEnter)
            )
            .padding(.top, 6)
        }

        private func appearance(for letter: Character) -> GameKeyAppearance {
            let state = keyStates[letter] ?? .unknown
            switch state {
            case .unknown:
                return .plain
            case .absent, .present, .correct:
                return .filled(fill: state.fill(colorBlind: colorBlind), foreground: state.foreground(colorBlind: colorBlind))
            }
        }

        private func keyValue(for letter: Character) -> String {
            switch keyStates[letter] ?? .unknown {
            case .unknown: ""
            case .absent: String(localized: "Not in the word")
            case .present: String(localized: "In the word, wrong spot")
            case .correct: String(localized: "In the right spot")
            }
        }
    }
}
