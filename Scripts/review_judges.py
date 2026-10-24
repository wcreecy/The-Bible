#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Second-pass audit fixes for Judges (accuracy, KJV spelling, reading level, overview coverage)."""

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


SUMMARY_FIXES = {
    "Judges 2": [("After a retrospective account of Joshua's death and the faithful elders, the narrative says a later generation", "The book looks back at Joshua's death and the faithful elders, then says a later generation")],
    "Judges 3": [("Moab's King Eglon, allied with Ammon and Amalek, subjugates Israel", "Moab's King Eglon, with help from Ammon and Amalek, rules over Israel")],
    "Judges 7": [("camp with Purah and hears", "camp with Phurah and hears")],
    "Judges 9": [("Zebul manipulates events", "Zebul helps Abimelech")],
    "Judges 10": [("especially in Gilead, with incursions westward", "especially in Gilead, and the Ammonites cross the Jordan to attack Judah, Benjamin, and Ephraim")],
    "Judges 12": [("with their families and tenures", "with their families and years as judge")],
}


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "07_judges.json"
    data = load(path)
    for key, fixes in SUMMARY_FIXES.items():
        for old, new in fixes:
            data[key]["summary"] = replace_once(data[key]["summary"], old, new, key)
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_book_overview():
    path = ROOT / "book_overviews" / "02_early_history.json"
    data = load(path)
    book = data["Judges"]
    first = book["movements"][0]
    first["title"] = "Failure to Finish and Early Cycles"
    first["description"] = "Israel leaves Canaanites in the land and forgets the LORD, then Othniel, Ehud, and Deborah deliver Israel from oppressors."
    first["passages"] = ["Judges 1-5"]
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_FIXES = [
    ("The book reveals that this Levite was Jonathan, a grandson of Gershom, the son of Moses.",
     "The book reveals that this Levite was Jonathan, the son of Gershom, who was the son of Moses."),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "02_early_history.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("# Judges")
    end = text.index("\n# ", start + 5) + 1
    section = text[start:end]
    for old, new in STORY_FIXES:
        section = replace_once(section, old, new, "story")
    path.write_text(text[:start] + section + text[end:], encoding="utf-8")
    print(f"Updated {path.relative_to(ROOT)}")


if __name__ == "__main__":
    apply_chapter_insights()
    apply_book_overview()
    apply_story_fixes()
