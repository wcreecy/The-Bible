#!/usr/bin/env python3
"""Apply the completed editorial review for Romans to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


WWA = {
    1: ("Acts closed with Paul under guard in Rome, preaching the kingdom of God to all who came to him "
        "(Acts 28:30-31). Romans is the letter he wrote to that city's believers before ever reaching it: "
        "he introduces himself as an apostle, says he longs to visit them, and states his theme that the "
        "gospel is God's power to save everyone who believes, before describing why the whole world needs "
        "it (1:1-32). That diagnosis of human sin turns in chapter 2 toward the person who judges others."),
    2: ("Chapter 1 ended with Paul describing a world that exchanged the truth about God for idols (1:18-32). "
        "Chapter 2 turns on the reader who agrees and feels superior: God judges everyone impartially by "
        "their deeds, those with the written law and those without it, and having the law or circumcision "
        "is not enough without a changed heart (2:1-29). That levels the ground for chapter 3's question "
        "about what advantage the Jew has."),
    3: ("Chapter 2 ended with Paul saying true circumcision is of the heart, not the flesh (2:28-29). "
        "Chapter 3 asks what advantage the Jew has, answers that Israel was entrusted with God's words, "
        "then strings together Scripture to show that Jews and Gentiles are alike under sin before "
        "announcing that God's righteousness comes through faith in Jesus Christ for all who believe "
        "(3:1-31). Chapter 4 tests that claim against Abraham."),
    4: ("Chapter 3 ended with Paul saying that faith does not cancel the law but establishes it (3:31). "
        "Chapter 4 proves the point from Scripture: Abraham believed God and it was counted to him for "
        "righteousness before he was circumcised, and David describes the same blessing of forgiven sin "
        "(4:1-25). That faith, resting on God who raises the dead, opens chapter 5's picture of peace "
        "with God."),
    5: ("Chapter 4 ended with Jesus delivered for our offences and raised for our justification (4:25). "
        "Chapter 5 describes what that gives believers, peace with God and hope in suffering, then widens "
        "to compare Adam, through whom sin and death entered the world, with Christ, through whom grace "
        "and life abound (5:1-21). Grace's abundance raises the question chapter 6 answers."),
    6: ("Chapter 5 ended with grace abounding where sin abounded (5:20-21). Chapter 6 answers the "
        "objection that this invites more sinning: believers were baptized into Christ's death and "
        "resurrection, so they are to count themselves dead to sin, offer themselves to God, and serve "
        "righteousness instead of sin (6:1-23). Chapter 7 turns to the law's place in that freedom."),
    7: ("Chapter 6 ended with the wages of sin set against God's gift of eternal life (6:23). Chapter 7 "
        "uses marriage to explain how believers have died to the law, defends the law as holy and good, "
        "and describes in the first person the struggle of knowing the good yet doing what is hated, "
        "ending in thanks to God through Jesus Christ (7:1-25). That cry for deliverance is answered "
        "in chapter 8."),
    8: ("Chapter 7 ended with Paul thanking God through Jesus Christ for deliverance from the body of "
        "this death (7:24-25). Chapter 8 declares no condemnation for those in Christ, describes life "
        "by the Spirit, adoption as God's children, and creation groaning for redemption, and closes "
        "with the assurance that nothing can separate believers from God's love (8:1-39). Chapter 9 "
        "turns to Paul's sorrow over his own people."),
    9: ("Chapter 8 ended with nothing able to separate believers from the love of God (8:38-39). "
        "Chapter 9 raises the painful question that assurance invites, whether God's word to Israel has "
        "failed: Paul grieves for his kinsmen, shows that the promise follows God's call through Isaac "
        "and Jacob, and describes God's mercy toward Jews and Gentiles alike (9:1-33). Chapter 10 "
        "continues with Israel's response."),
    10: ("Chapter 9 ended with Israel stumbling at the stone laid in Zion (9:32-33). Chapter 10 shows "
         "Paul praying for his people's salvation, explaining that Christ is the end of the law for "
         "righteousness to everyone who believes, and tracing how faith comes through sending, "
         "preaching, and hearing (10:1-21). Chapter 11 asks whether Israel's stumbling is final."),
    11: ("Chapter 10 ended with God stretching out his hands to a disobedient and contrary people "
         "(10:21). Chapter 11 answers that God has not cast them away: Paul points to himself and a "
         "remnant, pictures Gentile believers as wild branches grafted into Israel's olive tree, and "
         "praises the depth of God's wisdom (11:1-36). That doxology closes the argument and opens "
         "chapter 12's call to live it out."),
    12: ("Chapter 11 ended with praise that all things are of God, through him, and to him (11:36). "
         "Chapter 12 turns from argument to life: Paul urges believers, in view of God's mercies, to "
         "present themselves as a living sacrifice, serve as one body with different gifts, love "
         "sincerely, and overcome evil with good (12:1-21). Chapter 13 extends that conduct to "
         "governing authorities and neighbors."),
    13: ("Chapter 12 ended with the call to overcome evil with good (12:21). Chapter 13 applies it "
         "publicly: believers are to be subject to governing authorities and pay what they owe, to owe "
         "no one anything but love, and to wake from sleep because salvation is nearer than when they "
         "believed (13:1-14). Chapter 14 brings the same love to disagreements inside the church."),
    14: ("Chapter 13 ended with Paul telling believers to put on the Lord Jesus Christ (13:14). "
         "Chapter 14 shows what that means among believers who disagree about food and holy days: "
         "welcome one another, stop judging, answer to the Lord, and do not cause a brother to "
         "stumble, since the kingdom of God is righteousness, peace, and joy in the Holy Ghost "
         "(14:1-23). Chapter 15 carries that unity into Paul's plans."),
    15: ("Chapter 14 ended with Paul warning against acting against conscience (14:23). Chapter 15 asks "
         "the strong to bear with the weak as Christ did, urges Jews and Gentiles to glorify God "
         "together, and shares Paul's plans to carry a collection to Jerusalem and then visit Rome on "
         "the way to Spain (15:1-33). Chapter 16 fills in the people behind those plans."),
    16: ("Chapter 15 ended with Paul asking for prayer for his journey to Jerusalem (15:30-33). Chapter "
         "16 commends Phebe, who probably carried the letter, greets many named believers, warns "
         "against those who cause divisions, and closes with greetings and a doxology (16:1-27). "
         "That personal network leads into the letters Paul wrote to the churches he had already "
         "planted, beginning with 1 Corinthians."),
}

KEY_FIGURES = {
    1: [
        ("Paul", "Introduces himself as an apostle set apart for the gospel, thanks God for Rome's faith, and says he has long wanted to visit them (1:1-15)."),
        ("Jesus Christ", "The subject of the gospel, descended from David and declared the Son of God with power by the resurrection from the dead (1:3-4)."),
        ("Believers in Rome", "Addressed as beloved of God and called to be saints, with a faith spoken of throughout the whole world (1:7-8)."),
        ("Gentiles and Greeks", "Named with the Jews as those the gospel is for, and as those who suppressed the truth about God and turned to idols (1:14,16,18-25)."),
        ("God", "Reveals his righteousness in the gospel and his wrath against ungodliness, and gives people up to what they have chosen (1:17-18,24-28)."),
    ],
    2: [
        ("Paul", "Confronts judging and complacency by speaking directly to an imagined questioner and to one who calls himself a Jew (2:1,17)."),
        ("The judging person", "A representative objector who condemns others while doing the same things, and is told God's goodness is meant to lead him to repentance (2:1-5)."),
        ("Jews and Gentiles", "Both are judged by deeds without partiality, whether they have the written law or only a conscience that bears witness (2:9-16)."),
        ("God", "Judges each person impartially according to deeds and sees the secrets of the heart through Jesus Christ (2:6,11,16)."),
    ],
    3: [
        ("Paul", "Answers what advantage the Jew has, gathers Scripture to show all are under sin, and explains righteousness through faith (3:1-31)."),
        ("Jews and Gentiles", "Shown by a chain of Psalms and Isaiah to be alike under sin, and both justified by faith in the one God (3:9-20,29-30)."),
        ("Jesus Christ", "Set forth by God as a propitiation through faith in his blood, the redemption by which believers are justified freely (3:24-25)."),
        ("God", "Stays faithful though every man is a liar, and is both just and the justifier of the one who believes in Jesus (3:3-4,26)."),
    ],
    4: [
        ("Abraham", "Believed God and it was counted to him for righteousness before he was circumcised, making him father of all who believe (4:3,9-12)."),
        ("David", "Quoted by Paul as describing the blessing of the person whose sins are forgiven and not counted against him (4:6-8)."),
        ("Paul", "Reads Genesis and the Psalms to show that righteousness comes by faith, not works, and applies it to those who believe in God who raised Jesus (4:1-25)."),
        ("Jesus Christ", "Delivered for our offences and raised again for our justification (4:24-25)."),
    ],
    5: [
        ("Paul", "Moves from peace with God through justification to a comparison of Adam and Christ (5:1-21)."),
        ("Jesus Christ", "Dies for the ungodly while they are still sinners, and through his one act of obedience brings justification of life to many (5:6-8,18-19)."),
        ("Adam", "The one man through whom sin entered the world, and death by sin, passing to all (5:12-14)."),
        ("Believers", "Have peace with God, access into grace, and a hope that does not shame them, even in tribulation (5:1-5)."),
    ],
    6: [
        ("Paul", "Rejects the idea that believers should keep sinning so grace can abound, using baptism and slavery as his pictures (6:1-23)."),
        ("Jesus Christ", "Died and was raised, so that those baptized into him walk in newness of life (6:3-10)."),
        ("Baptized believers", "Told to count themselves dead to sin and alive to God, and to yield their members to him as instruments of righteousness (6:11-13)."),
    ],
    7: [
        ("Paul", "Uses marriage law to show believers have died to the law through Christ, then defends the law as holy and just (7:1-13)."),
        ("The first-person “I”", "The voice of 7:7-25, who delights in God's law yet finds another law at work in his members and cries out for deliverance (7:7-24)."),
        ("Jesus Christ", "Named in the closing thanksgiving as the one through whom God delivers from the body of this death (7:24-25)."),
    ],
    8: [
        ("Paul", "Declares no condemnation for those in Christ and ends with a list of things that cannot separate believers from God's love (8:1,35-39)."),
        ("Jesus Christ", "Died, rose, and makes intercession at the right hand of God, so that nothing can separate believers from his love (8:34-35)."),
        ("Holy Spirit", "Frees believers from the law of sin and death, bears witness that they are children of God, and helps their weakness with groanings that cannot be uttered (8:2,15-16,26)."),
        ("Believers and creation", "Both groan while waiting for redemption, believers as adopted children and the creation as in the pains of childbirth (8:19-23)."),
    ],
    9: [
        ("Paul", "Grieves over his kinsmen according to the flesh and argues that God's word to Israel has not failed (9:1-6)."),
        ("Israelites", "Paul's kinsmen, to whom belong the adoption, the glory, the covenants, the law, and the promises (9:3-5)."),
        ("Isaac, Ishmael, Jacob and Esau", "Genesis figures through whom Paul shows that the promise follows God's call, not physical descent alone (9:7-13)."),
        ("Moses and Pharaoh", "Cited from Exodus to show God's mercy on whom he will have mercy and his hardening of Pharaoh (9:15-18)."),
        ("Gentiles", "Called as God's people according to Hosea, and attain righteousness by faith while Israel stumbles at the stumblingstone (9:24-26,30-33)."),
    ],
    10: [
        ("Paul", "Prays for Israel's salvation, saying they have a zeal of God but not according to knowledge (10:1-3)."),
        ("Israel", "Pursues righteousness by the law and stumbles, yet is told that God has stretched out his hands all day long to a disobedient people (10:3,21)."),
        ("Jesus Christ", "The end of the law for righteousness to everyone who believes, confessed as Lord and believed raised from the dead (10:4,9)."),
        ("Moses and Isaiah", "Quoted to describe the word of faith near at hand and to show Gentiles finding God while Israel resists (10:5-8,16,19-21)."),
    ],
    11: [
        ("Paul", "Points to himself as an Israelite to show God has not cast away his people, and warns Gentile believers against boasting (11:1,13-24)."),
        ("Elijah", "Recalled for complaining that he alone was left, and for the answer that God had reserved seven thousand men (11:2-4)."),
        ("Israel and Gentiles", "Pictured as natural branches broken off and wild olive branches grafted in, with a promise that all Israel shall be saved (11:17-26)."),
        ("God", "Has not cast away his people, grafts branches in and can graft them in again, and is praised for the depth of his wisdom and knowledge (11:1-2,23,33-36)."),
    ],
    12: [
        ("Paul", "Beseeches believers by God's mercies to present their bodies as a living sacrifice and be transformed by the renewing of their minds (12:1-2)."),
        ("Believers as one body", "Many members in one body in Christ, each with a different gift to use for the others (12:4-8)."),
        ("Enemies and persecutors", "Those who curse or wrong believers, who are told to bless and not curse, and to overcome evil with good (12:14,17-21)."),
    ],
    13: [
        ("Paul", "Tells believers to be subject to the higher powers, to pay what is owed, and to owe no one anything but love (13:1-8)."),
        ("Governing authorities", "Described as God's ministers who bear the sword, praise good conduct, and punish evil (13:1-4)."),
        ("Neighbors and fellow believers", "The ones believers are told to love, since love is the fulfilling of the law (13:8-10)."),
        ("Jesus Christ", "The Lord whom believers are told to put on, making no provision for the flesh (13:14)."),
    ],
    14: [
        ("Paul", "Calls believers to welcome one another without quarreling over doubtful things such as food and days (14:1-6)."),
        ("The weak in faith", "Believers who eat only herbs or esteem one day above another, and are told not to be judged or despised (14:1-6)."),
        ("Those who eat all things", "Believers with broader freedom, told not to despise the weak or put a stumblingblock in a brother's way (14:3,13-21)."),
        ("The Lord", "The master before whom each believer stands or falls, and before whose judgment seat all will give account (14:4,10-12)."),
    ],
    15: [
        ("Paul", "Describes his ministry to the Gentiles, his plan to bring a collection to Jerusalem, and his hope to visit Rome on the way to Spain (15:14-29)."),
        ("Jesus Christ", "Pleased not himself and became a minister of the circumcision to confirm the promises, so that Gentiles might glorify God for his mercy (15:3,8-9)."),
        ("Gentile believers", "Share in the collection for the poor saints at Jerusalem, having been made partakers of their spiritual things (15:26-27)."),
        ("Poor believers in Jerusalem", "The recipients of a gift from Macedonia and Achaia that Paul carries to them (15:25-26)."),
    ],
    16: [
        ("Phebe", "A servant of the church at Cenchrea and a succourer of many, commended to the Romans and probably the letter's carrier (16:1-2)."),
        ("Priscilla and Aquila", "Paul's helpers in Christ Jesus who risked their necks for his life and host a church in their house (16:3-5)."),
        ("Andronicus and Junia", "Paul's kinsmen and fellow prisoners, described as of note among the apostles and in Christ before Paul (16:7)."),
        ("Timothy and Tertius", "Timothy sends greetings, and Tertius identifies himself as the one who wrote the letter (16:21-22)."),
        ("Other greeted believers", "Many named men, women, and households whom Paul greets and honors for their labor in the Lord (16:5-16)."),
    ],
}

THEMES = {
    1: {
        "The gospel for all": "Paul says the gospel is the power of God unto salvation to everyone who believes, to the Jew first and also to the Greek (1:16-17).",
        "Creator and idolatry": "Though God's power is plain in creation, people changed the truth of God into a lie and worshiped the creature more than the Creator (1:18-25).",
        "Human accountability": "Paul lists the evils that follow when God gives people up to what they chose, and says those who do them are without excuse (1:28-32).",
    },
    2: {
        "Impartial judgment": "God will render to every man according to his deeds, for there is no respect of persons with God (2:6-11).",
        "Hearing and doing": "Not the hearers of the law but the doers are justified, and even Gentiles show the law written in their hearts through conscience (2:12-16).",
        "Inward and outward identity": "Circumcision matters only with obedience, and a true Jew is one inwardly, whose circumcision is of the heart (2:25-29).",
    },
    3: {
        "Universal sin": "A chain of Psalms and Isaiah shows that there is none righteous, no, not one, and every mouth is stopped before God (3:9-20).",
        "Justification and grace": "All have sinned, and believers are justified freely by God's grace through the redemption that is in Christ Jesus (3:21-26).",
        "One God of all": "Boasting is excluded, since the one God justifies both the circumcised and the uncircumcised by faith (3:27-31).",
    },
    4: {
        "Faith before circumcision": "Abraham was counted righteous in Genesis 15, before he was circumcised in Genesis 17, so he is father of all who believe (4:9-12).",
        "Promise and grace": "The promise came through the righteousness of faith, not the law, so that it might be by grace and sure to all the seed (4:13-17).",
        "Faith amid impossibility": "Abraham, nearly a hundred years old, did not stagger at the promise but was fully persuaded that God could perform it (4:18-25).",
    },
    5: {
        "Peace and hope": "Justified by faith, believers have peace with God, access into grace, and a hope that does not make ashamed even in tribulation (5:1-5).",
        "Love toward sinners": "God commended his love in that Christ died for us while we were yet sinners, and we were reconciled while enemies (5:6-11).",
        "Adam and Christ": "Sin and death entered through one man, but the gift of grace by one man, Jesus Christ, abounds much more (5:12-21).",
    },
    6: {
        "Baptism and new life": "Buried with Christ by baptism into death, believers are raised to walk in newness of life (6:3-11).",
        "Grace is not permission to sin": "Paul answers the question whether to continue in sin that grace may abound with God forbid, since believers died to sin (6:1-2).",
        "Freedom and service": "Everyone serves something, sin that pays death or obedience that leads to righteousness, and eternal life is God's gift through Jesus Christ (6:15-23).",
    },
    7: {
        "Law and sin distinguished": "The law is holy, just, and good; it is sin that took occasion by the commandment and worked death (7:7-13).",
        "Inner struggle": "Paul describes willing the good but doing the evil he hates, a war between the law of his mind and the law in his members (7:14-24).",
        "Liberation through Christ": "The cry, who shall deliver me from the body of this death, is answered with thanks to God through Jesus Christ our Lord (7:24-25).",
    },
    8: {
        "Life in the Spirit": "There is no condemnation to those in Christ Jesus, because the law of the Spirit of life has made them free from the law of sin and death (8:1-11).",
        "Adoption and suffering": "Those led by the Spirit are children and heirs of God, and present sufferings are not worthy to be compared with the coming glory (8:12-25).",
        "Enduring divine love": "If God is for us, nothing, not death, life, nor any other creature, can separate us from the love of God in Christ Jesus (8:31-39).",
    },
    9: {
        "Sorrow and covenant privilege": "Paul has great heaviness for his kinsmen, to whom belong the adoption, the glory, the covenants, the law, and the promises (9:1-5).",
        "Promise and divine mercy": "God's word has not failed, for the promise follows his call through Isaac and Jacob, and he has mercy on whom he will have mercy (9:6-24).",
        "Remnant and inclusion": "Hosea and Isaiah show God calling a people from the Gentiles and saving a remnant of Israel, who stumbled at the stumblingstone (9:25-33).",
    },
    10: {
        "Righteousness and faith": "Christ is the end of the law for righteousness to everyone who believes, and confessing him as Lord and believing he was raised brings salvation (10:3-10).",
        "Salvation offered broadly": "There is no difference between Jew and Greek, for whosoever shall call upon the name of the Lord shall be saved (10:11-13).",
        "Hearing and proclamation": "Paul traces calling, believing, hearing, preaching, and sending, ending that faith cometh by hearing and hearing by the word of God (10:14-17).",
        "Israel’s response": "Quoting Moses and Isaiah, Paul says Israel has heard yet remains a disobedient and gainsaying people toward whom God stretches out his hands (10:18-21).",
    },
    11: {
        "Israel not abandoned": "God has not cast away his people; Paul is himself an Israelite, and a remnant exists according to the election of grace (11:1-6).",
        "Humility of Gentile believers": "Gentile believers are wild branches grafted into the olive tree and are warned not to boast against the branches (11:17-24).",
        "Mystery and mercy": "Blindness in part has happened to Israel until the fulness of the Gentiles comes in, and God has concluded all in unbelief that he might have mercy on all (11:25-32).",
        "Divine wisdom": "Paul ends in praise for the depth of the riches of God's wisdom and knowledge, for of him, and through him, and to him are all things (11:33-36).",
    },
    12: {
        "Renewed living": "In view of God's mercies, believers present their bodies a living sacrifice and are transformed by the renewing of their minds (12:1-2).",
        "One body, many gifts": "Believers are many members in one body, each using a different gift for the others (12:3-8).",
        "Sincere love": "Paul urges love without dissimulation, kindness, hospitality, rejoicing with those who rejoice and weeping with those who weep (12:9-16).",
        "Overcome evil with good": "Believers are told not to repay evil for evil but to feed a hungry enemy and overcome evil with good (12:17-21).",
    },
    13: {
        "Public authority and accountability": "Believers are to be subject to the higher powers as God's ministers, and to render tribute, custom, fear, and honor to whom each is due (13:1-7).",
        "Love fulfills the Law": "Owing no one anything but to love one another, believers fulfil the law, since love works no ill to his neighbour (13:8-10).",
        "Living in wakefulness": "Because salvation is nearer, believers are to cast off the works of darkness and put on the Lord Jesus Christ (13:11-14).",
    },
    14: {
        "Welcome amid disagreement": "Believers are to receive the one who is weak in faith without quarreling over doubtful things such as food and days (14:1-6).",
        "Responsibility before God": "Whether living or dying, believers are the Lord's, and each will give account of himself to God at the judgment seat of Christ (14:7-12).",
        "Love limits liberty": "The kingdom of God is righteousness, peace, and joy in the Holy Ghost, so believers avoid putting a stumblingblock before a brother (14:13-23).",
    },
    15: {
        "Mutual welcome": "The strong bear the infirmities of the weak, receiving one another as Christ received them to the glory of God (15:1-7).",
        "Jews and Gentiles praising God": "Christ confirmed the promises to the fathers so that Gentiles might also glorify God for his mercy, as the Scriptures foretold (15:8-13).",
        "Mission and generosity": "Paul describes preaching where Christ was not named, and his plan to carry the Macedonian and Achaian gift to Jerusalem before going to Spain (15:14-29).",
        "Prayer and uncertainty": "Paul asks the Romans to strive with him in prayer that he may be delivered from unbelievers in Judea and that his service be accepted (15:30-33).",
    },
    16: {
        "Shared ministry": "Paul commends Phebe and greets Priscilla, Aquila, Andronicus, and Junia as fellow workers and fellow prisoners in Christ (16:1-7).",
        "House churches and hospitality": "Paul greets a church in Priscilla and Aquila's house and many named believers, women and men, for their labor in the Lord (16:3-16).",
        "Guarding community unity": "Paul urges believers to mark those who cause divisions contrary to the doctrine they learned, and promises that God will bruise Satan under their feet (16:17-20).",
        "Praise and revelation": "The letter ends in glory to God, who is able to establish believers according to the gospel and the revelation of the mystery now made known to all nations (16:25-27).",
    },
}

SUMMARY_FIXES = {
    7: [("Scholars disagree on whether the 'I' depicts Paul’s own present experience, life before Christ, Israel, or a representative human being; the text emphasizes sin's power and the Law's inability by itself to liberate.",
         "Readers have understood the first-person voice as Paul’s own present experience, his life before Christ, Israel, or a representative human being; the passage emphasizes sin's power and the Law's inability by itself to liberate.")],
    11: [("declares that 'all Israel will be saved,' a phrase interpreted in different ways",
          "declares that “all Israel shall be saved,” a phrase Christians have read in different ways")],
    13: [("although Christians have debated how these instructions apply",
          "although Christians have long asked how these instructions apply")],
}


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "45_romans.json"
    data = load(path)
    for n in range(1, 17):
        entry = data[f"Romans {n}"]
        entry["whereWeAre"] = WWA[n]
        for old, new in SUMMARY_FIXES.get(n, []):
            if old not in entry["summary"]:
                raise SystemExit(f"Romans {n}: summary fix not found: {old!r}")
            entry["summary"] = entry["summary"].replace(old, new)
        if n == 16:
            for old, new in [("Phoebe", "Phebe"), ("Cenchreae", "Cenchrea"), ("Prisca and Aquila", "Priscilla and Aquila")]:
                entry["summary"] = entry["summary"].replace(old, new)
        entry["keyFigures"] = [{"name": a, "role": b} for a, b in KEY_FIGURES[n]]
        theme_map = THEMES[n]
        seen = set()
        for theme in entry["keyThemes"]:
            if theme["theme"] not in theme_map:
                raise SystemExit(f"Romans {n}: no explanation for {theme['theme']!r}")
            theme["explanation"] = theme_map[theme["theme"]]
            seen.add(theme["theme"])
        if set(theme_map) - seen:
            raise SystemExit(f"Romans {n}: drafted themes not in source: {set(theme_map) - seen}")
        if len(entry["keyFigures"]) > 6 or len(entry["whereWeAre"]) > 600:
            raise SystemExit(f"Romans {n}: too many figures or WWA {len(entry['whereWeAre'])} chars")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


AUDIENCE_FIXES = {
    1: "Roman believers who knew Paul only by reputation, and whose own faith was already spoken of across the empire (Romans 1:8), would have read this long, careful introduction as an apostle earning a hearing before he arrived.",
    3: "Jewish and Gentile hearers in Rome who knew the Psalms and Isaiah would have recognized each quoted line, and felt the weight of hearing them strung together as a single verdict on everyone.",
    7: "Believers who knew the law of Moses would have followed the marriage illustration easily, since the rule that a husband's death frees his wife from her obligation was familiar in Jewish and Roman households alike.",
    8: "Believers living under a government that could turn on them would have heard the closing list of things that cannot separate them from God's love as an answer to fears they actually carried.",
    9: "Jewish believers in Rome would have recognized a fellow Israelite grieving for his own people, while Gentile believers would have been reminded that the promises they now shared were first Israel's.",
    10: "Hearers would have taken from the chain of questions about calling, believing, hearing, preaching, and sending that the message depends on messengers, including the letter they were then listening to.",
    13: "Believers in a capital where tax collectors were openly resented would have felt the weight of Paul's instruction to pay what is owed to whom it is due.",
    14: "Jewish and Gentile believers who shared meals in the same homes would have heard the call to welcome one another as addressed to the very table where their differing customs met.",
    15: "Believers in Rome would have understood Paul's travel plans as a request for partnership, since Spain lay beyond any existing church's reach and he hoped Rome would help send him there.",
}


def apply_chapter_context():
    path = ROOT / "chapter_context" / "36_romans.json"
    data = load(path)
    for n, text in AUDIENCE_FIXES.items():
        data[f"Romans {n}"]["audience"] = text
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_book_overview():
    path = ROOT / "book_overviews" / "08_pauls_letters.json"
    data = load(path)
    romans = data["Romans"]
    for figure in romans["keyFigures"]:
        if figure["name"] == "Phoebe":
            figure["name"] = "Phebe"
            figure["description"] = figure["description"].replace("Cenchreae", "Cenchrea")
    if romans["keyVerse"] != "Romans 8:28":
        raise SystemExit("Romans keyVerse changed")
    romans["keyVerse"] = "Romans 1:16"
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_PRONOUN_FIXES = [
    ("because God shows Himself through creation:", "because God shows himself through creation:"),
    ("But people refused to honor Him.", "But people refused to honor him."),
    ("because “the goodness of God leadeth thee to repentance.” He will judge everyone",
     "because “the goodness of God leadeth thee to repentance.” he will judge everyone"),
    ("a way to be right with Him that does not depend", "a way to be right with him that does not depend"),
    ("the sacrifice that turns away His anger,", "the sacrifice that turns away his anger,"),
    ("We stand in His grace and look forward to His glory.", "We stand in his grace and look forward to his glory."),
    ("because God has poured His love into our hearts", "because God has poured his love into our hearts"),
    ("And His love is amazing:", "And his love is amazing:"),
    ("God did by sending His own Son.", "God did by sending his own Son."),
    ("God did not spare His own Son, so surely He will give us everything else.",
     "God did not spare his own Son, so surely he will give us everything else."),
    ("God's freedom to show mercy, and His continuing purposes", "God's freedom to show mercy, and his continuing purposes"),
    ("and the Messiah Himself came from them.", "and the Messiah himself came from them."),
    ("God has always chosen freely. He chose Isaac, not Ishmael. Before the twins were born, He chose Jacob,",
     "God has always chosen freely. he chose Isaac, not Ishmael. Before the twins were born, he chose Jacob,"),
    ("shape the clay as He wishes.", "shape the clay as he wishes."),
    ("God does not take back His promises.", "God does not take back his promises."),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "08_pauls_letters.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("# Romans")
    end = text.index("\n# 1 Corinthians", start)
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
