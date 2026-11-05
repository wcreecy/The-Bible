#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Targeted quality pass for 2 Chronicles: KJV facts and spellings, distinct Original Audience text,
overview coverage, and hedged interpretations in the story.

Run once, after review_2_chronicles.py.
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def replace_once(text, old, new, label):
    if text.count(old) == 0 and text.count(new) >= 1:
        return text
    if text.count(old) != 1:
        raise SystemExit(f"{label}: {text.count(old)} matches for {old!r}")
    return text.replace(old, new)


# (chapter, field, old, new) edits to chapter insights.
INSIGHT_FIXES = [
    ("2 Chronicles 1", "summary", "where Moses' tabernacle and the brasen altar still stand", "where Moses' tabernacle and the bronze altar still stand"),
    ("2 Chronicles 3", "summary", "Solomon makes the vail of blue, purple, and crimson", "Solomon makes the curtain of blue, purple, and crimson"),
    ("2 Chronicles 4", "summary", "a hundred gold basons", "a hundred gold basins"),
    ("2 Chronicles 15", "whereWeAre", "he will be found of you\" (2 Chronicles 15:2), and Asa leads", "he will be found of you,\" and Asa leads"),
    ("2 Chronicles 20", "whereWeAre", "but God's\" (2 Chronicles 20:15). Chapter 21", "but God's.\" Chapter 21"),
]


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "14_2_chronicles.json"
    data = load(path)
    for chapter, field, old, new in INSIGHT_FIXES:
        data[chapter][field] = replace_once(data[chapter][field], old, new, f"{chapter} {field}")
    for theme in data["2 Chronicles 3"]["keyThemes"]:
        theme["explanation"] = theme["explanation"].replace("the vail", "the curtain")
    for ref in data["2 Chronicles 18"]["explainedReferences"]:
        ref["explanation"] = ref["explanation"].replace("Ramoth-gilead", "Ramothgilead")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


# Original Audience text: who first heard it and what they knew (places and dates stay in the moment).
AUDIENCE = {
    1: "The first readers, rebuilding Jerusalem after exile, knew Solomon above all as the king who built the temple. They heard that he began his reign by seeking God before anything else.",
    2: "The first readers had rebuilt the temple with the same help, cedar brought from Lebanon (Ezra 3:7). They heard that a foreign king praised the LORD and helped build the first temple.",
    3: "The first readers knew Moriah from Abraham's offering of Isaac (Genesis 22:2). They heard that the temple stood on the same hill, and that it was planned as David had prepared.",
    5: "The first readers knew the ark was no longer in their temple, and they heard it described here in its glory. They learned that it held only the two tablets of stone (2 Chronicles 5:10).",
    8: "The first readers cared about the right order of worship. They heard that even in Solomon's busy years, the daily and feast offerings were kept as Moses and David had commanded.",
    14: "The first readers knew Ethiopia as a distant power, and they were a small people facing strong neighbors. They heard that Asa won by asking God for help, not by counting soldiers (2 Chronicles 14:11).",
    15: "The first readers had made their own oath to walk in God's law after the return (Nehemiah 10:29). They heard that Judah once swore an oath to seek the LORD \"with a loud voice, and with shouting, and with trumpets\" (2 Chronicles 15:14).",
    16: "The first readers heard Hanani say that the LORD looks for hearts that are true (2 Chronicles 16:9). They learned that a king who once trusted God could end by trusting others.",
    26: "The first readers knew Uzziah as the king whose pride ended in leprosy, and they knew that Isaiah's vision came in the year he died (Isaiah 6:1). They heard that he prospered as long as he sought God.",
    28: "The first readers knew Ahaz from Isaiah's warnings (Isaiah 7). They heard that enemies from Israel showed mercy when a prophet spoke, while Judah's own king sinned more in his trouble.",
    30: "The first readers were themselves a remnant, and they heard that the way back to the LORD was open to everyone who would humble themselves. Some mocked and some came (2 Chronicles 30:10–11).",
}

# (chapter, note title, old text, new text) edits to cultural notes.
CULTURE = [
    (15, "Burning an idol by the Kidron", "Asa destroys his grandmother Maachah's idol", "Asa destroys his mother Maachah's idol"),
    (20, "The valley of Berachah", "Berachah means ‘blessing.’", "Berachah means blessing."),
]


def apply_chapter_context():
    path = ROOT / "chapter_context" / "14_2_chronicles.json"
    data = load(path)
    for number, text in AUDIENCE.items():
        data[f"2 Chronicles {number}"]["audience"] = text
    for number, title, old, new in CULTURE:
        hits = [n for n in data[f"2 Chronicles {number}"]["culture"] if n["title"] == title]
        if len(hits) != 1:
            raise SystemExit(f"2 Chronicles {number}: {len(hits)} notes titled {title!r}")
        hits[0]["text"] = replace_once(hits[0]["text"], old, new, f"2 Chronicles {number} {title}")
    for key, entry in data.items():
        if not key.startswith("2 Chronicles"):
            continue
        for old, new in (("Ramoth-gilead", "Ramothgilead"), ("Beth-horon", "Bethhoron"), ("Kirjath-jearim", "Kirjathjearim")):
            entry["audience"] = entry["audience"].replace(old, new)
            for note in entry["culture"]:
                note["title"] = note["title"].replace(old, new)
                note["text"] = note["text"].replace(old, new)
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_book_overview():
    path = ROOT / "book_overviews" / "03_later_history.json"
    data = load(path)
    book = data["2 Chronicles"]
    book["author"] = replace_once(
        book["author"],
        "Ezra, according to Jewish tradition, who is also credited with 1 Chronicles. The book does not name its writer.",
        "1 and 2 Chronicles were one book. Jewish tradition credits Ezra as the author, though the book does not name its writer.",
        "author",
    )
    first = book["movements"][0]
    first["description"] = replace_once(
        first["description"],
        "The temple is constructed, dedicated, and filled with God's glory.",
        "Solomon asks for wisdom, builds and dedicates the temple, and reaches great wealth.",
        "movement",
    )
    first["passages"] = ["2 Chronicles 1-9"]
    for figure in book["keyFigures"]:
        if figure["name"] == "Uzziah":
            figure["description"] = replace_once(
                figure["description"],
                "A strong king struck with a skin disease after pridefully burning incense in the temple.",
                "A strong king struck with leprosy after he pridefully burned incense in the temple.",
                "Uzziah",
            )
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_FIXES = [
    ("asking for cedar, cypress, and a master craftsman", "asking for cedar, fir, and a master craftsman"),
    ("He even removes his grandmother Maachah from her position as queen mother because of her idol.", "He even removes his mother Maachah from her position as queen because of her idol."),
    ("They crown him, give him a copy of the law, and anoint him,", "They crown him, give him the testimony, probably a copy of the law, and anoint him,"),
    ("Jesus later spoke of the blood of Zechariah, who", "Many readers think Jesus later spoke of the blood of this Zechariah, who"),
    ("Jesus' parable of the Good Samaritan echoes this scene.", "Many readers hear an echo of this scene in Jesus' parable of the Good Samaritan."),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "03_later_history.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("# 2 Chronicles")
    end = text.find("\n# ", start + 5)
    end = len(text) if end < 0 else end + 1
    section = text[start:end]
    for old, new in STORY_FIXES:
        section = replace_once(section, old, new, f"story {old[:40]!r}")
    path.write_text(text[:start] + section + text[end:], encoding="utf-8")
    print(f"Updated {path.relative_to(ROOT)}")


if __name__ == "__main__":
    apply_chapter_insights()
    apply_chapter_context()
    apply_book_overview()
    apply_story_fixes()
