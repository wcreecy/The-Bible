#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Apply the completed editorial review for 1 Thessalonians to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BOOK = "1 Thessalonians"


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


SUMMARY = {
    1: ("Paul, and Silvanus, and Timotheus write unto the church of the Thessalonians, which is in God the Father and in the Lord Jesus Christ (1 Thessalonians 1:1). They thank God always for them, remembering their work of faith, and labour of love, and patience of hope in our Lord Jesus Christ (1 Thessalonians 1:2–3). They know their election of God, because the gospel came not in word only, but also in power, and in the Holy Ghost (1 Thessalonians 1:4–5). The Thessalonians became followers of the missionaries and of the Lord, receiving the word in much affliction, with joy of the Holy Ghost, and ensamples to all that believe in Macedonia and Achaia (1 Thessalonians 1:6–8). Others tell how they turned to God from idols to serve the living and true God, and to wait for his Son from heaven, even Jesus, which delivered us from the wrath to come (1 Thessalonians 1:9–10)."),
    2: ("Paul reminds the Thessalonians that their coming to them was not in vain, for after they had suffered and were shamefully entreated at Philippi, they were bold in their God to speak the gospel with much contention (1 Thessalonians 2:1–2). Their exhortation was not of deceit, nor of uncleanness, nor in guile; they used no flattering words nor a cloke of covetousness, but were gentle among them, even as a nurse cherisheth her children (1 Thessalonians 2:3–8). Labouring night and day, they would not be chargeable unto any, and they exhorted each one as a father doth his children to walk worthy of God (1 Thessalonians 2:9–12). They thank God that the Thessalonians received the word of God, not as the word of men, which effectually worketh in them that believe (1 Thessalonians 2:13). They suffered like things of their own countrymen, as the churches in Judaea did of the Jews, who killed the Lord Jesus and their own prophets and forbid the missionaries to speak to the Gentiles (1 Thessalonians 2:14–16). Taken from them for a short time in presence, not in heart, Paul would have come again and again, but Satan hindered him, and they are his hope, and joy, and crown of rejoicing at the coming of the Lord Jesus (1 Thessalonians 2:17–20)."),
    3: ("When Paul could no longer forbear, he thought it good to be left at Athens alone and sent Timotheus, his brother and fellowlabourer in the gospel of Christ, to establish and comfort the Thessalonians, that no man should be moved by these afflictions (1 Thessalonians 3:1–3). He had told them before that they should suffer tribulation, and he feared lest the tempter had tempted them and his labour be in vain (1 Thessalonians 3:4–5). Timotheus has come with good tidings of their faith and charity, and of their good remembrance of the missionaries, and Paul is comforted, for now he lives, if they stand fast in the Lord (1 Thessalonians 3:6–8). He cannot thank God enough for their joy and prays night and day that he might see their face and perfect that which is lacking in their faith (1 Thessalonians 3:9–10). He prays that God and the Lord Jesus direct his way to them, that the Lord make them to increase and abound in love, and that he stablish their hearts unblameable in holiness at the coming of our Lord Jesus Christ with all his saints (1 Thessalonians 3:11–13)."),
    4: ("Paul beseeches the Thessalonians by the Lord Jesus to walk and to please God as they have received, and to abound more and more (1 Thessalonians 4:1–2). This is the will of God, even their sanctification, that they abstain from fornication, that each possess his vessel in sanctification and honour, and that no man go beyond and defraud his brother, for the Lord is the avenger of all such (1 Thessalonians 4:3–8). As touching brotherly love, they are taught of God to love one another, and he urges them to increase more and more (1 Thessalonians 4:9–10). They are to study to be quiet, to do their own business, and to work with their own hands, that they may walk honestly toward them that are without (1 Thessalonians 4:11–12). Paul would not have them ignorant concerning them which are asleep, that they sorrow not, even as others which have no hope, for if we believe that Jesus died and rose again, even so them also which sleep in Jesus will God bring with him (1 Thessalonians 4:13–14). The Lord himself shall descend from heaven with a shout, with the voice of the archangel, and with the trump of God, the dead in Christ shall rise first, and then the living shall be caught up together with them in the clouds, to meet the Lord in the air, and so shall be ever with the Lord (1 Thessalonians 4:15–18)."),
    5: ("Paul says they know perfectly that the day of the Lord so cometh as a thief in the night, and when they shall say, Peace and safety, then sudden destruction cometh upon them (1 Thessalonians 5:1–3). But the Thessalonians are not in darkness; they are the children of light, and the children of the day, and are to watch and be sober, putting on the breastplate of faith and love and for an helmet the hope of salvation (1 Thessalonians 5:4–8). God hath not appointed them to wrath, but to obtain salvation by our Lord Jesus Christ, who died for them that, whether they wake or sleep, they should live together with him (1 Thessalonians 5:9–11). They are to know them which labour among them and are over them in the Lord, to esteem them very highly in love, and to be at peace among themselves (1 Thessalonians 5:12–13). They are to warn the unruly, comfort the feebleminded, support the weak, be patient toward all men, and see that none render evil for evil (1 Thessalonians 5:14–15). They are to rejoice evermore, pray without ceasing, in every thing give thanks, quench not the Spirit, prove all things, and hold fast that which is good (1 Thessalonians 5:16–22). Paul prays that the very God of peace sanctify them wholly, for faithful is he that calleth them, who also will do it, and he closes with a request for prayer, greetings, and grace (1 Thessalonians 5:23–28)."),
}

