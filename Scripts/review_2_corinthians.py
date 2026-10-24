#!/usr/bin/env python3
"""Apply the completed editorial review for 2 Corinthians to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BOOK = "2 Corinthians"


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


WWA = {
    1: ("First Corinthians ended with Paul's travel plans and greetings from Ephesus (1 Corinthians "
        "16:5-24). Second Corinthians, written from Macedonia after more trouble, opens by praising "
        "the God of all comfort for rescuing him from a crushing ordeal in Asia, then answers the "
        "charge that he is unreliable because he changed his travel plans (1:1-24). Chapter 2 explains "
        "why he held back from another painful visit."),
    2: ("Chapter 1 ended with Paul saying he stayed away to spare the Corinthians, not to rule over "
        "their faith (1:23-24). Chapter 2 explains the painful letter he wrote instead, urges them to "
        "forgive and comfort the person they disciplined, and describes his anxious search for Titus "
        "before he thanks God for leading him in triumph in Christ (2:1-17). Chapter 3 answers the "
        "question of Paul's credentials."),
    3: ("Chapter 2 ended with Paul asking who is sufficient for the work of the gospel (2:16-17). "
        "Chapter 3 answers that the Corinthians themselves are Christ's letter of recommendation, "
        "written by the Spirit on hearts, and that the new covenant's ministry of the Spirit surpasses "
        "the glory that faded from Moses' face (3:1-18). Chapter 4 shows how that ministry is carried "
        "out."),
    4: ("Chapter 3 ended with believers being changed from glory to glory as they behold the Lord "
        "(3:18). Chapter 4 says this ministry needs no trickery, since the light of the gospel shines "
        "in hearts, but the treasure is held in earthen vessels so that the power is plainly God's, "
        "and present troubles are light beside what is eternal (4:1-18). Chapter 5 looks past the "
        "perishing body."),
    5: ("Chapter 4 ended with Paul fixing his eyes on the things that are not seen, which are eternal "
        "(4:18). Chapter 5 pictures the body as a tent and a building from God waiting, says all must "
        "appear before the judgment seat of Christ, and describes believers as a new creation given "
        "the ministry of reconciliation as ambassadors for Christ (5:1-21). Chapter 6 turns that "
        "appeal toward the Corinthians."),
    6: ("Chapter 5 ended with God making Christ to be sin for us so that we might be made the "
        "righteousness of God in him (5:21). Chapter 6 urges the Corinthians not to receive God's "
        "grace in vain, lists the hardships and virtues of Paul's ministry, asks them to open their "
        "hearts, and warns against being unequally yoked with unbelievers (6:1-18). Chapter 7 "
        "continues the call to holiness and to reconciliation."),
    7: ("Chapter 6 ended with God's promise to be a Father to those who come out and are separate "
        "(6:16-18). Chapter 7 draws the conclusion, cleansing from all filthiness, and returns to "
        "Paul's relationship with the Corinthians: he was troubled in Macedonia until Titus arrived "
        "with good news, and rejoices that godly sorrow led them to repentance (7:1-16). Chapters 8 "
        "and 9 turn to the collection."),
    8: ("Chapter 7 ended with Paul's confidence in the Corinthians (7:16). Chapter 8 turns to the "
        "collection for the saints, using the poor Macedonian churches as an example of generosity, "
        "pointing to Christ who became poor, urging the Corinthians to finish what they began, and "
        "naming Titus and trusted brothers to handle the gift honestly (8:1-24). Chapter 9 continues "
        "the same appeal."),
    9: ("Chapter 8 ended with Paul sending Titus and two brothers so the gift would be handled "
        "honestly (8:16-24). Chapter 9 explains why he is sending them ahead: so the Corinthians' "
        "gift is ready and given willingly, since he who sows bountifully reaps bountifully and God "
        "loves a cheerful giver (9:1-15). Chapter 10 begins the letter's sharpest section."),
    10: ("Chapter 9 ended with thanks to God for his unspeakable gift (9:15). Chapter 10 changes tone "
         "as Paul answers critics who say he is bold in letters but weak in person, insisting his "
         "weapons are not carnal and that his authority is for building up, not tearing down "
         "(10:1-18). Chapter 11 grows more pointed."),
    11: ("Chapter 10 ended with the principle that he who glories should glory in the Lord (10:17-18). "
         "Chapter 11 has Paul reluctantly boast like a fool to answer rival apostles who preach "
         "another Jesus: he refused payment from the Corinthians, lists his beatings, shipwrecks, and "
         "dangers, and recalls being let down a wall in Damascus (11:1-33). Chapter 12 continues "
         "the boasting."),
    12: ("Chapter 11 ended with Paul glorying in his infirmities and escaping Damascus in a basket "
         "(11:30-33). Chapter 12 turns to a vision of the third heaven, the thorn in the flesh, and "
         "Christ's answer, \"My grace is sufficient for thee,\" before Paul states his love for the "
         "Corinthians and his fear of what he may find when he comes (12:1-21). Chapter 13 closes "
         "with his coming visit."),
    13: ("Chapter 12 ended with Paul fearing quarrels and unrepented sin at his coming (12:20-21). "
         "Chapter 13 announces his third visit, says the Corinthians should examine themselves "
         "whether they are in the faith, and ends with a call to be perfect, of one mind, and at peace, "
         "and with the blessing of the grace of the Lord Jesus Christ (13:1-14). The next letter, "
         "Galatians, follows."),
}

KEY_FIGURES = {
    1: [
        ("Paul", "Praises God for comfort in affliction, describes the ordeal in Asia that made him despair of life, and explains why he changed his travel plans (1:3-17)."),
        ("Timothy", "Named with Paul in the greeting, and with Silvanus a preacher of the Son of God whose word was not yea and nay (1:1,19)."),
        ("Corinthian and Achaian believers", "Addressed in the greeting and asked to help Paul by prayer (1:1,11)."),
        ("Silvanus (Silas)", "Named with Paul and Timothy as preaching Jesus Christ among the Corinthians (1:19)."),
    ],
    2: [
        ("Paul", "Explains that he wrote out of much affliction and anguish of heart and urges forgiveness, then tells of having no rest in Troas because he did not find Titus (2:3-4,10-13)."),
        ("The person who caused grief", "A member punished by the majority, whom Paul now asks the church to forgive and comfort (2:5-8)."),
        ("The Corinthian majority", "Imposed the punishment and are asked to confirm their love toward him (2:6-8)."),
        ("Titus", "Paul's brother whose absence in Troas left him without rest, so he went on to Macedonia (2:12-13)."),
        ("Christ", "The one in whom God always causes Paul to triumph and through whom the knowledge of God spreads like a sweet savour (2:14-15)."),
    ],
    3: [
        ("Paul", "Says he needs no letters of commendation, since the Corinthians are his epistle written by the Spirit, and calls himself an able minister of the new testament (3:1-6)."),
        ("The Corinthians", "Described as the epistle of Christ, written not with ink but with the Spirit of the living God in fleshy tables of the heart (3:2-3)."),
        ("Moses", "Put a veil over his face so Israel could not look on the fading glory, an image Paul uses for the old covenant (3:7,13)."),
        ("Christ and the Spirit", "The one who takes away the veil, and the Lord Spirit who gives liberty and changes believers into the same image (3:14-18)."),
    ],
    4: [
        ("Paul", "Renounces hidden dishonesty, preaches Christ Jesus the Lord, and describes carrying the treasure in earthen vessels while troubled on every side (4:1-9)."),
        ("Jesus Christ", "The Lord whom Paul preaches and whose life is made manifest in believers' mortal flesh (4:5,10-11)."),
        ("God", "Commanded the light to shine out of darkness, shines in hearts to give the knowledge of his glory, and raised up the Lord Jesus (4:6,14)."),
        ("Corinthian believers", "Those for whose sakes all things are done, so that abundant grace may increase thanksgiving to the glory of God (4:15)."),
    ],
    5: [
        ("Paul", "Groans in the earthly tent, labours to be accepted of the Lord, and says the love of Christ constrains him to be an ambassador (5:2,9,14,20)."),
        ("Christ", "Died for all, will judge from his seat, and was made sin for us who knew no sin (5:10,15,21)."),
        ("God", "Reconciled us to himself by Jesus Christ and committed to us the word of reconciliation (5:18-19)."),
        ("Those in Christ", "Called a new creature, for old things are passed away and all things are become new (5:17)."),
    ],
    6: [
        ("Paul", "Beseeches the Corinthians not to receive the grace of God in vain and lists stripes, imprisonments, tumults, labours, watchings, and fastings as marks of his ministry (6:1-5)."),
        ("Corinthian believers", "Told Paul's mouth is open to them, his heart enlarged, and that they are straitened in their own affections (6:11-12)."),
        ("Unbelievers", "Named in the warning against being unequally yoked together, set against righteousness, light, and the temple of God (6:14-16)."),
        ("God and Christ", "God promises to dwell in his people and be a Father to them, and Christ stands opposite Belial (6:15-18)."),
    ],
    7: [
        ("Paul", "Urges cleansing from all filthiness, tells of no rest in Macedonia, and rejoices that godly sorrow worketh repentance (7:1,5,9-10)."),
        ("Titus", "Arrives with news of the Corinthians' earnest desire, mourning, and fervent mind toward Paul, which comforts him (7:6-7,13)."),
        ("Corinthian believers", "Sorrowed after a godly manner and showed carefulness, clearing of themselves, and zeal (7:9-11)."),
        ("God", "Comforts those that are cast down by the coming of Titus (7:6)."),
    ],
    8: [
        ("Paul", "Declares the grace of God given to the churches of Macedonia and urges the Corinthians to perform the doing of it (8:1,10-11)."),
        ("Macedonian churches", "Gave to the utmost of their power, and beyond, in deep poverty and a great trial of affliction, first giving themselves to the Lord (8:2-5)."),
        ("Titus", "Paul's partner and fellowhelper who earnestly cares for the Corinthians and goes to them by his own accord (8:6,16-17,23)."),
        ("Brothers sent with Titus", "Unnamed brethren chosen by the churches to travel with the gift, so that no man blame Paul (8:18-23)."),
        ("Corinthian believers", "Urged to finish the performance of what they had willingly begun a year before (8:10-11)."),
    ],
    9: [
        ("Paul", "Boasts of Achaia's readiness to the Macedonians and sends the brethren so that his boasting is not in vain (9:2-5)."),
        ("Corinthians (Achaian believers)", "Told to give each as he purposes in his heart, not grudgingly or of necessity, for God loveth a cheerful giver (9:7)."),
        ("Macedonians", "May come with Paul and find the Corinthians unprepared, to the shame of both (9:2-4)."),
        ("Brothers sent ahead", "Sent to make up beforehand the Corinthians' bounty so it is ready as a matter of bounty (9:3,5)."),
        ("Recipients of the service", "The saints whose wants are supplied and who thank God and pray for the Corinthians (9:12-14)."),
    ],
    10: [
        ("Paul", "Beseeches by the meekness and gentleness of Christ and says the weapons of his warfare are not carnal but mighty through God (10:1,4)."),
        ("Corinthian believers", "Told to look on things after the outward appearance and weigh Paul's authority, given for edification (10:7-8)."),
        ("Paul’s critics", "Say his letters are weighty and powerful, but his bodily presence weak and his speech contemptible (10:10)."),
        ("Christ", "The one by whose meekness and gentleness Paul appeals, and whom he serves in preaching where Christ was not named (10:1,14)."),
    ],
    11: [
        ("Paul", "Reluctantly boasts as a fool, lists his labours, stripes, perils, and cares, and recalls being let down by the wall in a basket (11:1,23-33)."),
        ("Corinthian believers", "Warned against being corrupted from the simplicity that is in Christ, as the serpent beguiled Eve (11:3-4)."),
        ("False apostles", "Unnamed deceitful workers who transform themselves into the apostles of Christ, as Satan into an angel of light (11:13-15)."),
        ("Macedonian brethren", "Supplied what was lacking to Paul when he was in want at Corinth (11:9)."),
        ("The governor under Aretas", "Kept the city of the Damascenes with a garrison to catch Paul, who escaped through a window in a basket (11:32-33)."),
    ],
    12: [
        ("Paul", "Tells of a vision of the third heaven, receives a thorn in the flesh, and hears that Christ's grace is sufficient and his strength made perfect in weakness (12:1-10)."),
        ("The man in Christ", "A man Paul knew who was caught up to the third heaven fourteen years before, usually understood as Paul himself (12:2-4)."),
        ("Titus", "Sent to the Corinthians with a brother, walking in the same spirit and steps as Paul (12:18)."),
        ("A brother sent with Titus", "Unnamed companion sent with Titus to the Corinthians (12:18)."),
        ("Corinthian believers", "Regarded by Paul as children for whom he will gladly spend and be spent, though he fears finding strife and uncleanness among them (12:14-15,20-21)."),
    ],
    13: [
        ("Paul", "Warns he is coming a third time and will not spare, yet seeks to build up and not to destruction (13:1-2,10)."),
        ("Corinthian believers", "Told to examine themselves whether they are in the faith and to be of one mind and live in peace (13:5,11)."),
        ("Christ", "Crucified through weakness yet living by the power of God (13:4)."),
        ("God and the Holy Ghost", "Named in the closing blessing with the Lord Jesus Christ: the love of God and the communion of the Holy Ghost (13:14)."),
    ],
}

THEMES = {
    1: {
        "God comforts in affliction": "God comforts Paul in all his tribulation so that he can comfort others with the same comfort (1:3-7).",
        "Reliance on God, not self": "Paul despaired even of life in Asia so that he would trust not in himself but in God who raises the dead (1:8-11).",
        "Integrity and God’s promises": "Paul says his word was not yea and nay, because all the promises of God in Christ are yea and Amen (1:12-22).",
        "Care rather than control": "Paul stayed away to spare them, not because he has dominion over their faith but because he is a helper of their joy (1:23-24).",
    },
    2: {
        "Discipline with restoration": "Paul asks the church to forgive and comfort the person punished by the many, lest he be swallowed up with overmuch sorrow (2:5-8).",
        "Forgiveness and communal health": "Forgiveness keeps Satan from getting an advantage, for believers are not ignorant of his devices (2:9-11).",
        "Vulnerability in ministry": "Though a door was opened in Troas, Paul had no rest in his spirit because he did not find Titus (2:12-13).",
        "Integrity in proclamation": "Paul is a sweet savour of Christ in those who are saved and those who perish, and unlike many does not corrupt the word of God (2:14-17).",
    },
    3: {
        "Lives as testimony": "The Corinthians are Christ's epistle, known and read of all men, written by the Spirit of the living God (3:1-3).",
        "God-enabled ministry": "Paul's sufficiency is of God, who made him an able minister of the new testament, of the spirit and not the letter (3:4-6).",
        "Covenant glory": "The ministry of the Spirit is more glorious than the ministry of condemnation, whose glory was passing away (3:7-11).",
        "Freedom and transformation": "Where the Spirit of the Lord is, there is liberty, and believers are changed into the same image from glory to glory (3:12-18).",
    },
    4: {
        "Truthful ministry": "Paul has renounced the hidden things of dishonesty and commends himself by manifestation of the truth, since God shines in hearts (4:1-6).",
        "Treasure in fragile vessels": "This treasure is in earthen vessels so the excellency of the power may be of God and not of us (4:7-9).",
        "Life through suffering": "Always bearing about in the body the dying of the Lord Jesus, that his life may be made manifest, so that death works in Paul and life in them (4:10-15).",
        "Renewed perspective": "The outward man perisheth but the inward is renewed day by day, and affliction is light compared with the eternal weight of glory (4:16-18).",
    },
    5: {
        "Hope beyond mortality": "If the earthly tent is dissolved believers have a building of God, an house not made with hands, and prefer to be present with the Lord (5:1-8).",
        "Accountable living": "All must appear before the judgment seat of Christ, so Paul labours to be accepted of him and persuades men (5:9-13).",
        "New creation": "The love of Christ constrains Paul, and if any man be in Christ he is a new creature (5:14-17).",
        "Reconciliation": "God was in Christ reconciling the world to himself, and Paul and others are ambassadors for Christ, beseeching men to be reconciled (5:18-21).",
    },
    6: {
        "Responding to grace": "Now is the accepted time and the day of salvation, so the Corinthians should not receive the grace of God in vain (6:1-2).",
        "Faithfulness under pressure": "In afflictions, necessities, stripes, and imprisonments, Paul commends himself as sorrowful yet always rejoicing and poor yet making many rich (6:3-10).",
        "Openness in relationship": "Paul's mouth is open and his heart enlarged, and he asks the Corinthians to be enlarged as well (6:11-13).",
        "Holiness and loyalties": "Believers are not to be unequally yoked with unbelievers, for they are the temple of the living God (6:14-18).",
    },
    7: {
        "Pursuing holiness": "Having these promises, believers are to cleanse themselves from all filthiness of the flesh and spirit, perfecting holiness in the fear of God (7:1).",
        "Comfort through relationships": "Paul was troubled on every side, but God comforted him by the coming of Titus (7:5-7).",
        "Sorrow leading to repentance": "Godly sorrow worketh repentance to salvation, but the sorrow of the world worketh death (7:8-11).",
        "Restored trust": "Paul rejoices that Titus's spirit was refreshed and that he has confidence in the Corinthians in all things (7:12-16).",
    },
    8: {
        "Grace-filled generosity": "The Macedonians in deep poverty gave beyond their power, praying Paul for the privilege of taking part in the ministering to the saints (8:1-5).",
        "Christ as model": "Though he was rich, Christ for their sakes became poor, that they through his poverty might be rich (8:6-9).",
        "Fair sharing": "Giving is accepted according to what a man hath, that there may be equality, as it is written of the manna (8:10-15).",
        "Financial accountability": "Paul provides for honest things, not only in the sight of the Lord but of men, by sending Titus and trusted brethren (8:16-24).",
    },
    9: {
        "Readiness and integrity": "Paul sends brethren ahead so the gift will be ready as a matter of bounty and not of covetousness (9:1-5).",
        "Cheerful and voluntary giving": "He which soweth sparingly shall reap sparingly, and each should give as he purposeth in his heart, for God loveth a cheerful giver (9:6-7).",
        "Resources for good works": "God is able to make all grace abound so that believers, always having sufficiency, may abound to every good work (9:8-11).",
        "Generosity building gratitude": "The administration of this service supplies the saints' wants and abounds by many thanksgivings unto God (9:12-15).",
    },
    10: {
        "Gentleness and authority": "Paul beseeches by the meekness and gentleness of Christ, who is base among them in presence but bold when absent (10:1-2).",
        "Spiritual arguments, not physical force": "The weapons of warfare are not carnal but mighty through God to the pulling down of strong holds and every high thing that exalts itself against the knowledge of God (10:3-6).",
        "Authority to build up": "The authority the Lord gave Paul is for edification and not for destruction (10:7-11).",
        "Limits of boasting": "Paul will not boast beyond his measure, and he that glorieth is to glory in the Lord, for not he who commends himself is approved (10:12-18).",
    },
    11: {
        "Loyalty to Christ": "Paul is jealous with godly jealousy, having espoused them to one husband that he may present them as a chaste virgin to Christ (11:1-4).",
        "Integrity in support": "Paul preached the gospel freely, taking wages of other churches, and will keep from burdening them, unlike the false apostles (11:5-15).",
        "The cost of service": "Paul lists labours, stripes, imprisonments, shipwrecks, perils, hunger, and the care of all the churches (11:16-29).",
        "Boasting in weakness": "If he must glory, Paul will glory of the things which concern his infirmities, as when he was let down by the wall in a basket (11:30-33).",
    },
    12: {
        "Revelation and humility": "Paul speaks of a man caught up into the third heaven, yet keeps from boasting lest anyone think more of him than what he sees or hears from him (12:1-6).",
        "Grace amid weakness": "Given a thorn in the flesh, Paul hears, My grace is sufficient for thee, for my strength is made perfect in weakness (12:7-10).",
        "Love without exploitation": "Paul seeks not theirs but them, and will gladly spend and be spent for their souls, though the more he loves the less he is loved (12:11-18).",
        "Preparing for repentance": "Paul fears he will find debates, envyings, wraths, strifes, and uncleanness, and will mourn over those who have not repented (12:19-21).",
    },
    13: {
        "Evidence and accountability": "In the mouth of two or three witnesses shall every word be established, and Paul will not spare those who have sinned (13:1-2).",
        "Power expressed in weakness": "Christ was crucified through weakness yet liveth by the power of God, and Paul is weak in him but will live by God's power toward them (13:3-4).",
        "Self-examination": "The Corinthians are to examine themselves whether they be in the faith, and Paul's power is for edification and not destruction (13:5-10).",
        "Restoration and peace": "Paul closes: be perfect, be of good comfort, be of one mind, live in peace, and the God of love and peace shall be with you (13:11-14).",
    },
}

SUMMARY_FIXES = {
    2: [("because he could not find (Titus 2) Corinthians 2:12–13.", "because he could not find Titus (2 Corinthians 2:12–13).")],
    6: [("other associations is debated; its explicit imagery", "other associations is understood in different ways; its explicit imagery")],
}


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "47_2_corinthians.json"
    data = load(path)
    for n in range(1, 14):
        entry = data[f"{BOOK} {n}"]
        entry["whereWeAre"] = WWA[n]
        for old, new in SUMMARY_FIXES.get(n, []):
            if old not in entry["summary"]:
                raise SystemExit(f"{BOOK} {n}: summary fix not found: {old!r}")
            entry["summary"] = entry["summary"].replace(old, new)
        entry["keyFigures"] = [{"name": a, "role": b} for a, b in KEY_FIGURES[n]]
        theme_map = THEMES[n]
        seen = set()
        for theme in entry["keyThemes"]:
            if theme["theme"] not in theme_map:
                raise SystemExit(f"{BOOK} {n}: no explanation for {theme['theme']!r}")
            theme["explanation"] = theme_map[theme["theme"]]
            seen.add(theme["theme"])
        if set(theme_map) - seen:
            raise SystemExit(f"{BOOK} {n}: drafted themes not in source: {set(theme_map) - seen}")
        if len(entry["keyFigures"]) > 6 or len(entry["whereWeAre"]) > 600:
            raise SystemExit(f"{BOOK} {n}: figures {len(entry['keyFigures'])} or WWA {len(entry['whereWeAre'])} chars")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


AUDIENCE_FIXES = {
    1: "Corinthians who had heard Paul promise a visit and then not seen him come would have read his opening thanks for God's comfort as the start of an explanation owed to them.",
    4: "Believers who saw Paul's weakness and valued polished leaders would have needed to hear that God's power shows best in earthen vessels, not in impressive ones.",
    5: "Believers who knew that tents were temporary lodging, and that every traveler eventually faced a judge, would have found these pictures of the body and of judgment immediately concrete.",
    7: "Corinthians who had worried how Paul would take their response to a painful letter would have been relieved to learn that Titus's report had turned his anxiety into joy.",
    10: "Believers who had been told Paul's presence was weak would have heard his answer as a pointed reversal of the charge, with gentleness and authority both claimed from Christ.",
    12: "Corinthians impressed by rivals' visions and credentials would have noticed that Paul, who had real revelations, chose to boast of his weakness instead.",
}


def apply_chapter_context():
    path = ROOT / "chapter_context" / "37_corinthians.json"
    data = load(path)
    for n, text in AUDIENCE_FIXES.items():
        data[f"{BOOK} {n}"]["audience"] = text
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_book_overview():
    path = ROOT / "book_overviews" / "08_pauls_letters.json"
    data = load(path)
    book = data[BOOK]
    if book["keyVerse"] != "2 Corinthians 5:17":
        raise SystemExit("keyVerse changed")
    book["keyVerse"] = "2 Corinthians 12:9"
    for figure in book["keyFigures"]:
        if figure["name"] == "The 'super-apostles'":
            figure["name"] = "The “very chiefest apostles”"
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_PRONOUN_FIXES = [
    ("Either way, his goal is to please Him,", "Either way, his goal is to please him,"),
    ("God has done all this. He “hath reconciled us to himself by Jesus Christ,” and He has given believers",
     "God has done all this. he “hath reconciled us to himself by Jesus Christ,” and he has given believers"),
    ("and the comfort He gives His people even in suffering.", "and the comfort he gives his people even in suffering."),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "08_pauls_letters.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("\n# 2 Corinthians") + 1
    end = text.index("\n# Galatians", start)
    section = text[start:end]
    for old, new in STORY_PRONOUN_FIXES:
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
