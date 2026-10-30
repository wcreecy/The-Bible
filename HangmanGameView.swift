import SwiftUI
import UIKit

struct HangmanGameView: View {
    @State private var vm = HangmanGameViewModel()

    // Global Auto‑Win debug toggle
    private var debugAutoWinEnabled: Bool { DebugOptions.autoWinEnabled }

    // Smart link style preview state (mirror Wordle)
    @State private var showRefSheet: Bool = false
    @State private var selectedRef: ScriptureRef? = nil
    @State private var loadedPreview: (title: String, verses: [Verse])? = nil

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
                        #if canImport(UIKit)
                        HangmanKeyCapture(
                            onKey: { ch in
                                if !vm.roundOver {
                                    vm.guess(ch)
                                }
                            },
                            onBackspace: {},
                            onEnter: {
                                if vm.roundOver {
                                    vm.nextWord()
                                }
                            }
                        )
                        .frame(width: 0, height: 0)
                        .accessibilityHidden(true)
                        #endif

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
                        Spacer(minLength: 32)
                        HangmanResultsCard(
                            score: vm.session.score,
                            total: vm.totalWords,
                            bestStreak: vm.session.sessionBestStreak,
                            bestGameScore: vm.session.bestGameScore,
                            isNewBest: vm.session.isNewBestGame,
                            onPlayAgain: vm.startGame,
                            onChangeSettings: vm.resetToSetup
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
        }
        .tabBarContentClearance()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if vm.phase != .setup {
                    GameNavigationTitle(title: "Hangman", systemImage: "text.word.spacing", tint: .teal)
                }
            }
        }
        .task {
            await vm.loadData()
        }
        .onAppear {
            vm.onAppear()
        }
        .onDisappear {
            vm.onDisappear()
        }
        // The keyboard card is layout state; a finished round always brings it back for "Next Word".
        .onChange(of: vm.roundOver) { _, isOver in
            if isOver { showsOnScreenKeyboard = true }
        }
        .sheet(isPresented: $showRefSheet, onDismiss: {
            selectedRef = nil
            loadedPreview = nil
        }) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    if let preview = loadedPreview {
                        ScripturePreviewCard(
                            content: preview,
                            refContext: selectedRef,
                            onCopy: {
                                let verseLines = preview.verses.map { $0.text }.joined(separator: " ")
                                UIPasteboard.general.string = "\(preview.title) — \(verseLines)"
                            },
                            onClose: { showRefSheet = false }
                        )
                    } else {
                        ContentUnavailableView("No reference available", systemImage: "book")
                    }
                }
                .padding()
                .navigationTitle("Reference")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showRefSheet = false }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .task(id: selectedRef) {
                guard let sr = selectedRef else { return }
                loadedPreview = BibleReferenceLinker.loadVerses(for: sr)
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var startSection: some View {
        Spacer(minLength: 24)
        Text("Guess the person, place or book from the Bible")
            .gameStartDescriptionStyle(title: "Hangman", systemImage: "text.word.spacing", tint: .teal)

        GameSplashLaunchLayout(
            tint: .teal,
            experienceLevel: $vm.experienceLevel,
            experienceDetails: GameExperienceDetails(
                learn: "Well-known names, 8 mistakes, and a clue for every word.",
                standard: "More names, 6 mistakes; a clue costs one mistake.",
                challenge: "Every name, 5 mistakes, and no clues."
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
                second: ("xmark.octagon", "\(vm.difficulty.maxWrong)", String(localized: "Mistakes allowed")),
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
                Text(vm.spacedDisplayWord)
                    .font(.title.weight(.semibold).monospaced())
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Word to guess")
                    .accessibilityValue(vm.spokenDisplayWord)

                Text("Mistakes: \(vm.wrongGuesses)/\(vm.maxWrong)")
                    .font(.subheadline)
                    .foregroundStyle(vm.wrongGuesses >= vm.maxWrong - 1 ? .red : .secondary)

                if vm.roundOver, let current = vm.current {
                    HangmanRevealCard(
                        didWin: vm.didWin,
                        answer: current.answer,
                        qualifier: current.qualifier,
                        clue: current.clue,
                        reference: current.reference,
                        onShowReference: presentReferencePreview
                    )
                } else {
                    clueRow
                }
            }
        } drawing: {
            VStack(spacing: 18) {
                if !usesWideLayout && !showsOnScreenKeyboard {
                    alphabetStatusTray
                }

                HangmanDrawing(
                    progress: Double(vm.wrongGuesses) / Double(max(1, vm.maxWrong)),
                    maximumCharacterHeight: drawingMaximumCharacterHeight(
                        usesWideLayout: usesWideLayout
                    )
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
            if vm.roundOver {
                Group {
                    if vm.isLastWord {
                        Button("See Results", systemImage: "flag.checkered", action: vm.nextWord)
                            .buttonStyle(GameProminentButtonStyle(tint: .teal))
                    } else {
                        Button("Next Word", systemImage: "arrow.right", action: vm.nextWord)
                            .buttonStyle(GameProminentButtonStyle(tint: .accentColor))
                    }
                }
                .padding(.horizontal, 6)
                .padding(.top, 8)
            } else {
                keyboardView(keyHeight: usesWideLayout ? 60 : 42)
                    .padding(.horizontal, 6)
                    .padding(.top, 8)
            }
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

    private var playedLettersTray: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Played Letters")
                .font(.headline)

            if vm.guessedLetters.isEmpty {
                Text("No letters played yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 36), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(vm.guessedLetters.sorted(), id: \.self) { letter in
                        Text(String(letter))
                            .font(.headline.monospaced())
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                vm.correctLetters.contains(letter) ? Color.green : Color.red,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                            .accessibilityLabel(
                                vm.correctLetters.contains(letter)
                                    ? "\(String(letter)), correct"
                                    : "\(String(letter)), incorrect"
                            )
                    }
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
        guard UIDevice.current.userInterfaceIdiom != .pad else { return 130 }

        if keyboardIsVisible {
            // Leave room for the word, clue, and keyboard on shorter iPhones.
            return min(150, max(128, availableHeight * 0.20))
        }

        return min(360, max(260, availableHeight * 0.44))
    }

    // MARK: - References

    private func presentReferencePreview(from refString: String) {
        selectedRef = HangmanGameViewModel.scriptureRef(from: refString)
        loadedPreview = nil
        showRefSheet = true
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
            onGuess: vm.guess
        )
    }
}
