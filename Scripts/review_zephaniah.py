#!/usr/bin/env python3
"""Apply the completed editorial review for Zephaniah to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


WWA = {
    1: ("Habakkuk ended by trusting God's character even through hardship still to come (Habakkuk "
        "3:17-19). Zephaniah opens the next book by announcing exactly that still-coming judgment in "
        "detail: during Josiah's reign, before his reforms took hold, the prophet condemns Judah's Baal "
        "worship, astral worship on the rooftops, and the officials, merchants, and complacent people who "
        "assume the LORD will do nothing. That sweeping warning against Judah itself sets up chapter 2's "
        "call to seek the LORD before the coming day of wrath arrives."),
    2: ("Chapter 1 announced a coming day of judgment against Judah's idolatry and complacency, closing "
        "with a warning that wealth cannot buy rescue from it (Zephaniah 1:17-18). Chapter 2 widens that "
        "warning outward, from Judah's own call to seek the LORD in humility to a series of judgments "
        "against neighboring peoples: Philistia to the west, Moab and Ammon to the east, Cush to the south, "
        "and Assyria's capital Nineveh to the north. Nineveh's own proud claim to stand unmatched sets up "
        "chapter 3's return to Jerusalem's unmatched refusal to listen."),
    3: ("Chapter 2 pictured proud Nineveh's confident claim to stand unmatched, a claim judgment will "
        "expose as empty (Zephaniah 2:15). The book's closing chapter turns that same charge back on "
        "Jerusalem: its leaders, judges, prophets, and priests are corrupt, and the city refuses correction "
        "even though the LORD is righteous in its midst. The chapter's turn from judgment to a purified, "
        "rejoicing remnant, with God himself singing over his people, hands off to Haggai, where a very "
        "different struggle, rebuilding the temple after the exile, begins."),
}

NAME_FIXES = {
    3: {"The city / daughter of Zion / Jerusalem": "The city (daughter of Zion, Jerusalem)"},
}

ROLE_FIXES = {
    2: {
        "Philistines and their cities":
            "Western coastal peoples named in the oracle. Gaza, Ashkelon, Ashdod, and Ekron exemplify "
            "neighboring places facing announced devastation (2:4–7).",
        "Cushites, Assyria, and Nineveh":
            "Other named peoples and imperial center. Broaden the oracle to southern and northern powers; "
            "Nineveh epitomizes arrogant imperial confidence (2:12–15).",
    },
}

AUDIENCE_FIXES = {
    1: ("Hearers who worshipped both the LORD and Baal on their own rooftops, or who simply assumed God "
        "would never act either way, would have recognized their own daily habits named directly in this "
        "oracle rather than a distant or hypothetical sin."),
    2: ("Judahites who had themselves been mocked by Philistine, Moabite, and Ammonite neighbors, or who "
        "lived in fear of Assyria's power, would have heard their own oppressors named one by one and "
        "promised the same downfall Judah itself was warned of in chapter 1."),
}

THEMES = {
    1: {
        "Judgment against false worship":
            "The oracle names specific practices, Baal worship, bowing to the host of heaven on rooftops, "
            "and divided loyalty between the LORD and other gods, as the reason judgment is coming (1:4-6).",
        "The day of the LORD as accountability":
            "The coming day is pictured as a solemn sacrifice at which officials, the royal household, and "
            "ordinary people alike will answer for their conduct (1:7-8,14-16).",
        "Violence, deceit, and complacency":
            "Alongside outright violence and fraud, the oracle also condemns those who assume the LORD will "
            "do nothing either way, treating indifference as its own form of wrongdoing (1:9,12-13).",
        "The limits of wealth and security":
            "Silver and gold are named directly as unable to rescue anyone on the day of the LORD's wrath, "
            "since the coming judgment cannot be bought off (1:17-18).",
    },
    2: {
        "Seeking God with humility":
            "Before judgment falls, the humble who already follow God's commands are urged to actively seek "
            "righteousness and humility, with shelter held out as a possibility rather than a guarantee "
            "(2:1-3).",
        "Judgment reaches beyond Judah":
            "The oracle widens from Judah to Philistia, Moab, Ammon, Cush, and Assyria, showing that the "
            "LORD's accountability is not limited to his own covenant people (2:4-5,8-12,13-15).",
        "Pride and mistreatment of neighbors":
            "Moab and Ammon are condemned specifically for taunting and exalting themselves over God's "
            "people, and Nineveh for boasting that no city could compare to it (2:8-10,15).",
        "Hope for a remnant":
            "Even amid judgment on surrounding nations, a surviving remnant of Judah is promised pastureland "
            "and territory once held by those same nations (2:7,9).",
    },
    3: {
        "Accountability for corrupt leadership":
            "Jerusalem's officials, judges, prophets, and priests are each named and charged with specific "
            "failures, predatory rule, deceit, and profaning what is holy (3:1-5).",
        "Refusing correction":
            "Even after watching other nations fall as a warning, the city still would not learn or draw "
            "near to its God, making its judgment a response to persistent refusal, not a single offense "
            "(3:6-7).",
        "Purified and shared worship":
            "God promises to give peoples a purified speech so that they can call on the LORD together, "
            "reversing the scattering of languages at Babel (3:8-10).",
        "Humility, truthfulness, and peaceful life":
            "Pride is removed from the city, leaving a humble and honest remnant who can rest without fear, "
            "like sheep lying down undisturbed (3:11-13).",
        "Divine presence and restoration":
            "The chapter ends with the LORD himself present as king in Zion, rejoicing over his people with "
            "singing and promising to gather the scattered and reverse their shame (3:14-20).",
    },
}


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "36_zephaniah.json"
    data = load(path)
    for n in range(1, 4):
        key = f"Zephaniah {n}"
        entry = data[key]
        entry["whereWeAre"] = WWA[n]
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
                raise SystemExit(f"Zephaniah {n}: no explanation drafted for theme {name!r}")
            theme["explanation"] = theme_map[name]
            seen.add(name)
        missing = set(theme_map) - seen
        if missing:
            raise SystemExit(f"Zephaniah {n}: drafted themes not in source: {missing}")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_chapter_context():
    path = ROOT / "chapter_context" / "30_nahum_malachi.json"
    data = load(path)
    for n, new_audience in AUDIENCE_FIXES.items():
        key = f"Zephaniah {n}"
        old_audience = data[key]["audience"]
        data[key]["audience"] = new_audience
        if old_audience == new_audience:
            raise SystemExit(f"Zephaniah {n}: audience fix made no change")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_overview():
    path = ROOT / "book_overviews" / "06_minor_prophets.json"
    data = load(path)
    entry = data["Zephaniah"]
    entry["movements"][2]["description"] = entry["movements"][2]["description"].replace(
        "The book ends with promises of humble worship, restored fortunes, and divine joy over His people.",
        "The book ends with promises of humble worship, restored fortunes, and divine joy over his people.",
    )
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_PRONOUN_FIXES = [
    ("Then God narrows His aim to Judah and Jerusalem. He will remove what is left of Baal worship, the "
     "idol priests, and “them that worship the host of heaven upon the housetops.” He will also judge "
     "those who try to worship both the LORD and the god Malcham, and those who simply never seek God at "
     "all.",
     "Then God narrows his aim to Judah and Jerusalem. he will remove what is left of Baal worship, the "
     "idol priests, and “them that worship the host of heaven upon the housetops.” he will also judge "
     "those who try to worship both the LORD and the god Malcham, and those who simply never seek God at "
     "all."),
    ("He is after the comfortable people who are “settled on their lees.”",
     "he is after the comfortable people who are “settled on their lees.”"),
    ("So He tells the faithful, “wait ye upon me,” for He will gather the nations and pour out His anger "
     "on the whole earth.",
     "So he tells the faithful, “wait ye upon me,” for he will gather the nations and pour out his anger "
     "on the whole earth."),
    ("These survivors will trust in His name, reject lies and wrongdoing",
     "These survivors will trust in his name, reject lies and wrongdoing"),
    ("God promises to remove shame, gather the scattered, defeat oppressors, and dwell among His people.",
     "God promises to remove shame, gather the scattered, defeat oppressors, and dwell among his people."),
    ("In other words, God Himself sings over His people. He will rescue the lame, gather the outcasts, "
     "and turn their shame into praise.",
     "In other words, God himself sings over his people. he will rescue the lame, gather the outcasts, "
     "and turn their shame into praise."),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "06_minor_prophets.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("# Zephaniah")
    end = text.index("# Haggai")
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
