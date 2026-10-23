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
        ),
        Entry(
            bookName: "Leviticus",
            chapterNumber: 23,
            sourceVerse: 40,
            relatedReference: "John 12:13",
            reason: "Both passages mention palm branches, but the Feast of Tabernacles ritual and Jesus' triumphal entry have no direct contextual relationship."
        ),
        Entry(
            bookName: "Numbers",
            chapterNumber: 27,
            sourceVerse: 14,
            relatedReference: "Exodus 17:7",
            reason: "Both recall water-related rebellion, but Rephidim's Massah and Meribah is not the Kadesh rebellion for which Moses is judged."
        ),
        Entry(
            bookName: "Numbers",
            chapterNumber: 27,
            sourceVerse: 21,
            relatedReference: "1 Samuel 28:6",
            reason: "Both mention inquiry by Urim, but Saul's unanswered inquiry does not interpret Joshua's commission through Eleazar."
        ),
        Entry(
            bookName: "Numbers",
            chapterNumber: 29,
            sourceVerse: 2,
            relatedReference: "Numbers 28:27",
            reason: "The passages prescribe similar festival offerings, but the Day of Atonement and the seventh-month trumpet festival are distinct rites."
        ),
        Entry(
            bookName: "Numbers",
            chapterNumber: 29,
            sourceVerse: 39,
            relatedReference: "Deuteronomy 12:6",
            reason: "Both list offerings brought to worship, but the broad central-sanctuary instruction does not explain this festival-offering summary."
        ),
        Entry(
            bookName: "Numbers",
            chapterNumber: 32,
            sourceVerse: 38,
            relatedReference: "Isaiah 46:1",
            reason: "The connection rests on the name Nebo; a rebuilt town and Babylon's god are not contextually linked here."
        ),
        Entry(
            bookName: "Numbers",
            chapterNumber: 34,
            sourceVerse: 11,
            relatedReference: "2 Kings 23:33",
            reason: "Both name Riblah, but the boundary description does not develop Pharaoh Necho's later imprisonment of Jehoahaz there."
        ),
        Entry(
            bookName: "Numbers",
            chapterNumber: 35,
            sourceVerse: 1,
            relatedReference: "Numbers 33:50",
            reason: "Both introduce commands in the plains of Moab, but they govern different laws and share only a setting formula."
        ),
        Entry(
            bookName: "Numbers",
            chapterNumber: 35,
            sourceVerse: 1,
            relatedReference: "Numbers 36:13",
            reason: "The final editorial location formula does not specifically interpret the Levite-city legislation."
        ),
        Entry(
            bookName: "Numbers",
            chapterNumber: 35,
            sourceVerse: 1,
            relatedReference: "Numbers 26:63",
            reason: "Both locate Israel near Jericho, but the census setting does not meaningfully develop the Levite-city law."
        ),
        Entry(
            bookName: "Numbers",
            chapterNumber: 36,
            sourceVerse: 13,
            relatedReference: "Numbers 26:3",
            reason: "Both use the plains-of-Moab setting, but the census command is not a substantive counterpart to this closing formula."
        ),
        Entry(
            bookName: "Numbers",
            chapterNumber: 36,
            sourceVerse: 13,
            relatedReference: "Numbers 35:1",
            reason: "The chapter's closing formula does not specifically interpret the Levite-city legislation."
        ),
        Entry(
            bookName: "Deuteronomy",
            chapterNumber: 1,
            sourceVerse: 6,
            relatedReference: "Exodus 3:1",
            reason: "Both name Horeb, but the burning bush account does not explain Israel's later departure from Sinai."
        ),
        Entry(
            bookName: "Deuteronomy",
            chapterNumber: 1,
            sourceVerse: 15,
            relatedReference: "1 Samuel 8:12",
            reason: "Both mention military officers, but Samuel's warning about royal conscription does not develop Moses' appointment of wilderness officials."
        ),
        Entry(
            bookName: "Deuteronomy",
            chapterNumber: 1,
            sourceVerse: 15,
            relatedReference: "Numbers 31:14",
            reason: "The shared officer titles do not create a contextual link between appointing judges and disciplining Midian-war commanders."
        ),
        Entry(
            bookName: "Deuteronomy",
            chapterNumber: 1,
            sourceVerse: 46,
            relatedReference: "Numbers 20:1",
            reason: "Both mention Kadesh, but the extended stay after the spies and the later Meribah episode are distinct events."
        ),
        Entry(
            bookName: "Deuteronomy",
            chapterNumber: 2,
            sourceVerse: 37,
            relatedReference: "Genesis 32:22",
            reason: "The connection rests on the Jabbok's name; Jacob's crossing does not interpret Israel's Ammonite boundary restriction."
        ),
        Entry(
            bookName: "Deuteronomy",
            chapterNumber: 3,
            sourceVerse: 7,
            relatedReference: "Joshua 8:27",
            reason: "Both permit taking war booty, but Ai's conquest does not interpret the campaign against Og."
        ),
        Entry(
            bookName: "Deuteronomy",
            chapterNumber: 3,
            sourceVerse: 17,
            relatedReference: "Joshua 3:16",
            reason: "Both mention the Sea of Arabah, but the Jordan crossing miracle does not develop this territorial boundary description."
        ),
        Entry(
            bookName: "Joshua",
            chapterNumber: 2,
            sourceVerse: 14,
            relatedReference: "Genesis 24:49",
            reason: "Both use a formal loyalty phrase, but Rahab's protection agreement does not interpret the servant's request for Abraham's family." 
        ),
        Entry(
            bookName: "Joshua",
            chapterNumber: 3,
            sourceVerse: 7,
            relatedReference: "1 Chronicles 29:25",
            reason: "Both describe God magnifying a leader, but Solomon's royal establishment does not develop Joshua's Jordan-crossing vindication."
        ),
        Entry(
            bookName: "Joshua",
            chapterNumber: 3,
            sourceVerse: 16,
            relatedReference: "Deuteronomy 3:17",
            reason: "The connection rests on Jordan and the Sea of Arabah; the territorial boundary does not interpret the crossing miracle."
        ),
        Entry(
            bookName: "Joshua",
            chapterNumber: 5,
            sourceVerse: 13,
            relatedReference: "Numbers 22:23",
            reason: "Both describe an angel with a drawn sword, but Balaam's confrontation does not interpret Joshua's encounter with the Lord's commander."
        ),
        Entry(
            bookName: "Joshua",
            chapterNumber: 6,
            sourceVerse: 12,
            relatedReference: "Joshua 3:1",
            reason: "The link only follows narrative order from Shittim to Jericho and does not connect Rahab's preservation to the departure for the Jordan."
        ),
        Entry(
            bookName: "Joshua",
            chapterNumber: 7,
            sourceVerse: 2,
            relatedReference: "Joshua 18:12",
            reason: "Both mention the Bethel region, but the Benjaminite boundary does not interpret the reconnaissance of Ai."
        ),
        Entry(
            bookName: "Joshua",
            chapterNumber: 7,
            sourceVerse: 15,
            relatedReference: "Genesis 34:7",
            reason: "The passages use a general term for disgraceful wrongdoing but address unrelated offenses and judgments."
        ),
        Entry(
            bookName: "Joshua",
            chapterNumber: 7,
            sourceVerse: 26,
            relatedReference: "Joshua 8:29",
            reason: "Both describe a stone heap after an execution, but Achan's judgment does not interpret the separate treatment of Ai's king."
        ),
        Entry(
            bookName: "Joshua",
            chapterNumber: 8,
            sourceVerse: 10,
            relatedReference: "Joshua 7:16",
            reason: "Joshua rising early occurs in unrelated scenes; Achan's lot inquiry does not explain the military preparations for Ai."
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
