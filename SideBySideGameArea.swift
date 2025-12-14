import SwiftUI

struct SideBySideGameArea: View {
    let size: Int
    let grid: [[Character]]
    let selectionStart: (row: Int, col: Int)?
    let selectionEnd: (row: Int, col: Int)?
    let foundCells: Set<String>
    let revealedWords: Set<String>
    let placed: [WordSearchEngine.PlacedWord]
    let backgroundColorForCell: (_ row: Int, _ col: Int) -> Color
    let onTapCell: (_ row: Int, _ col: Int) -> Void
    let onDragChanged: (_ cell: (row: Int, col: Int)) -> Void
    let onDragEnded: () -> Void
    let dynamicGridHeight: CGFloat

    let words: [String]
    let foundWords: Set<String>

    let gameMode: WordSearchViewModel.GameMode
    let showBlindWordList: Bool

    let isTimedMode: Bool
    let timeUp: Bool
    let remainingSeconds: Int
    let pulseOn: Bool
    let timerTint: (Int) -> Color

    let onNewPuzzle: () -> Void
    let onReveal: () -> Void
    let onChangeDifficultyOrMode: () -> Void
    let onToggleHealed: () -> Void
    let healedOn: Bool
    let roundOver: Bool

    private var splitColumns: (left: [String], right: [String]) {
        if words.count > 8 {
            let mid = (words.count + 1) / 2
            return (Array(words.prefix(mid)), Array(words.suffix(from: mid)))
        } else {
            return ([], words)
        }
    }

    private func formattedTime(_ secs: Int) -> String {
        let m = secs / 60
        let s = secs % 60
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                if isTimedMode && !timeUp {
                    HStack(spacing: 8) {
                        Image(systemName: "timer")
                        Text(formattedTime(remainingSeconds)).monospacedDigit()
                    }
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(timerTint(remainingSeconds))
                    .scaleEffect(pulseOn ? 1.08 : 1.0)
                    .animation(.easeInOut(duration: 0.25), value: pulseOn)
                }

                HStack(spacing: 10) {
                    if !roundOver {
                        Button("Reveal") { onReveal() }
                            .buttonStyle(ModernPillButtonStyle(tint: .blue))

                        if gameMode == .blind {
                            Button(healedOn ? "I'm Healed" : "Be Healed") { onToggleHealed() }
                                .buttonStyle(ModernPillButtonStyle(tint: healedOn ? .green : .red))
                        }
                    } else {
                        Button("New Puzzle") { onNewPuzzle() }
                            .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                        Button("Change Settings") { onChangeDifficultyOrMode() }
                            .buttonStyle(ModernPillButtonStyle(tint: .orange))
                    }
                }
                .padding(.bottom, 4)

                if !splitColumns.left.isEmpty {
                    if gameMode == .blind && !showBlindWordList {
                        let foundCount = words.filter { foundWords.contains($0) }.count
                        SideBlindCountColumn(count: splitColumns.left.count, foundCount: foundCount)
                            .frame(width: 220)
                    } else {
                        SideWordsColumn(words: splitColumns.left, found: foundWords, revealed: revealedWords)
                            .frame(width: 220)
                    }
                }
            }
            .frame(width: 220)

            ZStack(alignment: .trailing) {
                Color.clear
                GridBoard(
                    size: size,
                    grid: grid,
                    selectionStart: selectionStart,
                    selectionEnd: selectionEnd,
                    foundCells: foundCells,
                    revealedWords: revealedWords,
                    placed: placed,
                    backgroundColorForCell: backgroundColorForCell,
                    onTapCell: onTapCell,
                    onDragChanged: onDragChanged,
                    onDragEnded: onDragEnded,
                    dynamicGridHeight: dynamicGridHeight
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)

            if !splitColumns.right.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    if gameMode == .blind && !showBlindWordList {
                        let foundCount = words.filter { foundWords.contains($0) }.count
                        SideBlindCountColumn(count: splitColumns.right.count, foundCount: foundCount)
                            .frame(width: 220)
                    } else {
                        SideWordsColumn(words: splitColumns.right, found: foundWords, revealed: revealedWords)
                            .frame(width: 220)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct SideBlindCountColumn: View {
    let count: Int
    let foundCount: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Words to find: \(count)").font(.headline)
                Spacer(minLength: 8)
                Text("Found: \(foundCount)").font(.headline).foregroundStyle(.secondary)
            }
            Text("Tap Healed to show the list.").font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SideWordsColumn: View {
    let words: [String]
    let found: Set<String>
    let revealed: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Find these words:").font(.headline)
            if words.isEmpty {
                Text("No words").foregroundStyle(.secondary)
            } else {
                let columns = [GridItem(.adaptive(minimum: 120), spacing: 8)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(words, id: \.self) { w in
                        let isFound = found.contains(w)
                        let isRevealed = !isFound && revealed.contains(w)
                        Text(w)
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(isFound ? Color.green.opacity(0.20) : (isRevealed ? Color.red.opacity(0.20) : Color.accentColor.opacity(0.12)))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(isFound ? Color.green.opacity(0.60) : (isRevealed ? Color.red.opacity(0.60) : Color.accentColor.opacity(0.35)), lineWidth: 1)
                            )
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
