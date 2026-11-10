import Testing
@testable import Bible

/// Focus Mode numbers every page of the Bible (a title page per chapter, then its verses)
/// without building them, so a wrong page number means landing on the wrong verse.
@MainActor
struct FocusPageMapTests {
    private func kjvMap() async throws -> (map: FocusPageMap, books: [Book]) {
        let books = await BibleRepository.shared.loadAllBooks(for: .kjv)
        try #require(!books.isEmpty)
        return (FocusPageMap(books: books), books)
    }

    @Test func everyChapterHasATitlePageAndEveryVerseAPage() async throws {
        let (map, books) = try await kjvMap()
        let chapters = books.reduce(0) { $0 + $1.chapters.count }
        let verses = books.reduce(0) { total, book in
            total + book.chapters.reduce(0) { $0 + $1.verses.count }
        }
        #expect(chapters == 1_189)
        #expect(map.pageCount == chapters + verses)
    }

    @Test func theFirstPageIsGenesisOnesTitleAndTheLastIsTheBiblesLastVerse() async throws {
        let (map, _) = try await kjvMap()

        guard case .chapter(let bookName, let chapterNumber) = map.page(at: 0) else {
            Issue.record("The first page should be a title page.")
            return
        }
        #expect(bookName == "Genesis")
        #expect(chapterNumber == 1)

        guard case .verse(let verse) = map.page(at: 1) else {
            Issue.record("Genesis 1:1 should follow its title page.")
            return
        }
        #expect(verse.location == FocusVerseLocation(bookName: "Genesis", chapterNumber: 1, verseNumber: 1))

        guard case .verse(let last) = map.page(at: map.pageCount - 1) else {
            Issue.record("The last page should be a verse.")
            return
        }
        #expect(last.location == FocusVerseLocation(bookName: "Revelation", chapterNumber: 22, verseNumber: 21))
    }

    @Test func pagesOutsideTheBibleDoNotExist() async throws {
        let (map, _) = try await kjvMap()
        #expect(map.page(at: -1) == nil)
        #expect(map.page(at: map.pageCount) == nil)
    }

    @Test(arguments: [
        FocusVerseLocation(bookName: "Genesis", chapterNumber: 1, verseNumber: 1),
        FocusVerseLocation(bookName: "Psalms", chapterNumber: 119, verseNumber: 176),
        FocusVerseLocation(bookName: "Esther", chapterNumber: 8, verseNumber: 9),
        FocusVerseLocation(bookName: "John", chapterNumber: 3, verseNumber: 16),
        FocusVerseLocation(bookName: "Revelation", chapterNumber: 22, verseNumber: 21),
    ])
    func aVersesPageShowsThatVerse(_ location: FocusVerseLocation) async throws {
        let (map, _) = try await kjvMap()
        let index = try #require(map.index(of: location))
        guard case .verse(let verse) = map.page(at: index) else {
            Issue.record("\(location.reference) should be a verse page.")
            return
        }
        #expect(verse.location == location)
        #expect(!verse.text.isEmpty)
    }

    @Test func aChaptersTitlePageComesJustBeforeItsFirstVerse() async throws {
        let (map, _) = try await kjvMap()
        let verseIndex = try #require(map.index(of: FocusVerseLocation(bookName: "Romans", chapterNumber: 8, verseNumber: 1)))
        guard case .chapter(let bookName, let chapterNumber) = map.page(at: verseIndex - 1) else {
            Issue.record("Romans 8's title page should come just before 8:1.")
            return
        }
        #expect(bookName == "Romans")
        #expect(chapterNumber == 8)
    }

    /// Choosing just a book in Go to Verse asks for verse 0, which opens the chapter's title page.
    @Test func aVerseThatDoesNotExistOpensItsChaptersTitlePage() async throws {
        let (map, _) = try await kjvMap()
        for verseNumber in [0, 999] {
            let index = try #require(map.index(of: FocusVerseLocation(bookName: "Ruth", chapterNumber: 1, verseNumber: verseNumber)))
            guard case .chapter(let bookName, let chapterNumber) = map.page(at: index) else {
                Issue.record("Ruth 1:\(verseNumber) should fall back to Ruth 1's title page.")
                return
            }
            #expect(bookName == "Ruth")
            #expect(chapterNumber == 1)
        }
    }

    @Test func aChapterThatDoesNotExistHasNoPage() async throws {
        let (map, _) = try await kjvMap()
        #expect(map.index(of: FocusVerseLocation(bookName: "Jude", chapterNumber: 2, verseNumber: 1)) == nil)
        #expect(map.index(of: FocusVerseLocation(bookName: "Hezekiah", chapterNumber: 1, verseNumber: 1)) == nil)
    }

    @Test func everyPageLeadsBackToItself() async throws {
        let (map, _) = try await kjvMap()
        // Every 97th page samples all of the Bible quickly; a title page reports verse 1's
        // location, so only verse pages map back to their own index.
        for index in stride(from: 0, to: map.pageCount, by: 97) {
            guard case .verse(let verse) = map.page(at: index) else { continue }
            #expect(map.index(of: verse.location) == index, "Page \(index) is \(verse.location.reference)")
        }
    }
}
