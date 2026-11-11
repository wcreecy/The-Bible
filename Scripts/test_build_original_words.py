#!/usr/bin/env python3
"""Tests for `build_original_words.py`: the rules that turn STEPBible's files into the Word Study
database. Run them after changing the script:

    python3 -I Scripts/test_build_original_words.py

The inputs are small made-up examples in the sources' format, so the tests need none of the
downloaded data and don't copy it. The last test checks every real Greek definition when the
source files are in `Scripts/data/stepbible/`, and is skipped when they aren't.
"""
import importlib.util
import pathlib
import re
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parent / "build_original_words.py"
_spec = importlib.util.spec_from_file_location("build_original_words", SCRIPT)
bow = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(bow)

# An entry's first line is its headword, which the cleanup treats separately.
HEADWORD = "εἰσ-έρχομαι,\n"
FOREIGN = re.compile("[Ͱ-Ͽἀ-῿֐-׿]")


class SearchKeyTests(unittest.TestCase):
    def test_the_same_word_in_every_spelling_has_one_key(self):
        self.assertEqual(bow.search_key("ἀγάπη"), "αγαπη")
        self.assertEqual(bow.search_key("agapē"), "agape")
        self.assertEqual(bow.search_key("AGAPE"), "agape")

    def test_final_sigma_is_an_ordinary_sigma(self):
        self.assertEqual(bow.search_key("λόγος"), "λογοσ")
        self.assertEqual(bow.search_key("Ἰησοῦς"), "ιησουσ")

    def test_hebrew_loses_its_vowel_points_and_transliteration_its_dots(self):
        self.assertEqual(bow.search_key("אֱלֹהִים"), "אלהים")
        self.assertEqual(bow.search_key("e.lo.him"), "elohim")


class GlossTests(unittest.TestCase):
    def test_prefix_slashes_become_spaces_and_angle_brackets_parentheses(self):
        self.assertEqual(bow.hebrew_gloss("and/ <obj.>"), "and (obj.)")
        self.assertEqual(bow.hebrew_gloss("[the]/ heavens,"), "[the] heavens")

    def test_the_sources_notes_are_not_part_of_the_meaning(self):
        self.assertEqual(bow.hebrew_gloss("¿ not"), "not")
        self.assertEqual(bow.hebrew_gloss("{14.24}/ To Him"), "To Him")


class WordEdgeTests(unittest.TestCase):
    def test_greek_punctuation_is_removed_by_category(self):
        for printed, word in [
            ("αὐτοῖς·", "αὐτοῖς"),   # raised dot, U+0387
            ("ὑμῶν;", "ὑμῶν"),       # Greek question mark, U+037E
            ("αὐτόν.¶", "αὐτόν"),    # paragraph sign
            ("[Κύριε]", "Κύριε"),
        ]:
            self.assertEqual(bow.trim_word_edges(printed), word)

    def test_the_apostrophe_of_a_dropped_vowel_stays(self):
        self.assertEqual(bow.trim_word_edges("ἀλλ᾽"), "ἀλλ᾽")


class MorphologyTests(unittest.TestCase):
    def test_a_greek_verb(self):
        line = bow.morphology_line(
            "Function=Verb; Tense=Aorist; Voice=Passive; Mood=Indicative; Person=3rd; Number=Singular",
            "greek",
        )
        self.assertEqual(line, "Verb · Aorist Passive Indicative · 3rd Singular")

    def test_a_hebrew_verb_drops_the_explanations_in_parentheses(self):
        line = bow.morphology_line(
            "Function=Verb ; Stem=Qal (hence Action=Simple; Voice=Active); "
            "Form=Perfect (hence Tense=Past/present; Mood=Indicative); "
            "Person=Third; Gender=Masculine; Number=Singular",
            "hebrew",
        )
        self.assertEqual(line, "Verb · Qal Perfect · Third Masculine Singular")

    def test_a_name_says_what_kind(self):
        line = bow.morphology_line(
            "Function=Noun; Case=Genitive; Number=Singular; Gender=Masculine; Name type=Individual",
            "greek",
        )
        self.assertEqual(line, "Noun · Genitive Singular Masculine Individual name")

    def test_the_root_of_a_hebrew_word_is_found_among_its_prefixes(self):
        self.assertEqual(bow.hebrew_root_code("H9003/{H7225G}", "HR/Ncfsa"), ("HNcfsa",))
        self.assertEqual(bow.hebrew_root_code("{H1254A}", "HVqp3ms"), ("HVqp3ms",))

    def test_aramaic_keeps_its_own_language_letter(self):
        self.assertEqual(bow.hebrew_root_code("{H0001}", "ANpm"), ("ANpm",))
        self.assertEqual(bow.hebrew_root_code("H9003/{H0001}", "AR/Npm"), ("ANpm",))

    def test_a_word_with_no_root_has_no_code(self):
        self.assertEqual(bow.hebrew_root_code("", ""), ())

    def test_two_words_written_as_one_give_both_codes(self):
        self.assertEqual(bow.greek_codes("G1473=P-1NS + G2532=CONJ"), ("P-1NS", "CONJ"))
        self.assertEqual(bow.greek_codes("G2424G=N-GSM-P"), ("N-GSM-P",))

    def test_a_code_missing_from_the_table_gives_no_line(self):
        table = {"CONJ": "Function=Conjunction"}
        self.assertEqual(bow.describe_codes(("CONJ",), table, "greek"), "Conjunction")
        self.assertIsNone(bow.describe_codes(("CONJ", "XX"), table, "greek"))


