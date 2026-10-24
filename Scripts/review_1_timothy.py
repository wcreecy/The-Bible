#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Apply the completed editorial review for 1 Timothy to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BOOK = "1 Timothy"


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


SUMMARY = {
    1: "Paul, an apostle of Jesus Christ by the commandment of God our Saviour, writes unto Timothy, his own son in the faith, with grace, mercy, and peace (1 Timothy 1:1–2). He asks Timothy to abide still at Ephesus, as he went into Macedonia, that he might charge some that they teach no other doctrine, nor give heed to fables and endless genealogies (1 Timothy 1:3–4). The end of the commandment is charity out of a pure heart, and of a good conscience, and of faith unfeigned, but some have swerved and turned aside unto vain jangling, desiring to be teachers of the law, understanding neither what they say nor whereof they affirm (1 Timothy 1:5–7). The law is good, if a man use it lawfully, for it is made for the lawless and disobedient and for whatever is contrary to sound doctrine, according to the glorious gospel (1 Timothy 1:8–11). Paul thanks Christ Jesus for counting him faithful and putting him into the ministry, though he was before a blasphemer, and a persecutor, and injurious, but he obtained mercy because he did it ignorantly in unbelief (1 Timothy 1:12–14). It is a faithful saying, and worthy of all acceptation, that Christ Jesus came into the world to save sinners, of whom Paul is chief, and he obtained mercy as a pattern to them which should hereafter believe (1 Timothy 1:15–17). He charges Timothy to war a good warfare, holding faith and a good conscience, which some have put away and made shipwreck, among them Hymenaeus and Alexander, whom Paul delivered unto Satan that they may learn not to blaspheme (1 Timothy 1:18–20).",
    2: "Paul exhorts that first of all supplications, prayers, intercessions, and giving of thanks be made for all men, for kings and all that are in authority, that they may lead a quiet and peaceable life in all godliness and honesty (1 Timothy 2:1–2). This is good and acceptable in the sight of God our Saviour, who will have all men to be saved and to come unto the knowledge of the truth (1 Timothy 2:3–4). There is one God, and one mediator between God and men, the man Christ Jesus, who gave himself a ransom for all, and Paul was ordained a preacher, an apostle, and a teacher of the Gentiles (1 Timothy 2:5–7). He wills that men pray every where, lifting up holy hands, without wrath and doubting (1 Timothy 2:8). He wills that women adorn themselves in modest apparel, with shamefacedness and sobriety, not with broided hair, or gold, or pearls, or costly array, but with good works (1 Timothy 2:9–10). He says a woman is to learn in silence with all subjection and that he suffers not a woman to teach, nor to usurp authority over the man, because Adam was first formed, then Eve, and the woman being deceived was in the transgression (1 Timothy 2:11–14). Notwithstanding she shall be saved in childbearing, if they continue in faith and charity and holiness with sobriety (1 Timothy 2:15).",
    3: "Paul says it is a true saying that if a man desire the office of a bishop, he desireth a good work (1 Timothy 3:1). A bishop must be blameless, the husband of one wife, vigilant, sober, of good behaviour, given to hospitality, apt to teach, not given to wine, no striker, not greedy of filthy lucre, but patient, not a brawler, not covetous (1 Timothy 3:2–3). He must rule well his own house, for a man who knows not how to rule his own house cannot take care of the church of God (1 Timothy 3:4–5). He must not be a novice, lest being lifted up with pride he fall into the condemnation of the devil, and he must have a good report of them which are without (1 Timothy 3:6–7). Deacons must likewise be grave, not doubletongued, not given to much wine, not greedy of filthy lucre, holding the mystery of the faith in a pure conscience, and first proved (1 Timothy 3:8–10). Their wives must be grave, not slanderers, sober, faithful in all things, and deacons must be the husbands of one wife, ruling their children and houses well (1 Timothy 3:11–13). Paul hopes to come shortly, but writes that Timothy may know how to behave in the house of God, which is the church of the living God, the pillar and ground of the truth (1 Timothy 3:14–15). Great is the mystery of godliness: God was manifest in the flesh, justified in the Spirit, seen of angels, preached unto the Gentiles, believed on in the world, received up into glory (1 Timothy 3:16).",
    4: "The Spirit speaketh expressly that in the latter times some shall depart from the faith, giving heed to seducing spirits and doctrines of devils, speaking lies in hypocrisy, having their conscience seared with a hot iron (1 Timothy 4:1–2). They forbid to marry and command to abstain from meats, which God hath created to be received with thanksgiving, for every creature of God is good, and nothing to be refused, if it be received with thanksgiving, for it is sanctified by the word of God and prayer (1 Timothy 4:3–5). If Timothy put the brethren in remembrance of these things, he shall be a good minister of Jesus Christ, nourished up in the words of faith and of good doctrine (1 Timothy 4:6). He is to refuse profane and old wives' fables and exercise himself unto godliness, for bodily exercise profiteth little, but godliness is profitable unto all things, having promise of the life that now is, and of that which is to come (1 Timothy 4:7–8). This is a faithful saying, for they labour and suffer reproach because they trust in the living God, who is the Saviour of all men, specially of those that believe (1 Timothy 4:9–11). Timothy is to let no man despise his youth, but be an example of the believers in word, in conversation, in charity, in spirit, in faith, in purity (1 Timothy 4:12). Till Paul comes, he is to give attendance to reading, to exhortation, to doctrine, and not neglect the gift that is in him, given by prophecy with the laying on of the hands of the presbytery (1 Timothy 4:13–14). He is to meditate upon these things and take heed unto himself and the doctrine, for in doing this he shall both save himself and them that hear him (1 Timothy 4:15–16).",
    5: "Paul says Timothy is not to rebuke an elder, but intreat him as a father, the younger men as brethren, the elder women as mothers, and the younger as sisters, with all purity (1 Timothy 5:1–2). He is to honour widows that are widows indeed, but if a widow have children or nephews, let them learn first to shew piety at home and requite their parents (1 Timothy 5:3–4). A widow indeed, and desolate, trusteth in God and continueth in supplications and prayers night and day, but she that liveth in pleasure is dead while she liveth (1 Timothy 5:5–6). If any provide not for his own, and specially for those of his own house, he hath denied the faith and is worse than an infidel (1 Timothy 5:7–8). A widow is not to be taken into the number under threescore years old, having been the wife of one man and well reported of for good works (1 Timothy 5:9–10). Paul would have the younger widows marry, bear children, guide the house, and give none occasion to the adversary to speak reproachfully, for some are already turned aside after Satan (1 Timothy 5:11–15). If any believing man or woman have widows, let them relieve them, that the church may relieve them that are widows indeed (1 Timothy 5:16). The elders that rule well are counted worthy of double honour, for the scripture says not to muzzle the ox that treadeth out the corn and that the labourer is worthy of his reward (1 Timothy 5:17–18). Against an elder Timothy is to receive no accusation but before two or three witnesses, and he is charged before God, and the Lord Jesus Christ, and the elect angels to do nothing by partiality, to lay hands suddenly on no man, and to keep himself pure (1 Timothy 5:19–22). He is to drink no longer water, but use a little wine for his stomach's sake and his often infirmities (1 Timothy 5:23). Some men's sins are open beforehand and some they follow after, and likewise good works are manifest beforehand and cannot be hid (1 Timothy 5:24–25).",
    6: "Paul says that servants under the yoke are to count their own masters worthy of all honour, that the name of God and his doctrine be not blasphemed, and those with believing masters are not to despise them, because they are brethren, but rather do them service (1 Timothy 6:1–2). If any man teach otherwise and consent not to the wholesome words of our Lord Jesus Christ, he is proud, knowing nothing, but doting about questions and strifes of words, supposing that gain is godliness (1 Timothy 6:3–5). But godliness with contentment is great gain, for we brought nothing into this world and can carry nothing out, and having food and raiment let us be therewith content (1 Timothy 6:6–8). They that will be rich fall into temptation and a snare, and the love of money is the root of all evil, which some coveted after and pierced themselves through with many sorrows (1 Timothy 6:9–10). Timothy, as a man of God, is to flee these things, follow after righteousness, godliness, faith, love, patience, and meekness, fight the good fight of faith, and lay hold on eternal life (1 Timothy 6:11–12). Paul charges him in the sight of God and of Christ Jesus, who before Pontius Pilate witnessed a good confession, to keep the commandment without spot until the appearing of our Lord Jesus Christ, whom God will shew, the blessed and only Potentate, the King of kings, and Lord of lords (1 Timothy 6:13–16). The rich in this world are charged not to be highminded nor trust in uncertain riches but in the living God, to do good, to be rich in good works, ready to distribute, and to lay hold on eternal life (1 Timothy 6:17–19). Timothy is to keep that which is committed to his trust, avoiding profane and vain babblings and oppositions of science falsely so called (1 Timothy 6:20–21).",
}

