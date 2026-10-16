#!/usr/bin/env python3
"""Fill in cross references for chapters that have none, keeping only direct links.

Candidates come from the OpenBible.info cross-reference dataset (CC-BY):
https://a.openbible.info/data/cross-references.zip

This only adds rows for
chapters in the chosen books that have no cross references yet, so hand-explained
references elsewhere are left untouched (apart from appending stated fulfillments). A candidate is kept only if it is:

- a quotation: the two verses share a rare phrase (found in at most MAX_PHRASE_VERSES
  verses) containing at least two distinctive words that aren't names, so stock wording
  like "and it came to pass", or a shared place name like "the plains of Jericho",
  doesn't count on its own. Everything the two verses share must hold at least two real
  words, and a shared run of LONG_QUOTE_WORDS words if it holds only two, so idioms like
  "shall not be moved" or "under every green tree" don't count; parallel accounts (two
  Gospels, or Samuel–Kings and Chronicles) are exempt. A shared run shorter than LONG_QUOTE_WORDS also needs
  MIN_SHORT_QUOTE_VOTES votes, which filters repeated formulas such as "how long wilt thou";
  or a rare shared phrase of any words with at least STRONG_QUOTE_VOTES votes, which catches
  New Testament quotations worded in common words ("thou shalt love the Lord"). Letters
  (Romans–Revelation) share many formulas ("Grace be unto you, and peace from God our
  Father", "rejoice in the Lord"), so when a letter quotes the Old Testament the looser test
  needs a shared run of LONG_QUOTE_WORDS words with at least two that aren't function words,
  and greeting words aren't distinctive;
  between a letter and another New Testament book, a quotation needs a shared run of
  LETTER_PARALLEL_WORDS words not counting greeting words, names, or names of God,
  including a phrase found in at most LETTER_PARALLEL_MAX_VERSES verses (so refrains don't count), or
- a named link: both verses name the same uncommon person or place, and the link has
  at least MIN_NAME_VOTES votes, or
- a stated fulfillment from Scripts/curated_cross_references.json, where one passage
  records that the other came to pass.

Every link needs at least one vote; the dataset includes down-voted links. Links are read in
both directions, since a New Testament quotation is often recorded from the quoting verse.

Usage:
    python3 Scripts/add_strict_cross_references.py [path/to/cross_references.txt|.zip] [Book ...] [--dry-run] [--rebuild]

The dataset defaults to Scripts/data/openbible_cross_references.zip (see Scripts/data/README.md).

With no books given, it fills Genesis through Ruth. Safe to run again. --rebuild first removes
the links this script added for those books (rows in chapters without hand-written
explanations, plus curated fulfillments), so changed rules can be applied again.
"""

import collections
import io
import zipfile
import json
import re
import sqlite3
import sys
from pathlib import Path

from insights_common import DATABASE, OSIS_BOOKS, format_target
from book_content_tools import KJV, normalize


DEFAULT_BOOKS = ["Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua", "Judges", "Ruth"]
CURATED = Path(__file__).resolve().parent / "curated_cross_references.json"
DATASET = Path(__file__).resolve().parent / "data" / "openbible_cross_references.zip"

