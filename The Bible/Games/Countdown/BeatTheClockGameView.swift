import SwiftUI

struct BeatTheClockGameView: View {
    @State private var vm: BeatTheClockGameViewModel
    @State private var isGiveUpConfirmationPresented = false
    @State private var selectedPassage: PassageReference?

    init(reviewQuestionIDs: Set<String> = []) {
        _vm = State(initialValue: BeatTheClockGameViewModel(reviewQuestionIDs: reviewQuestionIDs))
    }

    // Global Auto‑Win debug toggle
    private var debugAutoWinEnabled: Bool { DebugOptions.autoWinEnabled }

    // Layout-only state
    @FocusState private var searchFieldFocused: Bool
    @State private var showAnswers: Bool = false
    @State private var timerOnLeft: Bool = false
    @State private var usesMutedTimerStyle: Bool = false

    var body: some View {
        BeatTheClockResponsiveGameScreen(
            isPlaying: vm.phase == .playing,
            isPaused: vm.isPaused,
            timerOnLeft: $timerOnLeft,
            content: { usesSplitLayout, availableHeight in
                gameContent(usesSplitLayout: usesSplitLayout, availableHeight: availableHeight)
            },
            actions: { actions },
            timer: { largeTimer }
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
            vm.isRapidFire ? "End this round?" : "Give up this question?",
            isPresented: $isGiveUpConfirmationPresented,
            message: vm.isRapidFire
                ? "The round ends now and keeps the books you've found."
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
            onDoubleTap: vm.selectionLocked ? { vm.nextRound() } : nil
        ) {
            if vm.selectionLocked {
                Button(vm.isLastQuestion ? "See Results" : "Next Question", systemImage: "arrow.right", action: vm.nextRound)
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
        // The view model can't touch focus, so the field follows the round state.
        .onChange(of: vm.roundID) { _, _ in
            // Wait a turn so the answer field is on screen before it takes focus.
            Task { searchFieldFocused = true }
        }
        .onChange(of: vm.roundOutcome) { _, outcome in
            if outcome != nil { searchFieldFocused = false }
        }
        .onChange(of: vm.phase) { _, phase in
            if phase != .playing { searchFieldFocused = false }
        }
        .onChange(of: vm.isPaused) { _, isPaused in
            if isPaused {
                searchFieldFocused = false
            } else {
                // Wait a turn so the answer field is back on screen before it takes focus.
                Task { searchFieldFocused = true }
            }
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
                            foundBooks: Set(vm.foundBooks + [vm.submittedBook].compactMap(\.self)),
                            firstMention: vm.firstMention(in:),
                            onOpen: { selectedPassage = PassageReferenceParser.parse($0) }
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
                resultNote: vm.pointsNote,
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
            outcome: vm.roundOutcome,
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

    @ViewBuilder
    private var setupContent: some View {
        Spacer(minLength: 32)
        Text(vm.mode == .rapidFire
            ? "Name as many Bible books as you can that mention each person or place before the timer runs out."
            : "Type a Bible book that mentions the shown person or place before the timer runs out.")
            .gameStartDescriptionStyle(for: .beatTheClock)

        GameSplashLaunchLayout(
            tint: .indigo,
            experienceLevel: $vm.experienceLevel,
            experienceDetails: vm.mode == .rapidFire
                ? GameExperienceDetails(
                    learn: "\(BeatTheClockDifficulty.easy.rapidFireTime) seconds for each name. Well-known names, with a clue shown for each one.",
                    standard: "\(BeatTheClockDifficulty.normal.rapidFireTime) seconds for each name. Adds less familiar names.",
                    challenge: "\(BeatTheClockDifficulty.hard.rapidFireTime) seconds for each name. Every name in the game."
                )
                : GameExperienceDetails(
                    learn: "\(BeatTheClockDifficulty.easy.roundTime) seconds per question. Well-known names, with a clue shown for each one.",
                    standard: "\(BeatTheClockDifficulty.normal.roundTime) seconds per question. Adds less familiar names. A clue costs \(BeatTheClockDifficulty.hintCost) seconds.",
                    challenge: "\(BeatTheClockDifficulty.hard.roundTime) seconds per question. Every name in the game. A clue costs \(BeatTheClockDifficulty.hintCost) seconds."
                ),
            experienceTitle: vm.reviewQuestionIDs.isEmpty ? "How you’ll play" : "Timer",
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
            GameSplashFacts(
                first: (
                    "number",
                    vm.reviewQuestionIDs.isEmpty
                        ? (vm.mode == .rapidFire
                            ? "\(BeatTheClockGameViewModel.rapidFireSubjectsPerGame) names"
                            : "\(BeatTheClockGameViewModel.questionsPerGame) questions")
                        : "Up to \(BeatTheClockGameViewModel.questionsPerGame) questions",
                    String(localized: "This session")
                ),
                second: (
                    "timer",
                    "\(vm.mode == .rapidFire ? vm.difficulty.rapidFireTime : vm.difficulty.roundTime) sec",
                    vm.mode == .rapidFire ? String(localized: "Per name") : String(localized: "Per question")
                ),
                third: (
                    "lightbulb",
                    vm.difficulty.showsClueAutomatically
                        ? String(localized: "Shown")
                        : String(localized: "−\(BeatTheClockDifficulty.hintCost) sec"),
                    String(localized: "Clues")
                )
            )
        }

        Spacer(minLength: 32)
    }

    // MARK: - Gameplay layouts

    private var clueRow: BeatTheClockClueRow {
        BeatTheClockClueRow(
            clue: vm.currentQuestion?.clue ?? "",
            isRevealed: vm.showsClue,
            canRequestHint: vm.canRequestHint,
            onRequestHint: vm.revealHint,
            testamentHint: vm.currentQuestion?.testamentHint ?? "",
            showsTestamentHint: vm.showsTestamentHint,
            canRequestTestamentHint: vm.canRequestTestamentHint,
            onRequestTestamentHint: vm.revealTestamentHint
        )
    }

    @ViewBuilder
    private var roundResult: some View {
        if let roundOutcome = vm.roundOutcome, let currentQuestion = vm.currentQuestion {
            VStack(spacing: 12) {
                BeatTheClockRoundResultCard(
                    outcome: roundOutcome,
                    subjectName: currentQuestion.label,
                    submittedBook: vm.submittedBook,
                    books: vm.booksByMentions,
                    scriptureReference: currentQuestion.scriptureReference,
                    foundBooks: vm.isRapidFire ? vm.foundBooks : nil,
                    earnedSpeedBonus: vm.earnedSpeedBonus,
                    earnedLessKnownBonus: vm.earnedLessKnownBonus,
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
            canSubmit: vm.canSubmit,
            isLastQuestion: vm.isLastQuestion,
            showsDebugWin: debugAutoWinEnabled,
            onSubmit: vm.submitCurrentEntry,
            onNext: vm.nextRound,
            onDebugWin: vm.debugWin
        )
    }

    private func clearInput() {
        vm.clearInput()
        searchFieldFocused = true
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
                Text(vm.currentQuestion?.label ?? "")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                clueRow
                    .padding(.top, 2)
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

        if vm.selectionLocked {
            roundResult
        } else {
            GameTimerCard(
                remainingSeconds: vm.remainingSeconds,
                tint: vm.timerColor,
                isPulsing: vm.isPulsing,
                formattedTime: vm.isTimerDisabled ? "Timer off" : nil,
                isDisabled: vm.isTimerDisabled,
                onTap: vm.toggleTimer
            )

            if vm.isRapidFire {
                rapidFireProgress
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(vm.isRapidFire ? "Name another book" : "Type a Bible book")
                    .font(.headline)
                HStack(spacing: 8) {
                    TextField("Start typing…", text: $vm.searchText)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { vm.submitCurrentEntry() }
                        .focused($searchFieldFocused)

                    Button(action: clearInput) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(vm.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Color.red)
                    .disabled(vm.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Clear input")
                }

                if let inputMessage = vm.inputMessage {
                    Label(inputMessage, systemImage: "exclamationmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }

                let suggestions = vm.filteredBooks
                if !suggestions.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(suggestions.prefix(8), id: \.self) { name in
                            Button {
                                vm.submit(bookName: name)
                            } label: {
                                Text(name)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .contentShape(Rectangle())
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color(.secondarySystemBackground))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        // Submit and Next are pinned above the tab bar on iPhone.
    }

    @ViewBuilder
    private var rapidFireProgress: some View {
        if let currentQuestion = vm.currentQuestion {
            BeatTheClockFoundBooks(foundBooks: vm.foundBooks, totalBooks: currentQuestion.acceptableBooks.count)
        }
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
                targetLabel: vm.currentQuestion?.label ?? "",
                clueRow: clueRow,
                tint: vm.timerColor,
                isLocked: vm.selectionLocked
            )

            if vm.selectionLocked {
                roundResult
            } else {
                if vm.isRapidFire {
                    rapidFireProgress
                }

                BeatTheClockDashboardAnswer(
                    searchText: $vm.searchText,
                    searchFieldFocused: $searchFieldFocused,
                    filteredBooks: Array(vm.filteredBooks.prefix(8)),
                    inputMessage: vm.inputMessage,
                    onClear: clearInput,
                    onSubmit: vm.submitCurrentEntry,
                    onSelectBook: { vm.submit(bookName: $0) }
                )
            }

            Spacer(minLength: 0)

            actions
        }
        .padding(.horizontal, AppDesignMetrics.cardPadding)
        .padding(.bottom, AppDesignMetrics.cardPadding)
        .padding(.top, AppDesignMetrics.cardPadding + 12)
        .frame(maxWidth: .infinity, minHeight: availableHeight, alignment: .top)
        .heroCardSurface()
    }
}

private struct BeatTheClockResponsiveGameScreen<Content: View, Actions: View, Timer: View>: View {
    let isPlaying: Bool
    let isPaused: Bool
    @Binding private var timerOnLeft: Bool
    private let content: (Bool, CGFloat) -> Content
    private let actions: () -> Actions
    private let timer: () -> Timer

    init(
        isPlaying: Bool,
        isPaused: Bool,
        timerOnLeft: Binding<Bool>,
        @ViewBuilder content: @escaping (Bool, CGFloat) -> Content,
        @ViewBuilder actions: @escaping () -> Actions,
        @ViewBuilder timer: @escaping () -> Timer
    ) {
        self.isPlaying = isPlaying
        self.isPaused = isPaused
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
                .pinnedGameActionButton(isShown: !usesSplitLayout && isPlaying && !isPaused) {
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
