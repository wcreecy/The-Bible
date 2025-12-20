import SwiftUI
import SwiftData
import Combine

struct WordSearchGameView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [Favorite]
    @StateObject private var vm: WordSearchViewModel
    @State private var didBindVM = false

    // Reuse a single in-memory placeholder container across instances to avoid store churn.
    private static let placeholderContainer: ModelContainer = {
        try! ModelContainer(
            for: Favorite.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }()

    init() {
        _vm = StateObject(
            wrappedValue: WordSearchViewModel(
                modelContext: ModelContext(Self.placeholderContainer),
                favoritesFetch: { [] }
            )
        )
    }

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        ScrollViewReader { _ in
            ScrollView {
                VStack(spacing: 16) {
                    if !vm.started {
                        WordSearchStartScreen(
                            howToExpanded: $vm.howToExpanded,
                            difficultyExpanded: $vm.difficultyExpanded,
                            difficulty: $vm.difficulty,
                            gameMode: $vm.gameMode,
                            isTimedMode: $vm.isTimedMode,
                            timeLimitString: vm.timeLimitString(),
                            onStart: { vm.start() }
                        )
                    } else {
                        WordSearchHeaderBox(
                            isTimedMode: vm.isTimedMode,
                            timeUp: vm.timeUp,
                            didWin: vm.didWin,
                            remainingSeconds: vm.remainingSeconds,
                            pulseOn: vm.pulseOn,
                            verseRef: vm.verseRef,
                            verseText: vm.verseText,
                            isFavorited: vm.isCurrentFavorited(),
                            onToggleFavorite: { vm.toggleFavoriteCurrent() },
                            timerTint: vm.timerTint(for:)
                        )

                        WordSearchStatusBanner(timeUp: vm.timeUp, didWin: vm.didWin)

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
                                gameMode: vm.gameMode,
                                showBlindWordList: vm.showBlindWordList,

                                isTimedMode: vm.isTimedMode,
                                timeUp: vm.timeUp,
                                remainingSeconds: vm.remainingSeconds,
                                pulseOn: vm.pulseOn,
                                timerTint: vm.timerTint(for:),

                                onNewPuzzle: { vm.newPuzzle() },
                                onReveal: { vm.reveal() },
                                onChangeDifficultyOrMode: { vm.changeSettings() },
                                onToggleHealed: { vm.showBlindWordList.toggle() },
                                healedOn: vm.showBlindWordList,
                                roundOver: vm.roundOver
                            )
                        } else {
                            ZstackPhoneLayout
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Word Search")
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear { vm.stopTimer() }
        }
        // Rebind the VM to the real environment context/fetcher once the view is active.
        .task {
            if !didBindVM {
                vm.rebind(modelContext: modelContext, favoritesFetch: { favorites })
                didBindVM = true
            }
        }
    }

    // MARK: - Extracted phone layout block to keep body smaller

    // Consistent small spacing between the grid and word list on all difficulties (matches the "easy" feel).
    private var phoneInterSectionSpacing: CGFloat {
        6
    }

    private var ZstackPhoneLayout: some View {
        // Use GeometryReader to get the actual content width (after outer padding).
        GeometryReader { geo in
            let gridHeight = dynamicGridHeightForLayout(availableWidth: geo.size.width)
            VStack(spacing: phoneInterSectionSpacing) {
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
                .padding(.top, vm.difficulty == .easy ? 2 : 0)

                // Word list + controls sit under the grid
                wordListAndControlsPhone
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        // Keep the geometry container as small as needed vertically; ScrollView will handle scrolling.
        .frame(minHeight: 0)
    }

    private var wordListAndControlsPhone: some View {
        VStack(spacing: vm.difficulty == .easy ? 8 : 6) {
            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    if vm.gameMode == .blind && !vm.showBlindWordList {
                        let foundCount = vm.targetWords.filter { vm.foundWords.contains($0) }.count
                        HStack {
                            Text("Words to find: \(vm.targetWords.count)").font(.headline)
                            Spacer(minLength: 8)
                            Text("Found: \(foundCount)").font(.headline).foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Find these words:").font(.headline)
                        if vm.targetWords.isEmpty {
                            Text("No words").foregroundStyle(.secondary)
                        } else {
                            WrapWordsView(words: vm.targetWords, found: vm.foundWords, revealed: vm.revealedWords)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            WordSearchControlsBar(
                onNewPuzzle: { vm.newPuzzle() },
                onReveal: { vm.reveal() },
                onChangeDifficultyOrMode: { vm.changeSettings() },
                gameMode: vm.gameMode,
                onToggleHealed: { vm.showBlindWordList.toggle() },
                healedOn: vm.showBlindWordList,
                roundOver: vm.roundOver
            )
        }
        // Small positive top padding to ensure a tiny, consistent gap (no overlap) on all difficulties.
        .padding(.top, 2)
    }

    // MARK: - Helpers

    // Height that matches the grid’s actual size for the given container width (phone).
    // If availableWidth is nil (iPad side layout), we fall back to the previous “target cell” approach.
    private func dynamicGridHeightForLayout(availableWidth: CGFloat?) -> CGFloat {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let spacing: CGFloat = isPad ? 6 : 4
        let minCell: CGFloat = isPad ? 36 : 26
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

    private func backgroundColorForCell(row: Int, col: Int) -> Color {
        let key = "\(row),\(col)"
        if vm.foundCells.contains(key) { return Color.green.opacity(0.45) }
        // Revealed cells (red)
        if vm.placed.contains(where: { pw in
            let original = (vm.difficulty == .expert) ? String(pw.word.reversed()) : pw.word
            return vm.revealedWords.contains(original) && WordSearchEngine(size: vm.size, difficulty: vm.difficulty).cellsForPlacedWord(pw).contains(where: { $0.row == row && $0.col == col })
        }) {
            return Color.red.opacity(0.35)
        }
        if let start = vm.selectionStart, let end = vm.selectionEnd {
            let path = WordSearchEngine(size: vm.size, difficulty: vm.difficulty).selectionCells(from: start, to: end)
            if path.contains(where: { $0.row == row && $0.col == col }) {
                return Color.blue.opacity(0.35)
            }
        }
        return Color(.secondarySystemBackground)
    }
}

#Preview {
    NavigationStack { VerseMatchGameView() }
}
