#!/usr/bin/env python3
"""Builds `The Bible (iOS)/OriginalWords.sqlite`, the Hebrew and Greek words behind each verse.

The sources are STEPBible-Data (Tyndale House Cambridge, CC BY 4.0), kept unedited in
`Scripts/data/stepbible/` (see `Scripts/data/README.md`):

    TAHOT *.txt   Hebrew OT, one word per line
    TAGNT *.txt   Greek NT, one word per line
    TBESH / TBESG Brief lexicons (definitions) keyed by extended Strong's number
    TEHMC / TEGMC Expansions of the Hebrew and Greek morphology (grammar) codes
    TIPNR         Proper names: who each person is, and the places, with every verse

    python3 -I Scripts/build_original_words.py            # build and replace the bundled database
    python3 -I Scripts/build_original_words.py --check    # report only; writes nothing

Verse numbers are the KJV's, which the app keys everything by. TAHOT and TAGNT give the
English (NRSV) reference first and the Hebrew one in brackets, and the English numbering
matches the KJV, so the brackets are ignored. Two differences are handled here:

- Psalm titles are verse 0 in the source but part of verse 1 in the KJV, so their words
  are placed first in verse 1.
- Greek words carry which texts include them: N is the modern critical text and K is the
  text behind the KJV. A word in neither (only in "other" editions) is left out; `source`
  records N, K, or NK so the app can choose by translation. Hebrew words from the
  Leningrad text (L), the Qere (Q), and restored text (R) are kept; words added from the
  Greek (X) are not in the Hebrew Bible and are left out.

To keep the database small (about 20 MB, 8 MB compressed), it also:

- stores a search key beside each dictionary entry's lemma and transliteration, so the app can
  find an entry from "ἀγάπη", "agapē", or "agape";
- stores each distinct word once (`forms`) and each verse as a list of them (`words`);
- turns each word's grammar code into one English line ("Verb · Aorist Passive Indicative ·
  3rd Singular") using the expansion tables, and stores only those lines (`parses`);
- keeps, for each name in the Bible, who or what it is and how it's related (`names`), and
  links it to the verses it appears in by Strong's number (`name_verses`), because many
  people share a name and only the verse says which one is meant;
- strips punctuation from the ends of words and glosses ("λόγος," → "λόγος");
- reduces the Greek definitions to their English senses (no quoted Greek or Hebrew, Latin
  glosses, verse lists, or citations of other works) and cuts any definition over
  800 characters at a line break.

The build runs against a temporary file and replaces the bundled database only if it
succeeds. Coverage against `The Bible/KJVText.json` is printed, not enforced: it lists
KJV verses that have no words.
"""
import hashlib
import json
from collections import Counter
import pathlib
import re
import shutil
import sqlite3
import sys
import tempfile
import unicodedata

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCES = ROOT / "Scripts" / "data" / "stepbible"
KJV = ROOT / "The Bible" / "KJVText.json"
OUTPUT = ROOT / "The Bible (iOS)" / "OriginalWords.sqlite"

# The STEPBible abbreviations, in the KJV's book order.
ABBREVIATIONS = (
    "Gen Exo Lev Num Deu Jos Jdg Rut 1Sa 2Sa 1Ki 2Ki 1Ch 2Ch Ezr Neh Est Job Psa Pro Ecc Sng "
    "Isa Jer Lam Ezk Dan Hos Jol Amo Oba Jon Mic Nam Hab Zep Hag Zec Mal "
    "Mat Mrk Luk Jhn Act Rom 1Co 2Co Gal Eph Php Col 1Th 2Th 1Ti 2Ti Tit Phm Heb Jas 1Pe 2Pe "
    "1Jn 2Jn 3Jn Jud Rev"
).split()

# Group 1: book. 2: chapter. 3: verse. Then optional alternate numbering: "(heb ref)" in the
# Hebrew files; "[kjv chapter.verse]" in the Greek ones, where it is the KJV's number and
# the leading one is the Greek text's; "{where some editions place it}". Group 4: KJV
# chapter and 5: KJV verse from the brackets. 6: word number. 7: text type.
WORD_REF = re.compile(
    r"^(\w{3})\.(\d+)\.(\d+)(?:\[(\d+)\.(\d+)\])?(?:\{[^}]*\})?(?:\([^)]*\))?#(\d+)=(.+)$"
)
STRONGS = re.compile(r"[HG]\d{4}[A-Z]?")
# Cantillation marks, maqaf, and the verse-end and paseq signs clutter a word on a phone.
HEBREW_DISPLAY_STRIP = re.compile("[֑-֯־׀׃׆\\\\/]")
HTML_BREAK = re.compile(r"<\s*(?:br|lb)\s*/?\s*>", re.IGNORECASE)
HTML_TAG = re.compile(r"<[^>]+>")
SCRIPTURE_REFERENCE = re.compile(r"<ref=[^>]*>.*?</ref>", re.IGNORECASE | re.DOTALL)
# Punctuation the word files carry from the printed text ("λόγος," "Word."). It would make
# the same word look different and isn't part of it.
EDGE_PUNCTUATION = ",.;:?!·;—…"
# Longest definition kept, in characters. A few Greek entries run to several pages.
DEFINITION_LIMIT = 800


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_lines(path):
    # utf-8-sig: the Greek files start with a byte order mark. The names file has CRLF endings.
    return path.read_text(encoding="utf-8-sig").replace("\r", "").split("\n")