WWA = {
    1: "1 Thessalonians follows Colossians among Paul's letters. Paul, Silvanus, and Timotheus write to a young church at Thessalonica, thanking God for their work of faith, labour of love, and patience of hope, and for how they turned from idols to serve the living God and wait for his Son (1:1-10). Chapter 2 recalls how the missionaries lived among them.",
    2: "Chapter 1 ended with the Thessalonians waiting for God's Son from heaven (1:10). Chapter 2 recalls how Paul, Silvanus, and Timotheus lived among them with pure motives and a parent's care, thanks God that they received the word, and tells of Paul's longing to see them again (2:1-20). Chapter 3 tells how Timotheus was sent to them.",
    3: "Chapter 2 ended with Paul calling the Thessalonians his hope, joy, and crown at Christ's coming (2:19-20). Chapter 3 tells how Paul sent Timotheus from Athens to strengthen them, how glad he was at the good report, and how he prays that they abound in love (3:1-13). Chapter 4 turns to holy living and the hope of Christ's return.",
    4: "Chapter 3 ended with a prayer that their hearts be established unblameable in holiness at Christ's coming (3:13). Chapter 4 teaches holy living, brotherly love, and honest work, and comforts those who grieve for believers who have died with the hope of the Lord's return (4:1-18). Chapter 5 continues with readiness for the day of the Lord.",
    5: "Chapter 4 ended with believers comforting one another with words about the Lord's coming (4:18). Chapter 5 says the day of the Lord will come as a thief in the night, calls believers children of light, gives short commands for church life, and closes with prayer and greetings (5:1-28). 2 Thessalonians follows.",
}

