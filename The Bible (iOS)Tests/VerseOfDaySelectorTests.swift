import Foundation
import Testing
@testable import Bible

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

    @Test func shortStandaloneVersesCountButFragmentsDoNot() {
        let standalone = weight(book: "1 Thessalonians", chapter: 5, verse: 17, text: "Pray without ceasing.")
        let fragment = weight(book: "Genesis", chapter: 9, verse: 29, text: "And he died.")
        let long = weight(
            book: "Psalms",
            chapter: 46,
            verse: 1,
            text: "God is our refuge and strength, a very present help in trouble."
        )

        #expect(standalone > 0)
        #expect(fragment == 0)
        // Length alone no longer buries a short verse.
        #expect(long <= standalone * 3)
    }

    @Test func poolOnlyReturnsEligibleVersesAndHonorsExclusions() {
        let pool = VerseOfDaySelector.makePool(from: sampleBooks, scopeRaw: "whole", specificBook: "")

        // Genesis 5:1 is excluded, so only two verses are eligible.
        #expect(pool.count == 2)
        for _ in 0..<50 {
            let pick = pool.pick(avoiding: { $0.bookName == "John" })
            #expect(pick?.bookName == "Genesis")
            #expect(pick?.verseNumber == 8)
        }
        #expect(pool.pick(avoiding: { _ in true }) == nil)
    }

    @Test func poolMatchesScopeAndKey() {
        let genesis = VerseOfDaySelector.makePool(from: sampleBooks, scopeRaw: "book", specificBook: "Genesis")
        #expect(genesis.count == 1)
        #expect(genesis.key == VerseOfDaySelector.poolKey(scopeRaw: "book", specificBook: "Genesis"))
        #expect(genesis.key != VerseOfDaySelector.poolKey(scopeRaw: "whole", specificBook: ""))
        // The book name only matters when the scope is a single book.
        #expect(
            VerseOfDaySelector.poolKey(scopeRaw: "old", specificBook: "John")
                == VerseOfDaySelector.poolKey(scopeRaw: "old", specificBook: "")
        )
    }

    @Test func selectionAvoidsExcludedVerses() {
        for _ in 0..<20 {
            let selection = VerseOfDaySelector.select(
                from: sampleBooks,
                scopeRaw: "whole",
                specificBook: "",
                avoiding: { $0.bookName == "Genesis" }
            )
            #expect(selection?.bookName == "John")
        }
    }

    @Test func historyKeepsNewestVersesWithoutDuplicates() throws {
        let suiteName = "VerseOfDaySelectorTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        func selection(_ verse: Int) -> VerseOfDaySelector.Selection {
            .init(bookName: "Psalms", chapterNumber: 1, verseNumber: verse, text: "text")
        }

        for verse in 1...(VerseOfDaySelector.History.capacity + 10) {
            VerseOfDaySelector.History.record(selection(verse), in: defaults)
        }
        // Showing an older verse again moves it to the newest end instead of duplicating it.
        VerseOfDaySelector.History.record(selection(20), in: defaults)

        let recent = VerseOfDaySelector.History.recent(in: defaults)
        #expect(recent.count == VerseOfDaySelector.History.capacity)
        #expect(recent.last == selection(20).historyKey)
        #expect(recent.filter { $0 == selection(20).historyKey }.count == 1)
        #expect(!recent.contains(selection(1).historyKey))
    }

    private var sampleBooks: [Book] {
        [
            Book(name: "Genesis", chapters: [
                Chapter(number: 5, verses: [Verse(number: 1, text: "This is the book of the generations of Adam.")]),
                Chapter(number: 6, verses: [Verse(number: 8, text: "But Noah found grace in the eyes of the LORD.")])
            ]),
            Book(name: "John", chapters: [
                Chapter(number: 3, verses: [Verse(number: 16, text: "For God so loved the world, that he gave his only begotten Son.")])
            ])
        ]
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
