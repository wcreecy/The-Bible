import Foundation

/// One of the three columns on the iPad Home dashboard.
enum HomeColumn: String, CaseIterable, Hashable {
    case left, middle, right

    var title: String {
        switch self {
        case .left: return "Left Column"
        case .middle: return "Middle Column"
        case .right: return "Right Column"
        }
    }

    /// The short name used in pickers ("Left", "Middle", "Right").
    var shortTitle: String {
        switch self {
        case .left: return "Left"
        case .middle: return "Middle"
        case .right: return "Right"
        }
    }

    /// The neighboring column in a direction (-1 is left, +1 is right), if there is one.
    func neighbor(by offset: Int) -> HomeColumn? {
        let all = HomeColumn.allCases
        guard let index = all.firstIndex(of: self) else { return nil }
        let destination = index + offset
        return all.indices.contains(destination) ? all[destination] : nil
    }
}

/// How wide Verse of the Day is on the iPad dashboard. Wider than one column, it sits
/// above the columns it covers, which continue below it; any column it doesn't cover runs
/// the full height beside it. Wide cards stay at the top because the columns have
/// different heights, so a wide card further down would leave a gap under the shorter one.
enum HomeCardWidth: String, CaseIterable {
    case oneColumn
    case leftTwoColumns
    case rightTwoColumns
    case allColumns

    /// The columns the card covers, left to right; empty when it sits in a column.
    var coveredColumns: [HomeColumn] {
        switch self {
        case .oneColumn: return []
        case .leftTwoColumns: return [.left, .middle]
        case .rightTwoColumns: return [.middle, .right]
        case .allColumns: return HomeColumn.allCases
        }
    }

    var columnCount: Int { max(1, coveredColumns.count) }

    var spansColumns: Bool { self != .oneColumn }
}

/// The iPad dashboard's cards, top to bottom in each of three columns. The Today's Reading
/// panel, when shown, sits above the cards in its chosen column.
///
/// Every card appears exactly once, hidden ones included, so a card that is shown again
/// returns to the place it was hidden from.
struct HomeColumnLayout: Equatable {
    var left: [HomeCardID]
    var middle: [HomeCardID]
    var right: [HomeCardID]
    /// Verse of the Day keeps its place in its column while wide, so it returns there when
    /// it's narrowed to one column again.
    var verseOfDayWidth: HomeCardWidth

    init(
        left: [HomeCardID],
        middle: [HomeCardID] = [],
        right: [HomeCardID],
        verseOfDayWidth: HomeCardWidth = .oneColumn
    ) {
        self.left = left
        self.middle = middle
        self.right = right
        self.verseOfDayWidth = verseOfDayWidth
    }

    subscript(column: HomeColumn) -> [HomeCardID] {
        get {
            switch column {
            case .left: return left
            case .middle: return middle
            case .right: return right
            }
        }
        set {
            switch column {
            case .left: left = newValue
            case .middle: middle = newValue
            case .right: right = newValue
            }
        }
    }

    func column(of id: HomeCardID) -> HomeColumn? {
        HomeColumn.allCases.first { self[$0].contains(id) }
    }

    /// Whether a card sits above the columns rather than in one.
    func isSpanning(_ id: HomeCardID) -> Bool {
        id == .verseOfDay && verseOfDayWidth.spansColumns
    }

    /// The cards stacked in a column, leaving out a card that spans above the columns.
    func stackedCards(in column: HomeColumn) -> [HomeCardID] {
        self[column].filter { !isSpanning($0) }
    }

    /// A single top-to-bottom order for narrow widths: a spanning card first, as it heads
    /// the dashboard, then the columns read row by row.
    var flatOrder: [HomeCardID] {
        let rows = HomeColumn.allCases.map { stackedCards(in: $0).count }.max() ?? 0
        var order: [HomeCardID] = isSpanning(.verseOfDay) ? [.verseOfDay] : []
        for row in 0..<rows {
            for column in HomeColumn.allCases {
                let cards = stackedCards(in: column)
                if row < cards.count { order.append(cards[row]) }
            }
        }
        return order
    }

