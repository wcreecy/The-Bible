#!/usr/bin/env python3
"""Apply the completed editorial review for Matthew chapters 21-28 to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


WWA = {
    21: ("Chapter 20 ended with Jesus healing two blind men outside Jericho on the way to Jerusalem "
         "(Matthew 20:29-34). Chapter 21 arrives: Jesus enters the city riding a donkey as crowds shout "
         "praise, drives the money changers from the temple, curses a fruitless fig tree, and is "
         "challenged by temple authorities demanding to know by what authority he acts. His parables of "
         "two sons and wicked tenants warn that professed loyalty without action is worthless, a charge "
         "that provokes even sharper questioning in chapter 22's string of trap questions."),
    22: ("Chapter 21 ended with religious leaders recognizing that Jesus' parables were aimed directly "
         "at them (Matthew 21:45-46). Chapter 22 shows them striking back with a series of trap "
         "questions: Pharisees and Herodians ask about paying tax to Caesar, Sadducees challenge "
         "resurrection with a marriage scenario, and a lawyer asks which commandment is greatest. Jesus "
         "answers every question and then turns a question back on them about the Messiah's identity, "
         "silencing his questioners and setting up chapter 23's direct, public confrontation with the "
         "same scribes and Pharisees."),
    23: ("Chapter 22 ended with no one daring to ask Jesus another question after his answers silenced "
         "every trap (Matthew 22:46). Chapter 23 turns from defense to direct confrontation: Jesus warns "
         "the crowds and his disciples against scribes and Pharisees who say the right things without "
         "doing them, pronounces a series of woes against their hypocrisy, and closes with grief over "
         "Jerusalem's history of rejecting its own prophets. That lament over the city and its temple "
         "sets up chapter 24's prediction that the temple itself will soon be destroyed."),
    24: ("Chapter 23 ended with Jesus grieving over Jerusalem's refusal to be gathered like a hen "
         "gathers her chicks (Matthew 23:37-39). Chapter 24 explains what is coming: leaving the temple, "
         "Jesus predicts its destruction, and on the Mount of Olives answers the disciples' questions "
         "about timing with warnings about deceivers, persecution, and cosmic upheaval before "
         "describing the Son of Man's coming. Parables about a fig tree, Noah's flood, and a returning "
         "master all press the same point, readiness amid uncertain timing, which chapter 25's three "
         "parables develop further."),
    25: ("Chapter 24 warned that no one knows the day or hour of the Son of Man's return, so readiness "
         "cannot wait for a warning sign (Matthew 24:36-44). Chapter 25 develops that same readiness in "
         "three scenes: five bridesmaids are shut out for being unprepared, a servant is condemned for "
         "burying rather than using what was entrusted to him, and the Son of Man separates all nations "
         "based on how they treated the hungry, the stranger, and the imprisoned. That picture of a "
         "coming final judgment closes Jesus' public teaching and sets up chapter 26's account of his "
         "own arrest and trial."),
    26: ("Chapter 25 closed Jesus' public teaching with a vision of final judgment based on how people "
         "treated the vulnerable (Matthew 25:31-46). Chapter 26 turns to his own arrest: as Passover "
         "approaches, a woman anoints Jesus for burial even as Judas arranges to betray him, Jesus "
         "shares a last Passover meal and reinterprets its bread and cup around his own body and blood, "
         "and prays in anguish at Gethsemane while his disciples sleep. Judas's arrival with an armed "
         "crowd, Jesus' questioning before Caiaphas, and Peter's three denials set up chapter 27's trial "
         "before Pilate and crucifixion."),
    27: ("Chapter 26 ended with Peter denying Jesus three times and weeping bitterly (Matthew "
         "26:69-75). Chapter 27 carries Jesus from that same night into his execution: Judas returns the "
         "betrayal money and dies in despair, Pilate yields to the crowd's demand and releases Barabbas "
         "instead of Jesus, and Jesus is mocked, crucified, and dies with the temple veil torn in two. "
         "Joseph of Arimathea buries him in a borrowed tomb while women watch, setting up chapter 28's "
         "discovery that the tomb is empty."),
    28: ("Chapter 27 ended with Jesus' body sealed in a borrowed tomb and guards set to watch it "
         "(Matthew 27:62-66). Matthew's closing chapter answers that sealed tomb directly: an "
         "earthquake, an angel, and the risen Jesus himself meet the women first, while the guards' "
         "report leads the chief priests to pay for a cover story instead of believing it. The Gospel "
         "ends on a mountain in Galilee, where Jesus claims all authority and sends the eleven to make "
         "disciples of every nation, promising to be with them always, a commission the rest of the New "
         "Testament will show being carried out."),
}

SUMMARY_FIXES = {
    24: [
        ("Interpretation of how these statements relate to Jerusalem's fall and future events is "
         "vigorously debated.",
         "Jesus ties these statements to both Jerusalem's coming fall and his own future return, "
         "without giving a precise timetable for either."),
    ],
}

KEY_FIGURES = {
    21: [
        ("Jesus",
         "Enters Jerusalem on a donkey to shouting crowds, drives sellers and buyers from the temple, "
         "heals the blind and lame there, curses a fruitless fig tree, and answers a challenge to his "
         "authority with parables of two sons and wicked tenants (21:1-46)."),
        ("disciples",
         "Sent ahead to bring the donkey and colt Jesus rides into Jerusalem, fulfilling Zechariah's "
         "prophecy of a humble king (21:1-7)."),
        ("Jerusalem crowds",
         "Spread garments and branches before Jesus and shout \"Hosanna to the son of David,\" then are "
         "described by Jesus as the reason the Pharisees cannot arrest him outright (21:8-11,46)."),
        ("chief priests and elders",
         "Challenge Jesus in the temple to name the authority behind his actions, then recognize that "
         "his parables of the two sons and wicked tenants are aimed directly at them (21:23-27,45)."),
        ("children in temple",
         "Continue shouting \"Hosanna to the son of David\" in the temple, prompting indignant chief "
         "priests and Jesus' own reply quoting the psalm about praise from children (21:15-16)."),
        ("parable sons and tenants",
         "Fictional figures in Jesus' parables of the two sons and the wicked tenants, illustrating "
         "that professed obedience is empty without matching action and that rejecting God's "
         "messengers brings real consequences (21:28-41)."),
    ],
    22: [
        ("Jesus",
         "Tells the parable of the king's wedding feast, answers whether paying tax to Caesar is "
         "lawful, defends resurrection against the Sadducees, names love of God and neighbor as the "
         "greatest commandment, and questions his critics' own understanding of the Messiah "
         "(22:1-46)."),
        ("Pharisees (with Herodians)",
         "Send disciples along with Herodians to trap Jesus over paying tribute to Caesar, and are "
         "later silenced by Jesus' question about whose son the Christ is (22:15-22,41-46)."),
        ("Sadducees",
         "Pose a hypothetical marriage scenario to challenge belief in the resurrection, and are "
         "answered by Jesus from the Scriptures they themselves accepted (22:23-33)."),
        ("disciples",
         "Present as Jesus teaches in the temple through this sequence of hostile questions from "
         "Pharisees, Sadducees, and a lawyer (22:1,34-40)."),
        ("parable king and wedding guests",
         "Fictional figures in Jesus' parable of the wedding feast, illustrating how invited guests who "
         "refuse God's invitation are replaced by others who accept it (22:2-14)."),
        ("David (scriptural figure discussed)",
         "Cited by Jesus from Psalm 110 to question how the Messiah can be merely David's son if David "
         "himself calls him Lord (22:41-45)."),
    ],
    23: [
        ("Jesus",
         "Warns crowds and disciples against scribes and Pharisees who do not practice what they "
         "teach, pronounces a series of woes against their hypocrisy, and closes grieving over "
         "Jerusalem's rejection of its prophets (23:1-39)."),
        ("crowds",
         "Addressed alongside the disciples as Jesus warns them not to follow the example of the "
         "scribes and Pharisees even while respecting their formal teaching role (23:1-3)."),
        ("disciples",
         "Hear Jesus' warning against seeking titles and public honor the way the scribes and Pharisees "
         "do (23:1,8-12)."),
        ("scribes",
         "Named throughout the chapter's seven woes alongside the Pharisees for hypocrisy, for tithing "
         "herbs while neglecting justice, and for honoring dead prophets their own ancestors killed "
         "(23:13-36)."),
        ("Pharisees",
         "Named throughout the chapter's seven woes alongside the scribes for straining at a gnat while "
         "swallowing a camel and for cleaning the outside of the cup while leaving the inside full of "
         "greed (23:13-36)."),
        ("Jerusalem's inhabitants",
         "The object of Jesus' closing lament, pictured as chicks he longed to gather who were not "
         "willing, left desolate until they welcome the one who comes in the Lord's name (23:37-39)."),
    ],
    24: [
        ("Jesus",
         "Predicts the temple's destruction, answers the disciples' questions about the end of the age "
         "with warnings against deception and a description of his own coming as the Son of Man, and "
         "closes with parables urging readiness (24:1-51)."),
        ("disciples",
         "Ask Jesus privately on the Mount of Olives when the temple will fall and what sign will mark "
         "his coming and the end of the age (24:3)."),
        ("false messiahs and prophets (warned about)",
         "Claimants Jesus warns his followers not to trust, since many will come in his name performing "
         "great signs to deceive even the elect if possible (24:4-5,11,23-26)."),
        ("servants in parables",
         "Fictional figures in Jesus' parables of the faithful and abusive servants, illustrating the "
         "difference between readiness and presumption while a master's return is delayed (24:45-51)."),
    ],
    25: [
        ("Jesus",
         "Tells three parables about accountability before his return as the Son of Man: ten "
         "bridesmaids waiting for a bridegroom, a master entrusting money to servants, and a final "
         "separation of all nations based on how they treated the needy (25:1-46)."),
        ("disciples",
         "Continue hearing Jesus' private teaching on the Mount of Olives begun in chapter 24, now in "
         "parable form (25:1)."),
        ("bridesmaids, bridegroom, master and servants (parable figures)",
         "Fictional figures in Jesus' parables of the ten bridesmaids and the entrusted money, "
         "illustrating preparedness and faithful use of what one has been given (25:1-30)."),
        ("the nations",
         "Gathered before the Son of Man and separated like sheep from goats based on how they treated "
         "the hungry, the stranger, and the imprisoned (25:31-33,41-46)."),
        ("the needy",
         "The hungry, thirsty, stranger, naked, sick, and imprisoned whose treatment the Son of Man "
         "identifies directly with treatment of himself (25:35-36,42-43)."),
    ],
    26: [
        ("Jesus",
         "Is anointed for burial at Bethany, shares a final Passover meal reinterpreting its bread and "
         "cup around his own body and blood, prays in anguish at Gethsemane, and is arrested, "
         "questioned, and condemned by the council (26:1-68)."),
        ("disciples",
         "Share the Passover meal where Jesus identifies a betrayer among them, fall asleep while Jesus "
         "prays at Gethsemane, and scatter when he is arrested after one of them strikes off the ear of "
         "the high priest's servant (26:17-20,36-46,51,56)."),
        ("Judas Iscariot",
         "Arranges to betray Jesus for money, identifies him with a kiss, and arrives at Gethsemane "
         "with an armed crowd sent by the chief priests and elders (26:14-16,47-49)."),
        ("Peter",
         "Insists he will never deny Jesus, falls asleep at Gethsemane despite being asked to watch, "
         "and denies knowing Jesus three times before weeping bitterly (26:33-35,40-41,69-75)."),
        ("woman at Bethany",
         "Anoints Jesus with costly ointment, an act Jesus defends as preparation for his burial "
         "despite the disciples' objection to the cost (26:6-13)."),
        ("Caiaphas",
         "High priest who presides over the council that plots Jesus' death and later questions him, "
         "tearing his own clothes and declaring Jesus guilty of blasphemy (26:3-4,57-66)."),
    ],
    27: [
        ("Jesus",
         "Is handed to Pilate, scourged, mocked, crucified between two criminals, and dies with the "
         "temple veil torn in two, before being buried in a borrowed tomb (27:1-61)."),
        ("Pontius Pilate",
         "Questions Jesus, offers the crowd a choice between Jesus and the prisoner Barabbas, who is "
         "released, and orders Jesus crucified after washing his hands of responsibility (27:11-26)."),
        ("Judas Iscariot",
         "Regrets betraying Jesus once he is condemned, returns the thirty pieces of silver, and hangs "
         "himself, after which the money is used to buy a potter's field (27:3-10)."),
        ("chief priests and elders",
         "Persuade the crowd to ask for Barabbas instead of Jesus, mock Jesus at the cross, and later "
         "secure Pilate's permission to guard his tomb (27:20,41-43,62-66)."),
        ("Roman soldiers",
         "Mock Jesus with a robe and crown of thorns, compel Simon of Cyrene to carry his cross, cast "
         "lots for his garments, and keep watch at the crucifixion and later at the sealed tomb "
         "(27:27-37,54,65-66)."),
        ("Joseph of Arimathea and the women",
         "Joseph asks Pilate for Jesus' body and lays it in his own new tomb, while Mary Magdalene and "
         "the other women watch from a distance and remain sitting opposite the tomb (27:57-61)."),
    ],
    28: [
        ("Jesus",
         "Meets the women after his resurrection, is worshiped by them, and later meets the eleven on "
         "a mountain in Galilee, claiming all authority and commissioning them to make disciples of all "
         "nations (28:9-20)."),
        ("Mary Magdalene and the other Mary",
         "Visit the tomb after the Sabbath, are told by an angel that Jesus has risen, and then meet "
         "Jesus himself, who sends them to tell the disciples to go to Galilee (28:1-10)."),
        ("angel",
         "Descends with an earthquake, rolls back the stone, and announces to the women that Jesus has "
         "been raised just as he said (28:2-7)."),
        ("guards",
         "Shake with fear at the angel's appearance, then report the events to the chief priests rather "
         "than to the disciples (28:4,11)."),
        ("chief priests and elders",
         "Pay the guards to spread a false report that the disciples stole Jesus' body while they slept "
         "(28:12-15)."),
        ("the eleven disciples",
         "Go to the mountain in Galilee Jesus directed them to, worship him there, and receive his "
         "commission to make disciples of all nations (28:16-20)."),
    ],
}

THEMES = {
    21: {
        "Humble kingship":
            "Jesus enters Jerusalem on a donkey rather than a warhorse, deliberately fulfilling "
            "Zechariah's image of a humble king while crowds shout the same words sung to pilgrims "
            "entering the temple (21:1-11).",
        "Fruitful worship and justice":
            "Jesus drives out those buying and selling in the temple and curses a fig tree full of "
            "leaves but no fruit, pairing both acts as judgment on religious life that looks flourishing "
            "but produces nothing real (21:12-22).",
        "Authority and response":
            "When temple authorities demand to know by what authority Jesus acts, his parables of two "
            "sons and wicked tenants answer that professed obedience means nothing without the actions "
            "to back it up (21:23-46).",
    },
    22: {
        "Responding to God's invitation":
            "In the parable of the wedding feast, those first invited refuse to come, so the king sends "
            "for anyone found, making the invitation itself, not an exclusive guest list, the point of "
            "the story (22:1-14).",
        "Divine and civic claims":
            "Asked whether paying tax to Caesar is lawful, Jesus says to give Caesar what bears his "
            "image and God what bears God's, refusing to let the trap force a simple yes or no "
            "(22:15-22).",
        "Love as the law's center":
            "Asked which commandment is greatest, Jesus names love of God and love of neighbor "
            "together, saying the whole law and the prophets hang on those two (22:34-40).",
    },
    23: {
        "Practice rather than performance":
            "Jesus says the scribes and Pharisees say the right things but do not practice them, "
            "loading burdens on others while seeking public recognition for themselves (23:1-12).",
        "Justice, mercy and faithfulness":
            "Jesus accuses his critics of tithing even garden herbs while neglecting the weightier "
            "matters of the law, justice, mercy, and faithfulness (23:23-28).",
        "Prophetic lament":
            "Jesus closes by grieving over Jerusalem's history of killing its own prophets, picturing "
            "himself as a hen longing to gather chicks that were not willing (23:37-39).",
    },
    24: {
        "Discernment amid crisis":
            "Jesus warns that false messiahs, wars, and disasters will come but tells his disciples not "
            "to be deceived into thinking any of it automatically signals the end (24:4-14,23-26).",
        "Judgment and hope":
            "A desolating sacrilege and severe distress are followed by the Son of Man's visible coming "
            "to gather his elect, joining real danger with a real promise of rescue (24:15-31).",
        "Watchful faithfulness":
            "The parables of the thief in the night and the faithful versus abusive servant both make "
            "the same point: readiness, not calculating the exact timing, is what matters (24:36-51).",
    },
    25: {
        "Preparedness":
            "Five bridesmaids run out of oil and are shut out of the wedding, showing that waiting "
            "itself is not enough without being ready for a delay (25:1-13).",
        "Faithful stewardship":
            "A servant who buries his master's money out of fear is condemned, while those who put what "
            "they were given to use are rewarded, tying faithfulness to active use rather than mere "
            "safekeeping (25:14-30).",
        "Care and judgment":
            "The Son of Man separates the nations based on whether they fed, clothed, and visited the "
            "hungry, the stranger, and the imprisoned, calling that treatment of the needy treatment of "
            "himself (25:31-46).",
    },
    26: {
        "Self-giving covenant language":
            "At the Passover table, Jesus calls the bread his body and the cup his blood of the "
            "covenant, reinterpreting the meal around his own coming death (26:26-29).",
        "Prayer amid anguish":
            "In Gethsemane, Jesus prays three times for the cup to pass while submitting to the "
            "Father's will, modeling honest anguish held together with obedience (26:36-46).",
        "Human failure and courage":
            "Judas betrays Jesus for money and Peter denies him three times, yet the chapter also "
            "includes a woman who anoints Jesus for burial before anyone else sees what is coming "
            "(26:6-16,69-75).",
    },
    27: {
        "Political and religious responsibility":
            "Pilate washes his hands of responsibility while still ordering the crucifixion, and the "
            "chief priests press for Jesus' death while using the very money that paid for it to buy a "
            "field, both claiming innocence while acting decisively (27:11-26).",
        "Suffering and apparent defeat":
            "Jesus is mocked, crucified between two criminals, and taunted to save himself, while "
            "darkness and a torn temple veil accompany his death (27:27-54).",
        "Witness and burial":
            "Joseph of Arimathea provides a tomb and women watch where Jesus is laid, naming "
            "eyewitnesses to both his death and burial before the resurrection is even announced "
            "(27:55-66).",
    },
    28: {
        "Resurrection proclamation":
            "An angel announces that Jesus has been raised before the women ever see him themselves, "
            "and Jesus then meets them in person and confirms the message (28:1-10).",
        "Conflicting public explanations":
            "The guards' honest report of what happened is paid off into a cover story that the "
            "disciples stole the body, setting two competing explanations of the empty tomb side by "
            "side (28:11-15).",
        "Worldwide discipleship":
            "Jesus claims all authority in heaven and earth and sends the eleven to make disciples of "
            "all nations, expanding a mission that had been directed to Israel first into one for the "
            "whole world (28:16-20).",
    },
}


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "40_matthew.json"
    data = load(path)
    for n in range(21, 29):
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
    21: ("Pilgrims who knew Zechariah's prophecy of a king coming on a donkey, and who knew the temple "
         "courts as the place for licensed money-changing and sacrifice-selling, would have recognized "
         "both actions, the donkey entry and the overturned tables, as deliberate prophetic claims "
         "rather than a thoughtless commotion."),
    22: ("Readers who knew that Pharisees and Herodians normally opposed each other politically, and "
         "that Pharisees and Sadducees disagreed sharply on resurrection, would have recognized how "
         "unusual it was for all three groups to set aside their own disagreements just to unite "
         "against Jesus in the same afternoon."),
    24: ("Disciples who had just admired the temple's massive stones would have felt the full shock of "
         "Jesus predicting that not one would be left standing, the same temple whose destruction forty "
         "years later would confirm, for Matthew's first readers, that this specific warning had "
         "already come true."),
    25: ("Readers familiar with wedding customs, where a bridegroom's arrival time was genuinely "
         "unpredictable, or with how a household entrusted capital to servants while an owner traveled, "
         "would have recognized ordinary social practices being used to describe something that cannot "
         "be prepared for at the last minute."),
    27: ("Readers who knew that Rome reserved crucifixion for slaves, rebels, and the worst criminals "
         "would have felt the full weight of the charge nailed above Jesus' head, \"THE KING OF THE "
         "JEWS,\" as both a mockery and, in Matthew's own telling, a truth stated by his executioners "
         "without their intending it."),
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
    for entry in data["Matthew 26"]["culture"]:
        if entry["title"] == "Caiaphas":
            entry["text"] = entry["text"].replace(
                "An ossuary inscribed ‘Joseph son of Caiaphas’ was found in Jerusalem in 1990.",
                "An ossuary inscribed with the name ‘Joseph son of Caiaphas’ was found in Jerusalem "
                "in 1990.",
            )
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_PRONOUN_FIXES = [
    ("He enters the temple and throws out the money changers and those selling animals, saying,",
     "he enters the temple and throws out the money changers and those selling animals, saying,"),
    ("He heals the blind and lame, and children cry out “Hosanna” in the temple. The next morning, "
     "He curses a fig tree with leaves but no fruit, and it withers.",
     "he heals the blind and lame, and children cry out “Hosanna” in the temple. The next morning, "
     "he curses a fig tree with leaves but no fruit, and it withers."),
    ("Jesus answers with a question about John's baptism that they refuse to answer. Then He tells "
     "parables aimed at them.",
     "Jesus answers with a question about John's baptism that they refuse to answer. Then he tells "
     "parables aimed at them."),
    ("His opponents try to trap Him with questions.",
     "His opponents try to trap him with questions."),
    ("After that, no one dares ask Him anything more.",
     "After that, no one dares ask him anything more."),
    ("Seven times He says, “Woe unto you, scribes and Pharisees, hypocrites!”",
     "Seven times he says, “Woe unto you, scribes and Pharisees, hypocrites!”"),
    ("Then His anger turns to grief:",
     "Then his anger turns to grief:"),
    ("Jesus foretells coming distress and judgment, urging His followers to remain watchful, "
     "faithful, and prepared for His return.",
     "Jesus foretells coming distress and judgment, urging his followers to remain watchful, "
     "faithful, and prepared for his return."),
    ("the disciples ask when it will happen and what will signal His return and the end of the age.",
     "the disciples ask when it will happen and what will signal his return and the end of the age."),
    ("famines, earthquakes, and persecution. “But he that shall endure unto the end, the same shall "
     "be saved. And this gospel of the kingdom shall be preached in all the world.” He warns of "
     "“the abomination of desolation,",
     "famines, earthquakes, and persecution. “But he that shall endure unto the end, the same shall "
     "be saved. And this gospel of the kingdom shall be preached in all the world.” he warns of "
     "“the abomination of desolation,"),
    ("So His followers must be ready.",
     "So his followers must be ready."),
    ("Finally, Jesus describes the last judgment. The Son of man will sit on His throne and separate "
     "the nations “as a shepherd divideth his sheep from the goats.” To those on His right He says,",
     "Finally, Jesus describes the last judgment. The Son of man will sit on his throne and separate "
     "the nations “as a shepherd divideth his sheep from the goats.” To those on his right he says,"),
    ("They ask when they ever did this, and He answers,",
     "They ask when they ever did this, and he answers,"),
    ("As religious leaders plot His death, Jesus shares a final meal with His disciples,",
     "As religious leaders plot his death, Jesus shares a final meal with his disciples,"),
    ("but Jesus says she has prepared His body for burial:",
     "but Jesus says she has prepared his body for burial:"),
    ("Then Jesus takes bread, blesses it, and says, “Take, eat; this is my body.” He takes the cup:",
     "Then Jesus takes bread, blesses it, and says, “Take, eat; this is my body.” he takes the cup:"),
    ("In the garden of Gethsemane, Jesus says, “My soul is exceeding sorrowful, even unto death.” He "
     "falls on His face and prays,",
     "In the garden of Gethsemane, Jesus says, “My soul is exceeding sorrowful, even unto death.” he "
     "falls on his face and prays,"),
    ("Three times He returns to find His disciples asleep:",
     "Three times he returns to find his disciples asleep:"),
    ("They spit in His face and beat Him.",
     "They spit in his face and beat him."),
    ("In the morning they bind Jesus and hand Him over to Pontius Pilate,",
     "In the morning they bind Jesus and hand him over to Pontius Pilate,"),
    ("Pilate asks Jesus, “Art thou the King of the Jews?” and Jesus says, “Thou sayest,” but He does "
     "not answer the other charges.",
     "Pilate asks Jesus, “Art thou the King of the Jews?” and Jesus says, “Thou sayest,” but he does "
     "not answer the other charges."),
    ("He has Jesus scourged, or whipped, and hands Him over to be crucified.",
     "He has Jesus scourged, or whipped, and hands him over to be crucified."),
    ("Jesus is crucified and buried, but on the third day His tomb is found empty, and His "
     "resurrection is announced.",
     "Jesus is crucified and buried, but on the third day his tomb is found empty, and his "
     "resurrection is announced."),
    ("press a crown of thorns onto His head, and put a reed in His hand as a fake scepter.",
     "press a crown of thorns onto his head, and put a reed in his hand as a fake scepter."),
    ("They kneel and mock Him, “Hail, King of the Jews!” Then they spit on Him and beat Him on the "
     "head.",
     "They kneel and mock him, “Hail, King of the Jews!” Then they spit on him and beat him on the "
     "head."),
    ("they force a man named Simon of Cyrene to carry His cross. At Golgotha, “a place of a skull,” "
     "they crucify Him between two thieves and gamble for His clothes. Above His head they post the "
     "charge:",
     "they force a man named Simon of Cyrene to carry his cross. At Golgotha, “a place of a skull,” "
     "they crucify him between two thieves and gamble for his clothes. Above his head they post the "
     "charge:"),
    ("These are the first words of Psalm 22. He cries out again and “yielded up the ghost.”",
     "These are the first words of Psalm 22. he cries out again and “yielded up the ghost.”"),
    ("The chief priests remember that Jesus said He would rise after three days,",
     "The chief priests remember that Jesus said he would rise after three days,"),
    ("As they run to tell the disciples, Jesus Himself meets them, and they take hold of His feet "
     "and worship Him.",
     "As they run to tell the disciples, Jesus himself meets them, and they take hold of his feet "
     "and worship him."),
    ("The risen Jesus meets His disciples in Galilee and commands them to make disciples throughout "
     "the world, promising His continuing presence.",
     "The risen Jesus meets his disciples in Galilee and commands them to make disciples throughout "
     "the world, promising his continuing presence."),
    ("The eleven disciples go to the mountain in Galilee where Jesus told them to meet Him.",
     "The eleven disciples go to the mountain in Galilee where Jesus told them to meet him."),
    ("Matthew begins by tracing Jesus to Abraham and David, placing Him within God's promises to "
     "Israel. It closes with the risen Jesus claiming authority over heaven and earth and extending "
     "His mission to every nation. The One introduced as Emmanuel, meaning God with us, sends His "
     "followers into the world with the assurance that His presence will continue with them.",
     "Matthew begins by tracing Jesus to Abraham and David, placing him within God's promises to "
     "Israel. It closes with the risen Jesus claiming authority over heaven and earth and extending "
     "his mission to every nation. The One introduced as Emmanuel, meaning God with us, sends his "
     "followers into the world with the assurance that his presence will continue with them."),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "07_gospels_acts.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("The King Enters Jerusalem and Confronts Its Leaders")
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
