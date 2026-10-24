#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Apply the completed editorial review for 2 Timothy to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BOOK = "2 Timothy"


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


SUMMARY = {
    1: "Paul, an apostle of Jesus Christ by the will of God, writes to Timothy, his dearly beloved son, with grace, mercy, and peace (2 Timothy 1:1–2). He thanks God, remembering Timothy in his prayers night and day and mindful of his tears, and calls to remembrance the unfeigned faith which dwelt first in his grandmother Lois and his mother Eunice (2 Timothy 1:3–5). He puts Timothy in remembrance to stir up the gift of God which is in him by the putting on of his hands, for God hath not given us the spirit of fear, but of power, and of love, and of a sound mind (2 Timothy 1:6–7). Timothy is not to be ashamed of the testimony of our Lord, nor of Paul his prisoner, but to be partaker of the afflictions of the gospel according to the power of God (2 Timothy 1:8). God hath saved us, and called us with an holy calling, not according to our works, but according to his own purpose and grace, now made manifest by the appearing of our Saviour Jesus Christ, who hath abolished death and brought life and immortality to light through the gospel (2 Timothy 1:9–10). Paul was appointed a preacher, and an apostle, and a teacher of the Gentiles, and he is not ashamed, for he knows whom he has believed and is persuaded that he is able to keep that which he has committed unto him against that day (2 Timothy 1:11–12). Timothy is to hold fast the form of sound words and keep that good thing which was committed unto him by the Holy Ghost which dwelleth in us (2 Timothy 1:13–14). All they which are in Asia are turned away from Paul, of whom are Phygellus and Hermogenes, but Onesiphorus oft refreshed him, was not ashamed of his chain, and sought him out very diligently in Rome (2 Timothy 1:15–18).",
    2: "Paul tells Timothy to be strong in the grace that is in Christ Jesus and to commit the things he hath heard among many witnesses to faithful men, who shall be able to teach others also (2 Timothy 2:1–2). He is to endure hardness as a good soldier of Jesus Christ, who does not entangle himself with the affairs of this life, as an athlete who strives lawfully, and as the husbandman that laboureth, who must be first partaker of the fruits (2 Timothy 2:3–7). Timothy is to remember that Jesus Christ of the seed of David was raised from the dead according to Paul's gospel, for which Paul suffers trouble unto bonds, but the word of God is not bound, and Paul endures all things for the elect's sakes (2 Timothy 2:8–10). It is a faithful saying that if we be dead with him we shall also live with him, if we suffer we shall also reign with him, and if we believe not, yet he abideth faithful, for he cannot deny himself (2 Timothy 2:11–13). Timothy is to charge them that they strive not about words to no profit, to study to shew himself approved unto God, a workman that needeth not to be ashamed, rightly dividing the word of truth, and to shun profane and vain babblings, which eat as doth a canker, as with Hymenaeus and Philetus, who say that the resurrection is past already (2 Timothy 2:14–18). The foundation of God standeth sure, having this seal, The Lord knoweth them that are his, and let every one that nameth the name of Christ depart from iniquity (2 Timothy 2:19). In a great house there are vessels of gold and silver, wood and earth, some to honour and some to dishonour, and a man who purges himself shall be a vessel unto honour, meet for the master's use (2 Timothy 2:20–21). Timothy is to flee youthful lusts, follow righteousness, faith, charity, and peace, and avoid foolish and unlearned questions (2 Timothy 2:22–23). The servant of the Lord must not strive but be gentle unto all men, apt to teach, patient, in meekness instructing those that oppose themselves, if God peradventure will give them repentance to the acknowledging of the truth (2 Timothy 2:24–26).",
    3: "Paul says that in the last days perilous times shall come, when men shall be lovers of their own selves, covetous, boasters, proud, blasphemers, disobedient to parents, unthankful, unholy, without natural affection, lovers of pleasures more than lovers of God, having a form of godliness but denying the power thereof, and from such Timothy is to turn away (2 Timothy 3:1–5). Of this sort are they which creep into houses and lead captive silly women laden with sins, ever learning and never able to come to the knowledge of the truth (2 Timothy 3:6–7). As Jannes and Jambres withstood Moses, so do these resist the truth, men of corrupt minds, but they shall proceed no further, for their folly shall be manifest unto all men (2 Timothy 3:8–9). Timothy hath fully known Paul's doctrine, manner of life, purpose, faith, longsuffering, charity, patience, and the persecutions and afflictions which came to him at Antioch, at Iconium, at Lystra, but out of them all the Lord delivered him (2 Timothy 3:10–11). All that will live godly in Christ Jesus shall suffer persecution, but evil men and seducers shall wax worse and worse, deceiving and being deceived (2 Timothy 3:12–13). Timothy is to continue in the things which he hath learned, for from a child he hath known the holy scriptures, which are able to make him wise unto salvation through faith which is in Christ Jesus (2 Timothy 3:14–15). All scripture is given by inspiration of God and is profitable for doctrine, for reproof, for correction, for instruction in righteousness, that the man of God may be perfect, throughly furnished unto all good works (2 Timothy 3:16–17).",
    4: "Paul charges Timothy before God and the Lord Jesus Christ, who shall judge the quick and the dead at his appearing and his kingdom, to preach the word, be instant in season, out of season, and reprove, rebuke, and exhort with all longsuffering and doctrine (2 Timothy 4:1–2). The time will come when they will not endure sound doctrine, but after their own lusts shall heap to themselves teachers, having itching ears, and shall be turned unto fables (2 Timothy 4:3–4). Timothy is to watch in all things, endure afflictions, do the work of an evangelist, and make full proof of his ministry (2 Timothy 4:5). Paul is now ready to be offered, and the time of his departure is at hand, and he has fought a good fight, finished his course, and kept the faith, and there is laid up for him a crown of righteousness, which the Lord, the righteous judge, shall give him at that day, and to all them that love his appearing (2 Timothy 4:6–8). He asks Timothy to come shortly, for Demas hath forsaken him, having loved this present world, and is departed unto Thessalonica, Crescens to Galatia, Titus unto Dalmatia, and only Luke is with him (2 Timothy 4:9–11). He asks him to take Mark, who is profitable for the ministry, and to bring the cloke left at Troas with Carpus, and the books, but especially the parchments (2 Timothy 4:11–13). Alexander the coppersmith did Paul much evil, and at his first answer no man stood with him, but the Lord stood with him and strengthened him, and he was delivered out of the mouth of the lion (2 Timothy 4:14–17). The Lord shall deliver him from every evil work and preserve him unto his heavenly kingdom (2 Timothy 4:18). He salutes Prisca and Aquila and the household of Onesiphorus, says Trophimus is left at Miletum sick, asks Timothy to come before winter, sends greetings from Eubulus, Pudens, Linus, Claudia, and all the brethren, and closes with grace (2 Timothy 4:19–22).",
}

