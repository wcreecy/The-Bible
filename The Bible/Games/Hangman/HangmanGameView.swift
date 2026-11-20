import SwiftUI

struct HangmanGameView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.preferredPencilDoubleTapAction) private var preferredPencilDoubleTapAction
    @Environment(\.preferredPencilSqueezeAction) private var preferredPencilSqueezeAction
    @State private var vm: HangmanGameViewModel
    private let isReviewRound: Bool
    @State private var isGiveUpConfirmationPresented = false
    @State private var showsPencilActions = false
    /// Set when a letter is guessed twice; a new value restarts the message's timer.
    @State private var repeatedGuessMessageID: UUID?
    @State private var selectedPassage: PassageReference?
    @FocusState private var isKeyboardFocused: Bool

    init(reviewQuestionIDs: Set<String> = []) {
        isReviewRound = !reviewQuestionIDs.isEmpty
        _vm = State(initialValue: HangmanGameViewModel(reviewQuestionIDs: reviewQuestionIDs))
    }

    // Global Auto‑Win debug toggle
    private var debugAutoWinEnabled: Bool { DebugOptions.autoWinEnabled }

    // Keyboard layout toggle: false = QWERTY, true = A-Z
    @State private var useAlphabeticalLayout: Bool = false
    @State private var showsOnScreenKeyboard: Bool = true
    @State private var showsHangmanCardFirst: Bool = false

    var body: some View {
        GeometryReader { geometry in
            let usesWideLayout = vm.phase == .playing && geometry.size.width >= 900

            ScrollView {
                VStack(spacing: 12) {
                    switch vm.phase {
                    case .setup:
                        startSection
                    case .playing:
                        inGameSection(
                            usesWideLayout: usesWideLayout,
                            availableHeight: geometry.size.height - 24
                        )

                        if debugAutoWinEnabled, !vm.roundOver {
                            Button("WIN", action: vm.debugWin)
                                .buttonStyle(ModernPillButtonStyle(tint: .red))
                                .controlSize(.large)
                                .padding(.top, 6)
                                .accessibilityLabel("Win this round")
                        }
                    case .results:
                        GameRoundSummaryView(
                            summary: GameRoundSummary(score: vm.session),
                            tint: .teal,
                            unit: .words,
                            canTimeOut: false,
                            onPlayAgain: vm.startGame,
                            onChangeSettings: vm.resetToSetup
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            // A hardware keyboard types guesses, and Return goes to the next word.
            .focusable()
            .focused($isKeyboardFocused)
            .onKeyPress(phases: .down, action: handleKeyPress)
            .onChange(of: vm.phase) { _, phase in
                isKeyboardFocused = phase == .playing
            }
        }
        .tabBarContentClearance()
        // Pinned above the tab bar, so the answer, clue and verse never push it out of reach.
        .pinnedGameActionButton(isShown: vm.phase == .playing && vm.roundOver) {
            nextWordButton
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if vm.phase != .setup {
                    GameNavigationTitle(title: "Hangman", systemImage: "text.word.spacing", tint: .teal)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if vm.phase == .playing, !vm.roundOver {
                    Menu {
                        Button(role: .destructive) {
                            isGiveUpConfirmationPresented = true
                        } label: {
                            Label("Give Up", systemImage: "flag.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Hangman options")
                }
            }
        }
        .confirmationDialog("Give up this word?", isPresented: $isGiveUpConfirmationPresented, titleVisibility: .visible) {
            Button("Give Up", role: .destructive, action: vm.giveUp)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The word will be marked incorrect and you can continue to the next word.")
        }
        .task {
            await vm.loadData()
        }
        // The verse is ready for the clue (or the Verses prompt), and for showing after the round.
        .task(id: vm.current?.answer) {
            await vm.loadVerse()
        }
        .task(id: repeatedGuessMessageID) {
            guard repeatedGuessMessageID != nil else { return }
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            repeatedGuessMessageID = nil
        }
        .onAppear {
            vm.onAppear()
        }
        .onDisappear {
            vm.onDisappear()
        }
        .sheet(item: $selectedPassage) { reference in
            ScripturePassageSheet(reference: reference)
        }
        .onPencilDoubleTap { _ in
            guard preferredPencilDoubleTapAction != .ignore, vm.phase == .playing else { return }
            if vm.roundOver {
                vm.nextWord()
            } else if vm.canRevealClue {
                vm.revealClue()
            }
        }
        .onPencilSqueeze { phase in
            guard preferredPencilSqueezeAction != .ignore, vm.phase == .playing,
                  case .ended = phase else { return }
            showsPencilActions = true
        }
        .confirmationDialog("Apple Pencil Actions", isPresented: $showsPencilActions, titleVisibility: .visible) {
            if vm.roundOver {
                Button(vm.isLastWord ? "See Results" : "Next Word", systemImage: "arrow.right", action: vm.nextWord)
            } else {
                if vm.canRevealClue {
                    Button("Show Clue", systemImage: "lightbulb", action: vm.revealClue)
                }
                if vm.canRevealLetter {
                    Button("Reveal a Letter", systemImage: "character.textbox", action: vm.revealLetter)
                }
                if vm.canShowVerseClue {
                    Button("Show Verse Clue", systemImage: "text.quote", action: vm.showVerseClue)
                }
                Button("Give Up", systemImage: "flag.fill", role: .destructive) {
                    isGiveUpConfirmationPresented = true
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        guard vm.phase == .playing else { return .ignored }

        if keyPress.key == .return || keyPress.characters == "\r" || keyPress.characters == "\n" {
            guard vm.roundOver else { return .ignored }
            vm.nextWord()
            return .handled
        }

        guard !vm.roundOver,
              keyPress.modifiers.isEmpty,
              let character = keyPress.characters.first,
              character.isLetter else {
            return .ignored
        }
        handleGuess(character)
        return .handled
    }

    private func handleGuess(_ letter: Character) {
        if vm.guess(letter) == .alreadyGuessed {
            repeatedGuessMessageID = UUID()
        }
    }

    private var nextWordButton: some View {
        Group {
            if vm.isLastWord {
                Button("See Results", systemImage: "flag.checkered", action: vm.nextWord)
                    .buttonStyle(GameProminentButtonStyle(tint: .teal))
            } else {
                Button("Next Word", systemImage: "arrow.right", action: vm.nextWord)
                    .buttonStyle(GameProminentButtonStyle(tint: .accentColor))
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var startSection: some View {
        Spacer(minLength: 24)
        Text("Guess the person, place, word, or book from the Bible")
            .gameStartDescriptionStyle(title: "Hangman", systemImage: "text.word.spacing", tint: .teal)

        GameSplashLaunchLayout(
            tint: .teal,
            experienceLevel: $vm.experienceLevel,
            experienceDetails: GameExperienceDetails(
                learn: "Well-known answers, 8 mistakes, and a clue for every word.",
                standard: "More answers, 6 mistakes; clues and letter hints cost one mistake.",
                challenge: "Every answer, 5 mistakes, and only a verse clue, which costs two."
            ),
            isStartEnabled: vm.isDataLoaded,
            startAction: vm.startGame
        ) {
            GameLobbyPreview(kind: .hangman)
        } configuration: {
            HangmanSetupControls(theme: $vm.theme)
        } facts: {
            GameSplashFacts(
                first: ("number", "\(HangmanGameViewModel.wordsPerGame) words", String(localized: "This session")),
                second: ("xmark.octagon", vm.difficulty.maxWrong.formatted(), String(localized: "Mistakes allowed")),
                third: ("lightbulb", vm.difficulty.clueSummary, String(localized: "Clue"))
            )
        }
        Spacer(minLength: 24)
    }

    private func inGameSection(usesWideLayout: Bool, availableHeight: CGFloat) -> some View {
        HangmanResponsiveLayout(
            usesWideLayout: usesWideLayout,
            availableHeight: availableHeight,
            showsKeyboardCard: showsOnScreenKeyboard,
            allowsKeyboardVisibilityToggle: !vm.roundOver,
            showsHangmanCardFirst: showsHangmanCardFirst,
            toggleKeyboardCard: { showsOnScreenKeyboard.toggle() },
            swapCards: { showsHangmanCardFirst.toggle() }
        ) {
            roundHeader
                .padding(.horizontal, 4)
        } word: {
            VStack(spacing: 12) {
                HangmanWordTiles(
                    letters: vm.displayLetters,
                    spokenWord: vm.spokenDisplayWord,
                    lastCorrectGuess: vm.lastCorrectGuess,
                    didWin: vm.roundOver && vm.didWin
                )

                // One count, in the lobby's terms ("Mistakes allowed"), rather than a
                // mistakes tally beside a separate guesses-left line.
                Text(vm.isOneGuessRemaining ? "1 mistake left" : "\(vm.maxWrong - vm.wrongGuesses) mistakes left")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(vm.isOneGuessRemaining ? .red : .secondary)

                if repeatedGuessMessageID != nil {
                    Label("Already guessed", systemImage: "arrow.uturn.backward.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if vm.roundOver, let current = vm.current {
                    HangmanRevealCard(
                        didWin: vm.didWin,
                        answer: current.answer,
                        qualifier: current.qualifier,
                        clue: current.clue,
                        reference: vm.verse?.reference ?? current.reference,
                        guessesLeft: vm.maxWrong - vm.wrongGuesses,
                        onShowReference: presentReferencePreview
                    )
                } else {
                    clueRow
                }

                if let verse = vm.displayedVerse {
                    GameVerseCard(verse: verse)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                } else if vm.isVersePrompt, !vm.isVerseLoaded {
                    ProgressView("Finding the verse…")
                        .font(.subheadline)
                }

                if !vm.roundOver {
                    hintButtons
                }
            }
            .animation(.snappy, value: vm.displayedVerse)
        } drawing: {
            VStack(spacing: 18) {
                if !usesWideLayout && !showsOnScreenKeyboard {
                    alphabetStatusTray
                }

                HangmanDrawing(
                    progress: Double(vm.wrongGuesses) / Double(max(1, vm.maxWrong)),
                    maximumCharacterHeight: drawingMaximumCharacterHeight(
                        usesWideLayout: usesWideLayout
                    ),
                    isFinalMistake: vm.isOneGuessRemaining,
                    celebratesWin: vm.roundOver && vm.didWin
                )
                .frame(
                    height: usesWideLayout
                        ? (showsOnScreenKeyboard
                            ? 280
                            : min(440, max(340, availableHeight * 0.48)))
                        : compactDrawingHeight(
                            availableHeight: availableHeight,
                            keyboardIsVisible: showsOnScreenKeyboard
                        )
                )
                .padding(.horizontal, 12)

                if usesWideLayout && !showsOnScreenKeyboard {
                    playedLettersTray
                }
            }
        } scoreboard: {
            GameScoreboardCard(
                currentCorrect: vm.session.score,
                currentAnswered: vm.session.answered,
                currentStreak: vm.session.streak,
                game: .hangman,
                style: usesWideLayout ? .dashboard : .compact
            )
        } keyboard: {
            // Next Word is pinned above the tab bar; the played keyboard stays for reference.
            keyboardView(keyHeight: usesWideLayout ? 60 : 42)
                .padding(.horizontal, 6)
                .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var clueRow: some View {
        if let current = vm.current, !current.clue.isEmpty {
            if vm.showsClue {
                Label(current.clue, systemImage: "lightbulb.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else if vm.difficulty == .normal {
                Button("Show clue (costs 1 mistake)", systemImage: "lightbulb", action: vm.revealClue)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.borderless)
                    .disabled(!vm.canRevealClue)
            }
        }
    }

    /// A letter hint and the verse clue, each with what it costs.
    @ViewBuilder
    private var hintButtons: some View {
        let showsLetterHint = vm.difficulty.allowsLetterHints
        // A verse clue is only offered once a verse naming the answer has been found.
        let showsVerseClue = !vm.isVersePrompt && !vm.isVerseClueShown && vm.verse != nil

        if showsLetterHint || showsVerseClue {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { hintButtonContent(showsLetterHint: showsLetterHint, showsVerseClue: showsVerseClue) }
                VStack(spacing: 8) { hintButtonContent(showsLetterHint: showsLetterHint, showsVerseClue: showsVerseClue) }
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder
    private func hintButtonContent(showsLetterHint: Bool, showsVerseClue: Bool) -> some View {
        if showsLetterHint {
            Button("Reveal a letter (costs 1 mistake)", systemImage: "character.textbox", action: vm.revealLetter)
                .disabled(!vm.canRevealLetter)
        }
        if showsVerseClue {
            Button(verseClueTitle, systemImage: "text.quote") {
                withAnimation(.snappy) { vm.showVerseClue() }
            }
            .disabled(!vm.canShowVerseClue)
        }
    }

    private var verseClueTitle: LocalizedStringKey {
        switch vm.difficulty.verseClueCost {
        case 0: "Show verse clue"
        case 1: "Verse clue (costs 1 mistake)"
        default: "Verse clue (costs \(vm.difficulty.verseClueCost) mistakes)"
        }
    }

    /// Every letter on iPad when the keyboard is hidden: played ones in green or red, the rest dimmed.
    private var playedLettersTray: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Letters")
                .font(.headline)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 36), spacing: 8)],
                spacing: 8
            ) {
                ForEach(Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ"), id: \.self) { letter in
                    let isCorrect = vm.correctLetters.contains(letter)
                    let isIncorrect = vm.wrongLetters.contains(letter)

                    Text(String(letter))
                        .font(.headline.monospaced())
                        .foregroundStyle(isCorrect || isIncorrect ? Color.white : Color.secondary)
                        .frame(width: 36, height: 36)
                        .background(
                            letterStatusColor(isCorrect: isCorrect, isIncorrect: isIncorrect),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                        .accessibilityLabel(letterStatusAccessibilityLabel(
                            letter,
                            isCorrect: isCorrect,
                            isIncorrect: isIncorrect
                        ))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var roundHeader: some View {
        let category = vm.current?.category ?? .all
        HStack(spacing: 8) {
            Label {
                Text(category.title)
                    .textCase(.uppercase)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            } icon: {
                Image(systemName: category.systemImage)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.18), in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.orange.opacity(0.45), lineWidth: 1)
            )
            .foregroundStyle(.orange)

            Spacer(minLength: 6)

            Text("Word \(vm.wordNumber) of \(vm.totalWords)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private var alphabetStatusTray: some View {
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 9),
            spacing: 4
        ) {
            ForEach(letters, id: \.self) { letter in
                let isCorrect = vm.correctLetters.contains(letter)
                let isIncorrect = vm.wrongLetters.contains(letter)

                Text(String(letter))
                    .font(.caption2.weight(.bold).monospaced())
                    .foregroundStyle(
                        isCorrect || isIncorrect ? .white : Color.secondary
                    )
                    .frame(maxWidth: .infinity, minHeight: 28)
                    .background(letterStatusColor(
                        isCorrect: isCorrect,
                        isIncorrect: isIncorrect
                    ), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .accessibilityLabel(letterStatusAccessibilityLabel(
                        letter,
                        isCorrect: isCorrect,
                        isIncorrect: isIncorrect
                    ))
            }
        }
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func letterStatusColor(isCorrect: Bool, isIncorrect: Bool) -> Color {
        if isCorrect { return .green }
        if isIncorrect { return .red }
        return .secondary.opacity(0.12)
    }

    private func letterStatusAccessibilityLabel(
        _ letter: Character,
        isCorrect: Bool,
        isIncorrect: Bool
    ) -> String {
        if isCorrect { return "\(letter), correct" }
        if isIncorrect { return "\(letter), incorrect" }
        return "\(letter), not guessed"
    }

    private func drawingMaximumCharacterHeight(usesWideLayout: Bool) -> CGFloat {
        if usesWideLayout && !showsOnScreenKeyboard { return 520 }
        if !usesWideLayout && !showsOnScreenKeyboard { return 400 }
        return 310
    }

    private func compactDrawingHeight(
        availableHeight: CGFloat,
        keyboardIsVisible: Bool
    ) -> CGFloat {
        // A regular-width window (iPad, not a narrow Split View) has room for a larger layout.
        guard horizontalSizeClass != .regular else { return 130 }

        if keyboardIsVisible {
            // Leave room for the word, clue, and keyboard on shorter iPhones.
            return min(150, max(128, availableHeight * 0.20))
        }

        return min(360, max(260, availableHeight * 0.44))
    }

    // MARK: - References

    private func presentReferencePreview(from reference: String) {
        selectedPassage = PassageReferenceParser.parse(reference)
    }

    // MARK: - On-screen keyboard

    private func keyboardView(keyHeight: CGFloat) -> some View {
        HangmanKeyboardView(
            usesAlphabeticalLayout: $useAlphabeticalLayout,
            guessedLetters: vm.guessedLetters,
            correctLetters: vm.correctLetters,
            wrongLetters: vm.wrongLetters,
            isRoundOver: vm.roundOver,
            keyHeight: keyHeight,
            onGuess: handleGuess
        )
    }
}
