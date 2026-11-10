# Source data

## openbible_cross_references.zip

`cross_references.txt` from the OpenBible.info cross-reference dataset, version dated
2026-10-12 (from the file's header line), downloaded from
https://a.openbible.info/data/cross-references.zip.

Licensed under Creative Commons Attribution (CC-BY): https://www.openbible.info. The app
credits OpenBible.info in Settings → Help → Acknowledgements.

`Scripts/add_strict_cross_references.py` reads this file directly. To update it, replace the
zip with a newer download and rebuild the cross references with `--rebuild`.

## Translation sources

The raw sources for translations other than the KJV live in `The Bible (iOS)Tests/TranslationSources/`,
so the test bundle (not the app) includes them. `Scripts/build_translation.py` builds each into
`The Bible/<ABBR>Text.json` and records hashes in `manifest.json` there.

- `asv.json`: American Standard Version (1901), public domain. Added 2026-11-04. The source
  had stray brackets and USFM markup around "Selah", which the build script removes.
- `web.json`: World English Bible (Protestant edition, "LORD" rather than "Yahweh"), public domain.
  Added 2026-11-06. The text needs no cleanup, but the WEB prints Matthew 23:13-14 in the
  Byzantine order, so `build_translation.py` swaps them back to the KJV's numbering. Its preface
  asks that the name "World English Bible" be kept for faithful copies of the translation.

## stepbible/ (not in git)

The Hebrew and Greek words behind each verse and their lexicon entries, from
[STEPBible-Data](https://github.com/STEPBible/STEPBible-Data) by STEPBible.org and Tyndale
House Cambridge, licensed CC BY 4.0. The files are ignored by git: the licence asks that
copies of the data files not be posted elsewhere, so that STEPBible stays the one up-to-date
source. The app bundles only the converted database.

To rebuild `The Bible (iOS)/OriginalWords.sqlite`, download these 11 files from the repository
into `Scripts/data/stepbible/`, unedited, then run `python3 -I Scripts/build_original_words.py`:

- `TAHOT Gen-Deu`, `TAHOT Jos-Est`, `TAHOT Job-Sng`, `TAHOT Isa-Mal`: Translators Amalgamated
  Hebrew OT (4 files, in `Translators Amalgamated OT+NT`).
- `TAGNT Mat-Jhn`, `TAGNT Act-Rev`: Translators Amalgamated Greek NT (2 files, same folder).
- `TBESH` and `TBESG`: Translators Brief lexicons of Extended Strong's for Hebrew and Greek
  (in `Lexicons`).
- `TEHMC` and `TEGMC`: Translators Expansion of Hebrew and Greek Morphology Codes, which turn
  each word's grammar code into plain terms (in `Morphology codes`).
- `TIPNR`: Translators Individualised Proper Names with all References, who each person is
  and where the places are (in `Proper Nouns`).

The database was built from the files downloaded on 2026-11-09 and 2026-11-10 (the last
three). Its `meta` table records the
SHA-256 of each source file, so a rebuild from a new download shows whether the data changed.

The licence asks that the source be credited to Tyndale House and STEPBible.org with a link to
https://STEPBible.github.io/STEPBible-Data, and that changes to the data be noted. The
script's changes are listed in its docstring (English-numbered references, Psalm titles
folded into verse 1, words only in unused editions left out, Greek definitions reduced to
their English senses, plain-text definitions, grammar codes turned into one English line,
and name records cut down to who each is and the verses they appear in; the map links in
TIPNR became coordinates). The app credits STEPBible in Settings → Help →
Acknowledgements, as it does OpenBible.info.
