import Foundation
import Observation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

enum QuizDifficulty: String, CaseIterable, Identifiable {
    case easy
    case normal
    case hard

    /// Seconds the previous verse costs on a timed difficulty.
    static let contextCost = 3

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .easy: "Easy"
        case .normal: "Normal"
        case .hard: "Hard"
        }
    }

    /// Seconds per verse, or nil for no time limit.
    var timeLimit: Int? {
        switch self {
        case .easy: nil
        case .normal: 15
        case .hard: 12
        }
    }

    /// Seconds the previous verse costs; free when there's no timer.
    var contextCost: Int { timeLimit == nil ? 0 : Self.contextCost }

    var detail: LocalizedStringResource {
        switch self {
        case .easy:
            "No time limit. Wrong choices come from other parts of the Bible."
        case .normal:
            "15 seconds per verse. Wrong choices come from anywhere in your categories."
        case .hard:
            "12 seconds per verse. Wrong choices come from the same part of the Bible, such as all four Gospels."
        }
    }

    var statsDifficulty: GameStats.Difficulty {
        switch self {
        case .easy: .easy
        case .normal: .normal
        case .hard: .hard
        }
    }

    var experienceLevel: GameExperienceLevel {
        switch self {
        case .easy: .learn
        case .normal: .standard
        case .hard: .challenge
        }
    }

    init(experienceLevel: GameExperienceLevel) {
        self = switch experienceLevel {
        case .learn: .easy
        case .standard: .normal
        case .challenge: .hard
        }
    }
}

/// Parts of the Bible a verse can be drawn from. Also used by Hangman and Verse Match.
enum QuizVerseSection: String, CaseIterable, Identifiable {
    case law
    case history
    case poetry
    case majorProphets
    case minorProphets
    case gospels
    case acts
    case epistles
    // Stored as "apocalypse" in existing settings.
    case revelation = "apocalypse"

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .law: "Law"
        case .history: "History"
        case .poetry: "Poetry"
        case .majorProphets: "Major Prophets"
        case .minorProphets: "Minor Prophets"
        case .gospels: "Gospels"
        case .acts: "Acts"
        case .epistles: "Epistles"
        case .revelation: "Revelation"
        }
    }

    var isOldTestament: Bool {
        switch self {
        case .law, .history, .poetry, .majorProphets, .minorProphets: true
        case .gospels, .acts, .epistles, .revelation: false
        }
    }

    /// Positions in the 66-book canon.
    private var canonRange: Range<Int> {
        switch self {
        case .law: 0..<5
        case .history: 5..<17
        case .poetry: 17..<22
        case .majorProphets: 22..<27
        case .minorProphets: 27..<39
        case .gospels: 39..<43
        case .acts: 43..<44
        case .epistles: 44..<65
        case .revelation: 65..<66
        }
    }

    var bookNames: [String] { Array(BibleCanon.fallbackCanon[canonRange]) }

    /// Hard draws wrong choices from these sections. Acts and Revelation are single
    /// books, so they share with their closest neighbors.
    var hardFamily: [QuizVerseSection] {
        switch self {
        case .acts: [.gospels, .acts]
        case .revelation: [.epistles, .revelation]
        default: [self]
        }
    }

    static func containing(_ bookName: String) -> QuizVerseSection? {
        allCases.first { $0.bookNames.contains(bookName) }
    }
}

enum QuizOutcome {
    case correct
    case incorrect
    case timedOut

    var title: LocalizedStringKey {
        switch self {
        case .correct: "Correct"
        case .incorrect: "Incorrect"
        case .timedOut: "Time’s Up"
        }
    }

    var systemImage: String {
        switch self {
        case .correct: "checkmark.circle.fill"
        case .incorrect: "xmark.circle.fill"
        case .timedOut: "hourglass.bottomhalf.filled"
        }
    }

    var tint: Color {
        self == .correct ? .green : .red
    }
}

struct QuizQuestion: Identifiable {
    let id = UUID()
    let verseText: String
    let correctBook: String
    let chapter: Int
    let verse: Int
    /// The verse before this one, offered as a hint.
    let contextText: String?
    let options: [String]
    var selected: String?
    var outcome: QuizOutcome?
    var contextRevealed = false

    /// Identifies the verse for missed-question review.
    var reviewID: String { "\(correctBook)|\(chapter)|\(verse)" }
}

@MainActor
@Observable
final class QuizGameViewModel {
    enum Phase {
        case setup
        case playing
        case results
    }

