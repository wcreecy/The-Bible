#!/usr/bin/env python3
"""Apply the completed editorial review for Nahum to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


WWA = {
    1: ("Micah ended with praise for the God who casts sin into the depths of the sea and keeps his ancient "
        "promises (Micah 7:18–20). Nahum opens the next book by turning that same God's power against "
        "Nineveh, the Assyrian capital that had oppressed Judah for a century: a hymn describes the LORD as "
        "patient yet certain to punish evil, and as a refuge for those who trust him. That hymn's good news "
        "for Judah, relief from Assyria's yoke, sets up the vivid siege scene of chapter 2, where Nineveh's "
        "fall is pictured in detail."),
    2: ("Chapter 1 promised that Judah's oppressor would be broken and that a messenger would announce peace "
        "(Nahum 1:12–15). Chapter 2 pictures exactly how that promise plays out: an unnamed attacker "
        "overwhelms Nineveh's defenses, plunders its silver and gold, and leaves the city, once pictured as "
        "a den overflowing with lions' prey, completely empty. That image of imperial strength emptied out "
        "continues in chapter 3, which lists the specific violence and deceit that earned Nineveh this "
        "judgment."),
    3: ("Chapter 2 pictured Nineveh's defenses overwhelmed and its wealth plundered (Nahum 2:1–13). The "
        "book's final chapter names exactly why: Nineveh is a city built on bloodshed, lies, and "
        "exploitation, no safer than Thebes, a great Egyptian city that fell despite its own strong defenses "
        "and allies. The book ends with Nineveh's wound declared incurable and the nations it oppressed "
        "rejoicing at its fall, handing off to Habakkuk, the next book, where a prophet in Judah questions "
        "how long God will let violence and injustice continue at all."),
}

SUMMARY_FIXES = {
    2: [
        ("The rapid siege scenes are prophetic war poetry; their colorful details should not automatically "
         "be treated as independently verified details of the siege of 612 BCE.",
         "The rapid siege scenes are prophetic war poetry, vivid rather than a tactical record of the actual "
         "612 BCE siege."),
    ],
    3: [
        ("an accusation against the 'bloody city,' characterized by deceit, theft, and continuing plunder",
         "an accusation against the \"bloody city,\" characterized by deceit, theft, and continuing plunder"),
        ("The closing lament addresses the 'king of Assyria' directly",
         "The closing lament addresses the \"king of Assyria\" directly"),
        ("The passage condemns exploitation; it should not be simplified into a modern endorsement of "
         "indiscriminate violence.",
         "The passage condemns exploitation and cruelty as Nineveh's own crimes, not as a model for conduct "
         "today."),
    ],
}

NAME_FIXES = {
    1: {"The oppressor / adversaries": "The oppressor"},
    2: {"The attacker / destroyer": "The attacker"},
    3: {
        "Nineveh / the bloody city": "Nineveh (the bloody city)",
        "No-amon / Thebes": "No-amon (Thebes)",
        "The nations / peoples harmed by Assyria": "The nations",
    },
}

ROLE_FIXES = {
    1: {
        "Nahum the Elkoshite":
            "Prophet named in the heading. Identified as the recipient or bearer of the oracle against "
            "Nineveh (1:1).",
        "Nineveh":
            "Assyrian imperial capital named as the target of the oracle. Sets the book’s larger target, "
            "though not repeated by name in the chapter’s poetry (1:1).",
    },
    2: {
        "The LORD":
            "Speaker of the closing judgment declaration. Opposes Nineveh’s destructive military and "
            "predatory might (2:13).",
    },
}

THEMES = {
    1: {
        "Justice and divine patience":
            "The hymn holds together two truths about the LORD: he takes vengeance on his adversaries, yet "
            "he is also slow to anger, so that patience and justice are not opposites but both part of his "
            "character (1:2-3).",
        "God as refuge amid upheaval":
            "Even as mountains quake and the earth trembles at the LORD's presence, the same God is called a "
            "stronghold who knows those who take refuge in him (1:5-7).",
        "Limits of oppressive power":
            "Whatever Nineveh imagines against the LORD will not succeed a second time, and the yoke it has "
            "placed on Judah will finally be broken (1:9-13).",
        "Deliverance and renewed worship":
            "Judah's relief is pictured concretely: a messenger brings good news over the mountains, and the "
            "people are told to keep their festivals again now that the oppressor is gone (1:12-15).",
    },
    2: {
        "The reversal of imperial security":
            "Nineveh's own defenders are told to guard the fortress and prepare for battle, showing a city "
            "once feared now reduced to scrambling defense (2:1-5).",
        "Restoration after plunder":
            "Even while Nineveh is under attack, the LORD promises to restore the splendor of Jacob and "
            "Israel, nations that Assyria itself had previously plundered (2:1-2).",
        "The emptiness of stolen wealth":
            "Despite the silver and gold seized by the attackers, the city is left \"empty, and void, and "
            "waste,\" showing that plunder brings no lasting security even to the victors (2:8-10).",
        "Predatory power brought to account":
            "Nineveh's kings liked to picture themselves as lions filling their den with prey, but the LORD "
            "declares himself against that same den, promising to silence its chariots and messengers "
            "(2:11-13).",
    },
    3: {
        "Violence and deceit judged":
            "Nahum names Nineveh's own crimes directly, bloodshed, lies, and plunder, before ever describing "
            "its punishment, making clear that judgment answers specific wrongdoing (3:1-4).",
        "Public accountability of empire":
            "The LORD promises to expose Nineveh's shame publicly, in front of the nations and kingdoms it "
            "once dominated, rather than letting its downfall happen quietly (3:5-7).",
        "Historical warning from Thebes":
            "Pointing to Thebes, a city with rivers, allies, and real strength that still fell to Assyria "
            "itself, Nahum argues that Nineveh's own defenses offer no guarantee against the same fate "
            "(3:8-11).",
        "Fragility of defenses and commercial strength":
            "Fortresses compared to fig trees ready to drop their fruit, and merchants as numerous as "
            "locusts, both turn out to offer no real protection when the LORD's judgment comes (3:12-17).",
        "The human cost of imperial rule":
            "The book closes by naming Assyria's own king directly and noting that the nations celebrating "
            "its fall had all suffered under its continual cruelty, making Nineveh's crimes, not just its "
            "power, the real subject of the book (3:18-19).",
    },
}


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "34_nahum.json"
    data = load(path)
    for n in range(1, 4):
        key = f"Nahum {n}"
        entry = data[key]
        entry["whereWeAre"] = WWA[n]
        for old, new in SUMMARY_FIXES.get(n, []):
            if old not in entry["summary"]:
                raise SystemExit(f"Nahum {n}: summary fix not found: {old!r}")
            entry["summary"] = entry["summary"].replace(old, new)
        for fig in entry["keyFigures"]:
            original_name = fig["name"]
            if original_name in NAME_FIXES.get(n, {}):
                fig["role"] = ROLE_FIXES.get(n, {}).get(original_name, fig["role"])
                fig["name"] = NAME_FIXES[n][original_name]
            elif original_name in ROLE_FIXES.get(n, {}):
                fig["role"] = ROLE_FIXES[n][original_name]
        theme_map = THEMES[n]
        seen = set()
        for theme in entry["keyThemes"]:
            name = theme["theme"]
            if name not in theme_map:
                raise SystemExit(f"Nahum {n}: no explanation drafted for theme {name!r}")
            theme["explanation"] = theme_map[name]
            seen.add(name)
        missing = set(theme_map) - seen
        if missing:
            raise SystemExit(f"Nahum {n}: drafted themes not in source: {missing}")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_overview():
    path = ROOT / "book_overviews" / "06_minor_prophets.json"
    data = load(path)
    entry = data["Nahum"]
    entry["movements"][0]["description"] = entry["movements"][0]["description"].replace(
        "An opening poem presents God as patient yet just, powerful yet a refuge for those who trust Him.",
        "An opening poem presents God as patient yet just, powerful yet a refuge for those who trust him.",
    )
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_PRONOUN_FIXES = [
    ("while God is a refuge for those who trust Him and promises Judah relief from Assyrian oppression.",
     "while God is a refuge for those who trust him and promises Judah relief from Assyrian oppression."),
    ("Nahum's message is that God will now judge it. “God is jealous, and the LORD revengeth.” In other "
     "words, He will not let evil win.",
     "Nahum's message is that God will now judge it. “God is jealous, and the LORD revengeth.” In other "
     "words, he will not let evil win."),
    ("Storms, mountains, and seas shake before Him: “Who can stand before his indignation?”",
     "Storms, mountains, and seas shake before him: “Who can stand before his indignation?”"),
    ("Yet the same God is safe shelter for His people: “The LORD is good, a strong hold in the day of "
     "trouble; and he knoweth them that trust in him.” He tells Judah, which had suffered under Assyria for "
     "a century,",
     "Yet the same God is safe shelter for his people: “The LORD is good, a strong hold in the day of "
     "trouble; and he knoweth them that trust in him.” he tells Judah, which had suffered under Assyria for "
     "a century,"),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "06_minor_prophets.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("# Nahum")
    end = text.index("# Habakkuk")
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
    apply_overview()
    apply_story_fixes()