WWA = {
    1: "1 Timothy opens Paul's letters to fellow workers, after his letters to churches. Paul writes to Timothy, whom he left at Ephesus, telling him to charge some not to teach other doctrine, to hold faith and a good conscience, and giving thanks for the mercy he himself received (1:1-20). Chapter 2 turns to prayer and conduct in public worship.",
    2: "Chapter 1 ended with Timothy charged to war a good warfare and to hold faith and a good conscience (1:18-19). Chapter 2 gives the first order of church life: prayer for all men and for kings, one God and one mediator, and instructions for men and women in the assembly (2:1-15). Chapter 3 gives the qualifications of bishops and deacons.",
    3: "Chapter 2 ended with instructions on conduct in worship (2:8-15). Chapter 3 lists the qualifications of a bishop and of deacons and closes with the church as the pillar and ground of the truth and the mystery of godliness (3:1-16). Chapter 4 warns of those who will depart from the faith.",
    4: "Chapter 3 ended with the great mystery of godliness, God manifest in the flesh (3:16). Chapter 4 warns of those who forbid marriage and certain meats and tells Timothy to be a good minister, to exercise himself unto godliness, and to be an example of the believers (4:1-16). Chapter 5 gives rules for widows and elders.",
    5: "Chapter 4 ended with Timothy told to take heed unto himself and unto the doctrine (4:16). Chapter 5 tells how to treat older and younger believers as family, care for widows, honour elders, and act without partiality (5:1-25). Chapter 6 deals with servants, false teachers, money, and a final charge.",
    6: "Chapter 5 ended with good works that cannot be hid (5:25). Chapter 6 speaks to servants, warns against teachers who think gain is godliness, praises godliness with contentment, and gives Timothy his final charge to fight the good fight and keep what is committed to his trust (6:1-21). 2 Timothy follows.",
}

