# Source data

## openbible_cross_references.zip

`cross_references.txt` from the OpenBible.info cross-reference dataset, version dated
2026-10-12 (from the file's header line), downloaded from
https://a.openbible.info/data/cross-references.zip.

Licensed under Creative Commons Attribution (CC-BY): https://www.openbible.info. The app
credits OpenBible.info in Settings → Help → Acknowledgements.

`Scripts/add_strict_cross_references.py` reads this file directly. To update it, replace the
zip with a newer download and rebuild the cross references with `--rebuild`.
