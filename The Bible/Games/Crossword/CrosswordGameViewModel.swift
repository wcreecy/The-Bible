import Foundation
import Observation

/// The rules of a Crossword round: typing, moving between squares, hints, and finishing.
@MainActor
@Observable
final class CrosswordGameViewModel {
    typealias Cell = CrosswordPuzzle.Cell
    typealias Direction = CrosswordPuzzle.Direction

    enum Difficulty: String, CaseIterable, Identifiable {
        case easy
        case normal
        case hard

        var id: Self { self }

        var boardSize: Int {
            switch self {
            case .easy: 9
            case .normal: 11
            case .hard: 13
            }
        }

        /// Which clue difficulties each level draws from. The hard list alone is too short
        /// to fill a 13×13 board reliably, so Hard mixes in Normal clues.
        var clueDifficulties: Set<String> {
            switch self {
            case .easy: ["easy"]
            case .normal: ["easy", "normal"]
            case .hard: ["normal", "hard"]
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
            switch experienceLevel {
            case .learn: self = .easy
            case .standard: self = .normal
            case .challenge: self = .hard
            }
        }

        var statsDifficulty: GameStats.Difficulty {
            switch self {
            case .easy: .easy
            case .normal: .normal
            case .hard: .hard
            }
        }
    }

    enum Phase: Equatable {
        case setup
        case loading
        case playing
        case finished
        /// No board could be built (for example the clue file is missing).
        case unavailable
    }

    enum Outcome: Equatable {
        case solved
        case revealed
    }

    private static let difficultyKey = "crosswordDifficulty"
    /// Answers from the player's last few puzzles, kept on this device only.
    static let recentAnswersKey = "crosswordRecentAnswers"
    /// How many recent puzzles' answers are kept out of the next board.
    static let rememberedPuzzleCount = 6
    static let currentStreakKey = "crosswordCurrentStreak"
    /// Unfinished boards, one per difficulty, so leaving doesn't lose a half-solved puzzle.
    static let savedRoundsKey = "crosswordSavedRounds"
    /// Fastest solved time for a difficulty. Revealed puzzles don't count.
    static func bestTimeKey(for difficulty: Difficulty) -> String { "crosswordBestTime_\(difficulty.rawValue)" }

    var difficulty: Difficulty {
        didSet { defaults.set(difficulty.rawValue, forKey: Self.difficultyKey) }
    }

    private(set) var phase: Phase = .setup
    private(set) var puzzle: CrosswordPuzzle?
    private(set) var guesses: [Cell: Character] = [:]
    /// Squares filled by a hint. They are locked so typing can't change them.
    private(set) var revealedCells: Set<Cell> = []
    /// Wrong letters found by Check. A square leaves this set once it is edited.
    private(set) var wrongCells: Set<Cell> = []
    private(set) var selectedCell: Cell?
    private(set) var direction: Direction = .across
    private(set) var outcome: Outcome?
    private(set) var letterHintsUsed = 0
    private(set) var wordHintsUsed = 0
    private(set) var checksUsed = 0
    private(set) var elapsedSeconds = 0
    private(set) var currentStreak = 0
    /// The finished puzzle's time against the best saved before it.
    private(set) var bestTimeComparison: GameBestTimeComparison?

    /// Solve time. It only runs while the app is in front, so time away doesn't count.
    private var clock = GameActiveClock()
    private var clues: [CrosswordClueEntry]?
    private let defaults: UserDefaults
    private let loadClues: () async -> [CrosswordClueEntry]
    private let recordsStats: Bool

    init(
        defaults: UserDefaults = .standard,
        recordsStats: Bool = true,
        loadClues: @escaping () async -> [CrosswordClueEntry] = { await GameDataLoaders.loadCrosswordCluesAsync() }
    ) {
        self.defaults = defaults
        self.recordsStats = recordsStats
        self.loadClues = loadClues
        difficulty = defaults.string(forKey: Self.difficultyKey).flatMap(Difficulty.init(rawValue:)) ?? .normal
        currentStreak = defaults.integer(forKey: Self.currentStreakKey)
    }

    // MARK: - Starting

    /// Resumes the saved board for this difficulty, or loads the clues (once), builds a fresh
    /// random board, and starts the round.
    func start() async {
        if let saved = savedRound(for: difficulty) {
            resume(saved)
            return
        }
        phase = .loading
        if clues == nil {
            clues = await loadClues()
        }
        let levels = difficulty.clueDifficulties
        let pool = (clues ?? []).filter { levels.contains($0.difficulty.lowercased()) }
        let size = difficulty.boardSize
        // Shared across difficulties, since Normal and Hard also draw from easier clues.
        let recentAnswers = Set(recentPuzzleAnswers.joined())
        // Building takes a few milliseconds per attempt; keep it off the main actor.
        let generated = await Task.detached(priority: .userInitiated) {
            CrosswordGenerator.generate(from: pool, preferredSize: size, avoiding: recentAnswers)
        }.value

        guard let generated else {
            phase = .unavailable
            return
        }
        remember(generated)
        begin(with: generated)
    }

