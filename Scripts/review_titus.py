#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Apply the completed editorial review for Titus to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BOOK = "Titus"


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


SUMMARY = {
    1: "Paul, a servant of God, and an apostle of Jesus Christ, writes according to the faith of God's elect, in hope of eternal life, which God, that cannot lie, promised before the world began, and hath in due times manifested his word through preaching (Titus 1:1–3). He greets Titus, his own son after the common faith, with grace, mercy, and peace (Titus 1:4). He left Titus in Crete to set in order the things that are wanting and ordain elders in every city (Titus 1:5). An elder must be blameless, the husband of one wife, having faithful children not accused of riot or unruly (Titus 1:6). A bishop, as the steward of God, must not be selfwilled, soon angry, given to wine, a striker, or given to filthy lucre, but a lover of hospitality, a lover of good men, sober, just, holy, temperate, holding fast the faithful word that he may by sound doctrine exhort and convince the gainsayers (Titus 1:7–9). There are many unruly and vain talkers and deceivers, specially they of the circumcision, whose mouths must be stopped, who subvert whole houses for filthy lucre's sake (Titus 1:10–11). One of themselves, a prophet of their own, said the Cretians are alway liars, evil beasts, slow bellies, and Paul says this witness is true, so Titus must rebuke them sharply that they may be sound in the faith, not giving heed to Jewish fables and commandments of men (Titus 1:12–14). Unto the pure all things are pure, but they that are defiled and unbelieving profess that they know God, but in works they deny him, being abominable, and disobedient, and unto every good work reprobate (Titus 1:15–16).",
    2: "Paul tells Titus to speak the things which become sound doctrine (Titus 2:1). The aged men are to be sober, grave, temperate, sound in faith, in charity, in patience (Titus 2:2). The aged women are to be in behaviour as becometh holiness, not false accusers, not given to much wine, teachers of good things, that they may teach the young women to be sober, to love their husbands, to love their children, to be discreet, chaste, keepers at home, good, obedient to their own husbands, that the word of God be not blasphemed (Titus 2:3–5). Young men are to be exhorted to be sober minded, and Titus himself is to be a pattern of good works, with uncorruptness, gravity, and sincerity in doctrine, and sound speech that cannot be condemned, that he that is of the contrary part may be ashamed (Titus 2:6–8). Servants are to be obedient unto their own masters, to please them well in all things, not answering again, not purloining, but shewing all good fidelity, that they may adorn the doctrine of God our Saviour in all things (Titus 2:9–10). The grace of God that bringeth salvation hath appeared to all men, teaching us that, denying ungodliness and worldly lusts, we should live soberly, righteously, and godly in this present world (Titus 2:11–12). We look for that blessed hope, and the glorious appearing of the great God and our Saviour Jesus Christ, who gave himself for us to redeem us from all iniquity and purify unto himself a peculiar people, zealous of good works (Titus 2:13–14). Titus is to speak, exhort, and rebuke with all authority, and let no man despise him (Titus 2:15).",
    3: "Paul tells Titus to put them in mind to be subject to principalities and powers, to obey magistrates, to be ready to every good work, to speak evil of no man, to be no brawlers, but gentle, shewing all meekness unto all men (Titus 3:1–2). For we ourselves also were sometimes foolish, disobedient, deceived, serving divers lusts and pleasures, living in malice and envy, hateful, and hating one another (Titus 3:3). But after that the kindness and love of God our Saviour toward man appeared, not by works of righteousness which we have done, but according to his mercy he saved us, by the washing of regeneration, and renewing of the Holy Ghost, which he shed on us abundantly through Jesus Christ our Saviour (Titus 3:4–6). Being justified by his grace, we should be made heirs according to the hope of eternal life (Titus 3:7). This is a faithful saying, and Titus is to affirm it constantly, that they which have believed in God might be careful to maintain good works, but to avoid foolish questions, and genealogies, and contentions, and strivings about the law, for they are unprofitable and vain (Titus 3:8–9). A man that is an heretick after the first and second admonition is to be rejected, knowing that he is subverted, and sinneth, being condemned of himself (Titus 3:10–11). When Paul sends Artemas or Tychicus, Titus is to be diligent to come unto him to Nicopolis, where he hath determined to winter, and to bring Zenas the lawyer and Apollos on their journey diligently, that nothing be wanting unto them (Titus 3:12–13). Let ours also learn to maintain good works for necessary uses, that they be not unfruitful, and all that are with Paul salute Titus, with grace be with you all (Titus 3:14–15).",
}

WWA = {
    1: "Titus follows 2 Timothy among Paul's letters to fellow workers. Paul writes to Titus, whom he left in Crete, giving the qualifications for elders and telling him to rebuke the unruly talkers and deceivers there (1:1-16). Chapter 2 tells Titus what sound doctrine means for every age and station.",
    2: "Chapter 1 ended with those who profess to know God but in works deny him (1:16). Chapter 2 tells Titus to teach sound doctrine to aged men and women, young men and women, and servants, and grounds it in the grace of God that bringeth salvation and the blessed hope (2:1-15). Chapter 3 turns to life in the world and the mercy that saved us.",
    3: "Chapter 2 ended with a peculiar people zealous of good works (2:14). Chapter 3 tells believers to be subject to rulers and gentle to all, recalls the mercy that saved us, warns against foolish questions and the heretick, and closes with plans and greetings (3:1-15). Philemon follows.",
}

