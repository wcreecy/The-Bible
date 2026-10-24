#!/usr/bin/env python3
"""Apply the completed editorial review for Acts to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


WWA = {
    1: ("John's Gospel closed with a note that Jesus did far more than any book could contain "
        "(John 21:24-25). Acts opens as Luke's second volume to Theophilus, picking up exactly "
        "where that Gospel left off: the risen Jesus spends forty days instructing the apostles, "
        "promises the Holy Spirit, and ascends from the Mount of Olives, after which the waiting "
        "believers choose Matthias to replace Judas among the Twelve (1:1-26). That waiting, "
        "prayerful community sets up chapter 2's sudden answer to their wait, the Spirit's arrival "
        "at Pentecost."),
    2: ("Chapter 1 ended with the apostles completing their number by choosing Matthias, then "
        "waiting in Jerusalem (1:26). Chapter 2 answers that wait: the Holy Spirit falls on the "
        "gathered believers at Pentecost, they speak in languages understood by pilgrims from many "
        "nations, and Peter's sermon leads about three thousand people to repent, be baptized, and "
        "join a community marked by shared teaching, fellowship, and meals (2:1-47). That new "
        "community's visible unity sets up chapter 3's first public miracle done in its midst."),
    3: ("Chapter 2 ended with the Lord adding to the young church daily (2:47). Chapter 3 shows "
        "that growth continuing through a public sign: Peter heals a man lame from birth at the "
        "temple gate, then uses the crowd's astonishment to preach Jesus as the one Israel's own "
        "prophets had pointed toward all along (3:1-26). That same temple setting and message bring "
        "the apostles their first arrest in chapter 4."),
    4: ("Chapter 3 ended with Peter calling the temple crowd to repent and turn to God (3:19-26). "
        "Chapter 4 shows the cost of that call: temple authorities arrest Peter and John, the "
        "council threatens them but cannot deny the healing everyone has seen, and the released "
        "believers pray for boldness before sharing their resources so generously that Barnabas "
        "becomes a named example (4:1-37). That same generosity is tested by its opposite in "
        "chapter 5's account of Ananias and Sapphira."),
    5: ("Chapter 4 ended with believers selling property and laying the proceeds at the apostles' "
        "feet, Barnabas's gift named as one example (4:34-37). Chapter 5 shows a darker version of "
        "that same generosity: Ananias and Sapphira lie about what they gave and both die, while "
        "the apostles themselves are arrested again, freed by an angel, and flogged, yet continue "
        "teaching about Jesus despite the council's and Gamaliel's warnings (5:1-42). That same "
        "growing community now needs its first organized leadership structure, which chapter 6 "
        "provides."),
    6: ("Chapter 5 ended with the apostles rejoicing that they were counted worthy to suffer for "
        "Jesus' name (5:41-42). Chapter 6 shows the community handling a quieter kind of strain: "
        "Greek-speaking widows are being overlooked in the daily food distribution, so the apostles "
        "have the community choose seven reputable men, including Stephen, to oversee the need "
        "while the Twelve focus on prayer and teaching (6:1-7). Stephen's own gifts then draw "
        "opposition that chapter 7 follows all the way to his death."),
    7: ("Chapter 6 ended with opponents who could not out-argue Stephen instead bringing false "
        "accusations against him before the council (6:9-15). Chapter 7 gives Stephen's own answer: "
        "a long retelling of Israel's history arguing that God's presence was never confined to one "
        "building, followed by a direct accusation that his hearers resist the Holy Spirit the way "
        "their ancestors always had, a charge that ends with the enraged crowd stoning him while a "
        "young man named Saul looks on approvingly (7:1-60). That persecution breaks fully open in "
        "chapter 8, scattering believers out of Jerusalem."),
    8: ("Chapter 7 ended with Saul approving of Stephen's killing (7:58-60). Chapter 8 shows the "
        "persecution Saul helps lead scattering believers out of Jerusalem instead of silencing "
        "them: Philip preaches in Samaria and confronts a magician named Simon who tries to buy "
        "spiritual power, then is sent to explain Isaiah to an Ethiopian court official on a desert "
        "road and baptizes him (8:1-40). That gospel reaching unexpected people continues directly "
        "in chapter 9, where the persecutor himself is confronted by Jesus."),
    9: ("Chapter 8 ended with the Ethiopian official going on his way rejoicing after his baptism "
        "(8:39-40). Chapter 9 turns to the persecutor behind so much of that scattering: Saul is "
        "blinded and converted on the road to Damascus, Ananias overcomes his fear to restore his "
        "sight, and Peter's own ministry continues with the healing of Aeneas and the raising of "
        "Tabitha from death (9:1-43). Peter's stay in Joppa at the chapter's end sets up chapter "
        "10's vision that sends him to a Gentile household."),
    10: ("Chapter 9 ended with Peter staying many days in Joppa with a tanner named Simon (9:43). "
         "Chapter 10 picks up right there: an angel directs the centurion Cornelius to send for "
         "Peter, a vision teaches Peter not to call any person unclean, and while he is still "
         "preaching in Cornelius's house the Holy Spirit falls on these Gentile listeners just as it "
         "had on the believers at Pentecost (10:1-48). That unprecedented event needs defending "
         "back in Jerusalem, which chapter 11 shows Peter doing."),
    11: ("Chapter 10 ended with Peter staying several days with Cornelius after baptizing his "
         "Gentile household (10:48). Chapter 11 shows Peter defending that decision in Jerusalem, "
         "explaining his vision until the critics fall silent and praise God for granting Gentiles "
         "life too, while believers scattered by persecution plant a thriving, mixed congregation "
         "in Antioch, where the disciples are first called Christians and a prophesied famine "
         "prompts the believers to send relief to Judea (11:1-30). That relief effort, carried by "
         "Barnabas and Saul, sets up chapter 12's return of persecution under Herod."),
    12: ("Chapter 11 ended with Barnabas and Saul carrying famine relief from Antioch to Judea's "
         "believers (11:27-30). Chapter 12 shows the danger they are stepping back into: Herod "
         "Agrippa kills James and imprisons Peter, who is freed by an angel and surprises the "
         "praying believers at Mary's house, while Herod himself dies after accepting worship as a "
         "god (12:1-23). The word of God continuing to grow despite that death leads into chapter "
         "13's sending of Barnabas and Saul on a mission of their own."),
    13: ("Chapter 12 ended with the word of God growing and multiplying even after Herod's death, "
         "as Barnabas and Saul returned to Antioch (12:24-25). Chapter 13 shows the Antioch church "
         "sending that same pair out further: the Holy Spirit sets apart Barnabas and Saul, now "
         "called Paul, for a mission that confronts a sorcerer on Cyprus and preaches in a Pisidian "
         "synagogue, where Jewish opposition leads Paul and Barnabas to declare that they will turn "
         "to the Gentiles instead (13:1-52). That turn to Gentile hearers continues through "
         "persecution in chapter 14."),
    14: ("Chapter 13 ended with Paul and Barnabas driven out of Pisidian Antioch, shaking its dust "
         "off and moving on to Iconium (13:50-52). Chapter 14 follows that same pattern of mixed "
         "reception: they heal a man at Lystra only to be mistaken for gods, then watch the same "
         "crowd turn and stone Paul, yet they return through the churches they planted to appoint "
         "elders before reporting to Antioch that God has opened a door of faith to the Gentiles "
         "(14:1-28). That same question of what faith requires from Gentiles becomes the subject of "
         "chapter 15's Jerusalem council."),
    15: ("Chapter 14 ended with Paul and Barnabas reporting to the Antioch church that God had "
         "opened a door of faith to the Gentiles (14:27-28). Chapter 15 settles exactly what that "
         "faith requires: after sharp debate in Jerusalem over circumcision, Peter and James side "
         "against imposing the full law on Gentile believers, a letter confirms the decision, and "
         "Paul and Barnabas then separate sharply over whether to bring John Mark on their next "
         "journey (15:1-41). That split sends Paul off with a new companion, Silas, whose travels "
         "fill chapter 16."),
    16: ("Chapter 15 ended with Paul choosing Silas as a new traveling companion after parting ways "
         "with Barnabas (15:39-41). Chapter 16 follows that new partnership into Europe: a vision "
         "calls them to Macedonia, Lydia becomes the first convert at Philippi, and after Paul "
         "frees an enslaved girl from a profit-making spirit, he and Silas are beaten and "
         "imprisoned, only for an earthquake and their own composure to convert their jailer before "
         "their Roman citizenship forces an official apology (16:1-40). That same mission keeps "
         "moving through Greece in chapter 17."),
    17: ("Chapter 16 ended with Paul and Silas leaving Philippi after the magistrates' apology "
         "(16:39-40). Chapter 17 carries them through three very different audiences: "
         "Thessalonica's synagogue erupts into civic unrest, Berea's hearers calmly search the "
         "Scriptures to test Paul's claims, and in Athens Paul addresses philosophers at the "
         "Areopagus about the God they have unknowingly been worshiping, with mixed results "
         "(17:1-34). That same mixed reception continues in chapter 18's long stay in Corinth."),
    18: ("Chapter 17 ended with some Athenians mocking Paul's mention of resurrection while others "
         "asked to hear more (17:32-34). Chapter 18 finds a more settled hearing in Corinth: Paul "
         "works alongside fellow tentmakers Aquila and Priscilla, stays eighteen months despite a "
         "failed attempt to have him judged before the proconsul Gallio, and before leaving for "
         "Antioch helps the couple give fuller instruction to the eloquent teacher Apollos "
         "(18:1-28). That same pattern of deeper teaching continues when Paul reaches Ephesus in "
         "chapter 19."),
    19: ("Chapter 18 ended with Apollos receiving fuller instruction from Priscilla and Aquila "
         "before moving on to minister in Achaia (18:24-28). Chapter 19 shows Paul giving that same "
         "kind of fuller instruction in Ephesus: he baptizes disciples who only knew John's baptism, "
         "teaches for two years in Tyrannus's hall, and sees the city's magic trade publicly "
         "discredited before a riot over the silversmiths' income in Artemis's temple is finally "
         "calmed by a city official (19:1-41). Paul's departure from that same city opens chapter "
         "20's travels toward Jerusalem."),
    20: ("Chapter 19 ended with the Ephesian riot settled and Paul free to continue his travels "
         "(19:40-41). Chapter 20 follows him on that onward journey: he raises Eutychus after a "
         "fatal fall at Troas, then summons the Ephesian elders to Miletus for a farewell charge "
         "recalling his hardships among them and warning of dangers still to come, a meeting that "
         "ends in tears since none of them expect to see him again (20:1-38). That same expectation "
         "of danger ahead becomes explicit warning in chapter 21."),
    21: ("Chapter 20 ended with the Ephesian elders weeping as they said goodbye to Paul, certain "
         "they would not see his face again (20:36-38). Chapter 21 shows exactly the danger they "
         "feared arriving in Jerusalem: despite Agabus's dramatic warning and the pleas of friends, "
         "Paul goes anyway, joins a temple purification rite to answer rumors about his teaching, "
         "and is seized by a mob that Roman soldiers have to fight through to rescue him from "
         "(21:1-40). That rescue leaves Paul in Roman custody for the hearings chapter 22 begins."),
    22: ("Chapter 21 ended with Paul, rescued from the mob, asking the Roman commander's permission "
         "to address the crowd from the barracks stairs (21:37-40). Chapter 22 gives that speech: "
         "Paul retells his own story, from training under Gamaliel to persecuting believers to the "
         "light that stopped him on the Damascus road, until the crowd erupts again at the mention "
         "of a mission to Gentiles, and Paul avoids an illegal flogging only by revealing his Roman "
         "citizenship (22:1-30). That citizenship keeps shaping his legal situation through chapter "
         "23's hearing before the council."),
    23: ("Chapter 22 ended with Paul's Roman citizenship alarming the commander who had nearly had "
         "him flogged without trial (22:28-30). Chapter 23 shows that same commander trying to "
         "manage a volatile situation: Paul's claim of resurrection hope splits the council into "
         "open conflict, the Lord assures him in the night that he will testify in Rome just as he "
         "has in Jerusalem, and when Paul's own nephew uncovers an assassination plot, the "
         "commander sends him under heavy guard to Governor Felix in Caesarea (23:1-35). That "
         "transfer to Roman provincial custody begins the hearings chapter 24 covers."),
    24: ("Chapter 23 ended with Paul arriving safely under guard at Felix's residence in Caesarea "
         "(23:33-35). Chapter 24 shows the hearing that follows: the high priest's own lawyer "
         "accuses Paul of stirring unrest, Paul answers by affirming his worship of Israel's God and "
         "his hope in the resurrection, and Felix, hoping for a bribe that never comes, leaves Paul "
         "in custody for two years rather than deciding the case (24:1-27). That stalled case passes "
         "to Felix's successor in chapter 25."),
    25: ("Chapter 24 ended with Paul still in custody two years later, Felix having been replaced "
         "by Festus (24:27). Chapter 25 shows Festus inheriting a case he does not know how to "
         "describe: renewed accusations lead Paul to appeal directly to Caesar rather than risk a "
         "Jerusalem trial, and when King Agrippa and Bernice visit, Festus admits he has no actual "
         "charge to send along with his prisoner (25:1-27). That admission sets up chapter 26's "
         "hearing before Agrippa, where Paul finally gets to explain himself at length."),
    26: ("Chapter 25 ended with Festus confessing he had no specific charge to write against Paul "
         "for the emperor's review (25:26-27). Chapter 26 gives Paul the chance to supply his own "
         "account instead: he retells his Pharisaic training, his persecution of believers, and the "
         "Damascus-road vision that commissioned him to the Gentiles, provoking Festus to call him "
         "mad before Agrippa admits Paul has nearly persuaded him, and the officials conclude he "
         "has done nothing worthy of death (26:1-32). His appeal to Caesar still has to go "
         "forward, which puts Paul on the ship chapter 27 follows toward Rome."),
    27: ("Chapter 26 ended with Agrippa and Festus agreeing that Paul could have gone free if he "
         "had not already appealed to Caesar (26:30-32). Chapter 27 follows that appeal onto a ship "
         "bound for Rome: Paul warns against sailing on from Crete, a violent storm proves him "
         "right, and after two weeks adrift he assures everyone aboard they will survive even "
         "though the ship will not, a promise that holds when all 276 people reach land safely "
         "after the wreck (27:1-44). That survival on open water leads into the unexpected "
         "hospitality of Malta in chapter 28."),
    28: ("Chapter 27 ended with everyone aboard reaching land safely after the shipwreck, just as "
         "Paul had promised (27:43-44). Acts' closing chapter brings that promise of reaching Rome "
         "to completion: Malta's islanders show Paul unusual kindness after a viper fails to harm "
         "him, he finally arrives in Rome, and for two years he preaches the kingdom of God "
         "unhindered, the message having traveled from Jerusalem to the empire's capital just as "
         "Jesus promised in chapter 1 (28:1-31). The New Testament's letters, beginning with "
         "Romans, pick up the life of the churches Acts describes."),
}

KEY_FIGURES = {
    1: [
        ("Jesus",
         "Commissions the apostles with the promise of the Holy Spirit and worldwide witness, then "
         "ascends from the Mount of Olives as two men in white promise his return (1:4-11)."),
        ("Peter",
         "Explains from Scripture that Judas's office must be filled and leads the process of "
         "choosing his replacement (1:15-22)."),
        ("Matthias",
         "Chosen by lot to join the Eleven as the twelfth witness to Jesus' resurrection (1:23-26)."),
        ("Joseph called Barsabbas (Justus)",
         "The other candidate considered alongside Matthias, showing that more than one qualified "
         "witness was available (1:23)."),
        ("Mary and the gathered believers",
         "Join the apostles in prayer in the upper room while waiting for the promised Spirit "
         "(1:14)."),
        ("Judas Iscariot",
         "His death and vacated office, discussed only after the fact, is the reason the community "
         "needs to choose a replacement (1:16-20)."),
    ],
    2: [
        ("Peter",
         "Stands with the Eleven to interpret the Spirit's coming through Joel and the Psalms and "
         "calls the crowd to repent and be baptized (2:14-40)."),
        ("The apostles",
         "Are filled with the Holy Spirit and speak in languages understood by visitors from many "
         "nations (2:4-11)."),
        ("Pilgrims and Jerusalem hearers",
         "Hear the apostles' witness each in their own native language and are pricked in their "
         "hearts by Peter's sermon (2:6-8,37)."),
        ("New believers",
         "About three thousand are baptized in a single day and devote themselves to the apostles' "
         "teaching, fellowship, and shared meals (2:41-47)."),
    ],
    3: [
        ("Peter",
         "Heals the lame man in Jesus' name and tells the gathered crowd that faith in that name, "
         "not his own power, made the man well (3:6,12-16)."),
        ("John",
         "Accompanies Peter to the temple and stands with him before the amazed crowd (3:1,11)."),
        ("Man lame from birth",
         "Is healed instantly and walks into the temple leaping and praising God, drawing the crowd "
         "that Peter then addresses (3:2-10)."),
        ("Temple worshipers",
         "Gather in astonishment at Solomon's Portico to hear Peter explain the healing (3:11-12)."),
    ],
    4: [
        ("Peter and John",
         "Are arrested for teaching about Jesus' resurrection and tell the council that salvation "
         "is found in no other name (4:1-12)."),
        ("Jewish rulers and temple leaders",
         "Threaten the apostles but release them because the healing is too well known to deny and "
         "the people are praising God (4:13-22)."),
        ("The healed man",
         "Stands beside the apostles before the council as living, undeniable evidence of the "
         "healing (4:14)."),
        ("Believers",
         "Pray together for boldness rather than for the threats to stop, then share their "
         "resources to meet one another's needs (4:23-37)."),
        ("Barnabas (Joseph)",
         "A Levite who sells a field and brings the whole price to the apostles, becoming a named "
         "example of the community's generosity (4:36-37)."),
    ],
    5: [
        ("Ananias and Sapphira",
         "Sell property, secretly keep back part of the price, and both die after separately lying "
         "to Peter about having given it all (5:1-10)."),
        ("Peter",
         "Confronts Ananias and Sapphira's deception and later tells the council that the apostles "
         "must obey God rather than men (5:3-4,8-9,29)."),
        ("The apostles",
         "Perform signs that draw crowds, are arrested and freed by an angel, and keep teaching "
         "about Jesus even after being flogged (5:12-21,40-42)."),
        ("High priest and council",
         "Arrest and interrogate the apostles, then have them flogged despite Gamaliel's warning "
         "(5:17-18,27-28,40)."),
        ("Gamaliel",
         "A respected Pharisee who urges the council to leave the apostles alone, since a work that "
         "is not of God will fail on its own (5:34-39)."),
    ],
    6: [
        ("The Twelve",
         "Ask the community to choose seven men to oversee the food distribution so the apostles "
         "can stay devoted to prayer and teaching (6:2-4)."),
        ("Hellenists and Hebrews",
         "Greek-speaking believers whose widows were being overlooked compared to Hebrew-speaking "
         "widows, exposing the inequity the seven are chosen to fix (6:1)."),
        ("The seven chosen men",
         "Are selected by the community and set apart by the apostles to oversee the daily "
         "distribution of food (6:3,6)."),
        ("Stephen",
         "One of the seven, full of faith and power, performs signs and debates opponents who "
         "cannot out-argue him (6:8-10)."),
        ("Accusers and council",
         "Unable to defeat Stephen in debate, bring false witnesses who accuse him of speaking "
         "against Moses, God, the temple, and the law (6:11-13)."),
    ],
    7: [
        ("Stephen",
         "Retells Israel's history before the council, accuses his hearers of resisting the Holy "
         "Spirit, and is stoned after reporting a vision of Jesus standing at God's right hand "
         "(7:2-60)."),
        ("Abraham, Joseph and Moses",
         "Ancestral figures in Stephen's speech through whom God worked outside the promised land, "
         "long before any temple existed (7:2-45)."),
        ("Council and hostile crowd",
         "Grow furious at Stephen's accusation, then drive him out of the city and stone him "
         "(7:54,57-58)."),
        ("Saul",
         "A young man who approves of Stephen's killing while guarding the coats of those who threw "
         "the stones (7:58-60)."),
        ("Jesus",
         "Appears to Stephen standing at God's right hand, the vision Stephen reports just before "
         "he is stoned (7:55-56)."),
    ],
    8: [
        ("Saul",
         "Ravages the church house by house, dragging believers to prison, and in doing so helps "
         "scatter the very mission he means to destroy (8:1-3)."),
        ("Philip",
         "Preaches and heals in Samaria, then is sent to explain Isaiah to an Ethiopian official on "
         "the road to Gaza and baptizes him (8:5-8,26-38)."),
        ("Simon",
         "A Samaritan known for practicing magic who believes Philip's message but later offers "
         "money to buy the apostles' power and is sharply rebuked (8:9-13,18-24)."),
        ("Peter and John",
         "Travel to Samaria to pray for the new believers there and confront Simon's attempt to buy "
         "spiritual authority (8:14-24)."),
        ("Ethiopian court official",
         "A high-ranking treasury official who is reading Isaiah aloud in his chariot and asks "
         "Philip to explain it, then is baptized on the spot (8:27-38)."),
    ],
    9: [
        ("Saul",
         "Is blinded by a heavenly light and voice on the road to Damascus, then regains his sight, "
         "is baptized, and begins preaching the very faith he came to destroy (9:1-22)."),
        ("Ananias of Damascus",
         "Overcomes his fear of Saul's reputation to obey a vision, visit him, and restore his "
         "sight (9:10-18)."),
        ("Barnabas",
         "Vouches for the converted Saul before suspicious believers, helping him be received in "
         "Jerusalem (9:26-28)."),
        ("Peter",
         "Heals the paralyzed Aeneas at Lydda and raises Tabitha from death at Joppa (9:32-41)."),
        ("Aeneas",
         "Paralyzed for eight years, he is healed instantly when Peter tells him to rise and make "
         "his bed (9:33-34)."),
        ("Tabitha (Dorcas)",
         "A disciple known for good works and charity whom Peter raises from death while widows "
         "show him the clothing she had made for them (9:36-41)."),
    ],
    10: [
        ("Cornelius",
         "A devout, generous Roman centurion who is told by an angel to send for Peter, then "
         "gathers his household and friends to hear him (10:1-8,24)."),
        ("Peter",
         "Receives a vision teaching him not to call any person unclean, then travels to Cornelius's "
         "house and declares that God shows no favoritism (10:9-43)."),
        ("Cornelius's household and friends",
         "Receive Peter's message about Jesus and are baptized after the Holy Spirit falls on them "
         "while he is still speaking (10:44-48)."),
        ("Jewish believers with Peter",
         "Are astonished to see the Holy Spirit poured out on Gentile listeners just as it had been "
         "on them at Pentecost (10:45-46)."),
    ],
    11: [
        ("Peter",
         "Explains his vision and Cornelius's story to critics in Jerusalem until they stop "
         "objecting and praise God for granting Gentiles life (11:1-18)."),
        ("Jerusalem believers",
         "Question Peter for eating with uncircumcised people, then are silenced and praise God "
         "once they hear his explanation (11:2-3,18)."),
        ("Barnabas",
         "Travels to Antioch, encourages the new believers there, and brings Saul from Tarsus to "
         "teach alongside him for a year (11:22-26)."),
        ("Saul",
         "Is brought by Barnabas from Tarsus to Antioch, where the two of them teach the growing "
         "congregation for a full year (11:25-26)."),
        ("Agabus",
         "A prophet who predicts a coming famine, prompting the Antioch believers to plan relief "
         "for Judea (11:27-28)."),
        ("Antioch disciples",
         "The first believers to be called Christians, who send relief to Judea's believers by the "
         "hands of Barnabas and Saul (11:26,29-30)."),
    ],
    12: [
        ("Herod Agrippa I",
         "Kills James, arrests Peter to please the Jewish leaders, and later dies after accepting "
         "the crowd's worship as a god (12:1-4,20-23)."),
        ("James brother of John",
         "An apostle killed by Herod's sword, his death showing the real cost of the persecution "
         "Herod is willing to use (12:2)."),
        ("Peter",
         "Is freed from prison by an angel and goes to Mary's house, where the praying believers "
         "can hardly believe he is really there (12:6-17)."),
        ("Mary mother of John Mark",
         "Hosts the prayer gathering Peter goes to immediately after his escape (12:12)."),
        ("Rhoda",
         "A servant girl so overjoyed to recognize Peter's voice at the gate that she runs to tell "
         "the others without even letting him in (12:13-15)."),
        ("Barnabas and Saul",
         "Return to Antioch from their relief mission to Judea, reappearing just as the chapter "
         "closes (12:25)."),
    ],
    13: [
        ("Barnabas",
         "Is set apart with Saul by the Holy Spirit for the mission that takes them to Cyprus and "
         "Pisidian Antioch (13:2-4)."),
        ("Saul (Paul)",
         "Confronts the sorcerer Elymas on Cyprus and preaches Jesus as David's promised descendant "
         "in the Pisidian Antioch synagogue (13:9-12,16-41)."),
        ("Sergius Paulus",
         "The Cypriot proconsul who believes once he sees Elymas struck blind for opposing the "
         "message (13:7,12)."),
        ("Elymas (Bar-Jesus)",
         "A sorcerer who tries to turn Sergius Paulus away from the faith and is struck blind by "
         "Paul for it (13:8,11)."),
        ("John Mark",
         "Serves as the missionaries' helper on the journey but leaves the party once they reach "
         "Perga (13:5,13)."),
        ("Jewish and Gentile hearers",
         "Respond to Paul's synagogue sermon so differently that the resulting opposition drives "
         "the missionaries to declare they will turn to the Gentiles instead (13:42-48)."),
    ],
    14: [
        ("Paul and Barnabas",
         "Preach and heal from Iconium to Derbe, reject being worshiped as gods at Lystra, and "
         "revisit their new churches to appoint elders (14:1-23)."),
        ("Lame man at Lystra",
         "Crippled from birth, he is healed by Paul and his restored walking triggers the crowd's "
         "attempt to worship the missionaries as gods (14:8-10)."),
        ("Priest of Zeus and local crowd",
         "Mistake Paul and Barnabas for Hermes and Zeus and try to offer sacrifices to them before "
         "the missionaries stop them (14:11-13,18)."),
        ("Opponents from Antioch and Iconium",
         "Follow the missionaries to Lystra and stir the same crowd that nearly worshiped Paul into "
         "stoning him instead (14:19)."),
        ("New disciples and elders",
         "Are strengthened and given appointed leaders when Paul and Barnabas revisit the churches "
         "on their way back (14:21-23)."),
    ],
    15: [
        ("Peter",
         "Argues at the Jerusalem council that God made no distinction between Jewish and Gentile "
         "believers, so the Gentiles should not be burdened with the full law (15:7-11)."),
        ("James",
         "Proposes the council's decision and the letter asking Gentile believers to avoid "
         "practices tied to idolatry, blood, and sexual immorality (15:13-21)."),
        ("Paul and Barnabas",
         "Report the signs and wonders God did among the Gentiles through them, then later "
         "disagree so sharply over John Mark that they part ways (15:12,36-39)."),
        ("Judas Barsabbas and Silas",
         "Carry the council's letter to Antioch and confirm its contents in person (15:22,27,32)."),
        ("Gentile believers",
         "Are the subject of the whole debate and receive the council's decision with encouragement "
         "once the letter reaches Antioch (15:30-31)."),
        ("John Mark",
         "The proposed travel companion whose earlier departure from the mission becomes the reason "
         "Paul and Barnabas separate (15:37-39)."),
    ],
    16: [
        ("Paul and Silas",
         "Travel to Macedonia after a vision, are beaten and imprisoned at Philippi for freeing an "
         "enslaved girl from a spirit, and are freed by an earthquake before revealing their Roman "
         "citizenship (16:9-10,16-24,35-37)."),
        ("Timothy",
         "Joins Paul's mission at Lystra and is circumcised to ease his reception among local Jewish "
         "communities (16:1-3)."),
        ("Lydia",
         "A seller of purple cloth whose heart the Lord opens to Paul's message, becoming "
         "Philippi's first convert and offering the missionaries lodging (16:14-15)."),
        ("Enslaved fortune-telling girl",
         "Follows Paul for days until he casts out the spirit that let her owners profit from her, "
         "costing them their income (16:16-18)."),
        ("Philippian jailer",
         "Nearly kills himself when he thinks the earthquake let the prisoners escape, then asks "
         "what he must do to be saved and is baptized with his household (16:27-33)."),
        ("Philippian magistrates",
         "Order Paul and Silas beaten and jailed without trial, then apologize once they learn the "
         "missionaries are Roman citizens (16:22-23,38-39)."),
    ],
    17: [
        ("Paul",
         "Reasons from Scripture in Thessalonica and Berea, then addresses the Athenian Areopagus "
         "about the God his hearers have unknowingly been worshiping (17:2-3,10-11,22-31)."),
        ("Silas and Timothy",
         "Accompany Paul through Thessalonica and Berea before staying behind when he goes on to "
         "Athens alone (17:14-15)."),
        ("Jason",
         "Hosts Paul in Thessalonica and is dragged before the city officials when a mob accuses "
         "him of harboring troublemakers (17:5-9)."),
        ("Berean listeners",
         "Receive Paul's message eagerly and search the Scriptures daily to check whether what he "
         "says is true (17:11)."),
        ("Epicurean and Stoic philosophers",
         "Debate with Paul in the marketplace and bring him to the Areopagus to explain his "
         "teaching more fully (17:18-19)."),
        ("Dionysius and Damaris",
         "Named Athenians who believe Paul's message, a positive response amid a mostly mixed "
         "Athenian reaction (17:34)."),
    ],
    18: [
        ("Paul",
         "Works as a tentmaker alongside Aquila and Priscilla in Corinth, stays eighteen months "
         "teaching, and later leaves by way of Cenchrea for Ephesus and Antioch (18:1-4,11,18)."),
        ("Aquila and Priscilla",
         "A Jewish couple expelled from Rome who host Paul in Corinth and later explain God's way "
         "more accurately to Apollos in Ephesus (18:2-3,26)."),
        ("Gallio",
         "The Roman proconsul of Achaea who refuses to judge the Jewish leaders' case against Paul, "
         "dismissing it as an internal dispute about their own law (18:12-17)."),
        ("Crispus",
         "A synagogue leader who believes in the Lord along with his whole household (18:8)."),
        ("Sosthenes",
         "Beaten in front of the tribunal during the uproar against Paul, showing how volatile the "
         "episode became (18:17)."),
        ("Apollos",
         "An eloquent, Scripture-trained teacher who receives fuller instruction from Priscilla and "
         "Aquila before going on to minister effectively in Achaea (18:24-28)."),
    ],
    19: [
        ("Paul",
         "Baptizes disciples who only knew John's baptism, teaches daily in Ephesus for two years, "
         "and sees the city's magic trade publicly discredited (19:1-12,17-20)."),
        ("Followers of John's baptism",
         "Had never heard of the Holy Spirit until Paul instructs them and baptizes them in the "
         "name of Jesus (19:1-5)."),
        ("Seven sons of Sceva",
         "Try to cast out a demon using Jesus' name as a formula and are overpowered and wounded by "
         "the possessed man instead (19:13-16)."),
        ("Demetrius",
         "A silversmith who mobilizes fellow craftsmen against Paul because his preaching threatens "
         "their trade in shrines of Artemis (19:24-27)."),
        ("Artemis worshipers and artisans",
         "Fill the city's theater shouting for about two hours in protest of Paul's preaching "
         "(19:28-34)."),
        ("City clerk",
         "Calms the riotous assembly and dismisses it before the disturbance can draw Roman "
         "intervention (19:35-41)."),
    ],
    20: [
        ("Paul",
         "Raises Eutychus after his fatal fall at Troas, then summons the Ephesian elders to "
         "Miletus to recall his ministry among them and warn of dangers ahead (20:7-12,17-35)."),
        ("Eutychus",
         "Falls asleep in a third-floor window during Paul's long sermon, falls to his death, and "
         "is restored alive when Paul embraces him (20:9-12)."),
        ("Ephesian elders",
         "Receive Paul's charge to watch over the flock and weep with him, certain they will never "
         "see his face again (20:17-18,36-38)."),
        ("Traveling companions",
         "Travel with Paul through Macedonia and Greece on this stage of the journey toward "
         "Jerusalem (20:4-5)."),
    ],
    21: [
        ("Paul",
         "Resolves to go to Jerusalem despite warnings, joins a temple purification rite to answer "
         "rumors about his teaching, and is rescued from a mob by Roman soldiers (21:13-14,26-27,"
         "31-32)."),
        ("Agabus",
         "A prophet who dramatizes with Paul's own belt that he will be bound in Jerusalem "
         "(21:10-11)."),
        ("Philip the evangelist and his daughters",
         "Host Paul and his companions at Caesarea on the way to Jerusalem (21:8-9)."),
        ("James and Jerusalem elders",
         "Welcome Paul but ask him to join the purification rite to show that he still respects "
         "Jewish practice (21:18-24)."),
        ("Jews from Asia and Jerusalem crowd",
         "Falsely accuse Paul of defiling the temple and seize him, nearly killing him before "
         "soldiers intervene (21:27-31)."),
        ("Roman tribune and soldiers",
         "Rescue Paul from the mob and carry him up the barracks stairs because the crowd's "
         "violence makes it impossible for him to walk (21:32,35-36)."),
    ],
    22: [
        ("Paul",
         "Recounts his training, persecution of believers, and Damascus-road encounter with Jesus "
         "to the Jerusalem crowd, then reveals his Roman citizenship to stop an illegal flogging "
         "(22:3-21,25-28)."),
        ("Ananias",
         "A devout, law-observant believer in Paul's own retelling who restores his sight and urges "
         "him to be baptized (22:12-16)."),
        ("Gamaliel",
         "Named by Paul as the teacher at whose feet he was trained, anchoring his claim to a "
         "respectable Jewish education (22:3)."),
        ("Jerusalem audience",
         "Listens quietly to Paul's story until he mentions being sent to the Gentiles, then erupts "
         "in protest (22:21-22)."),
        ("Roman tribune and centurion",
         "Order Paul examined by flogging, then stop immediately and grow alarmed once he reveals "
         "he is a Roman citizen (22:24-29)."),
    ],
    23: [
        ("Paul",
         "Splits the council by declaring his hope in the resurrection, then is assured by the Lord "
         "in the night that he will testify in Rome just as he has in Jerusalem (23:1-6,11)."),
        ("Ananias",
         "The high priest who orders Paul struck on the mouth for his opening statement before the "
         "council (23:2)."),
        ("Pharisees and Sadducees",
         "Disagree so sharply over the resurrection that the council dissolves into a shouting "
         "match over Paul (23:7-10)."),
        ("Paul's nephew",
         "An unnamed relative who learns of a plot to kill Paul and warns the Roman commander in "
         "time (23:16-22)."),
        ("Claudius Lysias",
         "The Roman commander who transfers Paul under heavy guard to Governor Felix once he learns "
         "of the assassination plot (23:23-30)."),
        ("Felix",
         "The governor in Caesarea who receives Paul and the commander's letter explaining the "
         "situation (23:33-35)."),
    ],
    24: [
        ("Paul",
         "Answers the accusations against him point by point, affirming his worship of Israel's "
         "God and his hope in the resurrection (24:10-21)."),
        ("Tertullus",
         "A hired advocate who presents the high priest's accusation that Paul is a troublemaker "
         "and temple profaner (24:1-9)."),
        ("Ananias and elders",
         "The high priest and Jerusalem leaders who travel to Caesarea to press their case against "
         "Paul before Felix (24:1)."),
        ("Felix",
         "Postpones Paul's case and keeps him in custody for two years, Acts noting he hoped for a "
         "bribe that never came (24:22,26-27)."),
        ("Drusilla",
         "Felix's wife, present when he later sends for Paul to hear him speak about faith in "
         "Christ (24:24)."),
        ("Festus",
         "Felix's successor, who inherits Paul's unresolved case at the chapter's close (24:27)."),
    ],
    25: [
        ("Paul",
         "Denies any wrongdoing and appeals to Caesar once Festus proposes moving his trial to "
         "Jerusalem (25:8-11)."),
        ("Festus",
         "Hears the renewed charges against Paul, declines to transfer him, and later admits to "
         "Agrippa he has no specific charge to report (25:4-5,26-27)."),
        ("Jewish leaders",
         "Press renewed accusations against Paul and seek to have him transferred to Jerusalem, a "
         "request Acts ties to a hidden plot (25:2-3,7)."),
        ("Agrippa II",
         "A client king who visits Festus and agrees to hear Paul's case for himself (25:13,22)."),
        ("Bernice",
         "Agrippa's sister, who attends the hearing alongside him (25:13,23)."),
    ],
    26: [
        ("Paul",
         "Recounts his Pharisaic training, his persecution of believers, and the Damascus-road "
         "vision that commissioned him to preach to the Gentiles (26:4-18)."),
        ("Agrippa II",
         "Hears Paul's defense and admits that Paul has almost persuaded him to become a Christian "
         "(26:27-28)."),
        ("Festus",
         "Interrupts Paul's defense to call him mad, provoking Paul's calm reply that he speaks "
         "words of truth and soberness (26:24-25)."),
        ("Bernice",
         "Attends the hearing with Agrippa, part of the audience Festus brings together with great "
         "ceremony (26:30)."),
        ("Jesus",
         "The speaker in Paul's narrated vision, who commissions him to open the eyes of Jews and "
         "Gentiles alike (26:15-18)."),
    ],
    27: [
        ("Paul",
         "Warns against sailing on from Crete, then assures everyone aboard that they will survive "
         "the coming storm even though the ship will be lost (27:9-10,21-26)."),
        ("Julius",
         "The centurion guarding Paul who treats him kindly and later overrules the soldiers' plan "
         "to kill the prisoners (27:1,3,42-43)."),
        ("Sailors",
         "Try to sneak away from the sinking ship in the lifeboat before the soldiers cut it loose "
         "at Paul's warning (27:30-32)."),
        ("Shipowner and pilot",
         "Favor continuing the voyage from Crete against Paul's own warning, a decision the storm "
         "soon proves costly (27:11-12)."),
        ("Soldiers and passengers",
         "Share in the shipwreck and the swim to shore, all 276 people reaching land safely "
         "(27:37,44)."),
    ],
    28: [
        ("Paul",
         "Survives a viper's bite on Malta, heals Publius's father and other islanders, and spends "
         "two years in Rome preaching without anyone forbidding him (28:3-9,30-31)."),
        ("Publius",
         "The leading official on Malta who hosts the shipwrecked travelers and whose father Paul "
         "heals (28:7-8)."),
        ("Islanders",
         "Show the shipwrecked survivors unusual kindness, building a fire and later loading them "
         "with supplies (28:2,10)."),
        ("Jewish leaders in Rome",
         "Meet with Paul to hear his explanation and respond to his message about Jesus in "
         "different ways, some persuaded and some not (28:17-24)."),
        ("Roman believers",
         "Walk out to meet Paul at the Forum of Appius and the Three Taverns, encouraging him as he "
         "nears the city (28:15)."),
    ],
}

THEMES = {
    1: {
        "Spirit-empowered witness":
            "Jesus tells the apostles that the coming Holy Spirit will make them his witnesses "
            "from Jerusalem to the ends of the earth, giving the whole book its traveling shape "
            "(1:4-8).",
        "Prayerful discernment":
            "The apostles devote themselves to prayer with the women and Jesus' family, then "
            "choose Matthias by lot only after that same kind of prayerful waiting (1:12-14,"
            "23-26).",
        "Continuity of apostolic testimony":
            "Peter insists that Judas's replacement must be someone who witnessed the whole span "
            "of Jesus' ministry, keeping the number of firsthand witnesses complete (1:16-22).",
    },
    2: {
        "The Spirit and intelligible witness":
            "The Holy Spirit's coming lets pilgrims from many nations each hear the apostles' "
            "witness in their own native language, not in confusion but in understanding (2:1-13).",
        "Jesus' resurrection proclaimed":
            "Peter argues from the Psalms that God raised Jesus because death itself could not "
            "hold him, making the resurrection the center of his first sermon (2:22-36).",
        "Repentance and shared life":
            "About three thousand people repent and are baptized in a single day, forming a "
            "community marked by shared teaching, meals, and possessions (2:37-47).",
    },
    3: {
        "Healing and public witness":
            "Peter heals a man lame from birth in the name of Jesus Christ, and the man's own "
            "walking and leaping become the crowd's first evidence (3:1-10).",
        "Jesus at the center":
            "Peter refuses to let the crowd credit the healing to his own power or piety, "
            "insisting that faith in Jesus' name alone made the man well (3:11-16).",
        "Repentance and covenant hope":
            "Peter calls the crowd to repent so that God's promised times of refreshing may come, "
            "tying the healing back to Israel's own prophetic hope (3:17-26).",
    },
    4: {
        "Courage under pressure":
            "Peter tells the council there is salvation in no other name than Jesus, and the "
            "rulers release the apostles only because the healed man's recovery is undeniable "
            "(4:8-20).",
        "Prayer for boldness":
            "Rather than praying for the threats to stop, the believers pray for courage to keep "
            "speaking, and the place where they are gathered shakes in response (4:23-31).",
        "Generosity and practical care":
            "Believers sell property to meet one another's needs, and Barnabas's gift is singled "
            "out as a named example of that shared generosity (4:32-37).",
    },
    5: {
        "Truthfulness in giving":
            "Ananias and Sapphira die after pretending to give the whole price of their land, a "
            "deception about generosity rather than generosity itself that fills the church with "
            "fear (5:1-11).",
        "Obedience amid prohibition":
            "Ordered to stop speaking about Jesus, the apostles answer plainly that they must obey "
            "God rather than men (5:27-32).",
        "Perseverance after suffering":
            "Flogged and released, the apostles leave rejoicing that they were counted worthy to "
            "suffer for Jesus' name, and keep right on teaching (5:33-42).",
    },
    6: {
        "Equitable provision":
            "Greek-speaking widows are being overlooked in the daily distribution, and the "
            "community treats that inequity as a problem serious enough to require a structural "
            "fix (6:1-3).",
        "Shared responsibility":
            "The apostles delegate the practical need to seven chosen men so they themselves can "
            "stay devoted to prayer and teaching, dividing labor rather than doing everything "
            "alone (6:2-7).",
        "Witness and accusations":
            "Unable to out-argue Stephen, his opponents resort to false accusations that he speaks "
            "against Moses, the temple, and the law (6:8-15).",
    },
    7: {
        "God's work beyond one place":
            "Stephen retells how God met Abraham, Joseph, and Moses far outside the promised "
            "land, arguing that God was never confined to one building or territory (7:2-16,"
            "44-50).",
        "Resistance to God's messengers":
            "Stephen accuses his hearers of resisting the Holy Spirit exactly as their ancestors "
            "resisted Moses, turning Israel's own history into a mirror held up to the council "
            "(7:35-43,51-53).",
        "Costly forgiveness":
            "As he is being stoned, Stephen asks the Lord to forgive his killers, dying the same "
            "way Jesus did, with forgiveness instead of retaliation on his lips (7:54-60).",
    },
    8: {
        "Mission through disruption":
            "The very persecution meant to crush the church instead scatters believers who keep "
            "preaching wherever they go, turning disaster into expansion (8:1-8).",
        "Spiritual gifts are not commodities":
            "Simon offers money to buy the power of conferring the Holy Spirit, and Peter's sharp "
            "rebuke makes clear that God's gift cannot be purchased at any price (8:18-24).",
        "Scripture and welcome":
            "Philip explains Isaiah's suffering servant to an Ethiopian official reading it alone "
            "in his chariot, and baptizes him the moment he asks what could possibly stand in the "
            "way (8:26-40).",
    },
    9: {
        "Transformation and calling":
            "A blinding light and a voice turn Saul from the church's fiercest persecutor into a "
            "preacher of the very faith he came to Damascus to destroy (9:1-22).",
        "Courageous welcome":
            "Ananias obeys a vision to visit the man he fears most, and Barnabas later vouches for "
            "that same converted persecutor before suspicious believers in Jerusalem (9:10-19,"
            "26-28).",
        "Care and restoration":
            "Peter heals the paralyzed Aeneas and raises Tabitha from death, extending the same "
            "restoring power seen in Jesus' own ministry to ordinary believers in Lydda and Joppa "
            "(9:32-43).",
    },
    10: {
        "No favoritism in receiving people":
            "Peter tells Cornelius's household that God shows no favoritism, and that anyone who "
            "fears God and does what is right is already accepted by him (10:28-35).",
        "Jesus proclaimed to outsiders":
            "Peter summarizes Jesus' whole ministry, death, and resurrection for a Gentile "
            "household that has never heard any of it before (10:36-43).",
        "The Spirit and Gentile inclusion":
            "The Holy Spirit falls on Cornelius's household while Peter is still speaking, "
            "settling the question of Gentile inclusion before anyone has to argue for it "
            "(10:44-48).",
    },
    11: {
        "Reconsidering boundaries":
            "Peter's explanation of his vision and Cornelius's story is enough to make even his "
            "harshest Jerusalem critics praise God for granting Gentiles life (11:1-18).",
        "Teaching a growing community":
            "Barnabas brings Saul from Tarsus to help teach the new, mixed congregation at "
            "Antioch for a full year, the city where believers are first called Christians "
            "(11:19-26).",
        "Mutual aid across distance":
            "Warned of a coming famine by the prophet Agabus, the Antioch believers send relief "
            "to the Judean church they have never even met (11:27-30).",
    },
    12: {
        "Cost of persecution":
            "Herod kills James and, seeing that it pleases the Jewish leaders, arrests Peter too, "
            "treating the apostles' deaths and imprisonments as a political strategy (12:1-4).",
        "Prayer and surprise":
            "The church prays constantly for Peter while he is in prison, yet is so surprised by "
            "his actual release that they tell Rhoda she is out of her mind for saying he is at "
            "the door (12:5-17).",
        "Limits of power":
            "Herod accepts the crowd's acclaim as a god and is struck down and eaten by worms, "
            "his sudden death showing how little his royal power actually controlled (12:20-24).",
    },
    13: {
        "Commissioned service":
            "The Antioch church worships and fasts before the Holy Spirit itself names Barnabas "
            "and Saul for the work they are sent to do (13:1-4).",
        "Scriptural proclamation of Jesus":
            "Paul traces Israel's history from Egypt to David to argue that Jesus is the promised "
            "descendant through whom forgiveness and justification finally come (13:16-41).",
        "Response and opposition":
            "Many Jews and Gentiles respond with joy, but jealousy among other Jewish leaders "
            "drives Paul and Barnabas out of the city entirely (13:42-52).",
    },
    14: {
        "Rejecting personal glory":
            "When the Lystra crowd tries to offer sacrifices to Paul and Barnabas as gods, they "
            "tear their own clothes in protest, insisting they are only men pointing to the "
            "living God (14:8-18).",
        "Perseverance through hardship":
            "Paul is stoned and left for dead at Lystra, yet gets up and walks back into the very "
            "city that just tried to kill him (14:19-22).",
        "Sustaining new communities":
            "Paul and Barnabas revisit the churches they planted to appoint elders and strengthen "
            "disciples before reporting back to Antioch (14:21-28).",
    },
    15: {
        "Belonging without circumcision":
            "Peter argues that God made no distinction between Jewish and Gentile believers in "
            "giving the Spirit, so the council should not place a burden on Gentiles that even "
            "Israel itself could never fully bear (15:6-19).",
        "Discernment and compromise":
            "James proposes a short list of practices for Gentile believers to avoid, a "
            "compromise meant to protect fellowship with their Jewish neighbors without "
            "re-imposing the whole law (15:19-31).",
        "Disagreement among leaders":
            "Paul and Barnabas disagree so sharply over taking John Mark that they part ways "
            "entirely, showing that even trusted partners in the same mission can reach an "
            "honest impasse (15:36-41).",
    },
    16: {
        "Mission across boundaries":
            "A vision of a man pleading for help redirects the mission into Macedonia, where "
            "Lydia becomes the first convert on European soil (16:6-15).",
        "Exploitation and economic backlash":
            "Freeing an enslaved girl from a spirit her owners profited from gets Paul and Silas "
            "beaten and jailed, since removing her exploitation cost someone else money "
            "(16:16-24).",
        "Dignity and legal protection":
            "An earthquake opens the prison, but it is the missionaries' own composure and later "
            "their Roman citizenship, not the earthquake, that actually secures their dignity and "
            "an official apology (16:25-40).",
    },
    17: {
        "Reasoned scriptural engagement":
            "The Berean believers are commended for searching the Scriptures daily to test what "
            "Paul tells them, rather than simply taking his word for it (17:1-12).",
        "Faith and civic allegiance":
            "Opponents in Thessalonica accuse Paul's converts of defying Caesar's decrees by "
            "proclaiming another king, turning a religious message into a civic threat (17:5-9).",
        "Speaking in a different culture":
            "Paul quotes Athenian poets and an altar to an unknown god to explain the Christian "
            "message in terms his philosophical hearers could actually recognize (17:22-34).",
    },
    18: {
        "Work and witness":
            "Paul supports himself making tents alongside Aquila and Priscilla while still "
            "teaching in the synagogue every Sabbath (18:1-11).",
        "Civil jurisdiction and dispute":
            "Gallio refuses to judge what he considers an internal dispute about Jewish law, a "
            "ruling that incidentally protects Paul's ministry from a hostile court (18:12-17).",
        "Humble learning":
            "Even an eloquent, Scripture-trained teacher like Apollos still has more to learn, "
            "and he receives it gladly from Priscilla and Aquila rather than resisting correction "
            "(18:24-28).",
    },
    19: {
        "Learning and baptism":
            "Disciples who only knew John's baptism are instructed further and receive the Holy "
            "Spirit once they are baptized in Jesus' name (19:1-7).",
        "Religion is not a magical technique":
            "The sons of Sceva try to use Jesus' name like a magic formula and are overpowered by "
            "the very spirit they tried to command, proving that the name itself has no power "
            "apart from genuine faith (19:11-20).",
        "Economic interests and public order":
            "Demetrius stirs a riot not over doctrine but over income, since Paul's preaching is "
            "cutting into the trade in silver shrines of Artemis (19:23-41).",
    },
    20: {
        "Community care in worship":
            "Paul interrupts a long night of teaching to go embrace Eutychus after his fatal "
            "fall, and the believers are comforted that he is alive before the gathering even "
            "continues (20:7-12).",
        "Responsible leadership":
            "Paul reminds the Ephesian elders that he never held back anything profitable to "
            "teach them, and warns that savage wolves will rise even from among their own number "
            "(20:17-31).",
        "Generosity and work":
            "Paul points to his own labor supporting himself and others as proof that it is more "
            "blessed to give than to receive (20:32-38).",
    },
    21: {
        "Commitment despite warning":
            "Agabus dramatizes a prophecy that Paul will be bound in Jerusalem, and Paul's "
            "friends beg him not to go, but he insists he is ready even to die there for Jesus' "
            "name (21:8-16).",
        "Diversity within Jewish belief":
            "James and the Jerusalem elders ask Paul to join a temple purification rite "
            "specifically to show that believing in Jesus does not require abandoning Jewish "
            "practice (21:17-26).",
        "Rumor and mob violence":
            "A false rumor that Paul brought a Gentile into the temple's restricted courts is "
            "enough to turn a crowd violent before any evidence is actually checked (21:27-40).",
    },
    22: {
        "Recounting a changed life":
            "Paul tells the Jerusalem crowd his own story in their own language, tracing his path "
            "from persecutor to believer through the light on the Damascus road (22:1-16).",
        "The contested Gentile mission":
            "The same crowd that listened calmly to Paul's testimony erupts the moment he "
            "mentions being sent to the Gentiles, showing exactly where the real offense lies "
            "(22:17-22).",
        "Rights under Roman law":
            "Paul reveals his Roman citizenship just before an illegal flogging begins, stopping "
            "the soldiers cold and alarming the commander who ordered it (22:23-30).",
    },
    23: {
        "Disputed resurrection hope":
            "Paul's single statement about his hope in the resurrection splits the council's "
            "Pharisees and Sadducees against each other so sharply that soldiers have to rescue "
            "him from his own judges (23:6-10).",
        "Human protective action":
            "Paul's own nephew overhears an assassination plot and reports it, turning ordinary "
            "family loyalty into the reason Paul survives the night (23:12-22).",
        "Roman jurisdiction":
            "The commander transfers Paul to Governor Felix under heavy guard, letting Roman "
            "provincial authority settle a dispute Jewish leaders could not resolve themselves "
            "(23:23-35).",
    },
    24: {
        "Evidence over accusation":
            "Paul answers Tertullus's charges point by point, noting that his accusers can "
            "produce no actual proof of wrongdoing in the temple (24:1-21).",
        "Resurrection and conscience":
            "Paul tells Felix that he always tries to keep a clear conscience toward God and man, "
            "grounding his defense in his resurrection hope rather than in political argument "
            "(24:14-21).",
        "Misuse of judicial power":
            "Felix leaves Paul in custody for two years not because the case demands it but "
            "because he hopes Paul will eventually offer him a bribe (24:22-27).",
    },
    25: {
        "Legal protections":
            "Facing a plot disguised as a request to move his trial, Paul uses his right as a "
            "Roman citizen to appeal directly to Caesar instead (25:1-12).",
        "Political favor and justice":
            "Festus considers sending Paul back to Jerusalem to do the Jewish leaders a favor, "
            "the same kind of political convenience that has already kept Paul in custody for "
            "years (25:9-12).",
        "Responsibility to state charges":
            "Festus admits to Agrippa that he has no specific charge to write against Paul, "
            "exposing how thin the case against him has always actually been (25:13-27).",
    },
    26: {
        "A changed vocation":
            "Paul traces his own transformation from zealous persecutor to commissioned witness "
            "back to a single vision of Jesus on the Damascus road (26:9-20).",
        "Repentance and deeds":
            "Paul insists that his preaching has always called people to repent and then to live "
            "in a way that actually matches that repentance, not merely to feel sorry (26:19-23).",
        "Public explanation":
            "Festus calls Paul mad, but Paul appeals instead to Agrippa's own familiarity with "
            "the facts, insisting that none of this was done in a corner (26:24-32).",
    },
    27: {
        "Risk and judgment":
            "Paul warns against sailing on from Crete so late in the season, but the centurion "
            "trusts the ship's owner and pilot instead, a decision the storm soon proves wrong "
            "(27:9-12).",
        "Hope during disaster":
            "With all hope of survival gone, Paul reports an angel's assurance that everyone "
            "aboard will live even though the ship itself will be lost (27:20-26).",
        "Cooperative rescue":
            "Soldiers, sailors, and prisoners all work together once Paul insists that everyone "
            "stay with the ship and eat before the final swim to shore, and all 276 people reach "
            "land safely (27:30-44).",
    },
    28: {
        "Hospitality to strangers":
            "Malta's islanders show Paul and the other survivors unusual kindness, and Paul in "
            "turn heals Publius's father and many other sick islanders (28:1-10).",
        "Varied reception":
            "Some of Rome's Jewish leaders are persuaded by what Paul says about Jesus from the "
            "law and the prophets, while others are not, the same divided response his message "
            "has drawn everywhere else (28:17-28).",
        "Unfinished legal story, continuing witness":
            "Acts ends without ever reporting the verdict of Paul's trial, choosing instead to "
            "close on two full years of his uninterrupted, unforbidden preaching in Rome "
            "(28:30-31).",
    },
}


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "44_acts.json"
    data = load(path)
    for n in range(1, 29):
        key = f"Acts {n}"
        entry = data[key]
        entry["whereWeAre"] = WWA[n]
        if n == 18:
            old = "Paul leaves Corinth via Cenchreae and Ephesus"
            new = "Paul leaves Corinth via Cenchrea and Ephesus"
            if old not in entry["summary"]:
                raise SystemExit(f"Acts {n}: modern-spelling fix not found: {old!r}")
            entry["summary"] = entry["summary"].replace(old, new)
        entry["keyFigures"] = [{"name": name, "role": role} for name, role in KEY_FIGURES[n]]
        theme_map = THEMES[n]
        seen = set()
        for theme in entry["keyThemes"]:
            name = theme["theme"]
            if name not in theme_map:
                raise SystemExit(f"Acts {n}: no explanation drafted for theme {name!r}")
            theme["explanation"] = theme_map[name]
            seen.add(name)
        missing = set(theme_map) - seen
        if missing:
            raise SystemExit(f"Acts {n}: drafted themes not in source: {missing}")
        if len(entry["keyFigures"]) > 6:
            raise SystemExit(f"Acts {n}: {len(entry['keyFigures'])} key figures (max 6)")
        if len(entry["whereWeAre"]) > 600:
            raise SystemExit(f"Acts {n}: whereWeAre is {len(entry['whereWeAre'])} characters (max 600)")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


AUDIENCE_FIXES = {
    2: ("Readers who knew that pilgrims from a dozen distant regions normally could not understand "
        "each other without a shared trade language would have recognized the crowd's ability to "
        "hear the apostles in their own native tongues as a deliberate reversal of the confusion at "
        "Babel."),
    4: ("Readers who knew that the same priestly family had handed Jesus over to Pilate only weeks "
        "earlier would have recognized Peter and John facing that very court as picking up a "
        "confrontation the authorities likely hoped had ended with the crucifixion."),
    6: ("Readers who knew that Greek-speaking and Aramaic-speaking Jews worshiped and organized "
        "charity somewhat separately even within the same city would have recognized the apostles' "
        "solution, appointing leaders with Greek names to fix a Greek-speaking community's "
        "complaint, as a deliberately even-handed response rather than a token gesture."),
    8: ("Readers who knew that Jews and Samaritans normally avoided each other, and that a court "
        "official from a distant African kingdom would have had almost no access to a private "
        "Jewish teacher otherwise, would have recognized both encounters as crossing boundaries the "
        "gospel had not yet crossed in Jerusalem."),
    12: ("Readers who remembered Peter's earlier escape from a Jerusalem jail (Acts 5:19) would "
         "have recognized this second angelic rescue, and Herod's own sudden death shortly after "
         "accepting worship as a god, as framing the chapter's real contrast between a king's "
         "claimed power and its actual limits."),
    15: ("Readers who knew that circumcision was the single clearest marker separating Jews from "
         "Gentiles in the ancient world would have recognized how much was actually being decided "
         "when the Jerusalem council chose not to require it of new Gentile believers."),
    17: ("Readers who knew that Thessalonica, Berea, and Athens each had a very different kind of "
         "audience, a Jewish synagogue, an unusually open synagogue, and a civic council of "
         "philosophers, would have recognized Paul adjusting his method each time while never "
         "changing his actual message."),
    18: ("Readers who knew that Jewish tentmakers and artisans often formed close working "
         "partnerships that doubled as lodging arrangements would have recognized Paul's extended "
         "stay with Aquila and Priscilla as both an economic and a teaching relationship, not "
         "simply a long visit."),
    20: ("Readers who knew how unusual it was for a traveling teacher to bypass a city entirely "
         "rather than risk the delay of a proper visit would have felt the urgency behind Paul "
         "calling the Ephesian elders to meet him at the port instead, rather than go to them "
         "himself."),
    21: ("Readers who knew that the Antonia fortress stood right beside the temple specifically so "
         "Roman troops could respond within minutes to any disturbance in the courts below would "
         "have recognized how quickly, and how routinely, that rescue happened."),
    22: ("Readers who knew that Roman law normally allowed a citizen facing examination to invoke "
         "that status before being struck, not after, would have recognized how perilously close "
         "the soldiers had already come to breaking the law before Paul spoke up."),
    28: ("Readers who knew that a prisoner awaiting trial in Rome normally had far less freedom "
         "than renting his own lodging and receiving all who came to him would have recognized how "
         "unusually open Paul's two years of custody actually were."),
}


def apply_chapter_context():
    path = ROOT / "chapter_context" / "35_acts.json"
    data = load(path)
    for n, new_audience in AUDIENCE_FIXES.items():
        key = f"Acts {n}"
        old_audience = data[key]["audience"]
        data[key]["audience"] = new_audience
        if old_audience == new_audience:
            raise SystemExit(f"Acts {n}: audience fix made no change")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


OVERVIEW_FIXES = [
    ("To show how the risen Jesus continues His mission through the Holy Spirit as the gospel "
     "moves from Jerusalem to Judea, Samaria, and the wider Roman world.",
     "To show how the risen Jesus continues his mission through the Holy Spirit as the gospel "
     "moves from Jerusalem to Judea, Samaria, and the wider Roman world."),
    ("The risen Lord who ascends and continues His work through the Spirit and His witnesses.",
     "The risen Lord who ascends and continues his work through the Spirit and his witnesses."),
    ("Paul's coworkers on later journeys; Luke appears in the 'we' passages.",
     "Paul's coworkers on later journeys; Luke appears in the \"we\" passages."),
]


def apply_book_overview():
    path = ROOT / "book_overviews" / "07_gospels_acts.json"
    data = load(path)
    acts = data["Acts"]
    text = json.dumps(acts, ensure_ascii=False)
    for old, new in OVERVIEW_FIXES:
        if old not in text:
            raise SystemExit(f"Acts overview: fix not found: {old!r}")
    acts["purpose"] = acts["purpose"].replace(*OVERVIEW_FIXES[0])
    for figure in acts["keyFigures"]:
        if figure["name"] == "Jesus":
            figure["description"] = figure["description"].replace(*OVERVIEW_FIXES[1])
        if figure["name"] == "Silas, Timothy, and Luke":
            figure["description"] = figure["description"].replace(*OVERVIEW_FIXES[2])
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_PRONOUN_FIXES = [
    ("and His followers prepare to continue His work by choosing a replacement for Judas.",
     "and his followers prepare to continue his work by choosing a replacement for Judas."),
    ("After His resurrection, Jesus appears to the apostles over forty days",
     "After his resurrection, Jesus appears to the apostles over forty days"),
    ("They ask if He will now restore the kingdom to Israel. He answers,",
     "They ask if he will now restore the kingdom to Israel. he answers,"),
    ("Mary the mother of Jesus, and His brothers, about 120 believers in all.",
     "Mary the mother of Jesus, and his brothers, about 120 believers in all."),
    ("God has poured out His Spirit, just as He promised.",
     "God has poured out his Spirit, just as he promised."),
    ("because God will judge the world by the man He raised from the dead.",
     "because God will judge the world by the man he raised from the dead."),
    ("James and the elders welcome Paul and praise God for what He has done among the Gentiles.",
     "James and the elders welcome Paul and praise God for what he has done among the Gentiles."),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "07_gospels_acts.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("# Acts")
    section = text[start:]
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
    path.write_text(text[:start] + section, encoding="utf-8")
    print(f"Updated {path.relative_to(ROOT)}")


if __name__ == "__main__":
    apply_chapter_insights()
    apply_chapter_context()
    apply_book_overview()
    apply_story_fixes()
