#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Full quality pass for 1 Chronicles: replaces template text with real summaries, Where We Are,
Key People, and themes; fixes Historical Moments and Original Audience text; KJV spellings.

Run once, after review_1_chronicles.py.
"""

import json
import re
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


CH = {}

CH[1] = dict(
    summary="The record begins with Adam and follows the line through Noah and his three sons to Abraham (1 Chronicles 1:1–27). It adds the sons of Ishmael and of Keturah, then narrows to Isaac, whose sons are Esau and Israel (1 Chronicles 1:28–42). It ends with the kings who ruled in Edom before any king ruled over the children of Israel, and with the chiefs of Edom (1 Chronicles 1:43–54). This is a list of names, not a story, and it places Israel among its related peoples so that the history of David and the temple has a long background.",
    wwa="2 Kings ended with Judah in exile, and 1 Chronicles opens by going back to the very beginning with Adam. This chapter lists the family lines from Adam to Abraham and on to Isaac's sons, Esau and Israel. Chapter 2 narrows to the twelve sons of Israel and the tribe of Judah.",
    people=[("Adam", "The first name on the list, where the whole record begins."), ("Noah", "His three sons start the family lines of the nations."), ("Abraham", "Father of Isaac and Ishmael, and the central ancestor of Israel."), ("Isaac", "Abraham's son, whose sons are Esau and Israel."), ("Esau", "Ancestor of Edom, whose kings and chiefs close the chapter."), ("Israel", "Isaac's son, also called Jacob, and the father of the twelve tribes.")],
    themes=[("Everyone has a place", "The list begins with Adam, so the people returning from exile could see themselves in the story of all humankind."), ("Israel among its neighbors", "The record names Ishmael, the sons of Keturah, and Esau's family, who were all related to Israel."), ("Kings before Israel's kings", "The kings of Edom \"reigned in the land of Edom before any king reigned over the children of Israel.\"")],
)
CH[2] = dict(
    summary="The chapter begins with the twelve sons of Israel and then turns to the sons of Judah (1 Chronicles 2:1–4). It follows the line of Pharez, mentions Achar, \"the troubler of Israel,\" and lists the families of Hezron, Caleb, Jerahmeel, and Ram (1 Chronicles 2:5–41). The line through Ram leads to Jesse and his seven sons, and David is the seventh (1 Chronicles 2:10–17). More family lists tie Judah's clans to places such as Bethlehem and Kirjathjearim (1 Chronicles 2:42–55). The chapter does not give full life stories, but it shows Judah's many branches and places David's family among them.",
    wwa="Chapter 1 ended with the kings and chiefs of Edom. This chapter lists the twelve sons of Israel and then follows Judah, the tribe of kings, down to Jesse and David. Chapter 3 gives David's own sons and the kings who came after him.",
    people=[("Israel", "Father of the twelve sons named at the start."), ("Judah", "The tribal ancestor whose families fill most of the chapter."), ("Pharez", "Judah's son, whose line leads to David."), ("Ram", "An ancestor in the line from Hezron to David."), ("Jesse", "David's father, with seven sons."), ("David", "The seventh son of Jesse.")],
    themes=[("Belonging to a tribe", "The chapter starts with all twelve sons of Israel, then settles on Judah."), ("David's family line", "The line runs from Judah through Ram to Jesse, and David is Jesse's seventh son."), ("Families tied to places", "Some names are towns, like Bethlehem and Kirjathjearim, listed as founded by a family's ancestor.")],
)
CH[3] = dict(
    summary="The record opens with David's sons born in Hebron, where he reigned seven years and six months, and those born later in Jerusalem, where he reigned thirty-three years (1 Chronicles 3:1–9). It then lists the kings of Judah from Solomon down to the time of the exile (1 Chronicles 3:10–16). The last verses follow the line of Jeconiah and his descendants, including Zerubbabel (1 Chronicles 3:17–24). Rather than telling of battles, the chapter keeps the royal line alive across the fall of Judah's kings. Some names and family links in the late part are hard to read, so they do not give an exact timeline.",
    wwa="Chapter 2 ended with the families of Judah. This chapter lists David's sons, then the kings of Judah, and then the descendants of the king carried to Babylon. Chapter 4 returns to the families of Judah and the prayer of Jabez.",
    people=[("David", "The king whose sons are listed by where they were born."), ("Solomon", "David's son and successor."), ("Rehoboam", "Solomon's son, the next king of Judah."), ("Josiah", "A later king in the list."), ("Jeconiah", "The king taken to Babylon, also called Jehoiachin."), ("Zerubbabel", "A descendant of Jeconiah named in the list.")],
    themes=[("Royal succession", "The list follows the kings from David to Josiah and his sons."), ("David's line survives the exile", "The record goes past the fall of Jerusalem, so David's family does not end with the exile."), ("Limits of the list", "Some late names are hard to place, so the list is a record of family memory, not a full timeline.")],
)
CH[4] = dict(
    summary="The chapter continues the family records of Judah with names tied to clans, towns, craftsmen, and settlements (1 Chronicles 4:1–23). In the middle of the lists, Jabez prays, \"Oh that thou wouldest bless me indeed, and enlarge my coast,\" and the writer says God granted what he asked (1 Chronicles 4:9–10). The record then turns to the descendants of Simeon, their towns, and their search for pasture (1 Chronicles 4:24–43). Together the lists show family memory, one short prayer, and the everyday need for land.",
    wwa="Chapter 3 ended with the royal line after the exile. This chapter goes back to Judah's clans, stops for the prayer of Jabez, and then lists the families of Simeon. Chapter 5 turns to the tribes east of the Jordan.",
    people=[("Jabez", "A man more honourable than his brothers, who asks God for blessing and protection."), ("The God of Israel", "Grants Jabez what he asked."), ("The craftsmen of Judah", "Families known for their trades, such as linen workers and potters."), ("The families of Simeon", "Settle towns and go looking for pasture for their flocks.")],
    themes=[("A short prayer", "Jabez asks God to bless him and to \"keep me from evil.\""), ("Work and family", "Some families are known for their trades, which were passed down in the household."), ("Land and a living", "The families of Simeon search for pasture and settle new places.")],
)
CH[5] = dict(
    summary="Reuben was Israel's firstborn, but because he defiled his father's bed his birthright was given to the sons of Joseph, while Judah became the chief ruler (1 Chronicles 5:1–2). The chapter lists the families of Reuben and Gad and the lands where they lived east of the Jordan (1 Chronicles 5:3–17). The eastern tribes fight the Hagarites, and they cry to God and are helped because they put their trust in him (1 Chronicles 5:18–22). But they later go astray after the gods of the land, and the king of Assyria carries them away (1 Chronicles 5:23–26). The record joins family history, war, and faithfulness.",
    wwa="Chapter 4 ended with Simeon's families looking for pasture. This chapter turns to Reuben, Gad, and half of Manasseh, who lived east of the Jordan, and tells how they won in war and then were carried away. Chapter 6 turns to Levi and the priests.",
    people=[("Reuben", "Israel's firstborn, who lost the birthright."), ("The sons of Joseph", "Receive the birthright that Reuben lost."), ("Judah", "The tribe from which the chief ruler comes."), ("The Reubenites, Gadites, and half tribe of Manasseh", "Win a war by trusting God, then turn to other gods."), ("Pul and Tilgathpilneser", "The kings of Assyria who carry them away.")],
    themes=[("Birthright and responsibility", "Reuben loses the firstborn's place because of what he did to his father's bed."), ("Trust in battle", "The eastern tribes \"cried to God in the battle,\" and he helped them because they trusted him."), ("Unfaithfulness and exile", "They go after the gods of the people of the land, and Assyria carries them away.")],
)
CH[6] = dict(
    summary="The long record of Levi begins with his sons Gershom, Kohath, and Merari, and follows the line from Aaron through the high priests to Jehozadak, who went into captivity when the LORD carried away Judah and Jerusalem by the hand of Nebuchadnezzar (1 Chronicles 6:1–30). It names the men David set over the service of song after the ark had rest, Heman, Asaph, and Ethan, with their fathers (1 Chronicles 6:31–48). Aaron and his sons are given the altar and the holy work of the sanctuary (1 Chronicles 6:49–53). The chapter ends with lists of towns and pasturelands given to the priests and Levites from the different tribes (1 Chronicles 6:54–81). Its main concern is who served in worship, and how that service continued.",
    wwa="Chapter 5 ended with the eastern tribes carried away to Assyria. This chapter turns to Levi, the tribe that served in worship, and traces its priests, singers, and towns. Chapter 7 returns to the other tribes.",
    people=[("Levi", "Father of Gershom, Kohath, and Merari."), ("Aaron", "The ancestor of the priests, who offered at the altar."), ("Eleazar", "Aaron's son in the line of high priests."), ("Heman", "A singer of the Kohathite line."), ("Asaph", "A singer of the Gershonite line."), ("Ethan", "A singer of the Merarite line.")],
    themes=[("Priestly work", "\"Aaron and his sons offered upon the altar of the burnt offering,\" and the other Levites served the tabernacle."), ("Worship and music", "David set singers over the service of song, and they served until Solomon built the house."), ("Towns for the Levites", "The priests and Levites received towns and pasturelands from every tribe.")],
)
CH[7] = dict(
    summary="The chapter lists the families of Issachar, Benjamin, Naphtali, Manasseh, Ephraim, and Asher (1 Chronicles 7:1–40). Several lines give the number of valiant men of might, which shows how households were organized for war (1 Chronicles 7:2–5, 7:7–11, 7:40). Ephraim's record pauses to say that men of Gath killed his sons, and Ephraim mourned many days before Beriah was born, and Jehoshua is named later in his line (1 Chronicles 7:20–27). The chapter also names places where Ephraim and Manasseh lived (1 Chronicles 7:28–29). It is a set of chosen lines, not a full count of Israel.",
    wwa="Chapter 6 ended with the towns of the Levites. This chapter lists six more tribes, Issachar, Benjamin, Naphtali, Manasseh, Ephraim, and Asher. Chapter 8 returns to Benjamin to follow Saul's family.",
    people=[("Issachar", "A tribe whose valiant men are counted."), ("Benjamin", "A tribe whose households are listed with their fighting men."), ("Manasseh", "Joseph's son, whose family lines are recorded."), ("Ephraim", "Mourns his sons killed by the men of Gath."), ("Beriah", "Born to Ephraim after the loss and named for it."), ("Sherah", "Ephraim's daughter, who built Bethhoron and Uzzensherah.")],
    themes=[("Households ready for war", "Several families give the number of valiant men of might."), ("Loss and a new start", "Ephraim mourns his sons many days, and then Beriah is born."), ("Places to belong", "The chapter names towns where Ephraim and Manasseh lived.")],
)
CH[8] = dict(
    summary="The chapter gives a longer record of Benjamin, naming household heads and families tied to places such as Jerusalem and Gibeon (1 Chronicles 8:1–28). It then follows the line of Kish to Saul and his sons, including Jonathan (1 Chronicles 8:29–40). Jonathan's son is Meribbaal, and the list goes on through many later descendants. This prepares for the story of Saul's death in chapter 10, and it keeps Saul's family in Israel's memory instead of erasing the first king.",
    wwa="Chapter 7 ended with the northern tribes. This chapter returns to Benjamin, the tribe of Saul, and follows his family. Chapter 9 tells who lived in Jerusalem after the exile.",
    people=[("Benjamin", "The tribe whose households and towns are listed."), ("Kish", "The father of Saul."), ("Saul", "Israel's first king."), ("Jonathan", "Saul's son."), ("Meribbaal", "Jonathan's son, whose line continues."), ("The sons of Ulam", "Mighty men and archers with many sons and grandsons.")],
    themes=[("Remembering Benjamin", "The record names the households and towns of a tribe that stayed close to Judah."), ("Saul's family", "Saul is traced from Kish, with his sons Jonathan, Malchishua, Abinadab, and Eshbaal."), ("Descendants after the kings", "Jonathan's line goes on, and the sons of Ulam \"were mighty men of valour, archers.\"")],
)
CH[9] = dict(
    summary="The writer says all Israel was reckoned by genealogies, and that Judah was carried away to Babylon for their transgression (1 Chronicles 9:1). The first people to live again in their cities were Israelites, priests, Levites, and the Nethinims, and in Jerusalem lived men of Judah, Benjamin, Ephraim, and Manasseh, with priests, Levites, gatekeepers, and singers (1 Chronicles 9:2–34). The chapter ends by repeating the family of Saul (1 Chronicles 9:35–44). It joins the long family record to the worshiping community that came home, and it leads into the story of the kings.",
    wwa="Chapter 8 traced Saul's family. This chapter explains why the lists matter: they tell who lived in Jerusalem after the exile and who served in the house of the LORD, and it repeats Saul's line to lead into his story. Chapter 10 begins that story with Saul's death.",
    people=[("The people of Judah, Benjamin, Ephraim, and Manasseh", "Live in Jerusalem after the return."), ("The priests", "Serve the sanctuary, listed by family."), ("The Levites", "Care for the work of the house of God."), ("The gatekeepers", "Guard the gates of the house in shifts."), ("The singers", "Live in the chambers, free from other work, because they worked day and night.")],
    themes=[("Exile and its cause", "Judah was \"carried away to Babylon for their transgression.\""), ("Rebuilding common life", "The first people back in their cities were Israelites, priests, Levites, and temple servants."), ("Order in the sanctuary", "The gatekeepers, the keepers of the vessels, and the singers each had a set job in the house of God.")],
)
CH[10] = dict(
    summary="The Philistines fight against Israel on mount Gilboa, and Saul's sons Jonathan, Abinadab, and Malchishua are killed, and Saul is wounded by the archers (1 Chronicles 10:1–3). His armourbearer will not kill him, so Saul falls on his sword, and the armourbearer dies too (1 Chronicles 10:4–6). The Philistines show the bodies, take Saul's head and armour to their gods, and the valiant men of Jabeshgilead take the bodies and bury the bones (1 Chronicles 10:7–12). The writer explains that Saul died for his transgression against the LORD, including asking counsel of one with a familiar spirit, and that the LORD turned the kingdom to David (1 Chronicles 10:13–14).",
    wwa="Chapter 9 ended with Saul's family line. This chapter skips most of Saul's life and tells only his death on mount Gilboa, then gives the writer's reason for it. Chapter 11 shows all Israel making David king.",
    people=[("Saul", "Wounded by the archers, he falls on his own sword."), ("Jonathan, Abinadab, and Malchishua", "Saul's sons, killed in the battle."), ("The Philistines", "Defeat Israel and show the bodies in their temples."), ("Saul's armourbearer", "Will not kill Saul, then falls on his own sword."), ("The men of Jabeshgilead", "Take the bodies and bury the bones."), ("The LORD", "Turns the kingdom to David.")],
    themes=[("Defeat and fear", "Saul asks his armourbearer to kill him so that the uncircumcised will not abuse him."), ("Respect for the dead", "The men of Jabeshgilead bury the bones of Saul and his sons and fast seven days."), ("The writer's judgment", "Saul died \"for his transgression which he committed against the LORD.\"")],
)
CH[11] = dict(
    summary="All Israel comes to David at Hebron and says, \"Behold, we are thy bone and thy flesh,\" and the elders make a covenant with him and anoint him king (1 Chronicles 11:1–3). David takes the stronghold of Zion from the Jebusites and calls it the city of David, and Joab becomes chief by going up first, and \"David waxed greater and greater: for the LORD of hosts was with him\" (1 Chronicles 11:4–9). The chapter lists David's mighty men, including Jashobeam and Eleazar, and three who break through the Philistine camp to bring him water from Bethlehem, but David will not drink it and pours it out to the LORD (1 Chronicles 11:10–47).",
    wwa="Chapter 10 ended with the kingdom turned to David. This chapter shows all Israel anointing him at Hebron, David taking Jerusalem, and a list of his mighty men. Chapter 12 tells who joined him.",
    people=[("David", "Anointed king over Israel, he takes Jerusalem."), ("The elders of Israel", "Make a covenant with David and anoint him."), ("Joab", "Goes up first against Jebus and becomes chief."), ("Jashobeam", "Chief of David's mighty men."), ("Eleazar son of Dodo", "One of the three mightiest."), ("Abishai", "A warrior and leader among the mighty men.")],
    themes=[("Recognized leadership", "All Israel says to David, \"we are thy bone and thy flesh.\""), ("A city for the king", "David takes Zion and it becomes the city of David."), ("Costly loyalty", "David will not drink water his men risked their lives to bring, and pours it out to the LORD.")],
)
CH[12] = dict(
    summary="The chapter names the warriors who came to David at Ziklag while he still kept himself close because of Saul, including men of Benjamin who could use both the right hand and the left in hurling stones and shooting arrows (1 Chronicles 12:1–7). Men of Gad join him in the wilderness, men of Benjamin and Judah come, and Amasai, with the spirit upon him, says, \"Thine are we, David, and on thy side, thou son of Jesse,\" and David welcomes them (1 Chronicles 12:8–18). Men of Manasseh also help him (1 Chronicles 12:19–22). A long list tells of armed groups from every tribe who come to Hebron to make David king, and they eat and drink with him three days with food brought from all around (1 Chronicles 12:23–40).",
    wwa="Chapter 11 ended with David's mighty men. This chapter tells who joined him, first at Ziklag when Saul still ruled, and then at Hebron when every tribe came to make him king. Chapter 13 tells of his first try at bringing the ark to Jerusalem.",
    people=[("David", "The leader who receives the men who come to him."), ("The Benjamites", "Archers and slingers, some of them from Saul's own tribe."), ("The Gadites", "Men of war whose faces were like the faces of lions."), ("Amasai", "Chief of the captains, who speaks peace to David."), ("The men of Manasseh", "Come over to help David."), ("The tribes at Hebron", "Armed men who come to make David king.")],
    themes=[("A growing band", "Men come to David at Ziklag even while Saul is king."), ("One heart", "All the rest of Israel \"were of one heart to make David king.\""), ("A feast of joy", "The tribes eat and drink with David three days, with food brought on donkeys, camels, mules, and oxen.")],
)
CH[13] = dict(
    summary="David talks with the captains and all the leaders and proposes bringing the ark of God from Kirjathjearim, because they did not ask at it in the days of Saul (1 Chronicles 13:1–6). They set the ark on a new cart, and David and all Israel play before God with all their might (1 Chronicles 13:7–8). When the oxen stumble, Uzza puts out his hand to hold the ark, and God strikes him dead, and David is displeased and afraid (1 Chronicles 13:9–12). The ark stays three months in the house of Obededom, and the LORD blesses his house (1 Chronicles 13:13–14). The story is troubling: joy and good aims do not make up for ignoring how God said the ark must be carried.",
    wwa="Chapter 12 ended with the feast at Hebron. This chapter tells David's first try at bringing the ark to Jerusalem, which ends with Uzza's death. Chapter 14 turns to David's house and his wars with the Philistines.",
    people=[("David", "Plans the move and is afraid when Uzza dies."), ("Uzza", "Puts out his hand to hold the ark and dies."), ("Ahio", "Helps drive the new cart."), ("Obededom", "Keeps the ark in his house and is blessed."), ("The people with David", "Sing and play before God as the ark moves.")],
    themes=[("Worship together", "All the congregation says it is right, and Israel plays with all their might."), ("Reverence and limits", "Good aims and joy do not change the way God said the ark must be handled."), ("Blessing and presence", "The LORD blesses the house of Obededom and all he has.")],
)
CH[14] = dict(
    summary="Hiram king of Tyre sends messengers, cedar, masons, and carpenters to build David a house, and David knows that the LORD has made him king over Israel (1 Chronicles 14:1–2). More children are born to David in Jerusalem (1 Chronicles 14:3–7). When the Philistines hear that David is king over all Israel, they come up, and David asks God and beats them at Baalperazim (1 Chronicles 14:8–12). The Philistines spread out again in the valley, and David asks God again, and God tells him to go around and attack when he hears a sound of going in the tops of the mulberry trees (1 Chronicles 14:13–17).",
    wwa="Chapter 13 ended with the ark at the house of Obededom. This chapter shows David's house being built, his family growing, and two wins over the Philistines won by asking God first. Chapter 15 tells how the ark finally comes to Jerusalem.",
    people=[("David", "Builds his house, grows his family, and asks God before each battle."), ("Hiram", "King of Tyre, who sends cedar, masons, and carpenters."), ("The Philistines", "Come up against David twice in the valley."), ("David's wives and children", "The family listed as David's household grows in Jerusalem.")],
    themes=[("A kingdom set firm", "David knows the LORD has made him king over Israel for the sake of his people."), ("Asking God first", "David asks God both times before facing the Philistines, and gets a different plan the second time."), ("A famous king", "\"The fame of David went out into all lands,\" and the LORD brought the fear of him on all nations.")],
)
CH[15] = dict(
    summary="David makes houses in the city of David and prepares a place for the ark, and says, \"None ought to carry the ark of God but the Levites\" (1 Chronicles 15:1–2). He gathers the priests, Levites, and elders, and tells them that the LORD broke out on them because they did not seek him in the right order, and they make themselves holy (1 Chronicles 15:3–15). Singers and musicians are appointed, and the ark is brought up with sacrifices, shouting, and music (1 Chronicles 15:16–28). Michal, Saul's daughter, looks out a window and sees David dancing and playing, and she despises him in her heart (1 Chronicles 15:29).",
    wwa="Chapter 14 ended with David's fame. This chapter goes back to the ark and shows David doing it the right way this time, with the Levites carrying it and singers leading praise. Chapter 16 gives the psalm of thanks.",
    people=[("David", "Prepares a place for the ark and leads the procession."), ("Zadok and Abiathar", "The priests David calls to bring up the ark."), ("The Levite family heads", "Make themselves holy and carry the ark."), ("Heman, Asaph, and Ethan", "The singers appointed to play and sing."), ("Michal", "Saul's daughter, who despises David in her heart.")],
    themes=[("Fixing a failure", "David says the first try failed because Israel \"sought him not after the due order.\""), ("Music in worship", "Levite singers play psalteries, harps, and cymbals as the ark comes up."), ("Two responses", "The people shout for joy, while Michal watches from a window and despises David.")],
)
CH[16] = dict(
    summary="The ark is set in the tent David pitched, and David offers burnt offerings and peace offerings, blesses the people, and gives each a loaf of bread, a good piece of meat, and a flagon of wine (1 Chronicles 16:1–3). David appoints Levites to serve before the ark, with Asaph as chief (1 Chronicles 16:4–7). A long psalm calls Israel to give thanks to the LORD, to remember his covenant with Abraham, Isaac, and Jacob, and to tell of his acts among the nations, because he made the heavens and comes to judge the earth (1 Chronicles 16:8–36). Asaph and his brethren serve before the ark every day, and Zadok and the priests serve at the tabernacle at Gibeon, and the people go home (1 Chronicles 16:37–43).",
    wwa="Chapter 15 ended with the ark brought into the city. This chapter sets the ark in its tent and gives David's psalm of thanks, then fixes who will serve before it. Chapter 17 tells how David wants to build God a house.",
    people=[("David", "Offers sacrifices, blesses the people, and gives the psalm to Asaph."), ("Asaph", "Chief of the Levites who serve before the ark."), ("Obededom", "Named among those who serve before the ark."), ("Zadok", "The priest who serves at the tabernacle at Gibeon."), ("The people", "Say \"Amen\" and praise the LORD.")],
    themes=[("A remembered covenant", "The psalm tells Israel to remember the covenant with Abraham, Isaac, and Jacob."), ("Praise for all the earth", "The psalm says, \"Sing unto the LORD, all the earth,\" and tells his acts among the nations."), ("Daily service", "Asaph and his brethren serve before the ark continually, as every day's work required.")],
)
CH[17] = dict(
    summary="David tells Nathan that he lives in a house of cedars while the ark of the covenant of the LORD remains under curtains, and Nathan tells him to do all that is in his heart (1 Chronicles 17:1–2). That night God tells Nathan to say that David will not build the house, and recalls how he has been with Israel, and says he will build David a house (1 Chronicles 17:3–10). A son of David will build the house, and God will be his father, and his throne will be established for evermore (1 Chronicles 17:11–14). David sits before the LORD and prays, \"Who am I, O LORD God, and what is mine house,\" and asks God to do as he has said (1 Chronicles 17:15–27).",
    wwa="Chapter 16 ended with praise before the ark. This chapter shows David wanting to build a house for the ark, and God promising to build David a house instead. Chapter 18 tells of David's victories.",
    people=[("David", "Wants to build a house for the ark, then prays in thanks."), ("Nathan", "Tells David to go ahead, then brings God's word that night."), ("The LORD", "Promises to build David a house and to set his son on a lasting throne.")],
    themes=[("God moves first", "God says he took David from the sheepcote and will build David's house."), ("A promise that lasts", "God says David's son will be set in his house \"for ever,\" and his throne will be established for evermore."), ("A humble prayer", "David asks, \"Who am I, O LORD God, and what is mine house,\" and asks God to do as he has said.")],
)
CH[18] = dict(
    summary="David beats the Philistines and takes Gath and her towns, beats Moab, and beats Hadarezer king of Zobah, and when the Syrians of Damascus come to help, he kills twenty-two thousand of them and puts garrisons in Syria (1 Chronicles 18:1–8). Tou king of Hamath sends his son Hadoram with gifts, and David dedicates the silver and gold from all the nations to the LORD (1 Chronicles 18:9–11). Abishai beats eighteen thousand Edomites in the valley of salt, and David puts garrisons in Edom, and the LORD keeps David safe wherever he goes (1 Chronicles 18:12–13). David reigns over all Israel and does judgment and justice among all his people, and his officers include Joab, Jehoshaphat, Zadok, Ahimelech, Shavsha, and Benaiah (1 Chronicles 18:14–17).",
    wwa="Chapter 17 gave God's promise to David. This chapter shows that promise at work, with David winning his wars, giving the spoil to the LORD, and ruling with justice. Chapter 19 tells how one of those wars began.",
    people=[("David", "Wins his wars, gives the spoil to the LORD, and rules with justice."), ("Hadarezer", "King of Zobah, beaten by David."), ("Tou", "King of Hamath, who sends gifts after Hadarezer falls."), ("Hadoram", "Tou's son, who brings the gifts."), ("Joab", "Commander of the army."), ("Zadok and Ahimelech", "The priests named among David's officers.")],
    themes=[("A kingdom that grows", "David beats the Philistines, Moab, Zobah, Syria, and Edom."), ("Spoil given to God", "David dedicates the silver and gold from all the nations to the LORD."), ("Justice and order", "David \"executed judgment and justice among all his people,\" with officers for the army, the priests, and the court.")],
)
CH[19] = dict(
    summary="After Nahash king of Ammon dies, David sends messengers to comfort his son Hanun (1 Chronicles 19:1–2). The princes of Ammon say David's men are spies, and Hanun shaves them and cuts their garments in the middle, and David tells them to stay at Jericho until their beards are grown (1 Chronicles 19:3–5). The Ammonites hire chariots and horsemen from Mesopotamia and Syria, and Joab and Abishai divide the army and win (1 Chronicles 19:6–15). When the Syrians gather again beyond the river, David wins another victory, and they make peace with him (1 Chronicles 19:16–19).",
    wwa="Chapter 18 listed David's wars. This chapter tells how one of them began, with a kind message to Ammon that was insulted. Chapter 20 tells of the fall of Rabbah.",
    people=[("David", "Sends comfort to Hanun and later leads the army against Syria."), ("Hanun", "King of Ammon, who shames David's messengers."), ("The princes of Ammon", "Tell Hanun that David's men are spies."), ("Joab", "Leads the main army against the Syrians."), ("Abishai", "Joab's brother, who leads the rest against Ammon.")],
    themes=[("Kindness mistaken for a trick", "The princes of Ammon say David's comforters have come to spy out the land."), ("Brothers backing each other", "Joab tells Abishai, \"If the Syrians be too strong for me, then thou shalt help me,\" and the same the other way."), ("A small insult grows", "The shaving of David's men leads to a war with Ammon and Syria.")],
)
CH[20] = dict(
    summary="At the time that kings go out to battle, Joab leads out the army, wastes the country of the children of Ammon, besieges Rabbah, and destroys it, while David stays at Jerusalem (1 Chronicles 20:1). David takes the crown of their king, weighing a talent of gold, and brings out much spoil from the city (1 Chronicles 20:2–3). In later wars with the Philistines, Sibbechai, Elhanan, and Jonathan the son of Shimea kill giants of Gath (1 Chronicles 20:4–8). The chapter is short and tells only of victories. Unlike 2 Samuel 11, it does not tell of David's sin with Bathsheba; that is the writer's choice and does not deny what the other book says.",
    wwa="Chapter 19 ended with peace with the Syrians. This chapter tells how Rabbah falls and how David's men beat giants of Gath, but it leaves out David's sin. Chapter 21 tells of the census.",
    people=[("Joab", "Leads the army and destroys Rabbah."), ("David", "Stays in Jerusalem, then takes the crown of Ammon's king."), ("The Ammonites", "Defend Rabbah and lose it."), ("Sibbechai", "Kills a giant of the sons of the giant."), ("Elhanan", "Kills Lahmi, the brother of Goliath."), ("Jonathan son of Shimea", "Kills a giant with six fingers on each hand and six toes on each foot.")],
    themes=[("War and royal power", "Joab's army wins at Rabbah, and David takes the crown."), ("Courage against giants", "Three of David's men kill giants of Gath."), ("What the writer leaves out", "This book skips David's sin with Bathsheba and keeps to his wins and his work for the temple.")],
)
CH[21] = dict(
    summary="Satan stands up against Israel and provokes David to number Israel (1 Chronicles 21:1). David tells Joab to number Israel from Beersheba to Dan, and Joab asks why David would be a cause of trespass to Israel, but the king's word wins, and God is displeased and strikes Israel (1 Chronicles 21:2–8). The LORD speaks to Gad, David's seer, who gives David three choices, and David says, \"let me fall now into the hand of the LORD; for very great are his mercies\" (1 Chronicles 21:9–13). Seventy thousand die of the pestilence, and as the angel stretches out his hand over Jerusalem, the LORD says, \"It is enough, stay now thine hand\" (1 Chronicles 21:14–17). Gad tells David to build an altar on the threshing floor of Ornan the Jebusite, and David pays six hundred shekels of gold for the place, refusing to offer burnt offerings that cost him nothing, and fire from heaven answers him (1 Chronicles 21:18–30). This account differs from 2 Samuel 24 in how it says who moved David.",
    wwa="Chapter 20 ended with victories over giants. This chapter tells how David's census brings a plague, how the LORD stops it at Jerusalem, and how David buys the threshing floor of Ornan and builds an altar. Chapter 22 shows David preparing the same place for the temple.",
    people=[("Satan", "Stands up against Israel and provokes David to number the people."), ("David", "Orders the census, confesses his sin, and chooses the LORD's hand."), ("Joab", "Warns David not to do it, then counts."), ("Gad", "David's seer, who brings the three choices."), ("Ornan", "Owner of the threshing floor, who offers it free."), ("The angel of the LORD", "Stretches out his hand over Jerusalem until the LORD says to stop.")],
    themes=[("Pride in numbers", "Joab warns that counting the people will make Israel guilty."), ("Judgment and mercy", "David chooses to fall into the hand of the LORD, \"for very great are his mercies.\""), ("Costly worship", "David will not offer burnt offerings \"without cost,\" and the place becomes the site of the temple.")],
)
CH[22] = dict(
    summary="David says, \"This is the house of the LORD God, and this is the altar of the burnt offering for Israel\" (1 Chronicles 22:1). He gathers the strangers in the land and prepares stone, iron, bronze, and cedar, because Solomon is young and tender and the house must be very grand (1 Chronicles 22:2–5). He tells Solomon that God did not let David build because he shed much blood, but a son who is a man of rest will be named Solomon and will build the house (1 Chronicles 22:6–10). David prays that the LORD will be with Solomon, tells him to keep the law, and tells the princes of Israel to help him build the sanctuary (1 Chronicles 22:11–19).",
    wwa="Chapter 21 ended with the altar on Ornan's threshing floor. This chapter shows David naming that place as the site of the temple and gathering everything Solomon will need. Chapter 23 tells how David organizes the Levites.",
    people=[("David", "Names the temple site, gathers materials, and charges Solomon."), ("Solomon", "The son who will build the house and be a man of rest."), ("The strangers in the land", "Work as stonecutters and craftsmen preparing the materials."), ("The princes of Israel", "Told to help Solomon build.")],
    themes=[("Preparing for someone else's work", "David gathers materials for a house that his son will build."), ("A man of war, a man of rest", "God says, \"his name shall be Solomon,\" and gives peace in his days."), ("Be strong", "David tells Solomon, \"Be strong and of good courage; dread not, nor be dismayed.\"")],
)
CH[23] = dict(
    summary="When David is old and full of days, he makes Solomon his son king over Israel and gathers the princes, priests, and Levites (1 Chronicles 23:1–2). The Levites thirty years old and up number thirty-eight thousand, and they are given work at the house of the LORD, as officers and judges, as gatekeepers, and as praisers (1 Chronicles 23:3–5). The families of Gershon, Kohath, and Merari are listed with their duties (1 Chronicles 23:6–23). David says the LORD has given rest to his people and will dwell in Jerusalem for ever, so the Levites no longer need to carry the tabernacle, and they will help the priests and stand every morning and evening to thank and praise the LORD (1 Chronicles 23:24–32).",
    wwa="Chapter 22 ended with David's charge to the princes. This chapter shows David making Solomon king and counting the Levites, then giving them new work now that the ark has a home. Chapter 24 tells how the priests are divided.",
    people=[("David", "Makes Solomon king and sets out the work of the Levites."), ("Solomon", "Made king by David."), ("The Levites", "Given work in the house, as officers, judges, gatekeepers, and praisers."), ("Gershon, Kohath, and Merari", "The three family branches that share the duties."), ("Aaron and his sons", "Set apart for the most holy things.")],
    themes=[("Organized service", "The Levites are counted and given set jobs: work, judging, gates, and praise."), ("Changing conditions", "The Levites no longer need to carry the tabernacle, because the LORD has given rest."), ("Daily praise", "Each morning and evening the Levites stand \"to thank and praise the LORD.\"")],
)
CH[24] = dict(
    summary="The chapter lists the sons of Aaron and says Nadab and Abihu died before their father and had no children, so Eleazar and Ithamar served as priests (1 Chronicles 24:1–2). David divides the priests with Zadok of the sons of Eleazar and Ahimelech of the sons of Ithamar, and sixteen chief men are found among Eleazar's sons and eight among Ithamar's (1 Chronicles 24:3–6). The priestly families are given their order of service by lot, in twenty-four courses (1 Chronicles 24:7–19). The rest of the chapter lists other Levite family heads, who also cast lots (1 Chronicles 24:20–31).",
    wwa="Chapter 23 ended with the Levites' duties. This chapter divides the priests, the sons of Aaron, into twenty-four courses by lot, so each family takes its turn. Chapter 25 tells how the singers are set apart.",
    people=[("Eleazar", "Aaron's son, whose descendants supply sixteen of the courses."), ("Ithamar", "Aaron's son, whose descendants supply eight."), ("David", "Divides the priests with Zadok and Ahimelech."), ("Zadok", "The priest of Eleazar's line."), ("Ahimelech", "The priest of Ithamar's line."), ("Shemaiah the scribe", "Writes down the names before the king and the princes.")],
    themes=[("Order in the ministry", "The priests are divided into courses that take turns in the house."), ("Lots, so no one is favored", "\"Thus were they divided by lot, one sort with another.\""), ("Priests and Levites together", "The other Levite heads cast lots too, \"the principal fathers over against their younger brethren.\"")],
)
CH[25] = dict(
    summary="David and the captains of the host set apart some of the sons of Asaph, Heman, and Jeduthun for the service of song, who should prophesy with harps, with psalteries, and with cymbals (1 Chronicles 25:1–3). Their sons and brethren are named, and all who were instructed in the songs of the LORD number two hundred eighty and eight (1 Chronicles 25:4–7). They cast lots for their turns in twenty-four courses, small and great, teacher and pupil together (1 Chronicles 25:8–31). The chapter shows music as skilled work, learned and shared, for the LORD.",
    wwa="Chapter 24 divided the priests by lot. This chapter sets apart the singers and musicians from three Levite families and divides them into twenty-four courses too. Chapter 26 tells of the gatekeepers and treasurers.",
    people=[("David", "Sets apart the musicians with the captains of the host."), ("Asaph", "A head of one family of singers."), ("Heman", "A head of another family, called the king's seer."), ("Jeduthun", "A head of the third family."), ("The sons and brethren of the three", "Trained musicians who serve in ordered groups.")],
    themes=[("Music as service", "The singers \"prophesy with harps, with psalteries, and with cymbals.\""), ("Skill that is taught", "Two hundred eighty-eight were instructed in the songs of the LORD."), ("Shared turns", "They cast lots \"as well the small as the great, the teacher as the scholar.\"")],
)
CH[26] = dict(
    summary="The chapter names the divisions of the porters, from the Korhites and the sons of Merari, including the sons of Obededom, whom God blessed (1 Chronicles 26:1–11). They cast lots for their gates, each family by its gate, and the guards watch in turn (1 Chronicles 26:12–19). Other Levites are over the treasures of the house of God and the treasures of the dedicated things, which David and the captains and others had dedicated (1 Chronicles 26:20–28). Chenaniah and his sons, Hashabiah and his brethren, and others are officers and judges over Israel on both sides of the Jordan (1 Chronicles 26:29–32).",
    wwa="Chapter 25 set apart the singers. This chapter assigns the gatekeepers, the keepers of the treasures, and the officers who serve outside the temple. Chapter 27 turns to David's army and royal officers.",
    people=[("Obededom and his sons", "Strong men chosen as gatekeepers, blessed by God."), ("Meshelemiah", "A Korhite leader of the gatekeepers."), ("Hosah", "A Merarite gatekeeper."), ("Shebuel", "Ruler of the treasures."), ("Shelomith", "Over the treasures of the dedicated things."), ("Chenaniah and the other officers", "Serve as officers and judges over Israel.")],
    themes=[("Guarding the house", "The gatekeepers cast lots for their gates, each family by its gate."), ("Care for what is given", "The treasurers look after the things dedicated to God."), ("Service outside the temple", "Some Levites serve as officers and judges over Israel on both sides of the Jordan.")],
)
CH[27] = dict(
    summary="The chapter lists the twelve divisions of twenty-four thousand men, each serving one month of the year with its captain (1 Chronicles 27:1–15). It names the princes over the tribes of Israel (1 Chronicles 27:16–22). David does not number those under twenty, because the LORD had said he would increase Israel like the stars, and Joab began to number but did not finish, because wrath fell on Israel (1 Chronicles 27:23–24). It then names the men over the king's treasures, storehouses, fields, vineyards, olive and sycamore trees, herds, camels, donkeys, and flocks, and David's counsellors, including Ahithophel and Hushai (1 Chronicles 27:25–34).",
    wwa="Chapter 26 assigned the temple officers. This chapter turns to the army, the tribal leaders, and the stewards of the king's property. Chapter 28 shows David's last charge to Solomon.",
    people=[("David", "The king whose army and estate officers are listed."), ("Jashobeam", "Captain of the first monthly division."), ("Benaiah son of Jehoiada", "Captain of a monthly division."), ("The princes of the tribes", "A leader named for each tribe."), ("Joab", "Began to number the people but did not finish."), ("Ahithophel", "The king's counsellor.")],
    themes=[("A rotating army", "Twelve divisions serve one month each, so the army is always ready but no one serves all year."), ("A leader for each tribe", "The tribes each have a named prince."), ("A warning about counting", "David did not number those under twenty, and the census brought wrath on Israel.")],
)
CH[28] = dict(
    summary="David calls together all the princes of Israel to Jerusalem and says he had it in his heart to build a house of rest for the ark, but God said he must not, because he has been a man of war and has shed blood, and God has chosen Solomon (1 Chronicles 28:1–7). David charges Israel to keep the commandments of the LORD and tells Solomon to \"know thou the God of thy father, and serve him with a perfect heart and with a willing mind\" (1 Chronicles 28:8–10). He gives Solomon the pattern for the porch, houses, rooms, courts, the courses of the priests and Levites, and the vessels of gold and silver, and says the LORD made him understand it in writing (1 Chronicles 28:11–19). He tells Solomon to be strong and of good courage and not to fear, because the LORD God will be with him until the work is done (1 Chronicles 28:20–21).",
    wwa="Chapter 27 listed David's army and officers. This chapter is David's public charge to Solomon, with the plans for the temple and the words that God will be with him. Chapter 29 shows the gifts for the temple and the end of David's reign.",
    people=[("David", "Gives a public charge and the temple plans."), ("Solomon", "The chosen builder."), ("The princes and leaders of Israel", "Gather as witnesses and helpers."), ("The priests and Levites", "Included in the plans for the house.")],
    themes=[("A chosen builder", "God chose Solomon to build the house, because David had been a man of war."), ("A willing mind", "David tells Solomon to serve God with a perfect heart, because the LORD \"searcheth all hearts.\""), ("Courage with help", "David tells Solomon that the LORD \"will not fail thee, nor forsake thee,\" until the work is finished.")],
)
CH[29] = dict(
    summary="David tells the assembly that Solomon is young and the work is great, and he gives his own treasure, and asks, \"who then is willing to consecrate his service this day unto the LORD?\" (1 Chronicles 29:1–5). The leaders offer gold, silver, bronze, iron, and precious stones, and the people rejoice because they gave willingly (1 Chronicles 29:6–9). David blesses the LORD before all, saying that all comes from him, \"of thine own have we given thee,\" and prays that Solomon will have a perfect heart (1 Chronicles 29:10–19). The people bless the LORD, offer sacrifices, eat and drink with great gladness, make Solomon king a second time, and anoint Zadok to be priest (1 Chronicles 29:20–25). David reigns forty years, seven in Hebron and thirty-three in Jerusalem, and dies in a good old age, full of days, riches, and honour, and his acts are written in the books of Samuel, Nathan, and Gad (1 Chronicles 29:26–30).",
    wwa="Chapter 28 ended with David's charge to Solomon. This chapter shows the people giving freely for the temple, David's great prayer, Solomon made king, and David's death. 2 Chronicles follows, with Solomon asking for wisdom and building the temple.",
    people=[("David", "Gives his own treasure, leads the prayer, and dies after forty years."), ("Solomon", "Made king a second time."), ("The leaders and people of Israel", "Give gladly for the house of God."), ("Zadok", "Anointed to be priest."), ("Samuel, Nathan, and Gad", "The seers whose books record David's acts.")],
    themes=[("Giving gladly", "The people \"offered willingly,\" and David rejoiced with great joy."), ("Everything is God's", "David prays, \"of thine own have we given thee.\""), ("A new king and an old king's end", "Solomon is made king, and David dies full of days, riches, and honour.")],
)


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "13_1_chronicles.json"
    data = load(path)
    for number, fields in CH.items():
        entry = data[f"1 Chronicles {number}"]
        entry["summary"] = fields["summary"]
        entry["whereWeAre"] = fields["wwa"]
        entry["keyFigures"] = [{"name": n, "role": r} for n, r in fields["people"]]
        old = entry["keyThemes"]
        refs = fields.get("refs") or [t["references"] for t in old]
        if len(fields["themes"]) != len(refs):
            raise SystemExit(f"1 Chronicles {number}: {len(fields['themes'])} themes but {len(refs)} reference lists")
        entry["keyThemes"] = [{"theme": t, "explanation": e, "references": r} for (t, e), r in zip(fields["themes"], refs)]
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


# Historical Moment = when and where. Only the template or thin entries are replaced.
MOMENTS = {
    1: "The names run from Adam to Abraham, Isaac, and Esau, across the ancient lands from Mesopotamia to Edom (1 Chronicles 1:1–54).",
    2: "The families of Judah, from Jacob's sons to David's family at Bethlehem in the hill country of Judah, in the years before David's reign (1 Chronicles 2:1–55).",
    4: "The families of Judah and Simeon in the south of the land, with Simeon's families looking for pasture in the days of Hezekiah king of Judah (1 Chronicles 4:41).",
    5: "The tribes east of the Jordan were counted in the days of Jotham of Judah and Jeroboam of Israel (1 Chronicles 5:17), until Assyria carried them away to Halah, Habor, Hara, and the river Gozan (1 Chronicles 5:26).",
    14: "In David's first years in Jerusalem, after he becomes king over all Israel, Hiram of Tyre sends builders and David beats the Philistines in the valley of Rephaim (1 Chronicles 14:1, 9–16).",
    18: "In the middle of David's reign, his wars reach from Gath and Moab in the south to Hamath and the river Euphrates in the north (1 Chronicles 18:1–13).",
    22: "Near the end of David's reign, in Jerusalem, David names the temple site and gathers materials for Solomon to build (1 Chronicles 22:1–5).",
    24: "In David's last years in Jerusalem, the priests are divided by lot into twenty-four courses before the king and the leaders (1 Chronicles 24:6–19).",
    28: "In David's last year, at Jerusalem, he calls the leaders of Israel together and gives Solomon the plans for the temple (1 Chronicles 28:1, 11).",
}

# Original Audience = who first heard it and what they knew.
AUDIENCE = {
    1: "The first readers, back from exile in Babylon, used this record to find their own families in Israel's long story. They knew that families who could not prove their line were kept from the priesthood (Ezra 2:62).",
    2: "The first readers, back from exile, knew David's family came from Judah and wanted to see how the tribe that gave Israel its kings was built. They heard that even Judah's story includes shame, as with Achar.",
    3: "The first readers knew the kings of Judah had ended in exile, and they knew Zerubbabel as the governor who led the first return (Ezra 3:2). They heard that David's line had not ended, and that some names in the list are hard to place.",
    4: "The first readers were a small community that had to make a living from the land again. They heard that one man's short prayer was answered, and that families carried on their trades and settled their towns.",
    5: "The first readers knew the eastern tribes had been carried away by Assyria and that many in Israel were scattered. They heard why: trust brought help in war, and unfaithfulness brought exile.",
    6: "The first readers included priests and Levites who traced their right to serve through these lists. They heard that worship had order and ancestors, and that the singers were part of that order from David's time.",
    7: "The first readers knew most of the northern tribes had been scattered, yet the writer still counts them as Israel. They heard that the whole people, not only Judah, belonged to the story.",
    8: "The first readers knew Benjamin, Saul's tribe, had stayed with Judah after the kingdom divided. They could trace Saul's family through Jonathan and Meribbaal for many generations (1 Chronicles 8:33–40).",
    9: "The first readers were themselves the families who had come back and settled Jerusalem, so they would look for their own names and duties here. They heard that the returned community stood in line with the faithful servants of long before.",
    10: "The first readers knew the story of Saul's reign from the book of Samuel. Here they heard only its end and the reason given for it: unfaithfulness, including asking a medium (1 Chronicles 10:13).",
    11: "The first readers heard the story of David's reign begin with all Israel together, and they longed for that unity after the exile. They knew the mighty men from 2 Samuel 23, and here the list is longer.",
    12: "The first readers knew Israel had been divided between north and south. They heard that men from every tribe once came to David with one heart, even men from Saul's own tribe.",
    13: "The first readers lived with a rebuilt temple and cared about right worship. They heard that the ark had been left alone \"in the days of Saul\" (1 Chronicles 13:3), and that careless worship could be dangerous.",
    14: "The first readers knew David as Israel's model king, and they heard that his strength came from asking God before he acted. They saw a foreign king, Hiram, help build his house.",
    15: "The first readers included Levites whose work went back to David's plans for the ark. They heard David say the first try failed because Israel \"sought him not after the due order\" (1 Chronicles 15:13).",
    16: "The first readers knew these words as the prayers of their own worship, and they heard them first sung when the ark came to Jerusalem. They heard that daily praise was part of Israel's life from David's day.",
    17: "The first readers had no king on the throne, so God's promise to David was still waiting to be fulfilled for them. They heard it repeated from 2 Samuel 7.",
    18: "The first readers lived in a small province with no king or army of their own. They heard how God once gave David wide victories, that David gave the spoil to the LORD, and that he ruled with justice.",
    19: "The first readers knew the Ammonites as an old enemy that troubled them again in their own day (Nehemiah 4:7). They heard how a kind act was met with insult, and how it led to war.",
    20: "The first readers knew the longer story in 2 Samuel, including David's sin. They heard Chronicles tell David's reign through its wins and its work for the temple.",
    21: "The first readers knew this site as the place where their own temple stood (2 Chronicles 3:1). They heard that Israel's holiest place began with a king's mistake, God's mercy, and a gift that cost something.",
    22: "The first readers had rebuilt the temple in poverty. They heard that David had stored up great riches long before, and that the LORD gave Solomon peace to build.",
    23: "The first readers knew the divisions of the Levites listed here, because they shaped temple service for centuries. They knew the families and their duties.",
    24: "The first readers included priests whose families kept this order of service. They heard that David chose the order by lot so that no family was favored.",
    25: "The first readers knew the psalms linked to Asaph, Heman, and Jeduthun (Psalm 39; 50; 73–83; 88) from their own worship. They heard that David treated music as a form of prophecy and a trained craft.",
    26: "The first readers knew a temple needs honest guards and keepers. They heard that care for dedicated gifts was a holy duty from the time of David.",
    27: "The first readers had no king or army of their own. They heard how David's kingdom was organized, month by month, and a warning about counting the people.",
    28: "The first readers were building and rebuilding the temple in a hard time. They heard David say the pattern came from the LORD, and a father charge his son to serve with a willing mind.",
}

# (chapter, note title, old text, new text) edits to cultural notes.
CULTURE = [
    (2, "Achar the troubler", "is called Achar here, ‘troubler,’ playing on", "is called Achar here, which means troubler, playing on"),
    (8, "Names with Baal", "replacing \"baal\" with \"bosheth,\" meaning ‘shame.’ \"Baal\" can also mean ‘lord’ or ‘master.’", "replacing baal with bosheth, which means shame. Baal can also mean lord or master."),
    (11, "Millo", "Millo means ‘filling,’ probably", "Millo means filling, probably"),
    (12, "Ambidextrous slingers", "Some Benjaminites could use", "Some Benjamites could use"),
]


def apply_chapter_context():
    path = ROOT / "chapter_context" / "13_1_chronicles.json"
    data = load(path)
    for number, text in AUDIENCE.items():
        data[f"1 Chronicles {number}"]["audience"] = text
    for number, title, old, new in CULTURE:
        hits = [n for n in data[f"1 Chronicles {number}"]["culture"] if n["title"] == title]
        if len(hits) != 1:
            raise SystemExit(f"1 Chronicles {number}: {len(hits)} notes titled {title!r}")
        hits[0]["text"] = replace_once(hits[0]["text"], old, new, f"1 Chronicles {number} {title}")
    spellings = [("Kirjath-jearim", "Kirjathjearim"), ("Beth-horon", "Bethhoron"), ("Jabesh-gilead", "Jabeshgilead"), ("Kiriath-jearim", "Kirjathjearim")]
    for key, entry in data.items():
        if not key.startswith("1 Chronicles"):
            continue
        for old, new in spellings:
            entry["audience"] = entry["audience"].replace(old, new)
            for note in entry["culture"]:
                note["title"] = note["title"].replace(old, new)
                note["text"] = note["text"].replace(old, new)
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_historical_moments():
    path = ROOT / "historical_moments" / "06_chronicles.json"
    data = load(path)
    for number, text in MOMENTS.items():
        data[f"1 Chronicles {number}"] = text
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_book_overview():
    path = ROOT / "book_overviews" / "03_later_history.json"
    data = load(path)
    book = data["1 Chronicles"]
    book["author"] = replace_once(
        book["author"],
        "Ezra is the traditional author, though 1 Chronicles does not name its writer.",
        "1 and 2 Chronicles were one book. Jewish tradition credits Ezra as the author, though the book does not name its writer.",
        "author",
    )
    book["audience"] = replace_once(
        book["audience"],
        "Post-exile Israel, learning its identity through David’s line, worship, and shared history.",
        "The Jews who returned from exile in Babylon, who needed to know who they were and that the LORD's promises to David still stood.",
        "audience",
    )
    book["purpose"] = replace_once(
        book["purpose"],
        "To retell Israel’s history around David’s kingdom, temple worship, and the LORD’s covenant purposes.",
        "To retell Israel's history around David's kingdom, temple worship, and the LORD's covenant purposes.",
        "purpose",
    )
    second = book["movements"][1]
    second["description"] = replace_once(
        second["description"],
        "David unites Israel, brings the ark to Jerusalem, and receives covenant promises.",
        "David unites Israel, brings the ark to Jerusalem, receives God's promise, wins his wars, and buys the threshing floor after the census.",
        "movement",
    )
    second["passages"] = ["1 Chronicles 10-21"]
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_FIXES = [
    ("His armor-bearer refuses to kill him, so Saul falls on his own sword.", "His armourbearer refuses to kill him, so Saul falls on his own sword."),
    ("” his name sounds like the Hebrew word for pain.", "” His name sounds like the Hebrew word for pain."),
    ("More than a thousand years later, Zacharias,", "About a thousand years later, Zacharias,"),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "03_later_history.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("# 1 Chronicles")
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
    apply_historical_moments()
    apply_book_overview()
    apply_story_fixes()
