#!/usr/bin/env python3
"""Apply the completed editorial review for Habakkuk to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


WWA = {
    1: ("Nahum closed with Nineveh's fall celebrated by the nations it had oppressed (Nahum 3:18-19). "
        "Habakkuk opens the next book by turning that same demand for justice inward: instead of celebrating "
        "judgment on a foreign empire, the prophet asks why violence and a weakened law go unanswered within "
        "Judah itself. The LORD's unsettling answer, that he is raising up the Chaldeans to deal with it, "
        "sets up Habakkuk's harder second question that runs through the rest of the chapter and into chapter "
        "2."),
    2: ("Chapter 1 ended with the LORD announcing that he would raise up the Chaldeans as judgment, leaving "
        "Habakkuk to ask how a holy God could use so violent a nation to punish a people more righteous than "
        "itself (Habakkuk 1:12-17). Chapter 2 is the LORD's answer: Habakkuk is told to write the vision "
        "plainly and wait for it, and a series of woes names exactly how Babylon's own violence, "
        "exploitation, and idolatry will bring its downfall. That coming judgment, and the promise that the "
        "just will live by faith, sets up chapter 3's closing prayer."),
    3: ("Chapter 2 answered Habakkuk's protest with woes against Babylon's violence and a call for the earth "
        "to keep silence before the LORD in his holy temple (Habakkuk 2:20). The book's closing chapter turns "
        "that answer into prayer: Habakkuk recalls God's past deliverance in awesome, earth-shaking terms, "
        "trembles at the judgment still to come, and resolves to rejoice in God even if every crop and animal "
        "fails. That resolve to trust God's character even when his methods are hard to understand hands off "
        "to Zephaniah, where the prophet announces that the great day of the LORD is near."),
}

NAME_FIXES = {
    3: {"The LORD / God / Holy One": "The LORD (God, Holy One)"},
}

ROLE_FIXES = {
    2: {
        "Habakkuk":
            "Prophetic watcher and receiver of the vision. Waits for a response and is told to record the "
            "message (2:1–2).",
        "The proud oppressor":
            "Primary addressee of the woes, described rather than personally named. Accumulates plunder, "
            "builds unjustly, humiliates others, and trusts false gods (2:5–19); the wider context points to "
            "Babylon but no king is named here.",
    },
    3: {
        "Habakkuk":
            "Prophet, psalmist, and first-person prayer speaker. Begins in fear, asks for mercy, recounts "
            "divine saving power, and resolves to rejoice despite loss (3:1–2,16–19).",
        "God’s people and anointed one":
            "Beneficiaries named in the poetic remembrance of salvation. They are identified in 3:13 as those "
            "for whom God goes forth to save, with \"thine anointed\" read as the king's office rather than "
            "one specific named ruler.",
    },
}

THEMES = {
    1: {
        "Honest lament before God":
            "Habakkuk's opening complaint models bringing real grievances, violence, injustice, a weakened "
            "law, directly to God rather than suppressing them (1:2-4).",
        "Divine action that challenges expectations":
            "The LORD's answer is not comfort but a warning: he is about to do something so startling that "
            "Habakkuk would not believe it if simply told (1:5-6).",
        "The danger of arrogant power":
            "The Chaldeans are described as swift, feared, and scoffing at kings, a nation that makes its own "
            "strength its god rather than acknowledging the LORD (1:7-11,15-17).",
        "The dilemma of suffering under worse oppressors":
            "Habakkuk's second question is sharper than his first: how can a holy God use a nation more "
            "wicked than Judah to punish Judah (1:12-13).",
    },
    2: {
        "Patient faithfulness while waiting":
            "Habakkuk is told to write the vision plainly and wait for its appointed time; the righteous are "
            "defined by living through faith rather than demanding an immediate answer (2:1-4).",
        "Exploitation produces unstable security":
            "The first woes condemn gaining wealth and safety through violence and dishonest gain, security "
            "that will not hold because the robbed nations will rise up (2:6-11).",
        "Bloodshed cannot secure lasting glory":
            "A city built with blood and iniquity will not last, while the earth will instead be filled with "
            "the knowledge of the LORD's glory (2:12-14).",
        "Humiliation and destruction are condemned":
            "Shaming a neighbor and destroying Lebanon's land and animals both turn back on the one who does "
            "them (2:15-17).",
        "Living God versus powerless idols":
            "Idols of wood and stone cannot teach or breathe, a direct contrast with the LORD who is present "
            "in his holy temple and before whom the earth must keep silence (2:18-20).",
    },
    3: {
        "Prayer that makes room for awe and mercy":
            "Habakkuk's prayer holds together fear at what he has heard and a plea for God to remember mercy "
            "in the midst of wrath (3:1-2).",
        "Divine power portrayed through creation imagery":
            "God's approach is pictured through mountains, waters, plague, and light, imagery of a divine "
            "warrior whose power reaches over all creation (3:3-11).",
        "Deliverance and opposition to destructive power":
            "God goes forth for the salvation of his people and strikes down the head of the wicked house, "
            "framing judgment on the oppressor as the flip side of rescue for the oppressed (3:12-15).",
        "Fear and faith can coexist":
            "Habakkuk trembles bodily at what is coming, yet still resolves to wait quietly, showing that "
            "real fear and real trust are not opposites (3:16).",
        "Joy even without material security":
            "Even if every crop fails and every flock is gone, Habakkuk chooses to rejoice in the God of his "
            "salvation rather than in harvests or herds (3:17-19).",
    },
}


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "35_habakkuk.json"
    data = load(path)
    for n in range(1, 4):
        key = f"Habakkuk {n}"
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
                raise SystemExit(f"Habakkuk {n}: no explanation drafted for theme {name!r}")
            theme["explanation"] = theme_map[name]
            seen.add(name)
        missing = set(theme_map) - seen
        if missing:
            raise SystemExit(f"Habakkuk {n}: drafted themes not in source: {missing}")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_overview():
    path = ROOT / "book_overviews" / "06_minor_prophets.json"
    data = load(path)
    entry = data["Habakkuk"]
    entry["theme"] = entry["theme"].replace(
        "Faith trusts God's justice and character even when His timing and methods are difficult to "
        "understand.",
        "Faith trusts God's justice and character even when his timing and methods are difficult to "
        "understand.",
    )
    entry["movements"][0]["description"] = entry["movements"][0]["description"].replace(
        "Habakkuk asks why God seems to tolerate injustice among His people.",
        "Habakkuk asks why God seems to tolerate injustice among his people.",
    )
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_PRONOUN_FIXES = [
    ("God answers that He is raising the fierce Babylonians to bring judgment",
     "God answers that he is raising the fierce Babylonians to bring judgment"),
    ("yet asks how He can use a nation more wicked than Judah to punish His people.",
     "yet asks how he can use a nation more wicked than Judah to punish his people."),
    ("recalls His power over creation and His past deliverance of His people.",
     "recalls his power over creation and his past deliverance of his people."),
    ("Then he remembers how God came to rescue His people in the past, from the wilderness of Sinai:",
     "Then he remembers how God came to rescue his people in the past, from the wilderness of Sinai:"),
    ("God marched out to save His people and crush the wicked.",
     "God marched out to save his people and crush the wicked."),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "06_minor_prophets.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("# Habakkuk")
    end = text.index("# Zephaniah")
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