KEY_FIGURES = {
    1: [
        ("Paul", "Writes as an apostle, tells how he obtained mercy though he was a blasphemer, and delivers Hymenaeus and Alexander unto Satan (1:1,12-16,20)."),
        ("Timothy", "Paul's own son in the faith, left at Ephesus to charge some to teach no other doctrine and to war a good warfare (1:2-3,18)."),
        ("Some who teach other doctrine", "Give heed to fables and endless genealogies and desire to be teachers of the law without understanding it (1:3-7)."),
        ("Hymenaeus and Alexander", "Have put away a good conscience and made shipwreck of the faith (1:19-20)."),
        ("God our Saviour and Christ Jesus", "Christ enabled Paul and counted him faithful, and came into the world to save sinners (1:1,12-15)."),
    ],
    2: [
        ("Paul", "Exhorts the church to pray and says he was ordained a preacher, an apostle, and a teacher of the Gentiles (2:1,7-8)."),
        ("Men and women of the congregation", "Men are told to pray without wrath, and women are told about dress, learning, and teaching (2:8-12)."),
        ("God our Saviour", "Will have all men to be saved and is the one God (2:3-5)."),
        ("Christ Jesus", "The one mediator between God and men, who gave himself a ransom for all (2:5-6)."),
        ("Adam and Eve", "Named as the ground for the instruction: Adam was first formed, and the woman being deceived was in the transgression (2:13-14)."),
    ],
    3: [
        ("The bishop", "A man who desires the office, who must be blameless, apt to teach, and rule his own house well (3:1-7)."),
        ("The deacons", "Must be grave, not doubletongued, first proved, and hold the mystery of the faith (3:8-10,12-13)."),
        ("Their wives", "Must be grave, not slanderers, sober, and faithful in all things (3:11)."),
        ("Paul", "Hopes to come shortly and writes so that Timothy may know how to behave in the house of God (3:14-15)."),
        ("Timothy", "The one who is to know how to behave in the house of God (3:15)."),
        ("God manifest in the flesh", "The subject of the mystery of godliness, seen of angels and received up into glory (3:16)."),
    ],
    4: [
        ("The Spirit", "Speaketh expressly that some shall depart from the faith in the latter times (4:1)."),
        ("The teachers of seducing spirits", "Speak lies in hypocrisy, with their conscience seared with a hot iron, and forbid to marry and to eat meats (4:1-3)."),
        ("Timothy", "Told to exercise himself unto godliness, be an example of the believers, and give attendance to reading, exhortation, and doctrine (4:6-16)."),
        ("Paul and his fellow labourers", "Labour and suffer reproach because they trust in the living God (4:10)."),
        ("The presbytery", "Laid their hands on Timothy when the gift was given by prophecy (4:14)."),
        ("God", "Created meats to be received with thanksgiving, and is the Saviour of all men, specially of those that believe (4:3-4,10)."),
    ],
    5: [
        ("Timothy", "Told how to treat each group in the church, to avoid partiality, and to keep himself pure (5:1-2,21-22)."),
        ("Older and younger men and women", "To be treated as fathers, brethren, mothers, and sisters, with all purity (5:1-2)."),
        ("Widows indeed", "Desolate, they trust in God and continue in supplications and prayers night and day, and are to be honoured (5:3,5)."),
        ("The children and nephews of widows", "Told to shew piety at home and requite their parents (5:4,8,16)."),
        ("The younger widows", "Told to marry, bear children, and guide the house, lest they be idle and give the adversary occasion (5:11-15)."),
        ("The elders that rule well", "Counted worthy of double honour, and accusations against them need two or three witnesses (5:17-20)."),
    ],
    6: [
        ("Servants and believing masters", "Servants are to count their masters worthy of honour, and those with believing masters are to do them service (6:1-2)."),
        ("The teachers of other doctrine", "Proud, doting about strifes of words, and supposing that gain is godliness (6:3-5)."),
        ("They that will be rich", "Fall into temptation and a snare and into many foolish and hurtful lusts (6:9-10)."),
        ("Timothy, the man of God", "Told to flee these things, follow after righteousness, fight the good fight, and keep what is committed to his trust (6:11-14,20)."),
        ("God and Christ Jesus", "God quickeneth all things and Christ Jesus witnessed a good confession before Pontius Pilate (6:13-16)."),
        ("The rich in this world", "Charged not to be highminded or trust in uncertain riches, but to do good and be ready to distribute (6:17-19)."),
    ],
}