    /// Each recent puzzle's answers, oldest first.
    private var recentPuzzleAnswers: [[String]] {
        defaults.array(forKey: Self.recentAnswersKey) as? [[String]] ?? []
    }

    /// Adds this board's answers to the recent list, keeping only the last few puzzles.
    private func remember(_ puzzle: CrosswordPuzzle) {
        let updated = recentPuzzleAnswers + [puzzle.entries.map(\.answer)]
        defaults.set(Array(updated.suffix(Self.rememberedPuzzleCount)), forKey: Self.recentAnswersKey)
    }

    /// Starts a round on a given board. Used by `start()` and by tests.
    func begin(with puzzle: CrosswordPuzzle) {
        self.puzzle = puzzle
        guesses = [:]
        revealedCells = []
        wrongCells = []
        outcome = nil
        letterHintsUsed = 0
        wordHintsUsed = 0
        checksUsed = 0
        elapsedSeconds = 0
        bestTimeComparison = nil
        clock.start()
        if let first = puzzle.entries.first {
            direction = first.direction
            selectedCell = first.cells.first
        }
        phase = .playing
    }

    func changeSettings() {
        phase = .setup
        puzzle = nil
        selectedCell = nil
    }

    // MARK: - Saved boards

    /// An unfinished board: the puzzle, the letters so far, and what the player has used.
    struct SavedRound: Codable, Equatable {
        struct Letter: Codable, Equatable {
            let cell: Cell
            let letter: String
        }

        let puzzle: CrosswordPuzzle
        let letters: [Letter]
        let revealedCells: [Cell]
        let letterHintsUsed: Int
        let wordHintsUsed: Int
        let checksUsed: Int
        let elapsedSeconds: Int
        let selectedCell: Cell?
        let direction: Direction
    }

    /// True when Start would resume an unfinished board at this difficulty.
    var hasSavedRound: Bool { savedRound(for: difficulty) != nil }

    /// Saves the board in play. Called when the player leaves and when the app goes to the background.
    func saveProgress(at now: Date = Date()) {
        guard phase == .playing, let puzzle else { return }
        let round = SavedRound(
            puzzle: puzzle,
            letters: guesses.map { SavedRound.Letter(cell: $0.key, letter: String($0.value)) },
            revealedCells: Array(revealedCells),
            letterHintsUsed: letterHintsUsed,
            wordHintsUsed: wordHintsUsed,
            checksUsed: checksUsed,
            elapsedSeconds: clock.elapsedSeconds(at: now),
            selectedCell: selectedCell,
            direction: direction
        )
        var rounds = savedRounds
        rounds[difficulty.rawValue] = round
        storeSavedRounds(rounds)
    }

    private var savedRounds: [String: SavedRound] {
        guard let data = defaults.data(forKey: Self.savedRoundsKey) else { return [:] }
        return PersistedDecoding.decode(
            [String: SavedRound].self, from: data, key: Self.savedRoundsKey, keepingUnreadableIn: defaults
        ) ?? [:]
    }

    private func storeSavedRounds(_ rounds: [String: SavedRound]) {
        guard let data = try? JSONEncoder().encode(rounds) else { return }
        defaults.set(data, forKey: Self.savedRoundsKey)
    }

    private func savedRound(for difficulty: Difficulty) -> SavedRound? {
        guard let round = savedRounds[difficulty.rawValue], !round.puzzle.entries.isEmpty else { return nil }
        return round
    }

    private func clearSavedRound() {
        var rounds = savedRounds
        guard rounds.removeValue(forKey: difficulty.rawValue) != nil else { return }
        storeSavedRounds(rounds)
    }

    /// Puts a saved board back exactly as it was left, with the clock carrying on from its time.
    private func resume(_ round: SavedRound) {
        begin(with: round.puzzle)
        let validCells = Set(allLetterCells(in: round.puzzle))
        guesses = Dictionary(
            round.letters.compactMap { item in
                guard validCells.contains(item.cell), let letter = item.letter.first else { return nil }
                return (item.cell, letter)
            },
            uniquingKeysWith: { first, _ in first }
        )
        revealedCells = Set(round.revealedCells).intersection(validCells)
        letterHintsUsed = round.letterHintsUsed
        wordHintsUsed = round.wordHintsUsed
        checksUsed = round.checksUsed
        clock.start(alreadyElapsed: TimeInterval(round.elapsedSeconds))
        if let cell = round.selectedCell, validCells.contains(cell) {
            selectedCell = cell
            direction = round.direction
            if currentEntry == nil { direction = direction.other }
        }
    }

