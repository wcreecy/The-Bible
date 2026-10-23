#!/usr/bin/env python3
"""Apply the completed editorial review for Joel to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


WWA = {
    1: ("Hosea ended with a call for Israel to return to the LORD and a promise that God would heal their "
        "unfaithfulness (Hosea 14:1–9). Joel opens the next book with a different crisis: a locust plague "
        "and drought so severe that even the grain and drink offerings at the temple have stopped. The prophet "
        "summons the whole community to mourn and declare a fast, setting up his warning in chapter 2 that this "
        "disaster is only a sign of the greater “day of the LORD” still to come."),
    2: ("Chapter 1 described the locust plague's damage and Joel's call for the community to mourn and fast "
        "(Joel 1:1–20). Chapter 2 sounds a trumpet alarm and pictures the coming destruction in the most "
        "vivid terms in the book, then turns from warning to hope: God calls the people to heartfelt repentance "
        "and promises to restore the land and pour out his Spirit on everyone, a promise Peter later quotes at "
        "Pentecost (Acts 2:16–21). That promise of deliverance sets up chapter 3, where the LORD turns from "
        "restoring Judah to judging the nations that wronged it."),
    3: ("Chapter 2 ended with the LORD's promise to pour out his Spirit on all people and save everyone who "
        "calls on his name (Joel 2:28–32). Chapter 3 turns from Judah's restoration to the LORD's judgment "
        "of the nations that scattered Israel and sold its people into slavery, gathering them for sentencing "
        "in the valley of Jehoshaphat. The book closes with the LORD dwelling in Zion forever, completing "
        "Joel's picture of judgment and restoration before Amos, the next book, turns to the LORD's judgment "
        "on Israel and its neighbors in greater detail."),
}

SUMMARY_FIXES = {
    1: [
        ("The shortage disrupts the grain and drink offerings at the house of the LORD (Joel 1:9), Joel 1:13.",
         "The shortage disrupts the grain and drink offerings at the house of the LORD (Joel 1:9, 13)."),
        ("He names the approaching 'day of the LORD' as a time of destruction (Joel 1:15).",
         "He names the approaching “day of the LORD” as a time of destruction (Joel 1:15)."),
        ("Its main message is that a devastating communal crisis calls for serious lament and a collective "
         "turning toward God; the text does not give an independent historical date for the disaster.",
         "Joel gives no date for the disaster; his point is that a crisis this size calls for serious lament "
         "and a collective turning back to God."),
    ],
    2: [
        ("Whether this imagery extends the locust plague, portrays human invaders, or deliberately combines "
         "both remains debated.",
         "The imagery may extend the locust plague into something larger, picture a human army, or "
         "deliberately combine both into one picture of unstoppable judgment."),
        ("and to 'rend your heart, and not your garments' (Joel 2:12–13).",
         "and to “rend your heart, and not your garments” (Joel 2:12–13)."),
        ("The chapter connects sincere repentance, promised restoration, and wider participation in God's "
         "Spirit; its images and fulfillment are read differently among religious traditions.",
         "The chapter connects sincere repentance, promised restoration, and wider participation in God's "
         "Spirit, a promise the New Testament identifies with the day of Pentecost (Acts 2:16–21)."),
    ],
    3: [
        ("God summons nations to the 'valley of Jehoshaphat' because, according to the oracle,",
         "God summons nations to the “valley of Jehoshaphat” because, according to the oracle,"),
        ("Its central contrast is judgment on oppressive nations and hope for Zion; details such as the "
         "valley's precise location and fulfillment timetable are not established by the text.",
         "The chapter's central contrast is judgment on the nations that wronged God's people and lasting "
         "hope for Zion that outlasts the locusts and armies described in chapters 1–2."),
    ],
}

NAME_FIXES = {
    2: {
        "Northern army/approaching host": "Northern army",
        "People of Zion/Judah and Jerusalem": "People of Zion (Judah and Jerusalem)",
    },
}

ROLE_FIXES = {
    3: {
        "Greeks and Sabeans":
            "Groups mentioned in trade and reversal imagery. Greeks are named as buyers of exiles; Sabeans "
            "appear in the announced retaliatory sale (3:6, 8)",
    },
}

THEMES = {
    1: {
        "Shared suffering and the memory of disaster":
            "Joel tells the elders to pass this disaster down to their children and grandchildren, since "
            "living through something this severe together becomes part of the community's own memory of "
            "God's dealings with it (1:2-3).",
        "The fragility of material security":
            "Wine, grain, and fruit trees that everyone depended on for daily life disappear almost "
            "overnight, showing how quickly comfort and security can be stripped away (1:5-12).",
        "Worship amid a broken economy":
            "With no grain or wine left to bring, the regular offerings at the temple stop; Joel calls the "
            "priests to lead a fast and solemn assembly instead, since worship must continue even when the "
            "usual gifts cannot be given (1:9-14).",
        "The day of the LORD and lament":
            "Joel reads the locust plague and drought as a warning sign of a greater reckoning still to come, "
            "and responds by crying out to God rather than despairing (1:15-20).",
    },
    2: {
        "The day of the LORD and urgent warning":
            "Joel sounds a trumpet alarm and pictures an overwhelming force sweeping the land bare, framing "
            "the advancing danger as proof that the day of the LORD is close and unstoppable (2:1-11).",
        "Heartfelt repentance and mercy":
            "God calls for inward change, not only the outward signs of mourning, and summons every person "
            "in the community, even newlyweds, to the fast (2:12-17).",
        "Compassion and restoration":
            "Once the people turn back, the LORD responds with pity, driving off the destroying force and "
            "restoring the very years of harvest the locusts had eaten (2:18-27).",
        "The Spirit shared across the community":
            "God promises to pour out his Spirit without regard to age, sex, or social status, a promise "
            "Peter later applies to the day of Pentecost (2:28-29).",
        "Calling on the LORD amid judgment":
            "Alongside cosmic signs announcing the day of the LORD, Joel promises that anyone who calls on "
            "the LORD's name, not only a select few, will be saved (2:30-32).",
    },
    3: {
        "Accountability for violence and exploitation":
            "The LORD charges the nations with scattering his people, dividing their land, and selling "
            "children for the price of wine or a prostitute, and promises to return the same treatment on "
            "their own heads (3:1-8).",
        "The day of the LORD as judgment":
            "Joel ironically summons the nations to arm themselves for war, since gathering for battle only "
            "brings them to the harvest and winepress of God's judgment (3:9-15).",
        "God as refuge for his people":
            "Even as the earth shakes, the LORD is described as a shelter and stronghold for Israel, "
            "dwelling in Zion rather than abandoning his people (3:16-17).",
        "Renewal and enduring presence":
            "The book closes with pictures of overflowing abundance and a spring flowing from God's house, "
            "promising that Judah and Jerusalem will endure forever because the LORD dwells there (3:18-21).",
    },
}

AUDIENCE_FIXES = {
    3: "People whose relatives had been sold into slavery for the price of a drink would hear this oracle as "
       "reassurance that the LORD keeps a ledger: every nation that profited from their suffering, named one "
       "by one, would answer for it, while their own displaced community would finally rest secure in "
       "Jerusalem (Joel 3:1–8).",
}

OVERVIEW_FIX = (
    "The 'ministers of the altar,' summoned to lead the people in fasting and prayer.",
    "The “ministers of the altar,” summoned to lead the people in fasting and prayer.",
)


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "29_joel.json"
    data = load(path)
    for n in range(1, 4):
        key = f"Joel {n}"
        entry = data[key]
        entry["whereWeAre"] = WWA[n]
        for old, new in SUMMARY_FIXES.get(n, []):
            if old not in entry["summary"]:
                raise SystemExit(f"Joel {n}: summary fix not found: {old!r}")
            entry["summary"] = entry["summary"].replace(old, new)
        for fig in entry["keyFigures"]:
            if fig["name"] in NAME_FIXES.get(n, {}):
                fig["role"] = ROLE_FIXES.get(n, {}).get(fig["name"], fig["role"])
                fig["name"] = NAME_FIXES[n][fig["name"]]
            elif fig["name"] in ROLE_FIXES.get(n, {}):
                fig["role"] = ROLE_FIXES[n][fig["name"]]
        theme_map = THEMES[n]
        seen = set()
        for theme in entry["keyThemes"]:
            name = theme["theme"]
            if name not in theme_map:
                raise SystemExit(f"Joel {n}: no explanation drafted for theme {name!r}")
            theme["explanation"] = theme_map[name]
            seen.add(name)
        missing = set(theme_map) - seen
        if missing:
            raise SystemExit(f"Joel {n}: drafted themes not in source: {missing}")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_chapter_context():
    path = ROOT / "chapter_context" / "29_hosea_micah.json"
    data = load(path)
    for n, text in AUDIENCE_FIXES.items():
        data[f"Joel {n}"]["audience"] = text
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_overview():
    path = ROOT / "book_overviews" / "06_minor_prophets.json"
    data = load(path)
    entry = data["Joel"]
    old, new = OVERVIEW_FIX
    found = False
    for fig in entry["keyFigures"]:
        if old in fig["description"]:
            fig["description"] = fig["description"].replace(old, new)
            found = True
    if not found:
        raise SystemExit(f"overview fix not found: {old!r}")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_PRONOUN_FIXES = [
    ("Even as judgment approaches, God calls the people to return with all their hearts through fasting, "
     "mourning, and prayer. He seeks hearts changed within, not only outward signs of grief, and summons "
     "every part of the nation to seek His mercy.",
     "Even as judgment approaches, God calls the people to return with all their hearts through fasting, "
     "mourning, and prayer. he seeks hearts changed within, not only outward signs of grief, and summons "
     "every part of the nation to seek his mercy."),
    ("God promises pity for His people, renewed grain, wine, oil, rain, and fruitful fields. He will remove "
     "the destructive force and restore the years consumed by locusts, so Judah will know that the Lord is "
     "present among them.",
     "God promises pity for his people, renewed grain, wine, oil, rain, and fruitful fields. he will remove "
     "the destructive force and restore the years consumed by locusts, so Judah will know that the Lord is "
     "present among them."),
    ("He will send grain, wine, and oil again and drive the invading army away into the desert.",
     "he will send grain, wine, and oil again and drive the invading army away into the desert."),
    ("God promises to pour out His Spirit on people of every generation and social position, with sons and "
     "daughters prophesying and servants included.",
     "God promises to pour out his Spirit on people of every generation and social position, with sons and "
     "daughters prophesying and servants included."),
    ("His Spirit will come even on servants, men and women alike.",
     "his Spirit will come even on servants, men and women alike."),
    ("God gathers nations for judgment because they scattered His people, divided their land, and traded "
     "their lives.",
     "God gathers nations for judgment because they scattered his people, divided their land, and traded "
     "their lives."),
    ("When God restores His people, He will also judge the nations that hurt them. He will gather them in "
     "“the valley of Jehoshaphat,” a name that means the LORD judges.",
     "When God restores his people, he will also judge the nations that hurt them. he will gather them in "
     "“the valley of Jehoshaphat,” a name that means the LORD judges."),
    ("In a reversal of Isaiah's famous promise of peace, He says,",
     "In a reversal of Isaiah's famous promise of peace, he says,"),
    ("But for His own people, “the LORD will be the hope of his people, and the strength of the "
     "children of Israel.”",
     "But for his own people, “the LORD will be the hope of his people, and the strength of the "
     "children of Israel.”"),
    ("while God promises an enduring future for His people.",
     "while God promises an enduring future for his people."),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "06_minor_prophets.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("# Joel")
    end = text.index("# Amos")
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
