import Foundation
import Testing
@testable import Bible

/// Searching the Bible by the Hebrew or Greek word behind a verse, from the ordinary search field.
@MainActor
struct StrongsSearchTests {
    private func search(
        _ text: String,
        transliteration: Bool = false,
        translation: BibleTranslation = .kjv,
        scope: Range<Int>? = nil,
        maxResults: Int = 200
    ) async -> StrongsSearch.Outcome? {
        let books = await BibleRepository.shared.loadAllBooks(for: .kjv)
        return await StrongsSearch.search(
            text,
            allowingTransliteration: transliteration,
            translation: translation,
            books: books,
            allowedBookIndices: scope,
            maxResults: maxResults
        )
    }

    // MARK: Reading what was typed

    @Test(arguments: [
        ("G3056", "G3056"), ("g3056", "G3056"), ("G 3056", "G3056"), ("G03056", "G3056"),
        ("H430", "H0430"), ("h0430", "H0430"), ("Strong's G26", "G0026"), ("strongs h1", "H0001"),
    ])
    func numbersAreRecognizedInTheWaysPeopleWriteThem(typed: String, prefix: String) {
        #expect(StrongsSearch.parse(typed, allowingTransliteration: false) == .number(prefix: prefix))
    }

    @Test(arguments: ["G0", "G12345", "G", "H", "John 3:16", "Genesis 1", "Hebrews 11", "3056"])
    func otherTextIsNotANumber(typed: String) {
        let query = StrongsSearch.parse(typed, allowingTransliteration: false)
        if case .number = query {
            Issue.record("\(typed) was read as a Strong's number")
        }
    }

    @Test
    func englishWordsAreLeftToTheEnglishSearch() {
        #expect(StrongsSearch.parse("love", allowingTransliteration: false) == nil)
        #expect(StrongsSearch.parse("peace", allowingTransliteration: false) == nil)
    }

    @Test
    func aTransliterationIsOneWordOfThreeLettersOrMore() {
        #expect(StrongsSearch.parse("agape", allowingTransliteration: true) == .word(key: "agape"))
        #expect(StrongsSearch.parse("in the beginning", allowingTransliteration: true) == nil)
        #expect(StrongsSearch.parse("ab", allowingTransliteration: true) == nil)
    }

    @Test
    func greekAndHebrewLettersAreASearchWithoutAskingForOne() {
        #expect(StrongsSearch.parse("ἀγάπη", allowingTransliteration: false) == .word(key: "αγαπη"))
        #expect(StrongsSearch.parse("אֱלֹהִים", allowingTransliteration: false) == .word(key: "אלהים"))
    }

    /// The database's keys are built by Scripts/build_original_words.py, and typing is matched
    /// against them, so both must reduce a word the same way.
    @Test
    func theSameWordInEverySpellingHasOneKey() {
        #expect(StrongsSearch.key(for: "ἀγάπη") == "αγαπη")
        #expect(StrongsSearch.key(for: "agapē") == "agape")
        #expect(StrongsSearch.key(for: "AGAPE") == "agape")
        #expect(StrongsSearch.key(for: "Λόγος") == "λογοσ")
        #expect(StrongsSearch.key(for: "e.lo.him") == "elohim")
    }

    @Test
    func typedKeysFindTheEntriesTheBuilderKeyed() async {
        for typed in ["ἀγάπη", "agapē", "agape", "ΑΓΑΠΗ"] {
            let entries = await OriginalWordsRepository.shared.strongsEntries(forKey: StrongsSearch.key(for: typed))
            #expect(entries.map(\.strongs) == ["G0026"], "\(typed) should find G26")
        }
        let hebrew = await OriginalWordsRepository.shared.strongsEntries(forKey: StrongsSearch.key(for: "אֱלֹהִים"))
        #expect(hebrew.map(\.strongs).contains("H0430G"))
    }

    // MARK: Searching

    @Test
    func aNumberFindsItsEntryAndItsVersesInBibleOrder() async throws {
        let outcome = try #require(await search("G3056"))
        let entry = try #require(outcome.match.entries.first)
        #expect(outcome.match.entries.count == 1)
        #expect(entry.lemma == "λόγος")
        #expect(entry.displayNumber == "G3056")

        let all = await OriginalWordsRepository.shared.verses(using: "G3056", translation: .kjv)
        #expect(outcome.match.verseCount == all.count)
        #expect(outcome.results.count == 200)
        #expect(outcome.hasMore)

        let first = try #require(outcome.results.first)
        #expect(first.bookName == "Matthew" && first.chapterNumber == 5 && first.verseNumber == 32)
        #expect(!first.verseText.isEmpty)
        let order = outcome.results.map(\.bookIndex)
        #expect(order == order.sorted())
    }

    @Test
    func aHebrewNumberFindsEverySenseOfIt() async throws {
        let outcome = try #require(await search("H430"))
        let numbers = outcome.match.entries.map(\.strongs)
        #expect(numbers.contains("H0430G"))
        #expect(numbers.allSatisfy { $0.hasPrefix("H0430") })
        let first = try #require(outcome.results.first)
        #expect(first.bookName == "Genesis" && first.chapterNumber == 1 && first.verseNumber == 1)
    }

    @Test
    func aWordInItsOwnLettersFindsTheSameVerses() async throws {
        let byNumber = try #require(await search("G26", maxResults: 1000))
        let byLetters = try #require(await search("ἀγάπη", maxResults: 1000))
        #expect(byLetters.match.entries.map(\.strongs) == ["G0026"])
        #expect(byLetters.results.map(\.id) == byNumber.results.map(\.id))
        #expect(byLetters.results.contains { $0.bookName == "1 Corinthians" && $0.chapterNumber == 13 && $0.verseNumber == 1 })
    }

    @Test
    func aTransliterationIsOnlyASearchWhenAllowed() async throws {
        #expect(await search("agape", transliteration: false) == nil)
        let outcome = try #require(await search("agape", transliteration: true))
        #expect(outcome.match.entries.map(\.strongs) == ["G0026"])
        #expect(!outcome.results.isEmpty)
    }

    @Test
    func theSearchScopeNarrowsTheVerses() async throws {
        let books = await BibleRepository.shared.loadAllBooks(for: .kjv)
        let matthew = try #require(books.firstIndex { $0.name == "Matthew" })

        // λόγος is Greek, so it isn't in the Old Testament, but is in the New.
        #expect(await search("G3056", scope: 0..<matthew) == nil)
        let newTestament = try #require(await search("G3056", scope: matthew..<books.count))
        #expect(newTestament.results.allSatisfy { $0.bookIndex >= matthew })

        // The scope also limits the count shown in the header.
        let everywhere = try #require(await search("G3056"))
        #expect(newTestament.match.verseCount == everywhere.match.verseCount)
    }

    @Test
    func aGreekWordFollowsTheTranslationsGreekText() async throws {
        let kjv = try #require(await search("G3962", translation: .kjv))
        let asv = try #require(await search("G3962", translation: .asv))
        #expect(kjv.match.verseCount > asv.match.verseCount)
    }

    @Test
    func nothingIsFoundForAnUnusedNumberOrUnknownWord() async {
        #expect(await search("G9999") == nil)
        #expect(await search("zzzzzz", transliteration: true) == nil)
        #expect(await search("love", transliteration: true) == nil)
    }
}
