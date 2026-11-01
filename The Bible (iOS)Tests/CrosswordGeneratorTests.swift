import Foundation
import Testing
@testable import Bible

struct CrosswordGeneratorTests {
    private static let answers = [
        "NOAH", "ABRAHAM", "ISAAC", "JACOB", "JOSEPH", "MOSES", "AARON", "MIRIAM", "JOSHUA", "GIDEON",
        "SAMSON", "SAMUEL", "DAVID", "SOLOMON", "ELIJAH", "ELISHA", "ISAIAH", "JEREMIAH", "EZEKIEL", "DANIEL",
        "JONAH", "MICAH", "HOSEA", "NAHUM", "MALACHI", "PETER", "ANDREW", "JAMES", "PHILIP", "THOMAS",
        "MATTHEW", "SIMON", "JUDAS", "PAUL", "BARNABAS", "TIMOTHY", "TITUS", "SILAS", "LYDIA", "MARTHA",
        "LAZARUS", "NICODEMUS", "ZACCHAEUS", "HEROD", "PILATE", "CAESAR", "EDEN", "BABEL", "CANAAN", "EGYPT",
        "SINAI", "JORDAN", "JERICHO", "BETHEL", "HEBRON", "BETHLEHEM", "NAZARETH", "GALILEE", "SAMARIA", "JUDEA",
        "ROME", "CORINTH", "EPHESUS", "PHILIPPI", "ANTIOCH", "DAMASCUS", "MANNA", "COVENANT", "TABERNACLE", "TEMPLE",
        "ALTAR", "PSALMS", "PROVERBS", "GENESIS", "EXODUS", "LEVITICUS", "NUMBERS", "RUTH", "ESTHER", "NEHEMIAH",
        "EZRA", "GOLIATH", "SAUL", "JONATHAN", "ABSALOM", "BATHSHEBA", "URIAH", "NATHAN", "RACHEL", "LEAH",
        "REBEKAH", "SARAH", "HAGAR", "ISHMAEL", "ESAU", "LABAN", "BENJAMIN", "JUDAH", "LEVI", "REUBEN",
        "GOSPEL", "GRACE", "MERCY", "FAITH", "HOPE", "CHARITY", "PRAYER", "SABBATH", "PASSOVER", "PENTECOST",
        "BAPTISM", "SHEPHERD", "SERPENT", "DOVE", "RAVEN", "LAMB", "LION", "OLIVE", "VINE", "CEDAR",
    ]

    private static let clues = answers.enumerated().map { offset, answer in
        CrosswordClueEntry(id: "test-\(offset)", answer: answer, clue: "Clue \(answer)", reference: "Ref", difficulty: "easy")
    }

    /// Every run of two or more letters in the grid, across and down.
    private func letterRuns(in puzzle: CrosswordPuzzle) -> [(cell: CrosswordPuzzle.Cell, direction: CrosswordPuzzle.Direction, word: String)] {
        var runs: [(CrosswordPuzzle.Cell, CrosswordPuzzle.Direction, String)] = []
        for direction in CrosswordPuzzle.Direction.allCases {
            let step = direction.step
            for line in 0..<puzzle.size {
                var position = 0
                while position < puzzle.size {
                    let start = direction == .across
                        ? CrosswordPuzzle.Cell(row: line, col: position)
                        : CrosswordPuzzle.Cell(row: position, col: line)
                    var word = ""
                    var cell = start
                    while let letter = puzzle.letter(at: cell) {
                        word.append(letter)
                        cell = CrosswordPuzzle.Cell(row: cell.row + step.row, col: cell.col + step.col)
                    }
                    if word.count >= 2 { runs.append((start, direction, word)) }
                    position += max(1, word.count)
                }
            }
        }
        return runs
    }

