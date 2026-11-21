import SwiftUI

struct ScrambleGameView: View {
    @State private var timerOnLeft = false
    @State private var usesMutedTimerStyle = false
    @State private var selectedPassage: PassageReference?
    @State private var isRevealConfirmationPresented = false
    @State private var vm: ScrambleGameViewModel
    /// The board's frame in the game's Pencil space, to find the square or tile under the Pencil.
    @State private var boardFrameInGame: CGRect = .zero
    /// Square and tile frames, and any drag in progress, for drag and Apple Pencil drops.
    @State private var boardLayout = ScrambleBoardLayout()

    init(reviewQuestionIDs: Set<String> = []) {
        _vm = State(initialValue: ScrambleGameViewModel(reviewQuestionIDs: reviewQuestionIDs))
    }
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isIncorrectAnswer: Bool {
        if case .incorrect = vm.answerFeedback {
            return true
        }
        return false
    }
    @FocusState private var isKeyboardFocused: Bool

    private var experienceLevel: Binding<GameExperienceLevel> {
        Binding(
            get: { vm.difficulty.experienceLevel },
            set: { vm.difficulty = Difficulty(experienceLevel: $0) }
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let usesSplitLayout = vm.phase == .playing && geometry.size.width >= 700

            ZStack {
                ScrollView {
                    VStack(spacing: 16) {
                        switch vm.phase {
                        case .setup:
                            startScreen
                        case .playing:
                            if vm.isPaused {
                                GamePausedView(tint: .pink, remainingSeconds: vm.timeRemaining) {
                                    vm.isPaused = false
                                }
                                .frame(maxWidth: 620)
                            } else {
                                gameScreen(usesSplitLayout: usesSplitLayout)
                            }
                        case .results:
                            resultsScreen
                        }
                    }
                    .padding(.horizontal)
                }
                .tabBarContentClearance()
                // Pinned above the tab bar, so a long verse never pushes it out of reach.
                .pinnedGameActionButton(isShown: showsNextWordButton) {
                    nextWordButton
                }
                .background {
                    if usesSplitLayout {
                        Color.clear
                            .heroCardSurface()
                            .padding(12)
                    }
                }
                .frame(width: usesSplitLayout ? geometry.size.width / 2 : geometry.size.width)
                .frame(
                    maxWidth: .infinity,
                    alignment: usesSplitLayout && timerOnLeft ? .trailing : .leading
                )

                if usesSplitLayout {
                    ScrambleLargeTimerView(
                        timeRemaining: vm.timeRemaining,
                        timeLimit: vm.currentTimeLimit,
                        tint: vm.timerTint,
                        isTimerDisabled: vm.isTimerDisabled,
                        verse: vm.displayedVerse,
                        usesMutedStyle: $usesMutedTimerStyle,
                        onToggleTimer: vm.toggleTimer,
                        onSwapSides: {
                            withAnimation(.snappy) {
                                timerOnLeft.toggle()
                            }
                        }
                    )
                    .frame(width: geometry.size.width / 2)
                    .frame(maxWidth: .infinity, alignment: timerOnLeft ? .leading : .trailing)
                }
            }
            .focusable()
            .focused($isKeyboardFocused)
            .onKeyPress(phases: .down) { keyPress in
                handleKeyboardPress(keyPress)
            }
            .onChange(of: vm.phase) { _, phase in
                isKeyboardFocused = phase == .playing
            }
        }
        .background(AppBackgroundView(tab: .games))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if vm.phase != .setup {
                    GameNavigationTitle(.scramble)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if vm.phase == .playing, !vm.isCurrentWordResolved {
                    GameOptionsMenu(gameTitle: "Scramble") {
                        isRevealConfirmationPresented = true
                    }
                }
            }
        }
        // A call, another app, or locking the phone pauses the word until Resume.
        .gamePauseControls(canPause: vm.canPause) { vm.isPaused = true }
        .task {
            await vm.loadWordBank()
        }
        // Restarts with each word, and on resume, so the first second is a full second.
        .task(id: ScrambleTimerRun(id: vm.timerID, isPaused: vm.isPaused)) {
            await vm.runTimer()
        }
        // The verse is ready for the clue, and for showing once the word is solved.
        .task(id: vm.currentWord?.id) {
            await vm.loadVerse()
        }
        .sheet(item: $selectedPassage) { reference in
            ScripturePassageSheet(reference: reference)
        }
        .gameGiveUpConfirmation(
            "Give up this word?",
            isPresented: $isRevealConfirmationPresented,
            message: "The word will be shown and marked incorrect. Then the next word begins.",
            action: vm.revealAnswer
        )
        // Double-tap checks a full answer, or goes on once the word is over; squeezing on a
        // square or tile moves letters, and anywhere else opens the menu.
        .gamePencilActions(
            isEnabled: vm.phase == .playing && !vm.isPaused,
            onDoubleTap: pencilDoubleTapAction,
            onSqueeze: handlePencilSqueeze
        ) {
            if vm.isCurrentWordResolved {
                if showsNextWordButton {
                    Button(vm.isLastWord ? "See Results" : "Next Word", systemImage: "arrow.right", action: vm.loadNextWord)
                }
            } else {
                Button("Check Answer", systemImage: "checkmark.circle", action: vm.checkAnswer)
                    .disabled(!vm.canCheckAnswer)
                Button("Undo", systemImage: "arrow.uturn.backward", action: vm.undo)
                    .disabled(!vm.canUndo)
                GameGiveUpButton { isRevealConfirmationPresented = true }
            }
        }
        .onAppear {
            vm.session.syncSavedBest(from: vm.persistentStreak)
        }
        .onChange(of: vm.difficulty) { _, _ in
            vm.session.syncSavedBest(from: vm.persistentStreak)
        }
        .onDisappear {
            vm.onDisappear()
        }
    }

    private func handleKeyboardPress(_ keyPress: KeyPress) -> KeyPress.Result {
        guard vm.phase == .playing,
              !vm.isPaused,
              !vm.isCurrentWordResolved,
              let currentWord = vm.currentWord else {
            return .ignored
        }

        if keyPress.key == .delete || keyPress.characters == "\u{8}" {
            vm.deleteBackward()
            return .handled
        }

        if keyPress.key == .leftArrow || keyPress.key == .rightArrow {
            vm.moveCursor(by: keyPress.key == .leftArrow ? -1 : 1)
            return .handled
        }

        if keyPress.key == .escape, vm.heldTile != nil {
            vm.cancelHold()
            return .handled
        }

        if keyPress.key == .return || keyPress.characters == "\r" || keyPress.characters == "\n" {
            guard vm.typedAnswer.count == currentWord.answer.count else { return .handled }
            vm.checkAnswer()
            return .handled
        }

        guard keyPress.modifiers.isEmpty,
              let character = keyPress.characters.first,
              character.isLetter,
              vm.selectLetter(matching: character) else {
            return .ignored
        }

        return .handled
    }

    private var startScreen: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 24)

            Text("Unscramble Bible names, places, books, and terms.")
                .gameStartDescriptionStyle(for: .scramble)

            GameSplashLaunchLayout(
                tint: .pink,
                experienceLevel: experienceLevel,
                experienceDetails: GameExperienceDetails(
                    learn: "Familiar words with 45 seconds per word.",
                    standard: "A broader word list with 30 seconds per word.",
                    challenge: "Tougher words with 30 seconds per word."
                ),
                isStartEnabled: vm.wordBankStatus == .ready,
                startAction: vm.startSession
            ) {
                GameLobbyPreview(kind: .scramble)
            } configuration: {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Tap letters to fill the squares, or drag them where they belong. Tap a placed letter to move it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if vm.wordBankStatus == .unavailable {
                        Label("The word list couldn’t be loaded. Close the game and try again.", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }

                    @Bindable var bindableVM = vm
                    GameSettingsGroup {
                        GameChoiceSetting(
                            title: "Session length",
                            systemImage: "number",
                            tint: .pink,
                            selection: $bindableVM.sessionLength,
                            choices: [
                                GameChoice(value: SessionLength.short, title: "5 words", icon: "5.circle"),
                                GameChoice(value: SessionLength.quick, title: "10 words", icon: "10.circle"),
                                GameChoice(value: SessionLength.extended, title: "20 words", icon: "20.circle")
                            ]
                        )
                        GameToggleSetting(
                            title: "Practice Mode",
                            detail: "No timer, so you can take your time with each word.",
                            systemImage: "timer",
                            tint: .pink,
                            isOn: $bindableVM.isPracticeMode
                        )
                    }
                }
            } facts: {
                GameSplashFacts(
                    first: ("number", "\(vm.sessionLength.rawValue) words", "This session"),
                    second: ("timer", vm.isPracticeMode ? "Untimed" : vm.difficulty.timerLabel, "Per word"),
                    third: ("lightbulb", vm.difficulty.hintLabel, "Available"),
                    fourth: vm.difficulty == .easy ? nil : ("xmark.shield", "3 strikes", "Limited attempts")
                )
            }

            Spacer(minLength: 24)
        }
    }

    private func gameScreen(usesSplitLayout: Bool) -> some View {
        VStack(spacing: usesSplitLayout ? 18 : 20) {
            GameScoreboardCard(
                currentCorrect: vm.session.score,
                currentAnswered: vm.session.answered,
                currentStreak: vm.session.streak,
                game: .scramble,
                style: horizontalSizeClass == .regular ? .dashboard : .compact
            )

            Text("Word \(vm.currentNumber) of \(vm.totalWords)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityLabel("Word \(vm.currentNumber) of \(vm.totalWords)")

            if let currentWord = vm.currentWord {
                ScramblePrompt(
                    category: currentWord.category,
                    categoryName: currentWord.categoryName,
                    reference: vm.difficulty == .easy || vm.isCurrentWordResolved ? currentWord.reference : nil,
                    isResolved: vm.isCurrentWordResolved,
                    verse: usesSplitLayout ? nil : vm.displayedVerse,
                    timerTint: vm.currentTimeLimit == nil || vm.isTimerDisabled ? nil : vm.timerTint,
                    onShowReference: showCurrentReference
                ) {
                    ScrambleAnswerTiles(
                        vm: vm,
                        layout: boardLayout,
                        isIncorrect: isIncorrectAnswer,
                        isCorrect: vm.answerFeedback == .correct,
                        onDrop: drop
                    )
                }

                if !usesSplitLayout, vm.currentTimeLimit != nil {
                    GameTimerCard(
                        remainingSeconds: vm.timeRemaining,
                        tint: vm.isTimerDisabled ? .secondary : vm.timerTint,
                        isPulsing: false,
                        formattedTime: vm.isTimerDisabled ? "Timer off" : nil,
                        isDisabled: vm.isTimerDisabled,
                        onTap: vm.toggleTimer
                    )
                }

                if let alternate = vm.acceptedAlternate, vm.answerFeedback == .correct {
                    // The reference above is still the puzzle's own word.
                    Label("\(alternate) works too! The word was \(currentWord.answer).", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                        .multilineTextAlignment(.center)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else if let answerFeedback = vm.answerFeedback {
                    Label(answerFeedback.message, systemImage: answerFeedback.systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(answerFeedback.tint)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                if vm.difficulty != .easy {
                    ScrambleStrikeIndicator(strikes: vm.strikes, limit: 3)
                }

                ScrambleLetterTray(vm: vm, layout: boardLayout, onDrop: drop)
                    .disabled(vm.isCurrentWordResolved)

                if vm.isCurrentWordResolved {
                    if !showsNextWordButton {
                        Label("Correct — take a moment to review.", systemImage: "book.closed.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                } else {
                    answerControls
                        .padding(.top, 12)
                }
            }
        }
        // Drags, tile frames and Pencil hover locations all share this coordinate space.
        .coordinateSpace(.named(ScrambleBoardLayout.coordinateSpace))
        .overlay {
            if let drag = boardLayout.drag {
                ScrambleFloatingTile(letter: drag.letter)
                    .position(drag.location)
            }
        }
        // Apple Pencil squeezes arrive in the game's space; this converts them to the board's.
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(GamePencil.coordinateSpace)) } action: {
            boardFrameInGame = $0
        }
        .frame(maxWidth: 620)
        .padding(.top, 8)
    }

    /// Finishes a drag: onto a square places or swaps the letter, onto the tray returns it.
    /// Anywhere else leaves it where it was.
    private func drop(_ source: ScrambleGameViewModel.TileSource, on target: ScrambleBoardLayout.Target?) {
        switch (source, target) {
        case (.tray(let tile), .square(let position)?):
            vm.placeTile(tile, at: position)
        case (.slot(let from), .square(let position)?):
            vm.moveLetter(from: from, to: position)
        case (.slot(let from), .tray?), (.slot(let from), .trayTile?):
            vm.returnToTray(from)
        default:
            break
        }
    }

    /// Double-tap: check a full answer, or go on once the word is over. Never a hint.
    private var pencilDoubleTapAction: (() -> Void)? {
        if vm.isCurrentWordResolved {
            guard showsNextWordButton else { return nil }
            return { vm.loadNextWord() }
        }
        guard vm.canCheckAnswer else { return nil }
        return { vm.checkAnswer() }
    }

    /// Squeezing over a square or tile moves letters, as tapping does. Returns `false` (so the
    /// Pencil menu opens) anywhere else, or once the word is over.
    private func handlePencilSqueeze(at point: CGPoint?) -> Bool {
        guard !vm.isCurrentWordResolved else { return false }
        let target = point.flatMap { point in
            boardLayout.target(at: CGPoint(x: point.x - boardFrameInGame.minX, y: point.y - boardFrameInGame.minY))
        }

        if vm.heldTile != nil {
            switch target {
            case .square(let position)?: vm.dropHeldTile(on: position)
            case .tray?, .trayTile?: vm.returnHeldTileToTray()
            case nil: vm.cancelHold()
            }
            return true
        }

        switch target {
        case .square(let position)?:
            // Picks up a placed letter, or makes an empty square the next one to fill.
            vm.tapSquare(position)
            return true
        case .trayTile(let index)?:
            vm.pickUp(.tray(index))
            return true
        case .tray?, nil:
            return false
        }
    }

    /// Once the word is over. A correct answer first waits a moment so the verse can be read.
    private var showsNextWordButton: Bool {
        vm.phase == .playing && vm.isCurrentWordResolved
            && (vm.answerFeedback != .correct || vm.isNextWordReady)
    }

    private var nextWordButton: some View {
        Button(
            vm.isLastWord ? "See Results" : "Next Word",
            systemImage: vm.isLastWord ? "flag.checkered" : "arrow.right"
        ) {
            vm.loadNextWord()
        }
        .buttonStyle(GameProminentButtonStyle(tint: .pink))
    }

    /// Secondary editing controls and a deliberately prominent primary action.
    private var answerControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                ScrambleActionButton(
                    systemImage: "arrow.uturn.backward",
                    accessibilityLabel: "Undo",
                    isEnabled: vm.canUndo,
                    isProminent: true,
                    action: vm.undo
                )
                ScrambleActionButton(
                    systemImage: "shuffle",
                    accessibilityLabel: "Shuffle available letters",
                    isEnabled: vm.shuffledLetters.count - vm.usedTileIndices.count >= 2,
                    action: vm.shuffleUnusedLetters
                )
                ScrambleActionButton(
                    systemImage: "lightbulb.fill",
                    accessibilityLabel: vm.hintLevel == 0 ? "Show hint" : "Show another hint",
                    isEnabled: vm.hintLevel < vm.maxHintLevel,
                    tint: .yellow,
                    badgeText: vm.hintBadgeText,
                    action: vm.showHint
                )
                ScrambleActionButton(
                    systemImage: "text.quote",
                    accessibilityLabel: "Show verse clue",
                    isEnabled: vm.canShowVerseClue,
                    tint: .teal,
                    action: { withAnimation(.snappy) { vm.showVerseClue() } }
                )
                ScrambleActionButton(
                    systemImage: "trash",
                    accessibilityLabel: "Clear answer",
                    isEnabled: vm.hasPlacedLetters,
                    action: vm.clearAnswer
                )
            }

            ScrambleCheckAnswerButton(
                isEnabled: vm.canCheckAnswer,
                requiresAnswerEdit: vm.requiresAnswerEdit,
                action: vm.checkAnswer
            )
        }
    }

    private var resultsScreen: some View {
        GameRoundSummaryView(
            summary: GameRoundSummary(score: vm.session),
            tint: .pink,
            unit: .words,
            canTimeOut: vm.currentTimeLimit != nil,
            resultNote: vm.hardModeResultNote,
            onPlayAgain: vm.startSession,
            onChangeSettings: vm.resetToSetup
        )
    }

    private func showCurrentReference() {
        guard let reference = vm.currentWord?.reference else { return }
        selectedPassage = PassageReferenceParser.firstPassage(in: reference)
    }

}

/// Identifies one run of the Scramble timer: a new word or a resume starts a new run.
private struct ScrambleTimerRun: Hashable {
    let id: UUID
    let isPaused: Bool
}
