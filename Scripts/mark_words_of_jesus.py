#!/usr/bin/env python3
"""Adds private-use red-letter delimiters to the bundled KJV source.

The delimiters are stripped while decoding and become ranges on `Verse`, so
they never reach search, favorites, accessibility, or the user interface.
"""

import json
import re
import sys
from difflib import SequenceMatcher
from pathlib import Path

START = "\ue000"
END = "\ue001"

RED_LETTER_BOOK_FILES = {
    "mt": "matthew", "mk": "mark", "lk": "luke", "jo": "john",
    "act": "acts", "1co": "1_corinthians", "2co": "2_corinthians",
    "re": "revelation",
}


def comparable(text: str) -> str:
    """Matches typography and supplied-word markup without changing display text."""
    return re.sub(r"[\[\]{}]", "", text).replace("’", "'").replace("‘", "'")


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: mark_words_of_jesus.py <existing-kjv.json> <red-letter-repo>")
        return 2

    target_path = Path(sys.argv[1])
    source_root = Path(sys.argv[2])
    books = json.loads(target_path.read_text())
    for book in books:
        for chapter in book["chapters"]:
            for index, verse in enumerate(chapter):
                chapter[index] = verse.replace(START, "").replace(END, "")
    marked = 0
    unmatched = []

    for book in books:
        source_filename = RED_LETTER_BOOK_FILES.get(book["abbrev"])
        if not source_filename:
            continue

        source_path = source_root / f"{source_filename}.json"
        source = json.loads(source_path.read_text())["chapters"]
        for chapter_index, verses in enumerate(book["chapters"], start=1):
            source_verses = source[str(chapter_index)]
            original_verses = list(verses)
            claimed_target_indexes = set()

            for source_verse_number, source_text in source_verses.items():
                red_segments = re.findall(r"\{([^{}]+)\}", source_text)
                if not red_segments:
                    continue

                source_plain = comparable(source_text)
                candidate_indexes = [
                    index for index in range(len(original_verses))
                    if index not in claimed_target_indexes
                ]
                target_index = max(
                    candidate_indexes,
                    key=lambda index: SequenceMatcher(
                        None, source_plain, comparable(original_verses[index])
                    ).ratio(),
                )
                similarity = SequenceMatcher(
                    None, source_plain, comparable(original_verses[target_index])
                ).ratio()
                if similarity < 0.5:
                    unmatched.append((
                        book["abbrev"], chapter_index, source_verse_number,
                        "could not align source verse", source_text,
                    ))
                    continue

                text = original_verses[target_index]
                result = text
                search_start = 0
                for segment in red_segments:
                    # Convert the source's italic markup to the app's display form.
                    display_segment = (
                        segment.replace("[", "{").replace("]", "}")
                        .replace("’", "'").replace("‘", "'")
                    )
                    position = result.find(display_segment, search_start)
                    if position < 0:
                        if comparable(segment) == source_plain:
                            result = START + text + END
                            break
                        unmatched.append((
                            book["abbrev"], chapter_index, source_verse_number,
                            segment, text,
                        ))
                        break
                    end = position + len(display_segment)
                    result = result[:position] + START + result[position:end] + END + result[end:]
                    search_start = end + len(START) + len(END)
                else:
                    verses[target_index] = result
                    claimed_target_indexes.add(target_index)
                    marked += 1
                    continue

                if result.startswith(START) and result.endswith(END):
                    verses[target_index] = result
                    claimed_target_indexes.add(target_index)
                    marked += 1

    if unmatched:
        print(f"Skipped {len(unmatched)} red-letter source verses not present in the bundled corpus.")
        for item in unmatched[:10]:
            print(item[:4])

    target_path.write_text(json.dumps(books, ensure_ascii=False, separators=(",", ":")))
    print(f"Marked {marked} verses.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