    @Test(arguments: CrosswordGenerator.supportedSizes)
    func generatedBoardsMeetTheRules(size: Int) throws {
        let settings = CrosswordGenerator.Settings.relaxed(size: size)
        for _ in 0..<10 {
            let puzzle = try #require(CrosswordGenerator.generate(from: Self.clues, preferredSize: size))
            #expect(puzzle.size <= size)
            #expect(puzzle.rows.count == puzzle.size)
            #expect(puzzle.rows.allSatisfy { $0.count == puzzle.size })

            // A fallback board may be smaller or built with relaxed rules, so hold every board
            // to the relaxed minimums.
            #expect(puzzle.entries.count >= settings.minEntries)
            #expect(puzzle.crossingCount >= settings.minCrossings)

            // Every answer is written into its cells, and no answer repeats.
            for entry in puzzle.entries {
                let written = String(entry.cells.compactMap { puzzle.letter(at: $0) })
                #expect(written == entry.answer)
                #expect(CrosswordGenerator.answerLengths.contains(entry.answer.count))
            }
            #expect(Set(puzzle.entries.map(\.answer)).count == puzzle.entries.count)

            // Every word you can read in the grid is a real entry: no accidental words.
            let runs = letterRuns(in: puzzle)
            #expect(runs.count == puzzle.entries.count)
            for run in runs {
                let entry = puzzle.entries.first { $0.row == run.cell.row && $0.col == run.cell.col && $0.direction == run.direction }
                #expect(entry?.answer == run.word)
            }
        }
    }

    @Test func everyEntryIsConnectedToTheRest() throws {
        let puzzle = try #require(CrosswordGenerator.generate(from: Self.clues, preferredSize: 13))
        var reached: Set<CrosswordPuzzle.Cell> = []
        var frontier = [try #require(puzzle.entries.first?.cells.first)]
        while let cell = frontier.popLast() {
            guard puzzle.letter(at: cell) != nil, reached.insert(cell).inserted else { continue }
            frontier += [
                .init(row: cell.row + 1, col: cell.col), .init(row: cell.row - 1, col: cell.col),
                .init(row: cell.row, col: cell.col + 1), .init(row: cell.row, col: cell.col - 1),
            ]
        }
        #expect(reached == Set(puzzle.entries.flatMap(\.cells)))
    }

    @Test func numbersFollowReadingOrder() throws {
        let puzzle = try #require(CrosswordGenerator.generate(from: Self.clues, preferredSize: 11))
        let starts = Set(puzzle.entries.map { CrosswordPuzzle.Cell(row: $0.row, col: $0.col) })
            .sorted { ($0.row, $0.col) < ($1.row, $1.col) }
        for (offset, cell) in starts.enumerated() {
            #expect(puzzle.number(at: cell) == offset + 1)
        }
    }

    @Test func boardsAreRandom() {
        let layouts = Set((0..<5).compactMap { _ in CrosswordGenerator.generate(from: Self.clues, preferredSize: 11)?.rows })
        #expect(layouts.count > 1)
    }

    @Test func aliasesKeepOnePersonOffTheBoardTwice() throws {
        let clues = Self.clues + [
            CrosswordClueEntry(id: "israel", answer: "ISRAEL", clue: "Jacob's new name", reference: "Genesis 32:28", difficulty: "easy", aliases: ["JACOB"]),
        ]
        for _ in 0..<10 {
            let puzzle = try #require(CrosswordGenerator.generate(from: clues, preferredSize: 13))
            let answers = Set(puzzle.entries.map(\.answer))
            #expect(!(answers.contains("JACOB") && answers.contains("ISRAEL")))
        }
    }

    @Test func answersThatDoNotFitAreSkipped() throws {
        let clues = Self.clues + [
            CrosswordClueEntry(id: "long", answer: "MAHERSHALALHASHBAZ", clue: "", reference: "", difficulty: "hard"),
            CrosswordClueEntry(id: "space", answer: "RED SEA", clue: "", reference: "", difficulty: "easy"),
        ]
        for _ in 0..<5 {
            let puzzle = try #require(CrosswordGenerator.generate(from: clues, preferredSize: 9))
            #expect(puzzle.entries.allSatisfy { $0.answer.count <= puzzle.size })
            #expect(!puzzle.entries.contains { $0.clueID == "long" || $0.clueID == "space" })
        }
    }

    @Test func tooFewCluesReturnsNil() {
        let clues = Array(Self.clues.prefix(3))
        #expect(CrosswordGenerator.generate(from: clues, preferredSize: 9) == nil)
    }
}
