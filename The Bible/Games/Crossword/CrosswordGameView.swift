import GameController
import SwiftUI

struct CrosswordGameView: View {
    static let title: LocalizedStringKey = "Crossword"
    static let systemImage = "squareshape.split.3x3"
    static let tint = Color.orange.mix(with: .red, by: 0.35)

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.preferredPencilDoubleTapAction) private var preferredPencilDoubleTapAction
    @Environment(\.preferredPencilSqueezeAction) private var preferredPencilSqueezeAction
    @State private var vm = CrosswordGameViewModel()
    @State private var confirmReveal = false
    @State private var checkMessage: String?
    @State private var selectedPassage: PassageReference?
    /// iPhone: a brief message over the board after Check, or when the board fills with mistakes.
    @State private var bannerMessage: String?
    @FocusState private var isBoardFocused: Bool
    @State private var keyboardFocusRequestID = 0
    @State private var showsTouchKeyboard = true
    @State private var showsPencilActions = false
    /// iPhone: the full clue list, opened from the Clues button.
    @State private var showsClueSheet = false
    /// iPhone: the board zoomed in around the selected square.
    @State private var isZoomed = false
    @State private var boardScroll = ScrollPosition()
    /// The verse shown after an answer is finished, when that setting is on.
    @State private var completedVerse: GameVerse?

    private static let zoomScale: CGFloat = 1.8

    private static let scrollTopID = "crosswordTop"

    init() {}

    #if DEBUG
    /// Lets previews open straight into a round.
    fileprivate init(viewModel: CrosswordGameViewModel) {
        _vm = State(initialValue: viewModel)
    }
    #endif
    private var isPad: Bool { horizontalSizeClass == .regular }

    var body: some View {
        gameContent
        .tabBarContentClearance()
        .pinnedGameActionButton(isShown: isPad && vm.phase == .finished) {
            Button("New Puzzle", systemImage: "arrow.clockwise", action: startPuzzle)
                .buttonStyle(GameProminentButtonStyle(tint: Self.tint))
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if vm.phase != .setup {
                    GameNavigationTitle(title: Self.title, systemImage: Self.systemImage, tint: Self.tint)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if vm.phase == .playing {
                    Menu {
                        Toggle("Show Mistakes as You Type", systemImage: "exclamationmark.circle", isOn: $vm.showsMistakesAsYouType)
                        Toggle("Verse After Each Answer", systemImage: "book.pages", isOn: $vm.showsVerseAfterAnswer)
                        if !vm.wrongCells.isEmpty {
                            Button("Remove All Wrong Letters", systemImage: "eraser.fill") {
                                vm.removeAllWrongLetters()
                                checkMessage = nil
                                restoreBoardFocus()
                            }
                        }
                        Button("Reveal Puzzle", systemImage: "eye", role: .destructive) {
                            confirmReveal = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Crossword options")
                }
            }
        }
        .confirmationDialog("Reveal the puzzle?", isPresented: $confirmReveal, titleVisibility: .visible) {
            Button("Reveal", role: .destructive) { vm.revealPuzzle() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This fills in every answer and counts this puzzle as a loss.")
        }
        .onPencilDoubleTap { _ in
            guard preferredPencilDoubleTapAction != .ignore,
                  vm.phase == .playing, vm.canToggleDirection else { return }
            vm.toggleDirection()
            restoreBoardFocus()
        }
        .onPencilSqueeze { phase in
            guard preferredPencilSqueezeAction != .ignore,
                  vm.phase == .playing, case .ended = phase else { return }
            showsPencilActions = true
        }
        .confirmationDialog("Apple Pencil Actions", isPresented: $showsPencilActions, titleVisibility: .visible) {
            Button("Letter Hint", systemImage: "character.cursor.ibeam") {
                vm.revealLetter()
                restoreBoardFocus()
            }
            Button("Word Hint", systemImage: "text.cursor") {
                vm.revealWord()
                restoreBoardFocus()
            }
            Button("Check", systemImage: "checkmark.circle.fill") {
                checkPuzzle()
                restoreBoardFocus()
            }
            if !vm.wrongCells.isEmpty {
                Button("Remove All Wrong Letters", systemImage: "eraser.fill") {
                    vm.removeAllWrongLetters()
                    restoreBoardFocus()
                }
            }
            Button("Cancel", role: .cancel) { restoreBoardFocus() }
        }
        .sheet(item: $selectedPassage, onDismiss: restoreBoardFocus) { reference in
            ScripturePassageSheet(reference: reference)
        }
        .onChange(of: confirmReveal) { _, isPresented in
            if !isPresented { restoreBoardFocus() }
        }
        // Time away from the app doesn't count toward the solve time.
        .onAppActiveChange { vm.appActiveChanged($0) }
        // Leaving keeps the board, so it comes back with Resume.
        .onDisappear { vm.saveProgress() }
        .sheet(isPresented: $showsClueSheet, onDismiss: restoreBoardFocus) {
            if let puzzle = vm.puzzle {
                NavigationStack {
                    ScrollView {
                        clueList(puzzle)
                            .padding()
                    }
                    .navigationTitle("Clues")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showsClueSheet = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
        // A correct answer shows its verse for a few seconds, when that setting is on.
        .overlay(alignment: .top) {
            if let completedVerse {
                GameVerseCard(verse: completedVerse)
                    .frame(maxWidth: 520)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
                    .onTapGesture { self.completedVerse = nil }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityHint("Double tap to close")
            }
        }
        .animation(.snappy, value: completedVerse)
        .task(id: vm.lastCompletedEntry) {
            guard vm.showsVerseAfterAnswer, vm.phase == .playing, let entry = vm.lastCompletedEntry,
                  let passage = await GamePassage.load(for: entry.reference) else { return }
            completedVerse = GameVerse(text: passage.text, reference: passage.title, isClue: false)
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            completedVerse = nil
        }
        .onChange(of: vm.phase) { _, phase in
            if phase != .playing {
                completedVerse = nil
                isZoomed = false
            }
        }
        // A connected hardware keyboard closes the iPad touch keyboard, which it makes redundant.
        .task {
            if GCKeyboard.coalesced != nil { showsTouchKeyboard = false }
            for await _ in NotificationCenter.default.notifications(named: .GCKeyboardDidConnect) {
                showsTouchKeyboard = false
            }
        }
        .task {
            for await _ in NotificationCenter.default.notifications(named: .GCKeyboardDidDisconnect) {
                showsTouchKeyboard = true
            }
        }
    }

    @ViewBuilder
    private var gameContent: some View {
        if vm.phase == .playing, let puzzle = vm.puzzle {
            if isPad {
                ipadPlayingViewport(puzzle)
            } else {
                iPhonePlayingLayout(puzzle)
            }
        } else {
            scrollableGameContent
        }
    }

    private var scrollableGameContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    switch vm.phase {
                    case .setup:
                        startScreen
                    case .loading:
                        ProgressView("Building your puzzle…")
                            .frame(maxWidth: .infinity, minHeight: 300)
                    case .unavailable:
                        unavailableView
                    case .playing, .finished:
                        if let puzzle = vm.puzzle {
                            gameArea(puzzle)
                        }
                    }
                }
                // The lobby brings its own margins via `gameStartScreenStyle`, like the other
                // games; padding it here too doubled them.
                .padding(vm.phase == .setup ? 0 : 16)
                .id(Self.scrollTopID)
            }
            .onChange(of: vm.phase) { _, phase in
                if phase != .finished {
                    proxy.scrollTo(Self.scrollTopID, anchor: .top)
                }
                if phase == .playing {
                    restoreBoardFocus()
                }
            }
        }
    }

    // MARK: - Start

    private var startScreen: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 24)

            Text("Solve a crossword of Bible people, places, and words.")
                .gameStartDescriptionStyle(title: "Crossword", systemImage: Self.systemImage, tint: Self.tint)

            GameSplashLaunchLayout(
                tint: Self.tint,
                experienceLevel: Binding(
                    get: { vm.difficulty.experienceLevel },
                    set: { vm.difficulty = .init(experienceLevel: $0) }
                ),
                experienceDetails: GameExperienceDetails(
                    learn: "A 9×9 board of familiar names and words.",
                    standard: "An 11×11 board with a broader mix of clues.",
                    challenge: "A 13×13 board with the toughest clues."
                ),
                startTitle: vm.hasSavedRound ? "Resume" : "Start Game",
                startSubtitle: vm.hasSavedRound ? "Pick up where you left off." : "Begin your challenge.",
                startAction: startPuzzle
            ) {
                GameLobbyPreview(kind: .crossword)
            } configuration: {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tap a square to choose it, and tap it again to switch between Across and Down.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Toggle(isOn: $vm.showsMistakesAsYouType) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show Mistakes as You Type")
                            Text("Wrong letters turn red right away.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(Self.tint)

                    Toggle(isOn: $vm.showsVerseAfterAnswer) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Verse After Each Answer")
                            Text("Briefly shows the verse behind each answer you finish.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(Self.tint)

                    if isPad {
                        Toggle(isOn: $vm.usesLargeBoard) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Large 15×15 Puzzle")
                                Text("A longer puzzle designed for the iPad workspace.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(Self.tint)
                    }
                }
            } facts: {
                GameSplashFacts(
                    first: ("stopwatch", vm.savedBestTime.map { GameTimeFormat.short(seconds: $0) } ?? "—", String(localized: "Best time")),
                    second: ("square.grid.3x3", "\(vm.targetBoardSize)×\(vm.targetBoardSize)", String(localized: "Board")),
                    third: ("lightbulb", String(localized: "Unlimited"), String(localized: "Hints")),
                    fourth: ("flame", vm.currentStreak.formatted(), String(localized: "Current streak"))
                )
            }

            Spacer(minLength: 24)
        }
        .gameStartScreenStyle()
    }

    private var unavailableView: some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "Puzzle Unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text("A crossword couldn’t be built from the clue list.")
            )
            Button("Try Again", systemImage: "arrow.clockwise", action: startPuzzle)
                .buttonStyle(GameProminentButtonStyle(tint: Self.tint))
            Button("Change Settings") { vm.changeSettings() }
                .buttonStyle(.bordered)
        }
    }

    private func startPuzzle() {
        Task {
            await vm.start()
            isBoardFocused = true
        }
    }

    // MARK: - Playing

    private func ipadPlayingViewport(_ puzzle: CrosswordPuzzle) -> some View {
        GeometryReader { proxy in
            gameArea(puzzle)
                .frame(
                    width: max(0, proxy.size.width - 32),
                    height: max(0, proxy.size.height - 16),
                    alignment: .top
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func gameArea(_ puzzle: CrosswordPuzzle) -> some View {
        if isPad {
            HStack(alignment: .top, spacing: 24) {
                board(puzzle)
                    .frame(maxWidth: 700)

                if vm.phase == .finished {
                    resultCard(puzzle, pinsNewPuzzle: true)
                        .frame(maxWidth: 520)
                } else {
                    // Only the time redraws each second; the panel redraws when the board changes.
                    CrosswordInspectorView(
                            puzzle: puzzle,
                            guesses: vm.guesses,
                            wrongCells: vm.displayedWrongCells,
                            currentEntry: vm.currentEntry,
                            elapsedSeconds: { vm.activeSeconds() },
                            letterHintsUsed: vm.letterHintsUsed,
                            wordHintsUsed: vm.wordHintsUsed,
                            checksUsed: vm.checksUsed,
                            canUseLetterHint: vm.canUseLetterHint,
                            canUseWordHint: vm.canUseWordHint,
                            canToggleDirection: vm.canToggleDirection,
                            isFilledWithMistakes: vm.isFilledWithMistakes,
                            checkMessage: checkMessage,
                            tint: Self.tint,
                            showsKeyboard: $showsTouchKeyboard,
                            isPencilMode: $vm.isPencilMode,
                            selectEntry: {
                                vm.select($0)
                                restoreBoardFocus()
                            },
                            moveToEntry: {
                                vm.moveToEntry(offset: $0)
                                restoreBoardFocus()
                            },
                            toggleDirection: {
                                vm.toggleDirection()
                                restoreBoardFocus()
                            },
                            revealLetter: {
                                vm.revealLetter()
                                restoreBoardFocus()
                            },
                            revealWord: {
                                vm.revealWord()
                                restoreBoardFocus()
                            },
                            checkPuzzle: {
                                checkPuzzle()
                                restoreBoardFocus()
                            },
                            removeWrongLetters: {
                                vm.removeAllWrongLetters()
                                checkMessage = nil
                                restoreBoardFocus()
                            },
                            typeLetter: {
                                vm.type($0)
                                restoreBoardFocus()
                            },
                            deleteBackward: {
                                vm.deleteBackward()
                                restoreBoardFocus()
                            },
                            showReference: { entry in
                                selectedPassage = PassageReferenceParser.parse(entry.reference)
                            }
                    )
                    .frame(maxWidth: 540, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: 1264)
        } else {
            // iPhone play has its own fixed layout; this is the finished board and results.
            VStack(spacing: 12) {
                board(puzzle)
                resultCard(puzzle, pinsNewPuzzle: false)
            }
        }
    }

    private func board(_ puzzle: CrosswordPuzzle) -> some View {
        ZStack {
            if dynamicTypeSize.isAccessibilitySize, let entry = vm.currentEntry {
                CrosswordAccessibleEntryView(
                    entry: entry,
                    guesses: vm.guesses,
                    revealedCells: vm.revealedCells,
                    selectedCell: vm.selectedCell,
                    tint: Self.tint,
                    onTapCell: { cell in
                        vm.select(cell)
                        restoreBoardFocus()
                    }
                )
            } else if canZoom(puzzle) {
                zoomableBoard(puzzle)
            } else {
                boardGrid(puzzle)
            }

            if isPad {
                CrosswordScribbleCapture(
                    puzzle: puzzle,
                    isActive: vm.phase == .playing,
                    onSelect: { cell in
                        if cell != vm.selectedCell { vm.select(cell) }
                    },
                    onText: { text in
                        for letter in text where letter.isLetter {
                            vm.type(letter)
                        }
                    },
                    onFinish: restoreBoardFocus
                )
                .allowsHitTesting(false)
            }

            CrosswordHardwareKeyboardCapture(
                isActive: vm.phase == .playing,
                focusRequestID: keyboardFocusRequestID,
                onText: { text in
                    for letter in text where letter.isLetter {
                        vm.type(letter)
                    }
                    restoreBoardFocus()
                },
                onDelete: {
                    vm.deleteBackward()
                    restoreBoardFocus()
                },
                onMove: { rowDelta, columnDelta in
                    vm.moveSelection(rowDelta: rowDelta, columnDelta: columnDelta)
                    restoreBoardFocus()
                },
                onNextClue: { offset in
                    vm.moveToEntry(offset: offset)
                    restoreBoardFocus()
                },
                onToggleDirection: {
                    vm.toggleDirection()
                    restoreBoardFocus()
                },
                onCheck: {
                    checkPuzzle()
                    restoreBoardFocus()
                },
                onEscape: dismissPresentedContent
            )
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .allowsHitTesting(false)
        }
        // A hardware keyboard types straight into the board.
        .contentShape(Rectangle())
        .focusable(vm.phase == .playing)
        .focused($isBoardFocused)
        .focusEffectDisabled()
        .onKeyPress(phases: .down, action: handleKeyPress)
        .onAppear(perform: restoreBoardFocus)
    }

    private func boardGrid(_ puzzle: CrosswordPuzzle) -> some View {
        CrosswordBoardView(
            puzzle: puzzle,
            guesses: vm.guesses,
            revealedCells: vm.revealedCells,
            selectedCell: vm.selectedCell,
            selectedDirection: vm.direction,
            wrongCells: vm.displayedWrongCells,
            pencilCells: vm.pencilCells,
            tint: Self.tint,
            hasKeyboardFocus: isBoardFocused,
            onTapCell: { cell in
                vm.select(cell)
                restoreBoardFocus()
            }
        )
    }

    /// iPhone boards of 11×11 and up have small squares, so they can zoom in.
    private func canZoom(_ puzzle: CrosswordPuzzle) -> Bool {
        !isPad && vm.phase == .playing && puzzle.size >= 11
    }

    /// The board, zoomed in around the selected square when `isZoomed`. Pinch to zoom in or out.
    /// The zoomed board scrolls, following the selection as you type.
    private func zoomableBoard(_ puzzle: CrosswordPuzzle) -> some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            Group {
                if isZoomed {
                    ScrollView([.horizontal, .vertical], showsIndicators: false) {
                        boardGrid(puzzle)
                            .frame(width: side * Self.zoomScale, height: side * Self.zoomScale)
                    }
                    .scrollPosition($boardScroll)
                    .onAppear { scrollToSelection(puzzle: puzzle, side: side, animated: false) }
                    .onChange(of: vm.selectedCell) { _, _ in scrollToSelection(puzzle: puzzle, side: side, animated: true) }
                } else {
                    boardGrid(puzzle)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .simultaneousGesture(
                MagnifyGesture().onEnded { value in
                    if value.magnification > 1.15 { setZoomed(true) }
                    if value.magnification < 0.87 { setZoomed(false) }
                }
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func setZoomed(_ zoomed: Bool) {
        guard zoomed != isZoomed else { return }
        withAnimation(.snappy) { isZoomed = zoomed }
        Haptics.selection()
    }

    /// Scrolls the zoomed board so the selected square sits in the middle where it can.
    private func scrollToSelection(puzzle: CrosswordPuzzle, side: CGFloat, animated: Bool) {
        guard let cell = vm.selectedCell else { return }
        let cellSize = side * Self.zoomScale / CGFloat(puzzle.size)
        let point = CGPoint(
            x: max(0, (CGFloat(cell.col) + 0.5) * cellSize - side / 2),
            y: max(0, (CGFloat(cell.row) + 0.5) * cellSize - side / 2)
        )
        if animated {
            withAnimation(.snappy) { boardScroll.scrollTo(point: point) }
        } else {
            boardScroll.scrollTo(point: point)
        }
    }

    // MARK: - iPhone

    /// iPhone play: time and progress, the board, then the current clue, tools and keyboard
    /// pinned at the bottom, with nothing to scroll. The full clue list opens as a sheet.
    ///
    /// The clue, tools and keyboard always get the height they need (a long clue wraps instead of
    /// spilling over the tools), and the board shrinks to fit what's left.
    private func iPhonePlayingLayout(_ puzzle: CrosswordPuzzle) -> some View {
        GeometryReader { geometry in
            VStack(spacing: 8) {
                iPhoneStatusRow(puzzle)
                board(puzzle)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .bottom) { messageBanner }
                VStack(spacing: 8) {
                    clueBar
                    iPhoneToolRow
                    keyboard(keyHeight: Self.iPhoneKeyHeight(for: geometry.size))
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
        // Uses most of the space kept clear for the tab bar, leaving a small gap above it.
        .padding(.bottom, -Self.iPhoneTabBarAllowance)
        .onChange(of: vm.guesses) {
            checkMessage = nil
            if !vm.isFilledWithMistakes { bannerMessage = nil }
        }
        .onChange(of: vm.isFilledWithMistakes) { _, isFull in
            if isFull {
                bannerMessage = String(localized: "The board is full, but some letters are wrong. Tap Check to find them.")
            }
        }
        .task(id: bannerMessage) {
            guard bannerMessage != nil else { return }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(.snappy) { bannerMessage = nil }
        }
        .animation(.snappy, value: bannerMessage)
    }

    /// How far the iPhone game may extend into the 80 points `tabBarContentClearance()` keeps
    /// clear, leaving a 16-point gap above the tab bar (as in WORD).
    private static let iPhoneTabBarAllowance: CGFloat = 64

    /// Keys grow on taller phones, from 40 up to 48 points. This depends only on the screen
    /// size (with room for a three-line clue), so keys don't change size from clue to clue.
    private static func iPhoneKeyHeight(for size: CGSize) -> CGFloat {
        let board = size.width - 24
        // Status row, three-line clue, tool row, keyboard gaps, spacing and padding.
        let reserved: CGFloat = 20 + 96 + 44 + 12 + 4 * 8 + 12
        let leftover = size.height - board - reserved - 3 * 40
        return 40 + min(8, max(0, leftover / 3)).rounded(.down)
    }

    /// The solve time and how many squares are filled, under the title.
    private func iPhoneStatusRow(_ puzzle: CrosswordPuzzle) -> some View {
        let letterCells = Set(puzzle.entries.flatMap(\.cells))
        let filled = letterCells.count { vm.guesses[$0] != nil }
        return TimelineView(.periodic(from: .now, by: 1)) { _ in
            HStack(spacing: 6) {
                Label(GameTimeFormat.short(seconds: vm.activeSeconds()), systemImage: "timer")
                Text(verbatim: "·")
                    .accessibilityHidden(true)
                Text("\(filled)/\(letterCells.count) squares")
            }
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(.primary.opacity(0.06), in: Capsule())
            .accessibilityElement(children: .combine)
        }
    }

    /// The Check result or the board-full note, over the bottom of the board for a few seconds,
    /// so it never pushes the board or keyboard around. Tap to close it sooner.
    @ViewBuilder
    private var messageBanner: some View {
        if let bannerMessage {
            Text(bannerMessage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(vm.isFilledWithMistakes ? .orange : .primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: .capsule)
                .padding(8)
                .onTapGesture { self.bannerMessage = nil }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityAddTraits(.isStaticText)
        }
    }

    /// Hints, Check, pencil mode, zoom and the clue list, in one slim row.
    private var iPhoneToolRow: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                Button("Letter", systemImage: "character.cursor.ibeam") {
                    vm.revealLetter()
                    restoreBoardFocus()
                }
                .disabled(!vm.canUseLetterHint)
                .accessibilityLabel("Reveal a letter")

                Button("Word", systemImage: "text.cursor") {
                    vm.revealWord()
                    restoreBoardFocus()
                }
                .disabled(!vm.canUseWordHint)
                .accessibilityLabel("Reveal the current word")

                Button(checkButtonTitle, systemImage: "checkmark.circle.fill") {
                    checkPuzzle()
                    restoreBoardFocus()
                }
                .buttonStyle(.borderedProminent)
                .tint(vm.isFilledWithMistakes ? .orange : Self.tint)

                Button("Pencil", systemImage: vm.isPencilMode ? "pencil.circle.fill" : "pencil.circle") {
                    vm.isPencilMode.toggle()
                    restoreBoardFocus()
                }
                .tint(vm.isPencilMode ? Self.tint : nil)
                .accessibilityLabel("Pencil mode")
                .accessibilityValue(vm.isPencilMode ? "On" : "Off")

                if let puzzle = vm.puzzle, canZoom(puzzle) {
                    Button(isZoomed ? "Zoom Out" : "Zoom In", systemImage: isZoomed ? "minus.magnifyingglass" : "plus.magnifyingglass") {
                        setZoomed(!isZoomed)
                    }
                    .labelStyle(.iconOnly)
                }

                Button("Clues", systemImage: "list.bullet") {
                    showsClueSheet = true
                }
                .labelStyle(.iconOnly)
            }
            .font(.subheadline.weight(.semibold))
            .labelStyle(CrosswordHintLabelStyle())
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .buttonStyle(.glass)
            .foregroundStyle(.primary)
        }
    }

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        if handleArrowKey(press.key.character) {
            restoreBoardFocus()
            return .handled
        }

        switch press.key {
        case .delete:
            vm.deleteBackward()
        case .tab:
            vm.moveToEntry(offset: press.modifiers.contains(.shift) ? -1 : 1)
        case .return:
            if press.modifiers.contains(.command) {
                checkPuzzle()
            } else {
                vm.toggleDirection()
            }
        case .space:
            vm.toggleDirection()
        case .escape:
            if selectedPassage != nil {
                selectedPassage = nil
            } else if confirmReveal {
                confirmReveal = false
            } else {
                return .ignored
            }
        default:
            guard press.modifiers.intersection([.command, .control, .option]).isEmpty,
                  let letter = press.characters.first,
                  letter.isLetter else { return .ignored }
            vm.type(letter)
        }
        restoreBoardFocus()
        return .handled
    }

    /// Arrow-key characters use the standard function-key scalar values on iPadOS.
    private func handleArrowKey(_ character: Character) -> Bool {
        switch character {
        case "\u{F700}":
            vm.moveSelection(rowDelta: -1, columnDelta: 0)
        case "\u{F701}":
            vm.moveSelection(rowDelta: 1, columnDelta: 0)
        case "\u{F702}":
            vm.moveSelection(rowDelta: 0, columnDelta: -1)
        case "\u{F703}":
            vm.moveSelection(rowDelta: 0, columnDelta: 1)
        default:
            return false
        }
        return true
    }

    private func checkPuzzle() {
        let wrong = vm.checkPuzzle()
        checkMessage = wrong == 0
            ? String(localized: "No mistakes so far.")
            : String(localized: "\(wrong) letters to fix.")
        bannerMessage = checkMessage
        if let checkMessage {
            AccessibilityNotification.Announcement(checkMessage).post()
        }
    }

    private func restoreBoardFocus() {
        guard vm.phase == .playing else { return }
        keyboardFocusRequestID &+= 1
        Task { @MainActor in
            await Task.yield()
            isBoardFocused = true
        }
    }

    private func dismissPresentedContent() {
        if selectedPassage != nil {
            selectedPassage = nil
        } else if confirmReveal {
            confirmReveal = false
        }
        restoreBoardFocus()
    }

    private var clueBar: some View {
        // One container so the clue panel and arrow buttons blend as a single glass group.
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                clueArrow("Previous clue", systemImage: "chevron.left", offset: -1)
                clueText
                clueArrow("Next clue", systemImage: "chevron.right", offset: 1)
            }
        }
    }

    private var directionButtonAccessibilityLabel: String {
        switch (vm.direction, vm.canToggleDirection) {
        case (.across, true):
            String(localized: "Across. Switch to Down")
        case (.down, true):
            String(localized: "Down. Switch to Across")
        case (.across, false):
            String(localized: "Across. No Down answer at this square")
        case (.down, false):
            String(localized: "Down. No Across answer at this square")
        }
    }

    private func clueArrow(_ title: LocalizedStringKey, systemImage: String, offset: Int) -> some View {
        Button(title, systemImage: systemImage) {
            vm.moveToEntry(offset: offset)
            restoreBoardFocus()
        }
            .labelStyle(.iconOnly)
            .font(.body.weight(.semibold))
            .frame(width: 32, height: 32)
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
    }

    /// The current clue, with the direction and Scripture buttons beside its label so the clue
    /// itself gets the full width. Long clues wrap to three lines and then shrink slightly.
    private var clueText: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let entry = vm.currentEntry {
                HStack(spacing: 6) {
                    Text(entryLabel(entry))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button(
                        vm.direction == .across ? "Across" : "Down",
                        systemImage: vm.direction == .across ? "arrow.left.and.right" : "arrow.up.and.down"
                    ) {
                        vm.toggleDirection()
                        restoreBoardFocus()
                    }
                    .disabled(!vm.canToggleDirection)
                    .accessibilityLabel(directionButtonAccessibilityLabel)
                    if let reference = PassageReferenceParser.parse(entry.reference) {
                        Button("Scripture Hint", systemImage: "book") { selectedPassage = reference }
                            .accessibilityHint("Shows the verse behind this clue")
                    }
                }
                .labelStyle(.iconOnly)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderless)
                .tint(.primary)

                Button {
                    vm.toggleDirection()
                    restoreBoardFocus()
                } label: {
                    Text(entry.clue)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Switches between Across and Down")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: AppDesignMetrics.cardCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius)
                .stroke(.primary.opacity(0.12), lineWidth: 0.75)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.10), radius: 3, y: 1)
    }

    private var checkButtonTitle: LocalizedStringKey {
        if vm.isFilledWithMistakes, !vm.wrongCells.isEmpty {
            "Check \(vm.wrongCells.count) mistakes"
        } else {
            "Check"
        }
    }

    private func keyboard(keyHeight: CGFloat) -> some View {
        CrosswordKeyboardView(
            keyHeight: keyHeight,
            onLetter: {
                vm.type($0)
                restoreBoardFocus()
            },
            onDelete: {
                vm.deleteBackward()
                restoreBoardFocus()
            }
        )
    }

    private func clueList(_ puzzle: CrosswordPuzzle) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            clueSection("Across", entries: puzzle.acrossEntries)
            clueSection("Down", entries: puzzle.downEntries)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func clueSection(_ title: LocalizedStringKey, entries: [CrosswordPuzzle.Entry]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            ForEach(entries) { entry in
                let isCurrent = entry == vm.currentEntry
                let isFilled = entry.cells.allSatisfy { vm.guesses[$0] != nil }
                Button {
                    vm.select(entry)
                    showsClueSheet = false
                    restoreBoardFocus()
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(entry.number)")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .frame(minWidth: 24, alignment: .trailing)
                        Text(entry.clue)
                            .font(.subheadline)
                            .strikethrough(isFilled, color: .secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if isFilled {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Self.tint)
                                .transition(.scale.combined(with: .opacity))
                                .accessibilityLabel("Entry filled")
                        }
                    }
                    .foregroundStyle(isFilled ? .secondary : .primary)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background(isCurrent ? Self.tint.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("\(entryLabel(entry)): \(entry.clue)"))
                .accessibilityAddTraits(isCurrent ? .isSelected : [])
            }
        }
    }

    private func entryLabel(_ entry: CrosswordPuzzle.Entry) -> String {
        switch entry.direction {
        case .across: String(localized: "\(entry.number) Across")
        case .down: String(localized: "\(entry.number) Down")
        }
    }

    // MARK: - Results

    private func resultCard(_ puzzle: CrosswordPuzzle, pinsNewPuzzle: Bool) -> some View {
        let unassistedAnswers = puzzle.entries.filter(vm.wasSolvedWithoutHints).count
        let title: String = switch vm.outcome {
        case .solved: String(localized: "Puzzle solved!")
        case .solvedWithHelp: String(localized: "Solved with help")
        case .revealed, nil: String(localized: "Puzzle revealed")
        }
        let subtitle: String? = switch vm.outcome {
        case .solved where vm.wordHintsUsed > 0:
            String(localized: "Solved without hints: \(unassistedAnswers) of \(puzzle.entries.count) answers. Best times need no word hints.")
        case .solved:
            String(localized: "Solved without hints: \(unassistedAnswers) of \(puzzle.entries.count) answers")
        case .solvedWithHelp:
            String(localized: "Hints filled more than half the letters. Your streak continues, but it doesn't count toward a best time.")
        case .revealed, nil:
            nil
        }
        let isWin = vm.outcome == .solved || vm.outcome == .solvedWithHelp
        return VStack(spacing: 12) {
            GamePuzzleResultCard(
                title: title,
                subtitle: subtitle,
                systemImage: vm.outcome == .solved ? "checkmark.seal.fill" : (isWin ? "lightbulb.fill" : "eye.fill"),
                tint: vm.outcome == .solved ? .green : Self.tint,
                facts: [
                    ("timer", GameTimeFormat.short(seconds: vm.elapsedSeconds), String(localized: "Time")),
                    ("character.cursor.ibeam", "\(vm.letterHintsUsed)", String(localized: "Letter hints")),
                    ("text.cursor", "\(vm.wordHintsUsed)", String(localized: "Word hints")),
                    ("checkmark.circle", "\(vm.checksUsed)", String(localized: "Checks")),
                ],
                bestTime: vm.bestTimeComparison,
                streak: GamePuzzleStreak(current: vm.currentStreak)
            ) {
                GamePuzzleResultSection(title: "Answers", systemImage: "book.closed", tint: Self.tint) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(puzzle.entries) { entry in
                            answerRow(entry)
                        }
                    }
                }
            }

            if !pinsNewPuzzle {
                Button("New Puzzle", systemImage: "arrow.clockwise", action: startPuzzle)
                    .buttonStyle(GameProminentButtonStyle(tint: Self.tint))
            }
            Button("Change Settings") { vm.changeSettings() }
                .buttonStyle(.bordered)
        }
    }

    private func answerRow(_ entry: CrosswordPuzzle.Entry) -> some View {
        let solvedByPlayer = vm.wasSolvedWithoutHints(entry)
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(entryLabel(entry))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(entry.answer)
                    .font(.subheadline.weight(.bold).monospaced())
                if !solvedByPlayer {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundStyle(CrosswordBoardView.hintColor)
                        .accessibilityLabel("Revealed")
                }
            }
            Text(entry.clue)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            if let reference = PassageReferenceParser.parse(entry.reference) {
                Button(entry.reference, systemImage: "book") { selectedPassage = reference }
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.borderless)
                    .tint(Self.tint)
                    .accessibilityHint("Shows the verse")
            } else {
                Text(entry.reference)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


// MARK: - iPad workspace

private struct CrosswordInspectorView: View {
    let puzzle: CrosswordPuzzle
    let guesses: [CrosswordPuzzle.Cell: Character]
    let wrongCells: Set<CrosswordPuzzle.Cell>
    let currentEntry: CrosswordPuzzle.Entry?
    /// The solve time so far, read by the status bar once a second.
    let elapsedSeconds: () -> Int
    let letterHintsUsed: Int
    let wordHintsUsed: Int
    let checksUsed: Int
    let canUseLetterHint: Bool
    let canUseWordHint: Bool
    let canToggleDirection: Bool
    let isFilledWithMistakes: Bool
    let checkMessage: String?
    let tint: Color
    @Binding var showsKeyboard: Bool
    @Binding var isPencilMode: Bool
    let selectEntry: (CrosswordPuzzle.Entry) -> Void
    let moveToEntry: (Int) -> Void
    let toggleDirection: () -> Void
    let revealLetter: () -> Void
    let revealWord: () -> Void
    let checkPuzzle: () -> Void
    let removeWrongLetters: () -> Void
    let typeLetter: (Character) -> Void
    let deleteBackward: () -> Void
    let showReference: (CrosswordPuzzle.Entry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CrosswordStatusBar(
                puzzle: puzzle,
                guesses: guesses,
                elapsedSeconds: elapsedSeconds,
                hintsUsed: letterHintsUsed + wordHintsUsed,
                checksUsed: checksUsed,
                tint: tint
            )

            if let currentEntry {
                CrosswordActiveClueCard(
                    entry: currentEntry,
                    tint: tint,
                    canToggleDirection: canToggleDirection,
                    previous: { moveToEntry(-1) },
                    next: { moveToEntry(1) },
                    toggleDirection: toggleDirection,
                    showReference: { showReference(currentEntry) }
                )
            }

            CrosswordInspectorTools(
                isPencilMode: $isPencilMode,
                canUseLetterHint: canUseLetterHint,
                canUseWordHint: canUseWordHint,
                isFilledWithMistakes: isFilledWithMistakes,
                checkMessage: checkMessage,
                wrongLetterCount: wrongCells.count,
                tint: tint,
                revealLetter: revealLetter,
                revealWord: revealWord,
                checkPuzzle: checkPuzzle,
                removeWrongLetters: removeWrongLetters
            )

            DisclosureGroup(isExpanded: $showsKeyboard) {
                CrosswordKeyboardView(onLetter: typeLetter, onDelete: deleteBackward)
                    .padding(.top, 10)
            } label: {
                Label("Touch Keyboard", systemImage: "keyboard")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(12)
            .heroCardSurface()

            CrosswordClueListCard(
                puzzle: puzzle,
                guesses: guesses,
                wrongCells: wrongCells,
                currentEntry: currentEntry,
                tint: tint,
                selectEntry: selectEntry
            )
            .frame(maxHeight: .infinity)
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct CrosswordStatusBar: View {
    let puzzle: CrosswordPuzzle
    let guesses: [CrosswordPuzzle.Cell: Character]
    let elapsedSeconds: () -> Int
    let hintsUsed: Int
    let checksUsed: Int
    let tint: Color

    private var completedEntries: Int {
        puzzle.entries.filter { entry in
            entry.cells.allSatisfy { guesses[$0] != nil }
        }.count
    }

    var body: some View {
        HStack(spacing: 0) {
            // The only part of the panel that changes every second.
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                item(GameTimeFormat.short(seconds: elapsedSeconds()), label: "Time", systemImage: "timer")
            }
            Divider()
            item("\(completedEntries)/\(puzzle.entries.count)", label: "Answers", systemImage: "list.number")
            Divider()
            item("\(hintsUsed)", label: "Hints", systemImage: "lightbulb")
            Divider()
            item("\(checksUsed)", label: "Checks", systemImage: "checkmark.circle")
        }
        .padding(.vertical, 10)
        .heroCardSurface()
        .accessibilityElement(children: .contain)
    }

    private func item(_ value: String, label: LocalizedStringKey, systemImage: String) -> some View {
        VStack(spacing: 3) {
            Label(value, systemImage: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .labelStyle(.titleAndIcon)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CrosswordActiveClueCard: View {
    let entry: CrosswordPuzzle.Entry
    let tint: Color
    let canToggleDirection: Bool
    let previous: () -> Void
    let next: () -> Void
    let toggleDirection: () -> Void
    let showReference: () -> Void

    private var directionLabel: String {
        switch entry.direction {
        case .across: String(localized: "Across")
        case .down: String(localized: "Down")
        }
    }

    private var directionButtonAccessibilityLabel: String {
        switch (entry.direction, canToggleDirection) {
        case (.across, true):
            String(localized: "Across. Switch to Down")
        case (.down, true):
            String(localized: "Down. Switch to Across")
        case (.across, false):
            String(localized: "Across. No Down answer at this square")
        case (.down, false):
            String(localized: "Down. No Across answer at this square")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("Previous clue", systemImage: "chevron.left", action: previous)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.number) \(directionLabel)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                    Text(entry.clue)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(
                    directionLabel,
                    systemImage: entry.direction == .across ? "arrow.left.and.right" : "arrow.up.and.down",
                    action: toggleDirection
                )
                    .disabled(!canToggleDirection)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .accessibilityLabel(directionButtonAccessibilityLabel)

                Button("Next clue", systemImage: "chevron.right", action: next)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
            }

            HStack {
                Label("\(entry.answer.count) letters", systemImage: "textformat.size")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                if !entry.reference.isEmpty {
                    Button("Scripture Hint", systemImage: "book", action: showReference)
                        .font(.footnote.weight(.semibold))
                        .buttonStyle(.borderless)
                }
            }
        }
        .padding(14)
        .heroCardSurface()
    }
}

private struct CrosswordInspectorTools: View {
    @Binding var isPencilMode: Bool
    let canUseLetterHint: Bool
    let canUseWordHint: Bool
    let isFilledWithMistakes: Bool
    let checkMessage: String?
    let wrongLetterCount: Int
    let tint: Color
    let revealLetter: () -> Void
    let revealWord: () -> Void
    let checkPuzzle: () -> Void
    let removeWrongLetters: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text("Reveal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Button("Letter", systemImage: "character.cursor.ibeam", action: revealLetter)
                    .disabled(!canUseLetterHint)
                    .accessibilityLabel("Reveal a letter")
                Button("Word", systemImage: "text.cursor", action: revealWord)
                    .disabled(!canUseWordHint)
                    .accessibilityLabel("Reveal the current word")

                Divider()
                    .frame(height: 24)

                Button("Check", systemImage: "checkmark.circle.fill", action: checkPuzzle)
                    .buttonStyle(.borderedProminent)
                    .tint(isFilledWithMistakes ? .orange : tint)

                Toggle(isOn: $isPencilMode) {
                    Label("Pencil", systemImage: "pencil")
                }
                .toggleStyle(.button)
                .tint(tint)
                .accessibilityHint("Letters you type now are drawn in gray as guesses")
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)

            if isFilledWithMistakes {
                Text("The board is full, but some letters are wrong. Check the puzzle to find them.")
                    .foregroundStyle(.orange)
            } else if let checkMessage {
                Text(checkMessage)
                    .foregroundStyle(.secondary)
            }

            if wrongLetterCount > 0 {
                Button("Remove All Wrong Letters", systemImage: "eraser.fill", action: removeWrongLetters)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .accessibilityLabel("Remove \(wrongLetterCount) wrong letters")
            }
        }
        .font(.footnote)
    }
}

private struct CrosswordClueListCard: View {
    let puzzle: CrosswordPuzzle
    let guesses: [CrosswordPuzzle.Cell: Character]
    let wrongCells: Set<CrosswordPuzzle.Cell>
    let currentEntry: CrosswordPuzzle.Entry?
    let tint: Color
    let selectEntry: (CrosswordPuzzle.Entry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Clues", systemImage: "list.bullet.rectangle")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Divider()

            ScrollView {
                CrosswordClueBrowser(
                    puzzle: puzzle,
                    guesses: guesses,
                    wrongCells: wrongCells,
                    currentEntry: currentEntry,
                    tint: tint,
                    selectEntry: selectEntry
                )
                .padding(.vertical, 2)
                .padding(.trailing, 4)
            }
            .scrollIndicators(.visible)
        }
        .padding(12)
        .heroCardSurface()
    }
}

private struct CrosswordClueBrowser: View {
    let puzzle: CrosswordPuzzle
    let guesses: [CrosswordPuzzle.Cell: Character]
    let wrongCells: Set<CrosswordPuzzle.Cell>
    let currentEntry: CrosswordPuzzle.Entry?
    let tint: Color
    let selectEntry: (CrosswordPuzzle.Entry) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 14) {
                section("Across", entries: puzzle.acrossEntries)
                section("Down", entries: puzzle.downEntries)
            }
            VStack(alignment: .leading, spacing: 16) {
                section("Across", entries: puzzle.acrossEntries)
                section("Down", entries: puzzle.downEntries)
            }
        }
    }

    private func section(_ title: LocalizedStringKey, entries: [CrosswordPuzzle.Entry]) -> some View {
        CrosswordClueSection(
            title: title,
            entries: entries,
            guesses: guesses,
            wrongCells: wrongCells,
            currentEntry: currentEntry,
            tint: tint,
            selectEntry: selectEntry
        )
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct CrosswordClueSection: View {
    let title: LocalizedStringKey
    let entries: [CrosswordPuzzle.Entry]
    let guesses: [CrosswordPuzzle.Cell: Character]
    let wrongCells: Set<CrosswordPuzzle.Cell>
    let currentEntry: CrosswordPuzzle.Entry?
    let tint: Color
    let selectEntry: (CrosswordPuzzle.Entry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            ForEach(entries) { entry in
                CrosswordClueRow(
                    entry: entry,
                    guesses: guesses,
                    wrongCells: wrongCells,
                    isCurrent: entry == currentEntry,
                    tint: tint,
                    action: { selectEntry(entry) }
                )
            }
        }
    }
}