def trim_edges(text):
    return text.strip().strip(EDGE_PUNCTUATION + " ").strip()


# The apostrophe that marks a dropped vowel ("ἀλλ᾽") belongs to the word.
ELISION_MARKS = "’ʼ᾽"


def trim_word_edges(text):
    """A Greek word without the printed text's punctuation: the question mark (;), the raised dot
    (·), the paragraph sign (¶), brackets. Unicode has its own characters for the Greek ones, so
    this goes by category instead of a list."""
    def punctuation(character):
        return character not in ELISION_MARKS and (
            unicodedata.category(character).startswith("P") or character in "¶¬")

    start, end = 0, len(text)
    while start < end and punctuation(text[start]):
        start += 1
    while end > start and punctuation(text[end - 1]):
        end -= 1
    return text[start:end].strip()


def search_key(text):
    """What a word is matched on when someone types it: lowercase letters only, without accents,
    vowel points, or macrons, and with the Greek final sigma as an ordinary one. The app
    builds the same key from what is typed, so "ἀγάπη", "agapē", and "agape" all find G26."""
    decomposed = unicodedata.normalize("NFD", text.lower())
    letters = "".join(ch for ch in decomposed if unicodedata.category(ch)[0] == "L")
    return letters.replace("ς", "σ")


def hebrew_text(field):
    return re.sub(r"\s+", " ", HEBREW_DISPLAY_STRIP.sub("", field)).strip()


# Notes in the source's English that aren't part of the meaning: "{14.24}" marks a verse that
# some editions place elsewhere, and "¿" opens a question ("¿ not").
GLOSS_NOTES = re.compile(r"\{[^}]*\}|¿")


def hebrew_gloss(field):
    """'and/ <obj.>' → 'and (obj.)': the slashes mirror the Hebrew prefixes."""
    gloss = GLOSS_NOTES.sub("", field).replace("/", " ").replace("<", "(").replace(">", ")")
    return trim_edges(re.sub(r"\s+", " ", gloss))


# --- Greek definitions -----------------------------------------------------------------------
# The Greek lexicon (Abbott-Smith) is written for scholars: entries quote Greek phrases, Latin
# glosses, other works, and text-critical notes, and none of it reads without the Greek. The
# cleanup keeps the English meaning and drops the rest, clause by clause, so a sentence
# is either kept whole or removed rather than left with holes in it.

FOREIGN = re.compile("[Ͱ-Ͽἀ-῿֐-׿]")  # Greek and Hebrew letters
PARENTHETICAL = re.compile(r"\([^()]*\)|\[[^\[\]]*\]")
# Other works and scholars: what follows is commentary, not meaning.
COMMENTARY = re.compile(
    r"\b(reff?|Artt?|Cremer|Thayer|DB|DCG|MM|VGT|Exp|Deiss\w*|LAE|Dalman|Moulton|Lightfoot|Westcott|"
    r"Hort|Burkitt|Swete|Blass|Rutherford|Vulg|Syr\w*|Hatch|Field|Sanday|Kennedy|Selwyn|Mayor|"
    r"Ellicott|Lft|WM|Moult|Winer|Hdt|Xen|Plat|Thuc|Polyb|Jos|Philo|Epict|Plut|Syll|om|mg)\b"
)
VERSE_NUMBER = re.compile(r"\b\d{1,3}:\d{1,3}(?:[-–]\d+)?\b|\bvv?\.\s*\d+")
BOOK_CITATION = re.compile(r"\b(?:[1-3]\s?)?[A-Z][a-z]{1,4}\.?\s+\d+(?::\d+)?\b")
BOOK_ABBREVIATION = re.compile(
    r"(?<![A-Za-z])(?:[1-3]\s?)?(Mat|Mt|Mrk|Mk|Luk|Lk|Jhn|Act|Rom|Co|Gal|Eph|Php|Phil|Col|Th|Ti|Tit|"
    r"Phm|Heb|Jas|Pe|Jn|Jud|Rev|Gen|Exo|Lev|Num|Deu|Psa|Isa|Jer|Eze|Dan|Hos|Mic|Zec)\.?(?![A-Za-z])"
)
# What the verse references leave behind once they are removed ("enter: , , al.").
STRAY_ABBREVIATION = re.compile(r"(?<![A-Za-z])(al|ff|sq|sqq|ibid|etc|q\.v|l\.c|ll|cc|cf|sc)\.(?!\w)", re.IGNORECASE)
# Text-critical sigla ("a reason, cause WH, mg., R, mg.") and everything after them.
SIGLA_TAIL = re.compile(r"[\s,]+\b(WH|Rec|Treg|TR?|RV|AV|R)\b[\s,.].*$|[\s,]+\b(WH|Rec|Treg|TR?|RV|AV)\b$")
FOREIGN_RUN = re.compile(r"[\s,:;]*(?:[^\s,;:()]*[Ͱ-Ͽἀ-῿֐-׿][^\s,;:()]*[\s,:;]*)+")
# A clause that ends on one of these had its object cut out ("before εἰς" → "before").
DANGLING_END = re.compile(
    r"\b(before|with|of|in|to|by|for|from|and|or|the|a|an|on|at|as|after|into|upon|against|like|are|is|"
    r"adv|prep|cf|see|also|esp|e\.g|i\.e)\.?:?$",
    re.IGNORECASE,
)
LEFTOVER_MARKS = re.compile(r"[*=]|^in (?:OT|NT|LXX)\b", re.IGNORECASE)
SENSE_MARKER = re.compile(r"^(__)?([IVX]+\.|\d+\.|\([a-z]\)|[a-z]\))?\s*")


