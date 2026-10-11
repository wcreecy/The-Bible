import Foundation

public struct WordSearchEngine {
    public struct PlacedWord: Identifiable, Hashable, Sendable {
        public let id = UUID()
        public let word: String
        public let originalWord: String
        public let startRow: Int
        public let startCol: Int
        public let dr: Int
        public let dc: Int
        public init(word: String, originalWord: String? = nil, startRow: Int, startCol: Int, dr: Int, dc: Int) {
            self.word = word
            self.originalWord = originalWord ?? word
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

    /// Common words that make poor puzzle answers (KJV function words and pronouns).
    static let fillerWords: Set<String> = [
        "THE", "AND", "THAT", "SHALL", "UNTO", "FOR", "HIS", "THEY", "HIM", "NOT", "THEM", "WITH",
        "ALL", "THOU", "THY", "WAS", "WHICH", "THEE", "THEIR", "HAVE", "FROM", "HATH", "WERE", "ARE",
        "BUT", "THIS", "WHEN", "THERE", "THEN", "UPON", "OUT", "ALSO", "BEEN", "ONE", "INTO", "SAID",
        "HER", "SHE", "WILL", "SHALT", "BEFORE", "WHO", "EVEN", "NOW", "THESE", "OUR", "YOUR", "YOU",
        "AGAINST", "BECAUSE", "THEREFORE", "WHAT", "ABOUT", "AFTER", "AGAIN", "AMONG", "ANY", "EVERY",
        "HAD", "HAS", "HOW", "LET", "MAY", "MINE", "MORE", "MUCH", "NOR", "OVER", "SHOULD", "SUCH",
        "THAN", "THOSE", "THUS", "UNDER", "UNTIL", "VERY", "WHERE", "WHEREFORE", "WHOM", "WHOSE",
        "WOULD", "COULD", "BEING", "DID", "DOTH", "HAST", "WILT", "CAN", "ART", "SAITH", "SAYING",
        "LIKE", "SAME", "NEITHER", "EITHER", "YET", "ITS", "OWN", "OFF", "YEA", "NAY", "THINE",
        "WHETHER", "WHILE", "WITHIN", "WITHOUT", "WHATSOEVER", "WHOSOEVER", "HIMSELF", "THEMSELVES",
        "THYSELF", "MYSELF", "OURSELVES", "YOURSELVES", "HERSELF", "ITSELF", "THEREOF", "THEREIN",
        "HEREIN", "WHEREIN", "THITHER", "HITHER", "WHENCE", "THENCE", "HENCE", "LEST", "SHOULDEST",
    ]

    /// The verse's longest distinct words that fit the grid, skipping filler words.
    public func extractKeywords(from text: String, minLen: Int, countRange: ClosedRange<Int>) -> [String] {
        let letters = text.uppercased().map { $0.isLetter ? $0 : " " }
        let tokenized = String(letters).split(separator: " ").map(String.init)
        var uniq: [String] = []
        var seen = Set<String>()
        // Filter by grid size before choosing, so an over-long word doesn't take a slot
        // and then get dropped, leaving the puzzle short of words it could have had.
        for t in tokenized where t.count >= minLen && t.count <= size && !Self.fillerWords.contains(t) {
            if !seen.contains(t) {
                seen.insert(t)
                uniq.append(t)
            }
        }
        uniq.sort { $0.count > $1.count }
        return Array(uniq.prefix(countRange.upperBound))
    }

    public func generatePuzzle(from verseText: String, countRange: ClosedRange<Int>) -> (grid: [[Character]], placed: [PlacedWord], target: [String]) {
        // Letters from crossing words and decoys can, very rarely, line up to spell an answer
        // a second time. That copy wouldn't count when found, so build the puzzle again.
        var puzzle = buildPuzzle(from: verseText, countRange: countRange)
        for _ in 0..<5 where hasDuplicateAnswer(in: puzzle.grid, placed: puzzle.placed) {
            puzzle = buildPuzzle(from: verseText, countRange: countRange)
        }
        return puzzle
    }

    /// True when any answer can be read in the grid anywhere other than its own cells.
    private func hasDuplicateAnswer(in grid: [[Character]], placed: [PlacedWord]) -> Bool {
        let directions = [(0, 1), (1, 0), (0, -1), (-1, 0), (1, 1), (1, -1), (-1, 1), (-1, -1)]
        for pw in placed {
            let letters = Array(pw.word)
            let own = cellsForPlacedWord(pw)
            for r in 0..<size {
                for c in 0..<size where grid[r][c] == letters[0] {
                    for (dr, dc) in directions {
                        let cells = letters.indices.map { (row: r + dr * $0, col: c + dc * $0) }
                        guard cells.allSatisfy({ $0.row >= 0 && $0.row < size && $0.col >= 0 && $0.col < size }),
                              cells.map({ grid[$0.row][$0.col] }) == letters else { continue }
                        if !sequenceEquals(cells, own) && !sequenceEquals(cells, own.reversed()) { return true }
                    }
                }
            }
        }
        return false
    }

    private func buildPuzzle(from verseText: String, countRange: ClosedRange<Int>) -> (grid: [[Character]], placed: [PlacedWord], target: [String]) {
        var grid = Array(repeating: Array(repeating: Character(" "), count: size), count: size)
        var placed: [PlacedWord] = []

        let target = extractKeywords(from: verseText, minLen: 3, countRange: countRange)

        // Multi-attempt placement
        let maxAttempts = 20
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

            let desiredVariety = min(baseAllowedDirections.count, target.count)
            if count == target.count && variety >= desiredVariety { break }
        }

        grid = bestGrid
        placed = bestPlaced
        if difficulty == .expert {
            placeDecoys(for: placed, onto: &grid)
        }
        fillRandom(into: &grid, avoidingAccidentalMatchesFor: placed)

        // Only advertise words that actually made it onto the board. This keeps
        // unusually dense puzzles from becoming impossible to complete.
        return (grid, placed, placed.map(\.originalWord))
    }

