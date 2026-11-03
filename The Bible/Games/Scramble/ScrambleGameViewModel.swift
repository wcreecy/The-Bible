import SwiftUI

/// The state and rules of a Scramble game. `ScrambleGameView` lays it out.
@MainActor
@Observable
final class ScrambleGameViewModel {
    typealias Difficulty = ScrambleGameView.Difficulty
    typealias SessionLength = ScrambleGameView.SessionLength

    enum Phase {
        case setup
        case playing
        case results
    }

    struct ScrambleWord: Identifiable {
        enum Level: Int {
            case easy
            case normal
            case hard

            init?(difficulty: String) {
                switch difficulty.lowercased() {
                case "easy": self = .easy
                case "normal", "medium": self = .normal
                case "hard": self = .hard
                default: return nil
                }
            }
        }

        let answer: String
        let category: LocalizedStringKey
        /// The category as plain text, for the round summary.
        let categoryName: String
        let reference: String?
        let level: Level

        var id: String { answer }

        init?(_ entry: ScrambleWordEntry) {
            guard let level = Level(difficulty: entry.difficulty), !entry.answer.isEmpty else { return nil }
            let reference = entry.reference?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            self.answer = entry.answer
            self.category = LocalizedStringKey(entry.category)
            self.categoryName = entry.category
            self.reference = reference.isEmpty ? nil : reference
            self.level = level
        }
    }

    enum AnswerFeedback {
        case correct
        case incorrect
        case timedOut
        case revealed

        var message: LocalizedStringKey {
            switch self {
            case .correct: "Correct!"
            case .incorrect: "Try again."
            case .timedOut: "Time's up."
            case .revealed: "Answer shown."
            }
        }

        var tint: Color {
            switch self {
            case .correct: .green
            case .incorrect: .orange
            case .timedOut: .red
            case .revealed: .secondary
            }
        }
    }

    private static let difficultyKey = "scrambleDifficulty"
    private static let sessionLengthKey = "scrambleSessionLength"

    /// Saved under the keys the game has always used, so existing choices carry over.
    var difficulty: Difficulty = Difficulty(
        rawValue: UserDefaults.standard.string(forKey: ScrambleGameViewModel.difficultyKey) ?? ""
    ) ?? .normal {
        didSet { UserDefaults.standard.set(difficulty.rawValue, forKey: Self.difficultyKey) }
    }

    var sessionLength: SessionLength = SessionLength(
        rawValue: UserDefaults.standard.integer(forKey: ScrambleGameViewModel.sessionLengthKey)
    ) ?? .quick {
        didSet { UserDefaults.standard.set(sessionLength.rawValue, forKey: Self.sessionLengthKey) }
    }

    var phase: Phase = .setup
    var wordBank: [ScrambleWord] = []
    /// Start waits for the word list, so a tap never has to decode it on the main thread.
    var wordBankStatus: WordBankStatus = .loading

    enum WordBankStatus {
        case loading, ready, unavailable
    }
    var deck: [ScrambleWord] = []
    var currentWord: ScrambleWord?
    var shuffledLetters: [Character] = []
    var selectedIndices: [Int] = []
    var typedAnswer = ""
    var currentNumber = 0
    /// Score and streaks; see `GameScore` for the rules.
    var session = GameScore()
    var strikes = 0
    var timeRemaining = 0
    var answerFeedback: AnswerFeedback?
    var timerID = UUID()
    var hintLevel = 0
    var isTimerDisabled = false
    /// True while the word is paused: the timer stops and the letters are hidden.
    var isPaused = false

    /// Waits between timer ticks; tests pass a manual clock.
    @ObservationIgnored private let sleep: (Duration) async throws -> Void

    init(sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.sleep = sleep
    }

    var selectedAnswer: String {
        typedAnswer
    }

    var isLastWord: Bool {
        deck.isEmpty
    }

    var isCurrentWordResolved: Bool {
        switch answerFeedback {
        case .correct, .timedOut, .revealed: true
        case .incorrect, nil: false
        }
    }

    var currentTimeLimit: Int? {
        difficulty.timeLimit
    }

