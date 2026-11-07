import SwiftUI

struct ScrambleGameView: View {
    @State private var timerOnLeft = false
    @State private var usesMutedTimerStyle = false
    @State private var selectedPassage: PassageReference?
    @State private var isRevealConfirmationPresented = false
    @State private var vm: ScrambleGameViewModel

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
                    GameNavigationTitle(
                        title: "Scramble",
                        systemImage: "text.line.first.and.arrowtriangle.forward",
                        tint: .pink
                    )
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if vm.canPause {
                    GamePauseButton { vm.isPaused = true }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if vm.phase == .playing, !vm.isCurrentWordResolved {
                    Menu {
                        Button(role: .destructive) {
                            isRevealConfirmationPresented = true
                        } label: {
                            Label("Reveal Answer", systemImage: "eye")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Scramble options")
                    .accessibilityHint("Includes an option to reveal the answer")
                }
            }
        }
        // A call, another app, or locking the phone pauses the word until Resume.
        .onAppActiveChange { isActive in
            if !isActive, vm.canPause { vm.isPaused = true }
        }
        .task {
            await vm.loadWordBank()
        }
        // Restarts with each word, and on resume, so the first second is a full second.
        .task(id: ScrambleTimerRun(id: vm.timerID, isPaused: vm.isPaused)) {
            await vm.runTimer()
        }
        .sheet(item: $selectedPassage) { reference in
            ScripturePassageSheet(reference: reference)
        }
        .confirmationDialog("Reveal answer?", isPresented: $isRevealConfirmationPresented, titleVisibility: .visible) {
            Button("Reveal & Next", role: .destructive) {
                vm.revealAnswer()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The word will be marked incorrect, then the next word will begin.")
        }
        .onAppear {
            vm.session.syncSavedBest(from: vm.persistentStreak)
        }
        .onChange(of: vm.difficulty) { _, _ in
            vm.session.syncSavedBest(from: vm.persistentStreak)
        }
        .onDisappear {
            if vm.phase != .setup {
                vm.resetToSetup()
            }
            vm.session.clearStreak()
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
            vm.removeLastLetter()
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
                .gameStartDescriptionStyle(
                    title: "Scramble",
                    systemImage: "text.line.first.and.arrowtriangle.forward",
                    tint: .pink
                )

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
                    Text("Build each answer from the scrambled letter tiles.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if vm.wordBankStatus == .unavailable {
                        Label("The word list couldn’t be loaded. Close the game and try again.", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }

                    Picker("Session length", selection: $vm.sessionLength) {
                        ForEach(SessionLength.allCases) { length in
                            Text(length.title).tag(length)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            } facts: {
                GameSplashFacts(
                    first: ("number", "\(vm.sessionLength.rawValue) words", "This session"),
                    second: ("timer", vm.difficulty.timerLabel, "Per word"),
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
                    answer: vm.typedAnswer,
                    answerLength: currentWord.answer.count,
                    hintedLetters: vm.hintedLetters,
                    isResolved: vm.isCurrentWordResolved,
                    isIncorrect: isIncorrectAnswer,
                    isCorrect: vm.answerFeedback == .correct,
                    timerTint: vm.currentTimeLimit == nil || vm.isTimerDisabled ? nil : vm.timerTint,
                    onRemoveLetters: vm.removeLetters,
                    onShowReference: showCurrentReference
                )

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

                if let answerFeedback = vm.answerFeedback {
                    Label(answerFeedback.message, systemImage: answerFeedback.systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(answerFeedback.tint)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                if vm.difficulty != .easy {
                    ScrambleStrikeIndicator(strikes: vm.strikes, limit: 3)
                }

                ScrambleLetterTray(
                    letters: vm.shuffledLetters,
                    selectedIndices: vm.selectedIndices,
                    onSelect: vm.selectLetter
                )
                .disabled(vm.isCurrentWordResolved)

                if vm.isCurrentWordResolved {
                    nextWordButton
                } else {
                    answerControls
                        .padding(.top, 12)
                }
            }
        }
        .frame(maxWidth: 620)
        .padding(.top, 8)
    }

    private var nextWordButton: some View {
        Button(
            vm.isLastWord ? "See Results" : "Next Word",
            systemImage: vm.isLastWord ? "flag.checkered" : "arrow.right"
        ) {
            vm.loadNextWord()
        }
        .buttonStyle(.borderedProminent)
        .tint(.pink)
    }

    /// Secondary editing controls and a deliberately prominent primary action.
    private var answerControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                ScrambleActionButton(
                    systemImage: "delete.left",
                    accessibilityLabel: "Remove last letter",
                    isEnabled: !vm.typedAnswer.isEmpty,
                    isProminent: true,
                    action: vm.removeLastLetter
                )
                ScrambleActionButton(
                    systemImage: "shuffle",
                    accessibilityLabel: "Shuffle available letters",
                    isEnabled: vm.shuffledLetters.count - vm.selectedIndices.count >= 2,
                    action: vm.shuffleUnusedLetters
                )
                ScrambleActionButton(
                    systemImage: "lightbulb.fill",
                    accessibilityLabel: vm.hintLevel == 0 ? "Show hint" : "Show another hint",
                    isEnabled: vm.hintLevel < vm.maxHintLevel,
                    tint: .yellow,
                    action: vm.showHint
                )
                ScrambleActionButton(
                    systemImage: "trash",
                    accessibilityLabel: "Clear answer",
                    isEnabled: !vm.typedAnswer.isEmpty,
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
            onPlayAgain: vm.startSession,
            onChangeSettings: vm.resetToSetup
        )
    }

    private func showCurrentReference() {
        guard let reference = vm.currentWord?.reference else { return }
        selectedPassage = PassageReferenceParser.parse(reference)
    }

}

/// Identifies one run of the Scramble timer: a new word or a resume starts a new run.
private struct ScrambleTimerRun: Hashable {
    let id: UUID
    let isPaused: Bool
}
