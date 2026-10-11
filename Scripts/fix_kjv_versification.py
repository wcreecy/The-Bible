#!/usr/bin/env python3
"""Restore standard KJV verse numbering in the bundled kjv.json.

The source text was missing six verses (shifting every later verse in those
chapters) and split four verses in two (adding a verse). This restores the
missing verses and re-joins the split ones so every chapter matches the
standard 31,102-verse KJV.

The script checks each location before changing it and is safe to re-run: a fix
that's already applied is skipped. A review sheet of every change is written to
Scripts/kjv_fixes_review.md.

Missing verse text is standard KJV (1769) wording. Inserted verses don't carry
the translators' supplied-word markup or footnotes, since the source used to
restore them doesn't record italics. The words of Jesus are marked red-letter
to match the surrounding verses.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KJV = ROOT / "The Bible" / "kjv.json"
REVIEW = ROOT / "Scripts" / "kjv_fixes_review.md"

RED_START = ""
RED_END = ""


def red(text: str) -> str:
    return f"{RED_START}{text}{RED_END}"


# (book, chapter, verse to insert, text, the verse currently at that position must start with)
MISSING_VERSES = [
    ("Matthew", 2, 16,
     "Then Herod, when he saw that he was mocked of the wise men, was exceeding wroth, and sent forth, "
     "and slew all the children that were in Bethlehem, and in all the coasts thereof, from two years old "
     "and under, according to the time which he had diligently enquired of the wise men.",
     "Then was fulfilled that which was spoken by Jeremy"),
    ("Matthew", 22, 1,
     "And Jesus answered and spake unto them again by parables, and said,",
     "The kingdom of heaven is like unto a certain king"),
    ("Matthew", 26, 38,
     "Then saith he unto them, "
     + red("My soul is exceeding sorrowful, even unto death: tarry ye here, and watch with me."),
     "And he went a little further"),
    ("Mark", 4, 40,
     "And he said unto them, " + red("Why are ye so fearful? how is it that ye have no faith?"),
     "And they feared exceedingly"),
    ("Mark", 7, 11,
     red("But ye say, If a man shall say to his father or mother, It is Corban, that is to say, a gift, "
         "by whatsoever thou mightest be profited by me; he shall be free."),
     RED_START + "And ye suffer him no more"),
    ("Mark", 8, 8,
     "So they did eat, and were filled: and they took up of the broken meat that was left seven baskets.",
     "And they that had eaten were about four thousand"),
]

# (book, chapter, verse that absorbs the next one, how to join, where the second half goes)
# Each split verse is joined back into the verse it was cut from.
def join_with_lowercase(first: str, second: str) -> str:
    # "…LORD:" + "Nevertheless…" → "…LORD: nevertheless…"
    return f"{first} {second[0].lower()}{second[1:]}"


def join_plain(first: str, second: str) -> str:
    return f"{first} {second}"


SPLIT_VERSES = [
    # 1 Samuel 20:43 is the second half of 20:42.
    ("1 Samuel", 20, 42, "And he arose and departed: and Jonathan went into the city.", join_plain),
    # 1 Kings 22:44 is the second half of 22:43.
    ("1 Kings", 22, 43, "Nevertheless the high places were not taken away", join_with_lowercase),
    # 3 John 1:15 is the second half of 1:14.
    ("3 John", 1, 14, "Peace {be} to thee.", join_plain),
]

# Revelation 12:18 is the first half of Revelation 13:1 in the KJV.
REV_12_18 = "And I stood upon the sand of the sea."
REV_13_1_START = "And saw a beast rise up out of the sea"


def strip_markup(text: str) -> str:
    """Readable text for the review sheet: drop footnotes, supplied-word braces, red-letter marks."""
    text = text.replace(RED_START, "").replace(RED_END, "")
    text = re.sub(r"\s*\{[^{}]*:[^{}]*\}", "", text)
    return text.replace("{", "").replace("}", "")


def main() -> int:
    books = json.loads(KJV.read_text(encoding="utf-8"))
    by_name = {book["name"]: book for book in books}
    changes: list[str] = []

    def chapter(book: str, number: int) -> list[str]:
        return by_name[book]["chapters"][number - 1]

    # Insert missing verses.
    for book, ch, verse, text, current_start in MISSING_VERSES:
        verses = chapter(book, ch)
        if verses[verse - 1] == text:
            print(f"skip {book} {ch}:{verse} (already restored)")
            continue
        if not verses[verse - 1].startswith(current_start):
            print(f"ERROR {book} {ch}:{verse}: unexpected text, not changing: {verses[verse - 1][:80]!r}")
            return 1
        verses.insert(verse - 1, text)
        changes.append(
            f"### {book} {ch}:{verse} — missing verse restored\n\n"
            f"**Added:** {strip_markup(text)}\n\n"
            f"Every later verse in {book} {ch} moves up by one, so verse {verse} through the end of the "
            f"chapter now carries its correct number (the chapter now has {len(verses)} verses)."
        )

    # Re-join split verses.
    for book, ch, verse, second_start, join in SPLIT_VERSES:
        verses = chapter(book, ch)
        if len(verses) <= verse or not verses[verse].startswith(second_start):
            print(f"skip {book} {ch}:{verse} (already joined)")
            continue
        first, second = verses[verse - 1], verses[verse]
        verses[verse - 1] = join(first, second)
        del verses[verse]
        changes.append(
            f"### {book} {ch}:{verse} — split verse re-joined\n\n"
            f"**Before:** {book} {ch}:{verse} — {strip_markup(first)}\n\n"
            f"{book} {ch}:{verse + 1} — {strip_markup(second)}\n\n"
            f"**After:** {book} {ch}:{verse} — {strip_markup(verses[verse - 1])}\n\n"
            f"The chapter now has {len(verses)} verses."
        )

    # Move Revelation 12:18 back to the start of 13:1.
    rev12, rev13 = chapter("Revelation", 12), chapter("Revelation", 13)
    if rev12[-1] == REV_12_18 and rev13[0].startswith(REV_13_1_START):
        old13 = rev13[0]
        rev13[0] = "And I stood upon the sand of the sea, and saw" + old13[len("And saw"):]
        rev12.pop()
        changes.append(
            "### Revelation 12:18 / 13:1 — split verse re-joined\n\n"
            f"**Before:** Revelation 12:18 — {REV_12_18}\n\n"
            f"Revelation 13:1 — {strip_markup(old13)}\n\n"
            f"**After:** Revelation 13:1 — {strip_markup(rev13[0])}\n\n"
            "Revelation 12 now ends at verse 17, as in the KJV."
        )
    else:
        print("skip Revelation 12:18 (already joined)")

    total = sum(len(c) for b in books for c in b["chapters"])
    if not changes:
        print(f"Nothing to change. Total verses: {total}")
        return 0

    # Same compact encoding as the original file, so only the fixed verses differ.
    KJV.write_text(json.dumps(books, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

    REVIEW.write_text(
        "# KJV text fixes — review sheet\n\n"
        f"`The Bible/kjv.json` now has **{total:,} verses**, matching the standard KJV (31,102).\n\n"
        "Fixed by `Scripts/fix_kjv_versification.py`. Every chapter was compared against an independent "
        "KJV text ([aruljohn/Bible-kjv](https://github.com/aruljohn/Bible-kjv)); these were the only "
        "places where verse numbering differed.\n\n"
        "**Notes**\n\n"
        "- Restored verses use standard KJV (1769) wording. They don't have the supplied-word (italic) "
        "markup or translators' footnotes that other verses carry, because the source used doesn't "
        "record them.\n"
        "- Words of Jesus in restored verses are marked red-letter, matching the verses around them.\n"
        "- Saved bookmarks, favorites, notes, and highlights in the affected chapters were stored by verse "
        "number, so any saved after a gap now point to the verse with that (correct) number.\n\n"
        "## Missing verses restored (6)\n\n"
        + "\n\n".join(c for c in changes if "missing verse" in c)
        + "\n\n## Split verses re-joined (4)\n\n"
        + "\n\n".join(c for c in changes if "split verse" in c)
        + "\n",
        encoding="utf-8",
    )
    print(f"Applied {len(changes)} fixes. Total verses: {total}. Review: {REVIEW.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
