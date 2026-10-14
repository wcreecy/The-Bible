#!/usr/bin/env python3
"""Add book-specific reading tips and connections to BibleInsights.sqlite.

The content is hand-written in Scripts/book_guides/*.json, one object per book:

    "Judges": {
      "tips": ["…", "…"],
      "looksBack": [{"title": "…", "text": "…"}],
      "looksAhead": [{"title": "…", "text": "…"}]
    }

Every scripture reference in the text must exist in the app's KJV, and every
quotation must match it. The script writes nothing if any check fails.

Writes the book_reading_tips and book_connections tables; safe to run again:
    python3 Scripts/add_book_guides.py
"""

import json
import re
import sqlite3
import sys
from pathlib import Path

from add_related_verses import DATABASE
from book_content_tools import KJV, kjv_books, normalize


GUIDES = Path(__file__).resolve().parent / "book_guides"
ALIASES = {"Psalm": "Psalms", "Song of Songs": "Song of Solomon"}


def load_guides():
    guides = {}
    for path in sorted(GUIDES.glob("*.json")):
        for name, guide in json.loads(path.read_text(encoding="utf-8")).items():
            if name in guides:
                raise ValueError(f"{path.name}: {name} appears twice")
            guides[name] = guide
    return guides


def reference_problems(text, chapters_by_book):
    """Checks each "Book C:V" reference, plus "; C:V" and ", V" entries continuing it."""
    names = sorted(list(chapters_by_book) + list(ALIASES), key=len, reverse=True)
    full = re.compile(
        r"(?<![A-Za-z0-9])(" + "|".join(map(re.escape, names)) + r")\s+(\d+)(?::(\d+))?(?:[–-](\d+)(?::(\d+))?)?"
        r"((?:\s*[;,]\s*\d+(?::\d+)?(?:[–-]\d+(?::\d+)?)?(?![A-Za-z]))*)"
        # The app can't link a cross-chapter range after "; ", so require the book name there.
    )
    problems = []

    def check(book, chapter, verse, label):
        chapters = chapters_by_book[book]
        if not 1 <= chapter <= len(chapters):
            problems.append(f"no chapter {chapter} in {book} ({label})")
        elif verse is not None and not 1 <= verse <= len(chapters[chapter - 1]):
            problems.append(f"no verse {chapter}:{verse} in {book} ({label})")

    for match in full.finditer(text):
        book = ALIASES.get(match[1], match[1])
        chapter, verse = int(match[2]), match[3] and int(match[3])
        check(book, chapter, verse, match[0])
        if match[4]:
            if match[5]:
                check(book, int(match[4]), int(match[5]), match[0])
            elif verse is not None:
                check(book, chapter, int(match[4]), match[0])
            else:
                check(book, int(match[4]), None, match[0])
        # Continuations: "; 6:16" starts a new chapter, ", 7" adds a verse in the same chapter.
        for part in re.finditer(r"([;,])\s*(\d+)(?::(\d+))?(?:[–-](\d+)(:\d+)?)?", match[6] or ""):
            if part[5]:
                problems.append(f"write the book name before a cross-chapter range ({match[0]})")
                continue
            if part[3]:
                chapter, verse = int(part[2]), int(part[3])
            elif part[1] == "," and verse is not None:
                verse = int(part[2])
            else:
                chapter, verse = int(part[2]), None
            check(book, chapter, verse, match[0])
            if part[4]:
                check(book, chapter, int(part[4]) if verse is not None else None, match[0])
    return problems


def quote_problems(text, bible):
    problems = []
    for quote in re.findall(r"“([^”]+)”|\"([^\"]+)\"", text):
        for part in re.split(r"\.\.\.|…", quote[0] or quote[1]):
            part = normalize(part)
            if len(part.split()) >= 2 and part not in bible:
                problems.append(f"not found in KJV: {part}")
    return problems


def validate(guides, book_names, chapters_by_book):
    bible = " ".join(kjv_books())
    problems = []
    missing = [name for name in book_names if name not in guides]
    extra = [name for name in guides if name not in chapters_by_book]
    if missing or extra:
        problems.append(f"missing {missing}, unknown {extra}")
    for name, guide in guides.items():
        if set(guide) != {"tips", "looksBack", "looksAhead"}:
            problems.append(f"{name}: unexpected keys {sorted(guide)}")
            continue
        if not guide["tips"]:
            problems.append(f"{name}: no tips")
        if not guide["looksBack"] and not guide["looksAhead"]:
            problems.append(f"{name}: no connections")
        texts = list(guide["tips"])
        for connection in guide["looksBack"] + guide["looksAhead"]:
            if set(connection) != {"title", "text"} or not connection["title"].strip():
                problems.append(f"{name}: malformed connection {connection}")
                continue
            texts.append(connection["text"])
        for text in texts:
            problems += [f"{name}: {p}" for p in reference_problems(text, chapters_by_book) + quote_problems(text, bible)]
    return problems


def write_guides(database, guides):
    database.executescript("""
        DROP TABLE IF EXISTS book_reading_tips;
        DROP TABLE IF EXISTS book_connections;
        CREATE TABLE book_reading_tips (
            id INTEGER PRIMARY KEY, book_name TEXT NOT NULL REFERENCES book_overviews(name),
            sequence INTEGER NOT NULL, tip TEXT NOT NULL,
            UNIQUE(book_name, sequence)
        );
        CREATE TABLE book_connections (
            id INTEGER PRIMARY KEY, book_name TEXT NOT NULL REFERENCES book_overviews(name),
            direction TEXT NOT NULL CHECK (direction IN ('back', 'ahead')),
            sequence INTEGER NOT NULL, title TEXT NOT NULL, text TEXT NOT NULL,
            UNIQUE(book_name, direction, sequence)
        );
    """)
    for name, guide in guides.items():
        database.executemany(
            "INSERT INTO book_reading_tips (book_name, sequence, tip) VALUES (?, ?, ?)",
            [(name, index, tip) for index, tip in enumerate(guide["tips"])],
        )
        for direction, key in (("back", "looksBack"), ("ahead", "looksAhead")):
            database.executemany(
                "INSERT INTO book_connections (book_name, direction, sequence, title, text) VALUES (?, ?, ?, ?, ?)",
                [(name, direction, index, c["title"], c["text"]) for index, c in enumerate(guide[key])],
            )


def main():
    kjv = json.loads(KJV.read_text(encoding="utf-8-sig"))
    chapters_by_book = {book["name"]: book["chapters"] for book in kjv}
    guides = load_guides()
    problems = validate(guides, [book["name"] for book in kjv], chapters_by_book)
    for problem in problems:
        print(problem)
    tips = sum(len(g.get("tips", [])) for g in guides.values())
    connections = sum(len(g.get("looksBack", [])) + len(g.get("looksAhead", [])) for g in guides.values())
    print(f"{len(guides)} books, {tips} tips, {connections} connections, {len(problems)} problems")
    if problems or "--check" in sys.argv:
        sys.exit(1 if problems else 0)
    with sqlite3.connect(DATABASE) as database:
        write_guides(database, guides)
    print(f"Wrote {DATABASE.name}")


if __name__ == "__main__":
    main()
