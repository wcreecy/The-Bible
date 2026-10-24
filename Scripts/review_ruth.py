#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Second-pass audit and rewrite for Ruth."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


SUMMARY = {
    1: "In the days when the judges ruled, a famine sends Elimelech, his wife Naomi, and their two sons, Mahlon and Chilion, from Bethlehem in Judah to the country of Moab (Ruth 1:1–2). Elimelech dies, the sons marry Orpah and Ruth, and after about ten years both sons die, leaving Naomi and her two daughters-in-law widows (Ruth 1:3–5). Naomi hears that the LORD has given his people bread and starts for Judah, and she urges Orpah and Ruth to go back to their mothers' houses (Ruth 1:6–13). Orpah kisses Naomi and goes home, but Ruth clings to her and says Naomi's people will be her people and Naomi's God her God (Ruth 1:14–18). The two women reach Bethlehem at the beginning of barley harvest, and Naomi asks to be called Mara, because the Almighty has dealt very bitterly with her (Ruth 1:19–22).",
    2: "Naomi has a kinsman of her husband's named Boaz, a mighty man of wealth, and Ruth goes to glean ears of corn after the reapers and happens to come to a part of the field that belongs to Boaz (Ruth 2:1–3). Boaz greets his reapers, learns from his servant that she is the Moabitish damsel who came back with Naomi, and tells her to stay close to his maidens, whom he has told not to touch her, and to drink from the water the young men have drawn (Ruth 2:4–9). Ruth asks why she has found grace in his eyes, since she is a stranger, and Boaz answers that he has heard all she has done for her mother in law and asks the LORD God of Israel, under whose wings she has come to trust, to reward her (Ruth 2:10–13). He invites her to eat with the reapers, gives her parched corn, and tells his young men to let her glean among the sheaves and to let fall handfuls of purpose for her (Ruth 2:14–16). She beats out about an ephah of barley and brings it home with the food she saved, and Naomi blesses the man and says he is near of kin, one of their next kinsmen (Ruth 2:17–20). Ruth keeps to the maidens of Boaz to the end of the barley and wheat harvests (Ruth 2:21–23).",
    3: "Naomi tells Ruth to wash, anoint herself, put on her best clothes, and go down to the threshingfloor where Boaz is winnowing barley, and to lie down at his feet after he has eaten and drunk (Ruth 3:1–5). Ruth does what her mother in law says, and at midnight Boaz wakes to find a woman at his feet, and she asks him to spread his skirt over her, because he is a near kinsman (Ruth 3:6–9). Boaz blesses her, says all the city knows she is a virtuous woman, and promises to do the part of a kinsman, but he says there is a kinsman nearer than he (Ruth 3:10–13). She lies at his feet until morning, rises before one could know another, and he sends her home with six measures of barley (Ruth 3:14–17). Naomi tells her to sit still until she knows how the matter will fall, for the man will not rest until he has finished the thing this day (Ruth 3:18).",
    4: "Boaz goes up to the gate, calls the nearer kinsman to sit down, gathers ten elders of the city, and tells the kinsman that Naomi is selling the land of Elimelech and he has the first right to redeem it (Ruth 4:1–4). When Boaz adds that whoever buys the field must also buy Ruth the Moabitess, to raise up the name of the dead, the kinsman says he cannot redeem it lest he mar his own inheritance, and he gives Boaz his shoe, which was how a matter was confirmed in Israel (Ruth 4:5–8). Boaz tells the elders and all the people that they are witnesses that he has bought all that was Elimelech's, Chilion's, and Mahlon's, and that he has bought Ruth to be his wife, and the people bless him (Ruth 4:9–12). Boaz takes Ruth, the LORD gives her conception, and she bears a son, and the women tell Naomi that the child will be a restorer of her life and a nourisher of her old age (Ruth 4:13–15). Naomi takes the child and becomes his nurse, and the neighbours call him Obed, the father of Jesse, the father of David (Ruth 4:16–17). The book ends with the generations of Pharez down to David (Ruth 4:18–22).",
}

