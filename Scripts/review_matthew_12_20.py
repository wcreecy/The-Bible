#!/usr/bin/env python3
"""Apply the completed editorial review for Matthew chapters 12-20 to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


WWA = {
    12: ("Chapter 11 closed with Jesus inviting the weary to find rest under his gentle yoke (Matthew "
         "11:28-30). Chapter 12 shows exactly how little rest the religious leaders are willing to give "
         "him: two Sabbath controversies, over grain and a withered hand, escalate into the Pharisees "
         "plotting his death, and an exorcism gets explained away as demonic rather than divine. When "
         "even Jesus' own family comes looking for him, he redefines family around those who do the "
         "Father's will, a reordering of relationships that chapter 13's parables will describe as the "
         "kingdom itself."),
    13: ("Chapter 12 ended with Jesus redefining family around those who do the Father's will rather "
         "than blood relation (Matthew 12:46-50). Chapter 13 explains why that redefinition is "
         "necessary: a series of parables about seed, weeds, and growth account for why people respond "
         "so differently to the same kingdom message, ending with Jesus himself rejected in his own "
         "hometown by neighbors who thought they already knew him. That same rejection from people who "
         "should have recognized him continues into chapter 14, where Herod Antipas mistakes Jesus for "
         "a John the Baptist he himself had executed."),
    14: ("Chapter 13 ended with Jesus doing few mighty works in his own hometown because of unbelief "
         "(Matthew 13:53-58). Chapter 14 opens with an even darker failure to recognize him: Herod "
         "Antipas, who had already beheaded John the Baptist, wonders if Jesus is John raised from the "
         "dead. Jesus withdraws but still feeds five thousand and later walks on the water to rescue "
         "his frightened disciples, contrasting Herod's fear-driven violence with his own compassionate "
         "authority. That same authority over Israel's own traditions is what Pharisees and scribes "
         "come from Jerusalem to challenge in chapter 15."),
    15: ("Chapter 14 showed Jesus caring for crowds and rescuing frightened disciples even after "
         "Herod's violence (Matthew 14:13-33). Chapter 15 turns to a dispute over handwashing "
         "traditions, which Jesus answers by locating true defilement in the heart rather than in "
         "ritual, and then travels to Gentile territory near Tyre and Sidon, where a Canaanite woman's "
         "persistent faith succeeds where Israel's own religious leaders had only offered empty "
         "tradition. That question of who truly recognizes Jesus sets up chapter 16's pointed question "
         "to the disciples themselves: who do you say that I am?"),
    16: ("Chapter 15 showed a Gentile woman's faith succeeding where religious tradition had failed "
         "(Matthew 15:21-28). Chapter 16 asks the question directly: at Caesarea Philippi, a city built "
         "up around pagan worship, Peter confesses Jesus as the Christ, the Son of the living God, only "
         "for Jesus to immediately begin teaching that this same Christ must suffer, die, and rise "
         "again, a prediction Peter himself rebukes. That tension between confessing who Jesus is and "
         "accepting what his path requires carries directly into chapter 17's vision on the mountain."),
    17: ("Chapter 16 ended with Jesus rebuking Peter for refusing to accept that the Christ must suffer "
         "(Matthew 16:21-23). Chapter 17 answers that hard teaching with a vision: Peter, James, and "
         "John see Jesus transfigured alongside Moses and Elijah, and a heavenly voice tells them to "
         "listen to him. Coming down, Jesus heals a boy the disciples could not heal and again foretells "
         "his death, before paying the temple tax to avoid giving offense, though he argues he is not "
         "actually bound to. That same concern for not giving offense sets up chapter 18's teaching on "
         "humility and the vulnerable."),
    18: ("Chapter 17 showed Jesus quietly paying the temple tax rather than cause offense, even though "
         "he argued he was not obligated to (Matthew 17:24-27). Chapter 18 widens that same concern for "
         "not giving offense into a full teaching on community life: a child is placed at the center of "
         "the question of who is greatest, a parable pictures God's concern for one lost sheep, and a "
         "process for correcting wrongdoing is paired with Peter's question about how often to forgive. "
         "Jesus' answer, forgiveness without a ceiling, sets up chapter 19's test of another "
         "relationship built on commitment: marriage."),
    19: ("Chapter 18 taught forgiveness without a ceiling inside the community of disciples (Matthew "
         "18:21-35). Chapter 19 turns to marriage, another relationship meant to last: Jesus answers "
         "Pharisees on divorce by returning to creation itself, welcomes children his disciples try to "
         "turn away, and tells a wealthy young man to sell what he has and follow him, a request the "
         "man cannot accept. Peter's question about the disciples' own sacrifices, and Jesus' answer "
         "that the first and last may be reversed, sets up chapter 20's parable of a landowner paying "
         "every laborer the same wage."),
    20: ("Chapter 19 ended with Jesus warning that the first and last may be reversed in the kingdom "
         "(Matthew 19:30). Chapter 20 illustrates that reversal: a landowner pays latecomers the same "
         "wage as all-day laborers, answering their protest with a question about generosity rather "
         "than fairness. Traveling toward Jerusalem, Jesus predicts his own death a third time, teaches "
         "that greatness means service, and stops to heal two blind men who refuse to be silenced. That "
         "journey, now healing the blind who call him Son of David, sets up chapter 21's entry into "
         "Jerusalem itself."),
}

KEY_FIGURES = {
    12: [
        ("Jesus",
         "Defends his disciples' Sabbath grain-picking and heals a man's withered hand on the Sabbath, "
         "is accused of exorcising demons by Beelzebub's power, and redefines family around those who "
         "do the Father's will (12:1-14,22-37,46-50)."),
        ("disciples",
         "Picked at by Pharisees for plucking grain on the Sabbath, an act Jesus defends by citing "
         "David and the temple's priests (12:1-8)."),
        ("Pharisees (and scribes)",
         "Challenge Jesus over Sabbath observance, attribute his exorcism to Beelzebub, and later "
         "demand a sign despite having already seen his works (12:1-2,14,24,38)."),
        ("man with withered hand",
         "Healed by Jesus in the synagogue on the Sabbath, prompting the Pharisees to plot against "
         "Jesus (12:9-14)."),
        ("crowds",
         "Amazed by Jesus' healing of a blind and mute demoniac, they wonder aloud whether he could be "
         "the Son of David (12:22-23)."),
        ("Jesus' mother and brothers",
         "Come looking for Jesus while he is teaching, prompting him to redefine his family as whoever "
         "does the will of his Father in heaven (12:46-50)."),
    ],
    13: [
        ("Jesus",
         "Teaches from a boat in parables about the sower, weeds, mustard seed, yeast, hidden treasure, "
         "a pearl, and a net, then is rejected by his own hometown neighbors (13:1-58)."),
        ("disciples",
         "Privately asked by Jesus why he teaches in parables, and given the interpretation of the "
         "sower and the weeds that the crowds do not receive (13:10-23,36-43)."),
        ("crowds",
         "Hear Jesus' parables from the shore while he teaches from a boat, without receiving the "
         "private explanation given to the disciples (13:1-3,34-35)."),
        ("the sower and other parable characters (fictional figures)",
         "Fictional figures in Jesus' parables of the sower, the weeds, and the net, illustrating "
         "different responses to the kingdom message rather than naming real individuals "
         "(13:3-9,24-30,47-50)."),
        ("Jesus' hometown neighbors",
         "Take offense at Jesus in Nazareth because they know his family, causing him to do few mighty "
         "works there (13:54-58)."),
    ],
    14: [
        ("Jesus",
         "Withdraws on hearing of John's execution, but has compassion on the crowd, feeds five "
         "thousand, then walks on the water to rescue a sinking Peter (14:13-33)."),
        ("Herod Antipas",
         "Imprisons and, prompted by a banquet request from Herodias's daughter, beheads John the "
         "Baptist for criticizing his marriage; later wonders whether Jesus is John raised from the "
         "dead (14:1-12)."),
        ("Herodias",
         "Herod's wife, whose marriage John the Baptist had publicly criticized; prompts her daughter "
         "to request John's head after the girl's dance pleases Herod (14:3-11)."),
        ("Peter",
         "Asks to walk to Jesus on the water, begins to sink when he notices the wind, and is caught "
         "and rescued by Jesus' hand (14:28-31)."),
        ("disciples",
         "Battle contrary winds in a boat at night, are terrified when they see Jesus walking toward "
         "them, and worship him as God's Son once he calms the wind (14:24-33)."),
        ("crowds",
         "Follow Jesus by land to a desert place, where he heals their sick and feeds about five "
         "thousand men besides women and children (14:13-21)."),
    ],
    15: [
        ("Jesus",
         "Teaches that defilement comes from the heart rather than unwashed hands, heals a Canaanite "
         "woman's daughter after praising her faith, and feeds four thousand near the Sea of Galilee "
         "(15:1-39)."),
        ("Pharisees",
         "Challenge Jesus because his disciples do not wash their hands before eating, prompting his "
         "teaching on tradition versus the heart (15:1-9)."),
        ("scribes",
         "Travel from Jerusalem alongside the Pharisees to raise the handwashing challenge against "
         "Jesus' disciples (15:1-2)."),
        ("disciples",
         "Urge Jesus to send away the pleading Canaanite woman, then distribute the loaves and fish "
         "that feed four thousand people (15:23,32-38)."),
        ("Canaanite woman",
         "A Gentile mother near Tyre and Sidon who persistently begs Jesus to heal her demon-afflicted "
         "daughter despite his initial refusal, and whose great faith Jesus praises before healing the "
         "girl (15:21-28)."),
        ("crowds",
         "Bring their sick to Jesus near the Sea of Galilee and are fed by him from seven loaves and a "
         "few small fish after three days together (15:29-38)."),
    ],
    16: [
        ("Jesus",
         "Refuses to give the Pharisees and Sadducees a sign, warns disciples about their teaching, "
         "accepts Peter's confession as the Christ, then foretells his suffering and rebukes Peter for "
         "resisting it (16:1-28)."),
        ("Peter",
         "Confesses Jesus as the Christ, the Son of the living God, and is told he will receive the "
         "keys of the kingdom, then rebukes Jesus for predicting his own suffering and is sharply "
         "corrected in turn (16:13-23)."),
        ("disciples",
         "Warned by Jesus to beware the leaven of the Pharisees and Sadducees, later explained as their "
         "teaching (16:5-12)."),
        ("Pharisees",
         "Join the Sadducees in demanding a sign from Jesus, who answers that they can read the weather "
         "but not the times (16:1-4)."),
        ("Sadducees",
         "Join the Pharisees in testing Jesus with a demand for a sign from heaven (16:1-4)."),
    ],
    17: [
        ("Jesus",
         "Transfigured before three disciples with Moses and Elijah present, heals a boy the disciples "
         "could not heal, foretells his death again, and has Peter pay the temple tax for them both "
         "(17:1-27)."),
        ("Peter",
         "Witnesses the transfiguration and offers to build three shelters, then is asked by the "
         "temple-tax collectors whether Jesus pays the tax, prompting Jesus' teaching on sons and "
         "freedom before Jesus provides the coin anyway (17:1-4,24-27)."),
        ("James and John",
         "Along with Peter, the only disciples who witness Jesus transfigured and hear the heavenly "
         "voice command them to listen to him (17:1-5)."),
        ("Moses",
         "Appears with Elijah beside the transfigured Jesus, representing the Law alongside Elijah's "
         "Prophets (17:3-4)."),
        ("Elijah",
         "Appears with Moses beside the transfigured Jesus on the mountain (17:3-4)."),
        ("boy and his father",
         "The father brings his son, afflicted with seizures and a demonic condition the disciples "
         "could not heal, and Jesus heals the boy immediately (17:14-18)."),
    ],
    18: [
        ("Jesus",
         "Answers a question about greatness by placing a child among the disciples, tells the parable "
         "of the lost sheep, outlines a process for addressing sin, and answers Peter's question about "
         "forgiveness with a parable of an unforgiving servant (18:1-35)."),
        ("disciples",
         "Ask Jesus who is greatest in the kingdom, prompting his answer about humility and childlike "
         "status (18:1)."),
        ("Peter",
         "Asks Jesus how many times he must forgive a brother who sins against him, prompting an answer "
         "far beyond any number he expected (18:21-22)."),
        ("child",
         "Placed by Jesus among the disciples as the model of greatness in the kingdom of heaven "
         "(18:2-5)."),
        ("parable shepherd and servants (literary figures)",
         "Fictional figures in Jesus' parables of the lost sheep and the unforgiving servant, "
         "illustrating God's concern for the lost and the scale of forgiveness expected from the "
         "forgiven (18:12-14,23-35)."),
    ],
    19: [
        ("Jesus",
         "Answers Pharisees on divorce by returning to creation, welcomes children his disciples try to "
         "turn away, tells a wealthy young man to sell his possessions and follow him, and promises "
         "reward to those who have left everything for his sake (19:1-30)."),
        ("Pharisees",
         "Test Jesus with a question about the lawfulness of divorce, prompting his teaching on "
         "marriage grounded in creation rather than later legal allowances (19:3-9)."),
        ("disciples",
         "Try to turn away children brought to Jesus and are rebuked for it, then react with surprise "
         "at Jesus' teaching on how hard it is for the wealthy to enter the kingdom (19:13-14,23-25)."),
        ("children",
         "Brought to Jesus for his blessing despite the disciples' attempt to turn them away "
         "(19:13-15)."),
        ("wealthy young man",
         "Asks Jesus what good thing he must do to gain eternal life, but leaves sorrowful when told to "
         "sell his possessions and give to the poor (19:16-22)."),
        ("Peter",
         "Asks Jesus what the disciples will receive for having left everything to follow him, "
         "prompting the promise that the first may be last and the last first (19:27-30)."),
    ],
    20: [
        ("Jesus",
         "Tells the parable of the generous landowner, predicts his death a third time, redefines "
         "greatness as service when James and John's mother asks for places of honor, and heals two "
         "blind men outside Jericho (20:1-34)."),
        ("disciples",
         "Hear Jesus' third prediction of his coming death and are indignant when James and John's "
         "mother asks for places of honor for her sons (20:17-19,24)."),
        ("James and John",
         "Their mother asks Jesus to seat them at his right and left in his kingdom, prompting his "
         "teaching that greatness means serving rather than being served (20:20-28)."),
        ("two blind men",
         "Call out to Jesus as Son of David outside Jericho, are told by the crowd to be quiet, and "
         "receive their sight when Jesus has compassion and touches their eyes (20:29-34)."),
        ("parable landowner and laborers",
         "Fictional figures in Jesus' parable of the vineyard workers, illustrating a generosity that "
         "exceeds strict fairness (20:1-16)."),
    ],
}

THEMES = {
    12: {
        "Mercy on the Sabbath":
            "Jesus defends his disciples picking grain and heals a man's withered hand on the Sabbath, "
            "arguing that mercy and doing good take priority over a rigid rest requirement (12:1-14).",
        "Interpreting spiritual works":
            "When critics attribute Jesus' exorcism to demonic power, he answers that a divided kingdom "
            "cannot stand, making how people explain his works a test of their own hearts (12:22-37).",
        "Kinship and obedience":
            "When his mother and brothers come looking for him, Jesus points to his disciples and names "
            "whoever does the Father's will as his true family (12:46-50).",
    },
    13: {
        "Different responses to the word":
            "The parable of the sower explains identical seed producing wildly different results "
            "depending entirely on the condition of the soil it falls on (13:3-23).",
        "Patient growth and final judgment":
            "The weeds are left to grow alongside the wheat until harvest, picturing a kingdom that "
            "tolerates apparent mixture now but still ends in a real separation later (13:24-43).",
        "The kingdom's worth":
            "Treasure hidden in a field and a pearl of great price both describe something worth giving "
            "up everything else to obtain (13:44-46).",
    },
    14: {
        "Prophetic courage and political violence":
            "John's criticism of Herod's marriage, spoken directly to a ruler who could kill him, costs "
            "John his life after a banquet request he never saw coming (14:1-12).",
        "Compassion and provision":
            "Jesus withdraws after hearing of John's death, but still has compassion on the crowd that "
            "follows him, feeding five thousand men besides women and children from five loaves and two "
            "fish (14:13-21).",
        "Fear, trust and rescue":
            "Peter steps out of the boat in faith, then sinks in fear, and Jesus immediately reaches out "
            "to save him, holding both faith and failure together in the same moment (14:28-31).",
    },
    15: {
        "Heart and tradition":
            "Jesus answers a complaint about unwashed hands by locating real defilement in what comes "
            "out of the heart, not in ritual purity rules added onto the law (15:1-20).",
        "Persistent faith across boundaries":
            "A Canaanite woman keeps pressing her request even after Jesus describes his mission as "
            "being to Israel first, and Jesus praises her faith as great precisely because she does not "
            "give up (15:21-28).",
        "Compassion for the hungry":
            "Jesus feeds four thousand people with seven loaves and a few small fish, echoing his "
            "earlier compassion for the five thousand in a different region (15:32-39).",
    },
    16: {
        "Recognizing Jesus":
            "Peter's confession that Jesus is the Christ, the Son of the living God, is the clearest "
            "statement in the Gospel so far of who Jesus actually is (16:13-16).",
        "A suffering Messiah":
            "Immediately after Peter's confession, Jesus says the Christ must suffer, die, and rise "
            "again, a path Peter himself rebukes him for predicting (16:21-23).",
        "Costly discipleship":
            "Jesus tells his followers that gaining the whole world while losing their own soul is no "
            "gain at all, tying discipleship to self-denial rather than self-preservation (16:24-26).",
    },
    17: {
        "Revelation and listening":
            "A heavenly voice at the transfiguration tells Peter, James, and John to listen to Jesus "
            "specifically, even with Moses and Elijah also present (17:1-5).",
        "Faith and dependence":
            "The disciples cannot heal a boy with seizures, and Jesus traces the failure to their own "
            "little faith rather than to any limit on what is possible (17:14-20).",
        "Freedom and responsibility":
            "Jesus argues that as God's son he is technically exempt from the temple tax, then pays it "
            "anyway rather than cause unnecessary offense (17:24-27).",
    },
    18: {
        "Humility and protecting the vulnerable":
            "Jesus places a child, someone with essentially no social status, at the center of his "
            "answer about who is greatest in the kingdom (18:1-5).",
        "Restoring relationships":
            "A parable about one lost sheep out of a hundred pictures God's concern for the individual, "
            "which Jesus follows with a concrete process for restoring a brother who sins (18:10-20).",
        "Forgiveness and accountability":
            "Asked how many times to forgive, Jesus answers with a number far beyond any reasonable "
            "count, then tells a parable where an unforgiving servant's own forgiven debt is revoked "
            "(18:21-35).",
    },
    19: {
        "Marriage and faithful commitment":
            "Jesus answers a question about divorce by pointing back to creation's original design for "
            "marriage rather than arguing over the law's later allowances (19:3-9).",
        "Receiving the overlooked":
            "Jesus rebukes his disciples for turning away children brought to him, insisting the "
            "kingdom belongs to those just like them (19:13-15).",
        "Wealth and reliance on God":
            "A wealthy young man walks away sorrowful rather than sell his possessions, prompting Jesus "
            "to say it is easier for a camel to pass through a needle's eye than for a rich person to "
            "enter the kingdom (19:16-26).",
    },
    20: {
        "Generosity beyond calculation":
            "A landowner pays workers hired at the eleventh hour the same wage as those who worked all "
            "day, defending the choice as his own generosity rather than an injustice to anyone "
            "(20:1-16).",
        "Greatness as service":
            "When James and John's mother asks for places of honor, Jesus redefines greatness as "
            "serving others rather than being served (20:20-28).",
        "Mercy and attention":
            "Jesus stops for two blind men the crowd tries to silence, giving them the attention and "
            "mercy the crowd itself withheld (20:29-34).",
    },
}

SUMMARY_FIXES = {
    13: [
        ("interprets the sower and weeds in terms of responses to the kingdom and the final separation "
         "of evil Matthew 13:10–23,Matthew 13:36–43.",
         "interprets the sower and weeds in terms of responses to the kingdom and the final separation "
         "of evil (Matthew 13:10–23; Matthew 13:36–43)."),
    ],
}


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "40_matthew.json"
    data = load(path)
    for n in range(12, 21):
        key = f"Matthew {n}"
        entry = data[key]
        entry["whereWeAre"] = WWA[n]
        for old, new in SUMMARY_FIXES.get(n, []):
            if old not in entry["summary"]:
                raise SystemExit(f"Matthew {n}: summary fix not found: {old!r}")
            entry["summary"] = entry["summary"].replace(old, new)
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
    13: ("Listeners used to rabbis teaching with direct, propositional arguments would have noticed "
         "that Jesus instead taught in parables that could inform the curious while concealing meaning "
         "from those who merely wanted a sign, the same divide the chapter describes between different "
         "soils and the wheat and weeds growing together."),
    15: ("Jewish listeners who distinguished themselves from Gentiles through purity customs like "
         "handwashing would have been struck that defilement, in Jesus' own teaching, comes from within "
         "the heart rather than from what enters the body, the same reversal that lets a Gentile "
         "woman's faith succeed where Israel's own leaders' traditions had failed."),
    16: ("Readers who knew Caesarea Philippi as a center of pagan worship built up by Herod's son "
         "Philip would have felt the force of Peter's confession happening in exactly that setting: "
         "Jesus is named the Christ, the Son of the living God, in the shadow of rival claims to divine "
         "power."),
    18: ("A community used to ranking people by social honor would have felt the force of Jesus placing "
         "a child, someone with essentially no public status, at the center of his answer about who is "
         "greatest, and of insisting that private correction and limitless forgiveness mattered more "
         "than social standing."),
    19: ("Readers aware that both stricter and more permissive Jewish schools argued over acceptable "
         "grounds for divorce would have recognized Jesus deliberately bypassing that debate, appealing "
         "instead to creation itself rather than siding with either school's reading of Moses."),
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
    for entry in data["Matthew 16"]["culture"]:
        if entry["title"] == "Reading the sky":
            entry["text"] = entry["text"].replace(
                "‘Red sky at night’ weather lore was familiar to fishermen and farmers.",
                "Weather lore familiar to fishermen and farmers, similar to what is still called "
                "‘red sky at night’ wisdom today.",
            )
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_PRONOUN_FIXES = [
    ("When Jesus teaches in His hometown of Nazareth, people take offense: “Is not this the "
     "carpenter's son?” He says, “A prophet is not without honour,",
     "When Jesus teaches in his hometown of Nazareth, people take offense: “Is not this the "
     "carpenter's son?” he says, “A prophet is not without honour,"),
    ("When Jesus hears, He goes away to a quiet place, but crowds follow. Moved with compassion, He "
     "heals their sick. In the evening He takes five loaves and two fish, gives thanks, and feeds "
     "“about five thousand men, beside women and children,” with twelve baskets left over. That night, "
     "the disciples are rowing against a storm when they see Jesus walking on the water. They think He "
     "is a ghost, but He says, “Be of good cheer; it is I; be not afraid.” Peter asks to come to Him "
     "and walks on the water, until he sees the wind, panics, and begins to sink. “Lord, save me.” "
     "Jesus catches him: “O thou of little faith, wherefore didst thou doubt?” The disciples worship "
     "Him: “Of a truth thou art the Son of God.”",
     "When Jesus hears, he goes away to a quiet place, but crowds follow. Moved with compassion, he "
     "heals their sick. In the evening he takes five loaves and two fish, gives thanks, and feeds "
     "“about five thousand men, beside women and children,” with twelve baskets left over. That night, "
     "the disciples are rowing against a storm when they see Jesus walking on the water. They think he "
     "is a ghost, but he says, “Be of good cheer; it is I; be not afraid.” Peter asks to come to him "
     "and walks on the water, until he sees the wind, panics, and begins to sink. “Lord, save me.” "
     "Jesus catches him: “O thou of little faith, wherefore didst thou doubt?” The disciples worship "
     "him: “Of a truth thou art the Son of God.”"),
    ("Jesus exposes false religious traditions, welcomes expressions of faith, and begins preparing "
     "His disciples for His death and resurrection.",
     "Jesus exposes false religious traditions, welcomes expressions of faith, and begins preparing "
     "his disciples for his death and resurrection."),
    ("Jesus says they have put human traditions above God's commands. He quotes Isaiah:",
     "Jesus says they have put human traditions above God's commands. he quotes Isaiah:"),
    ("because evil thoughts, murder, and lies come from the heart. He calls the Pharisees blind guides:",
     "because evil thoughts, murder, and lies come from the heart. he calls the Pharisees blind guides:"),
    ("In Gentile territory, a Canaanite woman begs Him to heal her demon-possessed daughter. Jesus "
     "tests her, saying He was sent to Israel and it is not right to give the children's bread to the "
     "dogs.",
     "In Gentile territory, a Canaanite woman begs him to heal her demon-possessed daughter. Jesus "
     "tests her, saying he was sent to Israel and it is not right to give the children's bread to the "
     "dogs."),
    ("He then feeds four thousand men, plus women and children, with seven loaves and a few fish.",
     "he then feeds four thousand men, plus women and children, with seven loaves and a few fish."),
    ("Near Caesarea Philippi, Jesus asks His disciples, “But whom say ye that I am?”",
     "Near Caesarea Philippi, Jesus asks his disciples, “But whom say ye that I am?”"),
    ("From then on, Jesus begins to tell them plainly that He must suffer in Jerusalem, be killed, and "
     "rise on the third day. Peter pulls Him aside and argues, but Jesus says, “Get thee behind me, "
     "Satan.” He tells them,",
     "From then on, Jesus begins to tell them plainly that he must suffer in Jerusalem, be killed, and "
     "rise on the third day. Peter pulls him aside and argues, but Jesus says, “Get thee behind me, "
     "Satan.” he tells them,"),
    ("Six days later, Jesus takes Peter, James, and John up a high mountain. There He is transfigured:",
     "Six days later, Jesus takes Peter, James, and John up a high mountain. There he is transfigured:"),
    ("Moses and Elijah appear and talk with Him.",
     "Moses and Elijah appear and talk with him."),
    ("Coming down, Jesus heals a boy the other disciples could not help. He tells them that with faith "
     "“as a grain of mustard seed,” they could move mountains. He predicts His death again. When "
     "collectors ask whether He pays the temple tax,",
     "Coming down, Jesus heals a boy the other disciples could not help. he tells them that with faith "
     "“as a grain of mustard seed,” they could move mountains. he predicts his death again. When "
     "collectors ask whether he pays the temple tax,"),
    ("Jesus teaches His followers to care for the vulnerable, forgive others, honor marriage, and seek "
     "greatness through service rather than status.",
     "Jesus teaches his followers to care for the vulnerable, forgive others, honor marriage, and seek "
     "greatness through service rather than status."),
    ("He warns that anyone who leads one of these little ones into sin would be better off drowned "
     "with a millstone around his neck.",
     "he warns that anyone who leads one of these little ones into sin would be better off drowned "
     "with a millstone around his neck."),
    ("Jesus explains how to settle a wrong between believers, and He promises,",
     "Jesus explains how to settle a wrong between believers, and he promises,"),
    ("Then He tells of a servant whose king forgave him a debt of ten thousand talents,",
     "Then he tells of a servant whose king forgave him a debt of ten thousand talents,"),
    ("Pharisees test Jesus about divorce. He points back to creation, when God made them male and "
     "female:",
     "Pharisees test Jesus about divorce. he points back to creation, when God made them male and "
     "female:"),
    ("Jesus tells him to “go and sell that thou hast, and give to the poor,” and follow Him.",
     "Jesus tells him to “go and sell that thou hast, and give to the poor,” and follow him."),
    ("On the way to Jerusalem, Jesus predicts His death a third time. Then the mother of James and "
     "John asks for her sons to sit at His right and left.",
     "On the way to Jerusalem, Jesus predicts his death a third time. Then the mother of James and "
     "John asks for her sons to sit at his right and left."),
    ("Leaving Jericho, He heals two blind men who cry out,",
     "Leaving Jericho, he heals two blind men who cry out,"),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "07_gospels_acts.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("Jesus Reveals the Mysteries of the Kingdom")
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
    apply_story_fixes()
