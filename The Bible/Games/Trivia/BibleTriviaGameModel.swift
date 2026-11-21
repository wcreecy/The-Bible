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
    /// A practice round on one book can be shorter, but not shorter than this.
    private static let minimumBookRoundQuestions = 5
    private static let bestScoreKeyPrefix = "bibleTriviaBestScore"

    private let reviewQuestionIDs: Set<String>
    /// Where missed questions are recorded; tests pass a store that never touches disk or iCloud.
    private let missedQuestions: MissedGameQuestionStore
    /// Waits between timer ticks; tests pass a manual clock.
    @ObservationIgnored private let sleep: (Duration) async throws -> Void
    /// The current time for the question clock; tests pass the manual clock's time.
    @ObservationIgnored private let now: () -> Date
    /// Loads the passage a question cites; tests pass a fixed passage.
    @ObservationIgnored private let loadPassageForReference: (String) async -> GamePassage?

    /// The stores, clock and Bible text default to the real ones. They're resolved here rather
    /// than as default arguments, which would be evaluated outside the main actor.
    init(
        reviewQuestionIDs: Set<String> = [],
        missedQuestions: MissedGameQuestionStore? = nil,
        progressStore: BibleTriviaProgressStore? = nil,
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        now: @escaping () -> Date = Date.init,
        loadPassage: ((String) async -> GamePassage?)? = nil
    ) {
        self.reviewQuestionIDs = reviewQuestionIDs
        self.missedQuestions = missedQuestions ?? .shared
        self.progressStore = progressStore ?? .shared
        self.sleep = sleep
        self.now = now
        self.loadPassageForReference = loadPassage ?? { await GamePassage.load(for: $0) }
    }

    private struct RoundQuestion: Identifiable {
        let question: BibleTriviaQuestion
        let options: [String]
        var selectedAnswer: String?
        var timedOut = false
        /// Wrong answers taken away by 50/50.
        var removedOptions: Set<String> = []
        var lifelinesUsed: Set<BibleTriviaLifeline> = []
        var bonusSeconds = 0
        /// The timer was off at some point, so the answer can't earn a speed bonus.
        var wasTimerOff = false
        var earnedSpeedBonus = false

        var id: Int { question.id }
        var isAnswered: Bool { selectedAnswer != nil || timedOut }
    }

    var phase: Phase = .loading
    /// Saved like the other games' difficulty, so Trivia opens on the last one played.
    var difficulty: BibleTriviaDifficulty = BibleTriviaDifficulty(
        rawValue: UserDefaults.standard.string(forKey: AppStorageKey.triviaDifficulty) ?? ""
    ) ?? .normal {
        didSet {
            UserDefaults.standard.set(difficulty.rawValue, forKey: AppStorageKey.triviaDifficulty)
            session.syncSavedBest(from: persistentStreak)
        }
    }
    var topic: BibleTriviaTopic = BibleTriviaTopic(
        rawValue: UserDefaults.standard.string(forKey: AppStorageKey.triviaTopic) ?? ""
    ) ?? .mixed {
        didSet { UserDefaults.standard.set(topic.rawValue, forKey: AppStorageKey.triviaTopic) }
    }
    private(set) var questions: [BibleTriviaQuestion] = []
    /// Each question's book, worked out once when the catalog loads.
    @ObservationIgnored private var bookNames: [Int: String] = [:]
    private var round: [RoundQuestion] = []
    private var carryoverQuestionIDs: Set<Int> = []
    /// Set for a practice round on the book missed most, which doesn't count toward the pool.
    private(set) var practiceBook: String?
    private(set) var currentIndex = 0
    /// Score and streaks; see `GameScore` for the rules. Trivia keeps its own best score below.
    private(set) var session = GameScore()
    private(set) var bestScore = 0
    private(set) var remainingSeconds = 0
    var isTimerDisabled = false
    /// True while the question is paused: the timer stops and the question is hidden.
    private(set) var isPaused = false
    /// The current question's passage, once loaded.
    private(set) var passage: GamePassage?
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    /// Time spent on the current question; the countdown is worked out from it.
    @ObservationIgnored private var questionClock = GameActiveClock()

    let progressStore: BibleTriviaProgressStore

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

    var removedOptions: Set<String> {
        currentRoundQuestion?.removedOptions ?? []
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

    var earnedSpeedBonus: Bool {
        currentRoundQuestion?.earnedSpeedBonus ?? false
    }

    /// Speed bonuses earned this round: a correct answer in the first third of the time.
    var speedBonusCount: Int {
        round.count { $0.earnedSpeedBonus }
    }

    /// Correct answers plus speed bonuses.
    var points: Int {
        session.score + speedBonusCount
    }

    /// The question's full time, plus any extra time added.
    var currentTimeLimit: Int {
        difficulty.timerSeconds + (currentRoundQuestion?.bonusSeconds ?? 0)
    }

    private func bookName(of question: BibleTriviaQuestion) -> String? {
        bookNames[question.id] ?? question.bookName
    }

    var eligibleQuestions: [BibleTriviaQuestion] {
        if !reviewQuestionIDs.isEmpty {
            return questions.filter { reviewQuestionIDs.contains(String($0.id)) }
        }
        if let practiceBook {
            let inBook = questions.filter { bookName(of: $0) == practiceBook }
            // A small book may need questions from every level to fill a round.
            let atLevel = inBook.filter(difficulty.includes)
            return atLevel.count >= Self.minimumBookRoundQuestions ? atLevel : inBook
        }
        return questions.filter { difficulty.includes($0) && topic.includes(bookName: bookName(of: $0)) }
    }

    /// Questions from this topic and level already asked in the current pass through the pool.
    var completedInPool: Int {
        let completed = progressStore.progress(for: difficulty).completedQuestionIDs
        return eligibleQuestions.count { completed.contains($0.id) }
    }

    var accuracy: Int {
        guard session.answered > 0 else { return 0 }
        return Int((Double(session.score) / Double(session.answered) * 100).rounded())
    }

    var isLastQuestion: Bool {
        currentIndex == round.count - 1
    }

    var canGoNext: Bool {
        isAnswered
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
        bookNames = Dictionary(uniqueKeysWithValues: loadedQuestions.compactMap { question in
            question.bookName.map { (question.id, $0) }
        })
        phase = .setup
    }

    /// Starts a round from the chosen level and topic. A practice round on one book ends here.
    func startRound() {
        practiceBook = nil
        beginRound()
    }

    private func beginRound() {
        let eligible = eligibleQuestions
        let roundSize = practiceBook == nil ? Self.questionsPerRound : min(Self.questionsPerRound, eligible.count)
        guard eligible.count >= roundSize, roundSize >= Self.minimumBookRoundQuestions else {
            phase = .unavailable
            return
        }

        round = selectRoundQuestions(from: eligible, count: roundSize).map(makeRoundQuestion)
        guard round.count == roundSize else {
            phase = .unavailable
            return
        }

        currentIndex = 0
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
    /// The pool is kept per level, so finishing one topic's questions restarts that level's pool.
    /// Review and book practice rounds pick at random and leave the pool alone.
    private func selectRoundQuestions(from eligible: [BibleTriviaQuestion], count: Int) -> [BibleTriviaQuestion] {
        carryoverQuestionIDs = []
        guard reviewQuestionIDs.isEmpty, practiceBook == nil else {
            return Array(eligible.shuffled().prefix(count))
        }

        let completed = progressStore.progress(for: difficulty).completedQuestionIDs
        var selected = Array(eligible.filter { !completed.contains($0.id) }.shuffled().prefix(count))
        guard selected.count < count else { return selected }

        // Leftovers belong to the finished cycle, so they aren't recorded against the new one.
        carryoverQuestionIDs = Set(selected.map(\.id))
        progressStore.resetCompletedPool(for: difficulty)
        let refill = eligible.filter { !carryoverQuestionIDs.contains($0.id) }.shuffled()
        selected += refill.prefix(count - selected.count)
        return selected.shuffled()
    }

    func choose(_ answer: String) {
        guard !isPaused, !isAnswered, options.contains(answer), !removedOptions.contains(answer),
              let question = currentQuestion else { return }
        finishAnswer(answer, question: question)
    }

    func advance() {
        guard canGoNext else { return }
        if isLastQuestion {
            session.endGame()
            savePersonalBest()
            phase = .results
        } else {
            currentIndex += 1
            prepareCurrentQuestion()
        }
    }

    /// Back to the start screen. The streak is kept so the next game can continue it.
    func returnToSetup() {
        timerTask?.cancel()
        questionClock.pause(at: now())
        isPaused = false
        phase = .setup
        round = []
        practiceBook = nil
        passage = nil
        currentIndex = 0
        session.clearGame()
    }

    func onDisappear() {
        // Every Trivia level is timed, so leaving mid-question counts as running out of time.
        // Backing out can't be used to skip a hard question and keep the streak.
        if phase == .playing, !isAnswered, let question = currentQuestion {
            finishAnswer(nil, question: question)
        }
        // Leaving after answering begins a new game on return.
        if (phase == .playing || phase == .results) && session.answered > 0 {
            returnToSetup()
        }
        session.clearStreak()
    }

    private func prepareCurrentQuestion() {
        passage = nil
        guard !isAnswered else { return }
        remainingSeconds = difficulty.timerSeconds
        session.startQuestion()
        isPaused = false
        questionClock.start(at: now())
        if isTimerDisabled {
            questionClock.pause(at: now())
            round[currentIndex].wasTimerOff = true
        }
        startTimer()
    }

    // MARK: - Practicing a book

    /// The book with the most misses this round, when it has enough questions for a practice round.
    var bookToPractice: String? {
        // Only books with enough questions for a round can be practiced.
        let missedBooks = session.entries
            .filter { $0.outcome != .correct }
            .compactMap(\.bookName)
            .filter { book in questions.count { bookName(of: $0) == book } >= Self.minimumBookRoundQuestions }
        let counts = Dictionary(missedBooks.map { ($0, 1) }, uniquingKeysWith: +)
        // Most misses first; ties go to the book missed first.
        return missedBooks.first { counts[$0] == counts.values.max() }
    }

    /// A round of up to ten questions from one book, at this level when it has enough.
    func practice(book: String) {
        practiceBook = book
        beginRound()
    }

    // MARK: - Lifelines

    /// Lifelines already used this round; each can be used once.
    var usedLifelines: Set<BibleTriviaLifeline> {
        round.reduce(into: []) { $0.formUnion($1.lifelinesUsed) }
    }

    func canUse(_ lifeline: BibleTriviaLifeline) -> Bool {
        guard phase == .playing, !isPaused, !isAnswered, !usedLifelines.contains(lifeline) else { return false }
        switch lifeline {
        case .fiftyFifty:
            return options.count - removedOptions.count > 2
        case .verseHint:
            return passage != nil
        case .extraTime:
            return difficulty != .easy && !isTimerDisabled
        }
    }

    /// Whether the player can use this lifeline in this kind of game at all, used or not.
    func offers(_ lifeline: BibleTriviaLifeline) -> Bool {
        lifeline != .extraTime || difficulty != .easy
    }

    func use(_ lifeline: BibleTriviaLifeline) {
        guard canUse(lifeline), let question = currentQuestion else { return }
        round[currentIndex].lifelinesUsed.insert(lifeline)
        switch lifeline {
        case .fiftyFifty:
            let wrong = options.filter { $0 != question.correctAnswer }.shuffled()
            round[currentIndex].removedOptions = Set(wrong.prefix(2))
        case .verseHint:
            break
        case .extraTime:
            round[currentIndex].bonusSeconds += BibleTriviaLifeline.extraSeconds
            updateRemainingSeconds()
        }
    }

    var isVerseHintShown: Bool {
        currentRoundQuestion?.lifelinesUsed.contains(.verseHint) ?? false
    }

    /// Before answering, the verse hint with the answer blanked out; after, the passage in full.
    var displayedVerse: GameVerse? {
        guard let passage, let question = currentQuestion else { return nil }
        if isAnswered {
            return GameVerse(text: passage.text, reference: passage.title, isClue: false)
        }
        guard isVerseHintShown, let opening = passage.verses.first else { return nil }
        return GameVerse(
            text: Self.blankingOut(question.correctAnswer, in: opening.text),
            reference: "\(passage.bookName) \(passage.chapter):\(opening.number)",
            isClue: true
        )
    }

    /// `text` with the answer blanked out, along with each of its longer words, so the hint
    /// doesn't give it away. "Forty days" blanks "forty" and "days" wherever they appear.
    static func blankingOut(_ answer: String, in text: String) -> String {
        let skipped: Set<String> = ["the", "and", "of", "his", "her", "a", "an", "to", "in"]
        let words = answer.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count >= 3 && !skipped.contains($0.lowercased()) }
        var result = text
        for phrase in [answer] + words {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: phrase) + "\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            for match in regex.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed() {
                guard let range = Range(match.range, in: result) else { continue }
                // Letters only, so a phrase keeps its spaces: "Forty days" becomes "_____ ____".
                let blanked = String(result[range].map { $0.isLetter || $0.isNumber ? "_" : $0 })
                result.replaceSubrange(range, with: blanked)
            }
        }
        return result
    }

    // MARK: - Passages

    /// Loads the current question's passage, for the verse hint and for after answering.
    func loadPassage() async {
        guard let question = currentQuestion, passage == nil else { return }
        let loaded = await loadPassageForReference(question.reference)
        // The player may have moved on while the Bible loaded.
        guard currentQuestion?.id == question.id else { return }
        passage = loaded
    }

    // MARK: - Pausing

    /// Only a question with its timer running can be paused. With "Timer Off" the question
    /// stays on screen and untimed, so there's nothing to pause.
    var canPause: Bool {
        phase == .playing && !isTimerDisabled && !isAnswered && !isPaused
    }

    /// Stops the clock and hides the question until `resume()`.
    func pause() {
        guard canPause else { return }
        isPaused = true
        questionClock.pause(at: now())
        timerTask?.cancel()
    }

    /// Carries on from the time already used.
    func resume() {
        guard isPaused else { return }
        isPaused = false
        questionClock.resume(at: now())
        startTimer()
    }

    private func updateRemainingSeconds() {
        remainingSeconds = max(0, currentTimeLimit - Int(questionClock.elapsed(at: now())))
    }

    /// Updates the countdown from the question clock. The clock is the authority, so pausing
    /// and resuming can't give back part of a second; the short interval only keeps the display current.
    private func startTimer() {
        timerTask?.cancel()
        guard !isTimerDisabled, !isPaused else { return }
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await self?.sleep(.milliseconds(100))
                guard let self, !Task.isCancelled, !self.isAnswered, !self.isPaused else { return }
                self.updateRemainingSeconds()
                if self.remainingSeconds == 0 {
                    if let question = self.currentQuestion {
                        self.finishAnswer(nil, question: question)
                    }
                    return
                }
            }
        }
    }

    func toggleTimer() {
        isTimerDisabled.toggle()
        if isTimerDisabled {
            session.noteTimerTurnedOff()
            questionClock.pause(at: now())
            if round.indices.contains(currentIndex) {
                round[currentIndex].wasTimerOff = true
            }
        } else if !isAnswered {
            questionClock.resume(at: now())
        }
        if !isTimerDisabled, !isAnswered {
            startTimer()
        } else {
            timerTask?.cancel()
        }
    }

    private func finishAnswer(_ answer: String?, question: BibleTriviaQuestion) {
        guard !isAnswered else { return }
        timerTask?.cancel()
        questionClock.pause(at: now())
        round[currentIndex].selectedAnswer = answer
        round[currentIndex].timedOut = answer == nil
        let isCorrect = answer == question.correctAnswer
        if isCorrect { Haptics.success() } else if answer == nil { Haptics.warning() } else { Haptics.error() }
        // A quick answer with the timer on the whole time earns a bonus point.
        round[currentIndex].earnedSpeedBonus = isCorrect && !round[currentIndex].wasTimerOff
            && questionClock.elapsed(at: now()) <= Double(difficulty.timerSeconds) / 3
        let book = bookName(of: question)
        let scriptureReference = BibleReferenceLinker.parse(question.reference)
        session.record(
            GameRoundEntry(
                prompt: question.question,
                outcome: isCorrect ? .correct : (answer == nil ? .timedOut : .wrong),
                givenAnswer: answer,
                correctAnswer: question.correctAnswer,
                category: Self.questionLevelTitle(question.difficulty),
                bookName: book,
                reference: question.reference,
                hintCount: round[currentIndex].lifelinesUsed.count
            ),
            savedStreak: persistentStreak
        )
        if !carryoverQuestionIDs.contains(question.id), practiceBook == nil {
            progressStore.record(questionID: question.id, difficulty: difficulty)
        }
        GameStats.shared.recordRound(
            game: .trivia,
            difficulty: difficulty.statsDifficulty,
            correct: isCorrect ? 1 : 0,
            answered: 1,
            currentBestStreak: session.savedBestStreak
        )
        if let book {
            GameStats.shared.recordTriviaPerBook(
                bookName: book,
                answered: 1,
                correct: isCorrect ? 1 : 0
            )
        }
        if isCorrect, !reviewQuestionIDs.isEmpty {
            missedQuestions.resolveReviewQuestion(
                game: .bibleTrivia,
                questionID: String(question.id)
            )
        } else if !isCorrect {
            missedQuestions.record(
                game: .bibleTrivia,
                bookNames: book.map { [$0] } ?? [],
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

    /// Progress through this level and topic's question pool; nil for a review or practice round.
    var poolProgress: GameRoundSummaryView.PoolProgress? {
        guard reviewQuestionIDs.isEmpty, practiceBook == nil else { return nil }
        let title = topic == .mixed
            ? String(localized: difficulty.title)
            : "\(String(localized: difficulty.title)) · \(String(localized: topic.title))"
        return GameRoundSummaryView.PoolProgress(
            title: title,
            seen: completedInPool,
            total: eligibleQuestions.count
        )
    }

    /// How the points add up, for the summary. Nil when there were no bonuses.
    var roundPoints: RoundPoints? {
        RoundPoints(correct: session.score, bonuses: [RoundPoints.speed(speedBonusCount)])
    }

    private var bestScoreKey: String {
        "\(Self.bestScoreKeyPrefix).\(difficulty.rawValue)"
    }

    private func savePersonalBest() {
        // The best is in points, so bonuses count toward it.
        guard points > bestScore else { return }
        bestScore = points
        UserDefaults.standard.set(points, forKey: bestScoreKey)
        iCloudSyncCoordinator.shared.pushKey(bestScoreKey)
    }
}