THEMES = {
    1: [
        "Paul says the end of the commandment is charity out of a pure heart, and of a good conscience, and of faith unfeigned, and that fables and endless genealogies lead the other way (1:3-7).",
        "The law is good, if a man use it lawfully, for it is made for the lawless and disobedient and for what is contrary to sound doctrine (1:8-11).",
        "Paul was a blasphemer, and a persecutor, and injurious, yet obtained mercy, and Christ Jesus came into the world to save sinners, of whom he is chief (1:12-16).",
        "Paul thanks Christ Jesus, who counted him faithful and put him into the ministry, so his service is a gift and not his own doing (1:12-14).",
        "Timothy is to war a good warfare, holding faith and a good conscience, which some put away and made shipwreck of the faith (1:18-20).",
    ],
    2: [
        "Supplications, prayers, intercessions, and giving of thanks are to be made for all men, for kings, and for all in authority, so that they may lead a quiet and peaceable life (2:1-4).",
        "There is one God, and one mediator between God and men, the man Christ Jesus, who gave himself a ransom for all (2:5-6).",
        "The aim of the prayer is a quiet and peaceable life in all godliness and honesty (2:1-2).",
        "Men are to pray every where, lifting up holy hands, without wrath and doubting (2:8).",
        "Women are given instruction about dress, learning, and teaching, and the reasons given come from the creation of Adam and Eve (2:9-15).",
    ],
    3: [
        "The bishop and the deacons are described mostly by their character and conduct, such as blameless, grave, and sober (3:1-13).",
        "A bishop must rule his own house well, for it shows whether he can take care of the church of God (3:4-5,12).",
        "A bishop must have a good report of them which are without, and deacons are to be first proved (3:7,10).",
        "The church is the house of God, the church of the living God, the pillar and ground of the truth (3:14-15).",
        "Great is the mystery of godliness: God was manifest in the flesh, justified in the Spirit, and received up into glory (3:16).",
    ],
    4: [
        "Every creature of God is good, and nothing is to be refused, if it be received with thanksgiving, for it is sanctified by the word of God and prayer (4:3-5).",
        "The Spirit speaketh expressly that some shall depart from the faith, giving heed to seducing spirits and doctrines of devils (4:1-3).",
        "Bodily exercise profiteth little, but godliness is profitable unto all things, having promise of the life that now is and of that which is to come (4:7-10).",
        "Timothy is told to let no man despise his youth, but be an example of the believers in word, in conversation, in charity, in spirit, in faith, in purity (4:12).",
        "Timothy is to give attendance to reading, to exhortation, to doctrine, and not neglect the gift that is in him (4:13-16).",
    ],
    5: [
        "The church is to honour widows that are widows indeed, and the godly are to relieve their own widows so the church can help those who have no one (5:3-5,9-10,16).",
        "If any provide not for his own, and specially for those of his own house, he hath denied the faith and is worse than an infidel (5:4,8,16).",
        "Timothy is to treat older and younger people as fathers, brethren, mothers, and sisters, with all purity (5:1-2).",
        "The elders that rule well are counted worthy of double honour, and an accusation against an elder needs two or three witnesses (5:17-20).",
        "Timothy is told to do nothing by partiality, to lay hands suddenly on no man, and to keep himself pure (5:21-22).",
    ],
    6: [
        "Godliness with contentment is great gain, and having food and raiment let us be therewith content (6:6-8).",
        "They that will be rich fall into temptation and a snare, and the love of money is the root of all evil (6:9-10).",
        "Timothy is told to flee these things, follow after righteousness, godliness, faith, love, patience, and meekness, and to fight the good fight of faith (6:11-12).",
        "The rich are charged to trust not in uncertain riches but in the living God, to do good, and to lay hold on eternal life (6:17-19).",
        "Timothy is to keep that which is committed to his trust and avoid profane and vain babblings (6:20-21).",
    ],
}

