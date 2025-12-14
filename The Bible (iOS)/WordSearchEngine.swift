import Foundation

public struct WordSearchEngine {
    public struct PlacedWord: Identifiable, Hashable, Sendable {
        public let id = UUID()
        public let word: String
        public let startRow: Int
        public let startCol: Int
        public let dr: Int
        public let dc: Int
        public var endRow: Int { startRow + dr * (word.count - 1) }
        public var endCol: Int { startCol + dc * (word.count - 1) }
        public init(word: String, startRow: Int, startCol: Int, dr: Int, dc: Int) {
            self.word = word
            self.startRow = startRow
            self.startCol = startCol
            self.dr = dr
            self.dc = dc
        }
    }

    public enum Difficulty: String, CaseIterable, Identifiable, Sendable {
        case easy, medium, hard, expert
        public var id: String { rawValue }
    }

    public struct ValidationResult: Equatable, Sendable {
        public let matchedWordOriginal: String? // forward/original text for UI/found set
        public let matchedPath: [(row: Int, col: Int)]
        public init(matchedWordOriginal: String?, matchedPath: [(row: Int, col: Int)]) {
            self.matchedWordOriginal = matchedWordOriginal
            self.matchedPath = matchedPath
        }
        public static let noMatch = ValidationResult(matchedWordOriginal: nil, matchedPath: [])

        public static func == (lhs: ValidationResult, rhs: ValidationResult) -> Bool {
            guard lhs.matchedWordOriginal == rhs.matchedWordOriginal,
                  lhs.matchedPath.count == rhs.matchedPath.count else { return false }
            return zip(lhs.matchedPath, rhs.matchedPath).allSatisfy { l, r in
                l.row == r.row && l.col == r.col
            }
        }
    }

    public let size: Int
    public let difficulty: Difficulty
    private let alphabet: [Character]

    public init(size: Int, difficulty: Difficulty, alphabet: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")) {
        self.size = size
        self.difficulty = difficulty
        self.alphabet = alphabet
    }

    // MARK: - Public API

    public func extractKeywords(from text: String, minLen: Int, countRange: ClosedRange<Int>) -> [String] {
        let letters = text.uppercased().map { $0.isLetter ? $0 : " " }
        let tokenized = String(letters).split(separator: " ").map(String.init)
        var uniq: [String] = []
        var seen = Set<String>()
        for t in tokenized where t.count >= minLen {
            if !seen.contains(t) {
                seen.insert(t)
                uniq.append(t)
            }
        }
        uniq.sort { $0.count > $1.count }
        let count = min(countRange.upperBound, max(countRange.lowerBound, uniq.count))
        return Array(uniq.prefix(count))
    }

    public func generatePuzzle(from verseText: String, countRange: ClosedRange<Int>) -> (grid: [[Character]], placed: [PlacedWord], target: [String]) {
        var grid = Array(repeating: Array(repeating: Character(" "), count: size), count: size)
        var placed: [PlacedWord] = []

        // Extract and filter by grid fit
        let extracted = extractKeywords(from: verseText, minLen: 3, countRange: countRange)
        let fitting = extracted.filter { $0.count <= size }
        let target = Array(fitting.prefix(countRange.upperBound))

        // Multi-attempt placement
        let maxAttempts = 10
        var bestPlaced: [PlacedWord] = []
        var bestGrid: [[Character]] = grid
        var bestScore: (count: Int, variety: Int, spread: Double) = (0, 0, 0)

        for _ in 0..<maxAttempts {
            grid = Array(repeating: Array(repeating: Character(" "), count: size), count: size)
            placed = []

            let wordsToPlace = wordsInterleavedByLength(target)
            var dirUsage: [String: Int] = [:]

            for w in wordsToPlace {
                _ = placeWordScattered(w, onto: &grid, placed: &placed, dirUsage: &dirUsage)
            }

            let count = placed.count
            let variety = directionVarietyScore(placed)
            let spread = averagePairwiseDistance(of: placed)

            if (count > bestScore.count)
                || (count == bestScore.count && variety > bestScore.variety)
                || (count == bestScore.count && variety == bestScore.variety && spread > bestScore.spread) {
                bestScore = (count, variety, spread)
                bestPlaced = placed
                bestGrid = grid
            }

            if count == target.count && variety >= 5 { break }
        }

        grid = bestGrid
        placed = bestPlaced
        fillRandom(into: &grid)

        return (grid, placed, target)
    }

