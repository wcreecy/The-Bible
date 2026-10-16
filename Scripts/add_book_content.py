#!/usr/bin/env python3
"""Load each book's When & Where section and story into BibleInsights.sqlite.

The content is hand-written in Scripts/book_content/*.md (the format is described in
book_content_tools.py) and replaces the book_history and book_story_sections tables.
Every quotation must match the app's KJV and every passage label must exist in it.

The script stops if the database holds story sections the .md files would not recreate,
so a change made directly in the database is never lost; write it back first with
export_book_content.py, or pass --replace-stories to replace it anyway.

    python3 Scripts/add_book_content.py [--replace-stories]
"""

import sqlite3
import sys

from book_content_tools import check_passages, check_quotes, load_books
from insights_common import DATABASE


def story_sections_lost(database, books):
    """Story sections in the database that book_content/*.md would not recreate."""
    existing = set(database.execute("SELECT book_name, passage, text FROM book_story_sections"))
    imported = {(name, passage, text) for name, book in books.items() for passage, text in book["story"]}
    return existing - imported


def write_book_content(database, books):
    known = {name for (name,) in database.execute("SELECT name FROM book_overviews")}
    if set(books) != known:
        raise RuntimeError(f"Book content mismatch: missing {sorted(known - set(books))}, extra {sorted(set(books) - known)}")
    database.execute("DELETE FROM book_history")
    database.execute("DELETE FROM book_story_sections")
    for name, book in books.items():
        when_where = book["when_where"]
        database.execute(
            "INSERT INTO book_history VALUES (?, ?, ?, ?, ?)",
            (name, when_where["when_it_happened"], when_where["when_it_was_written"],
             when_where["location"], when_where["world_at_the_time"]),
        )
        database.executemany(
            "INSERT INTO book_story_sections (book_name, sequence, passage, text) VALUES (?, ?, ?, ?)",
            [(name, index, passage, text) for index, (passage, text) in enumerate(book["story"])],
        )


def main():
    books = load_books()
    if check_quotes(books) or check_passages(books):
        sys.exit("Fix the book content problems above before importing.")

    with sqlite3.connect(DATABASE) as database:
        lost = story_sections_lost(database, books)
        if lost and "--replace-stories" not in sys.argv:
            sys.exit(f"{len(lost)} story sections in the database are not in book_content/*.md and would be "
                     "deleted. Write them back with export_book_content.py, or pass --replace-stories.")
        write_book_content(database, books)
    sections = sum(len(book["story"]) for book in books.values())
    print(f"Loaded history and {sections} story sections for {len(books)} books")


if __name__ == "__main__":
    main()