    // MARK: - App activity

    /// Stops the solve clock while the app isn't in front and starts it again on return.
    /// The board stays as it was; only the time away is left out.
    func appActiveChanged(_ isActive: Bool, at now: Date = Date()) {
        guard phase == .playing else { return }
        if isActive {
            clock.resume(at: now)
        } else {
            clock.pause(at: now)
            // Kept in case the app is closed from the background.
            saveProgress(at: now)
        }
    }

    /// Seconds of active play so far in this round.
    func activeSeconds(at now: Date = Date()) -> Int {
        clock.elapsedSeconds(at: now)
    }

    // MARK: - Selection

    /// The entry the selected square belongs to in the current direction.
    var currentEntry: CrosswordPuzzle.Entry? {
        guard let puzzle, let selectedCell else { return nil }
        return puzzle.entry(containing: selectedCell, direction: direction)
    }

    /// Selecting a new square keeps the direction if it has an entry there; selecting the
    /// same square again switches between Across and Down.
    func select(_ cell: Cell) {
        guard phase == .playing, let puzzle, !puzzle.isBlock(cell) else { return }
        if cell == selectedCell {
            toggleDirection()
            return
        }
        selectedCell = cell
        if puzzle.entry(containing: cell, direction: direction) == nil {
            direction = direction.other
        }
    }

    func toggleDirection() {
        guard let puzzle, let selectedCell,
              puzzle.entry(containing: selectedCell, direction: direction.other) != nil else { return }
        direction = direction.other
    }

    func select(_ entry: CrosswordPuzzle.Entry) {
        guard phase == .playing else { return }
        direction = entry.direction
        selectedCell = firstOpenCell(in: entry) ?? entry.cells.first
    }

    /// Moves to the next clue (or the previous one), Across then Down, wrapping around.
    func moveToEntry(offset: Int) {
        guard let puzzle, !puzzle.entries.isEmpty else { return }
        let entries = puzzle.entries
        let index = currentEntry.flatMap { entries.firstIndex(of: $0) } ?? -1
        let next = ((index + offset) % entries.count + entries.count) % entries.count
        select(entries[next])
    }

    // MARK: - Typing

    func type(_ letter: Character) {
        guard phase == .playing, let selectedCell, let entry = currentEntry,
              let upper = letter.uppercased().first, ("A"..."Z").contains(upper) else { return }
        if !revealedCells.contains(selectedCell) {
            guesses[selectedCell] = upper
            wrongCells.remove(selectedCell)
        }
        advance(from: selectedCell, in: entry)
        checkForCompletion()
    }

    /// Clears the selected square, or if it's already empty, steps back and clears that one.
    func deleteBackward() {
        guard phase == .playing, let selectedCell, let entry = currentEntry else { return }
        if guesses[selectedCell] != nil, !revealedCells.contains(selectedCell) {
            clear(selectedCell)
            return
        }
        let cells = entry.cells
        guard let index = cells.firstIndex(of: selectedCell), index > 0 else { return }
        let previous = cells[index - 1]
        self.selectedCell = previous
        if !revealedCells.contains(previous) {
            clear(previous)
        }
    }

    private func clear(_ cell: Cell) {
        guesses[cell] = nil
        wrongCells.remove(cell)
    }

    /// After typing, go to the next open square in this answer. If the answer is now full,
    /// jump to the next answer that still has an open square.
    private func advance(from cell: Cell, in entry: CrosswordPuzzle.Entry) {
        let cells = entry.cells
        guard let index = cells.firstIndex(of: cell) else { return }
        if let nextOpen = cells[(index + 1)...].first(where: isOpen) {
            selectedCell = nextOpen
        } else if let wrapped = cells[..<index].first(where: isOpen) {
            selectedCell = wrapped
        } else if let nextEntry = nextEntryWithOpenCell(after: entry) {
            direction = nextEntry.direction
            selectedCell = firstOpenCell(in: nextEntry)
        } else if index + 1 < cells.count {
            selectedCell = cells[index + 1]
        }
    }

    private func isOpen(_ cell: Cell) -> Bool {
        guesses[cell] == nil
    }

    private func firstOpenCell(in entry: CrosswordPuzzle.Entry) -> Cell? {
        entry.cells.first(where: isOpen)
    }

    private func nextEntryWithOpenCell(after entry: CrosswordPuzzle.Entry) -> CrosswordPuzzle.Entry? {
        guard let entries = puzzle?.entries, let index = entries.firstIndex(of: entry) else { return nil }
        let rotated = entries[(index + 1)...] + entries[..<index]
        return rotated.first { firstOpenCell(in: $0) != nil }
    }

    // MARK: - Hints

