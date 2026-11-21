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

    /// Where a picked-up or dragged letter comes from.
    enum TileSource: Equatable {
        /// A tray tile that isn't placed yet, by its index in `shuffledLetters`.
        case tray(Int)
        /// The letter in an answer square, by position.
        case slot(Int)
    }

    typealias VerseDisplay = GameVerse

    private struct UndoState {
        let slots: [Int?]
        let letters: [Character]
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
    /// The letter tiles in the tray. A tile keeps its spot when it's placed, leaving a gap.
    var shuffledLetters: [Character] = []
    /// The answer squares, each holding the index of the tile placed in it. The one record of
    /// the answer: what's typed and which tiles are used are both worked out from it.
    private(set) var slots: [Int?] = []
    /// A tile the player has picked up and not yet dropped.
    private(set) var heldTile: TileSource?
    /// The square the next tapped or typed letter goes into, once the player picks one.
    private(set) var cursorPosition: Int?
    /// Earlier arrangements, newest last, for Undo. Cleared with each word.
    private var undoHistory: [UndoState] = []
    /// The source verse's text, once loaded. Nil when there's no reference or it can't be found.
    private(set) var verseText: String?
    private(set) var isVerseClueShown = false
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
    /// Whether a string is a real English word; tests can pass a fixed list. Main actor
    /// because the real check uses UIKit's spell checker.
    @ObservationIgnored private let isEnglishWord: @MainActor (String) -> Bool
    /// Looks up a verse's text by reference, for the verse clue; tests pass a fixed text.
    @ObservationIgnored private let loadVerseText: (String) async -> String?
    /// Time spent on the current word. The countdown is worked out from it, so pausing and
    /// resuming can't give back part of a second.
    @ObservationIgnored private var wordClock = GameActiveClock()

    /// `missedQuestions` and `loadVerseText` default to the shared store and the Bible text.
    /// They're resolved here rather than as default arguments, which would be evaluated
    /// outside the main actor.
    init(
        reviewQuestionIDs: Set<String> = [],
        missedQuestions: MissedGameQuestionStore? = nil,
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        now: @escaping () -> Date = Date.init,
        isEnglishWord: @escaping @MainActor (String) -> Bool = EnglishDictionary.contains,
        loadVerseText: ((String) async -> String?)? = nil
    ) {
        self.reviewQuestionIDs = reviewQuestionIDs
        self.missedQuestions = missedQuestions ?? .shared
        self.sleep = sleep
        self.now = now
        self.isEnglishWord = isEnglishWord
        self.loadVerseText = loadVerseText ?? { await Self.sourceVerseText(for: $0) }
    }

    // MARK: - The answer squares

    /// The letter in each square, or nil for an empty one.
    var placedLetters: [Character?] {
        slots.map { $0.map { shuffledLetters[$0] } }
    }

    /// The placed letters in order, skipping empty squares.
    var typedAnswer: String {
        String(slots.compactMap { $0.map { shuffledLetters[$0] } })
    }

    /// Tray tiles that are in a square.
    var usedTileIndices: Set<Int> {
        Set(slots.compactMap { $0 })
    }

    var isAnswerFull: Bool {
        !slots.isEmpty && slots.allSatisfy { $0 != nil }
    }

    var hasPlacedLetters: Bool {
        slots.contains { $0 != nil }
    }

    var canUndo: Bool {
        canEdit && !undoHistory.isEmpty
    }

    /// Letters can only be moved while a word is on screen and unsolved.
    private var canEdit: Bool {
        currentWord != nil && !isCurrentWordResolved
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
        currentWord != nil && isAnswerFull && !requiresAnswerEdit
    }

    var currentTimeLimit: Int? {
        isPracticeMode ? nil : difficulty.timeLimit
    }

    var hintBadgeText: String? {
        guard maxHintLevel > 0 else { return nil }
        return "\(hintLevel)/\(maxHintLevel)"
    }

    /// Letter hints plus the verse clue, which counts as one more.
    var hintsUsed: Int {
        hintLevel + (isVerseClueShown ? 1 : 0)
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
            // Each hint places a letter, so Hard allows one per three letters, up to three:
            // the opening letter, then interior ones.
            return min(3, max(1, wordLength / 3), max(1, wordLength - 1))
        }

        return min(difficulty.hintLimit, wordLength)
    }

    /// The correct letter for each hinted square, shown faintly whenever the square is empty.
    var hintedLetters: [Character?] {
        guard let currentWord else { return [] }
        let answer = Array(currentWord.answer)
        return answer.indices.map { hintPositions.contains($0) ? answer[$0] : nil }
    }

    var canShowVerseClue: Bool {
        canEdit && verseText != nil && !isVerseClueShown
    }

    /// The clue with the word blanked out while the word is unsolved, and the whole verse after.
    var displayedVerse: VerseDisplay? {
        guard let currentWord, let verseText, let reference = currentWord.reference else { return nil }
        if isCurrentWordResolved {
            return VerseDisplay(text: verseText, reference: reference, isClue: false)
        }
        guard isVerseClueShown else { return nil }
        return VerseDisplay(text: Self.blankingOut(currentWord.answer, in: verseText), reference: reference, isClue: true)
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
        resetBoard(letterCount: 0)
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
        resetBoard(letterCount: next.answer.count)
        answerFeedback = nil
        requiresAnswerEdit = false
        isNextWordReady = false
        hintLevel = 0
        hintPositions.removeAll()
        verseText = nil
        isVerseClueShown = false
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

    private func resetBoard(letterCount: Int) {
        slots = Array(repeating: nil, count: letterCount)
        heldTile = nil
        cursorPosition = nil
        undoHistory.removeAll()
    }

    /// Every change to the squares goes through here, so it can be undone and clears the last verdict.
    private func updateSlots(_ change: (inout [Int?]) -> Void) {
        var updated = slots
        change(&updated)
        heldTile = nil
        guard updated != slots else { return }
        undoHistory.append(UndoState(slots: slots, letters: shuffledLetters))
        slots = updated
        answerFeedback = nil
        requiresAnswerEdit = false
    }

    /// The next empty square after `position`, wrapping around.
    private func nextEmptyPosition(after position: Int) -> Int? {
        guard !slots.isEmpty else { return nil }
        return (1...slots.count)
            .map { (position + $0) % slots.count }
            .first { slots[$0] == nil }
    }

    /// A tap on a tray tile: the quick way to build an answer. The letter goes into the chosen
    /// square, or the first empty one. While a placed letter is held, it goes back to the tray instead.
    func selectLetter(_ index: Int) {
        guard canEdit, shuffledLetters.indices.contains(index), !usedTileIndices.contains(index) else { return }

        if case .slot = heldTile {
            returnHeldTileToTray()
            return
        }
        guard let position = cursorPosition ?? slots.firstIndex(where: { $0 == nil }) else {
            heldTile = nil
            return
        }

        placeTile(index, at: position)
        if cursorPosition != nil {
            cursorPosition = nextEmptyPosition(after: position)
        }
    }

    /// Places the next unused tile matching a hardware-keyboard character.
    @discardableResult
    func selectLetter(matching character: Character) -> Bool {
        let used = usedTileIndices
        guard let index = shuffledLetters.indices.first(where: {
            !used.contains($0)
                && String(shuffledLetters[$0]).uppercased() == String(character).uppercased()
        }) else {
            return false
        }

        selectLetter(index)
        return usedTileIndices.contains(index)
    }

    /// Puts a tray tile into a square. A letter already there goes back to the tray.
    func placeTile(_ index: Int, at position: Int) {
        guard canEdit, slots.indices.contains(position), shuffledLetters.indices.contains(index),
              !usedTileIndices.contains(index) else { return }
        updateSlots { $0[position] = index }
    }

    /// Moves a placed letter to another square, swapping with any letter already there.
    func moveLetter(from source: Int, to destination: Int) {
        guard canEdit, slots.indices.contains(source), slots.indices.contains(destination),
              slots[source] != nil else { return }
        updateSlots { $0.swapAt(source, destination) }
    }

    func returnToTray(_ position: Int) {
        guard canEdit, slots.indices.contains(position) else { return }
        updateSlots { $0[position] = nil }
    }

    /// A tap on a square. Holding a letter drops it here; otherwise a placed letter is picked
    /// up, and an empty square becomes (or stops being) where the next letter goes.
    func tapSquare(_ position: Int) {
        guard canEdit, slots.indices.contains(position) else { return }

        if heldTile != nil {
            dropHeldTile(on: position)
        } else if slots[position] != nil {
            pickUp(.slot(position))
        } else {
            cursorPosition = cursorPosition == position ? nil : position
        }
    }

    func pickUp(_ source: TileSource) {
        guard canEdit else { return }
        switch source {
        case .tray(let index):
            guard shuffledLetters.indices.contains(index), !usedTileIndices.contains(index) else { return }
        case .slot(let position):
            guard slots.indices.contains(position), slots[position] != nil else { return }
        }
        heldTile = source
        cursorPosition = nil
    }

    /// Drops the held letter into a square. Dropping it where it came from just puts it down.
    func dropHeldTile(on position: Int) {
        switch heldTile {
        case .tray(let index): placeTile(index, at: position)
        case .slot(let source): moveLetter(from: source, to: position)
        case nil: break
        }
        heldTile = nil
    }

    func returnHeldTileToTray() {
        if case .slot(let position) = heldTile {
            returnToTray(position)
        }
        heldTile = nil
    }

    func cancelHold() {
        heldTile = nil
    }

    /// Moves the typing cursor one square left or right.
    func moveCursor(by offset: Int) {
        guard canEdit, !slots.isEmpty else { return }
        let start = cursorPosition ?? (offset > 0 ? -1 : slots.count)
        cursorPosition = min(max(start + offset, 0), slots.count - 1)
        heldTile = nil
    }

    /// The Delete key: clears the letter at the cursor, or the last one before it.
    func deleteBackward() {
        guard canEdit else { return }
        let end = cursorPosition.map { $0 + 1 } ?? slots.count
        guard let position = slots[..<end].lastIndex(where: { $0 != nil }) else { return }
        returnToTray(position)
        if cursorPosition != nil {
            cursorPosition = position
        }
    }

    /// Puts back the arrangement before the last move, shuffle or hint letter.
    func undo() {
        guard canEdit, let previous = undoHistory.popLast() else { return }
        slots = previous.slots
        shuffledLetters = previous.letters
        heldTile = nil
        answerFeedback = nil
        requiresAnswerEdit = false
    }

    func clearAnswer() {
        guard hasPlacedLetters else { return }
        updateSlots { $0 = Array(repeating: nil, count: $0.count) }
        cursorPosition = nil
    }

    /// Reveals a letter and places it in its square. The first hint is the opening letter;
    /// later Hard hints are interior letters, ones not already right where possible.
    func showHint() {
        guard canEdit, let currentWord, hintLevel < maxHintLevel else { return }
        let answer = Array(currentWord.answer)

        let position: Int?
        if hintLevel == 0 {
            position = 0
        } else {
            let placed = placedLetters
            let unrevealed = (1..<max(1, answer.count - 1)).filter { !hintPositions.contains($0) }
            position = unrevealed.filter { placed[$0] != answer[$0] }.randomElement() ?? unrevealed.randomElement()
        }

        hintLevel += 1
        guard let position else { return }
        hintPositions.insert(position)
        placeHintedLetter(at: position, answer: answer)
    }

    /// Puts the correct letter in `position`, using an unused tile if there is one, or else
    /// taking it from a square where it's wrong. Whatever was in `position` goes back to the tray.
    private func placeHintedLetter(at position: Int, answer: [Character]) {
        let letter = answer[position]
        let placed = placedLetters
        guard placed[position] != letter else { return }

        let used = usedTileIndices
        if let tile = shuffledLetters.indices.first(where: { !used.contains($0) && shuffledLetters[$0] == letter }) {
            updateSlots { $0[position] = tile }
        } else if let source = slots.indices.first(where: {
            $0 != position && placed[$0] == letter && answer[$0] != letter
        }) {
            updateSlots {
                $0[position] = $0[source]
                $0[source] = nil
            }
        }
        if cursorPosition == position {
            cursorPosition = nextEmptyPosition(after: position)
        }
    }

    // MARK: - Verse clue

    /// Loads the current word's source verse, for the clue and for showing after it's solved.
    func loadVerse() async {
        guard let word = currentWord, let reference = word.reference, verseText == nil else { return }
        let text = await loadVerseText(reference)
        guard currentWord?.id == word.id else { return }
        verseText = text
    }

    func showVerseClue() {
        guard canShowVerseClue else { return }
        isVerseClueShown = true
    }

    /// `text` with every appearance of `word` replaced by blanks, so the clue doesn't give it away.
    /// Longer words that contain it (PRAYED for PRAY) keep their other letters.
    static func blankingOut(_ word: String, in text: String) -> String {
        guard !word.isEmpty else { return text }
        return text.replacingOccurrences(
            of: word,
            with: String(repeating: "_", count: word.count),
            options: [.caseInsensitive, .diacriticInsensitive]
        )
    }

    /// The first verse of `reference` in the reader's translation, or nil if it can't be found.
    static func sourceVerseText(for reference: String) async -> String? {
        guard let passage = PassageReferenceParser.firstPassage(in: reference), let verse = passage.startVerse else { return nil }
        let scriptureRef = ScriptureRef(
            bookName: passage.bookName,
            chapter: passage.startChapter,
            startVerse: verse,
            endVerse: nil
        )
        guard let text = await BibleReferenceLinker.loadVersesEnsuringLoaded(for: scriptureRef)?.verses.first?.text,
              !text.isEmpty else { return nil }
        return text
    }

    func toggleTimer() {
        guard currentTimeLimit != nil else { return }
        isTimerDisabled.toggle()
        if isTimerDisabled {
            session.noteTimerTurnedOff()
        }
    }

    func shuffleUnusedLetters() {
        guard canEdit else { return }
        let used = usedTileIndices
        let availableIndices = shuffledLetters.indices.filter { !used.contains($0) }
        guard availableIndices.count > 1 else { return }

        let availableLetters = availableIndices.map { shuffledLetters[$0] }
        guard Set(availableLetters).count > 1 else { return }

        var rearranged = availableLetters.shuffled()
        if rearranged == availableLetters {
            rearranged = Array(availableLetters.dropFirst()) + [availableLetters[0]]
        }

        undoHistory.append(UndoState(slots: slots, letters: shuffledLetters))
        heldTile = nil
        for (index, letter) in zip(availableIndices, rearranged) {
            shuffledLetters[index] = letter
        }
    }

    func checkAnswer() {
        guard let currentWord, !isCurrentWordResolved, canCheckAnswer else { return }

        let guess = typedAnswer.uppercased()
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
            Haptics.error()
            return
        }

        acceptedAlternate = guess == currentWord.answer ? nil : guess
        recordWordResult(.correct, givenAnswer: guess)
        answerFeedback = .correct
        Haptics.success()
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
        showAnswerInSquares(currentWord)
        recordWordResult(.wrong, givenAnswer: nil)
        answerFeedback = .revealed
        Haptics.warning()
    }

    func revealAnswerAfterStrikeLimit(for word: ScrambleWord) {
        let lastGuess = typedAnswer.uppercased()
        showAnswerInSquares(word)
        recordWordResult(.wrong, givenAnswer: lastGuess.isEmpty ? nil : lastGuess)
        answerFeedback = .revealed
    }

    /// Fills the squares with the word, matching each letter to a tile.
    private func showAnswerInSquares(_ word: ScrambleWord) {
        var unused = Array(shuffledLetters.indices)
        slots = word.answer.map { letter in
            unused.firstIndex { shuffledLetters[$0] == letter }.map { unused.remove(at: $0) }
        }
        heldTile = nil
        cursorPosition = nil
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
        showAnswerInSquares(word)
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
                    hintCount: hintsUsed
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
