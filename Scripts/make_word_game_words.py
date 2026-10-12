#!/usr/bin/env python3
"""Build the WORD game's curated answer list.

Each entry below is WORD or WORD|Reference. Words were curated from every 5-letter
token in the KJV (see word_game_candidates.py): biblically meaningful, mostly base
forms, no archaic verb forms (SAITH, SPAKE, BEGAT...). A hand-picked reference is
verified to contain the word; otherwise the word's first occurrence is used.

Output:
  Scripts/word_game_words_review.md   – alphabetical review sheet with verse text

This was the first draft of the list. The game now reads the reviewed list in
The Bible/WORDCuratedWordList.json; edit that file to change the game's words.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KJV = ROOT / "The Bible" / "kjv.json"
OUT_REVIEW = ROOT / "Scripts" / "word_game_words_review.md"

# Mirrors BookNames in BibleData.swift.
BOOK_NAMES = {
    "gn": "Genesis", "ex": "Exodus", "lev": "Leviticus", "num": "Numbers", "de": "Deuteronomy",
    "jos": "Joshua", "jdg": "Judges", "ru": "Ruth", "1sa": "1 Samuel", "2sa": "2 Samuel",
    "1ki": "1 Kings", "2ki": "2 Kings", "1ch": "1 Chronicles", "2ch": "2 Chronicles",
    "ezr": "Ezra", "ne": "Nehemiah", "es": "Esther", "job": "Job", "ps": "Psalms",
    "pr": "Proverbs", "ec": "Ecclesiastes", "so": "Song of Solomon", "is": "Isaiah",
    "je": "Jeremiah", "la": "Lamentations", "eze": "Ezekiel", "da": "Daniel", "ho": "Hosea",
    "joe": "Joel", "am": "Amos", "ob": "Obadiah", "jon": "Jonah", "mic": "Micah", "na": "Nahum",
    "hab": "Habakkuk", "zep": "Zephaniah", "hag": "Haggai", "zec": "Zechariah", "mal": "Malachi",
    "mt": "Matthew", "mr": "Mark", "lu": "Luke", "joh": "John", "ac": "Acts", "ro": "Romans",
    "1co": "1 Corinthians", "2co": "2 Corinthians", "ga": "Galatians", "eph": "Ephesians",
    "php": "Philippians", "col": "Colossians", "1th": "1 Thessalonians", "2th": "2 Thessalonians",
    "1ti": "1 Timothy", "2ti": "2 Timothy", "tit": "Titus", "phm": "Philemon", "heb": "Hebrews",
    "jas": "James", "1pe": "1 Peter", "2pe": "2 Peter", "1jo": "1 John", "2jo": "2 John",
    "3jo": "3 John", "jude": "Jude", "re": "Revelation",
}

CURATED = """
# Faith and theology
FAITH|Hebrews 11:1
GRACE|Ephesians 2:8
MERCY|Micah 6:8
PEACE|John 14:27
GLORY|Luke 2:14
TRUTH|John 8:32
TRUST|Proverbs 3:5
HEART|Psalms 119:11
ANGEL|Luke 2:10
DEVIL|James 4:7
SATAN|Luke 10:18
CROSS|Luke 9:23
BLOOD|Hebrews 9:22
FLESH|John 1:14
DEATH|John 5:24
LIGHT|Genesis 1:3
POWER|Acts 1:8
WORLD|John 3:16
CROWN|James 1:12
ALTAR|Genesis 8:20
PSALM|Psalms 98:5
BLESS|Numbers 6:24
CURSE|Genesis 12:3
SAVED|Acts 16:31
SAINT|Philippians 4:21
ELECT|Colossians 3:12
GODLY|2 Timothy 3:12
TITHE|Leviticus 27:30
MANNA|Exodus 16:31
MYRRH|Matthew 2:11
EPHOD|Exodus 28:6
CUBIT|Matthew 6:27
SELAH|Psalms 3:2
TRIBE
JUDGE|Matthew 7:1
REIGN|Revelation 11:15
WRATH|Proverbs 15:1
ANGER|Psalms 103:8
SHAME|Hebrews 12:2
PRIDE|Proverbs 16:18
FOLLY|Proverbs 26:11
GUILE|John 1:47
GUILT
GHOST|Acts 2:4
SLAIN|Revelation 5:12
RISEN|Matthew 28:6
UNITY|Psalms 133:1
PIETY|1 Timothy 5:4
AGONY|Luke 22:44
TRUMP|1 Corinthians 15:52
STING|1 Corinthians 15:55
PRIZE|Philippians 3:14
GIVER|2 Corinthians 9:7
DEBTS|Matthew 6:12
TRIAL|1 Peter 4:12
TITLE|John 19:19
SKULL|John 19:17
TOWEL|John 13:4