KEY_FIGURES = {
    1: [
        ("Paul", "Writes as a servant of God and an apostle of Jesus Christ and tells Titus what he left him in Crete to do (1:1,4-5)."),
        ("Titus", "Paul's own son after the common faith, left in Crete to set things in order and ordain elders (1:4-5)."),
        ("God our Saviour and the Lord Jesus Christ", "God that cannot lie promised eternal life, and grace and peace come from the Father and the Lord Jesus (1:2-4)."),
        ("The elders to be ordained", "Described as blameless, the steward of God, holding fast the faithful word (1:6-9)."),
        ("The unruly and vain talkers and deceivers", "Specially they of the circumcision, who subvert whole houses for filthy lucre's sake (1:10-11)."),
        ("The Cretians and their prophet", "Called alway liars, evil beasts, slow bellies by one of their own, and told to be rebuked sharply (1:12-13)."),
    ],
    2: [
        ("Titus", "Told to speak sound doctrine, be a pattern of good works, and exhort and rebuke with all authority (2:1,7,15)."),
        ("The aged men and the young men", "The aged men are to be sober, grave, and sound in faith, and the young men sober minded (2:2,6)."),
        ("The aged women and the young women", "The aged women are to be teachers of good things, who teach the young women to love their husbands and children (2:3-5)."),
        ("The servants", "To be obedient to their masters, not purloining but shewing good fidelity (2:9-10)."),
        ("God our Saviour", "His grace that bringeth salvation hath appeared to all men (2:10-12)."),
        ("Jesus Christ", "The great God and our Saviour, who gave himself for us to redeem us and purify a peculiar people (2:13-14)."),
    ],
    3: [
        ("Titus", "Told to put them in mind, affirm constantly, avoid foolish questions, and come to Paul at Nicopolis (3:1,8-9,12)."),
        ("Paul", "Gives his instructions and says he hath determined to winter at Nicopolis (3:12)."),
        ("The believers", "Once foolish and disobedient, they are told to be gentle to all and to maintain good works (3:1-3,8,14)."),
        ("God our Saviour", "Saved us by his mercy, the washing of regeneration, and the renewing of the Holy Ghost through Jesus Christ (3:4-7)."),
        ("The heretick", "A man to be rejected after the first and second admonition, condemned of himself (3:10-11)."),
        ("Artemas, Tychicus, Zenas, and Apollos", "Artemas or Tychicus is to be sent, and Zenas the lawyer and Apollos are to be helped on their journey (3:12-13)."),
    ],
}

THEMES = {
    1: [
        "Titus is to ordain elders who are blameless, the steward of God, a lover of hospitality, sober, just, holy, and temperate (1:5-9).",
        "The elder is to hold fast the faithful word, that he may by sound doctrine both exhort and convince the gainsayers (1:9).",
        "Paul writes in hope of eternal life, which God, that cannot lie, promised before the world began (1:1-3).",
        "Unruly and vain talkers subvert whole houses, teaching things which they ought not, for filthy lucre's sake (1:10-11).",
        "Some profess that they know God but in works they deny him, being abominable, and disobedient, and unto every good work reprobate (1:15-16).",
    ],
    2: [
        "Titus is to speak the things which become sound doctrine and to be a pattern of good works in doctrine, uncorruptness, gravity, and sincerity (2:1,7-8).",
        "The aged men and women, the young men and women, and the servants each have their part to live out (2:2-6,9-10).",
        "Good behaviour keeps the word of God from being blasphemed and lets servants adorn the doctrine of God our Saviour in all things (2:5,8,10).",
        "The grace of God that bringeth salvation hath appeared to all men, teaching us to deny ungodliness and worldly lusts and live soberly, righteously, and godly (2:11-12).",
        "Believers look for that blessed hope, the glorious appearing of the great God and our Saviour Jesus Christ, who purified a peculiar people, zealous of good works (2:13-14).",
    ],
    3: [
        "Believers are to be subject to principalities and powers, ready to every good work, and gentle, shewing all meekness unto all men (3:1-2).",
        "We ourselves also were sometimes foolish, disobedient, deceived, serving divers lusts and pleasures, which is a reason to be meek with others (3:3).",
        "Not by works of righteousness which we have done, but according to his mercy he saved us, by the washing of regeneration and the renewing of the Holy Ghost (3:4-7).",
        "Those who have believed in God are to be careful to maintain good works, which are good and profitable unto men (3:8,14).",
        "Foolish questions, genealogies, and contentions are unprofitable, and the heretick is to be rejected after the first and second admonition (3:9-11).",
    ],
}

AUDIENCE_FIXES = {
    1: "Young churches in a place known for liars and loose living would have heard what kind of man to trust as a leader, and why deceivers must be stopped.",
    2: "Believers of every age, and servants in other people's houses, would have heard that quiet, steady lives made the gospel look good to outsiders.",
    3: "Believers who were once as foolish as anyone would have heard that they were saved by mercy, not works, and were sent back into daily life to do good and be gentle with all.",
}


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "56_titus.json"
    data = load(path)
    for n in range(1, 4):
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
    book["author"] = "Paul the apostle, writing to Titus (Titus 1:1, 4)."
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_FIXES = [
    ("Peculiar here means His own special possession.", "Peculiar here means his own special possession."),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "08_pauls_letters.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("\n# Titus") + 1
    end = text.index("\n# Philemon", start)
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
