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
                BibleTriviaPlayScreen(
                    question: model.currentQuestion,
                    options: model.options,
                    questionNumber: model.currentIndex + 1,
                    questionCount: model.roundCount,
                    score: model.session.score,
                    answered: model.session.answered,
                    currentStreak: model.session.streak,
                    accuracy: model.accuracy,
                    remainingSeconds: model.remainingSeconds,
                    timerSeconds: model.difficulty.timerSeconds,
                    isTimerDisabled: model.isTimerDisabled,
                    selectedAnswer: model.selectedAnswer,
                    isAnswered: model.isAnswered,
                    timedOut: model.timedOut,
                    canGoNext: model.canGoNext,
                    isLastQuestion: model.isLastQuestion,
                    onChoose: model.choose,
                    onToggleTimer: model.toggleTimer,
                    onAdvance: model.advance
                )
            case .results:
                ScrollView {
                    GameRoundSummaryView(
                        summary: GameRoundSummary(score: model.session),
                        tint: .cyan,
                        poolProgress: model.poolProgress,
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
                        learn: "30 seconds for each answer.",
                        standard: "15 seconds for each answer and questions are a little more challenging",
                        challenge: "10 seconds for each answer and the most challenging questions."
                    ),
                    experienceTitle: isReviewRound ? "Timer" : "How you’ll play",
                    isConfigurationEnabled: !isReviewRound,
                    startAction: onStart
                ) {
                    GameLobbyPreview(kind: .trivia)
                } configuration: {
                    EmptyView()
                } facts: {
                    GameSplashFacts(
                        first: ("number", "\(questionsPerRound) questions", "This session"),
                        second: ("timer", "\(difficulty.timerSeconds) sec", "Per question"),
                        third: ("square.stack.3d.up", "\(eligibleQuestionCount)", "Question pool")
                    )
                }

                Spacer(minLength: 24)
            }
            .gameStartScreenStyle()
        }
    }
}

private struct BibleTriviaPlayScreen: View {
    let question: BibleTriviaQuestion?
    let options: [String]
    let questionNumber: Int
    let questionCount: Int
    let score: Int
    let answered: Int
    let currentStreak: Int
    let accuracy: Int
    let remainingSeconds: Int
    let timerSeconds: Int
    let isTimerDisabled: Bool
    let selectedAnswer: String?
    let isAnswered: Bool
    let timedOut: Bool
    let canGoNext: Bool
    let isLastQuestion: Bool
    let onChoose: (String) -> Void
    let onToggleTimer: () -> Void
    let onAdvance: () -> Void

    @State private var timerOnLeft = false
    @State private var usesMutedTimerStyle = false
    @State private var verseToast = VerseActionToastState()

    private var timerTint: Color {
        let fraction = Double(remainingSeconds) / Double(max(1, timerSeconds))
        if fraction <= 0.3 { return .red }
        if fraction <= 0.6 { return .yellow }
        return .green
    }

    private var outcome: BibleTriviaAnswerOutcome? {
        guard isAnswered, let question else {
            return nil
        }
        if timedOut {
            return .timedOut
        }
        return selectedAnswer == question.correctAnswer ? .correct : .incorrect
    }

    var body: some View {
        GeometryReader { geometry in
            let usesSplitLayout = geometry.size.width >= 700

            ZStack {
                ScrollView {
                    if let question {
                        if usesSplitLayout {
                            BibleTriviaDashboard(
                                question: question.question,
                                correctAnswer: question.correctAnswer,
                                options: options,
                                questionNumber: questionNumber,
                                questionCount: questionCount,
                                score: score,
                                answered: answered,
                                currentStreak: currentStreak,
                                outcome: outcome,
                                reference: question.reference,
                                selectedAnswer: selectedAnswer,
                                isAnswered: isAnswered,
                                onChoose: onChoose,
                                canGoNext: canGoNext,
                                isLastQuestion: isLastQuestion,
                                onAdvance: onAdvance
                            )
                            .frame(minHeight: geometry.size.height - 32, alignment: .top)
                        } else {
                            BibleTriviaCompactBoard(
                                question: question.question,
                                correctAnswer: question.correctAnswer,
                                options: options,
                                questionNumber: questionNumber,
                                questionCount: questionCount,
                                score: score,
                                answered: answered,
                                currentStreak: currentStreak,
                                remainingSeconds: remainingSeconds,
                                timerTint: timerTint,
                                isTimerDisabled: isTimerDisabled,
                                outcome: outcome,
                                reference: question.reference,
                                selectedAnswer: selectedAnswer,
                                isAnswered: isAnswered,
                                onChoose: onChoose,
                                onToggleTimer: onToggleTimer,
                                canGoNext: canGoNext,
                                isLastQuestion: isLastQuestion,
                                onAdvance: onAdvance
                            )
                        }
                    }
                }
                .tabBarContentClearance()
                .pinnedNextQuestionButton(
                    isShown: !usesSplitLayout && question != nil && isAnswered,
                    isLastQuestion: isLastQuestion,
                    tint: .cyan,
                    action: onAdvance
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
                    BibleTriviaLargeTimerView(
                        remainingSeconds: remainingSeconds,
                        tint: isTimerDisabled ? .secondary : timerTint,
                        isTimerDisabled: isTimerDisabled,
                        outcome: outcome,
                        usesMutedStyle: $usesMutedTimerStyle,
                        onToggleTimer: onToggleTimer,
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
    }
}

#Preview {
    NavigationStack {
        BibleTriviaGameView()
    }
}