    /// Only a word with its timer running can be paused. Hard has no timer, and
    /// "Timer Off" already stops the clock while leaving the word on screen.
    var canPause: Bool {
        phase == .playing && currentTimeLimit != nil && !isTimerDisabled
            && currentWord != nil && !isCurrentWordResolved && !isPaused
    }

    var hintText: String? {
        guard hintLevel > 0, let currentWord else { return nil }
        let prefix = currentWord.answer.prefix(min(hintLevel, currentWord.answer.count))
        return "Starts with \(prefix)."
    }

    // MARK: - Persistent streak (per difficulty)
    var persistentStreak: PersistentGameStreak {
        PersistentGameStreak(game: "scramble", variant: difficulty.rawValue)
    }

    /// Matches Quiz: green above 60%, yellow down to 30%, then red.
    var timerTint: Color {
        guard let timeLimit = currentTimeLimit else { return .secondary }
        let fractionRemaining = Double(timeRemaining) / Double(max(1, timeLimit))
        if fractionRemaining <= 0.3 { return .red }
        if fractionRemaining <= 0.6 { return .yellow }
        return .green
    }

    func loadWordBank() async {
        guard wordBank.isEmpty else {
            wordBankStatus = .ready
            return
        }
        wordBank = await GameDataLoaders.loadScrambleWordsAsync().compactMap(ScrambleWord.init)
        wordBankStatus = wordBank.isEmpty ? .unavailable : .ready
    }

    func startSession() {
        guard wordBankStatus == .ready else { return }

        let eligible = wordBank.filter { word in
            switch difficulty {
            case .easy: word.level == .easy
            case .normal: word.level == .normal
            case .hard: word.level == .hard
            }
        }

        guard !eligible.isEmpty else { return }

        deck = RecentGameQuestionStore.shared.select(
            from: eligible.shuffled(),
            game: "scramble",
            count: sessionLength.rawValue,
            cooldown: max(sessionLength.rawValue * 7, 10),
            id: \.answer
        )
        currentNumber = 0
        // The session streak carries from one game to the next.
        session.beginGame(savedStreak: persistentStreak, isTimed: currentTimeLimit != nil)
        strikes = 0
        hintLevel = 0
        isTimerDisabled = false
        phase = .playing
        loadNextWord()
    }

    /// Back to the start screen. The streak is kept so the next game can continue it.
    func resetToSetup() {
        phase = .setup
        isPaused = false
        deck = []
        currentWord = nil
        answerFeedback = nil
        session.clearGame()
    }

    func loadNextWord() {
        guard let next = deck.popLast() else {
            session.endGame()
            phase = .results
            timerID = UUID()
            return
        }

        currentWord = next
        RecentGameQuestionStore.shared.record(next, game: "scramble", id: \.answer)
        currentNumber += 1
        shuffledLetters = scrambledLetters(for: next.answer)
        selectedIndices.removeAll()
        typedAnswer = ""
        answerFeedback = nil
        hintLevel = 0
        strikes = 0
        timeRemaining = currentTimeLimit ?? 0
        isPaused = false
        timerID = UUID()
        session.startQuestion()
    }

    func selectLetter(_ index: Int) {
        guard !selectedIndices.contains(index),
              let currentWord,
              selectedIndices.count < currentWord.answer.count else {
            return
        }

        selectedIndices.append(index)
        typedAnswer.append(shuffledLetters[index])
        answerFeedback = nil
    }

    /// Selects the next unused tile matching a hardware-keyboard character.
    @discardableResult
    func selectLetter(matching character: Character) -> Bool {
        guard let index = shuffledLetters.indices.first(where: {
            !selectedIndices.contains($0)
                && String(shuffledLetters[$0]).uppercased() == String(character).uppercased()
        }) else {
            return false
        }

        let previousCount = selectedIndices.count
        selectLetter(index)
        return selectedIndices.count > previousCount
    }

    func removeLastLetter() {
        guard let index = selectedIndices.popLast() else { return }
        typedAnswer.removeLast()
        answerFeedback = nil
        _ = index
    }

    func clearAnswer() {
        selectedIndices.removeAll()
        typedAnswer = ""
        answerFeedback = nil
    }

