#!/usr/bin/env python3
"""Builds `The Bible Widgets/LockScreenVerses.json`: the lock-screen widget's verses and the
app's well-known verses (Verse Match, Word Search). The one file belongs to both targets.

Verse text is copied exactly from the bundled KJV (`The Bible/kjv.json`), so nothing is
retyped by hand. The list is shuffled once with a fixed seed; the widget shows the verses
in this order, one per day. Re-run after editing REFERENCES:

    python3 Scripts/make_lockscreen_verses.py
"""
import json
import pathlib
import random
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
KJV = ROOT / "The Bible" / "kjv.json"
OUTPUT = ROOT / "The Bible Widgets" / "LockScreenVerses.json"
SEED = 2026

# Same abbreviation-to-name mapping the app uses (BibleData.swift).
NAMES = {
    "gn": "Genesis", "ex": "Exodus", "lev": "Leviticus", "num": "Numbers", "de": "Deuteronomy",
    "jos": "Joshua", "jdg": "Judges", "ru": "Ruth", "1sa": "1 Samuel", "2sa": "2 Samuel",
    "1ki": "1 Kings", "2ki": "2 Kings", "1ch": "1 Chronicles", "2ch": "2 Chronicles",
    "ezr": "Ezra", "ne": "Nehemiah", "es": "Esther", "job": "Job", "ps": "Psalms",
    "pr": "Proverbs", "ec": "Ecclesiastes", "so": "Song of Solomon", "is": "Isaiah",
    "je": "Jeremiah", "la": "Lamentations", "eze": "Ezekiel", "da": "Daniel", "ho": "Hosea",
    "joe": "Joel", "am": "Amos", "ob": "Obadiah", "jon": "Jonah", "mic": "Micah", "na": "Nahum",
    "hab": "Habakkuk", "zep": "Zephaniah", "hag": "Haggai", "zec": "Zechariah", "mal": "Malachi",
    "mt": "Matthew", "mr": "Mark", "lu": "Luke", "joh": "John", "ac": "Acts", "ro": "Romans",
    "1co": "1 Corinthians", "2co": "2 Corinthians", "ga": "Galatians", "eph": "Ephesians",
    "php": "Philippians", "col": "Colossians", "1th": "1 Thessalonians", "2th": "2 Thessalonians",
    "1ti": "1 Timothy", "2ti": "2 Timothy", "tit": "Titus", "phm": "Philemon", "heb": "Hebrews",
    "jas": "James", "1pe": "1 Peter", "2pe": "2 Peter", "1jo": "1 John", "2jo": "2 John",
    "3jo": "3 John", "jude": "Jude", "re": "Revelation",
}

