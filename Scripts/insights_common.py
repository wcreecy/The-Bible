"""Paths and book tables shared by the BibleInsights.sqlite build scripts.

Each script writes to DATABASE. build_insights.py points it at a working copy by setting
BIBLE_INSIGHTS_DATABASE, so a failed build never touches the bundled database.
"""

import os
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BUNDLED_DATABASE = ROOT / "The Bible (iOS)" / "BibleInsights.sqlite"
DATABASE = Path(os.environ.get("BIBLE_INSIGHTS_DATABASE", BUNDLED_DATABASE))
KJV = ROOT / "The Bible" / "kjv.json"

# OSIS abbreviations used by the OpenBible.info cross-reference dataset, in canonical order.
OSIS_BOOKS = [
    "Gen", "Exod", "Lev", "Num", "Deut", "Josh", "Judg", "Ruth", "1Sam", "2Sam",
    "1Kgs", "2Kgs", "1Chr", "2Chr", "Ezra", "Neh", "Esth", "Job", "Ps", "Prov",
    "Eccl", "Song", "Isa", "Jer", "Lam", "Ezek", "Dan", "Hos", "Joel", "Amos",
    "Obad", "Jonah", "Mic", "Nah", "Hab", "Zeph", "Hag", "Zech", "Mal", "Matt",
    "Mark", "Luke", "John", "Acts", "Rom", "1Cor", "2Cor", "Gal", "Eph", "Phil",
    "Col", "1Thess", "2Thess", "1Tim", "2Tim", "Titus", "Phlm", "Heb", "Jas", "1Pet",
    "2Pet", "1John", "2John", "3John", "Jude", "Rev",
]


def format_target(book, chapter, verse, end_chapter, end_verse):
    """A reference as the app writes it: "John 3:16", "John 3:16-18", or "John 3:16-4:2"."""
    if (end_chapter, end_verse) == (chapter, verse):
        return f"{book} {chapter}:{verse}"
    if end_chapter == chapter:
        return f"{book} {chapter}:{verse}-{end_verse}"
    return f"{book} {chapter}:{verse}-{end_chapter}:{end_verse}"
