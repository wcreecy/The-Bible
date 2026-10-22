# Scripts

## Building the study database

`The Bible (iOS)/BibleInsights.sqlite` holds everything on the book overview and chapter
insights pages. Edit the source files below, then run:

```sh
python3 Scripts/build_insights.py --check   # see what would change; keeps nothing
python3 Scripts/build_insights.py           # build and replace the bundled database
```

The build runs every step against a copy of the database and replaces the bundled file only
if every step and check passes. A build from unchanged sources reports "No content changes".
Rebuild the app afterwards to include the new database.

| Source | What it holds | Loaded by |
| --- | --- | --- |
| `book_overviews/*.json` | Each book's author, audience, purpose, theme, summary, key verse, movements, and key figures | `add_book_overviews.py` |
| `book_content/*.md` | Each book's When & Where section and story | `add_book_content.py` |
| `book_guides/*.json` | Book reading tips and connections | `add_book_guides.py` |
| `chapter_insights/*.json` | Each chapter's summary, Where We Are text, key figures, key themes, and explained cross references | `add_chapter_insights.py` |
| `chapter_context/*.json` | Chapter original audience and cultural background | `add_chapter_context.py` |
| `historical_moments/*.json` | Chapter "Historical Moment" text | `add_chapter_context.py` |
| `data/openbible_cross_references.zip` | OpenBible.info cross-reference dataset (CC-BY; see `data/README.md`) | `add_strict_cross_references.py` |
| `curated_cross_references.json` | Hand-picked cross references the dataset misses | `add_strict_cross_references.py` |

After loading, the build collapses repeated parallel-passage cards
(`collapse_repeated_cross_references.py`), repairs known reference defects and checks that
every reference in every table exists in the KJV (`repair_bible_insight_references.py`), and
confirms `book_content/*.md` matches the database (`export_book_content.py --check`).

Last, `check_content_quality.py` checks the house style that the reference and quote checks
can't: Where We Are text that places the chapter instead of filler, exact KJV wording even in
single quotes, summaries with citations for the What Happens outline, explained themes, at
most six Key People, distinct Historical Moment and Original Audience text, lowercase
pronouns for God, and KJV spellings of names. Run `python3 Scripts/check_content_quality.py`
for open issues by book, or add `--book Joshua` for every issue in one book. When a book has
had a full review, add it to `quality_reviewed_books.json`; from then on any issue in that
book fails the build.

Each step can also be run on its own; they all write to the database `insights_common.py`
names. Every content file is checked against `The Bible/kjv.json`: references must exist and
double-quoted text must match the KJV wording.

Every table in the database is built from these files, so the database is purely a build
output: don't edit it directly, because the next build replaces it. A key verse's text is
copied from the KJV at build time, so only its reference is in `book_overviews/`. If the book
stories or history are ever changed directly in the database,
`python3 Scripts/export_book_content.py` writes them back to `book_content/*.md`.

## Other generated files

| Command | Output |
| --- | --- |
| `python3 Scripts/make_lockscreen_verses.py` | `The Bible Widgets/LockScreenVerses.json`, shared by the app and the widget. Re-run after editing its verse list or `kjv.json`. |

## One-time and occasional tools

These have already been applied, or produce material for review rather than app data.

| Script | Purpose |
| --- | --- |
| `fix_kjv_versification.py` | Restored standard KJV verse numbering in `kjv.json`; skips fixes already applied. Writes `kjv_fixes_review.md`. |
| `mark_words_of_jesus.py` | Added red-letter markers to `kjv.json`. Needs an external red-letter source repository. |
| `word_game_candidates.py`, `make_word_game_words.py` | Drafted the WORD game list. The game reads `The Bible/WORDCuratedWordList.json`; edit that file directly. |