FIGURES = {
    1: [
        ("Naomi", "Loses her husband and both sons in Moab, then goes home to Bethlehem and says the Almighty has dealt very bitterly with her (1:3-5,19-21)."),
        ("Ruth", "A Moabite widow who clings to Naomi and chooses Naomi's people and Naomi's God (1:14-17)."),
        ("Orpah", "Kisses Naomi and goes back to her people and her gods (1:14-15)."),
        ("Elimelech, Mahlon, and Chilion", "The husband and two sons who die in Moab (1:3,5)."),
        ("The women of Bethlehem", "Ask Is this Naomi when she returns (1:19)."),
        ("The LORD", "Visited his people in giving them bread, though Naomi says his hand is gone out against her (1:6,13,21)."),
    ],
    2: [
        ("Ruth", "Gleans after the reapers from morning until evening to feed herself and Naomi (2:2-3,7,17)."),
        ("Boaz", "A mighty man of wealth and a kinsman of Elimelech who protects Ruth and tells his men to leave extra grain for her (2:1,8-9,15-16)."),
        ("Naomi", "Blesses Boaz and says he is one of their next kinsmen (2:19-20)."),
        ("The servant over the reapers", "Tells Boaz that Ruth is the Moabitish damsel who came back with Naomi (2:5-7)."),
        ("The reapers and young men", "Greet Boaz with The LORD bless thee and are told not to touch or rebuke Ruth (2:4,9,15-16)."),
    ],
    3: [
        ("Ruth", "Does what Naomi says, goes to the threshingfloor, and asks Boaz to spread his skirt over her (3:5-9)."),
        ("Naomi", "Plans for Ruth to find rest and tells her to sit still until the matter is settled (3:1-4,18)."),
        ("Boaz", "Calls Ruth a virtuous woman, promises to act, but says a nearer kinsman has the first right (3:10-13)."),
        ("The nearer kinsman", "Not named and does not appear in this chapter, but Boaz must first offer him the right to redeem (3:12-13)."),
    ],
    4: [
        ("Boaz", "Settles the matter at the gate, buys Elimelech's land, and takes Ruth as his wife (4:1-10)."),
        ("Ruth", "Marries Boaz and bears Obed, who will be the grandfather of David (4:13,17)."),
        ("Naomi", "Takes the child, becomes his nurse, and is told he will be a restorer of her life (4:14-16)."),
        ("The nearer kinsman", "Says he cannot redeem lest he mar his own inheritance and gives Boaz his shoe (4:6-8)."),
        ("The elders and the people at the gate", "Are witnesses and bless Boaz and his house (4:2,9-12)."),
        ("The women of Bethlehem", "Bless the LORD with Naomi and name the child Obed (4:14-17)."),
    ],
}

THEMES = {
    1: [
        "Ruth stays with Naomi when she has every reason to go home, and says whither thou goest, I will go (1:14-18).",
        "Naomi does not hide her grief; she tells the town to call her Mara, for the Almighty hath dealt very bitterly with her (1:19-21).",
        "Ruth makes Naomi's people her people and Naomi's God her God, and leaves Moab behind (1:16-17).",
        "The chapter ends at the beginning of barley harvest, a small sign that bread and hope are coming back (1:22).",
    ],
    2: [
        "Ruth gleans after the reapers, as the poor were allowed to do, and Boaz makes sure she is safe and has plenty (2:2-3,8-9,15-16).",
        "She works from morning until now with only a little rest, and brings home about an ephah of barley (2:7,17-18).",
        "Boaz shows kindness to Ruth even though she is a stranger from Moab (2:8-13).",
        "Boaz has heard how Ruth treated her mother in law, and Naomi says the LORD hath not left off his kindness to the living and to the dead (2:11-12,20).",
    ],
    3: [
        "Naomi wants Ruth to have rest, a home where it may be well with her, and sends her to Boaz (3:1-5).",
        "Ruth goes to the threshingfloor at night and asks Boaz to spread his skirt over her, and he answers with honour and does not take advantage (3:6-11).",
        "Boaz says there is a kinsman nearer than he and will not skip him, but promises to see it done (3:12-13).",
        "Ruth goes home with six measures of barley, and Naomi tells her to sit still until the matter is settled (3:14-18).",
    ],
    4: [
        "Boaz settles the matter at the gate before ten elders, so everyone can see it done fairly (4:1-12).",
        "Boaz buys Elimelech's land and takes Ruth as his wife, to raise up the name of the dead upon his inheritance (4:5-10).",
        "The people at the gate bless Boaz, and the women of Bethlehem bless the LORD with Naomi (4:11-15).",
        "Naomi, who said she came home empty, now holds Obed, a restorer of life and a nourisher of her old age (4:13-17).",
    ],
}

WWA_FIXES = {}


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "08_ruth.json"
    data = load(path)
    for n in range(1, 5):
        entry = data[f"Ruth {n}"]
        entry["summary"] = SUMMARY[n]
        entry["keyFigures"] = [{"name": a, "role": b} for a, b in FIGURES[n]]
        if len(entry["keyThemes"]) != len(THEMES[n]):
            raise SystemExit(f"Ruth {n}: theme count mismatch")
        for theme, explanation in zip(entry["keyThemes"], THEMES[n]):
            theme["explanation"] = explanation
        if n == 3:
            entry["keyThemes"][3]["references"] = ["Ruth 3:14-18"]
        if len(entry["whereWeAre"]) > 600 or len(entry["keyFigures"]) > 6:
            raise SystemExit(f"Ruth {n}: WWA or figure count")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_FIXES = [
    ("The book ends with David's genealogy (Ruth 4:17–22), so it was written down no earlier than David's time; scholars propose dates from the early monarchy to after the exile.",
     "Jewish tradition credits Samuel, though the book does not name its writer. It ends with David's family line (Ruth 4:17–22), so it was written down in David's time or later."),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "02_early_history.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("\n# Ruth") + 1
    end = text.index("\n# ", start + 5) + 1
    section = text[start:end]
    for old, new in STORY_FIXES:
        if section.count(old) == 0 and section.count(new) >= 1:
            continue
        if section.count(old) != 1:
            raise SystemExit(f"story: {section.count(old)} matches")
        section = section.replace(old, new)
    path.write_text(text[:start] + section + text[end:], encoding="utf-8")
    print(f"Updated {path.relative_to(ROOT)}")


if __name__ == "__main__":
    apply_chapter_insights()
    apply_story_fixes()