def english_words(text):
    return [word for word in re.findall(r"[A-Za-z][A-Za-z'’-]*", FOREIGN.sub(" ", text)) if len(word) > 1]


def foreign_ratio(text):
    letters = re.findall(r"[^\W\d_]", text)
    return len(FOREIGN.findall(text)) / len(letters) if letters else 0


def drop_citations(text):
    """Removes parentheses and brackets that hold Greek or Hebrew, scholarly notes, numbers, or
    only author abbreviations ("Plat., Xen., al."). Repeats so nested ones go too."""
    def keep(match):
        inner = match.group(0)
        if FOREIGN.search(inner) or COMMENTARY.search(inner) or re.search(r"\bLXX\b|\d", inner):
            return ""
        words = re.findall(r"[^\s,;()\[\]]+", inner)
        if (words and any(word.endswith(".") for word in words)
                and all(re.fullmatch(r"[A-ZÆŒ][\wæœ]*\.?|al\.|etc\.|ib\.|cf\.", word) for word in words)):
            return ""
        return inner

    previous = None
    while previous != text:
        previous, text = text, PARENTHETICAL.sub(keep, text)
    return text


def tidy_punctuation(text):
    if text.count('"') % 2:  # a quotation whose other half was cut
        text = text.replace('"', "")
    text = re.sub(r"\s+", " ", text)
    text = re.sub(r"\s+([,.;:)])", r"\1", text)
    text = re.sub(r"([(\[])\s+", r"\1", text)
    text = re.sub(r"[,;:]\s*(?=[,;:])", "", text)
    text = re.sub(r"\.{2,}", ".", text)
    text = re.sub(r"\(\s*[,.;:\s]*\)|\[\s*[,.;:\s]*\]", "", text)
    text = re.sub(r"[,;:]+\s*\.", ".", text)
    text = re.sub(r"\s+([,.;:)])", r"\1", text)
    return text.strip(" ,;:-–—")


def clean_greek_clause(clause):
    """The clause with its citations and Greek removed, or "" when too little English is left."""
    original = tidy_punctuation(clause)
    clause = SIGLA_TAIL.sub("", clause)
    clause = re.sub(r",?\s*\bLat\.\s.*$", "", clause)  # "Lat. oratio, sermo, …"
    clause = drop_citations(clause)
    clause = VERSE_NUMBER.sub("", clause)
    clause = BOOK_CITATION.sub("", clause)
    if COMMENTARY.search(clause):
        return ""
    clause = re.sub(r"\b\d+[a-z]{0,2}\b", "", clause)
    clause = STRAY_ABBREVIATION.sub("", clause)
    clause = BOOK_ABBREVIATION.sub("", clause)
    clause = re.sub(r",\s*al(?=[;.,]|$)", "", clause)
    clause = FOREIGN_RUN.sub(" ", clause) if FOREIGN.search(clause) else clause
    clause = tidy_punctuation(clause)
    if clause == original:
        return clause  # nothing was taken out
    # Something was cut, so keep what is left only if it still says something: a couple of words
    # ("a reason, cause"), not a dangling preposition or a leftover mark ("in OT, *", "= (which see)").
    if len(english_words(clause)) < 2 or DANGLING_END.search(clause) or LEFTOVER_MARKS.search(clause):
        return ""
    return clause


