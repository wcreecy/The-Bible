import Foundation
import Testing
@testable import Bible

/// How games read the scripture reference that comes with a person, place, or clue. Many carry
/// more than one passage ("Genesis 29:24; 30:9–13"), and a game still has a verse to show.
@MainActor
struct GamePassageTests {
    @Test
    func aReferenceWithSeveralPassagesUsesTheFirst() async throws {
        _ = await BibleRepository.shared.loadAllBooks()

        let several = try #require(PassageReferenceParser.firstPassage(in: "Genesis 29:24; 30:9–13"))
        #expect(several.bookName == "Genesis")
        #expect(several.startChapter == 29)
        #expect(several.startVerse == 24)

        let single = try #require(PassageReferenceParser.firstPassage(in: "Genesis 20:2–18"))
        #expect(single.startChapter == 20)
        #expect(single.endVerse == 18)

        // A reference that has no passage in it is still not one.
        #expect(PassageReferenceParser.firstPassage(in: "Narrative of the Exodus") == nil)
    }

    @Test
    func aPersonWithSeveralPassagesGetsAVerse() async throws {
        let passage = try #require(await GamePassage.load(for: "Genesis 29:24; 30:9–13"))
        #expect(passage.bookName == "Genesis")
        #expect(passage.chapter == 29)
        #expect(!passage.verses.isEmpty)
    }

    @Test
    func everyWhoQuestionHasAReferenceAGameCanOpen() async {
        _ = await BibleRepository.shared.loadAllBooks()
        let unreadable = GameDataLoaders.loadWhoQuestions()
            .map(\.reference)
            .filter { !$0.isEmpty && PassageReferenceParser.firstPassage(in: $0) == nil }
        #expect(unreadable.isEmpty, "References no game can read: \(Set(unreadable).sorted().prefix(10))")
    }
}