    public func validateSelection(grid: [[Character]], placed: [PlacedWord], start: (row: Int, col: Int), end: (row: Int, col: Int)) -> ValidationResult {
        let cells = selectionCells(from: start, to: end)
        guard !cells.isEmpty else { return .noMatch }

        let forward = String(cells.map { grid[$0.row][$0.col] })
        let backward = String(forward.reversed())

        if let match = placed.first(where: { pw in
            let pwCells = cellsForPlacedWord(pw)
            let pwForward = String(pwCells.map { grid[$0.row][$0.col] })
            let pwBackward = String(pwForward.reversed())

            switch difficulty {
            case .easy:
                return (forward == pwForward && sequenceEquals(cells, pwCells))
            case .medium, .hard:
                return (forward == pwForward && sequenceEquals(cells, pwCells))
                    || (backward == pwForward && sequenceEquals(cells.reversed(), pwCells))
                    || (forward == pwBackward && sequenceEquals(cells, pwCells.reversed()))
                    || (backward == pwBackward && sequenceEquals(cells.reversed(), pwCells.reversed()))
            case .expert:
                return (forward == pwBackward && sequenceEquals(cells, pwCells.reversed()))
                    || (backward == pwBackward && sequenceEquals(cells.reversed(), pwCells.reversed()))
            }
        }) {
            let original = (difficulty == .expert) ? String(match.word.reversed()) : match.word
            return ValidationResult(matchedWordOriginal: original, matchedPath: cells)
        }

        return .noMatch
    }

    // MARK: - Directions

    private var baseAllowedDirections: [(dr: Int, dc: Int)] {
        switch difficulty {
        case .easy, .medium:
            return [(0,1), (1,0), (1,1), (1,-1)]
        case .hard, .expert:
            return [(0,1), (1,0), (0,-1), (-1,0), (1,1), (1,-1), (-1,1), (-1,-1)]
        }
    }

    private func directionsForPlacement(biasingWith usage: [String: Int]?) -> [(dr: Int, dc: Int)] {
        var dirs = baseAllowedDirections
        dirs.shuffle()
        guard let usage else { return dirs }
        return dirs.sorted { lhs, rhs in
            let lk = "\(lhs.dr),\(lhs.dc)"
            let rk = "\(rhs.dr),\(rhs.dc)"
            let lu = usage[lk] ?? 0
            let ru = usage[rk] ?? 0
            if lu == ru { return Bool.random() }
            return lu < ru
        }
    }

    // MARK: - Placement

    private struct PlacementCandidate {
        let row: Int, col: Int, dr: Int, dc: Int
        let overlap: Int, adjacency: Int
        let centerDistance: Double
        let startReusePenalty: Int
        let directionUsage: Int
    }

    private func wordsInterleavedByLength(_ words: [String]) -> [String] {
        guard words.count > 1 else { return words }
        let sorted = words.sorted { $0.count > $1.count }
        var buckets: [[String]] = []
        var currentLen: Int? = nil
        for w in sorted {
            if currentLen == nil || w.count != currentLen {
                buckets.append([w])
                currentLen = w.count
            } else {
                buckets[buckets.count - 1].append(w)
            }
        }
        for i in buckets.indices { buckets[i].shuffle() }
        var result: [String] = []
        while buckets.contains(where: { !$0.isEmpty }) {
            var order = Array(buckets.indices)
            order.shuffle()
            for idx in order where !buckets[idx].isEmpty {
                result.append(buckets[idx].removeFirst())
            }
        }
        return result
    }

