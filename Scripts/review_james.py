#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Apply the completed editorial review for James to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BOOK = "James"


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


SUMMARY = {
    1: "James, a servant of God and of the Lord Jesus Christ, writes to the twelve tribes which are scattered abroad (James 1:1). He tells the brethren to count it all joy when they fall into divers temptations, knowing that the trying of their faith worketh patience, and to let patience have her perfect work (James 1:2–4). If any lack wisdom, let him ask of God, that giveth to all liberally, but let him ask in faith, nothing wavering, for a double minded man is unstable in all his ways (James 1:5–8). The brother of low degree is to rejoice in that he is exalted, and the rich in that he is made low, because as the flower of the grass he shall pass away (James 1:9–11). Blessed is the man that endureth temptation, for he shall receive the crown of life (James 1:12). No man is to say he is tempted of God, for God tempteth no man, but every man is tempted when he is drawn away of his own lust, which brings forth sin, and sin brings forth death, while every good gift and every perfect gift cometh down from the Father of lights (James 1:13–18). Every man is to be swift to hear, slow to speak, slow to wrath, to lay apart all filthiness and receive with meekness the engrafted word (James 1:19–21). They are to be doers of the word, and not hearers only, like a man who beholds his natural face in a glass and straightway forgetteth what manner of man he was (James 1:22–25). Pure religion and undefiled before God and the Father is to visit the fatherless and widows in their affliction, and to keep himself unspotted from the world (James 1:26–27).",
    2: "James tells his brethren not to hold the faith of our Lord Jesus Christ, the Lord of glory, with respect of persons (James 2:1). If a man with a gold ring in goodly apparel comes into the assembly, and a poor man in vile raiment, and they say to the rich Sit thou here in a good place and to the poor Stand thou there, they are partial in themselves and become judges of evil thoughts (James 2:2–4). God hath chosen the poor of this world rich in faith, and heirs of the kingdom, but they have despised the poor, though rich men oppress them and draw them before the judgment seats (James 2:5–7). If they fulfil the royal law, Thou shalt love thy neighbour as thyself, they do well, but if they have respect to persons they commit sin, for whosoever shall keep the whole law and yet offend in one point is guilty of all (James 2:8–11). They are to speak and do as they that shall be judged by the law of liberty, for he shall have judgment without mercy that hath shewed no mercy, and mercy rejoiceth against judgment (James 2:12–13). What doth it profit, though a man say he hath faith and have not works, as if one said to a naked and destitute brother Depart in peace, be warmed and filled, and gave him not those things which are needful, for faith, if it hath not works, is dead, being alone (James 2:14–17). The devils also believe, and tremble, and faith without works is dead (James 2:18–20). Abraham was justified by works when he offered Isaac his son upon the altar, faith wrought with his works, and he was called the Friend of God, and Rahab the harlot was justified by works when she had received the messengers (James 2:21–25). As the body without the spirit is dead, so faith without works is dead also (James 2:26).",
    3: "James says, be not many masters, knowing that we shall receive the greater condemnation, for in many things we offend all, and if any man offend not in word, he is a perfect man, able also to bridle the whole body (James 3:1–2). We put bits in the horses' mouths and turn about the great ships with a very small helm, even so the tongue is a little member and boasteth great things, and how great a matter a little fire kindleth (James 3:3–5). The tongue is a fire, a world of iniquity, that defileth the whole body and is set on fire of hell (James 3:6). Every kind of beasts, and of birds, and of serpents is tamed of mankind, but the tongue can no man tame, an unruly evil full of deadly poison (James 3:7–8). Therewith bless we God, even the Father, and therewith curse we men, which are made after the similitude of God, and out of the same mouth proceedeth blessing and cursing, which ought not so to be (James 3:9–12). A wise man endued with knowledge will shew out of a good conversation his works with meekness of wisdom, but bitter envying and strife is earthly, sensual, devilish, and where it is there is confusion and every evil work (James 3:13–16). The wisdom that is from above is first pure, then peaceable, gentle, easy to be intreated, full of mercy and good fruits, without partiality, and without hypocrisy, and the fruit of righteousness is sown in peace of them that make peace (James 3:17–18).",
    4: "James asks from whence come wars and fightings among them, and answers that they come of their lusts that war in their members, for they lust, and have not, and ask not, or ask amiss that they may consume it upon their lusts (James 4:1–3). He calls them adulterers and adulteresses and says the friendship of the world is enmity with God, but God resisteth the proud and giveth grace unto the humble (James 4:4–6). They are to submit themselves to God, resist the devil, draw nigh to God, cleanse their hands, purify their hearts, be afflicted and mourn, and humble themselves in the sight of the Lord, and he shall lift them up (James 4:7–10). They are not to speak evil one of another, for he that judgeth his brother judgeth the law, and there is one lawgiver, who is able to save and to destroy (James 4:11–12). To those who say To day or to morrow we will go into such a city and buy and sell and get gain, James says they know not what shall be on the morrow, for life is even a vapour, and they ought to say If the Lord will, we shall live, and do this, or that (James 4:13–16). Therefore to him that knoweth to do good, and doeth it not, to him it is sin (James 4:17).",
    5: "James tells the rich men to weep and howl for their miseries, for their riches are corrupted, their garments motheaten, and their gold and silver cankered, and the rust shall be a witness against them (James 5:1–3). The hire of the labourers who have reaped their fields, kept back by fraud, crieth, and the cries have entered into the ears of the Lord of sabaoth, while the rich have lived in pleasure and condemned and killed the just (James 5:4–6). The brethren are to be patient unto the coming of the Lord, as the husbandman waiteth for the precious fruit of the earth, to stablish their hearts, and not to grudge one against another, for the judge standeth before the door (James 5:7–9). They are to take the prophets for an example of suffering affliction and patience and remember the patience of Job and the end of the Lord, that the Lord is very pitiful, and of tender mercy (James 5:10–11). Above all things they are to swear not, but let their yea be yea and their nay, nay (James 5:12). The afflicted is to pray, the merry to sing psalms, and the sick to call for the elders of the church, who pray over him, anointing him with oil in the name of the Lord, and the prayer of faith shall save the sick (James 5:13–15). They are to confess their faults one to another and pray one for another, for the effectual fervent prayer of a righteous man availeth much, as with Elias, a man subject to like passions, who prayed that it might not rain, and it rained not for three years and six months, and then prayed again and the heaven gave rain (James 5:16–18). If any do err from the truth and one convert him, he shall save a soul from death and hide a multitude of sins (James 5:19–20).",
}

