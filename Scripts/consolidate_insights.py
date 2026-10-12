#!/usr/bin/env python3
"""Consolidate BibleInsights.sqlite around book-level history and chapter-specific detail.

1. Loads each book's When & Where section and its story from Scripts/book_content/*.md
   into the book_history and book_story_sections tables.
2. Clears chapter background fields whose text is repeated across chapters of the same
   book. That repeated text describes the whole book rather than the chapter, and the
   book's When & Where section now covers it. (The original text remains in git history.)
3. Cleans up imported text: decodes summaries stored as raw JSON, removes KJV translators'
   notes from key scriptures, and puts citations tacked onto the end of a clause in
   parentheses ("…remains debated (Ruth 3:5–7).").
4. Optionally copies the database and a JSON export to an output folder.

Every step is safe to run again.

Run after build_bible_insights.py and add_related_verses.py:
    python3 Scripts/consolidate_insights.py [output_dir]
"""

import json
import re
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


def decode_json_summaries(database):
    """Some chapter summaries were imported as raw JSON ({"summary": ..., "central_message": ...})."""
    fixed = 0
    for book, chapter, encoded in database.execute(
        "SELECT book_name, chapter_number, overall_summary FROM chapter_insights WHERE overall_summary LIKE '{%'"
    ).fetchall():
        source = json.loads(encoded)
        summary = " ".join(part.strip() for part in [source.get("summary", ""), source.get("central_message", "")] if part)
        database.execute(
            "UPDATE chapter_insights SET overall_summary = ? WHERE book_name = ? AND chapter_number = ?",
            (summary, book, chapter),
        )
        fixed += 1
    return fixed


def clean_kjv_markup(text):
    """Drops translators' notes ({x: or, y}) and the braces marking supplied words."""
    text = re.sub(r"\s*\{[^{}]*:[^{}]*\}", "", text)
    text = re.sub(r"[{}]", "", text)
    return re.sub(r"\s{2,}", " ", text).strip()


def clean_key_scripture(database):
    rows = database.execute("SELECT name, key_scripture_text FROM book_overviews").fetchall()
    changed = [(clean_kjv_markup(text), name) for name, text in rows if clean_kjv_markup(text) != text]
    database.executemany("UPDATE book_overviews SET key_scripture_text = ? WHERE name = ?", changed)
    return len(changed)


# Words that make a following reference part of the sentence ("as told in Genesis 12"),
# rather than a citation tacked onto the end of a clause ("…remains debated Ruth 3:5–7.").
CONNECTING_WORDS = {
    "in", "of", "and", "or", "nor", "to", "from", "see", "compare", "cf", "with", "at", "by",
    "also", "like", "as", "after", "before", "through", "into", "on", "under", "within",
    "during", "between", "until", "about", "against", "for", "unlike", "than", "then", "read",
    "reads", "explain", "explains", "example", "recalls", "echoes", "cites", "quotes", "including",
    "especially", "where", "when", "why", "how", "chapter", "chapters", "verse", "verses",
}

CHAPTER_TEXT_COLUMNS = {
    "chapter_insights": ["overall_summary", *CHAPTER_BACKGROUND_COLUMNS],
    "chapter_key_themes": ["explanation"],
    "chapter_key_figures": ["role_and_significance"],
}


def citation_pattern(book_names):
    names = "|".join(re.escape(name) for name in sorted(book_names + ["Psalm"], key=len, reverse=True))
    reference = rf"(?:{names}) \d+(?::\d+)?(?:[–-]\d+(?::\d+)?)?(?:[,;] (?:\d+:)?\d+(?:[–-]\d+)?)*"
    # The word may end a parenthetical, as in "Israel (Jacob) 1 Chronicles 1:28–42."
    return re.compile(rf"(?P<word>[\w’'-]+\)?) (?P<reference>{reference})(?=[.,;:]?(?:\s|$))")


def parenthesize_citations(text, pattern):
    def replace(match):
        # Include the word, so "(Jacob)" counts as already closed.
        before = text[:match.end("word")]
        inside_parentheses = before.count("(") > before.count(")")
        if inside_parentheses or match["word"].lower().strip("’')") in CONNECTING_WORDS:
            return match.group()
        return f"{match['word']} ({match['reference']})"
    return pattern.sub(replace, text)


def parenthesize_chapter_citations(database):
    pattern = citation_pattern([name for (name,) in database.execute("SELECT name FROM book_overviews")])
    changed = 0
    for table, columns in CHAPTER_TEXT_COLUMNS.items():
        for column in columns:
            rows = database.execute(f"SELECT rowid, {column} FROM {table}").fetchall()
            updates = [(new, rowid) for rowid, text in rows if (new := parenthesize_citations(text, pattern)) != text]
            database.executemany(f"UPDATE {table} SET {column} = ? WHERE rowid = ?", updates)
            changed += len(updates)
    return changed


def main():
    books = load_books()
    if check_quotes(books) or check_passages(books):
        sys.exit("Fix the book content problems above before importing.")

    database = sqlite3.connect(DATABASE)
    write_book_content(database, books)
    cleared = clear_repeated_chapter_background(database)
    decoded = decode_json_summaries(database)
    scriptures = clean_key_scripture(database)
    citations = parenthesize_chapter_citations(database)
    database.commit()
    database.execute("VACUUM")
    print(f"Imported history and stories for {len(books)} books; cleared {cleared} repeated chapter fields")
    print(f"Decoded {decoded} JSON summaries, cleaned {scriptures} key scriptures, "
          f"parenthesized citations in {citations} text fields")

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
