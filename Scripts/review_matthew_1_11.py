#!/usr/bin/env python3
"""Apply the completed editorial review for Matthew chapters 1-11 to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


WWA = {
    1: ("The Old Testament ended with Malachi's promise of Elijah before the great day of the LORD, "
        "followed by about four hundred years without a new prophet (Malachi 4:5-6). Matthew opens the "
        "New Testament by picking that silence back up: a genealogy ties Jesus directly to Abraham and "
        "David, and an angel explains to Joseph that Mary's unborn son will save his people from their "
        "sins. That claim about who Jesus is sets up chapter 2's account of the world's first responses "
        "to his birth, both worship and violence."),
    2: ("Chapter 1 explained who Jesus is, through his genealogy and the angel's announcement that he "
        "would save his people from their sins (Matthew 1:21). Chapter 2 shows how the world first "
        "responds to that birth: magi travel to worship him while Herod tries to kill him, and the holy "
        "family's flight to Egypt and eventual return to Nazareth are each read by Matthew as fulfilling "
        "Israel's own Scriptures. That childhood survival sets up chapter 3's leap forward to Jesus as an "
        "adult, beginning his public life at his baptism."),
    3: ("Chapter 2 closed with the child Jesus settled safely in Nazareth after Herod's death (Matthew "
        "2:19-23). Chapter 3 jumps forward roughly thirty years: John the Baptist prepares the way in the "
        "wilderness, and Jesus comes to be baptized by him, after which the Spirit descends and a "
        "heavenly voice names Jesus God's beloved Son. That public identification sets up chapter 4's "
        "test of exactly what kind of son Jesus will be, as the same Spirit leads him into the wilderness "
        "to be tempted."),
    4: ("Chapter 3 ended with Jesus publicly named God's beloved Son at his baptism (Matthew 3:16-17). "
        "Chapter 4 tests that identity directly: the devil tempts Jesus three times, each time twisting "
        "or quoting Scripture, and Jesus answers each temptation from Deuteronomy. Having passed that "
        "test, Jesus begins preaching in Galilee, calls his first four disciples, and draws crowds "
        "through healing, setting up chapters 5 through 7's extended teaching to the disciples and those "
        "same crowds."),
    5: ("Chapter 4 ended with Jesus' ministry already drawing great crowds from Galilee and beyond "
        "(Matthew 4:23-25). Chapter 5 opens the Sermon on the Mount, Jesus' most extended teaching block: "
        "the Beatitudes describe who is blessed, his followers are called salt and light, and he "
        "declares that he has come to fulfill the Law and the Prophets rather than abolish them before "
        "pressing six of its commands deeper than outward compliance. That inward standard of "
        "righteousness continues directly into chapter 6's teaching on prayer, giving, and fasting."),
    6: ("Chapter 5 pressed the Law's commands inward, from outward acts to the intentions behind them "
        "(Matthew 5:21-48). Chapter 6 applies that same inward standard to religious practice itself: "
        "giving, praying, and fasting are warned against becoming displays for an audience, the Lord's "
        "Prayer models what sincere prayer sounds like, and Jesus closes by telling his listeners not to "
        "serve both God and money or be consumed by worry over food and clothing. That call to undivided "
        "trust sets up chapter 7's warnings about judging others and about the only foundation that "
        "actually holds."),
    7: ("Chapter 6 called Jesus' listeners to undivided trust in God rather than anxiety over daily "
        "needs (Matthew 6:25-34). Chapter 7 closes the Sermon on the Mount with a string of warnings: "
        "against hypocritical judgment, toward persistent prayer, and about the narrow way, false "
        "prophets known by their fruit, and a profession of faith not backed by obedience. The crowds' "
        "astonishment at Jesus' own authority, unlike that of the scribes, closes the sermon and sets up "
        "chapters 8 and 9's run of miracles that put that authority into action."),
    8: ("Chapter 7 ended with crowds astonished at the authority behind Jesus' teaching (Matthew "
        "7:28-29). Chapter 8 puts that same authority into action: Jesus cleanses a man with a skin "
        "disease, heals a Roman centurion's servant from a distance and praises his faith, heals Peter's "
        "mother-in-law and many others, calms a storm with a word, and casts demons out of two men into "
        "a herd of pigs. That display of authority over disease, nature, and demons continues directly "
        "into chapter 9's further healings and a call to a very different kind of follower."),
    9: ("Chapter 8 showed Jesus' authority over disease, a storm, and demons (Matthew 8:1-34). Chapter 9 "
        "adds authority over sin itself: Jesus forgives and heals a paralyzed man, then calls Matthew, a "
        "tax collector, and eats with tax collectors and sinners over religious leaders' objections. A "
        "ruler's daughter is raised, a bleeding woman is healed, and two blind men receive sight, before "
        "Jesus sees the crowds as sheep without a shepherd and tells his disciples to pray for more "
        "workers. That image sets up chapter 10's sending of the twelve as exactly those workers."),
    10: ("Chapter 9 ended with Jesus asking his disciples to pray for more workers for a plentiful "
         "harvest (Matthew 9:37-38). Chapter 10 answers that prayer: Jesus commissions the twelve "
         "apostles by name, sends them first to Israel with authority to heal and cast out unclean "
         "spirits, and gives them travel instructions alongside sober warnings about the persecution, "
         "family division, and costly allegiance discipleship will bring. That warning about opposition "
         "continues into chapter 11, where even John the Baptist's own confidence in Jesus is tested "
         "from inside a prison cell."),
    11: ("Chapter 10 warned the twelve apostles that following Jesus would provoke real opposition "
         "(Matthew 10:16-39). Chapter 11 shows that opposition reaching even John the Baptist: from "
         "prison, John sends disciples to ask whether Jesus is really the expected one, and Jesus "
         "answers by pointing to his own works before pronouncing woes on towns that witnessed those "
         "works without repenting. The closing invitation, to the weary and burdened to find rest under "
         "his gentle yoke, carries that demanding call forward into an invitation chapter 12's "
         "continuing conflict will immediately test."),
}

KEY_FIGURES = {
    1: [
        ("Jesus",
         "Central subject of the opening genealogy and birth narrative; the angel instructs that he is "
         "to be named Jesus because he will save his people from their sins (1:1,21)."),
        ("Joseph",
         "Mary's betrothed husband, a descendant of David. Resolves to divorce Mary quietly, then obeys "
         "an angel's dream instruction to take her as his wife and name the child Jesus (1:18-21,24-25)."),
        ("Mary",
         "Betrothed to Joseph and found with child by the Holy Spirit before the couple lives together, "
         "fulfilling Isaiah's sign of a virgin bearing a son (1:18,23)."),
        ("Abraham",
         "Opening ancestor of the genealogy, anchoring Jesus' line in God's covenant with Israel "
         "(1:1-2)."),
        ("David",
         "Royal ancestor whose name marks the genealogy's turning point and ties Jesus to the promised "
         "kingly line (1:1,6,17)."),
        ("angel of the Lord",
         "Appears to Joseph in a dream, explaining Mary's pregnancy and instructing him to name the "
         "child Jesus (1:20-21)."),
    ],
    2: [
        ("Jesus",
         "Infant sought by the magi as newborn king of the Jews and by Herod for execution; taken to "
         "Egypt and later to Nazareth for safety (2:1-2,13-15,19-23)."),
        ("Mary",
         "Found with the child Jesus by the visiting magi, and taken to Egypt and then Nazareth by "
         "Joseph for the child's protection (2:11,13-14,19-21)."),
        ("Joseph",
         "Warned repeatedly in dreams; flees with Mary and Jesus to Egypt, then returns after Herod's "
         "death but settles in Nazareth rather than Judea because Herod's son Archelaus now ruled there "
         "(2:13-15,19-23)."),
        ("Herod the Great",
         "Troubled king who questions the chief priests and scribes about the Messiah's birthplace, then "
         "orders the killing of Bethlehem's young boys after the magi evade him (2:3-4,7-8,16)."),
        ("magi",
         "Eastern visitors who follow a star to Jerusalem and Bethlehem, worship the child with gifts, "
         "and are warned in a dream not to report back to Herod (2:1-2,7-12)."),
        ("chief priests and scribes",
         "Consulted by Herod, they cite Micah's prophecy naming Bethlehem as the Messiah's birthplace "
         "(2:4-6)."),
    ],
    3: [
        ("John the Baptist",
         "Preaches repentance in the Judean wilderness, baptizes confessing crowds in the Jordan, warns "
         "Pharisees and Sadducees that lineage from Abraham is not enough, and baptizes Jesus despite his "
         "own objection (3:1-8,13-15)."),
        ("Jesus",
         "Comes from Galilee to be baptized by John, insisting it is fitting to fulfill all "
         "righteousness; the Spirit descends on him like a dove and a heavenly voice calls him the "
         "beloved Son (3:13-17)."),
        ("Pharisees",
         "Religious group that comes to John's baptism and is warned not to rely on descent from "
         "Abraham instead of genuine repentance (3:7-10)."),
        ("Sadducees",
         "Religious group that comes to John's baptism alongside the Pharisees and receives the same "
         "warning about fruit worthy of repentance (3:7-10)."),
        ("Holy Spirit",
         "Descends on Jesus like a dove immediately after his baptism, confirming him before the "
         "heavenly voice speaks (3:16)."),
    ],
    4: [
        ("Jesus",
         "Led by the Spirit into the wilderness to be tempted by the devil, answers each temptation with "
         "Deuteronomy, then begins preaching in Galilee, calls four fishermen as disciples, and draws "
         "crowds through teaching, preaching, and healing (4:1-11,17-25)."),
        ("devil",
         "Tempts Jesus three times in the wilderness, twisting Scripture in his second attempt, and "
         "leaves after being rebuked (4:1-11)."),
        ("John the Baptist",
         "His arrest is the occasion for Jesus to withdraw to Capernaum and begin his own public "
         "preaching (4:12)."),
        ("Simon Peter",
         "Called with his brother Andrew from their fishing nets to follow Jesus and fish for people "
         "(4:18-20)."),
        ("Andrew",
         "Peter's brother, called alongside him from their nets to follow Jesus (4:18-20)."),
        ("James and John",
         "Sons of Zebedee, called from their father's boat to follow Jesus immediately after Peter and "
         "Andrew (4:21-22)."),
    ],
    5: [
        ("Jesus",
         "Sees the crowds, goes up a mountain, and teaches the Beatitudes, calls his followers salt and "
         "light, and declares that he has come to fulfill, not abolish, the Law and the Prophets before "
         "pressing its demands deeper than outward compliance (5:1-48)."),
        ("disciples",
         "Those Jesus addresses directly on the mountain, called to visible righteousness as salt and "
         "light (5:1-2,13-16)."),
        ("crowds",
         "Present at the edge of the teaching, implicitly included in Jesus' description of righteousness "
         "that exceeds the scribes and Pharisees (5:1,20)."),
        ("Moses (in references to the Law)",
         "His Law is the standard Jesus says he has come to fulfill, then intensifies point by point "
         "throughout the chapter's six contrasts (5:17-48)."),
    ],
    6: [
        ("Jesus",
         "Warns against performing righteousness, giving, praying, and fasting, to be seen by others, "
         "teaches the Lord's Prayer, and tells his listeners not to serve both God and wealth or be "
         "consumed by anxiety over food and clothing (6:1-34)."),
        ("disciples",
         "Addressed directly with the model prayer and the command to seek first God's kingdom rather "
         "than store up earthly treasure (6:9-13,25-33)."),
        ("hypocrites (criticized religious performers)",
         "Named as a negative example who sound trumpets when giving, pray visibly on street corners, "
         "and disfigure their faces when fasting (6:2,5,16)."),
        ("Gentiles (as a comparison)",
         "Cited as people who pile up empty words in prayer and chase after food and clothing, a "
         "comparison Jesus uses to redirect his listeners' trust (6:7,32)."),
    ],
    7: [
        ("Jesus",
         "Warns against hypocritical judgment, invites persistent prayer, summarizes the Law and "
         "Prophets in the Golden Rule, warns of false prophets known by their fruit, and closes with the "
         "parable of two builders before the crowds are left astonished at his authority (7:1-29)."),
        ("disciples",
         "Primary hearers of the closing teaching on the narrow way, false prophets, and the wise and "
         "foolish builders (7:13-27)."),
        ("crowds",
         "React with astonishment at the end of the sermon because Jesus teaches with his own authority, "
         "unlike the scribes (7:28-29)."),
        ("false prophets (warned about)",
         "Described as wolves in sheep's clothing, identifiable by the fruit their lives produce rather "
         "than by their words alone (7:15-20)."),
    ],
    8: [
        ("Jesus",
         "Cleanses a man with a skin disease, heals a centurion's servant from a distance and praises "
         "his faith, heals Peter's mother-in-law and many others, stills a storm on the lake, and casts "
         "demons from two men into a herd of pigs (8:1-34)."),
        ("man with skin disease",
         "Kneels before Jesus asking to be made clean, is healed by Jesus' touch, and is told to show "
         "himself to the priest as the law required (8:1-4)."),
        ("centurion",
         "Roman officer who asks Jesus to heal his servant from a distance and whose faith Jesus praises "
         "as greater than any he has found in Israel (8:5-13)."),
        ("Peter's mother-in-law",
         "Healed of a fever by Jesus, after which she rises and serves him (8:14-15)."),
        ("disciples",
         "Follow Jesus into a boat, panic when a storm threatens to sink it, and wake him; Jesus "
         "questions their little faith before calming the wind and sea (8:23-27)."),
        ("two demon-possessed men",
         "Violent men living among the tombs in the Gadarenes' country; Jesus casts their demons into a "
         "herd of pigs that rushes into the sea, after which the local residents ask Jesus to leave their "
         "region (8:28-34)."),
    ],
    9: [
        ("Jesus",
         "Forgives and heals a paralyzed man despite scribes' objections, calls Matthew from his tax "
         "booth and eats with tax collectors and sinners, answers a question about fasting, raises a "
         "ruler's daughter, heals a woman's twelve-year hemorrhage, gives sight to two blind men, and "
         "frees a mute man from a demon (9:1-34)."),
        ("Matthew",
         "Tax collector called by Jesus from his booth; hosts Jesus at a meal attended by many other tax "
         "collectors and sinners (9:9-10)."),
        ("scribes",
         "Accuse Jesus of blasphemy in their hearts for forgiving the paralyzed man's sins, prompting "
         "Jesus to heal him as visible proof of his authority to forgive (9:2-6)."),
        ("Pharisees",
         "Question why Jesus eats with tax collectors and sinners, and Jesus answers that he came to "
         "call sinners, not the righteous (9:10-13)."),
        ("A ruler and a woman with bleeding",
         "A synagogue ruler asks Jesus to raise his just-died daughter; on the way, a woman who had bled "
         "for twelve years touches Jesus' garment and is healed before Jesus raises the ruler's daughter "
         "(9:18-26)."),
        ("two blind men",
         "Follow Jesus home calling him Son of David, and receive their sight after Jesus asks whether "
         "they believe he is able to heal them (9:27-31)."),
    ],
    10: [
        ("Jesus",
         "Commissions the twelve apostles with authority to heal and cast out unclean spirits, sends "
         "them first to Israel with instructions for the journey, and warns them of coming persecution "
         "while promising the Father's care (10:1-42)."),
        ("the twelve apostles",
         "Named individually, Simon Peter, Andrew, James and John, Philip, Bartholomew, Thomas, Matthew, "
         "James son of Alphaeus, Thaddaeus, Simon the Canaanite, and Judas Iscariot, who would later "
         "betray Jesus, then sent out together to preach, heal, and travel without provisions (10:1-15)."),
        ("households receiving or rejecting messengers",
         "Those in each town who either welcome the apostles, worthy of the peace they bring, or refuse "
         "to hear them, whose town will fare worse than Sodom and Gomorrah (10:11-15,40-42)."),
    ],
    11: [
        ("Jesus",
         "Answers John's disciples by pointing to his own works of healing, praises John's role, "
         "pronounces woes on unrepentant towns, thanks the Father for revealing truth to the simple, and "
         "invites the weary to find rest under his yoke (11:1-30)."),
        ("John the Baptist",
         "Sends disciples from prison to ask whether Jesus is the expected one, then is praised by Jesus "
         "as more than a prophet (11:2-11)."),
        ("John's disciples",
         "Sent by the imprisoned John to ask Jesus directly whether he is the one who should come "
         "(11:2-6)."),
        ("crowds",
         "Addressed by Jesus as he reflects on how both John's austerity and his own table fellowship "
         "were met with the same refusal to listen (11:7,16-19)."),
        ("people of Chorazin, Bethsaida and Capernaum",
         "Towns that witnessed Jesus' mighty works without repenting, drawing a woe comparing them "
         "unfavorably to Tyre, Sidon, and Sodom (11:20-24)."),
    ],
}

THEMES = {
    1: {
        "Jesus' place in Israel's story":
            "The genealogy traces Jesus through Abraham and David across three sets of fourteen "
            "generations, including women with complicated histories, to root his identity in Israel's "
            "own story rather than apart from it (1:1-17).",
        "Faithfulness amid uncertainty":
            "Joseph plans to quietly end his engagement to Mary when he finds her pregnant, then obeys "
            "an angel's dream instruction instead, modeling faithful obedience in a confusing situation "
            "(1:18-20,24-25).",
        "Jesus' saving vocation":
            "The angel explains that the child is to be named Jesus specifically because he will save "
            "his people from their sins, naming his mission before his birth (1:20-23).",
    },
    2: {
        "Conflicting responses to Jesus":
            "Magi travel from the east to worship the newborn king while Herod and all Jerusalem are "
            "troubled by the same news, setting worship against threat from the chapter's opening scene "
            "(2:1-12).",
        "Threatened life and protective action":
            "An angel warns Joseph in time to flee to Egypt with Mary and Jesus before Herod's soldiers "
            "kill the boys of Bethlehem (2:13-18).",
        "Scripture and fulfillment language":
            "Matthew repeatedly reads the events of Jesus' early life, the birthplace, the flight to "
            "Egypt, Rachel's weeping, and the move to Nazareth, as fulfilling specific lines from "
            "Israel's Scriptures (2:5-6,15,17-18,23).",
    },
    3: {
        "Repentance and changed conduct":
            "John demands that even Pharisees and Sadducees produce fruit worthy of repentance, warning "
            "that descent from Abraham cannot substitute for changed conduct (3:7-10).",
        "A coming judgment and renewal":
            "John describes one coming after him who will baptize with the Holy Spirit and fire and "
            "separate wheat from chaff, framing his own baptism as preparation for something more "
            "decisive (3:11-12).",
        "Jesus' baptism and identity":
            "Jesus insists on being baptized to fulfill all righteousness, and the Spirit's descent and "
            "the heavenly voice publicly identify him as God's beloved Son (3:13-17).",
    },
    4: {
        "Testing and Scripture":
            "The devil tempts Jesus three times, twisting Scripture in his second attempt, and each time "
            "Jesus answers from Deuteronomy rather than from his own reasoning (4:1-11).",
        "The kingdom announcement":
            "After John's arrest, Jesus settles in Capernaum and begins proclaiming that the kingdom of "
            "heaven has drawn near, the same message John had preached (4:12-17).",
        "Discipleship and healing":
            "Jesus calls four fishermen away from their nets with a word, and his teaching, preaching, "
            "and healing draw crowds from across the wider region (4:18-25).",
    },
    5: {
        "Kingdom blessings":
            "The Beatitudes pronounce blessing on those the world would not usually call fortunate, the "
            "poor in spirit, mourners, and the persecuted, redefining what blessing looks like (5:3-12).",
        "Visible witness":
            "Jesus calls his followers salt and light, images that only function when they are not "
            "hidden, tying their identity to visible, public impact (5:13-16).",
        "Integrity beyond appearances":
            "Six contrasts push the Law's commands on murder, adultery, divorce, oaths, retaliation, and "
            "enemies past outward compliance into the intentions and relationships behind them "
            "(5:17-48).",
    },
    6: {
        "Sincere devotion":
            "Giving, praying, and fasting are each warned against becoming performances for an audience, "
            "with the same practice either done for show or done sincerely before the Father (6:1-18).",
        "Forgiveness and prayer":
            "The Lord's Prayer asks for forgiveness in the same breath that it commits to forgiving "
            "others, tying answered prayer to an already-forgiving heart (6:9-15).",
        "Wealth and worry":
            "Jesus says no one can serve both God and money, then grounds freedom from anxiety over food "
            "and clothing in trusting the same Father who feeds birds and clothes flowers (6:19-34).",
    },
    7: {
        "Humility and discernment":
            "The image of a plank in one's own eye warns against hypocritical judgment, while the "
            "warning about wolves in sheep's clothing still calls for real discernment about who to "
            "trust (7:1-6,15-20).",
        "Prayer and reciprocity":
            "Persistent asking, seeking, and knocking in prayer are paired directly with the Golden "
            "Rule's call to treat others as one would want to be treated (7:7-12).",
        "Doing what is taught":
            "The parable of the wise and foolish builders makes hearing Jesus' words without obeying "
            "them as dangerous as building a house with no foundation (7:21-27).",
    },
    8: {
        "Authority and compassion":
            "Jesus cleanses a man with a skin disease, heals a centurion's servant from a distance, and "
            "heals Peter's mother-in-law and many others, pairing real authority with real compassion in "
            "each case (8:1-17).",
        "Cost of following":
            "When a would-be follower offers to come along, Jesus answers that even foxes and birds have "
            "homes while he himself has nowhere to lay his head, naming the cost of discipleship plainly "
            "(8:18-22).",
        "Faith and fear":
            "Jesus questions his disciples' little faith during the storm, and the Gadarenes respond to "
            "his power over demons with fear that leads them to ask him to leave, two very different "
            "reactions to the same authority (8:23-34).",
    },
    9: {
        "Forgiveness and restoration":
            "Jesus forgives the paralyzed man's sins before healing him, showing physical healing as "
            "visible proof of an authority whose real point was forgiveness itself (9:1-8).",
        "Mercy toward outsiders":
            "Jesus eats with tax collectors and sinners and answers the Pharisees' objection by quoting "
            "Hosea on mercy rather than sacrifice, defining his mission around those usually excluded "
            "(9:9-13).",
        "Compassion and mission":
            "Seeing the crowds as sheep without a shepherd, Jesus is moved to tell his disciples to pray "
            "for more workers, turning compassion directly into a call for others to join the work "
            "(9:35-38).",
    },
    10: {
        "Commissioned service":
            "Jesus gives the twelve apostles real authority to heal and cast out unclean spirits, then "
            "sends them out with specific instructions rather than keeping that authority for himself "
            "alone (10:1-15).",
        "Courage amid opposition":
            "Jesus warns the twelve they will be hated and dragged before authorities, yet tells them "
            "not to fear, since the Father who notices a falling sparrow also numbers the hairs on their "
            "heads (10:16-31).",
        "Costly allegiance and hospitality":
            "Following Jesus is said to bring division even within families, while welcoming one of his "
            "messengers is treated as equivalent to welcoming Jesus himself (10:34-42).",
    },
    11: {
        "Questions and evidence":
            "John sends disciples from prison to ask directly whether Jesus is the expected one, and "
            "Jesus answers not with a claim but with evidence, the healing and good news his disciples "
            "can already see (11:2-6).",
        "Responsibility for response":
            "Jesus pronounces woes on Chorazin, Bethsaida, and Capernaum specifically because they "
            "witnessed his mighty works and still did not repent, tying judgment to what people had "
            "already seen (11:20-24).",
        "Rest and discipleship":
            "Jesus invites the weary and burdened to take his yoke, describing discipleship itself, not "
            "escape from it, as the source of the rest he offers (11:28-30).",
    },
}


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "40_matthew.json"
    data = load(path)
    for n in range(1, 12):
        key = f"Matthew {n}"
        entry = data[key]
        entry["whereWeAre"] = WWA[n]
        entry["keyFigures"] = [{"name": name, "role": role} for name, role in KEY_FIGURES[n]]
        theme_map = THEMES[n]
        seen = set()
        for theme in entry["keyThemes"]:
            name = theme["theme"]
            if name not in theme_map:
                raise SystemExit(f"Matthew {n}: no explanation drafted for theme {name!r}")
            theme["explanation"] = theme_map[name]
            seen.add(name)
        missing = set(theme_map) - seen
        if missing:
            raise SystemExit(f"Matthew {n}: drafted themes not in source: {missing}")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


AUDIENCE_FIXES = {
    3: ("Readers already familiar with ritual washing in Judaism would have recognized something new in "
        "John's baptism: it specifically called for repentance and bore fruit in changed conduct, not "
        "just purification, which is why he could warn even those claiming Abraham as their father that "
        "ancestry alone would not be enough (Matthew 3:7-10)."),
    7: ("Readers used to Pharisaic and scribal teaching, which worked by citing chains of earlier "
        "authorities, would have felt exactly why the crowds were so struck: Jesus taught the same Torah "
        "with no appeal to any human authority but his own (Matthew 7:29)."),
    10: ("Readers who knew Jewish mission customs, where a sent representative carried the full "
         "authority of the one who sent him, would have understood why welcoming one of the twelve was "
         "treated as equivalent to welcoming Jesus himself (Matthew 10:40)."),
}


def apply_chapter_context():
    path = ROOT / "chapter_context" / "31_matthew.json"
    data = load(path)
    for n, new_audience in AUDIENCE_FIXES.items():
        key = f"Matthew {n}"
        old_audience = data[key]["audience"]
        data[key]["audience"] = new_audience
        if old_audience == new_audience:
            raise SystemExit(f"Matthew {n}: audience fix made no change")
    for entry in data["Matthew 11"]["culture"]:
        if entry["title"] == "A yoke":
            entry["text"] = entry["text"].replace(
                "Rabbis spoke of taking on ‘the yoke of the law.’ Jesus offers his own yoke as "
                "easy.",
                "Rabbis spoke of taking on what was called ‘the yoke of the law.’ Jesus offers "
                "his own yoke as easy.",
            )
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_overview():
    path = ROOT / "book_overviews" / "07_gospels_acts.json"
    data = load(path)
    entry = data["Matthew"]
    entry["summary"] = entry["summary"].replace(
        "Matthew traces Jesus from Abraham and David through His teaching, miracles, conflict, death, "
        "and resurrection, emphasizing fulfillment of Scripture and the demands of discipleship.",
        "Matthew traces Jesus from Abraham and David through his teaching, miracles, conflict, death, "
        "and resurrection, emphasizing fulfillment of Scripture and the demands of discipleship.",
    )
    entry["movements"][0]["description"] = entry["movements"][0]["description"].replace(
        "Jesus' genealogy, birth, baptism, temptation, and beginning ministry establish His messianic "
        "identity.",
        "Jesus' genealogy, birth, baptism, temptation, and beginning ministry establish his messianic "
        "identity.",
    )
    for fig in entry["keyFigures"]:
        if fig["name"] == "John the Baptist":
            fig["description"] = fig["description"].replace(
                "The prophet who prepares the way for Jesus and baptizes Him.",
                "The prophet who prepares the way for Jesus and baptizes him.",
            )
        elif fig["name"] == "Peter":
            fig["description"] = fig["description"].replace(
                "Leader among the twelve disciples, who confesses Jesus as the Messiah but later denies "
                "Him.",
                "Leader among the twelve disciples, who confesses Jesus as the Messiah but later denies "
                "him.",
            )
        elif fig["name"] == "Mary Magdalene":
            fig["description"] = fig["description"].replace(
                "A follower of Jesus who witnesses His death and the empty tomb.",
                "A follower of Jesus who witnesses his death and the empty tomb.",
            )
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_PRONOUN_FIXES = [
    ("Matthew traces Jesus' family line to Abraham and David, then describes His birth and the events "
     "that bring His family to Nazareth.",
     "Matthew traces Jesus' family line to Abraham and David, then describes his birth and the events "
     "that bring his family to Nazareth."),
    ("John prepares the people for repentance, Jesus is baptized and tested, and His ministry begins "
     "with preaching, healing, and the calling of disciples.",
     "John prepares the people for repentance, Jesus is baptized and tested, and his ministry begins "
     "with preaching, healing, and the calling of disciples."),
    ("Jesus comes to be baptized. John protests that Jesus should baptize him instead, but Jesus "
     "insists. As He comes up from the water,",
     "Jesus comes to be baptized. John protests that Jesus should baptize him instead, but Jesus "
     "insists. As he comes up from the water,"),
    ("Then the Spirit leads Jesus into the wilderness, where He fasts forty days and is tempted by the "
     "devil. First the devil tells Him to turn stones into bread.",
     "Then the Spirit leads Jesus into the wilderness, where he fasts forty days and is tempted by the "
     "devil. First the devil tells him to turn stones into bread."),
    ("Next the devil takes Him to the top of the temple and dares Him to jump, quoting a psalm.",
     "Next the devil takes him to the top of the temple and dares him to jump, quoting a psalm."),
    ("Last, the devil offers Him all the kingdoms of the world if He will bow down.",
     "Last, the devil offers him all the kingdoms of the world if he will bow down."),
    ("After John is arrested, Jesus moves to Capernaum by the Sea of Galilee. By the shore He calls two "
     "pairs of fishermen brothers,",
     "After John is arrested, Jesus moves to Capernaum by the Sea of Galilee. By the shore he calls two "
     "pairs of fishermen brothers,"),
    ("Jesus travels through Galilee, teaching, preaching, and healing every kind of sickness, and great "
     "crowds follow Him.",
     "Jesus travels through Galilee, teaching, preaching, and healing every kind of sickness, and great "
     "crowds follow him."),
    ("Jesus teaches His followers about righteousness, prayer, mercy, trust in God, and the obedience "
     "expected of those who enter His kingdom.",
     "Jesus teaches his followers about righteousness, prayer, mercy, trust in God, and the obedience "
     "expected of those who enter his kingdom."),
    ("He tells His followers, “Ye are the salt of the earth,”",
     "he tells his followers, “Ye are the salt of the earth,”"),
    ("Then, again and again, He says, “Ye have heard that it was said,” and takes the law deeper.",
     "Then, again and again, he says, “Ye have heard that it was said,” and takes the law deeper."),
    ("Instead of “An eye for an eye,” He says, “whosoever shall smite thee",
     "Instead of “An eye for an eye,” he says, “whosoever shall smite thee"),
    ("Jesus warns against doing good deeds to be seen by others. He teaches His disciples to pray:",
     "Jesus warns against doing good deeds to be seen by others. he teaches his disciples to pray:"),
    ("He tells them, “Lay not up for yourselves treasures upon earth",
     "he tells them, “Lay not up for yourselves treasures upon earth"),
    ("He goes on: “Judge not, that ye be not judged.”",
     "he goes on: “Judge not, that ye be not judged.”"),
    ("He gives the Golden Rule: “all things whatsoever ye would",
     "he gives the Golden Rule: “all things whatsoever ye would"),
    ("He warns of false prophets “in sheep's clothing,”",
     "he warns of false prophets “in sheep's clothing,”"),
    ("Finally, He says that whoever hears and obeys His words is like a wise man who built his house "
     "upon a rock.",
     "Finally, he says that whoever hears and obeys his words is like a wise man who built his house "
     "upon a rock."),
    ("Coming down from the mountain, Jesus shows His power.",
     "Coming down from the mountain, Jesus shows his power."),
    ("He heals Peter's mother-in-law and many others. When a man offers to follow Him anywhere,",
     "he heals Peter's mother-in-law and many others. When a man offers to follow him anywhere,"),
    ("On the lake, a violent storm hits while Jesus sleeps. His disciples wake Him in terror. He asks,",
     "On the lake, a violent storm hits while Jesus sleeps. his disciples wake him in terror. he asks,"),
    ("On the other side, He frees two men from demons, sending the demons into a herd of pigs",
     "On the other side, he frees two men from demons, sending the demons into a herd of pigs"),
    ("When scribes object, He heals the man to prove He has power to forgive sins.",
     "When scribes object, he heals the man to prove he has power to forgive sins."),
    ("To the critics He says, “They that be whole need not a physician,",
     "To the critics he says, “They that be whole need not a physician,"),
    ("A woman who has bled for twelve years touches the hem of His garment and is healed:",
     "A woman who has bled for twelve years touches the hem of his garment and is healed:"),
    ("Then He raises a ruler's daughter, saying, “the maid is not dead, but sleepeth.”",
     "Then he raises a ruler's daughter, saying, “the maid is not dead, but sleepeth.”"),
    ("He chooses twelve apostles and sends them out to the lost sheep of Israel",
     "he chooses twelve apostles and sends them out to the lost sheep of Israel"),
    ("He warns that they will face hatred and arrest: “be ye therefore wise as serpents,",
     "he warns that they will face hatred and arrest: “be ye therefore wise as serpents,"),
    ("Questions about Jesus increase as He responds to John, confronts unbelief, and challenges "
     "religious leaders who reject His works.",
     "Questions about Jesus increase as he responds to John, confronts unbelief, and challenges "
     "religious leaders who reject his works."),
    ("He praises John as more than a prophet. But He warns towns like Capernaum that saw His miracles "
     "and still did not repent.",
     "he praises John as more than a prophet. But he warns towns like Capernaum that saw his miracles "
     "and still did not repent."),
    ("Then He gives a warm invitation: “Come unto me, all ye that labour",
     "Then he gives a warm invitation: “Come unto me, all ye that labour"),
    ("The Pharisees begin to oppose Him openly. They complain when His hungry disciples pick grain on "
     "the Sabbath.",
     "The Pharisees begin to oppose him openly. They complain when his hungry disciples pick grain on "
     "the Sabbath."),
    ("Then He heals a man with a withered hand in the synagogue on the Sabbath. The Pharisees go out "
     "and plot how to kill Him.",
     "Then he heals a man with a withered hand in the synagogue on the Sabbath. The Pharisees go out "
     "and plot how to kill him."),
    ("the Pharisees claim He does it by the power of Beelzebub,",
     "the Pharisees claim he does it by the power of Beelzebub,"),
    ("He warns that speaking against the Holy Spirit will not be forgiven,",
     "he warns that speaking against the Holy Spirit will not be forgiven,"),
    ("When they demand a sign, He says the only sign will be Jonah's:",
     "When they demand a sign, he says the only sign will be Jonah's:"),
    ("When His mother and brothers come looking for Him, He points to His disciples:",
     "When his mother and brothers come looking for him, he points to his disciples:"),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "07_gospels_acts.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("# Matthew")
    end = text.index("# Mark")
    section = text[start:end]
    for old, new in STORY_PRONOUN_FIXES:
        count = section.count(old)
        if count == 0:
            if section.count(new) == 1:
                continue
            raise SystemExit(f"story fix matched 0 times and not already applied: {old!r}")
        if count != 1:
            raise SystemExit(f"story fix matched {count} times (expected 1): {old!r}")
        section = section.replace(old, new)
    path.write_text(text[:start] + section + text[end:], encoding="utf-8")
    print(f"Updated {path.relative_to(ROOT)}")


if __name__ == "__main__":
    apply_chapter_insights()
    apply_chapter_context()
    apply_overview()
    apply_story_fixes()
