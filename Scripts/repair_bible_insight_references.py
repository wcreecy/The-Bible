#!/usr/bin/env python3
"""Repair known reference defects in the bundled Bible insights database.

The script is safe to run repeatedly. It also validates every canonical reference
that it can recognize against the app's bundled KJV chapter and verse boundaries.
"""

import json
import re
import sqlite3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATABASE = ROOT / "The Bible (iOS)" / "BibleInsights.sqlite"
KJV = ROOT / "The Bible" / "kjv.json"


def repair(database: sqlite3.Connection) -> int:
    changes = 0

    # A faulty import wrote each chapter number twice: "Jeremiah 19:19:1".
    for book in ("Jeremiah", "Leviticus"):
        for chapter in range(1, 53 if book == "Jeremiah" else 28):
            old = f"{book} {chapter}:{chapter}:"
            new = f"{book} {chapter}:"
            cursor = database.execute(
                """
                UPDATE chapter_key_themes
                SET scripture_references_json = replace(scripture_references_json, ?, ?)
                WHERE book_name = ? AND scripture_references_json LIKE ?
                """,
                (old, new, book, f"%{old}%"),
            )
            changes += cursor.rowcount

    # 3 John has fourteen verses in the bundled KJV.
    cursor = database.execute(
        """
        UPDATE chapter_key_themes
        SET scripture_references_json = replace(
            scripture_references_json, '3 John 1:13-15', '3 John 1:13-14'
        )
        WHERE scripture_references_json LIKE '%3 John 1:13-15%'
        """
    )
    changes += cursor.rowcount

    # The app uses KJV chapter numbering, where these verses are Malachi 4.
    cursor = database.execute(
        """
        UPDATE chapter_insights
        SET customs_and_traditions = replace(
            customs_and_traditions, 'Malachi 3:19–24', 'Malachi 4:1–6'
        )
        WHERE customs_and_traditions LIKE '%Malachi 3:19–24%'
        """
    )
    changes += cursor.rowcount

    # This is an external (non-canonical) work; retain it as a clear citation.
    cursor = database.execute(
        """
        UPDATE chapter_insights
        SET customs_and_traditions = replace(
            customs_and_traditions, '4 (Ezra 7:28-29)', '4 Ezra 7:28–29'
        )
        WHERE customs_and_traditions LIKE '%4 (Ezra 7:28-29)%'
        """
    )
    changes += cursor.rowcount
    return changes


def validate(database: sqlite3.Connection) -> None:
    books = {book["name"]: book["chapters"] for book in json.loads(KJV.read_text())}
    names = "|".join(re.escape(name) for name in sorted(books, key=len, reverse=True))
    pattern = re.compile(rf"(?P<book>{names}) (?P<chapter>\d+):(?P<verse>\d+)(?:[–-](?P<end>\d+))?")
    errors: list[str] = []

    for table, column in (
        ("book_overviews", "key_scripture_reference"),
        ("book_movements", "key_passages_json"),
        ("book_story_sections", "passage"),
        ("chapter_insights", "overall_summary"),
        ("chapter_key_themes", "scripture_references_json"),
        ("chapter_related_verses", "related_reference"),
    ):
        for rowid, value in database.execute(f"SELECT rowid, {column} FROM {table}"):
            if column.endswith("_json"):
                value = " ".join(json.loads(value))
            for match in pattern.finditer(value):
                book = match["book"]
                chapter = int(match["chapter"])
                verse = int(match["verse"])
                end = int(match["end"] or verse)
                if not 1 <= chapter <= len(books[book]):
                    errors.append(f"{table} row {rowid}: invalid chapter in {match.group()}")
                    continue
                limit = len(books[book][chapter - 1])
                if not 1 <= verse <= end <= limit:
                    errors.append(f"{table} row {rowid}: invalid verse in {match.group()}")

    if errors:
        raise RuntimeError("\n".join(errors))


def main() -> None:
    with sqlite3.connect(DATABASE) as database:
        changed = repair(database)
        validate(database)
    print(f"Repaired {changed} database rows and validated canonical references.")


if __name__ == "__main__":
    main()
