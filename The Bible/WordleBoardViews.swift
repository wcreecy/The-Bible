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

        private var background: Color {
            switch state {
            case .unknown: Color(.secondarySystemBackground)
            case .absent: .gray
            case .present: .yellow
            case .correct: .green
            }
        }

        private var foreground: Color {
            switch state {
            case .unknown: .primary
            case .present, .correct: .black
            case .absent: .white
            }
        }

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

        private var spacing: CGFloat {
            tileSize > 48 ? 9 : 6
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
            guard !isRoundOver,
                  row < rowIndex,
                  evaluations[row][column] == .correct,
                  let letter = letter(atRow: row, column: column).first else { return }

            onReuseCorrectLetter(letter, column)
        }

        private func tile(
            letter: String,
            state: KeyState,
            row: Int,
            column: Int
        ) -> some View {
            let isPinned = pinned[row][column] != nil
            let isNextInput = row == rowIndex && column == nextInputColumn && !isRoundOver

            return ZStack(alignment: .topTrailing) {
                WordleTile(
                    letter: letter,
                    state: state,
                    tileSize: tileSize,
                    isNextInput: isNextInput
                )

                if row == rowIndex, !isRoundOver, isPinned {
                    Button {
                        pinned[row][column] = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear pinned letter")
                }
            }
            .monospaced()
            .accessibilityLabel(accessibilityLabel(letter: letter, row: row, column: column, isPinned: isPinned, isNextInput: isNextInput))
            .accessibilityHint(state == .correct && row < rowIndex && !isRoundOver ? "Tap to place and lock this letter in the current guess." : "")
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

    struct WordleKeyboardView: View {
        @Binding var usesABCLayout: Bool
        let keyStates: [Character: KeyState]
        let isRoundOver: Bool
        let isCurrentRowFull: Bool
        let canDelete: Bool
        let keyHeight: CGFloat
        let onLetter: (Character) -> Void
        let onDelete: () -> Void
        let onEnter: () -> Void

        private var rows: [[Character]] {
            if usesABCLayout {
                return [Array("ABCDEFGHIJ"), Array("KLMNOPQRS"), Array("TUVWXYZ")]
            }
            return [Array("QWERTYUIOP"), Array("ASDFGHJKL"), Array("ZXCVBNM")]
        }

        private var rowSpacing: CGFloat {
            keyHeight <= 32 ? 5 : 8
        }

        private var keySpacing: CGFloat {
            keyHeight <= 32 ? 4 : 6
        }

        var body: some View {
            VStack(spacing: rowSpacing) {
                keyboardRow(rows[0])
                keyboardRow(rows[1])

                HStack(spacing: keySpacing) {
                    Button {
                        usesABCLayout.toggle()
                    } label: {
                        Image(systemName: "arrow.uturn.backward.circle")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: keyHeight)
                    }
                    .buttonStyle(GameKeyButtonStyle(tint: .accentColor))
                    .disabled(isRoundOver)
                    .accessibilityLabel(usesABCLayout ? "Switch to QWERTY layout" : "Switch to ABC layout")

                    ForEach(rows[2], id: \.self) { character in
                        keyButton(for: character)
                    }

                    Button(action: onDelete) {
                        Image(systemName: "delete.left")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: keyHeight)
                    }
                    .buttonStyle(.glass(.regular.tint(.orange)))
                    .disabled(isRoundOver || !canDelete)
                    .accessibilityLabel("Backspace")
                }

                Button(action: onEnter) {
                    Label("Enter", systemImage: "return")
                        .labelStyle(.titleAndIcon)
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: keyHeight)
                }
                .buttonStyle(
                    GameKeyButtonStyle(tint: isCurrentRowFull ? .green : .gray)
                )
                .disabled(isRoundOver || !isCurrentRowFull)
                .accessibilityLabel("Enter")
            }
            .accessibilityElement(children: .contain)
            .padding(.top, 6)
        }

        private func keyboardRow(_ characters: [Character]) -> some View {
            HStack(spacing: keySpacing) {
                ForEach(characters, id: \.self) { character in
                    keyButton(for: character)
                }
            }
        }

        @ViewBuilder
        private func keyButton(for character: Character) -> some View {
            let state = keyStates[character] ?? .unknown

            switch state {
            case .unknown:
                keyLabel(character)
                    .buttonStyle(GameKeyButtonStyle(tint: state.tint))
                    .disabled(isRoundOver || isCurrentRowFull)
            case .absent:
                keyLabel(character)
                    .buttonStyle(FilledGameKeyButtonStyle(fill: .gray, foreground: .white))
                    .disabled(isRoundOver || isCurrentRowFull)
            case .present:
                keyLabel(character)
                    .buttonStyle(FilledGameKeyButtonStyle(fill: .yellow, foreground: .black))
                    .disabled(isRoundOver || isCurrentRowFull)
            case .correct:
                keyLabel(character)
                    .buttonStyle(FilledGameKeyButtonStyle(fill: .green, foreground: .white))
                    .disabled(isRoundOver || isCurrentRowFull)
            }
        }

        private func keyLabel(_ character: Character) -> some View {
            Button {
                onLetter(character)
            } label: {
                Text(String(character))
                    .font((keyHeight > 40 ? Font.title3 : Font.headline).weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: keyHeight)
            }
        }
    }
}