    /// True when every square has a letter but some are wrong.
    var isFilledWithMistakes: Bool {
        guard phase == .playing, let puzzle else { return false }
        let cells = allLetterCells(in: puzzle)
        return cells.allSatisfy { guesses[$0] != nil } && !isSolved
    }

    var canUseLetterHint: Bool { letterHintTarget != nil }

    var canUseWordHint: Bool {
        guard phase == .playing, let entry = currentEntry else { return false }
        return entry.cells.contains { !isCorrect($0) }
    }

    /// The selected square if it's wrong or empty, otherwise the first such square in the answer.
    private var letterHintTarget: Cell? {
        guard phase == .playing, let selectedCell, let entry = currentEntry else { return nil }
        if !isCorrect(selectedCell) { return selectedCell }
        return entry.cells.first { !isCorrect($0) }
    }

    func revealLetter() {
        guard let target = letterHintTarget, let entry = currentEntry else { return }
        reveal(target)
        letterHintsUsed += 1
        selectedCell = target
        advance(from: target, in: entry)
        checkForCompletion()
    }

    func revealWord() {
        guard canUseWordHint, let entry = currentEntry else { return }
        for cell in entry.cells where !isCorrect(cell) {
            reveal(cell)
        }
        wordHintsUsed += 1
        if let next = nextEntryWithOpenCell(after: entry) {
            select(next)
        }
        checkForCompletion()
    }

    /// Marks every wrong letter on the board. Returns how many were wrong.
    @discardableResult
    func checkPuzzle() -> Int {
        guard phase == .playing, let puzzle else { return 0 }
        checksUsed += 1
        wrongCells = Set(allLetterCells(in: puzzle).filter { cell in
            guard let guess = guesses[cell] else { return false }
            return guess != puzzle.letter(at: cell)
        })
        return wrongCells.count
    }

    /// Fills in the whole board and ends the round as a loss.
    func revealPuzzle() {
        guard phase == .playing, let puzzle else { return }
        for cell in allLetterCells(in: puzzle) where !isCorrect(cell) {
            reveal(cell)
        }
        finish(.revealed)
    }

    private func reveal(_ cell: Cell) {
        guard let solution = puzzle?.letter(at: cell) else { return }
        guesses[cell] = solution
        revealedCells.insert(cell)
        wrongCells.remove(cell)
    }

    // MARK: - Finishing

    private func isCorrect(_ cell: Cell) -> Bool {
        guard let solution = puzzle?.letter(at: cell) else { return true }
        return guesses[cell] == solution
    }

    private var isSolved: Bool {
        guard let puzzle else { return false }
        return allLetterCells(in: puzzle).allSatisfy(isCorrect)
    }

    private func allLetterCells(in puzzle: CrosswordPuzzle) -> [Cell] {
        Array(Set(puzzle.entries.flatMap(\.cells)))
    }

    private func checkForCompletion() {
        if isSolved { finish(.solved) }
    }

    private func finish(_ result: Outcome) {
        guard phase == .playing else { return }
        outcome = result
        phase = .finished
        selectedCell = nil
        wrongCells = []
        clock.pause()
        elapsedSeconds = max(1, clock.elapsedSeconds())
        clearSavedRound()
        recordBestTime(solved: result == .solved)

        // One board is one game: a solve counts as a win (hints are allowed), revealing
        // the puzzle counts as a loss and resets the streak, the same as Word Search.
        let won = result == .solved
        currentStreak = won ? defaults.integer(forKey: Self.currentStreakKey) + 1 : 0
        defaults.set(currentStreak, forKey: Self.currentStreakKey)

        guard recordsStats else { return }
        GameStats.shared.recordRound(
            game: .crossword,
            difficulty: difficulty.statsDifficulty,
            correct: won ? 1 : 0,
            answered: 1,
            currentBestStreak: currentStreak
        )
    }

    /// Fastest solved time at the current difficulty, if there is one.
    var savedBestTime: Int? {
        let value = defaults.integer(forKey: Self.bestTimeKey(for: difficulty))
        return value > 0 ? value : nil
    }

    /// Compares this puzzle's time with the best so far, and saves it if it's a new best.
    /// Only solved puzzles count, the same as Book Order.
    private func recordBestTime(solved: Bool) {
        let previousBest = savedBestTime
        bestTimeComparison = GameBestTimeComparison(seconds: elapsedSeconds, previousBest: previousBest, isSolved: solved)
        if solved, previousBest.map({ elapsedSeconds < $0 }) ?? true {
            defaults.set(elapsedSeconds, forKey: Self.bestTimeKey(for: difficulty))
        }
    }

    /// Answers the player filled in entirely without hints, for the results screen.
    func wasSolvedWithoutHints(_ entry: CrosswordPuzzle.Entry) -> Bool {
        !entry.cells.contains { revealedCells.contains($0) }
    }
}
