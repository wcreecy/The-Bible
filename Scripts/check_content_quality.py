#!/usr/bin/env python3
"""Check the editorial quality of the Book Overview and Chapter Insights content.

    python3 Scripts/check_content_quality.py                 # per-book counts of open issues
    python3 Scripts/check_content_quality.py --book Joshua   # every issue in one book

The other build steps check that references exist and double-quoted text matches the KJV.
This step checks the house style those can't: placement text instead of filler, exact KJV
wording even in single quotes, citations the "What Happens" outline can use, explained
themes, short Key People lists, distinct Historical Moment and Original Audience text,
lowercase pronouns for God, and KJV spellings of names.

Books listed in quality_reviewed_books.json have passed a full review, so any issue in them
fails the build. Issues in other books are only counted, so the remaining books can be
reviewed one at a time.
"""

import json
import re
import sqlite3
import sys
from collections import defaultdict
from pathlib import Path

from book_content_tools import kjv_books, normalize
from insights_common import DATABASE, KJV


REVIEWED_BOOKS = Path(__file__).resolve().parent / "quality_reviewed_books.json"

# Filler and disclaimer wording from the original drafts. Where We Are should place the
# chapter in the book's story; these phrases mark text that doesn't.
FILLER = re.compile("|".join([
    r"This background helps explain",
    r"The instructions are presented in",
    r"events, commands, and reported circumstances",
    r"The specific details are those described",
    r"Within the biblical narrative",
    r"Its historical and literary setting",
    r"within the prophetic material",
    r"setting helps (?:explain|clarify)",
    r"\bscholar",
    r"\bdebated\b",
    r"\bis a proposal\b",
    r"\bcannot be (?:independently|securely|externally)",
    r"\bnot independently\b",
    r"independent(?:ly)? (?:verif|confirm|document)",
    r"\bshould not be (?:read|treated|taken|assumed|equated|confused|used|mechanically|presented|forced)",
    r"\bwithout (?:assuming|claiming|treating|asserting|requiring)\b",
]), re.IGNORECASE)

# A quotation in single quotes, which the KJV check (double quotes only) never sees.
SINGLE_QUOTED = re.compile(r"(?:^|[\s(—])[‘']([^‘’']{8,}?)[’'](?=[\s,.;:)!?—]|$)")
# "Deuteronomy 2:1-9,Deuteronomy 2:17-19": a list of citations run together outside parentheses.
RUN_TOGETHER_CITATIONS = re.compile(r"(?:[1-3] )?[A-Z][a-z]+ \d+:\d+[–\-\d]*,(?:[1-3] )?[A-Z][a-z]+ \d+:\d+")
# A summary sentence that ends in a citation, as the outline expects: "… (Joshua 6:1–21)."
TRAILING_CITATION = re.compile(r"\([^()]*\d+:\d+[^()]*\)[.!?]?[\"”’]?$")
SENTENCE_BREAK = re.compile(r"(?:(?<=[.!?])|(?<=[.!?][\"”’)]))\s+(?=[A-Z\"“(])")
# Capitalized pronouns for God; the house style is lowercase, as in the KJV.
CAPITALIZED_PRONOUN = re.compile(r"(?<=[a-z,;:—] )(His|Him|Himself)\b")
# Single quotes after these words give a name's meaning ("Beersheba means 'well of the oath'"), not a quotation.
GLOSS_LEAD_IN = re.compile(r"\b(?:means?|meaning|meant|named?|names|called|calls|word|term|title|translated|literally)\b[^.]{0,40}$", re.IGNORECASE)
NOT_A_PERSON = re.compile(r"not a character|^The readers\b", re.IGNORECASE)
MODERN_SPELLINGS = {
    "Phoebe": "Phebe", "Pergamum": "Pergamos", "Cenchreae": "Cenchrea", "Bezalel": "Bezaleel",
    "Oholiab": "Aholiab", "Negeb": "the south (the Negev)", "Ben-ammi": "Benammi",
}
MODERN_SPELLING = re.compile(r"\b(" + "|".join(MODERN_SPELLINGS) + r")\b")

