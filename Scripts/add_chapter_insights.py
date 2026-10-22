#!/usr/bin/env python3
"""Load chapter insights into BibleInsights.sqlite.

The content is in Scripts/chapter_insights/*.json, one file per book and one object per chapter:

    "Ruth 1": {
      "summary": "…",
      "whereWeAre": "Where the chapter falls in the book's story…",
      "keyFigures": [{"name": "Naomi", "role": "…"}],
      "keyThemes": [{"theme": "…", "explanation": "…", "references": ["Ruth 1:16-17"]}],
      "explainedReferences": [{"verse": 16, "reference": "Matthew 1:5", "explanation": "…"}]
    }

Every chapter must be present. Fields may be empty strings or empty lists. Every reference
must exist in the KJV and every double-quoted passage must match it; nothing is written if
any check fails.

Replaces chapter_insights, chapter_key_figures, chapter_key_themes, chapter_scripture_connections,
the "Where We Are" text in chapter_reading_contexts, and the explained cross references in
chapter_related_verses (stored with 0 votes). Other cross references are left in place, after
the explained ones; build_insights.py then rebuilds them from the OpenBible dataset and
curated_cross_references.json.

    python3 Scripts/add_chapter_insights.py [--check]
"""

import json
import re
import sqlite3
import sys
from pathlib import Path

from add_book_guides import quote_problems, reference_problems
from book_content_tools import kjv_books
from insights_common import DATABASE, KJV


CONTENT = Path(__file__).resolve().parent / "chapter_insights"
FIELDS = {"summary", "whereWeAre", "keyFigures", "keyThemes", "explainedReferences"}
CHAPTER_KEY = re.compile(r"^(.+) (\d+)$")
EXPLAINED_VOTES = 0


def load_chapters():
    chapters = {}
    for path in sorted(CONTENT.glob("*.json")):
        for key, entry in json.loads(path.read_text(encoding="utf-8")).items():
            if key in chapters:
                raise ValueError(f"{path.name}: {key} appears twice")
            chapters[key] = entry
    return chapters


def validate(chapters, chapters_by_book):
    bible = " ".join(kjv_books())
    expected = {f"{book} {number}" for book, chapters_list in chapters_by_book.items() for number in range(1, len(chapters_list) + 1)}
    problems = []
    if set(chapters) != expected:
        problems.append(f"chapters missing {sorted(expected - set(chapters))[:10]}, unknown {sorted(set(chapters) - expected)[:10]}")
    for key, entry in chapters.items():
        if key not in expected:
            continue
        if set(entry) != FIELDS:
            problems.append(f"{key}: expected keys {sorted(FIELDS)}, found {sorted(entry)}")
            continue
        book, chapter = CHAPTER_KEY.match(key).group(1, 2)
        verse_count = len(chapters_by_book[book][int(chapter) - 1])
        texts = [entry["summary"], entry["whereWeAre"]]
        for figure in entry["keyFigures"]:
            if set(figure) != {"name", "role"}:
                problems.append(f"{key}: malformed key figure {figure}")
                continue
            texts += [figure["name"], figure["role"]]
        for theme in entry["keyThemes"]:
            if set(theme) != {"theme", "explanation", "references"}:
                problems.append(f"{key}: malformed key theme {theme}")
                continue
            texts += [theme["theme"], theme["explanation"]]
            for reference in theme["references"]:
                problems += [f"{key}: theme reference {p}" for p in reference_problems(reference, chapters_by_book)]
        seen = set()
        for explained in entry["explainedReferences"]:
            if set(explained) != {"verse", "reference", "explanation"}:
                problems.append(f"{key}: malformed explained reference {explained}")
                continue
            if not 1 <= explained["verse"] <= verse_count:
                problems.append(f"{key}: no verse {explained['verse']} for explained reference {explained['reference']}")
            if (explained["verse"], explained["reference"]) in seen:
                problems.append(f"{key}: verse {explained['verse']} → {explained['reference']} appears twice")
            seen.add((explained["verse"], explained["reference"]))
            problems += [f"{key}: explained reference {p}" for p in reference_problems(explained["reference"], chapters_by_book)]
            texts.append(explained["explanation"])
        for text in texts:
            problems += [f"{key}: {p}" for p in reference_problems(text, chapters_by_book) + quote_problems(text, bible)]
    return problems


