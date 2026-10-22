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
        ),
        Entry(
            bookName: "Exodus",
            chapterNumber: 14,
            sourceVerse: 13,
            relatedReference: "2 Chronicles 20:17",
            reason: "Both call Israel to stand still for deliverance, but they address distinct crises without a direct historical or literary development."
        ),
        Entry(
            bookName: "Exodus",
            chapterNumber: 14,
            sourceVerse: 13,
            relatedReference: "Lamentations 3:26",
            reason: "The link rests on a general exhortation to wait quietly for salvation rather than a connection to the sea deliverance."
        ),
        Entry(
            bookName: "Exodus",
            chapterNumber: 15,
            sourceVerse: 26,
            relatedReference: "Deuteronomy 13:18",
            reason: "Both urge obedience to the Lord, but the passages govern different covenant situations without a specific development between them."
        ),
        Entry(
            bookName: "Exodus",
            chapterNumber: 19,
            sourceVerse: 18,
            relatedReference: "Genesis 19:28",
            reason: "The smoke imagery is a shared simile; Sinai's theophany and Sodom's destruction are otherwise unrelated."
        ),
        Entry(
            bookName: "Exodus",
            chapterNumber: 24,
            sourceVerse: 16,
            relatedReference: "Numbers 16:42",
            reason: "Both mention the glory-cloud at the tent, but neither passage interprets or develops the other's event."
        ),
        Entry(
            bookName: "Exodus",
            chapterNumber: 35,
            sourceVerse: 35,
            relatedReference: "2 Chronicles 2:14",
            reason: "Both describe skilled artisans, but Hiram's worker does not continue or interpret Bezalel and Oholiab's work."
        ),
        Entry(
            bookName: "Exodus",
            chapterNumber: 36,
            sourceVerse: 1,
            relatedReference: "Numbers 7:9",
            reason: "The passages share sanctuary-service context but do not connect the craftsmen's appointment with the Kohathites' transport duty."
        ),
        Entry(
            bookName: "Leviticus",
            chapterNumber: 5,
            sourceVerse: 12,
            relatedReference: "Numbers 5:26",
            reason: "Both involve a priest taking a memorial portion of flour, but the sin offering and jealousy ordeal have no direct contextual relationship."
        ),
        Entry(
            bookName: "Leviticus",
            chapterNumber: 10,
            sourceVerse: 9,
            relatedReference: "Luke 1:15",
            reason: "The priestly prohibition against wine during sanctuary service is unrelated to John's lifelong abstinence."
        ),
        Entry(
            bookName: "Leviticus",
            chapterNumber: 14,
            sourceVerse: 10,
            relatedReference: "Numbers 6:14",
            reason: "The passages list offerings with similar flour and oil measures but govern unrelated restoration and Nazirite rites."
        ),
        Entry(
            bookName: "Leviticus",
            chapterNumber: 14,
            sourceVerse: 10,
            relatedReference: "Leviticus 23:13",
            reason: "The shared grain-offering measure does not create a substantive link between cleansing a leper and firstfruits worship."
        ),
        Entry(
            bookName: "Leviticus",
            chapterNumber: 23,
            sourceVerse: 13,
            relatedReference: "Leviticus 14:10",
            reason: "The shared grain-offering measure does not connect the firstfruits offering to the leper's cleansing rite."
        ),
        Entry(
            bookName: "Leviticus",
            chapterNumber: 26,
            sourceVerse: 46,
            relatedReference: "Leviticus 27:34",
            reason: "Both are editorial closing formulas for Sinai legislation, not a contextual relationship between their respective laws."
        ),
        Entry(
            bookName: "Leviticus",
            chapterNumber: 26,
            sourceVerse: 46,
            relatedReference: "Deuteronomy 12:1",
            reason: "The passages share a formula introducing or closing statutes, but Sinai's covenant terms do not directly develop Deuteronomy's land laws."
        ),
        Entry(
            bookName: "Leviticus",
            chapterNumber: 27,
            sourceVerse: 34,
            relatedReference: "Leviticus 26:46",
            reason: "Both are editorial closing formulas for Sinai legislation, not a contextual relationship between their respective laws."
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
