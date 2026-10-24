#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Apply the completed editorial review for 2 Thessalonians to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BOOK = "2 Thessalonians"


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


SUMMARY = {
    1: ("Paul, and Silvanus, and Timotheus write unto the church of the Thessalonians in God our Father and the Lord Jesus Christ (2 Thessalonians 1:1–2). They are bound to thank God always for them, because their faith groweth exceedingly and the charity of every one of them toward each other aboundeth (2 Thessalonians 1:3). They glory in them in the churches of God for their patience and faith in all their persecutions and tribulations, a manifest token of the righteous judgment of God, that they may be counted worthy of the kingdom of God (2 Thessalonians 1:4–5). God will recompense tribulation to them that trouble them and give rest to the troubled when the Lord Jesus shall be revealed from heaven with his mighty angels in flaming fire (2 Thessalonians 1:6–8). Those that know not God and obey not the gospel shall be punished with everlasting destruction from the presence of the Lord, when he shall come to be glorified in his saints (2 Thessalonians 1:8–10). Paul prays that God would count them worthy of this calling and fulfil the work of faith with power, that the name of the Lord Jesus Christ may be glorified in them (2 Thessalonians 1:11–12)."),
    2: ("Paul beseeches the Thessalonians, by the coming of our Lord Jesus Christ and our gathering together unto him, not to be soon shaken in mind or troubled by spirit, word, or letter as from him, as that the day of Christ is at hand (2 Thessalonians 2:1–2). That day shall not come except there come a falling away first, and that man of sin be revealed, the son of perdition, who exalteth himself above all that is called God and sitteth in the temple of God, shewing himself that he is God (2 Thessalonians 2:3–4). They know what withholdeth that he might be revealed in his time, for the mystery of iniquity doth already work, only he who now letteth will let, until he be taken out of the way (2 Thessalonians 2:5–7). Then shall that Wicked be revealed, whom the Lord shall consume with the spirit of his mouth and destroy with the brightness of his coming (2 Thessalonians 2:8). His coming is after the working of Satan with all power and signs and lying wonders, and God sends strong delusion on them that received not the love of the truth (2 Thessalonians 2:9–12). Paul thanks God that he hath from the beginning chosen them to salvation through sanctification of the Spirit and belief of the truth (2 Thessalonians 2:13–14). They are to stand fast and hold the traditions they were taught, and he prays that the Lord Jesus Christ and God our Father comfort their hearts and stablish them in every good word and work (2 Thessalonians 2:15–17)."),
    3: ("Paul asks the Thessalonians to pray for him, that the word of the Lord may have free course and be glorified, and that he may be delivered from unreasonable and wicked men, for all men have not faith (2 Thessalonians 3:1–2). The Lord is faithful, who shall stablish them and keep them from evil, and Paul prays that the Lord direct their hearts into the love of God and into the patient waiting for Christ (2 Thessalonians 3:3–5). He commands them in the name of the Lord Jesus Christ to withdraw from every brother that walketh disorderly and not after the tradition they received (2 Thessalonians 3:6). He and his companions wrought with labour and travail night and day, that they might not be chargeable to any, to make themselves an ensample, and the rule was, if any would not work, neither should he eat (2 Thessalonians 3:7–10). He hears of some that walk among them disorderly, working not at all, but are busybodies, and he commands that with quietness they work and eat their own bread (2 Thessalonians 3:11–12). The rest are to be not weary in well doing, and if any man obey not this word, they are to note that man that he may be ashamed, yet count him not as an enemy, but admonish him as a brother (2 Thessalonians 3:13–15). Paul closes with a prayer that the Lord of peace give them peace always, a salutation with his own hand, which is the token in every epistle, and the grace of our Lord Jesus Christ (2 Thessalonians 3:16–18)."),
}

