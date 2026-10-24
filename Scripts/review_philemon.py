#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Apply the completed editorial review for Philemon to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BOOK = "Philemon"


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


SUMMARY = {
    1: "Paul, a prisoner of Jesus Christ, and Timotheus his brother write unto Philemon, our dearly beloved and fellowlabourer, and to Apphia, Archippus our fellowsoldier, and the church in his house, with grace and peace from God our Father and the Lord Jesus Christ (Philemon 1:1–3). Paul thanks God, making mention of Philemon always in his prayers, hearing of his love and faith toward the Lord Jesus and toward all saints, and has great joy and consolation in his love, because the bowels of the saints are refreshed by him (Philemon 1:4–7). Though Paul might be much bold in Christ to enjoin that which is convenient, yet for love's sake he rather beseeches, being such an one as Paul the aged, and now also a prisoner of Jesus Christ (Philemon 1:8–9). He beseeches Philemon for his son Onesimus, whom he hath begotten in his bonds, who in time past was unprofitable but now is profitable to Philemon and to Paul (Philemon 1:10–11). Paul has sent him again and asks Philemon to receive him, that is, his own bowels, and says he would have retained him but without Philemon's mind would do nothing, that his benefit should not be of necessity, but willingly (Philemon 1:12–14). Perhaps Onesimus departed for a season that Philemon should receive him for ever, not now as a servant, but above a servant, a brother beloved, both in the flesh and in the Lord (Philemon 1:15–16). Paul asks Philemon to receive him as himself, and if he hath wronged Philemon or oweth ought, to put that on Paul's account, for Paul has written it with his own hand and will repay it (Philemon 1:17–19). He asks Philemon to refresh his bowels in the Lord, has confidence in his obedience, asks for a lodging, and trusts that through their prayers he shall be given unto them (Philemon 1:20–22). Epaphras, Marcus, Aristarchus, Demas, and Lucas send greetings, and Paul closes with the grace of our Lord Jesus Christ (Philemon 1:23–25).",
}

WWA = {
    1: "Philemon follows Titus and is the shortest of Paul's letters. Written from prison, it is a personal appeal to Philemon, who has a church in his house, to receive Onesimus, once unprofitable and now profitable, no longer as a servant but as a brother beloved (1:1-25). Hebrews follows after the letters of Paul.",
}

KEY_FIGURES = {
    1: [
        ("Paul", "A prisoner of Jesus Christ who beseeches Philemon for love's sake and promises to repay any debt (1:1,9-10,18-19)."),
        ("Timotheus", "Named with Paul as a brother and sender of the letter (1:1)."),
        ("Philemon", "Paul's dearly beloved fellowlabourer, who has love and faith toward all saints and must decide how to receive Onesimus (1:1,5,17)."),
        ("Onesimus", "Paul's son begotten in his bonds, once unprofitable and now profitable, who is sent again as a brother beloved (1:10-12,16)."),
        ("Apphia, Archippus, and the church in his house", "Addressed with Philemon in the greeting (1:2)."),
        ("Epaphras, Marcus, Aristarchus, Demas, and Lucas", "Paul's fellowprisoner and fellowlabourers who send their greetings (1:23-24)."),
    ],
}

THEMES = {
    1: [
        "Though Paul might be much bold in Christ to enjoin that which is convenient, for love's sake he rather beseeches, so Philemon's good deed is to be willing and not of necessity (1:8-9,14).",
        "Onesimus is to be received no longer as a servant but above a servant, a brother beloved, both in the flesh and in the Lord (1:15-17).",
        "Paul says if Onesimus hath wronged Philemon or oweth ought, put that on his account, and he writes it with his own hand (1:18-19).",
        "Onesimus, once unprofitable, is now profitable to both of them, and has been begotten as Paul's son in his bonds (1:10-11).",
        "Paul thanks God for Philemon's love and faith toward all saints, and the saints' hearts are refreshed by him (1:4-7,20).",
    ],
}

AUDIENCE_FIXES = {
    1: "Philemon, his house church, and Onesimus himself would have heard Paul ask a master to welcome a returning slave as a beloved brother, with Paul standing good for any debt.",
}


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "57_philemon.json"
    data = load(path)
    for n in range(1, 2):
        entry = data[f"{BOOK} {n}"]
        entry["summary"] = SUMMARY[n]
        entry["whereWeAre"] = WWA[n]
        entry["keyFigures"] = [{"name": a, "role": b} for a, b in KEY_FIGURES[n]]
        if len(entry["keyThemes"]) != len(THEMES[n]):
            raise SystemExit(f"{BOOK} {n}: theme count mismatch")
        for theme, explanation in zip(entry["keyThemes"], THEMES[n]):
            theme["explanation"] = explanation
            refs = []
            for ref in theme["references"]:
                refs.extend(json.loads(ref) if ref.startswith("[") else [ref])
            theme["references"] = refs
        if len(entry["whereWeAre"]) > 600 or len(entry["keyFigures"]) > 6:
            raise SystemExit(f"{BOOK} {n}: WWA {len(entry['whereWeAre'])} chars or too many figures")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_chapter_context():
    path = ROOT / "chapter_context" / "39_thessalonians_philemon.json"
    data = load(path)
    for n, text in AUDIENCE_FIXES.items():
        data[f"{BOOK} {n}"]["audience"] = text
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_book_overview():
    path = ROOT / "book_overviews" / "08_pauls_letters.json"
    data = load(path)
    book = data[BOOK]
    book["author"] = "Paul the apostle, with Timothy named in the greeting (Philemon 1:1, 9)."
    book["keyVerse"] = "Philemon 1:16"
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_FIXES = [
    ("taking their debt on Himself", "taking their debt on himself"),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "08_pauls_letters.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("\n# Philemon") + 1
    end = len(text)
    section = text[start:end]
    for old, new in STORY_FIXES:
        if section.count(old) == 0 and section.count(new) >= 1:
            continue
        if section.count(old) != 1:
            raise SystemExit(f"story fix matched {section.count(old)} times: {old!r}")
        section = section.replace(old, new)
    path.write_text(text[:start] + section + text[end:], encoding="utf-8")
    print(f"Updated {path.relative_to(ROOT)}")


if __name__ == "__main__":
    apply_chapter_insights()
    apply_chapter_context()
    apply_book_overview()
    apply_story_fixes()
