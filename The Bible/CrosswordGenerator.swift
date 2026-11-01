import Foundation

/// Builds a random freeform crossword from a pool of clues.
///
/// Each attempt shuffles the pool, seeds the board with a long answer, then keeps adding
/// answers only where they cross a matching letter already on the board. Because every
/// answer after the first must cross another, the board is always one connected piece.
/// Boards that are too sparse, too small, or too lopsided are rejected; the best of several
/// attempts is kept, and if a size never produces a good board the next smaller size is tried.
nonisolated struct CrosswordGenerator: Sendable {
    struct Settings: Sendable {
        let size: Int
        let minEntries: Int
        let minCrossings: Int
        /// The fraction of the board's width and height the answers must span.
        let minSpan: Double
        /// How many shuffled pools to try at this size.
        let attempts: Int
        /// How many shuffled clues each attempt considers.
        let candidatePoolSize: Int

        static func standard(size: Int) -> Settings {
            switch size {
            case ..<10:
                Settings(size: size, minEntries: 8, minCrossings: 8, minSpan: 0.75, attempts: 40, candidatePoolSize: 70)
            case 10..<12:
                Settings(size: size, minEntries: 11, minCrossings: 11, minSpan: 0.75, attempts: 40, candidatePoolSize: 90)
            default:
                Settings(size: size, minEntries: 14, minCrossings: 14, minSpan: 0.75, attempts: 40, candidatePoolSize: 110)
            }
        }

        /// Looser rules for the last try before giving up on generating a board.
        static func relaxed(size: Int) -> Settings {
            Settings(size: size, minEntries: 5, minCrossings: 4, minSpan: 0.5, attempts: 40, candidatePoolSize: 120)
        }
    }

    static let supportedSizes = [9, 11, 13]
    static let answerLengths = 4...10

    /// Generates a board at `preferredSize`, falling back to smaller sizes and then to relaxed
    /// rules. Returns nil only when the pool can't make any acceptable board, in which case the
    /// caller should use a pre-generated puzzle.
    ///
    /// Answers in `recentAnswers` (from the player's last few puzzles) are left out while
    /// enough other clues remain, so the same words don't come back puzzle after puzzle.
    static func generate<R: RandomNumberGenerator>(
        from clues: [CrosswordClueEntry],
        preferredSize: Int,
        avoiding recentAnswers: Set<String> = [],
        using rng: inout R
    ) -> CrosswordPuzzle? {
        let sizes = supportedSizes.filter { $0 <= preferredSize }.sorted(by: >)
        for size in sizes.isEmpty ? [supportedSizes[0]] : sizes {
            if let puzzle = generate(from: clues, settings: .standard(size: size), avoiding: recentAnswers, using: &rng) {
                return puzzle
            }
        }
        return generate(from: clues, settings: .relaxed(size: sizes.last ?? supportedSizes[0]), avoiding: recentAnswers, using: &rng)
    }

    static func generate(from clues: [CrosswordClueEntry], preferredSize: Int, avoiding recentAnswers: Set<String> = []) -> CrosswordPuzzle? {
        var rng = SystemRandomNumberGenerator()
        return generate(from: clues, preferredSize: preferredSize, avoiding: recentAnswers, using: &rng)
    }

    /// One size, one set of rules. Returns the best acceptable board from all attempts.
    static func generate<R: RandomNumberGenerator>(
        from clues: [CrosswordClueEntry],
        settings: Settings,
        avoiding recentAnswers: Set<String> = [],
        using rng: inout R
    ) -> CrosswordPuzzle? {
        let maxLength = min(answerLengths.upperBound, settings.size)
        let fitting = clues.filter { clue in
            let answer = clue.gridAnswer
            return answer.count >= answerLengths.lowerBound
                && answer.count <= maxLength
                && answer.count == clue.answer.count
        }
        // Skip recently used answers, but only while plenty of clues are left to build from.
        let fresh = fitting.filter { !recentAnswers.contains($0.gridAnswer) }
        let eligible = fresh.count >= max(settings.candidatePoolSize, settings.minEntries * 6) ? fresh : fitting
        guard eligible.count >= settings.minEntries else { return nil }

        var best: (layout: Layout, score: Double)?
        for _ in 0..<settings.attempts {
            let pool = Array(eligible.shuffled(using: &rng).prefix(settings.candidatePoolSize))
            guard let layout = buildLayout(from: pool, size: settings.size, using: &rng),
                  isAcceptable(layout, settings: settings) else { continue }
            let score = layout.qualityScore
            if best == nil || score > best!.score {
                best = (layout, score)
            }
        }
        guard var layout = best?.layout else { return nil }
        layout.center()
        return layout.makePuzzle()
    }

    // MARK: - Building

    private static func buildLayout<R: RandomNumberGenerator>(
        from pool: [CrosswordClueEntry],
        size: Int,
        using rng: inout R
    ) -> Layout? {
        // Roughly longest first, so short answers fill the gaps long ones leave. Each answer's
        // length gets a random boost of up to 3 letters, so the first (seed) answer isn't always
        // one of the few longest words in the list, which made those repeat on most boards.
        let ordered = pool
            .map { (clue: $0, rank: Double($0.gridAnswer.count) + Double.random(in: 0..<3, using: &rng)) }
            .sorted { $0.rank > $1.rank }
            .map(\.clue)
        guard let seed = ordered.first else { return nil }

        var layout = Layout(size: size)
        let seedLetters = Array(seed.gridAnswer)
        let seedDirection: CrosswordPuzzle.Direction = Bool.random(using: &rng) ? .across : .down
        // Seed near the middle line, at a random offset along it.
        let middle = size / 2
        let line = middle + Int.random(in: -1...1, using: &rng)
        let offset = Int.random(in: 0...(size - seedLetters.count), using: &rng)
        let seedCell = seedDirection == .across
            ? CrosswordPuzzle.Cell(row: line, col: offset)
            : CrosswordPuzzle.Cell(row: offset, col: line)
        layout.place(seed, letters: seedLetters, at: seedCell, direction: seedDirection, crossings: 0)

        var remaining = Array(ordered.dropFirst())
        // Keep sweeping the list: an answer that didn't fit earlier may fit once more
        // letters are on the board.
        var placedSomething = true
        while placedSomething {
            placedSomething = false
            var stillRemaining: [CrosswordClueEntry] = []
            for clue in remaining {
                guard layout.canUse(clue) else { continue }
                let letters = Array(clue.gridAnswer)
                if let option = layout.bestPlacement(for: letters, using: &rng) {
                    layout.place(clue, letters: letters, at: option.cell, direction: option.direction, crossings: option.crossings)
                    placedSomething = true
                } else {
                    stillRemaining.append(clue)
                }
            }
            remaining = stillRemaining
        }
        return layout
    }

    private static func isAcceptable(_ layout: Layout, settings: Settings) -> Bool {
        guard layout.placements.count >= settings.minEntries,
              layout.crossings >= settings.minCrossings,
              let bounds = layout.bounds else { return false }
        let minSpan = Int((Double(settings.size) * settings.minSpan).rounded(.up))
        // Both directions must be used; a board of only Across answers can't cross at all,
        // but this also rules out a board that is nearly all one direction.
        let acrossCount = layout.placements.filter { $0.direction == .across }.count
        let downCount = layout.placements.count - acrossCount
        return bounds.height >= minSpan
            && bounds.width >= minSpan
            && min(acrossCount, downCount) * 3 >= layout.placements.count
    }
}

