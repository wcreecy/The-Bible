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

        var systemImage: String {
            switch self {
            case .correct: "checkmark.circle.fill"
            case .incorrect: "exclamationmark.circle.fill"
            case .timedOut: "clock.badge.exclamationmark"
            case .revealed: "eye"
            }
        }
    }

    private static let difficultyKey = "scrambleDifficulty"
    private static let sessionLengthKey = "scrambleSessionLength"
    private static let practiceModeKey = "scramblePracticeMode"

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

    /// Practice keeps the same word deck and scoring, without a per-word timer.
    var isPracticeMode = UserDefaults.standard.bool(forKey: ScrambleGameViewModel.practiceModeKey) {
        didSet { UserDefaults.standard.set(isPracticeMode, forKey: Self.practiceModeKey) }
    }

    var phase: Phase = .setup
    var wordBank: [ScrambleWord] = [] {
        didSet { bankAnswers = Set(wordBank.map(\.answer)) }
    }
    /// Every answer in the list, so another list word spelled from the same letters counts.
    @ObservationIgnored private var bankAnswers: Set<String> = []
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
    var totalWords = 0
    /// Score and streaks; see `GameScore` for the rules.
    var session = GameScore()
    var strikes = 0
    var timeRemaining = 0
    var answerFeedback: AnswerFeedback?
    /// An incorrect answer must be edited before it can consume another strike.
    private(set) var requiresAnswerEdit = false
    private(set) var isNextWordReady = false
    var timerID = UUID()
    var hintLevel = 0
    private(set) var hintPositions: Set<Int> = []
    var isTimerDisabled = false {
        didSet {
            guard isTimerDisabled != oldValue else { return }
            if isTimerDisabled { wordClock.pause(at: now()) } else if !isPaused { wordClock.resume(at: now()) }
        }
    }
    /// True while the word is paused: the timer stops and the letters are hidden.
    var isPaused = false {
        didSet {
            guard isPaused != oldValue else { return }
            if isPaused { wordClock.pause(at: now()) } else if !isTimerDisabled { wordClock.resume(at: now()) }
        }
    }
    /// Another real word the player spelled from the letters, accepted in place of the puzzle's word.
    private(set) var acceptedAlternate: String?
    private let reviewQuestionIDs: Set<String>
    /// Where missed words are recorded; tests pass a store that never touches disk or iCloud.
    private let missedQuestions: MissedGameQuestionStore

    /// Waits between timer ticks; tests pass a manual clock.
    @ObservationIgnored private let sleep: (Duration) async throws -> Void
    /// The current time for the word clock; tests pass the manual clock's time.
    @ObservationIgnored private let now: () -> Date
    /// Whether a string is a real English word; tests can pass a fixed list.
    @ObservationIgnored private let isEnglishWord: (String) -> Bool
    /// Time spent on the current word. The countdown is worked out from it, so pausing and
    /// resuming can't give back part of a second.
    @ObservationIgnored private var wordClock = GameActiveClock()

    /// `missedQuestions` defaults to the shared store. It's resolved here rather than as a
    /// default argument, which would be evaluated outside the main actor.
    init(
        reviewQuestionIDs: Set<String> = [],
        missedQuestions: MissedGameQuestionStore? = nil,
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        now: @escaping () -> Date = Date.init,
        isEnglishWord: @escaping (String) -> Bool = EnglishDictionary.contains
    ) {
        self.reviewQuestionIDs = reviewQuestionIDs
        self.missedQuestions = missedQuestions ?? .shared
        self.sleep = sleep
        self.now = now
        self.isEnglishWord = isEnglishWord
    }

    var selectedAnswer: String {
        typedAnswer
    }

    var isLastWord: Bool {
        deck.isEmpty
    }

    var isReviewRound: Bool { !reviewQuestionIDs.isEmpty }

    var isCurrentWordResolved: Bool {
        switch answerFeedback {
        case .correct, .timedOut, .revealed: true
        case .incorrect, nil: false
        }
    }

    var canCheckAnswer: Bool {
        guard let currentWord else { return false }
        return typedAnswer.count == currentWord.answer.count && !requiresAnswerEdit
    }

    var currentTimeLimit: Int? {
        isPracticeMode ? nil : difficulty.timeLimit
    }

    var hintBadgeText: String? {
        guard difficulty != .easy, maxHintLevel > 0 else { return nil }
        return "\(hintLevel)/\(maxHintLevel)"
    }

    var hintFreeSolvedCount: Int {
        session.entries.count { $0.outcome == .correct && $0.hintCount == 0 }
    }

    var hardModeResultNote: String? {
        guard difficulty == .hard else { return nil }
        return String(localized: "Solved \(session.score) of \(session.answered), \(hintFreeSolvedCount) without hints.")
    }

    /// Only a word with its timer running can be paused. "Timer Off" stops the
    /// clock while leaving the word on screen.
    var canPause: Bool {
        phase == .playing && currentTimeLimit != nil && !isTimerDisabled
            && currentWord != nil && !isCurrentWordResolved && !isPaused
    }

    var maxHintLevel: Int {
        guard let currentWord else { return 0 }
        let wordLength = currentWord.answer.count

        if difficulty == .hard {
            // The first Hard hint reveals the opening letter; later hints
            // reveal up to two different interior letters.
            return min(3, max(1, wordLength - 1))
        }

        return min(difficulty.hintLimit, wordLength)
    }

    var hintText: String? {
        guard hintLevel > 0, let currentWord, let firstLetter = currentWord.answer.first else { return nil }

        guard !hintPositions.isEmpty else {
            return "Starts with \(firstLetter)."
        }

        let details = hintPositions.sorted().map { position in
            let index = currentWord.answer.index(currentWord.answer.startIndex, offsetBy: position)
            return "Position \(position + 1) is \(currentWord.answer[index])."
        }
        return (["Starts with \(firstLetter)."] + details).joined(separator: " ")
    }

    var hintedLetters: [Character?] {
        guard let currentWord else { return [] }

        var hints = Array<Character?>(repeating: nil, count: currentWord.answer.count)
        if hintLevel > 0 {
            hints[0] = currentWord.answer.first
        }
        for position in hintPositions where position < currentWord.answer.count {
            let index = currentWord.answer.index(currentWord.answer.startIndex, offsetBy: position)
            hints[position] = currentWord.answer[index]
        }
        return hints
    }

    /// Each difficulty has its own word list, so each keeps its own pass through it.
    private var recencyGameKey: String { "scramble.\(difficulty.rawValue)" }

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
            if isReviewRound { return reviewQuestionIDs.contains(word.answer.uppercased()) }
            return switch difficulty {
            case .easy: word.level == .easy
            case .normal: word.level == .normal
            case .hard: word.level == .hard
            }
        }

        guard !eligible.isEmpty else { return }

        let wordCount = isReviewRound ? min(10, eligible.count) : sessionLength.rawValue
        // Every word at this difficulty comes up before any repeats.
        deck = isReviewRound
            ? Array(eligible.shuffled().prefix(wordCount))
            : RecentGameQuestionStore.shared.selectCycling(
                from: eligible,
                game: recencyGameKey,
                count: wordCount,
                id: \.answer
            )
        currentNumber = 0
        totalWords = deck.count
        // The session streak carries from one game to the next.
        session.beginGame(savedStreak: persistentStreak, isTimed: currentTimeLimit != nil)
        strikes = 0
        hintLevel = 0
        isTimerDisabled = false
        phase = .playing
        loadNextWord()
    }

    /// Leaving mid-word counts as running out of time, so backing out can't skip a hard word
    /// and keep the streak. Practice has no timer, so leaving it costs nothing.
    func onDisappear() {
        if phase == .playing, currentTimeLimit != nil, let currentWord, !isCurrentWordResolved {
            revealTimedOutAnswer(for: currentWord)
        }
        if phase != .setup {
            resetToSetup()
        }
        session.clearStreak()
    }

    /// Back to the start screen. The streak is kept so the next game can continue it.
    func resetToSetup() {
        wordClock.pause(at: now())
        phase = .setup
        isPaused = false
        deck = []
        currentWord = nil
        totalWords = 0
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
        RecentGameQuestionStore.shared.record(next, game: recencyGameKey, id: \.answer)
        currentNumber += 1
        shuffledLetters = scrambledLetters(for: next.answer)
        acceptedAlternate = nil
        selectedIndices.removeAll()
        typedAnswer = ""
        answerFeedback = nil
        requiresAnswerEdit = false
        isNextWordReady = false
        hintLevel = 0
        hintPositions.removeAll()
        strikes = 0
        timeRemaining = currentTimeLimit ?? 0
        isPaused = false
        wordClock.start(at: now())
        if isTimerDisabled {
            wordClock.pause(at: now())
        }
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
        requiresAnswerEdit = false
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
        requiresAnswerEdit = false
        _ = index
    }

    func clearAnswer() {
        selectedIndices.removeAll()
        typedAnswer = ""
        answerFeedback = nil
        requiresAnswerEdit = false
    }

    /// Removes the tapped letter and every letter after it, so an answer can be
    /// corrected directly from its answer slots.
    func removeLetters(startingAt position: Int) {
        guard position >= 0, position < selectedIndices.count else { return }

        selectedIndices.removeSubrange(position...)
        typedAnswer.removeLast(typedAnswer.count - position)
        answerFeedback = nil
        requiresAnswerEdit = false
    }

    func showHint() {
        guard !isCurrentWordResolved, maxHintLevel > 0 else { return }

        let nextLevel = min(hintLevel + 1, maxHintLevel)
        if nextLevel > 1, let currentWord {
            let wordLength = currentWord.answer.count
            if difficulty == .hard {
                // Keep the first and last letters out of later Hard hints,
                // and never reveal an interior letter twice.
                let candidates = (1..<(wordLength - 1)).filter { !hintPositions.contains($0) }
                if let position = candidates.randomElement() {
                    hintPositions.insert(position)
                }
            } else {
                hintPositions.insert(1)
            }
        }
        hintLevel = nextLevel
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
        guard let currentWord, !isCurrentWordResolved, canCheckAnswer else { return }

        let guess = selectedAnswer.uppercased()
        guard isAcceptedAnswer(guess, for: currentWord.answer) else {
            if difficulty != .easy {
                strikes += 1
                if strikes >= 3 {
                    revealAnswerAfterStrikeLimit(for: currentWord)
                    return
                }
            }
            answerFeedback = .incorrect
            requiresAnswerEdit = true
            return
        }

        acceptedAlternate = guess == currentWord.answer ? nil : guess
        recordWordResult(.correct, givenAnswer: guess)
        answerFeedback = .correct
        let wordID = currentWord.id
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, self?.currentWord?.id == wordID, self?.answerFeedback == .correct else { return }
            self?.isNextWordReady = true
        }
    }

    /// The puzzle's word, or another word with exactly the same letters: one from the Scramble
    /// list or any real English word. EARTH can be solved as HEART.
    func isAcceptedAnswer(_ guess: String, for answer: String) -> Bool {
        guard guess != answer else { return true }
        guard guess.count == answer.count, guess.sorted() == answer.sorted() else { return false }
        return bankAnswers.contains(guess) || isEnglishWord(guess)
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

        // The clock is the authority; the short interval only keeps the display current.
        while !Task.isCancelled, phase == .playing, !isPaused, timeRemaining > 0 {
            try? await sleep(.milliseconds(100))
            guard !Task.isCancelled, phase == .playing, !isPaused else { return }
            guard !isCurrentWordResolved else { return }
            guard !isTimerDisabled, let timeLimit = currentTimeLimit else { continue }

            let remaining = max(0, timeLimit - Int(wordClock.elapsed(at: now())))
            if remaining != timeRemaining {
                timeRemaining = remaining
            }
            if timeRemaining == 0 {
                revealTimedOutAnswer(for: currentWord)
                return
            }
        }
    }

    func revealTimedOutAnswer(for word: ScrambleWord?) {
        guard let word else { return }
        wordClock.pause(at: now())
        typedAnswer = word.answer
        selectedIndices = Array(shuffledLetters.indices)
        recordWordResult(.timedOut, givenAnswer: nil)
        answerFeedback = .timedOut
    }

    /// Counts a resolved word. The saved streak ends on a reveal, the strike limit or a timeout.
    func recordWordResult(_ outcome: GameRoundEntry.Outcome, givenAnswer: String?) {
        wordClock.pause(at: now())
        let correct = outcome == .correct
        if let currentWord {
            session.record(
                GameRoundEntry(
                    prompt: String(shuffledLetters),
                    outcome: outcome,
                    givenAnswer: givenAnswer,
                    correctAnswer: currentWord.answer,
                    category: currentWord.categoryName,
                    reference: currentWord.reference,
                    hintCount: hintLevel
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
        if let currentWord {
            let questionID = currentWord.answer.uppercased()
            if correct, isReviewRound {
                missedQuestions.resolveReviewQuestion(game: .scramble, questionID: questionID)
            } else if !correct {
                missedQuestions.record(
                    game: .scramble,
                    bookNames: [],
                    topic: currentWord.categoryName,
                    questionID: questionID
                )
            }
        }
    }

    /// Shuffles the answer so the tiles don't already spell it, or any other word that would be
    /// accepted (EARTH never starts as HEART). A word whose every arrangement is a word settles for
    /// one that at least isn't the answer itself.
    func scrambledLetters(for answer: String) -> [Character] {
        let letters = Array(answer)
        guard letters.count > 1, Set(letters).count > 1 else { return letters }

        var fallback: [Character]?
        for _ in 0..<100 {
            let result = letters.shuffled()
            guard result != letters else { continue }
            if !isAcceptedAnswer(String(result), for: answer) { return result }
            fallback = fallback ?? result
        }
        if let fallback { return fallback }

        var result = letters
        repeat {
            result.shuffle()
        } while result == letters
        return result
    }
}
