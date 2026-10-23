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
        ),
        Entry(
            bookName: "Joshua",
            chapterNumber: 9,
            sourceVerse: 6,
            relatedReference: "Joshua 5:10",
            reason: "Both passages place Israel at Gilgal, but the Gibeonites' embassy does not develop the Passover observance there."
        ),
        Entry(
            bookName: "Joshua",
            chapterNumber: 11,
            sourceVerse: 12,
            relatedReference: "Joshua 10:28",
            reason: "The passages use conquest language for different cities; Makkedah's fall does not interpret the destruction of Hazor's northern coalition."
        ),
        Entry(
            bookName: "Joshua",
            chapterNumber: 12,
            sourceVerse: 3,
            relatedReference: "Joshua 13:20",
            reason: "The Salt Sea boundary of Sihon's former kingdom does not meaningfully explain the separate Reubenite city list."
        ),
        Entry(
            bookName: "Joshua",
            chapterNumber: 15,
            sourceVerse: 9,
            relatedReference: "1 Chronicles 13:6",
            reason: "Both identify Kiriath-jearim by its alternate name Baalah, but Judah's boundary notice does not develop the later ark narrative."
        ),
        Entry(
            bookName: "Joshua",
            chapterNumber: 15,
            sourceVerse: 35,
            relatedReference: "1 Samuel 22:1",
            reason: "The connection rests only on Adullam's place name; the Judahite town list does not contextualize David's refuge there."
        ),
        Entry(
            bookName: "Joshua",
            chapterNumber: 15,
            sourceVerse: 35,
            relatedReference: "1 Samuel 17:1",
            reason: "The connection rests only on the nearby town Socoh; the territorial list does not contextualize the Philistine encampment."
        ),
        Entry(
            bookName: "Joshua",
            chapterNumber: 18,
            sourceVerse: 16,
            relatedReference: "2 Kings 23:10",
            reason: "Both mention the Valley of Hinnom, but Benjamin's boundary marker does not explain Josiah's later reform at Topheth."
        ),
        Entry(
            bookName: "Joshua",
            chapterNumber: 18,
            sourceVerse: 28,
            relatedReference: "2 Samuel 21:14",
            reason: "The connection rests on Zelah's place name; Benjamin's town list does not contextualize Saul's later burial there."
        ),
        Entry(
            bookName: "Joshua",
            chapterNumber: 19,
            sourceVerse: 18,
            relatedReference: "1 Samuel 28:4",
            reason: "The connection rests on Shunem's place name; Issachar's town list does not explain the Philistine camp there."
        ),
        Entry(
            bookName: "Joshua",
            chapterNumber: 19,
            sourceVerse: 27,
            relatedReference: "1 Kings 9:13",
            reason: "Both use the name Cabul, but Asher's boundary town does not establish a contextual link to Solomon's later district."
        ),
        Entry(
            bookName: "Joshua",
            chapterNumber: 24,
            sourceVerse: 25,
            relatedReference: "Exodus 15:25",
            reason: "Both mention a statute and ordinance, but the Marah provision does not explain Joshua's covenant ceremony at Shechem."
        ),
        Entry(bookName: "Judges", chapterNumber: 4, sourceVerse: 6, relatedReference: "Judges 8:18", reason: "Barak's call from Kedesh and Gideon's later questioning of Zebah concern different conflicts; Tabor is only an incidental setting."),
        Entry(bookName: "Judges", chapterNumber: 6, sourceVerse: 12, relatedReference: "Judges 13:3", reason: "The angel's appearances to Gideon and Manoah's wife are separate commissions, linked only by a general angelic greeting."),
        Entry(bookName: "Judges", chapterNumber: 6, sourceVerse: 33, relatedReference: "Joshua 17:16", reason: "Both passages locate events in the Jezreel Valley, but the Canaanite chariot problem does not explain the Midianite invasion."),
        Entry(bookName: "Judges", chapterNumber: 9, sourceVerse: 15, relatedReference: "Isaiah 2:13", reason: "The passages use tree imagery in different rhetorical settings; Isaiah does not develop Jotham's bramble fable."),
        Entry(bookName: "Judges", chapterNumber: 9, sourceVerse: 15, relatedReference: "Hosea 14:7", reason: "The shared shade-and-tree imagery is metaphorical but does not connect Hosea's restoration promise with Jotham's fable."),
        Entry(bookName: "Judges", chapterNumber: 11, sourceVerse: 10, relatedReference: "Jeremiah 42:5", reason: "Both invoke the Lord as a witness to an oath, but the Gileadite agreement and Judah's later pledge are unrelated."),
        Entry(bookName: "Judges", chapterNumber: 11, sourceVerse: 11, relatedReference: "Judges 20:1", reason: "Mizpah is the only connection; Jephthah's installation does not explain Israel's later assembly against Benjamin."),
        Entry(bookName: "Judges", chapterNumber: 11, sourceVerse: 11, relatedReference: "1 Samuel 10:17", reason: "Mizpah is the only connection; Samuel's assembly to select Saul does not develop Jephthah's appointment."),
        Entry(bookName: "Judges", chapterNumber: 11, sourceVerse: 13, relatedReference: "Genesis 32:22", reason: "The connection rests on the Jabbok's name; Jacob's crossing does not interpret the Ammonite border dispute."),
        Entry(bookName: "Judges", chapterNumber: 11, sourceVerse: 33, relatedReference: "Ezekiel 27:17", reason: "Both mention Minnith, but Jephthah's conquest does not explain the later trade reference."),
        Entry(bookName: "Judges", chapterNumber: 13, sourceVerse: 24, relatedReference: "Luke 1:80", reason: "The accounts share a generic notice that a child grew; John’s preparation in the wilderness does not interpret Samson’s growth."),
        Entry(bookName: "Judges", chapterNumber: 16, sourceVerse: 21, relatedReference: "2 Chronicles 33:11", reason: "Samson and Manasseh are both captured, but the passages have no direct historical or literary relationship."),
        Entry(bookName: "Judges", chapterNumber: 16, sourceVerse: 21, relatedReference: "2 Kings 25:7", reason: "The blinding of Zedekiah is not an allusion to Samson and does not develop Samson's capture."),
        Entry(bookName: "Judges", chapterNumber: 17, sourceVerse: 6, relatedReference: "Proverbs 12:15", reason: "The wording about a person's own way being right is proverbial and does not interpret the book's moral diagnosis."),
        Entry(bookName: "Judges", chapterNumber: 17, sourceVerse: 7, relatedReference: "Ruth 1:1-2", reason: "Bethlehem and the period of the judges are shared setting details, not a contextual link between the Levite and Elimelech's family."),
        Entry(bookName: "Judges", chapterNumber: 18, sourceVerse: 28, relatedReference: "2 Samuel 10:6", reason: "The texts share the name Rehob without connecting Dan's capture of Laish to the Aramean force hired against David."),
        Entry(bookName: "Judges", chapterNumber: 20, sourceVerse: 1, relatedReference: "Judges 11:11", reason: "Mizpah is the only connection; Jephthah's installation does not explain Israel's later assembly against Benjamin."),
        Entry(bookName: "Ruth", chapterNumber: 1, sourceVerse: 1, relatedReference: "Genesis 12:10", reason: "Both narratives mention a famine that prompts travel, but Abram's journey to Egypt does not interpret Elimelech's move to Moab."),
        Entry(bookName: "Ruth", chapterNumber: 1, sourceVerse: 1, relatedReference: "Genesis 26:1", reason: "The connection rests on famine as a general circumstance; Isaac's stay in Gerar is not a development of Ruth's opening crisis."),
        Entry(bookName: "Ruth", chapterNumber: 1, sourceVerse: 22, relatedReference: "2 Samuel 21:9", reason: "Both mention the beginning of barley harvest, but the seasonal timing does not connect Naomi's return with the Gibeonite execution."),
        Entry(bookName: "Ruth", chapterNumber: 2, sourceVerse: 10, relatedReference: "1 Samuel 25:23", reason: "Both describe bowing to the ground, a customary gesture that does not create a contextual link between Ruth and Abigail."),
        Entry(bookName: "1 Samuel", chapterNumber: 2, sourceVerse: 12, relatedReference: "2 Corinthians 6:15", reason: "The shared term Belial is a general label for wickedness and does not connect Eli's sons to Paul's argument."),
        Entry(bookName: "1 Samuel", chapterNumber: 2, sourceVerse: 18, relatedReference: "2 Samuel 6:14", reason: "Both mention a linen ephod, but Samuel's sanctuary service does not interpret David's later ark celebration."),
        Entry(bookName: "1 Samuel", chapterNumber: 4, sourceVerse: 1, relatedReference: "1 Samuel 29:1", reason: "Aphek is the only connection; the Philistine staging before Saul's last battle does not develop the earlier ark battle."),
        Entry(bookName: "1 Samuel", chapterNumber: 7, sourceVerse: 5, relatedReference: "Judges 20:1", reason: "Mizpah is only a shared assembly location; the civil-war gathering does not interpret Samuel's call to repentance."),
        Entry(bookName: "1 Samuel", chapterNumber: 7, sourceVerse: 12, relatedReference: "Genesis 31:45-52", reason: "Both involve a memorial stone, but Jacob and Laban's boundary covenant does not explain Samuel's Ebenezer."),
        Entry(bookName: "1 Samuel", chapterNumber: 10, sourceVerse: 27, relatedReference: "Deuteronomy 13:13", reason: "The term sons of Belial is a general condemnation, not a link to Deuteronomy's law concerning an idolatrous city."),
        Entry(bookName: "1 Samuel", chapterNumber: 10, sourceVerse: 27, relatedReference: "1 Samuel 2:12", reason: "Both call wicked people sons of Belial, but Eli's sons and Saul's opponents are unrelated groups."),
        Entry(bookName: "1 Samuel", chapterNumber: 10, sourceVerse: 27, relatedReference: "2 Chronicles 13:7", reason: "The shared label for rebels does not connect Saul's opponents with Jeroboam's supporters."),
        Entry(bookName: "1 Samuel", chapterNumber: 11, sourceVerse: 4, relatedReference: "Judges 21:2", reason: "The passages share weeping, but the grief after Benjamin's civil war does not explain Jabesh-gilead's appeal to Saul."),
        Entry(bookName: "1 Samuel", chapterNumber: 13, sourceVerse: 18, relatedReference: "Nehemiah 11:34", reason: "The connection rests on Geba's place name; Nehemiah's resettlement list does not interpret Saul's campaign."),
        Entry(bookName: "1 Samuel", chapterNumber: 13, sourceVerse: 23, relatedReference: "Isaiah 10:28", reason: "The connection rests on the Michmash-area route; Isaiah's Assyrian march does not develop the Philistine conflict."),
        Entry(bookName: "1 Samuel", chapterNumber: 16, sourceVerse: 4, relatedReference: "1 Kings 2:13", reason: "The wording about coming peaceably appears in unrelated political situations and does not link Samuel with Adonijah."),
        Entry(bookName: "1 Samuel", chapterNumber: 17, sourceVerse: 1, relatedReference: "Joshua 15:35", reason: "Socoh is only a shared location; Judah's town list does not explain the Philistine encampment."),
        Entry(bookName: "1 Samuel", chapterNumber: 17, sourceVerse: 7, relatedReference: "1 Chronicles 11:23", reason: "The two accounts describe different giant opponents; shared stature and weapon imagery do not establish a connection."),
        Entry(bookName: "1 Samuel", chapterNumber: 23, sourceVerse: 1, relatedReference: "Joshua 15:44", reason: "Keilah is only a shared location; the territorial list does not explain David's rescue of the town."),
        Entry(bookName: "1 Samuel", chapterNumber: 23, sourceVerse: 14, relatedReference: "Joshua 15:55", reason: "Ziph is only a shared location; Judah's town list does not interpret David's refuge there."),
        Entry(bookName: "1 Samuel", chapterNumber: 23, sourceVerse: 29, relatedReference: "2 Chronicles 20:2", reason: "En-gedi is only a shared location; Jehoshaphat's later invasion does not develop David's escape from Saul."),
        Entry(bookName: "1 Samuel", chapterNumber: 24, sourceVerse: 12, relatedReference: "Genesis 16:5", reason: "Both invoke the Lord as judge, but Sarai's dispute with Hagar does not interpret David's appeal concerning Saul."),
        Entry(bookName: "1 Samuel", chapterNumber: 25, sourceVerse: 2, relatedReference: "Joshua 15:55", reason: "Carmel is only a shared location; Judah's town list does not explain Nabal's household."),
        Entry(bookName: "1 Samuel", chapterNumber: 25, sourceVerse: 22, relatedReference: "1 Kings 14:10", reason: "The same curse formula occurs in unrelated judgments and does not connect David's anger with Ahijah's oracle."),
        Entry(bookName: "1 Samuel", chapterNumber: 25, sourceVerse: 22, relatedReference: "1 Kings 21:21", reason: "The same curse formula occurs in unrelated judgments and does not connect David's anger with Elijah's oracle against Ahab."),
        Entry(bookName: "1 Samuel", chapterNumber: 25, sourceVerse: 22, relatedReference: "2 Kings 9:8", reason: "The same curse formula occurs in unrelated judgments and does not connect David's anger with Jehu's judgment on Ahab's house."),
        Entry(bookName: "1 Samuel", chapterNumber: 25, sourceVerse: 43, relatedReference: "Joshua 15:56", reason: "Jezreel is only a shared location; the Judahite town list does not interpret David's marriage to Ahinoam."),
        Entry(bookName: "1 Samuel", chapterNumber: 28, sourceVerse: 4, relatedReference: "Joshua 19:18", reason: "Shunem is only a shared location; Issachar's town list does not explain the Philistine camp before Gilboa."),
        Entry(bookName: "1 Samuel", chapterNumber: 29, sourceVerse: 1, relatedReference: "1 Samuel 4:1", reason: "Aphek is only a shared location; the earlier ark battle does not explain the Philistine staging against Saul."),
        Entry(bookName: "1 Samuel", chapterNumber: 30, sourceVerse: 27, relatedReference: "Joshua 15:48", reason: "The connection rests on a Judahite place name; the territorial list does not explain David's distribution of spoil."),
        Entry(bookName: "1 Samuel", chapterNumber: 30, sourceVerse: 28, relatedReference: "Joshua 13:16", reason: "Aroer is only a shared location; the Transjordanian boundary list does not explain David's gift of spoil."),
        Entry(bookName: "1 Samuel", chapterNumber: 30, sourceVerse: 30, relatedReference: "Judges 1:17", reason: "Hormah is only a shared location; Judah's earlier destruction of the city does not interpret David's distribution of spoil."),
        Entry(bookName: "2 Samuel", chapterNumber: 3, sourceVerse: 16, relatedReference: "2 Samuel 16:5", reason: "Bahurim is the only connection; Shimei's later curse of David does not interpret Paltiel's pursuit of Michal."),
        Entry(bookName: "2 Samuel", chapterNumber: 3, sourceVerse: 16, relatedReference: "2 Samuel 19:16", reason: "Bahurim is the only connection; Shimei's return to David does not interpret Paltiel's separation from Michal."),
        Entry(bookName: "2 Samuel", chapterNumber: 4, sourceVerse: 2, relatedReference: "Joshua 18:25", reason: "Gibeon is only a shared location; Benjamin's territorial list does not interpret the murder of Ish-bosheth."),
        Entry(bookName: "2 Samuel", chapterNumber: 4, sourceVerse: 3, relatedReference: "Nehemiah 11:33", reason: "Beeroth is only a shared location; Nehemiah's resettlement list does not interpret the Beerothite fugitives."),
        Entry(bookName: "2 Samuel", chapterNumber: 14, sourceVerse: 25, relatedReference: "Job 2:7", reason: "The contrast between Absalom's beauty and Job's sores does not establish a contextual or literary relationship."),
        Entry(bookName: "2 Samuel", chapterNumber: 15, sourceVerse: 12, relatedReference: "Joshua 15:51", reason: "Hebron is only a shared location; Judah's town list does not interpret Absalom's conspiracy."),
        Entry(bookName: "2 Samuel", chapterNumber: 16, sourceVerse: 5, relatedReference: "2 Samuel 3:16", reason: "Bahurim is the only connection; Shimei's curse does not interpret Paltiel's pursuit of Michal."),
        Entry(bookName: "2 Samuel", chapterNumber: 17, sourceVerse: 17, relatedReference: "Joshua 15:7", reason: "En-rogel is only a shared location; Judah's boundary description does not interpret the spies' mission."),
        Entry(bookName: "2 Samuel", chapterNumber: 17, sourceVerse: 17, relatedReference: "Joshua 18:16", reason: "En-rogel is only a shared location; Benjamin's boundary description does not interpret the spies' mission."),
        Entry(bookName: "2 Samuel", chapterNumber: 17, sourceVerse: 18, relatedReference: "2 Samuel 3:16", reason: "Bahurim is only a shared location; Paltiel's separation from Michal does not interpret the spies' escape."),
        Entry(bookName: "2 Samuel", chapterNumber: 19, sourceVerse: 35, relatedReference: "Ezra 2:65", reason: "The mention of singers is incidental; Ezra's returnee list does not interpret Barzillai's old age."),
        Entry(bookName: "2 Samuel", chapterNumber: 19, sourceVerse: 35, relatedReference: "Nehemiah 7:67", reason: "The mention of singers is incidental; Nehemiah's returnee list does not interpret Barzillai's old age."),
        Entry(bookName: "2 Samuel", chapterNumber: 21, sourceVerse: 9, relatedReference: "Ruth 1:22", reason: "Both mention the barley harvest, but seasonal timing does not connect the Gibeonite execution to Naomi's return."),
        Entry(bookName: "2 Samuel", chapterNumber: 21, sourceVerse: 14, relatedReference: "Joshua 18:28", reason: "Zelah is only a shared location; Benjamin's town list does not interpret Saul's burial."),
        Entry(bookName: "2 Samuel", chapterNumber: 23, sourceVerse: 6, relatedReference: "Deuteronomy 13:13", reason: "The shared term Belial is a general label for wickedness and does not link David's image of worthless men to Deuteronomy's law."),
        Entry(bookName: "Matthew", chapterNumber: 7, sourceVerse: 28, relatedReference: "Mark 11:18", reason: "Both report a reaction to Jesus' teaching, but Mark's later response from hostile leaders does not interpret the crowd's response to the Sermon on the Mount.")
