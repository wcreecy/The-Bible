#!/usr/bin/env python3
"""Clean imported chapter insight text in BibleInsights.sqlite.

1. Restores sentence breaks lost when key figure descriptions were imported:
   "Those whom readers are commanded to love Their treatment discloses…" becomes
   "Those whom readers are commanded to love. Their treatment discloses…"
2. Clears boilerplate "original audience" text that is shared word for word by many
   chapters, so the app shows that field only where it says something chapter-specific.

Every step is safe to run again:
    python3 Scripts/clean_chapter_insights.py [--dry-run]
"""

import re
import sqlite3
import sys

from add_related_verses import DATABASE


# Words that begin the second sentence in the imported descriptions. A lowercase word (or a
# closing parenthesis) followed by one of these and then a lowercase word marks a lost period.
SENTENCE_STARTERS = ["Part", "Their", "His", "Her", "Its", "This", "These", "Collective", "The", "He", "She", "They", "Represents"]
LOST_PERIOD = re.compile(r"(?<=[a-z0-9)’'])( )(?=(?:" + "|".join(SENTENCE_STARTERS) + r") [a-z])")

# A value repeated in more chapters than this is boilerplate rather than chapter context.
BOILERPLATE_THRESHOLD = 10


def restore_sentence_breaks(database, dry_run):
    changed = []
    for row_id, text in database.execute("SELECT id, role_and_significance FROM chapter_key_figures"):
        fixed = LOST_PERIOD.sub(". ", text)
        if fixed != text:
            changed.append((fixed, row_id))
    if not dry_run:
        database.executemany("UPDATE chapter_key_figures SET role_and_significance = ? WHERE id = ?", changed)
    return changed


def clear_boilerplate_audience(database, dry_run):
    shared = [text for (text,) in database.execute(f"""
        SELECT original_audience FROM chapter_reading_contexts
        WHERE trim(original_audience) <> ''
        GROUP BY original_audience HAVING count(*) > {BOILERPLATE_THRESHOLD}
    """)]
    if dry_run:
        return sum(database.execute(
            "SELECT count(*) FROM chapter_reading_contexts WHERE original_audience = ?", (text,)
        ).fetchone()[0] for text in shared)
    return sum(database.execute(
        "UPDATE chapter_reading_contexts SET original_audience = '' WHERE original_audience = ?", (text,)
    ).rowcount for text in shared)


def main():
    dry_run = "--dry-run" in sys.argv
    with sqlite3.connect(DATABASE) as database:
        changed = restore_sentence_breaks(database, dry_run)
        cleared = clear_boilerplate_audience(database, dry_run)
    verb = "Would update" if dry_run else "Updated"
    print(f"{verb} {len(changed)} key figure descriptions")
    for fixed, _ in changed[:8]:
        print(f"  {fixed[:150]}")
    print(f"{verb} {cleared} boilerplate original-audience entries")


if __name__ == "__main__":
    main()
