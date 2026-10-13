import SwiftUI

struct CrosswordGameView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var puzzle: CrosswordPuzzle?
    @State private var selectedCell: CrosswordCoordinate?
    @State private var enteredLetters: [CrosswordCoordinate: Character] = [:]
    @State private var typedLetter = ""
    @State private var isLoading = true
    @State private var revealed = false
    @FocusState private var isLetterFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView("Creating crossword…")
                        .frame(maxWidth: .infinity, minHeight: 260)
                } else if let puzzle {
                    CrosswordHeader(
                        filledCount: filledCount(for: puzzle),
                        totalCount: puzzle.occupiedCells.count,
                        isSolved: isSolved(puzzle)
                    )

                    CrosswordPuzzleLayout(
                        puzzle: puzzle,
                        enteredLetters: enteredLetters,
                        selectedCell: selectedCell,
                        revealed: revealed,
                        usesWideLayout: horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize,
                        onSelect: select,
                        onSelectEntry: select(entry:)
                    )

                    CrosswordLetterInput(
                        typedLetter: $typedLetter,
                        isFocused: $isLetterFieldFocused,
                        hasSelection: selectedCell != nil
                    )

                    HStack {
                        Button("Hint", systemImage: "lightbulb") {
                            revealSelectedLetter()
                        }
                        .buttonStyle(.bordered)

                        Button("Reveal Puzzle", systemImage: "eye") {
                            revealPuzzle()
                        }
                        .buttonStyle(.bordered)

                        Button("New Puzzle", systemImage: "arrow.clockwise") {
                            createPuzzle()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .labelStyle(.titleAndIcon)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                } else {
                    ContentUnavailableView(
                        "No Puzzle Available",
                        systemImage: "rectangle.slash",
                        description: Text("Try creating another crossword.")
                    )
                }
            }
            .padding()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                GameNavigationTitle(title: "Crossword", systemImage: "square.grid.3x3.fill", tint: .indigo)
            }
        }
        .task {
            if puzzle == nil {
                await loadPuzzle()
            }
        }
        .onChange(of: typedLetter) {
            acceptTypedLetter()
        }
    }

    private func loadPuzzle() async {
        isLoading = true
        let books = await BibleRepository.shared.loadAllBooks()
        puzzle = CrosswordEngine.makePuzzle(from: books)
        enteredLetters = [:]
        selectedCell = puzzle?.occupiedCells.sorted { ($0.row, $0.column) < ($1.row, $1.column) }.first
        revealed = false
        isLoading = false
    }

    private func createPuzzle() {
        Task {
            await loadPuzzle()
        }
    }

    private func select(_ coordinate: CrosswordCoordinate) {
        guard puzzle?.occupiedCells.contains(coordinate) == true else { return }
        selectedCell = coordinate
        isLetterFieldFocused = true
    }

    private func select(entry: CrosswordEntry) {
        select(CrosswordCoordinate(row: entry.row, column: entry.column))
    }

    private func acceptTypedLetter() {
        let letters = typedLetter.uppercased().filter(\.isLetter)
        guard let letter = letters.last, let selectedCell else {
            typedLetter = ""
            return
        }
        enteredLetters[selectedCell] = letter
        typedLetter = ""
        advanceSelection()
    }

    private func advanceSelection() {
        guard let puzzle, let selectedCell,
              let entry = puzzle.entries.first(where: { $0.cells.contains(selectedCell) }),
              let position = entry.cells.firstIndex(of: selectedCell) else { return }
        let next = entry.cells[(position + 1) % entry.cells.count]
        self.selectedCell = next
    }

    private func revealSelectedLetter() {
        guard let puzzle, let selectedCell, let answer = puzzle.solution[selectedCell] else { return }
        enteredLetters[selectedCell] = answer
    }

    private func revealPuzzle() {
        guard let puzzle else { return }
        enteredLetters = puzzle.solution
        revealed = true
    }

    private func filledCount(for puzzle: CrosswordPuzzle) -> Int {
        puzzle.occupiedCells.filter { enteredLetters[$0] != nil }.count
    }

    private func isSolved(_ puzzle: CrosswordPuzzle) -> Bool {
        !puzzle.solution.isEmpty && puzzle.solution.allSatisfy { enteredLetters[$0.key] == $0.value }
    }
}