    public func validateSelection(grid: [[Character]], placed: [PlacedWord], start: (row: Int, col: Int), end: (row: Int, col: Int)) -> ValidationResult {
        let cells = selectionCells(from: start, to: end)
        guard !cells.isEmpty else { return .noMatch }

        // A word counts when the selection covers exactly its cells, dragged from either end.
        if let match = placed.first(where: { pw in
            let pwCells = cellsForPlacedWord(pw)
            return sequenceEquals(cells, pwCells) || sequenceEquals(cells, pwCells.reversed())
        }) {
            return ValidationResult(matchedWordOriginal: match.originalWord, matchedPath: cells)
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
        // Words are written as-is; Hard and Expert already include backward directions,
        // so reversing the text first wouldn't change the puzzle.
        let toPlace = word

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

        // Score once per candidate. Calling random from inside the comparator can
        // make the comparison inconsistent and bias the selected placement.
        let scoredCandidates = candidates.map { (candidate: $0, score: score($0)) }
        if let best = scoredCandidates.min(by: { $0.score < $1.score })?.candidate {
            write(toPlace, atRow: best.row, col: best.col, dr: best.dr, dc: best.dc, into: &grid)
            placed.append(PlacedWord(word: toPlace, originalWord: word, startRow: best.row, startCol: best.col, dr: best.dr, dc: best.dc))
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
        for (i, letter) in word.enumerated() {
            let r = row + dr * i
            let c = col + dc * i
            guard r >= 0, r < size, c >= 0, c < size else { return (false, 0) }
            let ch = grid[r][c]
            // Filler letters are added only after placement, so any non-space cell
            // belongs to another word.
            if ch == " " { continue }
            // Expert lets words cross where they share a letter. Other levels keep
            // every word on its own cells.
            guard difficulty == .expert, ch == letter else { return (false, 0) }
            overlap += 1
        }
        // One shared cell is a crossing; more would let a word hide inside another.
        return overlap <= 1 ? (true, overlap) : (false, 0)
    }

    /// Expert only: writes look-alike fragments (a word missing its last letter) into
    /// empty cells, so a familiar start isn't always the real word.
    private func placeDecoys(for placed: [PlacedWord], onto grid: inout [[Character]]) {
        let directions = baseAllowedDirections
        let targets = placed.map(\.word)
        // Cells just past each decoy's ends. Later decoys stay off them, so one decoy
        // can't supply the missing letter that completes another.
        var reserved = Set<[Int]>()
        for pw in placed.shuffled().prefix(3) where pw.word.count >= 5 {
            let fragment = Array(pw.word.dropLast())
            // A fragment that spells another answer would be a second copy that doesn't count.
            let forward = String(fragment), backward = String(fragment.reversed())
            guard !targets.contains(where: { forward.contains($0) || backward.contains($0) }) else { continue }
            var candidates: [(row: Int, col: Int, dr: Int, dc: Int)] = []
            for dir in directions {
                for r in 0..<size {
                    for c in 0..<size {
                        let cells = fragment.indices.map { (r + dir.dr * $0, c + dir.dc * $0) }
                        guard cells.allSatisfy({
                            $0.0 >= 0 && $0.0 < size && $0.1 >= 0 && $0.1 < size
                                && grid[$0.0][$0.1] == " " && !reserved.contains([$0.0, $0.1])
                        }) else { continue }
                        // The cells just past each end must be empty or off the grid, so a
                        // decoy can only be completed by a filler letter, which fillRandom
                        // already refuses to place when it would spell a target word.
                        let before = (r - dir.dr, c - dir.dc)
                        let after = (r + dir.dr * fragment.count, c + dir.dc * fragment.count)
                        let endsClear = [before, after].allSatisfy { cell in
                            cell.0 < 0 || cell.0 >= size || cell.1 < 0 || cell.1 >= size || grid[cell.0][cell.1] == " "
                        }
                        if endsClear { candidates.append((r, c, dir.dr, dir.dc)) }
                    }
                }
            }
            guard let spot = candidates.randomElement() else { continue }
            write(String(fragment), atRow: spot.row, col: spot.col, dr: spot.dr, dc: spot.dc, into: &grid)
            reserved.insert([spot.row - spot.dr, spot.col - spot.dc])
            reserved.insert([spot.row + spot.dr * fragment.count, spot.col + spot.dc * fragment.count])
        }
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

    private func fillRandom(into grid: inout [[Character]], avoidingAccidentalMatchesFor placed: [PlacedWord]) {
        for r in 0..<size {
            for c in 0..<size {
                if grid[r][c] == " " {
                    let candidates = alphabet.shuffled()
                    if let safeLetter = candidates.first(where: { letter in
                        grid[r][c] = letter
                        return !createsAccidentalMatch(in: grid, atRow: r, col: c, placed: placed)
                    }) {
                        grid[r][c] = safeLetter
                    } else {
                        // With a normal alphabet this is extraordinarily unlikely,
                        // but always leave the grid fully populated.
                        grid[r][c] = candidates.first ?? "A"
                    }
                }
            }
        }
    }

    private func createsAccidentalMatch(in grid: [[Character]], atRow row: Int, col: Int, placed: [PlacedWord]) -> Bool {
        let directions = [
            (dr: 0, dc: 1), (dr: 1, dc: 0), (dr: 0, dc: -1), (dr: -1, dc: 0),
            (dr: 1, dc: 1), (dr: 1, dc: -1), (dr: -1, dc: 1), (dr: -1, dc: -1)
        ]

        for target in placed {
            let answer = Array(target.originalWord)
            guard !answer.isEmpty else { continue }

            // Try every position the newly filled cell could occupy in the word.
            for index in answer.indices {
                for direction in directions {
                    let startRow = row - direction.dr * index
                    let startCol = col - direction.dc * index
                    let cells = answer.indices.map { offset in
                        (row: startRow + direction.dr * offset, col: startCol + direction.dc * offset)
                    }
                    guard cells.allSatisfy({ cell in
                        cell.row >= 0 && cell.row < size && cell.col >= 0 && cell.col < size
                    }) else { continue }

                    let letters = cells.map { grid[$0.row][$0.col] }
                    guard letters == answer else { continue }

                    let actualCells = cellsForPlacedWord(target)
                    let isIntendedPath = sequenceEquals(cells, actualCells)
                        || sequenceEquals(cells, actualCells.reversed())
                    if !isIntendedPath { return true }
                }
            }
        }
        return false
    }

    // MARK: - Selection helpers (pure)

    /// Snaps a drag to the nearest straight line (one of 8 directions) from `start`, so a
    /// slightly crooked swipe still selects the cells the person meant. Selections are
    /// allowed in every direction on every level, since words can be dragged from either end.
    public func constrainToAllowedLine(from start: (row: Int, col: Int), to end: (row: Int, col: Int)) -> (row: Int, col: Int) {
        let dRow = end.row - start.row
        let dCol = end.col - start.col
        guard dRow != 0 || dCol != 0 else { return start }

        // Nearest 45° direction.
        let octant = Int((atan2(Double(dRow), Double(dCol)) / (.pi / 4)).rounded())
        let directions = [(0, 1), (1, 1), (1, 0), (1, -1), (0, -1), (-1, -1), (-1, 0), (-1, 1)]
        let (dr, dc) = directions[((octant % 8) + 8) % 8]

        // Length along that line: the drag's extent on the axis, or the average for diagonals.
        var length: Int
        if dr == 0 { length = abs(dCol) }
        else if dc == 0 { length = abs(dRow) }
        else { length = Int((Double(abs(dRow) + abs(dCol)) / 2).rounded()) }

        // Keep the end on the grid.
        while length > 0 {
            let r = start.row + dr * length, c = start.col + dc * length
            if r >= 0 && r < size && c >= 0 && c < size { break }
            length -= 1
        }
        return (row: start.row + dr * length, col: start.col + dc * length)
    }

    public func selectionCells(from start: (row: Int, col: Int), to end: (row: Int, col: Int)) -> [(row: Int, col: Int)] {
        // Callers normally pass a snapped end; snapping again makes any end point safe.
        let snapped = constrainToAllowedLine(from: start, to: end)
        let dRow = snapped.row - start.row
        let dCol = snapped.col - start.col
        let steps = max(abs(dRow), abs(dCol))
        guard steps > 0 else { return [start] }
        let dr = dRow.signum(), dc = dCol.signum()
        return (0...steps).map { (row: start.row + dr * $0, col: start.col + dc * $0) }
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