# People
DAVID|1 Samuel 16:13
JESUS|John 11:35
MOSES|Exodus 3:4
JUDAH|Genesis 49:10
JACOB|Genesis 32:28
AARON|Exodus 4:14
PETER|Matthew 14:29
SIMON|Matthew 16:16
ISAAC|Genesis 22:2
ABRAM|Genesis 12:1
SARAH|Genesis 18:14
LABAN
HAMAN|Esther 7:10
JESSE|Isaiah 11:1
CALEB|Numbers 14:24
JUDAS|Matthew 26:14
MICAH|Micah 1:1
URIAH|2 Samuel 11:3
NAOMI|Ruth 1:3
JONAH|Jonah 1:17
TAMAR
CYRUS|Ezra 1:1
HIRAM|1 Kings 5:1
NABAL|1 Samuel 25:3
HEROD|Matthew 2:1
JAMES|Mark 1:19
TITUS|Titus 1:4
SILAS|Acts 16:25
ENOCH|Genesis 5:24
HAGAR|Genesis 16:1
RAHAB|Joshua 2:1
DINAH|Genesis 34:1
FELIX|Acts 24:25
HOSEA|Hosea 1:1
LYDIA|Acts 16:14
KORAH|Numbers 16:32
BARAK|Judges 4:6
ABNER
ZADOK|1 Kings 1:39
ASAPH
ASHER
BALAK|Numbers 22:2
AMNON
ELIHU|Job 32:2
TERAH|Genesis 11:27
GOMER|Hosea 1:3
JARED
JABEZ|1 Chronicles 4:10
JASON
GAIUS|3 John 1:1
ANNAS|John 18:13
ACHAN|Joshua 7:1
JOASH
NAHUM|Nahum 1:1

# Places and names
EGYPT|Exodus 20:2
SODOM|Genesis 19:24
SINAI|Exodus 19:20
HOREB|Exodus 3:1
JOPPA|Jonah 1:3
CRETE|Titus 1:5
ITALY|Acts 27:1
SALEM|Genesis 14:18
ENDOR|1 Samuel 28:7
SYRIA|Luke 2:2
RAMAH|1 Samuel 1:19
TABOR
SIDON|Matthew 11:21
PURIM|Esther 9:26
DAGON|1 Samuel 5:3
MARAH|Exodus 15:23
ALPHA|Revelation 1:8
OMEGA|Revelation 22:13
GREEK|Galatians 3:28
ROMAN|Acts 22:25
AMMON
MAMRE|Genesis 18:1
HARAN|Genesis 12:4
EKRON
MAGOG|Ezekiel 38:2
LIBYA
BABEL|Genesis 11:9

