#!/usr/bin/env python3
"""Apply the completed editorial review for Mark to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


WWA = {
    1: ("Matthew's Gospel ended with the risen Jesus commissioning the eleven to make disciples of "
        "all nations (Matthew 28:16-20). Mark opens the New Testament's second Gospel at a faster "
        "pace, with no birth story: John the Baptist prepares the way in the wilderness, Jesus is "
        "baptized and tested for forty days, and after John's arrest Jesus calls four fishermen and "
        "begins teaching, healing, and casting out demons in Capernaum (1:1-45). That burst of "
        "authority and healing draws such crowds that chapter 2 opens with a paralyzed man being "
        "lowered through a roof just to reach him."),
    2: ("Chapter 1 ended with a healed man's report drawing such crowds that Jesus could no longer "
        "openly enter a town (1:45). Chapter 2 shows him teaching indoors anyway: four men lower a "
        "paralyzed friend through the roof, Jesus calls the tax collector Levi to follow him, and he "
        "answers questions about fasting and the Sabbath by appealing to his own authority (2:1-28). "
        "These first conflicts set up chapter 3's sharper confrontation, where a Sabbath healing "
        "leads Pharisees and Herodians to begin plotting against him."),
    3: ("Chapter 2 closed with Jesus teaching that the Sabbath was made for people, not people for "
        "the Sabbath (2:27-28). Chapter 3 shows the cost of that claim: a Sabbath healing in the "
        "synagogue drives Pharisees and Herodians to plot against him, while Jesus responds by "
        "appointing twelve apostles and naming those who do God's will as his true family (3:1-35). "
        "That contrast between official rejection and a widening circle of followers sets up chapter "
        "4's parables about how the kingdom takes root in different kinds of hearers."),
    4: ("Chapter 3 ended with Jesus naming whoever does God's will as his true family, in contrast to "
        "the leaders who rejected him (3:31-35). Chapter 4 explains how that family grows: from a "
        "boat Jesus tells parables of a sower, a lamp, and seeds that picture the kingdom of God, "
        "then stills a storm and asks the disciples why they still have no faith (4:1-41). Their "
        "fear in the boat carries into chapter 5, where Jesus crosses the lake to free a man "
        "tormented by many unclean spirits."),
    5: ("Chapter 4 ended with the disciples terrified in a storm, wondering who Jesus could be that "
        "even wind and sea obey him (4:35-41). Chapter 5 answers with three acts of rescue: Jesus "
        "frees a man possessed by many unclean spirits, heals a woman who had suffered twelve years "
        "of bleeding, and raises Jairus's twelve-year-old daughter from death (5:1-43). That sequence "
        "of restored lives gives way in chapter 6 to rejection, when Jesus returns to his own "
        "hometown and is met with disbelief instead."),
    6: ("Chapter 5 ended with Jesus raising Jairus's daughter and ordering those present to tell no "
        "one (5:42-43). Chapter 6 shows a harder reception: his own hometown takes offense at him, so "
        "he sends the Twelve out two by two instead, Herod Antipas has John the Baptist beheaded "
        "after a banquet oath, and Jesus feeds five thousand and walks on the sea while the disciples "
        "still do not understand about the loaves (6:1-52). That failure to understand carries into "
        "chapter 7, where Pharisees challenge Jesus over handwashing traditions."),
    7: ("Chapter 6 ended by noting that the disciples' hearts were hardened and they still did not "
        "understand about the loaves (6:51-52). Chapter 7 presses the same point with Israel's own "
        "leaders: Pharisees and scribes challenge Jesus over handwashing traditions, he teaches that "
        "defilement comes from the heart rather than from food, and he then grants a Gentile woman's "
        "request for her daughter and heals a deaf man in the Decapolis (7:1-37). Those two "
        "Gentile-region healings lead into chapter 8, which opens with Jesus again feeding a crowd in "
        "that same region."),
    8: ("Chapter 7 ended with crowds in the Decapolis astonished that Jesus had healed a deaf man and "
        "made the mute speak (7:37). Chapter 8 opens in that same region as Jesus feeds four thousand, "
        "then moves toward Caesarea Philippi, where Peter identifies him as the Messiah; when Jesus "
        "predicts his own suffering, death, and resurrection, Peter objects and is sharply rebuked, "
        "and Jesus tells the crowd that following him requires taking up a cross (8:1-38). Six days "
        "later, in chapter 9, three of those same disciples see Jesus briefly transfigured in glory "
        "on a mountain."),
    9: ("Chapter 8 ended with Jesus warning that whoever is ashamed of him will find the Son of man "
        "ashamed of them at his coming in glory (8:38). Chapter 9 shows that glory briefly: Jesus is "
        "transfigured before Peter, James, and John, then comes down to free a boy the other "
        "disciples could not help, predicts his coming death again, and teaches that true greatness "
        "means becoming a servant of all (9:1-50). That same question of status continues in chapter "
        "10, where Pharisees ask about divorce and James and John request the places of highest "
        "honor."),
    10: ("Chapter 9 ended with Jesus teaching that welcoming a child in his name means welcoming him, "
         "and warning against anything that causes the vulnerable to stumble (9:36-37,42). Chapter 10 "
         "extends that concern: Jesus teaches against divorce, welcomes children, tells a wealthy man "
         "to sell his possessions, and predicts his death again before James and John ask for seats "
         "of honor (10:1-45). He answers that the Son of man came to serve and give his life as a "
         "ransom for many, fulfilled visibly in chapter 11 as he enters Jerusalem like a humble king."),
    11: ("Chapter 10 ended with the healed beggar Bartimaeus following Jesus on the road to Jerusalem "
         "(10:52). Chapter 11 arrives at that city: Jesus enters riding a colt as crowds hail the "
         "coming kingdom of David, curses a fruitless fig tree, drives the money changers from the "
         "temple, and is challenged by chief priests, scribes, and elders demanding to know his "
         "authority (11:1-33). His refusal to answer their question directly sets up chapter 12's "
         "series of trap questions and parables aimed at exposing those same leaders."),
    12: ("Chapter 11 ended with religious leaders refusing to answer Jesus' question about John's "
         "baptism, so he refused to tell them his own authority (11:33). Chapter 12 shows him turning "
         "the tables: his parable of the wicked tenants exposes those same leaders, and he answers a "
         "series of trap questions about taxes, resurrection, and the greatest commandment before "
         "praising a poor widow's small offering over the large gifts of the rich (12:1-44). Leaving "
         "the temple at the end of that scene, in chapter 13 Jesus predicts that the temple itself "
         "will soon fall."),
    13: ("Chapter 12 ended with Jesus praising a poor widow who gave two small coins, all she had, "
         "far more in his eyes than the large gifts of the rich (12:41-44). Chapter 13 leaves that "
         "same temple behind: Jesus predicts its coming destruction, and on the Mount of Olives "
         "answers the disciples' private questions with warnings about deception, persecution, and "
         "cosmic upheaval, insisting that no one knows the day or hour (13:1-37). That call to "
         "watchfulness gives way in chapter 14 to the events it was warning about, beginning with the "
         "leaders' plot to arrest Jesus near Passover."),
    14: ("Chapter 13 ended with Jesus commanding his followers to watch, since no one knows when the "
         "master of the house will come (13:35-37). Chapter 14 shows the watch failing: as Passover "
         "approaches, a woman anoints Jesus for burial even as Judas arranges his betrayal, Jesus "
         "shares a final Passover meal and reinterprets its bread and cup around his own body and "
         "blood, and in Gethsemane he finds his disciples asleep instead of watching with him "
         "(14:1-72). His arrest that same night and Peter's three denials set up chapter 15's account "
         "of his trial before Pilate and crucifixion."),
    15: ("Chapter 14 ended with Peter denying Jesus three times and weeping after the rooster crowed "
         "(14:72). Chapter 15 carries Jesus from that same night into his execution: the council "
         "hands him to Pilate, the crowd chooses to release Barabbas instead, and Jesus is mocked, "
         "crucified between two criminals, and dies as the temple curtain tears in two and a Roman "
         "centurion calls him God's Son (15:1-47). Joseph of Arimathea buries him in a rock-cut tomb "
         "while women watch, setting up chapter 16's discovery that the tomb is empty."),
    16: ("Chapter 15 ended with Joseph of Arimathea laying Jesus' body in a tomb while Mary Magdalene "
         "and Mary the mother of Joses watched where he was laid (15:46-47). Mark's closing chapter "
         "answers that sealed tomb directly: the same women find the stone rolled away and are told "
         "by a young man in white that Jesus has risen and goes before them to Galilee, though they "
         "flee in fear (16:1-8). The KJV's longer ending adds resurrection appearances and a "
         "commission to preach the gospel worldwide, the same mission Luke's Gospel will trace again "
         "from its own beginning with John the Baptist and Jesus."),
}

SUMMARY_FIXES = {
    16: [
        ("The two earliest surviving complete Greek manuscripts end at 16:8, and many textual "
         "scholars regard 9–20 as a later ending; its content is therefore presented here as part of "
         "the KJV textual tradition, not as unquestionably original to Mark.",
         "The two earliest surviving complete Greek manuscripts end at 16:8, and the KJV's verses "
         "9–20 are a longer ending found in most later manuscript copies; this chapter presents that "
         "longer ending as part of the KJV's own textual tradition, alongside the shorter ending the "
         "oldest manuscripts preserve."),
    ],
}

KEY_FIGURES = {
    1: [
        ("John the Baptist",
         "Preaches repentance in the wilderness, baptizes crowds in the Jordan, and tells them one "
         "mightier than himself is coming (1:2-8)."),
        ("Jesus",
         "Is baptized and named God's beloved Son, is tested forty days in the wilderness, calls "
         "four fishermen to follow him, teaches and heals in Capernaum, and cleanses a man with a "
         "skin disease (1:9-45)."),
        ("Simon Peter",
         "Is called from his nets to follow Jesus, and his mother-in-law is healed of a fever in his "
         "own house (1:16-18,29-31)."),
        ("Andrew, James and John",
         "Are called away from their fishing nets and boats to follow Jesus as his first disciples "
         "(1:16-20)."),
        ("Crowds and those seeking healing",
         "Gather at Simon's door once the Sabbath ends and later press in from every town once a "
         "healed leper spreads the news (1:32-34,45)."),
    ],
    2: [
        ("Jesus",
         "Forgives and heals a paralyzed man, calls Levi the tax collector to follow him, and "
         "defends his disciples' conduct over fasting and the Sabbath (2:1-28)."),
        ("Paralyzed man and four carriers",
         "The four dig through a roof to lower their friend to Jesus, who forgives his sins and then "
         "heals him to prove he has authority to do both (2:1-12)."),
        ("Levi son of Alphaeus",
         "Leaves his tax booth to follow Jesus and hosts him for a meal with tax collectors and "
         "sinners (2:14-15)."),
        ("Scribes and Pharisees",
         "Accuse Jesus of blasphemy for forgiving sins and later object when his disciples pick "
         "grain on the Sabbath (2:6-7,24)."),
        ("John's disciples",
         "Are named in a question asking why they and the Pharisees fast while Jesus' disciples do "
         "not, drawing his image of wedding guests and a bridegroom (2:18)."),
    ],
    3: [
        ("Jesus",
         "Heals a man's withered hand in the synagogue, appoints twelve apostles, answers the charge "
         "that he casts out demons by Beelzebul, and names those who do God's will as his true "
         "family (3:1-35)."),
        ("Man with a withered hand",
         "Is healed by Jesus in the synagogue while observers watch to see whether Jesus will break "
         "the Sabbath (3:1-5)."),
        ("Pharisees and Herodians",
         "Watch for grounds to accuse Jesus after the Sabbath healing, then go out and begin "
         "plotting how to destroy him (3:2,6)."),
        ("The Twelve",
         "Are appointed by Jesus, including Simon Peter, James, John, and Judas Iscariot, to be with "
         "him, to preach, and to cast out demons (3:13-19)."),
        ("Scribes from Jerusalem",
         "Claim Jesus casts out demons by the prince of demons, drawing his warning about "
         "blaspheming the Holy Spirit (3:22,29-30)."),
        ("Jesus' mother and brothers",
         "Come looking for him outside the house, prompting his teaching that whoever does God's "
         "will is his true family (3:31-35)."),
    ],
    4: [
        ("Jesus",
         "Teaches kingdom parables from a boat, explains them privately to his disciples, and calms "
         "a storm that terrifies them (4:1-41)."),
        ("Disciples",
         "Receive Jesus' private explanation of the sower parable and later wake him in panic during "
         "a storm, asking if he even cares that they are dying (4:10-20,38)."),
        ("Crowd",
         "Gathers on the shore to hear Jesus' parables about the sower, the lamp, and the growing "
         "seed (4:1-2,26-32)."),
        ("Sower in the parable",
         "A fictional figure in Jesus' parable who scatters seed on four kinds of soil, picturing "
         "different responses to God's word (4:3-8,14-20)."),
    ],
    5: [
        ("Jesus",
         "Frees a man controlled by many unclean spirits, heals a woman's twelve-year hemorrhage, "
         "and raises Jairus's dead daughter (5:1-43)."),
        ("Man formerly possessed",
         "Lives among the tombs crying out and cutting himself until Jesus frees him, after which he "
         "is sent home to tell what the Lord has done for him (5:2-5,15-19)."),
        ("Jairus",
         "A synagogue leader who begs Jesus to heal his dying daughter and is told not to fear but "
         "only to believe once she is reported dead (5:22-23,35-36)."),
        ("Woman with ongoing bleeding",
         "Touches Jesus' garment in secret after twelve years of illness and is healed, then publicly "
         "confesses what she did when Jesus calls her out (5:25-33)."),
        ("Jairus's daughter",
         "A twelve-year-old girl who dies before Jesus arrives, then is raised when he takes her "
         "hand and tells her to rise (5:41-42)."),
        ("Peter, James and John",
         "Are the only disciples Jesus allows into the room where he raises Jairus's daughter "
         "(5:37)."),
    ],
    6: [
        ("Jesus",
         "Is rejected in his hometown, sends out the Twelve, feeds five thousand, and walks on the "
         "sea to his disciples (6:1-52)."),
        ("The Twelve",
         "Are sent out by Jesus in pairs to preach repentance and heal, then return to report what "
         "they did and taught (6:7-13,30)."),
        ("John the Baptist",
         "Is imprisoned by Herod for condemning his marriage to Herodias, then beheaded at Herod's "
         "command after a banquet oath (6:17-18,27-28)."),
        ("Herod Antipas",
         "The tetrarch who fears and yet listens to John, then has him executed rather than break an "
         "oath made in front of his dinner guests (6:20,26-27)."),
        ("Herodias and her daughter",
         "Herodias wants John dead and uses her daughter's dance and Herod's rash oath to obtain his "
         "head on a platter (6:19,22-25)."),
        ("Crowds",
         "Follow Jesus by land even after he tries to withdraw, and he feeds five thousand of them "
         "with five loaves and two fish (6:33-34,41-44)."),
    ],
    7: [
        ("Jesus",
         "Teaches that defilement comes from the heart rather than unwashed hands, frees a Gentile "
         "girl from an unclean spirit, and heals a deaf man in the Decapolis (7:1-37)."),
        ("Pharisees and scribes",
         "Challenge Jesus over his disciples eating with unwashed hands according to the tradition "
         "of the elders (7:1-5)."),
        ("Syrophoenician woman",
         "Asks Jesus to free her daughter from an unclean spirit and persists even after his hard "
         "answer about children and dogs (7:25-28)."),
        ("Woman's daughter",
         "Is freed from an unclean spirit at a distance once Jesus grants her mother's request "
         "(7:29-30)."),
        ("Deaf man with speech difficulty",
         "Is brought to Jesus in the Decapolis and healed when Jesus touches his ears and tongue and "
         "says, \"Ephphatha\" (7:32-35)."),
    ],
    8: [
        ("Jesus",
         "Feeds four thousand, refuses the Pharisees a sign, heals a blind man in stages, and "
         "predicts his own suffering after Peter names him the Messiah (8:1-38)."),
        ("Peter",
         "Correctly identifies Jesus as the Christ, then rebukes him for predicting his death and is "
         "sharply rebuked in turn (8:29,32-33)."),
        ("Pharisees",
         "Demand a sign from heaven to test Jesus, who refuses and sighs deeply in his spirit "
         "(8:11-12)."),
        ("Disciples",
         "Misunderstand Jesus' warning about the Pharisees' and Herod's leaven as a complaint about "
         "forgetting bread (8:14-21)."),
        ("Blind man at Bethsaida",
         "Receives sight from Jesus in two stages, first seeing people as trees before seeing "
         "clearly (8:23-25)."),
        ("Crowds",
         "Are called together with the disciples to hear Jesus' teaching that following him means "
         "denying self and taking up a cross (8:34)."),
    ],
    9: [
        ("Jesus",
         "Is transfigured in glory before three disciples, frees a boy from a spirit the others "
         "could not cast out, and teaches that greatness means becoming a servant (9:2-50)."),
        ("Peter, James and John",
         "Witness Jesus transfigured with Moses and Elijah and hear a voice from the cloud command "
         "them to listen to him (9:2-7)."),
        ("Moses and Elijah",
         "Appear with Jesus on the mountain, talking with him before the voice from the cloud ends "
         "the vision (9:4-7)."),
        ("Father and afflicted boy",
         "The father pleads for help with his unbelief, and Jesus casts the spirit out of his son "
         "after the other disciples had failed to (9:17-18,24-27)."),
        ("The Twelve",
         "Argue on the road about who is greatest and try to stop a man casting out demons in Jesus' "
         "name who was not one of their group (9:33-34,38)."),
        ("Child",
         "Is placed among the disciples by Jesus as an example of the lowly person they must welcome "
         "in his name (9:36-37)."),
    ],
    10: [
        ("Jesus",
         "Teaches against divorce, welcomes children, calls a wealthy man to sell his possessions, "
         "predicts his death again, and heals blind Bartimaeus (10:1-52)."),
        ("Pharisees",
         "Ask Jesus whether divorce is lawful, prompting his teaching that Moses only permitted it "
         "because of human hardness of heart (10:2-9)."),
        ("Children",
         "Are brought to Jesus for a blessing, and he is indignant when the disciples try to turn "
         "them away (10:13-16)."),
        ("Wealthy inquirer",
         "Asks Jesus what he must do to inherit eternal life, then goes away sad rather than sell "
         "his great possessions (10:17,22)."),
        ("James and John",
         "Ask Jesus to let them sit at his right and left in his glory, drawing both his teaching on "
         "servant leadership and the other ten disciples' anger (10:35-41)."),
        ("Bartimaeus",
         "A blind beggar near Jericho who calls out to Jesus despite the crowd's rebuke, receives "
         "his sight, and follows Jesus on the road (10:46-52)."),
    ],
    11: [
        ("Jesus",
         "Enters Jerusalem on a colt, curses a fruitless fig tree, drives traders from the temple, "
         "and refuses to answer the leaders who question his authority (11:1-33)."),
        ("Disciples",
         "Bring Jesus the colt he requested and later notice that the fig tree he cursed has "
         "withered from the roots (11:1-7,20-21)."),
        ("Crowds",
         "Spread cloaks and branches on the road and shout praise for the coming kingdom of their "
         "father David (11:8-10)."),
        ("Buyers, sellers and money changers",
         "Conduct business in the temple courts until Jesus drives them out and overturns their "
         "tables (11:15-16)."),
        ("Chief priests, scribes and elders",
         "Demand to know by what authority Jesus acts, then refuse to answer his counter-question "
         "about John's baptism (11:27-33)."),
    ],
    12: [
        ("Jesus",
         "Tells the parable of the tenants, answers questions about taxes, resurrection, and the "
         "greatest commandment, and praises a poor widow's offering (12:1-44)."),
        ("Chief priests, scribes and elders",
         "Recognize that Jesus' parable of the wicked tenants is told against them and seek a way "
         "to arrest him (12:12)."),
        ("Pharisees and Herodians",
         "Try to trap Jesus with a question about paying tribute to Caesar and are left marveling at "
         "his answer (12:13-17)."),
        ("Sadducees",
         "Pose a hypothetical case about a widow and seven brothers to challenge belief in the "
         "resurrection (12:18-23)."),
        ("Scribe who asks the first commandment",
         "Agrees with Jesus that loving God and neighbor matters more than any sacrifice, and is "
         "told he is not far from the kingdom of God (12:28-34)."),
        ("Poor widow",
         "Puts two small coins into the temple treasury, a gift Jesus calls greater than all the "
         "large sums given by the rich (12:41-44)."),
    ],
    13: [
        ("Jesus",
         "Predicts the temple's destruction, warns the disciples about deception and distress to "
         "come, and describes himself as the Son of man coming in the clouds with great power and "
         "glory to gather his elect (13:1-27)."),
        ("Peter, James, John and Andrew",
         "Ask Jesus privately on the Mount of Olives when the temple will fall and what sign will "
         "mark these events (13:3-4)."),
        ("False claimants",
         "Predicted figures who will come claiming to be the Christ and will try to deceive even the "
         "elect if possible (13:6,21-22)."),
        ("The elect",
         "Will be gathered by the Son of man's angels from the four winds after the days of distress "
         "(13:27)."),
    ],
    14: [
        ("Jesus",
         "Is anointed at Bethany, shares the Passover meal, prays in anguish at Gethsemane, and is "
         "arrested and condemned before the council (14:3-65)."),
        ("Unnamed woman in Bethany",
         "Pours costly perfume on Jesus' head, an act he defends as preparing his body for burial "
         "ahead of time (14:3-9)."),
        ("Judas Iscariot",
         "Goes to the chief priests to arrange Jesus' betrayal for money, then identifies him with a "
         "kiss when the armed crowd arrives (14:10-11,44-45)."),
        ("Peter",
         "Insists he will never deny Jesus, falls asleep at Gethsemane, and then denies knowing him "
         "three times before weeping bitterly (14:29-31,37,66-72)."),
        ("The Twelve",
         "Share the Passover meal where Jesus names a betrayer among them and later flee when he is "
         "arrested (14:17-21,50)."),
        ("High priest and council",
         "Hear false testimony against Jesus, then condemn him to death once he declares his own "
         "identity (14:55-56,61-64)."),
    ],
    15: [
        ("Jesus",
         "Is tried before Pilate, mocked, crucified between two criminals, and buried in a borrowed "
         "tomb (15:1-47)."),
        ("Pontius Pilate",
         "Questions Jesus, offers the crowd a choice between Jesus and the convicted rebel Barabbas, "
         "who is released instead, and orders Jesus crucified after the crowd shouts him down "
         "(15:2-15)."),
        ("Simon of Cyrene",
         "Is compelled by the soldiers to carry Jesus' cross to Golgotha (15:21)."),
        ("Roman centurion",
         "Watches Jesus die and declares, \"Truly this man was the Son of God\" (15:39)."),
        ("Joseph of Arimathea",
         "A council member who boldly asks Pilate for Jesus' body and buries it in his own rock-cut "
         "tomb (15:43,46)."),
        ("Mary Magdalene, Mary mother of Joses and Salome",
         "Watch the crucifixion from a distance and see exactly where Jesus is laid (15:40,47)."),
    ],
    16: [
        ("Jesus",
         "Is announced as risen by a messenger in the tomb and, in the KJV's longer ending, appears "
         "to his followers and commissions them before being received into heaven (16:1-20)."),
        ("Mary Magdalene, Mary mother of James and Salome",
         "Come to anoint Jesus' body with spices and find the tomb's stone already rolled away "
         "(16:1-4)."),
        ("Young man in white",
         "Sits inside the empty tomb and tells the women that Jesus has risen and goes before them "
         "to Galilee (16:5-7)."),
        ("Peter and other disciples",
         "Are named as the ones the women are told to tell that Jesus goes before them into Galilee "
         "(16:7)."),
        ("Eleven disciples",
         "Receive the risen Jesus' appearance and commission to preach the gospel to all creation in "
         "the KJV's longer ending (16:14-16)."),
    ],
}

THEMES = {
    1: {
        "Preparation and repentance":
            "John the Baptist calls Israel to repent and be baptized, deliberately living out "
            "Isaiah's picture of a voice preparing the way for the Lord (1:2-8).",
        "Identity and testing":
            "A voice from heaven names Jesus God's beloved Son at his baptism, and the Spirit "
            "immediately drives him into the wilderness to be tested by Satan for forty days "
            "(1:9-13).",
        "God's kingdom and discipleship":
            "Jesus announces that God's kingdom is at hand and calls four fishermen to leave their "
            "nets and follow him at once (1:14-20).",
        "Authority with compassion":
            "Jesus teaches with an authority that amazes the synagogue, casts out an unclean spirit, "
            "and heals Simon's mother-in-law, many of the sick, and a man with a skin disease "
            "(1:21-45).",
    },
    2: {
        "Forgiveness and authority":
            "Jesus forgives the paralyzed man's sins before healing him, using the visible healing "
            "to prove his authority to forgive what scribes say only God can forgive (2:1-12).",
        "Calling the excluded":
            "Jesus calls the tax collector Levi and eats with tax collectors and sinners, saying he "
            "came to call sinners rather than those who think themselves already righteous "
            "(2:13-17).",
        "Newness and religious habits":
            "Asked why his disciples do not fast like John's disciples, Jesus compares himself to a "
            "bridegroom and warns that his new teaching cannot simply be patched onto old practices "
            "(2:18-22).",
        "Sabbath and human need":
            "When Pharisees object to the disciples picking grain on the Sabbath, Jesus answers that "
            "the Sabbath was made for people, not people for the Sabbath (2:23-28).",
    },
    3: {
        "Mercy and Sabbath":
            "Jesus heals a man's withered hand in the synagogue and asks whether the Sabbath permits "
            "doing good or doing harm, a question his critics will not answer (3:1-6).",
        "Calling and mission":
            "Jesus appoints twelve men to be with him and to be sent out to preach and to have "
            "authority over demons (3:13-19).",
        "Discernment of spiritual work":
            "When scribes claim Jesus casts out demons by the prince of demons, he answers that a "
            "divided kingdom cannot stand and warns against calling the Spirit's work unclean "
            "(3:22-30).",
        "Belonging through obedience":
            "When his mother and brothers come looking for him, Jesus says that whoever does God's "
            "will is his brother, sister, and mother (3:31-35).",
    },
    4: {
        "Hearing and responding":
            "The parable of the sower pictures four different responses to God's word, from "
            "immediate loss to a harvest thirty, sixty, or a hundred times what was sown (4:1-20).",
        "Revelation and attentiveness":
            "Jesus says a lamp is meant to be seen, not hidden, and warns that how carefully a "
            "person listens determines how much they will be given (4:21-25).",
        "Unexpected kingdom growth":
            "The growing seed and the mustard seed both show God's kingdom starting small and "
            "almost unnoticed before becoming something large (4:26-34).",
        "Faith amid fear":
            "When a storm threatens to sink their boat, Jesus calms the wind and sea with a word and "
            "asks the disciples why they still have no faith (4:35-41).",
    },
    5: {
        "Freedom from destructive power":
            "Jesus frees a man controlled by many unclean spirits calling themselves Legion, "
            "restoring him to his right mind even though the local people respond with fear rather "
            "than welcome (5:1-20).",
        "Dignity and healing":
            "A woman who had spent everything on doctors over twelve years touches Jesus' clothes in "
            "secret, but he stops to call her out publicly as a daughter whose faith has healed her "
            "(5:25-34).",
        "Faith in crisis":
            "Jairus pleads for his dying daughter, and when word comes that she has died, Jesus "
            "tells him to stop being afraid and simply believe (5:21-24,35-36).",
        "Life and restoration":
            "Jesus takes the dead girl's hand and tells her to get up, then has her given something "
            "to eat, a small practical detail that confirms she is truly alive (5:37-43).",
    },
    6: {
        "Unbelief and mission":
            "Jesus can do few miracles in his own hometown because of its unbelief, yet he still "
            "sends the Twelve out two by two to preach repentance and heal (6:1-13).",
        "Cost of prophetic witness":
            "Mark recounts how Herod Antipas had John the Baptist beheaded after a rash birthday "
            "oath, showing what confronting a ruler's sin can cost a prophet (6:14-29).",
        "Compassionate provision":
            "Moved with compassion for a crowd like sheep without a shepherd, Jesus feeds five "
            "thousand men from five loaves and two fish, with twelve baskets left over (6:30-44).",
        "Understanding and fear":
            "Jesus walks on the sea to the disciples in their boat, and Mark notes that their hearts "
            "were hardened, since they still had not understood about the loaves (6:45-52).",
    },
    7: {
        "Commandments and human traditions":
            "Jesus rebukes Pharisees and scribes for a tradition that lets people dedicate money to "
            "God while using it as an excuse to withhold care from their own parents (7:1-13).",
        "Moral source of defilement":
            "Jesus teaches that food cannot make a person unclean, since defilement comes from the "
            "evil thoughts and actions that come out of the human heart (7:14-23).",
        "Persistent petition across boundaries":
            "A Syrophoenician woman persists in asking Jesus to free her daughter even after a hard "
            "answer about children and dogs, and he grants her request (7:24-30).",
        "Restorative compassion":
            "In the Decapolis, Jesus heals a deaf man who struggles to speak, leaving the crowds "
            "astonished that he does all things well (7:31-37).",
    },
    8: {
        "Provision and misperception":
            "Jesus feeds four thousand people with seven loaves, yet the disciples still worry about "
            "having no bread, missing his warning about the Pharisees' corrupting influence "
            "(8:1-21).",
        "Gradual sight":
            "Jesus heals a blind man at Bethsaida in two stages, a healing that mirrors the "
            "disciples' own slow, incomplete understanding of who Jesus is (8:22-26).",
        "Messiahship and suffering":
            "Peter correctly names Jesus as the Messiah but then rebukes him for predicting his own "
            "suffering and death, earning Jesus' sharp rebuke in return (8:27-33).",
        "Costly discipleship":
            "Jesus tells the crowd that following him means denying themselves and taking up a "
            "cross, since saving one's life by avoiding that cost actually loses it (8:34-38).",
    },
    9: {
        "Revelation and listening":
            "Jesus is transfigured in dazzling glory before Peter, James, and John, and a voice from "
            "the cloud commands them simply to listen to him (9:2-13).",
        "Prayer and dependent faith":
            "A father begs help for his son with the honest cry, \"Lord, I believe; help thou mine "
            "unbelief,\" and Jesus casts the spirit out after the other disciples could not (9:14-29).",
        "Greatness as service":
            "After the disciples argue about who is greatest, Jesus takes a child in his arms and "
            "teaches that whoever wants to be first must become servant of all (9:33-37).",
        "Guarding vulnerable people":
            "Jesus corrects the disciples for stopping a man who cast out demons in his name, then "
            "warns in forceful terms against anything that causes one of these little ones to "
            "stumble (9:38-50).",
    },
    10: {
        "Marriage and responsibility":
            "Jesus traces marriage back to God's creation of male and female as one flesh, teaching "
            "that Moses only permitted divorce because of human hardness of heart (10:1-12).",
        "Receiving the kingdom":
            "When the disciples turn children away, Jesus is indignant and says that whoever does "
            "not receive God's kingdom like a child will not enter it at all (10:13-16).",
        "Possessions and trust":
            "A wealthy man goes away sad rather than sell his possessions, and Jesus tells the "
            "astonished disciples that what is impossible for people is possible for God "
            "(10:17-31).",
        "Greatness through service":
            "When James and John ask for the places of highest honor, Jesus teaches that greatness "
            "means serving others, since the Son of man came to give his life as a ransom for many "
            "(10:35-45).",
        "Faithful response":
            "Blind Bartimaeus refuses to be silenced, and once Jesus restores his sight he does not "
            "go home but follows Jesus on the road (10:46-52).",
    },
    11: {
        "Kingship and expectation":
            "Jesus enters Jerusalem on a colt as crowds spread cloaks and branches and shout for the "
            "coming kingdom of David, acting out the picture of a humble king (11:1-11).",
        "Worship and justice":
            "Jesus curses a fruitless fig tree and drives the money changers from the temple, "
            "pairing both acts as judgment on worship that looks flourishing but produces nothing "
            "real (11:12-19).",
        "Faith and forgiveness":
            "Finding the fig tree withered, Jesus teaches the disciples to pray with unwavering "
            "trust in God and to forgive others so that God will forgive them (11:20-25).",
        "Contested authority":
            "When chief priests, scribes, and elders demand to know his authority, Jesus answers "
            "with a question about John's baptism that they refuse to answer (11:27-33).",
    },
    12: {
        "Accountability of leaders":
            "In the parable of the tenant farmers who kill the owner's beloved son, Jesus tells the "
            "religious leaders a story that they immediately recognize is aimed at them (12:1-12).",
        "God and political obligation":
            "Asked whether paying tax to Caesar is lawful, Jesus answers that people should give "
            "Caesar what bears his image and give God what bears God's, refusing to let the trap "
            "force a simple answer (12:13-17).",
        "Resurrection hope":
            "Sadducees try to make resurrection absurd with a hypothetical widow, but Jesus answers "
            "that they know neither the Scriptures nor the power of God, who is God of the living "
            "(12:18-27).",
        "Love as the heart of the law":
            "Asked which commandment is greatest, Jesus joins loving God with all one's heart from "
            "Deuteronomy to loving one's neighbor from Leviticus as the two commands the whole law "
            "hangs on (12:28-34).",
        "Integrity in worship":
            "Jesus warns against scribes who seek honor while exploiting widows, then praises a poor "
            "widow whose two small coins were, in his eyes, a greater gift than the large sums "
            "thrown in by the rich (12:38-44).",
    },
    13: {
        "Discernment amid turmoil":
            "Jesus warns that wars, earthquakes, and false messiahs will come but tells the "
            "disciples not to be deceived into reading any of it as the certain sign of the end "
            "(13:5-8,21-23).",
        "Endurance in witness":
            "Disciples will be handed over to councils and rulers for Jesus' sake, but he promises "
            "the Holy Spirit will give them words to say and that the one who endures to the end "
            "will be saved (13:9-13).",
        "Crisis and deliverance":
            "A desolating horror in the temple will bring suffering unlike anything before it, yet "
            "Jesus promises the Son of man will come in power to gather his elect out of that same "
            "crisis (13:14-27).",
        "Watchfulness without date setting":
            "Jesus compares the fig tree's leaves to the signs of the end, but insists no one knows "
            "the day or hour, so disciples must simply stay awake and ready (13:28-37).",
    },
    14: {
        "Honor and costly devotion":
            "An unnamed woman pours costly perfume on Jesus, and when others object to the waste, he "
            "defends her act as preparing his body in advance for burial (14:3-9).",
        "Covenant and self-giving":
            "At the Passover table Jesus calls the bread his body and the cup his blood of the "
            "covenant, reinterpreting the meal around his own coming death (14:22-25).",
        "Prayer and surrender":
            "In Gethsemane Jesus prays that the cup might pass from him, yet submits, \"not what I "
            "will, but what thou wilt,\" while his disciples sleep instead of keeping watch "
            "(14:32-42).",
        "Betrayal and failed loyalty":
            "Judas betrays Jesus with a kiss and the other disciples flee, while Peter denies even "
            "knowing him three times before the rooster crows and he weeps (14:43-72).",
    },
    15: {
        "Injustice and political power":
            "Pilate finds no real charge against Jesus but releases the murderer Barabbas instead "
            "and has Jesus flogged and crucified simply to satisfy the crowd (15:1-15).",
        "Mocked kingship":
            "Soldiers dress Jesus in purple and a crown of thorns to mock him as king, not realizing "
            "their taunt will be nailed above his cross as the literal charge against him "
            "(15:16-32).",
        "Suffering and disclosure":
            "Jesus dies crying out the opening words of Psalm 22 as the temple curtain tears in two, "
            "and a Roman centurion is the first to call him the Son of God (15:33-39).",
        "Witness and care after death":
            "Joseph of Arimathea boldly asks for Jesus' body and buries it in his own tomb, while "
            "the women who had followed Jesus from Galilee watch and remember exactly where he was "
            "laid (15:40-47).",
    },
    16: {
        "Resurrection announcement":
            "The women find the tomb's stone already rolled away, and a young man inside tells them "
            "Jesus has been raised and goes before them to Galilee (16:1-7).",
        "Fear and astonishment":
            "The women flee the tomb trembling and say nothing to anyone, since fear overtakes them "
            "before any word of joy (16:8).",
        "Witness and proclamation":
            "In the KJV's longer ending, the risen Jesus appears first to Mary Magdalene and then to "
            "others, yet the disciples at first refuse to believe their report (16:9-15).",
        "Commission and exaltation":
            "Jesus commissions the disciples to preach the gospel to all creation before being "
            "received up into heaven to sit at God's right hand (16:15-20).",
    },
}


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "41_mark.json"
    data = load(path)
    for n in range(1, 17):
        key = f"Mark {n}"
        entry = data[key]
        entry["whereWeAre"] = WWA[n]
        for old, new in SUMMARY_FIXES.get(n, []):
            if old not in entry["summary"]:
                raise SystemExit(f"Mark {n}: summary fix not found: {old!r}")
            entry["summary"] = entry["summary"].replace(old, new)
        entry["keyFigures"] = [{"name": name, "role": role} for name, role in KEY_FIGURES[n]]
        theme_map = THEMES[n]
        seen = set()
        for theme in entry["keyThemes"]:
            name = theme["theme"]
            if name not in theme_map:
                raise SystemExit(f"Mark {n}: no explanation drafted for theme {name!r}")
            theme["explanation"] = theme_map[name]
            seen.add(name)
        missing = set(theme_map) - seen
        if missing:
            raise SystemExit(f"Mark {n}: drafted themes not in source: {missing}")
        if len(entry["keyFigures"]) > 6:
            raise SystemExit(f"Mark {n}: {len(entry['keyFigures'])} key figures (max 6)")
        if len(entry["whereWeAre"]) > 600:
            raise SystemExit(f"Mark {n}: whereWeAre is {len(entry['whereWeAre'])} characters (max 600)")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


AUDIENCE_FIXES = {
    3: ("Readers who knew how sharply Galileans, Judeans, and the mixed Gentile populations of "
        "Idumaea, the Transjordan, and Phoenician Tyre and Sidon were normally divided would have "
        "recognized how unusual it was for people from every one of those regions to converge on a "
        "single Galilean teacher."),
    4: ("Galilean fishermen among the first readers, who knew how suddenly storms could turn deadly "
        "on that same lake, would have felt the full shock of a teacher who could silence wind and "
        "water with nothing but a word."),
    6: ("Readers who knew Nazareth as Jesus' own small hometown would have felt the force of "
        "neighbors who had watched him grow up refusing to see him as anything more than Mary's son, "
        "the local carpenter."),
    8: ("Readers who already knew the feeding of the five thousand from chapter 6 would have "
        "recognized that a second, separate feeding of four thousand made the disciples' continuing "
        "confusion about bread even harder to excuse."),
    9: ("Readers familiar with Moses' own shining face after meeting God on a mountain (Exodus "
        "34:29-30) would have recognized Jesus' transfiguration as placing him in that same company, "
        "yet addressed by a voice that commanded them to listen to Jesus above Moses and Elijah "
        "both."),
    11: ("Pilgrims who knew Psalm 118's words of praise for one who comes in the Lord's name, and "
         "who knew the temple's outer court as the place licensed for trading and money-changing, "
         "would have recognized both the donkey entry and the overturned tables as deliberate, "
         "provocative claims rather than ordinary festival commotion."),
    12: ("Readers who knew that Pharisees and Herodians normally opposed each other politically, and "
         "that Pharisees and Sadducees disagreed sharply over resurrection, would have recognized "
         "how unusual it was for all these rival groups to unite against the same teacher in a "
         "single day in the temple."),
    13: ("Disciples who had just admired Herod's temple, one of the wonders of the Roman world, "
         "would have felt the full shock of being told that not one of its massive stones would be "
         "left standing, a warning Mark's first readers knew had already come true within living "
         "memory."),
}


def apply_chapter_context():
    path = ROOT / "chapter_context" / "32_mark.json"
    data = load(path)
    for n, new_audience in AUDIENCE_FIXES.items():
        key = f"Mark {n}"
        old_audience = data[key]["audience"]
        data[key]["audience"] = new_audience
        if old_audience == new_audience:
            raise SystemExit(f"Mark {n}: audience fix made no change")
    for entry in data["Mark 7"]["culture"]:
        if entry["title"] == "Corban":
            entry["text"] = entry["text"].replace(
                "Corban means ‘a gift’ dedicated to God.",
                "Corban means \"a gift\" dedicated to God.",
            )
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_historical_moments():
    path = ROOT / "historical_moments" / "14_matthew_mark.json"
    data = load(path)
    old = "Two days before Passover, Jesus is anointed at Bethany. He eats the Passover, goes to Gethsemane, and is arrested."
    new = "Two days before Passover, Jesus is anointed at Bethany. he eats the Passover, goes to Gethsemane, and is arrested."
    if data["Mark 14"] != old:
        raise SystemExit("Mark 14 historical moment text has changed since review")
    data["Mark 14"] = new
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


OVERVIEW_PRONOUN_FIXES = [
    ("Jesus' identity is revealed through authority, suffering, death, and resurrection; His "
     "followers are called to costly discipleship.",
     "Jesus' identity is revealed through authority, suffering, death, and resurrection; his "
     "followers are called to costly discipleship."),
    ("Mark moves quickly through Jesus' ministry, repeatedly asking who He really is.",
     "Mark moves quickly through Jesus' ministry, repeatedly asking who he really is."),
    ("A leading disciple who confesses Jesus as the Christ but denies Him during the trial.",
     "A leading disciple who confesses Jesus as the Christ but denies him during the trial."),
    ("A council member who boldly asks for Jesus' body and buries Him.",
     "A council member who boldly asks for Jesus' body and buries him."),
]


def apply_book_overview():
    path = ROOT / "book_overviews" / "07_gospels_acts.json"
    data = load(path)
    mark = data["Mark"]
    text = json.dumps(mark, ensure_ascii=False)
    for old, new in OVERVIEW_PRONOUN_FIXES:
        if old not in text:
            raise SystemExit(f"Mark overview: pronoun fix not found: {old!r}")
    mark["theme"] = mark["theme"].replace(*OVERVIEW_PRONOUN_FIXES[0])
    mark["summary"] = mark["summary"].replace(*OVERVIEW_PRONOUN_FIXES[1])
    for figure in mark["keyFigures"]:
        if figure["name"] == "Peter":
            figure["description"] = figure["description"].replace(*OVERVIEW_PRONOUN_FIXES[2])
        if figure["name"] == "Joseph of Arimathea":
            figure["description"] = figure["description"].replace(*OVERVIEW_PRONOUN_FIXES[3])
    if mark["keyVerse"] != "Mark 10:27":
        raise SystemExit("Mark keyVerse has changed since review")
    mark["keyVerse"] = "Mark 10:45"
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_PRONOUN_FIXES = [
    ('and demonstrates His authority through teaching and healing.',
     'and demonstrates his authority through teaching and healing.'),
    ('as opposition to His ministry grows.',
     'as opposition to his ministry grows.'),
    ('Jesus sends His disciples to preach, feeds thousands, walks upon the sea,',
     'Jesus sends his disciples to preach, feeds thousands, walks upon the sea,'),
    ("Jesus challenges His disciples' understanding, reveals His coming suffering, and teaches that following Him requires sacrifice.",
     "Jesus challenges his disciples' understanding, reveals his coming suffering, and teaches that following him requires sacrifice."),
    ('and commands His followers to remain watchful for His coming.',
     'and commands his followers to remain watchful for his coming.'),
    ('Judas betrays Him, and Jesus is arrested after sharing a final meal with His disciples.',
     'Judas betrays him, and Jesus is arrested after sharing a final meal with his disciples.'),
    ('while His followers witness the events surrounding His death.',
     'while his followers witness the events surrounding his death.'),
    ('As He comes up out of the water, He sees the heavens open',
     'As he comes up out of the water, he sees the heavens open'),
    ('the Spirit drives Him into the wilderness for forty days, where He is tempted by Satan',
     'the Spirit drives him into the wilderness for forty days, where he is tempted by Satan'),
    ('By the Sea of Galilee He calls Simon Peter and Andrew,',
     'By the Sea of Galilee he calls Simon Peter and Andrew,'),
    ("He heals Simon's mother-in-law of a fever, and that evening",
     "he heals Simon's mother-in-law of a fever, and that evening"),
    ('Then He moves on to other towns.',
     'Then he moves on to other towns.'),
    ('To show that He has authority to forgive sins, He tells the man to get up,',
     'To show that he has authority to forgive sins, he tells the man to get up,'),
    ('When asked why His disciples do not fast, He says wedding guests',
     'When asked why his disciples do not fast, he says wedding guests'),
    ('When Pharisees object to His disciples picking grain on the Sabbath, He answers,',
     'When Pharisees object to his disciples picking grain on the Sabbath, he answers,'),
    ("and Jesus' enemies watch to see if He will heal on the Sabbath.",
     "and Jesus' enemies watch to see if he will heal on the Sabbath."),
    ('supporters of King Herod, how to destroy Him.',
     'supporters of King Herod, how to destroy him.'),
    ('Back home, His own family thinks,',
     'Back home, his own family thinks,'),
    ('and comes to take Him away. Scribes from Jerusalem claim He casts out demons',
     'and comes to take him away. Scribes from Jerusalem claim he casts out demons'),
    ('When His mother and brothers arrive outside, He looks at those sitting around Him:',
     'When his mother and brothers arrive outside, he looks at those sitting around him:'),
    ('The terrified disciples wake Him:',
     'The terrified disciples wake him:'),
    ('He rebukes the wind and says to the sea,',
     'he rebukes the wind and says to the sea,'),
    ('Everything goes completely calm. He asks,',
     'Everything goes completely calm. he asks,'),
    ('touches His clothes from behind and is instantly healed. Jesus stops and asks who touched Him.',
     'touches his clothes from behind and is instantly healed. Jesus stops and asks who touched him.'),
    ('Trembling, she confesses, and He says,',
     'Trembling, she confesses, and he says,'),
    ('mourners laugh when He says she is only sleeping. He takes her hand and says,',
     'mourners laugh when he says she is only sleeping. he takes her hand and says,'),
    ('In His hometown, people are offended:',
     'In his hometown, people are offended:'),
    ('He sends the twelve out two by two,',
     'he sends the twelve out two by two,'),
    ('He teaches them, then has them sit in groups on the green grass.',
     'he teaches them, then has them sit in groups on the green grass.'),
    ('With five loaves and two fish He feeds five thousand men,',
     'With five loaves and two fish he feeds five thousand men,'),
    ('They scream, thinking He is a ghost, but He says,',
     'They scream, thinking he is a ghost, but he says,'),
    ('When He gets in the boat, the wind stops.',
     'When he gets in the boat, the wind stops.'),
    ('Pharisees complain that His disciples eat without the ritual washing of hands.',
     'Pharisees complain that his disciples eat without the ritual washing of hands.'),
    ('a Greek woman begs Him to free her daughter from a demon. When He tests her,',
     'a Greek woman begs him to free her daughter from a demon. When he tests her,'),
    ('Then He heals a deaf man with a speech problem,',
     'Then he heals a deaf man with a speech problem,'),
    ('and He refuses. In the boat He warns the disciples about',
     'and he refuses. In the boat he warns the disciples about'),
    ('but they think He is talking about bread.',
     'but they think he is talking about bread.'),
    ('At Bethsaida, He heals a blind man in two steps.',
     'At Bethsaida, he heals a blind man in two steps.'),
    ('Peter rebukes Him, and Jesus rebukes Peter:',
     'Peter rebukes him, and Jesus rebukes Peter:'),
    ('He calls the crowd and says,',
     'he calls the crowd and says,'),
    ('His clothes become shining,',
     'his clothes become shining,'),
    ('Elijah and Moses appear, talking with Him.',
     'Elijah and Moses appear, talking with him.'),
    ('Jesus drives out the spirit. Again He predicts His death, but the disciples do not understand.',
     'Jesus drives out the spirit. Again he predicts his death, but the disciples do not understand.'),
    ('Taking a child in His arms, He says that whoever welcomes such a child welcomes Him.',
     'Taking a child in his arms, he says that whoever welcomes such a child welcomes him.'),
    ('He warns that it would be better to cut off a hand or foot',
     'he warns that it would be better to cut off a hand or foot'),
    ('He takes them in His arms and blesses them.',
     'he takes them in his arms and blesses them.'),
    ('He says Moses allowed it only',
     'he says Moses allowed it only'),
    ('give to the poor, and follow Him.',
     'give to the poor, and follow him.'),
    ('The disciples are amazed, but He tells them,',
     'The disciples are amazed, but he tells them,'),
    ('and His followers are afraid. For the third time, He tells them He will be handed over, mocked, spit on, whipped, and killed, and that He will rise again.',
     'and his followers are afraid. For the third time, he tells them he will be handed over, mocked, spit on, whipped, and killed, and that he will rise again.'),
    ('James and John ask to sit at His right and left in His glory.',
     'James and John ask to sit at his right and left in his glory.'),
    ('Jesus tells them that among His followers, the leader must be a servant:',
     'Jesus tells them that among his followers, the leader must be a servant:'),
    ('He rides it into the city as crowds spread cloaks and branches on the road and shout,',
     'he rides it into the city as crowds spread cloaks and branches on the road and shout,'),
    ('The next day, He curses a fig tree that has leaves but no fruit. Then He enters the temple and drives out the buyers and sellers,',
     'The next day, he curses a fig tree that has leaves but no fruit. Then he enters the temple and drives out the buyers and sellers,'),
    ('The chief priests begin looking for a way to kill Him, because the people hang on His every word.',
     'The chief priests begin looking for a way to kill him, because the people hang on his every word.'),
    ('Jesus tells His disciples, “Have faith in God,”',
     'Jesus tells his disciples, “Have faith in God,”'),
    ('The religious leaders demand to know by what authority He acts. He tells a parable about tenant farmers',
     'The religious leaders demand to know by what authority he acts. he tells a parable about tenant farmers'),
    ('Next, Pharisees and Herodians try to trap Him about taxes. Holding a coin, He says,',
     'Next, Pharisees and Herodians try to trap him about taxes. Holding a coin, he says,'),
    ('Then He sits across from the temple treasury and watches people give.',
     'Then he sits across from the temple treasury and watches people give.'),
    ('Jesus calls His disciples:',
     'Jesus calls his disciples:'),
    ('ask Him privately when this will happen.',
     'ask him privately when this will happen.'),
    ('His followers will be beaten in synagogues',
     'his followers will be beaten in synagogues'),
    ('He will send His angels to gather His chosen people from the four winds.',
     'he will send his angels to gather his chosen people from the four winds.'),
    ('pours it on His head.',
     'pours it on his head.'),
    ('Then He takes bread, blesses it, and breaks it:',
     'Then he takes bread, blesses it, and breaks it:'),
    ('He gives them the cup:',
     'he gives them the cup:'),
    ('On the Mount of Olives, He tells them they will all fall away.',
     'On the Mount of Olives, he tells them they will all fall away.'),
    ('He falls to the ground and prays,',
     'he falls to the ground and prays,'),
    ('Three times He finds the disciples asleep.',
     'Three times he finds the disciples asleep.'),
    ('They seize Him, and all the disciples run away.',
     'They seize him, and all the disciples run away.'),
    ('They condemn Him to death, spit on Him, blindfold Him, and hit Him, saying,',
     'They condemn him to death, spit on him, blindfold him, and hit him, saying,'),
    ('the council ties Jesus up and hands Him to Pilate.',
     'the council ties Jesus up and hands him to Pilate.'),
    ('has Jesus whipped, and hands Him over to be crucified.',
     'has Jesus whipped, and hands him over to be crucified.'),
    ('twist a crown of thorns onto His head, and salute Him,',
     'twist a crown of thorns onto his head, and salute him,'),
    ('They beat Him and spit on Him.',
     'They beat him and spit on him.'),
    ('At Golgotha they offer Him wine mixed with myrrh, a drink to dull pain, but He refuses it.',
     'At Golgotha they offer him wine mixed with myrrh, a drink to dull pain, but he refuses it.'),
    ('when they crucify Him. They gamble for His clothes, and the sign over Him reads,',
     'when they crucify him. They gamble for his clothes, and the sign over him reads,'),
    ('Two thieves are crucified with Him.',
     'Two thieves are crucified with him.'),
    ('After another loud cry, He breathes His last,',
     'After another loud cry, he breathes his last,'),
    ('The centurion standing in front of the cross sees how He died',
     'The centurion standing in front of the cross sees how he died'),
    ('Mary Magdalene and Mary the mother of Joses see where He is laid.',
     'Mary Magdalene and Mary the mother of Joses see where he is laid.'),
    ('He then appears to two followers walking in the country, and finally to the eleven as they eat. He scolds them for their unbelief',
     'he then appears to two followers walking in the country, and finally to the eleven as they eat. he scolds them for their unbelief'),
    ('demonstrating His authority through teaching, healing, and deliverance. It follows Him through growing opposition, His willing suffering, and His death upon the cross.',
     'demonstrating his authority through teaching, healing, and deliverance. It follows him through growing opposition, his willing suffering, and his death upon the cross.'),
    ('extends outward through His followers, who are sent to proclaim the good news.',
     'extends outward through his followers, who are sent to proclaim the good news.'),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "07_gospels_acts.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("# Mark")
    end = text.index("# Luke")
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
    apply_historical_moments()
    apply_book_overview()
    apply_story_fixes()