,
        Entry(bookName: "1 Kings", chapterNumber: 1, sourceVerse: 8, relatedReference: "1 Kings 4:18", reason: "The passages share only the name Shimei; neither identifies the court officer as the supporter named in Adonijah's crisis."),
        Entry(bookName: "1 Kings", chapterNumber: 1, sourceVerse: 9, relatedReference: "2 Samuel 17:17", reason: "En-rogel is the only connection; the messenger episode does not interpret Adonijah's feast there."),
        Entry(bookName: "1 Kings", chapterNumber: 1, sourceVerse: 33, relatedReference: "2 Chronicles 32:30", reason: "Both mention Gihon, but Hezekiah's waterwork does not explain Solomon's procession to be anointed."),
        Entry(bookName: "1 Kings", chapterNumber: 2, sourceVerse: 37, relatedReference: "2 Samuel 15:23", reason: "The Kidron is only a shared location; David's flight across it does not interpret Shimei's boundary of confinement."),
        Entry(bookName: "1 Kings", chapterNumber: 4, sourceVerse: 18, relatedReference: "1 Kings 1:8", reason: "The link rests only on the name Shimei; the officer is identified as son of Elah and is not connected to Nathan's supporter."),
        Entry(bookName: "1 Kings", chapterNumber: 4, sourceVerse: 31, relatedReference: "1 Chronicles 15:19", reason: "The passages share the name Heman, but they do not establish that Solomon's Ezrahite comparator is the Levitical singer."),
        Entry(bookName: "1 Kings", chapterNumber: 9, sourceVerse: 3, relatedReference: "2 Kings 20:5", reason: "Both report God hearing a king's prayer, but Hezekiah's healing does not interpret the temple-dedication answer to Solomon."),
        Entry(bookName: "1 Kings", chapterNumber: 9, sourceVerse: 8, relatedReference: "Jeremiah 49:17", reason: "The shared judgment language is a general curse formula; Jeremiah's oracle against Edom does not develop the warning about Solomon's temple."),
        Entry(bookName: "1 Kings", chapterNumber: 11, sourceVerse: 18, relatedReference: "Numbers 10:12", reason: "Paran is the only connection; Israel's wilderness departure does not interpret Hadad's later flight through the region."),
        Entry(bookName: "1 Kings", chapterNumber: 13, sourceVerse: 21, relatedReference: "1 Samuel 13:13-14", reason: "Both narratives condemn disobedience, but Saul's dynastic rejection does not explain the man of God's separate judgment."),
        Entry(bookName: "1 Kings", chapterNumber: 14, sourceVerse: 7, relatedReference: "1 Kings 16:2", reason: "The similar prophetic formula addresses different dynasties and does not create a specific relationship between Jeroboam and Baasha."),
        Entry(bookName: "1 Kings", chapterNumber: 14, sourceVerse: 9, relatedReference: "Ezekiel 23:35", reason: "The phrase about casting God behind one's back is a general accusation of unfaithfulness, not a contextual link to Jerusalem's later judgment."),
        Entry(bookName: "1 Kings", chapterNumber: 14, sourceVerse: 10, relatedReference: "1 Kings 15:29", reason: "The repeated judgment formula does not by itself connect Ahijah's oracle to Baasha's separate dynasty purge."),
        Entry(bookName: "1 Kings", chapterNumber: 14, sourceVerse: 10, relatedReference: "1 Kings 21:21", reason: "The repeated judgment formula does not create a substantive connection between Jeroboam's house and Elijah's oracle against Ahab."),
        Entry(bookName: "1 Kings", chapterNumber: 14, sourceVerse: 10, relatedReference: "2 Kings 9:8-9", reason: "The repeated judgment formula does not connect Ahijah's oracle to Jehu's later judgment on Ahab's house."),
        Entry(bookName: "1 Kings", chapterNumber: 14, sourceVerse: 17, relatedReference: "1 Kings 15:33", reason: "Tirzah is the only connection; Jeroboam's wife's return does not interpret Baasha's later reign there."),
        Entry(bookName: "1 Kings", chapterNumber: 15, sourceVerse: 22, relatedReference: "Joshua 21:17", reason: "Geba is the only connection; the Levitical town list does not explain Asa's fortification work."),
        Entry(bookName: "1 Kings", chapterNumber: 15, sourceVerse: 27, relatedReference: "Joshua 19:44", reason: "Gibbethon is only a shared location; Dan's territorial list does not explain Baasha's siege."),
        Entry(bookName: "1 Kings", chapterNumber: 15, sourceVerse: 27, relatedReference: "Joshua 21:23", reason: "Gibbethon is only a shared location; the Levitical city list does not interpret Baasha's conspiracy."),
        Entry(bookName: "1 Kings", chapterNumber: 16, sourceVerse: 2, relatedReference: "1 Kings 14:7", reason: "The shared elevation-from-dust formula addresses different kings and does not establish a specific relationship."),
        Entry(bookName: "1 Kings", chapterNumber: 16, sourceVerse: 3, relatedReference: "1 Kings 14:10", reason: "The repeated curse formula does not create a substantive connection between Baasha's judgment and Jeroboam's earlier oracle."),
        Entry(bookName: "1 Kings", chapterNumber: 16, sourceVerse: 6, relatedReference: "1 Kings 14:17", reason: "Tirzah is the only connection; Jeroboam's household event does not interpret Baasha's burial."),
        Entry(bookName: "1 Kings", chapterNumber: 16, sourceVerse: 9, relatedReference: "1 Kings 20:16", reason: "The passages share drunken rulers but describe unrelated events without a literary or historical development."),
        Entry(bookName: "1 Kings", chapterNumber: 17, sourceVerse: 9, relatedReference: "Obadiah 1:20", reason: "Zarephath is only a shared location; Obadiah's restoration geography does not interpret Elijah's stay with the widow."),
        Entry(bookName: "1 Kings", chapterNumber: 18, sourceVerse: 19, relatedReference: "Joshua 19:26", reason: "Mount Carmel is the only connection; Asher's boundary notice does not interpret Elijah's confrontation there."),
        Entry(bookName: "1 Kings", chapterNumber: 18, sourceVerse: 30, relatedReference: "2 Chronicles 33:16", reason: "Both describe repairing an altar, but Manasseh's later reform does not interpret Elijah's Carmel restoration."),
        Entry(bookName: "1 Kings", chapterNumber: 18, sourceVerse: 31, relatedReference: "Ezra 6:17", reason: "The number twelve represents Israel in both offerings, but the postexilic dedication does not develop Elijah's altar stones."),
        Entry(bookName: "1 Kings", chapterNumber: 18, sourceVerse: 33, relatedReference: "Genesis 22:9", reason: "The passages share sacrificial preparation details but do not establish a contextual connection between Carmel and Isaac's binding."),
        Entry(bookName: "1 Kings", chapterNumber: 18, sourceVerse: 36, relatedReference: "Matthew 22:32", reason: "Jesus' argument for resurrection from Exodus does not interpret Elijah's covenantal prayer."),
        Entry(bookName: "1 Kings", chapterNumber: 20, sourceVerse: 1, relatedReference: "1 Kings 15:18", reason: "The link rests on the royal name Ben-hadad; the earlier Aramean treaty does not specifically interpret Ahab's later war."),
        Entry(bookName: "1 Kings", chapterNumber: 20, sourceVerse: 16, relatedReference: "1 Kings 16:9", reason: "The passages share drunken rulers but describe unrelated events without a substantive historical or literary development."),
        Entry(bookName: "1 Kings", chapterNumber: 21, sourceVerse: 21, relatedReference: "1 Kings 14:10", reason: "The repeated dynastic judgment formula does not by itself connect Elijah's oracle against Ahab with Ahijah's oracle against Jeroboam."),
        Entry(bookName: "1 Kings", chapterNumber: 21, sourceVerse: 21, relatedReference: "1 Samuel 25:22", reason: "The shared curse formula does not create a substantive connection between Elijah's judgment on Ahab and David's oath against Nabal."),
        Entry(bookName: "1 Kings", chapterNumber: 21, sourceVerse: 21, relatedReference: "1 Samuel 25:34", reason: "The shared curse formula does not create a substantive connection between Elijah's judgment on Ahab and Abigail's plea concerning Nabal."),
        Entry(bookName: "2 Kings", chapterNumber: 1, sourceVerse: 3, relatedReference: "1 Kings 17:1", reason: "Both involve Elijah delivering a word to a king, but the drought announcement does not interpret Ahaziah's inquiry of Baal-zebub."),
        Entry(bookName: "2 Kings", chapterNumber: 2, sourceVerse: 3, relatedReference: "2 Kings 4:38", reason: "The references share only the phrase sons of the prophets; the Bethel group does not specifically explain the later Gilgal community."),
        Entry(bookName: "2 Kings", chapterNumber: 2, sourceVerse: 3, relatedReference: "2 Kings 4:1", reason: "The references share only the phrase sons of the prophets; no connection is established between the Bethel group and the widow's household."),
        Entry(bookName: "2 Kings", chapterNumber: 4, sourceVerse: 8, relatedReference: "Joshua 19:18", reason: "Shunem is the only connection; Issachar's town list does not interpret the Shunammite woman's hospitality."),
        Entry(bookName: "2 Kings", chapterNumber: 4, sourceVerse: 38, relatedReference: "2 Kings 2:1", reason: "Gilgal is the only connection; Elijah's departure itinerary does not interpret Elisha's later ministry there."),
        Entry(bookName: "2 Kings", chapterNumber: 6, sourceVerse: 13, relatedReference: "Genesis 37:17", reason: "Dothan is the only connection; Joseph's search for his brothers does not interpret Elisha's military encounter."),
        Entry(bookName: "2 Kings", chapterNumber: 7, sourceVerse: 1, relatedReference: "Revelation 6:6", reason: "The passages mention food prices during scarcity, but Revelation's apocalyptic rationing does not interpret Samaria's siege."),
        Entry(bookName: "2 Kings", chapterNumber: 7, sourceVerse: 6, relatedReference: "1 Kings 10:29", reason: "The shared chariot trade details do not connect Solomon's commercial prices with the Aramean army's panic."),
        Entry(bookName: "2 Kings", chapterNumber: 4, sourceVerse: 1, relatedReference: "2 Kings 2:3", reason: "The references share only the phrase sons of the prophets; no connection is established between the widow's household and the Bethel group."),
        Entry(bookName: "2 Kings", chapterNumber: 6, sourceVerse: 1, relatedReference: "2 Kings 2:3", reason: "The repeated label sons of the prophets does not connect the growing community with the Bethel group at Elijah's departure."),
        Entry(bookName: "2 Kings", chapterNumber: 6, sourceVerse: 1, relatedReference: "2 Kings 4:1", reason: "The repeated label sons of the prophets does not identify the growing community with the widow's husband's household."),
        Entry(bookName: "2 Kings", chapterNumber: 6, sourceVerse: 1, relatedReference: "2 Kings 4:38", reason: "The repeated label sons of the prophets does not establish that this building project develops the earlier Gilgal gathering."),
        Entry(bookName: "2 Kings", chapterNumber: 4, sourceVerse: 29, relatedReference: "2 Kings 9:1", reason: "Both are messenger commissions from Elisha, but the healing mission and Jehu's anointing do not have a specific contextual relationship."),
        Entry(bookName: "2 Kings", chapterNumber: 4, sourceVerse: 38, relatedReference: "2 Kings 8:1", reason: "Both mention famine during Elisha's ministry, but the later seven-year warning does not interpret the earlier Gilgal episode."),
        Entry(bookName: "2 Kings", chapterNumber: 9, sourceVerse: 1, relatedReference: "2 Kings 4:29", reason: "Both are messenger commissions from Elisha, but the healing mission and Jehu's anointing do not have a specific contextual relationship."),
        Entry(bookName: "2 Kings", chapterNumber: 9, sourceVerse: 1, relatedReference: "Jeremiah 1:17", reason: "The instruction to gird oneself for a mission is a general commission formula, not a link between Elisha's messenger and Jeremiah."),
        Entry(bookName: "2 Kings", chapterNumber: 9, sourceVerse: 8, relatedReference: "1 Samuel 25:22", reason: "The shared curse formula does not connect Jehu's judgment on Ahab's house with David's oath against Nabal."),
        Entry(bookName: "2 Kings", chapterNumber: 9, sourceVerse: 8, relatedReference: "1 Kings 14:10-11", reason: "The repeated dynastic judgment formula does not create a substantive connection between Jehu's commission and Ahijah's oracle against Jeroboam."),
        Entry(bookName: "2 Kings", chapterNumber: 9, sourceVerse: 27, relatedReference: "Judges 1:27", reason: "Megiddo is the only connection; Manasseh's territorial notice does not interpret Ahaziah's flight and death."),
        Entry(bookName: "2 Kings", chapterNumber: 14, sourceVerse: 4, relatedReference: "2 Kings 15:35", reason: "Both retain high places, but the repeated royal evaluation does not establish a specific development between Amaziah and Jotham."),
        Entry(bookName: "2 Kings", chapterNumber: 15, sourceVerse: 4, relatedReference: "1 Kings 15:14", reason: "The recurring notice about high places is not a specific relationship between Azariah and Asa."),
        Entry(bookName: "2 Kings", chapterNumber: 15, sourceVerse: 4, relatedReference: "2 Kings 12:3", reason: "The recurring notice about high places is not a specific relationship between Azariah and Joash."),
        Entry(bookName: "2 Kings", chapterNumber: 15, sourceVerse: 14, relatedReference: "1 Kings 14:17", reason: "Tirzah is the only connection; Jeroboam's household event does not interpret Menahem's reign."),
        Entry(bookName: "2 Kings", chapterNumber: 15, sourceVerse: 23, relatedReference: "1 Kings 22:51", reason: "The link rests only on royal succession language and does not connect Pekahiah's reign with Ahaziah's accession."),
        Entry(bookName: "2 Kings", chapterNumber: 15, sourceVerse: 23, relatedReference: "1 Kings 15:25", reason: "The passages merely report different northern accessions and do not establish a contextual relationship."),
        Entry(bookName: "2 Kings", chapterNumber: 16, sourceVerse: 9, relatedReference: "Isaiah 22:6", reason: "The mention of Kir and Elam does not connect Tiglath-pileser's deportation policy with Isaiah's oracle about Jerusalem."),
        Entry(bookName: "2 Kings", chapterNumber: 17, sourceVerse: 9, relatedReference: "2 Kings 18:8", reason: "The shared phrase from watchtower to fortified city is a general geographic formula, not a relationship between Israel's high places and Hezekiah's Philistine campaign."),
        Entry(bookName: "2 Kings", chapterNumber: 25, sourceVerse: 7, relatedReference: "2 Chronicles 33:11", reason: "Both kings are captured by foreign powers, but Manasseh's captivity does not interpret Zedekiah's blinding and deportation."),
        Entry(bookName: "2 Kings", chapterNumber: 25, sourceVerse: 7, relatedReference: "Judges 16:21", reason: "The shared blinding and captivity motif does not connect Samson's capture with Zedekiah's Babylonian punishment.")
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