class NameTests(unittest.TestCase):
    def test_markers_and_references_are_removed_from_a_name(self):
        self.assertEqual(bow.plain_name("Amram@Exo.6.18-1Ch"), "Amram")
        self.assertEqual(bow.plain_name("Etam_2"), "Etam")

    def test_relatives_become_a_list_of_plain_names(self):
        self.assertEqual(bow.relatives("Moses@Exo.2.10-Rev, Miriam@Exo.15.20-Mic"), "Moses, Miriam")
        self.assertEqual(
            bow.relatives("Amram@Exo.6.18-1Ch + Jochebed@Exo.6.20-Num", " and "), "Amram and Jochebed"
        )
        self.assertEqual(bow.relatives("Zorathites@1Ch.2.53- +"), "Zorathites")  # mother unknown
        self.assertEqual(bow.relatives("Canaan@Gen.9.18-1Ch(d)"), "Canaan")

    def test_a_group_descended_from_a_person_is_not_the_person(self):
        """The source files "the Jews" under Judah's record, labeled Group."""
        tab = "\t"
        top = tab.join([
            "Judah@Gen.29.35-Rev=H3063G", "Jacob's son living at the time of the Patriarchs",
            "Jacob@Gen.25.26-Rev + Leah@Gen.29.31-Gen", "Reuben@Gen.29.32, Simeon@Gen.29.33", "", "",
            "Tribe of Judah", "#A summary", "Male",
        ])
        spellings = [
            tab.join(["– Named", "Judah@Gen.29.35-Rev", "H3063G«H3063=יְהוּדָה", "Judah", "Gen.29.35; Gen.35.23"]),
            tab.join(["– Group", "Jews|Judah@Gen.29.35-Rev", "G2453«G2453=Ἰουδαῖος", "Jew", "Mat.2.2; Mrk.15.12"]),
            tab.join(["– Spelled", "Jews|Judah@Gen.29.35-Rev", "G2450«G2450=Ἰουδαΐζω", "Jew", "Gal.2.14"]),
            tab.join(["– Total", "Judah or Jew", "Judah", "H3063G", "Gen.29.35;", "9"]),
        ]
        text = "\n".join(["$========== PERSON(s)", top, *spellings, ""])
        with tempfile.TemporaryDirectory() as folder:
            path = pathlib.Path(folder) / "names.txt"
            path.write_text(text, encoding="utf-8")
            book_numbers = {a: n for n, a in enumerate(bow.ABBREVIATIONS, 1)}
            records, links = bow.parse_names(path, book_numbers, lambda strongs: strongs, [])

        judah, jews = records
        self.assertEqual((judah[1], judah[2], judah[4]), ("Judah", "Male", "Jacob and Leah"))
        self.assertEqual((jews[1], jews[2], jews[3]), ("Jews", "Group", "People descended from Judah"))
        self.assertEqual(
            sorted(links),
            sorted([
                ("H3063G", 1, 29, 35, judah[0]), ("H3063G", 1, 35, 23, judah[0]),
                ("G2453", 40, 2, 2, jews[0]), ("G2453", 41, 15, 12, jews[0]),
                ("G2450", 48, 2, 14, jews[0]),
            ]),
        )