WWA = {
    1: "2 Timothy follows 1 Timothy and is Paul's last letter, written from prison in Rome. He thanks God for Timothy's unfeigned faith, tells him to stir up the gift of God and not be ashamed of the gospel or of Paul his prisoner, and names those who turned away and the one friend who did not (1:1-18). Chapter 2 tells Timothy to be strong and pass on what he has heard.",
    2: "Chapter 1 ended with Onesiphorus, who was not ashamed of Paul's chain (1:16-18). Chapter 2 tells Timothy to be strong, to commit the gospel to faithful men, to endure as a soldier, an athlete, and a husbandman, and to handle the word of truth rightly while correcting opposers with meekness (2:1-26). Chapter 3 warns of perilous times.",
    3: "Chapter 2 ended with the servant of the Lord instructing opposers in meekness (2:24-26). Chapter 3 warns of perilous times in the last days, points Timothy to Paul's example, and ends with the holy scriptures given by inspiration of God (3:1-17). Chapter 4 gives Paul's last charge.",
    4: "Chapter 3 ended with the scripture making the man of God perfect for every good work (3:16-17). Chapter 4 gives Paul's last charge to preach the word, his words about finishing his course, his requests and news, and his farewell (4:1-22). Titus follows.",
}

KEY_FIGURES = {
    1: [
        ("Paul", "Writes from his chain, tells Timothy to stir up his gift and not be ashamed, and says he knows whom he has believed (1:1,6-8,12)."),
        ("Timothy", "Paul's dearly beloved son, told to stir up the gift of God, hold fast sound words, and keep the good thing committed to him (1:2,6,13-14)."),
        ("Lois and Eunice", "His grandmother and mother, in whom the unfeigned faith dwelt first (1:5)."),
        ("Phygellus and Hermogenes", "Named among all they in Asia who turned away from Paul (1:15)."),
        ("Onesiphorus", "Oft refreshed Paul, was not ashamed of his chain, and sought him out very diligently in Rome (1:16-17)."),
        ("God and Christ Jesus", "God hath saved us and called us, and Christ Jesus abolished death and brought life and immortality to light (1:9-10)."),
    ],
    2: [
        ("Timothy", "Told to be strong, commit the gospel to faithful men, endure hardness, and shun profane babblings (2:1-3,16)."),
        ("Paul", "Suffers trouble unto bonds and endures all things for the elect's sakes (2:9-10)."),
        ("Jesus Christ", "Of the seed of David, raised from the dead, who abideth faithful and cannot deny himself (2:8,13)."),
        ("Faithful men", "Those who shall receive what Timothy heard and teach others also (2:2)."),
        ("Hymenaeus and Philetus", "Say that the resurrection is past already and overthrow the faith of some (2:17-18)."),
        ("The servant of the Lord", "Must be gentle, apt to teach, and patient, instructing those that oppose themselves in meekness (2:24-25)."),
    ],
    3: [
        ("Timothy", "Told to turn away from the ungodly and to continue in what he has learned from childhood (3:5,14-15)."),
        ("Paul", "Gives his doctrine, manner of life, and persecutions as an example, out of which the Lord delivered him (3:10-11)."),
        ("Men of the last days, and those who creep into houses", "Lovers of their own selves with a form of godliness, who lead captive silly women (3:1-7)."),
        ("Jannes and Jambres", "Withstood Moses, as the ungodly resist the truth (3:8)."),
        ("Evil men and seducers", "Wax worse and worse, deceiving and being deceived (3:13)."),
        ("The Lord", "Delivered Paul out of all his persecutions (3:11)."),
    ],
    4: [
        ("Paul", "Gives his charge, says the time of his departure is at hand, and tells of those who forsook him (4:1-8,10,16)."),
        ("Timothy", "Charged to preach the word, do the work of an evangelist, and come before winter, bringing Mark (4:2,5,9,11,21)."),
        ("Jesus Christ and God", "The judge of the quick and the dead, and the Lord who stood with Paul and strengthened him (4:1,8,17-18)."),
        ("Demas", "Forsook Paul, having loved this present world, and departed unto Thessalonica (4:10)."),
        ("Luke and Mark", "Luke alone is with Paul, and Mark is profitable for the ministry (4:11)."),
        ("Alexander the coppersmith", "Did Paul much evil and greatly withstood his words (4:14-15)."),
    ],
}

