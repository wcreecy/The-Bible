#!/usr/bin/env python3
"""Apply the completed editorial review for Daniel to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


WWA = {
    1: "Ezekiel's final chapter closed the book of a priest-prophet exiled to Babylon with the promise that God's own presence would return and remain forever. Daniel opens in that same Babylonian captivity from a different angle: a young noble from Judah's own royal and noble families is taken into the king's court itself, tested for his loyalty to God through something as ordinary as food. Chapter 2 moves from this personal test to Daniel's first real test of prophetic skill, interpreting a king's forgotten dream.",
    2: "Chapter 1 showed Daniel and his friends quietly proving their loyalty through diet. Here a much bigger test arrives: Nebuchadnezzar demands that his wise men both describe and interpret a dream they were never told, and only Daniel, through prayer, receives the secret, revealing a statue that pictures a whole sequence of coming kingdoms. Chapter 3 shows that same king's court turning from private dream-interpretation to a very public demand for worship.",
    3: "Chapter 2 ended with Nebuchadnezzar honoring Daniel's God in word. Here that same king demands worship from everyone in word and action, and Daniel's three friends refuse even under threat of a burning furnace, trusting God to deliver them or not. Chapter 4 returns to Nebuchadnezzar's own story, as another dream exposes the pride his earlier praise never fully overcame.",
    4: "Chapter 3 ended with Nebuchadnezzar praising the God who rescued three men from his own furnace. Here that same king's pride resurfaces in a new dream of a felled tree, and Daniel's warning proves true: Nebuchadnezzar is humbled until he personally acknowledges that heaven, not his own power, rules every kingdom. Chapter 5 shows a later king failing to learn the very lesson this chapter records Nebuchadnezzar actually learning.",
    5: "Chapter 4 ended with Nebuchadnezzar restored once he acknowledged God's rule. Here his successor Belshazzar refuses that same lesson, using Jerusalem's own temple vessels to praise idols at a drunken feast, until a handwriting on the wall announces his kingdom's immediate end. Chapter 6 shows a very different kind of ruler, Darius, reacting to Daniel's God with reluctant respect rather than defiance.",
    6: "Chapter 5 ended with Belshazzar's kingdom handed over the very night he insulted God. Here, under the new ruler Darius, Daniel's enemies use his own faithfulness in prayer to trap him under a law even the king cannot undo, and God shuts the mouths of the lions meant to kill him. Chapter 7 shifts from this court story to the book's second half, where Daniel himself starts receiving the visions rather than only interpreting other men's dreams.",
    7: "Chapter 6 closed with Darius decreeing reverence for Daniel's God after his rescue from the lions. Here Daniel receives his own vision instead of interpreting someone else's: four beasts rising from the sea picture a succession of oppressive kingdoms, until a heavenly court strips their power and gives lasting dominion to 'one like the Son of man.' Chapter 8 continues this same kind of symbolic vision with a ram and a goat representing two more empires in that same succession.",
    8: "Chapter 7 pictured four beastly kingdoms ultimately judged from heaven. Here a more specific vision narrows the focus: a ram and a goat, identified by the angel Gabriel as Media-Persia and Greece, act out that same succession of empires, ending in a small horn that attacks the sanctuary itself. Chapter 9 turns from this vision of future empires back to Daniel's own prayer over Jerusalem's past and present devastation.",
    9: "Chapter 8 left Daniel sick and overwhelmed after a vision of the sanctuary under attack. Here he turns instead to prayer, reading Jeremiah's promise of seventy years and confessing his people's guilt, until Gabriel answers with a further revelation of seventy weeks reaching toward Jerusalem's ultimate restoration. Chapter 10 opens the book's final vision, beginning with Daniel's own mourning and a startling encounter by the Tigris River.",
    10: "Chapter 9 ended with Gabriel's answer to Daniel's prayer about Jerusalem's future. Here Daniel mourns and fasts for three weeks before a radiant figure appears to him by the Tigris, explaining that a conflict involving heavenly princes over Persia and Greece had delayed this very visit. Chapter 11 continues directly from this explanation into the detailed vision of conflict the messenger has come to deliver.",
    11: "Chapter 10 introduced the heavenly messenger who delayed his arrival because of conflict over Persia. Here that messenger details a long, specific sequence of kings of the north and south, climaxing in a contemptible ruler who profanes the sanctuary and persecutes the faithful before his own sudden end. Chapter 12 closes the book with this same vision's final word: a time of unmatched distress answered by the promise of resurrection.",
    12: "Chapter 11 ended with a proud ruler's downfall still part of an unfinished vision. Here that vision reaches its true conclusion: Michael stands up for his people during a time of unmatched trouble, many who sleep in the dust awake to life or shame, and Daniel himself is told to seal the words and simply wait for his own promised rest at the end of days. The book of Daniel closes the Old Testament's major prophets with hope reaching beyond any single empire's rise or fall, into resurrection itself.",
}

THEMES = {
    1: {"Faithfulness under pressure": "Refusing the king's food while still staying respectful and cooperative with the steward shows loyalty to God expressed through tact, not open defiance (1:8-14).",
        "Education and identity": "Receiving new Babylonian names and three years of imperial training tests whether Daniel's core identity can survive a deliberate, systematic attempt to remake it (1:4, 1:6-7).",
        "Wisdom as gift": "Crediting God, not their own diet or effort, for their understanding keeps the four men's success from becoming a point of personal pride (1:17).",
        "Exile and endurance": "Daniel's service lasting all the way to the first year of Cyrus frames the whole book as one long story of outlasting the empires that once controlled him (1:21)."},
    2: {"Limits of human expertise": "Babylon's wise men protesting that no one 'upon the earth' could meet the king's demand concedes outright that their whole profession has limits court politics usually hides (2:10-11).",
        "Prayer in crisis": "Asking his friends to seek mercy together, not handling the crisis alone, shows Daniel treating urgent prayer as something meant to be shared (2:17-18).",
        "Temporary empires": "Each successive metal in the statue being weaker than the one before pictures political power as something that naturally declines, not a one-time judgment on any single king (2:39-40).",
        "Humble service": "Asking the king to promote his three friends alongside himself turns Daniel's own reward into an opportunity to include others rather than keep the honor for himself (2:49)."},
    3: {"Integrity under coercion": "Refusing even a 'second chance' to comply shows the three men's loyalty was already settled before Nebuchadnezzar offered them an easier way out (3:14-15, 3:18).",
        "Faith without guaranteed rescue": "Saying God is able to deliver them, 'but if not,' separates genuine trust in God from any guarantee that trust always ends in rescue (3:17-18).",
        "Rescue and witness": "Nebuchadnezzar's own public praise of their God after the furnace turns the three men's private conviction into testimony an entire empire has to hear (3:28-29).",
        "Limits of royal authority": "A king who can order anyone's death still cannot force genuine worship, and his own decree ends up honoring the very God he first tried to override (3:29)."},
    4: {"Pride and humility": "Nebuchadnezzar's own words, 'is not this great Babylon that I have built,' are the exact boast that triggers his humiliation (4:30).",
        "Responsibility to the vulnerable": "Daniel's advice to 'break off thy sins by righteousness, and thine iniquities by shewing mercy to the poor' ties the king's own future directly to how he treats people with no power over him (4:27).",
        "Divine sovereignty": "The dream's own explanation, that 'the most High ruleth in the kingdom of men,' states outright what the whole chapter then goes on to prove through Nebuchadnezzar's own experience (4:17, 4:25).",
        "Warning before judgment": "A full year passes between Daniel's warning and the king's downfall, showing that judgment here follows a real opportunity to change, not an ambush (4:28-29)."},
    5: {"Sacred things and arrogance": "Drinking from Jerusalem's own temple vessels while praising idols of gold and silver turns Belshazzar's arrogance into a specific act of sacrilege, not just generic pride (5:2-4).",
        "Accountability of rulers": "Daniel's blunt accusation that Belshazzar 'hast not humbled thine heart' holds the king responsible for failing to learn a lesson he already knew firsthand (5:22).",
        "History as warning": "Daniel retells Nebuchadnezzar's own humbling before explaining the handwriting, using recent history as evidence Belshazzar had no excuse to ignore (5:18-21).",
        "Fragility of empires": "An empire falls the very same night its king is judged, showing how quickly political power can end once its foundation is gone (5:30)."},
    6: {"Persistent prayer": "Praying three times a day with his windows open toward Jerusalem, even after the law against it, shows Daniel treating visible, regular prayer as non-negotiable (6:10).",
        "Envy and abuse of law": "Unable to find any actual corruption, Daniel's rivals manufacture a law specifically designed to turn his faithfulness itself into a crime (6:4-5).",
        "Courage and deliverance": "Daniel's calm answer from inside the den, that his God 'hath sent his angel,' credits the rescue entirely to God rather than his own composure (6:21-22).",
        "Public integrity": "Being found faithful, 'neither was there any error or fault found in him,' makes Daniel's reputation something built over years, not asserted for the occasion (6:4)."},
    7: {"Empire as beastly power": "Four violent, hybrid creatures rising from a churning sea picture human empire as something chaotic and predatory rather than simply orderly or civilized (7:2-7).",
        "Heavenly judgment": "Thrones being 'set up' and 'books opened' before the beast is destroyed shows judgment happening through a formal heavenly process, not sudden, arbitrary force (7:9-11).",
        "Hope amid persecution": "Promising that 'the saints of the most High' will finally receive the kingdom answers the little horn's temporary power to oppress them with a permanent reversal (7:21-22, 7:27).",
        "Enduring dominion": "Unlike every beast's kingdom before it, the dominion given to 'one like the Son of man' is specifically said to never pass away or be destroyed (7:14)."},
    8: {"Symbols interpreted in the text": "Having Gabriel name the ram and goat as Media-Persia and Greece gives readers a concrete starting point for the rest of the vision's own imagery (8:20-21).",
        "Assault on worship": "Stopping the daily sacrifice and throwing truth to the ground targets Israel's actual worship practice, not merely its political independence (8:11-12).",
        "Limits of tyranny": "The fierce king being broken 'without hand' insists that his eventual downfall comes from God, not from any human army finally strong enough to oppose him (8:25).",
        "Human response to visions": "Daniel fainting and lying sick for days afterward shows this revelation costing him something physically real, not just information delivered painlessly (8:27)."},
    9: {"Confession and responsibility": "Daniel includes himself in the confession, 'we have sinned,' even though his own faithfulness was never in question, modeling solidarity with a guilty community (9:5, 9:20).",
        "Mercy rather than merit": "Explicitly asking 'for our righteousnesses, but for thy great mercies' rules out any claim that Israel's restoration could be earned (9:18).",
        "Scripture and prayer": "Daniel's prayer begins only after he reads Jeremiah's own written words about seventy years, tying his urgent intercession directly to studying scripture first (9:2-3).",
        "Hope amid uncertainty": "Gabriel's answer about seventy weeks gives Daniel a detailed timetable even while leaving its precise fulfillment genuinely difficult to pin down (9:24-27)."},
    10: {"Perseverance in seeking understanding": "Three full weeks of mourning and limited food show Daniel pursuing this vision's meaning with sustained effort, not a single brief request (10:2-3, 10:12).",
         "Human frailty before the vision": "Daniel's companions fleeing in terror without even seeing what caused it, and Daniel's own strength draining away, shows how overwhelming this encounter is physically, not just intellectually (10:7-8).",
         "Spiritual imagery of conflict": "A delay caused by 'the prince of the kingdom of Persia' pictures earthly political struggles as connected to a larger, unseen conflict behind them (10:13).",
         "Encouragement and peace": "Being touched and told 'peace be unto thee' twice shows the messenger deliberately restoring Daniel's strength before giving him the vision's actual content (10:18-19)."},
    11: {"Unstable political alliances": "Marriages and treaties between the king of the north and south repeatedly collapse, showing that even formal political alliances in this account provide no lasting security (11:6, 11:17).",
         "Religious persecution": "Stopping the daily sacrifice and setting up 'the abomination that maketh desolate' targets Israel's worship specifically, not merely its political standing (11:31).",
         "Courage and costly wisdom": "Teachers who 'instruct many' are said to fall 'by the sword, and by flame' for a time, showing that faithful teaching carries a real, predicted cost here (11:33).",
         "Uncertain horizons": "The chapter's closing ruler comes 'to his end, and none shall help him,' but exactly how and when remains far less detailed than everything that led up to it (11:45)."},
    12: {"Hope beyond death": "Promising that 'many of them that sleep in the dust of the earth shall awake' gives the book's suffering a resolution that reaches beyond any single lifetime (12:2).",
         "Endurance in distress": "Calling this 'a time of trouble, such as never was' before promising deliverance insists the hope that follows is real precisely because the distress it answers is not minimized (12:1).",
         "Limits of knowledge": "Daniel himself admitting 'I heard, but I understood not' shows that even the book's own central prophet does not fully grasp everything he has just been shown (12:8).",
         "Faithful completion": "Being told to simply 'go thy way' and wait for 'thy lot at the end of the days' closes the book with an instruction to persevere rather than a final, complete explanation (12:13)."},
}

NAME_FIXES = {
    4: {"Daniel / Belteshazzar": "Daniel (Belteshazzar)",
        "God / the Most High": "God (the Most High)"},
    8: {"Little horn / fierce king": "Little horn (the fierce king)"},
    9: {"Israel/Judah and Jerusalem": "Judah and Jerusalem"},
    11: {"Those who know their God / the wise": "Those who know their God (the wise)"},
    12: {"Heavenly figures / messenger": "Heavenly figures (the messenger)"},
}

ROLE_FIXES = {
    10: {"Radiant figure and speaking messenger":
         "Heavenly figure or figures, whose exact relationship to one another the text leaves open. Deliver and explain the troubling revelation"},
}

SUMMARY_FIXES = {
    2: ("Identifying every later kingdom remains debated.",
        "Later tradition most often identifies the statue's remaining kingdoms as Medo-Persia, Greece, and Rome."),
    3: ("The identity of the fourth figure is interpreted differently; the king describes a figure like 'a son of the gods' in many modern renderings.",
        "The king describes the fourth figure's form as like 'the Son of God,' though interpreters differ on exactly who or what he saw."),
    4: ("The text gives a theological account of the king’s humiliation, not an independently verified medical diagnosis.",
        "The chapter presents this humiliation as God's own direct response to pride, not as a case history written for any other purpose."),
    7: ("He then sees the Ancient of Days seated in judgment and ‘one like a son of man’ receiving enduring dominion (Daniel 7:9–14).",
        "He then sees the Ancient of Days seated in judgment and ‘one like the Son of man’ receiving enduring dominion (Daniel 7:9–14)."),
    10: ("The beings’ exact identities and how such conflict operates are not independently observable historical facts.",
         "The chapter tells this heavenly conflict entirely through Daniel's own description of what he saw and heard."),
    11: ("Many historical-critical scholars identify much of the detailed struggle with Seleucid and Ptolemaic kingdoms and Antiochus IV, while the interpretation of the closing verses and any longer-range fulfillment is debated.",
         "Tradition most often identifies much of this detailed struggle with the Seleucid and Ptolemaic kingdoms and Antiochus IV, while the closing verses are read as reaching further, toward a final ruler still to come."),
}

AUDIENCE = {
    5: "Readers who already knew Belshazzar from Babylonian royal records as Nabonidus's son, not the sole reigning king, would have recognized the title 'third ruler' offered to Daniel as a precise, period-accurate detail, not a vague honor (5:7, 5:16).",
    6: "Hearers familiar with 'the law of the Medes and Persians, which altereth not' would have understood immediately why even a troubled king who liked Daniel could not simply reverse the decree himself (6:8, 6:14).",
    7: "Readers who already knew the Son of man title from Jesus's own trial testimony would have recognized Daniel's vision as the Old Testament scene Jesus was deliberately pointing back to (Mark 14:62).",
    8: "Hearers who knew Shushan only later as a Persian royal capital would have found it striking that Daniel's vision placed him there in advance, before Persia had even risen to replace Babylon (8:2).",
    9: "Exiles who had also read Jeremiah's own seventy-year prophecy would have recognized Daniel doing the math themselves, realizing their long captivity was approaching its promised end (9:2; Jeremiah 25:11).",
    10: "Readers who knew fine gold specifically came from Uphaz, the same detail used elsewhere for a king's own royal dress, would have recognized that same mark of extraordinary status on the being Daniel describes meeting (10:5; Jeremiah 10:9).",
    12: "Readers who recognized this as one of the Old Testament's clearest statements of resurrection would have carried its promise of shining 'as the stars for ever and ever' forward into their own later hope, not treated it only as a conclusion to Daniel's own story (12:3).",
}


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "27_daniel.json"
    data = load(path)
    for n in range(1, 13):
        key = f"Daniel {n}"
        entry = data[key]
        entry["whereWeAre"] = WWA[n]
        theme_map = THEMES[n]
        seen = set()
        for theme in entry["keyThemes"]:
            name = theme["theme"]
            if name not in theme_map:
                raise SystemExit(f"Daniel {n}: no explanation drafted for theme {name!r}")
            theme["explanation"] = theme_map[name]
            seen.add(name)
        missing = set(theme_map) - seen
        if missing:
            raise SystemExit(f"Daniel {n}: drafted themes not in source: {missing}")
        for fig in entry["keyFigures"]:
            if fig["name"] in NAME_FIXES.get(n, {}):
                fig["role"] = ROLE_FIXES.get(n, {}).get(fig["name"], fig["role"])
                fig["name"] = NAME_FIXES[n][fig["name"]]
            elif fig["name"] in ROLE_FIXES.get(n, {}):
                fig["role"] = ROLE_FIXES[n][fig["name"]]
        old, new = SUMMARY_FIXES.get(n, (None, None))
        if old:
            if old in entry["summary"]:
                entry["summary"] = entry["summary"].replace(old, new)
            elif new not in entry["summary"]:
                raise SystemExit(f"Daniel {n}: summary fix not found: {old!r}")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_chapter_context():
    path = ROOT / "chapter_context" / "28_daniel.json"
    data = load(path)
    for n, text in AUDIENCE.items():
        data[f"Daniel {n}"]["audience"] = text
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_overview():
    path = ROOT / "book_overviews" / "05_major_prophets.json"
    data = load(path)
    entry = data["Daniel"]
    entry["theme"] = entry["theme"].replace(
        "God rules over human empires and will ultimately establish His kingdom, so His people can remain faithful under pressure.",
        "God rules over human empires and will ultimately establish his kingdom, so his people can remain faithful under pressure.",
    )
    for fig in entry["keyFigures"]:
        if fig["name"] == "One like a son of man":
            fig["description"] = fig["description"].replace(
                "Jesus applies this title to Himself.",
                "Jesus applies this title to himself.",
            )
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_PRONOUN_FIXES = [
    ("Shadrach, Meshach, and Abednego refuse, trusting God even if He does not deliver them.",
     "Shadrach, Meshach, and Abednego refuse, trusting God even if he does not deliver them."),
    ("and he has not honored the God who holds his very breath in His hand.",
     "and he has not honored the God who holds his very breath in his hand."),
    ("Fire streams out before Him, and millions of angels serve Him.",
     "Fire streams out before him, and millions of angels serve him."),
    ("Jesus often called Himself “the Son of man,” and He used these words at His trial (Mark 14:62).",
     "Jesus often called himself “the Son of man,” and he used these words at his trial (Mark 14:62)."),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "05_major_prophets.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("# Daniel")
    section = text[start:]
    for old, new in STORY_PRONOUN_FIXES:
        count = section.count(old)
        if count == 0:
            if section.count(new) == 1:
                continue
            raise SystemExit(f"story fix matched 0 times and not already applied: {old!r}")
        if count != 1:
            raise SystemExit(f"story fix matched {count} times (expected 1): {old!r}")
        section = section.replace(old, new)
    path.write_text(text[:start] + section, encoding="utf-8")
    print(f"Updated {path.relative_to(ROOT)}")


if __name__ == "__main__":
    apply_chapter_insights()
    apply_chapter_context()
    apply_overview()
    apply_story_fixes()
