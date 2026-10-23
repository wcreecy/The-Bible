#!/usr/bin/env python3
"""Apply the completed editorial review for Obadiah to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


WWA = ("Amos ended with a promise to restore and resettle Israel under David's line (Amos 9:11–15). Obadiah, "
       "the shortest Old Testament book, turns to Edom, condemning Judah's relative for standing aside and "
       "even joining in when Jerusalem fell, and broadens that specific grievance into the \"day of the "
       "LORD\" coming on every nation. Its closing promise that deliverance and holiness will return to Mount "
       "Zion anticipates Jonah, the next book, where God's mercy reaches an entirely different enemy nation, "
       "Nineveh, instead of judgment alone.")

SUMMARY = (
    "Obadiah records a vision concerning Edom, Judah's neighbor and kin through Esau. The LORD announces "
    "that pride has deceived Edom, since no rocky stronghold can shield it from being brought down "
    "(Obadiah 1:1–4). Thieves and grape gatherers normally leave something behind, but Edom will be searched "
    "and stripped completely, and even its allies will betray it (Obadiah 1:5–9). The charge is not merely "
    "that Edom failed to help: it stood aloof while foreigners entered Jerusalem, celebrated Judah's "
    "calamity, looted its possessions, blocked escape routes, and handed over survivors (Obadiah 1:10–14). "
    "The prophecy then widens from Edom's own case to the \"day of the LORD\" coming on all nations, "
    "applying a single rule of justice: what a nation has done will be done to it in return "
    "(Obadiah 1:15–16). The closing vision promises escape and holiness on Mount Zion, victory for the house "
    "of Jacob over the house of Esau, restored and enlarged territory for Israel and Judah, and the LORD's "
    "own kingship over all (Obadiah 1:17–21). The book's central message is that pride and betrayal of a "
    "vulnerable neighbor will not escape judgment, while the LORD's people and his reign will ultimately "
    "prevail."
)

NAME_FIXES = {
    "Edom / the house of Esau": "Edom (the house of Esau)",
    "The nations and those who escape / deliverers": "The nations and those who escape (deliverers)",
}

MERGE_NAME = "Jacob / house of Jacob and house of Joseph"
MERGE_WITH = "People of Judah, Jerusalem, and Zion"
MERGED_FIGURE = {
    "name": "Jacob (Judah, Jerusalem, and Zion)",
    "role": ("Ancestral and geographic names for God's people across the oracle. Called Edom's brother in "
             "the accusation, suffer the invasion and looting described, and become the site of deliverance, "
             "holiness, and restored possession in the closing promise (1:10–14, 17–18, 20–21)."),
}

ROLE_FIXES = {
    "Foreign invaders and Edom’s allies":
        "Unnamed foreign groups in the prophetic account. Foreigners entered Jerusalem and cast lots, while "
        "Edom’s supposed allies are portrayed as unreliable (1:7, 11). They are not individually identified.",
}

THEMES = {
    "Pride and misplaced security":
        "Edom trusts its high, rocky dwellings to keep it safe, but the LORD insists no height is too high "
        "for him to bring down (1:2-4, 1:8-9).",
    "False confidence in political alliances":
        "The allies and trading partners Edom relied on are the very ones who deceive it and drive it to the "
        "border, showing that political alliances offer no real security against God's judgment (1:5-7).",
    "Responsibility toward neighbors in distress":
        "Edom's guilt is not only active violence but standing aloof, looting, blocking escape routes, and "
        "handing over survivors while its brother nation suffered (1:10-14).",
    "Justice and the day of the LORD":
        "Edom's specific punishment becomes an example of a universal rule: the day of the LORD applies to "
        "every nation, and what a nation has done will be done to it in return (1:15-16).",
    "Hope, holiness, and the LORD’s kingship":
        "The book ends by widening from Edom's fall to a positive vision of Zion's holiness, restored "
        "territory for God's people, and the LORD reigning as king over all (1:17-21).",
}


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "31_obadiah.json"
    data = load(path)
    entry = data["Obadiah 1"]
    entry["whereWeAre"] = WWA
    entry["summary"] = SUMMARY

    figures = entry["keyFigures"]
    names = [fig["name"] for fig in figures]
    if MERGE_NAME in names:
        rebuilt = []
        for fig in figures:
            if fig["name"] == MERGE_NAME:
                rebuilt.append(MERGED_FIGURE)
            elif fig["name"] == MERGE_WITH:
                continue
            else:
                rebuilt.append(fig)
        figures[:] = rebuilt
    elif not any(fig["name"] == MERGED_FIGURE["name"] for fig in figures):
        raise SystemExit("merge source figure not found and merge not already applied")

    for fig in figures:
        if fig["name"] in NAME_FIXES:
            fig["name"] = NAME_FIXES[fig["name"]]
        elif fig["name"] in ROLE_FIXES:
            fig["role"] = ROLE_FIXES[fig["name"]]

    seen = set()
    for theme in entry["keyThemes"]:
        name = theme["theme"]
        if name not in THEMES:
            raise SystemExit(f"no explanation drafted for theme {name!r}")
        theme["explanation"] = THEMES[name]
        seen.add(name)
    missing = set(THEMES) - seen
    if missing:
        raise SystemExit(f"drafted themes not in source: {missing}")

    if len(figures) > 6:
        raise SystemExit(f"still too many key figures: {len(figures)}")

    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


if __name__ == "__main__":
    apply_chapter_insights()
