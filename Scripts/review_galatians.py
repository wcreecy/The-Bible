#!/usr/bin/env python3
"""Apply the completed editorial review for Galatians to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BOOK = "Galatians"


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


SUMMARY = {
    1: ("Paul opens as an apostle sent not of men, neither by man, but by Jesus Christ and God the Father, who raised him from the dead, and says Christ gave himself for our sins (Galatians 1:1–5). Instead of his usual thanks he marvels that the Galatians are so soon turning to another gospel, and says anyone who preaches a different one is accursed (Galatians 1:6–10). To show his message came from God, he tells his story: a zealous persecutor whom God called by his grace and who received the gospel by the revelation of Jesus Christ (Galatians 1:11–17). He went to Arabia and Damascus, and only after three years visited Peter in Jerusalem for fifteen days and saw James the Lord's brother, then went to Syria and Cilicia (Galatians 1:18–24)."),
    2: ("Fourteen years later Paul went up to Jerusalem with Barnabas and Titus and laid before the leaders the gospel he preached among the Gentiles; Titus, a Greek, was not compelled to be circumcised, though false brethren spied out their liberty (Galatians 2:1–5). James, Cephas, and John added nothing to Paul's message and gave him and Barnabas the right hands of fellowship, asking only that they remember the poor (Galatians 2:6–10). At Antioch Peter drew back from eating with Gentiles when certain came from James, and Paul withstood him to the face (Galatians 2:11–14). Paul says a man is not justified by the works of the law but by the faith of Jesus Christ, that he is crucified with Christ, and that if righteousness comes by the law, Christ is dead in vain (Galatians 2:15–21)."),
    3: ("Paul asks the foolish Galatians who has bewitched them, since Christ was openly set forth crucified among them, and whether they received the Spirit by the works of the law or by the hearing of faith (Galatians 3:1–5). Abraham believed God and it was counted to him for righteousness, so those of faith are his children, and the Scripture foresaw that God would justify the heathen through faith (Galatians 3:6–9). Those under the law are under a curse, but Christ hath redeemed us from the curse of the law, being made a curse for us (Galatians 3:10–14). The law, given four hundred and thirty years after the promise, cannot disannul it; it was added because of transgressions and was a schoolmaster to bring us to Christ (Galatians 3:15–25). All are children of God by faith in Christ Jesus, one in him, and Abraham's seed and heirs according to the promise (Galatians 3:26–29)."),
    4: ("Paul says an heir is no different from a servant while he is a child, under tutors and governors until the time appointed of the father (Galatians 4:1–3). When the fulness of the time was come, God sent forth his Son, made of a woman, made under the law, to redeem them that were under the law, and sent the Spirit of his Son into their hearts, crying, Abba, Father (Galatians 4:4–7). He asks how the Galatians can turn back to weak and beggarly elements and observe days, months, times, and years (Galatians 4:8–11). He reminds them how they received him in his infirmity of the flesh as an angel of God, fears he has become their enemy by telling the truth, and travails in birth again until Christ be formed in them (Galatians 4:12–20). He ends with an allegory of Hagar and Sarah, Ishmael and Isaac, saying believers are children of the free woman (Galatians 4:21–31)."),
    5: ("Paul calls the Galatians to stand fast in the liberty wherewith Christ hath made them free and not be entangled again with the yoke of bondage (Galatians 5:1). If they are circumcised, Christ shall profit them nothing and they are debtors to do the whole law, for in Christ what avails is faith which worketh by love (Galatians 5:2–12). They are called to liberty, but not to use it for an occasion to the flesh; by love they are to serve one another, since all the law is fulfilled in loving one's neighbour as oneself (Galatians 5:13–15). He tells them to walk in the Spirit, lists the works of the flesh, and sets against them the fruit of the Spirit, against which there is no law (Galatians 5:16–26)."),
    6: ("Paul tells those who are spiritual to restore a man overtaken in a fault in the spirit of meekness, to bear one another's burdens, and so to fulfil the law of Christ (Galatians 6:1–5). He teaches that God is not mocked, that whatsoever a man soweth he shall reap, and that believers should not be weary in well doing but do good to all men, especially the household of faith (Galatians 6:6–10). Writing with his own hand in large letters, he says those who push circumcision want to avoid persecution and glory in the flesh, while he will glory only in the cross of our Lord Jesus Christ (Galatians 6:11–14). He says neither circumcision nor uncircumcision matters, but a new creature, and closes bearing in his body the marks of the Lord Jesus, with a blessing of grace (Galatians 6:15–18)."),
}

WWA = {
    1: ("Second Corinthians ended with a blessing of grace on a church Paul feared might drift (2 Corinthians 13:11-14). Galatians shows a drift already under way: Paul skips his usual thanks, marvels that the churches of Galatia are turning to another gospel, and defends the gospel he received by revelation, telling how God called him and how little he first consulted Jerusalem (1:1-24). Chapter 2 continues that story with a later visit there."),
    2: ("Chapter 1 ended with the churches of Judaea glorifying God over Paul's change (1:22-24). Chapter 2 continues his story with a later visit to Jerusalem, where the leaders added nothing to his gospel and Titus was not compelled to be circumcised, then tells how he withstood Peter at Antioch and states that a man is justified by faith in Christ, not works of the law (2:1-21). Chapter 3 turns that statement on the Galatians."),
    3: ("Chapter 2 ended with Paul saying that if righteousness came by the law, Christ is dead in vain (2:21). Chapter 3 presses the Galatians directly: they received the Spirit by hearing with faith, Abraham was counted righteous by believing, Christ redeemed us from the law's curse, and the law, given long after the promise, was a schoolmaster until Christ (3:1-29). Chapter 4 explains what that makes believers: sons and heirs."),
    4: ("Chapter 3 ended with believers being all one in Christ Jesus and heirs according to the promise (3:26-29). Chapter 4 explains with a picture of an heir under guardians until the time appointed, says God sent his Son to redeem them, pleads with the Galatians not to return to weak elements, and uses Hagar and Sarah as an allegory of slavery and freedom (4:1-31). Chapter 5 turns to how free people should live."),
    5: ("Chapter 4 ended with believers being children of the free woman, not the bondwoman (4:31). Chapter 5 therefore says to stand fast in liberty and not accept circumcision as a requirement, warns against using freedom as an occasion to the flesh, and sets the works of the flesh against the fruit of the Spirit (5:1-26). Chapter 6 gives practical instructions for life together."),
    6: ("Chapter 5 ended with a call to live and walk in the Spirit (5:25-26). Chapter 6 applies it: restore the fallen gently, bear one another's burdens, sow to the Spirit, and do good to all, then Paul takes the pen himself to say he will glory only in the cross of our Lord Jesus Christ, and ends with grace (6:1-18). Ephesians, which follows, sets out life in Christ at greater length."),
}

KEY_FIGURES = {
    1: [
        ("Paul", "Writes as an apostle sent by Jesus Christ and God the Father, and tells how he went from persecuting the church to preaching the faith he once destroyed (1:1,13-24)."),
        ("God the Father and Jesus Christ", "Jesus Christ gave himself for our sins, and God raised him from the dead, called Paul by his grace, and revealed his Son in him (1:1,4,15-16)."),
        ("The churches of Galatia", "The recipients, whom Paul says are so soon removed from the grace of Christ unto another gospel (1:2,6)."),
        ("Those who trouble the Galatians", "Unnamed people who would pervert the gospel of Christ, which Paul says is no other gospel at all (1:7-9)."),
        ("Cephas (Peter)", "Visited by Paul in Jerusalem for fifteen days three years after his calling (1:18)."),
        ("James the Lord’s brother", "The only other apostle Paul saw on that first visit to Jerusalem (1:19)."),
    ],
    2: [
        ("Paul", "Lays his gospel before the Jerusalem leaders, withstands Peter to the face at Antioch, and says he is crucified with Christ (2:2,11,20)."),
        ("Barnabas and Titus", "Go up to Jerusalem with Paul, where Titus, a Greek, is not compelled to be circumcised, while Barnabas is later carried away by the dissimulation at Antioch (2:1,3,13)."),
        ("False brethren", "Unawares brought in to spy out the liberty believers have in Christ Jesus, that they might bring them into bondage (2:4)."),
        ("James, Cephas, and John", "Seemed to be pillars, added nothing to Paul's message, and gave him and Barnabas the right hands of fellowship (2:6-9)."),
        ("Cephas at Antioch", "Ate with the Gentiles until certain came from James, then withdrew and separated himself, fearing those of the circumcision (2:11-12)."),
        ("Certain from James", "Came to Antioch and led Peter and the other Jews to draw back from table fellowship with Gentiles (2:12)."),
    ],
    3: [
        ("Paul", "Rebukes the foolish Galatians and argues from Abraham, the promise, and the law that the just shall live by faith (3:1-14)."),
        ("The Galatian believers", "Asked whether they received the Spirit by the works of the law or by the hearing of faith, having begun in the Spirit (3:1-5)."),
        ("Abraham", "Believed God and it was counted to him for righteousness, so that those of faith are his children and blessed with him (3:6-9)."),
        ("Jesus Christ", "Redeemed us from the curse of the law by being made a curse for us, the seed to whom the promise was made (3:13,16)."),
        ("Those of the works of the law", "Described as under the curse, since cursed is every one that continueth not in all things written in the law (3:10)."),
    ],
    4: [
        ("God the Father, the Son, and the Spirit", "God sent forth his Son, made of a woman and made under the law, and sent the Spirit of his Son into believers' hearts (4:4-6)."),
        ("Paul", "Pleads with the Galatians not to turn back, recalls their welcome, and travails in birth again until Christ be formed in them (4:11-20)."),
        ("The Galatian believers", "Once served them which by nature are no gods, and are now urged not to return to weak and beggarly elements (4:8-9)."),
        ("The other teachers", "Zealously affect the Galatians, but not well, wanting to shut them out that they might affect them (4:17)."),
        ("Hagar and Sarah", "The bondwoman and the free woman whom Paul uses as an allegory of two covenants (4:22-26)."),
        ("Ishmael and Isaac", "The son of the bondwoman born after the flesh and the son of the free woman born by promise, with believers as children of promise like Isaac (4:22-23,28)."),
    ],
    5: [
        ("Paul", "Tells the Galatians to stand fast in liberty, warns that circumcision puts them under the whole law, and lists the works of the flesh and the fruit of the Spirit (5:1-3,19-23)."),
        ("The Galatian believers", "Did run well, and are called unto liberty, to serve one another by love and walk in the Spirit (5:7,13,16)."),
        ("The one who troubles them", "Described as leavening the whole lump, who shall bear his judgment, whosoever he be (5:9-10)."),
        ("Christ", "Has made believers free, and will profit nothing those who are circumcised for justification (5:1-2)."),
        ("The Spirit", "Set against the flesh, leading believers and bearing the fruit of love, joy, peace, longsuffering, and the rest (5:16-18,22-23)."),
    ],
    6: [
        ("Paul", "Writes the closing lines with his own hand in large letters, will glory only in the cross, and bears in his body the marks of the Lord Jesus (6:11,14,17)."),
        ("Those who are spiritual", "Told to restore a man overtaken in a fault in the spirit of meekness and to bear one another's burdens (6:1-2)."),
        ("Those who compel circumcision", "Desire to make a fair shew in the flesh and avoid persecution for the cross, though they do not keep the law themselves (6:12-13)."),
        ("The household of faith", "Those to whom believers are to do good especially, as they have opportunity (6:10)."),
        ("The Israel of God", "Those who walk according to this rule, on whom Paul asks peace and mercy (6:16)."),
        ("The Lord Jesus Christ", "The one by whose cross the world is crucified to Paul, and whose grace Paul invokes in the closing blessing (6:14,18)."),
    ],
}

THEMES = {
    1: {
        "There is only one gospel": "Paul says there is no other gospel than the one they received, and that anyone who preaches another, even an angel from heaven, is accursed (1:6-9).",
        "Christ’s self-giving rescue": "Paul opens by saying Christ gave himself for our sins to deliver us from this present evil world, according to the will of God (1:3-5).",
        "A gospel received by revelation": "Paul says he neither received the gospel from man nor was taught it, but received it by the revelation of Jesus Christ (1:11-12,15-17).",
        "Pleasing God rather than people": "Paul asks whether he now persuades men or God, and says that if he still pleased men he would not be the servant of Christ (1:10).",
        "Grace that transforms a life": "God called Paul by his grace while he was wasting the church, and the churches of Judaea glorified God in him (1:13-16,23-24).",
    },
    2: {
        "One gospel for Jews and Gentiles": "The Jerusalem leaders saw that the gospel of the uncircumcision was committed to Paul as that of the circumcision was to Peter (2:6-10).",
        "Standing for the truth of the gospel": "Paul did not give place to false brethren for an hour, and withstood Peter to the face when he did not walk uprightly according to the truth of the gospel (2:3-5,11-14).",
        "Justified by faith, not by works of the law": "A man is not justified by the works of the law but by the faith of Jesus Christ, for by the works of the law shall no flesh be justified (2:15-17).",
        "Crucified with Christ, Christ living in me": "Paul says he is crucified with Christ, yet lives, yet not he, but Christ liveth in him, by the faith of the Son of God who loved him (2:19-20).",
        "Grace that must not be set aside": "Paul will not frustrate the grace of God, for if righteousness come by the law, then Christ is dead in vain (2:21).",
    },
    3: {
        "The Spirit received by faith": "Paul asks whether the Galatians received the Spirit by the works of the law or by the hearing of faith, and whether, having begun in the Spirit, they are made perfect by the flesh (3:2-5).",
        "Abraham’s children by faith": "Those who are of faith are the children of Abraham, and the Scripture preached the gospel to him, saying, In thee shall all nations be blessed (3:6-9,29).",
        "Christ bore the curse": "Christ hath redeemed us from the curse of the law, being made a curse for us, that the blessing of Abraham might come on the Gentiles (3:10-14).",
        "The purpose and limits of the law": "The law, coming four hundred and thirty years after the promise, cannot disannul it, but was added because of transgressions and was a schoolmaster to bring us to Christ (3:15-25).",
        "One in Christ": "All are the children of God by faith in Christ Jesus, and there is neither Jew nor Greek, bond nor free, male nor female, for all are one in him (3:26-29).",
    },
    4: {
        "Adoption as God’s children": "God sent forth his Son to redeem those under the law that we might receive the adoption of sons, and the Spirit cries, Abba, Father (4:4-7).",
        "From slavery to freedom": "As long as the heir is a child he differs nothing from a servant, so believers were in bondage under the elements of the world until the time appointed (4:1-3,7-9).",
        "Turning back to religious observances": "Paul fears he has bestowed labour in vain, since the Galatians observe days, months, times, and years (4:9-11).",
        "Pastoral love that tells the truth": "Paul asks whether he has become their enemy by telling the truth, and likens himself to a mother travailing in birth until Christ be formed in them (4:12-20).",
        "Children of promise": "Hagar and Sarah picture two covenants, and believers, like Isaac, are children of promise and of the free woman, not of the bondwoman (4:21-31).",
    },
    5: {
        "Freedom in Christ": "Believers are to stand fast in the liberty wherewith Christ hath made them free and not be entangled again with the yoke of bondage (5:1,13).",
        "Faith working through love": "In Jesus Christ neither circumcision nor uncircumcision avails, but faith which worketh by love (5:2-6).",
        "Freedom expressed in loving service": "Liberty is not an occasion to the flesh, but by love believers serve one another, since all the law is fulfilled in loving one's neighbour as oneself (5:13-15).",
        "Walking by the Spirit": "Believers are to walk in the Spirit and not fulfil the lust of the flesh, for the Spirit and the flesh are contrary one to the other (5:16-18,24-26).",
        "Works of the flesh and fruit of the Spirit": "Paul lists works of the flesh such as hatred, strife, and drunkenness, against the fruit of the Spirit, love, joy, peace, longsuffering, gentleness, goodness, faith, meekness, temperance (5:19-23).",
    },
    6: {
        "Gentle restoration and shared burdens": "Those who are spiritual restore one overtaken in a fault in the spirit of meekness, and bear one another's burdens, fulfilling the law of Christ (6:1-2).",
        "Personal responsibility without comparison": "Each man is to prove his own work and have rejoicing in himself alone, not in another, for every man shall bear his own burden (6:3-5).",
        "Sowing and reaping": "God is not mocked: he that soweth to the flesh shall reap corruption, but he that soweth to the Spirit shall reap life everlasting, so believers should not be weary in well doing (6:7-10).",
        "Boasting only in the cross": "Paul says God forbid that he should glory, save in the cross of our Lord Jesus Christ, by whom the world is crucified unto him (6:12-14).",
        "A new creation": "In Christ Jesus neither circumcision nor uncircumcision avails, but a new creature, and peace and mercy are on those who walk by this rule (6:15-16).",
    },
}


def norm(text):
    return text.replace("\u2019", "'")


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "48_galatians.json"
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
        if len(entry["whereWeAre"]) > 600:
            raise SystemExit(f"{BOOK} {n}: WWA {len(entry['whereWeAre'])} chars")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


AUDIENCE_FIXES = {
    1: 'Paul writes "unto the churches of Galatia" (Galatians 1:2) about teachers urging Gentile believers to be circumcised. Whether these were the southern Galatian cities of Acts 13–14 or ethnic Galatians farther north is understood in different ways.',
    4: "Galatians who had welcomed a sick, wandering preacher as an angel of God would have felt the sting of being asked whether he had now become their enemy by telling them the truth.",
    6: "Readers who knew that letters were usually dictated would have noticed Paul taking the pen himself for the closing lines, making the last appeal personal and impossible to mistake for a scribe's words.",
}


def apply_chapter_context():
    path = ROOT / "chapter_context" / "38_galatians_colossians.json"
    data = load(path)
    for n, text in AUDIENCE_FIXES.items():
        data[f"{BOOK} {n}"]["audience"] = text
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_book_overview():
    path = ROOT / "book_overviews" / "08_pauls_letters.json"
    data = load(path)
    book = data[BOOK]
    old = "Churches in Galatia; the exact geographic identification is debated."
    if book["audience"] != old:
        raise SystemExit("audience changed")
    book["audience"] = "Churches in Galatia, in central Asia Minor."
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_FIXES = [
    ("Probably around AD 48–55. Whether it was written before or after the Jerusalem council of Acts 15 is debated.",
     "Probably around AD 48–55, depending on whether it was written before or after the Jerusalem council of Acts 15."),
    ("revealed His Son to him, so that he would preach", "revealed his Son to him, so that he would preach"),
    ("just as He sent Peter to the Jews", "just as he sent Peter to the Jews"),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "08_pauls_letters.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("\n# Galatians") + 1
    end = text.index("\n# Ephesians", start)
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