WWA = {
    1: "2 Thessalonians follows 1 Thessalonians and was written to the same church soon after. Paul, Silvanus, and Timotheus thank God for the Thessalonians' growing faith and love, tell them their sufferings are a token of the righteous judgment of God, and promise rest when the Lord Jesus is revealed from heaven (1:1-12). Chapter 2 corrects a false report about the day of Christ.",
    2: "Chapter 1 ended with a prayer that the name of the Lord Jesus Christ be glorified in the Thessalonians (1:12). Chapter 2 asks them not to be shaken by claims that the day of Christ is at hand, tells of the falling away and the man of sin, and thanks God for choosing them (2:1-17). Chapter 3 turns to prayer and to the disorderly among them.",
    3: "Chapter 2 ended with a prayer that the Lord comfort their hearts and stablish them in every good word and work (2:17). Chapter 3 asks for their prayers, calls them to withdraw from every brother that walketh disorderly, and urges all to work quietly and be not weary in well doing (3:1-18). 1 Timothy, the first of Paul's letters to a fellow worker, follows.",
}

KEY_FIGURES = {
    1: [
        ("Paul, Silvanus, and Timotheus", "The writers, who thank God for the Thessalonians, glory in them in the churches, and pray for them (1:1-4,11)."),
        ("The church of the Thessalonians", "Praised for faith that groweth exceedingly and for patience in all their persecutions and tribulations (1:3-4)."),
        ("Them that trouble the believers", "Those to whom God will recompense tribulation (1:6)."),
        ("Them that know not God and obey not the gospel", "Those who shall be punished with everlasting destruction from the presence of the Lord (1:8-9)."),
        ("The Lord Jesus and his mighty angels", "Revealed from heaven in flaming fire to give rest to the troubled and to be glorified in his saints (1:7-10)."),
        ("God our Father", "Counts believers worthy of the kingdom, recompenses tribulation, and is asked to fulfil the work of faith with power (1:5-6,11)."),
    ],
    2: [
        ("The Thessalonian believers", "Told not to be soon shaken in mind, to stand fast, and to hold the traditions (2:2,15)."),
        ("Paul", "Teaches about the day of Christ, gives thanks, and prays for the believers (2:1,13,16-17)."),
        ("The man of sin and Satan", "The son of perdition who exalteth himself and sitteth in the temple of God, coming after the working of Satan with lying wonders (2:3-4,9)."),
        ("He who now letteth", "Withholds the revealing of the man of sin until he be taken out of the way (2:6-7)."),
        ("Them that perish", "Deceived because they received not the love of the truth (2:10-12)."),
        ("The Lord Jesus Christ and God", "The Lord shall consume the Wicked with the spirit of his mouth, and God chose the believers to salvation and sends strong delusion on those who believe not (2:8,11,13)."),
    ],
    3: [
        ("Paul, Silvanus, and Timotheus", "Ask for prayer, give commands, and set an ensample by working night and day (3:1,6-9)."),
        ("The Thessalonian believers", "Asked to pray, withdraw from the disorderly, and be not weary in well doing (3:1,6,13)."),
        ("Brethren who walk disorderly", "Working not at all but busybodies, they are commanded to work with quietness and eat their own bread (3:11-12)."),
        ("Unreasonable and wicked men", "Those from whom Paul asks to be delivered (3:2)."),
        ("The Lord", "Faithful, who shall stablish them, keep them from evil, direct their hearts, and give peace (3:3,5,16)."),
        ("The man who obeys not this word", "To be noted that he may be ashamed, yet admonished as a brother (3:14-15)."),
    ],
}

