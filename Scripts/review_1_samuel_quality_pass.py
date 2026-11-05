#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Full quality pass for 1 Samuel: plain summaries with outline citations, exact KJV quotes,
roles without citations, distinct Original Audience text, KJV spellings in notes and story.

Run once, after review_1_samuel.py.
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


# Each chapter: summary, wwa, people [(name, role)], themes [(title, explanation)] (references kept
# from the existing entry unless REFS overrides them).
CH = {}

CH[1] = dict(
    summary="Elkanah goes up every year to worship at Shiloh with his two wives, Hannah and Peninnah, and Peninnah makes Hannah weep because Hannah has no children (1 Samuel 1:1–8). Hannah prays at the tabernacle with bitter tears and vows to give a son to the LORD all his life, and Eli, who first thinks she is drunk, blesses her (1 Samuel 1:9–18). The LORD remembers Hannah, and she bears a son and names him Samuel (1 Samuel 1:19–20). When the boy is weaned, she brings him to Eli at Shiloh and lends him to the LORD (1 Samuel 1:21–28).",
    wwa="Ruth ended with the family line of David, and 1 Samuel opens in the days of the judges at Shiloh, where the tabernacle stands. This chapter shows Hannah, who has no children, praying for a son and giving him to the LORD. Chapter 2 gives her song of praise and shows the sins of Eli's sons.",
    people=[("Hannah", "Has no children, prays for a son with bitter tears, and gives Samuel to the LORD."), ("Elkanah", "Hannah's husband, who goes up to Shiloh every year and tries to comfort her."), ("Peninnah", "Elkanah's other wife, who makes Hannah weep."), ("Eli", "The priest who thinks Hannah is drunk, then blesses her."), ("Samuel", "The son born in answer to Hannah's prayer and lent to the LORD at Shiloh."), ("The LORD", "Remembers Hannah and gives her a son.")],
    themes=[("Praying through pain", "Hannah says she has \"poured out my soul before the LORD\" instead of hiding her sorrow."), ("Keeping a promise", "Hannah keeps her vow and gives Samuel to the LORD when he is weaned."), ("A family in pain", "Peninnah's teasing and Elkanah's loving but awkward comfort show how hard Hannah's trouble was. Elkanah asks, \"am not I better to thee than ten sons?\"")],
)
CH[2] = dict(
    summary="Hannah prays a song of praise to the LORD, who lifts up the poor and brings down the proud (1 Samuel 2:1–10). The boy Samuel serves the LORD before Eli, while Eli's sons Hophni and Phinehas take the best of the sacrifices by force (1 Samuel 2:11–17). Each year Hannah brings Samuel a little coat, and the LORD gives her three more sons and two daughters (1 Samuel 2:18–21). Eli hears how his sons sin and scolds them, but they do not listen, and a man of God tells Eli that his house will lose the priesthood and that both his sons will die on one day (1 Samuel 2:22–36).",
    wwa="Chapter 1 ended with Hannah leaving Samuel at Shiloh. This chapter opens with her song, then shows how wicked Eli's sons are while young Samuel grows in favour with the LORD. Chapter 3 tells how the LORD calls Samuel.",
    people=[("Hannah", "Sings that the LORD lifts up the poor and brings down the proud, and brings Samuel a little coat each year."), ("Samuel", "A child who serves the LORD before Eli and grows in favour with God and men."), ("Eli", "The old priest who scolds his sons but does not stop them."), ("Hophni and Phinehas", "Eli's sons, who take the best of the sacrifices and sin with the women at the tabernacle door."), ("The man of God", "Tells Eli that his house will lose the priesthood.")],
    themes=[("God lifts up the lowly", "Hannah sings that the LORD \"raiseth up the poor out of the dust.\""), ("Priests who abused their office", "Hophni and Phinehas take the best meat by force, and men \"abhorred the offering of the LORD\" because of them."), ("Honour for those who honour God", "The man of God tells Eli that the LORD says, \"them that honour me I will honour,\" and he will take the priesthood from Eli's house.")],
)
CH[3] = dict(
    summary="The word of the LORD is rare in those days, and the boy Samuel lies down to sleep near the ark of God (1 Samuel 3:1–3). The LORD calls Samuel three times, and he runs to Eli each time, until Eli tells him to answer, \"Speak, LORD; for thy servant heareth\" (1 Samuel 3:4–10). The LORD tells Samuel that he will judge Eli's house for ever, because Eli's sons made themselves vile and Eli did not stop them (1 Samuel 3:11–14). In the morning Samuel is afraid to tell Eli, but Eli makes him tell everything, and Eli says, \"It is the LORD\" (1 Samuel 3:15–18). Samuel grows, the LORD is with him, and all Israel from Dan to Beersheba knows he is a prophet of the LORD (1 Samuel 3:19–21).",
    wwa="Chapter 2 ended with a warning of judgment on Eli's house. This chapter tells how the LORD calls young Samuel at night and gives him a first message, which is that same judgment. Chapter 4 shows the judgment begin in battle.",
    people=[("Samuel", "A boy who hears the LORD call, answers, and tells Eli the whole message."), ("Eli", "Tells Samuel how to answer and accepts the message."), ("The LORD", "Calls Samuel by name and tells him he will judge Eli's house.")],
    themes=[("Learning to listen", "Samuel does not know it is the LORD calling until Eli tells him to say, \"Speak, LORD; for thy servant heareth.\""), ("Telling the truth when it hurts", "Samuel is afraid, but he tells Eli everything and hides nothing."), ("A prophet known to all Israel", "The LORD lets none of Samuel's words \"fall to the ground,\" and all Israel from Dan to Beersheba knows he is a prophet.")],
)
CH[4] = dict(
    summary="Israel loses about four thousand men to the Philistines, so the elders send to Shiloh for the ark of the covenant, and Eli's sons Hophni and Phinehas come with it (1 Samuel 4:1–4). The Philistines are afraid when they hear Israel's shout, but they fight, Israel loses thirty thousand footmen, the ark of God is taken, and Hophni and Phinehas are killed (1 Samuel 4:5–11). A man of Benjamin runs to Shiloh with his clothes torn and earth on his head, and when Eli, ninety-eight years old, hears that the ark is taken, he falls backward from his seat and his neck breaks (1 Samuel 4:12–18). Phinehas's wife bears a son as she dies and names him Ichabod, saying, \"The glory is departed from Israel\" (1 Samuel 4:19–22).",
    wwa="Chapter 3 gave Samuel's first message, that judgment would fall on Eli's house. This chapter begins to carry it out: Israel loses to the Philistines, the ark is taken, and Eli and his sons die. Chapter 5 follows the ark into the Philistine cities.",
    people=[("The elders and men of Israel", "Lose a battle, then bring the ark from Shiloh hoping it will save them."), ("The Philistines", "Are afraid when the ark comes, but fight and take it."), ("Hophni and Phinehas", "Eli's sons, who come with the ark and are killed."), ("Eli", "Ninety-eight years old, he falls backward and dies when he hears the ark is taken."), ("The man of Benjamin", "Runs to Shiloh with his clothes torn to tell the news."), ("Phinehas's wife", "Dies in childbirth and names her son Ichabod.")],
    themes=[("Treating the ark like a charm", "The elders bring the ark to win the battle, as if it could save them without the LORD."), ("The fall of Eli's house", "Hophni and Phinehas die on one day, and Eli dies when he hears the news."), ("The glory is departed", "The name Ichabod shows how the loss of the ark felt like the loss of God's presence.")],
)
CH[5] = dict(
    summary="The Philistines carry the ark of God to Ashdod and set it in the house of Dagon (1 Samuel 5:1–2). The next morning Dagon has fallen on his face before the ark, and the morning after, his head and hands are cut off on the threshold (1 Samuel 5:3–5). The hand of the LORD is heavy on Ashdod, which is struck with painful tumors, and the people send the ark to Gath and then to Ekron, where the same plague comes and the cry of the city goes up to heaven (1 Samuel 5:6–12).",
    wwa="Chapter 4 ended with the ark taken. This chapter shows the Philistines learning that the God of Israel is not beaten: Dagon falls before the ark, and plague strikes Ashdod, Gath, and Ekron. Chapter 6 tells how the ark is sent home.",
    people=[("The Philistines of Ashdod, Gath, and Ekron", "Move the ark from city to city and are struck with tumors."), ("Dagon", "The Philistine god, found fallen on his face before the ark, with his head and hands cut off."), ("The LORD", "Sends his heavy hand on the Philistine cities."), ("The lords of the Philistines", "Gather to decide what to do with the ark.")],
    themes=[("The LORD is not defeated", "Israel lost the battle, but the LORD shows his power inside the Philistine temple."), ("Dagon falls", "The idol falls before the ark twice, the second time with its head and hands cut off."), ("Fear spreads from city to city", "Ashdod, Gath, and Ekron each want the ark gone, and \"the cry of the city went up to heaven.\"")],
    refs=[["1 Samuel 5:1-5"], ["1 Samuel 5:2-5"], ["1 Samuel 5:6-12"]],
)
CH[6] = dict(
    summary="After seven months the Philistines ask their priests and diviners how to send the ark back, and they say to send an offering of five golden tumors and five golden mice (1 Samuel 6:1–9). The Philistines put the ark on a new cart pulled by two cows whose calves are shut up at home, and the cows go straight toward Bethshemesh (1 Samuel 6:10–12). The men of Bethshemesh, reaping their wheat harvest, see the ark and rejoice, and they offer the cows as a burnt offering (1 Samuel 6:13–18). But the LORD strikes the men of Bethshemesh because they looked into the ark, and the people ask the men of Kirjathjearim to come and take it (1 Samuel 6:19–21). The number of the dead in verse 19 differs in the manuscripts.",
    wwa="Chapter 5 ended with the cry of Ekron. This chapter tells how the Philistines, after seven months, send the ark home on a cart, and how it is met with joy and then with fear at Bethshemesh. Chapter 7 begins twenty years of waiting.",
    people=[("The Philistine priests and diviners", "Tell the lords to send the ark back with an offering."), ("The lords of the Philistines", "Send five golden tumors and five golden mice, and follow the cart to the border."), ("The men of Bethshemesh", "Rejoice at the ark, then are struck because they looked into it."), ("The men of Kirjathjearim", "Are asked to come and take the ark."), ("The LORD", "Strikes those who looked into the ark.")],
    themes=[("A guilt offering", "The Philistine priests say to send gold images of the plague as a trespass offering to the God of Israel."), ("A test with two cows", "If the cows leave their calves and go straight to Israel, the Philistines will know the LORD sent the plague."), ("Respect for holy things", "Joy at the ark turns to fear when men look into it.")],
)
CH[7] = dict(
    summary="The men of Kirjathjearim take the ark into the house of Abinadab and set apart his son Eleazar to keep it, and the ark stays there twenty years (1 Samuel 7:1–2). Samuel tells Israel to put away the strange gods and Ashtaroth and serve the LORD only, and they gather at Mizpeh, pour out water before the LORD, fast, and say, \"We have sinned against the LORD\" (1 Samuel 7:3–6). When the Philistines come up, Samuel offers a lamb and cries to the LORD, who thunders on the Philistines and throws them into confusion, and Israel chases them (1 Samuel 7:7–11). Samuel sets up a stone and calls it Ebenezer, saying, \"Hitherto hath the LORD helped us\" (1 Samuel 7:12–14). Samuel judges Israel all his days, going each year to Bethel, Gilgal, and Mizpeh and returning to Ramah (1 Samuel 7:15–17).",
    wwa="Chapter 6 ended with the ark sent to Kirjathjearim. This chapter tells how Israel, after twenty years, turns back to the LORD at Mizpeh, wins over the Philistines, and has Samuel as judge. Chapter 8 shows Samuel old and Israel asking for a king.",
    people=[("Samuel", "Tells Israel to put away the strange gods, prays for them at Mizpeh, and judges them."), ("Eleazar", "Abinadab's son, set apart to keep the ark."), ("The children of Israel", "Put away Baalim and Ashtaroth, fast, and confess their sin."), ("The Philistines", "Come up against Israel at Mizpeh and are thrown into confusion.")],
    themes=[("Turning back to the LORD", "Samuel says to put away the strange gods and serve the LORD only, and Israel does."), ("Prayer and rescue", "Samuel cries to the LORD, and the LORD thunders on the Philistines."), ("Remembering help", "The stone Ebenezer stands for \"Hitherto hath the LORD helped us.\"")],
)
CH[8] = dict(
    summary="When Samuel is old, he makes his sons Joel and Abiah judges at Beersheba, but they take bribes and twist justice (1 Samuel 8:1–3). The elders of Israel come to Ramah and say, \"make us a king to judge us like all the nations\" (1 Samuel 8:4–5). Samuel prays, and the LORD tells him that Israel has not rejected Samuel but has rejected the LORD, so Samuel is to listen to them but warn them (1 Samuel 8:6–9). Samuel tells them a king will take their sons and daughters, their fields, and a tenth of their crops and flocks, and they will cry out in that day (1 Samuel 8:10–18). The people refuse to listen to Samuel and say, \"Nay; but we will have a king over us,\" and the LORD tells Samuel to give them a king (1 Samuel 8:19–22).",
    wwa="Chapter 7 ended with Samuel judging Israel from Ramah. This chapter shows Samuel old, his sons corrupt, and the elders asking for a king like the other nations. Chapter 9 introduces Saul.",
    people=[("Samuel", "Prays about the elders' request and warns them what a king will do."), ("Joel and Abiah", "Samuel's sons, judges at Beersheba, who take bribes and twist justice."), ("The elders of Israel", "Ask for a king like all the nations."), ("The LORD", "Tells Samuel that Israel has rejected him, and to listen to them.")],
    themes=[("Why they asked", "Samuel's sons took bribes, and the elders wanted a king to judge them like all the nations."), ("The cost of a king", "Samuel warns that a king will take their sons, daughters, fields, and a tenth of their flocks."), ("Whom Israel trusts", "The LORD says Israel has not rejected Samuel but has rejected him, \"that I should not reign over them.\"")],
)
CH[9] = dict(
    summary="Kish, a Benjamite, has a son named Saul, \"a choice young man, and a goodly,\" and when his father's donkeys are lost, Saul and a servant go to look for them (1 Samuel 9:1–5). The servant says there is a man of God in the city, and Saul agrees to go, taking a quarter of a shekel of silver as a gift (1 Samuel 9:6–10). The day before, the LORD had told Samuel that he would send a man out of Benjamin to be captain over his people, and when Samuel sees Saul, the LORD says, \"Behold the man whom I spake to thee of!\" (1 Samuel 9:11–17). Samuel tells Saul the donkeys are found, and Saul says he is from the smallest tribe, but Samuel seats him at the head of the guests and gives him the shoulder (1 Samuel 9:18–24). Saul sleeps on Samuel's housetop, and in the morning Samuel says he will show him the word of God (1 Samuel 9:25–27).",
    wwa="Chapter 8 ended with the LORD telling Samuel to give Israel a king. This chapter tells how Saul, looking for lost donkeys, finds Samuel, who has already been told by the LORD that Saul is the man. Chapter 10 tells how Saul is anointed and chosen.",
    people=[("Saul", "Kish's son, a choice young man, who goes looking for his father's donkeys."), ("Kish", "Saul's father, a mighty man of power from Benjamin."), ("Saul's servant", "Suggests going to the man of God and offers a quarter of a shekel of silver."), ("Samuel", "Told by the LORD that Saul is the man, he feeds Saul at a feast."), ("The LORD", "Tells Samuel the day before that he will send a man of Benjamin.")],
    themes=[("God at work in an ordinary errand", "A search for lost donkeys leads Saul to the very man who has been told to look for him."), ("Honour at the feast", "Samuel gives Saul the chief place and the shoulder before telling him why he came."), ("A humble start", "Saul says he is from \"the smallest of the tribes of Israel,\" and his family is the least.")],
)
CH[10] = dict(
    summary="Samuel pours oil on Saul's head and kisses him, saying the LORD has anointed him captain over his inheritance (1 Samuel 10:1). Samuel gives him three signs, and God gives Saul another heart, and he prophesies among the prophets, so that people ask, \"Is Saul also among the prophets?\" (1 Samuel 10:2–13). Samuel calls the people to Mizpeh and reminds them that they have rejected God, and the lot falls on Benjamin, then Matri, then Kish's son Saul, who is hiding among the baggage (1 Samuel 10:17–22). When Saul stands, he is taller than any of the people, and Samuel says, \"See ye him whom the LORD hath chosen,\" and they shout, \"God save the king\" (1 Samuel 10:23–24). Samuel tells the people the rules of the kingdom and writes them in a book, and Saul goes home to Gibeah, but some worthless men despise him, and he holds his peace (1 Samuel 10:25–27).",
    wwa="Chapter 9 ended with Saul on Samuel's housetop, waiting for the word of God. This chapter tells how Samuel anoints Saul in private, gives him signs, and then the tribes choose him by lot at Mizpeh. Chapter 11 shows his first test.",
    people=[("Samuel", "Anoints Saul, gives him signs, and presents him to Israel at Mizpeh."), ("Saul", "The king chosen by lot, who hides among the baggage and holds his peace when some despise him."), ("The prophets", "A company with harp, pipe, and tabret whom Saul meets and prophesies with."), ("The tribes of Israel", "Gather at Mizpeh to see the lot cast."), ("The children of Belial", "Despise Saul and bring him no presents.")],
    themes=[("The anointing and the signs", "Samuel pours oil on Saul and gives him signs that all come true that day."), ("A public choice", "The lot falls to Benjamin, then Matri, then Saul, so all Israel sees the choice."), ("Not everyone agreed", "Some ask, \"How shall this man save us?\" and refuse him gifts, and Saul \"held his peace.\"")],
)
CH[11] = dict(
    summary="Nahash the Ammonite comes up against Jabeshgilead and says he will make a covenant only if he may put out all their right eyes (1 Samuel 11:1–2). The elders ask for seven days, and messengers bring the news to Gibeah, where the people weep aloud (1 Samuel 11:3–4). Saul comes in from the field behind the herd, and the Spirit of God comes on him; he cuts a yoke of oxen in pieces and sends the pieces through Israel, and the fear of the LORD falls on the people, so that three hundred thousand men of Israel and thirty thousand of Judah come out (1 Samuel 11:5–8). Saul divides them into three companies and strikes the Ammonites from the morning watch until the heat of the day (1 Samuel 11:9–11). Saul says, \"There shall not a man be put to death this day,\" and Samuel tells them to go to Gilgal and renew the kingdom (1 Samuel 11:12–15).",
    wwa="Chapter 10 ended with some men despising Saul. This chapter shows his first victory as king, saving Jabeshgilead from Nahash, after which the people renew the kingdom at Gilgal. Chapter 12 gives Samuel's farewell speech.",
    people=[("Saul", "Rallies Israel, wins at Jabeshgilead, and refuses to put anyone to death."), ("Nahash the Ammonite", "Besieges Jabeshgilead and asks for every man's right eye."), ("The men of Jabeshgilead", "Ask for seven days and send messengers for help."), ("Samuel", "Calls the people to Gilgal to renew the kingdom."), ("The people of Israel", "Come out with one consent when the fear of the LORD falls on them.")],
    themes=[("Rescue for a town in danger", "Saul does not leave Jabeshgilead to Nahash."), ("One people", "When the fear of the LORD falls on them, Israel comes out \"with one consent.\""), ("Mercy after the win", "Saul says no one will be put to death that day, \"for to day the LORD hath wrought salvation in Israel.\"")],
)
CH[12] = dict(
    summary="Samuel says he has walked before the people from his youth, and he asks them to testify before the LORD whether he has taken anyone's ox or donkey or cheated anyone, and they say he has not (1 Samuel 12:1–5). He reminds them how the LORD brought their fathers out of Egypt and saved them through Jerubbaal, Bedan, Jephthah, and Samuel when they forgot him (1 Samuel 12:6–11). When they saw Nahash, they said, \"Nay; but a king shall reign over us,\" though the LORD their God was their king (1 Samuel 12:12–15). Samuel calls for thunder and rain at wheat harvest, and the LORD sends it, and all the people fear the LORD and Samuel and ask him to pray for them (1 Samuel 12:16–19). Samuel says the LORD will not forsake his people, and that he will not stop praying for them, but if they still do wickedly, they and their king will be consumed (1 Samuel 12:20–25).",
    wwa="Chapter 11 ended with Saul made king again at Gilgal. This chapter gives Samuel's farewell speech: he proves his honesty, reminds Israel of the LORD's help, sends thunder in harvest, and promises to keep praying for them. Chapter 13 shows Saul's first big failure.",
    people=[("Samuel", "Gives his farewell speech, asks for witnesses to his honesty, and says he will not stop praying for them."), ("The people of Israel", "Say Samuel has taken nothing, then confess they sinned in asking for a king."), ("The LORD", "Sends thunder and rain at wheat harvest and will not forsake his people for his great name's sake.")],
    themes=[("An honest leader", "Samuel asks the people to say if he has taken any man's ox or donkey, and they say he has not."), ("The covenant still stands", "A king does not replace obeying the LORD, for if Israel does wickedly, they will be consumed, \"both ye and your king.\""), ("Praying and teaching", "Samuel says he will not stop praying for them and will teach them \"the good and the right way.\"")],
)
CH[13] = dict(
    summary="Saul chooses three thousand men, and his son Jonathan strikes the Philistine garrison at Geba, so the Philistines gather with thirty thousand chariots and six thousand horsemen (1 Samuel 13:1–5). The men of Israel see they are in trouble and hide in caves, thickets, rocks, and pits, while Saul waits at Gilgal and the people follow him trembling (1 Samuel 13:6–7). Saul waits seven days for Samuel, but when the people scatter, he offers the burnt offering himself (1 Samuel 13:8–10). Samuel comes and says, \"Thou hast done foolishly,\" and tells Saul his kingdom will not continue, because the LORD has sought a man after his own heart (1 Samuel 13:11–14). Saul counts only about six hundred men, and there is no smith in all Israel, so only Saul and Jonathan have a sword or spear (1 Samuel 13:15–22). The verse about Saul's age and years (13:1) is unclear in the Hebrew.",
    wwa="Chapter 12 ended with Samuel's warning to Israel and their king. This chapter shows Saul facing a huge Philistine army, losing his men, and offering the sacrifice himself because Samuel is late, so Samuel says his kingdom will not last. Chapter 14 tells of Jonathan's bold attack.",
    people=[("Saul", "Waits for Samuel, then offers the burnt offering himself."), ("Jonathan", "Strikes the Philistine garrison at Geba."), ("Samuel", "Arrives after the offering and tells Saul he has done foolishly."), ("The Philistines", "Gather with chariots and horsemen and keep Israel without smiths."), ("The people of Israel", "Hide in caves and thickets, or follow Saul trembling.")],
    themes=[("Pressure and obedience", "Saul sees his army scattering and does not wait, though Samuel had told him to."), ("An army that melts away", "Israel's men hide in caves, thickets, rocks, high places, and pits."), ("No weapons", "There is no smith in Israel, so the people go to the Philistines to sharpen their tools.")],
)
CH[14] = dict(
    summary="Jonathan tells his armourbearer they will go over to the Philistine garrison, because \"there is no restraint to the LORD to save by many or by few\" (1 Samuel 14:1–7). They climb up between two rocks and kill about twenty men, an earthquake comes, and the Philistine army melts away in panic (1 Samuel 14:8–16). Saul and the people join the battle, every man's sword is against his fellow, and the Hebrews who were with the Philistines turn to Israel (1 Samuel 14:17–23). Saul has made the people swear not to eat until evening, and Jonathan, who did not hear it, eats honey, and the faint people later eat meat with the blood (1 Samuel 14:24–35). When God does not answer, Saul casts lots and it falls on Jonathan, and Saul says he must die, but the people say, \"there shall not one hair of his head fall to the ground,\" and they rescue him (1 Samuel 14:36–46). Saul fights all his enemies, and the chapter lists his sons, his daughters Merab and Michal, and his captain Abner (1 Samuel 14:47–52).",
    wwa="Chapter 13 ended with Israel having no weapons. This chapter tells how Jonathan and his armourbearer start a great rout of the Philistines, how Saul's rash oath nearly costs Jonathan his life, and how the people save him. Chapter 15 gives the war with Amalek.",
    people=[("Jonathan", "Attacks the garrison with his armourbearer, eats honey without knowing about the oath, and is rescued by the people."), ("Jonathan's armourbearer", "Promises to follow Jonathan and climbs the rocks after him."), ("Saul", "Joins the chase and makes a rash oath that nearly costs his own son's life."), ("The people of Israel", "Grow faint, eat meat with the blood, and stop Saul from killing Jonathan."), ("The Philistines", "Melt away in panic and strike each other with swords.")],
    themes=[("Courage with few men", "Jonathan says, \"there is no restraint to the LORD to save by many or by few.\""), ("A rash oath", "Saul's curse on anyone who eats before evening leaves the people faint and leads them to break the law."), ("The people speak up", "They will not let Jonathan die, for \"he hath wrought with God this day.\"")],
)
CH[15] = dict(
    summary="Samuel tells Saul that the LORD has sent him to strike Amalek and destroy everything they have, because of what Amalek did to Israel on the way from Egypt (1 Samuel 15:1–3). Saul gathers two hundred thousand footmen and ten thousand men of Judah and defeats the Amalekites, but he spares King Agag and the best of the sheep and oxen (1 Samuel 15:4–9). The LORD tells Samuel, \"It repenteth me that I have set up Saul to be king,\" and Samuel cries to the LORD all night (1 Samuel 15:10–11). Samuel finds Saul at Gilgal, and Saul says he has done what the LORD commanded, but Samuel asks, \"What meaneth then this bleating of the sheep in mine ears,\" and Saul blames the people (1 Samuel 15:12–21). Samuel says, \"to obey is better than sacrifice,\" and because Saul rejected the word of the LORD, the LORD has rejected him from being king (1 Samuel 15:22–23). Saul says, \"I have sinned,\" and grabs Samuel's robe so that it tears, and Samuel says the LORD has torn the kingdom from him this day (1 Samuel 15:24–29). Samuel cuts Agag in pieces before the LORD at Gilgal, goes to Ramah, and never sees Saul again, though he mourns for him (1 Samuel 15:30–35).",
    wwa="Chapter 14 ended with Saul's wars and his family. This chapter tells how the LORD sends Saul against Amalek, how Saul keeps back Agag and the best of the flocks, and how Samuel tells him the LORD has rejected him as king. Chapter 16 turns to David.",
    people=[("Samuel", "Gives the command, confronts Saul, and cuts Agag in pieces."), ("Saul", "Spares Agag and the best animals, blames the people, and says, \"I have sinned.\""), ("Agag", "The king of the Amalekites, spared and then put to death."), ("The Amalekites", "The people Saul was sent to destroy because of what they did to Israel on the way."), ("The LORD", "Says, \"It repenteth me that I have set up Saul to be king.\"")],
    themes=[("To obey is better than sacrifice", "Saul says the people kept the best animals for sacrifice, but Samuel says the LORD wants obedience."), ("Excuses", "Saul says he has done what the LORD commanded, then blames the people when Samuel hears the sheep bleating."), ("The kingdom torn away", "Saul grabs Samuel's robe and it tears, and Samuel says the LORD has torn the kingdom from him.")],
)
CH[16] = dict(
    summary="The LORD tells Samuel to stop mourning for Saul, fill his horn with oil, and go to Jesse the Bethlehemite, because the LORD has \"provided me a king among his sons\" (1 Samuel 16:1–5). Samuel sees Eliab and thinks he is the one, but the LORD says, \"the LORD looketh on the heart\" (1 Samuel 16:6–10). Seven sons pass by, and the youngest, David, is keeping the sheep; when he comes in, ruddy and handsome, the LORD says, \"Arise, anoint him: for this is he,\" and the Spirit of the LORD comes on David from that day (1 Samuel 16:11–13). The Spirit of the LORD leaves Saul, and an evil spirit from the LORD troubles him, so his servants say to find a man who can play the harp (1 Samuel 16:14–18). David comes to Saul, and Saul loves him and makes him his armourbearer, and when David plays, Saul is refreshed and the evil spirit leaves him (1 Samuel 16:19–23).",
    wwa="Chapter 15 ended with Samuel mourning for Saul. This chapter tells how the LORD sends Samuel to Bethlehem to anoint David, the youngest son of Jesse, while the Spirit of the LORD leaves Saul and David comes to play the harp for him. Chapter 17 tells how David meets Goliath.",
    people=[("Samuel", "Goes to Bethlehem, looks over Jesse's sons, and anoints David."), ("Jesse", "A Bethlehemite who brings his sons before Samuel and later sends David to Saul with gifts."), ("David", "The youngest son, keeping sheep, who is anointed by Samuel and then called to play the harp for Saul."), ("Eliab and Jesse's other sons", "Seven sons pass before Samuel, and the LORD chooses none of them."), ("Saul", "Troubled by an evil spirit from the LORD, he loves David and is refreshed by his harp."), ("The LORD", "Looks on the heart and chooses David.")],
    themes=[("The LORD looks on the heart", "Samuel judges by looks, but the LORD says, \"the LORD seeth not as man seeth.\""), ("The youngest is chosen", "David is not even called in until the other sons have passed by."), ("Serving in the king's house", "David enters Saul's service as a harp player and armourbearer before he is king.")],
)
CH[17] = dict(
    summary="The Philistines gather at Shochoh, and Saul and Israel camp in the valley of Elah, where Goliath of Gath, whose height is six cubits and a span, comes out and challenges Israel for forty days (1 Samuel 17:1–11, 16). Jesse sends David with grain and loaves to his three oldest brothers, and David hears Goliath and asks, \"who is this uncircumcised Philistine, that he should defy the armies of the living God?\" (1 Samuel 17:12–30). David tells Saul he has killed a lion and a bear, and that the LORD who saved him from them will save him from this Philistine, and Saul says, \"Go, and the LORD be with thee\" (1 Samuel 17:31–37). David refuses Saul's armour, takes five smooth stones from the brook, and goes out with his sling, saying he comes in the name of the LORD of hosts (1 Samuel 17:38–47). David slings a stone that sinks into Goliath's forehead, and then cuts off his head with Goliath's own sword, and the Philistines flee (1 Samuel 17:48–54). Abner brings David to Saul, who asks whose son he is, and David says he is the son of Jesse the Bethlehemite (1 Samuel 17:55–58). Some manuscripts have a shorter chapter, and Goliath's height differs in them.",
    wwa="Chapter 16 ended with David serving Saul with his harp. This chapter tells how David goes to the army with food for his brothers, hears Goliath's challenge, and kills him with a sling and a stone in the name of the LORD. Chapter 18 shows what David's win leads to.",
    people=[("David", "A shepherd who brings food to his brothers and kills Goliath with a stone."), ("Goliath", "The Philistine champion of Gath who defies the armies of the living God."), ("Saul", "Says David is only a youth, then lets him go and arms him."), ("Eliab and David's brothers", "Soldiers in the army, where Eliab is angry at David."), ("Jesse", "Sends David with grain and loaves to his brothers."), ("Abner", "Saul's captain, who brings David before the king.")],
    themes=[("Trust from past rescue", "David says the LORD who saved him from the lion and the bear will save him from Goliath."), ("Not armour but trust", "David puts off Saul's armour and goes in the name of the LORD of hosts."), ("The battle is the LORD's", "David says all the people will know that \"the LORD saveth not with sword and spear.\"")],
)
CH[18] = dict(
    summary="The soul of Jonathan is \"knit with the soul of David,\" and Jonathan loves him as his own soul and makes a covenant with him, giving him his robe, his garments, his sword, his bow, and his girdle (1 Samuel 18:1–4). David behaves himself wisely and Saul sets him over the men of war, but when the women sing, \"Saul hath slain his thousands, and David his ten thousands,\" Saul is angry and watches David closely from that day (1 Samuel 18:5–9). The next day an evil spirit comes on Saul, and he throws a javelin at David twice, but David escapes, and Saul is afraid of him because the LORD is with David (1 Samuel 18:10–16). Saul offers his daughter Merab, then gives her to another man, and Michal loves David, and Saul asks a hundred Philistine foreskins as her price, hoping David will fall by their hand (1 Samuel 18:17–25). David kills two hundred, Saul gives him Michal, and Saul grows even more afraid and becomes David's enemy for good (1 Samuel 18:26–30).",
    wwa="Chapter 17 ended with David before Saul with Goliath's head. This chapter shows Jonathan's love for David, the women's song that makes Saul jealous, and Saul's plots to have David killed. Chapter 19 tells how Saul openly tries to kill him.",
    people=[("David", "Behaves wisely, wins battles, and marries Michal after bringing two hundred foreskins."), ("Jonathan", "Loves David as his own soul and gives him his robe, sword, bow, and girdle."), ("Saul", "Grows jealous and afraid, throws a javelin, and sets traps for David."), ("Michal", "Saul's daughter, who loves David and becomes his wife."), ("Merab", "Saul's older daughter, first offered to David and then given to Adriel.")],
    themes=[("A faithful friend", "Jonathan makes a covenant with David and gives him the robe he was wearing."), ("Jealousy", "The women's song about David's ten thousands makes Saul angry and afraid."), ("Plots dressed as honour", "Saul offers his daughters hoping the Philistines will kill David.")],
)
CH[19] = dict(
    summary="Saul tells Jonathan and his servants to kill David, but Jonathan warns David to hide and speaks well of him to his father, and Saul swears, \"As the LORD liveth, he shall not be slain\" (1 Samuel 19:1–7). War breaks out again, David defeats the Philistines, and an evil spirit from the LORD comes on Saul, who throws a javelin at David, but David flees (1 Samuel 19:8–10). Saul sends messengers to David's house, but Michal lets him down through a window and puts an image in the bed, saying he is sick (1 Samuel 19:11–17). David flees to Samuel at Ramah, and Saul's messengers prophesy, and so do the second and third groups, and Saul himself goes and prophesies, stripped of his clothes, all that day and night (1 Samuel 19:18–24).",
    wwa="Chapter 18 ended with Saul fearing David more. This chapter shows Saul trying again and again to kill David, and Jonathan, Michal, and Samuel each helping David escape. Chapter 20 tells of the covenant between David and Jonathan.",
    people=[("David", "Escapes the javelin, flees through a window, and goes to Samuel at Ramah."), ("Saul", "Tries to kill David and ends up prophesying stripped of his clothes."), ("Jonathan", "Warns David and speaks well of him to Saul."), ("Michal", "Lets David down through a window and puts an image in his bed."), ("Samuel", "Receives David at Naioth in Ramah."), ("Saul's messengers", "Come to take David and prophesy instead.")],
    themes=[("A son who speaks up", "Jonathan tells his father not to sin against David, \"because he hath not sinned against thee.\""), ("A wife who takes a risk", "Michal helps David escape and tells her father's men that David is sick."), ("The LORD stops the men", "Messengers sent to take David begin to prophesy instead.")],
)
CH[20] = dict(
    summary="David asks Jonathan what he has done that Saul wants to kill him, and Jonathan promises to do whatever David asks, and they agree that David will hide in the field while Jonathan tests his father at the new moon feast (1 Samuel 20:1–23). David's place is empty for two days, and when Jonathan speaks up for him, Saul becomes angry and throws a javelin at Jonathan, and Jonathan knows his father means to kill David (1 Samuel 20:24–34). In the morning Jonathan goes into the field and shoots arrows beyond the boy, and cries, \"Is not the arrow beyond thee?\" (1 Samuel 20:35–40). David comes out and bows three times, and the two kiss each other and weep, and Jonathan says, \"Go in peace\" (1 Samuel 20:41–42).",
    wwa="Chapter 19 ended with David at Naioth in Ramah. This chapter tells how David and Jonathan renew their covenant, test Saul at the new moon feast, learn he means to kill David, and part in tears. Chapter 21 follows David as a fugitive.",
    people=[("David", "Hides in the field and says there is but a step between him and death."), ("Jonathan", "Tests his father and warns David with arrows."), ("Saul", "Is angry at the empty seat and throws a javelin at his own son."), ("The lad", "Gathers the arrows without knowing what the signal means.")],
    themes=[("Covenant friendship", "Jonathan and David promise kindness to each other and to each other's families for ever."), ("Testing the truth", "Jonathan arranges a way to learn his father's mind instead of guessing."), ("Loyalty that costs", "Jonathan sides with David even though it makes his father angry.")],
)
CH[21] = dict(
    summary="David comes to Ahimelech the priest at Nob, who is afraid, and David says the king has sent him on a business, and Ahimelech gives him the holy bread because there is no common bread (1 Samuel 21:1–6). Doeg the Edomite, chief of Saul's herdmen, is there that day, and David takes the sword of Goliath, which is wrapped in a cloth behind the ephod (1 Samuel 21:7–9). David flees to Achish king of Gath, whose servants say, \"Is not this David the king of the land?\" and David is afraid (1 Samuel 21:10–12). David changes how he acts, scratches on the doors of the gate, and lets spit run down his beard, and Achish says, \"Have I need of mad men\" (1 Samuel 21:13–15).",
    wwa="Chapter 20 ended with David and Jonathan parting. This chapter shows David fleeing alone, eating the holy bread at Nob, taking Goliath's sword, and acting mad before Achish king of Gath. Chapter 22 tells where David goes next.",
    people=[("David", "Hungry and without a weapon, he eats the holy bread, takes Goliath's sword, and pretends to be mad at Gath."), ("Ahimelech", "The priest at Nob, who is afraid and gives David the holy bread and the sword."), ("Doeg the Edomite", "Saul's chief herdman, who is there that day."), ("Achish", "King of Gath, who sends David away as a madman.")],
    themes=[("Holy bread for a hungry man", "Ahimelech gives David the holy bread because there is no other."), ("Fear and a quick plan", "David is \"sore afraid\" of Achish and acts like a madman to escape."), ("A false story", "David tells Ahimelech the king sent him, which was not true, and the book does not praise it.")],
)
CH[22] = dict(
    summary="David escapes to the cave of Adullam, and his brothers and his father's house come to him, and everyone in distress, in debt, or unhappy, about four hundred men, gathers to him (1 Samuel 22:1–2). David takes his father and mother to the king of Moab, and the prophet Gad tells him to go into the land of Judah (1 Samuel 22:3–5). Saul, sitting under a tree in Ramah, complains that none of his servants tells him his son has made a league with David, and Doeg the Edomite says he saw David come to Ahimelech (1 Samuel 22:6–10). Saul sends for Ahimelech and all the priests of Nob and says, \"Thou shalt surely die,\" and his servants will not touch the priests, but Doeg kills eighty-five men who wear a linen ephod and strikes down Nob (1 Samuel 22:11–19). Abiathar escapes to David, and David says he is to blame for the death of all his father's house, and tells him, \"Abide thou with me, fear not\" (1 Samuel 22:20–23).",
    wwa="Chapter 21 ended with David escaping from Gath. This chapter tells how David gathers four hundred men at Adullam, and how Saul, hearing from Doeg, has the priests of Nob killed. Chapter 23 shows David still on the run.",
    people=[("David", "Hides at Adullam, leads a band of four hundred, and takes Abiathar in."), ("Saul", "Accuses the priests of helping David and orders them killed."), ("Doeg the Edomite", "Tells Saul about Ahimelech and kills the priests when Saul's servants will not."), ("Ahimelech", "The priest of Nob, who says David is the king's faithful son-in-law."), ("Abiathar", "Ahimelech's son, who alone escapes and flees to David."), ("The men gathered to David", "Those in distress, in debt, and unhappy, about four hundred.")],
    themes=[("Saul's cruel command", "Saul has eighty-five priests killed and the city of Nob struck down."), ("A refuge for the troubled", "Those in distress, in debt, or unhappy gather to David at Adullam."), ("David takes the blame", "David says he is to blame for the death of the priests' house and promises Abiathar safe keeping.")],
)
CH[23] = dict(
    summary="David hears that the Philistines are fighting against Keilah and robbing the threshing floors, and he asks the LORD, who says, \"Go, and smite the Philistines,\" and David saves Keilah (1 Samuel 23:1–5). Saul hears and says God has delivered David into his hand, and David asks the LORD through Abiathar's ephod and learns that the men of Keilah will give him up, so David and his six hundred men leave (1 Samuel 23:6–13). David stays in the wilderness of Ziph, and Jonathan goes to him and strengthens his hand in God, saying, \"thou shalt be king over Israel, and I shall be next unto thee\" (1 Samuel 23:14–18). The Ziphites tell Saul where David is, and Saul comes after him in the wilderness of Maon, but a messenger says the Philistines have invaded the land, and Saul turns back, and David goes up to the strongholds at Engedi (1 Samuel 23:19–29).",
    wwa="Chapter 22 ended with David taking Abiathar in. This chapter shows David saving Keilah, learning by the ephod that Keilah will give him up, meeting Jonathan one last time, and slipping away from Saul in the wilderness. Chapter 24 tells how David spares Saul.",
    people=[("David", "Saves Keilah, asks the LORD twice, and moves from place to place with six hundred men."), ("Abiathar", "The priest who brings the ephod to David."), ("Saul", "Plans to trap David at Keilah and chases him in the wilderness."), ("Jonathan", "Goes to David and strengthens his hand in God."), ("The Ziphites", "Tell Saul where David is hiding."), ("The Philistines", "Raid Keilah and later invade the land, so Saul must stop.")],
    themes=[("Asking the LORD first", "David asks the LORD before he goes to Keilah and again before he leaves."), ("Not safe even among friends", "The men of Keilah would have given David up, so he cannot stay."), ("A friend's last visit", "Jonathan tells David, \"Fear not: for the hand of Saul my father shall not find thee.\"")],
)
CH[24] = dict(
    summary="Saul takes three thousand chosen men to look for David in the wilderness of Engedi, and goes into a cave to relieve himself, where David and his men are hiding (1 Samuel 24:1–3). David's men say this is the day the LORD promised, and David quietly cuts off the corner of Saul's robe, but his heart troubles him, and he says, \"The LORD forbid that I should do this thing unto my master, the LORD'S anointed\" (1 Samuel 24:4–7). David goes out of the cave and calls after Saul, \"My lord the king,\" and shows him the corner of the robe, and says, \"The LORD judge between me and thee\" (1 Samuel 24:8–15). Saul lifts up his voice and weeps, and says, \"Thou art more righteous than I,\" and \"I know well that thou shalt surely be king\" (1 Samuel 24:16–20). Saul asks David to swear not to wipe out his family, and David swears, and Saul goes home while David goes up to the stronghold (1 Samuel 24:21–22).",
    wwa="Chapter 23 ended with David going up to the strongholds of Engedi. This chapter tells how Saul walks into the very cave where David is hiding, and David spares his life and cuts only his robe, so that Saul weeps and admits David will be king. Chapter 25 opens with Samuel's death and turns to Abigail.",
    people=[("David", "Cuts the corner of Saul's robe but will not kill the LORD'S anointed."), ("Saul", "Enters the cave, then weeps and says David is more righteous than he."), ("David's men", "Tell David this is the day the LORD has given his enemy into his hand.")],
    themes=[("Mercy instead of revenge", "David could have killed Saul, but says he will not put out his hand against one who is \"the LORD'S anointed.\""), ("An honest appeal", "David shows the corner of the robe as proof and asks the LORD to judge between them."), ("Saul sees clearly for a moment", "Saul says he knows David will be king and asks David to spare his family.")],
)
CH[25] = dict(
    summary="Samuel dies, and all Israel gathers and mourns him and buries him at Ramah (1 Samuel 25:1). In Maon there is a man named Nabal, very rich and \"churlish,\" who is shearing his sheep at Carmel, and David sends ten young men to greet him and ask for food, but Nabal answers, \"Who is David?\" and sends them away (1 Samuel 25:2–13). A servant tells Abigail, who takes two hundred loaves, two bottles of wine, five sheep, parched grain, raisins, and figs, and rides out to meet David without telling Nabal (1 Samuel 25:14–20). David has sworn to kill every male of Nabal's house, but Abigail falls at his feet and takes the blame, and David says, \"Blessed be the LORD God of Israel, which sent thee this day to meet me\" (1 Samuel 25:21–35). Abigail finds Nabal feasting and drunk, and in the morning when she tells him, his heart dies within him, and about ten days later the LORD strikes him and he dies (1 Samuel 25:36–38). David takes Abigail as his wife, and also Ahinoam of Jezreel, but Saul has given Michal to Phalti (1 Samuel 25:39–44).",
    wwa="Chapter 24 ended with Saul going home. This chapter opens with the death of Samuel, then shows David nearly killing Nabal's whole house in anger until Abigail stops him, and ends with David marrying her. Chapter 26 tells how David spares Saul a second time.",
    people=[("Abigail", "A woman of good understanding who brings food to David and stops him before he sheds blood."), ("David", "Is angry at Nabal and sets out with four hundred men, then thanks Abigail."), ("Nabal", "A rich and churlish man who insults David's young men and dies ten days after his heart fails him."), ("David's young men", "Greet Nabal and ask for food."), ("A servant of Nabal", "Tells Abigail what has happened."), ("The LORD", "Strikes Nabal and keeps David from avenging himself.")],
    themes=[("A peacemaker steps in", "Abigail rides out with food and meets David before he reaches her husband's house."), ("Anger that goes too far", "Nabal's insult makes David swear to kill every man in his house."), ("Kept from shedding blood", "David tells Abigail, \"blessed be thou, which hast kept me this day from coming to shed blood.\"")],
)
CH[26] = dict(
    summary="The Ziphites tell Saul that David is hiding on the hill of Hachilah, and Saul goes down with three thousand chosen men (1 Samuel 26:1–5). David and Abishai go down to the camp by night, and Saul lies sleeping inside the camp with his spear stuck in the ground at his head, and a deep sleep from the LORD has fallen on them all (1 Samuel 26:6–12). Abishai says God has delivered David's enemy into his hand, but David says, \"Destroy him not: for who can stretch forth his hand against the LORD'S anointed, and be guiltless?\" and takes the spear and the jar of water (1 Samuel 26:8–12). David cries from the top of a hill to Abner and Saul and shows the spear, and Saul says, \"I have sinned\" (1 Samuel 26:13–21). David tells a young man to come and get the spear, and Saul says, \"Blessed be thou, my son David\" (1 Samuel 26:22–25).",
    wwa="Chapter 25 ended with David's new wives. This chapter tells how Saul again hunts David, and David again spares him, taking only his spear and water jar. Chapter 27 shows David leaving Israel.",
    people=[("David", "Goes into Saul's camp at night and takes the spear but will not harm the LORD'S anointed."), ("Abishai", "Offers to strike Saul with one stroke."), ("Saul", "Comes with three thousand men, then says, \"I have sinned.\""), ("Abner", "Saul's captain, whom David mocks for not guarding the king."), ("The Ziphites", "Tell Saul where David is.")],
    themes=[("The same choice again", "David again will not take the life of the LORD'S anointed, though Abishai urges it."), ("Who guards the king", "David tells Abner he deserves to die for not keeping watch over his master."), ("Leaving the matter with the LORD", "David says, \"The LORD render to every man his righteousness and his faithfulness.\"")],
)
CH[27] = dict(
    summary="David says in his heart, \"I shall now perish one day by the hand of Saul,\" and he and his six hundred men and their households go over to Achish king of Gath (1 Samuel 27:1–3). Saul hears that David has fled to Gath and stops looking for him (1 Samuel 27:4). Achish gives David Ziklag, where he lives a year and four months (1 Samuel 27:5–7). David and his men raid the Geshurites, the Gezrites, and the Amalekites and leave no man or woman alive, but he tells Achish he has raided the south of Judah (1 Samuel 27:8–10). Achish believes David and says, \"he shall be my servant for ever\" (1 Samuel 27:11–12). The chapter reports the killing and the lie without praising David for them.",
    wwa="Chapter 26 ended with Saul blessing David. This chapter tells how David, still afraid of Saul, goes to live among the Philistines at Ziklag, where he raids Israel's old enemies and tells Achish a false story. Chapter 28 shows Saul facing the Philistines.",
    people=[("David", "Goes to Gath with six hundred men, lives at Ziklag, and raids the Geshurites, Gezrites, and Amalekites."), ("Achish", "King of Gath, who gives David Ziklag and believes his story."), ("David's men and their households", "Go with him to Gath and Ziklag.")],
    themes=[("Fear drives a hard choice", "David says he will perish by Saul's hand and goes to the Philistines."), ("Killing and lying", "David leaves no one alive to tell Achish where he really raided."), ("Living under a Philistine king", "Achish gives David a town in return for his service.")],
)
CH[28] = dict(
    summary="The Philistines gather to fight Israel, and Achish tells David he must go out with him to battle (1 Samuel 28:1–2). Samuel is dead, and Saul has put the mediums and wizards out of the land (1 Samuel 28:3). When Saul sees the Philistine army at Shunem, he is afraid, and he asks the LORD, but the LORD does not answer him by dreams, by Urim, or by prophets (1 Samuel 28:4–6). Saul disguises himself and goes at night to a woman at Endor who has a familiar spirit, and asks her to bring up Samuel (1 Samuel 28:7–14). Samuel says, \"Why hast thou disquieted me, to bring me up?\" and tells Saul that the LORD has torn the kingdom from him because he did not obey the LORD against Amalek, and that tomorrow Saul and his sons will be with him (1 Samuel 28:15–19). Saul falls full length on the ground, and the woman and his servants urge him to eat, and the woman kills a fatted calf and bakes bread, and Saul goes away that night (1 Samuel 28:20–25).",
    wwa="Chapter 27 ended with David at Ziklag. This chapter shows the Philistines gathering for war, Saul afraid and answered by no one, and a visit to the woman at Endor, where Saul is told he will die. Chapter 29 shows David sent away from the Philistine army.",
    people=[("Saul", "Afraid of the Philistines, he goes in disguise to the woman at Endor."), ("The woman of Endor", "A woman with a familiar spirit, who brings up the one Saul asks for."), ("Samuel", "Appears and tells Saul the LORD has torn the kingdom from him."), ("The Philistines", "Gather at Shunem to fight Israel."), ("Saul's servants", "Go with Saul and urge him to eat."), ("Achish", "Tells David he must go to battle with him.")],
    themes=[("Fear and silence", "Saul is afraid, and the LORD does not answer him by dreams, \"nor by Urim, nor by prophets.\""), ("Breaking his own rule", "Saul had put out those with familiar spirits, yet he looks for one."), ("The old message again", "Samuel repeats that the kingdom is torn from Saul and that he and his sons will die the next day.")],
)
CH[29] = dict(
    summary="The Philistines gather at Aphek, and the Israelites camp by a fountain in Jezreel, and the lords of the Philistines pass on by hundreds and by thousands, with David and his men in the rear with Achish (1 Samuel 29:1–2). The princes of the Philistines ask, \"What do these Hebrews here?\" and Achish says he has found no fault in David since he came (1 Samuel 29:3). The princes are angry and say, \"Make this fellow return,\" in case he turns against them in the battle, and they remind Achish of the song, \"Saul slew his thousands, and David his ten thousands\" (1 Samuel 29:4–5). Achish tells David he has been upright, but the lords do not favour him, and David asks, \"what have I done?\" but he must go back (1 Samuel 29:6–10). David and his men rise early and go back to the land of the Philistines, and the Philistines go up to Jezreel (1 Samuel 29:11).",
    wwa="Chapter 28 ended with Saul's night at Endor. This chapter tells how the Philistine princes will not let David fight beside them, so he is sent back to Ziklag and spared from going against Israel. Chapter 30 tells what he finds there.",
    people=[("David", "Marches in the rear with Achish, then is sent back."), ("Achish", "Says David has been upright but must go back because the lords do not favour him."), ("The princes of the Philistines", "Fear David may turn on them in battle and demand he be sent back."), ("The Israelites", "Camp by a fountain in Jezreel.")],
    themes=[("Who can be trusted", "The Philistine princes ask, \"Is not this David?\" and fear he will turn on them."), ("A friend who cannot overrule his lords", "Achish speaks well of David, but he cannot go against the other princes."), ("David's heart is not told", "The chapter does not say what David would have done in the battle.")],
)
CH[30] = dict(
    summary="On the third day David and his men come to Ziklag and find that the Amalekites have burned it and taken the women captive, including David's two wives, and David and his people weep until they have no more power to weep (1 Samuel 30:1–5). David is greatly distressed, because the people talk of stoning him, but David \"encouraged himself in the LORD his God\" (1 Samuel 30:6). David asks the LORD through Abiathar's ephod, and the LORD says, \"Pursue: for thou shalt surely overtake them, and without fail recover all\" (1 Samuel 30:7–10). At the brook Besor two hundred men are too faint to go on, and in a field they find an Egyptian who has had no food for three days, and he leads David to the Amalekites (1 Samuel 30:9–16). David strikes them from twilight until the evening of the next day, and only four hundred young men on camels escape, and David recovers everything (1 Samuel 30:17–20). When some wicked men do not want to share with the two hundred, David says all will share alike, and he sends gifts to the elders of Judah (1 Samuel 30:21–31).",
    wwa="Chapter 29 ended with David sent back to Ziklag. This chapter tells how he finds the town burned and his family gone, asks the LORD, chases the Amalekites, recovers everything, and shares the spoil with all. Chapter 31 turns back to Saul's last battle.",
    people=[("David", "Strengthens himself in the LORD, chases the raiders, and says all shall share alike."), ("Abiathar", "The priest who brings the ephod for David to ask the LORD."), ("The Amalekites", "Burn Ziklag and carry off the families."), ("The Egyptian servant", "Left sick by his master, he leads David to the raiders."), ("David's six hundred men", "Weep over their loss, then follow David, though two hundred stay at Besor."), ("The elders of Judah", "Receive a gift from the spoil.")],
    themes=[("Strength in the LORD", "When his men talk of stoning him, David \"encouraged himself in the LORD his God.\""), ("Kindness to a stranger", "David feeds the sick Egyptian, who then guides him to the camp."), ("Fair shares", "David says those who stay with the baggage shall share alike with those who fight, and it becomes a rule in Israel.")],
)
CH[31] = dict(
    summary="The Philistines fight against Israel, and the men of Israel flee, and Saul's sons Jonathan, Abinadab, and Melchishua are killed on mount Gilboa (1 Samuel 31:1–2). The archers hit Saul, and he asks his armourbearer to draw his sword and thrust him through, so the uncircumcised will not abuse him, but the armourbearer is afraid, so Saul takes a sword and falls on it (1 Samuel 31:3–5). The armourbearer sees that Saul is dead and falls on his sword and dies with him, so Saul, his three sons, and his armourbearer die the same day (1 Samuel 31:5–6). The men of Israel leave their cities and the Philistines move into them, and the next day the Philistines cut off Saul's head, put his armour in the house of Ashtaroth, and fasten his body to the wall of Bethshan (1 Samuel 31:7–10). The valiant men of Jabeshgilead go all night, take the bodies from the wall, burn them, bury the bones under a tree, and fast seven days (1 Samuel 31:11–13).",
    wwa="Chapter 30 ended with David sharing the spoil. This chapter tells how Saul and his three sons die on mount Gilboa, how the Philistines hang their bodies at Bethshan, and how the men of Jabeshgilead bury them. 2 Samuel follows, with David hearing the news.",
    people=[("Saul", "Is hit by the archers and falls on his own sword."), ("Jonathan, Abinadab, and Melchishua", "Saul's sons, killed at Gilboa."), ("The Philistines", "Defeat Israel and fasten Saul's body to the wall of Bethshan."), ("Saul's armourbearer", "Will not kill Saul, then falls on his own sword."), ("The men of Jabeshgilead", "Take the bodies, bury the bones, and fast seven days.")],
    themes=[("The cost of war", "Saul, three of his sons, and his armourbearer all die on one day, and Israel flees from its cities."), ("Shame and honour", "The Philistines fasten the bodies to the wall, but the men of Jabeshgilead take them down."), ("Loyalty remembered", "Jabeshgilead remembers that Saul saved them at the start of his reign.")],
)


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "09_1_samuel.json"
    data = load(path)
    for number, fields in CH.items():
        entry = data[f"1 Samuel {number}"]
        entry["summary"] = fields["summary"]
        entry["whereWeAre"] = fields["wwa"]
        entry["keyFigures"] = [{"name": n, "role": r} for n, r in fields["people"]]
        old = entry["keyThemes"]
        refs = fields.get("refs") or [t["references"] for t in old]
        if len(fields["themes"]) != len(refs):
            raise SystemExit(f"1 Samuel {number}: {len(fields['themes'])} themes but {len(refs)} reference lists")
        entry["keyThemes"] = [{"theme": t, "explanation": e, "references": r} for (t, e), r in zip(fields["themes"], refs)]
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


