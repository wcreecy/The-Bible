#!/usr/bin/env python3
"""Merges hand-edited dictionary entries into `Scripts/data/lexicon_edits.csv` and the bundled
`The Bible (iOS)/OriginalWords.sqlite`, so a later rebuild keeps them.

    python3 -I Scripts/import_lexicon_edits.py PATH/TO/edits.csv            # merge and update
    python3 -I Scripts/import_lexicon_edits.py PATH/TO/edits.csv --check    # report only

The CSV has the columns strongs_number, language, lemma, transliteration, gloss, definition (an
export of the whole dictionary works, and so does a few rows). For each row:

- if it differs from STEPBible's entry, it becomes that entry's edit, replacing any earlier one;
- if it is the same as STEPBible's, any earlier edit of that entry is dropped, so pasting the
  original text back undoes an edit.

Entries the CSV doesn't list keep their earlier edits. The database is updated in place (with
new search keys for a changed lemma or transliteration), so no rebuild is needed; a rebuild
applies the same edits. Needs STEPBible's lexicon files in `Scripts/data/stepbible/` to tell
edits from the original text.
"""
import importlib.util
import pathlib
import sqlite3
import sys

_spec = importlib.util.spec_from_file_location(
    "build_original_words", pathlib.Path(__file__).resolve().parent / "build_original_words.py")
bow = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(bow)


def stepbible_entries():
    paths = {"hebrew": next(iter(bow.SOURCES.glob("TBESH*.txt")), None),
             "greek": next(iter(bow.SOURCES.glob("TBESG*.txt")), None)}
    if not all(paths.values()):
        sys.exit(f"TBESH and TBESG must be in {bow.SOURCES.relative_to(bow.ROOT)} to compare with; "
                 "Scripts/data/README.md says where to download them.")
    entries = {}
    for language, path in paths.items():
        entries.update(bow.parse_lexicon(path, language))
    return entries


def merge(incoming, existing, originals):
    """The edits after taking in `incoming`, and what changed: (added, replaced, dropped,
    unchanged, problems)."""
    edits = dict(existing)
    added, replaced, dropped, unchanged, problems = [], [], [], [], []
    for key, row in sorted(incoming.items()):
        original = originals.get(key)
        if original is None:
            problems.append(f"{key}: STEPBible has no such entry.")
        elif original[1] != row[1]:
            problems.append(f"{key}: listed as {row[1]}, but the entry is {original[1]}.")
        elif row == original:
            if edits.pop(key, None) is not None:
                dropped.append(key)
        elif edits.get(key) == row:
            unchanged.append(key)
        else:
            (replaced if key in edits else added).append(key)
            edits[key] = row
    return edits, (added, replaced, dropped, unchanged, problems)


def update_database(path, keys, edits, originals):
    """Writes each key's edit, or STEPBible's text where it has none, into the database."""
    database = sqlite3.connect(path)
    present = {row[0] for row in database.execute("SELECT strongs FROM lexicon")}
    written = 0
    with database:
        for key in keys:
            if key not in present:
                continue
            _, _, lemma, translit, gloss, definition = edits.get(key, originals[key])
            database.execute(
                "UPDATE lexicon SET lemma=?, translit=?, gloss=?, definition=?, lemma_key=?, "
                "translit_key=? WHERE strongs=?",
                (lemma, translit, gloss, definition, bow.search_key(lemma), bow.search_key(translit), key),
            )
            written += 1
    database.execute("INSERT OR REPLACE INTO meta VALUES (?, ?)",
                     (bow.LEXICON_EDITS.name, bow.sha256(bow.LEXICON_EDITS)))
    database.commit()
    database.execute("VACUUM")
    database.close()
    return written


def main():
    arguments = [argument for argument in sys.argv[1:] if not argument.startswith("--")]
    if len(arguments) != 1:
        sys.exit(__doc__)
    check_only = "--check" in sys.argv
    incoming = bow.read_lexicon_edits(pathlib.Path(arguments[0]).expanduser())
    originals = stepbible_entries()
    existing = bow.read_lexicon_edits(bow.LEXICON_EDITS)
    edits, (added, replaced, dropped, unchanged, problems) = merge(incoming, existing, originals)

    print(f"{len(incoming):,} rows read; {len(added):,} new edits, {len(replaced):,} edits replaced, "
          f"{len(dropped):,} edits dropped (back to STEPBible's text), {len(unchanged):,} edits "
          f"already in place, {len(incoming) - len(added) - len(replaced) - len(dropped) - len(unchanged) - len(problems):,} "
          f"rows the same as STEPBible's.")
    print(f"{len(edits):,} entries will have hand edits ({len(existing):,} before).")
    if problems:
        print(f"{len(problems)} rows skipped:")
        print("\n".join(f"  {problem}" for problem in problems[:20]))
    if check_only:
        print("Nothing written.")
        return

    bow.write_lexicon_edits(bow.LEXICON_EDITS, edits)
    written = update_database(bow.OUTPUT, added + replaced + dropped, edits, originals)
    print(f"Wrote {bow.LEXICON_EDITS.relative_to(bow.ROOT)} and updated {written:,} entries in "
          f"{bow.OUTPUT.relative_to(bow.ROOT)}.")


if __name__ == "__main__":
    main()