THEMES = {
    1: {
        "Growing faith and love": "Paul is bound to thank God because their faith groweth exceedingly and the charity of every one of them toward each other aboundeth (1:3).",
        "Endurance in persecution": "The Thessalonians show patience and faith in all their persecutions and tribulations, so that Paul glories in them in the churches of God (1:4).",
        "God's justice and relief at Christ's return": "It is a righteous thing with God to recompense tribulation to them that trouble you, and to give rest to the troubled when the Lord Jesus shall be revealed from heaven (1:5-10).",
        "Christ glorified in his people": "When the Lord shall come, he is to be glorified in his saints and admired in all them that believe (1:10).",
        "Prayer that God would complete the work": "Paul prays that God would count them worthy of this calling and fulfil the work of faith with power, that the name of the Lord Jesus Christ may be glorified in them (1:11-12).",
    },
    2: {
        "Not being shaken or deceived": "Paul asks them not to be soon shaken in mind or troubled by any word or letter as from him that the day of Christ is at hand, and says, Let no man deceive you by any means (2:1-3).",
        "Opposition to God and its end": "The man of sin exalteth himself above all that is called God, but the Lord shall consume him with the spirit of his mouth and destroy him with the brightness of his coming (2:3-8).",
        "Truth and deception": "Those that perish received not the love of the truth, so God sends strong delusion that they should believe a lie (2:9-12).",
        "God's choice and calling": "God hath from the beginning chosen them to salvation through sanctification of the Spirit and belief of the truth, and called them by the gospel (2:13-14).",
        "Standing firm in what was taught": "They are to stand fast and hold the traditions taught by word or epistle, and to be stablished by the Lord in every good word and work (2:15-17).",
    },
    3: {
        "Prayer and trust in the faithful Lord": "Paul asks for prayer that the word of the Lord may have free course, and says the Lord is faithful, who shall stablish them and keep them from evil (3:1-5).",
        "Honest work and not being a burden": "The missionaries wrought with labour and travail night and day, and the rule is that if any would not work, neither should he eat (3:7-12).",
        "Example and imitation": "Paul and his companions made themselves an ensample unto the Thessalonians to follow (3:7-9).",
        "Discipline with restoration in view": "The one who obeys not this word is to be noted that he may be ashamed, yet counted not as an enemy but admonished as a brother (3:14-15).",
        "Perseverance in doing good and peace": "The believers are to be not weary in well doing, and Paul prays that the Lord of peace give them peace always by all means (3:13,16).",
    },
}


def norm(text):
    return text.replace("’", "'")


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "53_2_thessalonians.json"
    data = load(path)
    for n in range(1, 4):
        entry = data[f"{BOOK} {n}"]
        entry["summary"] = SUMMARY[n]
        entry["whereWeAre"] = WWA[n]
        entry["keyFigures"] = [{"name": a, "role": b} for a, b in KEY_FIGURES[n]]
        theme_map = {norm(k): v for k, v in THEMES[n].items()}
        for theme in entry["keyThemes"]:
            if norm(theme["theme"]) not in theme_map:
                raise SystemExit(f"{BOOK} {n}: no explanation for {theme['theme']!r}")
            theme["explanation"] = theme_map[norm(theme["theme"])]
            refs = []
            for ref in theme["references"]:
                refs.extend(json.loads(ref) if ref.startswith("[") else [ref])
            theme["references"] = refs
        if len(entry["keyThemes"]) != len(theme_map):
            raise SystemExit(f"{BOOK} {n}: theme count mismatch")
        if len(entry["whereWeAre"]) > 600 or len(entry["keyFigures"]) > 6:
            raise SystemExit(f"{BOOK} {n}: WWA {len(entry['whereWeAre'])} chars or too many figures")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


AUDIENCE_FIXES = {
    1: "Persecuted believers would have heard that their endurance was a token of the righteous judgment of God and that rest would come when the Lord Jesus is revealed from heaven.",
    2: "Believers upset by rumours about the end would have heard calm instruction to stand fast and hold the traditions they were taught, with a prayer that God stablish them in every good word and work.",
}


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
    old = " Some scholars think it was written later in Paul's name."
    if old not in data[key]:
        raise SystemExit("historical moment text changed")
    data[key] = data[key].replace(old, "")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_book_overview():
    path = ROOT / "book_overviews" / "08_pauls_letters.json"
    data = load(path)
    book = data[BOOK]
    book["author"] = "Paul the apostle, with Silvanus and Timothy named in the greeting (2 Thessalonians 1:1; 3:17)."
    for movement in book["movements"]:
        movement["description"] = movement["description"].replace(
            "rebellion and the 'man of lawlessness.'", "the falling away and the man of sin."
        )
    for figure in book["keyFigures"]:
        if figure["name"] == "The man of lawlessness":
            figure["name"] = "The man of sin"
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_FIXES = [
    ("bring relief to His people", "bring relief to his people"),
    ("God will set things right. He will repay with trouble", "God will set things right; he will repay with trouble"),
    ("Those who reject Him “shall", "Those who reject him “shall"),
    ("worthy of His calling", "worthy of his calling"),
    ("until He comes.", "until he comes."),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "08_pauls_letters.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("\n# 2 Thessalonians") + 1
    end = text.index("\n# 1 Timothy", start)
    section = text[start:end]
    for old, new in STORY_FIXES:
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