# Things, places, creation
HOUSE|Joshua 24:15
EARTH|Genesis 1:1
VOICE|1 Kings 19:12
SWORD|Hebrews 4:12
MOUTH|Psalms 19:14
WATER|John 4:14
BREAD|John 6:35
DRINK|John 7:37
WOMAN|Proverbs 31:10
CHILD|Proverbs 22:6
SHEEP|John 10:11
STONE|John 8:7
BEAST|Revelation 13:18
RIVER|Revelation 22:1
FRUIT|Galatians 5:22
FIELD|Matthew 6:28
NIGHT|Psalms 30:5
MOUNT|Matthew 24:3
FEAST|Luke 2:41
FLOCK|Luke 2:8
CLOUD|Exodus 13:21
LINEN|Revelation 19:8
IMAGE|Genesis 1:27
HONEY|Exodus 3:8
WIDOW|Mark 12:42
QUEEN|Esther 2:17
WHEAT|John 12:24
CEDAR|Psalms 92:12
TOWER|Genesis 11:4
SNARE|Psalms 91:3
SPEAR|1 Samuel 17:45
SMOKE|Exodus 19:18
FLOOD|Genesis 7:17
STAFF|Psalms 23:4
HORSE|Revelation 6:2
OLIVE|Genesis 8:11
BROOK|1 Samuel 17:40
PORCH|John 10:23
FLAME
THIEF|1 Thessalonians 5:2
EAGLE|Deuteronomy 32:11
SWINE|Matthew 7:6
MAKER|Psalms 95:6
CHAFF|Psalms 1:4
BRIDE|Revelation 21:2
STORM|Mark 4:37
CAMEL|Matthew 19:24
IVORY|1 Kings 10:18
PALSY|Mark 2:3
LEPER|Matthew 8:2
SIEGE
BEARD|Psalms 133:2
ARROW|Psalms 91:5
LAVER
WHEEL|Ezekiel 1:16
TOKEN|Genesis 9:12
CHAIN
MITRE
BERYL
GRAPE
APPLE|Psalms 17:8
SLING|1 Samuel 17:50
GIANT
VIPER|Acts 28:3
ADDER|Psalms 91:13
RAVEN|Genesis 8:7
SOWER|Mark 4:14
TARES|Matthew 13:25
RABBI|John 3:2
THORN|2 Corinthians 12:7
COUCH|Luke 5:19
KNIFE|Genesis 22:10
FROST
LUCRE|1 Timothy 3:3
TOPAZ
SPICE
STORK|Jeremiah 8:7
FLINT
GOURD|Jonah 4:6
PENNY|Matthew 20:2
BLADE|Mark 4:28
DOWRY
FLUTE|Daniel 3:5
WHALE|Matthew 12:40
ORION|Job 38:31
JEWEL
PEARL|Matthew 13:46
CORAL
TORCH
EBONY
GUEST
CREEK
EXILE
BRIBE
FRAUD
BOOTH|Jonah 4:5
WITCH
VENOM
CRANE
HERON
MOUSE
SNAIL|Psalms 58:8
SHAPE|Luke 3:22
SHEET|Acts 10:11
PERIL|Romans 8:35
SPARK
CLIFF
SIEVE|Amos 9:9
PAPER|2 John 1:12
SENSE|Nehemiah 8:8
SHADE|Psalms 121:5
JUICE
SLAVE
ANVIL|Isaiah 41:7
MIDST|Matthew 18:20
MIGHT|Zechariah 4:6
SIGHT|2 Corinthians 5:7
RIGHT|Psalms 16:11
CHIEF|Ephesians 2:20
MONEY|1 Timothy 6:10
COURT
ENEMY|Romans 12:20
BRASS
NOISE|Psalms 100:1
RULER|John 3:1
TABLE|Psalms 23:5
DREAM|Genesis 37:5
YOUTH|Ecclesiastes 12:1
GRAVE|1 Corinthians 15:55
GRASS|Isaiah 40:8
FLOUR
WAGES|Romans 6:23
GUARD
BELLY|Jonah 2:1
PLANT|Ecclesiastes 3:2
ASHES|Job 42:6
BOSOM|Luke 16:22
GRIEF|Isaiah 53:3
STORE
WOUND
GUIDE|Psalms 32:8
THIGH|Genesis 32:25
PITCH|Genesis 6:14
FLOOR
FAULT
CLOTH|Matthew 9:16
GROVE
SHORE
STRAW|Exodus 5:7
MIRTH
BIRTH|Matthew 1:18
TROOP
ERROR
TOOTH|Matthew 5:38
DEPTH|Romans 8:39
ALARM
CHEER|John 16:33
DREAD
SHEAF|Genesis 37:7
FEVER|Matthew 8:15
CRUSE|1 Kings 17:12
CHEEK|Matthew 5:39
HEDGE|Job 1:10
GLASS|1 Corinthians 13:12
DOUGH
BRICK|Genesis 11:3
RIDER
BOUGH
RAZOR|Judges 13:5
GRAIN|Matthew 17:20
DROSS
CHEST|2 Kings 12:9
DITCH|Matthew 15:14
CRAFT
HAVEN|Psalms 107:30
ALIEN
FRAME|Psalms 103:14
PURSE
PROOF
SWEAT|Genesis 3:19
ORGAN|Genesis 4:21
SINEW
WHELP|Genesis 49:9
AGATE
WAFER
BOOTY
BROTH
SMITH
PULSE|Daniel 1:12
SCENT
DREGS
JEWEL
BRIER
AMBER
ISSUE|Mark 5:25
PRICE|1 Corinthians 6:20
SKILL
REALM