    // MARK: - Building

    /// Builds columns from a single order the way the old self-balancing grid placed cards
    /// of similar height, so the first column layout matches what people already saw.
    ///
    /// Cards fill the columns other than `readerColumn` (the Today's Reading panel's column,
    /// or nil when it's hidden). Verse of the Day, which spanned the top of the old grid,
    /// heads the first card column; then each visible card goes to the card column with the
    /// fewest visible cards, leftmost first.
    static func seeded(
        from order: [HomeCardID],
        hidden: Set<HomeCardID>,
        readerColumn: HomeColumn?
    ) -> HomeColumnLayout {
        let cardColumns = HomeColumn.allCases.filter { $0 != readerColumn }
        var layout = HomeColumnLayout(left: [], right: [])
        guard let firstColumn = cardColumns.first else { return layout }

        if order.contains(.verseOfDay) {
            layout[firstColumn].append(.verseOfDay)
        }

        var visibleCounts: [HomeColumn: Int] = [:]
        for id in order where id != .verseOfDay {
            if hidden.contains(id) {
                // Hidden cards only need a home for when they are shown again.
                let column = cardColumns.min { layout[$0].count < layout[$1].count } ?? firstColumn
                layout[column].append(id)
            } else {
                let column = cardColumns.min {
                    visibleCounts[$0, default: 0] < visibleCounts[$1, default: 0]
                } ?? firstColumn
                layout[column].append(id)
                visibleCounts[column, default: 0] += 1
            }
        }
        return layout.normalized(avoiding: readerColumn)
    }

    /// Removes duplicates and appends any card missing from every column (for example, a
    /// card added in an app update) to the shortest column, avoiding the reader's column
    /// when there is a choice.
    func normalized(avoiding readerColumn: HomeColumn? = nil) -> HomeColumnLayout {
        var seen: Set<HomeCardID> = []
        var layout = HomeColumnLayout(
            left: left.filter { seen.insert($0).inserted },
            middle: middle.filter { seen.insert($0).inserted },
            right: right.filter { seen.insert($0).inserted },
            verseOfDayWidth: verseOfDayWidth
        )
        let candidates = HomeColumn.allCases.filter { $0 != readerColumn }
        for id in HomeCardID.allCases where !seen.contains(id) {
            let column = candidates.min { layout[$0].count < layout[$1].count } ?? .left
            layout[column].append(id)
        }
        return layout
    }

    // MARK: - Moving cards

    /// Moves a card to the neighboring column (-1 is left, +1 is right) at the same row, so
    /// it slides straight across. A two-column card moves to the other pair of columns.
    mutating func moveAcross(_ id: HomeCardID, by offset: Int) {
        if isSpanning(id) {
            switch (verseOfDayWidth, offset) {
            case (.leftTwoColumns, 1): verseOfDayWidth = .rightTwoColumns
            case (.rightTwoColumns, -1): verseOfDayWidth = .leftTwoColumns
            default: break
            }
            return
        }
        guard let column = column(of: id),
              let destination = column.neighbor(by: offset),
              let row = self[column].firstIndex(of: id) else { return }
        self[column].remove(at: row)
        var cards = self[destination]
        cards.insert(id, at: min(row, cards.count))
        self[destination] = cards
    }

    func canMoveAcross(_ id: HomeCardID, by offset: Int) -> Bool {
        if isSpanning(id) {
            return (verseOfDayWidth == .leftTwoColumns && offset == 1)
                || (verseOfDayWidth == .rightTwoColumns && offset == -1)
        }
        return column(of: id)?.neighbor(by: offset) != nil
    }

