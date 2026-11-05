import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class BibleTriviaGameModel {
    enum Phase {
        case loading
        case setup
        case playing
        case results
        case unavailable
    }

    private static let questionsPerRound = 10
    private static let bestScoreKeyPrefix = "bibleTriviaBestScore"

    private let reviewQuestionIDs: Set<String>

    init(reviewQuestionIDs: Set<String> = []) {
        self.reviewQuestionIDs = reviewQuestionIDs
    }

    private struct RoundQuestion: Identifiable {
        let question: BibleTriviaQuestion
        let options: [String]
        var selectedAnswer: String?
        var timedOut = false

        var id: Int { question.id }
        var isAnswered: Bool { selectedAnswer != nil || timedOut }
    }

    var phase: Phase = .loading
    var difficulty: BibleTriviaDifficulty = .normal
    private(set) var questions: [BibleTriviaQuestion] = []
    private var round: [RoundQuestion] = []
    private var carryoverQuestionIDs: Set<Int> = []
    private(set) var currentIndex = 0
    private var furthestPresentedIndex = 0
    /// Score and streaks; see `GameScore` for the rules. Trivia keeps its own best score below.
    private(set) var session = GameScore()
    private(set) var bestScore = 0
    private(set) var remainingSeconds = 0
    var isTimerDisabled = false
    /// True while the question is paused: the timer stops and the question is hidden.
    private(set) var isPaused = false
    @ObservationIgnored private var timerTask: Task<Void, Never>?

    let progressStore = BibleTriviaProgressStore.shared

    private var currentRoundQuestion: RoundQuestion? {
        round.indices.contains(currentIndex) ? round[currentIndex] : nil
    }

    var currentQuestion: BibleTriviaQuestion? {
        currentRoundQuestion?.question
    }

    var roundCount: Int {
        round.count
    }

    var options: [String] {
        currentRoundQuestion?.options ?? []
    }

    var selectedAnswer: String? {
        currentRoundQuestion?.selectedAnswer
    }

    var isAnswered: Bool {
        currentRoundQuestion?.isAnswered ?? false
    }

    var timedOut: Bool {
        currentRoundQuestion?.timedOut ?? false
    }

    var eligibleQuestions: [BibleTriviaQuestion] {
        guard !reviewQuestionIDs.isEmpty else {
            return questions.filter(difficulty.includes)
        }
        return questions.filter { reviewQuestionIDs.contains(String($0.id)) }
    }

    var completedInPool: Int {
        min(progressStore.progress(for: difficulty).completedQuestionIDs.count, eligibleQuestions.count)
    }

    var accuracy: Int {
        guard session.answered > 0 else { return 0 }
        return Int((Double(session.score) / Double(session.answered) * 100).rounded())
    }

    var isLastQuestion: Bool {
        currentIndex == round.count - 1
    }

    var isViewingPrevious: Bool {
        currentIndex < furthestPresentedIndex
    }

    var canGoNext: Bool {
        isViewingPrevious || isAnswered
    }

    private var persistentStreak: PersistentGameStreak {
        PersistentGameStreak(game: "trivia", variant: difficulty.rawValue)
    }

    func load() async {
        guard questions.isEmpty else {
            phase = .setup
            return
        }

        // The catalog is large; decode it off the main actor so the screen stays responsive.
        let loadedQuestions = await Task.detached(priority: .userInitiated) { () -> [BibleTriviaQuestion] in
            guard let data = BibleTriviaCatalogStore.loadData(),
                  let decoded = PersistedDecoding.decode([BibleTriviaQuestion].self, from: data, name: "BibleTriviaQuestions.json") else {
                return []
            }
            return decoded
        }.value

        guard !loadedQuestions.isEmpty else {
            phase = .unavailable
            return
        }

        questions = loadedQuestions
        phase = .setup
    }

    func startRound() {
        let eligible = eligibleQuestions
        guard eligible.count >= Self.questionsPerRound else {
            phase = .unavailable
            return
        }

        round = selectRoundQuestions(from: eligible).map(makeRoundQuestion)
        guard round.count == Self.questionsPerRound else {
            phase = .unavailable
            return
        }

        currentIndex = 0
        furthestPresentedIndex = 0
        // The session streak carries from one game to the next.
        session.beginGame(savedStreak: persistentStreak)
        // The saved best score is still kept (and synced) but no longer shown on the summary.
        bestScore = UserDefaults.standard.integer(forKey: bestScoreKey)
        isTimerDisabled = false
        phase = .playing
        prepareCurrentQuestion()
    }

    /// Draws questions at random from those not yet asked in the current cycle. When fewer than a
    /// round's worth remain, the leftovers are used, the pool restarts, and the round is topped up
    /// from the rest so no question repeats until every question in the pool has been asked.
    private func selectRoundQuestions(from eligible: [BibleTriviaQuestion]) -> [BibleTriviaQuestion] {
        carryoverQuestionIDs = []
        guard reviewQuestionIDs.isEmpty else {
            return Array(eligible.shuffled().prefix(Self.questionsPerRound))
        }

        let completed = progressStore.progress(for: difficulty).completedQuestionIDs
        var selected = Array(eligible.filter { !completed.contains($0.id) }.shuffled().prefix(Self.questionsPerRound))
        guard selected.count < Self.questionsPerRound else { return selected }

        // Leftovers belong to the finished cycle, so they aren't recorded against the new one.
        carryoverQuestionIDs = Set(selected.map(\.id))
        progressStore.resetCompletedPool(for: difficulty)
        let refill = eligible.filter { !carryoverQuestionIDs.contains($0.id) }.shuffled()
        selected += refill.prefix(Self.questionsPerRound - selected.count)
        return selected.shuffled()
    }

    func choose(_ answer: String) {
        guard !isPaused, !isViewingPrevious, !isAnswered, options.contains(answer), let question = currentQuestion else { return }
        finishAnswer(answer, question: question)
    }

    func advance() {
        guard canGoNext else { return }
        if isViewingPrevious {
            currentIndex += 1
        } else if isLastQuestion {
            session.endGame()
            savePersonalBest()
            phase = .results
        } else {
            currentIndex += 1
            furthestPresentedIndex = currentIndex
            prepareCurrentQuestion()
        }
    }

    /// Back to the start screen. The streak is kept so the next game can continue it.
    func returnToSetup() {
        timerTask?.cancel()
        isPaused = false
        phase = .setup
        round = []
        currentIndex = 0
        furthestPresentedIndex = 0
        session.clearGame()
    }

    func onDisappear() {
        // Leaving after answering begins a new game on return.
        if (phase == .playing || phase == .results) && session.answered > 0 {
            returnToSetup()
        }
        session.clearStreak()
    }

    private func prepareCurrentQuestion() {
        guard !isViewingPrevious, !isAnswered else { return }
        remainingSeconds = difficulty.timerSeconds
        session.startQuestion()
        isPaused = false
        startTimer()
    }

    // MARK: - Pausing

    /// Only a question with its timer running can be paused. With "Timer Off" the question
    /// stays on screen and untimed, so there's nothing to pause.
    var canPause: Bool {
        phase == .playing && !isTimerDisabled && !isViewingPrevious && !isAnswered && !isPaused
    }

    /// Stops the clock and hides the question until `resume()`.
    func pause() {
        guard canPause else { return }
        isPaused = true
        timerTask?.cancel()
    }

    /// Restarts the countdown with a full first second.
    func resume() {
        guard isPaused else { return }
        isPaused = false
        startTimer()
    }

    private func startTimer() {
        timerTask?.cancel()
        guard !isTimerDisabled, !isPaused else { return }
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !self.isViewingPrevious, !self.isAnswered else { return }
                guard self.remainingSeconds > 1 else {
                    if let question = self.currentQuestion {
                        self.finishAnswer(nil, question: question)
                    }
                    return
                }
                self.remainingSeconds -= 1
            }
        }
    }

    func toggleTimer() {
        isTimerDisabled.toggle()
        if isTimerDisabled {
            session.noteTimerTurnedOff()
        }
        if !isTimerDisabled, !isViewingPrevious, !isAnswered {
            startTimer()
        } else {
            timerTask?.cancel()
        }
    }

    private func finishAnswer(_ answer: String?, question: BibleTriviaQuestion) {
        guard !isViewingPrevious, !isAnswered else { return }
        timerTask?.cancel()
        round[currentIndex].selectedAnswer = answer
        round[currentIndex].timedOut = answer == nil
        let isCorrect = answer == question.correctAnswer
        let scriptureReference = BibleReferenceLinker.parse(question.reference)
        session.record(
            GameRoundEntry(
                prompt: question.question,
                outcome: isCorrect ? .correct : (answer == nil ? .timedOut : .wrong),
                givenAnswer: answer,
                correctAnswer: question.correctAnswer,
                category: Self.questionLevelTitle(question.difficulty),
                bookName: scriptureReference?.bookName,
                reference: question.reference
            ),
            savedStreak: persistentStreak
        )
        if !carryoverQuestionIDs.contains(question.id) {
            progressStore.record(questionID: question.id, difficulty: difficulty)
        }
        GameStats.shared.recordRound(
            game: .trivia,
            difficulty: difficulty.statsDifficulty,
            correct: isCorrect ? 1 : 0,
            answered: 1,
            currentBestStreak: session.savedBestStreak
        )
        if let bookName = scriptureReference?.bookName {
            GameStats.shared.recordTriviaPerBook(
                bookName: bookName,
                answered: 1,
                correct: isCorrect ? 1 : 0
            )
        }
        if isCorrect, !reviewQuestionIDs.isEmpty {
            MissedGameQuestionStore.shared.resolveReviewQuestion(
                game: .bibleTrivia,
                questionID: String(question.id)
            )
        } else if !isCorrect {
            MissedGameQuestionStore.shared.record(
                game: .bibleTrivia,
                bookNames: scriptureReference.map { [$0.bookName] } ?? [],
                chapterNumber: scriptureReference?.chapter,
                topic: "Bible trivia",
                questionID: String(question.id)
            )
        }
    }

    private func makeRoundQuestion(_ question: BibleTriviaQuestion) -> RoundQuestion {
        let distractors = Array(Set(question.incorrectAnswers.filter { $0 != question.correctAnswer }))
        return RoundQuestion(
            question: question,
            options: (Array(distractors.shuffled().prefix(3)) + [question.correctAnswer]).shuffled()
        )
    }

    /// The question's own level, for the summary's "By Type" breakdown.
    private static func questionLevelTitle(_ level: String) -> String? {
        switch level {
        case "easy": String(localized: "Easy questions")
        case "normal": String(localized: "Normal questions")
        case "hard": String(localized: "Hard questions")
        default: nil
        }
    }

    /// Progress through this difficulty's question pool; nil for a review round.
    var poolProgress: GameRoundSummaryView.PoolProgress? {
        guard reviewQuestionIDs.isEmpty else { return nil }
        return GameRoundSummaryView.PoolProgress(
            title: String(localized: difficulty.title),
            seen: completedInPool,
            total: eligibleQuestions.count
        )
    }

    private var bestScoreKey: String {
        "\(Self.bestScoreKeyPrefix).\(difficulty.rawValue)"
    }

    private func savePersonalBest() {
        guard session.score > bestScore else { return }
        bestScore = session.score
        UserDefaults.standard.set(session.score, forKey: bestScoreKey)
        iCloudSyncCoordinator.shared.pushKey(bestScoreKey)
    }
}
