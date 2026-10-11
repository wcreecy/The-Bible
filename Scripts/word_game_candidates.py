#!/usr/bin/env python3
"""List every 5-letter word in the KJV with its count, as raw input for curating
the WORD game answer list. Prints: WORD count capitalized-share in-dictionary
"""
import json
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KJV = ROOT / "The Bible" / "kjv.json"


def clean(raw: str) -> str:
    """Mirror KJVTextCleaner: drop {x: y} footnotes, keep {supplied} words, strip red-letter marks."""
    text = raw.replace("", "").replace("", "")
    text = re.sub(r"\{[^{}]*:[^{}]*\}", "", text)
    text = text.replace("{", "").replace("}", "")
    return re.sub(r"\s+", " ", text).strip()


def main() -> None:
    books = json.loads(KJV.read_text(encoding="utf-8-sig"))
    counts: Counter[str] = Counter()
    capitalized: Counter[str] = Counter()
    for book in books:
        for chapter in book["chapters"]:
            for verse in chapter:
                for token in re.findall(r"[A-Za-z]+", clean(verse)):
                    if len(token) != 5:
                        continue
                    upper = token.upper()
                    counts[upper] += 1
                    if token[0].isupper():
                        capitalized[upper] += 1

    dictionary = {w.strip().lower() for w in open("/usr/share/dict/words") if w.strip().islower()}
    min_count = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    for word, n in sorted(counts.items(), key=lambda kv: -kv[1]):
        if n < min_count:
            continue
        cap = capitalized[word] / n
        in_dict = word.lower() in dictionary
        print(f"{word} {n} {cap:.2f} {'D' if in_dict else '-'}")


if __name__ == "__main__":
    main()
