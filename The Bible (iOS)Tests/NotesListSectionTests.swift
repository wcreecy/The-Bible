import Foundation
import Testing
@testable import Bible

@MainActor
struct NotesListSectionTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.firstWeekday = 1
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }

    /// Thursday, October 15, 2026, at noon UTC.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 12)) ?? .now
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 9)) ?? .distantPast
    }

    private func verseNote(
        _ book: String, _ chapter: Int, _ verse: Int,
        title: String = "", content: String = "", highlight: String = "",
        favorite: Bool = false, updated: Date? = nil
    ) -> VerseNote {
        let note = VerseNote()
        note.bookName = book
        note.chapterNumber = chapter
        note.verseNumber = verse
        note.title = title
        note.content = content
        note.highlightColor = highlight
        note.isFavorite = favorite
        note.categoryRawValue = NoteCategory.scripture.rawValue
        note.updatedAt = updated
        return note
    }

    private func userNote(
        title: String, category: NoteCategory = .personal, passage: String = "",
        favorite: Bool = false, updated: Date? = nil
    ) -> UserNote {
        let note = UserNote()
        note.title = title
        note.content = "Body"
        note.categoryRawValue = category.rawValue
        note.passageReference = passage
        note.isFavorite = favorite
        note.updatedAt = updated
        return note
    }

    private func library(
        _ verseNotes: [VerseNote], _ userNotes: [UserNote],
        sort: NotesTabSort, ascending: Bool? = nil
    ) -> NotesLibrary {
        NotesLibrary(
            scriptureNotes: verseNotes,
            userNotes: userNotes,
            filters: NotesFilters(),
            sort: sort,
            ascending: ascending ?? sort.defaultAscending,
            now: now,
            calendar: calendar
        )
    }

    private func headings(_ library: NotesLibrary) -> [String?] {
        library.sections.map(\.title)
    }

    @Test
    func dateSortGroupsByRecency() {
        let notes = [
            userNote(title: "Today", updated: date(2026, 10, 15)),
            userNote(title: "Monday", updated: date(2026, 10, 12)),
            userNote(title: "Early October", updated: date(2026, 10, 2)),
            userNote(title: "September", updated: date(2026, 9, 20)),
            userNote(title: "Last Year", updated: date(2025, 12, 1)),
            userNote(title: "Undated")
        ]
        let newestFirst = library([], notes, sort: .modified)
        #expect(headings(newestFirst) == ["Today", "This Week", "This Month", "September", "December 2025", "No Date"])
        #expect(newestFirst.sections.flatMap(\.items).map(\.title) == newestFirst.visibleItems.map(\.title))

        // Oldest first keeps each heading's notes together, in reverse.
        let oldestFirst = library([], notes, sort: .modified, ascending: true)
        #expect(headings(oldestFirst) == ["No Date", "December 2025", "September", "This Month", "This Week", "Today"])
    }

    @Test
    func aFutureDateCountsAsToday() {
        let notes = [userNote(title: "Clock ahead", updated: date(2026, 10, 20))]
        #expect(headings(library([], notes, sort: .modified)) == ["Today"])
    }

    @Test
    func typeAndColorSortsGroupByThatField() {
        let byType = library(
            [verseNote("John", 3, 16, content: "Love")],
            [userNote(title: "Sunday", category: .sermon), userNote(title: "Journal")],
            sort: .tag
        )
        #expect(headings(byType) == ["Personal Notes", "Scripture Notes", "Sermon Notes"])

        let byColor = library(
            [
                verseNote("John", 3, 16, highlight: "blue"),
                verseNote("Romans", 8, 28, highlight: "yellow"),
                verseNote("Psalms", 23, 1)
            ],
            [],
            sort: .color
        )
        #expect(headings(byColor) == ["Yellow", "Blue", "No Highlight"])
        #expect(byColor.sections.first?.highlight == .yellow)
    }

    @Test
    func bibleOrderGroupsByBookInCanonicalOrder() {
        let ordered = library(
            [
                verseNote("John", 3, 16, content: "a"),
                verseNote("Genesis", 1, 1, content: "b"),
                verseNote("John", 1, 1, content: "c")
            ],
            [
                userNote(title: "Psalm study", passage: "Psalm 23:1"),
                userNote(title: "Prayer list")
            ],
            sort: .bibleOrder
        )
        #expect(headings(ordered) == ["Genesis", "Psalms", "John", "No Passage"])
        #expect(ordered.sections[2].items.map(\.passage) == ["John 1:1", "John 3:16"])

        // Notes without a passage stay last when the order is reversed.
        let reversed = library(
            [verseNote("Genesis", 1, 1, content: "b"), verseNote("John", 3, 16, content: "a")],
            [userNote(title: "Prayer list")],
            sort: .bibleOrder,
            ascending: false
        )
        #expect(headings(reversed) == ["John", "Genesis", "No Passage"])
    }

    @Test
    func favoritesLeadAndTitleOrderHasNoHeadings() {
        let plain = library([], [userNote(title: "B"), userNote(title: "A")], sort: .title)
        #expect(headings(plain) == [nil])

        let withFavorite = library([], [userNote(title: "B"), userNote(title: "A", favorite: true)], sort: .title)
        #expect(headings(withFavorite) == ["Favorites", "Notes"])

        let grouped = library(
            [],
            [userNote(title: "Starred", favorite: true, updated: date(2026, 1, 1)), userNote(title: "Recent", updated: date(2026, 10, 15))],
            sort: .modified
        )
        #expect(headings(grouped) == ["Favorites", "Today"])
        #expect(library([], [], sort: .modified).sections.isEmpty)
    }

    @Test
    func rowsDoNotRepeatTheTitleAsThePassage() {
        let untitled = NotesListItem.scripture(verseNote("John", 3, 16, content: "Love"))
        #expect(untitled.title == "John 3:16")
        #expect(untitled.rowPassage == nil)

        let titled = NotesListItem.scripture(verseNote("John", 3, 16, title: "God's love", content: "Love"))
        #expect(titled.rowPassage == "John 3:16")
    }
}