    private struct VerseCandidate {
        let text: String
        let bookName: String
        let chapter: Int
        let verse: Int
        let contextText: String?

        var reviewID: String { "\(bookName)|\(chapter)|\(verse)" }
    }

    static let questionsPerGame = 10

    private static let difficultyKey = AppStorageKey.quizDifficulty
    private static let sectionsKey = AppStorageKey.quizSections
    /// Replaced by the category quick picks; read once to carry an old choice over.
    private static let legacyScopeKey = AppStorageKey.quizScope

    /// Verses to replay from the missed-questions list; empty for a normal game.
    let reviewQuestionIDs: Set<String>

    init(reviewQuestionIDs: Set<String> = []) {
        self.reviewQuestionIDs = reviewQuestionIDs
    }

    // MARK: - Settings

    var difficulty: QuizDifficulty = QuizDifficulty(
        rawValue: UserDefaults.standard.string(forKey: QuizGameViewModel.difficultyKey) ?? ""
    ) ?? .normal {
        didSet {
            UserDefaults.standard.set(difficulty.rawValue, forKey: Self.difficultyKey)
            session.syncSavedBest(from: persistentStreak)
        }
    }

    var experienceLevel: GameExperienceLevel {
        get { difficulty.experienceLevel }
        set { difficulty = QuizDifficulty(experienceLevel: newValue) }
    }

    private var sectionsRaw: String = UserDefaults.standard.string(forKey: QuizGameViewModel.sectionsKey) ?? "" {
        didSet { UserDefaults.standard.set(sectionsRaw, forKey: Self.sectionsKey) }
    }

    private var storedSections: Set<QuizVerseSection> {
        Set(sectionsRaw.split(separator: ",").compactMap { QuizVerseSection(rawValue: String($0)) })
    }

    /// The chosen categories. An empty stored selection means every category, and
    /// clearing every category is ignored.
    var selectedSections: Set<QuizVerseSection> {
        get { storedSections.isEmpty ? Set(QuizVerseSection.allCases) : storedSections }
        set {
            guard !newValue.isEmpty else { return }
            if newValue == Set(QuizVerseSection.allCases) {
                sectionsRaw = ""
            } else {
                sectionsRaw = QuizVerseSection.allCases
                    .filter { newValue.contains($0) }
                    .map(\.rawValue)
                    .joined(separator: ",")
            }
        }
    }

    private var poolBookNames: Set<String> {
        Set(selectedSections.flatMap(\.bookNames))
    }

    // MARK: - Game state

    private(set) var phase: Phase = .setup
    private(set) var isFilterReady = QuizVerseFilter.isReady
    private var questionBag: [VerseCandidate] = []
    private(set) var history: [QuizQuestion] = []
    private(set) var currentIndex: Int = -1
    private(set) var totalQuestions: Int = 0

    /// Score, streaks and best game; see `GameScore` for the rules.
    private(set) var session = GameScore()

    // Timer
    private(set) var remainingSeconds: Int = 0 {
        didSet { updateRedZone() }
    }
    /// Changes whenever the countdown should restart, so the view can restart its timer task.
    private(set) var timerID: Int = 0
    private(set) var isTimerDisabled = false
    private(set) var isPulsing = false
    private var wasInRedZone = false
    private var pulseTask: Task<Void, Never>?

    // MARK: - Derived state

    private var persistentStreak: PersistentGameStreak {
        PersistentGameStreak(game: "quiz", variant: difficulty.rawValue)
    }

    private var bestGameScoreKey: String { "quizBestGameScore_\(difficulty.rawValue)" }

    var current: QuizQuestion? {
        history.indices.contains(currentIndex) ? history[currentIndex] : nil
    }

    var isViewingPrevious: Bool { currentIndex < history.count - 1 }

    var isAnswered: Bool { current?.outcome != nil }

    var isTimed: Bool { difficulty.timeLimit != nil }

    var isTimerRunning: Bool {
        phase == .playing && isTimed && !isTimerDisabled && !isViewingPrevious && !isAnswered
    }

    var canGoPrevious: Bool {
        currentIndex > 0 && (isAnswered || isViewingPrevious || !isTimed)
    }

    var canGoNext: Bool { isViewingPrevious || isAnswered }

    var isOnLastQuestion: Bool { !isViewingPrevious && history.count >= totalQuestions }

    var canRevealContext: Bool {
        guard let current, current.contextText != nil, !current.contextRevealed,
              !isAnswered, !isViewingPrevious else { return false }
        return !isTimed || isTimerDisabled || remainingSeconds > difficulty.contextCost
    }

