import Foundation
import Testing
@testable import Bible

struct ChapterCrossReferenceEditorialCatalogTests {
    /// Update this when entries are intentionally added or removed.
    private static let expectedEntryCount = 3378

    @Test
    func catalogLoadsEveryEntry() {
        #expect(ChapterCrossReferenceEditorialCatalog.entries.count == Self.expectedEntryCount)
    }

    @Test
    func catalogHasNoDuplicatePairs() {
        struct Key: Hashable {
            let book: String
            let chapter: Int
            let verse: Int
            let targetBook: String
            let targetChapter: Int
            let targetVerse: Int
        }

        let keys = ChapterCrossReferenceEditorialCatalog.entries.map {
            Key(
                book: $0.bookName,
                chapter: $0.chapterNumber,
                verse: $0.sourceVerse,
                targetBook: $0.targetBookName,
                targetChapter: $0.targetChapterNumber,
                targetVerse: $0.targetVerse
            )
        }

        #expect(Set(keys).count == keys.count)
    }

    @Test
    func everyEntryHasADescription() {
        let blank = ChapterCrossReferenceEditorialCatalog.entries.filter {
            $0.relationshipDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        #expect(blank.isEmpty)
    }

    @Test
    func lookupFindsTheFirstGenesisEntryInEitherDirection() {
        let forward = ChapterCrossReferenceEditorialCatalog.relationshipDescription(
            bookName: "Genesis", chapterNumber: 1, sourceVerse: 27,
            targetBookName: "Mark", targetChapterNumber: 10, targetVerse: 6
        )
        let reverse = ChapterCrossReferenceEditorialCatalog.relationshipDescription(
            bookName: "Mark", chapterNumber: 10, sourceVerse: 6,
            targetBookName: "Genesis", targetChapterNumber: 1, targetVerse: 27
        )

        #expect(forward != nil)
        #expect(forward == reverse)
    }
}