    private func placeWordScattered(_ word: String, onto grid: inout [[Character]], placed: inout [PlacedWord], dirUsage: inout [String: Int]) -> Bool {
        let toPlace: String = {
            switch difficulty {
            case .expert:
                return String(word.reversed())
            case .hard:
                return Bool.random() && Double.random(in: 0...1) < 0.35 ? String(word.reversed()) : word
            default:
                return word
            }
        }()

        var candidates = enumerateCandidates(for: toPlace, on: grid, placed: placed, dirUsage: dirUsage)
        guard !candidates.isEmpty else { return false }
        candidates.shuffle()

        func score(_ c: PlacementCandidate) -> Double {
            let overlapWeight = -0.9
            let adjacencyWeight = 0.6
            let centerWeight = -0.35
            let startReuseWeight = 0.5
            let directionWeight = 0.4
            let jitter = Double.random(in: 0..<0.6)

            return overlapWeight * Double(c.overlap)
                 + adjacencyWeight * Double(c.adjacency)
                 + centerWeight * c.centerDistance
                 + startReuseWeight * Double(c.startReusePenalty)
                 + directionWeight * Double(c.directionUsage)
                 + jitter
        }

        if let best = candidates.min(by: { score($0) < score($1) }) {
            write(toPlace, atRow: best.row, col: best.col, dr: best.dr, dc: best.dc, into: &grid)
            placed.append(PlacedWord(word: toPlace, startRow: best.row, startCol: best.col, dr: best.dr, dc: best.dc))
            let key = "\(best.dr),\(best.dc)"
            dirUsage[key, default: 0] += 1
            return true
        }
        return false
    }

    private func enumerateCandidates(for word: String, on grid: [[Character]], placed: [PlacedWord], dirUsage: [String: Int]) -> [PlacementCandidate] {
        guard word.count <= size else { return [] }
        var list: [PlacementCandidate] = []
        let dirs = directionsForPlacement(biasingWith: dirUsage)

        let usedRows = Set(placed.map { $0.startRow })
        let usedCols = Set(placed.map { $0.startCol })

        let centerR = Double(size - 1) / 2.0
        let centerC = Double(size - 1) / 2.0

        for dir in dirs {
            let dr = dir.dr, dc = dir.dc

            let maxRowStart: Int = (dr == 0) ? (size - 1) : (dr > 0 ? (size - word.count) : (size - 1))
            let minRowStart: Int = (dr == 0) ? 0 : (dr > 0 ? 0 : (word.count - 1))
            if minRowStart > maxRowStart { continue }
            let rowRange = Array(minRowStart...maxRowStart)

            let maxColStart: Int = (dc == 0) ? (size - 1) : (dc > 0 ? (size - word.count) : (size - 1))
            let minColStart: Int = (dc == 0) ? 0 : (dc > 0 ? 0 : (word.count - 1))
            if minColStart > maxColStart { continue }
            let colRange = Array(minColStart...maxColStart)

            var starts: [(Int, Int)] = []
            starts.reserveCapacity(rowRange.count * colRange.count)
            for r in rowRange { for c in colRange { starts.append((r, c)) } }
            starts.shuffle()

            let dirKey = "\(dr),\(dc)"
            let usageCount = dirUsage[dirKey] ?? 0

            for (r, c) in starts {
                let probe = canPlaceAt(word: word, row: r, col: c, dr: dr, dc: dc, grid: grid)
                if probe.fits {
                    let adj = adjacencyCountFor(word: word, row: r, col: c, dr: dr, dc: dc, grid: grid)
                    let dist = hypot(Double(r) - centerR, Double(c) - centerC)
                    let reuse = (usedRows.contains(r) ? 1 : 0) + (usedCols.contains(c) ? 1 : 0)
                    list.append(PlacementCandidate(row: r, col: c, dr: dr, dc: dc, overlap: probe.overlap, adjacency: adj, centerDistance: dist, startReusePenalty: reuse, directionUsage: usageCount))
                }
            }
        }
        return list
    }

