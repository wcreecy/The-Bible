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

    // MARK: Usage

    @Test
    func godIsUsedThousandsOfTimesStartingInGenesis() async throws {
        let usage = try #require(
            await OriginalWordsRepository.shared.usage(of: "H0430G", translation: .kjv)
        )
        #expect(usage.wordCount > 2500)
        #expect(usage.verseCount > 2000)
        #expect(usage.verseCount <= usage.wordCount)
        #expect(usage.first == VerseLocation(bookName: "Genesis", chapter: 1, verse: 1))
    }

    @Test
    func theVerseListMatchesTheCountAndFollowsBibleOrder() async throws {
        let usage = try #require(
            await OriginalWordsRepository.shared.usage(of: "G3056", translation: .kjv)
        )
        let verses = await OriginalWordsRepository.shared.verses(using: "G3056", translation: .kjv)

        #expect(verses.count == usage.verseCount)
        #expect(verses.first == usage.first)
        #expect(Set(verses).count == verses.count)

        let order = verses.compactMap { OriginalWordsBooks.index(of: $0.bookName) }
        #expect(order.count == verses.count)
        #expect(order == order.sorted())
        // Every New Testament use of a Greek word is in the New Testament.
        #expect(verses.allSatisfy { !Canon.isOld($0.bookName) })
    }

    /// 1 John 5:7 has Greek the critical text leaves out, so the KJV counts the word more often.
    @Test
    func greekUsageFollowsTheTranslationsText() async throws {
        let kjv = try #require(await OriginalWordsRepository.shared.usage(of: "G3962", translation: .kjv))
        let asv = try #require(await OriginalWordsRepository.shared.usage(of: "G3962", translation: .asv))
        #expect(kjv.wordCount > asv.wordCount)
    }

    @Test
    func aWordThatIsNeverUsedHasNoUsage() async {
        #expect(await OriginalWordsRepository.shared.usage(of: "G9999", translation: .kjv) == nil)
        #expect(await OriginalWordsRepository.shared.verses(using: "G9999", translation: .kjv).isEmpty)
    }

    // MARK: Text variants

    @Test
    func wordsOnlyInTheKJVsGreekTextAreMarked() async {
        let words = await OriginalWordsRepository.shared.words(
            bookName: "1 John", chapter: 5, verse: 7, translation: .kjv
        )
        #expect(words.contains { $0.textVariant == .traditionalGreekOnly })
        // The words every Greek text has aren't marked.
        #expect(words.first?.textVariant == nil)
    }

    @Test
    func hebrewQereAndRestoredWordsAreMarked() async {
        let qere = await OriginalWordsRepository.shared.words(
            bookName: "Genesis", chapter: 8, verse: 17, translation: .kjv
        )
        #expect(qere.contains { $0.textVariant == .qere })

        let restored = await OriginalWordsRepository.shared.words(
            bookName: "Joshua", chapter: 21, verse: 36, translation: .kjv
        )
        #expect(restored.contains { $0.textVariant == .restored })
    }

    // MARK: Meanings

    private func word(gloss: String, dictionary: String?) -> OriginalWord {
        OriginalWord(
            id: 1, original: "", transliteration: "", gloss: gloss, strongsNumber: "G1702",
            entry: dictionary.map {
                OriginalWordEntry(lemma: "", transliteration: "", gloss: $0, definition: "")
            },
            source: "NK"
        )
    }

    @Test
    func theDictionaryMeaningShowsWhenItAddsSomething() {
        let outwitted = word(gloss: "he had been outwitted", dictionary: "to mock")
        #expect(outwitted.contextGloss == "he had been outwitted")
        #expect(outwitted.dictionaryGloss == "to mock")

        #expect(word(gloss: "he created", dictionary: "to create").dictionaryGloss == "to create")
    }

    @Test
    func theDictionaryMeaningIsHiddenWhenItRepeatsTheGloss() {
        #expect(word(gloss: "the heavens", dictionary: "heaven").dictionaryGloss == nil)
        #expect(word(gloss: "(obj.)", dictionary: "[Obj.]").dictionaryGloss == nil)
        #expect(word(gloss: "God", dictionary: "God").dictionaryGloss == nil)
        #expect(word(gloss: "God", dictionary: nil).dictionaryGloss == nil)
        #expect(word(gloss: "God", dictionary: "").dictionaryGloss == nil)
    }

    @Test
    func aWordWithoutAGlossFallsBackToTheDictionaryMeaning() {
        let fallback = word(gloss: "", dictionary: "to mock")
        #expect(fallback.contextGloss == "to mock")
        // It is already shown as the meaning, so it isn't repeated.
        #expect(fallback.dictionaryGloss == nil)
    }

    @Test
    func strongsNumbersDropZerosAndLetters() {
        let word = OriginalWord(
            id: 1, original: "", transliteration: "", gloss: "", strongsNumber: "G0011", entry: nil, source: "NK"
        )
        #expect(word.displayStrongsNumber == "G11")
        let lettered = OriginalWord(
            id: 1, original: "", transliteration: "", gloss: "", strongsNumber: "H0430G", entry: nil, source: "L"
        )
        #expect(lettered.displayStrongsNumber == "H430")
    }
}