# Original Audience text: who first heard it and what they knew (places stay in Historical Moment).
AUDIENCE = {
    1: "The first Israelites who heard this book knew Shiloh as the sanctuary later destroyed and remembered as a warning (Jeremiah 7:12), and they knew Samuel as the prophet who anointed their first kings. They heard that his life began in answer to a woman's prayer.",
    5: "The first Israelites who heard this book knew the Philistines as worshipers of Dagon (Judges 16:23) and as the people who held the ark for seven months. They heard that the LORD showed his power inside the Philistines' own temple.",
    6: "The first Israelites who heard this book knew Bethshemesh as a town given to the priests (Joshua 21:16) and knew the law that the holy things must not be looked on (Numbers 4:20). They heard how the ark came home with joy and then with fear.",
    7: "The first Israelites who heard this book remembered the shame of the lost ark and the long years of Philistine pressure. They heard that Israel's turn back to the LORD, not the ark, brought rescue, and that the stone Ebenezer was set up as a reminder.",
    10: "The first Israelites who heard this book knew Gibeah as Saul's royal town and knew that Saul's reign ended badly. They heard how he was chosen with signs and a public lot, and that some people doubted him from the start.",
    11: "The first Israelites who heard this book knew that the men of Jabeshgilead later rescued and buried Saul's body (1 Samuel 31:11–13), repaying this rescue. They heard Saul act as a deliverer, like the judges before him, and show mercy after the victory.",
    12: "The first Israelites who heard this book had lived under kings and knew how many of them led the people away from the LORD. They heard Samuel's farewell as a warning that both king and people must obey the LORD.",
    13: "The first Israelites who heard this book knew the weight of Philistine rule, and they knew that Samuel had told Saul to wait seven days for him (1 Samuel 10:8). They heard that Saul's first big failure came when he took the priest's work into his own hands.",
    14: "The first Israelites who heard this book knew that their army had few weapons (1 Samuel 13:19–22). They heard that Jonathan's attack with only his armourbearer was all the more striking, and that a king's rash oath could hurt his own people.",
    16: "The first Israelites who heard this book knew Jesse's family from the end of Ruth (Ruth 4:17–22) and knew David as their greatest king. They heard that God chose him while he was still a shepherd and the youngest of his brothers.",
    17: "The first Israelites who heard this book knew the Philistines as their long-time enemy and knew David's victory over Goliath as the start of his rise. Goliath's sword was later kept at Nob (1 Samuel 21:9). They heard that David won by trusting the LORD, not weapons.",
    19: "The first Israelites who heard this book knew Saul's later hatred of David and knew that prophets traveled in groups (1 Samuel 10:5). They heard that even Saul was overcome by prophesying in Samuel's presence, and that Jonathan, Michal, and Samuel all helped David.",
    21: "The first Israelites who heard this book knew David as their great king, and they knew that Jesus later pointed to David's eating the holy bread (Mark 2:25–26). They heard that David, God's chosen king, was hungry and afraid, and that he did not tell the truth.",
    23: "The first Israelites who heard this book knew these as Judah's own towns, and they heard that some of Judah's people gave David away to Saul (1 Samuel 23:12, 19). They heard that David asked the LORD before he acted and that Jonathan encouraged him.",
    24: "The first Israelites who heard this book knew that David later became king and that Saul's family fell. They heard that David honored Saul as the king the LORD had anointed, even when he could have killed him, and that Saul admitted David would reign.",
    25: "The first Israelites who heard this book knew Abigail as one of David's wives and the mother of his son Chileab (2 Samuel 3:3). They heard how her good sense kept David from shedding blood, and that Samuel's death is told in one verse.",
    27: "The first Israelites who heard this book knew that Ziklag later belonged \"unto the kings of Judah unto this day\" (1 Samuel 27:6), and that David's time among the Philistines came before his reign. They heard that fear led David to hard choices.",
    29: "The first Israelites who heard this book knew that David would soon be king and may have wondered how he escaped fighting his own people. They heard that the Philistine lords themselves sent him away.",
    31: "The first Israelites who heard this book knew David's lament for Saul and Jonathan (2 Samuel 1:17–27) and remembered how Jabeshgilead honored Saul. They heard how the first king's reign ended in defeat.",
}

