#!/usr/bin/env python3
"""Builds a bundled Bible translation from its raw source in `The Bible (iOS)Tests/TranslationSources/`.

The KJV has its own pipeline (`Scripts/clean_kjv`), because its source carries red-letter
and supplied-word markup. Every other translation goes through this script:

    python3 Scripts/build_translation.py asv            # build The Bible/ASVText.json
    python3 Scripts/build_translation.py asv --check    # validate only; writes nothing

The source is the same shape as `The Bible/kjv.json`: [{ abbrev, name, chapters: [[verse]] }].
The script applies the translation's known source fixes, then checks it against the bundled
KJV: the same 66 book names in the same order, and the same number of chapters and verses
in every chapter. The app keys bookmarks, notes, highlights, and reading progress by book,
chapter, and verse, so a translation must line up verse for verse before it can ship.

Some translations leave out verses the KJV has (Matthew 17:21, Acts 8:37, …). Their source
keeps the verse as an empty string, and so does the output, so later verses keep their
numbers; the app shows a note in the verse's place. The script lists them.

Each build records the SHA-256 of the source and of the output in
`The Bible (iOS)Tests/TranslationSources/manifest.json`. `BibleTranslationTests` fails when the source or the
bundled text no longer matches it, so a source edit without a rebuild (or a hand edit to the
bundled file) is caught.

Output matches `KJVText.json`, with each verse as `[text]`. To add a translation, put its
source in `The Bible (iOS)Tests/TranslationSources/<id>.json`, add any fixes to FIXES, run this script,
and add a case to `BibleTranslation` in the app.
"""
import hashlib
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
# In the tests folder so the test bundle gets them (see BibleTranslationTests); the app does not.
SOURCES = ROOT / "The Bible (iOS)Tests" / "TranslationSources"
KJV = ROOT / "The Bible" / "KJVText.json"
MANIFEST = SOURCES / "manifest.json"
OUTPUT_DIR = ROOT / "The Bible"


def fix_asv(text):
    # 17 Selahs still carry USFM word markup: \+w Selah|strong="H5542"\+w*
    text = re.sub(r'\\\+w ([^|\\]+)\|strong="[^"]*"\\\+w\*', r"\1", text)
    # The source opens each Selah with a stray bracket ("in God. [Selah", "[Higgaion. Selah").
    # Printed ASVs set it as a word on its own, as the KJV text does ("in God. Selah.").
    return re.sub(r"\[((?:Higgaion\. )?Selah)\b\.?", r"\1.", text)


# Per-translation fixes applied to every verse before validation.
FIXES = {
    "asv": fix_asv,
}


def normalized(text):
    return re.sub(r"\s+", " ", text).strip()


def main():
    args = [arg for arg in sys.argv[1:] if not arg.startswith("--")]
    check_only = "--check" in sys.argv
    if len(args) != 1:
        sys.exit("usage: build_translation.py <translation id> [--check]")
    translation = args[0].lower()

    source_path = SOURCES / f"{translation}.json"
    if not source_path.exists():
        sys.exit(f"No source at {source_path.relative_to(ROOT)}")
    source = json.loads(source_path.read_text(encoding="utf-8"))
    kjv = json.loads(KJV.read_text(encoding="utf-8"))
    fix = FIXES.get(translation, lambda text: text)

    problems = []
    omitted = []
    if len(source) != len(kjv):
        problems.append(f"{len(source)} books; the KJV has {len(kjv)}")

    output = []
    for book, kjv_book in zip(source, kjv):
        name = kjv_book["name"]
        if book.get("name") != name:
            problems.append(f"book {book.get('name')!r} is where the KJV has {name!r}")
        chapters = book["chapters"]
        if len(chapters) != len(kjv_book["chapters"]):
            problems.append(f"{name}: {len(chapters)} chapters; the KJV has {len(kjv_book['chapters'])}")
        for number, (verses, kjv_verses) in enumerate(zip(chapters, kjv_book["chapters"]), start=1):
            if len(verses) != len(kjv_verses):
                problems.append(f"{name} {number}: {len(verses)} verses; the KJV has {len(kjv_verses)}")
            for verse_number, text in enumerate(verses, start=1):
                if not normalized(fix(text)):
                    omitted.append(f"{name} {number}:{verse_number}")
        output.append({
            "abbrev": book["abbrev"],
            "chapters": [[[normalized(fix(text))] for text in verses] for verses in chapters],
            "name": name,
        })

    if problems:
        print(f"{translation.upper()} doesn't line up with the KJV:")
        for problem in problems[:50]:
            print(f"  - {problem}")
        if len(problems) > 50:
            print(f"  … and {len(problems) - 50} more")
        sys.exit(1)

    verse_count = sum(len(verses) for book in output for verses in book["chapters"])
    if omitted:
        print(f"{len(omitted)} verses not in the {translation.upper()} text: {', '.join(omitted)}")
    if check_only:
        print(f"{translation.upper()} lines up with the KJV ({verse_count} verses). Nothing written.")
        return

    output_path = OUTPUT_DIR / f"{translation.upper()}Text.json"
    data = json.dumps(output, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
    output_path.write_text(data, encoding="utf-8")
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
    manifest[translation] = {
        "source": hashlib.sha256(source_path.read_bytes()).hexdigest(),
        "output": hashlib.sha256(data.encode("utf-8")).hexdigest(),
    }
    MANIFEST.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Wrote {verse_count} verses to {output_path.relative_to(ROOT)} ({len(data.encode('utf-8'))} bytes).")


if __name__ == "__main__":
    main()