AUDIENCE_FIXES = {
    1: "Timothy, left to face false teachers in a busy city, would have heard Paul remind him that the aim of the charge is love and that mercy reached even the chief of sinners.",
    2: "A church in a city full of pagan temples would have heard that prayer is to be made for all men, even kings, because one God and one mediator wants all to be saved.",
    3: "Believers choosing leaders in a new church would have heard that the test is character, home life, and a good report from outsiders.",
    5: "Families and widows in the church, and its older men who led it, would have heard how God's household is to care for the helpless and treat its leaders fairly.",
}


def norm(text):
    return text.replace("’", "'")


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "54_1_timothy.json"
    data = load(path)
    for n in range(1, 7):
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


def apply_historical_moments():
    path = ROOT / "historical_moments" / "18_thessalonians_revelation.json"
    data = load(path)
    key = f"{BOOK} 1"
    old = " Many scholars think 1 and 2 Timothy and Titus were written later in Paul's name."
    if old in data[key]:
        data[key] = data[key].replace(old, "")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_book_overview():
    path = ROOT / "book_overviews" / "08_pauls_letters.json"
    data = load(path)
    book = data[BOOK]
    book["author"] = "Paul the apostle, writing to Timothy (1 Timothy 1:1-2)."
    for figure in book["keyFigures"]:
        if figure["name"] == "Timothy":
            figure["description"] = "Paul's own son in the faith, left in Ephesus to confront false teaching."
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_FIXES = [
    ("If God could save the worst sinner, He can save anyone.", "If God could save the worst sinner, he can save anyone."),
    ("God wants everyone to hear the gospel. He “will have all men", "God wants everyone to hear the gospel; he “will have all men"),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "08_pauls_letters.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("\n# 1 Timothy") + 1
    end = text.index("\n# 2 Timothy", start)
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
    apply_historical_moments()
    apply_book_overview()
    apply_story_fixes()
