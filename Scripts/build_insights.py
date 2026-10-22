#!/usr/bin/env python3
"""Build BibleInsights.sqlite from the hand-written sources, in order, with every check.

    python3 Scripts/build_insights.py            # build and replace the bundled database
    python3 Scripts/build_insights.py --check    # build, report what would change, keep nothing

Every step runs against a working copy of the database in a temporary folder. The bundled
database is replaced only if every step and every check passes, so a failed build leaves
it untouched. Steps, in order (see Scripts/README.md for each source):

 1. add_book_overviews.py       book_overviews/*.json  → book overviews, movements, key figures
 2. add_book_content.py         book_content/*.md      → book history and stories
 3. add_book_guides.py          book_guides/*.json     → reading tips and connections
 4. add_chapter_insights.py     chapter_insights/*.json
                                                       → summaries, Where We Are, key figures and
                                                         themes, explained cross references
 5. add_chapter_context.py      chapter_context/*.json, historical_moments/*.json
                                                       → audience, background, historical moment
 6. add_strict_cross_references.py --rebuild           OpenBible dataset + curated_cross_references.json
                                                       → cross references
 7. collapse_repeated_cross_references.py              one card per parallel passage
 8. repair_bible_insight_references.py                 fixes known reference defects; every reference
                                                       in every table must exist in the KJV
 9. export_book_content.py --check                     book_content/*.md matches the database
10. check_content_quality.py --summary                  house style: placement text, KJV wording,
                                                       outlines, themes, Key People; issues fail the
                                                       build only for quality_reviewed_books.json

Then the build checks database integrity and foreign keys and lists, table by table, how
many rows were added or removed compared with the bundled database.
"""

import json
import os
import shutil
import sqlite3
import subprocess
import sys
import tempfile
from collections import Counter
from pathlib import Path

from insights_common import BUNDLED_DATABASE, KJV


SCRIPTS = Path(__file__).resolve().parent


def book_names():
    return [book["name"] for book in json.loads(KJV.read_text(encoding="utf-8-sig"))]


STEPS = [
    ["add_book_overviews.py"],
    ["add_book_content.py"],
    ["add_book_guides.py"],
    ["add_chapter_insights.py"],
    ["add_chapter_context.py"],
    ["add_strict_cross_references.py", "--rebuild", *book_names()],
    ["collapse_repeated_cross_references.py"],
    ["repair_bible_insight_references.py"],
    ["export_book_content.py", "--check"],
    ["check_content_quality.py", "--summary"],
]


def run_step(number, command, environment):
    label = " ".join(argument for argument in command if not argument[0].isupper() and argument[0] not in "123")
    print(f"{number}. {label}")
    result = subprocess.run(
        [sys.executable, str(SCRIPTS / command[0]), *command[1:]],
        cwd=SCRIPTS, env=environment, capture_output=True, text=True,
    )
    output = (result.stdout + result.stderr).strip().splitlines()
    if result.returncode != 0:
        print("\n".join(f"     {line}" for line in output[-40:]))
        sys.exit(f"Step {number} failed; the bundled database was not changed.")
    # The last lines are each script's summary; dry-run listings above them are skipped.
    for line in output[-2:]:
        print(f"     {line}")


def check_database(path):
    with sqlite3.connect(path) as database:
        integrity = database.execute("PRAGMA integrity_check").fetchone()[0]
        foreign_keys = database.execute("PRAGMA foreign_key_check").fetchall()
    if integrity != "ok" or foreign_keys:
        sys.exit(f"Database check failed (integrity: {integrity}, foreign key problems: {len(foreign_keys)}); "
                 "the bundled database was not changed.")


def table_rows(database):
    """Each table's rows as a multiset, ignoring the id column, which a rebuild renumbers."""
    tables = {}
    for (table,) in database.execute("SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name"):
        columns = [row[1] for row in database.execute(f"PRAGMA table_info({table})") if row[1] != "id"]
        tables[table] = Counter(database.execute(f"SELECT {', '.join(columns)} FROM {table}"))
    return tables


def report_changes(before_path, after_path):
    with sqlite3.connect(before_path) as before, sqlite3.connect(after_path) as after:
        old, new = table_rows(before), table_rows(after)
    changed = False
    for table in sorted(set(old) | set(new)):
        added = sum((new.get(table, Counter()) - old.get(table, Counter())).values())
        removed = sum((old.get(table, Counter()) - new.get(table, Counter())).values())
        if added or removed:
            changed = True
            print(f"     {table}: +{added} −{removed} rows")
    if not changed:
        print("     No content changes.")
    return changed


def main():
    check_only = "--check" in sys.argv
    with tempfile.TemporaryDirectory() as folder:
        working = Path(folder) / BUNDLED_DATABASE.name
        shutil.copyfile(BUNDLED_DATABASE, working)
        environment = {**os.environ, "BIBLE_INSIGHTS_DATABASE": str(working), "PYTHONHASHSEED": "0"}

        for number, command in enumerate(STEPS, 1):
            run_step(number, command, environment)

        print("Checking the result")
        check_database(working)
        with sqlite3.connect(working) as database:
            database.execute("VACUUM")
        changed = report_changes(BUNDLED_DATABASE, working)

        if check_only:
            print("Check only: the bundled database was not changed.")
            return
        if not changed:
            print("The bundled database is already up to date.")
            return
        # Copy beside the bundled file first so the final rename can't leave it half written.
        staged = BUNDLED_DATABASE.with_name(BUNDLED_DATABASE.name + ".new")
        shutil.copyfile(working, staged)
        os.replace(staged, BUNDLED_DATABASE)
        print(f"Replaced {BUNDLED_DATABASE.relative_to(BUNDLED_DATABASE.parents[1])}. Rebuild the app to include it.")


if __name__ == "__main__":
    main()
