import SwiftUI

struct SideBySideGameArea<Summary: View>: View {
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
    /// Blind round whose word list is still hidden.
    let hidesWordList: Bool
    let colorForWord: (String) -> Color

    let roundOver: Bool
    let onHint: () -> Void
    let onReveal: () -> Void
    let onShowWordList: () -> Void
    let onNewPuzzle: () -> Void
    let onChangeSettings: () -> Void
    /// Shown above the word list once the round ends.
    let summary: Summary

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
            if roundOver {
                summary
            } else {
                progressHeader
            }

            if hidesWordList {
                SideBlindCountColumn(count: words.count, foundCount: foundCount)
            } else {
                SideWordsColumn(words: words, found: foundWords, revealed: revealedWords, colorForWord: colorForWord)
            }

            Spacer(minLength: 12)
            WordSearchControlsBar(
                roundOver: roundOver,
                canShowWordList: hidesWordList,
                onHint: onHint,
                onReveal: onReveal,
                onShowWordList: onShowWordList,
                onNewPuzzle: onNewPuzzle,
                onChangeSettings: onChangeSettings
            )
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
            Text("Tap Word List to show the words.").font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SideWordsColumn: View {
    let words: [String]
    let found: Set<String>
    let revealed: Set<String>
    let colorForWord: (String) -> Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Find these words:").font(.headline)
            if words.isEmpty {
                Text("No words").foregroundStyle(.secondary)
            } else {
                let columns = [GridItem(.adaptive(minimum: 120), spacing: 8)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(words, id: \.self) { w in
                        WordChip(word: w, state: state(for: w), foundColor: colorForWord(w))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func state(for word: String) -> WordChip.State {
        if found.contains(word) { return .found }
        if revealed.contains(word) { return .revealed }
        return .pending
    }
}