def write_chapters(database, chapters):
    for table in ("chapter_insights", "chapter_key_figures", "chapter_key_themes", "chapter_scripture_connections"):
        database.execute(f"DELETE FROM {table}")
    database.execute("DELETE FROM chapter_related_verses WHERE votes = ?", (EXPLAINED_VOTES,))

    for key, entry in chapters.items():
        book, chapter = CHAPTER_KEY.match(key).group(1, 2)
        chapter = int(chapter)
        database.execute(
            "INSERT INTO chapter_insights (book_name, chapter_number, overall_summary) VALUES (?, ?, ?)",
            (book, chapter, entry["summary"]),
        )
        # The other reading-context fields come from add_chapter_context.py.
        database.execute(
            "INSERT INTO chapter_reading_contexts (book_name, chapter_number, in_story, historical_moment, original_audience)"
            " VALUES (?, ?, ?, '', '') ON CONFLICT (book_name, chapter_number) DO UPDATE SET in_story = excluded.in_story",
            (book, chapter, entry["whereWeAre"]),
        )
        database.executemany(
            "INSERT INTO chapter_key_figures (book_name, chapter_number, sequence, name, role_and_significance) VALUES (?, ?, ?, ?, ?)",
            [(book, chapter, index, figure["name"], figure["role"]) for index, figure in enumerate(entry["keyFigures"])],
        )
        database.executemany(
            "INSERT INTO chapter_key_themes (book_name, chapter_number, sequence, theme, explanation, scripture_references_json)"
            " VALUES (?, ?, ?, ?, ?, ?)",
            [(book, chapter, index, theme["theme"], theme["explanation"], json.dumps(theme["references"], ensure_ascii=False))
             for index, theme in enumerate(entry["keyThemes"])],
        )
        explained = entry["explainedReferences"]
        if not explained:
            continue
        # Explained references come first; any other cross references in the chapter follow, in order.
        others = database.execute(
            "SELECT id FROM chapter_related_verses WHERE book_name = ? AND chapter_number = ? ORDER BY sequence",
            (book, chapter),
        ).fetchall()
        for offset, (row_id,) in enumerate(others):
            database.execute("UPDATE chapter_related_verses SET sequence = ? WHERE id = ?", (-1 - offset, row_id))
        for offset, (row_id,) in enumerate(others):
            database.execute("UPDATE chapter_related_verses SET sequence = ? WHERE id = ?", (len(explained) + offset, row_id))
        database.executemany(
            "INSERT INTO chapter_related_verses (book_name, chapter_number, sequence, source_verse, related_reference, votes)"
            " VALUES (?, ?, ?, ?, ?, ?)",
            [(book, chapter, index, item["verse"], item["reference"], EXPLAINED_VOTES) for index, item in enumerate(explained)],
        )
        database.executemany(
            "INSERT INTO chapter_scripture_connections (book_name, chapter_number, source_verse, related_reference, explanation)"
            " VALUES (?, ?, ?, ?, ?)",
            [(book, chapter, item["verse"], item["reference"], item["explanation"]) for item in explained],
        )


def main():
    kjv = json.loads(KJV.read_text(encoding="utf-8-sig"))
    chapters_by_book = {book["name"]: book["chapters"] for book in kjv}
    chapters = load_chapters()
    problems = validate(chapters, chapters_by_book)
    for problem in problems[:60]:
        print(problem)
    figures = sum(len(entry.get("keyFigures", [])) for entry in chapters.values())
    themes = sum(len(entry.get("keyThemes", [])) for entry in chapters.values())
    explained = sum(len(entry.get("explainedReferences", [])) for entry in chapters.values())
    print(f"{len(chapters)} chapters, {figures} key figures, {themes} key themes, "
          f"{explained} explained cross references, {len(problems)} problems")
    if problems or "--check" in sys.argv:
        sys.exit(1 if problems else 0)
    with sqlite3.connect(DATABASE) as database:
        write_chapters(database, chapters)


if __name__ == "__main__":
    main()
