#!/usr/bin/env python3
"""Apply the completed editorial review for Jonah and Micah to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


JONAH_WWA = {
    1: ("Obadiah closed with the promise that \"the kingdom shall be the LORD's,\" after judging Edom for "
        "betraying Judah (Obadiah 1:21). Jonah opens the next book with an entirely different test of that "
        "kingship: God sends a prophet to warn a hostile foreign city, Nineveh, and Jonah flees in the "
        "opposite direction instead, triggering a storm that terrifies the pagan sailors around him. Thrown "
        "overboard and swallowed by a great fish, Jonah's flight ends in chapter 2, where he prays for rescue "
        "from the one place left to run."),
    2: ("Chapter 1 ended with Jonah thrown into the sea and swallowed by a great fish the LORD had appointed "
        "(Jonah 1:17). Chapter 2 pauses the action for Jonah's prayer from inside the fish, a thanksgiving "
        "psalm that moves from vivid images of drowning and despair to a renewed hope that salvation belongs "
        "to the LORD. That rescue, when the fish releases Jonah onto dry land, sets up chapter 3, where Jonah "
        "finally receives his original commission to Nineveh a second time."),
    3: ("Chapter 2 ended with the fish releasing Jonah safely onto dry land after his prayer of thanksgiving "
        "(Jonah 2:10). Chapter 3 gives Jonah a second chance: this time he goes to Nineveh, and the entire "
        "city, from the king down to the animals, responds to his warning with fasting and genuine repentance. "
        "Because God relents from the announced judgment, chapter 4 turns from the city's response to Jonah's "
        "own reaction, anger instead of relief, at the mercy he predicted God would show."),
    4: ("Chapter 3 ended with Nineveh's repentance and God relenting from the disaster Jonah had announced "
        "(Jonah 3:10). Chapter 4 reveals why Jonah fled in the first place: he resents the LORD's mercy toward "
        "Israel's enemy and would rather die than watch Nineveh spared. The book closes on God's own "
        "unanswered question about compassion for a great city, leaving readers, not just Jonah, to weigh the "
        "same choice before Micah, the next book, turns from mercy for outsiders back to judgment on Israel "
        "and Judah's own corrupt leaders."),
}

JONAH_SUMMARY_FIXES = {
    1: [
        ("The account calls the creature a 'great fish'; it does not identify its species.",
         "The account calls the creature a \"great fish\"; it does not identify its species."),
    ],
    2: [
        ("Its language is poetic, so the descent imagery should not automatically be treated as a "
         "geographical travel report.",
         "Its language is poetic, picturing Jonah's rescue through images of drowning and the underworld "
         "rather than a literal geographical journey."),
    ],
    3: [
        ("Jonah enters the city and warns, 'Yet forty days, and Nineveh shall be overthrown' (Jonah 3:4).",
         "Jonah enters the city and warns, \"Yet forty days, and Nineveh shall be overthrown\" (Jonah 3:4)."),
    ],
    4: [
        ("The precise meaning of the right-hand/left-hand phrase and the exact demographic implications of "
         "the number are disputed.",
         "The right-hand/left-hand phrase likely points to moral innocence, perhaps young children too "
         "immature to know right from wrong, though readers differ on exactly how the number 120,000 should "
         "be understood."),
    ],
}

JONAH_NAME_FIXES = {
    3: {"The LORD / God": "The LORD"},
    4: {"The LORD / God": "The LORD"},
}

JONAH_ROLE_FIXES = {
    1: {
        "The LORD":
            "Divine speaker and actor. Commands Jonah, sends the storm, and appoints the fish (1:1–4,17)",
        "The sailors and shipmaster":
            "Non-Israelite crew and captain. Pray, seek to preserve life, and come to fear the LORD (1:5–16)",
        "The great fish":
            "Creature appointed by God in the narrative. Swallows Jonah after he is cast into the sea (1:17)",
    },
    2: {
        "The LORD":
            "Recipient of prayer and agent of deliverance. Hears Jonah and commands the fish to release him "
            "(2:2,6–7,10)",
        "Those who regard lying vanities / worthless idols":
            "Contrasting group invoked in Jonah's poetry as those who cling to worthless idols. Their "
            "misplaced loyalties are contrasted with Jonah's thanksgiving (2:8); no individuals are named",
    },
    3: {
        "The LORD / God":
            "Speaker and judge. Renews the commission and responds to the city's turning from evil (3:1–2,10)",
        "Jonah":
            "Prophetic messenger. Obeys the renewed command and announces impending judgment (3:3–4)",
        "The people of Nineveh":
            "Hearers of the warning. Believe God, fast, put on sackcloth, and turn from evil (3:5,8–10)",
    },
    4: {
        "The livestock of Nineveh":
            "Animals explicitly included in God's closing question. Emphasize the breadth of divine concern "
            "in the narrative (4:11)",
    },
}

JONAH_NAME_KEY = {"Those who regard lying vanities / worthless idols": "Those who regard lying vanities"}

JONAH_THEMES = {
    1: {
        "Resisting a divine commission":
            "Jonah is told to preach against Nineveh's wickedness but instead books passage in the opposite "
            "direction, showing that even a called prophet can choose flight over obedience (1:1-3).",
        "God’s rule over creation":
            "The LORD controls the storm that nearly destroys the ship and later appoints a great fish to "
            "save Jonah, showing power over both sea and creature (1:4, 1:9, 1:17).",
        "Concern for human life":
            "The sailors try rowing to shore before throwing Jonah overboard, and pray not to be held guilty "
            "for his death, showing a reluctance to take a life even to save their own (1:11-15).",
        "Recognition of the LORD among outsiders":
            "The pagan sailors move from praying to their own gods, to urging Jonah to call on his God, to "
            "fearing the LORD directly and offering sacrifice once the sea calms (1:5-6, 1:14-16).",
    },
    2: {
        "Prayer in extreme distress":
            "From inside the fish, with no other hope of rescue, Jonah turns to prayer, describing his "
            "situation in the vivid language of drowning and abandonment (2:1-4).",
        "Remembering God amid despair":
            "Even as he sinks toward the roots of the mountains, Jonah says that remembering the LORD is "
            "what brings his prayer to God's holy temple (2:5-7).",
        "Deliverance belongs to the LORD":
            "Jonah credits the LORD alone with bringing his life up from the pit and commanding the fish to "
            "release him, crediting no other power for his rescue (2:6, 2:9-10).",
        "Thanksgiving and commitments":
            "Jonah contrasts those who cling to worthless idols with his own promise to sacrifice and fulfill "
            "his vows, turning his rescue into an occasion for gratitude (2:8-9).",
    },
    3: {
        "A renewed opportunity to obey":
            "God gives Jonah the same commission a second time, and this time Jonah actually goes to Nineveh "
            "and delivers the warning (3:1-4).",
        "A warning that invites change":
            "Jonah's blunt forty-day warning is not the end of the story; the Ninevites respond immediately "
            "with belief, fasting, and sackcloth rather than despair (3:4-5).",
        "Repentance expressed in conduct":
            "The king's decree does not stop at religious ritual; it specifically calls the people to turn "
            "from evil and violence, showing repentance meant as a change in behavior, not only in feeling "
            "(3:7-10).",
        "Mercy in the face of judgment":
            "Because the city turns from its evil way, God relents from the disaster he had announced, "
            "showing judgment as conditional on response rather than fixed in advance (3:9-10).",
    },
    4: {
        "Resentment at mercy":
            "Jonah is angrier about Nineveh being spared than he ever was about his own danger, revealing "
            "that his real objection was always to God's mercy toward this enemy city (4:1-4).",
        "Disproportionate attachment":
            "Jonah mourns the loss of a plant that gave him one day of shade far more than he ever grieved "
            "for Nineveh's hundreds of thousands of people (4:5-9).",
        "Divine compassion reaches outsiders":
            "God's closing argument contrasts Jonah's concern for a plant he did not grow with God's own "
            "concern for a great city full of people and animals Jonah never had to care for (4:10-11).",
        "An open-ended challenge to readers":
            "The book ends with God's question left hanging, unanswered by Jonah or any narrated outcome, "
            "inviting every later reader to supply their own answer (4:9-11).",
    },
}

MICAH_WWA = {
    1: ("Jonah ended with God's unanswered question about compassion for Nineveh, a city outside Israel "
        "(Jonah 4:11). Micah turns back to Israel and Judah themselves, announcing that the LORD is coming to "
        "judge both capitals, Samaria and Jerusalem, for idolatry and covenant unfaithfulness, with mountains "
        "melting at his approach. Micah's own mourning over the coming disaster, voiced through wordplay on "
        "nearby towns, carries into chapter 2, where the prophet names exactly who is responsible: the "
        "wealthy who seize their neighbors' land."),
    2: ("Chapter 1 announced judgment on Samaria and Jerusalem and Micah's own grief over it (Micah 1:2–9). "
        "Chapter 2 names the specific crime driving that judgment: the powerful seizing fields and houses "
        "from families who cannot resist them, while demanding that Micah himself stop preaching against it. "
        "The chapter's surprising promise that God will one day gather a scattered remnant carries into "
        "chapter 3, where Micah confronts the leaders, priests, and prophets responsible for the exploitation "
        "he has just described."),
    3: ("Chapter 2 ended with a promised future gathering of Israel's remnant, even as the powerful kept "
        "seizing land in the present (Micah 2:12–13). Chapter 3 names exactly who bears responsibility for "
        "that injustice: rulers who prey on their own people, prophets who tailor their message to whoever "
        "pays them, and priests who teach for a price while claiming God's protection. Because of this "
        "corruption, Micah announces that Zion itself will be plowed like a field, setting up the sharp "
        "contrast in chapter 4, where a very different, honored Zion becomes the center of the nations' "
        "hope."),
    4: ("Chapter 3 ended by announcing that corrupt leadership would bring Zion and the temple hill to ruin "
        "(Micah 3:9–12). Chapter 4 answers that threat with a vision of a far future Zion, honored by the "
        "nations, where weapons become farm tools and God's people live in peace, even while the chapter also "
        "acknowledges Jerusalem's coming exile to Babylon before any such restoration. That same tension "
        "between present judgment and future hope continues in chapter 5, where a promised ruler from "
        "Bethlehem answers the national humiliation described there."),
    5: ("Chapter 4 held together Jerusalem's coming exile with a future vision of honored, peaceful Zion "
        "(Micah 4:9–13). Chapter 5 answers Israel's present humiliation, a ruler struck on the cheek during "
        "siege, with the promise of a future ruler from Bethlehem Ephrathah, small and overlooked, whose rule "
        "will bring lasting security. That promised peace comes paired with a purge of Israel's military and "
        "idolatrous props, setting up chapter 6's covenant lawsuit over what God actually requires in place "
        "of those false securities."),
    6: ("Chapter 5 promised a future ruler and the removal of Israel's weapons, fortresses, and idols "
        "(Micah 5:10–15). Chapter 6 stages a covenant lawsuit in which the LORD calls the mountains "
        "themselves as witnesses, reminds Israel of his deliverance from Egypt, and answers the question of "
        "what sacrifice could ever satisfy him with a simple threefold charge: do justice, love mercy, and "
        "walk humbly with God. Israel's continuing dishonest trade and violence despite that answer carries "
        "into the book's final chapter, where Micah laments how completely faithfulness has disappeared from "
        "the land."),
    7: ("Chapter 6 answered Israel's empty religious questions with God's own simple requirement: justice, "
        "mercy, and humility (Micah 6:8). Micah's final chapter laments that faithful people seem to have "
        "vanished entirely, with even family relationships broken by betrayal, yet the prophet resolves to "
        "watch and wait for God rather than give up hope. The book closes with praise for the God who "
        "delights in mercy and casts sins into the depths of the sea, handing off to Nahum, the next book, "
        "where that same LORD's patience finally runs out for Nineveh, the city Jonah once watched spared."),
}

MICAH_SUMMARY_FIXES = {
    5: [
        ("When Assyria invades, leaders will be raised up and the aggressor resisted; the precise historical "
         "or future reference of this poetic picture is disputed (Micah 5:5–6).",
         "When Assyria invades, leaders will be raised up and the aggressor resisted, likely reflecting an "
         "ongoing pattern of raised-up leaders rather than one single, dated event (Micah 5:5–6)."),
    ],
}

MICAH_NAME_FIXES = {
    3: {"Heads and rulers of Jacob/Israel": "Heads and rulers of Jacob (Israel)"},
    4: {"Daughter of Zion/Jerusalem": "Daughter of Zion (Jerusalem)"},
    5: {"Besieged ruler/judge of Israel": "The judge of Israel"},
    7: {"Daughter Zion / the community speaking": "Daughter Zion"},
}

MICAH_ROLE_FIXES = {
    1: {
        "Jotham, Ahaz, and Hezekiah":
            "Kings of Judah named in the superscription. Locate the ministry within a sequence of "
            "eighth-century rulers (1:1).",
        "Residents of Judah’s towns":
            "Communities addressed through place-name poetry. Embodiment of anticipated suffering and "
            "displacement (1:10–16).",
    },
    3: {
        "Prophets who proclaim peace for payment":
            "Religious speakers condemned for self-interest. Mislead the community and face the loss of "
            "vision (3:5–7, 11).",
    },
    4: {
        "Daughter of Zion/Jerusalem":
            "Personified city and its people. Endures labor-like distress, exile, and promised rescue "
            "(4:8–13).",
    },
    5: {
        "Promised ruler from Bethlehem Ephrathah":
            "Future shepherd-ruler described in the oracle. Governs in the LORD’s strength and is associated "
            "with security and peace (5:2–5).",
    },
}

MICAH_THEMES = {
    1: {
        "God’s judgment extends to both kingdoms":
            "Micah's opening vision addresses Samaria and Jerusalem together, showing that the LORD holds "
            "both the northern and southern kingdoms accountable, not only Israel's rivals (1:2-7).",
        "Idolatry and misplaced security":
            "Samaria's wealth and images, built up through what Micah compares to a harlot's hire, will be "
            "stripped away and burned, showing that material and religious confidence cannot outlast God's "
            "judgment (1:5-7).",
        "Lament in the face of calamity":
            "Micah responds to the coming disaster not with detachment but with public mourning, going "
            "stripped and wailing like a wild animal (1:8-9).",
        "Communal vulnerability and exile":
            "Micah's wordplay on the names of Judah's own towns turns local geography into a map of coming "
            "defeat and displacement (1:10-16).",
    },
    2: {
        "Economic injustice":
            "The powerful plan their land grabs at night and carry them out in daylight simply because they "
            "have the strength to get away with it (2:1-2).",
        "Consequences for exploitation":
            "God promises that those who have stripped others of land will themselves lose control over how "
            "land is divided, turning their own method of oppression back on them (2:3-5).",
        "Rejecting unwelcome truth":
            "The people would rather silence Micah than hear his warning, and admit a prophet promising wine "
            "and strong drink would be far more welcome (2:6-11).",
        "Hope for a gathered remnant":
            "Even after pronouncing judgment, Micah closes the chapter with God's promise to gather Israel's "
            "scattered remnant together under his own leadership (2:12-13).",
    },
    3: {
        "Leadership as a trust":
            "Israel's leaders are condemned precisely because their job was to know justice, making their "
            "violent exploitation of the people a betrayal of the responsibility they were given (3:1-4).",
        "Integrity in spiritual speech":
            "Prophets who shape their message around payment are contrasted with Micah, who claims the "
            "LORD's own Spirit and power to expose Israel's sin regardless of the cost (3:5-8).",
        "Corruption within institutions":
            "Rulers who take bribes, priests who teach for a price, and prophets who divine for money all "
            "point to corruption spreading through every public office meant to serve the people (3:9-11).",
        "False confidence in sacred status":
            "These same corrupt leaders insist the LORD is still with them and that no evil can touch them, "
            "even as Micah announces that Zion and its temple will become ruins (3:11-12).",
    },
    4: {
        "Peace founded on just judgment":
            "The vision of weapons turned into farm tools follows directly from the LORD judging between "
            "nations, showing that lasting peace depends on justice being settled, not merely declared "
            "(4:1-4).",
        "Faithful communal life":
            "While other nations walk in the name of their own gods, God's people are called to walk in the "
            "LORD's name, grounding their identity in loyalty rather than military strength (4:4-5).",
        "Gathering the vulnerable":
            "God promises to gather exactly the people easiest to overlook, the lame, the driven away, and "
            "the afflicted, and make them into the core of a renewed nation (4:6-8).",
        "Hope amid coming displacement":
            "Jerusalem's coming labor-like suffering and exile to Babylon do not cancel the promise of "
            "rescue; the same chapter that predicts displacement also predicts redemption from it (4:9-13).",
    },
    5: {
        "Hope arising from Bethlehem":
            "Against the humiliation of a ruler struck on the cheek, Micah promises a future ruler from "
            "obscure, overlooked Bethlehem, showing hope emerging from the least expected place (5:1-4).",
        "Shepherding and peace":
            "The promised ruler governs by shepherding his people in the LORD's strength rather than through "
            "conquest, and his rule itself becomes Israel's peace against future invasion (5:4-6).",
        "The remnant among the nations":
            "Micah pictures the remnant of Jacob as both refreshing dew that depends on no one and a lion "
            "that no one can resist, holding together gentleness and strength (5:7-9).",
        "Purging false sources of security":
            "God promises to remove Israel's horses, chariots, fortresses, sorceries, and idols together, "
            "treating military power and false worship as the same kind of misplaced trust (5:10-15).",
    },
    6: {
        "Remembering deliverance":
            "God's case against Israel begins not with accusation but with memory, recalling the exodus, the "
            "leadership of Moses, Aaron, and Miriam, and protection from Balak and Balaam's schemes (6:1-5).",
        "What God requires":
            "After the worshiper's escalating offers of sacrifice fail to find an answer, Micah states "
            "plainly what God actually wants: justice, mercy, and a humble walk with him (6:6-8).",
        "Honesty in economic life":
            "Dishonest scales and violent gain are named as the opposite of the justice God requires, "
            "showing that true worship must reach into ordinary commerce (6:9-12).",
        "Consequences of entrenched corruption":
            "Because Israel has kept the corrupt practices of Omri and Ahab, Micah warns that the people "
            "will plant, eat, and labor without ever being satisfied (6:13-16).",
    },
    7: {
        "Grief over social breakdown":
            "Micah compares his search for a faithful person to searching for fruit after the harvest is "
            "already over, and even family relationships have broken down into betrayal (7:1-6).",
        "Patient hope despite failure":
            "Rather than give in to despair, Micah resolves to watch and wait for God, confident that even "
            "after falling he will rise and see the LORD's light (7:7-10).",
        "Restoration and divine shepherding":
            "The chapter looks forward to rebuilt walls and a God who shepherds his people again as in the "
            "days of old, with even hostile nations left in awe (7:11-17).",
        "Forgiveness and covenant faithfulness":
            "The book ends by praising a God who delights in mercy, casts sin into the depths of the sea, "
            "and keeps promises made long ago to Abraham and Jacob (7:18-20).",
    },
}


def apply_chapter_insights(path_name, book, chapters, wwa, summary_fixes, name_fixes, role_fixes, themes,
                            name_key_overrides=None):
    path = ROOT / "chapter_insights" / path_name
    data = load(path)
    name_key_overrides = name_key_overrides or {}
    for n in chapters:
        key = f"{book} {n}"
        entry = data[key]
        entry["whereWeAre"] = wwa[n]
        for old, new in summary_fixes.get(n, []):
            if old not in entry["summary"]:
                raise SystemExit(f"{key}: summary fix not found: {old!r}")
            entry["summary"] = entry["summary"].replace(old, new)
        for fig in entry["keyFigures"]:
            original_name = fig["name"]
            if original_name in name_fixes.get(n, {}):
                lookup_key = name_key_overrides.get(original_name, original_name)
                fig["role"] = role_fixes.get(n, {}).get(lookup_key, fig["role"])
                fig["name"] = name_fixes[n][original_name]
            elif original_name in role_fixes.get(n, {}):
                fig["role"] = role_fixes[n][original_name]
        theme_map = themes[n]
        seen = set()
        for theme in entry["keyThemes"]:
            name = theme["theme"]
            if name not in theme_map:
                raise SystemExit(f"{key}: no explanation drafted for theme {name!r}")
            theme["explanation"] = theme_map[name]
            seen.add(name)
        missing = set(theme_map) - seen
        if missing:
            raise SystemExit(f"{key}: drafted themes not in source: {missing}")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_overview():
    path = ROOT / "book_overviews" / "06_minor_prophets.json"
    data = load(path)

    jonah = data["Jonah"]
    jonah["theme"] = jonah["theme"].replace(
        "God's mercy extends beyond Israel, and His servants must learn to value the people He is willing to forgive.",
        "God's mercy extends beyond Israel, and his servants must learn to value the people he is willing to forgive.",
    )
    jonah["keyVerse"] = "Jonah 4:2"

    micah = data["Micah"]
    micah["theme"] = micah["theme"].replace(
        "God requires justice, faithful love, and humble walking with Him; judgment is real, but restoration is promised.",
        "God requires justice, faithful love, and humble walking with him; judgment is real, but restoration is promised.",
    )

    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


JONAH_STORY_PRONOUN_FIXES = [
    ("and that he is running from Him. He tells them,",
     "and that he is running from him. He tells them,"),
    ("The pagan sailors now fear the LORD and offer Him sacrifices.",
     "The pagan sailors now fear the LORD and offer him sacrifices."),
    ("Jesus later pointed to this as a sign of His own three days in the grave (Matthew 12:40).",
     "Jesus later pointed to this as a sign of his own three days in the grave (Matthew 12:40)."),
    ("God exposes Jonah's concern for what he did not create and contrasts it with His own compassion for "
     "Nineveh's people and animals.",
     "God exposes Jonah's concern for what he did not create and contrasts it with his own compassion for "
     "Nineveh's people and animals."),
]

MICAH_STORY_PRONOUN_FIXES = [
    ("The cause is the sin of His own people.",
     "The cause is the sin of his own people."),
    ("with the Lord Himself leading them.",
     "with the Lord himself leading them."),
    ("Then God will remove everything Israel trusted in place of Him:",
     "Then God will remove everything Israel trusted in place of him:"),
    ("the priests quoted this verse to show He would be born in Bethlehem (Matthew 2:5–6).",
     "the priests quoted this verse to show he would be born in Bethlehem (Matthew 2:5–6)."),
    ("God recalls His past faithfulness to Israel and rejects the idea that costly offerings can replace "
     "obedience.",
     "God recalls his past faithfulness to Israel and rejects the idea that costly offerings can replace "
     "obedience."),
    ("God takes His people to court, with the mountains as witnesses.",
     "God takes his people to court, with the mountains as witnesses."),
    ("He requires justice, mercy, and humility, while warning that dishonest trade, violence, and idolatrous "
     "practices will bring loss and disgrace.",
     "he requires justice, mercy, and humility, while warning that dishonest trade, violence, and idolatrous "
     "practices will bring loss and disgrace."),
    ("But He speaks like a hurt friend:",
     "But he speaks like a hurt friend:"),
    ("He reminds them how He brought them out of Egypt, sent them Moses, Aaron, and Miriam,",
     "He reminds them how he brought them out of Egypt, sent them Moses, Aaron, and Miriam,"),
    ("praising God's mercy, forgiveness, and faithfulness to His covenant with Jacob and Abraham,",
     "praising God's mercy, forgiveness, and faithfulness to his covenant with Jacob and Abraham,"),
    ("He will keep the promises He made long ago to Abraham and Jacob.",
     "he will keep the promises he made long ago to Abraham and Jacob."),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "06_minor_prophets.md"
    text = path.read_text(encoding="utf-8")

    for marker_start, marker_end, fixes in [
        ("# Jonah", "# Micah", JONAH_STORY_PRONOUN_FIXES),
        ("# Micah", "# Nahum", MICAH_STORY_PRONOUN_FIXES),
    ]:
        start = text.index(marker_start)
        end = text.index(marker_end)
        section = text[start:end]
        for old, new in fixes:
            count = section.count(old)
            if count == 0:
                if section.count(new) == 1:
                    continue
                raise SystemExit(f"story fix matched 0 times and not already applied: {old!r}")
            if count != 1:
                raise SystemExit(f"story fix matched {count} times (expected 1): {old!r}")
            section = section.replace(old, new)
        text = text[:start] + section + text[end:]

    path.write_text(text, encoding="utf-8")
    print(f"Updated {path.relative_to(ROOT)}")


if __name__ == "__main__":
    apply_chapter_insights(
        "32_jonah.json", "Jonah", range(1, 5), JONAH_WWA, JONAH_SUMMARY_FIXES, JONAH_NAME_FIXES,
        JONAH_ROLE_FIXES, JONAH_THEMES, name_key_overrides=JONAH_NAME_KEY,
    )
    apply_chapter_insights(
        "33_micah.json", "Micah", range(1, 8), MICAH_WWA, MICAH_SUMMARY_FIXES, MICAH_NAME_FIXES,
        MICAH_ROLE_FIXES, MICAH_THEMES,
    )
    apply_overview()
    apply_story_fixes()
