import Foundation
import Testing
@testable import Bible

@MainActor
struct CrosswordGameViewModelTests {
    typealias Cell = CrosswordPuzzle.Cell

    /// A small fixed board:
    ///
    ///     N O A H #
    ///     # # R # #
    ///     # # K I N
    ///
    /// 1 Across NOAH, 2 Down ARK, 3 Across KIN.
    private static let puzzle = CrosswordPuzzle(
        size: 5,
        rows: ["NOAH#", "##R##", "##KIN", "#####", "#####"],
        entries: [
            .init(number: 1, direction: .across, row: 0, col: 0, answer: "NOAH", clue: "Ark builder", reference: "Genesis 6:14", clueID: "noah"),
            .init(number: 3, direction: .across, row: 2, col: 2, answer: "KIN", clue: "Family", reference: "Ruth 2:20", clueID: "kin"),
            .init(number: 2, direction: .down, row: 0, col: 2, answer: "ARK", clue: "Noah's boat", reference: "Genesis 6:14", clueID: "ark"),
        ]
    )

    private func makeViewModel() -> (CrosswordGameViewModel, UserDefaults) {
        let suite = "CrosswordGameViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let vm = CrosswordGameViewModel(defaults: defaults, recordsStats: false, loadClues: { [] })
        vm.begin(with: Self.puzzle)
        return (vm, defaults)
    }

    @Test func startsOnTheFirstClue() {
        let (vm, _) = makeViewModel()
        #expect(vm.selectedCell == Cell(row: 0, col: 0))
        #expect(vm.direction == .across)
        #expect(vm.currentEntry?.answer == "NOAH")
    }

    @Test func typingAdvancesAndJumpsToTheNextOpenClue() {
        let (vm, _) = makeViewModel()
        for letter in "noah" { vm.type(letter) }
        #expect(vm.guesses[Cell(row: 0, col: 0)] == "N")
        // NOAH is full, so the cursor moves to KIN, the next clue with an empty square.
        #expect(vm.currentEntry?.answer == "KIN")
        #expect(vm.selectedCell == Cell(row: 2, col: 2))
    }

    @Test func tappingTheSameSquareSwitchesDirection() {
        let (vm, _) = makeViewModel()
        vm.select(Cell(row: 0, col: 2))
        #expect(vm.direction == .across)
        vm.select(Cell(row: 0, col: 2))
        #expect(vm.direction == .down)
        #expect(vm.currentEntry?.answer == "ARK")
    }

    @Test func selectingASquareWithOnlyOneDirectionUsesIt() {
        let (vm, _) = makeViewModel()
        vm.select(Cell(row: 1, col: 2))
        #expect(vm.direction == .down)
    }

    @Test func blackSquaresCannotBeSelected() {
        let (vm, _) = makeViewModel()
        vm.select(Cell(row: 1, col: 0))
        #expect(vm.selectedCell == Cell(row: 0, col: 0))
    }

    @Test func deleteClearsThenStepsBack() {
        let (vm, _) = makeViewModel()
        vm.type("N")
        vm.type("O")
        #expect(vm.selectedCell == Cell(row: 0, col: 2))
        vm.deleteBackward()
        #expect(vm.selectedCell == Cell(row: 0, col: 1))
        #expect(vm.guesses[Cell(row: 0, col: 1)] == nil)
        #expect(vm.guesses[Cell(row: 0, col: 0)] == "N")
    }

    @Test func letterHintFillsAndLocksTheSquare() {
        let (vm, _) = makeViewModel()
        vm.revealLetter()
        #expect(vm.guesses[Cell(row: 0, col: 0)] == "N")
        #expect(vm.revealedCells.contains(Cell(row: 0, col: 0)))
        #expect(vm.letterHintsUsed == 1)

        // Typing over a hinted square doesn't change it.
        vm.select(Cell(row: 0, col: 0))
        vm.type("X")
        #expect(vm.guesses[Cell(row: 0, col: 0)] == "N")
    }

