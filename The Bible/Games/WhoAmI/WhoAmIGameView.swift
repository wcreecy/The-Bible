import SwiftUI

struct WhoAmIGameView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var vm: WhoAmIGameViewModel

    init(reviewQuestionIDs: Set<String> = []) {
        isReviewRound = !reviewQuestionIDs.isEmpty
        _vm = State(initialValue: WhoAmIGameViewModel(reviewQuestionIDs: reviewQuestionIDs))
    }
    @State private var maxChoiceHeight: CGFloat = 0
    @State private var timerOnLeading = false
    @State private var usesMutedTimerStyle = false
    private let isReviewRound: Bool

    // Global Auto‑Win debug toggle
    private var debugAutoWinEnabled: Bool { DebugOptions.autoWinEnabled }

    private struct ChoiceHeightKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = max(value, nextValue())
        }
    }

    private var promptIsName: Bool { vm.currentPromptIsName }

    private var experienceLevel: Binding<GameExperienceLevel> {
        Binding(
            get: {
                switch vm.difficulty {
                case .easy: .learn
                case .normal: .standard
                case .hard: .challenge
                }
            },
            set: { level in
                vm.difficulty = switch level {
                case .learn: .easy
                case .standard: .normal
                case .challenge: .hard
                }
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !vm.started {
                    setupContent
                } else if vm.isComplete {
                    VStack(spacing: 12) {
                        GameRoundSummaryView(
                            summary: GameRoundSummary(score: vm.session),
                            tint: .brown,
                            canTimeOut: vm.difficulty.timeLimit > 0,
                            onPlayAgain: vm.startGame,
                            onChangeSettings: vm.returnToSetup
                        )
                        if vm.difficulty.timeLimit > 0 {
                            WhoAmITimingSummary(timeouts: vm.timeoutCount, remainingTimes: vm.correctTimeRemaining)
                        }
                    }
                } else if vm.isPaused {
                    GamePausedView(tint: .brown, remainingSeconds: vm.remainingSeconds) {
                        vm.resume()
                    }
                    .frame(maxWidth: 620)
                } else if horizontalSizeClass == .regular {
                    iPadBoard
                } else {
                    compactBoard
                }
            }
            .padding()
        }
        .tabBarContentClearance()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if vm.started {
                    GameNavigationTitle(title: "Who?", systemImage: "person.text.rectangle", tint: .brown)
                }
            }
        }
        .gamePauseControls(canPause: vm.canPause, pause: vm.pause)
        .onAppear { vm.onAppear() }
        .onDisappear { vm.endRoundWhenLeavingScreen() }
        .onChange(of: vm.choices) { _, _ in
            maxChoiceHeight = 0
        }
    }

    // MARK: - Setup

    @ViewBuilder
    private var setupContent: some View {
        Spacer(minLength: 24)
        Text("Name the Bible person from a clue, or the clue from a name.")
            .gameStartDescriptionStyle(title: "Who?", systemImage: "person.text.rectangle", tint: .brown)

        GameSplashLaunchLayout(
            tint: .brown,
            experienceLevel: experienceLevel,
            experienceDetails: GameExperienceDetails(
                learn: "Well-known people with no timer.",
                standard: "More people with 30 seconds per clue.",
                challenge: "Everyone with 15 seconds per clue."
            ),
            experienceTitle: isReviewRound ? "Timer" : "How you’ll play",
            isConfigurationEnabled: !isReviewRound,
            isStartEnabled: vm.isReady,
            startAction: vm.startGame
        ) {
            GameLobbyPreview(kind: .whoAmI)
        } configuration: {
            WhoAmISetupControls(mode: $vm.mode)
        } facts: {
            GameSplashFacts(
                first: ("number", "\(WhoAmIGameViewModel.questionsPerGame) questions", String(localized: "This session")),
                second: (
                    "timer",
                    vm.difficulty.timeLimit > 0 ? String(localized: "\(vm.difficulty.timeLimit) sec") : String(localized: "No limit"),
                    String(localized: "Per question")
                ),
                third: ("square.stack.3d.up", "4", String(localized: "Choices"))
            )
        }
        Spacer(minLength: 24)
    }

    // MARK: - Gameplay

    private var progressText: String {
        String(localized: "Question \(vm.questionNumber) of \(vm.totalQuestions)")
    }

    @ViewBuilder
    private var reveal: some View {
        if vm.roundOver, let person = vm.current {
            WhoAmIRevealCard(
                wasCorrect: vm.selectedChoice == vm.correctChoice,
                wasTimedOut: vm.wasTimedOut,
                person: person,
                secondsRemaining: vm.remainingSeconds
            )
        }
    }

    @ViewBuilder
    private var roundActions: some View {
        if vm.roundOver {
            if vm.isLastQuestion {
                Button("See Results", systemImage: "flag.checkered", action: vm.nextRound)
                    .buttonStyle(GameProminentButtonStyle(tint: .brown))
            } else {
                Button("Next Question", systemImage: "arrow.right", action: vm.nextRound)
                    .buttonStyle(GameProminentButtonStyle(tint: .brown))
            }
        } else if debugAutoWinEnabled {
            Button("WIN") {
                vm.select(vm.correctChoice)
            }
            .buttonStyle(ModernPillButtonStyle(tint: .red))
            .controlSize(.large)
            .padding(.top, 6)
            .accessibilityLabel("Win this round")
        }
    }

    @ViewBuilder
    private var compactBoard: some View {
        GameScoreboardCard(
            currentCorrect: vm.session.score,
            currentAnswered: vm.session.answered,
            currentStreak: vm.session.streak,
            game: .whoami
        )

        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label(promptIsName ? "NAME → CLUE" : "CLUE → NAME", systemImage: promptIsName ? "person.fill" : "text.quote")
                    Spacer()
                    Text(progressText)
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(vm.promptTitle)
                    .font(promptIsName ? .title2.weight(.semibold) : .body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(questionBorderColor, lineWidth: timerIsActive ? 2 : 1)
        )
        .animation(.easeInOut(duration: 0.25), value: vm.remainingSeconds)

        if isTimedQuestion {
            GameTimerCard(
                remainingSeconds: vm.remainingSeconds,
                tint: vm.isTimerDisabled ? .secondary : timerTint,
                isPulsing: vm.isTimerDisabled ? false : vm.pulseOn,
                formattedTime: vm.isTimerDisabled ? "Timer off" : nil,
                isDisabled: vm.isTimerDisabled,
                onTap: vm.toggleTimer
            )
        }

        VStack(alignment: .leading, spacing: 8) {
            Text(promptIsName ? "Which clue describes them?" : "Who am I?")
                .font(.headline)
            LazyVGrid(columns: compactChoiceColumns, spacing: 12) {
                ForEach(vm.choices, id: \.self) { choice in
                    Button {
                        vm.select(choice)
                    } label: {
                        Text(choice)
                            .font(promptIsName ? .footnote : .body.weight(.semibold))
                            .multilineTextAlignment(promptIsName ? .leading : .center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(
                                maxWidth: .infinity,
                                minHeight: promptIsName ? max(maxChoiceHeight, 96) : 40,
                                maxHeight: promptIsName ? max(maxChoiceHeight, 96) : 40,
                                alignment: promptIsName ? .leading : .center
                            )
                            .padding(promptIsName ? 16 : 10)
                            .foregroundStyle(.primary)
                            .contentShape(Rectangle())
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .preference(key: ChoiceHeightKey.self, value: geo.size.height)
                                }
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.roundOver)
                    .accessibilityValue(accessibilityState(for: choice))
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(backgroundColor(for: choice))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                borderColor(for: choice),
                                lineWidth: vm.roundOver && choice == vm.correctChoice ? 2 : 1
                            )
                    )
                }
            }
            .onPreferenceChange(ChoiceHeightKey.self) { value in
                maxChoiceHeight = value
            }
        }

        hintAction

        reveal

        roundActions
    }

    private var iPadBoard: some View {
        VStack(spacing: 20) {
            GameScoreboardCard(
                currentCorrect: vm.session.score,
                currentAnswered: vm.session.answered,
                currentStreak: vm.session.streak,
                game: .whoami,
                style: .dashboard
            )

            HStack(alignment: .top, spacing: 20) {
                if timerOnLeading {
                    timerCard
                    playCard
                } else {
                    playCard
                    timerCard
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 620, alignment: .top)
        .animation(.snappy, value: timerOnLeading)
    }

    private var playCard: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                Label(promptIsName ? "NAME → CLUE" : "CLUE → NAME", systemImage: promptIsName ? "person.fill" : "text.quote")
                    Spacer()
                    Text(progressText)
                        .monospacedDigit()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

                Text(vm.promptTitle)
                    .font(promptIsName ? .title.weight(.semibold) : .title3.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
            }

            hintAction
            .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(vm.choices, id: \.self) { choice in
                    Button {
                        vm.select(choice)
                    } label: {
                        Text(choice)
                            .font(promptIsName ? .subheadline : .body.weight(.semibold))
                            .multilineTextAlignment(promptIsName ? .leading : .center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(
                                maxWidth: .infinity,
                                minHeight: promptIsName ? 88 : 40,
                                alignment: promptIsName ? .leading : .center
                            )
                            .padding(promptIsName ? 16 : 10)
                            .foregroundStyle(.primary)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.roundOver)
                    .accessibilityValue(accessibilityState(for: choice))
                    .background(
                        backgroundColor(for: choice),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                borderColor(for: choice),
                                lineWidth: vm.roundOver && choice == vm.correctChoice ? 2 : 1
                            )
                    }
                }
            }

            reveal

            Spacer(minLength: 0)

            roundActions
        }
        .padding(AppDesignMetrics.cardPadding)
        .heroCardSurface()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var timerCard: some View {
        WhoAmITimerCard(
            isTimed: vm.difficulty.timeLimit > 0,
            remainingSeconds: vm.remainingSeconds,
            tint: timerTint,
            isActive: timerIsActive,
            isTimerDisabled: vm.isTimerDisabled,
            isPulsing: vm.pulseOn,
            resultIsCorrect: vm.roundOver ? vm.selectedChoice == vm.correctChoice : nil,
            usesMutedStyle: $usesMutedTimerStyle,
            onSwapSides: { timerOnLeading.toggle() },
            onToggleTimer: vm.toggleTimer
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func accessibilityState(for choice: String) -> String {
        guard vm.roundOver else { return "" }
        if choice == vm.correctChoice { return String(localized: "Correct answer") }
        if choice == vm.selectedChoice { return String(localized: "Your answer, incorrect") }
        return ""
    }

    private func backgroundColor(for choice: String) -> Color {
        guard vm.roundOver else { return Color(.secondarySystemBackground) }
        if choice == vm.correctChoice { return .green.opacity(0.25) }
        if let sel = vm.selectedChoice, sel == choice, choice != vm.correctChoice { return .red.opacity(0.25) }
        return Color(.secondarySystemBackground)
    }

    private func borderColor(for choice: String) -> Color {
        guard vm.roundOver else { return Color.primary.opacity(0.15) }
        if choice == vm.correctChoice { return .green }
        if let sel = vm.selectedChoice, sel == choice, choice != vm.correctChoice { return .red }
        return Color.primary.opacity(0.15)
    }

    private var timerIsActive: Bool {
        isTimedQuestion && !vm.isTimerDisabled
    }

    private var compactChoiceColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: promptIsName || dynamicTypeSize.isAccessibilitySize ? 1 : 2)
    }

    @ViewBuilder
    private var hintAction: some View {
        if vm.canUseHint {
            Button("Hint — costs 5 seconds", systemImage: "lightbulb") { vm.useHint() }
                .buttonStyle(.bordered)
                .tint(.brown)
        } else if vm.hintUsed, let hint = vm.hintText {
            Label(hint, systemImage: "lightbulb.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var isTimedQuestion: Bool {
        vm.difficulty.timeLimit > 0 && !vm.roundOver
    }

    private var questionBorderColor: Color {
        timerIsActive ? timerTint : Color.primary.opacity(0.12)
    }

    /// Green, then yellow, then red as the question runs down, scaled to the time limit.
    private var timerTint: Color {
        let fraction = Double(vm.remainingSeconds) / Double(max(1, vm.difficulty.timeLimit))
        if fraction <= 0.3 { return .red }
        if fraction <= 0.6 { return .yellow }
        return .green
    }
}

#Preview {
    NavigationStack {
        WhoAmIGameView()
    }
}
