import SwiftUI

struct WordSearchGameView: View {
    private struct PlacedWord: Identifiable, Hashable {
        let id = UUID()
        let word: String
        let startRow: Int
        let startCol: Int
        let dr: Int
        let dc: Int
        var endRow: Int { startRow + dr * (word.count - 1) }
        var endCol: Int { startCol + dc * (word.count - 1) }
    }

    enum Difficulty: String, CaseIterable, Identifiable { case easy, medium, hard; var id: String { rawValue } }

    // Start screen state
    @State private var started: Bool = false
    @State private var howToExpanded: Bool = false
    @State private var difficultyExpanded: Bool = false
    @State private var difficulty: Difficulty = .easy

    // Grid and words
    @State private var grid: [[Character]] = Array(repeating: Array(repeating: " ", count: 10), count: 10)
    @State private var targetWords: [String] = []
    @State private var placed: [PlacedWord] = []
    @State private var verseRef: String = ""
    @State private var verseText: String = ""

    // Selection/found state
    @State private var selectionStart: (row: Int, col: Int)? = nil
    @State private var selectionEnd: (row: Int, col: Int)? = nil
    @State private var foundCells: Set<String> = [] // "r,c"
    @State private var foundWords: Set<String> = []
    @State private var revealedWords: Set<String> = [] // words revealed but not found by the player

