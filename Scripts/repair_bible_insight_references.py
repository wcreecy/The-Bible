#!/usr/bin/env python3
"""Repair known reference defects in the bundled Bible insights database.

The script is safe to run repeatedly. It also validates every reference in every text
column against the app's bundled KJV chapter and verse boundaries, and saves nothing if
any reference is invalid.
"""

import json
import re
import sqlite3
from pathlib import Path


from insights_common import DATABASE, KJV


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

    return changes + repair_all_text(database)


# Books with a single chapter, which imported text sometimes cites by verse alone ("Jude 12").
ONE_CHAPTER_BOOKS = ("Obadiah", "Philemon", "2 John", "3 John", "Jude")
VERSE_ONLY = re.compile(
    rf"\b(?P<book>{'|'.join(ONE_CHAPTER_BOOKS)}) (?P<verse>\d+)(?P<range>[–-]\d+)?(?![\d:])"
)


def text_columns(database: sqlite3.Connection):
    for (table,) in database.execute("SELECT name FROM sqlite_master WHERE type = 'table'"):
        for column in database.execute(f"PRAGMA table_info({table})"):
            if column[2].upper() == "TEXT":
                yield table, column[1]


def repair_text(text: str) -> str:
    def add_chapter(match: re.Match) -> str:
        # "Jude 1" on its own is the whole (only) chapter, which is already valid.
        if match["verse"] == "1" and not match["range"]:
            return match.group()
        return f"{match['book']} 1:{match['verse']}{match['range'] or ''}"

    text = VERSE_ONLY.sub(add_chapter, text)
    # 3 John has fourteen verses in the bundled KJV.
    text = text.replace("3 John 1:11-15", "3 John 1:11-14")
    # A semicolon before "2 Peter" reads as a second Jude chapter.
    text = text.replace("(compare Jude 1:6; 2 Peter 2:4)", "(compare Jude 1:6 and 2 Peter 2:4)")
    # Hebrew numbering, not a KJV reference: in the KJV these verses are Malachi 4:1–6.
    text = text.replace(
        "In the Hebrew numbering these verses are (Malachi 3:19–24) rather than a separate chapter 4.",
        "In the Hebrew numbering these verses are chapter 3, verses 19–24, rather than a separate chapter 4.",
    )
    # 4 Ezra is the apocryphal 2 Esdras, not the book of Ezra.
    text = text.replace("4 (Ezra 7:28-29)", "2 Esdras 7:28–29 (also called 4 Ezra)")
    text = text.replace("4 Ezra 7:28–29", "2 Esdras 7:28–29 (also called 4 Ezra)")
    return text


def repair_all_text(database: sqlite3.Connection) -> int:
    changes = 0
    for table, column in text_columns(database):
        for rowid, value in database.execute(f"SELECT rowid, {column} FROM {table}").fetchall():
            if not value:
                continue
            fixed = repair_text(value)
            if fixed != value:
                database.execute(f"UPDATE {table} SET {column} = ? WHERE rowid = ?", (fixed, rowid))
                changes += 1
    return changes


def validate(database: sqlite3.Connection) -> None:
    from add_book_guides import reference_problems

    books = {book["name"]: book["chapters"] for book in json.loads(KJV.read_text())}
    # Every reference in every text column, including chapter-only and verse-only forms.
    errors = [
        f"{table}.{column} row {rowid}: {problem}"
        for table, column in text_columns(database)
        for rowid, value in database.execute(f"SELECT rowid, {column} FROM {table}")
        if value
        for problem in reference_problems(value, books)
    ]
    if errors:
        raise RuntimeError("\n".join(errors))


def main() -> None:
    with sqlite3.connect(DATABASE) as database:
        changed = repair(database)
        validate(database)
    print(f"Repaired {changed} database rows and validated canonical references.")


if __name__ == "__main__":
    main()
