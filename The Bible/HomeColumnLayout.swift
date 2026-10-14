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

/// The iPad dashboard's cards, top to bottom in each of three columns. The Today's Reading
/// panel, when shown, sits above the cards in its chosen column.
///
/// Every card appears exactly once, hidden ones included, so a card that is shown again
/// returns to the place it was hidden from.
struct HomeColumnLayout: Equatable {
    var left: [HomeCardID]
    var middle: [HomeCardID]
    var right: [HomeCardID]

    init(left: [HomeCardID], middle: [HomeCardID] = [], right: [HomeCardID]) {
        self.left = left
        self.middle = middle
        self.right = right
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

    /// A single top-to-bottom order for narrow widths, read row by row across the columns.
    var flatOrder: [HomeCardID] {
        let rows = HomeColumn.allCases.map { self[$0].count }.max() ?? 0
        var order: [HomeCardID] = []
        for row in 0..<rows {
            for column in HomeColumn.allCases where row < self[column].count {
                order.append(self[column][row])
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
            right: right.filter { seen.insert($0).inserted }
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
    /// it slides straight across.
    mutating func moveAcross(_ id: HomeCardID, by offset: Int) {
        guard let column = column(of: id),
              let destination = column.neighbor(by: offset),
              let row = self[column].firstIndex(of: id) else { return }
        self[column].remove(at: row)
        var cards = self[destination]
        cards.insert(id, at: min(row, cards.count))
        self[destination] = cards
    }

    func canMoveAcross(_ id: HomeCardID, by offset: Int) -> Bool {
        column(of: id)?.neighbor(by: offset) != nil
    }

    /// Moves a card up (negative offset) or down (positive offset) within its column.
    mutating func move(_ id: HomeCardID, by offset: Int) {
        guard let column = column(of: id), let row = self[column].firstIndex(of: id) else { return }
        let destination = row + offset
        guard self[column].indices.contains(destination) else { return }
        self[column].swapAt(row, destination)
    }

    func canMove(_ id: HomeCardID, by offset: Int) -> Bool {
        guard let column = column(of: id), let row = self[column].firstIndex(of: id) else { return false }
        return self[column].indices.contains(row + offset)
    }

    // MARK: - Storage

    /// Encodes as `{"left": [...], "middle": [...], "right": [...]}` using card raw values.
    var storageString: String {
        let raw = Dictionary(uniqueKeysWithValues: HomeColumn.allCases.map { ($0.rawValue, self[$0].map(\.rawValue)) })
        guard let data = try? JSONEncoder().encode(raw) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Decodes a stored layout; returns nil when nothing valid is stored.
    ///
    /// Layouts saved before the middle column existed had two card columns beside the
    /// reader panel. Their cards move into the two columns the reader isn't in, so the
    /// dashboard looks the same.
    init?(storageString: String, readerColumn: HomeColumn?) {
        guard let data = storageString.data(using: .utf8),
              let raw = try? JSONDecoder().decode([String: [String]].self, from: data) else {
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
        self = normalized(avoiding: readerColumn)
    }
}