    // Derived grid size based on difficulty
    private var size: Int {
        switch difficulty {
        case .easy: return 10
        case .medium, .hard: return 12
        }
    }
    private let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !started {
                    Spacer(minLength: 24)
                    Text("Find hidden words from a random Bible verse.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 10) {
                        GroupBox {
                            DisclosureGroup(isExpanded: $howToExpanded) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("• Tap Start to generate a new puzzle.")
                                    Text("• Drag across letters to select a word.")
                                    Text("• Words are hidden horizontally or vertically on Easy/Medium; on Hard they can also be diagonal or reversed.")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } label: {
                                Text("How to Play").font(.headline)
                            }
                        }

                        GroupBox {
                            DisclosureGroup(isExpanded: $difficultyExpanded) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("• Easy: 10×10 grid; words go right or down.")
                                    Text("• Medium: 12×12 grid; words go right or down.")
                                    Text("• Hard: 12×12 grid; words can also be reversed and diagonal (all directions).")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } label: {
                                Text("Difficulty Levels").font(.headline)
                            }
                        }
                    }
                    .padding(.horizontal)

                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(Difficulty.allCases) { d in
                            Text(d.rawValue.capitalized).tag(d)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    Button("Start") {
                        started = true
                        generatePuzzle()
                    }
                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                    .controlSize(.large)
                    .frame(maxWidth: 240)

                    Spacer(minLength: 24)
                } else {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Word Search")
                                .font(.headline)
                            if !verseRef.isEmpty {
                                Text(verseRef)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            if !verseText.isEmpty {
                                Text("“\(verseText)”")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Grid with drag selection
                    GeometryReader { geo in
                        let cellSize: CGFloat = 28
                        let spacing: CGFloat = 4
                        let totalSize = CGFloat(size) * cellSize + CGFloat(size - 1) * spacing

                        VStack(spacing: spacing) {
                            ForEach(0..<size, id: \.self) { r in
                                HStack(spacing: spacing) {
                                    ForEach(0..<size, id: \.self) { c in
                                        let ch = grid[r][c]
                                        Text(String(ch))
                                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                                            .frame(width: cellSize, height: cellSize)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                    .fill(backgroundColorForCell(row: r, col: c))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }
                        .frame(width: totalSize, height: totalSize, alignment: .topLeading)
                        .position(x: geo.size.width / 2, y: totalSize / 2) // center horizontally
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let point = value.location
                                    if let cell = cellAt(point: point, in: geo.size, gridSize: totalSize, cellSize: cellSize, spacing: spacing) {
                                        if selectionStart == nil {
                                            selectionStart = cell
                                            selectionEnd = cell
                                        } else {
                                            if let start = selectionStart {
                                                let constrained = constrainToAllowedLine(from: start, to: cell)
                                                selectionEnd = constrained
                                            } else {
                                                selectionEnd = cell
                                            }
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    validateSelection()
                                    selectionStart = nil
                                    selectionEnd = nil
                                }
                        )
                    }
                    .frame(height: CGFloat(size) * 28 + CGFloat(size - 1) * 4)
                    .padding(.top, 4)

                    // Word list
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Find these words:")
                                .font(.headline)
                            if targetWords.isEmpty {
                                Text("No words").foregroundStyle(.secondary)
                            } else {
                                WrapWordsView(words: targetWords, found: foundWords, revealed: revealedWords)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack(spacing: 12) {
                        Button("New Puzzle") {
                            generatePuzzle()
                        }
                        .buttonStyle(ModernPillButtonStyle(tint: .accentColor))

                        Button("Reveal") {
                            revealOverlay()
                        }
                        .buttonStyle(ModernPillButtonStyle(tint: .blue))

                        Button("Change Difficulty") {
                            started = false
                            // Clear current state; the next Start will regenerate for chosen difficulty
                        }
                        .buttonStyle(ModernPillButtonStyle(tint: .orange))
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Word Search")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Do not auto-generate; wait for Start like other games
        }
    }

    // MARK: - Generation

    private func generatePuzzle() {
        // Reset state
        grid = Array(repeating: Array(repeating: " ", count: size), count: size)
        placed = []
        targetWords = []
        foundCells.removeAll()
        foundWords.removeAll()
        revealedWords.removeAll()
        selectionStart = nil
        selectionEnd = nil

        // Pick a random verse
        guard let book = BibleData.books.randomElement(),
              let chapter = book.chapters.randomElement(),
              let verse = chapter.verses.randomElement()
        else { return }
        verseRef = "\(book.name) \(chapter.number):\(verse.number)"
        verseText = verse.text

        // Extract keywords
        let countRange: ClosedRange<Int> = {
            switch difficulty {
            case .easy: return 3...6
            case .medium: return 4...7
            case .hard: return 5...8
            }
        }()
        let words = extractKeywords(from: verse.text, minLen: 3, maxCountRange: countRange)
        targetWords = words

        // Place words using allowed directions per difficulty
        for w in words {
            _ = placeWord(w)
        }

        // Fill remaining with random letters
        fillRandom()
    }

    private func extractKeywords(from text: String, minLen: Int, maxCountRange: ClosedRange<Int>) -> [String] {
        let letters = text
            .uppercased()
            .map { $0.isLetter ? $0 : " " }
        let tokenized = String(letters).split(separator: " ").map(String.init)
        var uniq: [String] = []
        var seen = Set<String>()
        for t in tokenized {
            guard t.count >= minLen else { continue }
            if !seen.contains(t) {
                seen.insert(t)
                uniq.append(t)
            }
        }
        // Favor longer words
        uniq.sort { $0.count > $1.count }
        let count = min(maxCountRange.upperBound, max(maxCountRange.lowerBound, uniq.count))
        return Array(uniq.prefix(count))
    }

    private var allowedDirections: [(dr: Int, dc: Int)] {
        switch difficulty {
        case .easy, .medium:
            return [(0, 1), (1, 0)] // right, down
        case .hard:
            return [
                (0, 1), (1, 0), (0, -1), (-1, 0), // right, down, left, up
                (1, 1), (1, -1), (-1, 1), (-1, -1) // diagonals
            ]
        }
    }

    private func placeWord(_ word: String) -> Bool {
        let tries = 600
        for _ in 0..<tries {
            let dir = allowedDirections.randomElement()!
            // Compute valid start bounds so the word fits
            let dr = dir.dr, dc = dir.dc
            let maxRowStart = dr >= 0 ? (size - word.count) : (size - 1)
            let maxColStart = dc >= 0 ? (size - word.count) : (size - 1)
            let minRowStart = dr >= 0 ? 0 : (word.count - 1)
            let minColStart = dc >= 0 ? 0 : (word.count - 1)

            let row = Int.random(in: minRowStart...maxRowStart)
            let col = Int.random(in: minColStart...maxColStart)

            if canPlace(word, atRow: row, col: col, dr: dr, dc: dc) {
                write(word, atRow: row, col: col, dr: dr, dc: dc)
                placed.append(PlacedWord(word: word, startRow: row, startCol: col, dr: dr, dc: dc))
                return true
            }
        }
        return false
    }

    private func canPlace(_ word: String, atRow row: Int, col: Int, dr: Int, dc: Int) -> Bool {
        for i in 0..<word.count {
            let r = row + dr * i
            let c = col + dc * i
            guard r >= 0, r < size, c >= 0, c < size else { return false }
            let ch = grid[r][c]
            if ch == " " { continue }
            let wi = word.index(word.startIndex, offsetBy: i)
            if ch != word[wi] { return false }
        }
        return true
    }

    private func write(_ word: String, atRow row: Int, col: Int, dr: Int, dc: Int) {
        for i in 0..<word.count {
            let r = row + dr * i
            let c = col + dc * i
            let wi = word.index(word.startIndex, offsetBy: i)
            grid[r][c] = word[wi]
        }
    }

    private func fillRandom() {
        for r in 0..<size {
            for c in 0..<size {
                if grid[r][c] == " " {
                    grid[r][c] = alphabet.randomElement()!
                }
            }
        }
    }

    // MARK: - Reveal

    private func revealOverlay() {
        // Mark only the words that are not already found as revealed.
        var newRevealed = revealedWords
        for pw in placed {
            if !foundWords.contains(pw.word) {
                newRevealed.insert(pw.word)
            }
        }
        revealedWords = newRevealed

        // Color the cells for the revealed (unfound) words in red by tracking via foundCells?:
        // We keep foundCells for found words as green; for revealed (unfound) words we do NOT add to foundCells,
        // instead we color via backgroundColorForCell using revealedWords membership.
        // So nothing else to do here for cells; the board coloring reads revealedWords.
    }

    // MARK: - Selection helpers

    private func keyFor(row: Int, col: Int) -> String { "\(row),\(col)" }

    private func backgroundColorForCell(row: Int, col: Int) -> Color {
        // If this cell belongs to any placed word that is revealed (and not found), color red
        let cellKey = keyFor(row: row, col: col)

        // Found cells: green
        if foundCells.contains(cellKey) {
            return Color.green.opacity(0.30)
        }

        // Revealed but not found: check if any placed word that includes this cell is in revealedWords
        if placed.contains(where: { pw in
            revealedWords.contains(pw.word) && cellsForPlacedWord(pw).contains(where: { $0.row == row && $0.col == col })
        }) {
            return Color.red.opacity(0.25)
        }

        // Current selection: blue
        if isCellInCurrentSelection(row: row, col: col) {
            return Color.blue.opacity(0.25)
        }

        return Color(.secondarySystemBackground)
    }

    private func isCellInCurrentSelection(row: Int, col: Int) -> Bool {
        guard let start = selectionStart, let end = selectionEnd else { return false }
        let path = selectionCells(from: start, to: end)
        return path.contains { $0.row == row && $0.col == col }
    }

    // Account for centered grid and exact hit testing
    private func cellAt(point: CGPoint, in containerSize: CGSize, gridSize: CGFloat, cellSize: CGFloat, spacing: CGFloat) -> (row: Int, col: Int)? {
        let originX = (containerSize.width - gridSize) / 2.0
        let originY: CGFloat = 0

        let localX = point.x - originX
        let localY = point.y - originY
        if localX < 0 || localY < 0 || localX > gridSize || localY > gridSize { return nil }

        let step = cellSize + spacing
        let col = Int(localX / step)
        let row = Int(localY / step)
        guard row >= 0, row < self.size, col >= 0, col < self.size else { return nil }

        let xInStep = localX - CGFloat(col) * step
        let yInStep = localY - CGFloat(row) * step
        guard xInStep <= cellSize, yInStep <= cellSize else { return nil }

        return (row, col)
    }

    // Constrain drag to allowed directions for the chosen difficulty
    private func constrainToAllowedLine(from start: (row: Int, col: Int), to end: (row: Int, col: Int)) -> (row: Int, col: Int) {
        let dRow = end.row - start.row
        let dCol = end.col - start.col

        // Normalize to -1, 0, or 1 for each axis
        func sign(_ x: Int) -> Int { x == 0 ? 0 : (x > 0 ? 1 : -1) }
        var dr = sign(dRow)
        var dc = sign(dCol)

        // Reduce to axis-aligned or diagonal unit vector
        if dr != 0 && dc != 0 {
            // Diagonal attempt; only allow on hard
            if difficulty != .hard {
                if abs(dRow) >= abs(dCol) { dc = 0 } else { dr = 0 }
            }
        } else {
            // Axis aligned: ok for all
        }

        // If resulting (dr, dc) not allowed for this difficulty, force to allowed
        let allowed = allowedDirections
        if !allowed.contains(where: { $0.dr == dr && $0.dc == dc }) {
            if abs(dRow) >= abs(dCol) {
                dr = dr == 0 ? 0 : (dr > 0 ? 1 : -1)
                dc = 0
            } else {
                dr = 0
                dc = dc == 0 ? 0 : (dc > 0 ? 1 : -1)
            }
        }

        // Clamp end to grid bounds along this direction
        let clampedRow = (start.row + dr * abs(dRow)).clamped(to: 0...(size - 1))
        let clampedCol = (start.col + dc * abs(dCol)).clamped(to: 0...(size - 1))
        return (row: clampedRow, col: clampedCol)
    }

    private func selectionCells(from start: (row: Int, col: Int), to end: (row: Int, col: Int)) -> [(row: Int, col: Int)] {
        let dRow = end.row - start.row
        let dCol = end.col - start.col
        if dRow == 0 && dCol == 0 { return [start] }

        func sign(_ x: Int) -> Int { x == 0 ? 0 : (x > 0 ? 1 : -1) }
        var dr = sign(dRow)
        var dc = sign(dCol)

        if difficulty != .hard {
            if abs(dRow) >= abs(dCol) { dc = 0 } else { dr = 0 }
        }

        if !allowedDirections.contains(where: { $0.dr == dr && $0.dc == dc }) {
            if difficulty == .easy || difficulty == .medium {
                if abs(dRow) >= abs(dCol) { dr = 1; dc = 0 } else { dr = 0; dc = 1 }
            }
        }

        var cells: [(Int, Int)] = []
        var r = start.row
        var c = start.col
        cells.append((r, c))
        while r != end.row || c != end.col {
            r += dr
            c += dc
            if r < 0 || r >= size || c < 0 || c >= size { break }
            cells.append((r, c))
        }
        return cells
    }

    private func validateSelection() {
        guard let start = selectionStart, let end = selectionEnd else { return }
        let cells = selectionCells(from: start, to: end)
        guard !cells.isEmpty else { return }

        // Build candidate string
        let forward = String(cells.map { grid[$0.row][$0.col] })
        let backward = String(forward.reversed())

        // Try to match any placed word
        if let match = placed.first(where: { pw in
            let pwCells = cellsForPlacedWord(pw)
            if difficulty == .hard {
                let pwForward = String(pwCells.map { grid[$0.row][$0.col] })
                let pwBackward = String(pwForward.reversed())
                return (forward == pwForward && sequenceEquals(cells, pwCells))
                    || (backward == pwForward && sequenceEquals(cells.reversed(), pwCells))
                    || (forward == pwBackward && sequenceEquals(cells, pwCells.reversed()))
                    || (backward == pwBackward && sequenceEquals(cells.reversed(), pwCells.reversed()))
            } else {
                let pwForward = String(pwCells.map { grid[$0.row][$0.col] })
                return (forward == pwForward && sequenceEquals(cells, pwCells))
            }
        }) {
            // Mark found cells (green) and found word
            for cell in cells {
                foundCells.insert(keyFor(row: cell.row, col: cell.col))
            }
            foundWords.insert(match.word)
            // If this was previously revealed (red), remove it from revealedWords so it becomes green everywhere
            revealedWords.remove(match.word)
        }
    }

    private func sequenceEquals<T: Equatable>(_ a: some Sequence<T>, _ b: some Sequence<T>) -> Bool {
        var ia = a.makeIterator()
        var ib = b.makeIterator()
        while true {
            let va = ia.next()
            let vb = ib.next()
            if va == nil || vb == nil { return va == nil && vb == nil }
            if va! != vb! { return false }
        }
    }

    // Overload specialized for sequences of (row: Int, col: Int) so we can compare label-based tuples safely
    private func sequenceEquals(_ a: some Sequence<(row: Int, col: Int)>, _ b: some Sequence<(row: Int, col: Int)>) -> Bool {
        var ia = a.makeIterator()
        var ib = b.makeIterator()
        while true {
            let va = ia.next()
            let vb = ib.next()
            if va == nil || vb == nil { return va == nil && vb == nil }
            if va!.row != vb!.row || va!.col != vb!.col { return false }
        }
    }

    private func cellsForPlacedWord(_ pw: PlacedWord) -> [(row: Int, col: Int)] {
        var cells: [(Int, Int)] = []
        for i in 0..<pw.word.count {
            cells.append((pw.startRow + pw.dr * i, pw.startCol + pw.dc * i))
        }
        return cells
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

private struct WrapWordsView: View {
    let words: [String]
    let found: Set<String>
    let revealed: Set<String>
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        // Simple wrapping using flexible grid
        let columns = [GridItem(.adaptive(minimum: 80), spacing: 8)]
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(words, id: \.self) { w in
                let isFound = found.contains(w)
                let isRevealed = !isFound && revealed.contains(w)
                Text(w)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(
                                isFound
                                ? Color.green.opacity(0.20)
                                : (isRevealed ? Color.red.opacity(0.20) : Color.accentColor.opacity(0.12))
                            )
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(
                                isFound
                                ? Color.green.opacity(0.60)
                                : (isRevealed ? Color.red.opacity(0.60) : Color.accentColor.opacity(0.35)),
                                lineWidth: 1
                            )
                    )
                    .foregroundStyle(.primary)
            }
        }
    }
}
