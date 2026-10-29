import SwiftUI

struct WhoAmIGameView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
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
    @AppStorage("debugAutoWinEnabled") private var debugAutoWinEnabled: Bool = false

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
                    Spacer(minLength: 32)
                    WhoAmIResultsCard(
                        score: vm.score,
                        total: vm.totalQuestions,
                        bestStreak: vm.sessionBestStreak,
                        bestGameScore: vm.bestGameScore,
                        isNewBest: vm.isNewBestGame,
                        onPlayAgain: vm.startGame,
                        onChangeSettings: vm.returnToSetup
                    )
                    .frame(maxWidth: .infinity)
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
                person: person
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
                    .buttonStyle(GameProminentButtonStyle(tint: .accentColor))
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
            currentCorrect: vm.score,
            currentAnswered: vm.answered,
            currentStreak: vm.sessionStreak,
            game: .whoami
        )

        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(promptIsName ? "Name" : "Clue")
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
                isDisabled: vm.isTimerDisabled
            )

            Button(vm.isTimerDisabled ? "Timer On" : "Timer Off", systemImage: vm.isTimerDisabled ? "play.fill" : "pause.fill", action: vm.toggleTimer)
                .buttonStyle(.bordered)
        }

        VStack(alignment: .leading, spacing: 8) {
            Text(promptIsName ? "Which clue describes them?" : "Who am I?")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
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

        reveal

        roundActions
    }

    private var iPadBoard: some View {
        VStack(spacing: 20) {
            GameScoreboardCard(
                currentCorrect: vm.score,
                currentAnswered: vm.answered,
                currentStreak: vm.sessionStreak,
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
                    Text(promptIsName ? "Name" : "Clue")
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

private struct WhoAmISetupControls: View {
    @Binding var mode: WhoAmIGameViewModel.Mode

    var body: some View {
        GameSettingsGroup {
            GameChoiceSetting(
                title: "How to play",
                systemImage: "person.text.rectangle",
                tint: .brown,
                selection: $mode,
                choices: WhoAmIGameViewModel.Mode.allCases.map {
                    GameChoice(value: $0, title: $0.title, detail: $0.detail, icon: $0.icon)
                }
            )
        }
    }
}

/// Who the answer was, and where they appear in the Bible.
private struct WhoAmIRevealCard: View {
    let wasCorrect: Bool
    let wasTimedOut: Bool
    let person: WhoAmIGameViewModel.Entry

    private static let shownBookCount = 6

    private var booksText: String {
        let shown = person.books.prefix(Self.shownBookCount).joined(separator: ", ")
        let remaining = person.books.count - Self.shownBookCount
        return remaining > 0 ? String(localized: "\(shown), and \(remaining) more") : shown
    }

    private var title: LocalizedStringKey {
        if wasCorrect { return "Correct!" }
        return wasTimedOut ? "Time’s up" : "Not quite"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.headline)
                .foregroundStyle(wasCorrect ? Color.green : Color.red)

            if let qualifier = person.qualifier {
                Text("\(person.name) (\(qualifier))")
                    .font(.title3.weight(.bold))
            } else {
                Text(person.name)
                    .font(.title3.weight(.bold))
            }

            Text(person.clue)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !person.books.isEmpty {
                Label {
                    Text("Appears in \(booksText)")
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "books.vertical")
                }
                .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            (wasCorrect ? Color.green : Color.red).opacity(0.1),
            in: RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct WhoAmIResultsCard: View {
    let score: Int
    let total: Int
    let bestStreak: Int
    let bestGameScore: Int
    let isNewBest: Bool
    let onPlayAgain: () -> Void
    let onChangeSettings: () -> Void

    private var accuracy: Int {
        guard total > 0 else { return 0 }
        return Int((Double(score) / Double(total) * 100).rounded())
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isNewBest ? "trophy.fill" : "flag.checkered")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(isNewBest ? Color.yellow : Color.brown)

            VStack(spacing: 6) {
                Text(isNewBest ? "New Best Game!" : "Game Over")
                    .font(.title.weight(.bold))

                Text("\(score) of \(total) correct")
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            GameSplashFacts(
                first: ("percent", "\(accuracy)%", String(localized: "Accuracy")),
                second: ("flame.fill", "\(bestStreak)", String(localized: "Best streak")),
                third: ("trophy", "\(bestGameScore)/\(total)", String(localized: "Best game"))
            )

            VStack(spacing: 10) {
                Button("Play Again", systemImage: "arrow.clockwise", action: onPlayAgain)
                    .buttonStyle(GameProminentButtonStyle(tint: .brown))

                Button("Change Settings", systemImage: "slider.horizontal.3", action: onChangeSettings)
                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
            }
        }
        .padding(24)
        .frame(maxWidth: 520)
        .heroCardSurface()
    }
}

private struct WhoAmITimerCard: View {
    let isTimed: Bool
    let remainingSeconds: Int
    let tint: Color
    let isActive: Bool
    let isTimerDisabled: Bool
    let isPulsing: Bool
    let resultIsCorrect: Bool?
    @Binding var usesMutedStyle: Bool
    let onSwapSides: () -> Void
    let onToggleTimer: () -> Void

    private var usesVividStyle: Bool {
        isTimed && !isTimerDisabled && !usesMutedStyle
    }

    private var timerTextColor: Color {
        tint == .yellow ? .black : .white
    }

    private var displayTint: Color {
        if isTimerDisabled, resultIsCorrect == nil { return .secondary }
        guard !isActive, let resultIsCorrect else { return tint }
        return resultIsCorrect ? .green : .red
    }

    private var vividTextColor: Color {
        isActive ? timerTextColor : .white
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            VStack(spacing: 24) {
                Image(systemName: statusSystemImage)
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(
                        usesVividStyle
                            ? vividTextColor.opacity(0.85)
                            : statusTint
                    )

                Text(statusTitle)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(
                        usesVividStyle
                            ? vividTextColor.opacity(0.85)
                            : statusTint
                    )

                if isTimed && isActive {
                    Text("\(remainingSeconds)s")
                        .font(.largeTitle.weight(.bold))
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .foregroundStyle(usesVividStyle ? vividTextColor : displayTint)
                }
            }
            .scaleEffect(isPulsing ? 1.04 : 1)
            .animation(.easeOut(duration: 0.18), value: isPulsing)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(statusTitle)
            .accessibilityValue(isTimed && isActive ? "\(remainingSeconds) seconds" : "")

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button(
                    "Swap card sides",
                    systemImage: "arrow.left.arrow.right",
                    action: onSwapSides
                )

                if isTimed {
                    if resultIsCorrect == nil {
                        Button(isTimerDisabled ? "Timer On" : "Timer Off", systemImage: isTimerDisabled ? "play.fill" : "pause.fill", action: onToggleTimer)
                    }

                    Button(
                        usesMutedStyle ? "Use vivid timer background" : "Use muted timer background",
                        systemImage: "circle.lefthalf.filled"
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            usesMutedStyle.toggle()
                        }
                    }
                }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass(.clear))
            .controlSize(.small)
            .tint(usesVividStyle ? vividTextColor : displayTint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .background(
            usesVividStyle ? displayTint : Color.clear,
            in: RoundedRectangle(
                cornerRadius: AppDesignMetrics.cardCornerRadius,
                style: .continuous
            )
        )
        .heroCardSurface()
    }

    /// Untimed games still show the result once the question is answered.
    private var statusTitle: LocalizedStringKey {
        if let resultIsCorrect, !isActive {
            return resultIsCorrect ? "Correct" : "Incorrect"
        }
        if isTimerDisabled { return "Timer Off" }
        return isTimed ? "Time Remaining" : "Untimed"
    }

    private var statusSystemImage: String {
        if let resultIsCorrect, !isActive {
            return resultIsCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
        }
        if isTimerDisabled { return "timer.slash" }
        return isTimed ? "timer" : "infinity"
    }

    private var statusTint: Color {
        if let resultIsCorrect, !isActive {
            return resultIsCorrect ? .green : .red
        }
        if isTimerDisabled { return .secondary }
        return isTimed ? tint : .secondary
    }
}

#Preview {
    NavigationStack {
        WhoAmIGameView()
    }
}
