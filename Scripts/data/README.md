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
