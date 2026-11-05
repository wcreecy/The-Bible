#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Full quality pass for 2 Samuel: plain summaries with outline citations, exact KJV quotes,
roles without citations, distinct Original Audience text, KJV facts and spellings in the story.

Run once, after review_2_samuel.py.
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


CH = {}

CH[1] = dict(
    summary="Three days after David returns to Ziklag, a man of the Amalekites comes from Saul's camp with his clothes torn and earth on his head and says Saul and Jonathan are dead (2 Samuel 1:1–4). He claims that Saul leaned on his spear and asked him to kill him, so he did, and he brings Saul's crown and bracelet to David (2 Samuel 1:5–10). David and his men tear their clothes, mourn, weep, and fast until evening (2 Samuel 1:11–12). David asks the man, \"How wast thou not afraid to stretch forth thine hand to destroy the LORD'S anointed?\" and has him put to death (2 Samuel 1:13–16). David sings a lament for Saul and Jonathan, the song of the bow, saying, \"How are the mighty fallen,\" and tells Judah to learn it (2 Samuel 1:17–27).",
    wwa="1 Samuel ended with Saul's death on mount Gilboa, and 2 Samuel opens with David at Ziklag hearing the news from an Amalekite. This chapter shows David grieving for his enemy and his friend instead of celebrating. Chapter 2 tells how David becomes king over Judah.",
    people=[("David", "Mourns Saul and Jonathan, has the messenger put to death, and sings the lament."), ("The Amalekite", "Says he killed Saul, brings the crown and bracelet, and is put to death."), ("The people of Judah", "Are told to learn the song of the bow.")],
    themes=[("Grief, not joy", "David weeps and fasts for Saul and Jonathan when he could have celebrated."), ("The LORD'S anointed", "David puts the messenger to death for saying he killed \"the LORD'S anointed.\""), ("A friend remembered", "David says Jonathan's love to him was \"wonderful, passing the love of women.\"")],
)
CH[2] = dict(
    summary="David asks the LORD and goes up to Hebron, where the men of Judah anoint him king over the house of Judah (2 Samuel 2:1–4). He sends word to the men of Jabeshgilead, blessing them for burying Saul (2 Samuel 2:4–7). Abner takes Ishbosheth, Saul's son, to Mahanaim and makes him king over Israel, and David reigns seven years and six months in Hebron (2 Samuel 2:8–11). Twelve men from each side meet at the pool of Gibeon and fall together, and a hard battle follows in which Abner's men are beaten (2 Samuel 2:12–17). Asahel, who is as light of foot as a wild roe, chases Abner, and Abner strikes him with the back end of his spear so that he dies (2 Samuel 2:18–23). Joab and Abishai chase Abner until sunset, Abner cries, \"Shall the sword devour for ever?\" and Joab blows the trumpet and stops the chase (2 Samuel 2:24–32).",
    wwa="Chapter 1 ended with David's lament for Saul and Jonathan. This chapter shows David made king over Judah at Hebron while Abner makes Saul's son Ishbosheth king over the rest of Israel, and the two sides begin to fight at Gibeon. Chapter 3 tells how the war goes on.",
    people=[("David", "Asks the LORD, goes to Hebron, and is anointed king over Judah."), ("Abner", "Saul's captain, who makes Ishbosheth king and kills Asahel."), ("Ishbosheth", "Saul's son, made king over Israel at Mahanaim."), ("Joab and Abishai", "David's men, who chase Abner after Asahel's death."), ("Asahel", "Joab's brother, light of foot as a wild roe, killed by Abner."), ("The men of Jabeshgilead", "Blessed by David for burying Saul.")],
    themes=[("Asking before moving", "David asks the LORD whether to go up and where."), ("Two kings", "Judah follows David while Abner sets up Ishbosheth over Israel."), ("The cost of civil war", "Men of Israel fight men of Israel, and Asahel dies.")],
)
CH[3] = dict(
    summary="There is long war between the house of Saul and the house of David, but David grows stronger and stronger, and six sons are born to him at Hebron (2 Samuel 3:1–5). Ishbosheth accuses Abner about Saul's concubine Rizpah, and Abner is very angry and promises to bring all Israel to David (2 Samuel 3:6–12). David asks for his wife Michal back, Abner talks to the elders of Israel, and he comes to David at Hebron and is sent away in peace (2 Samuel 3:13–21). Joab hears of it, calls Abner back, takes him aside in the gate, and strikes him under the fifth rib for the blood of Asahel (2 Samuel 3:22–27). David says he and his kingdom are guiltless before the LORD, curses Joab's house, and mourns Abner with all the people, saying, \"Know ye not that there is a prince and a great man fallen this day in Israel?\" (2 Samuel 3:28–39).",
    wwa="Chapter 2 ended with the first fight between the two sides. This chapter tells how Abner turns to David after a quarrel with Ishbosheth, how Joab kills him, and how David mourns him. Chapter 4 tells how Ishbosheth himself is killed.",
    people=[("David", "Grows stronger, makes peace with Abner, and openly mourns him."), ("Abner", "Quarrels with Ishbosheth, offers Israel to David, and is killed by Joab."), ("Ishbosheth", "Accuses Abner and loses his backing."), ("Joab", "Kills Abner to avenge his brother Asahel."), ("Michal", "Saul's daughter, taken from her husband and brought back to David.")],
    themes=[("Switching sides", "Abner promises to bring all Israel over to David."), ("Revenge", "Joab kills Abner in the gate for the blood of his brother."), ("David's open grief", "David curses the deed, fasts, and walks behind the bier.")],
)
CH[4] = dict(
    summary="When Saul's son Ishbosheth hears that Abner is dead, his hands are feeble and all Israel is troubled (2 Samuel 4:1). The chapter mentions Jonathan's son Mephibosheth, who is lame on his feet because he fell when his nurse fled (2 Samuel 4:4). Baanah and Rechab, captains of bands, go in at the heat of the day while Ishbosheth lies on his bed at noon, strike him, and take his head to David at Hebron (2 Samuel 4:2–8). David says that he killed the man who brought him news of Saul, and how much more should he deal with wicked men who have killed a righteous person in his own house on his bed (2 Samuel 4:9–11). David commands his young men to kill them, and they cut off their hands and feet and hang them up over the pool in Hebron (2 Samuel 4:12).",
    wwa="Chapter 3 ended with David mourning Abner. This chapter tells how two captains murder Ishbosheth in his bed to win a reward, and how David has them put to death. Chapter 5 tells how all Israel makes David king.",
    people=[("Ishbosheth", "Saul's son, whose hands become feeble, killed on his bed at noon."), ("Baanah and Rechab", "Captains who kill Ishbosheth and bring his head to David."), ("David", "Says wicked men have killed a righteous person, and has them put to death."), ("Mephibosheth", "Jonathan's son, lame on his feet from childhood.")],
    themes=[("A king who has lost heart", "Ishbosheth is feeble after Abner dies."), ("No reward for murder", "Baanah and Rechab expect thanks and receive death."), ("A boy who was dropped", "Mephibosheth became lame when his nurse fled with him at the news of Saul's death.")],
    refs=[["2 Samuel 4:1"], ["2 Samuel 4:5-12"], ["2 Samuel 4:4"]],
)
CH[5] = dict(
    summary="All the tribes of Israel come to David at Hebron and say, \"we are thy bone and thy flesh,\" and they anoint him king over Israel, and he is thirty years old and reigns forty years (2 Samuel 5:1–5). David and his men take the stronghold of Zion from the Jebusites, who had said the blind and the lame would keep him out, and he lives in the fort and calls it the city of David (2 Samuel 5:6–10). Hiram king of Tyre sends cedar trees, carpenters, and masons to build David a house, and David sees that the LORD has established him king over Israel (2 Samuel 5:11–12). More sons and daughters are born to David in Jerusalem (2 Samuel 5:13–16). The Philistines come up against David twice in the valley of Rephaim, and each time David asks the LORD, who gives him victory, the second time when he hears \"the sound of a going in the tops of the mulberry trees\" (2 Samuel 5:17–25).",
    wwa="Chapter 4 ended with the murder of Ishbosheth. This chapter shows all Israel anointing David at Hebron, David taking Jerusalem and making it his city, and David twice beating the Philistines after asking the LORD. Chapter 6 brings the ark to Jerusalem.",
    people=[("David", "Anointed over all Israel, takes Zion, and beats the Philistines after asking the LORD."), ("The elders of Israel", "Come to Hebron and anoint David king."), ("The Jebusites", "Say the blind and the lame can keep David out of Zion."), ("Hiram king of Tyre", "Sends cedar trees, carpenters, and masons."), ("The Philistines", "Come up twice against David in the valley of Rephaim."), ("The LORD", "Goes before David and gives him victory.")],
    themes=[("One king for all Israel", "The tribes say to David, \"we are thy bone and thy flesh,\" and the LORD had said David would feed his people."), ("The city of David", "David takes Zion and makes Jerusalem his capital."), ("Asking before fighting", "David asks the LORD both times before facing the Philistines.")],
    refs=[["2 Samuel 5:1-5"], ["2 Samuel 5:6-12"], ["2 Samuel 5:19", "2 Samuel 5:23-25"]],
)
CH[6] = dict(
    summary="David gathers thirty thousand chosen men and sets the ark of God on a new cart to bring it from Baale of Judah, and Uzzah and Ahio drive it while David and all Israel play before the LORD (2 Samuel 6:1–5). When the oxen shake the ark, Uzzah puts out his hand and takes hold of it, and God strikes him there for his error and he dies (2 Samuel 6:6–7). David is displeased and afraid, and says, \"How shall the ark of the LORD come to me?\" and he leaves it in the house of Obededom the Gittite, whom the LORD blesses for three months (2 Samuel 6:8–11). David brings up the ark with gladness, offers an ox and a fatling after six paces, and dances before the LORD with all his might, wearing a linen ephod (2 Samuel 6:12–15). He sets the ark in a tent, offers burnt offerings and peace offerings, and gives every man a cake of bread, a good piece of meat, and a flagon of wine (2 Samuel 6:16–19). Michal despises David for dancing, and he answers that it was before the LORD, and she has no child to the day of her death (2 Samuel 6:20–23).",
    wwa="Chapter 5 ended with David's victories over the Philistines. This chapter tells how David brings the ark to Jerusalem, stops after Uzzah dies, and then brings it in with joy, which Michal despises. Chapter 7 gives the LORD's promise to David.",
    people=[("David", "Brings the ark to Jerusalem, is afraid after Uzzah dies, and dances before the LORD."), ("Uzzah", "Takes hold of the ark when the oxen shake it and dies."), ("Obededom the Gittite", "Keeps the ark in his house three months and is blessed."), ("The thirty thousand men of Israel", "Go with David to bring up the ark."), ("Michal", "Looks through a window, despises David, and has no child.")],
    themes=[("Holy things", "Uzzah dies for putting his hand on the ark, and David fears to move it."), ("Joy before the LORD", "David dances with all his might and shares food with the people."), ("Two views of worship", "Michal thinks David has shamed himself, and he answers, \"I will yet be more vile than thus.\"")],
)
CH[7] = dict(
    summary="David sits in his house of cedar, and the LORD has given him rest from his enemies, and he tells Nathan the prophet that the ark of God dwells within curtains, and Nathan tells him to do all that is in his heart (2 Samuel 7:1–3). That night the word of the LORD comes to Nathan, who is to ask David, \"Shalt thou build me an house for me to dwell in?\" since the LORD never asked for one in all his walking with Israel (2 Samuel 7:4–7). The LORD says he took David from the sheepcote to be ruler over his people, made him a great name, and will give Israel a place (2 Samuel 7:8–11). The LORD will make David a house and set up his seed after him, who will build a house for his name, and the LORD will be his father, and he will be his son, and David's house and kingdom will be established for ever (2 Samuel 7:11–16). Nathan tells David all this, and David sits before the LORD and says, \"Who am I, O Lord GOD?\" and asks him to do as he has said (2 Samuel 7:17–29).",
    wwa="Chapter 6 ended with the ark in Jerusalem. This chapter shows David wanting to build God a house, and the LORD saying he will build David a house instead, a family line that will last for ever, which is the great promise of this book. Chapter 8 tells of David's victories.",
    people=[("David", "Wants to build a house for the ark, then sits before the LORD in thanks."), ("Nathan", "Tells David to go ahead, then brings the LORD's word that night."), ("The LORD", "Promises David a house, a son, and a throne for ever.")],
    themes=[("God's plan, not David's", "David wants to build a house for the LORD, and the LORD says he will build David's house."), ("A promise that lasts", "The LORD says David's house and kingdom \"shall be established for ever.\""), ("A thankful prayer", "David asks, \"Who am I, O Lord GOD?\" and praises him.")],
)
CH[8] = dict(
    summary="David strikes the Philistines and takes Methegammah, and he defeats Moab, measures them with a line, and makes them servants who bring gifts (2 Samuel 8:1–2). He defeats Hadadezer king of Zobah, and when the Syrians of Damascus help him, David kills twenty-two thousand of them and puts garrisons in Syria (2 Samuel 8:3–8). Toi king of Hamath sends his son Joram with vessels of silver, gold, and brass, and David dedicates them to the LORD with the other silver and gold from the nations he conquered (2 Samuel 8:9–12). David gets a name when he strikes eighteen thousand Edomites in the valley of salt, and the LORD keeps David safe wherever he goes (2 Samuel 8:13–14). David reigns over all Israel and does judgment and justice, and the chapter lists his officers, Joab, Jehoshaphat, Zadok, Ahimelech, Seraiah, and Benaiah (2 Samuel 8:15–18).",
    wwa="Chapter 7 gave the promise of a lasting house. This chapter lists David's wars against the Philistines, Moab, Zobah, Syria, and Edom, and the officers who help him rule. Chapter 9 shows his kindness to Jonathan's son.",
    people=[("David", "Wins his wars, dedicates the silver and gold to the LORD, and does judgment and justice."), ("Hadadezer king of Zobah", "Defeated by David as he went to recover his border at the river."), ("Toi king of Hamath", "Sends his son Joram with gifts when Hadadezer falls."), ("The LORD", "Keeps David safe wherever he goes."), ("David's officers", "Joab, Jehoshaphat, Zadok, Ahimelech, Seraiah, and Benaiah.")],
    themes=[("The LORD keeps David safe", "The text says twice that \"the LORD preserved David whithersoever he went.\""), ("Justice in the kingdom", "David \"executed judgment and justice unto all his people.\""), ("Giving back", "David dedicates the silver and gold from the nations to the LORD.")],
)
CH[9] = dict(
    summary="David asks, \"Is there yet any that is left of the house of Saul, that I may shew him kindness for Jonathan's sake?\" (2 Samuel 9:1). Ziba, a servant of Saul's house, tells him of a son of Jonathan who is lame on his feet, living in Lodebar in the house of Machir (2 Samuel 9:2–5). Mephibosheth comes and falls on his face, and David says, \"Fear not: for I will surely shew thee kindness for Jonathan thy father's sake,\" and promises to restore all the land of Saul to him (2 Samuel 9:6–8). Mephibosheth is to eat bread at David's table continually, and Ziba and his fifteen sons and twenty servants are to farm his land, and Mephibosheth eats at the king's table as one of the king's sons (2 Samuel 9:9–13).",
    wwa="Chapter 8 listed David's wars and officers. This chapter turns to one quiet act: David keeps his promise to Jonathan by bringing Jonathan's lame son Mephibosheth to eat at the king's table. Chapter 10 returns to war, with Ammon.",
    people=[("David", "Asks after Saul's house and shows kindness for Jonathan's sake."), ("Mephibosheth", "Jonathan's lame son, restored to Saul's land and seated at the king's table."), ("Ziba", "Saul's servant, who tells David about Mephibosheth and is told to farm his land."), ("Machir son of Ammiel", "Keeps Mephibosheth in Lodebar.")],
    themes=[("A promise kept", "David acts \"for Jonathan's sake,\" as he had sworn."), ("A place at the table", "Mephibosheth eats at the king's table continually, \"as one of the king's sons.\""), ("Land and help", "David gives back Saul's land and tells Ziba to farm it.")],
)
CH[10] = dict(
    summary="When Nahash king of the Ammonites dies, David sends servants to comfort his son Hanun, but the princes of Ammon say David has sent spies, and Hanun shaves off half the beard of each servant and cuts their garments off at the hips (2 Samuel 10:1–5). David tells his men to stay at Jericho until their beards are grown (2 Samuel 10:5). The Ammonites hire twenty thousand Syrians of Bethrehob and Zoba, a thousand men of the king of Maacah, and twelve thousand men of Ishtob, and Joab sets his army against both (2 Samuel 10:6–9). Joab says, \"Be of good courage, and let us play the men for our people,\" and the Syrians and the Ammonites flee (2 Samuel 10:10–14). Hadarezer brings in Syrians from beyond the river, and David crosses the Jordan to Helam and kills seven hundred charioteers and forty thousand horsemen, and the kings who served Hadarezer make peace with Israel and fear to help Ammon any more (2 Samuel 10:15–19).",
    wwa="Chapter 9 ended with Mephibosheth at David's table. This chapter tells how David's kind message to Ammon is insulted, which leads to war with Ammon and Syria. Chapter 11 begins with the siege of Rabbah and David's great sin.",
    people=[("David", "Sends comfort to Hanun and then fights Ammon and the Syrians."), ("Hanun", "King of Ammon, who shames David's servants."), ("The princes of the Ammonites", "Tell Hanun that David's servants are spies."), ("Joab and Abishai", "Divide the army and fight the Syrians and Ammonites."), ("The Syrians", "Hired by Ammon, then beaten, and they make peace with Israel.")],
    themes=[("Kindness mistaken for a trick", "Hanun's princes say David's comforters are spies."), ("Courage and trust", "Joab says, \"Be of good courage,\" and asks that \"the LORD do that which seemeth him good.\""), ("War spreads", "The fight with Ammon grows into a war with Syria.")],
)
CH[11] = dict(
    summary="At the time when kings go forth to battle, David sends Joab and the army against Ammon to besiege Rabbah, but David stays at Jerusalem (2 Samuel 11:1). One evening David walks on the roof of the king's house and sees a woman washing, very beautiful, and learns she is Bathsheba, the wife of Uriah the Hittite (2 Samuel 11:2–3). David sends messengers and takes her, and lies with her, and she sends word, \"I am with child\" (2 Samuel 11:4–5). David sends for Uriah and tells him to go down to his house, but Uriah sleeps at the door of the king's house, saying, \"The ark, and Israel, and Judah, abide in tents\" (2 Samuel 11:6–13). David makes Uriah drunk, but he still does not go home, so David writes a letter to Joab, sent by Uriah's own hand, telling him to put Uriah in the front of the hottest battle and pull back from him (2 Samuel 11:14–17). Uriah is killed, David tells the messenger, \"Let not this thing displease thee,\" and when Bathsheba's mourning is past, David brings her to his house, and she bears a son, but \"the thing that David had done displeased the LORD\" (2 Samuel 11:18–27).",
    wwa="Chapter 10 ended with Ammon's allies afraid to help again. This chapter tells how, while the army besieges Rabbah, David takes Bathsheba and has her husband Uriah killed in battle, and the LORD is displeased. Chapter 12 tells how Nathan confronts him.",
    people=[("David", "Stays in Jerusalem, takes Bathsheba, and arranges for Uriah to be killed."), ("Bathsheba", "The wife of Uriah, who is taken by David and bears his son."), ("Uriah the Hittite", "A loyal soldier who will not go home while the ark and the army are in tents, and is killed."), ("Joab", "Carries out David's letter at the siege of Rabbah."), ("The messenger", "Brings David word of the battle and of Uriah's death.")],
    themes=[("Power used for harm", "The king sends for a woman and then for her husband's death."), ("Hiding the sin", "David tries to bring Uriah home so the child will seem his, and when that fails, has him killed."), ("The LORD saw it", "The chapter ends by saying \"the thing that David had done displeased the LORD.\"")],
)
CH[12] = dict(
    summary="The LORD sends Nathan to David, who tells of a rich man who took a poor man's one little ewe lamb for his guest, and David says the man shall surely die and must pay back fourfold (2 Samuel 12:1–6). Nathan says, \"Thou art the man,\" tells David what the LORD gave him, and says that because David despised the commandment and killed Uriah, the sword will never leave his house (2 Samuel 12:7–12). David says, \"I have sinned against the LORD,\" and Nathan says, \"The LORD also hath put away thy sin; thou shalt not die,\" but the child will die (2 Samuel 12:13–14). David fasts and lies all night on the earth while the child is sick, and when the child dies on the seventh day, he rises, washes, worships in the house of the LORD, and eats, saying, \"I shall go to him, but he shall not return to me\" (2 Samuel 12:15–23). David comforts Bathsheba, and she bears Solomon, and the LORD loves him, and Nathan calls his name Jedidiah (2 Samuel 12:24–25). Joab fights Rabbah and sends for David to take the city, and David takes the crown of their king and brings out the spoil (2 Samuel 12:26–31).",
    wwa="Chapter 11 ended with the LORD displeased at David. This chapter shows Nathan telling a story that makes David judge himself, David confessing, the first child dying, and Solomon born, while Rabbah falls. Chapter 13 shows the trouble in David's house.",
    people=[("Nathan", "Tells the story of the poor man's lamb and says to David, \"Thou art the man.\""), ("David", "Says, \"I have sinned against the LORD,\" fasts for the child, and then takes Rabbah."), ("Bathsheba", "Loses her first child and later bears Solomon."), ("Solomon", "Born to David and Bathsheba, loved by the LORD, and called Jedidiah."), ("Joab", "Fights Rabbah and calls David to take the city.")],
    themes=[("A story that shows the sin", "Nathan's tale of the lamb makes David judge the man, and then Nathan says, \"Thou art the man.\""), ("Forgiven, but the cost remains", "The LORD puts away David's sin, yet the sword will not leave his house and the child dies."), ("Hope after loss", "Solomon is born, and the LORD loves him.")],
    refs=[["2 Samuel 12:1-12"], ["2 Samuel 12:13-23"], ["2 Samuel 12:24-25"]],
)
CH[13] = dict(
    summary="Absalom has a beautiful sister, Tamar, and his half brother Amnon loves her, and Jonadab, a very clever man, tells Amnon to lie down and make himself sick (2 Samuel 13:1–5). David sends Tamar to make cakes for him, and Amnon sends the others out, and she says, \"Nay, my brother, do not force me,\" but he forces her and then hates her exceedingly and has her put out (2 Samuel 13:6–18). Tamar puts ashes on her head, tears her garment, and goes away crying, and Absalom takes her in, and she lives desolate in his house, and David is very angry but does nothing (2 Samuel 13:19–22). After two full years Absalom invites the king's sons to sheepshearing at Baalhazor and has his servants kill Amnon when his heart is merry with wine (2 Samuel 13:23–29). David hears a false report that all the sons are dead, and Jonadab says only Amnon is dead, and Absalom flees to Talmai king of Geshur and stays three years, and David mourns and longs to go to Absalom (2 Samuel 13:30–39).",
    wwa="Chapter 12 ended with Rabbah taken. This chapter shows the sword in David's house, as Nathan said: Amnon wrongs his half sister Tamar, and her brother Absalom has Amnon killed and runs away. Chapter 14 tells how Absalom comes back.",
    people=[("Tamar", "David's daughter, who pleads with Amnon and is wronged and left desolate."), ("Amnon", "David's son, who wrongs Tamar and then hates her, and is killed."), ("Absalom", "Tamar's brother, who waits two years and then has Amnon killed."), ("Jonadab", "Amnon's friend, a very clever man, who plans the trick."), ("David", "Is very angry but does nothing, and later mourns."), ("Talmai king of Geshur", "Absalom's mother's father, to whom Absalom flees.")],
    themes=[("A wrong done to Tamar", "Tamar pleads with Amnon, but he forces her and puts her out."), ("A father who does nothing", "David is very angry but does not act, and Absalom hates Amnon."), ("Revenge", "Absalom has Amnon killed at the sheepshearing and flees.")],
)
CH[14] = dict(
    summary="Joab sees that the king's heart is toward Absalom and sends to Tekoa for a wise woman and tells her to pretend to be a mourner (2 Samuel 14:1–3). She tells David a story of two sons, one of whom has killed the other, and her family wants to put the survivor to death and put out her last coal, and David says not one hair of her son shall fall to the earth (2 Samuel 14:4–11). She says the king is at fault for not bringing home his banished son, for \"we must needs die\" and are \"as water spilt on the ground,\" but God makes a way so that the banished are not cast out from him (2 Samuel 14:12–17). David asks, \"Is not the hand of Joab with thee in all this?\" and tells Joab to bring Absalom home but not to see his face (2 Samuel 14:18–24). Absalom, whose hair weighs two hundred shekels and who has three sons and a daughter named Tamar, lives two full years in Jerusalem without seeing the king (2 Samuel 14:25–28). Absalom has Joab's field of barley set on fire to make him come, and then says, \"let me see the king's face,\" and the king kisses him (2 Samuel 14:29–33).",
    wwa="Chapter 13 ended with Absalom in Geshur. This chapter tells how Joab uses a wise woman of Tekoa to move David to bring Absalom home, though David will not see him for two years until Absalom sets Joab's field on fire. Chapter 15 tells how Absalom turns on his father.",
    people=[("Joab", "Sends the woman of Tekoa to plead for Absalom and later brings him to the king."), ("The wise woman of Tekoa", "Tells David a made-up story of two sons."), ("David", "Lets Absalom come home but will not see him for two years, then kisses him."), ("Absalom", "Comes home, has Joab's field burned, and says, \"let me see the king's face.\"")],
    themes=[("A story to move the king", "The woman of Tekoa tells David a tale that shows him what he is doing to Absalom."), ("Home, but not back", "Absalom lives in Jerusalem two years without seeing his father's face."), ("Absalom forces his way", "He burns Joab's barley field to get Joab to come.")],
)
CH[15] = dict(
    summary="Absalom gets chariots, horses, and fifty men to run before him, and he rises early and stands by the way of the gate, telling everyone with a matter for the king that no man is appointed to hear them, and he steals the hearts of the men of Israel (2 Samuel 15:1–6). After forty years, as the KJV has it, Absalom asks leave to pay a vow in Hebron and sends spies through Israel to say, \"Absalom reigneth in Hebron,\" and Ahithophel the Gilonite, David's counsellor, joins him (2 Samuel 15:7–12). David says, \"Arise, and let us flee,\" and leaves ten concubines to keep the house (2 Samuel 15:13–16). Ittai the Gittite swears to follow David wherever he goes, in death or in life (2 Samuel 15:17–22). Zadok and the Levites bring the ark, but David says, \"Carry back the ark of God into the city,\" and says that if the LORD has no delight in him, \"let him do to me as seemeth good unto him\" (2 Samuel 15:23–29). David goes up the mount of Olives weeping, with his head covered and barefoot, and prays that the LORD will turn the counsel of Ahithophel into foolishness (2 Samuel 15:30–31). He sends Hushai back to Absalom to defeat Ahithophel's advice (2 Samuel 15:32–37).",
    wwa="Chapter 14 ended with the king kissing Absalom. This chapter tells how Absalom wins the hearts of Israel, sets up as king at Hebron, and how David leaves Jerusalem weeping, sends the ark back, and sends Hushai to work against Ahithophel. Chapter 16 follows David in flight.",
    people=[("Absalom", "Wins the people at the gate and makes himself king at Hebron."), ("David", "Flees Jerusalem, sends back the ark, and prays against Ahithophel."), ("Ahithophel", "David's counsellor, who joins Absalom."), ("Ittai the Gittite", "A stranger who swears to follow David in death or in life."), ("Zadok and Abiathar", "The priests who bring the ark and then take it back."), ("Hushai the Archite", "David's friend, sent back to defeat Ahithophel's advice.")],
    themes=[("Stealing hearts", "Absalom tells people the king has no one to hear them and says, \"Oh that I were made judge in the land!\""), ("Loyalty from a stranger", "Ittai the Gittite swears to follow David wherever he goes."), ("Leaving it with the LORD", "David sends the ark back and says, \"let him do to me as seemeth good unto him.\"")],
)
CH[16] = dict(
    summary="Ziba meets David with two donkeys, bread, and fruit, and says Mephibosheth is staying in Jerusalem hoping the house of Israel will give him his father's kingdom, and David says all that belonged to Mephibosheth is Ziba's (2 Samuel 16:1–4). At Bahurim, Shimei the son of Gera curses David and throws stones, saying, \"Come out, come out, thou bloody man, and thou man of Belial\" (2 Samuel 16:5–8). Abishai asks leave to take off his head, but David says, \"let him curse,\" because the LORD has told him to, and it may be that the LORD will look on his affliction (2 Samuel 16:9–14). Hushai comes to Absalom and says, \"God save the king,\" and says he will serve the one whom the LORD and this people choose (2 Samuel 16:15–19). Ahithophel tells Absalom to go in to his father's concubines, and Absalom does so in the sight of all Israel on a tent on the top of the house (2 Samuel 16:20–23).",
    wwa="Chapter 15 ended with Hushai going into Jerusalem. This chapter shows David on the road meeting Ziba and Shimei, and Absalom taking Jerusalem and following Ahithophel's advice to claim his father's house. Chapter 17 tells whose advice Absalom takes next.",
    people=[("David", "Gives Mephibosheth's land to Ziba and bears Shimei's cursing."), ("Ziba", "Meets David with food and says his master hopes for the kingdom."), ("Shimei", "A man of Saul's house who curses David and throws stones."), ("Abishai", "Offers to take off Shimei's head."), ("Hushai", "Joins Absalom's court as David asked."), ("Absalom and Ahithophel", "Absalom takes Jerusalem and follows Ahithophel's advice.")],
    themes=[("Taking one side's word", "David gives away Mephibosheth's land after hearing only Ziba."), ("Patience under cursing", "David tells Abishai, \"let him curse,\" because the LORD has told him to."), ("A public claim to the throne", "Absalom goes in to his father's concubines in the sight of all Israel.")],
)
CH[17] = dict(
    summary="Ahithophel tells Absalom to let him take twelve thousand men and chase David that night and strike down the king only (2 Samuel 17:1–4). Hushai says that advice is not good, because David and his men are \"chafed in their minds, as a bear robbed of her whelps,\" and Absalom should gather all Israel and go to battle himself (2 Samuel 17:5–13). Absalom and Israel say Hushai's advice is better than Ahithophel's, for the LORD had planned to defeat Ahithophel's good advice (2 Samuel 17:14). Hushai tells Zadok and Abiathar, and Jonathan and Ahimaaz carry the word to David, hidden by a woman at Bahurim in a well, and David and all the people cross the Jordan before morning (2 Samuel 17:15–22). Ahithophel sees his advice is not followed, saddles his donkey, puts his house in order, and hangs himself (2 Samuel 17:23). David comes to Mahanaim, and Shobi, Machir, and Barzillai bring beds, basins, wheat, barley, honey, butter, sheep, and cheese for the people, while Absalom crosses the Jordan with Amasa (2 Samuel 17:24–29).",
    wwa="Chapter 16 ended with Absalom taking his father's house. This chapter tells how Absalom takes Hushai's advice over Ahithophel's, how David gets word and crosses the Jordan, and how Ahithophel hangs himself. Chapter 18 tells of the battle.",
    people=[("Ahithophel", "Advises a quick strike at David and hangs himself when it is refused."), ("Hushai", "Persuades Absalom to wait and gather all Israel, and sends word to David."), ("Absalom", "Takes Hushai's advice and crosses the Jordan with Amasa."), ("Jonathan and Ahimaaz", "Priests' sons who carry the warning to David."), ("The woman at Bahurim", "Hides the two messengers in a well."), ("David", "Crosses the Jordan and comes to Mahanaim, where friends feed his people.")],
    themes=[("Two plans", "Ahithophel's plan is quick and sharp, and Hushai's is slow and large."), ("The LORD turns the counsel", "The LORD had appointed \"to defeat the good counsel of Ahithophel.\""), ("Hidden helpers", "A woman at Bahurim hides the messengers in a well, and friends at Mahanaim bring food.")],
    refs=[["2 Samuel 17:1-13"], ["2 Samuel 17:14"], ["2 Samuel 17:17-20", "2 Samuel 17:27-29"]],
)
CH[18] = dict(
    summary="David numbers the people and puts them in three companies under Joab, Abishai, and Ittai, and the people will not let him go out to battle, saying, \"thou art worth ten thousand of us\" (2 Samuel 18:1–4). David tells the three captains in the hearing of all, \"Deal gently for my sake with the young man, even with Absalom\" (2 Samuel 18:5). The battle in the wood of Ephraim kills twenty thousand, and the wood devours more people that day than the sword (2 Samuel 18:6–8). Absalom's head is caught in the thick boughs of a great oak as he rides a mule, and a man tells Joab, who will not wait and thrusts three darts through the heart of Absalom, and ten young men strike him, and they cast him into a great pit in the wood (2 Samuel 18:9–18). Ahimaaz and the Cushite run with the news, and David asks, \"Is the young man Absalom safe?\" and when he hears, he goes up to the chamber over the gate and weeps, \"O my son Absalom, my son, my son Absalom! would God I had died for thee\" (2 Samuel 18:19–33).",
    wwa="Chapter 17 ended with David at Mahanaim. This chapter tells how David's army beats Absalom's in the wood of Ephraim, how Joab kills Absalom against David's wish, and how David mourns. Chapter 19 tells how the victory turns to shame.",
    people=[("David", "Tells his captains to deal gently with Absalom, then weeps for him."), ("Absalom", "Caught by his head in an oak and killed by Joab."), ("Joab", "Thrusts three darts through Absalom's heart against the king's charge."), ("Abishai and Ittai", "The other two captains over the thirds."), ("The man who saw Absalom", "Will not touch Absalom for a thousand shekels, because the king gave a charge."), ("Ahimaaz and the Cushite", "Run with the news to David.")],
    themes=[("A king who is also a father", "David asks the captains to deal gently with Absalom."), ("Joab does what he is told not to", "Joab kills Absalom although David had told them to spare him."), ("Grief after victory", "David cries, \"would God I had died for thee, O Absalom, my son, my son!\"")],
)
CH[19] = dict(
    summary="Joab is told that the king weeps and mourns for Absalom, so the victory that day is turned into mourning, and the people steal into the city as if they had fled in battle (2 Samuel 19:1–3). Joab tells David that he has shamed all his servants, loving his enemies and hating his friends, and says to go out and speak kindly to them or no man will stay with him that night (2 Samuel 19:4–7). The king sits in the gate, and David sends to the elders of Judah, saying, \"ye are my bones and my flesh,\" and makes Amasa captain in Joab's place, and Judah comes to Gilgal to bring him over the Jordan (2 Samuel 19:8–15). Shimei falls down and says, \"Let not my lord impute iniquity unto me,\" and David swears he shall not die, though Abishai would have had him put to death (2 Samuel 19:16–23). Mephibosheth, who has not cared for his feet or trimmed his beard, says Ziba deceived him, and David says, \"Thou and Ziba divide the land,\" and Mephibosheth says to let Ziba take all (2 Samuel 19:24–30). Barzillai, eighty years old, brings the king over the Jordan but will not go with him to Jerusalem, and Judah and Israel quarrel over the king, and the words of Judah are fiercer (2 Samuel 19:31–43).",
    wwa="Chapter 18 ended with David's cry for Absalom. This chapter tells how Joab makes David face his men, how David returns across the Jordan and deals with Shimei, Mephibosheth, and Barzillai, and how Judah and Israel begin to quarrel. Chapter 20 tells how that quarrel breaks out.",
    people=[("David", "Is rebuked by Joab, then crosses the Jordan and forgives Shimei."), ("Joab", "Tells David he has shamed his servants and must speak kindly to them."), ("Shimei", "Falls down and begs David not to hold his sin against him."), ("Mephibosheth", "Says Ziba deceived him, and will let Ziba take all."), ("Barzillai", "Eighty years old, who will not go to court."), ("Amasa", "Made captain of the host in Joab's place.")],
    themes=[("A king must face his men", "Joab says David must go out and speak kindly to his men, or no man will stay with him."), ("Mercy and the other side", "David spares Shimei and hears Mephibosheth's side of the story."), ("Judah against Israel", "Judah and Israel quarrel over who has more right in the king.")],
)
CH[20] = dict(
    summary="Sheba, a son of Bichri and a Benjamite, blows a trumpet and says, \"We have no part in David,\" and \"every man to his tents, O Israel,\" and all Israel follows him while Judah clings to the king (2 Samuel 20:1–2). David comes to Jerusalem and puts the ten concubines in ward, and they live as widows (2 Samuel 20:3). David tells Amasa to gather Judah in three days, but he is late, so David tells Abishai to chase Sheba, and Joab goes out with him (2 Samuel 20:4–7). At Gibeon Joab takes Amasa by the beard to kiss him and strikes him in the fifth rib, and a man calls, \"He that favoureth Joab, and he that is for David, let him go after Joab\" (2 Samuel 20:8–13). Joab besieges Sheba in Abel of Bethmaachah and builds a ramp against the city (2 Samuel 20:14–15). A wise woman calls from the wall, asking why Joab would swallow up the inheritance of the LORD, and her city throws Sheba's head over the wall, and Joab blows the trumpet and goes home (2 Samuel 20:16–22). The chapter lists David's officers (2 Samuel 20:23–26).",
    wwa="Chapter 19 ended with Judah and Israel quarrelling. This chapter shows the quarrel become a revolt under Sheba, Joab murdering Amasa, and a wise woman saving her city by giving up Sheba. Chapter 21 begins the closing chapters of the book.",
    people=[("Sheba son of Bichri", "A Benjamite who calls Israel to leave David."), ("David", "Puts the ten concubines in ward and sends Abishai after Sheba."), ("Amasa", "Is slow to gather Judah and is killed by Joab."), ("Joab", "Kills Amasa and besieges Abel of Bethmaachah."), ("The wise woman of Abel", "Speaks from the wall and has Sheba's head thrown over.")],
    themes=[("The kingdom splits again", "Sheba calls, \"every man to his tents,\" and most of Israel goes with him."), ("Joab kills a rival", "Joab takes Amasa by the beard and strikes him with a hidden sword."), ("A wise woman saves a city", "She asks Joab why he would swallow up the inheritance of the LORD, and her city gives up Sheba.")],
)
CH[21] = dict(
    summary="There is a famine in David's days three years, and David asks the LORD, who says, \"It is for Saul, and for his bloody house, because he slew the Gibeonites\" (2 Samuel 21:1–2). The Gibeonites say they want no silver or gold, but seven of Saul's sons to hang up before the LORD in Gibeah, and David says, \"I will give them\" (2 Samuel 21:3–6). The king spares Mephibosheth because of the LORD'S oath between David and Jonathan, and gives up two sons of Rizpah and five of Michal's, who are hanged on the hill before the LORD in the days of barley harvest (2 Samuel 21:7–9). Rizpah spreads sackcloth on the rock and will not let the birds of the air touch the bodies by day or the beasts of the field by night (2 Samuel 21:10). David takes the bones of Saul and Jonathan from Jabeshgilead and buries them with the hanged men's bones in the grave of Kish, and after that God was \"intreated for the land\" (2 Samuel 21:11–14). Four Philistine giants are killed by David's men, and David's men swear he shall go no more out to battle, \"that thou quench not the light of Israel\" (2 Samuel 21:15–22).",
    wwa="Chapter 20 ended with Sheba's revolt put down, and chapters 21 to 24 step back from the main story. This chapter tells of a famine, the Gibeonites' claim for justice, Rizpah's watch, and wars with Philistine giants. Chapter 22 gives David's song.",
    people=[("David", "Asks the LORD about the famine, gives up seven of Saul's sons, and buries the bones."), ("The Gibeonites", "Ask for seven men of Saul's house because he slew them."), ("Rizpah", "Keeps the birds and beasts from the bodies from the beginning of harvest until rain."), ("Mephibosheth son of Jonathan", "Spared because of the oath between David and Jonathan."), ("David's men", "Kill the Philistine giants and tell David not to go out to battle again.")],
    themes=[("A wrong that was not forgotten", "The famine is for Saul's bloody house because he killed the Gibeonites."), ("An oath kept", "David spares Mephibosheth because of the LORD'S oath between him and Jonathan."), ("Rizpah's watch", "Her long vigil leads David to bury the bones properly.")],
)
CH[22] = dict(
    summary="David speaks the words of this song to the LORD in the day that the LORD had delivered him out of the hand of all his enemies, and out of the hand of Saul (2 Samuel 22:1). He says, \"The LORD is my rock, and my fortress, and my deliverer\" (2 Samuel 22:2–4). He tells how the waves of death surrounded him, he called on the LORD, and the earth shook, smoke went up, and the LORD rode upon a cherub and drew him out of many waters (2 Samuel 22:5–20). The LORD rewarded him according to his righteousness, for with the merciful he will show himself merciful (2 Samuel 22:21–28). David says, \"thou art my lamp, O LORD,\" and that by his God he has leaped over a wall, and \"As for God, his way is perfect\" (2 Samuel 22:29–31). God is his strength and makes his feet like hinds' feet and teaches his hands to war (2 Samuel 22:32–43). He praises the LORD among the heathen and says the LORD shows mercy to his anointed, to David, and to his seed for evermore (2 Samuel 22:44–51).",
    wwa="Chapter 21 ended with David's men keeping him from battle. This chapter is a long song of thanks to the LORD for rescuing David from his enemies, and it appears again as Psalm 18. Chapter 23 gives David's last words.",
    people=[("David", "Sings that the LORD is his rock, fortress, and deliverer."), ("The LORD", "Hears David's cry, comes down in storm, delivers him, and shows mercy to his anointed.")],
    themes=[("The LORD my rock", "David calls the LORD his rock, fortress, shield, and high tower."), ("Thanks after rescue", "David says the LORD delivered him \"because he delighted in me.\""), ("A perfect way", "\"As for God, his way is perfect,\" David sings, and \"the word of the LORD is tried.\"")],
)
CH[23] = dict(
    summary="These are the last words of David, the sweet psalmist of Israel, who says, \"The Spirit of the LORD spake by me, and his word was in my tongue\" (2 Samuel 23:1–2). One who rules over men must be just, ruling in the fear of God, and he will be like the light of the morning, and God has made with David an everlasting covenant, ordered in all things, and sure (2 Samuel 23:3–5). The sons of Belial shall be thrust away like thorns (2 Samuel 23:6–7). The chapter lists David's mighty men: Adino the Eznite, who lifted up his spear against eight hundred, Eleazar, whose hand clave to the sword, and Shammah, who held a piece of ground full of lentils (2 Samuel 23:8–12). Three mighty men break through the host of the Philistines to draw water from the well of Bethlehem, but David will not drink it and pours it out to the LORD, saying, \"is not this the blood of the men that went in jeopardy of their lives?\" (2 Samuel 23:13–17). The list goes on with Abishai and Benaiah and ends with Uriah the Hittite, thirty and seven in all (2 Samuel 23:18–39).",
    wwa="Chapter 22 was David's song of thanks. This chapter gives his last words about a just ruler and God's covenant, then a list of his bravest men, ending with the name of Uriah the Hittite. Chapter 24 closes the book with the census.",
    people=[("David", "Speaks his last words and pours out the water as an offering."), ("Adino, Eleazar, and Shammah", "Three mighty men who each stood against the Philistines."), ("The three who drew the water", "Break through the Philistine host to bring water from Bethlehem."), ("Abishai", "Chief of the three, who lifted up his spear against three hundred."), ("Benaiah", "Kills two lionlike men of Moab, a lion in a pit, and an Egyptian.")],
    themes=[("A just ruler", "\"He that ruleth over men must be just, ruling in the fear of God.\""), ("An everlasting covenant", "David says God \"hath made with me an everlasting covenant, ordered in all things, and sure.\""), ("Water poured out", "David will not drink water bought with the blood of his men, and pours it out to the LORD.")],
)
CH[24] = dict(
    summary="The anger of the LORD is kindled against Israel, and David is moved to say, \"Go, number Israel and Judah,\" and Joab asks why the king delights in this thing, but the king's word wins (2 Samuel 24:1–4). Joab and the captains go through the land, and after nine months and twenty days they bring in eight hundred thousand men in Israel and five hundred thousand in Judah (2 Samuel 24:5–9). David's heart troubles him, and he says, \"I have sinned greatly in that I have done,\" and Gad the prophet offers him seven years of famine, three months of flight, or three days of plague (2 Samuel 24:10–13). David says, \"let us fall now into the hand of the LORD; for his mercies are great,\" and seventy thousand men die, and when the angel stretches out his hand over Jerusalem, the LORD says, \"It is enough: stay now thine hand\" (2 Samuel 24:14–16). David says, \"Lo, I have sinned,\" and asks, \"these sheep, what have they done?\" (2 Samuel 24:17). Gad tells David to build an altar on the threshing floor of Araunah the Jebusite, and David buys it for fifty shekels of silver, saying, \"neither will I offer burnt offerings unto the LORD my God of that which doth cost me nothing,\" and the plague is stopped (2 Samuel 24:18–25).",
    wwa="Chapter 23 ended with David's mighty men. This chapter closes the book: David numbers the people, a plague falls, and David buys Araunah's threshing floor and builds an altar, where the plague stops. 1 Kings follows, with David's last days and Solomon.",
    people=[("David", "Numbers the people, confesses his sin, chooses the LORD's hand, and buys the threshing floor."), ("Joab", "Asks the king not to do it, then does the counting."), ("Gad the prophet", "Gives David the three choices and tells him to build an altar."), ("Araunah the Jebusite", "Offers the threshing floor free, but David pays."), ("The angel", "Stretches out his hand over Jerusalem until the LORD says, \"It is enough.\"")],
    themes=[("Numbering the people", "David is moved to number Israel and Judah, and his heart troubles him afterward."), ("Judgment and mercy", "David chooses the hand of the LORD, whose mercies are great, and the LORD says, \"It is enough.\""), ("An offering that costs", "David will not offer burnt offerings to the LORD that cost him nothing.")],
)


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "10_2_samuel.json"
    data = load(path)
    for number, fields in CH.items():
        entry = data[f"2 Samuel {number}"]
        entry["summary"] = fields["summary"]
        entry["whereWeAre"] = fields["wwa"]
        entry["keyFigures"] = [{"name": n, "role": r} for n, r in fields["people"]]
        old = entry["keyThemes"]
        refs = fields.get("refs") or [t["references"] for t in old]
        if len(fields["themes"]) != len(refs):
            raise SystemExit(f"2 Samuel {number}: {len(fields['themes'])} themes but {len(refs)} reference lists")
        entry["keyThemes"] = [{"theme": t, "explanation": e, "references": r} for (t, e), r in zip(fields["themes"], refs)]
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


