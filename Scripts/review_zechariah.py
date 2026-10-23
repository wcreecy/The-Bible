#!/usr/bin/env python3
"""Apply the completed editorial review for Zechariah to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


WWA = {
    1: ("Haggai's book closed with God's personal promise to Zerubbabel as his chosen signet (Haggai "
        "2:20-23). Zechariah begins two months later with a call to the same returned community: unlike "
        "their ancestors who ignored earlier prophets, they are urged to turn back to the LORD. The "
        "chapter's first night vision, of patrol riders reporting that the earth lies at rest while "
        "Jerusalem still suffers, sets up chapter 2's vision of a city about to be measured and restored."),
    2: ("Chapter 1 ended with four craftsmen ready to throw down the powers that scattered Judah "
        "(Zechariah 1:18-21). Chapter 2 continues the night visions: a man goes out to measure Jerusalem, "
        "but an angel promises a city too full of people for any wall to contain, with the LORD himself as "
        "a wall of fire around it. That vision of a restored, indwelt city prepares for chapter 3's vision "
        "of Joshua the high priest, whose own cleansing pictures the community's own need for renewal."),
    3: ("Chapter 2 promised that the LORD himself would dwell among a restored Jerusalem (Zechariah "
        "2:10-11). Chapter 3 pictures what that dwelling requires: Joshua the high priest, representing "
        "the whole community, stands accused in filthy clothing before being cleansed and reclothed, with "
        "a promise of a coming Branch. That same vision night continues straight into chapter 4, where a "
        "lampstand and two olive trees bring the parallel promise that Zerubbabel's own stalled building "
        "work will be finished by God's Spirit."),
    4: ("Chapter 3 cleansed Joshua the high priest and promised a coming Branch (Zechariah 3:8-10). "
        "Chapter 4 turns to Zerubbabel with its own encouraging vision: a golden lampstand fed by two "
        "olive trees delivers the message that the temple will be finished \"not by might, nor by power, "
        "but by my spirit,\" so the day of small beginnings should not be despised. That same night of "
        "visions continues into chapter 5, where the scene shifts from encouragement to accountability for "
        "wrongdoing left in the land."),
    5: ("Chapter 4 promised that Zerubbabel would finish the temple by God's Spirit rather than by "
        "force (Zechariah 4:6-9). Chapter 5 turns from building to cleansing the community itself: a "
        "flying scroll curses thieves and false swearers, and a woman named Wickedness is sealed inside a "
        "measuring basket and carried away to Shinar. That same night of visions concludes in chapter 6, "
        "where four chariots go out under God's authority and the book's eighth and final vision gives way "
        "to the crowning of Joshua the high priest."),
    6: ("Chapter 5 closed the night visions by picturing wickedness carried out of the land (Zechariah "
        "5:9-11). Chapter 6 closes the vision sequence with four chariots sent out under God's authority, "
        "then shifts to a symbolic action: silver and gold from returning exiles become a crown for "
        "Joshua, pointing toward a coming Branch who will build the temple and hold royal and priestly "
        "honor together. Two years later, in chapter 7, a delegation arrives with a very different "
        "question about whether to keep fasting."),
    7: ("Chapter 6 closed the night visions with a crown for Joshua pointing toward a coming Branch "
        "(Zechariah 6:11-14). Chapter 7 jumps forward two years: a delegation asks whether to keep the "
        "mourning fasts that marked the exile, and the LORD answers by recalling what the earlier prophets "
        "already demanded, justice, mercy, and care for the vulnerable, which previous generations refused "
        "until they were scattered. That rebuke of self-centered ritual sets up chapter 8's turn to hope, "
        "where the same fasts will one day become feasts."),
    8: ("Chapter 7 recalled how earlier generations refused the justice and mercy the prophets "
        "demanded and were scattered for it (Zechariah 7:11-14). Chapter 8 answers that history with hope: "
        "the LORD promises to return to Zion, fill its streets with old people and children again, and "
        "turn the mourning fasts into joyful feasts, so long as the people speak truth and judge fairly. "
        "This closes the dated section of the book; chapter 9 opens a new, undated section with oracles "
        "about a coming king."),
    9: ("Chapters 1-8 were each dated to a specific day in Darius's reign; chapter 9 opens six undated "
        "chapters with oracles usually read as looking further into the future. Judgment falls on cities "
        "to the north and along the coast, then daughter Zion is told to rejoice because her king is "
        "coming, righteous and humble, riding on a donkey rather than a warhorse. That vision of a coming "
        "king who brings peace continues into chapter 10's call to seek the LORD rather than false "
        "shepherds for provision and leadership."),
    10: ("Chapter 9 promised a humble king who would remove the weapons of war and speak peace to the "
         "nations (Zechariah 9:9-10). Chapter 10 contrasts that true king with false sources of help: "
         "household gods and diviners offer empty promises, so the people wander like sheep under bad "
         "shepherds, and the LORD promises instead to strengthen Judah, save the house of Joseph, and "
         "gather them home from exile. That image of flock and shepherd turns much darker in chapter 11's "
         "extended allegory of a flock marked for slaughter."),
    11: ("Chapter 10 promised the LORD would gather his scattered flock and give them faithful "
         "leadership (Zechariah 10:6-12). Chapter 11 acts out the opposite scenario: the prophet himself "
         "plays a shepherd over a flock already marked for slaughter, is paid a contemptuous thirty pieces "
         "of silver, breaks two staffs representing favor and unity, and finally warns of a worthless "
         "shepherd still to come. That picture of broken leadership and a scattered flock sets up chapter "
         "12's vision of Jerusalem besieged yet defended by God."),
    12: ("Chapter 11 ended with a worthless shepherd condemned for neglecting the flock (Zechariah "
         "11:15-17). Chapter 12 turns to a future siege of Jerusalem: the LORD promises to defend the city "
         "and then, in a sudden shift, to pour out a spirit of grace so intense that the people mourn over "
         "one who has been pierced, as for an only child. That mourning over the pierced one continues "
         "directly into chapter 13, where a fountain is opened for the same house of David to cleanse the "
         "very sin being mourned."),
    13: ("Chapter 12 described the whole land mourning over one who was pierced (Zechariah 12:10-14). "
         "Chapter 13 answers that grief with cleansing: a fountain opens for the house of David, idols and "
         "false prophecy are removed, and a struck shepherd scatters the flock before a refined remnant "
         "survives testing and renews its covenant with God. The book's closing chapter then pictures the "
         "day when that same LORD finally reigns visibly over the whole earth."),
    14: ("Chapter 13 ended with a tested remnant renewing its covenant, \"It is my people: and they shall "
         "say, The LORD is my God\" (Zechariah 13:9). Zechariah's closing chapter pictures the day of the "
         "LORD in full: Jerusalem is attacked, the LORD himself fights for the city, the Mount of Olives "
         "splits, living water flows out, and the LORD is worshiped as king by survivors from every nation. "
         "Even ordinary objects, horse bells and cooking pots, become holy, handing off to Malachi, the "
         "last of the Minor Prophets, where the LORD confronts a priesthood that no longer treats holy "
         "things as holy at all."),
}

SUMMARY_FIXES = {
    3: [
        ("Interpretations of the Branch and stone differ, and the vision does not define every symbol.",
         "Christian tradition reads the Branch as pointing toward the Messiah, though the vision does not "
         "spell out every detail of the Branch and stone imagery."),
    ],
    6: [
        ("Their symbolism is debated, but the vision depicts divine oversight beyond Judah.",
         "Their symbolism is not spelled out in the text, but the vision depicts divine oversight beyond "
         "Judah."),
        ("How Joshua's crowning relates to the hoped-for ruler is contested; the text specifically names "
         "Joshua as the recipient of the crown.",
         "Joshua himself receives the crown in the text, while the oracle beside it looks ahead to the "
         "coming Branch's own royal and priestly role."),
    ],
    9: [
        ("Christians relate 9:9 to Jesus’ entry into Jerusalem; Jewish readings and historical-critical "
         "scholarship discuss the royal image differently, and the text does not date the events.",
         "Christians relate 9:9 directly to Jesus’ entry into Jerusalem on a donkey, though the text itself "
         "does not date the oracle’s events."),
    ],
    11: [
        ("The identity of the three shepherds and the exact historical reference of the symbolic acts are "
         "disputed.",
         "The text does not name the three shepherds removed in 11:8 or identify one historical crisis "
         "behind the symbolic acts."),
    ],
    12: [
        ("The identity of the pierced one and the relationship between divine speech and the person "
         "mourned are interpreted differently across traditions.",
         "Christian tradition connects the pierced one to Jesus’ crucifixion (John 19:37), though the "
         "oracle itself speaks in the LORD’s own voice without naming the pierced one directly."),
    ],
    13: [
        ("The identity of the shepherd and the precise meaning of the proportions are disputed.",
         "The text does not name the shepherd struck in 13:7 or explain the exact proportions in 13:8-9."),
    ],
}

ROLE_FIXES = {
    1: {
        "Four horns and four craftsmen":
            "Symbolic figures in a vision. Depict the scattering powers and their overthrow without naming "
            "particular empires (1:18–21).",
    },
    2: {
        "Two angels":
            "Heavenly messengers. Convey the promise of an unwalled, populous city (2:3–4).",
        "Many nations":
            "Peoples envisioned joining the LORD. Widen the hope beyond Judah (2:11).",
    },
    3: {
        "The angel of the LORD":
            "Heavenly figure. Presides over the scene and gives instructions concerning Joshua (3:1,5–6).",
        "The LORD":
            "Divine speaker. Chooses Jerusalem, promises cleansing, and announces coming renewal "
            "(3:2,8–9).",
        "The Branch":
            "Promised figure named in the oracle. Called the LORD’s servant and linked to building the "
            "temple; later Christian tradition reads this figure as pointing toward the Messiah (3:8).",
    },
    4: {
        "The LORD of hosts":
            "Divine speaker. Says the work succeeds by his Spirit (4:6).",
    },
    5: {
        "Two winged women":
            "Visionary carriers. Transport the container to Shinar (5:9–11).",
    },
    6: {
        "Heldai, Tobijah, and Jedaiah":
            "Named returnees from exile. Provide the silver and gold used for the crown, brought to the "
            "house of Josiah son of Zephaniah where Zechariah meets them (6:10).",
    },
    7: {
        "Zechariah":
            "Prophet receiving God’s reply. Delivers the response to the fasting question (7:4,8).",
        "Earlier generations":
            "Community recalled in the oracle. Rejected prophetic instruction and experienced scattering "
            "(7:11–14).",
    },
    8: {
        "Peoples of many nations":
            "Future seekers of the LORD. Travel to Jerusalem and seek God (8:20–23).",
    },
    10: {
        "Household gods, diviners and dreamers":
            "False sources of guidance. Offer empty reassurance and leave the people scattered (10:2).",
    },
    11: {
        "The LORD":
            "Divine speaker. Commands the shepherd action and announces judgment (11:4,13,15–17).",
        "The prophetic shepherd or first-person speaker":
            "Symbolic caretaker. Shepherds the flock, breaks two staffs, and receives thirty pieces of "
            "silver (11:7–14).",
        "Buyers, sellers and existing shepherds":
            "Exploitative figures. Benefit from or neglect the flock (11:5).",
        "Foolish shepherd":
            "Symbolic abusive leader. Neglects vulnerable sheep and faces condemnation (11:15–17).",
    },
    12: {
        "The LORD":
            "Divine creator and protector. Declares Jerusalem’s significance and promises grace and "
            "protection (12:1–10).",
        "The one who is pierced":
            "Figure at the center of mourning. Prompts grief and supplication from the house of David and "
            "Jerusalem (12:10).",
    },
    14: {
        "The LORD of hosts":
            "Divine king and warrior. Defends Jerusalem and is worshiped as king over all the earth "
            "(14:3,9,16–21).",
        "Jerusalem and its inhabitants":
            "Community in the prophetic scenario. Endure siege and afterward are pictured living in "
            "security (14:1–2,10–11).",
        "Nations gathered against Jerusalem":
            "Collective enemies and later pilgrims. First attack the city; surviving peoples then come to "
            "worship (14:2,16–19).",
    },
}

DROPPED_FIGURES = {
    6: {"Josiah son of Zephaniah"},
}

THEMES = {
    1: {
        "Repentance across generations":
            "The LORD contrasts the returned community with their ancestors, who ignored the earlier "
            "prophets until judgment overtook them, and calls the current generation not to repeat that "
            "pattern (1:2-6).",
        "Mercy and rebuilding":
            "After an angel asks how long Jerusalem must wait, the LORD answers with zeal for Zion and a "
            "promise that his house and cities will be rebuilt (1:12-17).",
        "The limits of oppressive power":
            "Four horns represent the powers that scattered Judah, but four craftsmen appear specifically "
            "to throw those powers down, showing that no empire's dominance is permanent (1:18-21).",
    },
    2: {
        "Security through divine presence":
            "Jerusalem will grow too large for any wall to enclose, because the LORD himself promises to "
            "be a wall of fire around it and its glory within (2:3-5).",
        "Return and restoration":
            "The LORD calls the exiles still scattered in Babylon to flee and return to Zion, promising "
            "that touching his people is like touching the pupil of his own eye (2:6-10).",
        "Inclusion of nations":
            "The vision looks beyond Judah to many nations joining themselves to the LORD and becoming his "
            "people too (2:10-13).",
    },
    3: {
        "Cleansing and renewed standing":
            "Joshua's filthy clothing is physically removed and replaced with clean garments, dramatizing "
            "the LORD rebuking the accuser and taking away the high priest's guilt (3:1-5).",
        "Responsible spiritual leadership":
            "Joshua is charged to walk in God's ways and keep his requirements, tying his cleansing to an "
            "ongoing responsibility rather than a one-time event (3:6-7).",
        "Hope for coming renewal":
            "The LORD promises a coming Branch and the removal of the land's guilt in a single day, "
            "closing with a vision of peaceful life under vine and fig tree (3:8-10).",
    },
    4: {
        "Divine empowerment over force":
            "The angel's message to Zerubbabel, that the work succeeds \"not by might, nor by power, but "
            "by my spirit,\" answers the stalled building project with divine enabling rather than "
            "military strength (4:6-7).",
        "Value of small beginnings":
            "Those who despise the small, unimpressive start of the rebuilt temple are told not to, since "
            "the same hands that laid its foundation will also finish it (4:8-10).",
        "Sustained leadership and worship":
            "The lampstand kept supplied by two olive trees pictures ongoing light and oil, symbols the "
            "angel ties to two anointed figures who stand beside the Lord of the whole earth (4:1-3,11-14).",
    },
    5: {
        "Integrity and communal accountability":
            "A flying scroll the size of a small building becomes a curse that enters the houses of "
            "thieves and those who swear falsely, showing that private dishonesty has public consequences "
            "(5:1-4).",
        "Exposure of wickedness":
            "A woman named Wickedness is forced down into a measuring basket and sealed under a lead "
            "cover, picturing wrongdoing being named, contained, and exposed rather than left hidden "
            "(5:5-8).",
        "Removal of corruption":
            "Two winged women carry the sealed basket away to Shinar, removing wickedness from the land "
            "entirely rather than merely managing it (5:9-11).",
    },
    6: {
        "God’s oversight of the nations":
            "Four chariots sent out from before the Lord to patrol different directions show that the "
            "LORD's authority extends over the whole earth, not just Judah (6:1-8).",
        "Leadership and the coming Branch":
            "Silver and gold from returning exiles become a crown for Joshua, and the accompanying oracle "
            "ties a coming figure called the Branch to both building the temple and holding royal and "
            "priestly honor together (6:11-13).",
        "Remembering and obeying":
            "The crown is kept in the temple as a memorial, and the vision closes with a reminder that the "
            "promised blessing still depends on obeying the LORD (6:14-15).",
    },
    7: {
        "Ritual and motive":
            "The LORD questions whether years of fasting and feasting were ever really directed toward "
            "him, or only toward the people's own comfort (7:4-6).",
        "Justice and compassion":
            "The prophet recalls what earlier prophets already demanded when Jerusalem stood secure: true "
            "justice, mercy, and protection for widows, orphans, foreigners, and the poor (7:8-10).",
        "Refusing correction":
            "Earlier generations hardened themselves against these same demands and were scattered among "
            "the nations as a result, a warning against repeating their refusal (7:11-14).",
    },
    8: {
        "Restoration as everyday peace":
            "The LORD's promised return to Zion is pictured in ordinary terms, old people and children "
            "filling the streets again, rather than only in dramatic or military language (8:3-8).",
        "Truth and justice in community":
            "Renewed blessing is tied directly to practical ethics: speaking truth, judging fairly, and "
            "rejecting both evil plotting and false oaths (8:14-17).",
        "Grief transformed into celebration":
            "The very fasts that once marked destruction and loss are promised to become joyful feasts, "
            "and peoples from many nations are pictured seeking the LORD in Jerusalem (8:18-23).",
    },
    9: {
        "Judgment on proud powers":
            "Named cities to the north and along the coast, Hadrach, Damascus, Tyre, Sidon, and the "
            "Philistine centers, face the LORD's judgment for their pride and hostility (9:1-8).",
        "A humble ruler and peace":
            "Daughter Zion is told to rejoice because her king arrives not on a warhorse but humbly on a "
            "donkey, bringing salvation and ending war chariots and battle bows (9:9-10).",
        "Covenant hope and deliverance":
            "Because of covenant blood, prisoners are summoned home with a promise of protection, and "
            "Judah and Ephraim are pictured as the LORD's own weapons of deliverance (9:11-17).",
    },
    10: {
        "True provision versus deceptive counsel":
            "The people are told to ask the LORD, not household idols or diviners, for rain, since those "
            "other sources of guidance only leave the flock scattered (10:1-2).",
        "Leadership and pastoral responsibility":
            "The LORD's anger falls on false shepherds who failed to care for the flock, while from Judah "
            "itself will come the cornerstone, tent peg, and battle bow needed for real leadership "
            "(10:3-5).",
        "Gathering the dispersed":
            "God promises to strengthen Judah, save the house of Joseph, and bring his scattered people "
            "home even from as far as Egypt and Assyria (10:6-12).",
    },
    11: {
        "Exploitation by leaders":
            "The flock is marked for slaughter, bought and sold by buyers and sellers while its own "
            "existing shepherds fail to pity it (11:4-6).",
        "Broken bonds and rejected care":
            "The shepherd's two staffs, Favor and Union, are broken one after another, dramatizing a "
            "canceled covenant and a ruptured bond between Judah and Israel, while the shepherd himself is "
            "paid an insulting thirty pieces of silver (11:7-14).",
        "Accountability for abusive shepherds":
            "The chapter closes with judgment pronounced on a foolish shepherd who abandons the vulnerable "
            "sheep to feed himself instead (11:15-17).",
    },
    12: {
        "Protection in crisis":
            "Jerusalem becomes a cup of staggering and an immovable stone for every nation that gathers "
            "against it, with the LORD himself confounding the attackers and strengthening Judah (12:2-9).",
        "Grace and turning to God":
            "In the middle of describing a siege, the LORD promises to pour out a spirit of grace and "
            "supplication on the house of David and Jerusalem (12:10).",
        "Communal grief and recognition":
            "That outpoured grace produces intense, specific mourning, named family by family, over one "
            "who has been pierced (12:10-14).",
    },
    13: {
        "Cleansing from sin and impurity":
            "A fountain is opened specifically for the house of David and Jerusalem to wash away sin and "
            "impurity, alongside the removal of idols and an unclean spirit from the land (13:1-2).",
        "Danger of deceptive prophecy":
            "False prophecy is treated as serious enough that even a prophet's own parents are pictured "
            "rejecting him for speaking falsely in God's name (13:3-6).",
        "Suffering, refining and covenant renewal":
            "A sword strikes the LORD's own shepherd and scatters the flock, yet a tested remnant survives "
            "the ordeal and renews the covenant: they are his people, and he is their God (13:7-9).",
    },
    14: {
        "The LORD’s worldwide kingship":
            "Once the LORD's feet stand on the Mount of Olives and it splits in two, he is proclaimed king "
            "over all the earth, with one LORD and one name acknowledged everywhere (14:8-9).",
        "Judgment and survival":
            "Jerusalem suffers heavy losses under siege, but the attacking nations themselves face plague "
            "and panic while the city endures (14:1-5,12-15).",
        "Worship among the nations":
            "Survivors from the very nations that attacked Jerusalem are pictured returning year after "
            "year to worship the LORD of hosts and keep the Feast of Booths (14:16-19).",
        "Holiness encompassing ordinary life":
            "Even the bells on horses and common cooking pots are declared holy to the LORD, erasing the "
            "old boundary between sacred objects and everyday ones (14:20-21).",
    },
}


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "38_zechariah.json"
    data = load(path)
    for n in range(1, 15):
        key = f"Zechariah {n}"
        entry = data[key]
        entry["whereWeAre"] = WWA[n]
        for old, new in SUMMARY_FIXES.get(n, []):
            if old not in entry["summary"]:
                raise SystemExit(f"Zechariah {n}: summary fix not found: {old!r}")
            entry["summary"] = entry["summary"].replace(old, new)
        kept_figures = []
        for fig in entry["keyFigures"]:
            original_name = fig["name"]
            if original_name in DROPPED_FIGURES.get(n, set()):
                continue
            if original_name in ROLE_FIXES.get(n, {}):
                fig["role"] = ROLE_FIXES[n][original_name]
            kept_figures.append(fig)
        entry["keyFigures"] = kept_figures
        theme_map = THEMES[n]
        seen = set()
        for theme in entry["keyThemes"]:
            name = theme["theme"]
            if name not in theme_map:
                raise SystemExit(f"Zechariah {n}: no explanation drafted for theme {name!r}")
            theme["explanation"] = theme_map[name]
            seen.add(name)
        missing = set(theme_map) - seen
        if missing:
            raise SystemExit(f"Zechariah {n}: drafted themes not in source: {missing}")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


AUDIENCE_FIXES = {
    2: ("Returning exiles who had watched Jerusalem's walls lie broken for decades would have heard "
        "this vision not as an excuse to skip rebuilding, but as a promise that the city's future "
        "population and God's own presence would outgrow whatever walls they could build (Zechariah "
        "2:5)."),
    3: ("A community still rebuilding its own worship life would have recognized in Joshua's public "
        "humiliation and cleansing a picture of their own need: the whole nation's standing before God, "
        "not just its high priest's wardrobe, was being renewed."),
    4: ("Workers discouraged by a rebuilding project that looked small next to Solomon's lost temple "
        "would have heard this vision as a direct answer to their own doubts, that the project's success "
        "depended on God's Spirit rather than on the limited manpower and resources actually in their "
        "hands."),
    5: ("A community that had just returned from Babylon would have heard wickedness being physically "
        "sealed up and sent back to Shinar as a pointed reversal: the very land of their exile becomes "
        "the place wrongdoing is exiled to instead."),
    6: ("Exiles who had personally carried silver and gold back from Babylon would have recognized "
        "their own contribution turned into something permanent, a crown kept in the temple as a "
        "memorial rather than spent or stored away."),
    7: ("People who had kept the same mourning fast every year since the exile, almost on autopilot, "
        "would have heard the LORD's answer as a direct challenge: the ritual itself was never the "
        "point, and justice and mercy mattered more than the calendar being followed correctly."),
    8: ("People who could still remember exactly which siege, breach, and assassination each mourning "
        "fast commemorated would have felt the weight of being told those same dates would someday mark "
        "celebration instead, not an abstract promise but a reversal of specific, remembered grief."),
    11: ("Readers who already knew the going rate for an injured slave in the law (Exodus 21:32) would "
         "have recognized thirty pieces of silver as a calculated insult, not a fair wage, the moment they "
         "heard the shepherd's price named."),
    13: ("A community that had lived through false prophets speaking confidently in the LORD's name "
         "would have heard the promise that prophets will one day be ashamed of their own visions as "
         "personally vindicating, not just a future rule but an answer to real deception they had already "
         "experienced."),
    14: ("Worshipers used to the Feast of Booths as their own nation's annual pilgrimage would have "
         "heard this vision as something stranger and larger: survivors from every nation that had once "
         "attacked Jerusalem returning, year after year, to keep that same Israelite feast themselves."),
}

HISTORICAL_MOMENT_FIXES = {
    9: ("Chapters 9–14 have no dates; tradition holds Zechariah wrote them later in his ministry, "
        "though some scholars propose a different origin. This oracle names Hadrach, Damascus, Tyre, the "
        "Philistine cities, and \"thy sons, O Greece\" (Zechariah 9:13)."),
}


def apply_chapter_context():
    path = ROOT / "chapter_context" / "30_nahum_malachi.json"
    data = load(path)
    for n, new_audience in AUDIENCE_FIXES.items():
        key = f"Zechariah {n}"
        old_audience = data[key]["audience"]
        data[key]["audience"] = new_audience
        if old_audience == new_audience:
            raise SystemExit(f"Zechariah {n}: audience fix made no change")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")

    hm_path = ROOT / "historical_moments" / "13_minor_prophets.json"
    hm_data = load(hm_path)
    for n, new_text in HISTORICAL_MOMENT_FIXES.items():
        key = f"Zechariah {n}"
        hm_data[key] = new_text
    save(hm_path, hm_data)
    print(f"Updated {hm_path.relative_to(ROOT)}")


def apply_overview():
    path = ROOT / "book_overviews" / "06_minor_prophets.json"
    data = load(path)
    entry = data["Zechariah"]
    entry["theme"] = entry["theme"].replace(
        "God's people must put His priorities ahead of complacent self-interest; renewed obedience brings "
        "courage and hope.",
        "God's people must put his priorities ahead of complacent self-interest; renewed obedience brings "
        "courage and hope.",
    )
    entry["theme"] = entry["theme"].replace(
        "God's people must put His priorities",
        "God's people must put his priorities",
    )
    entry["theme"] = entry["theme"].replace(
        "God has not abandoned His people; present restoration points toward a larger future work of "
        "cleansing, kingship, and worldwide rule.",
        "God has not abandoned his people; present restoration points toward a larger future work of "
        "cleansing, kingship, and worldwide rule.",
    )
    for fig in entry["keyFigures"]:
        if fig["name"] == "Zerubbabel":
            fig["description"] = fig["description"].replace(
                "The governor promised that the temple will be finished 'not by might, nor by power, but "
                "by my Spirit.'",
                "The governor promised that the temple will be finished \"not by might, nor by power, but "
                "by my spirit.\"",
            )
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_PRONOUN_FIXES = [
    ("If they return to Him, He promises to return to them;",
     "If they return to him, he promises to return to them;"),
    ("Even their ancestors finally admitted that God had treated them just as He had warned.",
     "Even their ancestors finally admitted that God had treated them just as he had warned."),
    ("God Himself will be a wall of fire and dwell within it.",
     "God himself will be a wall of fire and dwell within it."),
    ("God promises His coming Branch.",
     "God promises his coming Branch."),
    ("Afterward, God tells Zechariah to make a crown of silver and gold and place it on Joshua the "
     "high priest. He announces, “Behold the man whose name is The BRANCH",
     "Afterward, God tells Zechariah to make a crown of silver and gold and place it on Joshua the "
     "high priest. he announces, “Behold the man whose name is The BRANCH"),
    ("God questions whether the people's fasting was truly for Him and recalls that earlier "
     "generations rejected justice and compassion. He promises Jerusalem's restoration,",
     "God questions whether the people's fasting was truly for him and recalls that earlier "
     "generations rejected justice and compassion. he promises Jerusalem's restoration,"),
    ("God answers with questions of His own:",
     "God answers with questions of his own:"),
    ("What He wants is the same thing the earlier prophets preached:",
     "What he wants is the same thing the earlier prophets preached:"),
    ("He paints a peaceful picture:",
     "he paints a peaceful picture:"),
    ("God will bring His people home",
     "God will bring his people home"),
    ("He tells them to “Speak ye every man the truth to his neighbour,” and He promises that their "
     "sad fasts will become",
     "he tells them to “Speak ye every man the truth to his neighbour,” and he promises that their "
     "sad fasts will become"),
    ("He will protect and gather His scattered people,",
     "he will protect and gather his scattered people,"),
    ("Jesus fulfilled this when He rode into Jerusalem on Palm Sunday",
     "Jesus fulfilled this when he rode into Jerusalem on Palm Sunday"),
    ("God will save His people, and they will shine",
     "God will save his people, and they will shine"),
    ("In chapter 10, God tells the people to ask Him, not idols or fortune-tellers, for rain.",
     "In chapter 10, God tells the people to ask him, not idols or fortune-tellers, for rain."),
    ("He will strengthen Judah and save the house of Joseph,",
     "he will strengthen Judah and save the house of Joseph,"),
    ("Finally God warns that He will raise up a worthless shepherd",
     "Finally God warns that he will raise up a worthless shepherd"),
    ("God exposes corrupt leadership and rejection of His care.",
     "God exposes corrupt leadership and rejection of his care."),
    ("He will wipe out idols and false prophets from the land.",
     "he will wipe out idols and false prophets from the land."),
    ("On the night He was arrested, Jesus quoted this verse to warn His disciples",
     "On the night he was arrested, Jesus quoted this verse to warn his disciples"),
    ("nations come to worship Him, and holiness extends into ordinary life",
     "nations come to worship him, and holiness extends into ordinary life"),
    ("opening a valley for His people to escape.",
     "opening a valley for his people to escape."),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "06_minor_prophets.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("# Zechariah")
    end = text.index("# Malachi")
    section = text[start:end]
    for old, new in STORY_PRONOUN_FIXES:
        count = section.count(old)
        if count == 0:
            if section.count(new) == 1:
                continue
            raise SystemExit(f"story fix matched 0 times and not already applied: {old!r}")
        if count != 1:
            raise SystemExit(f"story fix matched {count} times (expected 1): {old!r}")
        section = section.replace(old, new)
    path.write_text(text[:start] + section + text[end:], encoding="utf-8")
    print(f"Updated {path.relative_to(ROOT)}")


if __name__ == "__main__":
    apply_chapter_insights()
    apply_chapter_context()
    apply_overview()
    apply_story_fixes()