    private func canPlaceAt(word: String, row: Int, col: Int, dr: Int, dc: Int, grid: [[Character]]) -> (fits: Bool, overlap: Int) {
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

    private func adjacencyCountFor(word: String, row: Int, col: Int, dr: Int, dc: Int, grid: [[Character]]) -> Int {
        var count = 0
        let path: [(Int, Int)] = (0..<word.count).map { i in (row + dr * i, col + dc * i) }
        let neighbors = [(-1,-1), (-1,0), (-1,1), (0,-1), (0,1), (1,-1), (1,0), (1,1)]
        for (r, c) in path {
            for (nr, nc) in neighbors {
                let rr = r + nr
                let cc = c + nc
                guard rr >= 0, rr < size, cc >= 0, cc < size else { continue }
                if path.contains(where: { $0.0 == rr && $0.1 == cc }) { continue }
                if grid[rr][cc] != " " { count += 1 }
            }
        }
        return count
    }

    private func write(_ word: String, atRow row: Int, col: Int, dr: Int, dc: Int, into grid: inout [[Character]]) {
        for (i, ch) in word.enumerated() {
            let r = row + dr * i
            let c = col + dc * i
            if r >= 0 && r < size && c >= 0 && c < size {
                grid[r][c] = ch
            }
        }
    }

    private func fillRandom(into grid: inout [[Character]]) {
        for r in 0..<size {
            for c in 0..<size {
                if grid[r][c] == " " {
                    grid[r][c] = alphabet.randomElement() ?? "A"
                }
            }
        }
    }

    // MARK: - Selection helpers (pure)

    public func constrainToAllowedLine(from start: (row: Int, col: Int), to end: (row: Int, col: Int)) -> (row: Int, col: Int) {
        let dRow = end.row - start.row
        let dCol = end.col - start.col
        func sign(_ x: Int) -> Int { x == 0 ? 0 : (x > 0 ? 1 : -1) }
        var dr = sign(dRow)
        var dc = sign(dCol)

        if dr != 0 && dc != 0 {
            // diagonal ok
        } else {
            // axis-aligned ok
        }

        let allowed = baseAllowedDirections
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

    public func selectionCells(from start: (row: Int, col: Int), to end: (row: Int, col: Int)) -> [(row: Int, col: Int)] {
        let dRow = end.row - start.row
        let dCol = end.col - start.col
        if dRow == 0 && dCol == 0 { return [start] }
        func sign(_ x: Int) -> Int { x == 0 ? 0 : (x > 0 ? 1 : -1) }
        var dr = sign(dRow)
        var dc = sign(dCol)
        if !baseAllowedDirections.contains(where: { $0.dr == dr && $0.dc == dc }) {
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

    public func cellsForPlacedWord(_ pw: PlacedWord) -> [(row: Int, col: Int)] {
        var cells: [(Int, Int)] = []
        for i in 0..<pw.word.count {
            cells.append((pw.startRow + pw.dr * i, pw.startCol + pw.dc * i))
        }
        return cells
    }

    // MARK: - Scoring helpers

    private func directionVarietyScore(_ words: [PlacedWord]) -> Int {
        var set = Set<String>()
        for pw in words {
            let norm = "\(pw.dr),\(pw.dc)"
            set.insert(norm)
        }
        return set.count
    }

    private func averagePairwiseDistance(of words: [PlacedWord]) -> Double {
        guard words.count > 1 else { return 0 }
        var sum: Double = 0
        var pairs = 0
        for i in 0..<(words.count - 1) {
            for j in (i + 1)..<words.count {
                let a = words[i]
                let b = words[j]
                let ar = Double(a.startRow), ac = Double(a.startCol)
                let br = Double(b.startRow), bc = Double(b.startCol)
                let d = hypot(ar - br, ac - bc)
                sum += d
                pairs += 1
            }
        }
        return pairs > 0 ? sum / Double(pairs) : 0
    }

    // MARK: - Sequence equality

    private func sequenceEquals<T: Equatable>(_ a: some Sequence<T>, _ b: some Sequence<T>) -> Bool {
        var ia = a.makeIterator(), ib = b.makeIterator()
        while true {
            let va = ia.next(), vb = ib.next()
            if va == nil || vb == nil { return va == nil && vb == nil }
            if va! != vb! { return false }
        }
    }

    private func sequenceEquals(_ a: some Sequence<(row: Int, col: Int)>, _ b: some Sequence<(row: Int, col: Int)>) -> Bool {
        var ia = a.makeIterator(), ib = b.makeIterator()
        while true {
            let va = ia.next(), vb = ib.next()
            if va == nil || vb == nil { return va == nil && vb == nil }
            if va!.row != vb!.row || va!.col != vb!.col { return false }
        }
    }
}
