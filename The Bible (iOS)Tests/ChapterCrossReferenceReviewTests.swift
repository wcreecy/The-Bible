import Foundation
import Testing
@testable import Bible

struct ChapterCrossReferenceReviewTests {
    /// Update this when entries are intentionally added or removed.
    private static let expectedEntryCount = 569

    @Test
    func excludedListLoadsEveryEntry() {
        #expect(ChapterCrossReferenceReview.excludedEntries.count == Self.expectedEntryCount)
    }

    @Test
    func excludedListHasNoDuplicateReferences() {
        let keys = ChapterCrossReferenceReview.excludedEntries.map {
            "\($0.bookName)|\($0.chapterNumber)|\($0.sourceVerse)|\($0.relatedReference)"
        }
        #expect(Set(keys).count == keys.count)
    }

    @Test
    func excludesMatchesAKnownEntry() {
        #expect(ChapterCrossReferenceReview.excludes(
            bookName: "Genesis", chapterNumber: 6, sourceVerse: 15, relatedReference: "Deuteronomy 3:11"
        ))
        #expect(!ChapterCrossReferenceReview.excludes(
            bookName: "Genesis", chapterNumber: 1, sourceVerse: 1, relatedReference: "John 1:1"
        ))
    }
}