KEY_FIGURES = {
    1: [
        ("Paul, Silvanus, and Timotheus", "The writers, who thank God for the Thessalonians, pray for them, and remember how the gospel came to them in power (1:1-5)."),
        ("The church of the Thessalonians", "Praised for their work of faith, labour of love, and patience of hope, they became followers of the Lord and ensamples to all that believe (1:3,6-7)."),
        ("Believers in Macedonia and Achaia", "Those to whom the Thessalonians were ensamples, and from whom others report how they turned from idols (1:7-9)."),
        ("God, the Lord Jesus Christ, and the Holy Ghost", "God elected them, raised his Son from the dead, and Jesus delivered us from the wrath to come, while the Holy Ghost gave power and joy (1:4-6,10)."),
    ],
    2: [
        ("Paul, Silvanus, and Timotheus", "Were bold to speak the gospel after being shamefully entreated, were gentle as a nurse, and laboured night and day (2:2,7,9)."),
        ("The Thessalonian believers", "Received the word of God and suffered like things of their own countrymen (2:13-14)."),
        ("The churches of God in Judaea", "Those whom the Thessalonians followed in suffering for Christ Jesus (2:14)."),
        ("The Jews who killed the Lord Jesus", "Killed the Lord Jesus and their own prophets, persecuted the missionaries, and forbid them to speak to the Gentiles (2:15-16)."),
        ("Satan", "Hindered Paul from coming to them again (2:18)."),
        ("God", "Allowed the missionaries to be put in trust with the gospel, tries our hearts, and calls believers into his kingdom and glory (2:4,12)."),
    ],
    3: [
        ("Paul", "Could forbear no longer, sent Timotheus, and prays night and day to see them (3:1-2,10)."),
        ("Timotheus", "Sent to establish and comfort them, he returned with good tidings of their faith and charity (3:2,6)."),
        ("The Thessalonian believers", "Under afflictions, they stand fast in the Lord, to Paul's comfort (3:3,7-8)."),
        ("The tempter", "Feared by Paul to have tempted them so that his labour would be in vain (3:5)."),
        ("God our Father and our Lord Jesus Christ", "Asked to direct Paul's way, make them abound in love, and stablish their hearts unblameable in holiness (3:11-13)."),
    ],
    4: [
        ("The Thessalonian believers", "Taught to walk and please God, abstain from fornication, love one another, and work with their own hands (4:1-3,9-11)."),
        ("Paul, Silvanus, and Timotheus", "Beseech and exhort them by the Lord Jesus and give the word of the Lord about those who sleep (4:1,15)."),
        ("The Gentiles which know not God", "Held up as those who live in the lust of concupiscence (4:5)."),
        ("Them that are without", "Outsiders toward whom believers are to walk honestly (4:12)."),
        ("Them which sleep in Jesus", "Those whom God will bring with him, and the dead in Christ who shall rise first (4:14,16)."),
        ("The Lord", "Shall descend from heaven with a shout, the voice of the archangel, and the trump of God (4:16)."),
    ],
    5: [
        ("The Thessalonian believers", "Children of light, they are told to watch and be sober, to comfort and edify one another, and to follow short commands for daily life (5:5-11,16-22)."),
        ("Paul, Silvanus, and Timotheus", "Teach about the day of the Lord, pray for the church, and ask for prayer (5:1,23,25)."),
        ("Those who say Peace and safety", "Those on whom sudden destruction cometh as travail upon a woman with child (5:3)."),
        ("Them which labour among them and are over them in the Lord", "Leaders whom the church is to know and esteem very highly in love (5:12-13)."),
        ("The God of peace and the Lord Jesus Christ", "God hath not appointed them to wrath, but to obtain salvation, and he will sanctify them wholly and do what he has called them to (5:9-10,23-24)."),
    ],
}

THEMES = {
    1: {
        "Faith, love and hope in action": "Paul remembers their work of faith, and labour of love, and patience of hope in our Lord Jesus Christ, showing that real faith shows itself in what people do (1:2-3).",
        "The gospel received with power and joy": "The gospel came not in word only, but in power, and in the Holy Ghost, and they received it in much affliction, with joy of the Holy Ghost (1:4-6).",
        "Being an example": "The Thessalonians became followers of the missionaries and of the Lord, and ensamples to all that believe in Macedonia and Achaia, so that their faith to God-ward is spread abroad (1:6-8).",
        "Turning from idols to the living God": "They turned to God from idols to serve the living and true God (1:9).",
        "Waiting for the Son from heaven": "They wait for his Son from heaven, whom he raised from the dead, even Jesus, which delivered us from the wrath to come (1:10).",
    },
    2: {
        "Integrity and pure motives in ministry": "The missionaries used no flattering words nor cloke of covetousness, nor sought glory of men, but spoke to please God, which trieth our hearts (2:3-6).",
        "Gentle care and parental love": "They were gentle among the Thessalonians as a nurse cherisheth her children, and exhorted each one as a father doth his children (2:7-12).",
        "Hard work and not being a burden": "Labouring night and day, the missionaries would not be chargeable unto any of them while they preached the gospel (2:9).",
        "The word of God at work": "The Thessalonians received the word not as the word of men, but as it is in truth, the word of God, which effectually worketh also in them that believe (2:13).",
        "Suffering for the faith and joy in fellowship": "They suffered like things of their own countrymen as the Judaean churches did, and Paul longs to see them again, for they are his hope, and joy, and crown of rejoicing (2:14-20).",
    },
    3: {
        "Concern for those suffering": "Paul could forbear no longer and sent Timotheus to establish and comfort the Thessalonians, that no man should be moved by these afflictions (3:1-5).",
        "Affliction expected": "Paul had told them before that they should suffer tribulation, and so it came to pass (3:3-4).",
        "Joy from the faith of others": "Timotheus's good tidings of their faith and charity comforted Paul, who says now we live, if ye stand fast in the Lord (3:6-9).",
        "Prayer for love that increases": "Paul prays night and day to see them and asks that the Lord make them to increase and abound in love one toward another, and toward all men (3:10-12).",
        "Holiness until Christ's coming": "Paul asks that the Lord stablish their hearts unblameable in holiness before God at the coming of our Lord Jesus Christ with all his saints (3:12-13).",
    },
    4: {
        "Sanctification and holy living": "The will of God is their sanctification, that they abstain from fornication and live in holiness and honour, for God hath not called us unto uncleanness, but unto holiness (4:1-8).",
        "Brotherly love": "They are taught of God to love one another, and Paul urges that they increase more and more (4:9-10).",
        "Quiet work and witness": "They are to study to be quiet, do their own business, and work with their own hands, that they may walk honestly toward them that are without (4:11-12).",
        "Hope in the face of death": "Believers do not sorrow as others which have no hope, for if we believe that Jesus died and rose again, God will bring with him them which sleep in Jesus (4:13-14).",
        "Being with the Lord always and mutual encouragement": "The dead in Christ shall rise first, the living shall be caught up with them to meet the Lord in the air, and so shall we ever be with the Lord, and they are to comfort one another with these words (4:16-18).",
    },
    5: {
        "Readiness for the day of the Lord": "The day of the Lord cometh as a thief in the night, so believers, who are children of light and of the day, are to watch and be sober (5:1-8).",
        "Salvation as God's appointment": "God hath not appointed us to wrath, but to obtain salvation by our Lord Jesus Christ, who died for us so that we should live together with him (5:9-10).",
        "Mutual care in the community": "Believers are to comfort and edify one another, esteem their leaders in love, warn the unruly, comfort the feebleminded, support the weak, and be patient toward all men (5:11-15).",
        "Joy, prayer and thanksgiving": "They are told to rejoice evermore, pray without ceasing, and in every thing give thanks, for this is the will of God in Christ Jesus concerning them (5:16-18).",
        "Discernment and God's sanctifying work": "They are to quench not the Spirit, prove all things, and hold fast that which is good, and the very God of peace will sanctify them wholly, for faithful is he that calleth them (5:19-24).",
    },
}


