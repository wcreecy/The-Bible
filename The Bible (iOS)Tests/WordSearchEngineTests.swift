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

    @Test
    func hardPuzzlesMixDirections() {
        let engine = WordSearchEngine(size: 14, difficulty: .hard)
        let varieties = (0..<20).map { _ in
            Set(engine.generatePuzzle(from: Self.verse, countRange: 5...8).placed.map { "\($0.dr),\($0.dc)" }).count
        }
        let average = Double(varieties.reduce(0, +)) / Double(varieties.count)
        #expect(average >= 5)
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