class GreekDefinitionTests(unittest.TestCase):
    """Abbott-Smith's entries cut down to their English senses."""

    def clean(self, text):
        return bow.greek_definition(text)

    def test_the_headword_and_the_septuagint_line_go_and_the_meaning_stays(self):
        raw = "ἀγάπη, -ης, ἡ\n[in LXX for אַהֲבָה;]\nlove, goodwill, esteem"
        self.assertEqual(self.clean(raw), "love, goodwill, esteem")

    def test_an_english_remark_in_the_headword_line_is_kept(self):
        raw = "βίβλος, -ου, ἡ (variant form of βύβλος, the Egyptian papyrus, paper made from its fibrous coat)\na book, a roll"
        self.assertEqual(self.clean(raw), "a book, a roll")

    def test_clauses_quoting_greek_are_dropped_whole(self):
        raw = HEADWORD + "to go in or into, enter: , , al.; before εἰς, , al.; ὑπὸ τ. στέγην; of food"
        self.assertEqual(self.clean(raw), "to go in or into, enter; of food")

    def test_a_clause_ending_on_a_preposition_lost_its_object_and_goes(self):
        raw = HEADWORD + "to go in or into, enter; before εἰς; with adv.: ὅπου"
        self.assertEqual(self.clean(raw), "to go in or into, enter")

    def test_a_clause_of_only_greek_leaves_nothing(self):
        self.assertEqual(self.clean(HEADWORD + "ὑπὸ τ. στέγην, εἰς κόπον"), "")

    def test_citations_of_other_authors_and_scholars_go(self):
        raw = HEADWORD + "a fellow-soldier (Plat., Xen., al.). Metaphorical, of fellowship in Christian service: , Phm 2 ."
        self.assertEqual(self.clean(raw), "a fellow-soldier. Metaphorical, of fellowship in Christian service.")
        self.assertEqual(self.clean(HEADWORD + "(Hom., Eur.); (cf. Dalman, Words, 116ff.)"), "")

    def test_verse_references_go_but_the_sense_stays(self):
        raw = HEADWORD + "to enter: Mat.5:1, Luk.2:3; to go in (cf. 22:3)"
        self.assertEqual(self.clean(raw), "to enter; to go in")

    def test_text_critical_notes_are_cut_from_the_end_of_a_clause(self):
        self.assertEqual(self.clean(HEADWORD + "a reason, cause WH, mg., R, mg."), "a reason, cause")

    def test_latin_glosses_are_cut_but_the_numbered_outline_stays(self):
        raw = (
            "λόγος, -ου, ὁ\n"
            "I. Of that by which the inward thought is expressed, Lat. oratio, sermo\n"
            "__1. a word, not in the grammatical sense of a mere name (ἔπος, ὄνομα), but a word as embodying a conception\n"
            "__2. a saying, statement, declaration; with genitive attrib., al."
        )
        self.assertEqual(
            self.clean(raw),
            "I. Of that by which the inward thought is expressed\n"
            "__1. a word, not in the grammatical sense of a mere name, but a word as embodying a conception\n"
            "__2. a saying, statement, declaration; with genitive attrib.",
        )

    def test_synonym_comparisons_and_the_source_tag_go(self):
        self.assertEqual(self.clean("ἀγάπη, -ης, ἡ\nlove\nSYN.: φιλία. ἀ., signifying properly\n(AS)"), "love")

    def test_markup_is_turned_into_plain_text_with_the_outline_numbers_kept(self):
        raw = (
            "<b>ἀγάπη</b>, -ης, ἡ <BR /> [in LXX for אַהֲבָה ;] <BR /> <b>love</b>, goodwill "
            "<ref='Mat.5.1'>Mat.5:1</ref>† <BR />__1. of men: <ref='Rom.5.8'>Rom.5:8</ref>"
        )
        self.assertEqual(bow.plain_definition(raw, "greek"), "love, goodwill\n1. of men")

    def test_hebrew_definitions_keep_their_outline_and_lose_only_markup(self):
        raw = "1) to create<br>1a) to shape<BR>Aramaic equivalent: <i>yat</i>"
        self.assertEqual(bow.plain_definition(raw, "hebrew"), "1) to create\n1a) to shape\nAramaic equivalent: yat")

    def test_a_long_definition_is_cut_at_a_line_break_and_marked(self):
        text = "\n".join(f"sense number {number}: " + "word " * 12 for number in range(60))
        cut = bow.shorten(text)
        self.assertTrue(cut.endswith("…"))
        self.assertLessEqual(len(cut), bow.DEFINITION_LIMIT + 1)
        self.assertEqual(bow.shorten("short"), "short")


_import_spec = importlib.util.spec_from_file_location(
    "import_lexicon_edits", SCRIPT.parent / "import_lexicon_edits.py")
ile = importlib.util.module_from_spec(_import_spec)
_import_spec.loader.exec_module(ile)


