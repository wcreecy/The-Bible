#!/usr/bin/env python3
"""Apply the completed editorial review for Ephesians to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BOOK = "Ephesians"


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


SUMMARY = {
    1: ("Paul greets the saints at Ephesus and blesses God, who hath blessed believers with all spiritual blessings in heavenly places in Christ (Ephesians 1:1–3). God chose them in him before the foundation of the world, predestinated them unto the adoption of children, and gave them redemption through his blood, the forgiveness of sins (Ephesians 1:4–8). He made known the mystery of his will, to gather together in one all things in Christ, and sealed believers with the holy Spirit of promise, the earnest of their inheritance (Ephesians 1:9–14). Paul thanks God for their faith and love and prays that the eyes of their understanding be enlightened to know the hope of his calling and the exceeding greatness of his power (Ephesians 1:15–19). That power raised Christ from the dead, set him above all principality and power, and made him head over all things to the church, which is his body (Ephesians 1:20–23)."),
    2: ("Paul reminds believers that they were dead in trespasses and sins, walking according to the prince of the power of the air, but God, who is rich in mercy, hath quickened them together with Christ and raised them up together (Ephesians 2:1–7). By grace are they saved through faith, not of works, for they are his workmanship, created in Christ Jesus unto good works (Ephesians 2:8–10). Gentiles who were aliens from the commonwealth of Israel, without Christ, and having no hope, are made nigh by the blood of Christ (Ephesians 2:11–13). Christ is our peace, who hath broken down the middle wall of partition and made of twain one new man, reconciling both unto God in one body by the cross (Ephesians 2:14–18). So they are no more strangers and foreigners but fellowcitizens with the saints and of the household of God, built upon the foundation of the apostles and prophets, Jesus Christ himself being the chief corner stone (Ephesians 2:19–22)."),
    3: ("Paul calls himself the prisoner of Jesus Christ for the Gentiles and speaks of the dispensation of the grace of God given to him (Ephesians 3:1–2). By revelation God made known to him the mystery, that the Gentiles should be fellowheirs, and of the same body, and partakers of his promise in Christ by the gospel (Ephesians 3:3–7). Though he is less than the least of all saints, grace was given him to preach among the Gentiles the unsearchable riches of Christ, so that now unto the principalities and powers in heavenly places might be known by the church the manifold wisdom of God (Ephesians 3:8–13). He bows his knees to the Father and prays that they be strengthened by his Spirit, that Christ may dwell in their hearts by faith, and that they know the love of Christ, which passeth knowledge (Ephesians 3:14–19). He ends with praise to him that is able to do exceeding abundantly above all that we ask or think (Ephesians 3:20–21)."),
    4: ("Paul, the prisoner of the Lord, beseeches believers to walk worthy of their calling, with lowliness and meekness, endeavouring to keep the unity of the Spirit in the bond of peace: one body, one Spirit, one hope, one Lord, one faith, one baptism, one God and Father of all (Ephesians 4:1–6). Christ ascended and gave some apostles, prophets, evangelists, pastors, and teachers for the perfecting of the saints and the edifying of the body of Christ (Ephesians 4:7–12). Speaking the truth in love, they are to grow up into him in all things, no more children tossed to and fro (Ephesians 4:13–16). They are to walk no longer as other Gentiles, but put off the old man and put on the new man, which after God is created in righteousness and true holiness (Ephesians 4:17–24). He urges putting away lying, letting no corrupt communication proceed out of their mouth, not grieving the holy Spirit, and being kind, tenderhearted, forgiving one another, even as God for Christ's sake hath forgiven them (Ephesians 4:25–32)."),
    5: ("Paul tells believers to be followers of God as dear children and to walk in love, as Christ also hath loved us, and hath given himself for us (Ephesians 5:1–2). Fornication, uncleanness, and covetousness are not once to be named among saints, and no one is to be deceived with vain words (Ephesians 5:3–7). Once darkness, they are now light in the Lord and are to walk as children of light, having no fellowship with the unfruitful works of darkness (Ephesians 5:8–14). They are to walk circumspectly, redeeming the time, not be drunk with wine but be filled with the Spirit, speaking in psalms and hymns and spiritual songs, and submitting themselves one to another in the fear of God (Ephesians 5:15–21). Wives are to submit to their husbands as unto the Lord, and husbands to love their wives as Christ loved the church and gave himself for it; the two shall be one flesh, a great mystery concerning Christ and the church (Ephesians 5:22–33)."),
    6: ("Children are to obey their parents in the Lord, for this is the first commandment with promise, and fathers are not to provoke their children to wrath but bring them up in the nurture and admonition of the Lord (Ephesians 6:1–4). Servants are to be obedient to their masters, as unto Christ, and masters are to forbear threatening, knowing that their Master is also in heaven, with whom is no respect of persons (Ephesians 6:5–9). Believers are to be strong in the Lord and put on the whole armour of God to stand against the wiles of the devil, for they wrestle not against flesh and blood (Ephesians 6:10–13). The armour is the girdle of truth, the breastplate of righteousness, feet shod with the preparation of the gospel of peace, the shield of faith, the helmet of salvation, and the sword of the Spirit, which is the word of God (Ephesians 6:14–17). Paul asks prayer for boldness as an ambassador in bonds, and says Tychicus will tell them his affairs, with a closing blessing (Ephesians 6:18–24)."),
}

WWA = {
    1: "Galatians ended with Paul glorying only in the cross and wishing grace on the brethren (Galatians 6:14-18). Ephesians, written while Paul is a prisoner, opens with a long burst of praise for what God has done in Christ, who chose, adopted, redeemed, and sealed his people, and with Paul's prayer that they know the hope of his calling and the power that raised Christ (1:1-23). Chapter 2 shows what that power did for them.",
    2: "Chapter 1 ended with Christ raised and made head over all things to the church (1:20-23). Chapter 2 shows the same power at work in believers: dead in sins, they were made alive by grace through faith, and Gentiles once far off are brought near, Jew and Gentile made one new man in Christ and built into God's household (2:1-22). Chapter 3 explains this mystery and prays for them.",
    3: "Chapter 2 ended with believers built together for a habitation of God through the Spirit (2:22). Chapter 3 explains the mystery that Gentiles are fellowheirs in Christ, tells of Paul's calling to preach it as a prisoner, and prays that they be strengthened and know the love of Christ (3:1-21). Chapter 4 turns from what God has done to how they should live.",
    4: "Chapter 3 ended with glory to God in the church by Christ Jesus throughout all ages (3:21). Chapter 4 turns to conduct: keep the unity of the Spirit, use the gifts Christ gave for building up the body, grow up in truth and love, put off the old man, and put away lying, anger, and bitterness (4:1-32). Chapter 5 continues with walking in love and light.",
    5: "Chapter 4 ended with believers forgiving one another as God for Christ's sake forgave them (4:32). Chapter 5 continues: walk in love as Christ loved us, walk as children of light, be filled with the Spirit, and let that love shape marriage, with Christ and the church as the pattern (5:1-33). Chapter 6 completes the household instructions and ends with spiritual armour.",
    6: "Chapter 5 ended with husbands and wives and the great mystery of Christ and the church (5:32-33). Chapter 6 completes the household instructions to children, fathers, servants, and masters, then calls believers to put on the whole armour of God against the devil's wiles, asks prayer for Paul's boldness, and closes with Tychicus's news (6:1-24). Philippians, also written from prison, follows.",
}

KEY_FIGURES = {
    1: [
        ("Paul", "Writes as an apostle by the will of God, blesses God for spiritual blessings, and prays that believers' eyes be enlightened (1:1-3,15-19)."),
        ("The saints at Ephesus", "The faithful in Christ Jesus to whom Paul writes, for whose faith and love he gives thanks (1:1,15-16)."),
        ("God the Father", "Chose believers before the foundation of the world, predestinated them to adoption, and raised Christ from the dead (1:3-5,20)."),
        ("Jesus Christ", "In whom believers have redemption through his blood, and who is made head over all things to the church (1:7,22)."),
        ("The Holy Spirit", "The Spirit of promise with which believers are sealed, the earnest of their inheritance (1:13-14)."),
    ],
    2: [
        ("Gentile believers", "Once aliens from the commonwealth of Israel, without Christ and having no hope, now made nigh by his blood and fellowcitizens with the saints (2:11-13,19)."),
        ("Jewish believers", "Included in \"we all\" who once had their conversation in the lusts of the flesh, and are now made one with the Gentiles (2:3,14-16)."),
        ("The prince of the power of the air", "The spirit that now worketh in the children of disobedience, whom believers once followed (2:2)."),
        ("God", "Rich in mercy, quickened believers together with Christ and saved them by grace through faith (2:4-8)."),
        ("Jesus Christ", "Our peace, who broke down the middle wall of partition, made of twain one new man, and is the chief corner stone (2:14-15,20)."),
        ("The Holy Spirit", "The one Spirit by whom both Jew and Gentile have access to the Father (2:18,22)."),
    ],
    3: [
        ("Paul", "The prisoner of Jesus Christ for the Gentiles, given grace to preach the unsearchable riches of Christ, who bows his knees in prayer for them (3:1,8,14)."),
        ("The Gentiles", "Fellowheirs, of the same body, and partakers of God's promise in Christ by the gospel (3:6)."),
        ("The holy apostles and prophets", "Those to whom the mystery of Christ is now revealed by the Spirit (3:5)."),
        ("The church", "Through whom the manifold wisdom of God is made known to principalities and powers in heavenly places (3:10)."),
        ("Principalities and powers", "Heavenly beings who learn God's manifold wisdom through the church (3:10)."),
        ("God the Father, Jesus Christ, and the Spirit", "The Father strengthens by his Spirit, Christ dwells in hearts by faith, and God is able to do exceeding abundantly above all we ask or think (3:14-20)."),
    ],
    4: [
        ("Paul", "The prisoner of the Lord who beseeches believers to walk worthy of their calling (4:1)."),
        ("Believers", "Called to keep the unity of the Spirit, put off the old man, and put on the new (4:3,22-24)."),
        ("Christ", "Ascended on high and gave gifts to men, the head from whom the whole body is joined together (4:8,15-16)."),
        ("Apostles, prophets, evangelists, pastors, and teachers", "Given by Christ for the perfecting of the saints and the work of the ministry (4:11-12)."),
        ("Other Gentiles", "Those who walk in the vanity of their mind, having the understanding darkened, from whom believers are to differ (4:17-19)."),
        ("The Holy Spirit", "The Spirit of God whom believers are not to grieve, by whom they are sealed unto the day of redemption (4:30)."),
    ],
    5: [
        ("Paul", "Calls believers to be followers of God as dear children, to walk in love, and to be filled with the Spirit (5:1-2,18)."),
        ("Christ", "Loved us and gave himself for us, and loved the church and gave himself for it to sanctify and cleanse it (5:2,25-26)."),
        ("Believers", "Once darkness, now light in the Lord, told to walk as children of light and to redeem the time (5:8,15-16)."),
        ("Wives and husbands", "Wives are told to submit to their husbands as unto the Lord, and husbands to love their wives as Christ loved the church (5:22-25)."),
        ("The church", "Subject to Christ, and the picture of what husband and wife are to be to each other in the great mystery (5:24,32)."),
        ("The children of disobedience", "Those on whom the wrath of God comes because of vain words, and with whom believers are not to be partakers (5:6-7)."),
    ],
    6: [
        ("Paul", "An ambassador in bonds who asks prayer that he may speak boldly the mystery of the gospel (6:19-20)."),
        ("Tychicus", "A beloved brother and faithful minister whom Paul sends to tell them his affairs and comfort their hearts (6:21-22)."),
        ("Children and parents", "Children are to obey their parents in the Lord, and fathers are not to provoke them to wrath (6:1-4)."),
        ("Servants and masters", "Servants are to obey as unto Christ, and masters to forbear threatening, since both have the same Master in heaven (6:5-9)."),
        ("The devil and spiritual wickedness", "The wiles and rulers of darkness against which believers wrestle, not against flesh and blood (6:11-12)."),
        ("The saints", "Those for whom Paul asks continual prayer and supplication in the Spirit (6:18)."),
    ],
}

THEMES = {
    1: {
        "Chosen and adopted by God's grace": "God chose believers in Christ before the foundation of the world and predestinated them unto the adoption of children, according to the good pleasure of his will (1:4-6,11).",
        "Redemption and forgiveness through Christ": "In Christ believers have redemption through his blood, the forgiveness of sins, according to the riches of his grace (1:7-8).",
        "God's plan to unite all things in Christ": "God made known the mystery of his will, that in the dispensation of the fulness of times he might gather together in one all things in Christ (1:9-10).",
        "Sealed with the Spirit as a guarantee": "After believing, they were sealed with that holy Spirit of promise, which is the earnest of our inheritance (1:13-14).",
        "Christ exalted as head over all for the church": "God raised Christ from the dead, set him at his right hand far above all principality and power, and gave him to be the head over all things to the church (1:18-23).",
    },
    2: {
        "From death to life by God's mercy": "Though dead in trespasses and sins, believers were quickened together with Christ and raised up together, because God is rich in mercy (2:1-7).",
        "Saved by grace through faith, created for good works": "By grace are ye saved through faith, not of works, lest any man should boast, for we are his workmanship created unto good works (2:8-10).",
        "One new humanity: Jews and Gentiles united": "Christ is our peace, who hath made both one and broken down the middle wall of partition, creating in himself one new man (2:11-16).",
        "Reconciliation and access to God": "Through the cross both are reconciled unto God in one body, and through Christ both have access by one Spirit unto the Father (2:16-18).",
        "God's household and holy temple": "Believers are fellowcitizens and of the household of God, built on the foundation of the apostles and prophets, Jesus Christ the chief corner stone (2:19-22).",
    },
    3: {
        "The mystery revealed: Gentiles as fellow heirs": "The mystery hid from ages is now revealed by the Spirit: the Gentiles are fellowheirs, of the same body, and partakers of the promise in Christ (3:3-6,9).",
        "Ministry as a gift of grace": "Paul says he was made a minister according to the gift of the grace of God, though less than the least of all saints (3:2,7-8).",
        "The church displays God's wisdom": "Through the church is made known to principalities and powers in heavenly places the manifold wisdom of God, so that believers have boldness and access with confidence (3:10-12).",
        "Strength and the surpassing love of Christ": "Paul prays that they be strengthened by his Spirit, rooted and grounded in love, and know the love of Christ, which passeth knowledge (3:14-19).",
        "God is able to do far more": "Unto him that is able to do exceeding abundantly above all that we ask or think be glory in the church by Christ Jesus throughout all ages (3:20-21).",
    },
    4: {
        "Keeping the unity of the Spirit": "Believers are to walk with lowliness and meekness, endeavouring to keep the unity of the Spirit, since there is one body, one Spirit, one hope, one Lord, one faith, one baptism, one God (4:1-6).",
        "Christ's gifts for equipping the church": "Christ gave apostles, prophets, evangelists, pastors, and teachers for the perfecting of the saints, for the work of the ministry, and for the edifying of the body (4:7-12).",
        "Growing to maturity in truth and love": "Believers are no more to be children tossed to and fro, but speaking the truth in love are to grow up into him which is the head, even Christ (4:13-16).",
        "Putting off the old self, putting on the new": "They are to put off the old man, be renewed in the spirit of their mind, and put on the new man, created in righteousness and true holiness (4:17-24).",
        "Words and actions that build up": "Believers are to put away lying, let no corrupt communication proceed out of their mouth, and be kind, tenderhearted, forgiving one another as God for Christ's sake hath forgiven them (4:25-32).",
    },
    5: {
        "Imitating God by walking in love": "Believers are to be followers of God as dear children and walk in love, as Christ loved us and gave himself for us (5:1-2).",
        "Holiness in conduct and speech": "Fornication, uncleanness, covetousness, and filthiness are not to be named among saints, but rather giving of thanks (5:3-7).",
        "Living as children of light": "Once darkness but now light in the Lord, believers are to walk as children of light and reprove the unfruitful works of darkness (5:8-14).",
        "Wisdom and being filled with the Spirit": "Believers are to walk circumspectly, not be drunk with wine but filled with the Spirit, singing and giving thanks, submitting one to another in the fear of God (5:15-21).",
        "Marriage reflecting Christ and the church": "Husbands are to love their wives as Christ loved the church and gave himself for it, and wives are to reverence their husbands, a great mystery concerning Christ and the church (5:21-33).",
    },
    6: {
        "Family relationships in the Lord": "Children are to obey their parents in the Lord and honour them, and fathers are to bring up their children in the nurture and admonition of the Lord (6:1-4).",
        "Work and authority before one Master": "Servants are to obey as unto Christ and masters to forbear threatening, for their Master is in heaven, and there is no respect of persons with him (6:5-9).",
        "Strength in the Lord for spiritual conflict": "Believers are to be strong in the Lord and put on the whole armour of God, for they wrestle not against flesh and blood but against principalities and powers (6:10-13).",
        "The armor of God": "The armour is truth, righteousness, the preparation of the gospel of peace, faith, salvation, and the word of God as the sword of the Spirit (6:14-17).",
        "Prayer and bold proclamation": "Believers are to pray always with all prayer and supplication in the Spirit, and Paul asks that he may open his mouth boldly to make known the mystery of the gospel (6:18-20).",
    },
}


def norm(text):
    return text.replace("’", "'")


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "49_ephesians.json"
    data = load(path)
    for n in range(1, 7):
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
    3: "Gentile readers who had been taught they stood outside Israel's promises would have heard Paul, a prisoner for their sake, announce that they were fellowheirs, a truth he calls a mystery hid from ages.",
    5: "Believers surrounded by banquets and the drunken worship of pagan gods would have heard the call to walk as children of light and be filled with the Spirit, not wine, as a pointed contrast.",
    6: "Servants and masters worshiping in the same household would have heard that both had one Master in heaven, with whom is no respect of persons, read aloud to them together by Tychicus.",
}


def apply_chapter_context():
    path = ROOT / "chapter_context" / "38_galatians_colossians.json"
    data = load(path)
    for n, text in AUDIENCE_FIXES.items():
        data[f"{BOOK} {n}"]["audience"] = text
    for entry in data[f"{BOOK} 5"]["culture"]:
        entry["text"] = entry["text"].replace("‘as to a god.’", "as to a god.")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_book_overview():
    path = ROOT / "book_overviews" / "08_pauls_letters.json"
    data = load(path)
    book = data[BOOK]
    old = "Traditionally attributed to Paul; some modern scholars debate Pauline authorship."
    if book["author"] != old:
        raise SystemExit("author changed")
    book["author"] = "Paul the apostle, writing as a prisoner (Ephesians 3:1; 4:1)."
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_FIXES = [
    ("God planned in love to adopt them as His children.", "God planned in love to adopt them as his children."),
    ("His great plan is “That in the dispensation", "his great plan is “That in the dispensation"),
    ("and made Him “the head over all things", "and made him “the head over all things"),
    ("He raised them up and seated them with Christ in heaven,", "he raised them up and seated them with Christ in heaven,"),
    ("By His death, He made Jews and Gentiles into", "By his death, he made Jews and Gentiles into"),
    ("a place where God Himself lives by His Spirit.", "a place where God himself lives by his Spirit."),
    ("God is showing His wisdom even to the powers in heaven.", "God is showing his wisdom even to the powers in heaven."),
    ("strengthen them by His Spirit,", "strengthen them by his Spirit,"),
    ("a living picture of Christ's love for His people.", "a living picture of Christ's love for his people."),
    ("the riches God has given His people in Christ", "the riches God has given his people in Christ"),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "08_pauls_letters.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("\n# Ephesians") + 1
    end = text.index("\n# Philippians", start)
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