def norm(text):
    return text.replace("’", "'")


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "52_1_thessalonians.json"
    data = load(path)
    for n in range(1, 6):
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
    1: "Gentile believers who had turned from the gods of their city and had suffered for it would have heard that their faith was known across Macedonia and Achaia.",
    3: "Young believers under pressure, who may have feared that Paul had forgotten them, would have heard of his longing to see them and his prayer that they grow in love.",
    5: "Believers worried about the day of the Lord would have heard that they were children of light, not appointed to wrath, and received short commands for daily life together.",
}

CULTURE_FIXES = {
    4: [("one common formula reads ‘I was not, I was, I am not, I care not.’",
         "one common formula said that the dead person once was not, then was, and now is not and cares not.")],
    5: [("celebrated the ‘peace’ (pax) and ‘security’ (securitas) of Roman rule.",
         "celebrated the peace (pax) and security (securitas) of Roman rule.")],
}


def apply_chapter_context():
    path = ROOT / "chapter_context" / "39_thessalonians_philemon.json"
    data = load(path)
    for n, text in AUDIENCE_FIXES.items():
        data[f"{BOOK} {n}"]["audience"] = text
    for n, fixes in CULTURE_FIXES.items():
        for old, new in fixes:
            hits = 0
            for entry in data[f"{BOOK} {n}"]["culture"]:
                if old in entry["text"]:
                    entry["text"] = entry["text"].replace(old, new)
                    hits += 1
            if hits != 1:
                raise SystemExit(f"culture fix matched {hits} times: {old!r}")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_book_overview():
    path = ROOT / "book_overviews" / "08_pauls_letters.json"
    data = load(path)
    book = data[BOOK]
    book["author"] = "Paul the apostle, with Silvanus and Timothy named in the greeting (1 Thessalonians 1:1)."
    book["keyVerse"] = "1 Thessalonians 4:14"
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_FIXES = [
    ("will share in His return.", "will share in his return."),
    ("Whether they are alive or dead when He comes, they will live with Him.", "Whether they are alive or dead when he comes, they will live with him."),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "08_pauls_letters.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("\n# 1 Thessalonians") + 1
    end = text.index("\n# 2 Thessalonians", start)
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
    apply_book_overview()
    apply_story_fixes()
