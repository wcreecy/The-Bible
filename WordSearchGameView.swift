import SwiftUI
import SwiftData

struct WordSearchGameView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query private var favorites: [Favorite]
    @State private var vm: WordSearchViewModel
    @State private var didBindVM = false
    @State private var confirmReveal = false

    // Reuse a single in-memory placeholder container across instances to avoid store churn.
    private static let placeholderContainer: ModelContainer = {
        try! ModelContainer(
            for: Favorite.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }()

    init() {
        _vm = State(
            initialValue: WordSearchViewModel(
                modelContext: ModelContext(Self.placeholderContainer),
                favoritesFetch: { [] }
            )
        )
    }

    private var isPad: Bool { horizontalSizeClass == .regular }

    var body: some View {
        @Bindable var vm = vm

        ScrollView {
            VStack(spacing: 16) {
                if !vm.started {
                    WordSearchStartScreen(
                        difficulty: $vm.difficulty,
                        verseSource: $vm.verseSource,
                        isBlindMode: $vm.isBlindMode,
                        isTimedMode: $vm.isTimedMode,
                        wordCountRange: vm.wordCountRange,
                        timePerWord: vm.timePerWordString(),
                        hasFavorites: !favorites.isEmpty,
                        onStart: { vm.start() }
                    )
                } else {
                    WordSearchHeaderBox(
                        verseRef: vm.verseRef,
                        // The summary shows the full verse once the round ends.
                        verseText: vm.roundOver ? "" : vm.verseText,
                        hidesVerseText: vm.hidesWordList,
                        isFavorited: vm.isCurrentFavorited(),
                        onToggleFavorite: { vm.toggleFavoriteCurrent() },
                        timerTint: vm.isTimedMode && !vm.roundOver
                            ? vm.timerTint(for: vm.remainingSeconds)
                            : nil
                    )

                    if vm.isTimedMode && !vm.roundOver {
                        GameTimerCard(
                            remainingSeconds: vm.remainingSeconds,
                            tint: vm.timerTint(for: vm.remainingSeconds),
                            isPulsing: vm.pulseOn,
                            formattedTime: vm.formattedTime(vm.remainingSeconds)
                        )
                    }

                    if isPad {
                        SideBySideGameArea(
                            size: vm.size,
                            grid: vm.grid,
                            selectionStart: vm.selectionStart,
                            selectionEnd: vm.selectionEnd,
                            foundCells: vm.foundCells,
                            revealedWords: vm.revealedWords,
                            placed: vm.placed,
                            backgroundColorForCell: backgroundColorForCell,
                            onTapCell: { r, c in vm.handleTap(row: r, col: c) },
                            onDragChanged: { cell in vm.dragChanged(to: cell) },
                            onDragEnded: { vm.dragEnded() },
                            // iPad keeps the previous height-driven fallback (words are beside, not below)
                            dynamicGridHeight: dynamicGridHeightForLayout(availableWidth: nil),

                            words: vm.targetWords,
                            foundWords: vm.foundWords,
                            hidesWordList: vm.hidesWordList,
                            colorForWord: colorForWord,

                            roundOver: vm.roundOver,
                            onHint: { vm.hint() },
                            onReveal: { confirmReveal = true },
                            onShowWordList: { vm.showWordList() },
                            onNewPuzzle: { vm.newPuzzle() },
                            onChangeSettings: { vm.changeSettings() },
                            summary: summaryCard
                        )
                    } else {
                        phoneLayout
                    }
                }
            }
            .padding()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if vm.started {
                    GameNavigationTitle(title: "Word Search", systemImage: "square.grid.3x3.topleft.filled", tint: .green)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if vm.started && vm.roundOver && !isPad {
                completionActionsPhone
            }
        }
        .confirmationDialog("Reveal all words?", isPresented: $confirmReveal, titleVisibility: .visible) {
            Button("Reveal", role: .destructive) { vm.reveal() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This shows every word and counts the puzzle as unfinished.")
        }
        // The clock pauses while the game is off screen and picks up where it left off.
        .onAppear { vm.resumeTimer() }
        .onDisappear { vm.stopTimer() }
        // Rebind the VM to the real environment context/fetcher once the view is active.
        .task {
            if !didBindVM {
                vm.rebind(modelContext: modelContext, favoritesFetch: { favorites })
                didBindVM = true
            }
        }
    }

    // MARK: - Phone layout

    private var phoneLayout: some View {
        // Use GeometryReader to get the actual content width (after outer padding).
        GeometryReader { geo in
            let gridHeight = dynamicGridHeightForLayout(availableWidth: geo.size.width)
            VStack(spacing: 6) {
                GridBoard(
                    size: vm.size,
                    grid: vm.grid,
                    selectionStart: vm.selectionStart,
                    selectionEnd: vm.selectionEnd,
                    foundCells: vm.foundCells,
                    revealedWords: vm.revealedWords,
                    placed: vm.placed,
                    backgroundColorForCell: backgroundColorForCell,
                    onTapCell: { r, c in vm.handleTap(row: r, col: c) },
                    onDragChanged: { cell in vm.dragChanged(to: cell) },
                    onDragEnded: { vm.dragEnded() },
                    dynamicGridHeight: gridHeight
                )
                .frame(maxWidth: .infinity)

                // Word list + controls sit under the grid
                wordListAndControlsPhone
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        // Keep the geometry container as small as needed vertically; ScrollView will handle scrolling.
        .frame(minHeight: 0)
    }

    private var wordListAndControlsPhone: some View {
        VStack(spacing: 8) {
            if vm.roundOver {
                summaryCard
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    if vm.hidesWordList {
                        let foundCount = vm.targetWords.filter { vm.foundWords.contains($0) }.count
                        HStack {
                            Text("Words to find: \(vm.targetWords.count)").font(.headline)
                            Spacer(minLength: 8)
                            Text("Found: \(foundCount)").font(.headline).foregroundStyle(.secondary)
                        }
                    } else {
                        Text(vm.roundOver ? "Words" : "Find these words:").font(.headline)
                        if vm.targetWords.isEmpty {
                            Text("No words").foregroundStyle(.secondary)
                        } else {
                            WrapWordsView(words: vm.targetWords, found: vm.foundWords, revealed: vm.revealedWords, colorForWord: colorForWord)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !vm.roundOver {
                controlsBar(roundOver: false)
            }
        }
        // Small positive top padding to ensure a tiny, consistent gap (no overlap) on all difficulties.
        .padding(.top, 2)
    }

    private var completionActionsPhone: some View {
        controlsBar(roundOver: true)
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)
    }

    private func controlsBar(roundOver: Bool) -> some View {
        WordSearchControlsBar(
            roundOver: roundOver,
            canShowWordList: vm.hidesWordList,
            onHint: { vm.hint() },
            onReveal: { confirmReveal = true },
            onShowWordList: { vm.showWordList() },
            onNewPuzzle: { vm.newPuzzle() },
            onChangeSettings: { vm.changeSettings() }
        )
    }

    @ViewBuilder
    private var summaryCard: some View {
        if let result = vm.roundResult {
            WordSearchSummaryCard(
                result: result,
                foundCount: vm.foundWords.count,
                totalCount: vm.targetWords.count,
                elapsed: vm.formattedTime(vm.elapsedSeconds),
                hintsUsed: vm.hintsUsed,
                usedWordList: vm.isBlindMode ? vm.showBlindWordList : nil,
                verseRef: vm.verseRef,
                verseText: vm.verseText,
                onReadInContext: {
                    AppRouter.shared.openBibleReference(
                        book: vm.favBookName,
                        chapter: vm.favChapterNumber,
                        verse: vm.favVerseNumber
                    )
                }
            )
        }
    }

    // MARK: - Helpers

    // Height that matches the grid’s actual size for the given container width (phone).
    // If availableWidth is nil (iPad side layout), we fall back to the previous “target cell” approach.
    private func dynamicGridHeightForLayout(availableWidth: CGFloat?) -> CGFloat {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let spacing: CGFloat = isPad ? 6 : 4
        // Matches GridBoard: phones allow small cells so a 14×14 grid fits the screen width.
        let minCell: CGFloat = isPad ? 36 : 18
        let maxCell: CGFloat = isPad ? 58 : 36

        if let w = availableWidth {
            // Width available here already accounts for the outer padding in this ScrollView section.
            let cellSizeFromWidth = (w - CGFloat(vm.size - 1) * spacing) / CGFloat(vm.size)
            let cellSize = min(max(cellSizeFromWidth, minCell), maxCell)
            return CGFloat(vm.size) * cellSize + CGFloat(vm.size - 1) * spacing
        } else {
            // iPad fallback (unchanged): reserve a comfortable target height.
            let targetCell: CGFloat = isPad ? 54 : 34
            return CGFloat(vm.size) * targetCell + CGFloat(vm.size - 1) * spacing
        }
    }

    private func colorForWord(_ word: String) -> Color {
        WordSearchPalette.color(for: vm.colorIndexForWord[word])
    }

    private func backgroundColorForCell(row: Int, col: Int) -> Color {
        let key = "\(row),\(col)"
        if let hint = vm.hintCell, hint.row == row, hint.col == col {
            return Color.yellow.opacity(0.75)
        }
        if vm.foundCells.contains(key) {
            return WordSearchPalette.color(for: vm.colorIndexForCell[key]).opacity(0.45)
        }
        // Revealed cells (red)
        let engine = WordSearchEngine(size: vm.size, difficulty: vm.difficulty)
        if vm.placed.contains(where: { pw in
            vm.revealedWords.contains(pw.originalWord) && engine.cellsForPlacedWord(pw).contains(where: { $0.row == row && $0.col == col })
        }) {
            return Color.red.opacity(0.35)
        }
        if let start = vm.selectionStart, let end = vm.selectionEnd {
            let path = engine.selectionCells(from: start, to: end)
            if path.contains(where: { $0.row == row && $0.col == col }) {
                return Color.blue.opacity(0.35)
            }
        }
        return Color(.secondarySystemBackground)
    }
}

#Preview {
    NavigationStack { WordSearchGameView() }
}
