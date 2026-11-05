#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Full quality pass for 1 Kings: plain summaries with outline citations, exact KJV quotes,
roles without citations, distinct Original Audience text, KJV facts and spellings in notes and story.

Run once, after review_1_kings.py.
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
    summary="King David is old and weak, and his servants find a young woman, Abishag the Shunammite, to care for him and keep him warm, but \"the king knew her not\" (1 Kings 1:1–4). Adonijah the son of Haggith lifts himself up, saying, \"I will be king,\" and with Joab and Abiathar he holds a feast by Enrogel, but he does not invite Nathan, Zadok, Benaiah, or Solomon (1 Kings 1:5–10). Nathan tells Bathsheba to remind David that he swore Solomon would reign, and Nathan comes in to back her up (1 Kings 1:11–27). David swears that Solomon shall reign and tells Zadok and Nathan to set Solomon on the king's mule, take him to Gihon, and anoint him (1 Kings 1:28–40). Adonijah's guests hear the trumpet and the shout, \"God save king Solomon,\" and flee, and Adonijah takes hold of the horns of the altar (1 Kings 1:41–51). Solomon says that if Adonijah shows himself a worthy man, not a hair of him shall fall, but if wickedness is found in him he shall die, and sends him home (1 Kings 1:52–53).",
    wwa="2 Samuel ended with David's altar at Araunah's threshing floor, and 1 Kings opens with David very old and his son Adonijah trying to make himself king. This chapter shows Nathan and Bathsheba moving David to have Solomon anointed. Chapter 2 gives David's last words and Solomon's first acts as king.",
    people=[("David", "Old and cold, he swears to Bathsheba that Solomon shall reign and has him anointed."), ("Adonijah", "Lifts himself up as king, then holds the horns of the altar in fear."), ("Solomon", "Anointed king at Gihon, and spares Adonijah if he proves worthy."), ("Bathsheba", "Reminds David of his oath."), ("Nathan", "Tells Bathsheba what to say and backs her up before the king."), ("Zadok", "The priest who takes the horn of oil and anoints Solomon.")],
    themes=[("A grab for the throne", "Adonijah makes himself king without asking his father, and invites only some of the court."), ("A king chosen in public", "Solomon rides David's mule to Gihon and is anointed, and the people shout, \"God save king Solomon.\""), ("Mercy with a condition", "Solomon says Adonijah will live if he shows himself \"a worthy man,\" but will die if wickedness is found in him.")],
)
CH[2] = dict(
    summary="David charges Solomon, saying, \"I go the way of all the earth: be thou strong therefore, and shew thyself a man,\" and tells him to keep the charge of the LORD his God (1 Kings 2:1–4). He tells Solomon not to let Joab go down to the grave in peace for killing Abner and Amasa, to show kindness to the sons of Barzillai, and to deal with Shimei, who cursed him (1 Kings 2:5–9). David dies after reigning forty years, and the kingdom is established in Solomon's hand (1 Kings 2:10–12). Adonijah asks Bathsheba to ask Solomon for Abishag, and Solomon says Adonijah might as well ask for the kingdom, and sends Benaiah, who kills him (1 Kings 2:13–25). Solomon sends Abiathar to Anathoth, and when Joab flees to the horns of the altar, Benaiah kills him there, and Zadok and Benaiah take their places (1 Kings 2:26–35). Solomon makes Shimei build a house in Jerusalem and never cross the brook Kidron, and three years later Shimei goes to Gath, and Benaiah kills him, and the kingdom is established in Solomon's hand (1 Kings 2:36–46).",
    wwa="Chapter 1 ended with Solomon anointed and Adonijah sent home. This chapter gives David's last words, his death after forty years, and Solomon's removal of Adonijah, Abiathar, Joab, and Shimei, so that the kingdom is established in his hand. Chapter 3 shows him asking for wisdom.",
    people=[("David", "Charges Solomon to keep the LORD's ways and to deal with Joab and Shimei, then dies."), ("Solomon", "Has Adonijah, Joab, and Shimei put to death and removes Abiathar."), ("Adonijah", "Asks for Abishag through Bathsheba and is killed."), ("Bathsheba", "Brings Adonijah's request to Solomon."), ("Abiathar", "Sent to Anathoth for backing Adonijah."), ("Joab", "Flees to the altar and is killed there by Benaiah.")],
    themes=[("Keeping the LORD's charge", "David tells Solomon to walk in the LORD's ways, \"that thou mayest prosper in all that thou doest.\""), ("A throne made safe", "Adonijah's request for Abishag is taken as a new claim to the kingdom."), ("Hard judgments", "Joab, Abiathar, and Shimei are each dealt with, and \"the kingdom was established in the hand of Solomon.\"")],
)
CH[3] = dict(
    summary="Solomon makes an alliance with Pharaoh king of Egypt by taking his daughter, and the people still sacrifice in high places because no house has yet been built for the name of the LORD (1 Kings 3:1–2). Solomon loves the LORD, walking in the statutes of David his father, and goes to Gibeon, the great high place, and offers a thousand burnt offerings (1 Kings 3:3–4). The LORD appears to him in a dream and says, \"Ask what I shall give thee,\" and Solomon says he is but a little child and asks for an understanding heart to judge God's people (1 Kings 3:5–9). The LORD is pleased that he did not ask for long life, riches, or the life of his enemies, and gives him a wise and understanding heart, and riches and honour besides (1 Kings 3:10–15). Two harlots come before the king, each claiming the living child, and Solomon says, \"Bring me a sword,\" and the true mother says to give the other woman the living child and in no wise slay it (1 Kings 3:16–27). All Israel hears and fears the king, because they see that the wisdom of God is in him (1 Kings 3:28).",
    wwa="Chapter 2 ended with the kingdom established in Solomon's hand. This chapter shows him marrying Pharaoh's daughter, asking the LORD at Gibeon for an understanding heart, and showing that wisdom in the case of the two women. Chapter 4 tells how he ruled.",
    people=[("Solomon", "Asks for an understanding heart and judges between the two women."), ("The LORD", "Appears in a dream and gives Solomon wisdom, riches, and honour."), ("The two harlots", "Come before the king with one living child.")],
    themes=[("Asking for wisdom", "Solomon does not ask for long life or riches, but for an understanding heart to judge God's people."), ("A wise judgment", "He asks for a sword, and the true mother is shown by her love for the child."), ("High places before the house", "The people sacrificed in high places because \"there was no house built unto the name of the LORD.\"")],
)
CH[4] = dict(
    summary="The chapter lists Solomon's princes, including Azariah son of Zadok the priest, scribes, a recorder, Benaiah over the host, and Adoniram over the tribute (1 Kings 4:1–6). He has twelve officers over all Israel, each of whom provides food for the king and his household one month in the year (1 Kings 4:7–19). Judah and Israel are as many as the sand by the sea, eating and drinking and making merry, and Solomon reigns over all kingdoms from the river to the land of the Philistines and the border of Egypt (1 Kings 4:20–21). The daily food for his table is thirty measures of fine flour, sixty measures of meal, ten fat oxen, twenty pasture oxen, a hundred sheep, and game and birds (1 Kings 4:22–28). Judah and Israel live safely, every man under his vine and under his fig tree, from Dan to Beersheba (1 Kings 4:25). God gives Solomon wisdom and largeness of heart, so that he speaks three thousand proverbs and his songs are a thousand and five, and men of all nations come to hear his wisdom (1 Kings 4:29–34).",
    wwa="Chapter 3 ended with all Israel fearing the king for his wisdom. This chapter shows how he ruled: his officers, his twelve districts, a land at peace under vine and fig tree, and his fame for proverbs and songs. Chapter 5 turns to his plans for the temple.",
    people=[("Solomon", "Rules from the river to Egypt and speaks three thousand proverbs."), ("The princes and officers", "Azariah, Benaiah, Adoniram, and others who help him rule."), ("The twelve officers over Israel", "Each provides food for the king one month of the year."), ("The people of Judah and Israel", "Many as the sand by the sea, safe and glad.")],
    themes=[("An ordered kingdom", "Solomon has princes and twelve officers who supply the king's table month by month."), ("Peace and plenty", "Every man lives \"under his vine and under his fig tree.\""), ("Wisdom that draws the world", "God gives him \"largeness of heart,\" and kings send to hear his wisdom.")],
)
CH[5] = dict(
    summary="Hiram king of Tyre, who had always loved David, sends his servants to Solomon (1 Kings 5:1). Solomon tells him that David could not build a house for the LORD because of the wars around him, but now the LORD has given him rest on every side, and he plans to build a house for the name of the LORD (1 Kings 5:2–5). He asks Hiram to have cedar trees cut in Lebanon, because none of Solomon's men can cut timber like the Sidonians (1 Kings 5:6). Hiram rejoices and says, \"Blessed be the LORD this day, which hath given unto David a wise son,\" and he agrees to send cedar and fir by sea in floats (1 Kings 5:7–9). Solomon gives Hiram twenty thousand measures of wheat and twenty measures of pure oil year by year, and there is peace and a league between them (1 Kings 5:10–12). Solomon raises a levy of thirty thousand men, ten thousand a month in Lebanon, with seventy thousand who carry burdens and eighty thousand who cut stone in the mountains, and great stones are cut for the foundation (1 Kings 5:13–18).",
    wwa="Chapter 4 ended with Solomon's fame. This chapter shows him sending to Hiram of Tyre for cedar to build the house of the LORD, and organizing the workers who will cut and carry the timber and stone. Chapter 6 tells how the temple is built.",
    people=[("Solomon", "Asks Hiram for cedar and raises a levy of workers."), ("Hiram king of Tyre", "Blesses the LORD, and sends cedar and fir for wheat and oil."), ("Adoniram", "Set over the levy of thirty thousand men."), ("The workers", "Thirty thousand in shifts, seventy thousand burden bearers, and eighty thousand stonecutters.")],
    themes=[("Rest for building", "Solomon says the LORD has given him rest on every side, so he will build the house David could not."), ("Partners abroad", "Hiram sends cedar and fir, and Solomon sends wheat and oil, and there is peace between them."), ("The cost in labour", "Solomon raises a levy of thirty thousand men, and many more carry and cut stone.")],
)
CH[6] = dict(
    summary="In the four hundred and eightieth year after the children of Israel came out of Egypt, in the fourth year of Solomon's reign, in the month Zif, he begins to build the house of the LORD (1 Kings 6:1). The house is sixty cubits long (about ninety feet), twenty wide, and thirty high, with a porch, narrow windows, and rooms around it (1 Kings 6:2–10). The stone is made ready before it is brought, so that no hammer, axe, or tool of iron is heard in the house while it is being built (1 Kings 6:7). The word of the LORD comes to Solomon, saying that if he walks in his statutes, the LORD will keep his word to David and dwell among the children of Israel (1 Kings 6:11–13). The inside is covered with cedar carved with gourds and open flowers and overlaid with gold, and in the oracle he sets two cherubims of olive tree ten cubits high (1 Kings 6:14–36). The foundation is laid in the fourth year and the house is finished in the eleventh year, in the month Bul, so that Solomon takes seven years to build it (1 Kings 6:37–38).",
    wwa="Chapter 5 ended with the stones being cut for the foundation. This chapter tells how Solomon builds the temple over seven years, with a word from the LORD in the middle saying that he will dwell among his people if Solomon keeps his statutes. Chapter 7 describes his palace and the temple's bronze work.",
    people=[("Solomon", "Builds the house of the LORD in seven years."), ("The LORD", "Tells Solomon that he will dwell among Israel if they walk in his statutes."), ("The builders", "Prepare the stone at the quarry so that no hammer is heard in the house.")],
    themes=[("A house for the LORD", "The temple has a porch, a main room, and the oracle, with cherubims covered with gold."), ("Obedience matters more than the building", "The LORD tells Solomon he will dwell among Israel if they keep his statutes."), ("Seven years of work", "The house is begun in Zif and finished in Bul seven years later.")],
)
CH[7] = dict(
    summary="Solomon builds his own house for thirteen years, with the house of the forest of Lebanon, a porch of pillars, a porch for the throne where he may judge, and a house for Pharaoh's daughter (1 Kings 7:1–12). King Solomon sends and brings Hiram out of Tyre, a widow's son of the tribe of Naphtali, filled with wisdom and understanding to work all works in bronze (1 Kings 7:13–14). Hiram casts two pillars of bronze, each eighteen cubits high, and names them Jachin and Boaz (1 Kings 7:15–22). He makes a molten sea ten cubits across standing on twelve oxen, ten bases of bronze, and ten lavers (1 Kings 7:23–39). Hiram makes the pots, shovels, and basons, casting them in the plain of Jordan in the clay ground between Succoth and Zarthan, and Solomon does not weigh the bronze because there are so many vessels (1 Kings 7:40–47). Solomon makes the golden altar, the table for the shewbread, and the candlesticks, and brings in the things David his father had dedicated (1 Kings 7:48–51).",
    wwa="Chapter 6 ended with the temple finished. This chapter tells of Solomon's thirteen years building his own houses, and of Hiram of Tyre casting the bronze pillars, the sea, and the other bronze furnishings for the temple. Chapter 8 tells how the ark is brought in.",
    people=[("Solomon", "Builds his palace for thirteen years and has the temple furnished."), ("Hiram of Tyre", "A widow's son filled with wisdom, who casts the bronze work.")],
    themes=[("A palace beside the temple", "Solomon spends thirteen years on his own houses, the forest of Lebanon, the throne porch, and Pharaoh's daughter's house."), ("Skilled craftsmen", "Hiram makes the pillars Jachin and Boaz, the molten sea, and the lavers."), ("Gifts set apart", "David's dedicated treasures go into the house of the LORD.")],
    refs=[["1 Kings 7:1-12"], ["1 Kings 7:13-47"], ["1 Kings 7:48-51"]],
)
CH[8] = dict(
    summary="Solomon gathers the elders of Israel to Jerusalem to bring the ark of the covenant of the LORD up out of the city of David at the feast in the month Ethanim, and the priests bring it into the oracle under the wings of the cherubims (1 Kings 8:1–9). When the priests come out, the cloud fills the house of the LORD, so that they cannot stand to minister, for the glory of the LORD has filled the house (1 Kings 8:10–11). Solomon blesses the congregation and prays, \"LORD God of Israel, there is no God like thee\" (1 Kings 8:12–26). He asks, \"will God indeed dwell on the earth?\" since the heaven and heaven of heavens cannot contain him, and asks him to hear in heaven his dwelling place (1 Kings 8:27–30). He asks the LORD to hear when a man trespasses, when Israel is beaten by enemies, when there is no rain, famine, or plague, when a stranger prays toward this house, and when they sin and are carried away captive (1 Kings 8:31–53). Solomon blesses the people, saying, \"Let your heart therefore be perfect with the LORD our God,\" and offers twenty-two thousand oxen and a hundred and twenty thousand sheep, and keeps the feast fourteen days (1 Kings 8:54–66).",
    wwa="Chapter 7 ended with the temple furnished. This chapter is the dedication: the ark is brought in, the glory of the LORD fills the house, Solomon prays, and the people keep a great feast. Chapter 9 gives the LORD's answer to him.",
    people=[("Solomon", "Brings in the ark, blesses the people, and prays the long prayer."), ("The priests", "Carry the ark into the oracle and come out when the cloud fills the house."), ("The elders and congregation of Israel", "Gather at the feast of Ethanim and are blessed."), ("The LORD", "Fills the house with his glory, and is asked to hear in heaven his dwelling place.")],
    themes=[("God is near and yet too great for a house", "The glory fills the house, yet Solomon says \"the heaven and heaven of heavens cannot contain thee.\""), ("A prayer for every trouble", "Solomon asks the LORD to hear sin, defeat, drought, famine, and captivity when the people pray toward this house."), ("Even the stranger", "Solomon asks the LORD to hear the stranger who comes \"out of a far country for thy name's sake.\""), ("A whole heart", "Solomon tells the people to let their heart be \"perfect with the LORD our God\" and keep his statutes.")],
    refs=[["1 Kings 8:10-11", "1 Kings 8:27"], ["1 Kings 8:31-50"], ["1 Kings 8:41-43"], ["1 Kings 8:56-61"]],
)
CH[9] = dict(
    summary="When Solomon has finished the house of the LORD and the king's house, the LORD appears to him the second time, as he appeared at Gibeon (1 Kings 9:1–2). He says, \"I have heard thy prayer,\" and \"I have hallowed this house,\" and his eyes and his heart will be there always (1 Kings 9:3). If Solomon walks before him as David did, he will establish his throne for ever, but if they turn away and serve other gods, he will cut off Israel out of the land and cast this house out of his sight (1 Kings 9:4–9). After twenty years Solomon gives Hiram twenty cities in Galilee, and Hiram does not like them and calls them the land of Cabul (1 Kings 9:10–14). Solomon raises a levy to build the house of the LORD, his own house, Millo, the wall of Jerusalem, Hazor, Megiddo, and Gezer, using the people left of the Amorites, Hittites, and others as bondservants, but he makes no bondmen of the children of Israel (1 Kings 9:15–23). He offers burnt offerings and peace offerings three times a year, and builds a navy at Eziongeber, and Hiram's shipmen bring gold from Ophir (1 Kings 9:24–28).",
    wwa="Chapter 8 ended with the dedication feast. This chapter gives the LORD's answer: he will keep David's throne if Solomon obeys, but will cast the house out of his sight if Israel serves other gods, and then follows Solomon's cities, labour, and ships. Chapter 10 tells of the queen of Sheba.",
    people=[("Solomon", "Receives the LORD's second appearance, and builds cities and ships."), ("The LORD", "Promises to keep David's throne if Solomon walks before him, and warns of cutting off Israel if they turn."), ("Hiram of Tyre", "Does not like the twenty cities and sends gold and shipmen.")],
    themes=[("If you walk before me", "The LORD's promise to David's throne depends on Solomon walking as David did."), ("If you turn away", "If Israel serves other gods, the LORD will cast the house out of his sight, and passersby will ask why."), ("A kingdom built up", "Solomon builds cities, uses non-Israelites as bondservants, and sends ships to Ophir.")],
    refs=[["1 Kings 9:4-5"], ["1 Kings 9:6-9"], ["1 Kings 9:15-28"]],
)
CH[10] = dict(
    summary="When the queen of Sheba hears of the fame of Solomon concerning the name of the LORD, she comes to test him with hard questions, with camels carrying spices, gold, and precious stones (1 Kings 10:1–2). Solomon answers all her questions, and when she sees his wisdom, his house, his table, and the way he goes up to the house of the LORD, there is no more spirit in her (1 Kings 10:3–5). She says, \"It was a true report,\" and, \"the half was not told me,\" and she blesses the LORD for setting Solomon on the throne of Israel (1 Kings 10:6–9). She gives the king a hundred and twenty talents of gold and spices, and Solomon gives her all her desire (1 Kings 10:10–13). Solomon receives six hundred sixty-six talents of gold in one year, makes two hundred targets and three hundred shields of beaten gold, and a great throne of ivory overlaid with the best gold (1 Kings 10:14–20). All his drinking vessels are gold, for silver is nothing accounted of in the days of Solomon, and he surpasses all the kings of the earth for riches and wisdom (1 Kings 10:21–25). He gathers fourteen hundred chariots and twelve thousand horsemen and makes silver in Jerusalem as common as stones, and horses are brought out of Egypt (1 Kings 10:26–29).",
    wwa="Chapter 9 ended with Solomon's ships and cities. This chapter shows the queen of Sheba visiting him, praising the LORD for his wisdom, and then lists his gold, throne, chariots, and horses, which are the height of his wealth. Chapter 11 tells how it all begins to unravel.",
    people=[("The queen of Sheba", "Comes with hard questions, sees Solomon's house, and blesses the LORD."), ("Solomon", "Answers all her questions, gives her her desire, and grows richer than all kings."), ("Hiram's navy", "Brings gold and almug trees from Ophir."), ("The kings and merchants", "Bring presents, spices, and horses to Solomon.")],
    themes=[("Wisdom that is seen", "The queen says it was a true report, and \"the half was not told me.\""), ("Great riches", "Solomon makes shields and a throne of gold, and silver is \"nothing accounted of in the days of Solomon.\""), ("Trade with the world", "He buys horses and chariots from Egypt and sells them to the kings of the Hittites and Syria.")],
)
CH[11] = dict(
    summary="King Solomon loves many foreign women, together with the daughter of Pharaoh, women of the Moabites, Ammonites, Edomites, Zidonians, and Hittites, of whom the LORD had said, \"Ye shall not go in to them\" (1 Kings 11:1–2). He has seven hundred wives, princesses, and three hundred concubines, and when he is old they turn away his heart after other gods, so that his heart is not perfect with the LORD (1 Kings 11:3–6). He builds a high place for Chemosh and for Molech in the hill before Jerusalem (1 Kings 11:7–8). The LORD is angry, since he had appeared to Solomon twice, and says, \"I will surely rend the kingdom from thee,\" but not in Solomon's days, for David's sake, and he will leave one tribe (1 Kings 11:9–13). The LORD raises up adversaries, Hadad the Edomite and Rezon of Damascus, and Ahijah the Shilonite tears a new garment into twelve pieces and gives Jeroboam ten (1 Kings 11:14–31). Solomon seeks to kill Jeroboam, who flees to Shishak in Egypt, and Solomon reigns forty years in Jerusalem, sleeps with his fathers, and Rehoboam his son reigns (1 Kings 11:40–43).",
    wwa="Chapter 10 ended with Solomon's riches and horses. This chapter shows his foreign wives turning his heart to other gods, the LORD's word that the kingdom will be torn from his son, and the rise of Jeroboam, whom the prophet Ahijah names for ten tribes. Chapter 12 tells how the kingdom splits.",
    people=[("Solomon", "Loves many foreign women, builds high places for their gods, and is told the kingdom will be torn away."), ("His wives", "Seven hundred wives and three hundred concubines who turn away his heart."), ("The LORD", "Is angry and says he will tear the kingdom away, but leaves one tribe for David's sake."), ("Hadad and Rezon", "Adversaries raised up against Solomon."), ("Ahijah the Shilonite", "Tears a new garment into twelve pieces to give Jeroboam ten."), ("Jeroboam", "Told he will have ten tribes, he flees to Egypt.")],
    themes=[("A heart turned away", "Solomon's wives turn his heart after other gods when he is old."), ("Judgment and a promise kept", "The kingdom will be torn away, but one tribe remains for David's sake and Jerusalem's."), ("A torn garment", "Ahijah tears a new garment into twelve pieces to show Jeroboam gets ten tribes.")],
)
CH[12] = dict(
    summary="Rehoboam goes to Shechem to be made king, and Jeroboam, called out of Egypt, and all Israel say, \"Thy father made our yoke grievous,\" and ask him to make it lighter (1 Kings 12:1–4). The old men tell him that if he will serve this people they will be his servants for ever, but the young men say, \"My little finger shall be thicker than my father's loins,\" and that where his father punished them with whips, he will punish them with scorpions (1 Kings 12:5–15). Israel answers, \"What portion have we in David?\" and \"to your tents, O Israel,\" and only the tribe of Judah follows the house of David, and they make Jeroboam king (1 Kings 12:16–20). Rehoboam gathers an army, but Shemaiah the man of God tells him not to fight against his brethren, \"for this thing is from me,\" and they listen (1 Kings 12:21–24). Jeroboam fears the people will return to Rehoboam, so he makes two calves of gold and says, \"It is too much for you to go up to Jerusalem: behold thy gods, O Israel,\" and sets them in Bethel and in Dan (1 Kings 12:25–30). He makes priests of the lowest of the people and sets a feast in the eighth month, and \"this thing became a sin\" (1 Kings 12:31–33).",
    wwa="Chapter 11 ended with Solomon's death and Jeroboam in Egypt. This chapter tells how Rehoboam answers Israel harshly, ten tribes leave him and make Jeroboam king, and Jeroboam sets up golden calves at Bethel and Dan so that his people will not go to Jerusalem. Chapter 13 tells of a man of God at Bethel.",
    people=[("Rehoboam", "Rejects the old men's advice and answers Israel harshly."), ("Jeroboam", "Comes back from Egypt, is made king, and sets up golden calves at Bethel and Dan."), ("The old men and the young men", "Give opposite advice to Rehoboam."), ("Israel", "Say, \"to your tents, O Israel,\" and leave the house of David."), ("Shemaiah the man of God", "Tells Rehoboam not to fight against his brethren.")],
    themes=[("A king who will not listen", "Rehoboam turns from the old men's advice and takes the young men's."), ("The split", "Israel asks, \"What portion have we in David?\" and only Judah stays with Rehoboam."), ("A made-up religion", "Jeroboam sets up calves, other priests, and a new feast, so his people will not go to Jerusalem.")],
)
CH[13] = dict(
    summary="A man of God comes out of Judah to Bethel as Jeroboam stands by the altar to burn incense, and cries out against the altar that a child named Josiah will be born to the house of David and burn men's bones on it (1 Kings 13:1–2). The altar is torn apart and the ashes poured out, and when Jeroboam puts out his hand and says, \"Lay hold on him,\" his hand dries up, and the man of God prays and it is restored (1 Kings 13:3–6). Jeroboam asks him home for a reward, but the man says he was told not to eat bread or drink water in this place or go back the same way (1 Kings 13:7–10). An old prophet at Bethel follows him and says an angel told him to bring him back, but he lied, and the man of God goes and eats (1 Kings 13:11–19). The word of the LORD comes against him for disobeying, and on his way a lion meets him and kills him, and the donkey and the lion stand by the body (1 Kings 13:20–25). The old prophet buries him in his own grave and says, \"Alas, my brother!\" and Jeroboam does not turn from his evil way, and this thing becomes sin to the house of Jeroboam (1 Kings 13:26–34).",
    wwa="Chapter 12 ended with Jeroboam's calves and priests at Bethel. This chapter tells how a man of God from Judah speaks against Jeroboam's altar, but then disobeys the word given him and is killed, while Jeroboam goes on in his evil way. Chapter 14 tells how judgment comes to Jeroboam's house.",
    people=[("The man of God from Judah", "Speaks against the altar, then eats at Bethel against his charge and is killed by a lion."), ("Jeroboam", "Stretches out his hand, is healed, and does not turn from his evil way."), ("The old prophet of Bethel", "Lies to the man of God, then buries him and mourns."), ("The LORD", "Gives the sign at the altar and the word of judgment.")],
    themes=[("The word of the LORD is true", "The altar is torn apart as the man of God said."), ("A lie that sounded holy", "The old prophet says an angel spoke to him, but the LORD had given a different charge."), ("No turning back", "Jeroboam does not turn from his evil way and goes on making priests of the lowest people.")],
)
CH[14] = dict(
    summary="Abijah the son of Jeroboam falls sick, and Jeroboam tells his wife to disguise herself and go to Ahijah the prophet at Shiloh with ten loaves, cracknels, and a cruse of honey (1 Kings 14:1–4). The LORD tells Ahijah she is coming, and he says, \"Come in, thou wife of Jeroboam; why feignest thou thyself to be another?\" and tells her he has heavy news (1 Kings 14:5–6). He says that Jeroboam has done evil above all who were before him, making other gods and casting the LORD behind his back, so the LORD will take away the rest of his house as a man takes away dung (1 Kings 14:7–11). When her feet enter the city, the child will die, and all Israel will mourn him, because in him is found \"some good thing toward the LORD God of Israel\" (1 Kings 14:12–18). Jeroboam reigns twenty-two years, and Nadab his son reigns in his place (1 Kings 14:19–20). Rehoboam reigns seventeen years in Jerusalem, and Judah builds high places, images, and groves on every high hill and under every green tree (1 Kings 14:21–24). In Rehoboam's fifth year Shishak king of Egypt takes the treasures of the house of the LORD and the gold shields, and Rehoboam makes bronze shields in their place, and there is war between Rehoboam and Jeroboam all their days (1 Kings 14:25–31).",
    wwa="Chapter 13 ended with Jeroboam's evil continuing. This chapter tells how Ahijah foretells the end of Jeroboam's house and the death of his sick son, and how Judah under Rehoboam also does evil and is raided by Shishak of Egypt. Chapter 15 follows the kings who come next.",
    people=[("Jeroboam", "Sends his wife in disguise to ask about his sick son."), ("Jeroboam's wife", "Goes to Shiloh and hears the heavy news."), ("Ahijah the prophet", "Old and blind, he knows her and tells of judgment on Jeroboam's house."), ("Abijah", "Jeroboam's son, who dies and is mourned because some good thing is found in him."), ("Rehoboam", "King of Judah, whose treasures are taken by Shishak."), ("Shishak", "King of Egypt, who comes up against Jerusalem.")],
    themes=[("The end of a house", "Ahijah says the LORD will cut off the house of Jeroboam because he made other gods and cast the LORD behind his back."), ("A good thing in a sick boy", "The child will be buried in peace because in him is found \"some good thing toward the LORD God of Israel.\""), ("Judah does evil too", "Under Rehoboam, Judah builds high places, images, and groves, and Shishak takes the temple treasures.")],
)
CH[15] = dict(
    summary="Abijam reigns three years in Jerusalem and walks in all the sins of his father, but for David's sake the LORD gives him a lamp in Jerusalem (1 Kings 15:1–8). Asa reigns forty-one years and does right in the eyes of the LORD, as David did, taking away the male shrine prostitutes and the idols, and he removes his mother Maachah from being queen because she made an idol in a grove, though the high places are not removed (1 Kings 15:9–15). Baasha king of Israel builds Ramah, and Asa takes the silver and gold from the treasures of the house of the LORD and sends it to Benhadad king of Syria, who breaks his league with Baasha and strikes Ijon, Dan, and Abelbethmaachah (1 Kings 15:16–22). Asa takes away the stones of Ramah and builds Geba and Mizpah, and Jehoshaphat his son reigns after him (1 Kings 15:22–24). Nadab son of Jeroboam reigns two years in Israel, and Baasha plots against him, strikes him down, and kills all the house of Jeroboam, as the LORD said by Ahijah (1 Kings 15:25–30). Baasha reigns twenty-four years and walks in the way of Jeroboam (1 Kings 15:31–34).",
    wwa="Chapter 14 ended with war between Rehoboam and Jeroboam. This chapter moves quickly between the two kingdoms: Abijam and Asa in Judah, Nadab and Baasha in Israel, with Asa doing right but paying Syria with temple silver, and Baasha ending the house of Jeroboam. Chapter 16 follows the kings of Israel.",
    people=[("Abijam", "King of Judah, who walks in his father's sins."), ("Asa", "King of Judah, who does right, removes idols, and pays Benhadad."), ("Maachah", "Asa's mother, removed from being queen because of her idol."), ("Baasha", "Plots against Nadab, kills the house of Jeroboam, and walks in his way."), ("Nadab", "Jeroboam's son, who reigns two years and is killed."), ("Benhadad king of Syria", "Is paid by Asa to break his league with Baasha.")],
    themes=[("A king who did right, but not all", "Asa removes idols and his mother's idol, yet the high places remain."), ("Buying help", "Asa takes silver and gold from the house of the LORD to send to Benhadad."), ("Blood on the throne", "Baasha kills Nadab and all the house of Jeroboam as Ahijah had said.")],
    refs=[["1 Kings 15:11-15"], ["1 Kings 15:16-22"], ["1 Kings 15:25-30"]],
)
CH[16] = dict(
    summary="The word of the LORD comes to Jehu the son of Hanani against Baasha, saying that because he walked in the way of Jeroboam, the LORD will take away the house of Baasha (1 Kings 16:1–7). Elah his son reigns two years in Tirzah, and Zimri, captain of half his chariots, kills him while he is drinking himself drunk and kills all the house of Baasha (1 Kings 16:8–14). Zimri reigns seven days in Tirzah, and the people make Omri king, and Zimri burns the king's house over him with fire and dies (1 Kings 16:15–20). Half the people follow Tibni and half follow Omri, and Omri prevails, and Tibni dies (1 Kings 16:21–22). Omri buys the hill Samaria of Shemer for two talents of silver and builds a city, and does worse than all who were before him (1 Kings 16:23–28). Ahab his son reigns twenty-two years and does evil above all who were before him, takes Jezebel the daughter of Ethbaal king of the Zidonians, and serves Baal, setting up an altar and a grove in Samaria (1 Kings 16:29–33). In his days Hiel the Bethelite builds Jericho, and loses Abiram his firstborn and Segub his youngest, as the LORD said by Joshua (1 Kings 16:34).",
    wwa="Chapter 15 ended with Baasha in Israel. This chapter shows the kings of Israel falling one after another, from Elah and Zimri to Omri, who builds Samaria, and then Ahab, who marries Jezebel and sets up Baal worship in the capital. Chapter 17 introduces Elijah.",
    people=[("Jehu the son of Hanani", "Brings the LORD's word against Baasha."), ("Elah", "Baasha's son, killed by Zimri while drunk."), ("Zimri", "Kills Elah and the house of Baasha, reigns seven days, and burns the king's house over himself."), ("Omri", "Made king by the army, buys the hill of Samaria, and does worse than all before him."), ("Ahab", "Marries Jezebel, serves Baal, and builds a house and altar for him in Samaria."), ("Jezebel", "The daughter of Ethbaal king of the Zidonians, Ahab's wife.")],
    themes=[("Kings who kill kings", "Zimri kills Elah, and the people then make Omri king, and Zimri burns the palace."), ("A new capital", "Omri buys the hill Samaria for two talents of silver and builds a city."), ("Baal in Samaria", "Ahab marries Jezebel, builds an altar and a house for Baal, and does more to provoke the LORD than all before him.")],
    refs=[["1 Kings 16:8-22"], ["1 Kings 16:23-28"], ["1 Kings 16:29-33"]],
)
CH[17] = dict(
    summary="Elijah the Tishbite tells Ahab, \"As the LORD God of Israel liveth, before whom I stand, there shall not be dew nor rain these years, but according to my word\" (1 Kings 17:1). The LORD sends him to hide by the brook Cherith, where the ravens bring him bread and flesh morning and evening, until the brook dries up (1 Kings 17:2–7). The LORD tells him to go to Zarephath, which belongs to Zidon, where a widow woman will feed him, and she says she has only a handful of meal in a barrel and a little oil in a cruse (1 Kings 17:8–12). Elijah says, \"Fear not,\" and tells her to make him a little cake first, because the barrel of meal will not run out and the cruse of oil will not fail until the LORD sends rain, and so it is (1 Kings 17:13–16). The widow's son falls sick and there is no breath left in him, and she asks Elijah, \"art thou come unto me to call my sin to remembrance, and to slay my son?\" (1 Kings 17:17–18). Elijah carries the child up to his loft, stretches himself on him three times, and cries, \"let this child's soul come into him again,\" and the LORD hears him, and he says, \"See, thy son liveth\" (1 Kings 17:19–23). The woman says, \"Now by this I know that thou art a man of God, and that the word of the LORD in thy mouth is truth\" (1 Kings 17:24).",
    wwa="Chapter 16 ended with Ahab and his Baal worship. This chapter introduces Elijah, who tells Ahab it will not rain, is fed by ravens, and stays with a widow of Zarephath whose meal and oil do not run out and whose son is raised. Chapter 18 tells of the contest on Carmel.",
    people=[("Elijah", "Announces the drought, is fed by ravens and a widow, and prays for her son."), ("The widow of Zarephath", "Gives Elijah the last of her meal, and her meal and oil do not fail."), ("The widow's son", "Falls sick and dies, and the LORD gives his soul back."), ("The LORD", "Sends Elijah to the brook and to Zarephath and hears his prayer.")],
    themes=[("Fed in the drought", "Ravens bring Elijah bread and flesh, then a widow's meal and oil do not fail."), ("A stranger's kindness", "A widow in Zidon, Jezebel's country, feeds the prophet from her last meal."), ("Prayer and a child's life", "Elijah cries to the LORD, stretches himself on the child three times, and the child's soul comes into him again.")],
)
CH[18] = dict(
    summary="In the third year the word of the LORD comes to Elijah, \"Go, shew thyself unto Ahab; and I will send rain upon the earth,\" and the famine is sore in Samaria (1 Kings 18:1–2). Obadiah, who feared the LORD greatly and had hid a hundred prophets in two caves, meets Elijah and tells Ahab he is there (1 Kings 18:3–16). Ahab asks, \"Art thou he that troubleth Israel?\" and Elijah says it is Ahab who has troubled Israel by forsaking the commandments of the LORD, and he calls Israel and the prophets of Baal to mount Carmel (1 Kings 18:17–20). Elijah asks, \"How long halt ye between two opinions?\" and the people answer him not a word (1 Kings 18:21–24). The prophets of Baal cry from morning until noon and cut themselves, and there is neither voice nor any to answer (1 Kings 18:25–29). Elijah repairs the altar of the LORD, pours water on it, and prays, and the fire of the LORD falls and burns up the sacrifice, and the people say, \"The LORD, he is the God\" (1 Kings 18:30–39). Elijah has the prophets of Baal killed at the brook Kishon, and after he prays seven times a little cloud like a man's hand rises out of the sea, and there is a great rain (1 Kings 18:40–46).",
    wwa="Chapter 17 ended with the widow's faith in the word of the LORD. This chapter is the contest on mount Carmel, where the LORD answers Elijah by fire, the people say, \"The LORD, he is the God,\" the prophets of Baal are killed, and the drought ends with rain. Chapter 19 shows Elijah afraid.",
    people=[("Elijah", "Calls Israel to choose, prays, and runs before Ahab's chariot to Jezreel."), ("Ahab", "Calls Elijah the troubler of Israel and goes to Jezreel in his chariot."), ("Obadiah", "Governor of Ahab's house, who had hid a hundred prophets."), ("The prophets of Baal", "Four hundred and fifty, who cry out and cut themselves with no answer."), ("The people of Israel", "Are silent, then say, \"The LORD, he is the God.\""), ("The LORD", "Answers by fire and sends rain.")],
    themes=[("Choosing between the LORD and Baal", "Elijah asks, \"How long halt ye between two opinions?\""), ("The God who answers by fire", "The fire of the LORD falls and burns up the offering, and the people fall on their faces."), ("The prophets of Baal killed", "Elijah has them taken to the brook Kishon and killed, which the story reports without comment."), ("Rain after prayer", "A little cloud like a man's hand rises, and a great rain follows.")],
    refs=[["1 Kings 18:21-24"], ["1 Kings 18:30-39"], ["1 Kings 18:40"], ["1 Kings 18:41-46"]],
)
CH[19] = dict(
    summary="Ahab tells Jezebel all that Elijah has done, and she sends a messenger to say, \"So let the gods do to me, and more also,\" if she does not make his life like the life of one of the prophets he killed by tomorrow about this time (1 Kings 19:1–2). Elijah goes for his life to Beersheba, goes a day's journey into the wilderness, sits under a juniper tree, and asks that he might die, saying, \"I am not better than my fathers\" (1 Kings 19:3–4). An angel touches him and says, \"Arise and eat,\" and he goes in the strength of that food forty days and forty nights to Horeb the mount of God (1 Kings 19:5–8). The LORD asks, \"What doest thou here, Elijah?\" and he says he has been very jealous for the LORD, and \"I, even I only, am left\" (1 Kings 19:9–10). A great and strong wind, an earthquake, and a fire pass, but the LORD is not in them, and after the fire comes a still small voice (1 Kings 19:11–13). The LORD tells him to anoint Hazael king over Syria, Jehu king over Israel, and Elisha to be prophet in his place, and says he has left seven thousand in Israel who have not bowed to Baal (1 Kings 19:14–18). Elijah casts his mantle on Elisha, who is plowing with twelve yoke of oxen, and Elisha kills his oxen, follows Elijah, and serves him (1 Kings 19:19–21).",
    wwa="Chapter 18 ended with Elijah running before Ahab's chariot. This chapter shows Elijah, afraid of Jezebel, running to the wilderness and Horeb, where the LORD speaks in a still small voice, tells him he is not alone, and gives him Elisha. Chapter 20 turns back to Ahab and Syria.",
    people=[("Elijah", "Flees from Jezebel, asks to die, meets the LORD at Horeb, and calls Elisha."), ("Jezebel", "Sends a messenger to say she will kill him by tomorrow."), ("The angel", "Touches Elijah and tells him, \"Arise and eat.\""), ("The LORD", "Speaks in a still small voice and gives Elijah three tasks."), ("Elisha", "A plowman who leaves his oxen and follows Elijah.")],
    themes=[("Tired and afraid", "Elijah asks to die, and the angel gives him bread and water twice."), ("A still small voice", "The LORD is not in the wind, the earthquake, or the fire, but in a still small voice."), ("Not alone", "The LORD says he has seven thousand who have not bowed to Baal."), ("A calling accepted", "Elisha leaves his oxen, burns the plow gear, and follows Elijah.")],
)
CH[20] = dict(
    summary="Benhadad king of Syria gathers his army with thirty-two kings and besieges Samaria, and sends to Ahab, \"Thy silver and thy gold is mine\" (1 Kings 20:1–3). Ahab agrees, but when Benhadad says his servants will search the houses, Ahab and the elders refuse, and Ahab says, \"Let not him that girdeth on his harness boast himself as he that putteth it off\" (1 Kings 20:4–11). A prophet tells Ahab the LORD will give the great crowd into his hand, \"and thou shalt know that I am the LORD,\" and two hundred thirty-two young men with seven thousand Israelites go out and the Syrians flee (1 Kings 20:13–21). The next year the Syrians say, \"Their gods are gods of the hills,\" so a man of God says the LORD will give them into Ahab's hand, and Israel kills a hundred thousand footmen in one day at Aphek (1 Kings 20:22–30). Benhadad's servants come in sackcloth with ropes on their heads, and Ahab says, \"he is my brother,\" and makes a covenant and lets him go (1 Kings 20:31–34). A prophet disguised with ashes on his face tells Ahab, \"Thy life shall go for his life, and thy people for his people,\" because he let go a man the LORD had marked for destruction, and Ahab goes home heavy and displeased (1 Kings 20:35–43).",
    wwa="Chapter 19 ended with Elisha following Elijah. This chapter returns to Ahab and the war with Syria: the LORD gives Israel two victories, but Ahab lets Benhadad go and a prophet tells him it will cost his life. Chapter 21 tells of Naboth's vineyard.",
    people=[("Ahab", "Defeats the Syrians twice, then spares Benhadad and makes a covenant."), ("Benhadad king of Syria", "Besieges Samaria, boasts, is defeated, and begs for his life."), ("The prophets", "Promise victory in the LORD's name and later tell Ahab his life will go for Benhadad's."), ("The Syrian servants", "Say the gods of Israel are gods of the hills.")],
    themes=[("Victory for a small people", "The LORD gives Israel the Syrian army so that Ahab will know \"I am the LORD.\""), ("A wrong idea of God", "The Syrians say the LORD is God of the hills, but not of the valleys."), ("Mercy where God said no", "Ahab calls Benhadad his brother and lets him go, and a prophet judges him.")],
)
CH[21] = dict(
    summary="Naboth the Jezreelite has a vineyard next to the palace of Ahab, and Ahab asks for it for a garden of herbs, offering a better vineyard or its worth in money (1 Kings 21:1–2). Naboth says, \"The LORD forbid it me, that I should give the inheritance of my fathers unto thee,\" and Ahab goes home heavy and displeased, lies on his bed, and will eat no bread (1 Kings 21:3–4). Jezebel says, \"Dost thou now govern the kingdom of Israel?\" and writes letters in Ahab's name with his seal, telling the elders to call a fast, set two sons of Belial before Naboth to say he cursed God and the king, and stone him (1 Kings 21:5–10). They do so, and Naboth is stoned and dead, and Jezebel tells Ahab to take the vineyard (1 Kings 21:11–16). The word of the LORD comes to Elijah to meet Ahab in the vineyard, and Ahab says, \"Hast thou found me, O mine enemy?\" and Elijah says, \"I have found thee: because thou hast sold thyself to work evil in the sight of the LORD\" (1 Kings 21:17–20). Elijah says dogs shall lick Ahab's blood and eat Jezebel by the wall of Jezreel (1 Kings 21:19–26). Ahab tears his clothes, puts on sackcloth, and goes softly, and the LORD says he will not bring the evil in Ahab's days, but in his son's days (1 Kings 21:27–29).",
    wwa="Chapter 20 ended with Ahab heavy and displeased in Samaria. This chapter tells how Ahab and Jezebel take Naboth's vineyard by false witnesses and murder, how Elijah announces judgment on them, and how Ahab humbles himself. Chapter 22 tells how Ahab dies.",
    people=[("Ahab", "Wants Naboth's vineyard, sulks, takes it, and then humbles himself."), ("Naboth", "Refuses to sell the inheritance of his fathers and is stoned."), ("Jezebel", "Writes letters in Ahab's name and has Naboth killed by false witnesses."), ("Elijah", "Meets Ahab in the vineyard and tells him judgment will come."), ("The elders and nobles", "Carry out Jezebel's letters.")],
    themes=[("The inheritance of my fathers", "Naboth says, \"The LORD forbid it me, that I should give the inheritance of my fathers unto thee.\""), ("Justice twisted", "Two false witnesses are set up to say Naboth cursed God and the king."), ("The prophet says it to the king's face", "Elijah asks Ahab, \"Hast thou killed, and also taken possession?\""), ("Humbling and delay", "Ahab humbles himself, so the evil is put off to his son's days.")],
)
CH[22] = dict(
    summary="After three years without war, Jehoshaphat king of Judah comes to Ahab, and Ahab asks him to go up with him to Ramothgilead, and Jehoshaphat says, \"I am as thou art,\" but asks him to ask first for the word of the LORD (1 Kings 22:1–5). Four hundred prophets say, \"Go up; for the Lord shall deliver it,\" but Jehoshaphat asks, \"Is there not here a prophet of the LORD besides?\" and Ahab says there is Micaiah, \"but I hate him; for he doth not prophesy good concerning me, but evil\" (1 Kings 22:6–9). Zedekiah makes horns of iron, and Micaiah first says, \"Go, and prosper,\" then tells of Israel scattered as sheep that have not a shepherd (1 Kings 22:10–17). He says he saw the LORD on his throne, and a lying spirit was put in the mouth of all the prophets, and Ahab has Micaiah put in prison (1 Kings 22:18–28). Ahab disguises himself, and the Syrian captains are told to fight only with the king of Israel, and a certain man draws a bow at a venture and hits him between the joints of the harness, and he dies at evening (1 Kings 22:29–37). They bury him in Samaria, and the dogs lick up his blood, and Ahaziah his son reigns (1 Kings 22:38–40). Jehoshaphat reigns twenty-five years and does right in the eyes of the LORD, though the high places are not taken away, and Ahaziah in Israel does evil and serves Baal (1 Kings 22:41–53).",
    wwa="Chapter 21 ended with Ahab humbled but under judgment. This chapter tells how Ahab and Jehoshaphat go to Ramothgilead, how four hundred prophets promise victory while Micaiah warns of death, and how Ahab is killed by an arrow shot at a venture. 2 Kings follows, with Ahaziah and Elijah.",
    people=[("Ahab", "Plans the attack on Ramothgilead, disguises himself, and dies of an arrow."), ("Jehoshaphat", "King of Judah, who asks for a prophet of the LORD."), ("Micaiah the son of Imlah", "Tells the truth to the king and is put in prison."), ("The four hundred prophets and Zedekiah", "Promise victory in the LORD's name."), ("Ahaziah", "Ahab's son, who does evil like his father.")],
    themes=[("Truth against flattery", "Four hundred prophets say, \"Go up,\" but Micaiah says only what the LORD says to him."), ("A warning ignored", "Ahab puts Micaiah in prison and dies at Ramothgilead as Micaiah had said."), ("An alliance with a bad king", "Jehoshaphat joins Ahab but asks first to ask the LORD."), ("The next kings", "Jehoshaphat reigns well in Judah and Ahaziah does evil in Israel.")],
)


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "11_1_kings.json"
    data = load(path)
    for number, fields in CH.items():
        entry = data[f"1 Kings {number}"]
        entry["summary"] = fields["summary"]
        entry["whereWeAre"] = fields["wwa"]
        entry["keyFigures"] = [{"name": n, "role": r} for n, r in fields["people"]]
        old = entry["keyThemes"]
        refs = fields.get("refs") or [t["references"] for t in old]
        if len(fields["themes"]) != len(refs):
            raise SystemExit(f"1 Kings {number}: {len(fields['themes'])} themes but {len(refs)} reference lists")
        entry["keyThemes"] = [{"theme": t, "explanation": e, "references": r} for (t, e), r in zip(fields["themes"], refs)]
    for ref in data["1 Kings 22"]["explainedReferences"]:
        ref["explanation"] = ref["explanation"].replace("Ramoth-gilead", "Ramothgilead")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


