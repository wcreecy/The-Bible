#!/usr/bin/env python3
"""Write each book's When & Where section and story from BibleInsights.sqlite back to
Scripts/book_content/*.md, so the files match what the app shows.

The .md files are the source; edit them and run build_insights.py. Use this only
to recover changes that were made to the database directly.

Books keep the file and order they already have. The result is checked by parsing the
files again: every story part and When & Where field must come back exactly as stored,
or nothing is written.

    python3 Scripts/export_book_content.py [--check]

With --check, only reports whether the files and the database differ.
"""

import re
import sqlite3
import sys

from insights_common import DATABASE
from book_content_tools import CONTENT, UNLABELED_PART, WHEN_WHERE_FIELDS, load_books


def file_layout():
    """{file path: [book names in order]} from the existing files."""
    return {
        path: re.findall(r"^# (.+)$", path.read_text(encoding="utf-8"), flags=re.MULTILINE)
        for path in sorted(CONTENT.glob("*.md"))
    }


def database_books(database):
    books = {}
    for name, *fields in database.execute(
        "SELECT book_name, when_it_happened, when_it_was_written, location, world_at_the_time FROM book_history"
    ):
        books[name] = {"when_where": dict(zip(WHEN_WHERE_FIELDS.values(), fields)), "story": []}
    for name, passage, text in database.execute(
        "SELECT book_name, passage, text FROM book_story_sections ORDER BY book_name, sequence"
    ):
        books[name]["story"].append((passage, text))
    return books


def render_book(name, book):
    lines = [f"# {name}"]
    lines += [f"{label}: {book['when_where'][field]}" for label, field in WHEN_WHERE_FIELDS.items()]
    blocks = ["\n".join(lines)]
    for passage, text in book["story"]:
        paragraphs = text.split("\n\n")
        if passage:
            blocks.append(f"**{passage}** — {paragraphs[0]}")
        else:
            blocks += [UNLABELED_PART, paragraphs[0]]
        blocks += paragraphs[1:]
    return "\n\n".join(blocks)


def main():
    database = sqlite3.connect(DATABASE)
    books = database_books(database)
    layout = file_layout()
    placed = [name for names in layout.values() for name in names]
    if sorted(placed) != sorted(books):
        sys.exit(f"Book mismatch between files and database: {sorted(set(placed) ^ set(books))}")

    rendered = {path: "\n\n".join(render_book(name, books[name]) for name in names) + "\n" for path, names in layout.items()}
    current = {path: path.read_text(encoding="utf-8") for path in layout}
    if "--check" in sys.argv:
        stale = [path.name for path in layout if rendered[path] != current[path]]
        print("Book content files match the database." if not stale else f"Out of date: {', '.join(stale)}")
        sys.exit(1 if stale else 0)

    # Write, then confirm the files parse back to exactly what the database holds.
    for path, content in rendered.items():
        path.write_text(content, encoding="utf-8")
    parsed = load_books()
    if parsed != books:
        for path, content in current.items():
            path.write_text(content, encoding="utf-8")
        differing = [name for name in books if parsed.get(name) != books[name]]
        sys.exit(f"Round trip failed for {differing[:10]}; the original files were restored.")
    sections = sum(len(book["story"]) for book in books.values())
    print(f"Wrote {len(books)} books ({sections} story sections) to {len(layout)} files; round trip verified.")


if __name__ == "__main__":
    main()