WWA = {
    1: "James follows Hebrews among the general letters. Writing to the twelve tribes scattered abroad, James tells them to count trials joy, to ask God for wisdom, to see that temptation comes from our own lust and not from God, and to be doers of the word, not hearers only (1:1-27). Chapter 2 turns to partiality and a faith that works.",
    2: "Chapter 1 ended with pure religion: visiting the fatherless and widows and keeping unspotted from the world (1:27). Chapter 2 forbids respect of persons in the assembly, calls for the royal law of love, and argues that faith without works is dead, citing Abraham and Rahab (2:1-26). Chapter 3 turns to the tongue.",
    3: "Chapter 2 ended with faith without works being dead (2:26). Chapter 3 warns teachers, shows the tongue as a little fire that no man can tame, and sets the wisdom from above against envy and strife (3:1-18). Chapter 4 asks where wars and fightings come from.",
    4: "Chapter 3 ended with the fruit of righteousness sown in peace by them that make peace (3:18). Chapter 4 traces quarrels to lusts, calls for humility and drawing nigh to God, forbids speaking evil of a brother, and warns against planning without the Lord (4:1-17). Chapter 5 speaks to the rich and calls for patience and prayer.",
    5: "Chapter 4 ended with the warning that to him that knoweth to do good and doeth it not, it is sin (4:17). Chapter 5 condemns the rich who keep back wages, calls the brethren to patience until the coming of the Lord, and closes with prayer for the sick and care for those who err (5:1-20). 1 Peter follows.",
}

