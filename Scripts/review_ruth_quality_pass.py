#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Full quality pass for Ruth: plain summaries with outline citations, exact KJV quotes, distinct audience text."""

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


def people(*pairs):
    return [{"name": name, "role": role} for name, role in pairs]


def themes(*items):
    return [{"theme": t, "explanation": e, "references": r} for t, e, r in items]


INSIGHTS = {
    "Ruth 1": {
        "summary": "In the days when the judges ruled, a famine sends Elimelech, his wife Naomi, and their sons Mahlon and Chilion from Bethlehem in Judah to Moab (Ruth 1:1–2). Elimelech dies, the sons marry the Moabite women Orpah and Ruth, and after about ten years both sons die, leaving three widows (Ruth 1:3–5). Naomi hears that the LORD has given his people bread, so she starts for Judah and urges her daughters-in-law to go home to their mothers (Ruth 1:6–13). Orpah kisses Naomi and goes back, but Ruth clings to her and promises, \"thy people shall be my people, and thy God my God\" (Ruth 1:14–18). The women reach Bethlehem at the beginning of barley harvest, and Naomi asks to be called Mara, which means bitter, because the Almighty has dealt very bitterly with her (Ruth 1:19–22).",
        "whereWeAre": "Judges 21 ended with Israel doing what was right in its own eyes, and Ruth begins \"in the days when the judges ruled\" (Ruth 1:1). This chapter follows Naomi's loss in Moab and Ruth's choice to go home with her to Bethlehem. Chapter 2 shows how the two widows find food there.",
        "keyFigures": people(
            ("Naomi", "Loses her husband and both sons in Moab, then returns to Bethlehem and says the Almighty has dealt very bitterly with her."),
            ("Ruth", "A Moabitess who clings to Naomi and chooses Naomi's people and Naomi's God."),
            ("Orpah", "Kisses Naomi and goes back to her own people."),
            ("Elimelech, Mahlon, and Chilion", "A husband and two sons who move to Moab during a famine and die there."),
            ("The women of Bethlehem", "Ask, \"Is this Naomi?\" when she comes home."),
            ("The LORD", "Gives his people bread again, though Naomi feels his hand has gone out against her."),
        ),
        "keyThemes": themes(
            ("Loyal love", "Ruth stays with Naomi even though Naomi urges her to go home: \"whither thou goest, I will go.\"", ["Ruth 1:14-18"]),
            ("Honest grief", "Naomi does not hide her pain. She asks to be called Mara, \"for the Almighty hath dealt very bitterly with me.\"", ["Ruth 1:19-21"]),
            ("A new home and faith", "Ruth leaves Moab and makes Naomi's people and Naomi's God her own.", ["Ruth 1:16-17"]),
            ("Hope after loss", "The chapter ends \"in the beginning of barley harvest,\" a small sign that bread and hope are coming back.", ["Ruth 1:22"]),
        ),
    },
    "Ruth 2": {
        "summary": "Naomi has a relative of her husband's named Boaz, a wealthy man, and Ruth goes out to glean after the reapers and comes to a part of the field that belongs to Boaz (Ruth 2:1–3). Boaz greets his reapers, learns who Ruth is from his servant, and tells her to stay close to his maidens, who have been told not to touch her, and to drink from the vessels the young men have filled (Ruth 2:4–9). Ruth asks why she has found grace in his eyes when she is a stranger, and Boaz answers that he has heard all she has done for her mother-in-law and asks the LORD God of Israel, under whose wings she has come to trust, to reward her (Ruth 2:10–13). At mealtime he gives her parched corn, and he tells his young men to let her glean among the sheaves and to leave handfuls on purpose for her (Ruth 2:14–16). Ruth beats out about an ephah of barley and brings it home with the food she saved, and Naomi blesses the man and says he is \"one of our next kinsmen\" (Ruth 2:17–20). Ruth stays with the maidens of Boaz to the end of the barley and wheat harvests (Ruth 2:21–23).",
        "whereWeAre": "Chapter 1 ended with Naomi and Ruth arriving in Bethlehem at the start of barley harvest. Now Ruth gleans in the field of Boaz, who protects her and makes sure she has plenty. Chapter 3 turns Naomi's hope for Ruth into a bold plan at the threshing floor.",
        "keyFigures": people(
            ("Ruth", "Gleans from morning until evening to feed herself and Naomi."),
            ("Boaz", "A wealthy relative of Elimelech who protects Ruth and tells his men to leave extra grain for her."),
            ("Naomi", "Blesses Boaz and says he is \"one of our next kinsmen.\""),
            ("The servant over the reapers", "Tells Boaz that Ruth is \"the Moabitish damsel\" who came back with Naomi."),
            ("The reapers and young men", "Answer Boaz, \"The LORD bless thee,\" and are told not to touch or rebuke Ruth."),
        ),
        "keyThemes": themes(
            ("Care for the poor", "Ruth gleans after the reapers, as the poor were allowed to do, and Boaz makes sure she is safe and has plenty.", ["Ruth 2:2-3", "Ruth 2:8-9", "Ruth 2:15-16"]),
            ("Hard work", "Ruth works \"from the morning until now\" with only a short rest, and she brings home about an ephah of barley.", ["Ruth 2:7", "Ruth 2:17-18"]),
            ("Kindness to a stranger", "Boaz welcomes Ruth even though she is \"a stranger\" from Moab.", ["Ruth 2:8-13"]),
            ("God's kindness through people", "Naomi says the LORD \"hath not left off his kindness to the living and to the dead\" through Boaz.", ["Ruth 2:19-20"]),
        ),
    },
    "Ruth 3": {
        "summary": "Naomi tells Ruth to wash, anoint herself, put on her clothes, and go down to the threshing floor where Boaz is winnowing barley; after he has eaten and drunk, Ruth is to uncover his feet and lie down (Ruth 3:1–5). Ruth does what Naomi says, and at midnight Boaz wakes to find a woman at his feet, and she asks him to spread his skirt over her, because he is a near kinsman (Ruth 3:6–9). Boaz blesses her, says all the city knows she is a virtuous woman, and promises to do the part of a kinsman, but he says there is a kinsman nearer than he (Ruth 3:10–13). Ruth lies at his feet until morning and leaves before anyone can recognize her, and Boaz sends her home with six measures of barley (Ruth 3:14–17). Naomi tells her to sit still until she sees how the matter will fall, because Boaz will not rest until it is settled (Ruth 3:18).",
        "whereWeAre": "In chapter 2, Boaz protected Ruth through the harvest, and Naomi learned he is a near kinsman. Here Ruth asks him to act as a family redeemer, but he says a closer relative must be asked first. Chapter 4 brings the matter to the city gate.",
        "keyFigures": people(
            ("Ruth", "Follows Naomi's plan, goes to the threshing floor, and asks Boaz to spread his skirt over her."),
            ("Naomi", "Plans for Ruth to find rest and tells her to sit still until the matter is settled."),
            ("Boaz", "Calls Ruth a virtuous woman and promises to act, but says a nearer kinsman comes first."),
        ),
        "keyThemes": themes(
            ("A home for Ruth", "Naomi wants Ruth to have rest, \"that it may be well with thee,\" and sends her to Boaz.", ["Ruth 3:1-5"]),
            ("Courage and care", "Ruth goes to the threshing floor at night and asks for Boaz's protection. He answers with kindness and calls her \"a virtuous woman.\"", ["Ruth 3:6-11"]),
            ("Doing it the right way", "Boaz says \"there is a kinsman nearer than I,\" so he will not skip the nearer man, but he promises to see it done.", ["Ruth 3:12-13"]),
            ("Waiting", "Ruth goes home with six measures of barley, and Naomi tells her to sit still until the matter is settled.", ["Ruth 3:14-18"]),
        ),
    },
    "Ruth 4": {
        "summary": "Boaz goes up to the gate, sits down, calls the nearer kinsman over, and gathers ten elders of the city as witnesses (Ruth 4:1–2). He tells the kinsman that Naomi is selling Elimelech's land and that he has the first right to redeem it, and the man says, \"I will redeem it\" (Ruth 4:3–4). Boaz adds that whoever buys the field must also buy Ruth the Moabitess, \"to raise up the name of the dead,\" so the kinsman says he cannot redeem it, \"lest I mar mine own inheritance,\" and gives Boaz his shoe to confirm it (Ruth 4:5–8). Boaz tells the elders and all the people that they are witnesses that he has bought all that was Elimelech's, Chilion's, and Mahlon's, and that he has bought Ruth to be his wife, and the people bless him (Ruth 4:9–12). Boaz takes Ruth, the LORD gives her conception, and she bears a son, and the women tell Naomi he will restore her life and care for her in her old age (Ruth 4:13–15). Naomi becomes his nurse, and the neighbors name him Obed, the father of Jesse, the father of David (Ruth 4:16–17). The book ends with the generations of Pharez down to David (Ruth 4:18–22).",
        "whereWeAre": "In chapter 3, Ruth asked Boaz for help, and he promised to settle the matter. Here Boaz redeems the family land, marries Ruth, and Obed is born. The genealogy at the end leads to David, whose story begins in 1 Samuel.",
        "keyFigures": people(
            ("Boaz", "Settles the matter at the gate, buys Elimelech's land, and takes Ruth as his wife."),
            ("Ruth", "Marries Boaz and bears Obed, who becomes David's grandfather."),
            ("Naomi", "Takes the child, lays him in her bosom, and becomes his nurse."),
            ("The nearer kinsman", "Says he cannot redeem the land \"lest I mar mine own inheritance\" and gives Boaz his shoe."),
            ("The elders and the people at the gate", "Stand as witnesses and bless Boaz."),
            ("The women of Bethlehem", "Praise the LORD with Naomi and name the child Obed."),
        ),
        "keyThemes": themes(
            ("Done in public", "Boaz settles the matter at the gate before ten elders, so everyone can see it done fairly.", ["Ruth 4:1-12"]),
            ("A redeemer", "Boaz buys Elimelech's land and takes Ruth as his wife, \"to raise up the name of the dead upon his inheritance.\"", ["Ruth 4:5-10"]),
            ("A town that blesses", "The people at the gate bless Boaz, and the women of Bethlehem bless the LORD with Naomi.", ["Ruth 4:11-15"]),
            ("From empty to full", "Naomi, who said the LORD brought her home \"empty,\" now holds Obed, who will restore her life and care for her in old age.", ["Ruth 4:13-17"]),
        ),
    },
}


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "08_ruth.json"
    data = load(path)
    for chapter, fields in INSIGHTS.items():
        data[chapter].update(fields)
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def edit_note(notes, old_title, new_title, edits, label):
    note = [n for n in notes if n["title"] in (old_title, new_title)]
    if len(note) != 1:
        raise SystemExit(f"{label}: {len(note)} notes match {old_title!r}")
    note[0]["title"] = new_title
    for old, new in edits:
        note[0]["text"] = replace_once(note[0]["text"], old, new, label)