MAX_PER_CHAPTER = 15
MAX_PER_SOURCE_VERSE = 3
MIN_NAME_VOTES = 5
# A phrase in more verses than this is a formula, not a quotation.
MAX_PHRASE_VERSES = 10
# Shorter shared runs need community support to count as a quotation.
LONG_QUOTE_WORDS = 5
MIN_SHORT_QUOTE_VOTES = 3
# A rare shared phrase this well supported is a quotation even in common words.
STRONG_QUOTE_VOTES = 10
# Even a well-supported phrase needs one real content word ("one flesh", not "and that which is").
STRONG_QUOTE_CONTENT_WORD_VERSES = 450
# A word in more verses than this is too common to make a phrase distinctive.
MAX_DISTINCTIVE_WORD_VERSES = 200
# A name in more verses than this (Abraham, Moses, Israel) links too much to be specific.
MAX_NAME_VERSES = 120
CURATED_VOTES = 1000
# Never distinctive, however rare: function words, numbers, and titles of God.
STOPWORDS = set("""
    a an and the of to in into unto upon on at by for from with without within as than that this these those
    which what who whom whose when where there here then thus so also even yea nay not no nor but or if
    i me my mine we us our ye you your thee thou thy thine he him his she her it its they them their
    is are was were be been being am art hath have had shall shall will would should may might must
    let say said saying pray little more most many much times all every any some one two three four
    five six seven eight nine ten eleven twelve twenty thirty forty fifty sixty seventy eighty ninety
    hundred thousand thousands score great before after against among about over under come came go went
    wilt indeed find found liveth live sat sit see saw seen eye eyes long thence hence rent clothes
    sons daughters
    first second third fourth fifth sixth seventh eighth ninth tenth eleventh twelfth
    day days month months year years appearance country known know knew
""".split())
PARALLEL_BOOKS = [
    {"Matthew", "Mark", "Luke", "John"},
    {"1 Samuel", "2 Samuel", "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles"},
]
# Function words left out of STOPWORDS because they help name places ("Up" is never a name).
PREPOSITIONS = {"out", "up", "down", "off", "through"}
DIVINE_TITLES = {"almighty", "jehovah", "lord", "god", "highest", "amen", "selah", "hallelujah", "alleluia"}
# Month names date events but don't connect them.
MONTH_NAMES = {"abib", "nisan", "zif", "sivan", "elul", "ethanim", "bul", "chisleu", "tebeth", "sebat", "adar"}
# Letters share short formulas, so links touching them need longer shared wording.
LETTERS = set("""Romans|1 Corinthians|2 Corinthians|Galatians|Ephesians|Philippians|Colossians|1 Thessalonians|
    2 Thessalonians|1 Timothy|2 Timothy|Titus|Philemon|Hebrews|James|1 Peter|2 Peter|1 John|2 John|3 John|Jude|
    Revelation""".replace("\n    ", "").split("|"))
# Words from letter openings, greetings, and doxologies, never distinctive in a letter.
LETTER_FORMULA_WORDS = {
    "paul", "apostle", "grace", "peace", "saints", "salute", "greet", "mention", "thanks", "glory", "dominion", "ever",
}
# Run breakers when matching a letter against another New Testament book.
LETTER_RUN_BREAKERS = LETTER_FORMULA_WORDS | DIVINE_TITLES | {"jesus", "christ", "father", "amen"}
LETTER_PARALLEL_WORDS = 8
# ...and must share a phrase found in no more verses than this.
LETTER_PARALLEL_MAX_VERSES = 2
REFERENCE = re.compile(r"^(.+?) (\d+):(\d+)(?:-(\d+)(?::(\d+))?)?$")