def greek_definition(text):
    """An Abbott-Smith entry reduced to its English senses, keeping the numbered outline."""
    kept = []
    for index, line in enumerate(text.split("\n")):
        line = line.strip()
        if not line or line.startswith("SYN"):  # SYN. compares Greek words
            continue
        marker = SENSE_MARKER.match(line)
        prefix = marker.group(0).strip()
        body = re.sub(r"\[[^\]]*LXX[^\]]*\]", "", line[marker.end():])  # which Hebrew words it translates
        if body.strip() in ("", "(AS)", "]"):
            continue
        if index == 0 and foreign_ratio(body) > 0:
            # The headword line. The card already shows the word, so keep only an English remark
            # in parentheses ("variant form of …").
            remarks = [clean_greek_clause(m.group(0)[1:-1]) for m in re.finditer(r"\([^()]*\)", body)
                       if not FOREIGN.search(m.group(0)) and not re.search(r"\d|\bsee\b", m.group(0))]
            remarks = [remark for remark in remarks if len(english_words(remark)) >= 3]
            if remarks:
                kept.append("; ".join(remarks))
            continue
        body = drop_citations(body)
        body = re.sub(r"^\s*[\]\[]\s*|\s*[\]\[]\s*$", "", body)  # a bracket whose other half was cut
        clauses = [clean_greek_clause(part) for part in re.split(r";\s*|(?<=[a-z)])\.\s+(?=[A-Z])", body)]
        clauses = [clause for clause in clauses if clause]
        if clauses:
            kept.append((prefix + " " if prefix else "") + "; ".join(clauses))
    return "\n".join(kept)


def plain_definition(raw, language):
    """The lexicon's HTML-ish markup as plain text with line breaks, shortened for a phone.

    Greek entries (Abbott-Smith) are cleaned down to their English senses: see `greek_definition`.
    The Hebrew entries are mostly plain English and mention verses only in running text
    ("first mentioned at 1Ki.7.13"), so they are kept as they are. Some entries end up empty;
    the app then shows only the entry's short gloss.
    """
    text = HTML_BREAK.sub("\n", raw)
    if language == "greek":
        text = SCRIPTURE_REFERENCE.sub("", text).replace("†", "")
    text = HTML_TAG.sub("", text)  # <b> and <i> keep their text
    if language == "greek":
        text = greek_definition(text)
    lines = [re.sub(r"[ \t]+", " ", line).strip(" ,;:") for line in text.split("\n")]
    text = "\n".join(line for line in lines if line)
    # Abbott-Smith marks its outline with underscores ("__1.", "__(a)"); the numbers are enough.
    text = re.sub(r"(?<![\w_])_{2,}\s*", "", text)
    return shorten(text)


def shorten(text):
    """Cuts a long definition at a line (or else word) boundary under DEFINITION_LIMIT."""
    if len(text) <= DEFINITION_LIMIT:
        return text
    cut = text.rfind("\n", 0, DEFINITION_LIMIT)
    if cut < DEFINITION_LIMIT // 3:
        cut = text.rfind(" ", 0, DEFINITION_LIMIT)
    return text[:cut].rstrip(" ,;:") + "…"


def kjv_structure():
    """[(name, {chapter: verse count})] in the KJV's order."""
    books = json.loads(KJV.read_text(encoding="utf-8"))
    return [
        (book["name"], {number: len(verses) for number, verses in enumerate(book["chapters"], 1)})
        for book in books
    ]


def parse_hebrew(paths, names, problems):
    words = []
    for path in paths:
        for line_number, line in enumerate(read_lines(path), 1):
            fields = line.split("\t")
            match = WORD_REF.match(fields[0])
            if not match or len(fields) < 5:
                continue
            abbreviation, chapter, verse, kjv_chapter, kjv_verse, number, text_type = match.groups()
            chapter, verse = kjv_chapter or chapter, kjv_verse or verse
            if abbreviation not in names:
                problems.append(f"{path.name}:{line_number}: unknown book {abbreviation!r}")
                continue
            if text_type[0] not in "LQR":
                continue
            roots = re.findall(r"\{([^}]+)\}", fields[4])
            root = STRONGS.match(roots[0]) if roots else None
            words.append({
                "book": names[abbreviation], "chapter": int(chapter), "verse": int(verse),
                "number": int(number), "original": hebrew_text(fields[1]),
                "translit": fields[2].replace("/", "").replace("\\", ""),
                "gloss": hebrew_gloss(fields[3]), "strongs": root.group(0) if root else None,
                "source": text_type[0],
                "codes": hebrew_root_code(fields[4], fields[5] if len(fields) > 5 else ""),
            })
    return words


def parse_greek(paths, names, problems):
    words = []
    for path in paths:
        for line_number, line in enumerate(read_lines(path), 1):
            fields = line.split("\t")
            match = WORD_REF.match(fields[0])
            if not match or len(fields) < 5:
                continue
            abbreviation, chapter, verse, kjv_chapter, kjv_verse, number, text_type = match.groups()
            chapter, verse = kjv_chapter or chapter, kjv_verse or verse
            if abbreviation not in names:
                problems.append(f"{path.name}:{line_number}: unknown book {abbreviation!r}")
                continue
            # Capital N or K: the word is in the critical text or the KJV's text.
            source = "".join(letter for letter in "NK" if letter in text_type)
            if not source:
                continue
            greek = re.match(r"^(.*?)\s*\(([^)]*)\)\s*$", fields[1])
            strongs = fields[3].partition("=")[0]
            root = STRONGS.match(strongs)
            words.append({
                "book": names[abbreviation], "chapter": int(chapter), "verse": int(verse),
                "number": int(number), "original": trim_word_edges(greek.group(1) if greek else fields[1]),
                "translit": greek.group(2) if greek else "",
                "gloss": hebrew_gloss(fields[2].replace("/", "")),
                "strongs": root.group(0) if root else None, "source": source,
                "codes": greek_codes(fields[3]),
            })
    return words


