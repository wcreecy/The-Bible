import Foundation

/// The Notes page's filters, kept together so the page and tests share one definition.
struct NotesFilters: Equatable {
    var category: NotesFilter = .all
    var tag: String?
    var highlight: NotesHighlightFilter = .all
    var content: NotesContentFilter = .all
    var search = ""

    var isActive: Bool {
        category != .all || tag != nil || highlight != .all || content != .all ||
            !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Filters, sorts, and summarizes notes in one pass, so the page computes them once per update.
/// Favorites come first, but every filter still applies to them.
@MainActor
struct NotesLibrary {
    struct TagCount: Identifiable, Equatable {
        let tag: String
        let count: Int
        var id: String { tag }
    }

    /// Every note, in no particular order.
    let allItems: [NotesListItem]
    /// Notes that match the filters: favorites first, then the rest, each in sort order.
    let visibleItems: [NotesListItem]
    /// Every custom tag across all notes, A–Z, with how many notes use it.
    let tags: [TagCount]

    private let filters: NotesFilters

    init(
        scriptureNotes: [VerseNote],
        userNotes: [UserNote],
        filters: NotesFilters,
        sort: NotesTabSort,
        ascending: Bool
    ) {
        self.filters = filters
        let items = scriptureNotes.map(NotesListItem.scripture) + userNotes.map(NotesListItem.user)
        allItems = items

        // Parse each note's tags once; filtering, search, and the tag counts all reuse them.
        let tagsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.customTags) })
        var counts: [String: Int] = [:]
        for itemTags in tagsByID.values {
            for tag in itemTags { counts[tag, default: 0] += 1 }
        }
        tags = counts
            .map { TagCount(tag: $0.key, count: $0.value) }
            .sorted { $0.tag.localizedStandardCompare($1.tag) == .orderedAscending }

        let matching = items.filter { item in
            let itemTags = tagsByID[item.id] ?? []
            return (filters.category == .all || item.categoryRawValue == filters.category.rawValue) &&
                (filters.tag.map(itemTags.contains) ?? true) &&
                filters.highlight.matches(item.highlightColor) &&
                filters.content.matches(item) &&
                item.matchesSearch(filters.search, tags: itemTags)
        }
        let ordered = Self.sorted(matching, by: sort, ascending: ascending)
        visibleItems = ordered.filter(\.isFavorite) + ordered.filter { !$0.isFavorite }
    }

    func item(withID id: NotesListItem.ID?) -> NotesListItem? {
        guard let id else { return nil }
        return allItems.first { $0.id == id }
    }

    func isVisible(_ id: NotesListItem.ID?) -> Bool {
        guard let id else { return false }
        return visibleItems.contains { $0.id == id }
    }

    /// The list heading: the type, then any other active filter, then the count,
    /// e.g. "Sermon Notes · #prayer · Yellow · 4".
    var summaryTitle: String {
        var parts = [String(localized: filters.category.libraryTitle)]
        if let tag = filters.tag { parts.append("#\(tag)") }
        if filters.highlight != .all { parts.append(String(localized: filters.highlight.title)) }
        if filters.content != .all { parts.append(String(localized: filters.content.title)) }
        let search = filters.search.trimmingCharacters(in: .whitespacesAndNewlines)
        if !search.isEmpty { parts.append("“\(search)”") }
        parts.append(visibleItems.count.formatted())
        return parts.joined(separator: " · ")
    }

    // MARK: Sorting

    static func sorted(_ items: [NotesListItem], by field: NotesTabSort, ascending: Bool) -> [NotesListItem] {
        items.sorted { lhs, rhs in
            let order = compare(lhs, rhs, by: field)
            if order != .orderedSame {
                return order == (ascending ? .orderedAscending : .orderedDescending)
            }
            // Ties always fall back to title A–Z so the order is stable and predictable.
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    private static func compare(_ lhs: NotesListItem, _ rhs: NotesListItem, by field: NotesTabSort) -> ComparisonResult {
        switch field {
        case .modified:
            return (lhs.updatedAt ?? .distantPast).compare(rhs.updatedAt ?? .distantPast)
        case .created:
            return (lhs.createdAt ?? .distantPast).compare(rhs.createdAt ?? .distantPast)
        case .title:
            return lhs.title.localizedStandardCompare(rhs.title)
        case .tag:
            let left = lhs.category.map { String(localized: $0.title) } ?? lhs.categoryRawValue
            let right = rhs.category.map { String(localized: $0.title) } ?? rhs.categoryRawValue
            return left.localizedStandardCompare(right)
        case .color:
            // Follow the highlight picker's color order; notes without a highlight sort last.
            let left = colorPosition(lhs.highlightColor)
            let right = colorPosition(rhs.highlightColor)
            return left == right ? .orderedSame : (left < right ? .orderedAscending : .orderedDescending)
        }
    }

    private static func colorPosition(_ rawValue: String) -> Int {
        VerseHighlightColor.allCases.firstIndex { $0.rawValue == rawValue } ?? VerseHighlightColor.allCases.count
    }
}