    @Test func wordHintFillsTheCurrentAnswer() {
        let (vm, _) = makeViewModel()
        vm.revealWord()
        #expect(Self.puzzle.entries[0].cells.allSatisfy { vm.guesses[$0] == Self.puzzle.letter(at: $0) })
        #expect(vm.wordHintsUsed == 1)
        #expect(vm.phase == .playing)
    }

    @Test func checkMarksOnlyWrongLetters() {
        let (vm, _) = makeViewModel()
        vm.type("N")
        vm.type("X")
        #expect(vm.checkPuzzle() == 1)
        #expect(vm.wrongCells == [Cell(row: 0, col: 1)])

        // Fixing the square clears its mark.
        vm.select(Cell(row: 0, col: 1))
        vm.type("O")
        #expect(vm.wrongCells.isEmpty)
    }

    @Test func solvingWinsAndBuildsTheStreak() {
        let (vm, defaults) = makeViewModel()
        for letter in "NOAH" { vm.type(letter) }
        for letter in "KIN" { vm.type(letter) }
        // ARK's R is the only square left.
        vm.type("R")
        #expect(vm.phase == .finished)
        #expect(vm.outcome == .solved)
        #expect(vm.currentStreak == 1)
        #expect(defaults.integer(forKey: CrosswordGameViewModel.currentStreakKey) == 1)
    }

    @Test func aFullBoardWithMistakesIsNotSolved() {
        let (vm, _) = makeViewModel()
        for letter in "NOAHKINX" { vm.type(letter) }
        #expect(vm.phase == .playing)
        #expect(vm.isFilledWithMistakes)
    }

    @Test func revealingThePuzzleIsALossAndResetsTheStreak() {
        let (vm, defaults) = makeViewModel()
        defaults.set(4, forKey: CrosswordGameViewModel.currentStreakKey)
        vm.revealPuzzle()
        #expect(vm.outcome == .revealed)
        #expect(vm.currentStreak == 0)
        #expect(defaults.integer(forKey: CrosswordGameViewModel.currentStreakKey) == 0)
    }

    @Test func moveToEntryWrapsAround() {
        let (vm, _) = makeViewModel()
        vm.moveToEntry(offset: -1)
        #expect(vm.currentEntry?.answer == "ARK")
        vm.moveToEntry(offset: 1)
        #expect(vm.currentEntry?.answer == "NOAH")
    }

    @Test func newPuzzlesDontReuseAnswersFromRecentPuzzles() async throws {
        let suite = "CrosswordGameViewModelTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let vm = CrosswordGameViewModel(defaults: defaults, recordsStats: false)
        vm.difficulty = .easy

        var previous: [Set<String>] = []
        for _ in 0..<8 {
            await vm.start()
            let answers = Set(try #require(vm.puzzle).entries.map(\.answer))
            // Nothing from the last few puzzles comes back.
            let recent = previous.suffix(CrosswordGameViewModel.rememberedPuzzleCount).reduce(into: Set<String>()) { $0.formUnion($1) }
            #expect(answers.isDisjoint(with: recent), "Repeated: \(answers.intersection(recent).sorted())")
            previous.append(answers)
        }

        // Only the last few puzzles are remembered.
        let stored = defaults.array(forKey: CrosswordGameViewModel.recentAnswersKey) as? [[String]]
        #expect(stored?.count == CrosswordGameViewModel.rememberedPuzzleCount)
    }

    @Test func bundledCluesBuildABoardAtEveryDifficulty() async {
        for difficulty in CrosswordGameViewModel.Difficulty.allCases {
            let suite = "CrosswordGameViewModelTests.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            let vm = CrosswordGameViewModel(defaults: defaults, recordsStats: false)
            vm.difficulty = difficulty
            await vm.start()
            #expect(vm.phase == .playing)
            let entries = vm.puzzle?.entries ?? []
            let clues = GameDataLoaders.loadCrosswordClues()
            let used = Set(entries.map(\.clueID))
            #expect(clues.filter { used.contains($0.id) }.allSatisfy { difficulty.clueDifficulties.contains($0.difficulty) })
            defaults.removePersistentDomain(forName: suite)
        }
    }
}