private struct CrosswordClueRow: View {
    let entry: CrosswordPuzzle.Entry
    let guesses: [CrosswordPuzzle.Cell: Character]
    let wrongCells: Set<CrosswordPuzzle.Cell>
    let isCurrent: Bool
    let tint: Color
    let action: () -> Void

    private var filledCount: Int {
        entry.cells.filter { guesses[$0] != nil }.count
    }

    private var isFilled: Bool {
        filledCount == entry.cells.count
    }

    private var hasCheckedError: Bool {
        !wrongCells.isDisjoint(with: entry.cells)
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("\(entry.number)")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .frame(minWidth: 22, alignment: .trailing)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.clue)
                        .font(.subheadline)
                        .multilineTextAlignment(.leading)
                    Text("\(filledCount)/\(entry.cells.count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if hasCheckedError {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                        .accessibilityLabel("Has an incorrect letter")
                } else if isFilled {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(tint)
                        .accessibilityLabel("Filled")
                } else if filledCount > 0 {
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundStyle(tint)
                        .accessibilityLabel("Partially filled")
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 6)
            .background(isCurrent ? tint.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}

/// Hint button text that fills the button, so all four glass buttons share the width evenly.
private struct CrosswordHintLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.title
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Keyboard

/// An on-screen QWERTY keyboard for typing into the crossword.
private struct CrosswordKeyboardView: View {
    var keyHeight: CGFloat = 40
    let onLetter: (Character) -> Void
    let onDelete: () -> Void

