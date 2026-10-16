#!/usr/bin/env python3
"""Load book overviews into BibleInsights.sqlite.

The content is in Scripts/book_overviews/*.json, one object per book:

    "Ruth": {
      "author": "…", "audience": "…", "purpose": "…", "theme": "…", "summary": "…",
      "keyVerse": "Ruth 1:16",
      "movements": [{"title": "…", "description": "…", "passages": ["Ruth 1:1-22"]}],
      "keyFigures": [{"name": "Naomi", "description": "…"}]
    }

Every book must be present. The testament and order come from the KJV, and the key verse's
text is copied from it, so neither is written here. Every reference must exist in the KJV and
every double-quoted passage must match it; nothing is written if any check fails.

Replaces the book_overviews, book_movements, and book_key_figures tables:
    python3 Scripts/add_book_overviews.py [--check]
"""

import json
import re
import sqlite3
import sys
from pathlib import Path

from add_book_guides import quote_problems, reference_problems
from book_content_tools import kjv_books
from insights_common import DATABASE, KJV


CONTENT = Path(__file__).resolve().parent / "book_overviews"
FIELDS = {"author", "audience", "purpose", "theme", "summary", "keyVerse", "movements", "keyFigures"}
KEY_VERSE = re.compile(r"^(.+) (\d+):(\d+)(?:-(\d+))?$")
OLD_TESTAMENT_BOOKS = 39


def load_overviews():
    books = {}
    for path in sorted(CONTENT.glob("*.json")):
        for name, entry in json.loads(path.read_text(encoding="utf-8")).items():
            if name in books:
                raise ValueError(f"{path.name}: {name} appears twice")
            books[name] = entry
    return books


def key_verse_text(reference, chapters_by_book):
    """The verse text as the app shows it: no translators' notes, supplied-word braces, or red-letter markers."""
    book, chapter, first, last = KEY_VERSE.match(reference).groups()
    verses = chapters_by_book[book][int(chapter) - 1][int(first) - 1:int(last or first)]
    text = " ".join(verses).replace("\ue000", "").replace("\ue001", "")
    text = re.sub(r"\s*\{[^{}]*:[^{}]*\}", "", text)
    text = re.sub(r"[{}]", "", text)
    return re.sub(r"\s{2,}", " ", text).strip()


def validate(books, names, chapters_by_book):
    bible = " ".join(kjv_books())
    problems = []
    if set(books) != set(names):
        problems.append(f"books missing {sorted(set(names) - set(books))}, unknown {sorted(set(books) - set(names))}")
    for name, entry in books.items():
        if set(entry) != FIELDS:
            problems.append(f"{name}: expected keys {sorted(FIELDS)}, found {sorted(entry)}")
            continue
        match = KEY_VERSE.match(entry["keyVerse"])
        if not match or match[1] != name or reference_problems(entry["keyVerse"], chapters_by_book):
            problems.append(f"{name}: bad key verse {entry['keyVerse']!r}")
        texts = [entry[field] for field in ("author", "audience", "purpose", "theme", "summary")]
        for movement in entry["movements"]:
            if set(movement) != {"title", "description", "passages"}:
                problems.append(f"{name}: malformed movement {movement}")
                continue
            texts += [movement["title"], movement["description"]]
            for passage in movement["passages"]:
                problems += [f"{name}: movement passage {p}" for p in reference_problems(passage, chapters_by_book)]
        for figure in entry["keyFigures"]:
            if set(figure) != {"name", "description"}:
                problems.append(f"{name}: malformed key figure {figure}")
                continue
            texts += [figure["name"], figure["description"]]
        for text in texts:
            problems += [f"{name}: {p}" for p in reference_problems(text, chapters_by_book) + quote_problems(text, bible)]
    return problems


def write_overviews(database, books, names, chapters_by_book):
    for table in ("book_overviews", "book_movements", "book_key_figures"):
        database.execute(f"DELETE FROM {table}")
    for order, name in enumerate(names, 1):
        entry = books[name]
        database.execute(
            "INSERT INTO book_overviews (id, name, testament, canonical_order, traditional_author_or_attribution,"
            " original_audience, purpose, overall_theme, plain_english_summary, key_scripture_reference,"
            " key_scripture_text) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (order, name, "Old Testament" if order <= OLD_TESTAMENT_BOOKS else "New Testament", order,
             entry["author"], entry["audience"], entry["purpose"], entry["theme"], entry["summary"],
             entry["keyVerse"], key_verse_text(entry["keyVerse"], chapters_by_book)),
        )
        database.executemany(
            "INSERT INTO book_movements (book_name, sequence, title, description, key_passages_json) VALUES (?, ?, ?, ?, ?)",
            [(name, index, movement["title"], movement["description"], json.dumps(movement["passages"], ensure_ascii=False))
             for index, movement in enumerate(entry["movements"], 1)],
        )
        database.executemany(
            "INSERT INTO book_key_figures (book_name, sequence, name, description) VALUES (?, ?, ?, ?)",
            [(name, index, figure["name"], figure["description"]) for index, figure in enumerate(entry["keyFigures"], 1)],
        )


def main():
    kjv = json.loads(KJV.read_text(encoding="utf-8-sig"))
    names = [book["name"] for book in kjv]
    chapters_by_book = {book["name"]: book["chapters"] for book in kjv}
    books = load_overviews()
    problems = validate(books, names, chapters_by_book)
    for problem in problems:
        print(problem)
    movements = sum(len(entry.get("movements", [])) for entry in books.values())
    figures = sum(len(entry.get("keyFigures", [])) for entry in books.values())
    print(f"{len(books)} books, {movements} movements, {figures} key figures, {len(problems)} problems")
    if problems or "--check" in sys.argv:
        sys.exit(1 if problems else 0)
    with sqlite3.connect(DATABASE) as database:
        write_overviews(database, books, names, chapters_by_book)


if __name__ == "__main__":
    main()
