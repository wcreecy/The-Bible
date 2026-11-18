import Foundation
import Testing
@testable import Bible

@MainActor
struct PencilFeatureRegressionTests {
    /// The book-list Pencil menu always offers a retelling. This guards the shipped data
    /// that the menu opens against a missing or empty story.
    @Test
    func everyBookHasAPlainEnglishRetellingForThePencilMenu() async throws {
        let url = try #require(Bundle.main.url(forResource: "KJVText", withExtension: "json"))
        let books = try BibleData.decodeBooks(from: Data(contentsOf: url))
        #expect(books.count == 66)

        for book in books {
            let overview = await BibleBookOverviewRepository.shared.overview(forBookNamed: book.name)
            let story = try #require(overview?.story, "Missing retelling for \(book.name)")

            #expect(!story.isEmpty, "\(book.name) has no retelling sections")
            #expect(story.allSatisfy { !$0.passage.isEmpty && !$0.text.isEmpty }, "\(book.name) has an incomplete retelling section")
        }
    }

    /// Search-result actions need to retain the exact verse used by the shared action menu.
    @Test
    func searchResultIdentityIncludesItsExactVerseLocation() {
        let result = SearchResult(
            bookIndex: 42,
            bookName: "John",
            chapterNumber: 3,
            verseNumber: 16,
            verseText: "For God so loved the world",
            isReferenceMatch: false
        )

        #expect(result.id == "42:3:16")
        #expect(!result.isOmitted)
    }
}
