#!/usr/bin/env python3
"""Apply the completed editorial review for Amos to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


WWA = {
    1: ("Joel ended with a promise that the LORD would dwell in Zion forever, after judging the nations that "
        "had wronged his people (Joel 3:18–21). Amos opens the next book by turning that same judgment outward "
        "first: a shepherd from Judah announces one oracle after another against Israel's neighbors, Damascus, "
        "Gaza, Tyre, Edom, and Ammon, for their cruelty in war. Each oracle names a specific nation, building "
        "toward chapter 2, where the same formula turns inward and lands on Judah, then finally on Israel "
        "itself."),
    2: ("Chapter 1 worked through oracles against five surrounding nations for their cruelty in war "
        "(Amos 1:3–15). Chapter 2 completes the sequence with Moab and Judah before landing its longest oracle "
        "on Israel itself, a nation that received God's own deliverance from Egypt but now sells the poor for "
        "silver and silences the prophets he raised up among them. That indictment carries straight into "
        "chapter 3, where Amos explains why Israel's special relationship with God brings stricter "
        "accountability rather than protection."),
    3: ("Chapter 2 ended with Israel's history of deliverance turned into an indictment, since the very people "
        "God rescued from Egypt now reject his prophets and oppress the poor (Amos 2:9–12). Chapter 3 explains "
        "why that history raises the stakes: being specially known by God brings greater accountability, not "
        "immunity, and the LORD must speak through Amos the way thunder follows a lion's roar. The chapter's "
        "closing image of Samaria's ivory houses facing ruin carries into chapter 4, where Amos names exactly "
        "who lives in those houses and why they will be the first to fall."),
    4: ("Chapter 3 closed by condemning the luxury of Samaria's winter and summer houses as evidence of coming "
        "judgment (Amos 3:13–15). Chapter 4 names exactly who enjoys that luxury, the wealthy women of "
        "Samaria, and surveys famine, drought, blight, and war that God sent to turn Israel back, all without "
        "success. That repeated refrain, \"yet have ye not returned unto me,\" builds toward the command in "
        "chapter 5 to seek the LORD while there is still time to live."),
    5: ("Chapter 4 ended with five warnings Israel failed to heed, each closing with the same refrain that the "
        "people had not returned to God (Amos 4:6–11). Chapter 5 responds with a funeral song for a nation "
        "Amos treats as already fallen, then pivots to an urgent appeal: seek the LORD and live, rather than "
        "trusting the shrines at Bethel, Gilgal, or Beersheba, and let justice replace the bribery corrupting "
        "the courts. That same contrast between hollow religion and real justice continues in chapter 6, which "
        "exposes the comfortable complacency of Israel's leaders in even sharper terms."),
    6: ("Chapter 5 condemned worship that Israel kept up while abandoning justice in the courts "
        "(Amos 5:10–24). Chapter 6 turns to the leaders responsible for that imbalance, pronouncing woe on "
        "those who feel secure in Zion and Samaria, feast on the finest food and music, and feel no grief over "
        "the nation's coming ruin. Their complacency sets up the sharp break in chapter 7, where Amos moves "
        "from pronouncing judgment in general terms to a series of specific visions of exactly how it will "
        "arrive."),
    7: ("Chapter 6 pronounced woe on Israel's complacent leaders for ignoring the nation's coming ruin "
        "(Amos 6:1–14). Chapter 7 shows Amos receiving that judgment directly in a series of visions, twice "
        "persuading God to relent before a third vision announces judgment without reprieve, and shows the "
        "cost of delivering that message when Amaziah, the priest of Bethel, tries to send him home to Judah. "
        "Amos's reply that he was only a herdsman, not a professional prophet, carries into chapter 8, where "
        "another vision confirms that Israel's end has come."),
    8: ("Chapter 7 ended with Amos defending his calling against Amaziah's attempt to silence him and "
        "foretelling exile for Israel (Amos 7:14–17). Chapter 8 confirms that verdict with a vision of ripe "
        "summer fruit, a wordplay on Israel's own approaching end, then condemns merchants who cheat the poor "
        "with dishonest scales and can't wait for holy days to end so they can resume business. The chapter's "
        "most severe warning, a coming famine not of food but of hearing God's word, prepares for chapter 9's "
        "final vision, where no hiding place can escape the LORD at all."),
    9: ("Chapter 8 warned of a coming famine of hearing the words of the LORD (Amos 8:11–12). "
        "Chapter 9 delivers the book's final vision: no hiding place, from the depths of the sea to the "
        "heights of heaven, can shelter those under judgment, yet the LORD promises Israel will not be "
        "destroyed completely. The book closes with hope instead of ruin, promising to raise up David's "
        "fallen house and resettle the people in their own land, before Obadiah, the next book, turns to a "
        "single judgment oracle against Edom alone."),
}

SUMMARY_FIXES = {
    1: [
        ("The repeated 'three ... and four' formula stresses persistent wrongdoing; it should not be read as "
         "a literal crime count.",
         "Each oracle repeats a numeric pattern, \"For three transgressions...and for four,\" a wisdom-saying "
         "idiom meaning sin piled upon sin rather than a literal count of exactly four crimes."),
    ],
    4: [
        ("metaphorically called 'cows of Bashan,' who oppress the poor and demand drink (Amos 4:1–3).",
         "whom Amos calls \"kine of Bashan,\" who oppress the poor and demand drink (Amos 4:1–3)."),
        ("Judgment is pictured as their being carried away with hooks; the exact mechanics of this image are "
         "debated.",
         "Judgment is pictured vividly as being dragged away with hooks and fishhooks, like cattle led by "
         "force."),
    ],
    5: [
        ("Amos sings a lament over 'virgin Israel' as though she has already fallen (Amos 5:1–3).",
         "Amos sings a lament over the \"virgin of Israel\" as though she has already fallen (Amos 5:1–3)."),
        ("deprive the poor of justice (Amos 5:7), Amos 5:10–13.",
         "deprive the poor of justice (Amos 5:7, 10–13)."),
        ("The 'day of the LORD,' expected by some as deliverance, will instead be darkness for those under "
         "judgment (Amos 5:18–20).",
         "The \"day of the LORD,\" expected by some as deliverance, will instead be darkness for those under "
         "judgment (Amos 5:18–20)."),
    ],
    6: [
        ("using fine oils without grieving over 'the ruin of Joseph' (Amos 6:4–6).",
         "using fine oils without grieving over \"the affliction of Joseph\" (Amos 6:4–6)."),
    ],
    7: [
        ("a measuring tool, traditionally translated 'plumb line'; this time judgment",
         "a measuring tool, traditionally translated \"plumbline\"; this time judgment"),
    ],
    9: [
        ("God promises to raise the fallen 'booth of David,' repair its ruins, and renew the fortunes of the "
         "people (Amos 9:11–15).",
         "God promises to raise up \"the tabernacle of David that is fallen,\" repair its ruins, and renew the "
         "fortunes of the people (Amos 9:11–15)."),
    ],
}

NAME_FIXES = {
    1: {"Damascus/Aram, Philistine cities, Tyre, Edom, and Ammon":
        "Damascus (Aram), Philistine cities, Tyre, Edom, and Ammon"},
    3: {"Israel / children of Israel": "Israel (children of Israel)",
        "Amos / prophets": "Amos"},
    4: {"Israel / children of Israel": "Israel (children of Israel)"},
    5: {"Israel / house of Israel": "Israel (house of Israel)"},
    6: {"House of Israel / house of Joseph": "House of Israel (house of Joseph)"},
    7: {"Jacob / Israel": "Jacob (Israel)"},
    9: {"Israel / house of Jacob": "Israel (house of Jacob)"},
}

ROLE_FIXES = {
    1: {"Uzziah and Jeroboam son of Joash":
        "Kings used in the opening date. Locate Amos in the period of Judah and Israel's divided monarchies "
        "(Amos 1:1)"},
    3: {"Amos / prophets":
        "Prophetic messenger in this oracle. Insists that the LORD reveals his plans to his servants the "
        "prophets before compelling Amos himself to speak (Amos 3:7-8)"},
    6: {"Secure leaders of Zion and Samaria":
        "Complacent elites addressed. Trust in status, enjoyment, and prestige despite injustice (Amos 6:1-7)"},
    7: {"Amos":
        "Prophet and intercessor. Pleads for Jacob, sees visions, and defends his calling (Amos 7:1-17)",
        "Amaziah":
        "Priest of Bethel. Accuses Amos of conspiracy and tries to expel him (Amos 7:10-17)"},
    8: {"Merchants who oppress the needy":
        "Accused economic actors. Manipulate weights, prices, and sale practices (Amos 8:4-6)"},
    9: {"The LORD God of hosts":
        "Speaker and visionary figure. Pronounces judgment and promises future restoration (Amos 9:1-15)",
        "David":
        "Earlier royal ancestor named in an image. His fallen tabernacle stands for a future restoration "
        "associated with Davidic rule (Amos 9:11)"},
}

THEMES = {
    1: {
        "Accountability beyond national borders":
            "Even nations with no covenant relationship to the LORD are held responsible for how they treat "
            "others in war, starting with Damascus's brutal treatment of Gilead (1:3-5).",
        "The dignity of captives":
            "Gaza and Tyre are condemned specifically for handing entire captured populations over to "
            "slavery, treating conquered people as goods to trade rather than as human beings (1:6-10).",
        "Violence and exploitation":
            "Edom's relentless hostility toward a brother people and Ammon's atrocities against pregnant "
            "women in Gilead show violence pursued for its own sake or for territorial gain, not merely as a "
            "byproduct of war (1:11-15).",
        "Prophetic authority and warning":
            "Amos introduces his message as the LORD's own roaring voice from Zion, grounding a herdsman's "
            "words in divine authority rather than his own standing (1:1-2).",
    },
    2: {
        "Justice for the vulnerable":
            "Selling the poor for the price of a pair of sandals and trampling the needy into the dust shows "
            "Israel's economic life built on treating vulnerable people as disposable (2:6-7).",
        "Religious practices and wrongdoing":
            "Misusing pledged garments and fine money taken as pledges, even beside altars, shows religious "
            "settings being used to cover rather than correct injustice (2:7-8).",
        "Remembered grace and responsibility":
            "God recalls destroying the Amorites, bringing Israel from Egypt, and raising up prophets and "
            "Nazirites as evidence that Israel's current conduct is a betrayal of grace already given, not "
            "simple ignorance (2:9-11).",
        "Silencing correction":
            "Pressuring Nazirites to break their vows and ordering prophets not to speak shows Israel actively "
            "working to remove the very voices meant to call it back to God (2:11-12).",
    },
    3: {
        "Privilege entails responsibility":
            "Being the one family specially known by God does not exempt Israel from judgment; it is the "
            "reason God holds Israel to a stricter account than other nations (3:1-2).",
        "Speaking uncomfortable truth":
            "Amos compares his compulsion to prophesy to the involuntary fear caused by a lion's roar, "
            "insisting that once God has spoken, silence is not an option for those he sends (3:7-8).",
        "Systemic oppression":
            "Calling witnesses from Ashdod and Egypt, foreign and often hostile nations, to see Samaria's "
            "internal disorder shows oppression so severe that even outsiders would recognize it as wrong "
            "(3:9-11).",
        "Fragile luxury":
            "The image of a shepherd recovering only scraps of a sheep killed by a lion previews how little "
            "will remain of Samaria's winter houses, summer houses, and ivory decorations once judgment "
            "arrives (3:12-15).",
    },
    4: {
        "Wealth without compassion":
            "The wealthy women of Samaria are compared to well-fed cattle, demanding luxury from their "
            "husbands while the poor around them are crushed and oppressed (4:1-3).",
        "Ritual without repentance":
            "Amos's sarcastic invitation to keep worshiping at Bethel and Gilgal exposes continued religious "
            "activity that only multiplies transgression instead of addressing it (4:4-5).",
        "Persistent refusal to return":
            "Five disasters, famine, drought, blight, plague, and military defeat, are each followed by the "
            "same refrain, that Israel still did not return to God, showing a pattern of hardened resistance "
            "rather than isolated misfortune (4:6-11).",
        "God’s sovereign authority":
            "The closing hymn names God as the one who forms mountains, creates wind, and turns day into "
            "night, grounding the command to prepare to meet him in his power over the whole created order "
            "(4:12-13).",
    },
    5: {
        "Seek good and live":
            "Amos urges Israel to seek the LORD directly rather than at the shrines of Bethel, Gilgal, or "
            "Beersheba, since seeking the wrong thing leads to captivity instead of life (5:4-6).",
        "Integrity in judgment":
            "Taking bribes and turning the poor away in the city gate, the public place where legal disputes "
            "were settled, corrupts the very institution meant to protect the vulnerable (5:10-15).",
        "False confidence in the day of the LORD":
            "Some in Israel looked forward to the day of the LORD as a guaranteed victory; Amos warns it will "
            "instead be darkness for a people under judgment, like someone who escapes a lion only to meet a "
            "bear (5:18-20).",
        "Justice as essential to worship":
            "God declares that he hates festivals and sacrifices offered without justice, insisting that "
            "justice rolling down like waters describes what true devotion requires, not an optional addition "
            "to it (5:21-24).",
    },
    6: {
        "Complacency in privilege":
            "Amos challenges people who feel secure in Zion and Samaria simply because of their city's "
            "reputation, exposing confidence based on status rather than on actual faithfulness (6:1-3).",
        "Indifference to common suffering":
            "Those who lounge on ivory beds, eat the finest food, and enjoy music and wine are condemned "
            "specifically for feeling no grief over the nation's own suffering around them (6:4-7).",
        "Corruption of justice":
            "Turning judgment into poison and righteousness into bitterness is as unnatural as horses running "
            "on bare rock, an image Amos uses to show how far Israel's courts have strayed from their purpose "
            "(6:12).",
        "Arrogance and fragile security":
            "Leaders who boast of military victories are answered by God's announcement of an oppressing "
            "nation covering the whole land, showing that confidence built on past success cannot guarantee "
            "future safety (6:8, 6:13-14).",
    },
    7: {
        "Intercessory prayer":
            "Amos twice pleads for Jacob, since he is small, and both times the LORD relents from judgment "
            "already announced, showing prayer actually changing what happens next (7:1-6).",
        "Limits of postponed judgment":
            "The third vision of a plumbline against a crooked wall announces that the LORD will no longer "
            "pass by Israel's sin, ending the pattern of relenting seen in the first two visions (7:7-9).",
        "Calling against institutional pressure":
            "Amaziah, the priest of Bethel, tries to send Amos back to Judah by appealing to royal authority, "
            "but Amos answers that he never sought the role and speaks only because the LORD commanded him to "
            "(7:10-15).",
        "Costs of opposing warning":
            "Because Amaziah tried to silence God's word, Amos announces specific, personal disaster for "
            "Amaziah's own household along with Israel's coming exile (7:16-17).",
    },
    8: {
        "Ripe judgment":
            "A basket of summer fruit becomes a wordplay on Israel's approaching end, since the Hebrew words "
            "for summer fruit and end sound alike, showing judgment as ripe and ready rather than distant "
            "(8:1-3).",
        "Honesty in economic life":
            "Merchants eager for holy days to end so they can cheat customers with dishonest measures and even "
            "sell the sweepings as wheat show that Israel's injustice reaches into the details of ordinary "
            "commerce (8:4-6).",
        "Grief behind apparent prosperity":
            "God promises to turn feasts into mourning and songs into lamentation, revealing that prosperity "
            "built on exploitation will end in grief rather than lasting security (8:7-10).",
        "Famine of the word":
            "The gravest coming shortage is not bread or water but the words of the LORD; people will search "
            "for a message from God and not find one, having already rejected the warnings they were given "
            "(8:11-14).",
    },
    9: {
        "No hiding from judgment":
            "Whether sinners dig into the earth, climb to heaven, or hide at the bottom of the sea, Amos "
            "insists none of these places can shelter them from the LORD (9:1-4).",
        "Impartial divine sovereignty":
            "God's rule over creation and his bringing other peoples, the Philistines from Caphtor and the "
            "Syrians from Kir, out of their own lands just as he brought Israel from Egypt, challenges any "
            "assumption that Israel's relationship with God guarantees special treatment (9:5-8).",
        "Judgment with preservation":
            "Even as the sinful kingdom is shaken, God promises not to utterly destroy the house of Jacob, "
            "holding judgment and survival together rather than letting judgment mean total annihilation "
            "(9:8-10).",
        "Hope of rebuilding":
            "The book ends by promising to raise up David's fallen house and restore abundant harvests and "
            "secure, permanent settlement, answering eight chapters of judgment with genuine hope (9:11-15).",
    },
}

AUDIENCE_FIXES = {
    1: "Israelites at the height of Jeroboam II's prosperity would have nodded along as this outsider from "
       "Judah condemned their enemies one by one, Damascus, Philistia, Tyre, Edom, and Ammon, only to "
       "discover, oracle by oracle, that the circle was closing in on them next.",
    7: "Worshipers who treated Bethel as the northern kingdom's own royal shrine, not just a local sanctuary, "
       "would have heard the priest's command to leave as an entirely reasonable defense of the king's own "
       "chapel, and felt the force of Amos's reply that he never asked for the job, but spoke only because "
       "God compelled him.",
    8: "Merchants who prided themselves on technically keeping the sabbath and new moon would have heard in "
       "the prophet's wordplay, linking ripe fruit to Israel's coming end, a verdict on the kind of worship "
       "that let business resume the moment the holy day was over.",
    9: "Centuries later, quoting this closing promise let James argue at the Jerusalem council that Gentiles "
       "entering the church, not only a restored throne, fulfilled what the prophet foresaw (Acts 15:16-17).",
}


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "30_amos.json"
    data = load(path)
    for n in range(1, 10):
        key = f"Amos {n}"
        entry = data[key]
        entry["whereWeAre"] = WWA[n]
        for old, new in SUMMARY_FIXES.get(n, []):
            if old not in entry["summary"]:
                raise SystemExit(f"Amos {n}: summary fix not found: {old!r}")
            entry["summary"] = entry["summary"].replace(old, new)
        for fig in entry["keyFigures"]:
            if fig["name"] in NAME_FIXES.get(n, {}):
                fig["role"] = ROLE_FIXES.get(n, {}).get(fig["name"], fig["role"])
                fig["name"] = NAME_FIXES[n][fig["name"]]
            elif fig["name"] in ROLE_FIXES.get(n, {}):
                fig["role"] = ROLE_FIXES[n][fig["name"]]
        theme_map = THEMES[n]
        seen = set()
        for theme in entry["keyThemes"]:
            name = theme["theme"]
            if name not in theme_map:
                raise SystemExit(f"Amos {n}: no explanation drafted for theme {name!r}")
            theme["explanation"] = theme_map[name]
            seen.add(name)
        missing = set(theme_map) - seen
        if missing:
            raise SystemExit(f"Amos {n}: drafted themes not in source: {missing}")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_chapter_context():
    path = ROOT / "chapter_context" / "29_hosea_micah.json"
    data = load(path)
    for n, text in AUDIENCE_FIXES.items():
        data[f"Amos {n}"]["audience"] = text
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_PRONOUN_FIXES = [
    ("God reminds them how He brought them out of Egypt and gave them prophets,",
     "God reminds them how he brought them out of Egypt and gave them prophets,"),
    ("God lists all the ways He tried to get their attention. He sent famine: “I also have given you "
     "cleanness of teeth in all your cities.” He sent drought, crop disease, locusts, plague, and military "
     "defeat.",
     "God lists all the ways he tried to get their attention. he sent famine: “I also have given you "
     "cleanness of teeth in all your cities.” he sent drought, crop disease, locusts, plague, and military "
     "defeat."),
    ("God says He hates their religious festivals and sacrifices: “I hate, I despise your feast days... Take "
     "thou away from me the noise of thy songs.” What He wants is this:",
     "God says he hates their religious festivals and sacrifices: “I hate, I despise your feast days... Take "
     "thou away from me the noise of thy songs.” What he wants is this:"),
    ("they will be the first to go into exile. God says He hates their pride and their palaces.",
     "they will be the first to go into exile. God says he hates their pride and their palaces."),
    ("God says He is setting a plumbline among His people.",
     "God says he is setting a plumbline among his people."),
    ("He has also guided other nations' movements, like the Philistines and the Syrians. Still, God will not "
     "completely destroy His people. He will shake them among the nations like grain in a sieve,",
     "he has also guided other nations' movements, like the Philistines and the Syrians. Still, God will not "
     "completely destroy his people. he will shake them among the nations like grain in a sieve,"),
    ("After judgment, God promises to raise David's fallen house, restore His people, and renew the land with "
     "extraordinary abundance.",
     "After judgment, God promises to raise David's fallen house, restore his people, and renew the land with "
     "extraordinary abundance."),
    ("to show that God planned to include Gentiles among His people.",
     "to show that God planned to include Gentiles among his people."),
    ("God will bring His people back from exile,",
     "God will bring his people back from exile,"),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "06_minor_prophets.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("# Amos")
    end = text.index("# Obadiah")
    section = text[start:end]
    for old, new in STORY_PRONOUN_FIXES:
        count = section.count(old)
        if count == 0:
            if section.count(new) == 1:
                continue
            raise SystemExit(f"story fix matched 0 times and not already applied: {old!r}")
        if count != 1:
            raise SystemExit(f"story fix matched {count} times (expected 1): {old!r}")
        section = section.replace(old, new)
    path.write_text(text[:start] + section + text[end:], encoding="utf-8")
    print(f"Updated {path.relative_to(ROOT)}")


if __name__ == "__main__":
    apply_chapter_insights()
    apply_chapter_context()
    apply_story_fixes()
