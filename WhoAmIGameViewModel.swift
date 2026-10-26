import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class WhoAmIGameViewModel {
    enum Mode: String, CaseIterable, Identifiable {
        case clueToName     // prompt: clue -> choices: names
        case nameToClue     // prompt: name -> choices: clues

        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .clueToName: "Clue → Name"
            case .nameToClue: "Name → Clue"
            }
        }

        var detail: LocalizedStringResource {
            switch self {
            case .clueToName: "Read a clue and pick the person it describes."
            case .nameToClue: "See a name and pick the clue that describes them."
            }
        }

        var icon: String {
            switch self {
            case .clueToName: "text.quote"
            case .nameToClue: "person.fill"
            }
        }
    }

    enum Difficulty: String, CaseIterable, Identifiable {
        case easy, normal, hard
        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .easy: "Easy"
            case .normal: "Normal"
            case .hard: "Hard"
            }
        }

        var timeLimit: Int {
            switch self {
            case .easy: return 0
            case .normal: return 30
            case .hard: return 15
            }
        }

        var detail: LocalizedStringResource {
            switch self {
            case .easy: "Well-known people, no timer, and curated choices."
            case .normal: "Adds less familiar people. 30 seconds and curated choices."
            case .hard: "Everyone in the game. 15 seconds and curated choices."
            }
        }

        var statsDifficulty: GameStats.Difficulty {
            switch self {
            case .easy: return .easy
            case .normal: return .normal
            case .hard: return .hard
            }
        }
    }

    struct Entry: Hashable {
        let id: Int
        let questionMode: WhoGameQuestion.Mode
        /// The name without the description in parentheses, e.g. "Joseph".
        let name: String
        /// The description in parentheses in the data, e.g. "son of Jacob". Shown only in the reveal.
        let qualifier: String?
        let clue: String
        let books: [String]
        let difficulty: String
        let incorrectAnswers: [String]

        func matchesDifficulty(_ selectedDifficulty: Difficulty) -> Bool {
            switch difficulty.lowercased() {
            case "easy": true
            case "medium", "normal": selectedDifficulty != .easy
            default: selectedDifficulty == .hard
            }
        }
    }

    static let questionsPerGame = 10

    private let reviewQuestionIDs: Set<String>

    init(reviewQuestionIDs: Set<String> = []) {
        self.reviewQuestionIDs = reviewQuestionIDs
    }
    private static let modeKey = "whoamiMode"
    private static let difficultyKey = "whoamiDifficulty"

    // Start screen state
    var started: Bool = false
    var isComplete: Bool = false
    var mode: Mode = Mode(rawValue: UserDefaults.standard.string(forKey: WhoAmIGameViewModel.modeKey) ?? "") ?? .clueToName {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Self.modeKey) }
    }
    var difficulty: Difficulty = Difficulty(rawValue: UserDefaults.standard.string(forKey: WhoAmIGameViewModel.difficultyKey) ?? "") ?? .normal {
        didSet {
            UserDefaults.standard.set(difficulty.rawValue, forKey: Self.difficultyKey)
            currentBestStreak = max(currentBestStreak, persistentStreak.best)
        }
    }

    // Data
    private(set) var entries: [Entry] = []
    private var questionQueue: [Entry] = []

    private var eligibleEntries: [Entry] {
        entries.filter {
            $0.questionMode == questionMode && $0.matchesDifficulty(difficulty)
        }
    }

    var isReady: Bool {
        reviewQuestionIDs.isEmpty ? eligibleEntries.count >= 4 : reviewEntries.count >= Self.questionsPerGame
    }

    private var reviewEntries: [Entry] {
        entries.filter {
            $0.questionMode == questionMode
                && reviewQuestionIDs.contains(String(describing: $0.id))
        }
    }

    // Current round
    private(set) var current: Entry?
    private(set) var choiceEntries: [String] = []
    var selectedChoice: String? = nil
    private(set) var questionNumber: Int = 0
    private(set) var totalQuestions: Int = 0

    var promptTitle: String {
        guard let current else { return "" }
        return mode == .clueToName ? current.clue : current.name
    }

    var choices: [String] {
        choiceEntries
    }

    var correctChoice: String {
        guard let current else { return "" }
        return mode == .clueToName ? current.name : current.clue
    }

    var isLastQuestion: Bool { questionQueue.isEmpty }

    // Timer
    var remainingSeconds: Int = 0
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    var pulseOn: Bool = false

    // Scoring
    var score: Int = 0
    var answered: Int = 0
    /// Correct answers in a row during this game.
    var sessionStreak: Int = 0
    var sessionBestStreak: Int = 0
    var currentBestStreak: Int = 0
    var bestGameScore: Int = 0
    var isNewBestGame: Bool = false

    var roundOver: Bool = false
    var wasTimedOut: Bool = false

    // MARK: - Persistent streak (per difficulty)
    private var persistentStreak: PersistentGameStreak {
        PersistentGameStreak(game: "whoami", variant: difficulty.rawValue)
    }

    private var bestGameScoreKey: String { "whoamiBestGameScore_\(difficulty.rawValue)" }

    // Load data
    func onAppear() {
        currentBestStreak = max(currentBestStreak, persistentStreak.best)

        Task {
            if entries.isEmpty {
                async let characters = GameDataLoaders.loadCharactersAsync()
                async let questions = GameDataLoaders.loadWhoQuestionsAsync()
                let charactersByID = Dictionary(
                    uniqueKeysWithValues: await characters.map { ($0.id, $0) }
                )
                self.entries = await questions.compactMap { question in
                    guard let character = charactersByID[question.sourcePersonID] else { return nil }

                    let nameAndClue: (name: String, clue: String)
                    switch question.mode {
                    case .factToPerson:
                        nameAndClue = (question.correctAnswer, question.question)
                    case .personToFact:
                        nameAndClue = (question.question, question.correctAnswer)
                    }

                    let parts = Self.split(nameAndClue.name)
                    let clue = nameAndClue.clue.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !parts.name.isEmpty, !clue.isEmpty, question.incorrectAnswers.count >= 3 else {
                        return nil
                    }

                    return Entry(
                        id: question.sourcePersonID,
                        questionMode: question.mode,
                        name: parts.name,
                        qualifier: parts.qualifier,
                        clue: clue,
                        books: character.books,
                        difficulty: question.difficulty,
                        incorrectAnswers: question.incorrectAnswers
                    )
                }
            }
        }
    }

    private var questionMode: WhoGameQuestion.Mode {
        switch mode {
        case .clueToName: .factToPerson
        case .nameToClue: .personToFact
        }
    }

    /// Removes a trailing description in parentheses: "Joseph (son of Jacob)" → ("Joseph", "son of Jacob").
    private static func split(_ name: String) -> (name: String, qualifier: String?) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let open = trimmed.firstIndex(of: "("), trimmed.hasSuffix(")") else { return (trimmed, nil) }
        let base = trimmed[..<open].trimmingCharacters(in: .whitespaces)
        let qualifier = trimmed[trimmed.index(after: open)..<trimmed.index(before: trimmed.endIndex)]
            .trimmingCharacters(in: .whitespaces)
        return (base.isEmpty ? trimmed : base, qualifier.isEmpty ? nil : qualifier)
    }

    // MARK: - Game flow

    func startGame() {
        guard isReady else { return }
        score = 0
        answered = 0
        sessionStreak = 0
        sessionBestStreak = 0
        isNewBestGame = false
        currentBestStreak = max(currentBestStreak, persistentStreak.best)
        let candidates = reviewQuestionIDs.isEmpty ? eligibleEntries : reviewEntries
        questionQueue = Array(candidates.shuffled().prefix(Self.questionsPerGame))
        totalQuestions = questionQueue.count
        questionNumber = 0
        isComplete = false
        started = true
        nextRound()
    }

    /// Moves to the next question, or to the results once all are answered.
    func nextRound() {
        stopTimer()
        guard !questionQueue.isEmpty else {
            finishGame()
            return
        }

        let target = questionQueue.removeFirst()
        current = target
        let correct = mode == .clueToName ? target.name : target.clue
        choiceEntries = (Array(target.incorrectAnswers.shuffled().prefix(3)) + [correct]).shuffled()
        questionNumber += 1
        selectedChoice = nil
        roundOver = false
        wasTimedOut = false

        remainingSeconds = difficulty.timeLimit
        if remainingSeconds > 0 {
            startTimer()
        }
    }

    func select(_ choice: String) {
        guard !roundOver else { return }
        selectedChoice = choice
        finishRound(correct: choice == correctChoice)
    }

    private func timeOut() {
        guard !roundOver else { return }
        wasTimedOut = true
        finishRound(correct: false)
    }

    private func finishRound(correct: Bool) {
        stopTimer()
        roundOver = true
        answered += 1

        if correct {
            score += 1
            sessionStreak += 1
            sessionBestStreak = max(sessionBestStreak, sessionStreak)
            // Persistent streak: extend on correct
            let streak = persistentStreak.recordWin()
            currentBestStreak = max(currentBestStreak, streak.best)
        } else {
            // Persistent streak: reset on incorrect or timeout
            sessionStreak = 0
            persistentStreak.reset()
        }

        GameStats.shared.recordRound(
            game: .whoami,
            difficulty: difficulty.statsDifficulty,
            correct: correct ? 1 : 0,
            answered: 1,
            currentBestStreak: currentBestStreak
        )
        if correct, !reviewQuestionIDs.isEmpty, let current {
            MissedGameQuestionStore.shared.resolveReviewQuestion(
                game: .whoAmI,
                questionID: String(describing: current.id)
            )
        } else if !correct, let current {
            MissedGameQuestionStore.shared.record(
                game: .whoAmI,
                bookNames: current.books,
                topic: "Bible people",
                questionID: String(describing: current.id)
            )
        }
    }

    private func finishGame() {
        let previousBest = UserDefaults.standard.integer(forKey: bestGameScoreKey)
        isNewBestGame = score > previousBest
        bestGameScore = max(previousBest, score)
        if isNewBestGame {
            UserDefaults.standard.set(score, forKey: bestGameScoreKey)
        }
        current = nil
        isComplete = true
    }

    /// Back to the start screen, e.g. from the results or when leaving mid-game.
    func returnToSetup() {
        stopTimer()
        questionQueue = []
        current = nil
        choiceEntries = []
        selectedChoice = nil
        remainingSeconds = 0
        roundOver = false
        isComplete = false
        started = false
    }

    func endRoundWhenLeavingScreen() {
        guard started, answered > 0 else { return }
        returnToSetup()
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        guard remainingSeconds > 0 else { return }
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                self.tickTimer()
            }
        }
    }

    private func tickTimer() {
        guard !roundOver else { return }
        if remainingSeconds > 0 {
            remainingSeconds -= 1
            if remainingSeconds <= 5 {
                withAnimation(.easeInOut(duration: 0.25)) { pulseOn.toggle() }
                Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(250))
                    self?.pulseOn = false
                }
            }
        }
        if remainingSeconds == 0 {
            timeOut()
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
        pulseOn = false
    }
}