def entry(key, gloss, language="hebrew", definition="A definition."):
    return (key, language, "שֵׁבֶט", "she.vet", gloss, definition)


class LexiconEditTests(unittest.TestCase):
    """Hand edits to the dictionary, kept in `lexicon_edits.csv` so rebuilds don't undo them."""

    def test_the_edits_file_reads_back_what_was_written(self):
        edits = {"H7626G": entry("H7626G", "staff", definition="A rod, staff;\nalso a \"tribe\", 2, 3."),
                 "G0026": entry("G0026", "love", language="greek")}
        with tempfile.TemporaryDirectory() as folder:
            path = pathlib.Path(folder) / "edits.csv"
            bow.write_lexicon_edits(path, edits)
            self.assertEqual(bow.read_lexicon_edits(path), edits)

    def test_a_missing_edits_file_is_no_edits(self):
        self.assertEqual(bow.read_lexicon_edits(pathlib.Path("/nonexistent/edits.csv")), {})

    def test_a_listed_entry_is_replaced_and_the_rest_are_stepbibles(self):
        entries = [entry("H0001G", "father"), entry("H7626G", "tribe: staff")]
        edited, applied = bow.apply_lexicon_edits(entries, {"H7626G": entry("H7626G", "staff")}, [])
        self.assertEqual(edited, [entry("H0001G", "father"), entry("H7626G", "staff")])
        self.assertEqual(applied, 1)

    def test_an_edit_for_an_unused_entry_or_the_other_language_is_reported_not_applied(self):
        entries = [entry("H0001G", "father")]
        warnings = []
        edited, applied = bow.apply_lexicon_edits(entries, {
            "H9999": entry("H9999", "nothing"),
            "H0001G": entry("H0001G", "father", language="greek"),
        }, warnings)
        self.assertEqual((edited, applied), (entries, 0))
        self.assertEqual(len(warnings), 2)

    def test_merging_adds_replaces_and_undoes_edits(self):
        originals = {key: entry(key, "original") for key in ("H0001", "H0002", "H0003", "H0004")}
        existing = {"H0002": entry("H0002", "first edit"), "H0003": entry("H0003", "kept edit"),
                    "H0004": entry("H0004", "same edit")}
        incoming = {
            "H0001": entry("H0001", "new edit"),
            "H0002": entry("H0002", "second edit"),
            "H0003": entry("H0003", "original"),   # pasting the original back undoes the edit
            "H0004": entry("H0004", "same edit"),
            "H9999": entry("H9999", "unknown"),
        }
        edits, (added, replaced, dropped, unchanged, problems) = ile.merge(incoming, existing, originals)
        self.assertEqual(sorted(edits), ["H0001", "H0002", "H0004"])
        self.assertEqual(edits["H0002"][4], "second edit")
        self.assertEqual((added, replaced, dropped, unchanged), (["H0001"], ["H0002"], ["H0003"], ["H0004"]))
        self.assertEqual(len(problems), 1)

    def test_entries_a_csv_leaves_out_keep_their_edits(self):
        originals = {"H0001": entry("H0001", "original"), "H0002": entry("H0002", "original")}
        existing = {"H0002": entry("H0002", "earlier edit")}
        edits, _ = ile.merge({"H0001": entry("H0001", "new edit")}, existing, originals)
        self.assertEqual(edits["H0002"][4], "earlier edit")

    def test_a_row_in_the_other_language_is_skipped(self):
        originals = {"H0001": entry("H0001", "original")}
        edits, (_, _, _, _, problems) = ile.merge(
            {"H0001": entry("H0001", "edit", language="greek")}, {}, originals)
        self.assertEqual((edits, len(problems)), ({}, 1))


class RealDefinitionTests(unittest.TestCase):
    """Properties every cleaned definition must have, checked against the real Greek lexicon."""

    def test_no_definition_has_greek_or_hebrew_letters_or_outline_underscores(self):
        path = next(bow.SOURCES.glob("TBESG*.txt"), None)
        if path is None:
            self.skipTest("the STEPBible files aren't in Scripts/data/stepbible/")
        problems = []
        for key, entry in bow.parse_lexicon(path, "greek").items():
            definition = entry[5]
            if FOREIGN.search(definition):
                problems.append(f"{key}: has Greek or Hebrew letters")
            if "__" in definition:
                problems.append(f"{key}: has outline underscores")
            if len(definition) > bow.DEFINITION_LIMIT + 1:
                problems.append(f"{key}: is {len(definition)} characters")
        self.assertEqual(problems[:10], [])


if __name__ == "__main__":
    unittest.main(verbosity=1)