// MARK: - Layout

nonisolated extension CrosswordGenerator {
    struct Placement {
        let clue: CrosswordClueEntry
        let letters: [Character]
        var cell: CrosswordPuzzle.Cell
        let direction: CrosswordPuzzle.Direction
    }

    struct PlacementOption {
        let cell: CrosswordPuzzle.Cell
        let direction: CrosswordPuzzle.Direction
        let crossings: Int
    }

    /// A board under construction. Cells are stored flat, row by row.
    struct Layout {
        let size: Int
        private(set) var letters: [Character?]
        private(set) var usedAcross: [Bool]
        private(set) var usedDown: [Bool]
        private(set) var placements: [Placement] = []
        private(set) var crossings = 0
        private var usedNames: Set<String> = []
        /// Where each letter appears, so placements are only tried where they can cross.
        private var letterIndex: [Character: [Int]] = [:]

        init(size: Int) {
            self.size = size
            letters = Array(repeating: nil, count: size * size)
            usedAcross = Array(repeating: false, count: size * size)
            usedDown = Array(repeating: false, count: size * size)
        }

        private func index(_ row: Int, _ col: Int) -> Int { row * size + col }

        private func inBounds(_ row: Int, _ col: Int) -> Bool {
            row >= 0 && row < size && col >= 0 && col < size
        }

        private func isFilled(_ row: Int, _ col: Int) -> Bool {
            inBounds(row, col) && letters[index(row, col)] != nil
        }

        private func isUsed(_ idx: Int, _ direction: CrosswordPuzzle.Direction) -> Bool {
            direction == .across ? usedAcross[idx] : usedDown[idx]
        }

        /// False when this clue, or another name for it, is already on the board.
        func canUse(_ clue: CrosswordClueEntry) -> Bool {
            usedNames.isDisjoint(with: clue.normalizedNames)
        }

        /// How many existing letters the answer would cross, or nil if it can't go here.
        ///
        /// An answer may only touch the board where it crosses. Every new letter must have
        /// empty cells on both sides, and the cells just before and after the answer must be
        /// empty, so no unintended words are formed.
        func crossingsIfPlaced(_ word: [Character], at cell: CrosswordPuzzle.Cell, direction: CrosswordPuzzle.Direction) -> Int? {
            let step = direction.step
            let side = direction.other.step
            let endRow = cell.row + step.row * (word.count - 1)
            let endCol = cell.col + step.col * (word.count - 1)
            guard inBounds(cell.row, cell.col), inBounds(endRow, endCol) else { return nil }
            if isFilled(cell.row - step.row, cell.col - step.col) { return nil }
            if isFilled(endRow + step.row, endCol + step.col) { return nil }

            var crossed = 0
            for (offset, letter) in word.enumerated() {
                let row = cell.row + step.row * offset
                let col = cell.col + step.col * offset
                let idx = index(row, col)
                if let existing = letters[idx] {
                    guard existing == letter, !isUsed(idx, direction) else { return nil }
                    crossed += 1
                } else if isFilled(row - side.row, col - side.col) || isFilled(row + side.row, col + side.col) {
                    return nil
                }
            }
            // An answer made only of crossings adds no new letters and reads as a duplicate.
            return crossed < word.count ? crossed : nil
        }

        /// The best place to cross `word` into the board, favoring more crossings and
        /// placements that stretch the board, with a little randomness to vary layouts.
        func bestPlacement<R: RandomNumberGenerator>(for word: [Character], using rng: inout R) -> PlacementOption? {
            var best: (option: PlacementOption, score: Double)?
            let currentBounds = bounds
            for (offset, letter) in word.enumerated() {
                for idx in letterIndex[letter] ?? [] {
                    let row = idx / size
                    let col = idx % size
                    for direction in CrosswordPuzzle.Direction.allCases where !isUsed(idx, direction) {
                        let step = direction.step
                        let start = CrosswordPuzzle.Cell(row: row - step.row * offset, col: col - step.col * offset)
                        guard let crossed = crossingsIfPlaced(word, at: start, direction: direction), crossed > 0 else { continue }
                        var score = Double(crossed) * 3 + Double.random(in: 0..<2, using: &rng)
                        if let currentBounds, extendsBounds(currentBounds, word: word, start: start, direction: direction) {
                            score += 1
                        }
                        if best == nil || score > best!.score {
                            best = (PlacementOption(cell: start, direction: direction, crossings: crossed), score)
                        }
                    }
                }
            }
            return best?.option
        }

        private func extendsBounds(_ bounds: Bounds, word: [Character], start: CrosswordPuzzle.Cell, direction: CrosswordPuzzle.Direction) -> Bool {
            let step = direction.step
            let endRow = start.row + step.row * (word.count - 1)
            let endCol = start.col + step.col * (word.count - 1)
            return start.row < bounds.minRow || start.col < bounds.minCol
                || endRow > bounds.maxRow || endCol > bounds.maxCol
        }

        mutating func place(_ clue: CrosswordClueEntry, letters word: [Character], at cell: CrosswordPuzzle.Cell, direction: CrosswordPuzzle.Direction, crossings crossed: Int) {
            let step = direction.step
            for (offset, letter) in word.enumerated() {
                let idx = index(cell.row + step.row * offset, cell.col + step.col * offset)
                if letters[idx] == nil {
                    letters[idx] = letter
                    letterIndex[letter, default: []].append(idx)
                }
                if direction == .across { usedAcross[idx] = true } else { usedDown[idx] = true }
            }
            placements.append(Placement(clue: clue, letters: word, cell: cell, direction: direction))
            crossings += crossed
            usedNames.formUnion(clue.normalizedNames)
        }

        // MARK: Measuring

        struct Bounds {
            let minRow, maxRow, minCol, maxCol: Int
            var height: Int { maxRow - minRow + 1 }
            var width: Int { maxCol - minCol + 1 }
        }

        var bounds: Bounds? {
            var minRow = size, maxRow = -1, minCol = size, maxCol = -1
            for idx in letters.indices where letters[idx] != nil {
                let row = idx / size, col = idx % size
                minRow = min(minRow, row); maxRow = max(maxRow, row)
                minCol = min(minCol, col); maxCol = max(maxCol, col)
            }
            return maxRow < 0 ? nil : Bounds(minRow: minRow, maxRow: maxRow, minCol: minCol, maxCol: maxCol)
        }

        var filledCount: Int { letters.lazy.filter { $0 != nil }.count }

        /// Higher is better: more answers, more crossings, and a fuller board.
        var qualityScore: Double {
            let fill = Double(filledCount) / Double(size * size)
            return Double(placements.count) * 2 + Double(crossings) * 1.5 + fill * 20
        }

        // MARK: Finishing

        /// Shifts the answers so the empty margin is shared evenly around the board.
        mutating func center() {
            guard let bounds else { return }
            let rowShift = (size - bounds.height) / 2 - bounds.minRow
            let colShift = (size - bounds.width) / 2 - bounds.minCol
            guard rowShift != 0 || colShift != 0 else { return }

            let old = placements
            self = Layout(size: size)
            for placement in old {
                let cell = CrosswordPuzzle.Cell(row: placement.cell.row + rowShift, col: placement.cell.col + colShift)
                let crossed = crossingsIfPlaced(placement.letters, at: cell, direction: placement.direction) ?? 0
                place(placement.clue, letters: placement.letters, at: cell, direction: placement.direction, crossings: crossed)
            }
        }

        /// Numbers the starting cells row by row, the way printed crosswords do.
        func makePuzzle() -> CrosswordPuzzle {
            let starts = Set(placements.map { index($0.cell.row, $0.cell.col) }).sorted()
            var numbers: [Int: Int] = [:]
            for (offset, idx) in starts.enumerated() {
                numbers[idx] = offset + 1
            }

            let entries = placements
                .map { placement in
                    CrosswordPuzzle.Entry(
                        number: numbers[index(placement.cell.row, placement.cell.col)] ?? 0,
                        direction: placement.direction,
                        row: placement.cell.row,
                        col: placement.cell.col,
                        answer: String(placement.letters),
                        clue: placement.clue.clue,
                        reference: placement.clue.reference,
                        clueID: placement.clue.id
                    )
                }
                .sorted { lhs, rhs in
                    if lhs.direction != rhs.direction { return lhs.direction == .across }
                    return lhs.number < rhs.number
                }

            let rows = (0..<size).map { row in
                String((0..<size).map { col in letters[index(row, col)] ?? CrosswordPuzzle.blockMarker })
            }
            return CrosswordPuzzle(size: size, rows: rows, entries: entries)
        }
    }
}