KEY_FIGURES = {
    1: [
        ("James", "A servant of God and of the Lord Jesus Christ who writes to the twelve tribes and gives plain commands about trials, wisdom, and speech (1:1-27)."),
        ("The twelve tribes scattered abroad", "The brethren told to count their trials joy and to be doers of the word (1:1-2,22)."),
        ("God, the Father of lights", "Giveth wisdom liberally, tempteth no man, and sends down every good gift and every perfect gift (1:5,13,17)."),
        ("The double minded man", "Wavers like a wave of the sea and is unstable in all his ways (1:6-8)."),
        ("The brother of low degree and the rich man", "The first is told to rejoice in being exalted and the second in being made low (1:9-11)."),
        ("The fatherless and widows", "Those to be visited in their affliction as pure religion (1:27)."),
    ],
    2: [
        ("The brethren in the assembly", "Told not to hold the faith with respect of persons (2:1-4)."),
        ("The man with a gold ring and the poor man", "The rich man is given a good place, and the poor man in vile raiment is told to stand (2:2-3)."),
        ("God", "Hath chosen the poor of this world rich in faith, and heirs of the kingdom (2:5)."),
        ("The devils", "Believe that there is one God, and tremble (2:19)."),
        ("Abraham", "Justified by works when he offered Isaac his son upon the altar, and called the Friend of God (2:21-23)."),
        ("Rahab", "The harlot who was justified by works when she received the messengers and sent them out another way (2:25)."),
    ],
    3: [
        ("The masters, or teachers", "Told that they shall receive the greater condemnation (3:1)."),
        ("James and the brethren", "Say we all offend in many things, and bless God and curse men with the same mouth (3:2,9)."),
        ("God, the Father", "He whom we bless and in whose likeness men are made (3:9)."),
        ("The wise man endued with knowledge", "Shews out of a good conversation his works with meekness of wisdom (3:13)."),
        ("Those with bitter envying and strife", "Their wisdom is earthly, sensual, devilish and brings confusion (3:14-16)."),
    ],
    4: [
        ("The brethren who war and fight", "Their lusts war in their members, and they ask amiss (4:1-3)."),
        ("God", "Resisteth the proud and giveth grace unto the humble, and is the one lawgiver, who is able to save and to destroy (4:6,12)."),
        ("The devil", "He that is to be resisted and will flee (4:7)."),
        ("He that speaketh evil of his brother", "Judgeth the law and not a doer of the law, but a judge (4:11)."),
        ("The merchants who plan a year's gain", "Say To day or to morrow we will go into such a city, and know not what shall be on the morrow (4:13-14)."),
    ],
    5: [
        ("The rich men", "Told to weep and howl, for they have kept back the hire of the labourers by fraud and condemned the just (5:1-6)."),
        ("The labourers who reaped the fields", "Their cries have entered into the ears of the Lord of sabaoth (5:4)."),
        ("The Lord of sabaoth", "Hears the cries and is the judge that standeth before the door (5:4,9)."),
        ("The brethren", "Told to be patient, swear not, pray, and confess their faults (5:7-16)."),
        ("The elders of the church", "Called to pray over the sick and anoint him with oil in the name of the Lord (5:14)."),
        ("Elias", "A man subject to like passions who prayed that it might not rain, and then prayed again for rain (5:17-18)."),
    ],
}

