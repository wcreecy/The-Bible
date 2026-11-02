import Testing
@testable import The_Bible

struct VerseOfDaySelectorTests {
    @Test func excludesCuratedGenealogyAndMeasurementPassages() {
        #expect(weight(book: "Genesis", chapter: 5, verse: 1, text: "This is the book of the generations of Adam.") == 0)
        #expect(weight(book: "Exodus", chapter: 26, verse: 2, text: "The length of one curtain shall be eight and twenty cubits.") == 0)
        #expect(weight(book: "Matthew", chapter: 1, verse: 2, text: "Abraham begat Isaac; and Isaac begat Jacob.") == 0)
    }

    @Test func rejectsListsMeasurementsAndIncompleteFragments() {
        #expect(weight(book: "Ruth", chapter: 1, verse: 1, text: "And the sons of Eliab were Nemuel, and Dathan, and Abiram.") == 0)
        #expect(weight(book: "Ruth", chapter: 1, verse: 2, text: "The board was ten cubits, with two sockets and loops.") == 0)
        #expect(weight(book: "Ruth", chapter: 1, verse: 3, text: "And he said unto them:") == 0)
    }

    @Test func downweightsContextDependentLines() {
        let contextual = weight(
            book: "Mark",
            chapter: 4,
            verse: 9,
            text: "And he said unto them, He that hath ears to hear, let him hear."
        )
        let standalone = weight(
            book: "Psalms",
            chapter: 46,
            verse: 1,
            text: "God is our refuge and strength, a very present help in trouble."
        )

        #expect(contextual > 0)
        #expect(contextual < standalone)
    }

    @Test func selectionHonorsSpecificBookAndNeverReturnsExcludedVerse() {
        let books = [
            Book(name: "Genesis", chapters: [
                Chapter(number: 5, verses: [Verse(number: 1, text: "This is the book of the generations of Adam.")]),
                Chapter(number: 6, verses: [Verse(number: 8, text: "But Noah found grace in the eyes of the LORD.")])
            ]),
            Book(name: "John", chapters: [
                Chapter(number: 3, verses: [Verse(number: 16, text: "For God so loved the world, that he gave his only begotten Son.")])
            ])
        ]

        let selection = VerseOfDaySelector.select(from: books, scopeRaw: "book", specificBook: "Genesis")

        #expect(selection?.bookName == "Genesis")
        #expect(selection?.chapterNumber == 6)
        #expect(selection?.verseNumber == 8)
    }

    private func weight(book: String, chapter: Int, verse: Int, text: String) -> Int {
        VerseOfDaySelector.suitabilityWeight(
            bookName: book,
            chapter: chapter,
            verse: verse,
            text: text
        )
    }
}