class Bible:
    def __init__(self):
        kjv = json.loads(KJV.read_text(encoding="utf-8-sig"))
        self.book_names = [book["name"] for book in kjv]
        self.verse_counts = {book["name"]: [len(chapter) for chapter in book["chapters"]] for book in kjv}
        self.text = {
            # Drop italic-word braces and the closing notes on letters («Written from Rome»).
            (book["name"], c + 1, v + 1): re.sub(r"\{[^{}]*\}|«[^«»]*»", " ", text)
            for book in kjv for c, chapter in enumerate(book["chapters"]) for v, text in enumerate(chapter)
        }
        # Psalm titles ("[A Psalm of David.]") repeat, so they count toward names but not wording.
        self.words = {key: normalize(re.sub(r"\[[^\]]*\]", " ", text)).split() for key, text in self.text.items()}
        self.new_testament = set(self.book_names[self.book_names.index("Matthew"):])
        self.phrase_verses = collections.Counter(p for words in self.words.values() for p in self.phrases(words))
        self.word_verses = collections.Counter(w for words in self.words.values() for w in set(words))

        # A proper name is a word that is capitalized (almost) everywhere it appears mid-verse.
        capitalized, total = collections.Counter(), collections.Counter()
        for text in self.text.values():
            for word in re.findall(r"[A-Za-z]+", text)[1:]:
                total[word.lower()] += 1
                capitalized[word.lower()] += word[0].isupper()
        self.names = {
            w for w in total
            if capitalized[w] / total[w] > 0.95 and self.word_verses[w] <= MAX_NAME_VERSES and w not in DIVINE_TITLES | MONTH_NAMES
        }

    @staticmethod
    def phrases(words, length=4):
        return {" ".join(words[i:i + length]) for i in range(len(words) - length + 1)}

    @staticmethod
    def parallel_accounts(a, b):
        """Two different books that retell the same events: the Gospels, or Samuel–Kings and Chronicles."""
        return a != b and any(a in group and b in group for group in PARALLEL_BOOKS)

    def exists(self, book, chapter, verse):
        counts = self.verse_counts.get(book)
        return bool(counts) and 1 <= chapter <= len(counts) and 1 <= verse <= counts[chapter - 1]

    def names_in(self, key):
        return {w.lower() for w in re.findall(r"\b[A-Z][a-z]+\b", self.text[key])} & self.names

    @staticmethod
    def longest_run(a, b):
        """Length of the longest run of words the two verses share."""
        return len(Bible.shared_run(a, b))

    @staticmethod
    def shared_run(a, b):
        """The longest run of words the two verses share."""
        best, end, previous = 0, 0, [0] * (len(b) + 1)
        for i, word in enumerate(a, 1):
            current = [0] * (len(b) + 1)
            for j, other in enumerate(b, 1):
                if word == other:
                    current[j] = previous[j - 1] + 1
                    if current[j] > best:
                        best, end = current[j], i
            previous = current
        return a[end - best:end]

    def reason(self, source, target, votes):
        """Why the link is direct, or None when it is only thematic."""
        if votes < 1:
            return None
        shared_phrases = self.phrases(self.words[source]) & self.phrases(self.words[target])
        rare = [
            p for p in shared_phrases
            if self.phrase_verses[p] <= MAX_PHRASE_VERSES and any(
                w not in STOPWORDS and self.word_verses[w] <= STRONG_QUOTE_CONTENT_WORD_VERSES for w in p.split()
            )
        ]
        in_letter = source[0] in LETTERS or target[0] in LETTERS
        if in_letter and source[0] in self.new_testament and target[0] in self.new_testament:
            masked = [
                [f"<{side}{i}>" if w in LETTER_RUN_BREAKERS or w in self.names else w for i, w in enumerate(self.words[key])]
                for side, key in enumerate((source, target))
            ]
            # A refrain or doxology repeats across many verses; a true parallel is (almost) unique.
            shared_phrases = self.phrases(self.words[source]) & self.phrases(self.words[target])
            unique = any(self.phrase_verses[p] <= LETTER_PARALLEL_MAX_VERSES for p in shared_phrases)
            if unique and self.longest_run(*masked) >= LETTER_PARALLEL_WORDS:
                return "quotes a shared passage"
            shared = self.names_in(source) & self.names_in(target)
            return "names " + ", ".join(sorted(shared)) if shared and votes >= MIN_NAME_VOTES else None
        shared_run = self.shared_run(self.words[source], self.words[target])
        run = len(shared_run)
        # Real words across everything the verses share; a stock phrase ("shall not be moved",
        # "under every green tree") has one or two. Parallel accounts are exempt, since they
        # retell the same saying or event in different words.
        real_words = {w for p in shared_phrases for w in p.split()} - STOPWORDS - PREPOSITIONS
        stock_phrase = not self.parallel_accounts(source[0], target[0]) and (
            len(real_words) < 2 or (len(real_words) == 2 and run < LONG_QUOTE_WORDS)
        )
        if stock_phrase:
            shared_phrases, rare = set(), []
        # In a letter the shared wording must be long and carry at least two real words
        # ("all things under his feet", not "out of the snare of the").
        if in_letter and sum(w not in STOPWORDS | PREPOSITIONS for w in shared_run) < 2:
            run = 0
        if rare and votes >= STRONG_QUOTE_VOTES and (not in_letter or run >= LONG_QUOTE_WORDS):
            return f"quotes \"{rare[0]}\""
        ignored = STOPWORDS | (LETTER_FORMULA_WORDS if in_letter else set())
        for phrase in shared_phrases:
            distinctive = [
                w for w in phrase.split()
                if self.word_verses[w] <= MAX_DISTINCTIVE_WORD_VERSES and w not in ignored and w not in self.names
            ]
            if self.phrase_verses[phrase] > MAX_PHRASE_VERSES or len(distinctive) < 2:
                continue
            if in_letter and run < LONG_QUOTE_WORDS:
                continue
            if votes >= MIN_SHORT_QUOTE_VOTES or run >= LONG_QUOTE_WORDS:
                return f"quotes \"{phrase}\""
        shared = self.names_in(source) & self.names_in(target)
        if shared and votes >= MIN_NAME_VOTES:
            return "names " + ", ".join(sorted(shared))
        return None


