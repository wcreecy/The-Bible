import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

struct QuizView: View {
    @Query private var favorites: [Favorite]
    @State private var vm: QuizGameViewModel

    init(reviewQuestionIDs: Set<String> = [], mode: QuizMode = .standard) {
        _vm = State(initialValue: QuizGameViewModel(reviewQuestionIDs: reviewQuestionIDs, mode: mode))
    }

    // Global Auto‑Win debug toggle
    private var debugAutoWinEnabled: Bool { DebugOptions.autoWinEnabled }

    // Layout-only state for the split dashboard
    @State private var timerOnLeft: Bool = false
    @State private var usesMutedTimerStyle: Bool = false
    @State private var verseToast = VerseActionToastState()

    var body: some View {
        GeometryReader { geometry in
            let usesSplitLayout = vm.mode == .standard && vm.phase == .playing && geometry.size.width >= 700

            ZStack {
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
                                onPlayAgain: vm.startQuiz,
                                onChangeSettings: vm.resetToSetup
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .tabBarContentClearance()
                .pinnedNextQuestionButton(
                    isShown: !usesSplitLayout && vm.phase == .playing && vm.isAnswered,
                    isLastQuestion: vm.isOnLastQuestion,
                    tint: .blue,
                    action: vm.showNext
                )
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
                    GameNavigationTitle(title: "Quiz", systemImage: "questionmark.circle.fill", tint: .blue)
                }
            }
        }
        .gamePauseControls(canPause: vm.canPause, pause: vm.pause)
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

    // MARK: - Setup

    @ViewBuilder
    private var setupContent: some View {
        Text(vm.mode == .reverse ? "Choose the verse text that matches the reference." : "Test your knowledge by guessing the book of the Bible from a given verse.")
            .gameStartDescriptionStyle(title: "Quiz", systemImage: "questionmark.circle.fill", tint: .blue)

        GameSplashLaunchLayout(
            tint: .blue,
            experienceLevel: $vm.experienceLevel,
            experienceDetails: GameExperienceDetails(
                learn: "Untimed practice at your own pace.",
                standard: vm.mode == .reverse ? "20 seconds. Choices from your categories." : "15 seconds for each verse.",
                challenge: vm.mode == .reverse ? "30 seconds. Choices from the same book." : "12 seconds for each verse."
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
                        choices: QuizReversePool.allCases.map {
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

    private var contextRow: QuizContextRow? {
        guard let current = vm.current, let contextText = current.contextText else { return nil }
        return QuizContextRow(
            contextText: contextText,
            isRevealed: current.contextRevealed || current.outcome != nil,
            cost: vm.difficulty.contextCost,
            canReveal: vm.canRevealContext,
            onReveal: vm.revealContext
        )
    }

    @ViewBuilder
    private var answerReveal: some View {
        if let current = vm.current, let outcome = current.outcome {
            QuizAnswerReveal(
                outcome: outcome,
                bookName: current.correctBook,
                chapterNumber: current.chapter,
                verseNumber: current.verse,
                verseText: current.verseText
            )
        }
    }

    /// The inline Next button for the iPad dashboard; iPhone pins it to the bottom instead.
    private var nextButton: some View {
        GameNextQuestionButton(isLastQuestion: vm.isOnLastQuestion, tint: .blue, action: vm.showNext)
    }

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

                // Verse card
                VStack(alignment: .leading, spacing: 12) {
                    Text(vm.progressText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text(current.prompt)
                        .italic()
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)

                    contextRow
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(UIColor.secondarySystemBackground), Color(UIColor.systemBackground)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            vm.isTimerRunning ? vm.timerColor : Color.primary.opacity(0.12),
                            lineWidth: vm.isTimerRunning ? 2 : 1
                        )
                )
                .animation(.easeInOut(duration: 0.25), value: vm.remainingSeconds)
                .padding(.horizontal)

                if vm.isTimed, !vm.isAnswered {
                    GameTimerCard(
                        remainingSeconds: vm.remainingSeconds,
                        tint: vm.isTimerDisabled ? .secondary : vm.timerColor,
                        isPulsing: vm.isTimerDisabled ? false : vm.isPulsing,
                        formattedTime: vm.isTimerDisabled ? "Timer off" : nil,
                        isDisabled: vm.isTimerDisabled,
                        onTap: vm.toggleTimer
                    )
                    .padding(.horizontal)
                }

                if !vm.isAnswered {
                    Text(vm.mode == .reverse ? "Which verse matches this reference?" : "Which book is this from?")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }

                LazyVGrid(columns: vm.mode == .reverse ? [GridItem(.flexible())] : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(current.options, id: \.self) { option in
                        VStack(spacing: 0) {
                            Button {
                                vm.selectOption(option)
                            } label: {
                                Text(option)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .foregroundStyle(.primary)
                            }
                            .disabled(vm.isAnswered)

                            if vm.isAnswered,
                               let verse = current.optionVerses.first(where: { $0.verseText == option }) {
                                HStack {
                                    Text(verse.reference)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    VerseActionMenu(
                                        verse: VerseActionReference(
                                            bookName: verse.bookName,
                                            chapterNumber: verse.chapterNumber,
                                            verseNumber: verse.verseNumber,
                                            verseText: verse.verseText
                                        )
                                    )
                                    .accessibilityLabel("Actions for \(verse.reference)")
                                }
                                .padding(.horizontal)
                                .padding(.bottom)
                            }
                        }
                        .background(buttonBackground(for: option, in: current))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(
                                    vm.isAnswered && option == current.correctAnswer ? Color.green : Color.black.opacity(0.15),
                                    lineWidth: vm.isAnswered && option == current.correctAnswer ? 3 : 1
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .font(.body)
                    }
                }
                .padding(.horizontal)

                if vm.isAnswered {
                    answerReveal
                        .padding(.horizontal)
                }

                // DEBUG: WIN button
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

                QuizDashboardQuestion(
                    progressText: vm.progressText,
                    verseText: current.verseText,
                    contextRow: contextRow,
                    options: current.options,
                    selectedOption: current.selected,
                    correctBookName: current.correctBook,
                    isAnswered: vm.isAnswered,
                    onSelectOption: vm.selectOption
                )

                answerReveal

                Spacer(minLength: 0)

                if debugAutoWinEnabled && !vm.isAnswered {
                    Button("Win", systemImage: "checkmark.seal.fill") {
                        vm.selectOption(current.correctAnswer)
                    }
                    .buttonStyle(GameProminentButtonStyle(tint: .red))
                } else {
                    nextButton
                        .disabled(!vm.canGoNext)
                }
            }
            .padding(AppDesignMetrics.cardPadding)
            .padding(.top, 12)
            .frame(maxWidth: .infinity, minHeight: availableHeight, alignment: .top)
        }
    }

    // MARK: - UI helpers

    private func buttonBackground(for option: String, in question: QuizQuestion) -> Color {
        guard question.outcome != nil, question.selected == option else { return .clear }
        return option == question.correctAnswer ? Color.green.opacity(0.3) : Color.red.opacity(0.3)
    }
}

#Preview {
    NavigationStack {
        QuizView()
    }
}