def parse_lexicon(path, language):
    """{strongs: row} keyed by the disambiguated Strong's number the word files use.

    That is the first word of the second column ("H0430G = a Name of"). The third column is
    the entry a name or variant points to, so it can't be the key.
    """
    entries = {}
    for line in read_lines(path):
        fields = line.split("\t")
        key_match = STRONGS.match(fields[1].strip()) if len(fields) > 1 else None
        if len(fields) < 8 or not key_match:
            continue
        key = key_match.group(0)
        entries.setdefault(key, (
            key, language, fields[3].strip(), fields[4].strip(),
            fields[6].strip(), plain_definition("\t".join(fields[7:]), language),
        ))
    return entries


# --- Grammar ---------------------------------------------------------------------------------
# Each word has a morphology code ("V-API-3S", "HVqp3ms"). STEPBible's TEGMC and TEHMC tables
# expand every code into pairs ("Function=Verb; Tense=Aorist; …"), which this turns into one
# short line. Only the word's own element is described; a Hebrew prefix ("and", "the") is
# already in its gloss.

# The pairs, read in this order, make the line: the function, then what the word does or is
# (stem, tense, voice, mood, form), then who or what it applies to. Greek reads case, person,
# number, gender; Hebrew person, gender, number, state.
MORPHOLOGY_WHAT = ("Extra", "Stem", "Tense", "Voice", "Mood", "Form")
MORPHOLOGY_WHO = {
    "greek": ("Case", "Person", "Number", "Gender"),
    "hebrew": ("Person", "Gender", "Number", "State"),
}
HENCE = re.compile(r"\s*\(hence [^)]*\)")


def morphology_pairs(text):
    """[(key, value)] from "Function=Verb; Stem=Qal (hence Action=Simple; Voice=Active)".

    The parentheses hold explanations with semicolons of their own, so split outside them."""
    parts, depth, current = [], 0, ""
    for character in text:
        depth += (character == "(") - (character == ")")
        if character == ";" and depth == 0:
            parts.append(current)
            current = ""
        else:
            current += character
    parts.append(current)
    pairs = []
    for part in parts:
        key, separator, value = part.partition("=")
        if separator:
            pairs.append((key.strip(), HENCE.sub("", value).strip()))
    return pairs


def morphology_line(expansion, language):
    """One readable line for a code's expansion: "Verb · Aorist Passive Indicative · 3rd Singular"."""
    values = {}
    for key, value in morphology_pairs(expansion):
        if value:
            values.setdefault(key, value)
    segments = [values.get("Function", "")]
    segments.append(" ".join(values[key] for key in MORPHOLOGY_WHAT if key in values))
    who = [values[key] for key in MORPHOLOGY_WHO[language] if key in values]
    if "Name type" in values:
        who.append(f"{values['Name type']} name")
    segments.append(" ".join(who))
    return " · ".join(segment for segment in segments if segment)


def parse_morphology_table(path):
    """{code: expansion} from a TEGMC or TEHMC file (the codes used in the tagged texts)."""
    codes = {}
    for line in read_lines(path):
        cells = line.split("\t")
        if len(cells) >= 2 and re.fullmatch(r"[A-Za-z][A-Za-z0-9\-]*", cells[0].strip()) and "=" in cells[1]:
            codes.setdefault(cells[0].strip(), cells[1].strip())
    return codes


def hebrew_root_code(strongs_field, grammar_field):
    """The grammar code of a Hebrew word's root, as a tuple of one code, or ().

    "H9003/{H7225G}" and "HR/Ncfsa" line up element by element (a prefix, the root in braces).
    The first element's letter says the language (H Hebrew, A Aramaic) and is left off the
    rest, so it is put back to find them in the table."""
    elements, grammar = strongs_field.split("/"), grammar_field.split("/")
    if not grammar or not grammar[0]:
        return ()
    for index, element in enumerate(elements):
        if "{" in element and index < len(grammar) and grammar[index]:
            return (grammar[index] if index == 0 else grammar[0][0] + grammar[index],)
    return ()


def greek_codes(field):
    """The grammar codes of a Greek word: "G2424G=N-GSM-P" → ("N-GSM-P",). Two words written as
    one ("G1473=P-1NS + G2532=CONJ") give both."""
    codes = []
    for part in field.split("+"):
        _, separator, code = part.partition("=")
        if separator and code.strip():
            codes.append(code.strip())
    return tuple(codes)


def describe_codes(codes, table, language):
    """The line for a word's codes, joined with " + " for a word made of two; None if unknown."""
    lines = [morphology_line(table[code], language) for code in codes if code in table]
    return " + ".join(lines) if lines and len(lines) == len(codes) else None


# --- Names -----------------------------------------------------------------------------------
# TIPNR lists every proper name with a unique identity for each individual: Aaron the priest
# is not Aaron the name of someone else. A record is a "$========== PERSON(s)" line, a line
# of facts, and then one line per spelling (Hebrew, Greek, Aramaic) with its Strong's number
# and every verse. The same name and Strong's number can belong to several records (there are
# dozens of Zechariahs), so a verse is what says which one.

