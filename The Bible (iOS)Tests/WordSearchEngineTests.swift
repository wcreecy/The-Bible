import Foundation
import Testing
@testable import Bible

struct WordSearchEngineTests {
    private static let verse = "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life. And the LORD spake unto Moses saying, Speak unto the children of Israel"

    private static let directions = [(0, 1), (1, 0), (0, -1), (-1, 0), (1, 1), (1, -1), (-1, 1), (-1, -1)]

    /// How many times `word` can be read in the grid, in any direction.
    private func occurrences(of word: String, in grid: [[Character]]) -> Int {
        let letters = Array(word)
        let size = grid.count
        var count = 0
        for r in 0..<size {
            for c in 0..<size {
                for (dr, dc) in Self.directions {
                    let endRow = r + dr * (letters.count - 1), endCol = c + dc * (letters.count - 1)
                    guard endRow >= 0, endRow < size, endCol >= 0, endCol < size else { continue }
                    if letters.indices.allSatisfy({ grid[r + dr * $0][c + dc * $0] == letters[$0] }) {
                        count += 1
                    }
                }
            }
        }
        // A palindrome reads the same both ways, so it is found twice on its own cells.
        return letters == letters.reversed() ? count / 2 : count
    }

    @Test(arguments: [
        (WordSearchEngine.Difficulty.easy, 10, 3...6),
        (.medium, 12, 4...7),
        (.hard, 14, 5...8),
        (.expert, 14, 6...10)
    ])
    func puzzlesAreCompleteAndEachAnswerAppearsOnce(difficulty: WordSearchEngine.Difficulty, size: Int, range: ClosedRange<Int>) {
        let engine = WordSearchEngine(size: size, difficulty: difficulty)
        for _ in 0..<10 {
            let puzzle = engine.generatePuzzle(from: Self.verse, countRange: range)

            #expect(!puzzle.placed.isEmpty)
            #expect(puzzle.grid.allSatisfy { row in row.count == size && !row.contains(" ") })
            for word in puzzle.placed {
                let read = String(engine.cellsForPlacedWord(word).map { puzzle.grid[$0.row][$0.col] })
                #expect(read == word.word)
                #expect(occurrences(of: word.word, in: puzzle.grid) == 1)
            }
        }
    }

    /// Words may share one letter, but only where they cross at an angle. Two words on the
    /// same line sharing an end letter would look like one long word.
    @Test(arguments: [
        (WordSearchEngine.Difficulty.easy, 10, 3...6),
        (.medium, 12, 4...7),
        (.hard, 14, 5...8),
        (.expert, 14, 6...10)
    ])
    func sharedLettersOnlyJoinWordsThatCross(difficulty: WordSearchEngine.Difficulty, size: Int, range: ClosedRange<Int>) {
        let engine = WordSearchEngine(size: size, difficulty: difficulty)
        var crossings = 0
        for _ in 0..<40 {
            let words = engine.generatePuzzle(from: Self.verse, countRange: range).placed
            for (i, first) in words.enumerated() {
                let firstCells = Set(engine.cellsForPlacedWord(first).map { "\($0.row),\($0.col)" })
                for second in words[(i + 1)...] {
                    let shared = engine.cellsForPlacedWord(second).filter { firstCells.contains("\($0.row),\($0.col)") }
                    guard !shared.isEmpty else { continue }
                    crossings += 1
                    let isParallel = (first.dr == second.dr && first.dc == second.dc)
                        || (first.dr == -second.dr && first.dc == -second.dc)
                    #expect(!isParallel, "\(first.word) and \(second.word) share a letter on the same line")
                    #expect(shared.count == 1)
                }
            }
        }
        // Crossings still happen; they're just never in a straight line.
        #expect(crossings > 0)
    }

    @Test
    func hardPuzzlesMixDirections() {
        let engine = WordSearchEngine(size: 14, difficulty: .hard)
        let varieties = (0..<20).map { _ in
            Set(engine.generatePuzzle(from: Self.verse, countRange: 5...8).placed.map { "\($0.dr),\($0.dc)" }).count
        }
        let average = Double(varieties.reduce(0, +)) / Double(varieties.count)
        #expect(average >= 5)
    }

    /// Placement once rewarded distance from the center, so about 80% of words started on an
    /// edge and nearly every puzzle had a word in the first column. Purely random placement
    /// gives about 50% on Easy; the limit leaves room for the spacing between words.
    @Test
    func wordsAreNotPushedToTheEdges() {
        let engine = WordSearchEngine(size: 10, difficulty: .easy)
        var edgeStarts = 0
        var starts = 0
        for _ in 0..<150 {
            for word in engine.generatePuzzle(from: Self.verse, countRange: 3...6).placed {
                starts += 1
                if word.startRow == 0 || word.startRow == 9 || word.startCol == 0 || word.startCol == 9 {
                    edgeStarts += 1
                }
            }
        }
        #expect(Double(edgeStarts) / Double(starts) < 0.7)
    }

    /// Hard puzzles once took over a second each because the placement search almost never
    /// stopped early. The bound is generous so slow test machines don't fail it.
    @Test
    func hardPuzzlesGenerateQuickly() {
        let engine = WordSearchEngine(size: 14, difficulty: .hard)
        let elapsed = ContinuousClock().measure {
            for _ in 0..<20 {
                _ = engine.generatePuzzle(from: Self.verse, countRange: 5...8)
            }
        }
        #expect(elapsed < .seconds(5))
    }
}