# Original Audience text: who first heard it and what they knew (places stay in Historical Moment).
AUDIENCE = {
    2: "The first Israelites who heard this book knew the later split between north and south after Solomon (1 Kings 12). They saw its first sign here, with Judah following David while the rest of Israel followed Saul's son.",
    3: "The first Israelites who heard this book knew Amnon, Absalom, and Adonijah, the sons of David listed here (2 Samuel 3:2–5), and how their stories ended in trouble. They heard how David kept clear of Abner's murder and mourned him in public.",
    5: "The first Israelites who heard this book knew Jerusalem as the city where the temple stood and where David's family ruled, and they sang of Zion in worship (Psalm 48). They heard how the city first came to David, and how he won by asking the LORD.",
    8: "The first Israelites who heard this book knew these nations as old neighbors and enemies, and they remembered David's reign as the time when Israel was strongest. They heard that the LORD kept David safe wherever he went.",
    10: "The first Israelites who heard this book knew the Ammonites as an old enemy (Judges 11) and knew that David's army would soon besiege their capital (2 Samuel 11–12). They heard how a kind gesture was met with insult and war.",
    15: "The first Israelites who heard this book remembered Absalom's revolt as the worst trouble of David's reign. They heard how a son won the people's hearts with smooth words, and how David accepted the LORD's will and sent the ark back.",
    16: "The first Israelites who heard this book knew that Solomon later dealt with Shimei (1 Kings 2:8–9, 36–46). They heard how David bore insults, and how Absalom's shameful act in public fulfilled Nathan's warning (2 Samuel 12:11–12).",
    17: "The first Israelites who heard this book knew that Absalom's revolt was crushed. They heard how David's friends and the LORD defeated Ahithophel's wise advice, and how ordinary people helped David in his flight.",
    22: "The first Israelites who heard this book sang David's songs in worship and knew him as \"the sweet psalmist of Israel\" (2 Samuel 23:1). They heard him praise the LORD as his rock and shield.",
    24: "The first Israelites who heard this book knew that Solomon's temple later stood where David built this altar (2 Chronicles 3:1), and they remembered the plague as a time of judgment and mercy. They heard that David chose the LORD's mercy and refused a free offering.",
}