NAME_MARKERS = re.compile(r"\((?:d|a|f|\?)\)|_\d+|=[HG]\d{4}[A-Z]?|@\S*")
NAME_REFERENCE = re.compile(r"^([1-3A-Za-z]{3})\.(\d+)\.(\d+)[a-z]?$")


def plain_name(text):
    """"Amram@Exo.6.18-1Ch" → "Amram"; "Etam_2" → "Etam"."""
    return NAME_MARKERS.sub("", text).strip(" ,+-|>")


def relatives(text, joiner=", "):
    """A list of related names ("Moses@Exo.2.10-Rev, Miriam@Exo.15.20-Mic") as plain names."""
    names = [plain_name(token) for token in re.split(r"\s*[,+]\s*", text)]
    return joiner.join(name for name in names if name)


def parse_names(path, book_numbers, resolve, problems):
    """([name rows], [(strongs, book, chapter, verse, name id)]) from the TIPNR file."""
    lines = read_lines(path)
    records, links, seen = [], [], set()
    index = 0
    while index < len(lines):
        if not lines[index].startswith("$========== "):
            index += 1
            continue
        top = (lines[index + 1] if index + 1 < len(lines) else "").split("\t")
        cursor = index + 2
        spellings = []
        while cursor < len(lines) and lines[cursor].startswith("– "):
            spellings.append(lines[cursor].split("\t"))
            cursor += 1
        index = cursor
        if len(top) < 9 or "@" not in top[0]:
            continue

        cells = [cell.strip() for cell in top]
        kind = cells[8]
        is_place = kind == "Place"
        area = "" if cells[6] in ("", ">") else cells[6]
        name_id = len(records) + 1
        record_name = plain_name(cells[0].split("@")[0])
        records.append((
            name_id, record_name, kind,
            "" if is_place else cells[1],
            "" if is_place else relatives(cells[2], " and "),
            "" if is_place else relatives(cells[3]),
            "" if is_place else relatives(cells[4]),
            "" if is_place else relatives(cells[5]),
            area,
        ))
        # "– Group" lines are the people descended from this person (the Jews under Judah, the
        # Israelites under Israel) or who live in this place. They are not the individual, so each
        # group gets a card of its own, named by the alias ("Jews|Judah") or else the record.
        # Other spellings under the same alias ("Jews" in Aramaic, "Jewish") belong to it too.
        group_aliases = {
            plain_name(spelling[1].split("|")[0])
            for spelling in spellings
            if spelling[0].strip() == "– Group" and "|" in spelling[1]
        }
        groups = {}
        for spelling in spellings:
            label = spelling[0].strip()
            if label.startswith("– Total") or len(spelling) < 5:
                continue
            strongs = re.match(r"^([HG]\d{4}[A-Z]?)«", spelling[2].strip())
            if not strongs:
                continue
            alias = plain_name(spelling[1].split("|")[0]) if "|" in spelling[1] else ""
            target = name_id
            if label == "– Group" or (alias and alias in group_aliases):
                group_name = alias or record_name
                if group_name not in groups:
                    groups[group_name] = len(records) + 1
                    records.append((
                        groups[group_name], group_name, "Group",
                        f"People of {record_name}" if is_place else f"People descended from {record_name}",
                        "", "", "", "", "",
                    ))
                target = groups[group_name]
            for reference in re.split(r"[;,]\s*", spelling[4]):
                match = NAME_REFERENCE.match(reference.strip())
                if not match or match.group(1) not in book_numbers:
                    continue
                verse = max(int(match.group(3)), 1)  # verse 0 is a Psalm title, part of verse 1
                link = (resolve(strongs.group(1)), book_numbers[match.group(1)], int(match.group(2)), verse, target)
                if link not in seen:
                    seen.add(link)
                    links.append(link)
    return records, links


def fold_psalm_titles(words):
    """Moves verse 0 (a Psalm title) to the front of verse 1, where the KJV prints it."""
    folded = []
    for word in words:
        if word["verse"] == 0:
            # Word numbers restart at 1 in each verse; subtracting 1000 sorts title words first.
            word = {**word, "verse": 1, "number": word["number"] - 1000}
        folded.append(word)
    return folded