    func showHint() {
        guard let currentWord, !isCurrentWordResolved else { return }
        hintLevel = min(hintLevel + 1, min(difficulty.hintLimit, currentWord.answer.count))
    }

    func toggleTimer() {
        guard currentTimeLimit != nil else { return }
        isTimerDisabled.toggle()
        if isTimerDisabled {
            session.noteTimerTurnedOff()
        }
    }

    func shuffleUnusedLetters() {
        let selected = Set(selectedIndices)
        let availableIndices = shuffledLetters.indices.filter { !selected.contains($0) }
        guard availableIndices.count > 1 else { return }

        let availableLetters = availableIndices.map { shuffledLetters[$0] }
        guard Set(availableLetters).count > 1 else { return }

        var rearranged = availableLetters.shuffled()
        if rearranged == availableLetters {
            rearranged = Array(availableLetters.dropFirst()) + [availableLetters[0]]
        }

        for (index, letter) in zip(availableIndices, rearranged) {
            shuffledLetters[index] = letter
        }
    }

    func checkAnswer() {
        guard let currentWord, !isCurrentWordResolved else { return }

        guard selectedAnswer.uppercased() == currentWord.answer else {
            if difficulty == .hard {
                strikes += 1
                if strikes >= 3 {
                    revealAnswerAfterStrikeLimit(for: currentWord)
                    return
                }
            }
            answerFeedback = .incorrect
            return
        }

        recordWordResult(.correct, givenAnswer: currentWord.answer)
        answerFeedback = .correct
    }

    func revealAnswer() {
        guard let currentWord, !isCurrentWordResolved else { return }
        typedAnswer = currentWord.answer
        selectedIndices = Array(shuffledLetters.indices)
        recordWordResult(.wrong, givenAnswer: nil)
        answerFeedback = .revealed
    }

    func revealAnswerAfterStrikeLimit(for word: ScrambleWord) {
        let lastGuess = selectedAnswer.uppercased()
        typedAnswer = word.answer
        selectedIndices = Array(shuffledLetters.indices)
        recordWordResult(.wrong, givenAnswer: lastGuess.isEmpty ? nil : lastGuess)
        answerFeedback = .revealed
    }

    func runTimer() async {
        guard currentTimeLimit != nil, phase == .playing, !isPaused else { return }

        while !Task.isCancelled, phase == .playing, !isPaused, timeRemaining > 0 {
            try? await sleep(.seconds(1))
            guard !Task.isCancelled, phase == .playing, !isPaused else { return }
            guard !isCurrentWordResolved else { return }
            guard !isTimerDisabled else { continue }

            timeRemaining -= 1
            if timeRemaining == 0 {
                revealTimedOutAnswer(for: currentWord)
                return
            }
        }
    }

    func revealTimedOutAnswer(for word: ScrambleWord?) {
        guard let word else { return }
        typedAnswer = word.answer
        selectedIndices = Array(shuffledLetters.indices)
        recordWordResult(.timedOut, givenAnswer: nil)
        answerFeedback = .timedOut
    }

    /// Counts a resolved word. The saved streak ends on a reveal, the strike limit or a timeout.
    func recordWordResult(_ outcome: GameRoundEntry.Outcome, givenAnswer: String?) {
        let correct = outcome == .correct
        if let currentWord {
            session.record(
                GameRoundEntry(
                    prompt: String(shuffledLetters),
                    outcome: outcome,
                    givenAnswer: givenAnswer,
                    correctAnswer: currentWord.answer,
                    category: currentWord.categoryName,
                    reference: currentWord.reference
                ),
                savedStreak: persistentStreak
            )
        } else {
            session.record(correct: correct, savedStreak: persistentStreak)
        }
        GameStats.shared.recordRound(
            game: .scramble,
            difficulty: difficulty.statsDifficulty,
            correct: correct ? 1 : 0,
            answered: 1,
            currentBestStreak: session.savedBestStreak
        )
    }

    func scrambledLetters(for answer: String) -> [Character] {
        let letters = Array(answer)
        var result = letters.shuffled()

        while result == letters {
            result.shuffle()
        }

        return result
    }
}