# (title, old text, new text) edits to cultural notes, keyed by chapter.
CULTURE = {
    4: [("Ichabod", "Phinehas' wife names her son Ichabod", "Phinehas's wife names her son Ichabod")],
    6: [
        ("Guilt offering of gold", "(tumors)", "(tumors)"),
        ("Milk cows and their calves", "Going straight toward Beth-shemesh", "Going straight toward Bethshemesh"),
    ],
    7: [("Ebenezer", "names it Ebenezer, ‘stone of help.’", "names it Ebenezer, which means stone of help.")],
    11: [("Gouging out right eyes", "", "")],
    15: [("A victory monument", "", "")],
    24: [("Covering the feet", "", "")],
}


def apply_chapter_context():
    path = ROOT / "chapter_context" / "09_1_samuel.json"
    data = load(path)
    for number, text in AUDIENCE.items():
        data[f"1 Samuel {number}"]["audience"] = text
    for number, edits in CULTURE.items():
        notes = data[f"1 Samuel {number}"]["culture"]
        for title, old, new in edits:
            if not old:
                continue
            hits = [n for n in notes if n["title"] == title]
            if len(hits) != 1:
                raise SystemExit(f"1 Samuel {number}: {len(hits)} notes titled {title!r}")
            hits[0]["text"] = replace_once(hits[0]["text"], old, new, f"1 Samuel {number} {title}")
    # KJV spellings of place names in every note and audience text.
    spellings = [("Beth-shemesh", "Bethshemesh"), ("Jabesh-gilead", "Jabeshgilead"), ("Beth-shan", "Bethshan"), ("En-gedi", "Engedi")]
    for key, entry in data.items():
        if not key.startswith("1 Samuel"):
            continue
        for old, new in spellings:
            entry["audience"] = entry["audience"].replace(old, new)
            for note in entry["culture"]:
                note["title"] = note["title"].replace(old, new)
                note["text"] = note["text"].replace(old, new)
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_book_overview():
    path = ROOT / "book_overviews" / "02_early_history.json"
    data = load(path)
    book = data["1 Samuel"]
    book["author"] = replace_once(
        book["author"],
        "Samuel is the traditional author, with later material commonly linked to Nathan and Gad. The book itself does not name its writer.",
        "Jewish tradition credits Samuel with the first part of the book, and Nathan and Gad with the rest (1 Chronicles 29:29). The book itself does not name its writer.",
        "author",
    )
    book["audience"] = replace_once(
        book["audience"],
        "Israel during the transition from judges to monarchy.",
        "Israelites in the early kingdom, who wanted to know how their first kings came to the throne.",
        "audience",
    )
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_book_guide():
    path = ROOT / "book_guides" / "02_early_history.json"
    data = load(path)
    guide = data["1 Samuel"]
    guide["tips"][1] = replace_once(
        guide["tips"][1],
        "David is overlooked but is a man after God's own heart.",
        "David is overlooked, yet the LORD has sought out a man after his own heart (1 Samuel 13:14).",
        "tip 2",
    )
    back = guide["looksBack"][0]
    back["text"] = replace_once(
        back["text"],
        "Samuel's birth comes when Israel had \"no king\" and the priesthood was corrupt (1 Samuel 2:12–17), continuing the decline traced in Judges.",
        "Samuel's birth comes at the end of the judges, when the priesthood at Shiloh was corrupt (1 Samuel 2:12–17), continuing the decline traced in Judges.",
        "looksBack",
    )
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_FIXES = [
    ("Where: Shiloh, Ramah, Mizpeh, Gibeah, Bethlehem, the valley of Elah, the wilderness of Judah around En-gedi,",
     "Where: Shiloh, Ramah, Mizpeh, Gibeah, Bethlehem, the valley of Elah, the wilderness of Judah around Engedi,"),
    ("asks God for a child and promises to dedicate him to the Lord, beginning", "asks God for a child and promises to dedicate him to the LORD, beginning"),
    ("Old Eli, ninety-eight and blind, is sitting by the road", "Old Eli, ninety-eight and nearly blind, is sitting by the road"),
    ("Then Jonathan and his armor-bearer slip away", "Then Jonathan and his armourbearer slip away"),
    ("Saul loves him and makes him his armor-bearer.", "Saul loves him and makes him his armourbearer."),
    ("He tells his armor-bearer, “Draw thy sword", "He tells his armourbearer, “Draw thy sword"),
    ("But the armor-bearer is too afraid.", "But the armourbearer is too afraid."),
    ("When the armor-bearer sees that Saul is dead", "When the armourbearer sees that Saul is dead"),
    ("almost as if handing over his right to the throne.", "a gesture some readers see as handing over his own right to the throne."),
    ("She says she sees a god rising out of the earth, “An old man cometh up;", "She says she sees gods rising out of the earth, and “An old man cometh up;"),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "02_early_history.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("\n# 1 Samuel") + 1
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
    apply_book_guide()
    apply_story_fixes()
