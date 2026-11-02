import Foundation
import Testing
@testable import Bible

@MainActor
struct BibleDataHashingTests {
    private func makeBook(_ name: String, verseText: String = "In the beginning") -> Book {
        Book(name: name, chapters: [
            Chapter(number: 1, verses: [Verse(number: 1, text: verseText)]),
            Chapter(number: 2, verses: [Verse(number: 1, text: "Thus the heavens")])
        ])
    }

    @Test
    func equalBooksAndRoutesHashEqually() {
        let book = makeBook("Genesis")
        let copy = makeBook("Genesis")
        #expect(book == copy)
        #expect(book.hashValue == copy.hashValue)
        #expect(book.chapters[0].hashValue == copy.chapters[0].hashValue)

        let route = Route.reader(book: book, chapter: book.chapters[0], startVerse: 1)
        let sameRoute = Route.reader(book: copy, chapter: copy.chapters[0], startVerse: 1)
        #expect(Set([route, sameRoute]).count == 1)
    }

    @Test
    func differentContentStillComparesUnequal() {
        // Hashing only identifying fields must not make distinct values equal.
        #expect(makeBook("Genesis") != makeBook("Exodus"))
        #expect(makeBook("Genesis") != makeBook("Genesis", verseText: "Changed"))

        let book = makeBook("Genesis")
        let routes: Set<Route> = [
            .reader(book: book, chapter: book.chapters[0], startVerse: 1),
            .reader(book: book, chapter: book.chapters[1], startVerse: 1),
            .reader(book: book, chapter: book.chapters[0], startVerse: 5)
        ]
        #expect(routes.count == 3)
    }
}
