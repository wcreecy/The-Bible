import Foundation

/// The Notes page's filters, kept together so the page and tests share one definition.
struct NotesFilters: Equatable {
    var category: NotesFilter = .all
    var tag: String?
    var search = ""

    var isActive: Bool {
        category != .all || tag != nil || !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// A heading and its notes in the Notes list.
struct NotesListSection: Identifiable {
    let id: String
    /// Nil for a list with no headings, such as one sorted by title.
    let title: String?
    var systemImage: String?
    var items: [NotesListItem]
}

/// Filters, sorts, and summarizes notes in one pass, so the page computes them once per update.
/// Favorites come first, but every filter still applies to them.
///
/// Only written notes are listed. A verse that's highlighted without a note belongs to
/// Saved Verses, and a highlighted note mentions its highlight only in the note itself.
@MainActor
struct NotesLibrary {
    struct TagCount: Identifiable, Equatable {
        let tag: String
        let count: Int
        var id: String { tag }
    }

    /// Every written note, in no particular order.
    let allItems: [NotesListItem]
    /// Notes that match the filters: favorites first, then the rest, each in sort order.
    let visibleItems: [NotesListItem]
    /// Every custom tag across all notes, A–Z, with how many notes use it.
    let tags: [TagCount]
    /// `visibleItems` under headings: Favorites, then groups that follow the sort.
    let sections: [NotesListSection]

    private let filters: NotesFilters

    init(
        scriptureNotes: [VerseNote],
        userNotes: [UserNote],
        filters: NotesFilters,
        sort: NotesTabSort,
        ascending: Bool,
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        self.filters = filters
        let items = scriptureNotes.map(NotesListItem.scripture).filter(\.hasNoteText) + userNotes.map(NotesListItem.user)
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
                item.matchesSearch(filters.search, tags: itemTags)
        }
        let ordered = Self.sorted(matching, by: sort, ascending: ascending)
        let favorites = ordered.filter(\.isFavorite)
        let others = ordered.filter { !$0.isFavorite }
        visibleItems = favorites + others

        var sections: [NotesListSection] = []
        if !favorites.isEmpty {
            sections.append(NotesListSection(id: "favorites", title: String(localized: "Favorites"), systemImage: "star.fill", items: favorites))
        }
        var groups = Self.grouped(others, by: sort, now: now, calendar: calendar)
        // A list with no groupings still needs a heading under Favorites.
        if !favorites.isEmpty, groups.count == 1, groups[0].title == nil {
            groups[0] = NotesListSection(id: "notes", title: String(localized: "Notes"), systemImage: "note.text", items: groups[0].items)
        }
        self.sections = sections + groups
    }

    // MARK: Grouping

    /// Groups sorted notes under headings that match the sort, keeping the sorted order.
    /// Title order has no headings.
    static func grouped(
        _ items: [NotesListItem],
        by sort: NotesTabSort,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [NotesListSection] {
        guard !items.isEmpty else { return [] }
        guard sort != .title else {
            return [NotesListSection(id: "all", title: nil, items: items)]
        }

        var sections: [NotesListSection] = []
        var indexByID: [String: Int] = [:]
        for item in items {
            let heading = section(for: item, by: sort, now: now, calendar: calendar)
            if let index = indexByID[heading.id] {
                sections[index].items.append(item)
            } else {
                indexByID[heading.id] = sections.count
                var section = heading
                section.items = [item]
                sections.append(section)
            }
        }
        return sections
    }

    private static func section(
        for item: NotesListItem,
        by sort: NotesTabSort,
        now: Date,
        calendar: Calendar
    ) -> NotesListSection {
        switch sort {
        case .modified:
            return dateSection(for: item.updatedAt, now: now, calendar: calendar)
        case .created:
            return dateSection(for: item.createdAt, now: now, calendar: calendar)
        case .tag:
            let filter = NotesFilter(rawValue: item.categoryRawValue)
            let title = item.category.map { String(localized: $0.title) } ?? String(localized: "Other")
            return NotesListSection(id: "type.\(item.categoryRawValue)", title: title, systemImage: filter?.systemImage, items: [])
        case .bibleOrder:
            guard let book = item.bibleLocation?.bookName else {
                return NotesListSection(id: "book.none", title: String(localized: "No Passage"), systemImage: "note.text", items: [])
            }
            return NotesListSection(id: "book.\(book)", title: book, systemImage: "book.closed", items: [])
        case .title:
            return NotesListSection(id: "all", title: nil, items: [])
        }
    }

    /// Today, This Week, This Month, then each earlier month ("September", or "September
    /// 2025" before this year). Each is a continuous span of time, so sorted notes stay
    /// in order; a date in the future counts as today.
    private static func dateSection(for date: Date?, now: Date, calendar: Calendar) -> NotesListSection {
        guard let date else {
            return NotesListSection(id: "date.none", title: String(localized: "No Date"), items: [])
        }
        let day = min(date, now)
        if calendar.isDate(day, inSameDayAs: now) {
            return NotesListSection(id: "date.today", title: String(localized: "Today"), items: [])
        }
        if calendar.isDate(day, equalTo: now, toGranularity: .weekOfYear) {
            return NotesListSection(id: "date.week", title: String(localized: "This Week"), items: [])
        }
        if calendar.isDate(day, equalTo: now, toGranularity: .month) {
            return NotesListSection(id: "date.month", title: String(localized: "This Month"), items: [])
        }
        let month = calendar.dateComponents([.year, .month], from: day)
        let isThisYear = calendar.isDate(day, equalTo: now, toGranularity: .year)
        var style = Date.FormatStyle.dateTime.month(.wide)
        if !isThisYear { style = style.year() }
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        return NotesListSection(
            id: "date.\(month.year ?? 0)-\(month.month ?? 0)",
            title: day.formatted(style),
            items: []
        )
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
    /// e.g. "Sermon Notes · #prayer · 4".
    var summaryTitle: String {
        var parts = [String(localized: filters.category.libraryTitle)]
        if let tag = filters.tag { parts.append("#\(tag)") }
        let search = filters.search.trimmingCharacters(in: .whitespacesAndNewlines)
        if !search.isEmpty { parts.append("“\(search)”") }
        parts.append(visibleItems.count.formatted())
        return parts.joined(separator: " · ")
    }

    // MARK: Sorting

    static func sorted(_ items: [NotesListItem], by field: NotesTabSort, ascending: Bool) -> [NotesListItem] {
        // Reading a personal note's passage means parsing it, so do it once per note.
        let positions = field == .bibleOrder
            ? Dictionary(uniqueKeysWithValues: items.map { ($0.id, biblePosition(of: $0)) })
            : [:]
        return items.sorted { lhs, rhs in
            let order: ComparisonResult
            if field == .bibleOrder {
                // Notes without a passage come last in either direction.
                let left = positions[lhs.id] ?? nil
                let right = positions[rhs.id] ?? nil
                switch (left, right) {
                case let (left?, right?) where left != right:
                    return (left < right) == ascending
                case (nil, _?): return false
                case (_?, nil): return true
                default: order = .orderedSame
                }
            } else {
                order = compare(lhs, rhs, by: field)
            }
            if order != .orderedSame {
                return order == (ascending ? .orderedAscending : .orderedDescending)
            }
            // Ties always fall back to title A–Z so the order is stable and predictable.
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    private static let canonIndex = Dictionary(
        uniqueKeysWithValues: BibleCanon.fallbackCanon.enumerated().map { ($1, $0) }
    )

    /// Book, chapter, and verse as one comparable number; nil without a passage. Books
    /// outside the canon list sort after Revelation.
    private static func biblePosition(of item: NotesListItem) -> Int? {
        guard let location = item.bibleLocation else { return nil }
        let book = canonIndex[location.bookName] ?? canonIndex.count
        return (book * 1_000 + location.chapter) * 1_000 + location.startVerse
    }

    private static func compare(_ lhs: NotesListItem, _ rhs: NotesListItem, by field: NotesTabSort) -> ComparisonResult {
        switch field {
        case .bibleOrder:
            return .orderedSame
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
        }
    }
}
