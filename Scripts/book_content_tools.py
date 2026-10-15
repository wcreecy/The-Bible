#!/usr/bin/env python3
"""Parse the hand-written book content in Scripts/book_content/*.md.

Each book is a "# Book Name" heading followed by four "Label: text" lines for
the When & Where section and then the story, written as blank-line separated
paragraphs. A paragraph that starts with "**Passage** — " begins a new part of
the story labeled with the chapters it retells, such as
"**The Flood and God's Covenant (Genesis 6:1–9:29)** — ". Paragraphs after it
belong to the same part, separated by a blank line as in the app. A line that is
just "---" begins a part with no label, such as a closing summary.

These files are the source for book history and stories: edit them here, then run
Scripts/consolidate_insights.py to load them into the database. If the database is ever
edited directly, run Scripts/export_book_content.py to write the changes back here.

Run directly to check every quotation in the content against the app's KJV text:
    python3 Scripts/book_content_tools.py
"""

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "Scripts" / "book_content"
KJV = ROOT / "The Bible" / "kjv.json"

WHEN_WHERE_FIELDS = {
    "When it happened": "when_it_happened",
    "When it was written": "when_it_was_written",
    "Where": "location",
    "The world at the time": "world_at_the_time",
}
PASSAGE_PREFIX = re.compile(r"^\*\*(?P<passage>[^*]+)\*\*\s+—\s+")
UNLABELED_PART = "---"


def load_books():
    """Returns {book_name: {"when_where": {...}, "story": [(passage, text), ...]}}."""
    books = {}
    for path in sorted(CONTENT.glob("*.md")):
        current = None
        for block in re.split(r"\n\s*\n", path.read_text(encoding="utf-8")):
            block = block.strip()
            if not block:
                continue
            lines = block.splitlines()
            if lines[0].startswith("# "):
                name = lines[0][2:].strip()
                if name in books:
                    raise ValueError(f"{path.name}: {name} appears twice")
                current = books[name] = {"when_where": {}, "story": []}
                lines = lines[1:]
                for line in lines:
                    label, _, value = line.partition(":")
                    if label not in WHEN_WHERE_FIELDS:
                        raise ValueError(f"{path.name}: unexpected line in {name}: {line[:60]}")
                    current["when_where"][WHEN_WHERE_FIELDS[label]] = value.strip()
                continue
            if current is None:
                raise ValueError(f"{path.name}: text before the first book heading")
            if block == UNLABELED_PART:
                current["story"].append(("", None))
                continue
            text = " ".join(line.strip() for line in lines)
            match = PASSAGE_PREFIX.match(text)
            if match:
                current["story"].append((match["passage"].strip(), text[match.end():]))
            elif current["story"]:
                # A continuation paragraph of the current part.
                passage, previous = current["story"][-1]
                current["story"][-1] = (passage, text if previous is None else f"{previous}\n\n{text}")
            else:
                raise ValueError(f"{path.name}: {current} story must start with a labeled paragraph")
    for name, book in books.items():
        missing = set(WHEN_WHERE_FIELDS.values()) - set(book["when_where"])
        if missing:
            raise ValueError(f"{name} is missing {sorted(missing)}")
        if not book["story"] or not book["story"][0][0]:
            raise ValueError(f"{name}: the story must start with a labeled paragraph")
        if any(text is None for _, text in book["story"]):
            raise ValueError(f"{name}: a \"{UNLABELED_PART}\" line must be followed by a paragraph")
    return books


def normalize(text):
    text = re.sub(r"\{[^{}]*:[^{}]*\}", " ", text)  # translators' footnotes
    text = re.sub(r"[{}\[\]«»¶]", "", text)
    text = text.replace("’", "'").lower()
    return re.sub(r"[^a-z0-9']+", " ", text).strip()


def kjv_books():
    kjv = json.loads(KJV.read_text(encoding="utf-8-sig"))
    return [" ".join(normalize(verse) for chapter in book["chapters"] for verse in chapter) for book in kjv]


def check_quotes(books):
    bible = " ".join(kjv_books())
    problems = 0
    for name, book in books.items():
        texts = [text for _, text in book["story"]] + list(book["when_where"].values())
        for text in texts:
            for quote in re.findall(r"“([^”]+)”|\"([^\"]+)\"", text):
                quote = quote[0] or quote[1]
                for part in re.split(r"\.\.\.|…", quote):
                    part = normalize(part)
                    if len(part.split()) >= 2 and part not in bible:
                        problems += 1
                        print(f"{name}: not found in KJV: {part}")
    return problems


def check_passages(books):
    """Each label must name its own book and chapters/verses that exist in the KJV.

    A label is either a bare passage ("Genesis 1-3") or a title with the passage in
    parentheses ("The Flood and God's Covenant (Genesis 6:1–9:29)").
    """
    kjv = {book["name"]: book["chapters"] for book in json.loads(KJV.read_text(encoding="utf-8-sig"))}
    problems = 0
    for name, book in books.items():
        chapters = kjv[name]
        for passage, _ in book["story"]:
            if not passage:
                continue
            titled = re.fullmatch(r".+ \((?P<reference>[^()]+)\)", passage)
            reference = titled["reference"] if titled else passage
            match = re.fullmatch(
                rf"{re.escape(name)} (\d+)(?::(\d+))?(?:[-–](\d+)(?::(\d+))?)?", reference
            )
            valid = bool(match)
            if valid:
                first, verse, second, end_verse = (int(value) if value else None for value in match.groups())
                valid = 1 <= first <= len(chapters)
                if valid and end_verse is not None:
                    # "6:1–9:29": first chapter and verse through last chapter and verse.
                    valid = (verse is not None and first < second <= len(chapters)
                             and 1 <= verse <= len(chapters[first - 1])
                             and 1 <= end_verse <= len(chapters[second - 1]))
                elif valid and verse is not None:
                    # "6:1" or "6:1–13": verses within one chapter.
                    valid = 1 <= verse <= (second or verse) <= len(chapters[first - 1])
                elif valid and second is not None:
                    # "1-3": whole chapters.
                    valid = first < second <= len(chapters)
            if not valid:
                problems += 1
                print(f"{name}: bad passage label: {passage}")
    return problems


if __name__ == "__main__":
    books = load_books()
    words = sum(len(text.split()) for book in books.values() for _, text in book["story"])
    print(f"{len(books)} books, {words} story words")
    sys.exit(1 if check_quotes(books) + check_passages(books) else 0)
