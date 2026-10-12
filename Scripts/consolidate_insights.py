#!/usr/bin/env python3
"""Consolidate BibleInsights.sqlite around book-level history and chapter-specific detail.

1. Loads each book's When & Where section and its story from Scripts/book_content/*.md
   into the book_history and book_story_sections tables.
2. Clears chapter background fields whose text is repeated across chapters of the same
   book. That repeated text describes the whole book rather than the chapter, and the
   book's When & Where section now covers it. (The original text remains in git history.)
3. Optionally copies the database and a JSON export to an output folder.

Run after build_bible_insights.py and add_related_verses.py:
    python3 Scripts/consolidate_insights.py [output_dir]
"""

import sqlite3
import sys
from pathlib import Path

from add_related_verses import DATABASE, export_json
from book_content_tools import check_passages, check_quotes, load_books


CHAPTER_BACKGROUND_COLUMNS = [
    "historical_setting",
    "what_was_happening",
    "connection_to_chapter",
    "customs_and_traditions",
    "why_it_matters",
]


def write_book_content(database, books):
    database.executescript("""
        DROP TABLE IF EXISTS book_history;
        DROP TABLE IF EXISTS book_story_sections;
        CREATE TABLE book_history (
            book_name TEXT PRIMARY KEY REFERENCES book_overviews(name),
            when_it_happened TEXT NOT NULL, when_it_was_written TEXT NOT NULL,
            location TEXT NOT NULL, world_at_the_time TEXT NOT NULL
        );
        CREATE TABLE book_story_sections (
            id INTEGER PRIMARY KEY, book_name TEXT NOT NULL REFERENCES book_overviews(name),
            sequence INTEGER NOT NULL, passage TEXT NOT NULL, text TEXT NOT NULL,
            UNIQUE(book_name, sequence)
        );
    """)
    known = {name for (name,) in database.execute("SELECT name FROM book_overviews")}
    if set(books) != known:
        raise RuntimeError(f"Book content mismatch: missing {sorted(known - set(books))}, extra {sorted(set(books) - known)}")
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


def clear_repeated_chapter_background(database):
    cleared = 0
    for column in CHAPTER_BACKGROUND_COLUMNS:
        cleared += database.execute(f"""
            UPDATE chapter_insights SET {column} = ''
            WHERE trim({column}) <> '' AND (book_name, {column}) IN (
                SELECT book_name, {column} FROM chapter_insights
                GROUP BY book_name, {column} HAVING count(*) > 1
            )
        """).rowcount
    return cleared


def main():
    books = load_books()
    if check_quotes(books) or check_passages(books):
        sys.exit("Fix the book content problems above before importing.")

    database = sqlite3.connect(DATABASE)
    write_book_content(database, books)
    cleared = clear_repeated_chapter_background(database)
    database.commit()
    database.execute("VACUUM")
    print(f"Imported history and stories for {len(books)} books; cleared {cleared} repeated chapter fields")

    if len(sys.argv) > 1:
        output_dir = Path(sys.argv[1])
        output_dir.mkdir(parents=True, exist_ok=True)
        database.close()
        (output_dir / "BibleInsights.sqlite").write_bytes(DATABASE.read_bytes())
        database = sqlite3.connect(DATABASE)
        export_json(database, output_dir / "BibleInsights.json")
        print(f"Exported BibleInsights.sqlite and BibleInsights.json to {output_dir}")
    database.close()


if __name__ == "__main__":
    main()
