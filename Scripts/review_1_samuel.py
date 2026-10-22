#!/usr/bin/env python3
"""Apply the 1 Samuel quality review to the source JSON."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent

def read(path):
    return json.loads(path.read_text(encoding="utf-8"))

def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

def lead(text):
    return text.split(". ", 1)[0].replace(" (", ". (")

def main():
    path = ROOT / "chapter_insights/09_1_samuel.json"
    chapters = read(path)
    for number in range(1, 32):
        key = f"1 Samuel {number}"
        current = lead(chapters[key]["summary"])
        if number == 1:
            previous = "Ruth 4 closes with Ruth's family line leading to David."
        else:
            previous = f"Chapter {number - 1} has just moved the story forward."
        if number == 31:
            next_step = "The account hands off to 2 Samuel 1, where David hears of Saul's death."
        else:
            next_step = f"Chapter {number + 1} continues the consequences of these events."
        chapters[key]["whereWeAre"] = f"{previous} {current}. {next_step}"
    chapters["1 Samuel 1"]["summary"] = (
        "Elkanah travels with his family to worship at Shiloh. Hannah, hurt by childlessness, prays and promises that a son will serve the LORD (1 Samuel 1:1–18). "
        "The LORD gives Hannah a son, Samuel. After he is weaned, she brings him to Eli at Shiloh to serve the LORD (1 Samuel 1:19–28)."
    )
    chapters["1 Samuel 2"]["summary"] = chapters["1 Samuel 2"]["summary"].replace(
        "treat offerings with contempt 1 Samuel 2:11–17,1 Samuel 2:22–25.",
        "treat offerings with contempt (1 Samuel 2:11–17, 22–25)."
    )
    chapters["1 Samuel 15"]["summary"] = chapters["1 Samuel 15"]["summary"].replace(
        "The chapter’s violent command belongs to an ancient war narrative and raises substantial modern ethical questions; it should not be used to justify present-day violence.",
        "The chapter records a severe command of judgment and Saul's refusal to carry it out fully (1 Samuel 15:1–35)."
    )
    write(path, chapters)
    overview_path = ROOT / "book_overviews/02_early_history.json"
    overview = read(overview_path)
    book = overview["1 Samuel"]
    book["author"] = "Samuel is the traditional author, with later material commonly linked to Nathan and Gad. The book itself does not name its writer."
    for field in ("audience", "purpose", "theme", "summary"):
        book[field] = book[field].replace("His", "his").replace("Him", "him")
    write(overview_path, overview)
    story_path = ROOT / "book_content/02_early_history.md"
    story = story_path.read_text(encoding="utf-8")
    start, end = story.index("# 1 Samuel"), story.index("# 2 Samuel")
    section = story[start:end]
    section = section.replace("turn toward Him.", "turn toward him.")
    section = section.replace("God has done what He said.", "God has done what he said.")
    section = section.replace("Saul disobeyed Him with the Amalekites", "Saul disobeyed him with the Amalekites")
    story_path.write_text(story[:start] + section + story[end:], encoding="utf-8")

if __name__ == "__main__":
    main()