def parse_osis(osis, book_names):
    book, chapter, verse = osis.split(".")
    return book_names[book], int(chapter), int(verse)


def open_dataset(path):
    """The dataset's lines, read from cross_references.txt or the zip it is distributed in."""
    if Path(path).suffix == ".zip":
        archive = zipfile.ZipFile(path)
        return io.TextIOWrapper(archive.open("cross_references.txt"), encoding="utf-8")
    return open(path, encoding="utf-8")


def candidate_links(path, bible, books):
    osis_names = dict(zip(OSIS_BOOKS, bible.book_names))
    links = collections.defaultdict(list)
    with open_dataset(path) as source:
        next(source)
        for line in source:
            from_osis, to_osis, votes = line.rstrip("\n").split("\t")[:3]
            book, chapter, verse = parse_osis(from_osis, osis_names)
            start, _, end = to_osis.partition("-")
            target = parse_osis(start, osis_names)
            if book not in books:
                # Read the link backwards when it points into one of the chosen books.
                if target[0] not in books or end:
                    continue
                (book, chapter, verse), target = target, (book, chapter, verse)
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
        # "1 Corinthians 6:16" and "1 Corinthians 6:16-17" point to the same place.
        start = reference.split("-")[0]
        if start in seen or per_verse[verse] >= MAX_PER_SOURCE_VERSE:
            continue
        seen.add(start)
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
    # An optional dataset path comes first; everything else is a book name.
    dataset = DATASET
    if Path(args[0]).suffix in (".txt", ".zip"):
        dataset = Path(args.pop(0))
    books = args or DEFAULT_BOOKS

    bible = Bible()
    unknown = [b for b in books if b not in bible.verse_counts]
    if unknown:
        sys.exit(f"Unknown books: {unknown}")
    found = candidate_links(dataset, bible, books)
    for key, links in curated_links(bible, books).items():
        found[key].extend(links)

    database = sqlite3.connect(DATABASE)
    if "--rebuild" in sys.argv:
        removed = 0
        for book in books:
            removed += database.execute("""
                DELETE FROM chapter_related_verses
                WHERE book_name = ? AND (votes = ? OR chapter_number NOT IN (
                    SELECT chapter_number FROM chapter_scripture_connections WHERE book_name = ?
                ))
            """, (book, CURATED_VOTES, book)).rowcount
        print(f"{'Would remove' if dry_run else 'Removed'} {removed} previously added cross references")
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
            if dry_run and chosen:
                print(f"{book} {chapter}:")
                for verse, ref, votes, reason in chosen:
                    print(f"   v{verse} → {ref}  [{reason}]")

    # Stated fulfillments are added even to chapters that already have cross references.
    for (book, chapter), links in sorted(curated_links(bible, books).items()):
        if (book, chapter) not in covered:
            continue
        existing = {ref for (ref,) in database.execute(
            "SELECT related_reference FROM chapter_related_verses WHERE book_name = ? AND chapter_number = ?",
            (book, chapter),
        )}
        (next_sequence,) = database.execute(
            "SELECT coalesce(max(sequence), -1) + 1 FROM chapter_related_verses WHERE book_name = ? AND chapter_number = ?",
            (book, chapter),
        ).fetchone()
        for votes, verse, reference, _ in sorted(links, key=lambda link: link[1]):
            if reference not in existing:
                rows.append((book, chapter, next_sequence, verse, reference, votes))
                existing.add(reference)
                next_sequence += 1

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