# Original Audience text: who first heard it and what they knew (places stay in Historical Moment).
AUDIENCE = {
    3: "The first Israelites who heard this book remembered Solomon above all for his wisdom. They heard that the LORD was pleased when a young king asked for a listening heart instead of riches.",
    4: "The first Israelites who heard this book looked back on Solomon's reign as Israel's golden age, when every man lived \"under his vine and under his fig tree\" (1 Kings 4:25). They also remembered that his heavy demands on the people helped split the kingdom (1 Kings 12:4).",
    5: "The first Israelites who heard this book knew Hiram as a friend of David (2 Samuel 5:11) and as a partner in Solomon's building. They heard that the temple was built with help from a foreign king and the labor of thousands of workers.",
    6: "The first Israelites who heard this book knew the temple as the center of their worship for nearly four hundred years, until Babylon destroyed it (2 Kings 25:9). Those in exile remembered it with grief and heard that the LORD cared more about obedience than about the building.",
    7: "The first Israelites who heard this book knew that Judah's kings ruled from this palace, and they remembered the bronze pillars, sea, and stands until Babylon broke them up (2 Kings 25:13). They heard how much skill and wealth went into the LORD's house.",
    9: "The first Israelites who heard this book knew that Solomon's building and his forced labor weighed on the people (1 Kings 12:4). They heard the LORD's second warning that the kingdom depended on obedience.",
    14: "The first Israelites who heard this book knew the sorrow of seeing the temple's treasures carried off, and they knew that Jeroboam's family would end as Ahijah said (1 Kings 15:27–29). They heard that the LORD saw \"some good thing\" even in Jeroboam's sick son.",
    16: "The first Israelites who heard this book knew Samaria as the capital of the northern kingdom until Assyria destroyed it (2 Kings 17:5–6). They heard how quickly the kings of Israel rose and fell, and how Ahab's marriage brought Baal worship into the palace.",
    18: "The first Israelites who heard this book knew the question Elijah asks, \"How long halt ye between two opinions?\" as the heart of Israel's choice between the LORD and Baal. They heard that the LORD, not Baal the storm god, sent the fire and the rain.",
    19: "The first Israelites who heard this book knew Horeb as the mountain where the LORD gave the law to Moses (Exodus 3:1; 19:1–3). They heard that the same God met a worn-out prophet there, not in the storm but in a still small voice.",
    22: "The first Israelites who heard this book knew that kings often asked prophets about war, and that false prophets could tell them what they wanted to hear (Jeremiah 23:16–17). They heard that Micaiah told the truth at the cost of prison, and that Ahab could not escape what the LORD had said.",
}

