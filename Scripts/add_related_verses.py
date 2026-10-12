#!/usr/bin/env python3
"""Add a "Related Verses" table to BibleInsights.sqlite and export the full JSON.

Related verses come from the OpenBible.info cross-reference dataset (CC-BY),
which is derived from the Treasury of Scripture Knowledge and ranked by votes:
https://a.openbible.info/data/cross-references.zip

Usage:
    python3 Scripts/add_related_verses.py path/to/cross_references.txt [output_dir]
"""

import json
import sqlite3
import sys
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATABASE = ROOT / "The Bible (iOS)" / "BibleInsights.sqlite"
KJV = ROOT / "The Bible" / "kjv.json"

OSIS_BOOKS = [
    "Gen", "Exod", "Lev", "Num", "Deut", "Josh", "Judg", "Ruth", "1Sam", "2Sam",
    "1Kgs", "2Kgs", "1Chr", "2Chr", "Ezra", "Neh", "Esth", "Job", "Ps", "Prov",
    "Eccl", "Song", "Isa", "Jer", "Lam", "Ezek", "Dan", "Hos", "Joel", "Amos",
    "Obad", "Jonah", "Mic", "Nah", "Hab", "Zeph", "Hag", "Zech", "Mal", "Matt",
    "Mark", "Luke", "John", "Acts", "Rom", "1Cor", "2Cor", "Gal", "Eph", "Phil",
    "Col", "1Thess", "2Thess", "1Tim", "2Tim", "Titus", "Phlm", "Heb", "Jas", "1Pet",
    "2Pet", "1John", "2John", "3John", "Jude", "Rev",
]

MAX_PER_CHAPTER = 15
MAX_PER_SOURCE_VERSE = 3
MIN_VOTES = 1


def parse_verse(osis, book_names):
    book, chapter, verse = osis.split(".")
    return book_names[book], int(chapter), int(verse)


def parse_target(osis, book_names):
    """Returns (book, chapter, start_verse, end_chapter, end_verse)."""
    start, _, end = osis.partition("-")
    book, chapter, verse = parse_verse(start, book_names)
    if not end:
        return book, chapter, verse, chapter, verse
    end_book, end_chapter, end_verse = parse_verse(end, book_names)
    if end_book != book:
        return book, chapter, verse, chapter, verse
    return book, chapter, verse, end_chapter, end_verse


def format_target(book, chapter, verse, end_chapter, end_verse):
    if (end_chapter, end_verse) == (chapter, verse):
        return f"{book} {chapter}:{verse}"
    if end_chapter == chapter:
        return f"{book} {chapter}:{verse}-{end_verse}"
    return f"{book} {chapter}:{verse}-{end_chapter}:{end_verse}"


def verse_exists(verse_counts, book, chapter, verse):
    chapters = verse_counts[book]
    return 1 <= chapter <= len(chapters) and 1 <= verse <= chapters[chapter - 1]


def load_related_verses(cross_references_path, book_order, verse_counts):
    book_names = dict(zip(OSIS_BOOKS, book_order))
    candidates = defaultdict(list)

    with open(cross_references_path, encoding="utf-8") as source:
        next(source)
        for line in source:
            from_osis, to_osis, votes = line.rstrip("\n").split("\t")[:3]
            votes = int(votes)
            if votes < MIN_VOTES:
                continue
            book, chapter, verse = parse_verse(from_osis, book_names)
            target = parse_target(to_osis, book_names)
            target_book, target_chapter, target_verse, end_chapter, end_verse = target
            # Skip links back into the same chapter; they aren't "other" verses.
            if target_book == book and target_chapter == chapter:
                continue
            if not verse_exists(verse_counts, book, chapter, verse):
                continue
            if not verse_exists(verse_counts, target_book, target_chapter, target_verse):
                continue
            if not verse_exists(verse_counts, target_book, end_chapter, end_verse):
                target = (target_book, target_chapter, target_verse, target_chapter, target_verse)
            elif end_chapter != target_chapter:
                # The app's passage links only handle ranges within one chapter, so
                # clamp "4:25-5:32" to the end of its first chapter ("4:25-26").
                last_verse = verse_counts[target_book][target_chapter - 1]
                target = (target_book, target_chapter, target_verse, target_chapter, last_verse)
            candidates[(book, chapter)].append((votes, verse, format_target(*target)))

    related = {}
    for key, links in candidates.items():
        links.sort(key=lambda link: (-link[0], link[1]))
        chosen, seen_targets, per_verse = [], set(), defaultdict(int)
        for votes, verse, target in links:
            if target in seen_targets or per_verse[verse] >= MAX_PER_SOURCE_VERSE:
                continue
            seen_targets.add(target)
            per_verse[verse] += 1
            chosen.append((verse, target, votes))
            if len(chosen) == MAX_PER_CHAPTER:
                break
        # Present in reading order: by source verse, strongest link first.
        chosen.sort(key=lambda link: (link[0], -link[2]))
        related[key] = chosen
    return related


def write_related_verses(database, related):
    database.executescript("""
        DROP TABLE IF EXISTS chapter_related_verses;
        CREATE TABLE chapter_related_verses (
            id INTEGER PRIMARY KEY, book_name TEXT NOT NULL, chapter_number INTEGER NOT NULL,
            sequence INTEGER NOT NULL, source_verse INTEGER NOT NULL,
            related_reference TEXT NOT NULL, votes INTEGER NOT NULL,
            FOREIGN KEY(book_name, chapter_number) REFERENCES chapter_insights(book_name, chapter_number),
            UNIQUE(book_name, chapter_number, sequence)
        );
    """)
    chapters = set(database.execute("SELECT book_name, chapter_number FROM chapter_insights"))
    rows = [
        (book, chapter, index, verse, target, votes)
        for (book, chapter), links in sorted(related.items())
        if (book, chapter) in chapters
        for index, (verse, target, votes) in enumerate(links)
    ]
    database.executemany(
        """
        INSERT INTO chapter_related_verses (
            book_name, chapter_number, sequence, source_verse, related_reference, votes
        ) VALUES (?, ?, ?, ?, ?, ?)
        """,
        rows,
    )
    database.commit()
    database.execute("VACUUM")
    return len(rows)


