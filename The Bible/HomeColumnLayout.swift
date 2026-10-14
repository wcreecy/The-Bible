import Foundation

/// One of the two card columns on the iPad Home dashboard.
enum HomeColumn: String, CaseIterable, Hashable {
    case left, right

    var title: String {
        switch self {
        case .left: return "Left Column"
        case .right: return "Right Column"
        }
    }

    var other: HomeColumn {
        self == .left ? .right : .left
    }
}

/// The iPad dashboard's cards, top to bottom in each column.
///
/// Every card appears exactly once, hidden ones included, so a card that is shown again
/// returns to the place it was hidden from.
struct HomeColumnLayout: Equatable {
    var left: [HomeCardID]
    var right: [HomeCardID]

    subscript(column: HomeColumn) -> [HomeCardID] {
        get { column == .left ? left : right }
        set {
            if column == .left {
                left = newValue
            } else {
                right = newValue
            }
        }
    }

    func column(of id: HomeCardID) -> HomeColumn? {
        if left.contains(id) { return .left }
        if right.contains(id) { return .right }
        return nil
    }

    /// A single top-to-bottom order for narrow widths, read row by row across the columns.
    var flatOrder: [HomeCardID] {
        var order: [HomeCardID] = []
        for row in 0..<max(left.count, right.count) {
            if row < left.count { order.append(left[row]) }
            if row < right.count { order.append(right[row]) }
        }
        return order
    }

    // MARK: - Building

    /// Builds columns from a single order the way the old self-balancing grid placed cards
    /// of similar height, so the first column layout matches what people already saw:
    /// Verse of the Day (which spanned the top) heads the left column, then each visible
    /// card goes to the column with fewer visible cards, left first.
    static func seeded(from order: [HomeCardID], hidden: Set<HomeCardID>) -> HomeColumnLayout {
        var layout = HomeColumnLayout(left: [], right: [])
        if order.contains(.verseOfDay) {
            layout.left.append(.verseOfDay)
        }

        var visibleCounts: [HomeColumn: Int] = [.left: 0, .right: 0]
        for id in order where id != .verseOfDay {
            if hidden.contains(id) {
                // Hidden cards only need a home for when they are shown again.
                let column: HomeColumn = layout.left.count <= layout.right.count ? .left : .right
                layout[column].append(id)
            } else {
                let column: HomeColumn = visibleCounts[.left, default: 0] <= visibleCounts[.right, default: 0] ? .left : .right
                layout[column].append(id)
                visibleCounts[column, default: 0] += 1
            }
        }
        return layout.normalized()
    }

    /// Removes duplicates and appends any card missing from both columns (for example, a
    /// card added in an app update) to the shorter column.
    func normalized() -> HomeColumnLayout {
        var seen: Set<HomeCardID> = []
        var layout = HomeColumnLayout(
            left: left.filter { seen.insert($0).inserted },
            right: right.filter { seen.insert($0).inserted }
        )
        for id in HomeCardID.allCases where !seen.contains(id) {
            let column: HomeColumn = layout.left.count <= layout.right.count ? .left : .right
            layout[column].append(id)
        }
        return layout
    }

    // MARK: - Moving cards

    /// Moves a card to the other column at the same row, so it slides straight across.
    mutating func moveToOtherColumn(_ id: HomeCardID) {
        guard let column = column(of: id), let row = self[column].firstIndex(of: id) else { return }
        let destination = column.other
        self[column].remove(at: row)
        var cards = self[destination]
        cards.insert(id, at: min(row, cards.count))
        self[destination] = cards
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

    /// Encodes as `{"left": [...], "right": [...]}` using card raw values.
    var storageString: String {
        let raw = ["left": left.map(\.rawValue), "right": right.map(\.rawValue)]
        guard let data = try? JSONEncoder().encode(raw) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    init(left: [HomeCardID], right: [HomeCardID]) {
        self.left = left
        self.right = right
    }

    /// Decodes a stored layout; returns nil when nothing valid is stored.
    init?(storageString: String) {
        guard let data = storageString.data(using: .utf8),
              let raw = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return nil
        }
        self.init(
            left: (raw["left"] ?? []).compactMap(HomeCardID.init(rawValue:)),
            right: (raw["right"] ?? []).compactMap(HomeCardID.init(rawValue:))
        )
        self = normalized()
    }
}
