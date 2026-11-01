import SwiftUI

/// Draws a crossword grid: black squares, clue numbers, the player's letters, and the
/// selected word. It holds no game state; the game screen passes everything in.
struct CrosswordBoardView: View {
    let puzzle: CrosswordPuzzle
    /// Letters the player has typed, keyed by cell.
    let guesses: [CrosswordPuzzle.Cell: Character]
    /// Cells filled in by a hint, drawn in a different color.
    let revealedCells: Set<CrosswordPuzzle.Cell>
    let selectedCell: CrosswordPuzzle.Cell?
    let selectedDirection: CrosswordPuzzle.Direction
    /// When true, letters that don't match the solution are marked.
    var showsMistakes = false
    let onTapCell: (CrosswordPuzzle.Cell) -> Void

    /// The cells of the word the selected cell belongs to, in the selected direction.
    private var highlightedCells: Set<CrosswordPuzzle.Cell> {
        guard let selectedCell else { return [] }
        let entry = puzzle.entry(containing: selectedCell, direction: selectedDirection)
            ?? puzzle.entry(containing: selectedCell, direction: selectedDirection.other)
        return Set(entry?.cells ?? [])
    }

    var body: some View {
        let highlighted = highlightedCells
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cellSize = side / CGFloat(puzzle.size)

            VStack(spacing: 0) {
                ForEach(0..<puzzle.size, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<puzzle.size, id: \.self) { col in
                            let cell = CrosswordPuzzle.Cell(row: row, col: col)
                            cellView(cell, size: cellSize, highlighted: highlighted)
                        }
                    }
                }
            }
            .frame(width: side, height: side)
            .overlay(Rectangle().stroke(Color.primary.opacity(0.6), lineWidth: 1.5))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func cellView(_ cell: CrosswordPuzzle.Cell, size: CGFloat, highlighted: Set<CrosswordPuzzle.Cell>) -> some View {
        if let solution = puzzle.letter(at: cell) {
            let guess = guesses[cell]
            let isWrong = showsMistakes && guess != nil && guess != solution
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(fillColor(for: cell, highlighted: highlighted))
                if let number = puzzle.number(at: cell) {
                    Text("\(number)")
                        .font(.system(size: max(7, size * 0.26), weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, size * 0.06)
                        .padding(.top, size * 0.02)
                }
                Text(guess.map(String.init) ?? "")
                    .font(.system(size: size * 0.55, weight: .bold, design: .rounded))
                    .foregroundStyle(letterColor(for: cell, isWrong: isWrong))
                    .frame(width: size, height: size)
                    .offset(y: size * 0.05)
                if isWrong {
                    Path { path in
                        path.move(to: CGPoint(x: size * 0.15, y: size * 0.85))
                        path.addLine(to: CGPoint(x: size * 0.85, y: size * 0.15))
                    }
                    .stroke(Color.red.opacity(0.7), lineWidth: 1.5)
                }
            }
            .frame(width: size, height: size)
            .overlay(Rectangle().stroke(Color.primary.opacity(0.35), lineWidth: 0.5))
            .contentShape(Rectangle())
            .onTapGesture { onTapCell(cell) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel(for: cell, guess: guess))
            .accessibilityAddTraits(cell == selectedCell ? [.isButton, .isSelected] : .isButton)
        } else {
            Rectangle()
                .fill(Color.primary.opacity(0.85))
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }

    private func fillColor(for cell: CrosswordPuzzle.Cell, highlighted: Set<CrosswordPuzzle.Cell>) -> Color {
        if cell == selectedCell { return Color.accentColor.opacity(0.45) }
        if highlighted.contains(cell) { return Color.accentColor.opacity(0.18) }
        return Color(.systemBackground)
    }

    private func letterColor(for cell: CrosswordPuzzle.Cell, isWrong: Bool) -> Color {
        if isWrong { return .red }
        if revealedCells.contains(cell) { return .blue }
        return .primary
    }

    private func accessibilityLabel(for cell: CrosswordPuzzle.Cell, guess: Character?) -> String {
        var parts: [String] = []
        if let number = puzzle.number(at: cell) {
            parts.append(String(localized: "\(number)"))
        }
        parts.append(String(localized: "Row \(cell.row + 1), column \(cell.col + 1)"))
        parts.append(guess.map { String($0) } ?? String(localized: "Empty"))
        return parts.joined(separator: ", ")
    }
}

#if DEBUG
private struct CrosswordBoardPreview: View {
    @State private var selectedCell: CrosswordPuzzle.Cell?
    @State private var direction: CrosswordPuzzle.Direction = .across
    @State private var puzzle = CrosswordGenerator.generate(from: Self.sampleClues, preferredSize: 11)

    static let sampleClues: [CrosswordClueEntry] = [
        "NOAH", "ABRAHAM", "ISAAC", "JACOB", "JOSEPH", "MOSES", "AARON", "MIRIAM", "JOSHUA", "GIDEON",
        "SAMSON", "SAMUEL", "DAVID", "SOLOMON", "ELIJAH", "ELISHA", "ISAIAH", "JEREMIAH", "DANIEL", "JONAH",
        "PETER", "ANDREW", "JAMES", "PHILIP", "THOMAS", "MATTHEW", "SIMON", "PAUL", "BARNABAS", "TIMOTHY",
        "LYDIA", "MARTHA", "LAZARUS", "ZACCHAEUS", "HEROD", "PILATE", "CANAAN", "EGYPT", "SINAI", "JORDAN",
        "JERICHO", "BETHEL", "HEBRON", "BETHLEHEM", "NAZARETH", "GALILEE", "SAMARIA", "CORINTH", "EPHESUS", "MANNA",
        "COVENANT", "TABERNACLE", "TEMPLE", "ALTAR", "GENESIS", "EXODUS", "RUTH", "ESTHER", "GOLIATH", "RACHEL",
        "REBEKAH", "SARAH", "BENJAMIN", "GOSPEL", "GRACE", "MERCY", "FAITH", "PRAYER", "SABBATH", "PASSOVER",
    ].enumerated().map { offset, answer in
        CrosswordClueEntry(id: "preview-\(offset)", answer: answer, clue: "Clue for \(answer)", reference: "", difficulty: "easy")
    }

    var body: some View {
        VStack {
            if let puzzle {
                CrosswordBoardView(
                    puzzle: puzzle,
                    guesses: [:],
                    revealedCells: [],
                    selectedCell: selectedCell,
                    selectedDirection: direction,
                    onTapCell: { cell in
                        // Tapping the selected cell again switches between Across and Down.
                        if cell == selectedCell { direction = direction.other }
                        selectedCell = cell
                    }
                )
                .padding()
            }
            Button("New Board") {
                puzzle = CrosswordGenerator.generate(from: Self.sampleClues, preferredSize: 11)
                selectedCell = nil
            }
        }
    }
}

#Preview {
    CrosswordBoardPreview()
}
#endif
