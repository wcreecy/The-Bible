import Foundation

/// One clue in `CrosswordClues.json`.
nonisolated struct CrosswordClueEntry: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let answer: String
    let clue: String
    let reference: String
    let difficulty: String
    /// Other names for the same answer (for example JACOB / ISRAEL). Two clues that share a
    /// name are never placed on the same board.
    let aliases: [String]

    init(id: String, answer: String, clue: String, reference: String, difficulty: String, aliases: [String] = []) {
        self.id = id
        self.answer = answer
        self.clue = clue
        self.reference = reference
        self.difficulty = difficulty
        self.aliases = aliases
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        answer = try container.decode(String.self, forKey: .answer)
        clue = try container.decode(String.self, forKey: .clue)
        reference = try container.decode(String.self, forKey: .reference)
        difficulty = try container.decode(String.self, forKey: .difficulty)
        aliases = try container.decodeIfPresent([String].self, forKey: .aliases) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case id, answer, clue, reference, difficulty, aliases
    }

    /// The letters that go in the grid, uppercased with anything that isn't A–Z removed.
    var gridAnswer: String {
        Self.normalized(answer)
    }

    /// Every name this clue covers, used to keep duplicates off one board.
    var normalizedNames: Set<String> {
        Set(([answer] + aliases).map(Self.normalized).filter { !$0.isEmpty })
    }

    static func normalized(_ text: String) -> String {
        String(text.uppercased().filter { ("A"..."Z").contains($0) })
    }
}

/// A finished crossword layout. It is Codable so hand-built or pre-generated puzzles can be
/// bundled as a fallback.
nonisolated struct CrosswordPuzzle: Codable, Hashable, Sendable {
    enum Direction: String, Codable, CaseIterable, Sendable {
        case across
        case down

        var step: (row: Int, col: Int) {
            switch self {
            case .across: (0, 1)
            case .down: (1, 0)
            }
        }

        var other: Direction {
            self == .across ? .down : .across
        }
    }

    struct Cell: Codable, Hashable, Sendable {
        let row: Int
        let col: Int
    }

    struct Entry: Codable, Hashable, Identifiable, Sendable {
        let number: Int
        let direction: Direction
        let row: Int
        let col: Int
        let answer: String
        let clue: String
        let reference: String
        let clueID: String

        var id: String { "\(number)-\(direction.rawValue)" }

        var cells: [Cell] {
            let step = direction.step
            return (0..<answer.count).map { Cell(row: row + step.row * $0, col: col + step.col * $0) }
        }
    }

    /// The character used in `rows` for a black square.
    static let blockMarker: Character = "#"

    let size: Int
    /// The solution, one string per row, with `#` for black squares.
    let rows: [String]
    /// Across entries first, then Down, each in number order.
    let entries: [Entry]

    var acrossEntries: [Entry] { entries.filter { $0.direction == .across } }
    var downEntries: [Entry] { entries.filter { $0.direction == .down } }

    /// The solution letter for a cell, or nil for a black square or a cell off the board.
    func letter(at cell: Cell) -> Character? {
        guard cell.row >= 0, cell.row < size, cell.col >= 0, cell.col < size else { return nil }
        let row = rows[cell.row]
        let character = row[row.index(row.startIndex, offsetBy: cell.col)]
        return character == Self.blockMarker ? nil : character
    }

    func isBlock(_ cell: Cell) -> Bool {
        letter(at: cell) == nil
    }

    /// The small number printed in a cell's corner, if an entry starts there.
    func number(at cell: Cell) -> Int? {
        entries.first { $0.row == cell.row && $0.col == cell.col }?.number
    }

    /// The entry running through `cell` in `direction`, if there is one.
    func entry(containing cell: Cell, direction: Direction) -> Entry? {
        entries.first { $0.direction == direction && $0.cells.contains(cell) }
    }

    /// Cells that belong to both an Across and a Down entry.
    var crossingCount: Int {
        let across = Set(acrossEntries.flatMap(\.cells))
        return Set(downEntries.flatMap(\.cells)).intersection(across).count
    }
}
