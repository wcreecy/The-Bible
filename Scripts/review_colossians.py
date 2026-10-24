#!/usr/bin/env python3
"""Apply the completed editorial review for Colossians to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BOOK = "Colossians"


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


SUMMARY = {
    1: ("Paul, an apostle of Jesus Christ by the will of God, and Timotheus our brother greet the saints and faithful brethren in Christ at Colosse (Colossians 1:1–2). They give thanks for the Colossians' faith in Christ Jesus and love to all the saints, for the hope which is laid up for them in heaven, which they heard from Epaphras, a faithful minister of Christ (Colossians 1:3–8). They pray that the Colossians be filled with the knowledge of his will, walk worthy of the Lord, and give thanks unto the Father, who hath delivered us from the power of darkness and translated us into the kingdom of his dear Son (Colossians 1:9–14). Christ is the image of the invisible God, the firstborn of every creature, by whom all things were created, who is before all things, the head of the body, the church, and the firstborn from the dead, that in all things he might have the preeminence (Colossians 1:15–19). Through the blood of his cross God reconciled all things unto himself, and the Colossians, once alienated, are reconciled if they continue in the faith grounded and settled (Colossians 1:20–23). Paul rejoices in his sufferings for them and preaches the mystery hid from ages, Christ in you, the hope of glory, that he may present every man perfect in Christ Jesus (Colossians 1:24–29)."),
    2: ("Paul tells the Colossians how great a conflict he has for them and for them at Laodicea, and for as many as have not seen his face in the flesh, that their hearts be comforted and knit together in love, for in Christ are hid all the treasures of wisdom and knowledge (Colossians 2:1–5). As they have received Christ Jesus the Lord, so they are to walk in him, rooted and built up in him and stablished in the faith (Colossians 2:6–7). They are to beware lest any man spoil them through philosophy and vain deceit, after the tradition of men, for in Christ dwelleth all the fulness of the Godhead bodily, and they are complete in him (Colossians 2:8–10). They were buried with him in baptism and quickened together with him, and God hath forgiven all trespasses, blotting out the handwriting of ordinances that was against us, nailing it to his cross, and triumphing over principalities and powers (Colossians 2:11–15). So let no man judge them in meat, or in drink, or in respect of an holyday, for these are a shadow of things to come, but the body is of Christ (Colossians 2:16–17). They are not to be beguiled by voluntary humility and worshipping of angels, nor to be subject to ordinances such as Touch not; taste not; handle not, which are the commandments and doctrines of men (Colossians 2:18–23)."),
    3: ("Paul tells those who are risen with Christ to seek those things which are above, where Christ sitteth on the right hand of God, for they are dead, and their life is hid with Christ in God (Colossians 3:1–4). They are to mortify their members upon the earth, fornication, uncleanness, and covetousness, which is idolatry, for which the wrath of God cometh (Colossians 3:5–7). They are to put off anger, wrath, malice, and filthy communication, and lie not one to another, having put off the old man and put on the new man, renewed in knowledge after the image of him that created him (Colossians 3:8–11). As the elect of God, holy and beloved, they are to put on bowels of mercies, kindness, humbleness of mind, meekness, and longsuffering, forgiving one another as Christ forgave them, and above all put on charity, which is the bond of perfectness (Colossians 3:12–14). They are to let the peace of God rule in their hearts, let the word of Christ dwell in them richly, and do all in the name of the Lord Jesus, giving thanks to God and the Father by him (Colossians 3:15–17). Wives are to submit to husbands, husbands to love their wives, children to obey their parents, fathers not to provoke their children, and servants to obey in all things, as to the Lord, for he that doeth wrong shall receive for the wrong (Colossians 3:18–25)."),
    4: ("Paul tells masters to give unto their servants that which is just and equal, knowing that they also have a Master in heaven (Colossians 4:1). The Colossians are to continue in prayer and watch with thanksgiving, praying that God would open a door of utterance to speak the mystery of Christ, for which Paul is in bonds (Colossians 4:2–4). They are to walk in wisdom toward them that are without, redeeming the time, with speech alway with grace, seasoned with salt (Colossians 4:5–6). Tychicus, a beloved brother and faithful minister, will make known all Paul's state, and with him goes Onesimus, a faithful and beloved brother, who is one of them (Colossians 4:7–9). Aristarchus, Paul's fellowprisoner, Marcus, sister's son to Barnabas, and Jesus, which is called Justus, send greetings, and Epaphras, who is one of them, is always labouring fervently for them in prayers, with Luke the beloved physician and Demas (Colossians 4:10–14). The Colossians are to salute the brethren in Laodicea and Nymphas and the church in his house, to cause this epistle to be read also in the church of the Laodiceans, and to say to Archippus that he fulfil the ministry which he hath received in the Lord (Colossians 4:15–17). Paul closes with his own hand, asking them to remember his bonds, and with grace (Colossians 4:18)."),
}

WWA = {
    1: "Colossians follows Philippians, another letter Paul wrote in chains. Writing to a church he had never visited, Paul gives thanks for their faith, prays for them, and lifts up Christ as the image of the invisible God, the head of the church, and the one who reconciles all things (1:1-29). Chapter 2 warns them against teaching that would draw them away from Christ.",
    2: "Chapter 1 ended with Paul labouring to present every man perfect in Christ Jesus (1:28-29). Chapter 2 tells of his conflict for the Colossians and the Laodiceans, warns against philosophy and the rules of men, and shows that Christ is complete and has forgiven them and triumphed over the powers (2:1-23). Chapter 3 describes the new life of those who are risen with Christ.",
    3: "Chapter 2 ended with rules of men that cannot satisfy the flesh (2:20-23). Chapter 3 turns to the life of those risen with Christ: seek things above, put off the old man, put on the new, and live that faith in the household (3:1-25). Chapter 4 opens with masters, then closes with prayer, wise speech, and greetings.",
    4: "Chapter 3 ended with servants serving the Lord Christ and the warning that there is no respect of persons (3:24-25). Chapter 4 begins with masters, then calls for prayer and gracious speech and ends with news and greetings carried by Tychicus and Onesimus (4:1-18). The letter to Philemon tells more of Onesimus, and 1 Thessalonians follows Colossians in order.",
}

KEY_FIGURES = {
    1: [
        ("Paul and Timotheus", "The writers, who give thanks and pray for the Colossians, with Paul rejoicing in his sufferings and preaching the mystery (1:1-3,24-28)."),
        ("The saints and faithful brethren at Colosse", "Those to whom the letter is sent, who have faith in Christ, love for all the saints, and hope laid up in heaven (1:2,4-5)."),
        ("Epaphras", "Their dear fellowservant and a faithful minister of Christ, from whom they learned the gospel (1:7)."),
        ("God the Father", "Delivered us from the power of darkness, translated us into the kingdom of his dear Son, and reconciled all things unto himself (1:12-14,20)."),
        ("Christ", "The image of the invisible God, by whom all things were created, and the head of the church (1:15-18)."),
    ],
    2: [
        ("Paul", "Has a great conflict for the churches, is with them in the spirit, and warns them against being spoiled (2:1,5,8)."),
        ("The Colossians and those at Laodicea", "Told to walk in Christ, rooted and built up in him, and not to be beguiled (2:1,6-7)."),
        ("Christ", "In whom dwelleth all the fulness of the Godhead bodily, and who is the head of all principality and power (2:9-10)."),
        ("God", "Quickened them together with Christ, forgave all trespasses, and triumphed over principalities and powers (2:13-15)."),
        ("Those who would spoil, judge, or beguile them", "Unnamed teachers of philosophy, rules about food and holy days, and the worshipping of angels (2:8,16,18)."),
    ],
    3: [
        ("The Colossian believers", "Risen with Christ, they are told to seek things above, put off the old man, and put on the new (3:1,5-10)."),
        ("Christ", "Sits on the right hand of God, is their life, forgave them, and is all, and in all (3:1,4,11,13)."),
        ("God the Father", "The elect of God are holy and beloved, his wrath cometh on the disobedient, and thanks are given to him by Christ (3:6,12,17)."),
        ("Wives, husbands, children, and fathers", "Each is given a duty: wives to submit, husbands to love, children to obey, and fathers not to provoke (3:18-21)."),
        ("Servants", "Told to obey in all things, in singleness of heart, fearing God, as to the Lord (3:22-25)."),
    ],
    4: [
        ("Masters", "Told to give servants that which is just and equal, knowing they have a Master in heaven (4:1)."),
        ("Paul", "In bonds, asks for prayer for a door of utterance and sends news and greetings in his own hand (4:3,18)."),
        ("Tychicus and Onesimus", "Sent with the letter to make known all Paul's state, Onesimus being one of them (4:7-9)."),
        ("Aristarchus, Marcus, Justus, Luke, and Demas", "Companions who send greetings, with Marcus to be received if he comes (4:10-11,14)."),
        ("Epaphras", "One of them, always labouring fervently for them in prayers (4:12-13)."),
        ("Archippus", "Told to take heed to the ministry which he hath received in the Lord and to fulfil it (4:17)."),
    ],
}

THEMES = {
    1: {
        "Thanksgiving for faith, hope and love": "Paul and Timotheus give thanks for the Colossians' faith in Christ Jesus, their love to all the saints, and the hope which is laid up for them in heaven (1:3-5).",
        "Growing in knowledge and fruitful living": "Their prayer is that the Colossians be filled with the knowledge of his will, walk worthy of the Lord, be fruitful in every good work, and be strengthened with all might (1:9-12).",
        "The supremacy of Christ": "Christ is the image of the invisible God, by whom all things were created and consist, and the head of the church, that in all things he might have the preeminence (1:15-19).",
        "Reconciliation through the cross": "God made peace through the blood of the cross and reconciled all things unto himself, including the Colossians, who were once alienated, if they continue in the faith (1:20-23).",
        "The mystery revealed and ministry": "The mystery hid from ages is now made manifest to his saints, Christ in you, the hope of glory, and Paul labours to present every man perfect in Christ Jesus (1:24-29).",
    },
    2: {
        "Christ is sufficient": "In Christ are hid all the treasures of wisdom and knowledge, and in him dwelleth all the fulness of the Godhead bodily, so that believers are complete in him (2:3,6-10).",
        "Beware of human tradition and empty deceit": "Believers are to beware lest any man spoil them through philosophy and vain deceit, after the tradition of men and not after Christ (2:8).",
        "Union with Christ in death and life": "Believers are circumcised without hands, buried with Christ in baptism, and risen with him through the faith of the operation of God (2:11-13).",
        "Forgiveness and victory through the cross": "God hath forgiven all trespasses, blotted out the handwriting of ordinances, nailed it to his cross, and triumphed over principalities and powers (2:13-15).",
        "Freedom from judging over observances": "No man is to judge them in meat, or in drink, or in respect of an holyday, which are a shadow of things to come, but the body is of Christ (2:16-23).",
    },
    3: {
        "Living from union with Christ": "Since they are risen with Christ, believers are to seek those things which are above, where Christ sitteth, for their life is hid with Christ in God (3:1-4).",
        "Putting off the old self, putting on the new": "They are to mortify their earthly members, put off anger, wrath, and lying, and put on the new man, renewed in knowledge after the image of him that created him (3:5-10).",
        "Unity in Christ across all divisions": "In the new man there is neither Greek nor Jew, Barbarian, Scythian, bond nor free, but Christ is all, and in all (3:11).",
        "Compassion, forgiveness and love": "As the elect of God, they are to put on mercies, kindness, meekness, and longsuffering, forgiving as Christ forgave, and above all charity, the bond of perfectness (3:12-14).",
        "Whole life lived for the Lord": "Whatsoever they do in word or deed is to be done in the name of the Lord Jesus, and in their households and work they serve the Lord Christ (3:17-25).",
    },
    4: {
        "Devotion to prayer": "The Colossians are to continue in prayer and watch with thanksgiving, praying that God would open a door of utterance for Paul to speak the mystery of Christ (4:2-4).",
        "Wisdom and grace toward outsiders": "They are to walk in wisdom toward them that are without, redeeming the time, with speech alway with grace, seasoned with salt (4:5-6).",
        "Justice in authority": "Masters are to give their servants that which is just and equal, knowing that they also have a Master in heaven (4:1).",
        "Partnership in the gospel": "Tychicus, Onesimus, Aristarchus, Marcus, Justus, Epaphras, Luke, and Demas serve beside Paul or carry greetings and news, and Paul calls some of them a comfort to him (4:7-15).",
        "Faithfulness in ministry": "Archippus is told to take heed to the ministry he hath received in the Lord and fulfil it, and Epaphras is labouring fervently in prayer for them (4:12-13,17).",
    },
}


def norm(text):
    return text.replace("’", "'")


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "51_colossians.json"
    data = load(path)
    for n in range(1, 5):
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


def apply_chapter_context():
    path = ROOT / "chapter_context" / "38_galatians_colossians.json"
    data = load(path)
    for entry in data[f"{BOOK} 1"]["culture"]:
        entry["text"] = entry["text"].replace("Colossae was a small city", "Colosse was a small city")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_historical_moments():
    path = ROOT / "historical_moments" / "17_romans_colossians.json"
    data = load(path)
    old = " some scholars think a later follower wrote it."
    key = f"{BOOK} 1"
    if old not in data[key]:
        raise SystemExit("historical moment text changed")
    data[key] = data[key].replace("; some scholars think a later follower wrote it.", ".")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_book_overview():
    path = ROOT / "book_overviews" / "08_pauls_letters.json"
    data = load(path)
    book = data[BOOK]
    book["author"] = "Paul the apostle, with Timothy named in the greeting (Colossians 1:1; 4:18)."
    book["purpose"] = book["purpose"].replace("diminish His centrality", "diminish his centrality")
    book["theme"] = book["theme"].replace("complete in Him", "complete in him")
    book["keyVerse"] = "Colossians 1:18"
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_FIXES = [
    ("explaining how His death makes", "explaining how his death makes"),
    ("so He can present them holy", "so he can present them holy"),
    ("to fully proclaim His word", "to fully proclaim his word"),
    ("They were buried with Him in baptism and raised with Him through faith.", "They were buried with him in baptism and raised with him through faith."),
    ("believers are complete in Him,", "believers are complete in him,"),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "08_pauls_letters.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("\n# Colossians") + 1
    end = text.index("\n# 1 Thessalonians", start)
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