REFERENCES = {
    "Genesis": ["1:1", "1:27", "1:31", "2:7", "12:2", "15:6", "18:14", "28:15", "50:20"],
    "Exodus": ["3:14", "14:14", "15:2", "15:11", "20:12", "33:14", "34:6"],
    "Leviticus": ["19:18"],
    "Numbers": ["6:24", "6:25", "6:26", "23:19"],
    "Deuteronomy": ["6:5", "7:9", "8:3", "31:6", "31:8", "33:27"],
    "Joshua": ["1:8", "1:9", "24:15"],
    "Ruth": ["1:16"],
    "1 Samuel": ["2:2", "12:24", "16:7"],
    "2 Samuel": ["22:31"],
    "1 Kings": ["8:56"],
    "1 Chronicles": ["16:11", "16:34", "29:11"],
    "2 Chronicles": ["7:14", "16:9"],
    "Nehemiah": ["8:10"],
    "Esther": ["4:14"],
    "Job": ["19:25", "23:10", "42:2"],
    "Psalms": [
        "1:1", "1:2", "1:3", "4:8", "5:3", "8:3", "8:4", "9:9", "9:10", "16:8", "16:11", "18:2",
        "19:1", "19:14", "23:1", "23:2", "23:3", "23:4", "23:6", "25:4", "25:5", "27:1", "27:14",
        "28:7", "29:11", "30:5", "31:24", "32:8", "34:4", "34:8", "34:18", "37:4", "37:5", "37:7",
        "40:1", "42:1", "42:11", "46:1", "46:10", "51:10", "51:12", "55:22", "56:3", "62:1",
        "62:8", "63:1", "63:3", "66:20", "73:26", "84:11", "86:5", "90:12", "91:1", "91:2",
        "91:11", "95:1", "96:1", "100:4", "100:5", "103:1", "103:2", "103:12", "107:1", "118:24",
        "119:11", "119:105", "119:114", "121:1", "121:2", "121:3", "121:8", "126:5", "133:1", "136:1",
        "138:8", "139:14", "139:23", "143:8", "145:18", "147:3", "150:6",
    ],
    "Proverbs": [
        "3:3", "3:5", "3:6", "3:9", "3:27", "4:23", "10:12", "11:25", "12:25", "14:29", "15:1", "16:3",
        "16:9", "16:24", "17:17", "17:22", "18:10", "18:24", "19:21", "22:6", "27:17", "31:25",
        "31:30",
    ],
    "Ecclesiastes": ["3:1", "3:11", "4:9", "12:13"],
    "Song of Solomon": ["8:7"],
    "Isaiah": [
        "9:6", "12:2", "26:3", "26:4", "30:15", "40:8", "40:29", "40:31", "41:10", "41:13", "43:2",
        "43:19", "53:5", "54:10", "55:8", "55:9", "58:11", "61:1", "64:8",
    ],
    "Jeremiah": ["17:7", "29:11", "29:13", "31:3", "32:17", "33:3"],
    "Lamentations": ["3:22", "3:23", "3:25"],
    "Ezekiel": ["36:26"],
    "Daniel": ["2:20"],
    "Hosea": ["6:3"],
    "Joel": ["2:13"],
    "Micah": ["6:8", "7:18"],
    "Nahum": ["1:7"],
    "Habakkuk": ["3:19"],
    "Zephaniah": ["3:17"],
    "Zechariah": ["4:6"],
    "Malachi": ["3:6"],
    "Matthew": [
        "4:4", "5:3", "5:4", "5:5", "5:6", "5:7", "5:8", "5:9", "5:14", "5:16", "5:44", "6:21",
        "6:33", "6:34", "7:7", "7:12", "11:28", "11:29", "16:26", "17:20", "18:20", "19:26",
        "22:37", "22:39", "24:35", "28:19", "28:20",
    ],
    "Mark": ["9:23", "10:27", "10:45", "11:24", "12:30"],
    "Luke": ["1:37", "6:31", "6:38", "10:27", "11:9", "12:34", "15:7", "19:10"],
    "John": [
        "1:1", "1:5", "1:12", "1:14", "3:16", "3:17", "4:24", "6:35", "8:12", "8:32", "10:10",
        "10:11", "11:25", "13:34", "13:35", "14:1", "14:6", "14:27", "15:5", "15:12", "15:13",
        "16:33", "20:29",
    ],
    "Acts": ["1:8", "2:38", "4:12", "16:31", "20:35"],
    "Romans": [
        "1:16", "3:23", "5:1", "5:5", "5:8", "6:23", "8:1", "8:18", "8:28", "8:31", "8:38",
        "8:39", "10:9", "10:17", "12:2", "12:12", "12:21", "15:13",
    ],
    "1 Corinthians": ["2:9", "10:13", "13:4", "13:7", "13:13", "15:57", "15:58", "16:14"],
    "2 Corinthians": ["4:16", "4:18", "5:7", "5:17", "9:7", "12:9"],
    "Galatians": ["2:20", "5:1", "5:22", "5:23", "6:2", "6:9"],
    "Ephesians": ["2:8", "2:10", "3:20", "4:2", "4:32", "6:10"],
    "Philippians": ["1:6", "2:3", "3:14", "4:4", "4:6", "4:7", "4:8", "4:13", "4:19"],
    "Colossians": ["3:2", "3:12", "3:14", "3:15", "3:17", "3:23"],
    "1 Thessalonians": ["5:11", "5:16", "5:17", "5:18"],
    "2 Thessalonians": ["3:3"],
    "1 Timothy": ["4:12", "6:6"],
    "2 Timothy": ["1:7", "3:16", "4:7"],
    "Titus": ["3:5"],
    "Hebrews": ["4:12", "4:16", "10:23", "11:1", "11:6", "12:1", "12:2", "13:5", "13:8"],
    "James": ["1:2", "1:5", "1:12", "1:17", "1:22", "4:8", "5:16"],
    "1 Peter": ["2:9", "3:15", "4:8", "5:7"],
    "2 Peter": ["3:9"],
    "1 John": ["1:9", "3:1", "3:18", "4:4", "4:7", "4:8", "4:18", "4:19", "5:14"],
    "Jude": ["1:24"],
    "Revelation": ["3:20", "21:4", "22:13"],
}


def clean(text: str) -> str:
    """Removes KJV translator footnotes ("{ordained: or, prepared}") and keeps words the
    translators supplied in italics ("ye {are} the branches" -> "ye are the branches")."""
    # Red-letter markers around the words of Jesus (see mark_words_of_jesus.py).
    text = text.replace("\ue000", "").replace("\ue001", "")
    text = re.sub(r"\s*\{[^{}]*:[^{}]*\}", "", text)
    text = re.sub(r"\{([^{}]*)\}", r"\1", text)
    return re.sub(r"\s+", " ", text).strip()


def main() -> int:
    data = json.loads(KJV.read_text(encoding="utf-8-sig"))
    books = {}
    for entry in data:
        name = entry.get("name") or NAMES.get(entry["abbrev"].lower(), entry["abbrev"].upper())
        books[name] = entry["chapters"]

    verses, missing = [], []
    for book, refs in REFERENCES.items():
        for ref in refs:
            chapter, verse = (int(part) for part in ref.split(":"))
            try:
                text = books[book][chapter - 1][verse - 1]
            except (KeyError, IndexError):
                missing.append(f"{book} {ref}")
                continue
            verses.append({"book": book, "chapter": chapter, "verse": verse, "text": clean(text)})

    if missing:
        print("References not found in kjv.json:", ", ".join(missing), file=sys.stderr)
        return 1
    if len({(v["book"], v["chapter"], v["verse"]) for v in verses}) != len(verses):
        print("Duplicate references in REFERENCES.", file=sys.stderr)
        return 1

    random.Random(SEED).shuffle(verses)
    contents = json.dumps(verses, ensure_ascii=False, indent=1) + "\n"
    OUTPUT.write_text(contents, encoding="utf-8")
    print(f"Wrote {len(verses)} verses ({OUTPUT.stat().st_size // 1024} KB) to {OUTPUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
