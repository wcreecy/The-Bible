#!/usr/bin/env python3
"""Apply the completed editorial review for Malachi to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


WWA = {
    1: ("Zechariah closed with holiness extending even to ordinary objects once the LORD reigned as "
        "king over the whole earth (Zechariah 14:20-21). Malachi opens a new book, likely a century "
        "later, with the same returned community now grown cynical: when God declares his love for "
        "Jacob, the people ask how that love has ever shown itself. The chapter's turn to blind, lame, "
        "and sick sacrifices on the altar sets up chapter 2's wider charge that the priests themselves "
        "have corrupted the very worship they were meant to guard."),
    2: ("Chapter 1 ended by condemning priests who treated God's altar as a burden and offered damaged "
        "sacrifices (Malachi 1:12-14). Chapter 2 widens that charge: the priests have corrupted the "
        "teaching role tied to Levi's covenant, and the wider community has broken faith both with God "
        "and with each other through unfaithful marriages. The chapter's closing complaint, that "
        "evildoers seem to please God and justice never comes, sets up chapter 3's answer about a coming "
        "messenger and a coming day of reckoning."),
    3: ("Chapter 2 ended with the people wearying God by asking where his justice has gone (Malachi "
        "2:17). Chapter 3 answers directly: a messenger will prepare the way before the LORD suddenly "
        "comes to his own temple to purify the priesthood like a refiner's fire, judge exploiters of the "
        "vulnerable, and call the people back through the tithes they have withheld. The chapter's "
        "closing promise, that God is compiling a book of remembrance for those who fear him, sets up the "
        "book's final chapter and its vision of the day that promise will be revealed."),
    4: ("Chapter 3 promised a book of remembrance for those who feared the LORD, waiting for the day "
        "that distinction between righteous and wicked would be made plain (Malachi 3:16-18). Malachi's "
        "closing chapter, and the last chapter of the Old Testament, describes that day directly: "
        "burning judgment for the proud, healing for the reverent, a call to remember Moses's law, and a "
        "promise to send Elijah before the great and dreadful day of the LORD. About four hundred years "
        "of prophetic silence follow before John the Baptist and Jesus open the New Testament."),
}

SUMMARY_FIXES = {
    3: [
        ("The identity and relationship of these figures are debated.",
         "Many readers distinguish the unnamed preparatory messenger from the messenger of the covenant, "
         "since the text identifies the second as the LORD himself arriving at his own temple."),
    ],
}

NAME_FIXES = {
    1: {
        "Israel / Jacob": "Israel (Jacob)",
        "Esau / Edom": "Esau (Edom)",
    },
    2: {
        "Judah / Israel / the community": "Judah (Israel, the community)",
    },
}

ROLE_FIXES = {
    2: {
        "The priests":
            "Guardians of Torah instruction. Expected to guide the community but charged with partiality "
            "and misleading teaching (2:1–9).",
    },
    3: {
        "The LORD":
            "Speaker, purifier, and judge, called \"the messenger of the covenant\" as he comes "
            "suddenly to his own temple. Promises to purify the priesthood, confront oppression, and "
            "remember the faithful (3:1–18).",
        "The preparatory messenger":
            "Unnamed figure sent to prepare the way before the LORD's own coming. Christian tradition "
            "identifies this messenger with John the Baptist (3:1; see Mark 1:2).",
        "The sons of Levi":
            "Priestly community. Will be purified for righteous offerings (3:3–4).",
        "Oppressors and wrongdoers":
            "Groups facing divine judgment. Include perjurers and those exploiting workers, widows, "
            "orphans, and foreigners (3:5).",
        "Those who fear the LORD":
            "Faithful members of the community. Speak to one another and are remembered before God "
            "(3:16–18).",
    },
}

DROPPED_FIGURES = {
    3: {"The messenger of the covenant"},
}

THEMES = {
    1: {
        "Covenant love and the problem of recognition":
            "God states his love for Jacob plainly, but the people's question, \"Wherein hast thou loved "
            "us?\", shows a community that no longer recognizes love it already has (1:2-5).",
        "Reverence rather than perfunctory worship":
            "Blind, lame, and sick animals offered on the altar reveal worship reduced to going through "
            "the motions rather than treating God with the honor a father or governor would expect "
            "(1:6-8,12-14).",
        "Integrity in vows and offerings":
            "A curse falls on anyone who vows a good animal but substitutes a blemished one, since the "
            "problem is deliberate deception, not simple poverty (1:8-10,13-14).",
        "God’s name beyond Israel":
            "Even while Israel's own priests dishonor the altar, the LORD declares that his name will be "
            "great among the nations, reversing the expected direction of honor (1:5,11,14).",
    },
    2: {
        "Responsible spiritual teaching":
            "Priests are meant to preserve true knowledge the way Levi once did, but instead they mislead "
            "others and show favoritism in applying the law (2:5-9).",
        "Faithfulness to covenant relationships":
            "Judah shares one covenant identity and \"one father,\" yet deals treacherously with its own "
            "members, showing that corrupted worship and broken community go together (2:10-12).",
        "Marriage, justice, and betrayal":
            "Marriage is described in covenant terms, with God himself as witness, so betraying \"the "
            "wife of thy youth\" is treated as treachery against God, not just against a spouse "
            "(2:13-16).",
        "Questioning divine justice":
            "The people weary God by claiming that evildoers please him or by demanding to know where "
            "justice is, setting up the direct answer that follows in chapter 3 (2:17).",
    },
    3: {
        "Purification before acceptable worship":
            "The LORD's coming is pictured as a refiner's fire and fuller's soap, intense enough to "
            "purify the sons of Levi so that their offerings finally become acceptable again (3:1-4).",
        "Justice for vulnerable neighbors":
            "The LORD's judgment specifically names sorcery, adultery, false oaths, and the exploitation "
            "of hired workers, widows, orphans, and foreigners (3:5).",
        "Returning to God and communal support":
            "Withheld tithes are named directly as robbing God, and the LORD invites the people to test "
            "him by bringing the full tithe and seeing the blessing that follows (3:6-12).",
        "Hope despite apparent injustice":
            "Against those who say serving God is useless, a book of remembrance is written for those who "
            "fear the LORD, promising that the difference between righteous and wicked will not stay "
            "hidden forever (3:13-18).",
    },
    4: {
        "The Day of the LORD and accountability":
            "The coming day is pictured as a furnace that leaves the arrogant and wicked like stubble, "
            "with neither root nor branch remaining (4:1,3).",
        "Healing and hope for the reverent":
            "For those who fear God's name, the same day brings healing, pictured as the sun rising and "
            "as calves let loose from the stall to leap for joy (4:2).",
        "Remembering covenant instruction":
            "The book calls Israel back to the law of Moses given at Horeb, grounding future hope in "
            "existing covenant instruction rather than something entirely new (4:4).",
        "Reconciliation between generations":
            "Elijah's promised coming is tied specifically to turning the hearts of parents and children "
            "toward each other, so that the land will not be struck with a curse (4:5-6).",
    },
}


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "39_malachi.json"
    data = load(path)
    for n in range(1, 5):
        key = f"Malachi {n}"
        entry = data[key]
        entry["whereWeAre"] = WWA[n]
        for old, new in SUMMARY_FIXES.get(n, []):
            if old not in entry["summary"]:
                raise SystemExit(f"Malachi {n}: summary fix not found: {old!r}")
            entry["summary"] = entry["summary"].replace(old, new)
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
                raise SystemExit(f"Malachi {n}: no explanation drafted for theme {name!r}")
            theme["explanation"] = theme_map[name]
            seen.add(name)
        missing = set(theme_map) - seen
        if missing:
            raise SystemExit(f"Malachi {n}: drafted themes not in source: {missing}")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_overview():
    path = ROOT / "book_overviews" / "06_minor_prophets.json"
    data = load(path)
    entry = data["Malachi"]
    entry["theme"] = (
        "God remains faithful to his covenant and calls his people to return to sincere worship and "
        "faithful obedience while awaiting his coming judgment and restoration."
    )
    entry["movements"][0]["description"] = entry["movements"][0]["description"].replace(
        "God affirms His love for Israel, then rebukes the priests for offering defective sacrifices and "
        "dishonoring His name.",
        "God affirms his love for Israel, then rebukes the priests for offering defective sacrifices and "
        "dishonoring his name.",
    )
    for fig in entry["keyFigures"]:
        if fig["name"] == "Malachi":
            fig["description"] = fig["description"].replace(
                "The prophet ('my messenger') who confronts the post-exilic community.",
                "The prophet (meaning \"my messenger\") who confronts the post-exilic community.",
            )
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_PRONOUN_FIXES = [
    ("God declares His enduring love and points to His treatment of Jacob and Esau. Israel's "
     "difficult circumstances have not erased His covenant faithfulness, while Edom's efforts to "
     "rebuild cannot overturn His judgment.",
     "God declares his enduring love and points to his treatment of Jacob and Esau. Israel's "
     "difficult circumstances have not erased his covenant faithfulness, while Edom's efforts to "
     "rebuild cannot overturn his judgment."),
    ("This is a strong way of saying that God chose Jacob, not Esau, to carry His promises.",
     "This is a strong way of saying that God chose Jacob, not Esau, to carry his promises."),
    ("God answers that they offer blind, lame, and sick animals as sacrifices. He dares them,",
     "God answers that they offer blind, lame, and sick animals as sacrifices. he dares them,"),
    ("He reminds the priests of Levi, the father of the priestly tribe, who once served faithfully:",
     "he reminds the priests of Levi, the father of the priestly tribe, who once served faithfully:"),
    ("God rejects tears at the altar that conceal unfaithfulness and confronts people who question "
     "whether He will ever judge evil.",
     "God rejects tears at the altar that conceal unfaithfulness and confronts people who question "
     "whether he will ever judge evil."),
    ("So He warns twice, “take heed to your spirit, that ye deal not treacherously.”",
     "So he warns twice, “take heed to your spirit, that ye deal not treacherously.”"),
    ("God promises a messenger who will prepare the way before the Lord comes to His temple. His "
     "coming will purify the priesthood and expose injustice, adultery, false oaths, exploitation, "
     "and oppression,",
     "God promises a messenger who will prepare the way before the Lord comes to his temple. his "
     "coming will purify the priesthood and expose injustice, adultery, false oaths, exploitation, "
     "and oppression,"),
    ("The Gospels say this messenger was John the Baptist, who prepared the way for Jesus (Mark 1:2; "
     "Luke 7:27). But His coming will not be easy:",
     "The Gospels say this messenger was John the Baptist, who prepared the way for Jesus (Mark 1:2; "
     "Luke 7:27). But his coming will not be easy:"),
    ("God will purify the priests “as gold and silver,” so their offerings will please Him again.",
     "God will purify the priests “as gold and silver,” so their offerings will please him again."),
    ("He will also be “a swift witness” against sorcerers, adulterers, liars,",
     "he will also be “a swift witness” against sorcerers, adulterers, liars,"),
    ("Then He gives the reason Israel still exists:",
     "Then he gives the reason Israel still exists:"),
    ("Within Israel's covenant, He promises blessing, protected crops,",
     "Within Israel's covenant, he promises blessing, protected crops,"),
    ("Then God makes a challenge He makes nowhere else:",
     "Then God makes a challenge he makes nowhere else:"),
    ("He will stop the locusts from destroying their crops.",
     "he will stop the locusts from destroying their crops."),
    ("those who fear the Lord speak together and are remembered. God calls them His treasured "
     "possession and promises that the distinction between righteous and wicked will become clear.",
     "those who fear the Lord speak together and are remembered. God calls them his treasured "
     "possession and promises that the distinction between righteous and wicked will become clear."),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "06_minor_prophets.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("# Malachi")
    section = text[start:]
    for old, new in STORY_PRONOUN_FIXES:
        count = section.count(old)
        if count == 0:
            if section.count(new) == 1:
                continue
            raise SystemExit(f"story fix matched 0 times and not already applied: {old!r}")
        if count != 1:
            raise SystemExit(f"story fix matched {count} times (expected 1): {old!r}")
        section = section.replace(old, new)
    path.write_text(text[:start] + section, encoding="utf-8")
    print(f"Updated {path.relative_to(ROOT)}")


if __name__ == "__main__":
    apply_chapter_insights()
    apply_overview()
    apply_story_fixes()
