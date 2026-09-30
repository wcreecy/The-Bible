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

    let onNewPuzzle: () -> Void
    let onReveal: () -> Void
    let onChangeDifficultyOrMode: () -> Void
    let onToggleHealed: () -> Void
    let healedOn: Bool
    let roundOver: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            puzzlePanel
                .frame(maxWidth: .infinity)

            dashboardPanel
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: 1_240, alignment: .top)
        .frame(maxWidth: .infinity)
    }

    private var puzzlePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Puzzle", systemImage: "square.grid.3x3.fill")
                .font(.headline.weight(.bold))

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
                dynamicGridHeight: min(dynamicGridHeight, 620)
            )
            .frame(maxWidth: .infinity)
        }
        .padding(AppDesignMetrics.cardPadding)
        .heroCardSurface()
    }

    private var dashboardPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            progressHeader

            if gameMode == .blind && !showBlindWordList {
                SideBlindCountColumn(count: words.count, foundCount: foundCount)
            } else {
                SideWordsColumn(words: words, found: foundWords, revealed: revealedWords)
            }

            Spacer(minLength: 12)
            controls
        }
        .padding(AppDesignMetrics.cardPadding)
        .frame(minHeight: min(dynamicGridHeight, 620) + 57, alignment: .top)
        .heroCardSurface()
    }

    private var foundCount: Int {
        words.filter { foundWords.contains($0) }.count
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Word List", systemImage: "text.magnifyingglass")
                    .font(.headline.weight(.bold))

                Spacer()

                Text("\(foundCount) of \(words.count)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(foundCount), total: Double(max(words.count, 1)))
                .tint(foundCount == words.count ? .green : .accentColor)
        }
        .padding(16)
        .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous))
    }

    private var controls: some View {
        HStack(spacing: 12) {
            if roundOver {
                Button("New Puzzle", systemImage: "arrow.clockwise", action: onNewPuzzle)
                    .buttonStyle(GameProminentButtonStyle(tint: .accentColor))

                Button("Settings", systemImage: "slider.horizontal.3", action: onChangeDifficultyOrMode)
                    .buttonStyle(GameProminentButtonStyle(tint: .orange))
            } else {
                Button("Reveal", systemImage: "eye.fill", action: onReveal)
                    .buttonStyle(GameProminentButtonStyle(tint: .accentColor))

                if gameMode == .blind {
                    Button(healedOn ? "Hide List" : "Word List", systemImage: healedOn ? "eye.slash.fill" : "list.bullet", action: onToggleHealed)
                        .buttonStyle(GameProminentButtonStyle(tint: healedOn ? .green : .red))
                }
            }
        }
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
