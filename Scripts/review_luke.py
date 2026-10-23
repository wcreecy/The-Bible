#!/usr/bin/env python3
"""Apply the completed editorial review for Luke to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


WWA = {
    1: ("Mark's Gospel closed with the risen Jesus commissioning his followers and ascending to "
        "heaven, after which the women fled the tomb afraid (Mark 16:1-8,19-20). Luke opens his own "
        "orderly account differently, going back before Jesus' birth: the angel Gabriel announces "
        "John's birth to the priest Zechariah and then Mary's role as the mother of the promised "
        "Davidic king, and the chapter closes with John's birth and his father's prophecy (1:1-80). "
        "That birth of the forerunner sets up chapter 2's birth of the one he was sent to prepare "
        "for."),
    2: ("Chapter 1 ended with Zechariah's prophecy that his son John would prepare the way for God's "
        "promised deliverance (1:76-79). Chapter 2 delivers that deliverer: Jesus is born in "
        "Bethlehem during a Roman registration, shepherds and later Simeon and Anna recognize him, "
        "and at twelve he astonishes temple teachers with his understanding before returning home in "
        "obedience (2:1-52). Luke then jumps ahead about eighteen years to chapter 3, where John's "
        "own adult ministry finally begins."),
    3: ("Chapter 2 closed with the boy Jesus growing in wisdom and favor while John, though already "
        "born, was still years from his public ministry (2:52). Chapter 3 opens that ministry: John "
        "preaches repentance to crowds, tax collectors, and soldiers, denies being the Messiah, and "
        "is eventually imprisoned by Herod; Jesus is baptized, and Luke traces his ancestry all the "
        "way back to Adam (3:1-38). That baptism and genealogy, naming Jesus as God's Son and "
        "descendant of Adam, set up chapter 4's account of the devil's own direct challenge to that "
        "identity."),
    4: ("Chapter 3 ended with a voice from heaven naming Jesus God's beloved Son, and a genealogy "
        "tracing him back to Adam (3:22,38). Chapter 4 tests that identity: the devil tempts Jesus in "
        "the wilderness, he reads Isaiah's words about good news for the poor in his hometown "
        "synagogue and is nearly thrown off a cliff for it, and in Capernaum he teaches with "
        "authority, heals, and casts out demons (4:1-44). That pattern of authority and controversy "
        "continues in chapter 5, where a miraculous catch of fish leads Simon, James, and John to "
        "leave everything and follow him."),
    5: ("Chapter 4 ended with Jesus insisting he must preach the kingdom message in other towns too "
        "(4:43-44). Chapter 5 shows that mission drawing followers and critics alike: a miraculous "
        "catch of fish leads Simon, James, and John to leave their boats, Jesus heals and forgives a "
        "paralyzed man despite scribes' objections, and he calls the tax collector Levi while "
        "explaining his new teaching with images of wedding guests and new wine (5:1-39). Those "
        "objections sharpen in chapter 6, where Sabbath disputes lead Jesus to choose twelve "
        "apostles and deliver a sweeping sermon on the kingdom's values."),
    6: ("Chapter 5 ended with Jesus defending his disciples' new way of following him against the old "
        "patterns of fasting and patched garments (5:36-39). Chapter 6 shows that new way in full: "
        "Sabbath healings provoke his opponents, he chooses twelve apostles after a night of prayer, "
        "and he teaches a crowd blessings for the poor and hungry alongside warnings to the rich, "
        "love for enemies, and the need to act on what they hear (6:1-49). That sermon's call to "
        "build on a solid foundation leads into chapter 7's stories of people who respond to Jesus in "
        "faith."),
    7: ("Chapter 6 closed with Jesus warning that hearing his words without acting on them is like "
        "building a house with no foundation (6:46-49). Chapter 7 shows the foundation of faith in "
        "action: Jesus heals a centurion's servant because of the officer's trust, raises a widow's "
        "only son at Nain, answers John the Baptist's own doubts from prison, and lets a sinful "
        "woman's love at a Pharisee's table outshine his host's thin hospitality (7:1-50). That "
        "contrast between deep faith and shallow religion carries into chapter 8's parable of seed "
        "falling on different kinds of soil."),
    8: ("Chapter 7 ended with Jesus telling a forgiven woman that her faith had saved her, while his "
        "host Simon had offered little welcome at all (7:44-50). Chapter 8 widens that contrast: "
        "Jesus travels with the Twelve and the women who support his ministry, teaches that only "
        "some hearers let the word of God bear fruit, calms a storm, frees a man tormented by many "
        "demons, and heals a woman with bleeding on the way to raising Jairus's daughter (8:1-56). "
        "That combination of teaching and authority continues in chapter 9, where Jesus commissions "
        "the Twelve to do the same kind of work themselves."),
    9: ("Chapter 8 ended with Jesus raising Jairus's daughter and ordering her parents to tell no one "
        "(8:54-56). Chapter 9 sends that same authority outward: Jesus commissions the Twelve to "
        "preach and heal, feeds a crowd of five thousand, receives Peter's confession that he is "
        "God's Messiah, is transfigured before three disciples, and begins setting his face toward "
        "Jerusalem despite a Samaritan village's refusal to welcome him (9:1-62). That turn toward "
        "Jerusalem opens the travel narrative chapter 10 continues with the sending of seventy more "
        "messengers."),
    10: ("Chapter 9 closed with Jesus warning that no one who looks back after starting the journey "
         "is fit for God's kingdom (9:61-62). Chapter 10 continues that same journey: Jesus sends out "
         "seventy or seventy-two messengers ahead of him, a legal expert's question about the law "
         "leads to the parable of the compassionate Samaritan, and at Martha and Mary's home Jesus "
         "commends Mary for choosing to listen rather than stay busy serving (10:1-42). That praise "
         "for attentive listening leads directly into chapter 11's request from a disciple to be "
         "taught how to pray."),
    11: ("Chapter 10 ended with Jesus telling Martha that Mary had chosen the better part by sitting "
         "and listening to him (10:38-42). Chapter 11 opens with a disciple asking to be taught to "
         "pray the same way Mary listened, and Jesus gives them the Lord's Prayer before an exorcism "
         "draws the charge that he acts by Beelzebul; at a Pharisee's meal he denounces outward "
         "religious display that neglects justice and love (11:1-54). That public confrontation sets "
         "up chapter 12's private warning to the disciples about the same group's hypocrisy."),
    12: ("Chapter 11 ended with Pharisees and legal experts watching Jesus closely, hoping to trap "
         "him in something he said (11:53-54). Chapter 12 shows Jesus turning to warn his own "
         "disciples first: he tells them not to fear those who can only kill the body, refuses to "
         "settle an inheritance dispute and instead tells the parable of the rich fool, and calls "
         "them to trust God's care over anxiety while staying ready for his return (12:1-59). That "
         "same urgency about readiness carries into chapter 13's call to repent before it is too "
         "late."),
    13: ("Chapter 12 ended with Jesus urging his hearers to settle matters quickly, before it is too "
         "late to be reconciled (12:57-59). Chapter 13 presses that urgency further: Jesus rejects "
         "the idea that victims of a recent tragedy were worse sinners than anyone else and calls "
         "everyone to repent, heals a bent woman on the Sabbath over a synagogue leader's objection, "
         "and as he journeys on grieves over Jerusalem's history of rejecting the prophets sent to it "
         "(13:1-35). That lament continues in chapter 14, set at the table of one more Pharisee who "
         "watches Jesus closely."),
    14: ("Chapter 13 ended with Jesus grieving that Jerusalem was not willing to be gathered the way "
         "a hen gathers her chicks (13:34-35). Chapter 14 shows that resistance playing out at a "
         "Pharisee leader's Sabbath table: Jesus heals a man despite the objection, teaches humility "
         "about seating and hospitality toward people who cannot repay it, tells of a great banquet "
         "whose invited guests make excuses, and warns crowds to count the cost of following him "
         "(14:1-35). That demand for total commitment sets up chapter 15's parables defending why "
         "Jesus welcomes people who seem to have little to offer him."),
    15: ("Chapter 14 ended with Jesus warning that whoever does not renounce all he has cannot be his "
         "disciple (14:33-35). Chapter 15 answers why Jesus associates with people who seem to have "
         "renounced nothing at all: when Pharisees and scribes complain that he welcomes sinners, he "
         "tells three stories of a lost sheep, a lost coin, and a lost son, each ending in celebration "
         "over what was found, while the last parable's resentful older brother leaves the question "
         "of joining unanswered (15:1-32). That same tension between joy and resentment continues "
         "into chapter 16's warnings about wealth."),
    16: ("Chapter 15 ended with a father pleading for his resentful older son to join the celebration "
         "over a brother who was dead and is alive again (15:25-32). Chapter 16 turns to money: "
         "Jesus tells of a dismissed manager who secures his future by reducing others' debts, warns "
         "money-loving Pharisees that no one can serve both God and wealth, and contrasts a rich "
         "man's comfortable life with the poor man Lazarus at his gate, whose situations are "
         "completely reversed after death (16:1-31). That reversal leads into chapter 17's teaching "
         "on a kingdom that arrives differently than expected."),
    17: ("Chapter 16 ended with Abraham telling the rich man that if his brothers will not listen to "
         "Moses and the prophets, neither would someone risen from the dead persuade them "
         "(16:27-31). Chapter 17 shows persuasion already failing in small ways: Jesus warns against "
         "causing others to stumble, heals ten people with a skin disease but sees only one, a "
         "Samaritan, return to give thanks, and warns that the kingdom's and the Son of man's coming "
         "will be sudden, not something to chase after on rumor (17:1-37). That warning continues in "
         "chapter 18's call to persistent, humble prayer in the meantime."),
    18: ("Chapter 17 ended with Jesus warning that on the day of the Son of man's coming, people must "
         "not look back, remembering Lot's wife (17:28-37). Chapter 18 teaches how to wait for that "
         "day rightly: a persistent widow's story teaches prayer that does not give up, a humble tax "
         "collector's prayer is accepted over a self-confident Pharisee's, Jesus welcomes children "
         "and tells a wealthy ruler to sell his possessions, and nearing Jericho he restores a "
         "blind beggar's sight (18:1-43). That healed beggar leads into chapter 19's account of "
         "another outcast near Jericho, the tax collector Zacchaeus."),
    19: ("Chapter 18 ended with a blind beggar near Jericho receiving his sight and the crowd giving "
         "praise to God (18:35-43). Chapter 19 finds another outcast in that same city: Jesus calls "
         "Zacchaeus the tax collector down from a tree and brings salvation to his house, tells a "
         "parable about servants held accountable for what they were given, and enters Jerusalem amid "
         "praise before weeping over the city and driving sellers from the temple (19:1-48). That "
         "temple confrontation sets up chapter 20's direct challenges from the leaders who run it."),
    20: ("Chapter 19 ended with religious leaders looking for a way to destroy Jesus because the "
         "people hung on his every word in the temple (19:47-48). Chapter 20 shows that opposition "
         "taking shape in public debate: leaders challenge his authority, his parable of the tenant "
         "farmers who kill the owner's son exposes them further, and he answers trap questions about "
         "Roman taxes and resurrection before warning against scribes who exploit widows while "
         "seeking honor (20:1-47). That warning leads directly into chapter 21's praise for a poor "
         "widow who gives everything she has."),
    21: ("Chapter 20 ended with Jesus warning that scribes who devour widows' houses while making "
         "long prayers will receive greater condemnation (20:45-47). Chapter 21 immediately sets a "
         "poor widow's own small gift against that warning: Jesus praises her two coins as greater "
         "than the wealthy's large contributions, then predicts the temple's destruction and "
         "describes wars, persecution, and cosmic upheaval before urging watchfulness rather than "
         "despair (21:1-38). That call to stay awake leads into chapter 22's account of the night "
         "Jesus himself was betrayed."),
    22: ("Chapter 21 ended with Jesus teaching daily in the temple while crowds came early each "
         "morning to hear him there (21:37-38). Chapter 22 follows him into that final night: as "
         "Passover approaches Judas arranges to betray him, Jesus shares a last meal reinterpreting "
         "its bread and cup around his own body and covenant, prays in anguish on the Mount of "
         "Olives, is arrested, and is mocked and questioned before the council after Peter denies him "
         "three times (22:1-71). That council hearing sets up chapter 23's formal trial before Rome's "
         "own representatives."),
    23: ("Chapter 22 ended with the council asking Jesus directly whether he was the Son of God and "
         "deciding they needed no further testimony against him (22:70-71). Chapter 23 carries that "
         "charge to Pilate and Herod Antipas, both of whom examine Jesus without finding real fault "
         "in him, yet Pilate yields to the crowd's demand to release Barabbas and crucify Jesus "
         "instead; Jesus is mocked, dies between two criminals, and is buried by Joseph of Arimathea "
         "before the Sabbath begins (23:1-56). That burial sets up chapter 24's discovery, after the "
         "Sabbath ends, that the tomb is empty."),
    24: ("Chapter 23 ended with women from Galilee watching where Joseph laid Jesus' body, then "
         "resting on the Sabbath as the law commanded (23:55-56). Luke's closing chapter answers "
         "that rest: the same women find the tomb empty, two disciples recognize the risen Jesus on "
         "the road to Emmaus in the breaking of bread, and he appears to the gathered disciples and "
         "is carried up to heaven after commissioning them to preach forgiveness to all nations "
         "(24:1-53). That commission is where John's Gospel takes up Jesus' story again, from its "
         "own distinct beginning in the eternal Word."),
}

KEY_FIGURES = {
    1: [
        ("Zechariah",
         "A priest who doubts Gabriel's announcement and is struck speechless, then regains his "
         "voice at John's birth to prophesy about God's promised deliverance (1:8-20,57-79)."),
        ("Elizabeth",
         "Conceives John in her old age, and when Mary visits her the baby leaps in her womb as she "
         "blesses Mary as the mother of her Lord (1:24-25,39-45)."),
        ("Gabriel",
         "An angel sent to announce John's birth to Zechariah and, six months later, Jesus' birth to "
         "Mary, naming Jesus the promised Son of the Highest (1:11-20,26-38)."),
        ("Mary",
         "A young virgin who accepts Gabriel's announcement in trust and sings a song praising God "
         "for lifting up the lowly and bringing down the proud (1:26-38,46-55)."),
        ("John",
         "Born to Zechariah and Elizabeth in their old age and named by his father's own written "
         "word, the child Zechariah's prophecy says will prepare the way of the Lord (1:57-66,76-79)."),
        ("Jesus",
         "Named by Gabriel before his birth as the promised Davidic king whose kingdom will never end "
         "(1:31-33)."),
    ],
    2: [
        ("Joseph",
         "Travels with the pregnant Mary from Nazareth to Bethlehem for the Roman registration and "
         "returns there each year for Passover (2:4-7,41-42)."),
        ("Mary",
         "Gives birth to Jesus in Bethlehem, treasures what she hears about him in her heart, and "
         "later searches anxiously for him when he stays behind in the temple (2:6-7,19,41-48)."),
        ("Jesus",
         "Born in Bethlehem and laid in a manger, then found at twelve astonishing the temple "
         "teachers with his understanding before returning home in obedience (2:7,46-51)."),
        ("Shepherds",
         "Hear an angel's announcement of Jesus' birth, visit the manger, and spread the news to "
         "everyone they meet (2:8-18)."),
        ("Simeon",
         "A devout man promised he would not die before seeing the Messiah, who takes the infant "
         "Jesus in his arms and praises God while warning Mary of coming sorrow (2:25-35)."),
        ("Anna",
         "An elderly prophetess who gives thanks for the infant Jesus and tells everyone waiting for "
         "Jerusalem's redemption about him (2:36-38)."),
    ],
    3: [
        ("John the Baptist",
         "Preaches repentance in the Jordan region, gives crowds, tax collectors, and soldiers "
         "practical instructions, and denies being the Messiah himself before Herod imprisons him "
         "(3:3-20)."),
        ("Jesus",
         "Is baptized, hears a heavenly voice name him God's beloved Son, and has his ancestry traced "
         "by Luke all the way back to Adam (3:21-38)."),
        ("Herod Antipas",
         "Rebuked by John for his marriage to Herodias, Herod responds by locking John up in prison "
         "(3:19-20)."),
        ("Herodias",
         "The woman whose marriage to Herod Antipas draws John's public rebuke (3:19)."),
        ("Crowds, tax collectors and soldiers",
         "Ask John what they should do, and he tells them to share what they have, overcharge no "
         "one, and be content with their wages (3:10-14)."),
        ("Tiberius Caesar and Pilate",
         "Named rulers Luke uses to date the start of John's ministry to around AD 28-29 (3:1-2)."),
    ],
    4: [
        ("Jesus",
         "Resists the devil's wilderness temptations with Scripture, reads Isaiah's promise of good "
         "news to the poor in the Nazareth synagogue, and teaches, heals, and casts out demons with "
         "authority in Capernaum (4:1-44)."),
        ("The devil",
         "Tempts Jesus three times in the wilderness, twisting Scripture in his final temptation, "
         "and departs only until a more opportune time (4:1-13)."),
        ("Nazareth synagogue hearers",
         "First marvel at Jesus' gracious words, then grow furious and try to throw him off a cliff "
         "when he recalls God's mercy reaching foreigners ahead of Israel (4:22-29)."),
        ("Elijah and Elisha",
         "Earlier prophets Jesus cites as having helped a foreign widow and healed a foreign leper "
         "rather than anyone in Israel, provoking his hometown's anger (4:25-27)."),
        ("Simon",
         "His mother-in-law is healed of a fever by Jesus in his own Capernaum home (4:38-39)."),
        ("Demons",
         "Recognize Jesus and are cast out of an afflicted man in the Capernaum synagogue and of many "
         "others brought to him at sunset (4:33-36,41)."),
    ],
    5: [
        ("Jesus",
         "Calls fishermen to follow him after a miraculous catch, cleanses a man with a skin disease, "
         "forgives and heals a paralyzed man, and calls the tax collector Levi (5:1-32)."),
        ("Simon Peter",
         "Falls at Jesus' knees calling himself a sinful man after the miraculous catch of fish, then "
         "leaves his boats to follow him (5:8-11)."),
        ("James and John",
         "Simon's fishing partners who are equally astonished by the great catch and leave "
         "everything to follow Jesus alongside him (5:7-11)."),
        ("Levi",
         "A tax collector who leaves his booth the moment Jesus calls him and throws a great feast "
         "for him at his own house (5:27-29)."),
        ("Paralyzed man and friends",
         "His friends lower him through the roof tiles to reach Jesus, whose forgiveness and healing "
         "of the man prove his authority before watching scribes (5:18-25)."),
        ("Scribes and Pharisees",
         "Object that only God can forgive sins and criticize Jesus for eating with tax collectors "
         "and sinners (5:21,30)."),
    ],
    6: [
        ("Jesus",
         "Heals on the Sabbath, chooses twelve apostles after praying all night, and teaches a great "
         "sermon of blessings, warnings, and practical obedience (6:1-49)."),
        ("The twelve apostles",
         "Chosen by Jesus after a night of prayer to be his closest followers (6:12-16)."),
        ("Scribes and Pharisees",
         "Watch for grounds to accuse Jesus of breaking the Sabbath by picking grain and by healing a "
         "man's hand (6:1-2,6-7)."),
        ("Man with a withered hand",
         "Healed by Jesus in the synagogue despite his critics watching for a reason to accuse him "
         "(6:6-10)."),
        ("Disciples and crowds",
         "Hear Jesus' sermon of blessings for the poor and hungry, warnings to the rich, and the call "
         "to love enemies and build a life on his words (6:17-49)."),
    ],
    7: [
        ("Jesus",
         "Heals a centurion's servant, raises a widow's son at Nain, answers John the Baptist's "
         "questions from prison, and forgives a sinful woman's many sins at a Pharisee's table "
         "(7:1-50)."),
        ("Centurion",
         "A Roman officer whose trust that Jesus can heal his servant with only a word leads Jesus to "
         "marvel at faith he has not found even in Israel (7:1-10)."),
        ("Widow of Nain",
         "Her only son is raised by Jesus from his own funeral procession, moving the crowd to praise "
         "God (7:11-17)."),
        ("John the Baptist",
         "Sends messengers from prison to ask whether Jesus is the promised one, and is praised by "
         "Jesus as more than a prophet once they leave (7:18-28)."),
        ("Simon the Pharisee",
         "Invites Jesus to dinner, privately doubts he is a prophet for letting a sinful woman touch "
         "him, and is told the parable of two forgiven debtors in response (7:36-43)."),
        ("Woman known as a sinner",
         "Weeps at Jesus' feet, washes them with her tears and hair, and is told her many sins are "
         "forgiven because she loved much (7:37-48)."),
    ],
    8: [
        ("Jesus",
         "Teaches the sower parable, calms a storm, frees a man tormented by demons, heals a bleeding "
         "woman, and raises Jairus's daughter (8:1-56)."),
        ("The Twelve",
         "Travel with Jesus and the women supporting his ministry, and are present through the storm, "
         "the Gerasene healing, and Jairus's house (8:1,22-25)."),
        ("Mary Magdalene, Joanna and Susanna",
         "Women who travel with Jesus and support his ministry out of their own resources (8:1-3)."),
        ("The possessed man",
         "Freed by Jesus from many demons calling themselves Legion, then sent home to tell what God "
         "has done for him instead of staying with Jesus (8:26-39)."),
        ("Jairus and his daughter",
         "Jairus begs Jesus to heal his dying twelve-year-old daughter, and after she is reported "
         "dead Jesus takes her by the hand and raises her (8:41-42,49-56)."),
        ("Woman with bleeding",
         "Touches Jesus' garment after twelve years of illness, is healed instantly, and is called "
         "out publicly to confess what happened (8:43-48)."),
    ],
    9: [
        ("Jesus",
         "Commissions the Twelve, feeds five thousand, is transfigured, heals a boy the disciples "
         "could not help, and sets his face toward Jerusalem (9:1-62)."),
        ("The Twelve",
         "Are sent out to preach and heal, witness the feeding of five thousand, and argue among "
         "themselves about who is greatest (9:1-17,46)."),
        ("Peter",
         "Confesses that Jesus is God's Messiah and witnesses the transfiguration alongside James and "
         "John (9:20,28-33)."),
        ("Moses and Elijah",
         "Appear with Jesus at the transfiguration, speaking with him about his coming death in "
         "Jerusalem (9:30-31)."),
        ("James and John",
         "Witness the transfiguration with Peter and later ask Jesus to call down fire on a "
         "Samaritan village that refused to welcome him (9:28,54)."),
        ("Boy and father",
         "The father begs Jesus to heal his son after the disciples could not, and Jesus casts out "
         "the spirit and gives the boy back to him (9:38-42)."),
    ],
    10: [
        ("Jesus",
         "Sends out seventy or seventy-two messengers, answers a legal expert's question with the "
         "parable of the compassionate Samaritan, and commends Mary for listening at his feet "
         "(10:1-42)."),
        ("Seventy or seventy-two disciples",
         "Sent out ahead of Jesus in pairs and return rejoicing that even demons obeyed them in his "
         "name (10:1,17)."),
        ("Legal expert",
         "Asks Jesus what he must do to inherit eternal life and then, trying to justify himself, "
         "asks who counts as his neighbor (10:25-29)."),
        ("Samaritan",
         "A fictional traveler in Jesus' parable who stops to help a wounded stranger when a priest "
         "and a Levite both pass by, becoming the story's example of a true neighbor (10:30-37)."),
        ("Martha",
         "Welcomes Jesus into her home and complains that her sister has left her to do all the "
         "serving alone (10:38-40)."),
        ("Mary",
         "Sits at Jesus' feet listening instead of helping her sister Martha serve, and is told she "
         "has chosen the better part (10:39,42)."),
    ],
    11: [
        ("Jesus",
         "Teaches the Lord's Prayer, answers an accusation that he casts out demons by Beelzebul, and "
         "denounces Pharisees and legal experts for neglecting justice while loading others with "
         "burdens (11:1-54)."),
        ("Disciples",
         "Ask Jesus to teach them to pray as John taught his own disciples (11:1)."),
        ("Accusers in the crowd",
         "Claim Jesus casts out demons by Beelzebul, prompting his answer that a divided kingdom "
         "cannot stand (11:15)."),
        ("Pharisee host",
         "Invites Jesus to a meal and is surprised that he does not wash before eating, drawing "
         "Jesus' rebuke of outward religious display (11:37-39)."),
        ("Pharisees and legal experts",
         "Receive Jesus' series of woes for tithing herbs while neglecting justice, and for locking "
         "away the key of knowledge (11:42-52)."),
        ("Jonah and queen of the South",
         "Figures from Israel's own Scriptures Jesus cites as examples who responded to far less "
         "revelation than the crowd before him now has (11:29-32)."),
    ],
    12: [
        ("Jesus",
         "Warns his disciples against hypocrisy, tells the parable of the rich fool, teaches trust "
         "over anxiety, and calls for readiness like servants awaiting their master (12:1-59)."),
        ("Disciples",
         "Are warned not to fear those who can only kill the body and are assured that God cares for "
         "them more than for sparrows (12:4-7)."),
        ("Man requesting inheritance division",
         "Asks Jesus to make his brother divide their inheritance, prompting the parable of the rich "
         "fool instead (12:13-14)."),
        ("Rich fool",
         "A fictional farmer in Jesus' parable who plans bigger barns the same night his life is "
         "required of him, illustrating the danger of storing up wealth without regard for God "
         "(12:16-21)."),
        ("Servants and master",
         "Fictional figures in Jesus' parables about readiness, where faithful servants are rewarded "
         "and one entrusted with much is held to a stricter account (12:35-48)."),
        ("Crowds",
         "Hear Jesus call them to discern the present time the way they already read the weather, "
         "and to settle disputes before they escalate (12:54-59)."),
    ],
    13: [
        ("Jesus",
         "Calls everyone to repent rather than judge recent tragedy victims as worse sinners, heals a "
         "bent woman on the Sabbath, and laments over Jerusalem on his way there (13:1-35)."),
        ("Galileans killed by Pilate and Siloam victims",
         "Recent tragedy victims people cite to Jesus, who turns their deaths into a call for "
         "everyone's own repentance rather than a judgment on the victims (13:1-5)."),
        ("Woman bent for eighteen years",
         "Healed by Jesus on the Sabbath and immediately stands up straight to praise God "
         "(13:11-13)."),
        ("Synagogue leader",
         "Objects to Jesus healing on the Sabbath, only to be answered that even animals are untied "
         "and watered on that day (13:14-16)."),
        ("Herod",
         "Reported to want Jesus dead, prompting Jesus to call him \"that fox\" and insist he will "
         "finish his work regardless (13:31-32)."),
        ("Jerusalem",
         "The city Jesus addresses directly in his closing lament over its history of killing the "
         "prophets sent to it (13:34-35)."),
    ],
    14: [
        ("Jesus",
         "Heals a man with dropsy at a Sabbath meal, teaches humility and hospitality toward people "
         "who cannot repay it, and warns crowds to count the cost of following him (14:1-35)."),
        ("Pharisee leader",
         "Hosts the Sabbath meal where Jesus heals and teaches, watching him closely throughout "
         "(14:1)."),
        ("Man with dropsy (swelling)",
         "Healed by Jesus at the Pharisee leader's table despite the Sabbath (14:2-4)."),
        ("Guests and host",
         "Hear Jesus teach that grabbing the seat of honor risks public humiliation, while inviting "
         "people who cannot repay brings a different kind of reward (14:7-14)."),
        ("Invited guests and host in the banquet",
         "Fictional figures in Jesus' parable of the great supper, where the first invited guests "
         "make excuses and the host fills his table with the poor and overlooked instead (14:16-24)."),
        ("Crowds",
         "Warned by Jesus that following him requires carrying a cross and counting the cost the way "
         "a builder or a king would before committing (14:25-33)."),
    ],
    15: [
        ("Jesus",
         "Tells three parables of a lost sheep, a lost coin, and a lost son to answer why he welcomes "
         "sinners and eats with them (15:1-32)."),
        ("Tax collectors and sinners",
         "Draw near to hear Jesus, prompting the religious leaders' complaint that leads to his three "
         "parables (15:1)."),
        ("Pharisees and scribes",
         "Complain that Jesus welcomes sinners and eats with them, the criticism his three parables "
         "directly answer (15:2)."),
        ("Shepherd and woman",
         "Fictional searchers in Jesus' parables who leave everything to find one lost sheep or one "
         "lost coin and then celebrate with their neighbors (15:4-9)."),
        ("Father, younger son, older son",
         "A fictional family in which a father runs to welcome home a son who wasted his inheritance, "
         "while the older son refuses to join the celebration (15:11-32)."),
    ],
    16: [
        ("Jesus",
         "Tells the parable of the shrewd manager, warns that no one can serve both God and wealth, "
         "and tells of the rich man and Lazarus (16:1-31)."),
        ("Manager and rich employer",
         "Fictional figures in Jesus' parable in which a manager facing dismissal reduces others' "
         "debts to secure his own future (16:1-8)."),
        ("Pharisees",
         "Ridicule Jesus' teaching about money because they love it themselves, drawing his warning "
         "that what people value highly can be detestable to God (16:14-15)."),
        ("Rich man and Lazarus",
         "Figures in Jesus' account of a rich man who ignores the suffering beggar at his own gate, "
         "only to have their situations completely reversed after death (16:19-23)."),
        ("Abraham",
         "Speaks to the rich man in the afterlife, explaining that a great gulf now separates them "
         "and that his brothers already have Moses and the prophets to warn them (16:24-31)."),
    ],
    17: [
        ("Jesus",
         "Warns against causing others to stumble, heals ten people with a skin disease, and teaches "
         "that the kingdom's arrival and his own coming will be sudden (17:1-37)."),
        ("Apostles",
         "Ask Jesus to increase their faith, and are told that faith as small as a mustard seed is "
         "already enough (17:5-6)."),
        ("Ten people with skin disease",
         "Call out to Jesus for mercy and are healed as they go to show themselves to the priests "
         "(17:12-14)."),
        ("Samaritan man",
         "The only one of the ten healed who returns to thank Jesus, making the outsider the story's "
         "one example of gratitude (17:15-16)."),
        ("Pharisees",
         "Ask Jesus when the kingdom of God will come, and are told it is already in their midst "
         "rather than a spectacle to watch for (17:20-21)."),
        ("Noah and Lot",
         "Figures from Israel's own history Jesus cites as examples of sudden judgment arriving while "
         "ordinary life went on unaware (17:26-30)."),
    ],
    18: [
        ("Jesus",
         "Tells parables on persistent prayer and humble prayer, welcomes children, calls a wealthy "
         "ruler to sell his possessions, and heals a blind beggar near Jericho (18:1-43)."),
        ("Widow and unjust judge",
         "Fictional figures in Jesus' parable in which a persistent widow wears down an unjust judge "
         "simply by refusing to give up (18:2-5)."),
        ("Pharisee and tax collector",
         "Fictional worshippers in Jesus' comparison, where the Pharisee prays about his own "
         "righteousness and the tax collector simply begs for mercy (18:10-13)."),
        ("Children and caregivers",
         "Brought to Jesus for a blessing, and he rebukes the disciples who try to turn them away "
         "(18:15-16)."),
        ("Wealthy ruler",
         "Asks Jesus what he must do to inherit eternal life, then goes away sad rather than sell his "
         "great possessions (18:18,23)."),
        ("Blind beggar near Jericho",
         "Calls out to Jesus despite the crowd's rebuke and receives his sight for his faith "
         "(18:35-43)."),
    ],
    19: [
        ("Jesus",
         "Calls Zacchaeus down from a tree, tells the parable of the nobleman's entrusted money, "
         "enters Jerusalem weeping over it, and drives sellers from the temple (19:1-48)."),
        ("Zacchaeus",
         "A chief tax collector who climbs a tree to see Jesus, welcomes him joyfully, and pledges to "
         "repay everyone he has cheated four times over (19:2-8)."),
        ("Crowd and disciples",
         "Grumble that Jesus is staying with a sinner in Zacchaeus's house, then spread cloaks on the "
         "road and praise God as Jesus enters Jerusalem (19:7,36-37)."),
        ("Nobleman, servants and citizens",
         "Fictional figures in Jesus' parable about a nobleman who rewards servants who invested what "
         "he gave them and judges the citizens who rejected his rule (19:12-27)."),
        ("Temple merchants",
         "Buyers and sellers driven out of the temple courts by Jesus, who insists the temple was "
         "meant to be a house of prayer (19:45-46)."),
        ("Religious leaders",
         "Look for a way to destroy Jesus but cannot find one, since the people hang on his every "
         "word in the temple (19:47-48)."),
    ],
    20: [
        ("Jesus",
         "Is challenged over his authority, tells the parable of the wicked tenants, answers trap "
         "questions about taxes and resurrection, and warns against scribes who exploit widows "
         "(20:1-47)."),
        ("Chief priests, scribes and elders",
         "Challenge Jesus' authority in the temple, recognize themselves in his parable of the wicked "
         "tenants, and are warned by him for exploiting widows while seeking honor (20:1-19,45-47)."),
        ("Tenant farmers, owner and son",
         "Fictional figures in Jesus' parable in which renters beat the owner's servants and kill his "
         "son, a story the leaders recognize is told against them (20:9-16)."),
        ("Spies",
         "Sent to trap Jesus into saying something treasonous about paying tribute to Caesar "
         "(20:20-22)."),
        ("Sadducees",
         "Challenge belief in the resurrection with a hypothetical widow married to seven brothers, "
         "and are told they misunderstand both Scripture and God's power (20:27-38)."),
        ("David",
         "The scriptural king Jesus cites as calling the Messiah his Lord, questioning the assumption "
         "that the Messiah is merely David's son (20:41-44)."),
    ],
    21: [
        ("Jesus",
         "Praises a poor widow's offering, predicts the temple's destruction, and warns of "
         "persecution and cosmic upheaval while urging watchful hope (21:1-36)."),
        ("Poor widow",
         "Gives two small coins to the temple treasury, a gift Jesus says is greater than all the "
         "wealthy's large contributions (21:1-4)."),
        ("Disciples and hearers",
         "Ask Jesus when the temple will be destroyed and what sign will mark it, receiving his long "
         "discourse on persecution and the end in response (21:7)."),
        ("False claimants",
         "Predicted figures who will come claiming Jesus' own identity and saying the time is near, "
         "whom Jesus warns his followers not to follow (21:8)."),
        ("Jerusalem's inhabitants",
         "Described by Jesus as facing a coming siege and distress once the city is surrounded by "
         "armies (21:20-24)."),
    ],
    22: [
        ("Jesus",
         "Shares a final Passover meal reinterpreting its bread and cup around his own body and "
         "covenant, prays in anguish on the Mount of Olives, and is arrested and questioned before "
         "the council (22:1-71)."),
        ("Judas Iscariot",
         "A member of the Twelve who arranges to betray Jesus for money and identifies him with a "
         "kiss when the armed crowd arrives (22:3-6,47-48)."),
        ("Peter",
         "Is warned that Satan desires to sift him, insists he is ready to die with Jesus, and then "
         "denies knowing him three times before the rooster crows (22:31-34,54-62)."),
        ("The apostles",
         "Share the Passover meal, argue about who is greatest even as Jesus speaks of his coming "
         "death, and fall asleep at Gethsemane instead of praying with him (22:14,24,45)."),
        ("High priest's servant",
         "Has his ear cut off by one of the apostles during Jesus' arrest, and Jesus heals him on the "
         "spot (22:50-51)."),
        ("Chief priests and elders",
         "Arrive with the armed crowd to arrest Jesus and later question him before the council, "
         "where he is condemned for his own testimony (22:52,66-71)."),
    ],
    23: [
        ("Jesus",
         "Is questioned by Pilate and Herod Antipas without either finding real fault in him, is "
         "crucified between two criminals, and dies as the temple curtain tears in two (23:1-49)."),
        ("Pilate",
         "Finds no fault in Jesus three times, sends him to Herod Antipas, and finally yields to the "
         "crowd's demand, releasing the rebel Barabbas and ordering Jesus crucified (23:4,7,13-25)."),
        ("Herod Antipas",
         "Hopes to see Jesus perform a miracle, mocks him with his soldiers when Jesus stays silent, "
         "and sends him back to Pilate, becoming Pilate's friend that same day (23:7-12)."),
        ("Simon of Cyrene",
         "Is made to carry the cross behind Jesus on the way to the execution (23:26)."),
        ("Two condemned criminals",
         "Crucified on either side of Jesus; one mocks him while the other asks to be remembered and "
         "is promised paradise (23:32-33,39-43)."),
        ("Joseph of Arimathea and the women from Galilee",
         "Joseph, a council member who had not agreed with the decision against Jesus, asks for his "
         "body and lays it in a new tomb, while the women who had followed Jesus watch and then "
         "prepare spices (23:50-56)."),
    ],
    24: [
        ("Jesus",
         "Is found risen from the tomb, walks unrecognized with two disciples to Emmaus, and appears "
         "to the gathered disciples before being carried up to heaven (24:1-53)."),
        ("Women at the tomb",
         "Include Mary Magdalene, Joanna, Mary the mother of James, and others who find the tomb "
         "empty and are the first to hear that Jesus has risen (24:1-10)."),
        ("Peter",
         "Runs to the tomb after hearing the women's report and goes home wondering at what he sees "
         "(24:12)."),
        ("Cleopas and his companion",
         "Two disciples walking to Emmaus who are joined by the risen Jesus without recognizing him "
         "until he breaks bread at their table (24:13-31)."),
        ("The Eleven and companions",
         "Dismiss the women's report as idle tales, then receive the risen Jesus' appearance and his "
         "opening of their understanding of Scripture (24:11,36-45)."),
        ("Two radiant men",
         "Appear at the empty tomb to announce to the women that Jesus has risen just as he said he "
         "would (24:4-7)."),
    ],
}

THEMES = {
    1: {
        "God's promises and preparation":
            "Gabriel announces that Elizabeth's son John will prepare the way for the Lord, "
            "fulfilling Israel's long-held hope that God would act decisively through a chosen "
            "forerunner (1:5-17,67-79).",
        "Humble trust and questioning":
            "Zechariah doubts Gabriel's announcement and is struck silent, while Mary accepts an "
            "even more startling announcement with simple trust, pairing two very different "
            "responses to the same kind of impossible news (1:18-20,34-38).",
        "Reversal and mercy":
            "Mary's song praises a God who scatters the proud, lifts up the lowly, and fills the "
            "hungry, framing Jesus' coming birth as part of a larger pattern of reversal (1:46-55).",
        "Witness and praise":
            "John's birth restores Zechariah's speech, and his prophecy over the child links John's "
            "role as forerunner to God's larger promise of light and peace (1:57-66,76-80).",
    },
    2: {
        "Good news for the lowly":
            "Angels announce Jesus' birth first to shepherds, ordinary working people rather than "
            "rulers or priests, matching Luke's pattern of good news reaching the overlooked "
            "(2:8-20).",
        "Faithful observance":
            "Joseph and Mary follow the law's requirements for circumcision and purification "
            "exactly, presenting Jesus at the temple like any other Jewish family would "
            "(2:21-24,39-42).",
        "Hope extending to the nations":
            "Simeon calls the infant Jesus a light to the Gentiles as well as the glory of Israel, "
            "extending Israel's hope beyond Israel itself from the very start (2:25-35).",
        "Growing in wisdom":
            "At twelve, Jesus startles the temple teachers with his understanding and tells his "
            "worried parents he must be about his Father's business, foreshadowing his identity "
            "before his public ministry begins (2:46-52).",
    },
    3: {
        "Repentance has practical fruit":
            "John tells crowds, tax collectors, and soldiers that real repentance means sharing what "
            "they have and refusing to exploit others, not just feeling sorry (3:7-14).",
        "Messianic expectation":
            "John denies being the Christ himself and points instead to one far mightier who is "
            "coming, redirecting the crowd's hope away from himself (3:15-18).",
        "Jesus' baptism and identity":
            "As Jesus is baptized, the Spirit descends and a voice from heaven names him God's "
            "beloved Son, publicly confirming his identity before his ministry begins (3:21-22).",
        "Human solidarity in the genealogy":
            "Luke traces Jesus' ancestry all the way back to Adam, tying Jesus to the whole human "
            "family rather than stopping at Abraham as Matthew's genealogy does (3:23-38).",
    },
    4: {
        "Testing and faithfulness":
            "The devil tempts Jesus three times in the wilderness, and each time Jesus answers with "
            "Scripture rather than his own reasoning (4:1-13).",
        "Good news and reversal":
            "Reading from Isaiah in the Nazareth synagogue, Jesus announces that the Scripture's "
            "promise of good news to the poor and freedom to the oppressed is fulfilled that very "
            "day, in him (4:16-21).",
        "Prophetic rejection":
            "The same congregation that first marvels at Jesus turns furious when he reminds them "
            "that God once sent his prophets to help foreigners ahead of Israel's own people "
            "(4:22-30).",
        "Authority with compassion":
            "In Capernaum Jesus teaches with authority that amazes people, casts out an unclean "
            "spirit with a word, and heals Simon's mother-in-law and many others who are brought to "
            "him (4:31-44).",
    },
    5: {
        "Discipleship and response":
            "A miraculous catch of fish convinces Simon, James, and John to leave their boats, and "
            "Levi leaves his tax booth just as quickly once Jesus calls him (5:1-11,27-28).",
        "Healing and forgiveness":
            "Jesus cleanses a man with a skin disease and forgives and heals a paralyzed man, "
            "pairing physical healing with the deeper claim that he has authority to forgive sins "
            "(5:12-26).",
        "Fellowship with outsiders":
            "Jesus eats with tax collectors and sinners and tells critics that he came to call "
            "sinners to repentance, not people who already consider themselves righteous (5:29-32).",
        "Newness and old patterns":
            "Jesus compares his new teaching to new wine that cannot be poured into old wineskins, "
            "explaining why his disciples do not fast the way John's disciples or the Pharisees do "
            "(5:33-39).",
    },
    6: {
        "Sabbath and doing good":
            "When Pharisees object to the disciples picking grain and to a Sabbath healing, Jesus "
            "asks whether the Sabbath is for doing good or doing harm, not simply following rules "
            "(6:1-11).",
        "Kingdom reversal":
            "Jesus blesses the poor, hungry, and weeping while warning the rich, full, and laughing, "
            "turning ordinary ideas of who is fortunate completely upside down (6:20-26).",
        "Love of enemies":
            "Jesus tells his disciples to love their enemies, do good to those who hate them, and "
            "give without expecting anything back, matching the mercy of their own Father (6:27-36).",
        "Hearing and doing":
            "Jesus warns that calling him Lord means nothing without obeying him, comparing a life "
            "built on his words to a house built on solid rock (6:43-49).",
    },
    7: {
        "Faith and authority":
            "A Roman centurion trusts that Jesus can heal his servant with only a word, and Jesus "
            "marvels that he has not found faith like this even in Israel (7:1-10).",
        "Compassion for the vulnerable":
            "Moved with compassion for a widow who has just lost her only son, Jesus raises the "
            "young man from his own funeral procession without even being asked (7:11-17).",
        "Recognizing God's work":
            "When John's own disciples ask whether Jesus is the one who was promised, Jesus points "
            "to the healings and good news happening right in front of them as the answer "
            "(7:18-35).",
        "Forgiveness and love":
            "A woman known as a sinner weeps at Jesus' feet and is forgiven much, and Jesus tells his "
            "host that the one who is forgiven much loves much in return (7:36-50).",
    },
    8: {
        "Hearing that bears fruit":
            "The parable of the sower pictures different hearers as different kinds of soil, warning "
            "that hearing God's word is not the same as letting it actually take root (8:4-18).",
        "New family defined by obedience":
            "When told his mother and brothers are outside, Jesus says his true family is whoever "
            "hears God's word and does it, redefining kinship around obedience rather than blood "
            "(8:19-21).",
        "Faith amid fear":
            "Jesus calms a storm that terrifies the disciples and later tells a frightened Jairus not "
            "to fear but only to believe, pairing both moments as lessons in trusting him under "
            "pressure (8:22-25,40-56).",
        "Restoration and witness":
            "Once freed from the many demons controlling him, the man from the Gerasene region is "
            "sent home to tell everyone what God has done for him, becoming a witness instead of an "
            "outcast (8:26-39).",
    },
    9: {
        "Mission and dependence":
            "Jesus sends the Twelve out to preach and heal while taking nothing for the journey, "
            "teaching them to depend on the hospitality of those they serve (9:1-6).",
        "Messiahship and suffering":
            "Peter rightly calls Jesus God's Messiah, but Jesus immediately redefines that title "
            "around coming suffering, death, and a cross every follower must also carry (9:18-27).",
        "Listen to Jesus":
            "At the transfiguration, a voice from the cloud names Jesus God's Son and commands the "
            "disciples simply to listen to him, even with Moses and Elijah standing right beside him "
            "(9:28-36).",
        "Discipleship without rivalry":
            "The disciples argue about who is greatest and want to call down fire on an unwelcoming "
            "village, and Jesus answers both with lessons in humility rather than rivalry or "
            "retaliation (9:46-56).",
    },
    10: {
        "Mission and hospitality":
            "Jesus sends seventy or seventy-two messengers ahead of him in pairs, warning them of "
            "rejection but relying on whatever household welcomes them to receive their message "
            "(10:1-12).",
        "Joy with proper focus":
            "When the seventy return thrilled that demons obeyed them, Jesus redirects their joy "
            "toward the far greater fact that their names are written in heaven (10:17-24).",
        "Neighbor-love across boundaries":
            "Asked who counts as a neighbor, Jesus answers with a despised Samaritan who stops to "
            "help a wounded stranger when a priest and a Levite both pass by (10:25-37).",
        "Listening and service":
            "Martha is busy serving while Mary sits listening at Jesus' feet, and Jesus says Mary has "
            "chosen the one thing that is truly needed (10:38-42).",
    },
    11: {
        "Prayer and reliance":
            "Jesus teaches the Lord's Prayer and promises that God gives good gifts, especially the "
            "Holy Spirit, to those who keep asking (11:1-13).",
        "Responding to revelation":
            "Accused of casting out demons by Beelzebul, Jesus answers that a divided kingdom cannot "
            "stand and warns that people who see God's work and still demand another sign have "
            "already missed the point (11:14-32).",
        "Integrity inside and out":
            "Jesus condemns Pharisees for cleaning the outside of the cup while their hearts stay "
            "full of greed, insisting that inner integrity matters more than outward display "
            "(11:33-44).",
        "Responsible teaching":
            "Jesus rebukes legal experts for loading people with burdens they themselves will not "
            "lift a finger to carry, and for locking away the very knowledge they were meant to "
            "share (11:45-54).",
    },
    12: {
        "Against hypocrisy":
            "Jesus warns his disciples against the hidden hypocrisy of the Pharisees, promising that "
            "everything covered up will eventually be made known (12:1-12).",
        "Wealth and mortality":
            "Asked to settle an inheritance dispute, Jesus instead tells of a rich man who plans "
            "bigger barns the same night his life is required of him, warning that life does not "
            "consist of possessions (12:13-21).",
        "Trust and generosity":
            "Jesus tells his disciples not to worry about food or clothing, since the God who feeds "
            "ravens and clothes lilies can be trusted to provide for them too (12:22-34).",
        "Readiness and responsibility":
            "Jesus compares faithful disciples to servants who keep watch for their master's return, "
            "warning that the one entrusted with more will be held to a stricter account (12:35-48).",
    },
    13: {
        "Suffering is not a simple moral score":
            "Jesus rejects the idea that people killed by Pilate or by a falling tower were worse "
            "sinners than anyone else, turning the question back into a call for everyone to repent "
            "(13:1-5).",
        "Urgency of repentance":
            "The parable of the barren fig tree warns that patience for change has a limit, even "
            "when a gardener pleads for one more year (13:6-9).",
        "Healing and Sabbath dignity":
            "Jesus heals a woman bent over for eighteen years on the Sabbath and asks whether this "
            "daughter of Abraham deserves less consideration than an ox led to water (13:10-17).",
        "Kingdom growth and response":
            "The mustard seed and leaven picture a kingdom that starts small, while Jesus warns that "
            "many who expect to enter it by birthright will instead find the door shut (13:18-30).",
    },
    14: {
        "Mercy above status disputes":
            "Jesus heals a man with dropsy on the Sabbath and asks the watching lawyers and "
            "Pharisees whether mercy can ever really wait for a more convenient day (14:1-6).",
        "Humility at the table":
            "Watching guests grab the places of honor, Jesus teaches that whoever exalts himself "
            "will be humbled, and whoever humbles himself will be exalted (14:7-11).",
        "Hospitality without repayment":
            "Jesus tells his host to invite the poor and disabled instead of people who can repay "
            "the invitation, then pictures a great banquet filled with exactly those kinds of guests "
            "after the invited ones make excuses (14:12-24).",
        "Counting the cost":
            "Jesus warns large crowds that following him means carrying a cross, and compares the "
            "decision to a builder or a king who first counts whether they have enough to finish "
            "what they start (14:25-35).",
    },
    15: {
        "Seeking the lost":
            "A shepherd leaves ninety-nine sheep to search for one lost sheep, and a woman sweeps "
            "her whole house for one lost coin, both searching as if the one missing piece mattered "
            "most (15:3-10).",
        "Repentance and celebration":
            "Jesus says heaven rejoices more over one repentant sinner than over many who never felt "
            "they needed to return, the same point both the lost sheep and lost coin make (15:7-10).",
        "Compassion and reconciliation":
            "A father runs to meet his returning son before the son can even finish his rehearsed "
            "apology, celebrating a reunion the son himself assumed was impossible (15:11-24).",
        "Resentment at grace":
            "The older brother refuses to join the celebration for his returned brother, and the "
            "parable ends without saying whether he ever goes in, leaving the question open for "
            "Jesus' own critics (15:25-32).",
    },
    16: {
        "Wise stewardship":
            "A dismissed manager secures his own future by reducing what others owe his master, and "
            "Jesus uses his shrewdness, not his dishonesty, as the lesson for handling money wisely "
            "(16:1-13).",
        "God and money":
            "Jesus tells money-loving Pharisees that no one can serve both God and wealth, since "
            "loyalty to one will eventually crowd out the other (16:10-15).",
        "Attention to neglected neighbors":
            "A rich man feasts every day while the poor man Lazarus lies at his very gate, and after "
            "death their situations are completely and permanently reversed (16:19-26).",
        "Responding to Scripture":
            "Abraham tells the rich man that if his brothers will not listen to Moses and the "
            "prophets, nothing, not even someone rising from the dead, will persuade them either "
            "(16:27-31).",
    },
    17: {
        "Forgiveness and care":
            "Jesus warns against causing others to stumble and commands forgiving a repentant person "
            "again and again, even seven times in one day (17:1-4).",
        "Faith without self-congratulation":
            "Jesus says a servant who only does his duty deserves no special thanks, teaching that "
            "even great faith is simply what disciples owe, not a reason for pride (17:5-10).",
        "Gratitude across boundaries":
            "Of ten people healed of a skin disease, only the Samaritan comes back to thank Jesus, "
            "making the outsider the one example of real gratitude in the story (17:11-19).",
        "Discernment and readiness":
            "Jesus says the kingdom of God is already in their midst, not a spectacle to go chasing "
            "after, and warns that his own coming will be as sudden and inescapable as the flood in "
            "Noah's day (17:20-37).",
    },
    18: {
        "Persist in prayer and justice":
            "A persistent widow wears down an unjust judge simply by refusing to stop asking, and "
            "Jesus says God will surely answer his own people who cry out day and night (18:1-8).",
        "Humility before God":
            "A Pharisee thanks God for his own righteousness while a tax collector simply begs for "
            "mercy, and Jesus says the tax collector, not the Pharisee, goes home right with God "
            "(18:9-14).",
        "Receiving the kingdom":
            "Jesus welcomes children the disciples try to turn away, saying God's kingdom belongs to "
            "whoever receives it as simply as a child does (18:15-17).",
        "Possessions and discipleship":
            "A wealthy ruler goes away sad rather than sell his possessions, and Jesus says what is "
            "impossible for people to do on their own, God can still accomplish (18:18-30).",
    },
    19: {
        "Restoration and restitution":
            "Zacchaeus climbs a tree just to see Jesus and ends up pledging to repay everyone he has "
            "cheated four times over, prompting Jesus to say that salvation has come to his house "
            "(19:1-10).",
        "Accountability in entrusted matters":
            "A nobleman's servants are rewarded or rebuked based on what they did with the money "
            "entrusted to them while he was away, a picture of accountability for the time before "
            "Jesus returns (19:11-27).",
        "Peace and missed opportunity":
            "As Jesus approaches Jerusalem he weeps over it, warning that the city failed to "
            "recognize the things that would have brought it peace (19:28-44).",
        "Temple purpose and protest":
            "Jesus drives sellers from the temple, insisting it was meant to be a house of prayer "
            "rather than a marketplace, and then teaches there despite the leaders' anger "
            "(19:45-48).",
    },
    20: {
        "Authority and accountability":
            "When leaders demand to know Jesus' authority, his parable of tenants who kill the "
            "owner's son answers by exposing exactly what they themselves are doing to him "
            "(20:1-19).",
        "Civil power and divine claims":
            "Asked whether paying tax to Caesar is lawful, Jesus says to give Caesar what is "
            "Caesar's and God what is God's, refusing to let the question trap him into taking only "
            "one side (20:20-26).",
        "Hope of resurrection":
            "Sadducees try to make resurrection sound absurd with a hypothetical widow, but Jesus "
            "answers that God is not a God of the dead but of the living, since all live to him "
            "(20:27-40).",
        "Warning about exploitation":
            "Jesus warns against scribes who make a show of long prayers while exploiting widows, "
            "pairing their outward religion with real harm done to the vulnerable (20:45-47).",
    },
    21: {
        "Generosity and vulnerability":
            "A poor widow's two small coins outweigh the large gifts of the wealthy in Jesus' eyes, "
            "since she gave everything she had to live on (21:1-4).",
        "Temple's impermanence":
            "Jesus predicts that the temple's impressive stones will be thrown down, a destruction "
            "his own first readers had likely already seen happen (21:5-11).",
        "Perseverance under pressure":
            "Jesus promises that even persecution and betrayal will become an opportunity for "
            "testimony, and that not a hair of their heads will finally perish (21:12-19).",
        "Watchful hope":
            "Jesus describes Jerusalem surrounded by armies and the sky itself in upheaval, yet "
            "tells his followers to lift up their heads, since their redemption is drawing near "
            "(21:20-36).",
    },
    22: {
        "Covenant and remembrance":
            "At the Passover table Jesus calls the bread his body and the cup the new covenant in "
            "his blood, giving his disciples a meal to remember him by (22:14-20).",
        "Greatness through service":
            "When the disciples dispute who is greatest, Jesus says the one who leads must be like "
            "the one who serves, pointing to his own example at the table (22:24-30).",
        "Prayer amid trial":
            "In Gethsemane Jesus prays so intensely that his sweat falls like drops of blood, "
            "submitting to God's will even while wishing the coming suffering could pass (22:39-46).",
        "Human failure and mercy":
            "Peter denies Jesus three times just as predicted, and the Lord's own silent look after "
            "the rooster crows is enough to send him out weeping bitterly (22:54-62).",
    },
    23: {
        "Injustice and political pressure":
            "Pilate finds no fault in Jesus three times over but still yields to the crowd's demand, "
            "releasing a convicted rebel and murderer in his place (23:1-25).",
        "Compassion amid suffering":
            "On the way to his own execution Jesus tells weeping women to weep for themselves "
            "instead, and from the cross he promises paradise to a criminal who simply asks to be "
            "remembered (23:26-43).",
        "Jesus' death and witnesses":
            "Darkness covers the land and the temple curtain tears as Jesus dies, and even a Roman "
            "centurion is moved to call him a righteous man (23:44-49).",
        "Careful burial and preparation":
            "Joseph of Arimathea, a council member who had not agreed with the decision against "
            "Jesus, provides a new tomb, while the women who watched prepare spices before resting "
            "on the Sabbath (23:50-56).",
    },
    24: {
        "Witness and initial doubt":
            "The women's report of an empty tomb and a risen Jesus strikes the apostles as idle "
            "talk, though Peter still runs to check for himself (24:1-12).",
        "Scripture and recognition":
            "Two disciples walk seven miles with the risen Jesus without recognizing him until he "
            "breaks bread at their table, the same moment that opens their eyes to who he is "
            "(24:13-35).",
        "Resurrection and commission":
            "Jesus shows the gathered disciples his hands and feet, eats before them to prove he is "
            "not a ghost, and opens their understanding of how the Scriptures pointed to his "
            "suffering and resurrection all along (24:36-49).",
        "Worship and hope":
            "Luke's Gospel ends not in grief but in worship, as the disciples return to Jerusalem "
            "with great joy to wait for the power Jesus promised (24:50-53).",
    },
}


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "42_luke.json"
    data = load(path)
    for n in range(1, 25):
        key = f"Luke {n}"
        entry = data[key]
        entry["whereWeAre"] = WWA[n]
        entry["keyFigures"] = [{"name": name, "role": role} for name, role in KEY_FIGURES[n]]
        theme_map = THEMES[n]
        seen = set()
        for theme in entry["keyThemes"]:
            name = theme["theme"]
            if name not in theme_map:
                raise SystemExit(f"Luke {n}: no explanation drafted for theme {name!r}")
            theme["explanation"] = theme_map[name]
            seen.add(name)
        missing = set(theme_map) - seen
        if missing:
            raise SystemExit(f"Luke {n}: drafted themes not in source: {missing}")
        if len(entry["keyFigures"]) > 6:
            raise SystemExit(f"Luke {n}: {len(entry['keyFigures'])} key figures (max 6)")
        if len(entry["whereWeAre"]) > 600:
            raise SystemExit(f"Luke {n}: whereWeAre is {len(entry['whereWeAre'])} characters (max 600)")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


AUDIENCE_FIXES = {
    10: ("Readers who knew that Jews traveling the steep, bandit-plagued road from Jerusalem to "
         "Jericho normally expected a fellow Jew to help a wounded traveler, not a despised "
         "Samaritan, would have felt the full shock of Jesus making the Samaritan the story's hero."),
    11: ("Readers familiar with how often Pharisees criticized others for neglecting prayer would "
         "have recognized the disciples' own request to be taught to pray as deferring to Jesus as a "
         "teacher in his own right, the same authority on display moments later when he turns a "
         "dinner invitation into a public rebuke of his host's own circle."),
    14: ("Guests at any first-century banquet, where seating order openly ranked a person's status, "
         "would have felt how pointed it was for Jesus to tell his host to invite people who could "
         "never return the favor."),
    15: ("Readers who knew that Pharisees and scribes avoided table fellowship with those they "
         "considered irreligious would have recognized Jesus' three stories of search and "
         "celebration as a direct answer to their complaint, not simply three pleasant "
         "illustrations."),
    16: ("Readers who assumed that wealth signaled God's favor and poverty signaled God's disfavor "
         "would have felt the force of Abraham's reversal, in which the rich man begs from the poor "
         "man he once ignored at his own gate."),
    17: ("Readers who knew that Jews and Samaritans normally avoided each other would have "
         "recognized it as especially pointed that the one person who came back to thank Jesus was "
         "the outsider, not the nine who shared his own people's faith."),
    19: ("Readers who knew that tax collectors like Zacchaeus were widely regarded as collaborators "
         "profiting off their own neighbors would have felt the shock of Jesus inviting himself to "
         "such a man's house, and the force of Zacchaeus's own public pledge to repay what he had "
         "taken."),
    20: ("Readers who knew that chief priests, scribes, and Sadducees normally disagreed sharply "
         "with each other, especially over resurrection, would have recognized how unusual it was "
         "for all of them to take turns testing the same teacher in a single day."),
    21: ("Luke's first readers, who had very likely lived through or heard firsthand accounts of "
         "Jerusalem's actual destruction in AD 70, would have recognized Jesus' warning about the "
         "city being surrounded by armies as describing something they already knew had happened, "
         "not a vague future threat."),
    23: ("Readers who knew that Galilee and Judea were governed separately, each under its own ruler "
         "who rarely had reason to deal with the other, would have recognized Pilate's gesture of "
         "sending a Galilean prisoner to Herod, and the sudden friendship it produced, as a telling "
         "detail about how power accommodated itself rather than took responsibility."),
}


def apply_chapter_context():
    path = ROOT / "chapter_context" / "33_luke.json"
    data = load(path)
    for n, new_audience in AUDIENCE_FIXES.items():
        key = f"Luke {n}"
        old_audience = data[key]["audience"]
        data[key]["audience"] = new_audience
        if old_audience == new_audience:
            raise SystemExit(f"Luke {n}: audience fix made no change")
    for entry in data["Luke 2"]["culture"]:
        if entry["title"] == "The manger":
            entry["text"] = entry["text"].replace(
                "the ‘inn’ may mean a guest room.",
                "the \"inn\" may mean a guest room.",
            )
    for entry in data["Luke 22"]["culture"]:
        if entry["title"] == "Benefactors":
            entry["text"] = entry["text"].replace(
                "honored with the title ‘Benefactor’ in public inscriptions.",
                "honored with the title \"Benefactor\" in public inscriptions.",
            )
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


OVERVIEW_PRONOUN_FIXES = [
    ("Jesus is baptized, tempted, and announces His mission in Nazareth.",
     "Jesus is baptized, tempted, and announces his mission in Nazareth."),
    ("A fisherman called to follow Jesus, who later denies Him and is restored.",
     "A fisherman called to follow Jesus, who later denies him and is restored."),
    ("The Roman governor and the ruler of Galilee who examine Jesus at His trial.",
     "The Roman governor and the ruler of Galilee who examine Jesus at his trial."),
]


def apply_book_overview():
    path = ROOT / "book_overviews" / "07_gospels_acts.json"
    data = load(path)
    luke = data["Luke"]
    text = json.dumps(luke, ensure_ascii=False)
    for old, new in OVERVIEW_PRONOUN_FIXES:
        if old not in text:
            raise SystemExit(f"Luke overview: pronoun fix not found: {old!r}")
    luke["movements"][0]["description"] = luke["movements"][0]["description"].replace(
        *OVERVIEW_PRONOUN_FIXES[0])
    for figure in luke["keyFigures"]:
        if figure["name"] == "Peter":
            figure["description"] = figure["description"].replace(*OVERVIEW_PRONOUN_FIXES[1])
        if figure["name"] == "Pontius Pilate and Herod Antipas":
            figure["description"] = figure["description"].replace(*OVERVIEW_PRONOUN_FIXES[2])
    if luke["keyVerse"] != "Luke 2:11":
        raise SystemExit("Luke keyVerse has changed since review")
    luke["keyVerse"] = "Luke 19:10"
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_PRONOUN_FIXES = [
    ("is preparing salvation for His people.", "is preparing salvation for his people."),
    ("Jesus is baptized and tested, and His preaching and miracles begin attracting attention.",
     "Jesus is baptized and tested, and his preaching and miracles begin attracting attention."),
    ("Jesus heals, forgives, teaches through parables, and reveals His power while His disciples "
     "gradually recognize Him as the Christ.",
     "Jesus heals, forgives, teaches through parables, and reveals his power while his disciples "
     "gradually recognize him as the Christ."),
    ("As Jesus travels toward Jerusalem, He teaches the cost of discipleship,",
     "As Jesus travels toward Jerusalem, he teaches the cost of discipleship,"),
    ("Jesus enters Jerusalem, confronts corrupt worship, answers His opponents, and warns of coming "
     "destruction",
     "Jesus enters Jerusalem, confronts corrupt worship, answers his opponents, and warns of coming "
     "destruction"),
    ("As Passover approaches, Jesus prepares His disciples for His suffering, institutes the Lord's "
     "Supper,",
     "As Passover approaches, Jesus prepares his disciples for his suffering, institutes the Lord's "
     "Supper,"),
    ("Jesus is sentenced under Roman authority, forgives His enemies, promises paradise",
     "Jesus is sentenced under Roman authority, forgives his enemies, promises paradise"),
    ("appearances of the risen Jesus, and His ascension bring Luke's account to its conclusion.",
     "appearances of the risen Jesus, and his ascension bring Luke's account to its conclusion."),
    ("to present Him to the Lord.", "to present him to the Lord."),
    ("His parents discover He is not in their traveling group.",
     "his parents discover he is not in their traveling group."),
    ("they find Him in the temple, sitting among the teachers,",
     "they find him in the temple, sitting among the teachers,"),
    ("Everyone is amazed at His understanding.", "Everyone is amazed at his understanding."),
    ("worried sick, He answers,", "worried sick, he answers,"),
    ("He goes home and obeys them.", "he goes home and obeys them."),
    ("As He prays, heaven opens, and the Holy Ghost descends",
     "as he prays, heaven opens, and the Holy Ghost descends"),
    ("Luke then traces His family line all the way back",
     "Luke then traces his family line all the way back"),
    ("Then He returns to Galilee in the power of the Spirit.",
     "Then he returns to Galilee in the power of the Spirit."),
    ("In His hometown synagogue in Nazareth, He stands to read",
     "In his hometown synagogue in Nazareth, he stands to read"),
    ("He rolls up the scroll, sits down, and says,",
     "he rolls up the scroll, sits down, and says,"),
    ("At first they speak well of Him:", "At first they speak well of him:"),
    ("But when He reminds them that God once sent Elijah",
     "But when he reminds them that God once sent Elijah"),
    ("They drive Him to the edge of a cliff to throw Him off,",
     "They drive him to the edge of a cliff to throw him off,"),
    ("At sunset, people bring all their sick, and He lays His hands on every one of them.",
     "At sunset, people bring all their sick, and he lays his hands on every one of them."),
    ("When the crowd begs Him to stay, He says,",
     "When the crowd begs him to stay, he says,"),
    ("Simon, James, and John leave everything and follow Him.",
     "Simon, James, and John leave everything and follow him."),
    ("He calls Levi the tax collector, who throws a great feast for Him.",
     "he calls Levi the tax collector, who throws a great feast for him."),
    ("To critics He says, “I came not to call the righteous,",
     "To critics he says, “I came not to call the righteous,"),
    ("He explains that new wine needs new wineskins.",
     "he explains that new wine needs new wineskins."),
    ("When Pharisees watch to see if He will heal on the Sabbath, He asks,",
     "When Pharisees watch to see if he will heal on the Sabbath, he asks,"),
    ("In the morning, He chooses twelve apostles.", "In the morning, he chooses twelve apostles."),
    ("Then He stands on a level place and teaches a great crowd.",
     "Then he stands on a level place and teaches a great crowd."),
    ("He also warns, “But woe unto you that are rich!",
     "he also warns, “But woe unto you that are rich!"),
    ("He promises, “give, and it shall be given unto you;",
     "he promises, “give, and it shall be given unto you;"),
    ("He asks, “why beholdest thou the mote",
     "he asks, “why beholdest thou the mote"),
    ("He has compassion on her and says, “Weep not.”",
     "he has compassion on her and says, “Weep not.”"),
    ("He touches the coffin: “Young man,",
     "he touches the coffin: “Young man,"),
    ("Weeping, she washes His feet with her tears,",
     "Weeping, she washes his feet with her tears,"),
    ("if Jesus were a prophet, He would know what kind of woman she is.",
     "if Jesus were a prophet, he would know what kind of woman she is."),
    ("Then He says, “Her sins, which are many, are forgiven;",
     "Then he says, “Her sins, which are many, are forgiven;"),
    ("To her He says, “Thy faith hath saved thee;",
     "To her he says, “Thy faith hath saved thee;"),
    ("the twelve are with Him, along with women He had healed.",
     "the twelve are with him, along with women he had healed."),
    ("paying for His ministry from their own money.", "paying for his ministry from their own money."),
    ("He tells the parable of the sower.", "he tells the parable of the sower."),
    ("He calms a storm and asks the disciples,", "he calms a storm and asks the disciples,"),
    ("He frees the man possessed by Legion,", "he frees the man possessed by Legion,"),
    ("He sends the twelve out to preach and heal.", "he sends the twelve out to preach and heal."),
    ("Then He feeds five thousand men with five loaves and two fish.",
     "Then he feeds five thousand men with five loaves and two fish."),
    ("Alone with His disciples, He asks who they say He is,",
     "Alone with his disciples, he asks who they say he is,"),
    ("Jesus warns that He must suffer and be killed and rise the third day, and that His followers "
     "must",
     "Jesus warns that he must suffer and be killed and rise the third day, and that his followers "
     "must"),
    ("as He prays on a mountain, His face changes and His clothes become dazzling white.",
     "as he prays on a mountain, his face changes and his clothes become dazzling white."),
    ("Moses and Elijah appear and speak with Him about",
     "Moses and Elijah appear and speak with him about"),
    ("The next day He heals a boy the disciples could not help.",
     "The next day he heals a boy the disciples could not help."),
    ("and He sets a child beside Him:", "and he sets a child beside him:"),
    ("When a Samaritan village refuses to welcome Him,", "When a Samaritan village refuses to welcome him,"),
    ("To would-be followers who want to wait, He says,",
     "To would-be followers who want to wait, he says,"),
    ("“Master, what shall I do to inherit eternal life?” He agrees that the law says",
     "“Master, what shall I do to inherit eternal life?” he agrees that the law says"),
    ("while her sister Mary sits at His feet listening.",
     "while her sister Mary sits at his feet listening."),
    ("He tells of a friend who knocks at midnight", "he tells of a friend who knocks at midnight"),
    ("When critics claim He casts out demons by Beelzebub, Jesus says He does it",
     "When critics claim he casts out demons by Beelzebub, Jesus says he does it"),
    ("A woman calls out a blessing on His mother, but He says,",
     "A woman calls out a blessing on his mother, but he says,"),
    ("At a Pharisee's dinner, He condemns the Pharisees", "At a Pharisee's dinner, he condemns the Pharisees"),
    ("He tells the lawyers, “ye have taken away the key of knowledge.”",
     "he tells the lawyers, “ye have taken away the key of knowledge.”"),
    ("they watch Him closely, hoping to catch Him in His words.",
     "they watch him closely, hoping to catch him in his words."),
    ("He tells His friends not to fear those who can only kill the body.",
     "he tells his friends not to fear those who can only kill the body."),
    ("He tells of a rich farmer whose crops were so large", "he tells of a rich farmer whose crops were so large"),
    ("So His followers should not worry.", "So his followers should not worry."),
    ("and the lilies, which He clothes.", "and the lilies, which he clothes."),
    ("He warns that following Him will divide even families.",
     "he warns that following him will divide even families."),
    ("He also mentions eighteen people killed when the tower in Siloam fell.",
     "he also mentions eighteen people killed when the tower in Siloam fell."),
    ("He tells of a fig tree that has borne no fruit for three years.",
     "he tells of a fig tree that has borne no fruit for three years."),
    ("Someone asks if only a few will be saved. He answers,",
     "Someone asks if only a few will be saved. he answers,"),
    ("When warned that Herod wants to kill Him, Jesus says,",
     "When warned that Herod wants to kill him, Jesus says,"),
    ("“Go ye, and tell that fox” that He will finish His work.",
     "“Go ye, and tell that fox” that he will finish his work."),
    ("Then He grieves, “O Jerusalem, Jerusalem,", "Then he grieves, “O Jerusalem, Jerusalem,"),
    ("He tells them to take the lowest seat instead:", "he tells them to take the lowest seat instead:"),
    ("He tells the host to invite “the poor, the maimed,", "he tells the host to invite “the poor, the maimed,"),
    ("Then He tells of a man who prepares a great supper,", "Then he tells of a man who prepares a great supper,"),
    ("To the large crowds He warns,", "To the large crowds he warns,"),
    ("So He tells three stories about lost things.", "So he tells three stories about lost things."),
    ("He teaches, “He that is faithful in that which is least",
     "he teaches, “He that is faithful in that which is least"),
    ("Finally He tells of a rich man “clothed in purple and fine linen,”",
     "Finally he tells of a rich man “clothed in purple and fine linen,”"),
    ("Jesus tells His disciples to forgive a brother who repents,",
     "Jesus tells his disciples to forgive a brother who repents,"),
    ("He says that faith as small as a mustard seed can uproot a tree.",
     "he says that faith as small as a mustard seed can uproot a tree."),
    ("He sends them to show themselves to the priests,", "he sends them to show themselves to the priests,"),
    ("He warns that the day of His return will come suddenly,",
     "he warns that the day of his return will come suddenly,"),
    ("How much more will God answer His people?", "How much more will God answer his people?"),
    ("Then He speaks to those who trust in their own goodness.",
     "Then he speaks to those who trust in their own goodness."),
    ("He tells of a nobleman who leaves to receive a kingdom", "he tells of a nobleman who leaves to receive a kingdom"),
    ("down the Mount of Olives, His disciples praise God:", "down the Mount of Olives, his disciples praise God:"),
    ("“Master, rebuke thy disciples.” He answers,", "“Master, rebuke thy disciples.” he answers,"),
    ("But when He sees the city, He weeps over it.", "But when he sees the city, he weeps over it."),
    ("He says that if only it had known", "he says that if only it had known"),
    ("He enters the temple and drives out the sellers:", "he enters the temple and drives out the sellers:"),
    ("Every day He teaches there, while the leaders look for a way to destroy Him.",
     "Every day he teaches there, while the leaders look for a way to destroy him."),
    ("The leaders challenge His authority, and He tells the parable of the tenants",
     "The leaders challenge his authority, and he tells the parable of the tenants"),
    ("Spies try to trap Him about taxes, and He says,", "Spies try to trap him about taxes, and he says,"),
    ("To the Sadducees He says that God “is not a God of the dead,",
     "To the Sadducees he says that God “is not a God of the dead,"),
    ("He warns against scribes who “devour widows' houses.”",
     "he warns against scribes who “devour widows' houses.”"),
    ("Then He watches a poor widow put two small coins", "Then he watches a poor widow put two small coins"),
    ("He predicts it will be torn down.", "he predicts it will be torn down."),
    ("He warns of wars, earthquakes, famines, and persecution:", "he warns of wars, earthquakes, famines, and persecution:"),
    ("He warns them not to let their hearts be weighed down", "he warns them not to let their hearts be weighed down"),
    ("Each day He teaches in the temple, and each night He stays on the Mount of Olives.",
     "Each day he teaches in the temple, and each night he stays on the Mount of Olives."),
    ("the people come to hear Him.", "the people come to hear him."),
    ("At the table He says, “With desire I have desired", "At the table he says, “With desire I have desired"),
    ("He takes bread: “This is my body", "he takes bread: “This is my body"),
    ("After supper He takes the cup:", "After supper he takes the cup:"),
    ("he will deny Him three times.", "he will deny him three times."),
    ("An angel comes to strengthen Him.", "An angel comes to strengthen him."),
    ("He finds the disciples “sleeping for sorrow.”", "he finds the disciples “sleeping for sorrow.”"),
    ("To the officials He says, “this is your hour,", "To the officials he says, “this is your hour,"),
    ("The guards blindfold Jesus, beat Him, and mock Him,", "The guards blindfold Jesus, beat him, and mock him,"),
    ("“Art thou then the Son of God?” He answers,", "“Art thou then the Son of God?” he answers,"),
    ("accusing Him of “perverting the nation,", "accusing him of “perverting the nation,"),
    ("Pilate questions Him and says,", "Pilate questions him and says,"),
    ("Pilate sends Him to Herod Antipas, who is in Jerusalem.",
     "Pilate sends him to Herod Antipas, who is in Jerusalem."),
    ("Herod and his soldiers mock Him, dress Him in a gorgeous robe, and send Him back.",
     "Herod and his soldiers mock him, dress him in a gorgeous robe, and send him back."),
    ("including women who weep for Him.", "including women who weep for him."),
    ("He turns and says, “Daughters of Jerusalem,", "he turns and says, “Daughters of Jerusalem,"),
    ("they crucify Him between two criminals.", "they crucify him between two criminals."),
    ("The soldiers gamble for His clothes, and rulers and soldiers mock Him.",
     "The soldiers gamble for his clothes, and rulers and soldiers mock him."),
    ("Above Him is a sign written in Greek, Latin, and Hebrew:",
     "Above him is a sign written in Greek, Latin, and Hebrew:"),
    ("and breathes His last.", "and breathes his last."),
    ("Jesus had said He would be crucified", "Jesus had said he would be crucified"),
    ("Jesus Himself joins them, but they do not recognize Him.",
     "Jesus himself joins them, but they do not recognize him."),
    ("Sadly they tell Him about Jesus' death:", "Sadly they tell him about Jesus' death:"),
    ("At the village they urge Him, “Abide with us", "At the village they urge him, “Abide with us"),
    ("They are terrified, thinking He is a spirit.", "They are terrified, thinking he is a spirit."),
    ("To prove it, He eats a piece of broiled fish", "To prove it, he eats a piece of broiled fish"),
    ("Then He opens their minds to understand the Scriptures.", "Then he opens their minds to understand the Scriptures."),
    ("He tells them to wait in the city", "he tells them to wait in the city"),
    ("He leads them out as far as Bethany, lifts up His hands, and blesses them.",
     "he leads them out as far as Bethany, lifts up his hands, and blesses them."),
    ("As He blesses them, “he was parted from them,", "As he blesses them, “he was parted from them,"),
    ("They worship Him and return to Jerusalem", "They worship him and return to Jerusalem"),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "07_gospels_acts.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("# Luke")
    end = text.index("# John")
    section = text[start:end]
    for old, new in STORY_PRONOUN_FIXES:
        if old == new:
            continue
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
    apply_book_overview()
    apply_story_fixes()
