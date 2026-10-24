#!/usr/bin/env python3
"""Apply the completed editorial review for 1 Corinthians to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BOOK = "1 Corinthians"


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


WWA = {
    1: ("Romans closed with Paul's greetings to a church he had not yet visited (Romans 16:1-27). "
        "First Corinthians is written to a church he founded and knows well: from Ephesus he thanks God "
        "for the Corinthians' gifts, then addresses reports from Chloe's household that they are splitting "
        "into groups around Paul, Apollos, Cephas, or Christ, and answers with the message of Christ "
        "crucified (1:1-31). Chapter 2 continues that contrast between worldly wisdom and God's."),
    2: ("Chapter 1 ended with God choosing the weak and lowly so that no one may boast before him "
        "(1:26-31). Chapter 2 shows Paul living that out: he came to Corinth in weakness and fear "
        "preaching Christ crucified, yet speaks God's hidden wisdom, revealed by the Spirit, to the "
        "mature (2:1-16). Chapter 3 turns that wisdom on the church's quarrels over its leaders."),
    3: ("Chapter 2 ended with believers having the mind of Christ (2:16). Chapter 3 says the quarrels "
        "prove the Corinthians are still infants: Paul and Apollos are only servants, one planting and "
        "one watering while God gives the growth, and the church is God's building and temple on the "
        "one foundation, Jesus Christ (3:1-23). Chapter 4 applies this to how the church should view "
        "its apostles."),
    4: ("Chapter 3 ended with Paul telling the Corinthians not to boast in men, since all things are "
        "theirs and they are Christ's (3:21-23). Chapter 4 asks them to see Paul and Apollos as "
        "stewards of God's mysteries who answer to the Lord, contrasts their own proud self-confidence "
        "with the apostles' hardships, and promises to come, with a rod or in love (4:1-21). Chapter 5 "
        "shows pride that has already tolerated a serious wrong."),
    5: ("Chapter 4 ended with Paul asking whether he should come with a rod or in love (4:21). Chapter "
        "5 shows why the question matters: the church is proud of tolerating a man living with his "
        "father's wife, and Paul tells them to remove him, using the picture of leaven and Christ our "
        "passover, and clarifies an earlier letter about associating with sinners (5:1-13). Chapter 6 "
        "moves from that discipline to disputes among believers."),
    6: ("Chapter 5 ended with Paul telling the church to judge those inside it and put away the wicked "
        "person (5:12-13). Chapter 6 asks why believers who will judge the world take one another to "
        "court before unbelievers, reminds them that some of them were washed, sanctified, and "
        "justified, and calls them to glorify God in their bodies, which are temples of the Holy "
        "Ghost (6:1-20). Chapter 7 begins answering the church's own written questions."),
    7: ("Chapter 6 ended with believers' bodies being temples of the Holy Ghost, bought with a price "
        "(6:19-20). Chapter 7 starts answering what the Corinthians wrote: Paul speaks about marriage "
        "and singleness, spouses' mutual duties, mixed households, and staying in the calling one was "
        "in when called, separating the Lord's command from his own judgment (7:1-40). Chapter 8 takes "
        "up the next question, food offered to idols."),
    8: ("Chapter 7 ended with Paul's counsel about remarriage and his sense that he too has the Spirit "
        "of God (7:40). Chapter 8 answers the question of food offered to idols: knowledge puffs up but "
        "love builds up, an idol is nothing, yet a brother with a weak conscience can be wounded by "
        "another's example, so Paul would give up meat rather than make him stumble (8:1-13). Chapter 9 "
        "offers Paul's own surrendered rights as the model."),
    9: ("Chapter 8 ended with Paul declining to eat meat if it made his brother stumble (8:13). Chapter "
        "9 gives his own example: he defends his apostleship and his right to support, yet gave up that "
        "right so the gospel would not be hindered, became all things to all men to win some, and "
        "disciplines himself like an athlete (9:1-27). Chapter 10 warns what happens without that "
        "discipline."),
    10: ("Chapter 9 ended with Paul fearing that after preaching to others he himself might be a "
         "castaway (9:27). Chapter 10 uses Israel in the wilderness as a warning against idolatry and "
         "presumption, contrasts the Lord's table with idols' tables, and returns to meat sold in the "
         "market, telling believers to do everything to the glory of God (10:1-33). Chapter 11 turns to "
         "worship when the church gathers."),
    11: ("Chapter 10 ended with Paul seeking the profit of many so that they may be saved (10:33). "
         "Chapter 11 turns to the gathered church: he addresses head coverings in prayer and "
         "prophecy, rebukes meals where one is hungry and another drunken, and recalls the Lord Jesus' "
         "words over the bread and cup, calling believers to examine themselves (11:2-34). Chapter 12 "
         "moves to spiritual gifts."),
    12: ("Chapter 11 ended with Paul promising to set the rest in order when he comes (11:34). Chapter "
         "12 begins spiritual gifts: no one speaking by the Spirit calls Jesus accursed, there are "
         "diversities of gifts but one Spirit, and the church is one body with many members that need "
         "one another (12:1-31). Chapter 13 shows the more excellent way he promises at its close."),
    13: ("Chapter 12 ended with Paul showing the Corinthians a more excellent way (12:31). Chapter 13 "
         "is that way: without love, tongues, prophecy, knowledge, faith, and sacrifice profit "
         "nothing, love is patient and kind, and of faith, hope, and love the greatest is love "
         "(13:1-13). Chapter 14 applies it to how gifts are used in worship."),
    14: ("Chapter 13 ended with love as the greatest of faith, hope, and love (13:13). Chapter 14 "
         "applies that love to worship: prophecy that builds up is preferred to tongues no one "
         "understands, outsiders should be able to follow what is said, and all things are to be done "
         "decently and in order (14:1-40). Chapter 15 turns to what the church believes about the "
         "dead."),
    15: ("Chapter 14 ended with the call to do all things decently and in order (14:40). Chapter 15 "
         "turns to the heart of the gospel: Christ died, was buried, rose the third day, and was seen "
         "by many, so those who say there is no resurrection of the dead are wrong, for Christ is the "
         "firstfruits and the dead will be raised incorruptible (15:1-58). Chapter 16 closes with "
         "practical matters."),
    16: ("Chapter 15 ended with Paul urging the Corinthians to be steadfast because their labor in "
         "the Lord is not in vain (15:58). Chapter 16 comes down to practical matters: the collection "
         "for the saints at Jerusalem, Paul's travel plans, Timothy and Apollos, the household of "
         "Stephanas, and greetings in his own hand (16:1-24). The next letter, 2 Corinthians, follows "
         "this correspondence."),
}

KEY_FIGURES = {
    1: [
        ("Paul", "Greets the Corinthians with Sosthenes, thanks God for their gifts, and calls them to be joined together in the same mind (1:1-10)."),
        ("Sosthenes", "Named with Paul in the greeting as the brother who joins in sending the letter (1:1)."),
        ("Chloe’s people", "Members of Chloe's household who report to Paul that there are contentions among the Corinthians (1:11)."),
        ("Apollos and Cephas (Peter)", "Teachers whose names are used as rallying labels, though Paul does not say they encouraged the groups (1:12)."),
        ("Corinthian believers", "Divided into groups claiming Paul, Apollos, Cephas, or Christ, and reminded that few of them were wise, mighty, or noble when called (1:12,26)."),
    ],
    2: [
        ("Paul", "Recalls coming to Corinth in weakness and fear, preaching Christ crucified rather than excellency of speech (2:1-5)."),
        ("Jesus Christ", "The crucified Lord whom Paul determined to know among the Corinthians, and whose mind believers have (2:2,16)."),
        ("Holy Spirit", "Searches the deep things of God and reveals them to believers, who receive the Spirit that is of God (2:10-12)."),
        ("Rulers of this age", "Unnamed authorities who did not know God's hidden wisdom, for otherwise they would not have crucified the Lord of glory (2:6-8)."),
    ],
    3: [
        ("Paul", "Planted the church and laid its foundation as a wise masterbuilder, while calling the Corinthians babes still ruled by envy and strife (3:1-10)."),
        ("Apollos", "Watered what Paul planted, one of the servants through whom the Corinthians believed (3:5-6)."),
        ("God", "Gives the increase, owns the field and building, and will destroy anyone who defiles his temple (3:6-9,16-17)."),
        ("Jesus Christ", "The only foundation on which anyone can build (3:11)."),
        ("Corinthian believers", "Called God's husbandry, God's building, and the temple of God in which the Spirit dwells (3:9,16)."),
    ],
    4: [
        ("Paul", "Describes himself and Apollos as ministers of Christ and stewards of God's mysteries, answerable only to the Lord's judgment, and warns as a father (4:1-5,14-15)."),
        ("Apollos", "Paul uses him and himself as the example of not thinking of men above what is written (4:6)."),
        ("Timothy", "Paul's beloved and faithful son in the Lord, sent to remind the Corinthians of Paul's ways (4:17)."),
        ("Corinthian believers", "Rebuked as already full, already rich, and puffed up, while the apostles are hungry, naked, and buffeted (4:6-13,18)."),
    ],
    5: [
        ("Paul", "Judges, though absent in body, that the man living with his father's wife should be delivered to Satan for the destruction of the flesh (5:3-5)."),
        ("The man in the relationship", "A church member living with his father's wife, a sin Paul says is not even named among the Gentiles (5:1)."),
        ("Corinthian church", "Puffed up rather than mourning, and told to purge out the old leaven and not keep company with a professing brother who persists in sin (5:2,6-13)."),
        ("Christ", "Our passover, sacrificed for us, the reason believers keep the feast with sincerity and truth (5:7-8)."),
    ],
    6: [
        ("Paul", "Rebukes believers who sue one another before the unjust and reminds them that they were washed, sanctified, and justified (6:1-11)."),
        ("Corinthian believers", "Wrong and defraud one another in lawsuits, yet are called to glorify God in their bodies, which are members of Christ (6:7-8,15,20)."),
        ("Judges outside the church", "Called the unjust, those whose judgment the believers should not seek when they have saints able to judge (6:1-6)."),
        ("Holy Ghost", "Dwells in the believer's body as in a temple, which is not his own (6:19)."),
    ],
    7: [
        ("Paul", "Answers the church's written questions, distinguishing what the Lord commands from what he gives as judgment (7:1,10,12,25)."),
        ("Married believers", "Told that husband and wife each owe the other due benevolence and should not defraud one another (7:2-5)."),
        ("Unmarried and widows", "Told it is good to remain as Paul is, but that it is better to marry than to burn (7:8-9)."),
        ("Believers with unbelieving spouses", "Told not to leave a spouse who is pleased to stay, since God hath called us to peace (7:12-16)."),
        ("Enslaved and free believers", "Told that the enslaved is the Lord's freeman and the free is Christ's servant, bought with a price (7:21-23)."),
    ],
    8: [
        ("Paul", "Answers the question about things offered to idols, saying knowledge puffs up but charity edifies, and that he will eat no flesh while the world stands if it makes his brother stumble (8:1,13)."),
        ("Corinthian believers with knowledge", "Confident that an idol is nothing, and warned that their liberty must not become a stumblingblock to the weak (8:4,9)."),
        ("Believers with weak consciences", "Those who eat as if the meat still belonged to an idol and whose conscience is defiled (8:7-12)."),
    ],
    9: [
        ("Paul", "Defends his apostleship and right to support, yet gives up that right, becoming all things to all men and keeping his body under (9:1-27)."),
        ("Jesus Christ", "The Lord whom Paul has seen, making him an apostle (9:1)."),
        ("Corinthian believers", "Paul's work in the Lord and the seal of his apostleship (9:1-2)."),
        ("Barnabas", "Named with Paul as another who has the right to forbear working (9:6)."),
    ],
    10: [
        ("Paul", "Warns that Israel's wilderness fall was written for our admonition and tells the Corinthians to flee idolatry and do all to the glory of God (10:6-14,31)."),
        ("Israelites in the wilderness", "All under the cloud and passed through the sea, yet overthrown for lusting, idolatry, fornication, tempting Christ, and murmuring (10:1-10)."),
        ("Corinthian believers", "Told that God is faithful and will provide a way to escape temptation, and that the cup and bread are communion in Christ (10:13,16)."),
        ("Christ", "The spiritual Rock that followed Israel, and the one in whose cup and bread believers share (10:4,16)."),
    ],
    11: [
        ("Paul", "Praises the church for remembering him, then corrects head coverings and abuse of the Lord's supper (11:2,17-22)."),
        ("Men and women who pray or prophesy", "Worshipers whose conduct in prayer and prophecy Paul addresses (11:4-5)."),
        ("Jesus Christ", "The Lord Jesus who, the same night in which he was betrayed, took bread and the cup and said do this in remembrance of me (11:23-25)."),
        ("Wealthier and poorer meal participants", "Those in whose gatherings one is hungry and another drunken, despising the church of God and shaming those who have nothing (11:21-22)."),
    ],
    12: [
        ("Paul", "Does not want the Corinthians ignorant about spiritual gifts and compares the church to one body with many members (12:1,12-27)."),
        ("Holy Ghost", "The same Spirit who gives diversities of gifts to each as he will, for the profit of all (12:4-11)."),
        ("Jesus Christ", "Confessed as Lord by the Spirit, and the Christ whose body the church is (12:3,12,27)."),
        ("Corinthian believers", "Baptized by one Spirit into one body, each a member in particular and told no member can say to another, I have no need of thee (12:13,21,27)."),
    ],
    13: [
        ("Paul", "Describes tongues, prophecy, knowledge, faith, and sacrifice as nothing without charity, and charity as never failing (13:1-8)."),
        ("Corinthian believers", "Shown the more excellent way, to put love above gifts and to grow from childish things to the full knowledge they now see only in part (13:11-12)."),
    ],
    14: [
        ("Paul", "Prefers prophecy that edifies to tongues without interpretation, and tells the church to let all things be done decently and in order (14:1-5,40)."),
        ("People speaking in tongues", "Told to keep silent in the church if there is no interpreter, and to pray that they may interpret (14:13,28)."),
        ("Prophets", "Told to speak two or three while the others judge, since the spirits of the prophets are subject to the prophets (14:29-32)."),
        ("Visitors or unbelievers", "Pictured coming into a meeting where all speak with tongues, and saying that the church is mad, or falling down and confessing that God is among them (14:23-25)."),
        ("Women in the assembly", "Addressed in 14:34-35, a passage Paul gives with the instruction that they ask their husbands at home (14:34-35)."),
    ],
    15: [
        ("Paul", "Recites the gospel he received and preached, counts himself the least of the apostles, and argues from Christ's resurrection to the resurrection of the dead (15:1-58)."),
        ("Jesus Christ", "Died for our sins, was buried, rose the third day, and is become the firstfruits of them that slept (15:3-4,20)."),
        ("Cephas, the Twelve, and James", "Among those to whom the risen Christ appeared, named in the tradition Paul delivered (15:5-7)."),
        ("Adam", "The man in whom all die, set against Christ in whom all shall be made alive (15:21-22,45)."),
        ("Some Corinthians denying resurrection", "Those who say there is no resurrection of the dead, whose claim Paul answers (15:12)."),
    ],
    16: [
        ("Paul", "Gives directions for the collection for the saints, plans to pass through Macedonia, and writes the closing greeting with his own hand (16:1-9,21)."),
        ("Timothy", "A coworker Paul asks the Corinthians to receive without fear, for he works the work of the Lord as Paul does (16:10-11)."),
        ("Apollos", "A brother Paul greatly desired to come, who was not willing at this time (16:12)."),
        ("Stephanas, Fortunatus, and Achaicus", "Corinthian believers who supplied what was lacking and refreshed Paul's spirit, worthy of acknowledgement (16:15-18)."),
        ("Aquila and Priscilla", "Send greetings from the church in their house (16:19)."),
        ("Churches in Asia", "Send greetings to the Corinthians (16:19)."),
    ],
}

THEMES = {
    1: {
        "Thanksgiving and grace": "Paul thanks God for the grace given to the Corinthians, enriched in all utterance and knowledge, waiting for the coming of the Lord (1:4-9).",
        "Unity over factions": "Paul begs them to be perfectly joined together in the same mind, since Christ is not divided and they were not baptized in Paul's name (1:10-17).",
        "Wisdom of the cross": "The preaching of the cross is foolishness to those perishing but the power of God to those being saved, and God's foolishness is wiser than men (1:18-25).",
        "Boasting in the Lord": "God chose the foolish, weak, and base things so that no flesh should glory in his presence; let him that glorieth glory in the Lord (1:26-31).",
    },
    2: {
        "Faith founded on divine power": "Paul came without excellency of speech so that their faith should stand in the power of God, not in the wisdom of men (2:1-5).",
        "Hidden wisdom revealed": "The wisdom of God in a mystery, which the rulers of this age did not know, God has revealed to believers by his Spirit (2:6-10).",
        "Role of the Spirit": "The Spirit searches the deep things of God, and believers have received that Spirit so they may know what God has freely given (2:10-13).",
        "Mind of Christ": "The natural man does not receive the things of the Spirit, but he that is spiritual judges all things, for believers have the mind of Christ (2:14-16).",
    },
    3: {
        "Immaturity and jealousy": "Envying, strife, and divisions show the Corinthians are still carnal babes fed with milk, not meat (3:1-4).",
        "Shared ministry": "Paul planted, Apollos watered, but God gave the increase, so neither the planter nor the waterer is anything (3:5-9).",
        "Building on Christ": "No other foundation can be laid than Jesus Christ, and each builder's work will be tried by fire (3:10-15).",
        "Community as temple": "The church is the temple of God, and God will destroy anyone who defiles it (3:16-17).",
    },
    4: {
        "Faithful stewardship": "Ministers are stewards of the mysteries of God, and it is required in stewards that a man be found faithful, judged finally by the Lord (4:1-5).",
        "Humility about gifts": "Paul asks who makes one to differ and what they have that they did not receive, since there is nothing to glory in as if not received (4:6-8).",
        "Apostolic suffering": "Apostles are made a spectacle, fools for Christ's sake, hungry, buffeted, and reviled, in contrast to the Corinthians' pride (4:9-13).",
        "Corrective love": "Paul warns as a beloved father, not to shame them, and asks whether he should come with a rod or in love (4:14-21).",
    },
    5: {
        "Accountability within the church": "The church is puffed up instead of mourning over a man living with his father's wife and is told to remove him from among them (5:1-5).",
        "Leaven and integrity": "A little leaven leavens the whole lump, so believers are to purge it out and keep the feast with sincerity and truth (5:6-8).",
        "Community versus outsiders": "Paul explains that he did not mean avoiding all sinners of this world, but not keeping company with a professing brother who persists in sin, while God judges those outside (5:9-13).",
        "Discipline and hoped-for restoration": "The man is delivered to Satan for the destruction of the flesh, that the spirit may be saved in the day of the Lord Jesus (5:4-5).",
    },
    6: {
        "Disputes and witness": "Paul asks why believers who will judge the world take one another to law before the unjust, when it is better to suffer wrong (6:1-8).",
        "Changed identity": "The unrighteous will not inherit God's kingdom, but some of the Corinthians were washed, sanctified, and justified in the name of the Lord Jesus (6:9-11).",
        "Freedom and benefit": "All things are lawful, but not all are expedient, and Paul will not be brought under the power of any (6:12-13).",
        "Bodily dignity": "Believers' bodies are members of Christ and temples of the Holy Ghost, bought with a price, so they are to glorify God in their bodies (6:15-20).",
    },
    7: {
        "Mutuality in marriage": "Husband and wife owe each other due benevolence, and neither has power over his or her own body alone (7:3-5).",
        "Marriage, singleness, and gift": "Each has a proper gift of God, one after this manner and another after that, and it is better to marry than to burn (7:6-9).",
        "Peace in mixed households": "A believer should not leave a spouse who is pleased to dwell with him, for God has called us to peace (7:12-16).",
        "Calling and circumstances": "Each should abide in the calling in which he was called, since circumcision and slavery are not what matter before God (7:17-24).",
        "Present distress and judgment": "Because of the present distress and the passing fashion of the world, Paul gives his judgment about the unmarried and widows, allowing marriage without sin (7:25-40).",
    },
    8: {
        "Love over pride": "Knowledge puffs up but charity edifies, and the one who loves God is known of him (8:1-3).",
        "One God and one Lord": "An idol is nothing in the world; there is one God, the Father, and one Lord Jesus Christ (8:4-6).",
        "Conscience and sensitivity": "Not every believer has this knowledge, and a weak conscience can be defiled and a brother perish through another's example (8:7-12).",
        "Voluntary restraint": "Paul says he will eat no flesh while the world stands rather than make his brother to offend (8:13).",
    },
    9: {
        "Rights of gospel workers": "Paul argues from soldiers, vineyards, flocks, the law, and the temple that they which preach the gospel should live of the gospel (9:3-14).",
        "Rights voluntarily set aside": "Paul has not used this power, preferring to make the gospel of Christ without charge (9:15-18).",
        "Adaptation in mission": "Paul became all things to all men, a servant to all, that he might by all means save some (9:19-23).",
        "Disciplined purpose": "Like a runner and fighter, Paul keeps under his body so that after preaching to others he himself should not be a castaway (9:24-27).",
    },
    10: {
        "Warnings from Israel": "Israel's fathers were all baptized unto Moses, yet most fell in the wilderness, and these things are examples written for our admonition (10:1-12).",
        "Temptation and endurance": "God is faithful and will not allow believers to be tempted above what they are able, but will make a way to escape (10:12-13).",
        "Communion and idolatry": "The cup and bread are communion of the blood and body of Christ, and believers cannot partake of the Lord's table and the table of devils (10:14-22).",
        "Freedom for others’ good": "Whatever believers eat or drink, they are to do all to the glory of God, seeking not their own profit but that of many (10:23-33).",
    },
    11: {
        "Honor in public worship": "Paul addresses how men and women are to pray and prophesy, appealing to creation and noting that in the Lord neither is without the other (11:2-16).",
        "Equality at the table": "When they come together, one is hungry and another is drunken, and Paul asks if they despise the church of God and shame those who have nothing (11:17-22).",
        "Remembering Christ": "The Lord Jesus, the night he was betrayed, took bread and the cup, and as often as believers eat and drink they shew the Lord's death till he come (11:23-26).",
        "Self-examination and community": "Let a man examine himself, discerning the Lord's body, and tarry one for another when they come together (11:27-34).",
    },
    12: {
        "Diversity from one Spirit": "There are diversities of gifts, administrations, and operations, but the same Spirit, Lord, and God, working all in all for the profit of all (12:4-11).",
        "One body, many members": "As the body is one and has many members, so also is Christ, and all were baptized by one Spirit into one body (12:12-20).",
        "Honor for vulnerable members": "The members which seem more feeble are necessary, and God has tempered the body together so that there be no schism (12:21-26).",
        "Not everyone has the same gift": "God has set apostles, prophets, teachers, miracles, healings, helps, governments, and tongues in the church, and not all have the same gift (12:27-31).",
    },
    13: {
        "Love beyond gifts": "Without charity, tongues become sounding brass, prophecy and faith are nothing, and even giving all to the poor profits nothing (13:1-3).",
        "Practices of love": "Charity suffereth long and is kind, envieth not, vaunteth not itself, seeketh not her own, and beareth all things (13:4-7).",
        "Partial knowledge": "Prophecies shall fail, tongues cease, and knowledge vanish, for now we see through a glass darkly but then face to face (13:8-12).",
        "Love’s enduring priority": "Now abideth faith, hope, charity, these three, but the greatest of these is charity (13:13).",
    },
    14: {
        "Pursuing intelligible encouragement": "Prophecy speaks to men for edification, exhortation, and comfort, while one speaking in an unknown tongue edifies himself (14:1-12).",
        "Understanding in prayer": "Paul will pray and sing with the spirit and with the understanding also, and would rather speak five words with understanding than ten thousand in an unknown tongue (14:13-19).",
        "Outsiders and witness": "If all speak with tongues, an unbeliever coming in will say they are mad, but through prophecy he may fall down and say God is among them (14:20-25).",
        "Order and discernment": "Tongues are to be limited and interpreted and prophecies judged, for God is not the author of confusion but of peace (14:26-33).",
        "Interpretive care about women’s speech": "Paul instructs that women keep silence in the churches and ask their husbands at home, and ends that all things be done decently and in order (14:34-40).",
    },
    15: {
        "Received gospel and testimony": "Paul rehearses that Christ died for our sins, was buried, and rose again the third day, and was seen by Cephas, the Twelve, above five hundred brethren, James, and last of all himself (15:1-11).",
        "Resurrection and Christian hope": "If there is no resurrection of the dead, Christ is not risen, preaching and faith are vain, and those who have fallen asleep in Christ are perished (15:12-19).",
        "Christ and Adam": "As in Adam all die, so in Christ shall all be made alive, with Christ the firstfruits and death the last enemy to be destroyed (15:20-28).",
        "Raised bodies and transformation": "The dead are raised as a sown seed becomes a different body: sown in corruption, raised in incorruption; first Adam a living soul, the last Adam a quickening spirit (15:35-49).",
        "Victory and perseverance": "At the last trump we shall all be changed, death is swallowed up in victory, and believers are to be stedfast, unmoveable, abounding in the work of the Lord (15:50-58).",
    },
    16: {
        "Organized generosity": "On the first day of the week each is to lay by in store as God has prospered him, and the gift is to be carried to Jerusalem by approved men (16:1-4).",
        "Open doors and opposition": "Paul will tarry at Ephesus until Pentecost because a great door and effectual is opened to him, and there are many adversaries (16:5-9).",
        "Receiving coworkers": "Timothy is to be received without fear, and Apollos was not at all willing to come at this time but will when he has convenient time (16:10-12).",
        "Courage governed by love": "Believers are to watch, stand fast in the faith, quit themselves like men, be strong, and let all their things be done with charity (16:13-18).",
        "Shared networks of faith": "The churches of Asia, Aquila and Priscilla with the church in their house, and all the brethren send greetings, and Paul writes the last salutation with his own hand (16:19-24).",
    },
}

SUMMARY_FIXES = {
    7: [("a 'present distress'", "a “present distress”")],
    8: [("superior 'knowledge' without regard", "superior “knowledge” without regard"),
        ("by another's example 1 Corinthians 8:7–12.", "by another's example (1 Corinthians 8:7–12).")],
    14: [("(1 Corinthians 14:26–33, 1) Corinthians 14:39–40.", "(1 Corinthians 14:26–33,39–40)."),
         ("of these verses are debated.", "of these verses are read in different ways.")],
    15: [("Some individual verses remain much debated, but", "Some individual verses are read in different ways, but")],
}


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "46_1_corinthians.json"
    data = load(path)
    for n in range(1, 17):
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
    1: "Corinthian believers who prized speakers and status would have heard Paul's opening thanks for their gifts as generous praise, and the report of their quarrels as all the more pointed for following it.",
    4: "Believers used to teachers who flaunted success would have felt the sting of apostles described as fools for Christ's sake, and the gentleness of a father who offers either a rod or love.",
    5: "Believers proud of their tolerance would have been startled to learn that Paul's earlier, now-lost letter had already told them how to treat a professing believer who persists in sin.",
    6: "Citizens used to settling quarrels before Roman magistrates would have felt how unusual it was to be told that fellow believers, who will judge the world, should settle such matters.",
    11: "Wealthier members, free to eat early, and poorer members, who likely could not, would have recognized themselves in Paul's picture of a supper where one is hungry and another drunken.",
    12: "Hearers who remembered being carried away to idols that could not speak would have heard Paul's test of the Spirit, confessing Jesus as Lord, as a clear contrast with their old worship.",
    13: "Hearers who prized dramatic speech and knowledge would have recognized each gift Paul lists, and been unsettled to hear that every one is worth nothing without love.",
    14: "Visitors walking into a meeting where many spoke in tongues at once would have heard noise, not worship, which is the picture Paul uses to explain why order and understanding matter.",
    15: "Greek-minded hearers who expected the soul to escape the body, and who had laughed at resurrection in Athens, would have felt the force of Paul pointing to hundreds of living witnesses.",
    16: "Believers who had heard Paul's earlier appeal for the Jerusalem collection would have read his weekly-saving plan as a practical way to have their generosity ready before he arrived.",
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
    if book["keyVerse"] != "1 Corinthians 13:13":
        raise SystemExit("keyVerse changed")
    book["keyVerse"] = "1 Corinthians 1:18"
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_PRONOUN_FIXES = [
    ("After supper He took the cup:", "After supper he took the cup:"),
    ("could be asked. He was seen by James,", "could be asked. he was seen by James,"),
    ("until all His enemies are defeated,", "until all his enemies are defeated,"),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "08_pauls_letters.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("\n# 1 Corinthians") + 1
    end = text.index("\n# 2 Corinthians", start)
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
