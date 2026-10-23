#!/usr/bin/env python3
"""Apply the completed editorial review for Lamentations to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


WWA = {
    1: "Jeremiah's final chapter closed with a historical account of Jerusalem's fall and Jehoiachin's unexpected release, a restrained note of hope after decades of warning. Lamentations opens in the wake of that same fall: Jerusalem itself, personified as a grieving widow, voices the grief Jeremiah's warnings finally became. Lamentations 2 continues this same grief, describing the destruction in the stark language of God's own judgment.",
    2: "Lamentations 1 gave the devastated city its own voice to mourn her losses. Here the poem describes that same destruction more directly as the LORD's own judgment, picturing ruined defenses, humbled leaders, and starving children, before ending in a call to cry out rather than stay silent. Lamentations 3 turns from this communal description to one suffering individual's own extended lament and fragile hope.",
    3: "Lamentations 2 ended calling Zion to cry out continually over her suffering. Here a single voice, 'the man that hath seen affliction,' does exactly that: moving from near despair under God's anger to remembered mercy, and from self-examination to a plea for justice against his enemies. Lamentations 4 returns to the city's own voice, contrasting Jerusalem's former splendor with its present ruin.",
    4: "Lamentations 3 ended with one sufferer's personal plea for justice. Here the lament widens back out to the whole city, remembering Jerusalem's former honor against its present famine and shame, naming the failures of prophets and priests, and warning Edom that its own judgment is still coming. Lamentations 5 closes the book with the community's own collective prayer.",
    5: "Lamentations 4 warned Edom that celebrating Jerusalem's fall would not go unanswered. Here the book closes with a communal prayer, 'Remember, O LORD,' bringing the community's hunger, forced labor, and lost joy before God and asking to be restored, though the book ends with an honest, unresolved question rather than a settled answer. The next book, Ezekiel, continues this same exile with a very different kind of prophetic voice, visions given to a priest already living among the captives in Babylon.",
}

SUMMARY_1_SENTENCE_FIX = (
    "The poem repeatedly connects the city’s suffering with her sins without treating that explanation as a reason to ignore her pain (Lamentations 1:5), Lamentations 1:8, Lamentations 1:18.",
    "The poem repeatedly names the city’s own sin as part of her suffering, yet still gives full voice to her pain rather than treating the explanation as a reason to minimize it (Lamentations 1:5, 1:8, 1:18).",
)

NAME_FIXES = {
    1: {"Daughter of Zion / Jerusalem": "Daughter of Zion (Jerusalem)"},
    2: {"Daughter of Zion / Jerusalem": "Daughter of Zion (Jerusalem)"},
    3: {"The people / the living": "The people (the living)"},
    4: {"Daughter of Zion / Jerusalem": "Daughter of Zion (Jerusalem)",
        "Edom / daughter of Edom": "Edom (daughter of Edom)"},
}

ROLE_RUNON_FIXES = {
    3: {"The people / the living":
        "Community addressed with calls to self-examination. Broadens personal lament into collective responsibility and repentance (3:39–42)."},
    4: {"The LORD":
        "God whose wrath and future dealings are invoked. Judgment and the possibility of an end to Zion’s punishment frame the poem (4:11, 22)."},
    5: {"Servants and oppressors":
        "Persons described as ruling over or humiliating the community. Convey a loss of political freedom and dignity (5:5, 8, 11–13)."},
}

THEMES = {
    1: {"Grief after catastrophe": "Comparing Jerusalem to a widow who once had many lovers but now has no comforter turns a military defeat into a deeply personal loss of relationship and status (1:1-2).",
        "Sin and accountability": "The city's own admission, 'the LORD is righteous; for I have rebelled against his commandment,' keeps the poem from blaming the disaster on anyone but Jerusalem itself (1:18).",
        "Abandonment and failed support": "Allies Jerusalem once trusted are named among those who now betray or ignore her, showing that political alliances offered no real security when disaster came (1:2, 1:19).",
        "Appeal for divine attention": "Asking passersby, 'is it nothing to you, all ye that pass by? behold, and see,' and then asking the same of God turns private grief into a public plea for someone, anyone, to notice (1:12, 1:20)."},
    2: {"Judgment and the destruction of institutions": "Listing the fall of the king, the priests, and the sanctuary together shows that this judgment reached every pillar of Judah's public life, not just its army (2:1-9).",
        "The suffering of the vulnerable": "Children fainting for bread in the streets and asking their mothers where it is makes the famine's cost impossible to read as a purely political or military matter (2:11-12).",
        "Danger of misleading reassurance": "Prophets who saw 'vain and foolish things' instead of exposing Judah's sin are blamed for leaving the people unprepared for the judgment that still came (2:14).",
        "Lament as sustained prayer": "Being told to 'pour out thine heart like water' pictures prayer in disaster as something continuous and unguarded, not a single polished request (2:19)."},
    3: {"Steadfast love amid suffering": "Remembering that 'his compassions fail not' and are 'new every morning' becomes the hinge of the whole chapter, turning near despair into grounds for hope without denying the suffering that came first (3:22-23).",
        "Waiting and patience": "Calling it 'good' to both hope and 'quietly wait for the salvation of the LORD' treats patience itself as a form of faith, not merely delay (3:25-26).",
        "Self-examination and return": "The call to 'search and try our ways, and turn again to the LORD' moves the poem from personal suffering to communal responsibility for what caused it (3:40).",
        "Justice and concern for the oppressed": "Insisting that the LORD does not approve crushing prisoners or denying justice shows that God's own character, not just Judah's judgment, is at stake in how the oppressed are treated (3:34-36).",
        "Persevering lament": "Recalling a specific past rescue, 'out of the low dungeon,' while still pleading for justice now shows lament continuing even after hope has already been found once (3:55-58)."},
    4: {"Reversal of social standing": "Gold grown dim and children once worth their weight in gold now valued like broken clay turns economic language itself into a picture of the city's fall (4:1-2).",
        "Famine and civilian suffering": "Babies' tongues cleaving to the roof of their mouths for thirst makes the famine's horror physical and immediate rather than a statistic (4:4).",
        "Accountability of religious leaders": "Blaming prophets and priests for shedding 'the blood of the just' names specific moral failure among Judah's own leaders as part of the reason for judgment (4:13).",
        "Misplaced hope in political rescue": "Watching in vain 'for a nation that could not save' exposes the people's hope in Egypt as a hope placed in exactly the wrong source (4:17).",
        "Judgment and future reversal": "Telling Edom to prepare for its own cup of judgment while promising that Zion's punishment will one day end gives the chapter's final word to reversal rather than permanence (4:21-22)."},
    5: {"Collective remembrance and lament": "Opening with 'Remember, O LORD' and 'consider, and behold our reproach' asks God to actively look at the community's situation, not simply to be informed of it in passing (5:1).",
        "Social suffering after conquest": "Paying for water and wood that once belonged freely to the people turns conquest's cost into something felt in ordinary daily transactions (5:4).",
        "Grief over lost worship and joy": "Noting that 'the joy of our heart is ceased; our dance is turned into mourning' measures the city's loss in terms of its missing celebration, not only its missing buildings (5:15).",
        "Divine sovereignty and petition for restoration": "Confessing that the LORD's 'throne from generation to generation' endures even while asking him to 'turn us' shows trust in God's rule surviving even a request that assumes things are not yet right (5:19, 5:21).",
        "Unresolved ending": "Ending with 'thou hast utterly rejected us; thou art very wroth against us' instead of a settled answer leaves the book's hope genuinely uncertain rather than resolved (5:22)."},
}


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "25_lamentations.json"
    data = load(path)
    for n in range(1, 6):
        key = f"Lamentations {n}"
        entry = data[key]
        entry["whereWeAre"] = WWA[n]
        for fig in entry["keyFigures"]:
            if fig["name"] in NAME_FIXES.get(n, {}):
                fig["role"] = ROLE_RUNON_FIXES.get(n, {}).get(fig["name"], fig["role"])
                fig["name"] = NAME_FIXES[n][fig["name"]]
            elif fig["name"] in ROLE_RUNON_FIXES.get(n, {}):
                fig["role"] = ROLE_RUNON_FIXES[n][fig["name"]]
        theme_map = THEMES[n]
        seen = set()
        for theme in entry["keyThemes"]:
            name = theme["theme"]
            if name not in theme_map:
                raise SystemExit(f"Lamentations {n}: no explanation drafted for theme {name!r}")
            theme["explanation"] = theme_map[name]
            seen.add(name)
        missing = set(theme_map) - seen
        if missing:
            raise SystemExit(f"Lamentations {n}: drafted themes not in source: {missing}")
    old, new = SUMMARY_1_SENTENCE_FIX
    if old in data["Lamentations 1"]["summary"]:
        data["Lamentations 1"]["summary"] = data["Lamentations 1"]["summary"].replace(old, new)
    elif new not in data["Lamentations 1"]["summary"]:
        raise SystemExit("Lamentations 1 summary fix not found")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


AUDIENCE_FIX = (
    "Lamentations 2",
    "The second poem describes God's anger against Jerusalem—its walls, palaces, temple, priests, and children.",
    "Readers who had just absorbed the Historical Moment's bare facts of conquest would have heard this poem name those same losses one by one as acts of divine judgment, not misfortune.",
)


def apply_chapter_context():
    path = ROOT / "chapter_context" / "26_jeremiah_27-52_lamentations.json"
    data = load(path)
    key, old, new = AUDIENCE_FIX
    current = data[key]["audience"]
    if current == old:
        data[key]["audience"] = new
    elif current != new:
        raise SystemExit(f"{key} audience text not in expected state: {current!r}")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_PRONOUN_FIXES = [
    ("the destruction as the work of God Himself.",
     "the destruction as the work of God himself."),
    ("The Lord has acted like an enemy against His own people. He has swallowed up Israel's palaces",
     "The Lord has acted like an enemy against his own people. he has swallowed up Israel's palaces"),
    ("thrown down Judah's fortresses, and even rejected His own altar and temple.",
     "thrown down Judah's fortresses, and even rejected his own altar and temple."),
    ("Long ago He warned them this would happen.",
     "Long ago he warned them this would happen."),
    ("God is the speaker's portion and reason for hope; He disciplines but does not cast people away forever",
     "God is the speaker's portion and reason for hope; he disciplines but does not cast people away forever"),
    ("the speaker calls on the Lord, remembers that He heard and defended him,",
     "the speaker calls on the Lord, remembers that he heard and defended him,"),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "05_major_prophets.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("# Lamentations")
    end = text.index("# Ezekiel")
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
    for n, text in WWA.items():
        if len(text) > 600:
            print(f"TOO LONG {n}: {len(text)}")
    apply_chapter_insights()
    apply_chapter_context()
    apply_story_fixes()
