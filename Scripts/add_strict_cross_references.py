#!/usr/bin/env python3
"""Fill in cross references for chapters that have none, keeping only direct links.

Candidates come from the OpenBible.info cross-reference dataset (CC-BY):
https://a.openbible.info/data/cross-references.zip

Unlike add_related_verses.py, which rebuilds the whole table, this only adds rows for
chapters in the chosen books that have no cross references yet, so hand-explained
references elsewhere are left untouched. A candidate is kept only if it is:

- a quotation: the two verses share a rare four-word phrase containing at least two
  distinctive words (so stock wording like "and it came to pass" doesn't count), or
- a named link: both verses name the same uncommon person or place, and the link has
  at least MIN_NAME_VOTES votes, or
- a stated fulfillment from Scripts/curated_cross_references.json, where one passage
  records that the other came to pass.

Usage:
    python3 Scripts/add_strict_cross_references.py path/to/cross_references.txt [Book ...] [--dry-run]

With no books given, it fills Genesis through Ruth. Safe to run again.
"""

import collections
import json
import re
import sqlite3
import sys
from pathlib import Path

from add_related_verses import DATABASE, OSIS_BOOKS, format_target
from book_content_tools import KJV, normalize


DEFAULT_BOOKS = ["Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua", "Judges", "Ruth"]
CURATED = Path(__file__).resolve().parent / "curated_cross_references.json"

MAX_PER_CHAPTER = 15
MAX_PER_SOURCE_VERSE = 3
MIN_NAME_VOTES = 5
# A phrase in more verses than this is a formula, not a quotation.
MAX_PHRASE_VERSES = 25
# A word in more verses than this is too common to make a phrase distinctive.
MAX_DISTINCTIVE_WORD_VERSES = 600
# A name in more verses than this (Abraham, Moses, Israel) links too much to be specific.
MAX_NAME_VERSES = 120
CURATED_VOTES = 1000
REFERENCE = re.compile(r"^(.+?) (\d+):(\d+)(?:-(\d+)(?::(\d+))?)?$")


class Bible:
    def __init__(self):
        kjv = json.loads(KJV.read_text(encoding="utf-8-sig"))
        self.book_names = [book["name"] for book in kjv]
        self.verse_counts = {book["name"]: [len(chapter) for chapter in book["chapters"]] for book in kjv}
        self.text = {
            (book["name"], c + 1, v + 1): re.sub(r"\{[^{}]*\}", " ", text)
            for book in kjv for c, chapter in enumerate(book["chapters"]) for v, text in enumerate(chapter)
        }
        self.words = {key: normalize(text).split() for key, text in self.text.items()}
        self.phrase_verses = collections.Counter(p for words in self.words.values() for p in self.phrases(words))
        self.word_verses = collections.Counter(w for words in self.words.values() for w in set(words))

        # A proper name is a word that is capitalized (almost) everywhere it appears mid-verse.
        capitalized, total = collections.Counter(), collections.Counter()
        for text in self.text.values():
            for word in re.findall(r"[A-Za-z]+", text)[1:]:
                total[word.lower()] += 1
                capitalized[word.lower()] += word[0].isupper()
        self.names = {w for w in total if capitalized[w] / total[w] > 0.95 and self.word_verses[w] <= MAX_NAME_VERSES}

    @staticmethod
    def phrases(words, length=4):
        return {" ".join(words[i:i + length]) for i in range(len(words) - length + 1)}

    def exists(self, book, chapter, verse):
        counts = self.verse_counts.get(book)
        return bool(counts) and 1 <= chapter <= len(counts) and 1 <= verse <= counts[chapter - 1]

    def names_in(self, key):
        return {w.lower() for w in re.findall(r"\b[A-Z][a-z]+\b", self.text[key])} & self.names

    def reason(self, source, target, votes):
        """Why the link is direct, or None when it is only thematic."""
        for phrase in self.phrases(self.words[source]) & self.phrases(self.words[target]):
            distinctive = [w for w in phrase.split() if self.word_verses[w] <= MAX_DISTINCTIVE_WORD_VERSES]
            if self.phrase_verses[phrase] <= MAX_PHRASE_VERSES and len(distinctive) >= 2:
                return f"quotes \"{phrase}\""
        shared = self.names_in(source) & self.names_in(target)
        if shared and votes >= MIN_NAME_VOTES:
            return "names " + ", ".join(sorted(shared))
        return None


