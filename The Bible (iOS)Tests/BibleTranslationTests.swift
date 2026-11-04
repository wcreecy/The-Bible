import Foundation
import Testing
@testable import Bible

/// Saved verses, notes, highlights, and reading progress are keyed by book, chapter, and
/// verse, so every bundled translation must line up with the KJV verse for verse.
@MainActor
struct BibleTranslationTests {
    @Test
    func everyTranslationIsBundled() {
        #expect(BibleTranslation.available == BibleTranslation.allCases)
    }

    @Test(arguments: BibleTranslation.allCases)
    func translationLinesUpWithTheKJV(_ translation: BibleTranslation) async {
        let kjv = await BibleRepository.shared.loadAllBooks(for: .kjv)
        let books = await BibleRepository.shared.loadAllBooks(for: translation)

        #expect(books.map(\.name) == kjv.map(\.name))
        for (book, kjvBook) in zip(books, kjv) {
            #expect(
                book.chapters.map(\.verses.count) == kjvBook.chapters.map(\.verses.count),
                "\(translation.abbreviation) \(book.name) has different verse counts from the KJV."
            )
        }
        // A few verses may be left out (kept empty), never whole passages.
        let omitted = books.flatMap(\.chapters).flatMap(\.verses).filter(\.isOmitted)
        #expect(omitted.count < 40)
    }

    @Test
    func asvLeavesOutVersesTheOldestManuscriptsLack() async throws {
        let books = await BibleRepository.shared.loadAllBooks(for: .asv)
        let matthew = try #require(books.first { $0.name == "Matthew" })
        let chapter = try #require(matthew.chapters.first { $0.number == 17 })
        #expect(chapter.verses.first { $0.number == 21 }?.isOmitted == true)
        #expect(chapter.verses.first { $0.number == 22 }?.isOmitted == false)
    }

    @Test
    func asvTextHasNoSourceMarkup() async {
        let books = await BibleRepository.shared.loadAllBooks(for: .asv)
        let marked = books.flatMap(\.chapters).flatMap(\.verses).filter {
            $0.text.contains("[Selah") || $0.text.contains("\\+w") || $0.text.contains("strong=")
        }
        #expect(marked.isEmpty)
    }

    @Test
    func newSavedVersesAreTaggedWithTheActiveTranslation() {
        let favorite = Favorite(bookName: "John", chapterNumber: 3, verseNumber: 16, verseText: "For God so loved the world")
        #expect(favorite.translation == BibleRepository.shared.activeTranslation.rawValue)
        #expect(Bookmark().translation == BibleRepository.shared.activeTranslation.rawValue)
        #expect(VerseNote().translation == BibleRepository.shared.activeTranslation.rawValue)
    }

    @Test
    func shareTextNamesTheTranslation() {
        let verse = VerseActionReference(
            bookName: "John",
            chapterNumber: 3,
            verseNumber: 16,
            verseText: "For God so loved the world",
            translation: .asv
        )
        #expect(verse.shareText == "For God so loved the world\nJohn 3:16 ASV")
    }

    @Test
    func unknownStoredTranslationsShowTheirRawValue() {
        #expect(BibleTranslation.abbreviation(for: "kjv") == "KJV")
        #expect(BibleTranslation.abbreviation(for: "web") == "WEB")
    }
}