SCHEMA = """
-- A verse's words, in order. `book` is the 1-based index in the KJV's book order.
CREATE TABLE words (
    book INTEGER NOT NULL,
    chapter INTEGER NOT NULL,
    verse INTEGER NOT NULL,
    position INTEGER NOT NULL,
    form INTEGER NOT NULL REFERENCES forms(id),
    PRIMARY KEY (book, chapter, verse, position)
) WITHOUT ROWID;
-- Each distinct word as it appears (many of the 445,000 words repeat), most common first.
-- `source` is N, K, or NK for Greek (see the build script) and L, Q, or R for Hebrew.
CREATE TABLE forms (
    id INTEGER PRIMARY KEY,
    original TEXT NOT NULL,
    translit TEXT NOT NULL,
    gloss TEXT NOT NULL,
    strongs TEXT,
    source TEXT NOT NULL,
    parse INTEGER REFERENCES parses(id)
);
-- A word's grammar as one English line, shared by every word with the same parse.
CREATE TABLE parses (id INTEGER PRIMARY KEY, description TEXT NOT NULL);
-- Who or what a name is. `kind` is the source's type: Male, Female, Group, Place, and so on.
CREATE TABLE names (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    kind TEXT NOT NULL,
    description TEXT NOT NULL,
    parents TEXT NOT NULL,
    siblings TEXT NOT NULL,
    partners TEXT NOT NULL,
    offspring TEXT NOT NULL,
    area TEXT NOT NULL
);
-- The verses a name's Strong's number refers to this individual in.
CREATE TABLE name_verses (
    strongs TEXT NOT NULL,
    book INTEGER NOT NULL,
    chapter INTEGER NOT NULL,
    verse INTEGER NOT NULL,
    name INTEGER NOT NULL REFERENCES names(id),
    PRIMARY KEY (strongs, book, chapter, verse, name)
) WITHOUT ROWID;
CREATE TABLE lexicon (
    strongs TEXT PRIMARY KEY,
    language TEXT NOT NULL,
    lemma TEXT NOT NULL,
    translit TEXT NOT NULL,
    gloss TEXT NOT NULL,
    definition TEXT NOT NULL,
    lemma_key TEXT NOT NULL,
    translit_key TEXT NOT NULL
) WITHOUT ROWID;
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL) WITHOUT ROWID;
"""


