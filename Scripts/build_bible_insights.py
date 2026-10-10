#!/usr/bin/env python3
"""Build the single bundled Bible insights database from the legacy resources."""

import json
import re
import sqlite3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / "The Bible (iOS)"
OUTPUT = RESOURCES / "BibleInsights.sqlite"


def table_columns(database, table):
    return {row[1] for row in database.execute(f"PRAGMA table_info({table})")}


def text(value):
    return value or ""


def joined(values, separator):
    return separator.join(value for value in values if value)


def source_book_name(path):
    name = path.stem.split("_Chapter_Overviews_")[0]
    name = re.sub(r"^(?:[1-4][0-9]|[5-9][0-9])_", "", name)
    return name.replace("_", " ")


def decode_context(encoded):
    source = json.loads(encoded)
    return {
        "historical_setting": source.get("historical_setting", source.get("Historical Setting", "")),
        "what_was_happening": source.get("what_was_happening", source.get("What Was Happening", "")),
        "connection_to_chapter": source.get(
            "connection_to_chapter",
            source.get("historical_connection", source.get("Connection to the Chapter", "")),
        ),
        "customs_and_traditions": source.get("customs_and_traditions", source.get("Customs and Traditions", "")),
        "why_it_matters": source.get("why_it_matters", source.get("Why It Matters", "")),
    }


def decode_figures(encoded):
    figures = json.loads(encoded)
    return [
        (
            text(item.get("name", item.get("name_or_group", ""))),
            text(item.get("role_and_significance"))
            or joined([text(item.get("role")), text(item.get("significance"))], " "),
        )
        for item in figures
    ]


def decode_themes(encoded):
    themes = json.loads(encoded)
    return [
        (
            text(item.get("theme")),
            text(item.get("explanation_and_takeaway"))
            or text(item.get("explanation_and_lesson")),
            item.get("scripture_references", []),
        )
        for item in themes
    ]


