import Foundation
import Testing
@testable import Bible

@MainActor
struct SavedHighlightsTests {
    private let bookNames = BibleCanon.fallbackCanon

    private func note(
        _ book: String, _ chapter: Int, _ verse: Int, through end: Int = 0,
        color: String, text: String = "", content: String = "", updated: TimeInterval = 0
    ) -> VerseNote {
        let note = VerseNote()
        note.bookName = book
        note.chapterNumber = chapter
        note.verseNumber = verse
        note.endVerseNumber = end
        note.verseText = text
        note.content = content
        note.highlightColor = color
        note.updatedAt = Date(timeIntervalSince1970: updated)
        return note
    }

    private func library(
        _ notes: [VerseNote],
        color: VerseHighlightColor? = nil,
        search: String = "",
        sort: FavoritesView.SortOrder = .recent
    ) -> HighlightsLibrary {
        HighlightsLibrary(notes: notes, color: color, searchText: search, sort: sort, bookNames: bookNames)
    }

    private func references(_ library: HighlightsLibrary) -> [String] {
        library.sections.flatMap(\.highlights).map(\.reference)
    }

    private var sample: [VerseNote] {
        [
            note("John", 3, 16, color: "yellow", text: "For God so loved the world", updated: 30),
            note("Genesis", 1, 1, color: "blue", text: "In the beginning", content: "Creation study", updated: 20),
            note("John", 1, 1, through: 3, color: "yellow", text: "In the beginning was the Word", updated: 10),
            note("Romans", 8, 28, color: "", text: "All things", content: "Not highlighted", updated: 40)
        ]
    }

    @Test
    func listsOnlyHighlightedVersesNewestFirst() {
        let all = library(sample)
        #expect(all.totalCount == 3)
        #expect(references(all) == ["John 3:16", "Genesis 1:1", "John 1:1–3"])
    }

    @Test
    func filtersByColor() {
        #expect(references(library(sample, color: .yellow)) == ["John 3:16", "John 1:1–3"])
        #expect(library(sample, color: .pink).sections.isEmpty)
        // The total stays, so the screen can tell "no highlights" from "none in this color".
        #expect(library(sample, color: .pink).totalCount == 3)
    }

    @Test
    func searchesReferencesRangesVerseTextAndNotes() {
        #expect(references(library(sample, search: "John 3:16")) == ["John 3:16"])
        // A verse inside a highlighted range finds the range.
        #expect(references(library(sample, search: "John 1:2")) == ["John 1:1–3"])
        #expect(references(library(sample, search: "beginning")) == ["Genesis 1:1", "John 1:1–3"])
        #expect(references(library(sample, search: "creation")) == ["Genesis 1:1"])
        #expect(library(sample, search: "not highlighted").sections.isEmpty)
    }

    @Test
    func bibleOrderGroupsByBook() {
        let ordered = library(sample, sort: .bibleOrder)
        #expect(ordered.sections.map(\.title) == ["Genesis", "John"])
        #expect(ordered.sections[1].highlights.map(\.reference) == ["John 1:1–3", "John 3:16"])
    }

    @Test
    func favoritesSearchStillMatchesSingleVerses() {
        let favorite = Favorite(bookName: "John", chapterNumber: 3, verseNumber: 16, verseText: "For God so loved the world")
        #expect(SavedVerseSearchQuery("John 3:16", bookNames: bookNames)?.matches(favorite) == true)
        #expect(SavedVerseSearchQuery("John 3:17", bookNames: bookNames)?.matches(favorite) == false)
        #expect(SavedVerseSearchQuery("loved", bookNames: bookNames)?.matches(favorite) == true)
    }
}
