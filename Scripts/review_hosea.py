#!/usr/bin/env python3
"""Apply the completed editorial review for Hosea to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


WWA = {
    1: "Daniel's closing chapter promised Daniel himself rest and a resurrection beyond any single empire's rise or fall. Hosea turns from that far-future hope to an urgent, present crisis: a prophet in the northern kingdom's own last decades is told to marry an unfaithful woman and name his children after Israel's approaching judgment. Chapter 2 continues this same marriage imagery, turning from the children's names to Israel itself pictured as an unfaithful wife.",
    2: "Chapter 1 gave Hosea's children names announcing judgment and a surprising hope beyond it. Here that same marriage imagery expands: Israel is accused of crediting false gods for blessings only God gave, then promised a renewed courtship in which her children's rejected names are finally reversed. Chapter 3 returns to Hosea's own marriage, now showing what that renewed love actually costs him in practice.",
    3: "Chapter 2 promised a reversal of Israel's children's rejected names. Here Hosea acts out that same promised love directly: he buys back an unfaithful woman and requires a period of exclusive devotion, mirroring a national season without king or worship before Israel finally returns. Chapter 4 leaves this personal sign behind for a direct, public indictment of the whole nation's conduct.",
    4: "Chapter 3 pictured Israel's coming exile through Hosea's own household. Here God brings a formal covenant lawsuit against the nation itself, charging priests and people alike with abandoning knowledge of God for idolatry and injustice. Chapter 5 continues this same covenant lawsuit, naming the specific leaders and locations where that failure plays out.",
    5: "Chapter 4 charged Israel broadly with abandoning knowledge of God. Here the charge narrows to specific leaders and places, priests, royal household, and towns linked to a trap, while both Israel and Judah are shown turning to Assyria for a cure no foreign power can actually provide. Chapter 6 opens with the people's own words in response, an invitation to return whose sincerity the rest of the chapter immediately tests.",
    6: "Chapter 5 ended with Israel and Judah's useless appeal to Assyria for healing. Here the people's own voice offers to return to the LORD, but God's reply exposes that devotion as fleeting as morning dew, since what he truly desires is steadfast love and knowledge of him, not ritual sacrifice. Chapter 7 shows exactly how far that steadfast love and knowledge still are from Israel's actual political and religious life.",
    7: "Chapter 6 declared that God desires mercy and knowledge of him above sacrifice. Here the gap between that desire and reality becomes vivid: Israel's own court is consumed by plots and assassinations, and the nation itself flies between Egypt and Assyria like a senseless dove instead of turning to God. Chapter 8 sums up this same instability as a nation now reaping the whirlwind it has sown.",
    8: "Chapter 7 pictured Israel as a dove flying uselessly between Egypt and Assyria. Here that same restlessness is named as a broken covenant: unauthorized kings, a calf idol at Samaria, and multiplied altars all bring the proverb 'they have sown the wind, and they shall reap the whirlwind' into full effect. Chapter 9 turns that same proverb toward a specific, coming loss: exile itself, and the worship Israel will no longer be able to practice once it arrives.",
    9: "Chapter 8 announced that Israel would reap the whirlwind of its own sowing. Here that whirlwind is named directly as exile to Assyria and Egypt, where normal festival worship becomes impossible, while the prophet himself faces hostility for delivering this very warning. Chapter 10 continues the harvest imagery from chapter 8, now applied to Israel's own prosperity rather than only its coming loss.",
    10: "Chapter 9 pictured exile ending Israel's festival worship entirely. Here the focus returns to the present: Israel's prosperity, pictured as a luxuriant vine, has only multiplied altars and unstable kings, and the prophet calls the nation to sow righteousness instead of continuing to plow wickedness. Chapter 11 shifts from this call to change toward God's own remembered love for Israel from its very beginning.",
    11: "Chapter 10 ended warning that Israel's fortresses and king would be overwhelmed. Here the tone turns unexpectedly tender: God remembers loving Israel as a child called out of Egypt, and even after describing real judgment still asks how he could ever give Ephraim up completely. Chapter 12 turns from this parental memory to Israel's ancestor Jacob, using his own history to press the same call to return.",
    12: "Chapter 11 pictured God's compassion restraining Israel's complete destruction. Here that same compassion is pressed into a call to action, as Hosea retells episodes from Jacob's own life, his grasping, his wrestling, his service for a wife, to challenge Ephraim's present dishonesty and misplaced alliances. Chapter 13 returns from this ancestral example to Ephraim's own more recent and more severe decline.",
    13: "Chapter 12 used Jacob's own history to call Ephraim back to justice and patience. Here that call goes unanswered: Ephraim's once-honored status gives way to idolatry so complete that the chapter pictures the nation vanishing like mist, chaff, and smoke, with even kingship powerless to help. Chapter 14 closes the book with the one response that could actually change this outcome: genuine return.",
    14: "Chapter 13 pictured Ephraim vanishing under judgment with no earthly power able to save it. Here the book's last word answers that same judgment with an invitation: Israel is urged to return with honest words rather than military power or idols, and God promises healing, free love, and renewed fruitfulness in response. The next book, Joel, turns from Israel's own unfaithfulness to a devastating locust plague used to call an unnamed audience to exactly this same kind of repentance.",
}

THEMES = {
    1: {"Prophetic signs": "Naming real children after a nation's judgment and hope turns Hosea's own family into a public announcement no one in Israel could easily ignore (1:4, 1:6, 1:9).",
        "Judgment and mercy": "Judah being shown mercy while Israel is told 'I will no more have mercy' in the same breath keeps judgment from falling evenly, exposing a real distinction between the two kingdoms' standing (1:6-7).",
        "Restored identity": "Promising that 'ye are not my people' will one day become 'ye are the sons of the living God' reverses the chapter's harshest judgment into its most hopeful promise, using the very same relationship language (1:9-10)."},
    2: {"Misplaced dependence": "Crediting Baal for grain, wine, and oil that God actually gave shows Israel's core error as misattributing blessing, not simply disobeying a rule (2:8).",
        "Judgment expressed through loss": "Taking away the harvests and festivals Israel credited to Baal removes the very things Israel trusted, letting the loss itself expose the trust's foundation as false (2:9-12).",
        "Renewed covenant": "Promising to 'speak comfortably' to Israel in the wilderness, the same setting as her first devotion, pictures restoration as a return to an earlier intimacy, not just a fresh start (2:14).",
        "Reversal of rejection": "Turning 'Loruhamah' and 'Loammi' into promises of mercy and belonging uses the children's own rejected names as the very material restoration is built from (2:23)."},
    3: {"Steadfast love": "Paying silver and barley to buy back a woman who left him pictures love that keeps choosing its object even after real betrayal, not love that only exists before betrayal happens (3:1-2).",
        "Deprivation and displacement": "Losing king, sacrifice, and sacred objects all at once pictures exile as a loss touching every institution Israel relied on, not just its political independence (3:4).",
        "Hope of return": "Seeking 'the LORD their God, and David their king' together ties Israel's future worship and future kingship to the same restored relationship (3:5)."},
    4: {"Covenant ethics": "Listing swearing, murder, theft, and adultery together as the direct result of lacking 'knowledge of God' ties specific social crimes to a single underlying spiritual failure (4:1-2).",
        "Failure of spiritual leadership": "Blaming priests specifically for people's destruction 'for lack of knowledge' holds those responsible for teaching accountable for what their failure actually costs (4:6).",
        "Misguided worship": "Warning Judah not to follow Israel's example turns this chapter's indictment of the north into a direct warning for the south as well (4:15)."},
    5: {"Accountable leaders": "Naming priests, the royal household, and specific towns together refuses to let any single group blame the others for the coming judgment (5:1).",
        "Ritual without return": "Performing sacrifice while 'the spirit of whoredoms' still governs their actions shows worship continuing even after the relationship behind it has already failed (5:4, 5:6).",
        "False political security": "Comparing appeal to Assyria's 'great king' to applying a bandage that cannot heal a wound names political alliance as a real but ultimately useless substitute for turning to God (5:13)."},
    6: {"Return and healing": "Expecting revival 'after two days' and 'on the third day' expresses confidence in a quick, almost automatic restoration that the rest of the chapter immediately complicates (6:2).",
        "Steadfast love over empty ritual": "Saying God desires 'mercy, and not sacrifice' does not reject sacrifice outright but ranks it below the relationship it was always meant to express (6:6).",
        "Betrayed covenant": "Naming specific violence 'in the way by consent' near Shechem turns the chapter's general charge of covenant-breaking into a concrete, located crime (6:9)."},
    7: {"Corrupt political life": "Comparing conspirators to a baker's heated oven pictures political intrigue as something that builds in secret before it suddenly, visibly consumes everything around it (7:4, 7:6-7).",
        "Divided loyalties": "Calling Ephraim 'a cake not turned' pictures a nation half-formed in two directions at once, neither side fully developed or fully trustworthy (7:8).",
        "Unrepentant need": "Crying out 'for corn and wine' while still refusing to return to God shows real need coexisting with a refusal to look to its actual source (7:14)."},
    8: {"Rejected covenant": "Crying 'my God, we know thee' while actually breaking the covenant shows a claim to relationship that the people's own conduct directly contradicts (8:2-3).",
        "Idols and power": "Kings made 'but not by me' and a calf idol crafted by human hands both substitute human-made authority for the authority Israel was actually under (8:4-6).",
        "Reaping consequences": "The proverb 'they have sown the wind, and they shall reap the whirlwind' insists the coming disaster is proportionate to, and caused by, Israel's own earlier choices (8:7).",
        "Misplaced worship and defenses": "Multiplying altars 'to sin' while trusting fortified cities shows religious and military security treated as substitutes for the same missing trust in God (8:11, 8:14)."},
    9: {"Lost celebration and land": "Being told not to 'rejoice... as other people' because unfaithfulness has reached the threshing floor ties Israel's coming loss directly to its own worship practices, not an unrelated misfortune (9:1).",
        "Resisted prophetic warning": "Calling the prophet 'a fool' and 'mad' shows the warning itself being dismissed as the very proof that judgment is deserved (9:7).",
        "Unfaithfulness and barrenness": "Reversing Israel's own fruitful beginning, 'grapes in the wilderness,' into a future of miscarriage and childlessness makes the judgment's reversal of blessing explicit rather than abstract (9:10-14)."},
    10: {"Prosperity and idolatry": "Israel's prosperity producing more altars rather than more faithfulness, 'according to the multitude of his fruit he hath increased the altars,' shows wealth itself becoming the occasion for greater unfaithfulness (10:1).",
         "Political fragility": "A king 'cut off as the foam upon the water' pictures Israel's monarchy as something that could disappear almost instantly, not a stable institution interrupted by unlikely crisis (10:7).",
         "Sowing righteousness": "Being told to 'sow... in righteousness' and 'break up your fallow ground' extends Israel's own farming language into a call for a fundamentally different kind of life, not just better luck (10:12).",
         "Violence and consequences": "Trusting in 'the multitude of thy mighty men' is answered directly by the destruction of exactly those fortresses, showing misplaced confidence collapsing on its own terms (10:13-14)."},
    11: {"Parental care": "Teaching Ephraim to walk and healing them by the arms pictures God's care in the most basic, hands-on parental terms available, not abstract providence (11:3).",
         "Consequences of refusal": "Responding to God's call by sacrificing to Baalim shows rebellion here taking the specific form of redirected worship, not simply disobedience in general (11:2, 11:7).",
         "Compassion amid judgment": "Asking 'how shall I give thee up' and then answering, 'for I am God, and not man,' grounds Israel's survival in God's own nature rather than in anything Israel has done to deserve it (11:8-9).",
         "Hope of homecoming": "Picturing the exiles trembling home 'as a bird out of Egypt, and as a dove out of... Assyria' reverses the very nations that exiled them into the route of their own eventual return (11:11)."},
    12: {"Deceptive alliances": "Making 'a covenant with the Assyrians' while also sending 'oil into Egypt' shows Ephraim hedging between two powers rather than trusting either fully, let alone trusting God (12:1).",
         "Learning from Jacob": "Recalling that Jacob 'wept, and made supplication' when he sought God's blessing uses the nation's own ancestor to model the kind of seeking Ephraim currently refuses (12:4).",
         "Justice in commerce": "Ephraim's 'balances of deceit' in trade show covenant unfaithfulness reaching into ordinary business practice, not staying confined to formal worship (12:7).",
         "Remembering deliverance": "Recalling that God used 'a prophet' to bring Israel 'out of Egypt' ties the nation's whole existence back to prophetic guidance, the very kind of guidance it is currently rejecting in Hosea himself (12:13)."},
    13: {"Idolatry and fleeting security": "Men who 'kiss the calves' in worship are described through images of mist, dew, chaff, and smoke, all things that vanish almost as soon as they appear (13:2-3).",
         "Forgetting past care": "Saying that after being 'filled... they were exalted; therefore have they forgotten me' ties the people's forgetfulness directly to the very prosperity God gave them (13:6).",
         "Failure of kingship": "Asking 'where is thy king... that he may save thee' exposes the monarchy's inability to provide the protection Israel expected from it (13:10).",
         "Death and judgment": "Promising to redeem Israel 'from the power of the grave' in the very chapter that also announces Samaria's fall holds judgment and ultimate rescue together rather than letting either cancel the other out (13:14, 13:16)."},
    14: {"Honest return": "Being given the actual 'words' to say in returning, including naming Assyria and idols by name, shows real repentance including specific confession, not just general sorrow (14:2-3).",
         "Healing love": "Promising to 'love them freely' answers Israel's whole history of purchased, hedged, and divided loyalty with a love that asks for nothing in exchange (14:4).",
         "Renewed flourishing": "Describing Israel's restoration through lilies, olive trees, and grain pictures renewal in terms of ordinary, sustaining fruitfulness rather than only dramatic rescue (14:5-7).",
         "Wisdom and response": "Ending by asking who is 'wise' enough to 'understand these things' turns the whole book's message into a test of discernment for every later reader, not only Hosea's own audience (14:9)."},
}

NAME_FIXES = {
    2: {"Baal/Baalim": "Baal (Baalim)"},
    4: {"Israel/Ephraim": "Israel (Ephraim)"},
    5: {"Israel/Ephraim": "Israel (Ephraim)"},
    7: {"Ephraim/Israel": "Israel (Ephraim)"},
    8: {"Israel/Ephraim": "Israel (Ephraim)"},
    9: {"Israel/Ephraim": "Israel (Ephraim)"},
    10: {"Israel/Ephraim": "Israel (Ephraim)"},
    11: {"Israel/Ephraim": "Israel (Ephraim)"},
    12: {"Ephraim/Israel": "Israel (Ephraim)", "Jacob/Israel": "Jacob (Israel)"},
    13: {"Ephraim/Israel": "Israel (Ephraim)"},
    14: {"Israel/Ephraim": "Israel (Ephraim)"},
}

ROLE_FIXES = {
    3: {"The unnamed woman":
        "Person Hosea is told to love. Participates in the sign; many readers identify her with Gomer, though the text does not say so directly"},
    6: {"The collective speakers of 6:1-3":
        "Voices urging return. Express hope of healing, though the chapter's own reply suggests their devotion will not last"},
}

SUMMARY_FIXES = {
    13: ("Verse 14 invokes death and Sheol in language whose punctuation and interpretation are debated, and the chapter ends with violent warnings against Samaria (Hosea 13:14–16).",
         "Verse 14 invokes death and Sheol in language that different translations punctuate as either promise or taunt, and the chapter ends with violent warnings against Samaria (Hosea 13:14–16)."),
}

AUDIENCE = {
    1: "First hearers who had lived through Jeroboam II's prosperous reign would have heard Jezreel's name land very differently than later readers do, as a direct threat to the still-reigning royal dynasty, not distant history.",
    3: "Hearers who knew the going rate for a slave or a bride would have recognized fifteen pieces of silver and barley as a real, modest price, making Hosea's buying back of his wife feel like an ordinary transaction carrying extraordinary meaning.",
    7: "Hearers living through the actual chaos of four assassinated kings in a row would have heard this chapter's palace-intrigue imagery as a description of events in their own very recent memory, not a general warning.",
    9: "Exiles who later found themselves eating rationed, unfamiliar food far from Jerusalem would have recognized this warning's specific anxiety about unclean food in a foreign land as something they were actually living through.",
    14: "Hearers who had just heard Assyria named throughout the book as a tempting but unreliable ally would have recognized the confession God supplies them to pray, 'Asshur shall not save us,' as finally renouncing that very temptation by name.",
}


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "28_hosea.json"
    data = load(path)
    for n in range(1, 15):
        key = f"Hosea {n}"
        entry = data[key]
        entry["whereWeAre"] = WWA[n]
        theme_map = THEMES[n]
        seen = set()
        for theme in entry["keyThemes"]:
            name = theme["theme"]
            if name not in theme_map:
                raise SystemExit(f"Hosea {n}: no explanation drafted for theme {name!r}")
            theme["explanation"] = theme_map[name]
            seen.add(name)
        missing = set(theme_map) - seen
        if missing:
            raise SystemExit(f"Hosea {n}: drafted themes not in source: {missing}")
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
                raise SystemExit(f"Hosea {n}: summary fix not found: {old!r}")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_chapter_context():
    path = ROOT / "chapter_context" / "29_hosea_micah.json"
    data = load(path)
    for n, text in AUDIENCE.items():
        data[f"Hosea {n}"]["audience"] = text
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_overview():
    path = ROOT / "book_overviews" / "06_minor_prophets.json"
    data = load(path)
    entry = data["Hosea"]
    entry["theme"] = entry["theme"].replace(
        "Israel's spiritual adultery brings judgment, yet God's covenant love continues to call His people back.",
        "Israel's spiritual adultery brings judgment, yet God's covenant love continues to call his people back.",
    )
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_PRONOUN_FIXES = [
    ("yet God promises that judgment will not end His love: He will restore His people, renew mercy, and again call them His own.",
     "yet God promises that judgment will not end his love: he will restore his people, renew mercy, and again call them his own."),
    ("one day, in the very place where they were told they are not His people, they will be called “the sons of the living God.”",
     "one day, in the very place where they were told they are not his people, they will be called “the sons of the living God.”"),
    ("Then God will win her back: “I will allure her, and bring her into the wilderness, and speak comfortably unto her.” He promises, “I will betroth thee unto me for ever.” And He reverses the children's names:",
     "Then God will win her back: “I will allure her, and bring her into the wilderness, and speak comfortably unto her.” he promises, “I will betroth thee unto me for ever.” and he reverses the children's names:"),
    ("Just as Hosea bought back his unfaithful wife, God will buy back His unfaithful people.",
     "Just as Hosea bought back his unfaithful wife, God will buy back his unfaithful people."),
    ("God warns that He will withdraw until they acknowledge their guilt and seek Him.",
     "God warns that he will withdraw until they acknowledge their guilt and seek him."),
    ("God especially blames the priests, who were supposed to teach His law:",
     "God especially blames the priests, who were supposed to teach his law:"),
    ("So God will be like a lion tearing its prey. Then He will go back to His place",
     "So God will be like a lion tearing its prey. Then he will go back to his place"),
    ("God desires mercy and knowledge of Him rather than empty sacrifice, while the nation continues deceit",
     "God desires mercy and knowledge of him rather than empty sacrifice, while the nation continues deceit"),
    ("But their promises do not last. God says sadly, “O Ephraim, what shall I do unto thee?... for your goodness is as a morning cloud, and as the early dew it goeth away.” Then He tells them what He really wants:",
     "But their promises do not last. God says sadly, “O Ephraim, what shall I do unto thee?... for your goodness is as a morning cloud, and as the early dew it goeth away.” Then he tells them what he really wants:"),
    ("people will be taken captive to Assyria. God remembers when He first found Israel:",
     "people will be taken captive to Assyria. God remembers when he first found Israel:"),
    ("the people turned to Baal. Judgment through Assyria is coming, but His compassion remains;",
     "the people turned to Baal. Judgment through Assyria is coming, but his compassion remains;"),
    ("So Assyria will rule over them. But then God's heart breaks: “How shall I give thee up, Ephraim? how shall I deliver thee, Israel?... mine heart is turned within me.” He will not destroy them completely, “for I am God, and not man; the Holy One in the midst of thee.” One day His children will come home trembling,",
     "So Assyria will rule over them. But then God's heart breaks: “How shall I give thee up, Ephraim? how shall I deliver thee, Israel?... mine heart is turned within me.” he will not destroy them completely, “for I am God, and not man; the Holy One in the midst of thee.” One day his children will come home trembling,"),
    ("later wrestled with God and wept, asking for His blessing.",
     "later wrestled with God and wept, asking for his blessing."),
    ("God reminds them, “Yet I am the LORD thy God from the land of Egypt, and thou shalt know no god but me: for there is no saviour beside me.” He cared for them in the desert,",
     "God reminds them, “Yet I am the LORD thy God from the land of Egypt, and thou shalt know no god but me: for there is no saviour beside me.” he cared for them in the desert,"),
    ("their heart was exalted; therefore have they forgotten me.” Now He will meet them “as a bear that is bereaved of her whelps,”",
     "their heart was exalted; therefore have they forgotten me.” Now he will meet them “as a bear that is bereaved of her whelps,”"),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "06_minor_prophets.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("# Hosea")
    end = text.index("# Joel")
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
    apply_overview()
    apply_story_fixes()
