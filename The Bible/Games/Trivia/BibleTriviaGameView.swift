import Foundation
import Observation
import SwiftUI

struct BibleTriviaGameView: View {
    @State private var model: BibleTriviaGameModel
    private let isReviewRound: Bool

    init(reviewQuestionIDs: Set<String> = []) {
        isReviewRound = !reviewQuestionIDs.isEmpty
        _model = State(initialValue: BibleTriviaGameModel(reviewQuestionIDs: reviewQuestionIDs))
    }

    var body: some View {
        Group {
            switch model.phase {
            case .loading:
                ProgressView("Loading trivia questions…")
            case .setup:
                BibleTriviaSetupScreen(
                    difficulty: $model.difficulty,
                    topic: $model.topic,
                    questionsPerRound: 10,
                    eligibleQuestionCount: model.eligibleQuestions.count,
                    isReviewRound: isReviewRound,
                    onStart: model.startRound
                )
            case .playing where model.isPaused:
                ScrollView {
                    GamePausedView(tint: .cyan, remainingSeconds: model.remainingSeconds) {
                        model.resume()
                    }
                    .frame(maxWidth: 620)
                    .padding()
                }
                .tabBarContentClearance()
            case .playing:
                BibleTriviaPlayScreen(model: model)
            case .results:
                ScrollView {
                    GameRoundSummaryView(
                        summary: GameRoundSummary(score: model.session),
                        tint: .cyan,
                        poolProgress: model.poolProgress,
                        resultNote: model.speedBonusNote,
                        extraAction: model.bookToPractice.map { book in
                            GameRoundSummaryView.ExtraAction(
                                title: String(localized: "Practice \(book)"),
                                systemImage: "book.pages",
                                action: { model.practice(book: book) }
                            )
                        },
                        onPlayAgain: model.startRound,
                        onChangeSettings: model.returnToSetup
                    )
                    .padding()
                }
                .tabBarContentClearance()
            case .unavailable:
                ContentUnavailableView(
                    "Trivia questions unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text("The trivia catalog could not be loaded.")
                )
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if model.phase == .playing || model.phase == .results {
                    GameNavigationTitle(title: "Trivia", systemImage: "questionmark.text.page.fill", tint: .cyan)
                }
            }
        }
        .gamePauseControls(canPause: model.canPause, pause: model.pause)
        .task {
            await model.load()
        }
        .onDisappear {
            model.onDisappear()
        }
    }
}

private struct BibleTriviaSetupScreen: View {
    @Binding var difficulty: BibleTriviaDifficulty
    @Binding var topic: BibleTriviaTopic
    let questionsPerRound: Int
    let eligibleQuestionCount: Int
    let isReviewRound: Bool
    let onStart: () -> Void

    private var experienceLevel: Binding<GameExperienceLevel> {
        Binding(
            get: {
                switch difficulty {
                case .easy: .learn
                case .normal: .standard
                case .hard: .challenge
                }
            },
            set: { level in
                difficulty = switch level {
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
                Spacer(minLength: 24)

                Text("Answer Bible knowledge questions with Scripture support after every answer.")
                    .gameStartDescriptionStyle(
                        title: "Trivia",
                        systemImage: "questionmark.text.page.fill",
                        tint: .cyan
                    )

                GameSplashLaunchLayout(
                    tint: .cyan,
                    experienceLevel: experienceLevel,
                    experienceDetails: GameExperienceDetails(
                        learn: "The most familiar questions, with 30 seconds for each answer.",
                        standard: "15 seconds for each answer, and questions are a little more challenging.",
                        challenge: "10 seconds for each answer and the most challenging questions."
                    ),
                    experienceTitle: isReviewRound ? "Timer" : "How you’ll play",
                    isConfigurationEnabled: !isReviewRound,
                    startAction: onStart
                ) {
                    GameLobbyPreview(kind: .trivia)
                } configuration: {
                    GameSettingsGroup {
                        GameChoiceSetting(
                            title: "Questions from",
                            systemImage: "books.vertical.fill",
                            tint: .cyan,
                            selection: $topic,
                            choices: BibleTriviaTopic.allCases.map {
                                GameChoice(value: $0, title: $0.title, detail: $0.detail, icon: $0.systemImage)
                            }
                        )
                    }
                } facts: {
                    GameSplashFacts(
                        first: ("number", "\(questionsPerRound) questions", "This session"),
                        second: ("timer", "\(difficulty.timerSeconds) sec", "Per question"),
                        third: ("square.stack.3d.up", eligibleQuestionCount.formatted(), "Question pool")
                    )
                }

                Spacer(minLength: 24)
            }
            .gameStartScreenStyle()
        }
    }
}

private struct BibleTriviaPlayScreen: View {
    let model: BibleTriviaGameModel

    @Environment(\.preferredPencilDoubleTapAction) private var preferredPencilDoubleTapAction
    @State private var timerOnLeft = false
    @State private var usesMutedTimerStyle = false
    @State private var verseToast = VerseActionToastState()
    @State private var showsPencilActions = false
    @State private var selectedPassage: PassageReference?
    @FocusState private var isKeyboardFocused: Bool