def export_json(database, output):
    database.row_factory = sqlite3.Row

    def rows(query, *parameters):
        return database.execute(query, parameters).fetchall()

    book_overviews = []
    for book in rows("SELECT * FROM book_overviews ORDER BY canonical_order"):
        name = book["name"]
        history = rows("SELECT * FROM book_history WHERE book_name = ?", name)
        book_overviews.append({
            "name": name,
            "testament": book["testament"],
            "canonicalOrder": book["canonical_order"],
            "traditionalAuthorOrAttribution": book["traditional_author_or_attribution"],
            "originalAudience": book["original_audience"],
            "purpose": book["purpose"],
            "historicalContext": book["historical_context"],
            "overallTheme": book["overall_theme"],
            "plainEnglishSummary": book["plain_english_summary"],
            "interpretiveNotes": book["interpretive_notes"],
            "keyScripture": {
                "reference": book["key_scripture_reference"],
                "text": book["key_scripture_text"],
            },
            "whenAndWhere": {
                "whenItHappened": history[0]["when_it_happened"],
                "whenItWasWritten": history[0]["when_it_was_written"],
                "location": history[0]["location"],
                "worldAtTheTime": history[0]["world_at_the_time"],
            } if history else None,
            "story": [
                {"sequence": section["sequence"], "passage": section["passage"], "text": section["text"]}
                for section in rows(
                    "SELECT * FROM book_story_sections WHERE book_name = ? ORDER BY sequence", name
                )
            ],
            "movements": [
                {
                    "sequence": movement["sequence"],
                    "title": movement["title"],
                    "description": movement["description"],
                    "keyPassages": json.loads(movement["key_passages_json"]),
                }
                for movement in rows(
                    "SELECT * FROM book_movements WHERE book_name = ? ORDER BY sequence", name
                )
            ],
            "keyFigures": [
                {"sequence": figure["sequence"], "name": figure["name"], "description": figure["description"]}
                for figure in rows(
                    "SELECT * FROM book_key_figures WHERE book_name = ? ORDER BY sequence", name
                )
            ],
        })

    chapter_insights = []
    for chapter in rows("SELECT * FROM chapter_insights ORDER BY book_name, chapter_number"):
        key = (chapter["book_name"], chapter["chapter_number"])
        chapter_insights.append({
            "bookName": chapter["book_name"],
            "chapterNumber": chapter["chapter_number"],
            "reference": chapter["reference"],
            "overallSummary": chapter["overall_summary"],
            "historicalSetting": chapter["historical_setting"],
            "whatWasHappening": chapter["what_was_happening"],
            "connectionToChapter": chapter["connection_to_chapter"],
            "customsAndTraditions": chapter["customs_and_traditions"],
            "whyItMatters": chapter["why_it_matters"],
            "keyFigures": [
                {
                    "sequence": figure["sequence"],
                    "name": figure["name"],
                    "roleAndSignificance": figure["role_and_significance"],
                }
                for figure in rows(
                    "SELECT * FROM chapter_key_figures WHERE book_name = ? AND chapter_number = ? ORDER BY sequence",
                    *key,
                )
            ],
            "keyThemes": [
                {
                    "sequence": theme["sequence"],
                    "theme": theme["theme"],
                    "explanation": theme["explanation"],
                    "scriptureReferences": json.loads(theme["scripture_references_json"]),
                }
                for theme in rows(
                    "SELECT * FROM chapter_key_themes WHERE book_name = ? AND chapter_number = ? ORDER BY sequence",
                    *key,
                )
            ],
            "relatedVerses": [
                {
                    "sequence": link["sequence"],
                    "sourceVerse": link["source_verse"],
                    "sourceReference": f"{key[0]} {key[1]}:{link['source_verse']}",
                    "relatedReference": link["related_reference"],
                    "votes": link["votes"],
                }
                for link in rows(
                    "SELECT * FROM chapter_related_verses WHERE book_name = ? AND chapter_number = ? ORDER BY sequence",
                    *key,
                )
            ],
        })

    output.write_text(
        json.dumps({"bookOverviews": book_overviews, "chapterInsights": chapter_insights}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    cross_references_path = Path(sys.argv[1])
    output_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else None

    kjv = json.loads(KJV.read_text(encoding="utf-8-sig"))
    database = sqlite3.connect(DATABASE)
    book_order = [name for (name,) in database.execute("SELECT name FROM book_overviews ORDER BY canonical_order")]
    verse_counts = {
        name: [len(chapter) for chapter in book["chapters"]]
        for name, book in zip(book_order, kjv)
    }

    related = load_related_verses(cross_references_path, book_order, verse_counts)
    count = write_related_verses(database, related)
    print(f"Wrote {count} related verses for {len(related)} chapters to {DATABASE}")

    if output_dir:
        output_dir.mkdir(parents=True, exist_ok=True)
        database.close()
        (output_dir / "BibleInsights.sqlite").write_bytes(DATABASE.read_bytes())
        database = sqlite3.connect(DATABASE)
        export_json(database, output_dir / "BibleInsights.json")
        print(f"Exported BibleInsights.sqlite and BibleInsights.json to {output_dir}")
    database.close()


if __name__ == "__main__":
    main()
