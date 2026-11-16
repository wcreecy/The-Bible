import Foundation
import Testing
@testable import Bible

@MainActor
struct BibleLaunchPositionTests {
    private static func book(_ name: String, chapters: Int, verses: Int) -> Book {
        Book(name: name, chapters: (1...chapters).map { number in
            Chapter(number: number, verses: (1...verses).map {
                Verse(number: $0, text: "Verse \($0)", redLetterRanges: [], suppliedWordRanges: [])
            })
        })
    }

    private let books = [book("Genesis", chapters: 3, verses: 5), book("John", chapters: 4, verses: 10)]

    @Test
    func opensTheSavedPlace() throws {
        let saved = (bookName: "John", chapterNumber: 3, verseNumber: 7)
        let start = try #require(BibleLaunchPosition.resolve(in: books, saved: saved))
        #expect(start.book.name == "John")
        #expect(start.chapter.number == 3)
        #expect(start.verse == 7)
    }

    @Test
    func aSavedPlaceNotInTheBibleOpensGenesisOne() throws {
        let saved = (bookName: "John", chapterNumber: 3, verseNumber: 99)
        let start = try #require(BibleLaunchPosition.resolve(in: books, saved: saved))
        #expect(start.book.name == "Genesis")
        #expect(start.chapter.number == 1)
        #expect(start.verse == 1)
    }

    @Test
    func nothingSavedOpensGenesisOne() throws {
        let start = try #require(BibleLaunchPosition.resolve(in: books, saved: nil))
        #expect(start.location.bookName == "Genesis")
        #expect(start.location.chapterNumber == 1)
        #expect(start.location.verseNumber == 1)
    }

    @Test
    func anEmptyBibleHasNoPosition() {
        #expect(BibleLaunchPosition.resolve(in: [], saved: nil) == nil)
    }
}

@MainActor
struct StudyHomeCardTargetTests {
    private let bookmark = HomeVerseRef(bookName: "Romans", chapterNumber: 8, verseNumber: 28, verseText: "And we know…")
    private let verseOfDay = HomeVerseRef(bookName: "Psalms", chapterNumber: 23, verseNumber: 1, verseText: "The LORD is my shepherd")

    @Test
    func theBookmarkComesFirst() {
        let target = StudyHomeCard.Target(bookmark: bookmark, verseOfDay: verseOfDay, verseOfDayTitle: "Verse of the Day")
        #expect(target.bookName == "Romans")
        #expect(target.verseNumber == 28)
        #expect(target.source == .bookmark)
    }

    @Test
    func withoutABookmarkTheVerseOfDayIsUsed() {
        let target = StudyHomeCard.Target(bookmark: nil, verseOfDay: verseOfDay, verseOfDayTitle: "Word of the Night")
        #expect(target.bookName == "Psalms")
        #expect(target.source == .verseOfDay(title: "Word of the Night"))
    }

    @Test
    func withNeitherItStartsAtGenesisOne() {
        let target = StudyHomeCard.Target(bookmark: nil, verseOfDay: nil, verseOfDayTitle: "Verse of the Day")
        #expect(target.bookName == "Genesis")
        #expect(target.chapterNumber == 1)
        #expect(target.verseText == nil)
        #expect(target.source == .startingPoint)
    }
}
