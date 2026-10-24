#!/usr/bin/env python3
"""Apply the completed editorial review for Philippians to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BOOK = "Philippians"


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


SUMMARY = {
    1: ("Paul and Timotheus greet all the saints in Christ Jesus at Philippi, with the bishops and deacons (Philippians 1:1–2). Paul thanks God upon every remembrance of them for their fellowship in the gospel from the first day until now, is confident that he which hath begun a good work in them will perform it, and prays that their love may abound more and more (Philippians 1:3–11). His bonds have fallen out rather unto the furtherance of the gospel, since they are manifest in all the palace and most of the brethren wax confident, and he rejoices that Christ is preached, whether of envy or of good will (Philippians 1:12–18). He says that to live is Christ and to die is gain, and though he has a desire to depart and be with Christ, he is convinced he will stay for their furtherance and joy of faith (Philippians 1:19–26). He urges them to let their conversation be as it becometh the gospel, to stand fast in one spirit, and not to be terrified by adversaries, since it is given them not only to believe on Christ but also to suffer for his sake (Philippians 1:27–30)."),
    2: ("Paul asks the Philippians to be likeminded, to do nothing through strife or vainglory, and in lowliness of mind to esteem others better than themselves (Philippians 2:1–4). He sets before them the mind of Christ Jesus, who was in the form of God, made himself of no reputation, took the form of a servant, and humbled himself and became obedient unto death, even the death of the cross (Philippians 2:5–8). Therefore God hath highly exalted him and given him a name above every name, that every knee should bow and every tongue confess that Jesus Christ is Lord (Philippians 2:9–11). They are to work out their own salvation with fear and trembling, for it is God which worketh in them, and to do all things without murmurings and disputings, shining as lights in the world (Philippians 2:12–18). Paul trusts to send Timotheus, who will naturally care for their state, and he sends back Epaphroditus, who was sick nigh unto death, but God had mercy on him (Philippians 2:19–30)."),
    3: ("Paul bids the Philippians rejoice in the Lord and warns them to beware of dogs, evil workers, and the concision, for believers are the circumcision, which worship God in the spirit and have no confidence in the flesh (Philippians 3:1–3). If any man might trust in the flesh, Paul more: circumcised the eighth day, of the tribe of Benjamin, an Hebrew of the Hebrews, a Pharisee, and touching the righteousness which is in the law, blameless (Philippians 3:4–6). Yet he counts all things but loss for the excellency of the knowledge of Christ Jesus, that he may be found in him, having the righteousness which is of God by faith, and know the power of his resurrection (Philippians 3:7–11). He has not already attained, but forgetting those things which are behind, he presses toward the mark for the prize of the high calling of God in Christ Jesus (Philippians 3:12–16). He weeps over the enemies of the cross of Christ, whose God is their belly, and reminds believers that their conversation is in heaven, from whence they look for the Saviour, who shall change our vile body (Philippians 3:17–21)."),
    4: ("Paul calls the Philippians his joy and crown and bids them stand fast in the Lord, and he beseeches Euodias and Syntyche to be of the same mind in the Lord, asking his true yokefellow to help them (Philippians 4:1–3). He tells them to rejoice in the Lord alway, to be careful for nothing, and to let their requests be made known unto God by prayer with thanksgiving, and the peace of God shall keep their hearts and minds (Philippians 4:4–7). They are to think on whatsoever things are true, honest, just, pure, lovely, and of good report, and the God of peace shall be with them (Philippians 4:8–9). Paul rejoices in their care of him, has learned in whatsoever state he is therewith to be content, and can do all things through Christ which strengtheneth him (Philippians 4:10–13). Only they communicated with him in giving and receiving; their gift is an odour of a sweet smell, and his God shall supply all their need according to his riches in glory (Philippians 4:14–20). He ends with greetings, chiefly from Caesar's household, and the grace of the Lord Jesus Christ (Philippians 4:21–23)."),
}

WWA = {
    1: "Philippians follows Ephesians, another letter Paul wrote as a prisoner (Ephesians 6:20). Here he thanks the church he planted at Philippi for sharing in the gospel with him, tells them his chains have helped spread it, and calls them to live worthy of Christ and stand together (1:1-30). Chapter 2 holds up the humility of Christ as the pattern for that unity.",
    2: "Chapter 1 ended with Paul urging the Philippians to stand fast in one spirit and to suffer for Christ (1:27-30). Chapter 2 shows the way: humility like Christ's, who took the form of a servant and was then highly exalted. Paul also asks them to shine as lights and promises to send Timothy and Epaphroditus (2:1-30). Chapter 3 warns against trusting in the flesh.",
    3: "Chapter 2 ended with Paul honoring Epaphroditus, who risked his life for the work of Christ (2:30). Chapter 3 warns against those who trust in the flesh, shows that Paul counts all his credentials as loss for knowing Christ, and calls believers to press on, since their citizenship is in heaven (3:1-21). Chapter 4 turns to peace, joy, and thanks.",
    4: "Chapter 3 ended with believers waiting for the Saviour from heaven and told to stand fast in the Lord (3:20-4:1). Chapter 4 urges two women to agree, calls for joy and prayer instead of worry, teaches contentment, and thanks the church for their gift (4:1-23). Colossians, another letter from Paul in chains, follows.",
}

KEY_FIGURES = {
    1: [
        ("Paul", "Writes from his bonds with thanks and joy, prays for the Philippians, and says to live is Christ and to die is gain (1:3-4,13,21)."),
        ("Timothy", "Named with Paul as a servant of Jesus Christ in the greeting (1:1)."),
        ("The saints at Philippi", "The church, with its bishops and deacons, whose fellowship in the gospel from the first day Paul thanks God for (1:1,5)."),
        ("Those who preach Christ", "Some preach out of envy and strife, others of good will, and Paul rejoices that Christ is preached (1:15-18)."),
        ("The palace guard", "Those in all the palace and elsewhere who learned that Paul's bonds are in Christ (1:13)."),
        ("God", "Began a good work in the believers and will perform it until the day of Jesus Christ (1:6)."),
    ],
    2: [
        ("Jesus Christ", "Though in the form of God, made himself of no reputation, took the form of a servant, and became obedient unto death (2:6-8)."),
        ("God the Father", "Highly exalted Christ, and worketh in believers both to will and to do of his good pleasure (2:9,13)."),
        ("Paul", "Asks for unity, speaks of being offered upon their faith, and sends word of Timothy and Epaphroditus (2:2,17,19,25)."),
        ("The Philippian believers", "Told to work out their own salvation and shine as lights in the world (2:12,15)."),
        ("Timothy", "Paul hopes to send him, as he will naturally care for their state and has served with Paul as a son with his father (2:19-22)."),
        ("Epaphroditus", "Their messenger who ministered to Paul's wants, was sick nigh unto death, and is sent back to them (2:25-30)."),
    ],
    3: [
        ("Paul", "Lists his own credentials, counts them loss for Christ, and presses toward the mark (3:4-14)."),
        ("Jesus Christ", "The one Paul wants to win and know, in the power of his resurrection, and the Saviour who shall change our vile body (3:8-10,20-21)."),
        ("Dogs, evil workers, and the concision", "Those Paul warns against, who put confidence in the flesh (3:2-3)."),
        ("The enemies of the cross of Christ", "Those whose end is destruction, whose God is their belly, and who mind earthly things, of whom Paul tells weeping (3:18-19)."),
        ("Those who walk as Paul's ensample", "Believers whose way of life the Philippians are to mark and follow (3:17)."),
        ("God", "Calls believers upward in Christ Jesus and gives the righteousness which is of God by faith (3:9,14)."),
    ],
    4: [
        ("Paul", "Calls the church his joy and crown, has learned to be content, and thanks them for their gift (4:1,11,14-18)."),
        ("Euodias and Syntyche", "Two women who laboured with Paul in the gospel, and whom he beseeches to be of the same mind in the Lord (4:2-3)."),
        ("The true yokefellow", "Someone Paul asks to help these women (4:3)."),
        ("Clement and other fellowlabourers", "Those who laboured with Paul, whose names are in the book of life (4:3)."),
        ("The Philippians", "Sent gifts to Paul more than once, at Thessalonica and again by Epaphroditus (4:15-18)."),
        ("God", "Gives peace that passeth all understanding and will supply all their need according to his riches in glory (4:7,19)."),
    ],
}

THEMES = {
    1: {
        "Partnership in the gospel": "Paul thanks God for their fellowship in the gospel from the first day until now, and says they are partakers of his grace in his bonds and in the defence of the gospel (1:5,7).",
        "God completes what he begins": "Paul is confident that he which hath begun a good work in them will perform it until the day of Jesus Christ, and he prays they be filled with the fruits of righteousness (1:6,9-11).",
        "Joy and the gospel's progress in hardship": "Though in bonds, Paul prays with joy, and his troubles have fallen out rather unto the furtherance of the gospel, so that he rejoices that Christ is preached (1:4,12-14,18).",
        "A Christ-centered view of life and death": "To live is Christ and to die is gain, and Paul is in a strait betwixt two, though to remain is more needful for them (1:20-26).",
        "Living worthy of the gospel in unity": "Paul asks them to let their conversation be as it becometh the gospel, standing fast in one spirit, striving together for the faith, and not terrified by adversaries (1:27-30).",
    },
    2: {
        "Humility and unity": "Paul asks them to be likeminded, with the same love, doing nothing through strife or vainglory, and in lowliness of mind esteeming others better than themselves (2:1-4,14).",
        "The self-giving example of Christ": "Christ Jesus, being in the form of God, made himself of no reputation, took the form of a servant, and became obedient unto death, even the death of the cross, and believers are to have this mind (2:5-8).",
        "Exaltation after humility": "Because Christ humbled himself, God hath highly exalted him and given him a name above every name, so that every tongue shall confess that Jesus Christ is Lord, to the glory of God the Father (2:9-11).",
        "God's work and human effort": "Believers are to work out their own salvation with fear and trembling, for it is God which worketh in them both to will and to do of his good pleasure (2:12-13).",
        "Shining as lights through faithful service": "They are to be blameless and harmless, shining as lights in the world and holding forth the word of life, as Timothy and Epaphroditus served for the work of Christ (2:14-16,19-30).",
    },
    3: {
        "No confidence in the flesh": "Paul warns that those who worship God in the spirit have no confidence in the flesh, though he himself had reason, as circumcised, of the tribe of Benjamin, and a Pharisee (3:2-6).",
        "The surpassing worth of knowing Christ": "Paul counts all things but loss for the excellency of the knowledge of Christ Jesus his Lord, and wants to know him, the power of his resurrection, and the fellowship of his sufferings (3:7-8,10).",
        "Righteousness from God through faith": "Paul wants to be found in Christ, not having his own righteousness, which is of the law, but that which is through the faith of Christ, the righteousness which is of God by faith (3:9).",
        "Pressing on toward the goal": "Paul has not already attained, but forgetting those things which are behind and reaching forth unto those things which are before, he presses toward the mark for the prize (3:12-16).",
        "Heavenly citizenship and future hope": "Believers' conversation is in heaven, from whence they look for the Saviour, who shall change our vile body that it may be fashioned like unto his glorious body (3:11,20-21).",
    },
    4: {
        "Unity and reconciliation": "Paul beseeches Euodias and Syntyche to be of the same mind in the Lord and asks his true yokefellow to help those women who laboured with him in the gospel (4:1-3).",
        "Joy, prayer, and God's peace": "Paul tells them to rejoice in the Lord alway, to be careful for nothing, and to make their requests known unto God, and the peace of God shall keep their hearts and minds (4:4-7).",
        "Thinking on what is good and practicing it": "Paul tells them to think on whatsoever things are true, honest, just, pure, lovely, and of good report, and to do what they learned and saw in him, and the God of peace shall be with them (4:8-9).",
        "Contentment through Christ's strength": "Paul has learned in whatsoever state he is therewith to be content, knowing how to be abased and how to abound, and he can do all things through Christ which strengtheneth him (4:11-13).",
        "Generosity and God's provision": "The Philippians' gifts are an odour of a sweet smell, a sacrifice acceptable, wellpleasing to God, and God shall supply all their need according to his riches in glory by Christ Jesus (4:10,14-20).",
    },
}


def norm(text):
    return text.replace("’", "'")


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "50_philippians.json"
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


AUDIENCE_FIXES = {
    1: "Believers who had sent Paul gifts more than once would have heard thanks for their partnership and learned that his chains had helped the gospel go forward, not stopped it.",
    3: "Gentile believers living in a proud Roman colony would have heard that standing with God came by faith in Christ, not by any human badge, and that their true citizenship was in heaven.",
}


def apply_chapter_context():
    path = ROOT / "chapter_context" / "38_galatians_colossians.json"
    data = load(path)
    for n, text in AUDIENCE_FIXES.items():
        data[f"{BOOK} {n}"]["audience"] = text
    for entry in data[f"{BOOK} 1"]["culture"]:
        entry["text"] = entry["text"].replace(
            "Where Paul was imprisoned is debated: Rome, Ephesus, and Caesarea have all been suggested.",
            "Rome, Ephesus, and Caesarea have all been suggested as the place where Paul was imprisoned.",
        )
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_book_overview():
    path = ROOT / "book_overviews" / "08_pauls_letters.json"
    data = load(path)
    book = data[BOOK]
    book["keyVerse"] = "Philippians 1:21"
    for figure in book["keyFigures"]:
        if figure["name"] == "Euodia and Syntyche":
            figure["name"] = "Euodias and Syntyche"
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_FIXES = [
    ("Though He was God, Jesus did not cling to His rights. He stepped all the way down,",
     "Though he was God, Jesus did not cling to his rights; he stepped all the way down,"),
    ("Many scholars believe these lines were an early Christian hymn:", "These lines read like an early Christian hymn:"),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "08_pauls_letters.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("\n# Philippians") + 1
    end = text.index("\n# Colossians", start)
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
