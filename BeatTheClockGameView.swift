import SwiftUI
import UIKit

struct BeatTheClockGameView: View {
    @State private var vm: BeatTheClockGameViewModel

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
        GeometryReader { geometry in
            let usesSplitLayout = vm.phase == .playing && geometry.size.width >= 700

            ZStack {
                ScrollView {
                    VStack(spacing: 16) {
                        switch vm.phase {
                        case .setup:
                            setupContent
                        case .playing:
                            if usesSplitLayout {
                                dashboard(availableHeight: geometry.size.height - 32)
                            } else {
                                compactGameContent
                            }
                        case .results:
                            Spacer(minLength: 32)
                            BeatTheClockResultsCard(
                                score: vm.score,
                                total: vm.totalQuestions,
                                bestStreak: vm.sessionBestStreak,
                                bestGameScore: vm.bestGameScore,
                                isNewBest: vm.isNewBestGame,
                                onPlayAgain: vm.startGame,
                                onChangeSettings: vm.resetGameSession
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                }
                .tabBarContentClearance()
                .frame(width: usesSplitLayout ? geometry.size.width / 2 : geometry.size.width)
                .frame(
                    maxWidth: .infinity,
                    alignment: usesSplitLayout && timerOnLeft ? .trailing : .leading
                )

                if usesSplitLayout {
                    BeatTheClockLargeTimerView(
                        remainingSeconds: vm.remainingSeconds,
                        tint: vm.timerColor,
                        isPulsing: vm.isPulsing,
                        outcome: vm.roundOutcome,
                        usesMutedStyle: $usesMutedTimerStyle,
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
        }
        .background(AppBackgroundView(tab: .games))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if vm.phase != .setup {
                    GameNavigationTitle(title: "Countdown", systemImage: "hourglass", tint: .indigo)
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
        // Restarts with each round so the first second is a full second.
        .task(id: vm.roundID) {
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
        .sheet(isPresented: $showAnswers) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    if vm.sortedAcceptableBooks.isEmpty {
                        Text("No matches found in the Bible text for this entry.")
                            .foregroundStyle(.secondary)
                    } else {
                        List(vm.sortedAcceptableBooks, id: \.self) { name in
                            Text(name)
                        }
                        .listStyle(.insetGrouped)
                    }
                    Spacer(minLength: 0)
                }
                .padding()
                .navigationTitle("Acceptable Books")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showAnswers = false } } }
            }
        }
    }

    // MARK: - Setup

    @ViewBuilder
    private var setupContent: some View {
        Spacer(minLength: 32)
        Text("Type a Bible book that mentions the shown person or place before the timer runs out.")
            .gameStartDescriptionStyle(title: "Countdown", systemImage: "hourglass", tint: .indigo)

        GameSplashLaunchLayout(
            tint: .indigo,
            experienceLevel: $vm.experienceLevel,
            experienceDetails: GameExperienceDetails(
                learn: "Known names • 25 sec.",
                standard: "More names • 15 sec.",
                challenge: "All names • 10 sec."
            ),
            experienceTitle: vm.reviewQuestionIDs.isEmpty ? "How you’ll play" : "Timer",
            isConfigurationEnabled: vm.reviewQuestionIDs.isEmpty,
            isStartEnabled: !vm.isLoadingData,
            startAction: vm.startGame
        ) {
            GameLobbyPreview(kind: .beatTheClock)
        } configuration: {
            BeatTheClockSetupControls(category: $vm.category)

            if vm.isLoadingData {
                Label("Loading questions…", systemImage: "hourglass")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        } facts: {
            GameSplashFacts(
                first: ("number", "\(BeatTheClockGameViewModel.questionsPerGame) questions", String(localized: "This session")),
                second: ("timer", "\(vm.difficulty.roundTime) sec", String(localized: "Per question")),
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
            onRequestHint: vm.revealHint
        )
    }

    @ViewBuilder
    private var roundResult: some View {
        if let roundOutcome = vm.roundOutcome, let currentQuestion = vm.currentQuestion {
            BeatTheClockRoundResultCard(
                outcome: roundOutcome,
                subjectName: currentQuestion.label,
                submittedBook: vm.submittedBook,
                acceptableBooks: vm.sortedAcceptableBooks,
                scriptureReference: currentQuestion.scriptureReference,
                onShowAllAnswers: { showAnswers = true }
            )
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
            currentCorrect: vm.score,
            currentAnswered: vm.answered,
            currentStreak: vm.sessionStreak,
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
                isPulsing: vm.isPulsing
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Type a Bible book")
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

        actions
    }

    private func dashboard(availableHeight: CGFloat) -> some View {
        VStack(spacing: 18) {
            GameScoreboardCard(
                currentCorrect: vm.score,
                currentAnswered: vm.answered,
                currentStreak: vm.sessionStreak,
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