    private var timerTint: Color {
        let fraction = Double(model.remainingSeconds) / Double(max(1, model.currentTimeLimit))
        if fraction <= 0.3 { return .red }
        if fraction <= 0.6 { return .yellow }
        return .green
    }

    private var outcome: BibleTriviaAnswerOutcome? {
        guard model.isAnswered, let question = model.currentQuestion else {
            return nil
        }
        if model.timedOut {
            return .timedOut
        }
        return model.selectedAnswer == question.correctAnswer ? .correct : .incorrect
    }

    var body: some View {
        GeometryReader { geometry in
            let usesSplitLayout = geometry.size.width >= 700

            ZStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        if model.currentQuestion != nil {
                            if usesSplitLayout {
                                BibleTriviaDashboard(
                                    model: model,
                                    outcome: outcome,
                                    onShowPencilMenu: { showsPencilActions = true },
                                    onShowPassage: showFullPassage
                                )
                                .frame(minHeight: geometry.size.height - 32, alignment: .top)
                            } else {
                                BibleTriviaCompactBoard(
                                    model: model,
                                    timerTint: timerTint,
                                    outcome: outcome,
                                    onShowPencilMenu: { showsPencilActions = true },
                                    onShowPassage: showFullPassage
                                )
                            }
                        }
                    }
                    .tabBarContentClearance()
                    .pinnedNextQuestionButton(
                        isShown: !usesSplitLayout && model.currentQuestion != nil && model.isAnswered,
                        isLastQuestion: model.isLastQuestion,
                        tint: .cyan,
                        action: model.advance
                    )
                    // Once answered, keep the result and verse in view above the pinned Next button.
                    // This runs when the content grows (the result, then the verse) and when the
                    // button's inset arrives, rather than after a guessed delay.
                    .onScrollGeometryChange(for: CGFloat.self) { geometry in
                        geometry.contentSize.height + geometry.contentInsets.bottom
                    } action: { _, _ in
                        guard model.isAnswered, !usesSplitLayout else { return }
                        withAnimation(.snappy) {
                            proxy.scrollTo(BibleTriviaAnswerReveal.scrollID, anchor: .bottom)
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
                    BibleTriviaLargeTimerView(
                        remainingSeconds: model.remainingSeconds,
                        tint: model.isTimerDisabled ? .secondary : timerTint,
                        isTimerDisabled: model.isTimerDisabled,
                        outcome: outcome,
                        verse: model.displayedVerse,
                        usesMutedStyle: $usesMutedTimerStyle,
                        onToggleTimer: model.toggleTimer,
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
        // The passage loads with each question, ready for the verse hint and for after answering.
        .task(id: model.currentQuestion?.id) {
            await model.loadPassage()
        }
        // A hardware keyboard answers with 1–4 or A–D, and Return goes on.
        .focusable()
        .focused($isKeyboardFocused)
        .onKeyPress(phases: .down, action: handleKeyPress)
        .onAppear { isKeyboardFocused = true }
        .onPencilDoubleTap { _ in
            guard preferredPencilDoubleTapAction != .ignore, model.isAnswered else { return }
            model.advance()
        }
        .confirmationDialog("Apple Pencil Actions", isPresented: $showsPencilActions, titleVisibility: .visible) {
            if model.isAnswered {
                Button(model.isLastQuestion ? "See Results" : "Next Question", systemImage: "arrow.right", action: model.advance)
            } else {
                ForEach(BibleTriviaLifeline.allCases, id: \.self) { lifeline in
                    if model.canUse(lifeline) {
                        Button(lifeline.title, systemImage: lifeline.systemImage) {
                            model.use(lifeline)
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $selectedPassage) { reference in
            ScripturePassageSheet(reference: reference)
        }
    }

    private func showFullPassage() {
        guard let reference = model.currentQuestion?.reference else { return }
        selectedPassage = PassageReferenceParser.parse(reference)
    }

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        if keyPress.key == .return || keyPress.characters == "\r" || keyPress.characters == "\n" {
            guard model.isAnswered else { return .ignored }
            model.advance()
            return .handled
        }

        guard !model.isAnswered, keyPress.modifiers.isEmpty,
              let index = GameAnswerLetter.index(forKey: keyPress.characters),
              model.options.indices.contains(index) else {
            return .ignored
        }
        model.choose(model.options[index])
        return .handled
    }
}

extension BibleTriviaLifeline {
    var title: LocalizedStringKey {
        switch self {
        case .fiftyFifty: "50/50"
        case .verseHint: "Verse Hint"
        case .extraTime: "+\(Self.extraSeconds) Seconds"
        }
    }

    var systemImage: String {
        switch self {
        case .fiftyFifty: "circle.lefthalf.filled"
        case .verseHint: "text.quote"
        case .extraTime: "timer"
        }
    }

    var accessibilityHint: LocalizedStringKey {
        switch self {
        case .fiftyFifty: "Removes two wrong answers. Once per round."
        case .verseHint: "Shows the question's verse with the answer blanked out. Once per round."
        case .extraTime: "Adds ten seconds to the timer. Once per round."
        }
    }
}

#Preview {
    NavigationStack {
        BibleTriviaGameView()
    }
}
