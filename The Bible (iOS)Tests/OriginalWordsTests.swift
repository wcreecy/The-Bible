import Foundation
import Testing
@testable import Bible

/// OriginalWords.sqlite is built by Scripts/build_original_words.py, which checks that every KJV
/// verse has words. These tests check the app reads it correctly.
@MainActor
struct OriginalWordsTests {
    @Test
    func bookListMatchesTheCanonInKJVOrder() async {
        #expect(OriginalWordsBooks.names.count == 66)
        #expect(Set(OriginalWordsBooks.names) == Canon.old.union(Canon.new))
        #expect(OriginalWordsBooks.names.prefix(39).allSatisfy(Canon.isOld))
        #expect(OriginalWordsBooks.names.suffix(27).allSatisfy { !Canon.isOld($0) })

        let kjv = await BibleRepository.shared.loadAllBooks(for: .kjv)
        #expect(kjv.map(\.name) == OriginalWordsBooks.names)
    }

    @Test
    func genesisOneOneHasSevenHebrewWords() async throws {
        let words = await OriginalWordsRepository.shared.words(
            bookName: "Genesis", chapter: 1, verse: 1, translation: .kjv
        )
        #expect(words.count == 7)
        let first = try #require(words.first)
        #expect(first.original == "בְּרֵאשִׁית")
        #expect(first.displayStrongsNumber == "H7225")
        #expect(first.entry?.definition.contains("beginning") == true)
    }

    @Test
    func everyVerseWordHasAStrongsNumberEntry() async {
        let words = await OriginalWordsRepository.shared.words(
            bookName: "John", chapter: 1, verse: 1, translation: .kjv
        )
        #expect(words.count == 17)
        #expect(words.allSatisfy { $0.entry != nil })
        #expect(words.map(\.id) == Array(1...17))
    }

    /// Words only the critical text has (or only the KJV's text has) follow the translation.
    @Test
    func greekWordsFollowTheTranslationsText() async {
        // 1 John 5:7 is the Johannine Comma: in the KJV's text, not in the critical text.
        let kjv = await OriginalWordsRepository.shared.words(
            bookName: "1 John", chapter: 5, verse: 7, translation: .kjv
        )
        let asv = await OriginalWordsRepository.shared.words(
            bookName: "1 John", chapter: 5, verse: 7, translation: .asv
        )
        #expect(kjv.count > asv.count)
        #expect(!asv.isEmpty)
    }

    @Test
    func psalmTitlesAreInVerseOne() async {
        let words = await OriginalWordsRepository.shared.words(
            bookName: "Psalms", chapter: 3, verse: 1, translation: .kjv
        )
        // A Psalm of David (the title), then "LORD, how are they increased…".
        #expect(words.first?.gloss == "a psalm")
        #expect(words.count > 10)
    }

    @Test
    func unknownBooksHaveNoWords() async {
        let words = await OriginalWordsRepository.shared.words(
            bookName: "Not a Book", chapter: 1, verse: 1, translation: .kjv
        )
        #expect(words.isEmpty)
    }

    @Test
    func strongsNumbersDropZerosAndLetters() {
        let word = OriginalWord(
            id: 1, original: "", transliteration: "", gloss: "", strongsNumber: "G0011", entry: nil
        )
        #expect(word.displayStrongsNumber == "G11")
        let lettered = OriginalWord(
            id: 1, original: "", transliteration: "", gloss: "", strongsNumber: "H0430G", entry: nil
        )
        #expect(lettered.displayStrongsNumber == "H430")
    }
}