def main():
    check_only = "--check" in sys.argv
    kjv = kjv_structure()
    if len(kjv) != len(ABBREVIATIONS):
        sys.exit(f"The KJV has {len(kjv)} books; expected {len(ABBREVIATIONS)}.")
    names = {abbreviation: name for abbreviation, (name, _) in zip(ABBREVIATIONS, kjv)}

    hebrew_paths = sorted(SOURCES.glob("TAHOT*.txt"))
    greek_paths = sorted(SOURCES.glob("TAGNT*.txt"))
    lexicon_paths = {"hebrew": next(iter(SOURCES.glob("TBESH*.txt")), None),
                     "greek": next(iter(SOURCES.glob("TBESG*.txt")), None)}
    grammar_paths = {"hebrew": next(iter(SOURCES.glob("TEHMC*.txt")), None),
                     "greek": next(iter(SOURCES.glob("TEGMC*.txt")), None)}
    names_path = next(iter(SOURCES.glob("TIPNR*.txt")), None)
    if (len(hebrew_paths) != 4 or len(greek_paths) != 2 or not all(lexicon_paths.values())
            or not all(grammar_paths.values()) or not names_path):
        sys.exit(
            f"Expected 4 TAHOT, 2 TAGNT, TBESH, TBESG, TEHMC, TEGMC, and TIPNR files in "
            f"{SOURCES.relative_to(ROOT)}.\n"
            "They are not in git; Scripts/data/README.md says where to download them."
        )

    problems = []
    hebrew = fold_psalm_titles(parse_hebrew(hebrew_paths, names, problems))
    greek = parse_greek(greek_paths, names, problems)
    if problems:
        print("\n".join(problems[:50]))
        sys.exit(1)

    words = hebrew + greek
    lexicon = {}
    for language, path in lexicon_paths.items():
        lexicon.update(parse_lexicon(path, language))

    # A word file's suffix (G3700G) sometimes differs from the lexicon's (G3700), or a number
    # has only lettered entries (G0256 → G0256G). Point such words at the nearest entry so
    # the app's lookup is a plain match. Anything still unmatched is reported below.
    def resolve(key):
        if key is None or key in lexicon:
            return key
        for candidate in (key[:5], *sorted(k for k in lexicon if k.startswith(key[:5]))):
            if candidate in lexicon:
                return candidate
        return key

    for word in words:
        word["strongs"] = resolve(word["strongs"])

    # Each word's grammar as a line of English, from the expansion tables.
    tables = {language: parse_morphology_table(path) for language, path in grammar_paths.items()}
    for word in hebrew:
        word["parse"] = describe_codes(word["codes"], tables["hebrew"], "hebrew")
    for word in greek:
        word["parse"] = describe_codes(word["codes"], tables["greek"], "greek")

    # A word's position is its order within the verse. Words are unique by (verse, number).
    seen, rows = set(), []
    book_order = {name: index for index, (name, _) in enumerate(kjv)}
    words.sort(key=lambda w: (book_order[w["book"]], w["chapter"], w["verse"], w["number"]))
    position = 0
    previous = None
    for word in words:
        verse_key = (word["book"], word["chapter"], word["verse"])
        position = position + 1 if verse_key == previous else 1
        previous = verse_key
        if (*verse_key, position) in seen:
            sys.exit(f"Duplicate word at {verse_key} position {position}.")
        seen.add((*verse_key, position))
        rows.append((*verse_key, position, word["original"], word["translit"], word["gloss"],
                     word["strongs"], word["source"], word["parse"]))

    # Report: KJV verses with no words, and words for verses the KJV doesn't have.
    covered = {(r[0], r[1], r[2]) for r in rows}
    missing = [f"{name} {chapter}:{verse}"
               for name, chapters in kjv for chapter, count in chapters.items()
               for verse in range(1, count + 1) if (name, chapter, verse) not in covered]
    kjv_verses = {(name, chapter, verse)
                  for name, chapters in kjv for chapter, count in chapters.items()
                  for verse in range(1, count + 1)}
    extra = sorted(covered - kjv_verses)
    unknown = sorted({r[7] for r in rows if r[7] and r[7] not in lexicon})
    unused = {r[7] for r in rows if r[7]}
    used_lexicon = [entry for key, entry in sorted(lexicon.items()) if key in unused]

    book_numbers = {abbreviation: number for number, abbreviation in enumerate(ABBREVIATIONS, 1)}
    name_rows, name_links = parse_names(names_path, book_numbers, resolve, problems)
    if problems:
        print("\n".join(problems[:50]))
        sys.exit(1)
    # How well the names line up with the words: a link is useful when the verse has a word
    # with that Strong's number.
    strongs_by_verse = {}
    for row in rows:
        if row[7]:
            strongs_by_verse.setdefault((book_order[row[0]] + 1, row[1], row[2]), set()).add(row[7])
    matched = sum(1 for strongs, book, chapter, verse, _ in name_links
                  if strongs in strongs_by_verse.get((book, chapter, verse), ()))

    print(f"{len(hebrew)} Hebrew and {len(greek)} Greek words in {len(covered)} verses.")
    print(f"{len(used_lexicon)} lexicon entries used; {len(unknown)} Strong's numbers have no entry"
          + (f": {', '.join(unknown[:20])}" if unknown else "."))
    print(f"{len(missing)} KJV verses have no words" + (f": {', '.join(missing[:40])}" if missing else "."))
    if len(missing) > 40:
        print(f"  … and {len(missing) - 40} more")
    print(f"{len(extra)} verses with words aren't in the KJV" + (f": {extra[:20]}" if extra else "."))
    for language, group in (("Hebrew", hebrew), ("Greek", greek)):
        described = sum(1 for word in group if word["parse"])
        print(f"{described:,} of {len(group):,} {language} words have a grammar line"
              + ("." if described == len(group) else f"; {len(group) - described:,} don't."))
    print(f"{len(name_rows):,} names ({sum(1 for r in name_rows if r[2] == 'Place'):,} places) with "
          f"{len(name_links):,} verse links; {matched:,} of the links land on a word with that "
          f"Strong's number ({100 * matched / max(len(name_links), 1):.0f}%).")
    if check_only:
        print("Nothing written.")
        return

    meta = {
        "attribution": "Data from STEPBible.org and Tyndale House Cambridge, CC BY 4.0 "
                       "(https://github.com/STEPBible/STEPBible-Data).",
        **{path.name: sha256(path) for path in [
            *hebrew_paths, *greek_paths, *lexicon_paths.values(), *grammar_paths.values(), names_path,
        ]},
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as folder:
        temporary = pathlib.Path(folder) / "OriginalWords.sqlite"
        database = sqlite3.connect(temporary)
        database.executescript(SCHEMA)
        forms = Counter(row[4:] for row in rows)
        form_ids = {form: number for number, (form, _) in enumerate(forms.most_common(), 1)}
        parse_counts = Counter(row[9] for row in rows if row[9])
        parse_ids = {text: number for number, (text, _) in enumerate(parse_counts.most_common(), 1)}
        database.executemany("INSERT INTO parses VALUES (?,?)",
                             [(number, text) for text, number in parse_ids.items()])
        database.executemany("INSERT INTO forms VALUES (?,?,?,?,?,?,?)",
                             [(number, *form[:5], parse_ids.get(form[5])) for form, number in form_ids.items()])
        database.executemany("INSERT INTO names VALUES (?,?,?,?,?,?,?,?,?)", name_rows)
        database.executemany("INSERT INTO name_verses VALUES (?,?,?,?,?)", name_links)
        database.executemany("INSERT INTO words VALUES (?,?,?,?,?)",
                             [(book_order[row[0]] + 1, *row[1:4], form_ids[row[4:]]) for row in rows])
        database.executemany(
            "INSERT INTO lexicon VALUES (?,?,?,?,?,?,?,?)",
            [(*entry, search_key(entry[2]), search_key(entry[3])) for entry in used_lexicon],
        )
        database.executemany("INSERT INTO meta VALUES (?,?)", sorted(meta.items()))
        database.commit()
        database.execute("VACUUM")
        database.close()
        # The temporary folder may be on another volume, so move rather than rename.
        shutil.move(str(temporary), OUTPUT)
    print(f"Wrote {len(rows)} words to {OUTPUT.relative_to(ROOT)} ({OUTPUT.stat().st_size:,} bytes).")


if __name__ == "__main__":
    main()