    private let rows: [[Character]] = [Array("QWERTYUIOP"), Array("ASDFGHJKL"), Array("ZXCVBNM")]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(rows.indices, id: \.self) { index in
                HStack(spacing: 4) {
                    ForEach(rows[index], id: \.self) { letter in
                        Button(String(letter)) { onLetter(letter) }
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: keyHeight)
                            .buttonStyle(GameKeyButtonStyle(tint: .accentColor))
                    }
                    if index == rows.count - 1 {
                        Button(action: onDelete) {
                            Image(systemName: "delete.left")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: keyHeight)
                        }
                        .buttonStyle(GameKeyButtonStyle(tint: .red))
                        .frame(maxWidth: 64)
                        .accessibilityLabel("Delete")
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview("Start") {
    NavigationStack { CrosswordGameView() }
}

#if DEBUG
#Preview("Playing") {
    let vm = CrosswordGameViewModel(defaults: UserDefaults(suiteName: "CrosswordPreview") ?? .standard, recordsStats: false)
    let clues = GameDataLoaders.loadCrosswordClues().filter { $0.difficulty == "easy" }
    if let puzzle = CrosswordGenerator.generate(from: clues, preferredSize: 9) {
        vm.begin(with: puzzle)
        for letter in "ABC" { vm.type(letter) }
    }
    return NavigationStack { CrosswordGameView(viewModel: vm) }
}
#endif
