import SwiftUI

struct BeatTheClockGameView: View {
    @State private var vm: BeatTheClockGameViewModel
    @State private var isGiveUpConfirmationPresented = false
    @State private var selectedPassage: PassageReference?

    init(reviewQuestionIDs: Set<String> = [], reviewMode: BeatTheClockMode? = nil) {
        _vm = State(initialValue: BeatTheClockGameViewModel(reviewQuestionIDs: reviewQuestionIDs, reviewMode: reviewMode))
    }

    // Global Auto‑Win debug toggle
    private var debugAutoWinEnabled: Bool { DebugOptions.autoWinEnabled }

    // Layout-only state
    @State private var showAnswers: Bool = false
    @State private var timerOnLeft: Bool = false
    @State private var usesMutedTimerStyle: Bool = false

    /// Next and See Results are pinned once a timed-per-question round is answered; a game
    /// clock moves on by itself.
    private var showsActions: Bool {
        guard vm.phase == .playing, !vm.isPaused else { return false }
        return vm.selectionLocked ? !vm.mode.usesGameClock : debugAutoWinEnabled
    }

    var body: some View {
        BeatTheClockResponsiveGameScreen(
            isPlaying: vm.phase == .playing,
            showsActions: showsActions,
            timerOnLeft: $timerOnLeft,
            content: { usesSplitLayout, availableHeight in
                gameContent(usesSplitLayout: usesSplitLayout, availableHeight: availableHeight)
            },
            actions: { actions },
            timer: { largeTimer }
        )
        .gameKeyboardInput(
            isActive: vm.phase == .playing && !vm.isPaused && !isGiveUpConfirmationPresented && !showAnswers,
            onKey: handleKeyPress
        )
        .background(AppBackgroundView(tab: .games))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if vm.phase != .setup {
                    GameNavigationTitle(.beatTheClock)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if vm.phase == .playing, !vm.selectionLocked, !vm.isPaused {
                    GameOptionsMenu(gameTitle: "Countdown") {
                        isGiveUpConfirmationPresented = true
                    }
                }
            }
        }
        .gamePauseControls(canPause: vm.canPause, pause: vm.pause)
        .gameGiveUpConfirmation(
            vm.mode.usesGameClock ? "End this game?" : "Give up this question?",
            isPresented: $isGiveUpConfirmationPresented,
            message: vm.mode.usesGameClock
                ? "The game ends now and keeps the answers you've given."
                : "The answer will be shown and marked incorrect."
        ) {
            vm.giveUp()
        }
        .task {
            await vm.loadData()
        }
        // The cited verses load with each round, ready for when it ends.
        .task(id: vm.currentQuestion?.id) {
            await vm.loadPassage()
        }
        // Double-tap goes on once the question is answered; it never spends a hint.
        .gamePencilActions(
            isEnabled: vm.phase == .playing && !vm.isPaused,
            onDoubleTap: vm.selectionLocked && !vm.mode.usesGameClock ? { vm.nextRound() } : nil
        ) {
            if vm.selectionLocked {
                if !vm.mode.usesGameClock {
                    Button(vm.isLastQuestion ? "See Results" : "Next Question", systemImage: "arrow.right", action: vm.nextRound)
                }
            } else {
                if vm.canRequestHint {
                    Button("Show Clue", systemImage: "lightbulb", action: vm.revealHint)
                }
                if vm.canRequestTestamentHint {
                    Button("Which Testament?", systemImage: "books.vertical", action: vm.revealTestamentHint)
                }
                GameGiveUpButton { isGiveUpConfirmationPresented = true }
            }
        }
        .onAppear {
            vm.onAppear()
        }
        .onDisappear {
            vm.onDisappear()
        }
        // Restarts with each round or resume; elapsed time remains authoritative between updates.
        .task(id: CountdownTimerRun(roundID: vm.roundID, isPaused: vm.isPaused, isTimerDisabled: vm.isTimerDisabled)) {
            await vm.runTimer()
        }
        .sheet(isPresented: $showAnswers) {
            NavigationStack {
                Group {
                    if vm.booksByMentions.isEmpty {
                        Text("No matches found in the Bible text for this entry.")
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        BeatTheClockBooksList(
                            books: vm.booksByMentions,
                            foundBooks: Set([vm.submittedBook].compactMap(\.self)),
                            firstMention: vm.firstMention(in:),
                            onOpen: { selectedPassage = PassageReferenceParser.firstPassage(in: $0) }
                        )
                    }
                }
                .navigationTitle("Books That Mention \(vm.currentQuestion?.label ?? "")")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showAnswers = false } } }
                .sheet(item: $selectedPassage) { reference in
                    ScripturePassageSheet(reference: reference)
                }
            }
        }
    }

    private func handleKeyPress(_ press: GameKeyboardPress) -> GameKeyboardPress.Result {
        guard vm.phase == .playing, !vm.isPaused else { return .ignored }
        if press.key == .return {
            guard vm.selectionLocked, !vm.mode.usesGameClock else { return .ignored }
            vm.nextRound()
            return .handled
        }
        guard !vm.selectionLocked else { return .ignored }
        let index = GameAnswerLetter.index(forKey: press.characters)
        if vm.mode == .higherOrLower {
            let choice = press.key == .leftArrow ? 0 : press.key == .rightArrow ? 1 : index
            guard let choice, let first = vm.currentQuestion, let second = vm.rival,
                  (0...1).contains(choice) else { return .ignored }
            vm.choose(questionID: choice == 0 ? first.id : second.id)
        } else {
            guard let index, let choices = vm.choices,
                  choices.books.indices.contains(index) else { return .ignored }
            vm.submit(bookName: choices.books[index])
        }
        return .handled
    }

    @ViewBuilder
    private func gameContent(usesSplitLayout: Bool, availableHeight: CGFloat) -> some View {
        switch vm.phase {
        case .setup:
            setupContent
        case .playing:
            if vm.isPaused {
                GamePausedView(tint: .indigo, remainingSeconds: vm.remainingSeconds) {
                    vm.resume()
                }
            } else if usesSplitLayout {
                dashboard(availableHeight: availableHeight)
            } else {
                compactGameContent
            }
        case .results:
            GameRoundSummaryView(
                summary: GameRoundSummary(score: vm.session),
                tint: .indigo,
                // A game clock ends the game rather than a question, so nothing times out.
                canTimeOut: !vm.mode.usesGameClock,
                points: vm.roundPoints,
                best: vm.roundBest,
                onPlayAgain: vm.startGame,
                onChangeSettings: vm.resetToSetup
            )
        }
    }

    private var largeTimer: some View {
        BeatTheClockLargeTimerView(
            remainingSeconds: vm.remainingSeconds,
            tint: vm.timerColor,
            isPulsing: vm.isPulsing,
            isTimerDisabled: vm.isTimerDisabled,
            outcome: vm.mode.usesGameClock ? nil : vm.roundOutcome,
            canToggleTimer: vm.canToggleTimer,
            usesMutedStyle: $usesMutedTimerStyle,
            onToggleTimer: vm.toggleTimer,
            onSwapSides: {
                withAnimation(.snappy) {
                    timerOnLeft.toggle()
                }
            }
        )
    }

    // MARK: - Setup

    private var setupDescription: LocalizedStringKey {
        switch vm.mode {
        case .survival:
            "Tap a Bible book that mentions each person or place. Right answers add time to the clock; wrong ones take it away."
        case .classic:
            "Tap a Bible book that mentions each person or place before the timer runs out."
        case .firstAppearance:
            "Tap the book where each person or place first appears, before the timer runs out."
        case .higherOrLower:
            "Tap the name found in more books of the Bible, as many times as you can before the clock runs out."
        }
    }

    private var experienceDetails: GameExperienceDetails {
        let easy = BeatTheClockDifficulty.easy
        let normal = BeatTheClockDifficulty.normal
        let hard = BeatTheClockDifficulty.hard
        let clueCost = BeatTheClockDifficulty.hintCost
        switch vm.mode {
        case .survival:
            let penalty = BeatTheClockDifficulty.survivalPenalty
            return GameExperienceDetails(
                learn: "\(easy.survivalStartTime) seconds to start, +\(easy.survivalTimeBonus) for each right answer and −\(penalty) for each wrong one. Well-known names, with a clue shown for each one.",
                standard: "\(normal.survivalStartTime) seconds to start, +\(normal.survivalTimeBonus) for each right answer and −\(penalty) for each wrong one. Adds less familiar names, and wrong books from the same Testament.",
                challenge: "\(hard.survivalStartTime) seconds to start, +\(hard.survivalTimeBonus) for each right answer and −\(penalty) for each wrong one. Every name in the game, and wrong books from the same part of the Bible."
            )
        case .classic:
            return GameExperienceDetails(
                learn: "\(easy.roundTime) seconds per question. Well-known names, with a clue shown for each one. +1 bonus point for answering in the first \(easy.roundTime / 3) seconds.",
                standard: "\(normal.roundTime) seconds per question. Adds less familiar names, and wrong books from the same Testament. A clue costs \(clueCost) seconds. +1 bonus point for answering in the first \(normal.roundTime / 3) seconds.",
                challenge: "\(hard.roundTime) seconds per question. Every name in the game, and wrong books from the same part of the Bible. A clue costs \(clueCost) seconds. +1 bonus point for answering in the first \(hard.roundTime / 3) seconds."
            )
        case .firstAppearance:
            return GameExperienceDetails(
                learn: "\(easy.firstAppearanceTime) seconds per question. Well-known names, with a clue shown for each one, and the other books from later in the Bible. +1 bonus point for answering in the first \(easy.firstAppearanceTime / 3) seconds.",
                standard: "\(normal.firstAppearanceTime) seconds per question. Adds less familiar names. A clue costs \(clueCost) seconds. +1 bonus point for answering in the first \(normal.firstAppearanceTime / 3) seconds.",
                challenge: "\(hard.firstAppearanceTime) seconds per question. Every name in the game, and the other books are the ones right after the first. A clue costs \(clueCost) seconds. +1 bonus point for answering in the first \(hard.firstAppearanceTime / 3) seconds."
            )
        case .higherOrLower:
            let penalty = BeatTheClockDifficulty.higherOrLowerPenalty
            return GameExperienceDetails(
                learn: "\(easy.higherOrLowerTime) seconds for the game. Well-known names, at least \(easy.higherOrLowerGap) books apart. A wrong pick costs \(penalty) seconds.",
                standard: "\(normal.higherOrLowerTime) seconds for the game. Adds less familiar names, at least \(normal.higherOrLowerGap) books apart. A wrong pick costs \(penalty) seconds.",
                challenge: "\(hard.higherOrLowerTime) seconds for the game. Every name in the game, as close as \(hard.higherOrLowerGap) book apart. A wrong pick costs \(penalty) seconds."
            )
        }
    }

    private var setupFacts: GameSplashFacts {
        let isReview = !vm.reviewQuestionIDs.isEmpty
        let count: GameSplashFacts.Fact = if vm.mode.usesGameClock && !isReview {
            ("infinity", String(localized: "Until time’s up"), String(localized: "This session"))
        } else {
            (
                "number",
                isReview
                    ? String(localized: "Up to \(BeatTheClockGameViewModel.questionsPerGame) questions")
                    : String(localized: "\(BeatTheClockGameViewModel.questionsPerGame) questions"),
                String(localized: "This session")
            )
        }
        let clockLabel = switch vm.mode {
        case .survival: String(localized: "To start")
        case .higherOrLower: String(localized: "For the game")
        case .classic, .firstAppearance: String(localized: "Per question")
        }
        let clock: GameSplashFacts.Fact = ("timer", String(localized: "\(vm.roundTime) sec"), clockLabel)
        let third: GameSplashFacts.Fact = switch vm.mode {
        case .survival:
            ("plus.circle", String(localized: "+\(vm.difficulty.survivalTimeBonus) sec"), String(localized: "Per right answer"))
        case .higherOrLower:
            ("minus.circle", String(localized: "−\(BeatTheClockDifficulty.higherOrLowerPenalty) sec"), String(localized: "Per wrong pick"))
        case .classic, .firstAppearance:
            (
                "lightbulb",
                vm.difficulty.showsClueAutomatically
                    ? String(localized: "Shown")
                    : String(localized: "−\(BeatTheClockDifficulty.hintCost) sec"),
                String(localized: "Clues")
            )
        }
        return GameSplashFacts(first: count, second: clock, third: third)
    }

    @ViewBuilder
    private var setupContent: some View {
        Spacer(minLength: 32)
        Text(setupDescription)
            .gameStartDescriptionStyle(for: .beatTheClock)

        GameSplashLaunchLayout(
            tint: .indigo,
            experienceLevel: $vm.experienceLevel,
            experienceDetails: experienceDetails,
            experienceTitle: vm.reviewQuestionIDs.isEmpty ? "How you’ll play" : "Timer",
            bestPoints: vm.reviewQuestionIDs.isEmpty ? vm.bestPoints : nil,
            isConfigurationEnabled: vm.reviewQuestionIDs.isEmpty,
            isStartEnabled: !vm.isLoadingData,
            startAction: vm.startGame
        ) {
            GameLobbyPreview(kind: .beatTheClock)
        } configuration: {
            BeatTheClockSetupControls(mode: $vm.mode, category: $vm.category)

            if vm.isLoadingData {
                Label("Loading questions…", systemImage: "hourglass")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        } facts: {
            setupFacts
        }

        Spacer(minLength: 32)
    }

    // MARK: - Gameplay layouts

    private var clueRow: BeatTheClockClueRow {
        BeatTheClockClueRow(
            clue: vm.offersClue ? vm.currentQuestion?.clue ?? "" : "",
            isRevealed: vm.showsClue,
            canRequestHint: vm.canRequestHint,
            onRequestHint: vm.revealHint,
            testamentHint: vm.currentQuestion?.testamentHint ?? "",
            offersTestamentHint: vm.offersTestamentHint,
            showsTestamentHint: vm.showsTestamentHint,
            canRequestTestamentHint: vm.canRequestTestamentHint,
            onRequestTestamentHint: vm.revealTestamentHint
        )
    }

    /// The name in large type, or Higher or Lower's question, since it shows two names.
    private var promptTitle: String {
        vm.mode == .higherOrLower ? vm.instruction : vm.currentQuestion?.label ?? ""
    }

    @ViewBuilder
    private var board: some View {
        if vm.mode == .higherOrLower {
            if let first = vm.currentQuestion, let second = vm.rival {
                BeatTheClockPairBoard(
                    first: first,
                    second: second,
                    winnerID: vm.higherOrLowerWinner?.id,
                    chosenID: vm.chosenQuestionID,
                    isLocked: vm.selectionLocked,
                    tint: .indigo,
                    onChoose: vm.choose(questionID:)
                )
            }
        } else if let choices = vm.choices {
            BeatTheClockChoiceGrid(
                books: choices.books,
                answer: choices.answer,
                chosen: vm.submittedBook,
                isLocked: vm.selectionLocked,
                tint: .indigo,
                onChoose: { vm.submit(bookName: $0) }
            )
        }
    }

    /// What the last answer did to a game clock, e.g. "+4 sec".
    @ViewBuilder
    private var clockChange: some View {
        if vm.selectionLocked, let change = vm.lastClockChange {
            Label(
                change > 0 ? "+\(change) sec" : "−\(abs(change)) sec",
                systemImage: change > 0 ? "plus.circle.fill" : "minus.circle.fill"
            )
            .font(.headline.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(change > 0 ? .green : .red)
            .transition(.scale.combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var roundResult: some View {
        if let roundOutcome = vm.roundOutcome, let currentQuestion = vm.currentQuestion, !vm.mode.usesGameClock {
            VStack(spacing: 12) {
                BeatTheClockRoundResultCard(
                    outcome: roundOutcome,
                    subjectName: currentQuestion.label,
                    submittedBook: vm.submittedBook,
                    books: vm.booksByMentions,
                    scriptureReference: currentQuestion.scriptureReference,
                    firstAppearance: vm.mode == .firstAppearance ? vm.choices.map { choices in
                        (book: choices.answer, reference: vm.firstMention(in: choices.answer))
                    } : nil,
                    earnedSpeedBonus: vm.earnedSpeedBonus,
                    onShowAllAnswers: { showAnswers = true }
                )

                if let verse = vm.displayedVerse {
                    GameVerseCard(verse: verse)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
            }
            .animation(.snappy, value: vm.displayedVerse)
        }
    }

    private var actions: BeatTheClockActions {
        BeatTheClockActions(
            isLocked: vm.selectionLocked,
            isLastQuestion: vm.isLastQuestion,
            showsDebugWin: debugAutoWinEnabled,
            onNext: vm.nextRound,
            onDebugWin: vm.debugWin
        )
    }

    /// Tapping the timer turns it off and on, except on a game clock.
    private var timerTapAction: (() -> Void)? {
        guard vm.canToggleTimer else { return nil }
        return { vm.toggleTimer() }
    }

    @ViewBuilder
    private var compactGameContent: some View {
        GameScoreboardCard(
            currentCorrect: vm.session.score,
            currentAnswered: vm.session.answered,
            currentStreak: vm.session.streak,
            game: .beatclock
        )

        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(vm.targetType) · \(vm.progressText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(promptTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                if vm.mode != .higherOrLower {
                    Text(vm.instruction)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    clueRow
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    vm.selectionLocked ? Color.primary.opacity(0.12) : vm.timerColor,
                    lineWidth: vm.selectionLocked ? 1 : 2
                )
        )
        .animation(.easeInOut(duration: 0.25), value: vm.remainingSeconds)

        if !vm.selectionLocked || vm.mode.usesGameClock {
            GameTimerCard(
                remainingSeconds: vm.remainingSeconds,
                tint: vm.timerColor,
                isPulsing: vm.isPulsing,
                formattedTime: vm.isTimerDisabled ? "Timer off" : nil,
                isDisabled: vm.isTimerDisabled,
                onTap: timerTapAction
            )
        }

        board
        clockChange
        roundResult
        // Next and See Results are pinned above the tab bar on iPhone.
    }

    private func dashboard(availableHeight: CGFloat) -> some View {
        VStack(spacing: 18) {
            GameScoreboardCard(
                currentCorrect: vm.session.score,
                currentAnswered: vm.session.answered,
                currentStreak: vm.session.streak,
                game: .beatclock,
                style: .dashboard
            )

            BeatTheClockDashboardPrompt(
                targetType: vm.targetType,
                isPlace: vm.currentQuestion?.subject == .place,
                progressText: vm.progressText,
                title: promptTitle,
                instruction: vm.mode == .higherOrLower ? nil : vm.instruction,
                clueRow: vm.mode == .higherOrLower ? nil : clueRow,
                tint: vm.timerColor,
                isLocked: vm.selectionLocked
            )

            board
            clockChange
            roundResult

            // Next and See Results are pinned to the bottom of this half, as on iPhone.
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppDesignMetrics.cardPadding)
        .padding(.bottom, AppDesignMetrics.cardPadding)
        .padding(.top, AppDesignMetrics.cardPadding + 12)
        .frame(maxWidth: .infinity, minHeight: availableHeight, alignment: .top)
        .heroCardSurface()
        .animation(.snappy, value: vm.lastClockChange)
    }
}

private struct BeatTheClockResponsiveGameScreen<Content: View, Actions: View, Timer: View>: View {
    let isPlaying: Bool
    let showsActions: Bool
    @Binding private var timerOnLeft: Bool
    private let content: (Bool, CGFloat) -> Content
    private let actions: () -> Actions
    private let timer: () -> Timer

    init(
        isPlaying: Bool,
        showsActions: Bool,
        timerOnLeft: Binding<Bool>,
        @ViewBuilder content: @escaping (Bool, CGFloat) -> Content,
        @ViewBuilder actions: @escaping () -> Actions,
        @ViewBuilder timer: @escaping () -> Timer
    ) {
        self.isPlaying = isPlaying
        self.showsActions = showsActions
        _timerOnLeft = timerOnLeft
        self.content = content
        self.actions = actions
        self.timer = timer
    }

    var body: some View {
        GeometryReader { geometry in
            let usesSplitLayout = isPlaying && geometry.size.width >= 700

            ZStack {
                ScrollView {
                    VStack(spacing: 16) {
                        content(usesSplitLayout, geometry.size.height - 32)
                    }
                    .padding()
                }
                .tabBarContentClearance()
                .pinnedGameActionButton(isShown: showsActions) {
                    actions()
                }
                .frame(width: usesSplitLayout ? geometry.size.width / 2 : geometry.size.width)
                .frame(
                    maxWidth: .infinity,
                    alignment: usesSplitLayout && timerOnLeft ? .trailing : .leading
                )

                if usesSplitLayout {
                    timer()
                        .frame(width: geometry.size.width / 2)
                        .frame(maxWidth: .infinity, alignment: timerOnLeft ? .leading : .trailing)
                }
            }
        }
    }
}

/// Identifies one run of the Countdown timer: a new round or a resume starts a new run.
private struct CountdownTimerRun: Hashable {
    let roundID: Int
    let isPaused: Bool
    let isTimerDisabled: Bool
}
