import SwiftUI
import SwiftData
import Combine

struct WordSearchGameView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [Favorite]

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
                        ForEach(Difficulty.allCases) { d in
                            Text(d.rawValue.capitalized).tag(d)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    Toggle(isOn: $isTimedMode) {
                        Label("Timed Mode", systemImage: "timer")
                    }
                    .padding(.horizontal)

                    if isTimedMode {
                        Text("Time limit: \(timeLimitString())")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }

                    Button("Start") {
                        started = true
                        timeUp = false
                        didWin = false
                        generatePuzzle()
                        startTimerIfNeeded()
                    }
                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                    .controlSize(.large)
                    .frame(maxWidth: 240)

                    Spacer(minLength: 24)
                } else {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Word Search")
                                    .font(.headline)
                                Spacer()
                                if isTimedMode && !timeUp && !didWin {
                                    HStack(spacing: 6) {
                                        Image(systemName: "timer")
                                        Text(formattedTime(remainingSeconds))
                                            .monospacedDigit()
                                    }
                                    .font(.headline)
                                    .foregroundStyle(timerTint(for: remainingSeconds))
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
                                    Button(action: { toggleFavoriteCurrent() }) {
                                        Image(systemName: isCurrentFavorited() ? "heart.fill" : "heart")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(isCurrentFavorited() ? "Remove Favorite" : "Add to Favorites")
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

                    // Grid with drag selection and tap-to-select
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
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                guard !timeUp && !didWin else { return }
                                                handleCellTap(row: r, col: c)
                                            }
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
                                    guard !timeUp && !didWin else { return }
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
                                    guard !timeUp && !didWin else { return }
                                    validateSelection()
                                    selectionStart = nil
                                    selectionEnd = nil
                                    tapStart = nil
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
                            timeUp = false
                            didWin = false
                            startTimerIfNeeded()
                        }
                        .buttonStyle(ModernPillButtonStyle(tint: .accentColor))

                        Button("Reveal") {
                            revealOverlay()
                        }
                        .buttonStyle(ModernPillButtonStyle(tint: .blue))

                        Button("Change Difficulty") {
                            started = false
                            stopTimer()
                        }
                        .buttonStyle(ModernPillButtonStyle(tint: .orange))
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Word Search")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { stopTimer() }
    }

    // MARK: - Timed mode helpers

    private func timeLimitSeconds() -> Int {
        guard isTimedMode else { return 0 }
        switch difficulty {
        case .easy: return 60       // 1 minute
        case .medium: return 90     // 90 seconds
        case .hard: return 120      // 2 minutes
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
            .sink { _ in
                tickTimer()
            }
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
        let words = extractKeywords(from: verse.text, minLen: 3, maxCountRange: countRange)
        targetWords = words

        for w in words {
            _ = placeWord(w)
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

    private func placeWord(_ word: String) -> Bool {
        let tries = 600
        for _ in 0..<tries {
            let dir = allowedDirections.randomElement()!
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