MAX_KEY_PEOPLE = 6
MAX_WHERE_WE_ARE = 600


def outside_quotes(text):
    return re.sub(r"[\"“][^\"”]*[\"”]", " ", text)


def words(text):
    return set(re.findall(r"[a-z']+", text.lower()))


def nearly_same(first, second):
    if not first or not second:
        return False
    if first[:20].lower() == second[:20].lower():
        return True
    shorter, longer = sorted((words(first), words(second)), key=len)
    return len(shorter & longer) / max(1, len(shorter)) > 0.6


class Checker:
    def __init__(self, database):
        self.database = database
        self.bible = " ".join(kjv_books())
        # The KJV's margin notes give the meanings of names, which the text often repeats.
        kjv = json.loads(KJV.read_text(encoding="utf-8-sig"))
        self.notes = " ".join(normalize(note) for book in kjv for chapter in book["chapters"]
                              for verse in chapter for note in re.findall(r"\{([^{}]*:[^{}]*)\}", verse))
        self.issues = defaultdict(list)  # book → [(where, check, detail)]

    def add(self, book, where, check, detail=""):
        self.issues[book].append((where, check, detail))

    def style(self, book, where, text, heading=False):
        """Checks that apply to every piece of displayed text. Title-case headings may capitalize "His"."""
        for match in SINGLE_QUOTED.finditer(text):
            quote = match.group(1)
            normalized = normalize(quote)
            if len(normalized.split()) < 3 or normalized in self.bible or normalized in self.notes:
                continue
            if GLOSS_LEAD_IN.search(text[max(0, match.start() - 60):match.start() + 1]):
                continue
            self.add(book, where, "quote not in KJV wording", quote[:80])
        for match in RUN_TOGETHER_CITATIONS.findall(text):
            self.add(book, where, "citations missing parentheses", match)
        plain = outside_quotes(text)
        for pronoun in [] if heading else CAPITALIZED_PRONOUN.findall(plain):
            self.add(book, where, "capitalized pronoun for God", pronoun)
        for name in MODERN_SPELLING.findall(plain):
            self.add(book, where, "modern spelling", f"{name} → {MODERN_SPELLINGS[name]}")

    def chapters(self):
        rows = self.database.execute("""
            SELECT i.book_name, i.chapter_number, i.overall_summary,
                   r.in_story, r.historical_moment, r.original_audience
            FROM chapter_insights i
            JOIN chapter_reading_contexts r USING (book_name, chapter_number)
        """)
        for book, chapter, summary, where_we_are, moment, audience in rows:
            where = f"{book} {chapter}"
            for label, text in (("summary", summary), ("Where We Are", where_we_are),
                                ("Historical Moment", moment), ("Original Audience", audience)):
                self.style(book, f"{where} {label}", text)
            for label, text in (("summary", summary), ("Where We Are", where_we_are)):
                for match in FILLER.findall(text):
                    self.add(book, f"{where} {label}", "filler or disclaimer", match)
            if len(where_we_are) > MAX_WHERE_WE_ARE:
                self.add(book, f"{where} Where We Are", "too long", f"{len(where_we_are)} characters")
            sentences = [s.strip() for s in SENTENCE_BREAK.split(summary) if s.strip()]
            if sum(1 for s in sentences if TRAILING_CITATION.search(s)) < 2:
                self.add(book, f"{where} summary", "no What Happens outline", "needs 2+ sentences ending in a citation")
            if nearly_same(moment, audience):
                self.add(book, f"{where} Historical Moment", "repeats Original Audience")

        figures = defaultdict(list)
        for book, chapter, name, role in self.database.execute(
                "SELECT book_name, chapter_number, name, role_and_significance FROM chapter_key_figures"):
            figures[(book, chapter)].append(name)
            where = f"{book} {chapter} Key People"
            self.style(book, where, name, heading=True)
            self.style(book, where, role)
            if NOT_A_PERSON.search(name) or NOT_A_PERSON.search(role):
                self.add(book, where, "not a person who acts", name[:60])
            elif "/" in name:
                self.add(book, where, "name written with a slash", f"{name[:60]} (write it like \"Jacob (Israel)\")")
            for match in FILLER.findall(role):
                self.add(book, where, "filler or disclaimer", match)
        for (book, chapter), names in figures.items():
            if len(names) > MAX_KEY_PEOPLE:
                self.add(book, f"{book} {chapter} Key People", "too many people", f"{len(names)} (max {MAX_KEY_PEOPLE})")

        for book, chapter, theme, explanation in self.database.execute(
                "SELECT book_name, chapter_number, theme, explanation FROM chapter_key_themes"):
            where = f"{book} {chapter} Key Themes"
            self.style(book, where, theme, heading=True)
            self.style(book, where, explanation)
            if not explanation.strip():
                self.add(book, where, "theme not explained", theme)
            elif "\n" in explanation:
                self.add(book, where, "line break in theme", theme)
            for match in FILLER.findall(explanation):
                self.add(book, where, "filler or disclaimer", match)

        for book, chapter, title, text in self.database.execute(
                "SELECT book_name, chapter_number, title, then_text FROM chapter_cultural_lenses"):
            self.style(book, f"{book} {chapter} background", title, heading=True)
            self.style(book, f"{book} {chapter} background", text)

    def overviews(self):
        sources = [
            ("SELECT name, traditional_author_or_attribution || ' ' || original_audience || ' ' || purpose"
             " || ' ' || overall_theme || ' ' || plain_english_summary FROM book_overviews", "overview"),
            ("SELECT book_name, when_it_happened || ' ' || when_it_was_written || ' ' || location"
             " || ' ' || world_at_the_time FROM book_history", "setting"),
            ("SELECT book_name, description FROM book_key_figures", "key figures"),
            ("SELECT book_name, tip FROM book_reading_tips", "reading tips"),
            ("SELECT book_name, text FROM book_connections", "connections"),
            ("SELECT book_name, text FROM book_story_sections", "story"),
        ]
        for query, label in sources:
            for book, text in self.database.execute(query):
                self.style(book, f"{book} overview: {label}", text)
        for book, passage in self.database.execute("SELECT book_name, passage FROM book_story_sections"):
            self.style(book, f"{book} overview: story heading", passage, heading=True)