THEMES = {
    1: [
        "Timothy is not to be ashamed of the testimony of our Lord or of Paul his prisoner, for God hath not given us the spirit of fear, but of power, and of love, and of a sound mind (1:7-8,12).",
        "God hath saved us, and called us with an holy calling, not according to our works, but according to his own purpose and grace (1:9-10).",
        "Timothy is to hold fast the form of sound words and keep that good thing which was committed unto him by the Holy Ghost (1:13-14).",
        "Paul remembers the unfeigned faith that dwelt first in Lois and Eunice and tells Timothy to stir up the gift of God which is in him (1:5-6).",
        "All in Asia turned away from Paul, but Onesiphorus oft refreshed him and was not ashamed of his chain (1:15-18).",
    ],
    2: [
        "Timothy is to commit what he hath heard among many witnesses to faithful men, who shall be able to teach others also (2:1-2).",
        "He is to endure hardness as a good soldier, an athlete, and a husbandman, and Paul himself endures all things for the elect's sakes (2:3-10).",
        "If we believe not, yet he abideth faithful, and he cannot deny himself (2:11-13).",
        "Timothy is to shun profane and vain babblings, which eat as doth a canker, and to rightly divide the word of truth (2:14-18).",
        "A man who purges himself is a vessel unto honour, and the servant of the Lord is gentle, patient, and instructs opposers in meekness (2:20-26).",
    ],
    3: [
        "In the last days men will have a form of godliness but deny the power thereof, and Timothy is told to turn away from such (3:1-5).",
        "All that will live godly in Christ Jesus shall suffer persecution (3:10-12).",
        "Timothy has fully known Paul's doctrine, manner of life, faith, and patience, and is to continue in the things he hath learned (3:10-11,14).",
        "All scripture is given by inspiration of God and is profitable for doctrine, reproof, correction, and instruction in righteousness, so the man of God may be throughly furnished unto all good works (3:14-17).",
        "False teachers resist the truth as Jannes and Jambres did, but they shall proceed no further, for their folly shall be manifest unto all men (3:6-9,13).",
    ],
    4: [
        "Timothy is to preach the word, be instant in season, out of season, and reprove, rebuke, and exhort with all longsuffering and doctrine (4:1-2).",
        "The time will come when they will not endure sound doctrine but heap to themselves teachers, having itching ears (4:3-4).",
        "Paul says he has fought a good fight, finished his course, and kept the faith, and a crown of righteousness is laid up for him (4:6-8).",
        "Demas hath forsaken Paul and at his first answer no man stood with him, yet he asks that it not be laid to their charge (4:9-16).",
        "The Lord stood with Paul and strengthened him, and shall deliver him from every evil work and preserve him unto his heavenly kingdom (4:17-18).",
    ],
}

AUDIENCE_FIXES = {
    1: "Timothy, who may have feared standing with a jailed teacher, would have heard that the Spirit given is one of power, love, and a sound mind, and that one friend was not ashamed.",
    4: "Timothy and the church would have read the last words of a man facing the end, and learned that the Lord stood with him when everyone else left.",
}


def norm(text):
    return text.replace("’", "'")


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "55_2_timothy.json"
    data = load(path)
    for n in range(1, 5):
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
    book["author"] = "Paul the apostle, writing to Timothy from prison (2 Timothy 1:1-2, 8)."
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_FIXES = [
    ("by His own purpose and grace", "by his own purpose and grace"),
    ("preserve him for His heavenly kingdom", "preserve him for his heavenly kingdom"),
    ("Trophimus sick at Miletus", "Trophimus sick at Miletum"),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "08_pauls_letters.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("\n# 2 Timothy") + 1
    end = text.index("\n# Titus", start)
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