    /// Moves a card up (negative offset) or down (positive offset) among the cards stacked
    /// in its column. A spanning card stays at the top.
    mutating func move(_ id: HomeCardID, by offset: Int) {
        guard canMove(id, by: offset),
              let column = column(of: id),
              let row = stackedCards(in: column).firstIndex(of: id) else { return }
        let destination = row + offset
        moveStacked(in: column, fromOffsets: [row], toOffset: destination > row ? destination + 1 : destination)
    }

    func canMove(_ id: HomeCardID, by offset: Int) -> Bool {
        guard !isSpanning(id),
              let column = column(of: id),
              let row = stackedCards(in: column).firstIndex(of: id) else { return false }
        return stackedCards(in: column).indices.contains(row + offset)
    }

    /// Reorders the cards stacked in a column (offsets as in `Array.move`), leaving a
    /// spanning card's saved place where it was.
    mutating func moveStacked(in column: HomeColumn, fromOffsets source: IndexSet, toOffset destination: Int) {
        let stacked = stackedCards(in: column)
        let moving = source.filter(stacked.indices.contains).map { stacked[$0] }
        var cards = stacked.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        let insertion = destination - source.filter { $0 < destination }.count
        cards.insert(contentsOf: moving, at: min(max(0, insertion), cards.count))
        for (index, id) in self[column].enumerated() where isSpanning(id) {
            cards.insert(id, at: min(index, cards.count))
        }
        self[column] = cards
    }

    /// Sets Verse of the Day to cover 1, 2, or 3 columns. Widening to two columns covers
    /// the side it's already on; from the middle, the side away from the Today's Reading
    /// panel, so the panel keeps its full height.
    mutating func setVerseOfDayColumnCount(_ count: Int, readerColumn: HomeColumn?) {
        switch count {
        case ...1:
            verseOfDayWidth = .oneColumn
        case 2:
            guard verseOfDayWidth.columnCount != 2 else { return }
            switch column(of: .verseOfDay) {
            case .left: verseOfDayWidth = .leftTwoColumns
            case .right: verseOfDayWidth = .rightTwoColumns
            default: verseOfDayWidth = readerColumn == .left ? .rightTwoColumns : .leftTwoColumns
            }
        default:
            verseOfDayWidth = .allColumns
        }
    }

    // MARK: - Storage

    private static let verseOfDayWidthKey = AppStorageKey.verseOfDayWidth

    /// Encodes as `{"left": [...], "middle": [...], "right": [...], "verseOfDayWidth": [...]}`
    /// using raw values. The width is a one-item list so every value keeps the same type,
    /// which older versions of the app can still read.
    var storageString: String {
        var raw = Dictionary(uniqueKeysWithValues: HomeColumn.allCases.map { ($0.rawValue, self[$0].map(\.rawValue)) })
        raw[Self.verseOfDayWidthKey] = [verseOfDayWidth.rawValue]
        guard let data = try? JSONEncoder().encode(raw) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Decodes a stored layout; returns nil when nothing valid is stored.
    ///
    /// Layouts saved before the middle column existed had two card columns beside the
    /// reader panel. Their cards move into the two columns the reader isn't in, so the
    /// dashboard looks the same.
    init?(storageString: String, readerColumn: HomeColumn?) {
        guard let raw = PersistedDecoding.decode([String: [String]].self, fromText: storageString, key: "homeColumnLayout") else {
            return nil
        }
        func cards(_ key: String) -> [HomeCardID] {
            (raw[key] ?? []).compactMap(HomeCardID.init(rawValue:))
        }

        if raw["middle"] == nil {
            let cardColumns = HomeColumn.allCases.filter { $0 != (readerColumn ?? .right) }
            self.init(left: [], right: [])
            self[cardColumns[0]] = cards("left")
            self[cardColumns[1]] = cards("right")
        } else {
            self.init(left: cards("left"), middle: cards("middle"), right: cards("right"))
        }
        verseOfDayWidth = raw[Self.verseOfDayWidthKey]?.first.flatMap(HomeCardWidth.init(rawValue:)) ?? .oneColumn
        self = normalized(avoiding: readerColumn)
    }
}
