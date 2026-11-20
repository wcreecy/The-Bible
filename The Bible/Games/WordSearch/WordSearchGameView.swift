import SwiftUI
import SwiftData

struct WordSearchGameView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query private var favorites: [Favorite]
    @State private var vm = WordSearchViewModel()
    @State private var didBindVM = false
    @State private var confirmReveal = false
    /// Width available to the phone layout, used to size the grid.
    @State private var phoneContentWidth: CGFloat = 0

    private var isPad: Bool { horizontalSizeClass == .regular }
    private static let scrollTopID = "wordSearchTop"

    var body: some View {
        @Bindable var vm = vm

        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    if let puzzleGenerationError = vm.puzzleGenerationError {
                        ContentUnavailableView(
                            "Puzzle Unavailable",
                            systemImage: "exclamationmark.triangle",
                            description: Text(puzzleGenerationError)
                        )

                        Button("Try Again", systemImage: "arrow.clockwise") {
                            vm.start()
                        }
                        .buttonStyle(GameProminentButtonStyle(tint: .green))

                        Button("Change Settings") {
                            vm.changeSettings()
                        }
                        .buttonStyle(.glass)
                    } else if !vm.started {
                        WordSearchStartScreen(
                            difficulty: $vm.difficulty,
                            verseSource: $vm.verseSource,
                            isBlindMode: $vm.isBlindMode,
                            isTimedMode: $vm.isTimedMode,
                            wordCountRange: vm.wordCountRange,
                            totalTime: vm.totalTimeRangeString(),
                            eligibleFavoriteCount: vm.eligibleFavoriteCount(),
                            onStart: { vm.start() }
                        )
                    } else if vm.isPaused {
                        GamePausedView(tint: .green, message: "The puzzle is hidden until you resume.", remainingSeconds: vm.remainingSeconds) {
                            vm.resume()
                        }
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
                                selectionCells: vm.selectionCellKeys,
                                foundCells: vm.foundCells,
                                selectionStart: vm.selectionStart,
                                selectionEnd: vm.selectionEnd,
                                revealedWords: vm.revealedWords,
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
                                hintTitle: vm.hintButtonTitle,
                                onHint: { vm.hint() },
                                onShowWordList: { vm.showWordList() },
                                onNewPuzzle: { vm.newPuzzle() },
                                onChangeSettings: { vm.changeSettings() },
                                selectionText: vm.currentSelectionText,
                                hintMessage: vm.hintMessage,
                                lastFoundWord: vm.lastFoundWord,
                                summary: summaryCard
                            )
                        } else {
                            phoneLayout
                        }
                    }
                }
                .padding()
                .id(Self.scrollTopID)
            }
            .scrollDisabled(isPad && vm.started && !vm.isPaused)
            // Each new puzzle (and the start screen) begins at the top, rather than keeping
            // the scroll position from the start screen or the previous round's summary.
            .onChange(of: vm.started) { proxy.scrollTo(Self.scrollTopID, anchor: .top) }
            .onChange(of: vm.roundOver) { _, isOver in
                if !isOver { proxy.scrollTo(Self.scrollTopID, anchor: .top) }
            }
        }
        .tabBarContentClearance()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if vm.started {
                    GameNavigationTitle(.wordSearch)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if vm.started, !vm.roundOver, !vm.isPaused {
                    GameOptionsMenu(gameTitle: "Word Search") {
                        confirmReveal = true
                    }
                }
            }
        }
        .gamePauseControls(canPause: vm.canPause, pause: vm.pause)
        // On phones the controls stay pinned above the tab bar: Hint/Reveal while playing,
        // Settings/Next Puzzle once the round ends. A swipe that starts on the grid selects
        // letters rather than scrolling, so controls below the grid would be hard to reach.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if vm.started && !isPad && !vm.isPaused {
                phoneControlsBar
            }
        }
        .pinnedGameActionButton(
            isShown: vm.started && isPad && !vm.isPaused && vm.roundOver
        ) {
            Button("Next Puzzle", systemImage: "arrow.right") {
                vm.newPuzzle()
            }
            .buttonStyle(GameProminentButtonStyle(tint: .accentColor))
        }
        .gameGiveUpConfirmation(
            "Give up this puzzle?",
            isPresented: $confirmReveal,
            message: "Every word will be shown and this puzzle counts as unfinished."
        ) {
            vm.reveal()
        }
        // Double-tap clears a selection in progress, or starts the next puzzle once this one is
        // over; it never spends a hint.
        .gamePencilActions(isEnabled: vm.started && !vm.isPaused, onDoubleTap: pencilDoubleTapAction) {
            if vm.roundOver {
                Button("Next Puzzle", systemImage: "arrow.right") { vm.newPuzzle() }
            } else {
                Button(vm.hintButtonTitle, systemImage: "lightbulb") { vm.hint() }
                if vm.selectionStart != nil {
                    Button("Clear Selection", systemImage: "xmark.circle") { vm.cancelSelection() }
                }
                GameGiveUpButton { confirmReveal = true }
            }
        }
        .persistenceFailureAlert(failure: $vm.favoriteSaveFailure)
        // The clock pauses while the game is off screen and picks up where it left off.
        .onAppear { vm.resumeTimer() }
        .onDisappear { vm.stopTimer() }
        // A call, another app, or locking the phone pauses a timed round until Resume.
        .onAppActiveChange { vm.appActiveChanged($0) }
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
        VStack(spacing: 6) {
            GridBoard(
                size: vm.size,
                grid: vm.grid,
                selectionCells: vm.selectionCellKeys,
                foundCells: vm.foundCells,
                selectionStart: vm.selectionStart,
                selectionEnd: vm.selectionEnd,
                backgroundColorForCell: backgroundColorForCell,
                onTapCell: { r, c in vm.handleTap(row: r, col: c) },
                onDragChanged: { cell in vm.dragChanged(to: cell) },
                onDragEnded: { vm.dragEnded() },
                dynamicGridHeight: dynamicGridHeightForLayout(availableWidth: phoneContentWidth)
            )
            .frame(maxWidth: .infinity)

            selectionFeedback

            // Word list, controls, and the end-of-round summary sit under the grid.
            wordListAndControlsPhone
        }
        .frame(maxWidth: .infinity, alignment: .center)
        // Measure the width without wrapping the content in a GeometryReader. Inside a
        // ScrollView a GeometryReader doesn't report its content's height, so the summary
        // below the grid could extend past what the ScrollView would scroll to.
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { phoneContentWidth = $0 }
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
        }
        // Small positive top padding to ensure a tiny, consistent gap (no overlap) on all difficulties.
        .padding(.top, 2)
    }

    /// Double-tap: clear a selection in progress, or start the next puzzle once this one is over.
    private var pencilDoubleTapAction: (() -> Void)? {
        if vm.roundOver {
            return { vm.newPuzzle() }
        }
        guard vm.selectionStart != nil else { return nil }
        return { vm.cancelSelection() }
    }

    private var phoneControlsBar: some View {
        WordSearchControlsBar(
            roundOver: vm.roundOver,
            hintTitle: vm.hintButtonTitle,
            canShowWordList: vm.hidesWordList,
            onHint: { vm.hint() },
            onShowWordList: { vm.showWordList() },
            onNewPuzzle: { vm.newPuzzle() },
            onChangeSettings: { vm.changeSettings() },
            showsNextPuzzle: true
        )
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    @ViewBuilder
    private var selectionFeedback: some View {
        if !vm.currentSelectionText.isEmpty {
            Text(vm.currentSelectionText)
                .font(.headline.monospaced())
                .accessibilityLabel("Selected letters: \(vm.currentSelectionText)")
        } else if let hintMessage = vm.hintMessage {
            Label(hintMessage, systemImage: "lightbulb.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
                .transition(.opacity)
        } else if let lastFoundWord = vm.lastFoundWord, !vm.roundOver {
            Label("\(lastFoundWord) found", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
                .transition(.scale.combined(with: .opacity))
        }
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
                missedWords: vm.missedWords,
                currentStreak: vm.currentStreak,
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
            // iPad fallback: reserve a comfortable target height.
            let targetCell: CGFloat = isPad ? 54 : 34
            return CGFloat(vm.size) * targetCell + CGFloat(vm.size - 1) * spacing
        }
    }

    private func colorForWord(_ word: String) -> Color {
        WordSearchPalette.color(for: vm.colorIndexForWord[word])
    }

    private func backgroundColorForCell(row: Int, col: Int) -> Color {
        let key = "\(row),\(col)"
        if vm.hintCellKeys.contains(key) {
            return Color.yellow.opacity(0.75)
        }
        if vm.foundCells.contains(key) {
            return WordSearchPalette.color(for: vm.colorIndexForCell[key]).opacity(0.45)
        }
        if vm.revealedCellKeys.contains(key) {
            return Color.red.opacity(0.35)
        }
        if vm.selectionCellKeys.contains(key) {
            return Color.blue.opacity(0.35)
        }
        return Color(.secondarySystemBackground)
    }
}

#Preview {
    NavigationStack { WordSearchGameView() }
}
