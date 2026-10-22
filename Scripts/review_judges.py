#!/usr/bin/env python3
"""Apply the completed editorial review for Judges to source content only."""

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    insights_path = ROOT / "chapter_insights/07_judges.json"
    moments_path = ROOT / "historical_moments/03_deuteronomy_ruth.json"
    context_path = ROOT / "chapter_context/08_judges_ruth.json"
    overview_path = ROOT / "book_overviews/02_early_history.json"

    insights = load(insights_path)
    moments = load(moments_path)
    context = load(context_path)
    overview = load(overview_path)

    historical_moments = {
        1: "After Joshua's death, in the tribal lands of Canaan, Judah and the other tribes continue the unfinished fighting for the land (Judges 1:1–36).",
        2: "After Joshua and the elders who outlived him die, at Bochim and throughout the land of Israel, a new generation turns to other gods (Judges 2:1–13).",
        3: "In the early judges period, Israel faces Mesopotamian, Moabite, and Philistine oppression in the land of Israel and around Jericho (Judges 3:7–31).",
        4: "During Jabin's oppression in northern Canaan, Deborah judges between Ramah and Bethel, while the battle is fought near Mount Tabor and the river Kishon (Judges 4:3–16).",
        5: "Just after Sisera's defeat, Deborah and Barak sing in Israel about the battle by the river Kishon and the waters of Megiddo (Judges 5:1, 19–21).",
        6: "During seven years of Midianite raids, Gideon hides grain at Ophrah in Manasseh while raiders strip Israel's harvests (Judges 6:1–11).",
        7: "At the well of Harod in the Jezreel valley, Gideon's three hundred men face the Midianite camp below the hill of Moreh (Judges 7:1–8).",
        8: "After the night victory over Midian, Gideon pursues Zebah and Zalmunna east of the Jordan through Succoth and Penuel, then returns to Ophrah (Judges 8:4–28).",
        9: "For three years in the judges period, Abimelech rules from Shechem in the hill country of Ephraim before he dies at Thebez (Judges 9:6, 22, 50–54).",
        10: "After Tola and Jair judge Israel, Ammon oppresses Gilead east of the Jordan for eighteen years while Philistines trouble Israel from the west (Judges 10:1–9).",
        11: "During Ammon's attack on Gilead east of the Jordan, Jephthah leads Israel from Mizpeh of Gilead against Ammon (Judges 11:4–11, 29–33).",
        12: "After Jephthah defeats Ammon, Gilead and Ephraim fight at the Jordan fords, where fleeing Ephraimites are tested with the word Shibboleth (Judges 12:1–6).",
        13: "During forty years of Philistine rule, the angel of the LORD appears near Zorah in the territory of Dan and announces Samson's birth (Judges 13:1–5).",
        14: "While Philistines rule Israel, Samson travels from Zorah to Timnath, a Philistine town near the border of Dan (Judges 14:1–4).",
        15: "During Philistine rule, Samson's conflict reaches Philistine fields and then Lehi in Judah, where he defeats a thousand men (Judges 15:4–17).",
        16: "During the Philistine period, Samson is captured in the valley of Sorek and dies in Dagon's temple at Gaza (Judges 16:4–5, 21–30).",
        17: "In the later stories of Judges, Micah lives in mount Ephraim and a Levite arrives from Bethlehemjudah to serve in his household (Judges 17:1, 7–13).",
        18: "In the same period, Danites travel from Zorah and Eshtaol through mount Ephraim to Laish in the north, where they establish the city of Dan (Judges 18:2, 13, 27–29).",
        19: "In the days when Israel has no king, a Levite travels from Bethlehemjudah to Gibeah in Benjamin, north of Jebus, later Jerusalem (Judges 19:1, 10–15).",
        20: "After the crime at Gibeah, the tribes gather at Mizpeh and fight Benjamin at Gibeah; Phinehas serves before the ark at Bethel (Judges 20:1, 18, 26–28).",
        21: "Right after the war with Benjamin, Israel meets at Mizpeh and Shiloh to keep Benjamin from disappearing as a tribe (Judges 21:1–4, 19).",
    }
    original_audiences = {
        1: "The first Israelites who heard Judges knew the tribes still lived beside Canaanite peoples. This chapter explained why that unfinished conquest mattered to their life in the land.",
        2: "The first Israelites who heard Judges knew the recurring trouble of serving other gods. This chapter explained the pattern of rebellion, oppression, rescue, and relapse behind those troubles.",
        3: "The first Israelites who heard Judges knew Israel had faced stronger neighbors. They heard how the LORD raised deliverers from Judah, Benjamin, and elsewhere when Israel cried out.",
        4: "The first Israelites who heard Judges knew Hazor and the northern plain. They heard that the LORD defeated a chariot army through Deborah, Barak, and Jael.",
        5: "The first Israelites who heard Judges knew which tribes answered the call to fight and which did not. The song taught them to remember the LORD's victory and the cost of refusing to help.",
        6: "The first Israelites who heard Judges knew the fear of raids and lost harvests. They heard why Israel's disobedience mattered and how the LORD called Gideon while he was afraid.",
        7: "The first Israelites who heard Judges knew that a small force could not defeat a great camp by strength alone. They heard that the LORD gave the victory so Israel could not claim it for itself.",
        8: "The first Israelites who heard Judges knew Gideon as a deliverer. They also knew the warning that his ephod became a snare, even after he refused the title of king.",
        9: "The first Israelites who heard Judges knew Shechem and the danger of violent rulers. They heard how Abimelech and the people who supported him were repaid for their evil.",
        10: "The first Israelites who heard Judges knew Israel had served the gods of neighboring peoples. They heard that turning from those gods was part of their plea for deliverance.",
        11: "The first Israelites who heard Judges knew Gilead and its conflict with Ammon. They heard both Jephthah's rescue and the grief that followed his careless vow.",
        12: "The first Israelites who heard Judges knew the tribes could turn their weapons on one another. They heard how Ephraim's quarrel with Gilead brought terrible loss within Israel.",
        13: "The first Israelites who heard Judges knew the Philistines oppressed the border towns of Dan. They heard that Samson was set apart before birth to begin Israel's rescue.",
        14: "The first Israelites who heard Judges knew Israel's law warned against marriage with the peoples of the land. They heard how Samson's choice opened a conflict with the Philistines.",
        15: "The first Israelites who heard Judges knew the Philistines ruled over Judah. They heard that the LORD gave Samson strength, even while revenge made the conflict worse.",
        16: "The first Israelites who heard Judges knew Philistine power and the worship of Dagon. They heard that Samson's strength was not his own and that he called on God at the end.",
        17: "The first Israelites who heard Judges knew the difference between the LORD's worship and private idols. They heard Micah's household as an example of each person doing what seemed right.",
        18: "The first Israelites who heard Judges knew Dan as Israel's northern border. They heard how the tribe's search for land led to stolen worship and violence against Laish.",
        19: "The first Israelites who heard Judges knew Gibeah as a town in Benjamin. They heard this account as proof of how far Israel had fallen when there was no king.",
        20: "The first Israelites who heard Judges knew the tribes of Israel and the shame of Gibeah. They heard how Benjamin's refusal to surrender the guilty led to a war that nearly destroyed a tribe.",
        21: "The first Israelites who heard Judges knew Benjamin survived and remained part of Israel. They heard that rash vows and violent plans did not repair the wrongs of the war.",
    }
    final_citations = {
        1: "Israel has the land on paper, but not in fact (Judges 1:21–36).",
        2: "This sets the pattern for the whole book: Israel sins, suffers, cries out, is rescued, and falls away again (Judges 2:14–19).",
        3: "Three very different men each deliver Israel (Judges 3:7–31).",
        12: "The conflict shows the danger of divisions among Israel's own tribes (Judges 12:1–15).",
        21: "Each fix only adds new wrongs (Judges 21:8–25).",
    }

    for chapter in range(1, 22):
        key = f"Judges {chapter}"
        moments[key] = historical_moments[chapter]
        context[key]["audience"] = original_audiences[chapter]
        if chapter in final_citations:
            old = insights[key]["summary"].rsplit(". ", 1)[0]
            insights[key]["summary"] = old + ". " + final_citations[chapter]

    judges = overview["Judges"]
    judges["author"] = "Jewish tradition names Samuel as the author. Judges does not name its writer, but its repeated words, \"In those days there was no king in Israel,\" show that it was written after kings ruled Israel."
    judges["audience"] = "Israel after the time of the judges, when its people knew both the tribal stories and life under kings."
    judges["purpose"] = "To show Israel's repeating turn from the LORD, the oppression that follows, and the LORD's mercy in raising deliverers, while revealing the need for faithful leadership."
    judges["theme"] = "When Israel abandons covenant faithfulness, disorder deepens. The LORD repeatedly shows mercy through deliverers, yet the book ends with a nation doing what is right in its own eyes."
    judges["summary"] = "Judges traces Israel's downward cycle of rebellion, oppression, crying out, and rescue through leaders called judges. The final stories show idolatry, violence, and civil war, exposing the need for faithful leadership."

    story_path = ROOT / "book_content/02_early_history.md"
    story = story_path.read_text(encoding="utf-8")
    start = story.index("# Judges")
    end = story.index("# Ruth", start)
    judges_story = story[start:end].replace("“", '"').replace("”", '"').replace("‘", "'").replace("’", "'")
    story_path.write_text(story[:start] + judges_story + story[end:], encoding="utf-8")

    save(insights_path, insights)
    save(moments_path, moments)
    save(context_path, context)
    save(overview_path, overview)


if __name__ == "__main__":
    main()
