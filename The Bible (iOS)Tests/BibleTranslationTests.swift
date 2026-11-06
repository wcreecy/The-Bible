import CryptoKit
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

    /// Every translation except the KJV (which has `KJVTextBundleTests`) is built from a raw
    /// source in TranslationSources by Scripts/build_translation.py, which records the SHA-256
    /// of the source and of its output in manifest.json. This fails when either has changed
    /// since the last build: a source edited without a rebuild, or the bundled text edited by hand.
    @Test(arguments: BibleTranslation.allCases.filter { $0 != .kjv })
    func bundledTextMatchesItsBuiltSource(_ translation: BibleTranslation) throws {
        // The sources are copied into the test bundle only, never the app.
        let testBundle = Bundle(for: TranslationSourcesToken.self)
        let manifestURL = try #require(testBundle.url(forResource: "manifest", withExtension: "json"))
        let sourceURL = try #require(
            testBundle.url(forResource: translation.rawValue, withExtension: "json"),
            "The raw \(translation.abbreviation) source should be in the test bundle."
        )
        let bundledURL = try #require(Bundle.main.url(forResource: translation.resourceName, withExtension: "json"))

        let manifest = try JSONDecoder().decode(
            [String: [String: String]].self,
            from: Data(contentsOf: manifestURL)
        )
        let entry = try #require(
            manifest[translation.rawValue],
            "Run Scripts/build_translation.py \(translation.rawValue) to record it in manifest.json."
        )

        #expect(
            Self.sha256(of: try Data(contentsOf: sourceURL)) == entry["source"],
            "\(translation.abbreviation) source changed. Re-run Scripts/build_translation.py \(translation.rawValue)."
        )
        #expect(
            Self.sha256(of: try Data(contentsOf: bundledURL)) == entry["output"],
            "\(translation.resourceName).json doesn't match the last build. Re-run Scripts/build_translation.py \(translation.rawValue); don't edit it by hand."
        )
    }

    private static func sha256(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// The search index is built from one translation's wording, so it must follow the
    /// translation. ASV renders the divine name "Jehovah" throughout; the KJV almost never does.
    @Test
    func searchFindsEachTranslationsOwnWording() async {
        let tokens = BibleSearchTokenizer.tokens(in: "Jehovah")
        let asv = await BibleSearchIndex.shared.search(
            tokens: tokens, allowedBookIndices: nil, maxResults: 200, translation: .asv
        )
        let kjv = await BibleSearchIndex.shared.search(
            tokens: tokens, allowedBookIndices: nil, maxResults: 200, translation: .kjv
        )
        #expect(asv.count == 200)
        #expect(kjv.count < 20)
        // Switching back must not return a stale index.
        let asvAgain = await BibleSearchIndex.shared.search(
            tokens: tokens, allowedBookIndices: nil, maxResults: 200, translation: .asv
        )
        #expect(asvAgain.count == 200)
    }

    /// Beat the Clock's place catalog uses the KJV's spellings, and other translations hyphenate
    /// names the KJV doesn't ("Beer-sheba"). That is why the game matches places against the
    /// KJV text whichever translation is being read.
    @Test
    func placeNamesAreMatchedAgainstTheKJVSpellings() async {
        let places = [(id: 1, name: "Beersheba")]
        let kjv = await BibleRepository.shared.loadBooksWithoutCaching(for: .kjv)
        let asv = await BibleRepository.shared.loadBooksWithoutCaching(for: .asv)

        let kjvBooks = BeatTheClockAnswerIndex.booksMentioning(places, in: kjv)[1] ?? []
        let asvBooks = BeatTheClockAnswerIndex.booksMentioning(places, in: asv)[1] ?? []
        #expect(kjvBooks.contains("Genesis"))
        #expect(kjvBooks.count > asvBooks.count)
    }

    @Test
    func loadingWithoutCachingReturnsTheSameBible() async throws {
        let loaded = await BibleRepository.shared.loadBooksWithoutCaching(for: .asv)
        let cached = await BibleRepository.shared.loadAllBooks(for: .asv)
        #expect(loaded.count == 66)
        #expect(loaded == cached)
    }

    @Test
    func aLeftOutVerseAskedForByNameIsAnswered() async throws {
        let books = await BibleRepository.shared.loadAllBooks(for: .asv)

        let verse = try #require(BibleReferenceParser.results(for: "Acts 8:37", in: books))
        #expect(verse.count == 1)
        #expect(verse.first?.isOmitted == true)

        // A whole chapter lists only the verses the translation has.
        let chapter = try #require(BibleReferenceParser.results(for: "Acts 8", in: books))
        #expect(!chapter.isEmpty)
        #expect(chapter.allSatisfy { !$0.isOmitted })
        #expect(chapter.count == (books.first { $0.name == "Acts" }?.chapters.first { $0.number == 8 }?.verses.count ?? 0) - 1)
    }

    @Test
    func webLeavesOutFourVersesAndKeepsTheRest() async throws {
        let books = await BibleRepository.shared.loadAllBooks(for: .web)
        func verse(_ book: String, _ chapter: Int, _ number: Int) throws -> Verse {
            let found = books.first { $0.name == book }?
                .chapters.first { $0.number == chapter }?
                .verses.first { $0.number == number }
            return try #require(found)
        }
        for (book, chapter, number) in [("Luke", 17, 36), ("Acts", 8, 37), ("Acts", 15, 34), ("Acts", 24, 7)] {
            #expect(try verse(book, chapter, number).isOmitted, "\(book) \(chapter):\(number) should be left out")
        }
        // The WEB's Byzantine basis keeps verses the ASV leaves out.
        #expect(try !verse("Matthew", 17, 21).isOmitted)
        #expect(books.flatMap(\.chapters).flatMap(\.verses).filter(\.isOmitted).count == 4)
    }

    /// The WEB prints the widows' houses verse first; the build puts it back in the KJV's order,
    /// so a verse number means the same thing in every translation.
    @Test
    func webMatthew23FollowsTheKJVOrder() async throws {
        let books = await BibleRepository.shared.loadAllBooks(for: .web)
        let chapter = try #require(books.first { $0.name == "Matthew" }?.chapters.first { $0.number == 23 })
        let thirteen = try #require(chapter.verses.first { $0.number == 13 }).text
        let fourteen = try #require(chapter.verses.first { $0.number == 14 }).text
        #expect(thirteen.contains("shut up"))
        #expect(fourteen.contains("widows"))
    }

    @Test
    func theLeftOutNoteGivesEachTranslationsOwnReason() {
        let asv = Verse.omittedNote(in: .asv)
        let web = Verse.omittedNote(in: .web)
        #expect(asv.contains("oldest manuscripts"))
        #expect(web.contains("most Greek manuscripts"))
        #expect(asv != web)
    }

    /// The WEB uses contractions freely; splitting "doesn’t" at the apostrophe must not leave
    /// "DOESN" as a puzzle answer.
    @Test
    func wordSearchIgnoresContractionFragments() {
        let engine = WordSearchEngine(size: 14, difficulty: .hard)
        let words = engine.extractKeywords(
            from: "He doesn’t know why it isn’t true, and they wouldn’t believe righteousness",
            minLen: 4,
            countRange: 1...10
        )
        #expect(words.contains("RIGHTEOUSNESS"))
        #expect(!words.contains("DOESN"))
        #expect(!words.contains("ISN"))
        #expect(!words.contains("WOULDN"))
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

/// Locates this test bundle.
private final class TranslationSourcesToken {}
