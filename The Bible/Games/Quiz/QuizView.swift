import SwiftUI
import SwiftData

struct QuizView: View {
    @Query private var favorites: [Favorite]
    @State private var vm: QuizGameViewModel
    @FocusState private var isKeyboardFocused: Bool

    init(reviewQuestionIDs: Set<String> = [], mode: QuizMode = .standard) {
        _vm = State(initialValue: QuizGameViewModel(reviewQuestionIDs: reviewQuestionIDs, mode: mode))
    }

    #if DEBUG
    /// Lets previews open straight into a round.
    fileprivate init(viewModel: QuizGameViewModel) {
        _vm = State(initialValue: viewModel)
    }
    #endif

    // Global Auto‑Win debug toggle
    private var debugAutoWinEnabled: Bool { DebugOptions.autoWinEnabled }

    // Layout-only state for the split dashboard
    @State private var timerOnLeft: Bool = false
    @State private var usesMutedTimerStyle: Bool = false
    @State private var verseToast = VerseActionToastState()

    var body: some View {
        GeometryReader { geometry in
            // Both modes use the split layout on a wide screen.
            let usesSplitLayout = vm.phase == .playing && geometry.size.width >= 700

            ZStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            switch vm.phase {
                            case .setup:
                                setupContent
                            case .playing:
                                if vm.isPaused {
                                    GamePausedView(tint: .blue, remainingSeconds: vm.remainingSeconds) {
                                        vm.resume()
                                    }
                                } else if usesSplitLayout {
                                    dashboard(availableHeight: geometry.size.height - 32)
                                } else {
                                    compactGameContent
                                }
                            case .results:
                                GameRoundSummaryView(
                                    summary: GameRoundSummary(score: vm.session),
                                    tint: .blue,
                                    canTimeOut: vm.isTimed,
                                    points: vm.roundPoints,
                                    extraAction: vm.bookToPractice.map { book in
                                        GameRoundSummaryView.ExtraAction(
                                            title: String(localized: "Practice \(book)"),
                                            systemImage: "book.pages",
                                            action: { vm.practice(book: book) }
                                        )
                                    },
                                    onPlayAgain: vm.startQuiz,
                                    onChangeSettings: vm.resetToSetup
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .tabBarContentClearance()
                    .pinnedNextQuestionButton(
                        isShown: vm.phase == .playing && !vm.isPaused && vm.isAnswered,
                        isLastQuestion: vm.isOnLastQuestion,
                        tint: .blue,
                        action: vm.showNext
                    )
                    // Once answered, keep the result, bonus and summary in view above the pinned
                    // Next button: when the content grows and when the button's inset arrives.
                    .onScrollGeometryChange(for: CGFloat.self) { geometry in
                        geometry.contentSize.height + geometry.contentInsets.bottom
                    } action: { _, _ in
                        guard vm.phase == .playing, vm.isAnswered else { return }
                        withAnimation(.snappy) {
                            proxy.scrollTo(QuizAfterAnswer.scrollID, anchor: .bottom)
                        }
                    }
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
                    QuizLargeTimerView(
                        remainingSeconds: vm.remainingSeconds,
                        tint: vm.timerColor,
                        isPulsing: vm.isPulsing,
                        isTimed: vm.isTimed,
                        isTimerDisabled: vm.isTimerDisabled,
                        outcome: vm.current?.outcome,
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
            // A hardware keyboard answers with 1–4 or A–D (and picks the bonus chapter), and
            // Return goes on.
            .focusable()
            .focused($isKeyboardFocused)
            .onKeyPress(phases: .down, action: handleKeyPress)
            .onChange(of: vm.phase) { _, phase in
                isKeyboardFocused = phase == .playing
            }
        }
        .background(AppBackgroundView(tab: .games))
        .verseActionToast($verseToast)
        // Restarts with each question so the first second is a full second.
        .task(id: vm.timerID) {
            await vm.runTimer()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if vm.phase != .setup {
                    GameNavigationTitle(.quiz)
                }
            }
        }
        .gamePauseControls(canPause: vm.canPause, pause: vm.pause)
        // Double-tap goes on once the question is answered; squeezing on an answer chooses it.
        .gamePencilActions(
            isEnabled: vm.phase == .playing,
            handlesSqueeze: false,
            onDoubleTap: vm.isAnswered ? { vm.showNext() } : nil
        ) {
            if vm.isAnswered {
                Button(vm.isOnLastQuestion ? "See Results" : "Next Question", systemImage: "arrow.right", action: vm.showNext)
            } else {
                ForEach(QuizLifeline.allCases, id: \.self) { lifeline in
                    if vm.canUse(lifeline) {
                        Button(lifeline.title, systemImage: lifeline.systemImage) {
                            vm.use(lifeline)
                        }
                    }
                }
                if vm.canRevealContext {
                    Button("Show Previous Verse", systemImage: "text.alignleft", action: vm.revealContext)
                }
            }
        }
        .onChange(of: favoriteVerses, initial: true) { _, verses in
            vm.favoriteVerses = verses
        }
        .onAppear {
            vm.onAppear()
        }
        .task {
            await vm.prepareFilter()
        }
        .onDisappear {
            vm.onDisappear()
        }
    }

    private var favoriteVerses: [QuizVerse] {
        favorites.map {
            QuizVerse(bookName: $0.bookName, chapterNumber: $0.chapterNumber,
                      verseNumber: $0.verseNumber, verseText: $0.verseText)
        }
    }

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        guard vm.phase == .playing, !vm.isPaused, let current = vm.current else { return .ignored }

        if keyPress.key == .return || keyPress.characters == "\r" || keyPress.characters == "\n" {
            guard vm.isAnswered else { return .ignored }
            vm.showNext()
            return .handled
        }

        guard keyPress.modifiers.isEmpty, let index = GameAnswerLetter.index(forKey: keyPress.characters) else {
            return .ignored
        }
        if vm.isChapterBonusOpen, current.chapterOptions.indices.contains(index) {
            vm.guessChapter(current.chapterOptions[index])
            return .handled
        }
        guard !vm.isAnswered, current.options.indices.contains(index) else { return .ignored }
        vm.selectOption(current.options[index])
        return .handled
    }

    // MARK: - Setup

    @ViewBuilder
    private var setupContent: some View {
        Text(vm.mode == .reverse ? "Choose the verse text that matches the reference." : "Test your knowledge by guessing the book of the Bible from a given verse.")
            .gameStartDescriptionStyle(for: .quiz)

        GameSplashLaunchLayout(
            tint: .blue,
            experienceLevel: $vm.experienceLevel,
            experienceDetails: GameExperienceDetails(
                learn: "Untimed practice at your own pace. No bonus points.",
                standard: vm.mode == .reverse
                    ? "20 seconds. Choices from your categories. +1 bonus point for answering in the first third of the time."
                    : "15 seconds for each verse. +1 bonus point for answering in the first 5 seconds, and +1 for naming the right chapter.",
                challenge: vm.mode == .reverse
                    ? "30 seconds. Choices from the same book. +1 bonus point for answering in the first third of the time."
                    : "12 seconds for each verse. +1 bonus point for answering in the first 4 seconds, and +1 for naming the right chapter."
            ),
            experienceTitle: vm.reviewQuestionIDs.isEmpty ? "How you’ll play" : "Timer",
            isConfigurationEnabled: vm.reviewQuestionIDs.isEmpty,
            isStartEnabled: vm.canStart,
            startAction: vm.startQuiz
        ) {
            GameLobbyPreview(kind: vm.mode == .reverse ? .quizReverse : .quiz)
        } configuration: {
            VStack(alignment: .leading, spacing: 8) {
                GameSettingsGroup {
                    GameChoiceSetting(
                        title: "Mode",
                        systemImage: "arrow.left.arrow.right",
                        tint: .blue,
                        selection: $vm.mode,
                        choices: [
                            GameChoice(value: QuizMode.standard, title: "Standard",
                                       detail: "Verse text → book", icon: "book.closed"),
                            GameChoice(value: QuizMode.reverse, title: "Reverse",
                                       detail: "Reference → verse text", icon: "text.quote")
                        ]
                    )

                    GameChoiceSetting(
                        title: "Verse pool",
                        systemImage: "text.quote",
                        tint: .blue,
                        selection: $vm.pool,
                        choices: QuizVersePool.allCases.map {
                            GameChoice(value: $0, title: $0.title,
                                       detail: $0 == .favorites && !vm.isFavoritesAvailable
                                           ? "Save a favorite verse to unlock this." : $0.detail,
                                       icon: $0.icon,
                                       isEnabled: $0 != .favorites || vm.isFavoritesAvailable)
                        }
                    )

                    QuizCategoryQuickPicks(tint: .blue, selection: $vm.selectedSections)

                    GameStartMultiPickerCard(
                        title: "Fine-tune Categories",
                        tint: .blue,
                        selection: $vm.selectedSections,
                        options: QuizVerseSection.allCases
                    ) { section in
                        Text(section.title)
                    }
                }

                if !vm.isFilterReady {
                    Label {
                        Text("Preparing verses…")
                    } icon: {
                        ProgressView()
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                }
            }
        } facts: {
            GameSplashFacts(
                first: ("number", "\(QuizGameViewModel.questionsPerGame) questions", String(localized: "This session")),
                second: (
                    "timer",
                    vm.timeLimit.map { String(localized: "\($0) sec") } ?? String(localized: "No limit"),
                    String(localized: "Per verse")
                ),
                third: (
                    "text.alignleft",
                    vm.mode == .reverse ? "4" : (vm.difficulty.contextCost == 0 ? String(localized: "Free") : String(localized: "−\(vm.difficulty.contextCost) sec")),
                    vm.mode == .reverse ? String(localized: "Choices") : String(localized: "Previous verse")
                )
            )
        }
        Spacer(minLength: 48)
    }

    // MARK: - Gameplay layouts

    @ViewBuilder
    private var compactGameContent: some View {
        if let current = vm.current {
            VStack(spacing: 16) {
                GameScoreboardCard(
                    currentCorrect: vm.session.score,
                    currentAnswered: vm.session.answered,
                    currentStreak: vm.session.streak,
                    game: .quiz
                )

                QuizQuestionPanel(vm: vm, showsTimer: true)

                if !vm.isAnswered {
                    QuizLifelineBar(vm: vm)
                }

                QuizAfterAnswer(vm: vm)
                    .id(QuizAfterAnswer.scrollID)

                debugWinButton(for: current)
            }
            .padding(.vertical)
        }
    }

    @ViewBuilder
    private func dashboard(availableHeight: CGFloat) -> some View {
        if let current = vm.current {
            VStack(spacing: 18) {
                GameScoreboardCard(
                    currentCorrect: vm.session.score,
                    currentAnswered: vm.session.answered,
                    currentStreak: vm.session.streak,
                    game: .quiz,
                    style: .dashboard
                )

                QuizQuestionPanel(vm: vm, showsTimer: false)

                if !vm.isAnswered {
                    QuizLifelineBar(vm: vm)
                }

                QuizAfterAnswer(vm: vm)
                    .id(QuizAfterAnswer.scrollID)

                Spacer(minLength: 0)

                // Next is pinned to the bottom of this half, as on iPhone, so it never scrolls away.
                debugWinButton(for: current)
            }
            .padding(AppDesignMetrics.cardPadding)
            .padding(.top, 12)
            .frame(maxWidth: .infinity, minHeight: availableHeight, alignment: .top)
        }
    }

    @ViewBuilder
    private func debugWinButton(for current: QuizQuestion) -> some View {
        if debugAutoWinEnabled, !vm.isAnswered {
            Button("WIN") {
                vm.selectOption(current.correctAnswer)
            }
            .buttonStyle(ModernPillButtonStyle(tint: .red))
            .controlSize(.large)
            .padding(.top, 4)
            .accessibilityLabel("Win this round")
        }
    }
}

#Preview {
    NavigationStack {
        QuizView()
    }
}

#if DEBUG
/// A round answered correctly and instantly, so the speed bonus and chapter bonus show.
#Preview("Answered") {
    @Previewable @State var vm = QuizGameViewModel(
        mode: .standard,
        missedQuestions: MissedGameQuestionStore(entries: [])
    )
    NavigationStack { QuizView(viewModel: vm) }
        .task {
            _ = await BibleRepository.shared.loadAllBooks()
            vm.pool = .any
            vm.selectedSections = Set(QuizVerseSection.allCases)
            await vm.prepareFilter()
            vm.startQuiz()
            if let correct = vm.current?.correctAnswer {
                vm.selectOption(correct)
            }
        }
}
#endif
