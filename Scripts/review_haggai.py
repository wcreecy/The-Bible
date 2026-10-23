#!/usr/bin/env python3
"""Apply the completed editorial review for Haggai to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


WWA = {
    1: ("Zephaniah's hopeful close looked forward to a humble, restored people gathered by God "
        "(Zephaniah 3:18-20). Haggai opens the next book roughly a century later, now that the exile "
        "itself is over: the returned community has built comfortable homes of its own but left the LORD's "
        "house in ruins, and poor harvests follow that neglect. The prophet's call to consider their ways "
        "and rebuild gets an immediate response from Zerubbabel, Joshua, and the people, setting up chapter "
        "2's further messages once work is underway."),
    2: ("Chapter 1 ended with the leaders and people obeying Haggai's call and resuming work on the "
        "temple, encouraged by God's promise to be with them (Haggai 1:12-14). Chapter 2 records three "
        "further messages once building is underway: an encouragement that the new, modest temple will one "
        "day hold greater glory than Solomon's, a lesson from the priests about how holiness and impurity "
        "spread, and a closing promise that singles out Zerubbabel himself as God's chosen signet. That "
        "personal promise to a descendant of David closes the book looking toward a future beyond Persian "
        "rule."),
}

NAME_FIXES = {
    2: {"The remnant / people of the land": "The remnant (people of the land)"},
}

ROLE_FIXES = {
    1: {
        "Haggai":
            "Prophet and messenger of the LORD. Communicates the rebuke, rebuilding instructions, and "
            "reassurance to the leaders and community (1:1, 3, 12–13).",
    },
}

DROPPED_FIGURES = {
    2: {"Darius", "The nations and kingdoms"},
}

THEMES = {
    1: {
        "Reexamining priorities":
            "Twice the LORD commands the people to \"consider your ways,\" pointing to their effort spent "
            "on their own houses while his house still lay in ruins (1:2-5,7-9).",
        "Hardship within the prophetic covenant message":
            "Haggai connects the community's poor harvests and empty earnings directly to their neglect of "
            "the temple, naming specific economic hardship as a response to specific disobedience "
            "(1:5-6,9-11).",
        "Obedience expressed through action":
            "Zerubbabel, Joshua, and the people respond to the message not just with reverence but by "
            "actually resuming construction on the temple (1:8,12,14-15).",
        "Divine presence and encouragement":
            "Once the people obey, the LORD answers with the short assurance \"I am with you\" and stirs "
            "their spirits to keep working (1:12-14).",
    },
    2: {
        "Courage despite humble beginnings":
            "Those who remember Solomon's temple see the new, modest building as nothing by comparison, yet "
            "the LORD tells Zerubbabel, Joshua, and the people to be strong and keep working anyway (2:1-5).",
        "Divine presence, glory, and peace":
            "The LORD promises to shake the nations and fill this house with a glory and peace greater than "
            "the former temple ever had (2:5-9).",
        "Holiness, impurity, and integrity":
            "A ruling from the priests shows that holiness does not spread by touch the way uncleanness "
            "does, so going through the motions of worship cannot make an unfaithful people clean "
            "(2:10-14).",
        "Remembering hardship and anticipating blessing":
            "The LORD points back to the lean years before the rebuilding began, then promises blessing "
            "going forward even before any harvest has shown it (2:15-19).",
        "Sovereignty over rulers and chosen leadership":
            "In the same breath that God promises to overthrow the thrones and armies of nations, he "
            "singles out Zerubbabel personally as his chosen servant and signet (2:20-23).",
    },
}


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "37_haggai.json"
    data = load(path)
    for n in range(1, 3):
        key = f"Haggai {n}"
        entry = data[key]
        entry["whereWeAre"] = WWA[n]
        kept_figures = []
        for fig in entry["keyFigures"]:
            original_name = fig["name"]
            if original_name in DROPPED_FIGURES.get(n, set()):
                continue
            if original_name in NAME_FIXES.get(n, {}):
                fig["role"] = ROLE_FIXES.get(n, {}).get(original_name, fig["role"])
                fig["name"] = NAME_FIXES[n][original_name]
            elif original_name in ROLE_FIXES.get(n, {}):
                fig["role"] = ROLE_FIXES[n][original_name]
            kept_figures.append(fig)
        entry["keyFigures"] = kept_figures
        theme_map = THEMES[n]
        seen = set()
        for theme in entry["keyThemes"]:
            name = theme["theme"]
            if name not in theme_map:
                raise SystemExit(f"Haggai {n}: no explanation drafted for theme {name!r}")
            theme["explanation"] = theme_map[name]
            seen.add(name)
        missing = set(theme_map) - seen
        if missing:
            raise SystemExit(f"Haggai {n}: drafted themes not in source: {missing}")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_overview():
    path = ROOT / "book_overviews" / "06_minor_prophets.json"
    data = load(path)
    entry = data["Haggai"]
    entry["theme"] = entry["theme"].replace(
        "God's people must put His priorities ahead of complacent self-interest; renewed obedience brings "
        "courage and hope.",
        "God's people must put his priorities ahead of complacent self-interest; renewed obedience brings "
        "courage and hope.",
    )
    for fig in entry["keyFigures"]:
        if fig["name"] == "Zerubbabel":
            fig["description"] = fig["description"].replace(
                "Governor of Judah and descendant of David, called God's 'signet ring.'",
                "Governor of Judah and descendant of David, whom God calls \"a signet\" (2:23).",
            )
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_PRONOUN_FIXES = [
    ("assures Zerubbabel, Joshua, and the people that He is with them when they obey.",
     "assures Zerubbabel, Joshua, and the people that he is with them when they obey."),
    ("So God sent drought on their crops. His command is clear:",
     "So God sent drought on their crops. his command is clear:"),
    ("but God commands them to be strong because His Spirit remains with them. He promises to fill His "
     "house with glory and give peace beyond what its outward appearance suggests.",
     "but God commands them to be strong because his Spirit remains with them. he promises to fill his "
     "house with glory and give peace beyond what its outward appearance suggests."),
    ("But He tells them, “Yet now be strong, O Zerubbabel",
     "But he tells them, “Yet now be strong, O Zerubbabel"),
    ("Then God makes a great promise. He will soon “shake the heavens, and the earth,”",
     "Then God makes a great promise. he will soon “shake the heavens, and the earth,”"),
    ("He struck their crops “with blasting and with mildew and with hail,” yet they did not turn to Him.",
     "he struck their crops “with blasting and with mildew and with hail,” yet they did not turn to him."),
    ("God promises Zerubbabel that He will shake creation and overthrow earthly kingdoms.",
     "God promises Zerubbabel that he will shake creation and overthrow earthly kingdoms."),
    ("a sign of His continuing purpose.",
     "a sign of his continuing purpose."),
    ("throwing down chariots and riders. Then He makes a personal promise:",
     "throwing down chariots and riders. Then he makes a personal promise:"),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "06_minor_prophets.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("# Haggai")
    end = text.index("# Zechariah")
    section = text[start:end]
    for old, new in STORY_PRONOUN_FIXES:
        count = section.count(old)
        if count == 0:
            if section.count(new) == 1:
                continue
            raise SystemExit(f"story fix matched 0 times and not already applied: {old!r}")
        if count != 1:
            raise SystemExit(f"story fix matched {count} times (expected 1): {old!r}")
        section = section.replace(old, new)
    path.write_text(text[:start] + section + text[end:], encoding="utf-8")
    print(f"Updated {path.relative_to(ROOT)}")


if __name__ == "__main__":
    apply_chapter_insights()
    apply_overview()
    apply_story_fixes()
