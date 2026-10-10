#!/usr/bin/env python3
"""Adds private-use red-letter delimiters to the bundled KJV source.

The delimiters are stripped while decoding and become ranges on `Verse`, so
they never reach search, favorites, accessibility, or the user interface.
"""

import json
import re
import sys
from pathlib import Path

START = "\ue000"
END = "\ue001"

ABBREVIATIONS = {
    "Matthew": "mt", "Mark": "mr", "Luke": "lu", "John": "joh",
    "Acts": "ac", "1 Corinthians": "1co", "2 Corinthians": "2co",
    "Revelation": "re",
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
    marked = 0
    unmatched = []

    for book in books:
        source_abbreviation = ABBREVIATIONS.get(book.get("name"))
        if not source_abbreviation:
            continue

        source_path = source_root / f"{book['name'].lower().replace(' ', '_')}.json"
        source = json.loads(source_path.read_text())["chapters"]
        for chapter_index, verses in enumerate(book["chapters"], start=1):
            source_verses = source[str(chapter_index)]
            for verse_index, text in enumerate(verses, start=1):
                source_text = source_verses[str(verse_index)]
                red_segments = re.findall(r"\{([^{}]+)\}", source_text)
                if not red_segments:
                    continue

                result = text
                search_start = 0
                for segment in red_segments:
                    # Convert the source's italic markup to the app's display form.
                    display_segment = segment.replace("[", "{").replace("]", "}")
                    position = result.find(display_segment, search_start)
                    if position < 0:
                        unmatched.append((book["name"], chapter_index, verse_index, segment, text))
                        break
                    end = position + len(display_segment)
                    result = result[:position] + START + result[position:end] + END + result[end:]
                    search_start = end + len(START) + len(END)
                else:
                    verses[verse_index - 1] = result
                    marked += 1

    if unmatched:
        print(f"Could not align {len(unmatched)} red-letter verses; refusing to write output.")
        for item in unmatched[:10]:
            print(item[:4])
        return 1

    target_path.write_text(json.dumps(books, ensure_ascii=False, separators=(",", ":")))
    print(f"Marked {marked} verses.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
