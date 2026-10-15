#!/usr/bin/env python3
"""Load hand-written chapter background into BibleInsights.sqlite.

The content lives in Scripts/chapter_context/*.json, one object per chapter:

    "Judges 4": {
      "audience": "Who the chapter addresses or who first heard it, and what they would know.",
      "culture": [
        {"title": "Iron chariots", "reference": "Judges 4:3", "text": "Factual background…"}
      ]
    }

Each chapter's "audience" replaces chapter_reading_contexts.original_audience, and its
"culture" entries replace that chapter's rows in chapter_cultural_lenses. Chapters not
listed are left untouched. Every reference must exist in the app's KJV and every
quotation must match it; nothing is written if any check fails.

    python3 Scripts/add_chapter_context.py [--check]
"""

import json
import re
import sqlite3
import sys
from pathlib import Path

from add_book_guides import quote_problems, reference_problems
from add_related_verses import DATABASE
from book_content_tools import KJV, kjv_books


CONTENT = Path(__file__).resolve().parent / "chapter_context"
CHAPTER_KEY = re.compile(r"^(.+) (\d+)$")


def load_context():
    chapters = {}
    for path in sorted(CONTENT.glob("*.json")):
        for key, entry in json.loads(path.read_text(encoding="utf-8")).items():
            if key in chapters:
                raise ValueError(f"{path.name}: {key} appears twice")
            chapters[key] = entry
    return chapters


def validate(chapters, chapters_by_book):
    bible = " ".join(kjv_books())
    problems = []
    audiences = {}
    for key, entry in chapters.items():
        match = CHAPTER_KEY.match(key)
        if not match or match[1] not in chapters_by_book or not 1 <= int(match[2]) <= len(chapters_by_book[match[1]]):
            problems.append(f"{key}: not a chapter")
            continue
        if set(entry) != {"audience", "culture"}:
            problems.append(f"{key}: unexpected keys {sorted(entry)}")
            continue
        audience = entry["audience"].strip()
        if not audience:
            problems.append(f"{key}: empty audience")
        elif audience in audiences:
            # Repeated text is treated as boilerplate and cleared by clean_chapter_insights.py.
            problems.append(f"{key}: audience repeats {audiences[audience]}")
        audiences[audience] = key
        if not 1 <= len(entry["culture"]) <= 3:
            problems.append(f"{key}: needs 1–3 culture entries")
        texts = [audience]
        for item in entry["culture"]:
            if set(item) != {"title", "reference", "text"} or not item["title"].strip() or not item["text"].strip():
                problems.append(f"{key}: malformed culture entry {item}")
                continue
            if reference_problems(item["reference"], chapters_by_book) or not re.search(r"\d+:\d+", item["reference"]):
                problems.append(f"{key}: bad reference {item['reference']!r}")
            texts.append(item["text"])
        for text in texts:
            problems += [f"{key}: {p}" for p in reference_problems(text, chapters_by_book) + quote_problems(text, bible)]
    return problems


def write_context(database, chapters):
    for key, entry in chapters.items():
        book, chapter = CHAPTER_KEY.match(key).group(1, 2)
        updated = database.execute(
            "UPDATE chapter_reading_contexts SET original_audience = ? WHERE book_name = ? AND chapter_number = ?",
            (entry["audience"].strip(), book, int(chapter)),
        ).rowcount
        if updated != 1:
            raise RuntimeError(f"{key}: no reading context row")
        database.execute(
            "DELETE FROM chapter_cultural_lenses WHERE book_name = ? AND chapter_number = ?", (book, int(chapter))
        )
        database.executemany(
            "INSERT INTO chapter_cultural_lenses (book_name, chapter_number, sequence, title, scripture_reference,"
            " then_text, why_it_matters) VALUES (?, ?, ?, ?, ?, ?, '')",
            [(book, int(chapter), i, item["title"], item["reference"], item["text"]) for i, item in enumerate(entry["culture"])],
        )


def main():
    kjv = json.loads(KJV.read_text(encoding="utf-8-sig"))
    chapters_by_book = {book["name"]: book["chapters"] for book in kjv}
    chapters = load_context()
    problems = validate(chapters, chapters_by_book)
    for problem in problems:
        print(problem)
    entries = sum(len(e.get("culture", [])) for e in chapters.values())
    print(f"{len(chapters)} chapters, {entries} culture entries, {len(problems)} problems")
    if problems or "--check" in sys.argv:
        sys.exit(1 if problems else 0)
    with sqlite3.connect(DATABASE) as database:
        write_context(database, chapters)
    print(f"Wrote {DATABASE.name}")


if __name__ == "__main__":
    main()
