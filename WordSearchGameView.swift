import SwiftUI
import SwiftData
import Combine

struct WordSearchGameView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [Favorite]
    @StateObject private var vm: WordSearchViewModel
    @State private var didBindVM = false

    init() {
        // Defer creating VM until we have a modelContext at runtime; use a placeholder and rebind later
        _vm = StateObject(wrappedValue: WordSearchViewModel(modelContext: ModelContext(try! ModelContainer(for: Favorite.self)), favoritesFetch: { [] }))
    }

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        // Rebind VM with actual context and fetcher (only once)
        let _ = updateVMIfNeeded()

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
                                dynamicGridHeight: dynamicGridHeightForHeightDrivenLayout(),

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
                            ZStack(alignment: .trailing) {
                                Color.clear
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
                                    dynamicGridHeight: dynamicGridHeightForHeightDrivenLayout()
                                )
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)

                            GroupBox {
                                VStack(alignment: .leading, spacing: 8) {
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
                    }
                }
                .padding()
            }
            .navigationTitle("Word Search")
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear { vm.stopTimer() }
        }
    }

    // MARK: - Helpers

    private func updateVMIfNeeded() -> Bool {
        // Rebind the placeholder VM with the actual context and fetcher once
        guard !didBindVM else { return false }
        vm.rebind(modelContext: modelContext, favoritesFetch: { favorites })
        didBindVM = true
        return true
    }

    private var vmIsPlaceholder: Bool {
        // One-time rebind guard
        return !didBindVM
    }

    private func dynamicGridHeightForHeightDrivenLayout() -> CGFloat {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let spacing: CGFloat = isPad ? 6 : 4
        let targetCell: CGFloat = isPad ? 54 : 34
        return CGFloat(vm.size) * targetCell + CGFloat(vm.size - 1) * spacing
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
