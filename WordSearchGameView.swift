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

    enum Difficulty: String, CaseIterable, Identifiable {
        case easy
        case medium   // will be displayed as "Normal" in UI
        case hard
        case expert
        var id: String { rawValue }
    }

    enum GameMode: String, CaseIterable, Identifiable {
        case normal
        case blind
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .normal: return "Normal"
            case .blind: return "Blind"
            }
        }
    }

    // Start screen state
    @State private var started: Bool = false
    @State private var howToExpanded: Bool = false
    @State private var difficultyExpanded: Bool = false
    @State private var difficulty: Difficulty = .easy
    @State private var gameMode: GameMode = .normal

    // Timed mode
    @State private var isTimedMode: Bool = false
    @State private var remainingSeconds: Int = 0
    // Use a stored subscription to an autoconnected Timer publisher
    @State private var timerSubscription: AnyCancellable? = nil
    @State private var timeUp: Bool = false
    @State private var didWin: Bool = false
    @State private var pulseOn: Bool = false
    @State private var roundOver: Bool = false  // NEW: unified end-of-round flag

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

    // Blind mode state (toggle)
    @State private var showBlindWordList: Bool = false

    // Tap-to-select state
    @State private var tapStart: (row: Int, col: Int)? = nil

    // Derived grid size based on difficulty
    private var size: Int {
        switch difficulty {
        case .easy: return 10
        case .medium: return 12 // shown as Normal
        case .hard: return 14
        case .expert: return 14
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
                            gameMode: $gameMode,
                            isTimedMode: $isTimedMode,
                            timeLimitString: timeLimitString(),
                            onStart: {
                                started = true
                                timeUp = false
                                didWin = false
                                roundOver = false
                                showBlindWordList = false
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
                                    guard !timeUp && !didWin && !roundOver else { return }
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
                                    guard !timeUp && !didWin && !roundOver else { return }
                                    validateSelection()
                                    selectionStart = nil
                                    selectionEnd = nil
                                    tapStart = nil
                                },
                                dynamicGridHeight: dynamicGridHeightForHeightDrivenLayout(),
                                words: targetWords,
                                foundWords: foundWords,
                                gameMode: gameMode,
                                showBlindWordList: showBlindWordList,
                                // New: timer info for right-side column
                                isTimedMode: isTimedMode,
                                timeUp: timeUp,
                                remainingSeconds: remainingSeconds,
                                pulseOn: pulseOn,
                                timerTint: timerTint(for:),
                                // New: controls moved to left column on iPad
                                onNewPuzzle: {
                                    generatePuzzle()
                                    timeUp = false
                                    didWin = false
                                    roundOver = false
                                    showBlindWordList = false
                                    startTimerIfNeeded()
                                },
                                onReveal: {
                                    revealOverlay()
                                    stopTimer()
                                    roundOver = true
                                },
                                onChangeDifficultyOrMode: {
                                    started = false
                                    stopTimer()
                                    roundOver = false
                                    showBlindWordList = false
                                },
                                onToggleHealed: { showBlindWordList.toggle() },
                                healedOn: showBlindWordList,
                                roundOver: roundOver
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
                                        guard !timeUp && !didWin && !roundOver else { return }
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
                                        guard !timeUp && !didWin && !roundOver else { return }
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
                                    if gameMode == .blind && !showBlindWordList {
                                        let foundCount = targetWords.filter { foundWords.contains($0) }.count
                                        HStack {
                                            Text("Words to find: \(targetWords.count)")
                                                .font(.headline)
                                            Spacer(minLength: 8)
                                            Text("Found: \(foundCount)")
                                                .font(.headline)
                                                .foregroundStyle(.secondary)
                                        }
                                    } else {
                                        Text("Find these words:")
                                            .font(.headline)
                                        if targetWords.isEmpty {
                                            Text("No words").foregroundStyle(.secondary)
                                        } else {
                                            WrapWordsView(words: targetWords, found: foundWords, revealed: revealedWords)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            ControlsBar(
                                onNewPuzzle: {
                                    generatePuzzle()
                                    timeUp = false
                                    didWin = false
                                    roundOver = false
                                    showBlindWordList = false
                                    startTimerIfNeeded()
                                },
                                onReveal: {
                                    // Reveal ends the round
                                    revealOverlay()
                                    stopTimer()
                                    roundOver = true
                                },
                                onChangeDifficultyOrMode: {
                                    started = false
                                    stopTimer()
                                    roundOver = false
                                    showBlindWordList = false
                                },
                                gameMode: gameMode,
                                onToggleHealed: {
                                    showBlindWordList.toggle()
                                },
                                healedOn: showBlindWordList,
                                roundOver: roundOver
                            )
                        }
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
        // Increased limits in Blind Mode
        if gameMode == .blind {
            switch difficulty {
            case .easy: return 120      // 2:00
            case .medium: return 150    // 2:30
            case .hard: return 240      // 4:00
            case .expert: return 270    // 4:30
            }
        } else {
            switch difficulty {
            case .easy: return 60
            case .medium: return 90
            case .hard: return 120
            case .expert: return 150
            }
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
        guard isTimedMode, !timeUp, !didWin, !roundOver, remainingSeconds > 0 else { return }
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
        roundOver = true
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
        guard !timeUp && !didWin && !roundOver else { return }
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
        func resetState() {
            grid = Array(repeating: Array(repeating: " ", count: size), count: size)
            placed = []
            targetWords = []
            foundCells.removeAll()
            foundWords.removeAll()
            revealedWords.removeAll()
            selectionStart = nil
            selectionEnd = nil
            tapStart = nil
            showBlindWordList = false
            timeUp = false
            didWin = false
            roundOver = false
        }

        resetState()

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
            case .hard, .expert: return 5...8
            }
        }()
        // Extract, then filter to words that fit in the current grid size
        let extracted = extractKeywords(from: verse.text, minLen: 3, maxCountRange: countRange)
        let fitting = extracted.filter { $0.count <= size }
        targetWords = Array(fitting.prefix(countRange.upperBound))

        // Multi-attempt placement to improve variety and success rate
        // Try up to N attempts, keep the best (max placed words, then direction variety)
        let maxAttempts = 5
        var bestPlaced: [PlacedWord] = []
        var bestGrid: [[Character]] = grid
        var bestScore: (count: Int, variety: Int) = (0, 0)

        for _ in 0..<maxAttempts {
            // Reset grid for this attempt
            grid = Array(repeating: Array(repeating: " ", count: size), count: size)
            placed = []

            // Place longer words first for better fit, using improved scattered placement
            let wordsToPlace = targetWords.sorted(by: { $0.count > $1.count })
            for w in wordsToPlace {
                _ = placeWordScattered(w)
            }

            // Score attempt
            let count = placed.count
            let variety = directionVarietyScore(placed)
            if (count > bestScore.count) || (count == bestScore.count && variety > bestScore.variety) {
                bestScore = (count, variety)
                bestPlaced = placed
                bestGrid = grid
            }

            // Early exit if we placed all words with good variety
            if count == targetWords.count && variety >= 4 { break }
        }

        // Use best attempt
        placed = bestPlaced
        grid = bestGrid

        fillRandom()
    }

    private func directionVarietyScore(_ words: [PlacedWord]) -> Int {
        // Count unique direction unit vectors
        var set = Set<String>()
        for pw in words {
            // Normalize direction to unit vector string
            let norm = "\(pw.dr),\(pw.dc)"
            set.insert(norm)
        }
        return set.count
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

    private var baseAllowedDirections: [(dr: Int, dc: Int)] {
        switch difficulty {
        case .easy, .medium:
            // Forward-only directions (no backwards): right, down, down-right, down-left
            return [
                (0, 1),  // right
                (1, 0),  // down
                (1, 1),  // down-right
                (1, -1)  // down-left
            ]
        case .hard, .expert:
            // All 8 directions
            return [
                (0, 1), (1, 0), (0, -1), (-1, 0),
                (1, 1), (1, -1), (-1, 1), (-1, -1)
            ]
        }
    }

    // For each word, build the direction set to try and shuffle it.
    private func directionsForPlacement() -> [(dr: Int, dc: Int)] {
        var dirs = baseAllowedDirections

        // For hard/expert we already include both forward and backward via the 8 directions.
        // For easy/medium we intentionally keep forward-only, but still shuffle to avoid bias.
        dirs.shuffle()
        return dirs
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
        // In expert mode, write the reversed form onto the board so all hidden words are reversed.
        let toPlace = (difficulty == .expert) ? String(word.reversed()) : word

        var candidates = enumerateCandidates(for: toPlace)
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
            write(toPlace, atRow: best.row, col: best.col, dr: best.dr, dc: best.dc)
            placed.append(PlacedWord(word: toPlace, startRow: best.row, startCol: best.col, dr: best.dr, dc: best.dc))
            return true
        }
        return false
    }

    private func enumerateCandidates(for word: String) -> [PlacementCandidate] {
        // Skip words that cannot possibly fit in the grid
        guard word.count <= size else { return [] }

        var list: [PlacementCandidate] = []

        // Per-word shuffled direction order
        let dirs = directionsForPlacement()

        for dir in dirs {
            let dr = dir.dr, dc = dir.dc

            // Valid start ranges for bounds (protect against negative upper bounds)
            let maxRowStart: Int = (dr == 0) ? (size - 1) : (dr > 0 ? (size - word.count) : (size - 1))
            let minRowStart: Int = (dr == 0) ? 0 : (dr > 0 ? 0 : (word.count - 1))
            if minRowStart > maxRowStart { continue }
            let rowRange = Array(minRowStart...maxRowStart)

            let maxColStart: Int = (dc == 0) ? (size - 1) : (dc > 0 ? (size - word.count) : (size - 1))
            let minColStart: Int = (dc == 0) ? 0 : (dc > 0 ? 0 : (word.count - 1))
            if minColStart > maxColStart { continue }
            let colRange = Array(minColStart...maxColStart)

            // Build all valid start positions for this direction and shuffle to avoid top-left bias.
            var starts: [(Int, Int)] = []
            starts.reserveCapacity(rowRange.count * colRange.count)
            for r in rowRange {
                for c in colRange {
                    starts.append((r, c))
                }
            }
            starts.shuffle()

            for (r, c) in starts {
                let probe = canPlaceAt(word: word, row: r, col: c, dr: dr, dc: dc)
                if probe.fits {
                    let adj = adjacencyCountFor(word: word, row: r, col: c, dr: dr, dc: dc)
                    list.append(PlacementCandidate(row: r, col: c, dr: dr, dc: dc, overlap: probe.overlap, adjacency: adj))
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
                // Normalize to original word in expert mode for UI list
                let original = (difficulty == .expert) ? String(pw.word.reversed()) : pw.word
                newRevealed.insert(original)
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

    // Stronger fills for found/revealed/selection
    private func backgroundColorForCell(row: Int, col: Int) -> Color {
        let cellKey = keyFor(row: row, col: col)

        if foundCells.contains(cellKey) {
            return Color.green.opacity(0.45)
        }

        if placed.contains(where: { pw in
            let original = (difficulty == .expert) ? String(pw.word.reversed()) : pw.word
            return revealedWords.contains(original) && cellsForPlacedWord(pw).contains(where: { $0.row == row && $0.col == col })
        }) {
            return Color.red.opacity(0.35)
        }

        if isCellInCurrentSelection(row: row, col: col) {
            return Color.blue.opacity(0.35)
        }

        return Color(.secondarySystemBackground)
    }

    // New: state-based stroke color to improve edge clarity
    private func strokeColorForCell(row: Int, col: Int) -> Color {
        let cellKey = keyFor(row: row, col: col)

        if foundCells.contains(cellKey) {
            return Color.green.opacity(0.9)
        }

        if placed.contains(where: { pw in
            let original = (difficulty == .expert) ? String(pw.word.reversed()) : pw.word
            return revealedWords.contains(original) && cellsForPlacedWord(pw).contains(where: { $0.row == row && $0.col == col })
        }) {
            return Color.red.opacity(0.9)
        }

        if isCellInCurrentSelection(row: row, col: col) {
            return Color.blue.opacity(0.9)
        }

        // Default subtle stroke
        return Color.black.opacity(0.1)
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

        // New rules: diagonals allowed at all difficulties. Keep direction snapped to primary axis if zero-length on one axis.
        if dr != 0 && dc != 0 {
            // diagonal allowed; keep as-is
        } else {
            // horizontal or vertical
        }

        // Ensure the chosen vector is one of the baseAllowedDirections (forward-only on easy/medium)
        let allowed = baseAllowedDirections
        if !allowed.contains(where: { $0.dr == dr && $0.dc == dc }) {
            // Snap to nearest allowed (fallback)
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

        // Diagonals allowed at all difficulties now; just use the signed vector.

        if !baseAllowedDirections.contains(where: { $0.dr == dr && $0.dc == dc }) {
            // Fallback snap to axis-aligned if needed
            if abs(dRow) >= abs(dCol) { dr = dr == 0 ? 0 : (dr > 0 ? 1 : -1); dc = 0 }
            else { dr = 0; dc = dc == 0 ? 0 : (dc > 0 ? 1 : -1) }
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
            let pwForward = String(pwCells.map { grid[$0.row][$0.col] })
            let pwBackward = String(pwForward.reversed())

            switch difficulty {
            case .easy:
                // Forward-only matches (must match placed path orientation)
                return (forward == pwForward && sequenceEquals(cells, pwCells))
            case .medium, .hard:
                // Normal and Hard: accept forward or backward in any direction
                return (forward == pwForward && sequenceEquals(cells, pwCells))
                    || (backward == pwForward && sequenceEquals(cells.reversed(), pwCells))
                    || (forward == pwBackward && sequenceEquals(cells, pwCells.reversed()))
                    || (backward == pwBackward && sequenceEquals(cells.reversed(), pwCells.reversed()))
            case .expert:
                // Reversed-only relative to placed path
                return (forward == pwBackward && sequenceEquals(cells, pwCells.reversed()))
                    || (backward == pwBackward && sequenceEquals(cells.reversed(), pwCells.reversed()))
            }
        }) {
            // Normalize found word to the original (forward) text so UI highlighting and counts align with targetWords
            let originalWordFound: String = (difficulty == .expert) ? String(match.word.reversed()) : String(match.word)

            for cell in cells {
                foundCells.insert(keyFor(row: cell.row, col: cell.col))
            }
            foundWords.insert(originalWordFound)
            revealedWords.remove(originalWordFound)

            // Win condition: all words found before time expires
            if foundWords.count == targetWords.count {
                stopTimer()
                didWin = true
                roundOver = true
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

    // New: mode awareness for blind mode
    let gameMode: WordSearchGameView.GameMode
    let showBlindWordList: Bool

    // New: timer info for right column
    let isTimedMode: Bool
    let timeUp: Bool
    let remainingSeconds: Int
    let pulseOn: Bool
    let timerTint: (Int) -> Color

    // New: controls moved here on iPad
    let onNewPuzzle: () -> Void
    let onReveal: () -> Void
    let onChangeDifficultyOrMode: () -> Void
    let onToggleHealed: () -> Void
    let healedOn: Bool
    let roundOver: Bool

    private var splitColumns: (left: [String], right: [String]) {
        // If many words, split evenly; else put all on the right
        if words.count > 8 {
            let mid = (words.count + 1) / 2
            return (Array(words.prefix(mid)), Array(words.suffix(from: mid)))
        } else {
            return ([], words)
        }
    }

    private func formattedTime(_ secs: Int) -> String {
        let m = secs / 60
        let s = secs % 60
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Left utility column: timer + controls + optional left word list
            VStack(alignment: .leading, spacing: 10) {
                if isTimedMode && !timeUp {
                    HStack(spacing: 8) {
                        Image(systemName: "timer")
                        Text(formattedTime(remainingSeconds))
                            .monospacedDigit()
                    }
                    .font(.title2.weight(.semibold)) // bigger than header
                    .foregroundStyle(timerTint(remainingSeconds))
                    .scaleEffect(pulseOn ? 1.08 : 1.0)
                    .animation(.easeInOut(duration: 0.25), value: pulseOn)
                }

                // Controls (moved from bottom bar to here on iPad)
                HStack(spacing: 10) {
                    if !roundOver {
                        Button("Reveal") { onReveal() }
                            .buttonStyle(ModernPillButtonStyle(tint: .blue))

                        if gameMode == .blind {
                            Button(healedOn ? "I'm Healed" : "Be Healed") { onToggleHealed() }
                                .buttonStyle(ModernPillButtonStyle(tint: healedOn ? .green : .red))
                        }
                    } else {
                        Button("New Puzzle") { onNewPuzzle() }
                            .buttonStyle(ModernPillButtonStyle(tint: .accentColor))

                        Button("Change Settings") { onChangeDifficultyOrMode() }
                            .buttonStyle(ModernPillButtonStyle(tint: .orange))
                    }
                }
                .padding(.bottom, 4)

                // If we have a lot of words and split across columns, optionally show left words list here.
                if !splitColumns.left.isEmpty {
                    if gameMode == .blind && !showBlindWordList {
                        let foundCount = words.filter { foundWords.contains($0) }.count
                        SideBlindCountColumn(count: splitColumns.left.count, foundCount: foundCount)
                            .frame(width: 220)
                    } else {
                        SideWordsColumn(words: splitColumns.left, found: foundWords, revealed: revealedWords)
                            .frame(width: 220)
                    }
                }
            }
            .frame(width: (!splitColumns.left.isEmpty ? 220 : 220))

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
                VStack(alignment: .leading, spacing: 8) {
                    if gameMode == .blind && !showBlindWordList {
                        let foundCount = words.filter { foundWords.contains($0) }.count
                        SideBlindCountColumn(count: splitColumns.right.count, foundCount: foundCount)
                            .frame(width: 220)
                    } else {
                        SideWordsColumn(words: splitColumns.right, found: foundWords, revealed: revealedWords)
                            .frame(width: 220)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct SideBlindCountColumn: View {
    let count: Int
    let foundCount: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Words to find: \(count)")
                    .font(.headline)
                Spacer(minLength: 8)
                Text("Found: \(foundCount)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            Text("Tap Healed to show the list.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    @Binding var gameMode: WordSearchGameView.GameMode
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
                            Text("• Easy/Normal: words can be horizontal, vertical, or diagonal (forward only).")
                            Text("• Hard: words can be in any direction, forward or backwards.")
                            Text("• Expert: all words are reversed and can go in any direction.")
                            Text("• Blind Mode: the word list is hidden. Tap Healed to reveal the list, then find them.")
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
                            Text("• Easy: 10×10 grid; words go horizontal, vertical, or diagonal (forward only).")
                            Text("• Normal: 12×12 grid; words go horizontal, vertical, or diagonal (forward only).")
                            Text("• Hard: 14×14 grid; words can be in any direction, including backwards.")
                            Text("• Expert: 14×14 grid; all words are reversed and can go in any direction.")
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
                    Text(displayName(for: d)).tag(d)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Picker("Mode", selection: $gameMode) {
                ForEach(WordSearchGameView.GameMode.allCases) { m in
                    Text(m.displayName).tag(m)
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

    private func displayName(for d: WordSearchGameView.Difficulty) -> String {
        switch d {
        case .easy: return "Easy"
        case .medium: return "Normal"
        case .hard: return "Hard"
        case .expert: return "Expert"
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

    // Local state-based stroke color (mirrors parent’s logic using inputs available here)
    private func strokeColorForCell(_ row: Int, _ col: Int) -> Color {
        let key = "\(row),\(col)"

        if foundCells.contains(key) {
            return Color.green.opacity(0.9)
        }

        if placed.contains(where: { pw in
            let original = (WordSearchGameView.Difficulty.expert == .expert) ? String(pw.word.reversed()) : pw.word
            return revealedWords.contains(original) && {
                var cells: [(Int, Int)] = []
                for i in 0..<pw.word.count {
                    cells.append((pw.startRow + pw.dr * i, pw.startCol + pw.dc * i))
                }
                return cells.contains(where: { $0.0 == row && $0.1 == col })
            }()
        }) {
            return Color.red.opacity(0.9)
        }

        if let start = selectionStart, let end = selectionEnd {
            func sign(_ x: Int) -> Int { x == 0 ? 0 : (x > 0 ? 1 : -1) }
            let dRow = end.row - start.row
            let dCol = end.col - start.col
            var dr = sign(dRow)
            var dc = sign(dCol)
            if dRow == 0 && dCol == 0 {
                if start.row == row && start.col == col { return Color.blue.opacity(0.9) }
            } else {
                var r = start.row
                var c = start.col
                while true {
                    if r == row && c == col { return Color.blue.opacity(0.9) }
                    if r == end.row && c == end.col { break }
                    r += dr
                    c += dc
                    if r < 0 || r >= size || c < 0 || c >= size { break }
                }
            }
        }

        return Color.black.opacity(0.1)
    }

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
                                        .stroke(strokeColorForCell(r, c), lineWidth: 1.5)
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
    let onChangeDifficultyOrMode: () -> Void

    // Blind mode controls
    let gameMode: WordSearchGameView.GameMode
    let onToggleHealed: () -> Void
    let healedOn: Bool
    let roundOver: Bool

    var body: some View {
        HStack(spacing: 12) {
            // During play: show Reveal and (if blind) Healed toggle
            if !roundOver {
                Button("Reveal") { onReveal() }
                    .buttonStyle(ModernPillButtonStyle(tint: .blue))

                if gameMode == .blind {
                    // Red "Be Healed" when list hidden; Green "I'm Healed" when list showing
                    Button(healedOn ? "I'm Healed" : "Be Healed") { onToggleHealed() }
                        .buttonStyle(ModernPillButtonStyle(tint: healedOn ? .green : .red))
                }
            } else {
                // After round ends: show New Puzzle and Change Settings
                Button("New Puzzle") { onNewPuzzle() }
                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))

                Button("Change Settings") { onChangeDifficultyOrMode() }
                    .buttonStyle(ModernPillButtonStyle(tint: .orange))
            }
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
