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

    // MARK: Grammar

    @Test
    func wordsHaveAReadableGrammarLine() async {
        let hebrew = await OriginalWordsRepository.shared.words(
            bookName: "Genesis", chapter: 1, verse: 1, translation: .kjv
        )
        #expect(hebrew[0].parse == "Noun · Common · Feminine Singular Absolute")
        #expect(hebrew[1].parse == "Verb · Qal Perfect · Third Masculine Singular")

        let greek = await OriginalWordsRepository.shared.words(
            bookName: "John", chapter: 1, verse: 1, translation: .kjv
        )
        #expect(greek[2].parse == "Verb · Imperfect Active Indicative · 3rd Singular")
        #expect(greek[4].parse == "Noun · Nominative Singular Masculine")
    }

    /// κἀγώ is "and I" written as one word, so it has both grammar lines.
    @Test
    func aWordWrittenAsTwoGetsBothGrammarLines() async throws {
        let words = await OriginalWordsRepository.shared.words(
            bookName: "John", chapter: 1, verse: 31, translation: .kjv
        )
        let first = try #require(words.first)
        #expect(first.parse == "Personal pronoun · Nominative 1st Singular + Conjunction")
    }

    // MARK: Names

    @Test
    func aNameIsLookedUpByItsVerse() async throws {
        let names = await OriginalWordsRepository.shared.names(
            forStrongs: "H0175", in: VerseLocation(bookName: "Exodus", chapter: 4, verse: 14)
        )
        let aaron = try #require(names.first)
        #expect(names.count == 1)
        #expect(aaron.name == "Aaron")
        #expect(aaron.kind == .male)
        #expect(aaron.description.contains("High Priest"))
        #expect(aaron.parents == "Amram and Jochebed")
        #expect(aaron.siblings == "Moses, Miriam")
        #expect(aaron.partners == "Elisheba")
        #expect(aaron.offspring.contains("Eleazar"))
        #expect(aaron.area == "Tribe of Levi")
    }

    @Test
    func aPlaceIsMarkedAsOneWithItsRegion() async throws {
        let names = await OriginalWordsRepository.shared.names(
            forStrongs: "G0965", in: VerseLocation(bookName: "Matthew", chapter: 2, verse: 1)
        )
        let bethlehem = try #require(names.first)
        #expect(names.count == 1)
        #expect(bethlehem.name == "Bethlehem")
        #expect(bethlehem.kind == .place)
        #expect(bethlehem.area == "Tribe of Judah")
    }

    /// Several men are called Zechariah, but in Luke 1:5 the verse says which.
    @Test
    func theVerseSaysWhichPersonSharesAName() async throws {
        let names = await OriginalWordsRepository.shared.names(
            forStrongs: "G2197H", in: VerseLocation(bookName: "Luke", chapter: 1, verse: 5)
        )
        let zechariah = try #require(names.first)
        #expect(names.count == 1)
        #expect(zechariah.description.contains("New Testament"))
    }

    /// The people descended from Judah are "the Jews", not Judah: the source files them under his
    /// record, but they get a card of their own.
    @Test
    func aGroupOfPeopleIsNotTheirAncestor() async throws {
        let jews = await OriginalWordsRepository.shared.names(
            forStrongs: "G2453G", in: VerseLocation(bookName: "Mark", chapter: 15, verse: 12)
        )
        let group = try #require(jews.first)
        #expect(jews.count == 1)
        #expect(group.name == "Jews")
        #expect(group.kind == .group)
        #expect(group.description == "People descended from Judah")

        let judah = await OriginalWordsRepository.shared.names(
            forStrongs: "H3063G", in: VerseLocation(bookName: "Genesis", chapter: 29, verse: 35)
        )
        #expect(judah.first?.name == "Judah")
        #expect(judah.first?.kind == .male)
    }

    /// "Heart" (H3820) shares its number with a rare name, so a name must never be found by
    /// number alone: only in a verse the names data lists it for.
    @Test
    func aWordThatIsNotANameInThatVerseHasNoName() async {
        let heart = await OriginalWordsRepository.shared.names(
            forStrongs: "H3820A", in: VerseLocation(bookName: "Exodus", chapter: 4, verse: 14)
        )
        #expect(heart.isEmpty)

        let elsewhere = await OriginalWordsRepository.shared.names(
            forStrongs: "H0175", in: VerseLocation(bookName: "Genesis", chapter: 1, verse: 1)
        )
        #expect(elsewhere.isEmpty)

        let logos = await OriginalWordsRepository.shared.names(
            forStrongs: "G3056", in: VerseLocation(bookName: "John", chapter: 1, verse: 1)
        )
        #expect(logos.isEmpty)
    }

    // MARK: Meanings

    private func word(gloss: String, dictionary: String?) -> OriginalWord {
        OriginalWord(
            id: 1, original: "", transliteration: "", gloss: gloss, strongsNumber: "G1702",
            entry: dictionary.map {
                OriginalWordEntry(lemma: "", transliteration: "", gloss: $0, definition: "")
            },
            source: "NK",
            parse: nil
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
            id: 1, original: "", transliteration: "", gloss: "", strongsNumber: "G0011", entry: nil, source: "NK", parse: nil
        )
        #expect(word.displayStrongsNumber == "G11")
        let lettered = OriginalWord(
            id: 1, original: "", transliteration: "", gloss: "", strongsNumber: "H0430G", entry: nil, source: "L", parse: nil
        )
        #expect(lettered.displayStrongsNumber == "H430")
    }
}
