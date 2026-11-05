#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Targeted quality pass for Ezra: plain wording, distinct Original Audience text, small story fixes.

Run once, after review_ezra.py (if present).
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def replace_once(text, old, new, label):
    if text.count(old) == 0 and text.count(new) >= 1:
        return text
    if text.count(old) != 1:
        raise SystemExit(f"{label}: {text.count(old)} matches for {old!r}")
    return text.replace(old, new)


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "15_ezra.json"
    data = load(path)
    six = data["Ezra 6"]
    six["summary"] = replace_once(six["summary"], "offer twelve he goats for all Israel", "offer twelve male goats for all Israel", "Ezra 6 summary")
    seven = data["Ezra 7"]
    seven["whereWeAre"] = replace_once(
        seven["whereWeAre"],
        "\"had prepared his heart to seek the law of the LORD\" (Ezra 7:10). Chapter 8",
        "\"had prepared his heart to seek the law of the LORD.\" Chapter 8",
        "Ezra 7 where we are",
    )
    ten = data["Ezra 10"]
    for figure in ten["keyFigures"]:
        if figure["name"] == "Jonathan and Jahaziah":
            figure["role"] = replace_once(
                figure["role"],
                "Named in Ezra 10:15 in connection with the plan; the Hebrew word can mean they stood for it or against it.",
                "Are named in the handling of the matter; the Hebrew can be read as helping with it or as opposing it.",
                "Ezra 10 role",
            )
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


# Original Audience text: who first heard it and what they knew (numbers, places, and dates stay in the moment).
AUDIENCE = {
    2: "The first readers were the families who came home, so they could find their own clans and towns in this register. They heard that serving as a priest depended on proof of family.",
    3: "The first readers knew the mixed feelings of this day, the shouts of joy and the weeping of old men who had seen the first temple (Ezra 3:12). They heard that worship began again before the building did.",
    4: "The first readers knew what it was to have neighbors who opposed the rebuilding. They heard that the writer gathered later letters here to show how long the opposition lasted.",
    5: "The first readers knew the messages of Haggai and Zechariah from the books that bear their names. They heard that a governor questioned the work and could not stop it.",
    9: "The first readers knew the old law against marrying those who served other gods (Deuteronomy 7:3–4). They heard Ezra pray for the whole community, saying \"our iniquities\" though he had not done it himself.",
}


def apply_chapter_context():
    path = ROOT / "chapter_context" / "15_ezra_nehemiah.json"
    data = load(path)
    for number, text in AUDIENCE.items():
        data[f"Ezra {number}"]["audience"] = text
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_book_overview():
    path = ROOT / "book_overviews" / "03_later_history.json"
    data = load(path)
    book = data["Ezra"]
    book["author"] = replace_once(
        book["author"],
        "Ezra, according to Jewish tradition. Parts of chapters 7–9",
        "Jewish tradition credits Ezra. Ezra and Nehemiah were once one book. Parts of chapters 7–9",
        "author",
    )
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_FIXES = [
    ("the officials hurry to Jerusalem and force the Jews to stop by force.", "the officials hurry to Jerusalem and make the Jews stop by force."),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "03_later_history.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("# Ezra\n")
    end = text.find("\n# ", start + 5)
    end = len(text) if end < 0 else end + 1
    section = text[start:end]
    for old, new in STORY_FIXES:
        section = replace_once(section, old, new, f"story {old[:40]!r}")
    path.write_text(text[:start] + section + text[end:], encoding="utf-8")
    print(f"Updated {path.relative_to(ROOT)}")


if __name__ == "__main__":
    apply_chapter_insights()
    apply_chapter_context()
    apply_book_overview()
    apply_story_fixes()