def main():
    reviewed = json.loads(REVIEWED_BOOKS.read_text(encoding="utf-8"))
    with sqlite3.connect(DATABASE) as database:
        order = [name for (name,) in database.execute("SELECT name FROM book_overviews ORDER BY canonical_order")]
        unknown = sorted(set(reviewed) - set(order))
        if unknown:
            sys.exit(f"{REVIEWED_BOOKS.name} names unknown books: {unknown}")
        checker = Checker(database)
        checker.chapters()
        checker.overviews()

    if "--book" in sys.argv:
        book = " ".join(sys.argv[sys.argv.index("--book") + 1:])
        if book not in order:
            sys.exit(f"Unknown book: {book}")
        for where, check, detail in sorted(checker.issues[book]):
            print(f"{where}: {check}" + (f" — {detail}" if detail else ""))
        print(f"{book}: {len(checker.issues[book])} issues")
        return

    failing = [book for book in reviewed if checker.issues[book]]
    for book in failing:
        for where, check, detail in sorted(checker.issues[book])[:20]:
            print(f"{where}: {check}" + (f" — {detail}" if detail else ""))
    if "--summary" not in sys.argv:
        checks = sorted({check for issues in checker.issues.values() for _, check, _ in issues})
        for book in order:
            counts = defaultdict(int)
            for _, check, _ in checker.issues[book]:
                counts[check] += 1
            if counts:
                mark = "reviewed" if book in reviewed else ""
                print(f"{book:16} {sum(counts.values()):5}  " + ", ".join(f"{check} {counts[check]}" for check in checks if counts[check]) + f"  {mark}")
    open_books = [book for book in order if book not in reviewed and checker.issues[book]]
    open_issues = sum(len(checker.issues[book]) for book in open_books)
    print(f"{len(reviewed)} reviewed books, {len(failing)} with issues")
    print(f"{open_issues} open issues in {len(open_books)} books not yet reviewed")
    if failing:
        sys.exit(1)


if __name__ == "__main__":
    main()
