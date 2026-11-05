#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Full quality pass for Judges: plain wording, KJV spellings and facts, exact quotes, story fixes.

Run after review_judges.py. Every replacement must match exactly once (or already be applied).
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


# Chapter insights: (field, old, new) per chapter.
INSIGHT_FIXES = {
    "Judges 1": [
        ("summary", "sometimes subjecting them to forced labor rather than displacing them", "sometimes making them forced laborers instead of driving them out"),
        ("summary", "Achsah asks Caleb for springs to supplement her land", "Achsah asks Caleb for springs to water her land"),
    ],
    "Judges 2": [
        ("summary", "confronts Israel at Bochim over failure to honor the covenant and the resulting danger of rival worship", "rebukes Israel at Bochim for making peace with the Canaanites and leaving their altars standing"),
        ("summary", "the people turn again to corrupt practices", "the people go back to their sins"),
    ],
    "Judges 3": [
        ("summary", "The opening identifies nations left in the land and says Israel's interaction with them became a test of covenant loyalty; intermarriage and service to other gods follow", "The chapter opens with the nations the LORD left in the land to test Israel; the Israelites marry them and serve their gods"),
        ("summary", "Under the rule of Chushanrishathaim, Othniel receives", "After eight years under Chushanrishathaim, Othniel receives"),
        ("summary", "kills Eglon during a private audience", "kills Eglon in a private meeting"),
        ("summary", "using an oxgoad", "using an ox goad"),
        ("keyThemes.explanation", "A left-handed man and a farmer with an ox goad both save Israel.", "A left-handed man and a man with an ox goad both save Israel."),
    ],
    "Judges 5": [
        ("summary", "celebrating the LORD's intervention and honoring those who volunteered", "praising the LORD for the victory and honoring those who volunteered"),
        ("summary", "The song summons memories of divine appearances, praises participants from tribes such as Ephraim, Benjamin, Zebulun, and Naphtali, and rebukes groups that stayed away", "The song remembers how the LORD came to help his people, praises tribes such as Ephraim, Benjamin, Zebulun, and Naphtali, and scolds those that stayed away"),
        ("summary", "while the song poignantly imagines Sisera's mother awaiting his return", "while the song sadly pictures Sisera's mother waiting for him to come home"),
        ("summary", "It ends by wishing the LORD's enemies destroyed and his lovers strong", "It ends by asking that the LORD's enemies perish and that those who love him shine like the sun"),
        ("keyThemes.explanation", "\"The stars in their courses fought against Sisera,\"", "\"the stars in their courses fought against Sisera,\""),
    ],
    "Judges 6": [
        ("summary", "Gideon questions Israel's circumstances and receives a commission and sign", "Gideon asks why Israel suffers, and he is sent to save Israel and given a sign"),
        ("summary", "twice asks for reassurance using a wool fleece", "twice asks for proof with a wool fleece"),
    ],
    "Judges 8": [
        ("summary", "Gideon answers Ephraim's anger diplomatically, then pursues", "Gideon calms Ephraim's anger with a gentle answer, then chases"),
        ("summary", "When Israelites ask him to establish a hereditary rule", "When the Israelites ask him to rule over them, and his sons after him"),
        ("summary", "Gideon has many sons, including Abimelech by a concubine in Shechem", "Gideon has seventy sons, and also Abimelech by a concubine in Shechem"),
    ],
    "Judges 9": [
        ("summary", "Jotham delivers a parable of trees seeking a king and announces consequences for Shechem and Abimelech", "Jotham tells a parable of trees looking for a king and warns Shechem and Abimelech"),
        ("summary", "his armor-bearer kills him", "his armourbearer kills him"),
    ],
    "Judges 10": [
        ("summary", "Israel again serves multiple foreign gods, and the LORD allows Philistines and Ammonites to oppress them, especially in Gilead, and the Ammonites cross the Jordan to attack Judah, Benjamin, and Ephraim", "Israel again serves many foreign gods, and the LORD lets the Philistines and Ammonites oppress them; the Ammonites even cross the Jordan to attack Judah, Benjamin, and Ephraim"),
        ("whereWeAre", "but then the people serve more gods than ever, and Ammon", "but then the people serve the gods of many nations, and Ammon"),
    ],
    "Judges 11": [
        ("summary", "a capable warrior excluded by his half brothers", "a capable warrior driven out by his half brothers"),
    ],
    "Judges 12": [
        ("summary", "The pronunciation of “Shibboleth” becomes", "The pronunciation of \"Shibboleth\" becomes"),
    ],
    "Judges 13": [
        ("summary", "announces to a previously childless woman that she will bear", "tells a woman who has no children that she will bear"),
        ("summary", "the messenger returns, repeats instructions about what the mother should avoid, and refuses ordinary hospitality, instead directing an offering to the LORD", "the angel returns and repeats what the mother must avoid, and when Manoah offers food, the angel tells him to offer a burnt offering to the LORD instead"),
        ("summary", "The messenger ascends in the flame of the offering, and the couple recognizes the extraordinary encounter.", "The angel goes up in the flame of the offering, and Manoah and his wife realize they have seen the angel of the LORD."),
    ],
    "Judges 15": [
        ("summary", "he retaliates by releasing three hundred foxes or jackals with torches into Philistine crops", "he strikes back by sending three hundred foxes with torches tied to their tails into the Philistine crops"),
        ("summary", "three thousand Judahites bind Samson", "three thousand men of Judah bind Samson"),
    ],
    "Judges 16": [
        ("whereWeAre", "Samson has judged Israel twenty years since his victory in chapter 15. Now Delilah", "Chapter 15 ended with Samson's victory over the Philistines and his twenty years as judge. Now Delilah"),
    ],
    "Judges 17": [
        ("summary", "Micah wrongly assumes this guarantees the LORD's favor", "Micah thinks this will win the LORD's favor"),
    ],
    "Judges 20": [
        ("summary", "six hundred Benjaminite men escape", "six hundred Benjamite men escape"),
        ("summary", "attack Benjaminite towns", "attack Benjamite towns"),
    ],
    "Judges 21": [
        ("summary", "Benjaminite survivors", "Benjamite survivors"),
        ("summary", "remaining Benjaminite men", "remaining Benjamite men"),
        ("summary", "a scheme intended to evade the oath", "a plan to get around the oath"),
    ],
}


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "07_judges.json"
    data = load(path)
    for chapter, fixes in INSIGHT_FIXES.items():
        entry = data[chapter]
        for field, old, new in fixes:
            label = f"{chapter} {field}"
            if field == "keyThemes.explanation":
                matches = [t for t in entry["keyThemes"] if old in t["explanation"] or new in t["explanation"]]
                if len(matches) != 1:
                    raise SystemExit(f"{label}: {len(matches)} themes match")
                matches[0]["explanation"] = replace_once(matches[0]["explanation"], old, new, label)
            else:
                entry[field] = replace_once(entry[field], old, new, label)
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