def apply_chapter_context():
    path = ROOT / "chapter_context" / "08_judges_ruth.json"
    data = load(path)
    one = data["Ruth 1"]
    one["audience"] = replace_once(
        one["audience"],
        "knew Moab lay east of the Dead Sea and that widows without sons were vulnerable.",
        "knew Moab as a neighbor that had often been an enemy, and that widows without sons were vulnerable.",
        "Ruth 1 audience",
    )
    edit_note(one["culture"], "Bethlehem", "Bethlehem", [("‘house of bread,’", "house of bread,")], "Ruth 1 Bethlehem")
    edit_note(data["Ruth 2"]["culture"], "An ephah of barley", "An ephah of barley",
              [("roughly two-thirds of a bushel (about 22 liters)", "more than half a bushel (about 22 liters)")], "Ruth 2 ephah")
    edit_note(data["Ruth 4"]["culture"], "The sandal", "The shoe",
              [("a man gave his sandal to confirm", "a man gave his shoe to confirm")], "Ruth 4 shoe")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_book_overview():
    path = ROOT / "book_overviews" / "02_early_history.json"
    data = load(path)
    book = data["Ruth"]
    book["author"] = replace_once(
        book["author"],
        "Samuel is the traditional author. Ruth does not name its writer, but Jewish tradition connects the book with Samuel.",
        "Jewish tradition credits Samuel as the author, though the book does not name its writer. Because it ends with David's family line, it may have been written down in David's time or later.",
        "author",
    )
    book["audience"] = replace_once(
        book["audience"],
        "Israel, especially hearers who knew David's family line and the faithfulness God calls for among his people.",
        "Israelites in David's time or later, who knew the stories of the judges and David's family line.",
        "audience",
    )
    for figure in book["keyFigures"]:
        if figure["name"] == "Boaz":
            figure["description"] = replace_once(figure["description"], "A worthy relative of Naomi's family who acts", "A wealthy relative of Naomi's husband who acts", "Boaz")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_FIXES = [
    ("goes home. \"But Ruth clave unto her.\"", "goes home, \"but Ruth clave unto her.\""),
    ("gather the leftover grain. \"And her hap was to light on a part of the field belonging unto Boaz.\" It looks like chance",
     "gather the leftover grain (Leviticus 19:9–10). Ruth goes out, and \"her hap was to light on a part of the field belonging unto Boaz.\" It looks like chance"),
    ("so that her first son can carry on the family name of her dead husband and inherit the land.", "so that the dead man's name will live on with his land."),
    ("by taking off his sandal and handing it to the other person. So the relative takes off his sandal and gives it to Boaz.",
     "by taking off his shoe and handing it to the other person. So the relative takes off his shoe and gives it to Boaz."),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "02_early_history.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("\n# Ruth") + 1
    end = text.find("\n# ", start + 5)
    end = len(text) if end < 0 else end + 1
    section = text[start:end]
    for old, new in STORY_FIXES:
        section = replace_once(section, old, new, f"story {old[:30]!r}")
    path.write_text(text[:start] + section + text[end:], encoding="utf-8")
    print(f"Updated {path.relative_to(ROOT)}")


if __name__ == "__main__":
    apply_chapter_insights()
    apply_chapter_context()
    apply_book_overview()
    apply_story_fixes()
