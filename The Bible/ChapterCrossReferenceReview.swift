import Foundation

/// Cross references excluded from Chapter Insights pending future editorial review.
/// Keep each entry here instead of deleting it from the source database so its
/// original reference and reason for removal remain available to editors.
enum ChapterCrossReferenceReview {
    struct Entry: Hashable, Sendable {
        let bookName: String
        let chapterNumber: Int
        let sourceVerse: Int
        let relatedReference: String
        let reason: String
    }

    nonisolated static let excludedEntries: [Entry] = [
        Entry(
            bookName: "Genesis",
            chapterNumber: 6,
            sourceVerse: 15,
            relatedReference: "Deuteronomy 3:11",
            reason: "Both passages give measurements, but the ark and Og's bed have no substantive connection."
        ),
        Entry(
            bookName: "Genesis",
            chapterNumber: 14,
            sourceVerse: 14,
            relatedReference: "Genesis 15:3",
            reason: "Abram's pursuit to Dan is unrelated to his concern about an heir born in his household."
        ),
        Entry(
            bookName: "Genesis",
            chapterNumber: 19,
            sourceVerse: 3,
            relatedReference: "1 Samuel 28:24",
            reason: "The passages share meal-preparation wording but describe unrelated events."
        ),
        Entry(
            bookName: "Genesis",
            chapterNumber: 24,
            sourceVerse: 49,
            relatedReference: "Joshua 2:14",
            reason: "The same covenantal phrase appears in distinct situations without a direct thematic connection."
        ),
        Entry(
            bookName: "Genesis",
            chapterNumber: 25,
            sourceVerse: 8,
            relatedReference: "1 Chronicles 29:28",
            reason: "This is a generic death formula rather than a meaningful connection between Abraham and David."
        ),
        Entry(
            bookName: "Genesis",
            chapterNumber: 25,
            sourceVerse: 8,
            relatedReference: "Judges 8:32",
            reason: "This is a generic death formula rather than a meaningful connection between Abraham and Gideon."
        ),
        Entry(
            bookName: "Genesis",
            chapterNumber: 27,
            sourceVerse: 1,
            relatedReference: "1 Samuel 3:2",
            reason: "Both mention diminished eyesight, but Isaac and Eli's situations are otherwise unrelated."
        ),
        Entry(
            bookName: "Genesis",
            chapterNumber: 47,
            sourceVerse: 29,
            relatedReference: "Genesis 24:49",
            reason: "The passages reuse a formal phrase but concern unrelated requests."
        ),
        Entry(
            bookName: "Genesis",
            chapterNumber: 3,
            sourceVerse: 20,
            relatedReference: "Genesis 2:20",
            reason: "Both verses involve naming, but Adam naming the animals does not meaningfully explain his naming Eve."
        ),
        Entry(
            bookName: "Genesis",
            chapterNumber: 35,
            sourceVerse: 19,
            relatedReference: "Micah 5:2",
            reason: "Both passages mention Bethlehem, but Rachel's burial and Micah's messianic prophecy have no substantive contextual relationship beyond location."
        ),
        Entry(
            bookName: "Genesis",
            chapterNumber: 37,
            sourceVerse: 17,
            relatedReference: "2 Kings 6:13",
            reason: "Both passages mention Dothan, but Joseph's search for his brothers and Elisha's military encounter have no substantive connection beyond location."
        ),
        Entry(
            bookName: "Genesis",
            chapterNumber: 37,
            sourceVerse: 25,
            relatedReference: "Jeremiah 8:22",
            reason: "Both passages mention balm from Gilead, but the traders' cargo and Jeremiah's prophetic lament have no substantive contextual relationship."
        ),
        Entry(
            bookName: "Genesis",
            chapterNumber: 10,
            sourceVerse: 23,
            relatedReference: "Job 1:1",
            reason: "The link rests on the name Uz alone; the genealogy does not establish a substantive connection to Job's setting."
        ),
        Entry(
            bookName: "Genesis",
            chapterNumber: 49,
            sourceVerse: 14,
            relatedReference: "1 Chronicles 12:32",
            reason: "Both passages concern Issachar, but the later military description does not meaningfully develop Jacob's blessing."
        ),
        Entry(
            bookName: "Genesis",
            chapterNumber: 24,
            sourceVerse: 49,
            relatedReference: "Genesis 47:29",
            reason: "The passages reuse a formal phrase but concern unrelated requests."
        )
    ]

    nonisolated static func excludes(
        bookName: String,
        chapterNumber: Int,
        sourceVerse: Int,
        relatedReference: String
    ) -> Bool {
        excludedEntries.contains {
            $0.bookName == bookName &&
            $0.chapterNumber == chapterNumber &&
            $0.sourceVerse == sourceVerse &&
            $0.relatedReference == relatedReference
        }
    }
}