def parse_osis(osis, book_names):
    book, chapter, verse = osis.split(".")
    return book_names[book], int(chapter), int(verse)


def candidate_links(path, bible, books):
    osis_names = dict(zip(OSIS_BOOKS, bible.book_names))
    links = collections.defaultdict(list)
    with open(path, encoding="utf-8") as source:
        next(source)
        for line in source:
            from_osis, to_osis, votes = line.rstrip("\n").split("\t")[:3]
            book, chapter, verse = parse_osis(from_osis, osis_names)
            if book not in books:
                continue
            start, _, end = to_osis.partition("-")
            target = parse_osis(start, osis_names)
            if target[:2] == (book, chapter) or not bible.exists(*target) or not bible.exists(book, chapter, verse):
                continue
            reason = bible.reason((book, chapter, verse), target, int(votes))
            if not reason:
                continue
            # Keep ranges only within one chapter, which the app's passage links support.
            end_verse = target[2]
            if end:
                end_book, end_chapter, last = parse_osis(end, osis_names)
                if (end_book, end_chapter) == target[:2] and bible.exists(end_book, end_chapter, last):
                    end_verse = last
            reference = format_target(target[0], target[1], target[2], target[1], end_verse)
            links[(book, chapter)].append((int(votes), verse, reference, reason))
    return links


def curated_links(bible, books):
    links = collections.defaultdict(list)
    for entry in json.loads(CURATED.read_text(encoding="utf-8")):
        for reference in (entry["source"], entry["target"]):
            match = REFERENCE.match(reference)
            if not match or not bible.exists(match[1], int(match[2]), int(match[3])):
                raise ValueError(f"Curated reference does not exist: {reference}")
        book, chapter, verse = REFERENCE.match(entry["source"]).group(1, 2, 3)
        if book in books:
            links[(book, int(chapter))].append((CURATED_VOTES, int(verse), entry["target"], "fulfillment: " + entry["note"]))
    return links


def choose(links):
    links.sort(key=lambda link: (-link[0], link[1]))
    chosen, seen, per_verse = [], set(), collections.Counter()
    for votes, verse, reference, reason in links:
        if reference in seen or per_verse[verse] >= MAX_PER_SOURCE_VERSE:
            continue
        seen.add(reference)
        per_verse[verse] += 1
        chosen.append((verse, reference, votes, reason))
        if len(chosen) == MAX_PER_CHAPTER:
            break
    # Reading order: by source verse, strongest link first.
    return sorted(chosen, key=lambda link: (link[0], -link[2]))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        sys.exit(__doc__)
    dry_run = "--dry-run" in sys.argv
    books = args[1:] or DEFAULT_BOOKS

    bible = Bible()
    unknown = [b for b in books if b not in bible.verse_counts]
    if unknown:
        sys.exit(f"Unknown books: {unknown}")
    found = candidate_links(Path(args[0]), bible, books)
    for key, links in curated_links(bible, books).items():
        found[key].extend(links)

    database = sqlite3.connect(DATABASE)
    covered = set(database.execute("SELECT DISTINCT book_name, chapter_number FROM chapter_related_verses"))
    rows, empty = [], []
    for book in books:
        for chapter in range(1, len(bible.verse_counts[book]) + 1):
            if (book, chapter) in covered:
                continue
            chosen = choose(found.get((book, chapter), []))
            if not chosen:
                empty.append(f"{book} {chapter}")
            rows += [(book, chapter, i, verse, ref, votes) for i, (verse, ref, votes, _) in enumerate(chosen)]
            if dry_run and chapter in (1, 4):
                print(f"{book} {chapter}:")
                for verse, ref, votes, reason in chosen:
                    print(f"   v{verse} → {ref}  [{reason}]")

    filled = len({(r[0], r[1]) for r in rows})
    print(f"{'Would add' if dry_run else 'Added'} {len(rows)} cross references to {filled} chapters")
    if empty:
        print(f"No direct links found for {len(empty)} chapters: {', '.join(empty)}")
    if not dry_run:
        database.executemany(
            "INSERT INTO chapter_related_verses (book_name, chapter_number, sequence, source_verse, related_reference, votes)"
            " VALUES (?, ?, ?, ?, ?, ?)",
            rows,
        )
        database.commit()
    database.close()


if __name__ == "__main__":
    main()