THEMES = {
    1: [
        "The trying of their faith worketh patience, and the man that endureth temptation shall receive the crown of life (1:2-4,12).",
        "If any lack wisdom, let him ask of God, that giveth to all liberally, but ask in faith, nothing wavering (1:5-8).",
        "God tempteth no man, but every man is tempted when he is drawn away of his own lust, and every good gift is from the Father of lights (1:13-18).",
        "Every man is to be swift to hear, slow to speak, slow to wrath, and to bridle his tongue (1:19-21,26).",
        "They are to be doers of the word and not hearers only, and pure religion is to visit the fatherless and widows and keep unspotted from the world (1:22-27).",
    ],
    2: [
        "God hath chosen the poor of this world rich in faith, so the brethren are not to hold the faith with respect of persons (2:1-7).",
        "The royal law is Thou shalt love thy neighbour as thyself, and whosoever keepeth the whole law and offendeth in one point is guilty of all (2:8-11).",
        "He shall have judgment without mercy that hath shewed no mercy, and mercy rejoiceth against judgment (2:12-13).",
        "Faith, if it hath not works, is dead, being alone, and the devils also believe, and tremble (2:14-20,26).",
        "Abraham was justified by works when he offered Isaac, and Rahab the harlot when she received the messengers (2:21-25).",
    ],
    3: [
        "The tongue is a little member that boasteth great things, a fire that defileth the whole body (3:1-6).",
        "Every kind of beasts, and birds, and serpents is tamed of mankind, but the tongue can no man tame (3:7-8).",
        "Out of the same mouth proceedeth blessing and cursing, which ought not so to be, as a fountain does not send forth sweet and bitter (3:9-12).",
        "A wise man shews out of a good conversation his works with meekness of wisdom, while bitter envying and strife bring confusion (3:13-16).",
        "The wisdom from above is first pure, then peaceable, gentle, and full of mercy, and the fruit of righteousness is sown in peace of them that make peace (3:17-18).",
    ],
    4: [
        "Wars and fightings come of the lusts that war in their members, for they ask not or ask amiss (4:1-3).",
        "The friendship of the world is enmity with God (4:4-5).",
        "God resisteth the proud and giveth grace unto the humble, so they are to submit to God, draw nigh to him, and humble themselves in his sight (4:6-10).",
        "They are not to speak evil one of another, for there is one lawgiver, who is able to save and to destroy (4:11-12).",
        "They ought to say If the Lord will, we shall live, and do this, or that, for life is even a vapour (4:13-17).",
    ],
    5: [
        "The hire of the labourers kept back by fraud crieth, and the cries have entered into the ears of the Lord of sabaoth (5:1-6).",
        "The brethren are to be patient unto the coming of the Lord, like the husbandman, the prophets, and Job (5:7-11).",
        "They are to swear not, but let their yea be yea and their nay, nay (5:12).",
        "The prayer of faith shall save the sick, and the effectual fervent prayer of a righteous man availeth much, as Elias showed (5:13-18).",
        "He which converteth the sinner from the error of his way shall save a soul from death and hide a multitude of sins (5:19-20).",
    ],
}

AUDIENCE_FIXES = {
    1: "Scattered believers facing hard times would have heard that trials build patience, that God gives wisdom to all, and that hearing the word without doing it is self-deceit.",
    2: "A mixed assembly where the rich got the best seats would have heard that God chose the poor, that love is the royal law, and that faith without works is dead.",
    3: "Teachers and talkers in the congregation would have heard that a small tongue can set a whole life on fire, and that the wisdom from above is peaceable and full of mercy.",
    5: "Poor field workers and patient believers would have heard that God hears the cries of the defrauded and that the coming of the Lord was near, so prayer and patience should fill the meantime.",
}


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "59_james.json"
    data = load(path)
    for n in range(1, 6):
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
    path = ROOT / "chapter_context" / "40_hebrews_james.json"
    data = load(path)
    for n, text in AUDIENCE_FIXES.items():
        data[f"{BOOK} {n}"]["audience"] = text
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_book_overview():
    path = ROOT / "book_overviews" / "09_general_letters_revelation.json"
    data = load(path)
    book = data[BOOK]
    book["author"] = "Traditionally attributed to James, the brother of Jesus and leader in the Jerusalem church (James 1:1)."
    book["audience"] = "The twelve tribes which are scattered abroad, understood as Jewish Christians living outside their homeland."
    book["keyVerse"] = "James 1:22"
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_FIXES = [
    ("He chose to give us new birth", "God chose to give us new birth"),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "09_general_letters_revelation.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("\n# James") + 1
    end = text.index("\n# 1 Peter", start) + 1
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