def add_chapter(destination, book, chapter, reference, summary, context, figures, themes):
    destination.execute(
        """
        INSERT INTO chapter_insights (
            book_name, chapter_number, reference, overall_summary, historical_setting,
            what_was_happening, connection_to_chapter, customs_and_traditions, why_it_matters
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            book, chapter, reference, summary, context["historical_setting"],
            context["what_was_happening"], context["connection_to_chapter"],
            context["customs_and_traditions"], context["why_it_matters"],
        ),
    )
    destination.executemany(
        """
        INSERT INTO chapter_key_figures (
            book_name, chapter_number, sequence, name, role_and_significance
        ) VALUES (?, ?, ?, ?, ?)
        """,
        [(book, chapter, index, name, role) for index, (name, role) in enumerate(figures)],
    )
    destination.executemany(
        """
        INSERT INTO chapter_key_themes (
            book_name, chapter_number, sequence, theme, explanation, scripture_references_json
        ) VALUES (?, ?, ?, ?, ?, ?)
        """,
        [
            (book, chapter, index, theme, explanation, json.dumps(references))
            for index, (theme, explanation, references) in enumerate(themes)
        ],
    )


def import_default(destination, source, book):
    for row in source.execute(
        """
        SELECT chapter_id, chapter_number, reference, overall_summary, historical_setting,
               what_was_happening, connection_to_chapter, customs_and_traditions, why_it_matters
        FROM chapters
        """
    ):
        chapter_id, chapter, reference, summary, historical, happenings, connection, customs, why = row
        figures = list(source.execute(
            "SELECT name, role_and_significance FROM key_figures WHERE chapter_id = ? ORDER BY display_order",
            (chapter_id,),
        ))
        themes = [
            (theme, explanation, json.loads(references))
            for theme, explanation, references in source.execute(
                "SELECT theme, explanation, scripture_references_json FROM key_themes WHERE chapter_id = ? ORDER BY display_order",
                (chapter_id,),
            )
        ]
        add_chapter(destination, book, chapter, reference, summary, {
            "historical_setting": text(historical), "what_was_happening": text(happenings),
            "connection_to_chapter": text(connection), "customs_and_traditions": text(customs),
            "why_it_matters": text(why),
        }, figures, themes)


def import_embedded(destination, source, book):
    for row in source.execute(
        """
        SELECT chapter, reference, overall_summary, historical_setting, what_was_happening,
               historical_connection, customs_and_traditions, why_it_matters,
               key_figures_json, key_themes_json
        FROM chapters
        """
    ):
        chapter, reference, summary, historical, happenings, connection, customs, why, figures, themes = row
        add_chapter(destination, book, chapter, reference, summary, {
            "historical_setting": text(historical), "what_was_happening": text(happenings),
            "connection_to_chapter": text(connection), "customs_and_traditions": text(customs),
            "why_it_matters": text(why),
        }, decode_figures(figures), decode_themes(themes))


def import_simple(destination, source):
    columns = table_columns(source, "chapter_overviews")
    figures_column = "key_figures_json" if "key_figures_json" in columns else "key_figures"
    themes_column = "key_themes_json" if "key_themes_json" in columns else "key_themes"
    context_column = "historical_context_json" if "historical_context_json" in columns else "historical_context"
    query = f"SELECT book, chapter, overall_summary, {figures_column}, {themes_column}, {context_column} FROM chapter_overviews"
    for book, chapter, summary, figures, themes, context in source.execute(query):
        add_chapter(destination, book, chapter, f"{book} {chapter}", summary, decode_context(context), decode_figures(figures), decode_themes(themes))


def import_relational(destination, source, book):
    for row in source.execute(
        """
        SELECT chapters.id, chapters.chapter_number, chapters.reference, chapters.summary,
               historical_context.historical_setting, historical_context.what_was_happening,
               historical_context.connection_to_chapter, historical_context.why_it_matters
        FROM chapters
        LEFT JOIN historical_context ON historical_context.chapter_id = chapters.id
        """
    ):
        chapter_id, chapter, reference, summary, historical, happenings, connection, why = row
        events = [point for (point,) in source.execute(
            "SELECT point FROM chapter_events WHERE chapter_id = ? ORDER BY sort_order", (chapter_id,)
        )]
        customs = [f"{item}: {description}" for item, description in source.execute(
            "SELECT custom, explanation FROM customs_traditions WHERE chapter_id = ? ORDER BY sort_order", (chapter_id,)
        )]
        figures = [
            (name, joined([text(who), text(role), text(significance)], " "))
            for name, who, role, significance in source.execute(
                "SELECT name, who_they_are, role_in_chapter, significance FROM key_figures WHERE chapter_id = ? ORDER BY sort_order",
                (chapter_id,),
            )
        ]
        themes = [
            (theme, joined([text(explanation), text(significance), text(takeaway)], "\n\n"),
             [value.strip() for value in text(references).split(";") if value.strip()])
            for theme, explanation, significance, takeaway, references in source.execute(
                "SELECT theme, explanation, significance, takeaway, refs FROM key_themes WHERE chapter_id = ? ORDER BY sort_order",
                (chapter_id,),
            )
        ]
        add_chapter(destination, book, chapter, reference, summary, {
            "historical_setting": text(historical),
            "what_was_happening": "\n\n".join(events) if events else text(happenings),
            "connection_to_chapter": text(connection), "customs_and_traditions": "\n\n".join(customs),
            "why_it_matters": text(why),
        }, figures, themes)


def import_structured(destination, source, book):
    for chapter, title, summary, historical, connection, why in source.execute(
        "SELECT chapter, title, summary, historical_setting, connection_to_chapter, why_it_matters FROM chapters"
    ):
        happenings = [statement for (statement,) in source.execute(
            "SELECT statement FROM what_was_happening WHERE chapter = ? ORDER BY seq", (chapter,)
        )]
        customs = [f"{item}: {description}" for item, description in source.execute(
            "SELECT item, explanation FROM customs_and_traditions WHERE chapter = ? ORDER BY seq", (chapter,)
        )]
        figures = [
            (name, joined([text(role), text(significance)], " "))
            for name, role, significance in source.execute(
                "SELECT name, role_in_chapter, significance FROM key_figures WHERE chapter = ? ORDER BY seq", (chapter,)
            )
        ]
        themes = [
            (theme, joined([text(explanation), text(takeaway)], "\n\n"), [])
            for theme, explanation, takeaway in source.execute(
                "SELECT theme, explanation, takeaway FROM key_themes WHERE chapter = ? ORDER BY seq", (chapter,)
            )
        ]
        add_chapter(destination, book, chapter, f"{book} {chapter}: {title}", summary, {
            "historical_setting": text(historical), "what_was_happening": "\n\n".join(happenings),
            "connection_to_chapter": text(connection), "customs_and_traditions": "\n\n".join(customs),
            "why_it_matters": text(why),
        }, figures, themes)


def import_book_overviews(destination):
    destination.execute("ATTACH DATABASE ? AS legacy_books", (str(RESOURCES / "Bible_Book_Overviews_66.sqlite"),))
    destination.execute("INSERT INTO book_overviews SELECT * FROM legacy_books.books")
    destination.execute("INSERT INTO book_movements (book_name, sequence, title, description, key_passages_json) SELECT books.name, book_movements.sequence, book_movements.title, book_movements.description, book_movements.key_passages_json FROM legacy_books.book_movements JOIN legacy_books.books ON books.id = book_movements.book_id")
    destination.execute("INSERT INTO book_key_figures (book_name, sequence, name, description) SELECT books.name, book_key_figures.sequence, book_key_figures.name, book_key_figures.description FROM legacy_books.book_key_figures JOIN legacy_books.books ON books.id = book_key_figures.book_id")
    destination.commit()
    destination.execute("DETACH DATABASE legacy_books")


def create_schema(destination):
    destination.executescript("""
        PRAGMA foreign_keys = ON;
        CREATE TABLE book_overviews (
            id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE, testament TEXT NOT NULL,
            canonical_order INTEGER NOT NULL UNIQUE, traditional_author_or_attribution TEXT NOT NULL,
            original_audience TEXT NOT NULL, purpose TEXT NOT NULL, historical_context TEXT NOT NULL,
            overall_theme TEXT NOT NULL, plain_english_summary TEXT NOT NULL,
            interpretive_notes TEXT NOT NULL, key_scripture_reference TEXT NOT NULL,
            key_scripture_text TEXT NOT NULL
        );
        CREATE TABLE book_movements (
            id INTEGER PRIMARY KEY, book_name TEXT NOT NULL REFERENCES book_overviews(name),
            sequence INTEGER NOT NULL, title TEXT NOT NULL, description TEXT NOT NULL,
            key_passages_json TEXT NOT NULL, UNIQUE(book_name, sequence)
        );
        CREATE TABLE book_key_figures (
            id INTEGER PRIMARY KEY, book_name TEXT NOT NULL REFERENCES book_overviews(name),
            sequence INTEGER NOT NULL, name TEXT NOT NULL, description TEXT NOT NULL,
            UNIQUE(book_name, sequence)
        );
        CREATE TABLE chapter_insights (
            book_name TEXT NOT NULL, chapter_number INTEGER NOT NULL, reference TEXT NOT NULL,
            overall_summary TEXT NOT NULL, historical_setting TEXT NOT NULL,
            what_was_happening TEXT NOT NULL, connection_to_chapter TEXT NOT NULL,
            customs_and_traditions TEXT NOT NULL, why_it_matters TEXT NOT NULL,
            PRIMARY KEY(book_name, chapter_number)
        );
        CREATE TABLE chapter_key_figures (
            id INTEGER PRIMARY KEY, book_name TEXT NOT NULL, chapter_number INTEGER NOT NULL,
            sequence INTEGER NOT NULL, name TEXT NOT NULL, role_and_significance TEXT NOT NULL,
            FOREIGN KEY(book_name, chapter_number) REFERENCES chapter_insights(book_name, chapter_number),
            UNIQUE(book_name, chapter_number, sequence)
        );
        CREATE TABLE chapter_key_themes (
            id INTEGER PRIMARY KEY, book_name TEXT NOT NULL, chapter_number INTEGER NOT NULL,
            sequence INTEGER NOT NULL, theme TEXT NOT NULL, explanation TEXT NOT NULL,
            scripture_references_json TEXT NOT NULL,
            FOREIGN KEY(book_name, chapter_number) REFERENCES chapter_insights(book_name, chapter_number),
            UNIQUE(book_name, chapter_number, sequence)
        );
    """)


def main():
    if OUTPUT.exists():
        OUTPUT.unlink()
    destination = sqlite3.connect(OUTPUT)
    create_schema(destination)
    import_book_overviews(destination)
    for path in sorted(RESOURCES.glob("*_Chapter_Overviews_*.sqlite")):
        source = sqlite3.connect(path)
        tables = {row[0] for row in source.execute("SELECT name FROM sqlite_master WHERE type = 'table'")}
        book = source_book_name(path)
        if "chapter_overviews" in tables:
            import_simple(destination, source)
        elif "historical_context" in tables:
            import_relational(destination, source, book)
        elif "what_was_happening" in tables:
            import_structured(destination, source, book)
        elif "chapters" in tables and "chapter_id" in table_columns(source, "chapters"):
            import_default(destination, source, book)
        elif "chapters" in tables and "historical_connection" in table_columns(source, "chapters"):
            import_embedded(destination, source, book)
        else:
            raise RuntimeError(f"Unrecognized schema: {path.name}")
        source.close()
    destination.commit()
    destination.execute("VACUUM")
    destination.close()


if __name__ == "__main__":
    main()
