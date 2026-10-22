#!/usr/bin/env python3
"""Apply the completed editorial review for Ruth to source content only."""

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    insights_path = ROOT / "chapter_insights/08_ruth.json"
    moments_path = ROOT / "historical_moments/03_deuteronomy_ruth.json"
    context_path = ROOT / "chapter_context/08_judges_ruth.json"
    overview_path = ROOT / "book_overviews/02_early_history.json"
    insights = load(insights_path)
    moments = load(moments_path)
    context = load(context_path)
    overview = load(overview_path)

    summaries = {
        1: "During a famine, Elimelech takes Naomi and their sons from Bethlehem in Judah to Moab. Elimelech dies, and after about ten years both Mahlon and Chilion die, leaving Naomi and her daughters-in-law widowed (Ruth 1:1–5). Naomi hears that food has returned to Judah and starts home. Orpah returns to Moab, but Ruth stays with Naomi and joins herself to Naomi's people and God (Ruth 1:6–18). The two women reach Bethlehem at the beginning of barley harvest, where Naomi asks to be called Mara because of her grief (Ruth 1:19–22).",
        2: "Ruth goes out to glean grain for herself and Naomi and comes to the field of Boaz, a relative of Elimelech (Ruth 2:1–3). Boaz hears about Ruth's care for Naomi, protects her from harm, and tells his workers to let her glean generously (Ruth 2:4–16). Ruth brings barley and food home. Naomi learns that Boaz is a near kinsman and tells Ruth to stay in his fields through the harvests (Ruth 2:17–23).",
        3: "Naomi tells Ruth to ask Boaz for the security of a family redeemer. Ruth follows Naomi's plan and asks Boaz to spread his garment over her (Ruth 3:1–9). Boaz praises Ruth's kindness and agrees to act, but says a closer kinsman has the first right to redeem (Ruth 3:10–13). Boaz sends Ruth home with barley, and Naomi tells her to wait while Boaz settles the matter (Ruth 3:14–18).",
        4: "Boaz meets the closer kinsman and ten elders at Bethlehem's gate to settle Naomi's family property (Ruth 4:1–4). The closer kinsman gives up his right, and Boaz publicly takes Ruth as his wife and redeems the family property (Ruth 4:5–12). The LORD gives Ruth and Boaz a son, Obed, and the women of Bethlehem rejoice with Naomi (Ruth 4:13–17). Obed becomes the father of Jesse and the grandfather of David (Ruth 4:18–22).",
    }
    placement = {
        1: "Judges 21 ends with Israel doing what was right in its own eyes. Ruth 1 begins in those days and follows Naomi's loss in Moab and Ruth's choice to return with her to Bethlehem. Chapter 2 shows how the two widows find food there.",
        2: "Ruth returned with Naomi in chapter 1, and they arrived as the barley harvest began. Here Ruth gleans in Boaz's field, where he protects and provides for her. Chapter 3 turns Naomi's hope for safety into a direct request to Boaz.",
        3: "Boaz protected Ruth during the harvest in chapter 2, and Naomi learns that he is a near kinsman. Here Ruth asks Boaz to act as a family redeemer, but he must first speak with a closer relative. Chapter 4 brings that public decision at Bethlehem's gate.",
        4: "Ruth asked Boaz for help in chapter 3, and he promised to settle the matter. Here Boaz redeems the family property, marries Ruth, and Obed is born. The genealogy leads into 1 Samuel, where David's family story continues.",
    }
    moments = {
        1: "In the days when the judges ruled, a famine sends Elimelech's family from Bethlehem in Judah to Moab, east of the Dead Sea (Ruth 1:1–2).",
        2: "During the barley and wheat harvests near Bethlehem in Judah, Ruth gleans in Boaz's field while she and Naomi live in the town (Ruth 2:2–3, 23).",
        3: "At the end of the barley harvest in Bethlehem, Boaz winnows grain and sleeps beside it on the threshing floor (Ruth 3:2–7).",
        4: "In Bethlehem, Boaz settles the family matter before ten elders at the city gate, and the book closes with a genealogy from Pharez to David (Ruth 4:1–2, 18–22).",
    }
    audiences = {
        1: "The first Israelites who heard Ruth knew Moab lay east of the Dead Sea and that widows without sons were vulnerable. They heard Ruth's choice to join Naomi as a striking act of loyal love.",
        2: "The first Israelites who heard Ruth knew gleaning laws that provided food for the poor. They heard Boaz use his standing and field to protect a foreign widow.",
        3: "The first Israelites who heard Ruth knew family members could redeem property and protect a household. They heard Ruth and Boaz seek that help with care and public responsibility.",
        4: "The first Israelites who heard Ruth knew city gates were places for witnesses and legal decisions. They also knew David's family line and heard how Ruth became his great-grandmother.",
    }
    themes = {
        1: [
            ("Faithful loyalty amid uncertainty", "Ruth stays with Naomi when neither woman can see how their future will work out. Her promise joins her life to Naomi's people and God."),
            ("Grief can be spoken openly", "Naomi does not hide her sorrow when she returns to Bethlehem. She names her loss before her neighbors (Ruth 1:19–21)."),
            ("Belonging and allegiance", "Ruth leaves Moab and claims Naomi's people and God as her own. Her choice changes the course of the family (Ruth 1:16–18)."),
            ("A beginning after loss", "The chapter closes at the barley harvest. The small detail signals that food and hope are beginning to return (Ruth 1:22)."),
        ],
        2: [
            ("Care for people in need", "Ruth gathers what the harvesters leave behind so she and Naomi can eat. Boaz makes sure she has safe and generous access to the field."),
            ("Diligence and provision", "Ruth works from morning until evening and brings the barley home to Naomi. Her steady labor becomes part of their daily provision."),
            ("Kindness toward the outsider", "Boaz protects Ruth even though she is from Moab. He sees her care for Naomi and welcomes her in his field."),
            ("Recognition of steadfast kindness", "Boaz notices Ruth's kindness to Naomi, and Naomi sees kindness in Boaz. The chapter shows care passing from one person to another."),
        ],
        3: [
            ("Seeking stable care and belonging", "Naomi wants Ruth to have a secure home. Ruth's request asks Boaz to use his family role to protect her."),
            ("Courage with vulnerability", "Ruth makes a bold request at the threshing floor, placing herself in a vulnerable position. Boaz responds with honor rather than taking advantage of her."),
            ("Integrity and responsible restraint", "Boaz wants to help, but he will not ignore the closer kinsman's right. He promises to handle the matter in the proper order."),
            ("Waiting for a just resolution", "Ruth returns to Naomi with barley, but the future is still unsettled. Naomi tells her to wait while Boaz acts (Ruth 3:17–18)."),
        ],
        4: [
            ("Public accountability in family obligations", "Boaz settles the matter at the gate before ten elders and other witnesses. The public setting makes the agreement clear and binding."),
            ("Redemption and care for a vulnerable household", "Boaz redeems the family property and takes Ruth as his wife. His action protects the family line after Naomi's losses."),
            ("Community blessing and welcome", "The elders and people bless Ruth and Boaz. The women of Bethlehem also celebrate with Naomi when Obed is born."),
            ("Life and renewed hope after bereavement", "Naomi once called herself empty, but now she receives care through Ruth and Obed. The birth brings new life into a grieving household."),
        ],
    }

    for chapter in range(1, 5):
        key = f"Ruth {chapter}"
        insights[key]["summary"] = summaries[chapter]
        insights[key]["whereWeAre"] = placement[chapter]
        insights[key]["keyThemes"] = [
            {"theme": name, "explanation": explanation, "references": old["references"]}
            for (name, explanation), old in zip(themes[chapter], insights[key]["keyThemes"])
        ]
        moments_path_key = key
        # Keep the shared file's other book entries untouched.
        globals_moments[moments_path_key] = moments[chapter]
        context[key]["audience"] = audiences[chapter]

    # Chapters 3 and 4 now have four themes; remove the extra legacy theme records.
    insights["Ruth 3"]["keyThemes"] = insights["Ruth 3"]["keyThemes"][:4]
    insights["Ruth 4"]["keyThemes"] = insights["Ruth 4"]["keyThemes"][:4]
    insights["Ruth 4"]["keyFigures"] = [
        {"name": "Boaz", "role": "Publicly settles the redemption claim, marries Ruth, and becomes Obed's father."},
        {"name": "Ruth", "role": "Marries Boaz and gives birth to Obed."},
        {"name": "Naomi", "role": "Receives new care and joy through Obed's birth."},
        {"name": "The closer kinsman", "role": "Gives up his prior right and confirms the transfer with his sandal."},
        {"name": "The ten elders", "role": "Witness the agreement at the city gate and bless the household."},
        {"name": "The women of Bethlehem", "role": "Praise the LORD with Naomi and name the child Obed."},
    ]

    book = overview["Ruth"]
    book["author"] = "Samuel is the traditional author. Ruth does not name its writer, but Jewish tradition connects the book with Samuel."
    book["audience"] = "Israel, especially hearers who knew David's family line and the faithfulness God calls for among his people."
    book["purpose"] = "To show the LORD's care through Ruth's loyalty, Boaz's faithfulness, and the restoration of Naomi's family line."
    book["theme"] = "The LORD works through ordinary faithfulness and kindness to bring care, redemption, and hope."
    book["summary"] = "Ruth follows Naomi from Moab to Bethlehem after both women lose their husbands. Boaz protects Ruth, redeems the family property, and marries her; their son Obed becomes David's grandfather."
    book["keyVerse"] = "Ruth 1:16"

    story_path = ROOT / "book_content/02_early_history.md"
    story = story_path.read_text(encoding="utf-8")
    start = story.index("# Ruth")
    end = story.index("# 1 Samuel", start)
    ruth_story = story[start:end].replace("“", '"').replace("”", '"').replace("‘", "'").replace("’", "'")
    story_path.write_text(story[:start] + ruth_story + story[end:], encoding="utf-8")

    save(insights_path, insights)
    save(context_path, context)
    save(overview_path, overview)
    save(ROOT / "historical_moments/03_deuteronomy_ruth.json", globals_moments)


if __name__ == "__main__":
    # Preserve the name that makes the chapter loop easy to read above.
    globals_moments = load(ROOT / "historical_moments/03_deuteronomy_ruth.json")
    main()