    var progressText: String {
        String(localized: "Question \(currentIndex + 1) of \(totalQuestions)")
    }

    /// Green, then yellow, then red as the question runs down, scaled to the time limit.
    var timerColor: Color {
        guard let timeLimit = difficulty.timeLimit else { return .secondary }
        let fraction = Double(remainingSeconds) / Double(max(1, timeLimit))
        if fraction <= 0.3 { return .red }
        if fraction <= 0.6 { return .yellow }
        return .green
    }

    // MARK: - Lifecycle

    func onAppear() {
        migrateLegacyScope()
        session.syncSavedBest(from: persistentStreak)
    }

    /// Sorts out list and repeated verses while the start screen is showing.
    func prepareFilter() async {
        await QuizVerseFilter.prepare()
        isFilterReady = true
    }

    func onDisappear() {
        // Leaving after answering begins a new game on return.
        if phase != .setup && session.answered > 0 {
            resetToSetup()
        }
        session.clearStreak()
    }

    /// Counts down the current question. Run from a task keyed on `timerID` so each
    /// question restarts it and the first second is a full second.
    func runTimer() async {
        while !Task.isCancelled, isTimerRunning, remainingSeconds > 0 {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, isTimerRunning else { return }
            remainingSeconds -= 1
            if remainingSeconds == 0 {
                finishQuestion(.timedOut, selected: nil)
            }
        }
    }

    /// The Testament picker was folded into the categories; apply an old choice once.
    private func migrateLegacyScope() {
        let defaults = UserDefaults.standard
        let legacyScope = defaults.string(forKey: Self.legacyScopeKey) ?? "whole"
        guard legacyScope == "old" || legacyScope == "new" else { return }
        let testamentSections = Set(QuizVerseSection.allCases.filter { $0.isOldTestament == (legacyScope == "old") })
        let kept = storedSections.intersection(testamentSections)
        selectedSections = kept.isEmpty ? testamentSections : kept
        defaults.set("whole", forKey: Self.legacyScopeKey)
    }

    // MARK: - Questions

    private func buildQuestionBag() -> [VerseCandidate] {
        let pool = poolBookNames
        let difficultyKey = reviewQuestionIDs.isEmpty ? difficulty.rawValue : QuizDifficulty.hard.rawValue
        return BibleData.books
            .filter { pool.contains($0.name) }
            .flatMap { book in
                book.chapters.flatMap { chapter in
                    chapter.verses.indices.compactMap { index -> VerseCandidate? in
                        let verse = chapter.verses[index]
                        guard QuizVerseFilter.isQuizzable(
                            book: book.name,
                            chapter: chapter.number,
                            verse: verse.number,
                            difficulty: difficultyKey
                        ) else { return nil }
                        return VerseCandidate(
                            text: verse.text,
                            bookName: book.name,
                            chapter: chapter.number,
                            verse: verse.number,
                            contextText: index > 0 ? chapter.verses[index - 1].text : nil
                        )
                    }
                }
            }
            .shuffled()
    }

    /// Picks three wrong books, drawing from each list in turn until there are enough.
    private func wrongChoices(for correctBook: String) -> [String] {
        let canon = BibleCanon.fallbackCanon
        let pool = poolBookNames
        let section = QuizVerseSection.containing(correctBook)
        let isOld = section?.isOldTestament ?? true
        let sameTestament = canon.filter { QuizVerseSection.containing($0)?.isOldTestament == isOld }

        let tiers: [[String]]
        switch difficulty {
        case .easy:
            let otherSections = canon.filter { QuizVerseSection.containing($0) != section }
            tiers = [otherSections.filter(pool.contains), otherSections]
        case .normal:
            tiers = [canon.filter(pool.contains), sameTestament, canon]
        case .hard:
            let family = Set((section?.hardFamily ?? []).flatMap(\.bookNames))
            tiers = [
                canon.filter { family.contains($0) && pool.contains($0) },
                canon.filter(family.contains),
                sameTestament
            ]
        }

        var picks: [String] = []
        for tier in tiers {
            for name in tier.shuffled() where picks.count < 3 && name != correctBook && !picks.contains(name) {
                picks.append(name)
            }
        }
        return picks
    }

    private func makeQuestion() -> QuizQuestion? {
        guard let candidate = questionBag.popLast() else { return nil }
        return QuizQuestion(
            verseText: candidate.text,
            correctBook: candidate.bookName,
            chapter: candidate.chapter,
            verse: candidate.verse,
            contextText: candidate.contextText,
            options: (wrongChoices(for: candidate.bookName) + [candidate.bookName]).shuffled()
        )
    }

