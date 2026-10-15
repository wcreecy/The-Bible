#!/usr/bin/env python3
"""Show a parallel passage once per chapter instead of once per verse.

Older hand-explained cross references link every verse of a section to the same parallel
passage (2 Samuel 7:1, 7:2, ... 7:17 → 1 Chronicles 17:1-15), so the chapter insights page
listed the same card again and again. This keeps the link on the first verse that has it
and removes the repeats from chapter_related_verses and chapter_scripture_connections.

Usage:
    python3 Scripts/collapse_repeated_cross_references.py [--dry-run]

Safe to run again.
"""

import sqlite3
import sys

from add_related_verses import DATABASE


def main():
    dry_run = "--dry-run" in sys.argv
    database = sqlite3.connect(DATABASE)
    repeats = database.execute("""
        SELECT related.id, related.book_name, related.chapter_number, related.source_verse, related.related_reference
        FROM chapter_related_verses AS related
        JOIN (
            SELECT book_name, chapter_number, related_reference, MIN(source_verse) AS first_verse
            FROM chapter_related_verses
            GROUP BY book_name, chapter_number, related_reference
            HAVING COUNT(*) > 1
        ) AS first USING (book_name, chapter_number, related_reference)
        WHERE related.source_verse > first.first_verse
    """).fetchall()

    for row_id, book, chapter, verse, reference in repeats:
        database.execute("DELETE FROM chapter_related_verses WHERE id = ?", (row_id,))
        database.execute("""
            DELETE FROM chapter_scripture_connections
            WHERE book_name = ? AND chapter_number = ? AND source_verse = ? AND related_reference = ?
        """, (book, chapter, verse, reference))

    chapters = len({(book, chapter) for _, book, chapter, _, _ in repeats})
    print(f"{'Would remove' if dry_run else 'Removed'} {len(repeats)} repeated cross references in {chapters} chapters")
    if not dry_run:
        database.commit()


if __name__ == "__main__":
    main()