# Actions
BRING
SPEAK|1 Samuel 3:9
SERVE|Joshua 24:15
BUILD|Matthew 16:18
ENTER|Matthew 7:13
ARISE|Isaiah 60:1
TEACH|Psalms 25:4
WRITE|Habakkuk 2:2
CARRY|Isaiah 40:11
SLEEP|Psalms 4:8
ABIDE|John 15:4
DWELL|Psalms 23:6
CEASE
RAISE|John 6:40
SWEAR|Matthew 5:34
WATCH|Mark 13:37
TARRY|Luke 24:49
TOUCH|Mark 5:28
MOURN|Matthew 5:4
UTTER|Matthew 13:35
SPARE
VISIT|James 1:27
SHOUT|Joshua 6:5
SHINE|Matthew 5:16
LEARN|Matthew 11:29
FETCH
YIELD
PLUCK|John 10:28
LODGE|Ruth 1:16
THANK|Philippians 1:3
EXALT|Psalms 34:3
PROVE|Malachi 3:10
STEAL|Exodus 20:15
MARRY|Mark 12:25
TASTE|Psalms 34:8
GRANT|Revelation 3:21
BOAST|Ephesians 2:9
ABHOR|Romans 12:9
LAUGH|Ecclesiastes 3:4
GREET|1 Peter 5:14
SCORN
REACH|John 20:27
CATCH|Luke 5:10
PURGE|Psalms 51:7
ENJOY|1 Timothy 6:17
REBEL
DOUBT|Matthew 21:21
GLEAN|Ruth 2:2
COVET|Exodus 20:17
REPAY|Romans 12:19
DANCE|Ecclesiastes 3:4
GROAN
AGREE|Matthew 18:19
RENEW|Isaiah 40:31
WEIGH
AMEND
EXCEL
SEIZE
CHIDE|Psalms 103:9
ABASE
EXTOL|Psalms 30:1
KNOCK|Matthew 7:7
KNEEL|Psalms 95:6
CLIMB
QUAKE
EDIFY
FEIGN
DEFER
ALLOW
SWEEP|Luke 15:8
STUDY|2 Timothy 2:15
AVOID
OFFER
FIGHT|1 Timothy 6:12
BREAK|Isaiah 42:3
STAND|Ephesians 6:11
APPLY|Psalms 90:12
ADORN
YEARN
UNITE|Psalms 86:11
GNASH
WEAVE
DROWN
KNEAD