    // MARK: - Game flow

    func startQuiz() {
        guard isFilterReady else { return }
        questionBag = buildQuestionBag()
        if !reviewQuestionIDs.isEmpty {
            questionBag = questionBag.filter { reviewQuestionIDs.contains($0.reviewID) }
        }
        guard !questionBag.isEmpty else { return }
        totalQuestions = min(Self.questionsPerGame, questionBag.count)
        history = []
        currentIndex = -1
        session.beginGame(savedStreak: persistentStreak)
        isTimerDisabled = false
        phase = .playing
        appendNextQuestion()
    }

    private func appendNextQuestion() {
        guard let question = makeQuestion() else {
            showResults()
            return
        }
        history.append(question)
        currentIndex = history.count - 1
        remainingSeconds = difficulty.timeLimit ?? 0
        wasInRedZone = false
        stopTimerPulse()
        timerID += 1
    }

    private func showResults() {
        session.finishGame(bestScoreKey: bestGameScoreKey)
        phase = .results
    }

    func resetToSetup() {
        phase = .setup
        history = []
        currentIndex = -1
        questionBag = []
        remainingSeconds = 0
        session.clearGame()
    }

    func showPrevious() {
        guard canGoPrevious else { return }
        currentIndex -= 1
    }

    func showNext() {
        if isViewingPrevious {
            currentIndex += 1
        } else if history.count >= totalQuestions {
            showResults()
        } else {
            appendNextQuestion()
        }
    }

    func revealContext() {
        guard canRevealContext else { return }
        history[currentIndex].contextRevealed = true
        if !isTimerDisabled {
            remainingSeconds -= difficulty.contextCost
        }
    }

    func toggleTimer() {
        guard isTimed else { return }
        isTimerDisabled.toggle()
        stopTimerPulse()
        timerID += 1
    }

    func selectOption(_ name: String) {
        guard let current else { return }
        finishQuestion(name == current.correctBook ? .correct : .incorrect, selected: name)
    }

    /// Records the answer (or timeout) on the latest question, so it can't be answered again.
    private func finishQuestion(_ outcome: QuizOutcome, selected: String?) {
        guard phase == .playing, !isViewingPrevious, let current, current.outcome == nil else { return }
        history[currentIndex].outcome = outcome
        history[currentIndex].selected = selected
        stopTimerPulse()

        let correct = outcome == .correct
        session.record(correct: correct, savedStreak: persistentStreak)

        GameStats.shared.recordRound(
            game: .quiz,
            difficulty: difficulty.statsDifficulty,
            correct: correct ? 1 : 0,
            answered: 1,
            currentBestStreak: session.savedBestStreak
        )
        GameStats.shared.recordQuizPerBook(bookName: current.correctBook, answered: 1, correct: correct ? 1 : 0)
        if correct, !reviewQuestionIDs.isEmpty {
            MissedGameQuestionStore.shared.resolveReviewQuestion(
                game: .bibleQuiz,
                questionID: current.reviewID
            )
        } else if !correct {
            MissedGameQuestionStore.shared.record(
                game: .bibleQuiz,
                bookNames: [current.correctBook],
                chapterNumber: current.chapter,
                topic: "Book identification",
                questionID: current.reviewID
            )
        }

        #if canImport(UIKit)
        switch outcome {
        case .correct: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .incorrect: UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .timedOut: UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        #endif
    }

    // MARK: - Timer pulse

    /// Starts the pulse the moment a running timer crosses into the red zone.
    private func updateRedZone() {
        guard isTimerRunning else { return }
        let inRed = timerColor == .red
        if inRed && !wasInRedZone {
            startTimerPulse()
        }
        wasInRedZone = inRed
    }

    /// Flashes the timer when it enters the red zone. The task is cancelled when the question
    /// ends or the timer is reset, so a late toggle can't leave the timer lit.
    private func startTimerPulse() {
        pulseTask?.cancel()
        pulseTask = Task { @MainActor in
            for _ in 0..<6 {
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    isPulsing.toggle()
                }
                try? await Task.sleep(for: .milliseconds(250))
            }
            guard !Task.isCancelled else { return }
            isPulsing = false
        }
    }

    private func stopTimerPulse() {
        pulseTask?.cancel()
        pulseTask = nil
        isPulsing = false
    }
}