private struct CrosswordHeader: View {
    let filledCount: Int
    let totalCount: Int
    let isSolved: Bool

    var body: some View {
        VStack(spacing: 5) {
            Text(isSolved ? "Crossword Complete!" : "A fresh puzzle from Scripture")
                .font(.title3.weight(.bold))
            Text(isSolved ? "Well done." : "\(filledCount) of \(totalCount) letters filled")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct CrosswordPuzzleLayout: View {
    let puzzle: CrosswordPuzzle
    let enteredLetters: [CrosswordCoordinate: Character]
    let selectedCell: CrosswordCoordinate?
    let revealed: Bool
    let usesWideLayout: Bool
    let onSelect: (CrosswordCoordinate) -> Void
    let onSelectEntry: (CrosswordEntry) -> Void

    var body: some View {
        if usesWideLayout {
            HStack(alignment: .top, spacing: 14) {
                CrosswordClueSection(
                    title: "Across",
                    entries: puzzle.entries.filter { $0.direction == .across },
                    numbering: puzzle.numbering,
                    selectedCell: selectedCell,
                    onSelect: onSelectEntry
                )
                .frame(width: 175, alignment: .leading)

                CrosswordBoard(
                    puzzle: puzzle,
                    enteredLetters: enteredLetters,
                    selectedCell: selectedCell,
                    revealed: revealed,
                    onSelect: onSelect
                )
                .frame(maxWidth: .infinity)
                .layoutPriority(1)

                CrosswordClueSection(
                    title: "Down",
                    entries: puzzle.entries.filter { $0.direction == .down },
                    numbering: puzzle.numbering,
                    selectedCell: selectedCell,
                    onSelect: onSelectEntry
                )
                .frame(width: 175, alignment: .leading)
            }
            .frame(maxWidth: 900)
        } else {
            VStack(spacing: 20) {
                CrosswordBoard(
                    puzzle: puzzle,
                    enteredLetters: enteredLetters,
                    selectedCell: selectedCell,
                    revealed: revealed,
                    onSelect: onSelect
                )
                .frame(maxWidth: 560)

                CrosswordClueList(
                    entries: puzzle.entries,
                    numbering: puzzle.numbering,
                    selectedCell: selectedCell,
                    onSelect: onSelectEntry
                )
            }
        }
    }
}

private struct CrosswordLetterInput: View {
    @Binding var typedLetter: String
    @FocusState.Binding var isFocused: Bool
    let hasSelection: Bool

    var body: some View {
        TextField("Tap a square, then type a letter", text: $typedLetter)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .keyboardType(.asciiCapable)
            .focused($isFocused)
            .disabled(!hasSelection)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 360)
            .accessibilityLabel("Crossword letter entry")
    }
}

private struct CrosswordBoard: View {
    let puzzle: CrosswordPuzzle
    let enteredLetters: [CrosswordCoordinate: Character]
    let selectedCell: CrosswordCoordinate?
    let revealed: Bool
    let onSelect: (CrosswordCoordinate) -> Void

    var body: some View {
        GeometryReader { proxy in
            let side = proxy.size.width / CGFloat(puzzle.size)
            VStack(spacing: 1) {
                ForEach(0..<puzzle.size, id: \.self) { row in
                    HStack(spacing: 1) {
                        ForEach(0..<puzzle.size, id: \.self) { column in
                            let coordinate = CrosswordCoordinate(row: row, column: column)
                            CrosswordCell(
                                letter: enteredLetters[coordinate],
                                answer: puzzle.solution[coordinate],
                                number: puzzle.numbering[coordinate],
                                isSelected: coordinate == selectedCell,
                                isRevealed: revealed,
                                side: side,
                                action: { onSelect(coordinate) }
                            )
                        }
                    }
                }
            }
            .background(.secondary.opacity(0.35))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct CrosswordCell: View {
    let letter: Character?
    let answer: Character?
    let number: Int?
    let isSelected: Bool
    let isRevealed: Bool
    let side: CGFloat
    let action: () -> Void

    var body: some View {
        if let answer {
            Button(action: action) {
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(isSelected ? Color.indigo.opacity(0.22) : Color(uiColor: .systemBackground))
                    if let number {
                        Text("\(number)")
                            .font(.system(size: max(7, side * 0.21), weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(2)
                    }
                    Text(String(letter ?? (isRevealed ? answer : " ")))
                        .font(.system(size: max(12, side * 0.52), weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .buttonStyle(.plain)
            .frame(width: side, height: side)
            .accessibilityLabel(number.map { "Square \($0)" } ?? "Crossword square")
            .accessibilityValue(letter.map(String.init) ?? "Empty")
        } else {
            Color.primary
                .frame(width: side, height: side)
                .accessibilityHidden(true)
        }
    }
}

private struct CrosswordClueList: View {
    let entries: [CrosswordEntry]
    let numbering: [CrosswordCoordinate: Int]
    let selectedCell: CrosswordCoordinate?
    let onSelect: (CrosswordEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CrosswordClueSection(
                title: "Across",
                entries: entries.filter { $0.direction == .across },
                numbering: numbering,
                selectedCell: selectedCell,
                onSelect: onSelect
            )
            CrosswordClueSection(
                title: "Down",
                entries: entries.filter { $0.direction == .down },
                numbering: numbering,
                selectedCell: selectedCell,
                onSelect: onSelect
            )
        }
        .frame(maxWidth: 560, alignment: .leading)
    }
}

private struct CrosswordClueSection: View {
    let title: LocalizedStringKey
    let entries: [CrosswordEntry]
    let numbering: [CrosswordCoordinate: Int]
    let selectedCell: CrosswordCoordinate?
    let onSelect: (CrosswordEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ForEach(entries) { entry in
                Button {
                    onSelect(entry)
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(numbering[CrosswordCoordinate(row: entry.row, column: entry.column)] ?? 0).")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                        Text(entry.clue)
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(entry.cells.contains(selectedCell ?? .invalid) ? .indigo : .primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct CrosswordCoordinate: Hashable, Comparable {
    let row: Int
    let column: Int

    static let invalid = CrosswordCoordinate(row: -1, column: -1)

    static func < (lhs: CrosswordCoordinate, rhs: CrosswordCoordinate) -> Bool {
        (lhs.row, lhs.column) < (rhs.row, rhs.column)
    }
}

private enum CrosswordDirection {
    case across
    case down
}

private struct CrosswordEntry: Identifiable {
    let answer: String
    let clue: String
    let row: Int
    let column: Int
    let direction: CrosswordDirection

    var id: String { "\(answer)-\(row)-\(column)-\(direction)" }

    var cells: [CrosswordCoordinate] {
        answer.enumerated().map { offset, _ in
            switch direction {
            case .across: CrosswordCoordinate(row: row, column: column + offset)
            case .down: CrosswordCoordinate(row: row + offset, column: column)
            }
        }
    }
}

private struct CrosswordPuzzle {
    let size: Int
    let entries: [CrosswordEntry]
    let solution: [CrosswordCoordinate: Character]

    var occupiedCells: Set<CrosswordCoordinate> {
        Set(solution.keys)
    }

    var numbering: [CrosswordCoordinate: Int] {
        var result: [CrosswordCoordinate: Int] = [:]
        var next = 1
        for row in 0..<size {
            for column in 0..<size {
                let coordinate = CrosswordCoordinate(row: row, column: column)
                if entries.contains(where: { $0.row == row && $0.column == column }) {
                    result[coordinate] = next
                    next += 1
                }
            }
        }
        return result
    }
}

private enum CrosswordEngine {
    private struct Candidate {
        let answer: String
        let clue: String
    }

    static func makePuzzle(from books: [Book]) -> CrosswordPuzzle? {
        let candidates = verseCandidates(from: books).shuffled()
        guard let first = candidates.first else { return nil }

        let size = 13
        var solution: [CrosswordCoordinate: Character] = [:]
        var entries: [CrosswordEntry] = []

        place(
            first,
            row: size / 2,
            column: max(0, (size - first.answer.count) / 2),
            direction: .across,
            solution: &solution,
            entries: &entries
        )

        for candidate in candidates.dropFirst() where entries.count < 10 {
            guard let placement = bestPlacement(for: candidate, size: size, solution: solution) else { continue }
            place(
                candidate,
                row: placement.row,
                column: placement.column,
                direction: placement.direction,
                solution: &solution,
                entries: &entries
            )
        }

        guard entries.count >= 5 else { return nil }
        return CrosswordPuzzle(size: size, entries: entries, solution: solution)
    }

    private static func verseCandidates(from books: [Book]) -> [Candidate] {
        let ignored = Set(["ABOUT", "AFTER", "AGAIN", "AMONG", "BEFORE", "BEING", "CHILDREN", "CHRIST", "EVERY", "FROM", "HAVE", "INTO", "LORD", "SHALL", "THEIR", "THERE", "THESE", "THEY", "THIS", "THOSE", "THROUGH", "UNTO", "WERE", "WHEN", "WHICH", "WITH", "WOULD", "YOUR"])
        var seen = Set<String>()
        var candidates: [Candidate] = []

        for book in books {
            for chapter in book.chapters {
                for verse in chapter.verses {
                    let words = verse.text.split { !$0.isLetter }.map(String.init)
                    for word in words {
                        let answer = word.uppercased()
                        guard (4...9).contains(answer.count),
                              !ignored.contains(answer),
                              seen.insert(answer).inserted else { continue }
                        let redacted = verse.text.replacingOccurrences(
                            of: word,
                            with: "____",
                            options: [.caseInsensitive, .diacriticInsensitive]
                        )
                        let excerpt = redacted.count > 115 ? String(redacted.prefix(112)) + "…" : redacted
                        candidates.append(
                            Candidate(
                                answer: answer,
                                clue: "Complete the verse: “\(excerpt)” — \(book.name) \(chapter.number):\(verse.number)"
                            )
                        )
                    }
                }
            }
        }
        return candidates
    }

    private static func bestPlacement(
        for candidate: Candidate,
        size: Int,
        solution: [CrosswordCoordinate: Character]
    ) -> (row: Int, column: Int, direction: CrosswordDirection)? {
        let letters = Array(candidate.answer)
        var placements: [(row: Int, column: Int, direction: CrosswordDirection)] = []

        for (coordinate, existing) in solution {
            for (offset, letter) in letters.enumerated() where letter == existing {
                for direction in [CrosswordDirection.across, .down] {
                    let row = direction == .across ? coordinate.row : coordinate.row - offset
                    let column = direction == .across ? coordinate.column - offset : coordinate.column
                    guard canPlace(
                        letters,
                        row: row,
                        column: column,
                        direction: direction,
                        size: size,
                        solution: solution
                    ) else { continue }
                    placements.append((row, column, direction))
                }
            }
        }
        return placements.randomElement()
    }

    private static func canPlace(
        _ letters: [Character],
        row: Int,
        column: Int,
        direction: CrosswordDirection,
        size: Int,
        solution: [CrosswordCoordinate: Character]
    ) -> Bool {
        for (offset, letter) in letters.enumerated() {
            let coordinate = direction == .across
                ? CrosswordCoordinate(row: row, column: column + offset)
                : CrosswordCoordinate(row: row + offset, column: column)
            guard (0..<size).contains(coordinate.row), (0..<size).contains(coordinate.column),
                  solution[coordinate] == nil || solution[coordinate] == letter else {
                return false
            }
        }
        return true
    }

    private static func place(
        _ candidate: Candidate,
        row: Int,
        column: Int,
        direction: CrosswordDirection,
        solution: inout [CrosswordCoordinate: Character],
        entries: inout [CrosswordEntry]
    ) {
        let entry = CrosswordEntry(
            answer: candidate.answer,
            clue: candidate.clue,
            row: row,
            column: column,
            direction: direction
        )
        entries.append(entry)
        for (coordinate, letter) in zip(entry.cells, candidate.answer) {
            solution[coordinate] = letter
        }
    }
}