def apply_chapter_context():
    path = ROOT / "chapter_context" / "10_2_samuel.json"
    data = load(path)
    for number, text in AUDIENCE.items():
        data[f"2 Samuel {number}"]["audience"] = text
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_historical_moments():
    path = ROOT / "historical_moments" / "04_samuel.json"
    data = load(path)
    data["2 Samuel 5"] = replace_once(
        data["2 Samuel 5"],
        "mentions the ‘house of David.’",
        "mentions the house of David.",
        "2 Samuel 5 moment",
    )
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_book_overview():
    path = ROOT / "book_overviews" / "02_early_history.json"
    data = load(path)
    book = data["2 Samuel"]
    book["author"] = replace_once(
        book["author"],
        "Nathan and Gad are the traditional sources named for David's reign, though 2 Samuel does not name a single writer.",
        "1 and 2 Samuel were one book. Jewish tradition credits Samuel for the early part and Nathan and Gad for the story of David's reign (1 Chronicles 29:29), though 2 Samuel does not name its writer.",
        "author",
    )
    book["audience"] = replace_once(
        book["audience"],
        "Israel and later readers reflecting on David's monarchy and the LORD's covenant with his house.",
        "Israelites in the days of the kings, who lived under David's family line and wanted to know how it began.",
        "audience",
    )
    for figure in book["keyFigures"]:
        if figure["name"] == "Ish-bosheth":
            figure["name"] = "Ishbosheth"
        if figure["name"] == "Mephibosheth":
            figure["description"] = replace_once(figure["description"], "Jonathan's disabled son, to whom", "Jonathan's son, lame in both feet, to whom", "Mephibosheth")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_FIXES = [
    ("such as Nathan and Gad.", "such as Nathan and Gad (1 Chronicles 29:29)."),
    ("This time the Levites carry the ark properly, and every six steps they offer sacrifices.",
     "This time, when those who carry the ark have gone six steps, David offers an ox and a fatling."),
    ("and his kingdom grows from the Euphrates River to the border of Egypt.", "and his kingdom reaches as far as the Euphrates River."),
    ("and his armor-bearers finish him off.", "and ten young men who carry Joab's armour finish him off."),
    ("fought an Egyptian giant with only a club", "fought a large Egyptian with only a club"),
    ("three choices of punishment: three years of famine,", "three choices of punishment: seven years of famine,"),
    ("David seems to have been trusting in the size of his army rather than in God.", "Many readers think David was trusting in the size of his army rather than in God."),
    ("God's anger burns against Israel, and David decides to take a census", "God's anger burns against Israel again, and David is moved to take a census"),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "02_early_history.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("\n# 2 Samuel") + 1
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