# Descriptions
GREAT|Psalms 145:3
YOUNG|Psalms 37:25
WHOLE|Ecclesiastes 12:13
CLEAN|Psalms 51:10
SWEET|Psalms 119:103
ALONE|Matthew 4:4
READY|1 Peter 3:15
ALIVE|1 Corinthians 15:22
EARLY|Psalms 63:1
BLIND|John 9:25
WHITE|Isaiah 1:18
FALSE|Exodus 20:16
DAILY|Matthew 6:11
PROUD|James 4:6
NAKED|Job 1:21
ANGRY|Ephesians 4:26
TRULY|Psalms 62:1
WEARY|Galatians 6:9
GREEN|Psalms 23:2
FAINT|Isaiah 40:31
HEAVY|Matthew 11:28
EMPTY|Luke 1:53
NEEDY
QUIET|1 Thessalonians 4:11
HAPPY|Psalms 144:15
MERRY|Proverbs 17:22
CRUEL
SWIFT|Ecclesiastes 9:11
FIERY|Daniel 3:6
WORTH
NOBLE|Acts 17:11
LOWLY|Matthew 11:29
SOBER|1 Peter 5:8
LOFTY
HASTY
STONY|Matthew 13:5
ROUGH|Isaiah 40:4
RUDDY|1 Samuel 16:12
HOARY|Proverbs 16:31
STIFF
SHARP|Revelation 1:16
EQUAL|Philippians 2:6
BROAD|Matthew 7:13
INNER|Ephesians 3:16
UPPER|Mark 14:15
ELDER|Luke 15:25
QUICK|2 Timothy 4:1
LEAST|Matthew 25:40
OUTER|Matthew 8:12
STILL|Psalms 46:10
FRAIL|Psalms 39:4
WISER
AMISS|James 4:3
STEEP|Matthew 8:32
WOVEN|John 19:23
ROYAL|1 Peter 2:9
FRESH
SLACK|2 Peter 3:9

# Numbers
SEVEN|Matthew 18:22
THREE|1 Corinthians 13:13
FORTY|Matthew 4:2
FIRST|Matthew 6:33
THIRD|1 Corinthians 15:4
TENTH
"""


def clean(raw: str) -> str:
    """Mirror KJVTextCleaner: drop {x: y} footnotes, keep {supplied} words, strip red-letter marks."""
    text = raw.replace("\ue000", "").replace("\ue001", "")
    text = re.sub(r"\{[^{}]*:[^{}]*\}", "", text)
    text = text.replace("{", "").replace("}", "")
    return re.sub(r"\s+", " ", text).strip()


def tokens(text: str) -> set[str]:
    # Same tokenization as WordleView.tokens5: split on anything that isn't A–Z.
    return set(re.findall(r"[A-Z]+", text.upper()))


def main() -> None:
    books = json.loads(KJV.read_text(encoding="utf-8-sig"))
    verses: dict[str, str] = {}          # "Book C:V" -> text
    first_occurrence: dict[str, str] = {}
    for book in books:
        name = book.get("name") or BOOK_NAMES[book["abbrev"].lower()]
        for c, chapter in enumerate(book["chapters"], start=1):
            for v, raw in enumerate(chapter, start=1):
                ref = f"{name} {c}:{v}"
                text = clean(raw)
                verses[ref] = text
                for token in tokens(text):
                    if len(token) == 5:
                        first_occurrence.setdefault(token, ref)

    entries, seen, problems = [], set(), []
    for line in CURATED.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        word, _, ref = (part.strip() for part in line.partition("|"))
        if word in seen:
            continue
        seen.add(word)
        if len(word) != 5 or word not in first_occurrence:
            problems.append(f"{word}: not found as a 5-letter word in the KJV — dropped")
            continue
        source = "hand-picked"
        if ref and ref not in verses:
            problems.append(f"{word}: reference {ref} doesn't exist — used first occurrence")
            ref = ""
        elif ref and word not in tokens(verses[ref]):
            problems.append(f"{word}: {ref} doesn't contain the word — used first occurrence")
            ref = ""
        if not ref:
            ref, source = first_occurrence[word], "auto (first occurrence)"
        entries.append({"word": word, "ref": ref, "source": source})

    hand = sum(e["source"] == "hand-picked" for e in entries)
    lines = [
        "# WORD answer list — review sheet",
        "",
        f"{len(entries)} words: {hand} with a hand-picked verse, {len(entries) - hand} using the word's first occurrence.",
        "Delete weak words and change verses in `make_word_game_words.py`, then re-run it.",
        "",
        "| Word | Reference | Verse source | Verse |",
        "| --- | --- | --- | --- |",
    ]
    for e in sorted(entries, key=lambda e: e["word"]):
        text = verses[e["ref"]].replace("|", "\\|")
        lines.append(f"| {e['word']} | {e['ref']} | {e['source']} | {text} |")
    OUT_REVIEW.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"{len(entries)} words written ({hand} hand-picked verses)")
    for p in problems:
        print("  -", p)


if __name__ == "__main__":
    main()