CONTEXT_FIXES = {
    "Judges 1": [
        ("reference", "Judges 1:28", "Judges 1:28-30"),
    ],
    "Judges 3": [
        ("text", "Subject peoples brought tribute—goods and silver—to their overlord. Ehud uses the occasion", "Subject peoples brought tribute, a gift or payment, to their overlord. Ehud uses the occasion"),
    ],
    "Judges 12": [
        ("text", "Shibboleth means ‘ear of grain’ or ‘stream.’", "Shibboleth means ear of grain or stream."),
    ],
    "Judges 15": [
        ("text", "Samson names the place Ramath-lehi, ‘hill of the jawbone.’", "Samson names the place Ramathlehi, which means hill of the jawbone."),
    ],
    "Judges 21": [
        ("title", "Jabesh-gilead", "Jabeshgilead"),
        ("text", "Jabesh-gilead failed to send men", "Jabeshgilead failed to send men"),
    ],
}


def apply_chapter_context():
    path = ROOT / "chapter_context" / "08_judges_ruth.json"
    data = load(path)
    for chapter, fixes in CONTEXT_FIXES.items():
        for field, old, new in fixes:
            hits = [c for c in data[chapter]["culture"] if old in c[field] or new in c[field]]
            if len(hits) != 1:
                raise SystemExit(f"{chapter} {field}: {len(hits)} cultural notes match")
            hits[0][field] = replace_once(hits[0][field], old, new, f"{chapter} {field}")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_book_overview():
    path = ROOT / "book_overviews" / "02_early_history.json"
    data = load(path)
    book = data["Judges"]
    book["author"] = replace_once(book["author"], "show that it was written after kings ruled Israel", "suggest it was written after Israel had a king", "author")
    movement = book["movements"][1]
    movement["description"] = replace_once(
        movement["description"],
        "Later judges show both God's deliverance and the growing flaws of Israel's leaders.",
        "Gideon, Abimelech, Jephthah, and the smaller judges show both God's rescue and the growing flaws of Israel's leaders.",
        "movement",
    )
    for figure in book["keyFigures"]:
        if figure["name"] == "Othniel":
            figure["description"] = replace_once(figure["description"], "Caleb's nephew and the first judge", "Caleb's younger relative and the first judge", "Othniel")
        if figure["name"] == "Ehud":
            figure["description"] = replace_once(figure["description"], "A left-handed Benjaminite who assassinates Eglon", "A left-handed Benjamite who kills Eglon", "Ehud")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_book_guide():
    path = ROOT / "book_guides" / "02_early_history.json"
    data = load(path)
    tips = data["Judges"]["tips"]
    tips[1] = replace_once(tips[1], "and Samson breaks nearly every rule of his calling", "and Samson often ignores the vow that set him apart", "tip")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_FIXES = [
    ("Caleb's nephew Othniel captures a city", "Caleb's younger relative Othniel captures a city"),
    ("God raises up Othniel, Caleb's nephew.", "God raises up Othniel, Caleb's younger relative."),
    ("He brings Israel's tribute money to Eglon.", "He brings Israel's tribute to Eglon."),
    ("God throws the enemy army into confusion. A storm seems to have turned the plain to mud, and the river sweeps chariots away. Barak's men chase them,",
     "God throws the enemy army into confusion, and the river Kishon sweeps them away. Barak's men chase them,"),
    ("\"The stars in their courses fought against Sisera. The river of Kishon swept them away.\"",
     "\"They fought from heaven; the stars in their courses fought against Sisera.\" \"The river of Kishon swept them away.\""),
    ("his armor-bearer, \"Draw thy sword", "his armourbearer, \"Draw thy sword"),
    ("\"No razor shall come on his head,\"", "\"no razor shall come on his head,\""),
    ("even though a Nazarite was not supposed to touch a dead body.", "even though the law of the Nazarite forbade touching a dead body (Numbers 6:6)."),
    ("he grinds grain in the prison like an animal.", "he grinds grain in the prison."),
    ("Drunk and happy, they bring him out", "In high spirits, they bring him out"),
    ("The book reveals that this Levite was Jonathan, the son of Gershom, who was the son of Moses. Many ancient copies changed the name to Manasseh to hide the shame.",
     "The book names this Levite as Jonathan, \"the son of Gershom, the son of Manasseh.\" Gershom was a son of Moses, and Jewish tradition says the name Moses was changed to Manasseh so that Moses' name would not be tied to idol worship. A raised letter in the Hebrew text marks the change."),
    ("\"In those days, when there was no king in Israel,\" a Levite from the hill country of Ephraim takes a concubine, a secondary wife, from Bethlehem.",
     "The story begins \"in those days, when there was no king in Israel,\" with a Levite from the hill country of Ephraim, who takes a concubine, a secondary wife, from Bethlehem."),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "02_early_history.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("# Judges")
    end = text.index("\n# ", start + 5) + 1
    section = text[start:end]
    for old, new in STORY_FIXES:
        section = replace_once(section, old, new, f"story {old[:30]!r}")
    path.write_text(text[:start] + section + text[end:], encoding="utf-8")
    print(f"Updated {path.relative_to(ROOT)}")


if __name__ == "__main__":
    apply_chapter_insights()
    apply_chapter_context()
    apply_book_overview()
    apply_book_guide()
    apply_story_fixes()
