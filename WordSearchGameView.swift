import SwiftUI
import SwiftData
import Combine

struct WordSearchGameView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [Favorite]

    fileprivate struct PlacedWord: Identifiable, Hashable {
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

    // Timed mode
    @State private var isTimedMode: Bool = false
    @State private var remainingSeconds: Int = 0
    // Use a stored subscription to an autoconnected Timer publisher
    @State private var timerSubscription: AnyCancellable? = nil
    @State private var timeUp: Bool = false
    @State private var didWin: Bool = false
    @State private var pulseOn: Bool = false

    // Grid and words
    @State private var grid: [[Character]] = Array(repeating: Array(repeating: " ", count: 10), count: 10)
    @State private var targetWords: [String] = []
    @State private var placed: [PlacedWord] = []
    @State private var verseRef: String = ""
    @State private var verseText: String = ""

    // Parsed reference for favorites
    @State private var favBookName: String = ""
    @State private var favChapterNumber: Int = 0
    @State private var favVerseNumber: Int = 0

    // Selection/found state
    @State private var selectionStart: (row: Int, col: Int)? = nil
    @State private var selectionEnd: (row: Int, col: Int)? = nil
    @State private var foundCells: Set<String> = [] // "r,c"
    @State private var foundWords: Set<String> = []
    @State private var revealedWords: Set<String> = [] // words revealed but not found by the player

    // Tap-to-select state
    @State private var tapStart: (row: Int, col: Int)? = nil

    // Derived grid size based on difficulty
    private var size: Int {
        switch difficulty {
        case .easy: return 10
        case .medium, .hard: return 12
        }
    }
    private let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        ScrollViewReader { _ in
            ScrollView {
                VStack(spacing: 16) {
                    if !started {
                        StartScreen(
                            howToExpanded: $howToExpanded,
                            difficultyExpanded: $difficultyExpanded,
                            difficulty: $difficulty,
                            isTimedMode: $isTimedMode,
                            timeLimitString: timeLimitString(),
                            onStart: {
                                started = true
                                timeUp = false
                                didWin = false
                                generatePuzzle()
                                startTimerIfNeeded()
                            }
                        )
                    } else {
                        HeaderBox(
                            isTimedMode: isTimedMode,
                            timeUp: timeUp,
                            didWin: didWin,
                            remainingSeconds: remainingSeconds,
                            pulseOn: pulseOn,
                            verseRef: verseRef,
                            verseText: verseText,
                            isFavorited: isCurrentFavorited(),
                            onToggleFavorite: { toggleFavoriteCurrent() },
                            timerTint: timerTint(for:)
                        )

                        StatusBanner(timeUp: timeUp, didWin: didWin)

                        if isPad {
                            // Side-by-side layout on iPad
                            SideBySideGameArea(
                                size: size,
                                grid: grid,
                                selectionStart: selectionStart,
                                selectionEnd: selectionEnd,
                                foundCells: foundCells,
                                revealedWords: revealedWords,
                                placed: placed,
                                backgroundColorForCell: backgroundColorForCell(row:col:),
                                onTapCell: { r, c in handleCellTap(row: r, col: c) },
                                onDragChanged: { cell in
                                    guard !timeUp && !didWin else { return }
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
                                },
                                onDragEnded: {
                                    guard !timeUp && !didWin else { return }
                                    validateSelection()
                                    selectionStart = nil
                                    selectionEnd = nil
                                    tapStart = nil
                                },
                                dynamicGridHeight: dynamicGridHeightForHeightDrivenLayout(),
                                words: targetWords,
                                foundWords: foundWords
                            )
                        } else {
                            // Original stacked layout on iPhone
                            ZStack(alignment: .trailing) {
                                Color.clear

                                GridBoard(
                                    size: size,
                                    grid: grid,
                                    selectionStart: selectionStart,
                                    selectionEnd: selectionEnd,
                                    foundCells: foundCells,
                                    revealedWords: revealedWords,
                                    placed: placed,
                                    backgroundColorForCell: backgroundColorForCell(row:col:),
                                    onTapCell: { r, c in
                                        handleCellTap(row: r, col: c)
                                    },
                                    onDragChanged: { cell in
                                        guard !timeUp && !didWin else { return }
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
                                    },
                                    onDragEnded: {
                                        guard !timeUp && !didWin else { return }
                                        validateSelection()
                                        selectionStart = nil
                                        selectionEnd = nil
                                        tapStart = nil
                                    },
                                    dynamicGridHeight: dynamicGridHeightForHeightDrivenLayout()
                                )
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)

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
                        }

                        ControlsBar(
                            onNewPuzzle: {
                                generatePuzzle()
                                timeUp = false
                                didWin = false
                                startTimerIfNeeded()
                            },
                            onReveal: { revealOverlay() },
                            onChangeDifficulty: {
                                started = false
                                stopTimer()
                            }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Word Search")
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear { stopTimer() }
        }
    }

    // For height-driven layout, reduced iPad target cell so there’s space for the word list without scrolling
    private func dynamicGridHeightForHeightDrivenLayout() -> CGFloat {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let spacing: CGFloat = isPad ? 6 : 4
        let targetCell: CGFloat = isPad ? 54 : 34 // was larger; reduced for iPad to fit word list
        return CGFloat(size) * targetCell + CGFloat(size - 1) * spacing
    }

    // MARK: - Timed mode helpers

    private func timeLimitSeconds() -> Int {
        guard isTimedMode else { return 0 }
        switch difficulty {
        case .easy: return 60
        case .medium: return 90
        case .hard: return 120
        }
    }

    private func timeLimitString() -> String {
        let secs = timeLimitSeconds()
        return formattedTime(secs)
    }

    private func formattedTime(_ secs: Int) -> String {
        let m = secs / 60
        let s = secs % 60
        return String(format: "%d:%02d", m, s)
    }

    private func startTimerIfNeeded() {
        stopTimer()
        guard isTimedMode else { return }
        remainingSeconds = timeLimitSeconds()
        pulseOn = false
        timeUp = false
        didWin = false
        timerSubscription = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in tickTimer() }
    }

    private func stopTimer() {
        timerSubscription?.cancel()
        timerSubscription = nil
    }

    private func tickTimer() {
        guard isTimedMode, !timeUp, !didWin, remainingSeconds > 0 else { return }
        remainingSeconds -= 1
        if remainingSeconds == 0 {
            handleTimeUp()
        } else {
            let threshold = 10
            if remainingSeconds == threshold {
                startPulse()
            }
        }
    }

    private func startPulse() {
        let pulses = 4
        for i in 0..<(pulses * 2) {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.25) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    pulseOn.toggle()
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(pulses * 2) * 0.25 + 0.05) {
            pulseOn = false
        }
    }

    private func handleTimeUp() {
        timeUp = true
        stopTimer()
        revealOverlay()
        selectionStart = nil
        selectionEnd = nil
        tapStart = nil
        #if canImport(UIKit)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.warning)
        #endif
    }

    private func timerTint(for seconds: Int) -> Color {
        if seconds > 30 { return .green }
        else if seconds > 10 { return .yellow }
        else { return .red }
    }

    // MARK: - Tap-to-select

    private func handleCellTap(row: Int, col: Int) {
        guard !timeUp && !didWin else { return }
        if tapStart == nil {
            tapStart = (row, col)
            selectionStart = tapStart
            selectionEnd = tapStart
            return
        }
        if let start = tapStart {
            let constrained = constrainToAllowedLine(from: start, to: (row, col))
            selectionStart = start
            selectionEnd = constrained
            validateSelection()
            selectionStart = nil
            selectionEnd = nil
            tapStart = nil
        }
    }

    // MARK: - Generation

    private func generatePuzzle() {
        grid = Array(repeating: Array(repeating: " ", count: size), count: size)
        placed = []
        targetWords = []
        foundCells.removeAll()
        foundWords.removeAll()
        revealedWords.removeAll()
        selectionStart = nil
        selectionEnd = nil
        tapStart = nil

        guard let book = BibleData.books.randomElement(),
              let chapter = book.chapters.randomElement(),
              let verse = chapter.verses.randomElement()
        else { return }
        verseRef = "\(book.name) \(chapter.number):\(verse.number)"
        verseText = verse.text

        favBookName = book.name
        favChapterNumber = chapter.number
        favVerseNumber = verse.number

        let countRange: ClosedRange<Int> = {
            switch difficulty {
            case .easy: return 3...6
            case .medium: return 4...7
            case .hard: return 5...8
            }
        }()
        // Extract, then filter to words that fit in the current grid size
        let extracted = extractKeywords(from: verse.text, minLen: 3, maxCountRange: countRange)
        let fitting = extracted.filter { $0.count <= size }
        targetWords = Array(fitting.prefix(countRange.upperBound))

        // Place longer words first for better fit, using scattered placement
        for w in targetWords.sorted(by: { $0.count > $1.count }) {
            _ = placeWordScattered(w)
        }

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
        uniq.sort { $0.count > $1.count }
        let count = min(maxCountRange.upperBound, max(maxCountRange.lowerBound, uniq.count))
        return Array(uniq.prefix(count))
    }

    private var allowedDirections: [(dr: Int, dc: Int)] {
        switch difficulty {
        case .easy, .medium:
            return [(0, 1), (1, 0)]
        case .hard:
            return [
                (0, 1), (1, 0), (0, -1), (-1, 0),
                (1, 1), (1, -1), (-1, 1), (-1, -1)
            ]
        }
    }

    // MARK: - Scattered placement

    private struct PlacementCandidate {
        let row: Int
        let col: Int
        let dr: Int
        let dc: Int
        let overlap: Int
        let adjacency: Int
    }

    private func placeWordScattered(_ word: String) -> Bool {
        var candidates = enumerateCandidates(for: word)
        guard !candidates.isEmpty else { return false }

        // Shuffle for randomness across runs
        candidates.shuffle()

        // Light penalties; add jitter for variety
        func score(_ c: PlacementCandidate) -> Double {
            let overlapPenalty = 0.8
            let adjacencyPenalty = 0.5
            let jitter = Double.random(in: 0..<0.25)
            return Double(c.overlap) * overlapPenalty + Double(c.adjacency) * adjacencyPenalty + jitter
        }

        if let best = candidates.min(by: { score($0) < score($1) }) {
            write(word, atRow: best.row, col: best.col, dr: best.dr, dc: best.dc)
            placed.append(PlacedWord(word: word, startRow: best.row, startCol: best.col, dr: best.dr, dc: best.dc))
            return true
        }
        return false
    }

    private func enumerateCandidates(for word: String) -> [PlacementCandidate] {
        // Skip words that cannot possibly fit in the grid
        guard word.count <= size else { return [] }

        var list: [PlacementCandidate] = []
        for dir in allowedDirections {
            let dr = dir.dr, dc = dir.dc

            // Valid start ranges for bounds (protect against negative upper bounds)
            let maxRowStart: Int = (dr == 0) ? (size - 1) : (dr > 0 ? (size - word.count) : (size - 1))
            let minRowStart: Int = (dr == 0) ? 0 : (dr > 0 ? 0 : (word.count - 1))
            if minRowStart > maxRowStart { continue }
            let rowRange = minRowStart...maxRowStart

            let maxColStart: Int = (dc == 0) ? (size - 1) : (dc > 0 ? (size - word.count) : (size - 1))
            let minColStart: Int = (dc == 0) ? 0 : (dc > 0 ? 0 : (word.count - 1))
            if minColStart > maxColStart { continue }
            let colRange = minColStart...maxColStart

            for r in rowRange {
                for c in colRange {
                    let probe = canPlaceAt(word: word, row: r, col: c, dr: dr, dc: dc)
                    if probe.fits {
                        let adj = adjacencyCountFor(word: word, row: r, col: c, dr: dr, dc: dc)
                        list.append(PlacementCandidate(row: r, col: c, dr: dr, dc: dc, overlap: probe.overlap, adjacency: adj))
                    }
                }
            }
        }
        return list
    }

    // Returns (fits, overlapCount) for a candidate position
    private func canPlaceAt(word: String, row: Int, col: Int, dr: Int, dc: Int) -> (fits: Bool, overlap: Int) {
        var overlap = 0
        for i in 0..<word.count {
            let r = row + dr * i
            let c = col + dc * i
            guard r >= 0, r < size, c >= 0, c < size else { return (false, 0) }
            let ch = grid[r][c]
            if ch == " " { continue }
            let wi = word.index(word.startIndex, offsetBy: i)
            if ch == word[wi] {
                overlap += 1
            } else {
                return (false, 0)
            }
        }
               return (true, overlap)
    }

    // Count adjacent (8-neighborhood) cells around the path that already contain letters.
    private func adjacencyCountFor(word: String, row: Int, col: Int, dr: Int, dc: Int) -> Int {
        var count = 0
        let path: [(Int, Int)] = (0..<word.count).map { i in (row + dr * i, col + dc * i) }
        let neighbors = [(-1,-1), (-1,0), (-1,1), (0,-1), (0,1), (1,-1), (1,0), (1,1)]
        for (r, c) in path {
            for (nr, nc) in neighbors {
                let rr = r + nr
                let cc = c + nc
                guard rr >= 0, rr < size, cc >= 0, cc < size else { continue }
                // Don’t count the path cells themselves; only neighbors
                if path.contains(where: { $0.0 == rr && $0.1 == cc }) { continue }
                if grid[rr][cc] != " " { count += 1 }
            }
        }
        return count
    }

    // MARK: - Reveal

    private func revealOverlay() {
        var newRevealed = revealedWords
        for pw in placed {
            if !foundWords.contains(pw.word) {
                newRevealed.insert(pw.word)
            }
        }
        revealedWords = newRevealed
    }

    // MARK: - Favorites

    private func isCurrentFavorited() -> Bool {
        guard !favBookName.isEmpty, favChapterNumber > 0, favVerseNumber > 0 else { return false }
        return favorites.contains { fav in
            fav.bookName == favBookName &&
            fav.chapterNumber == favChapterNumber &&
            fav.verseNumber == favVerseNumber
        }
    }

    private func toggleFavoriteCurrent() {
        guard !favBookName.isEmpty, favChapterNumber > 0, favVerseNumber > 0 else { return }
        if let existing = favorites.first(where: { $0.bookName == favBookName && $0.chapterNumber == favChapterNumber && $0.verseNumber == favVerseNumber }) {
            modelContext.delete(existing)
            try? modelContext.save()
        } else {
            let fav = Favorite(
                bookName: favBookName,
                chapterNumber: favChapterNumber,
                verseNumber: favVerseNumber,
                verseText: verseText
            )
            modelContext.insert(fav)
            try? modelContext.save()
        }
    }

    // MARK: - Selection helpers

    private func keyFor(row: Int, col: Int) -> String { "\(row),\(col)" }

    private func backgroundColorForCell(row: Int, col: Int) -> Color {
        let cellKey = keyFor(row: row, col: col)

        if foundCells.contains(cellKey) {
            return Color.green.opacity(0.30)
        }

        if placed.contains(where: { pw in
            revealedWords.contains(pw.word) && cellsForPlacedWord(pw).contains(where: { $0.row == row && $0.col == col })
        }) {
            return Color.red.opacity(0.25)
        }

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

    private func cellAt(point: CGPoint, in containerSize: CGSize, gridSize: CGFloat, cellSize: CGFloat, spacing: CGFloat) -> (row: Int, col: Int)? {
        let originX = (containerSize.width - gridSize) / 2.0
        let originY: CGFloat = max(0, (containerSize.height - gridSize) / 2.0)

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

    private func constrainToAllowedLine(from start: (row: Int, col: Int), to end: (row: Int, col: Int)) -> (row: Int, col: Int) {
        let dRow = end.row - start.row
        let dCol = end.col - start.col

        func sign(_ x: Int) -> Int { x == 0 ? 0 : (x > 0 ? 1 : -1) }
        var dr = sign(dRow)
        var dc = sign(dCol)

        if dr != 0 && dc != 0 {
            if difficulty != .hard {
                if abs(dRow) >= abs(dCol) { dc = 0 } else { dr = 0 }
            }
        }

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

        let forward = String(cells.map { grid[$0.row][$0.col] })
        let backward = String(forward.reversed())

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
            for cell in cells {
                foundCells.insert(keyFor(row: cell.row, col: cell.col))
            }
            foundWords.insert(match.word)
            revealedWords.remove(match.word)

            // Win condition: all words found before time expires
            if isTimedMode && foundWords.count == targetWords.count {
                stopTimer()
                didWin = true
            }
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

    // Writes a word into the grid at a given position and direction.
    private func write(_ word: String, atRow row: Int, col: Int, dr: Int, dc: Int) {
        for (i, ch) in word.enumerated() {
            let r = row + dr * i
            let c = col + dc * i
            if r >= 0 && r < size && c >= 0 && c < size {
                grid[r][c] = ch
            }
        }
    }

    // Fills any remaining empty cells (" ") with random uppercase letters.
    private func fillRandom() {
        for r in 0..<size {
            for c in 0..<size {
                if grid[r][c] == " " {
                    grid[r][c] = alphabet.randomElement() ?? "A"
                }
            }
        }
    }
}

// MARK: - iPad side-by-side game area

private struct SideBySideGameArea: View {
    let size: Int
    let grid: [[Character]]
    let selectionStart: (row: Int, col: Int)?
    let selectionEnd: (row: Int, col: Int)?
    let foundCells: Set<String>
    let revealedWords: Set<String>
    let placed: [WordSearchGameView.PlacedWord]
    let backgroundColorForCell: (_ row: Int, _ col: Int) -> Color
    let onTapCell: (_ row: Int, _ col: Int) -> Void
    let onDragChanged: (_ cell: (row: Int, col: Int)) -> Void
    let onDragEnded: () -> Void
    let dynamicGridHeight: CGFloat

    let words: [String]
    let foundWords: Set<String>

    private var splitColumns: (left: [String], right: [String]) {
        // If many words, split evenly; else put all on the right
        if words.count > 8 {
            let mid = (words.count + 1) / 2
            return (Array(words.prefix(mid)), Array(words.suffix(from: mid)))
        } else {
            return ([], words)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            if !splitColumns.left.isEmpty {
                SideWordsColumn(words: splitColumns.left, found: foundWords, revealed: revealedWords)
                    .frame(width: 220)
            }

            ZStack(alignment: .trailing) {
                Color.clear

                GridBoard(
                    size: size,
                    grid: grid,
                    selectionStart: selectionStart,
                    selectionEnd: selectionEnd,
                    foundCells: foundCells,
                    revealedWords: revealedWords,
                    placed: placed,
                    backgroundColorForCell: backgroundColorForCell,
                    onTapCell: onTapCell,
                    onDragChanged: onDragChanged,
                    onDragEnded: onDragEnded,
                    dynamicGridHeight: dynamicGridHeight
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)

            if !splitColumns.right.isEmpty {
                SideWordsColumn(words: splitColumns.right, found: foundWords, revealed: revealedWords)
                    .frame(width: 220)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct SideWordsColumn: View {
    let words: [String]
    let found: Set<String>
    let revealed: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Find these words:")
                .font(.headline)
            if words.isEmpty {
                Text("No words").foregroundStyle(.secondary)
            } else {
                // Use a vertical flow that wraps nicely in a narrow column
                let columns = [GridItem(.adaptive(minimum: 120), spacing: 8)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Small extracted subviews to reduce type-checking load

private struct StartScreen: View {
    @Binding var howToExpanded: Bool
    @Binding var difficultyExpanded: Bool
    @Binding var difficulty: WordSearchGameView.Difficulty
    @Binding var isTimedMode: Bool
    let timeLimitString: String
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 16) {
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
                            Text("• Tip: You can also tap a start letter, then tap an end letter to select the line between them.")
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
                ForEach(WordSearchGameView.Difficulty.allCases) { d in
                    Text(d.rawValue.capitalized).tag(d)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Emphasized Timed Mode group: tighter label-toggle pairing
            HStack(spacing: 10) {
                Label {
                    Text("Timed Mode")
                        .font(.headline)
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "timer")
                        .foregroundStyle(.orange)
                }
                .labelStyle(.titleAndIcon)

                Spacer(minLength: 8)

                Toggle("", isOn: $isTimedMode)
                    .labelsHidden()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.orange.opacity(0.10))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.orange.opacity(0.25), lineWidth: 1)
            )
            .padding(.horizontal)

            if isTimedMode {
                Text("Time limit: \(timeLimitString)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            Button("Start") { onStart() }
                .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                .controlSize(.large)
                .frame(maxWidth: 240)

            Spacer(minLength: 24)
        }
    }
}

private struct HeaderBox: View {
    let isTimedMode: Bool
    let timeUp: Bool
    let didWin: Bool
    let remainingSeconds: Int
    let pulseOn: Bool
    let verseRef: String
    let verseText: String
    let isFavorited: Bool
    let onToggleFavorite: () -> Void
    let timerTint: (Int) -> Color

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Word Search")
                        .font(.headline)
                    Spacer()
                    // Show timer in timed mode unless time is up (keep visible after win)
                    if isTimedMode && !timeUp {
                        HStack(spacing: 6) {
                            Image(systemName: "timer")
                            Text(formattedTime(remainingSeconds))
                                .monospacedDigit()
                        }
                        .font(.headline)
                        .foregroundStyle(timerTint(remainingSeconds))
                        .scaleEffect(pulseOn ? 1.12 : 1.0)
                        .animation(.easeInOut(duration: 0.25), value: pulseOn)
                    }
                }
                if !verseRef.isEmpty {
                    HStack(spacing: 8) {
                        Text(verseRef)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Button(action: { onToggleFavorite() }) {
                            Image(systemName: isFavorited ? "heart.fill" : "heart")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isFavorited ? "Remove Favorite" : "Add to Favorites")
                    }
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
    }

    private func formattedTime(_ secs: Int) -> String {
        let m = secs / 60
        let s = secs % 60
        return String(format: "%d:%02d", m, s)
    }
}

private struct StatusBanner: View {
    let timeUp: Bool
    let didWin: Bool

    var body: some View {
        Group {
            if timeUp {
                Text("Time’s up!")
                    .font(.headline)
                    .foregroundStyle(.red)
                    .transition(.opacity)
            } else if didWin {
                Text("You Win!")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .transition(.opacity)
            }
        }
    }
}

private struct GridBoard: View {
    let size: Int
    let grid: [[Character]]
    let selectionStart: (row: Int, col: Int)?
    let selectionEnd: (row: Int, col: Int)?
    let foundCells: Set<String>
    let revealedWords: Set<String>
    let placed: [WordSearchGameView.PlacedWord]
    let backgroundColorForCell: (_ row: Int, _ col: Int) -> Color
    let onTapCell: (_ row: Int, _ col: Int) -> Void
    let onDragChanged: (_ cell: (row: Int, col: Int)) -> Void
    let onDragEnded: () -> Void
    let dynamicGridHeight: CGFloat

    var body: some View {
        GeometryReader { geo in
            let isPad = UIDevice.current.userInterfaceIdiom == .pad
            let spacing: CGFloat = isPad ? 6 : 4
            let minCell: CGFloat = isPad ? 36 : 26
            let maxCell: CGFloat = isPad ? 58 : 36
            let horizontalPaddingBudget: CGFloat = 32

            let availableHeight = max(0, geo.size.height)
            let cellSizeFromHeight = (availableHeight - CGFloat(size - 1) * spacing) / CGFloat(size)

            let availableWidth = max(0, geo.size.width - horizontalPaddingBudget)
            let cellSizeFromWidth = (availableWidth - CGFloat(size - 1) * spacing) / CGFloat(size)

            let rawCellSize = min(cellSizeFromHeight, cellSizeFromWidth)
            let cellSize = min(max(rawCellSize, minCell), maxCell)

            let totalSize = CGFloat(size) * cellSize + CGFloat(size - 1) * spacing
            let letterFontSize: CGFloat = isPad ? min(26, cellSize * 0.72) : min(20, cellSize * 0.72)

            VStack(spacing: spacing) {
                ForEach(0..<size, id: \.self) { r in
                    HStack(spacing: spacing) {
                        ForEach(0..<size, id: \.self) { c in
                            let ch = grid[r][c]
                            Text(String(ch))
                                .font(.system(size: letterFontSize, weight: .bold, design: .monospaced))
                                .frame(width: cellSize, height: cellSize)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(backgroundColorForCell(r, c))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onTapCell(r, c)
                                }
                        }
                    }
                }
            }
            .frame(width: totalSize, height: totalSize, alignment: .topLeading)
            .position(x: geo.size.width / 2, y: min(totalSize / 2, geo.size.height / 2))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let cell = hitCell(from: value.location, container: geo.size, gridSize: totalSize, cellSize: cellSize, spacing: spacing)
                        if let cell { onDragChanged(cell) }
                    }
                    .onEnded { _ in
                        onDragEnded()
                    }
            )
        }
        .frame(height: dynamicGridHeight)
    }

    private func hitCell(from point: CGPoint, container: CGSize, gridSize: CGFloat, cellSize: CGFloat, spacing: CGFloat) -> (row: Int, col: Int)? {
        let originX = (container.width - gridSize) / 2.0
        let originY: CGFloat = max(0, (container.height - gridSize) / 2.0)

        let localX = point.x - originX
        let localY = point.y - originY
        if localX < 0 || localY < 0 || localX > gridSize || localY > gridSize { return nil }

        let step = cellSize + spacing
        let col = Int(localX / step)
        let row = Int(localY / step)
        guard row >= 0, row < size, col >= 0, col < size else { return nil }

        let xInStep = localX - CGFloat(col) * step
        let yInStep = localY - CGFloat(row) * step
        guard xInStep <= cellSize, yInStep <= cellSize else { return nil }

        return (row, col)
    }
}

private struct ControlsBar: View {
    let onNewPuzzle: () -> Void
    let onReveal: () -> Void
    let onChangeDifficulty: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button("New Puzzle") { onNewPuzzle() }
                .buttonStyle(ModernPillButtonStyle(tint: .accentColor))

            Button("Reveal") { onReveal() }
                .buttonStyle(ModernPillButtonStyle(tint: .blue))

            Button("Change Difficulty") { onChangeDifficulty() }
                .buttonStyle(ModernPillButtonStyle(tint: .orange))
        }
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