# (chapter, note title, old text, new text) edits to cultural notes.
CULTURE = [
    (9, "Cabul", "which the KJV notes means ‘displeasing’ or ‘dirty.’", "which the KJV margin explains as displeasing or dirty."),
    (15, "The queen mother", "Asa removes his grandmother Maachah from it because she made an idol.", "Asa removes his mother Maachah from it because she made an idol."),
]


def apply_chapter_context():
    path = ROOT / "chapter_context" / "11_1_kings.json"
    data = load(path)
    for number, text in AUDIENCE.items():
        data[f"1 Kings {number}"]["audience"] = text
    for number, title, old, new in CULTURE:
        hits = [n for n in data[f"1 Kings {number}"]["culture"] if n["title"] == title]
        if len(hits) != 1:
            raise SystemExit(f"1 Kings {number}: {len(hits)} notes titled {title!r}")
        hits[0]["text"] = replace_once(hits[0]["text"], old, new, f"1 Kings {number} {title}")
    for key, entry in data.items():
        if not key.startswith("1 Kings"):
            continue
        entry["audience"] = entry["audience"].replace("Ramoth-gilead", "Ramothgilead")
        for note in entry["culture"]:
            note["title"] = note["title"].replace("Ramoth-gilead", "Ramothgilead")
            note["text"] = note["text"].replace("Ramoth-gilead", "Ramothgilead")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_historical_moments():
    path = ROOT / "historical_moments" / "05_kings.json"
    data = load(path)
    data["1 Kings 1"] = replace_once(data["1 Kings 1"], "at En-rogel", "at Enrogel", "1 Kings 1 moment")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_book_overview():
    path = ROOT / "book_overviews" / "02_early_history.json"
    data = load(path)
    book = data["1 Kings"]
    book["author"] = replace_once(
        book["author"],
        "Jeremiah is the traditional author, though 1 Kings does not name its writer.",
        "1 and 2 Kings were one book. Jewish tradition credits Jeremiah as the author, though 1 Kings does not name its writer.",
        "author",
    )
    book["audience"] = replace_once(
        book["audience"],
        "Israel and later readers learning why the united kingdom divided and how its kings answered the LORD.",
        "Israelites in exile and later readers, who wanted to know why the united kingdom divided and how its kings answered the LORD.",
        "audience",
    )
    book["purpose"] = replace_once(book["purpose"], "Solomon’s reign", "Solomon's reign", "purpose")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_FIXES = [
    ("his son Adonijah, the oldest surviving son and very handsome, decides", "his son Adonijah, born next after Absalom and very handsome, decides"),
    ("Inside the ark are only the two stone tablets Moses placed there at Mount Sinai.", "Inside the ark are only the two stone tablets Moses placed there at Horeb."),
    ("including Hazor, Megiddo, and Gezer, which Pharaoh had captured and given as a wedding gift.",
     "including Hazor, Megiddo, and Gezer. Pharaoh had captured Gezer and given it to his daughter as a wedding gift."),
    ("He even removes his own grandmother from her position as queen mother because she made a disgusting idol, and he burns it.",
     "He even removes his own mother Maachah from her position as queen because she made a disgusting idol, and he burns it."),
    ("cut themselves with swords and knives until blood flows.", "cut themselves with knives and lances until blood flows."),
    ("wants to take back the city of Ramoth-gilead.", "wants to take back the city of Ramothgilead."),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "03_later_history.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("# 1 Kings")
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
