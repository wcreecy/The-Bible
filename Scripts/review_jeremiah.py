#!/usr/bin/env python3
"""Apply the completed editorial review for Jeremiah to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


WWA = {
    1: "Isaiah's final chapters pictured nations gathered to witness God's glory even as idolatry still faced judgment. Jeremiah opens very differently: a young priest's son from Anathoth is called before his birth to be a prophet to the nations, right as Judah's last kings begin their decline. Chapter 2 opens his first extended message, recalling Israel's youthful devotion before indicting the present generation's unfaithfulness.",
    2: "Chapter 1 ended with Jeremiah commissioned and warned that Judah itself, not just a foreign army, would resist his message. Here his first message begins: God recalls Israel's early devotion in the wilderness and charges Judah with trading the fountain of living water for broken cisterns and foreign alliances. Chapter 3 continues the charge, comparing Judah's unfaithfulness to a formal divorce and inviting the backsliding nation to return.",
    3: "Chapter 2 charged Judah with abandoning God for idols and foreign powers. Here Jeremiah compares Judah to a wife worse than her already-divorced sister, the northern kingdom, yet still invites both to return and promises shepherds after God's own heart. Chapter 4 answers that invitation with a demand for sincere repentance before shifting to an urgent alarm of invasion.",
    4: "Chapter 3 invited Judah to return with a sincere heart. Here Jeremiah first presses that same call to genuine repentance, then the tone breaks into urgent alarm: a destroyer from the north is coming, and the prophet pictures the land itself undone like the darkness before creation. Chapter 5 continues the indictment, as God sends Jeremiah searching Jerusalem's streets for even one honest person.",
    5: "Chapter 4 raised the alarm over an invader from the north. Here God sends Jeremiah through Jerusalem's streets to find even one person who does justly, and finds none among rich or poor, while a powerful nation is announced as the instrument of judgment. Chapter 6 continues the siege warning, naming the approaching army and the leaders who falsely promise peace.",
    6: "Chapter 5 found no one in Jerusalem practicing justice. Here the invading army draws closer: trumpets sound the alarm, leaders offer false reassurances of peace, and the chapter closes picturing the people as rejected silver that refining cannot purify. Chapter 7 moves the warning to the temple gate itself, as Jeremiah confronts worshipers trusting the building rather than God.",
    7: "Chapter 6 closed comparing the people to metal that refining cannot purify. Here Jeremiah stands at the gate of the LORD's house and warns worshipers that the temple is no guarantee of safety, recalling the ruined sanctuary at Shiloh and condemning child sacrifice at Topheth. Chapter 8 continues this temple sermon's themes of judgment and grief, mourning a people who refuse to turn back.",
    8: "Chapter 7 warned that the temple could not shield a disobedient people from judgment. Here that judgment is pictured as the disgrace of disturbed graves and a wound no one will heal, as Jeremiah grieves that scribes and leaders claim wisdom they do not have. Chapter 9 continues the lament, as Jeremiah longs to weep without ceasing for his people.",
    9: "Chapter 8 ended with Jeremiah asking why no healing has come to his people. Here he wishes for tears enough to weep day and night over their slain, while God instructs trained mourners to lament and redirects true boasting away from wisdom, strength, and wealth toward knowing God. Chapter 10 turns from this lament to a direct contrast between handmade idols and the living God.",
    10: "Chapter 9 redirected true boasting toward knowing the LORD rather than wisdom, strength, or wealth. Here that contrast sharpens: idols shaped by craftsmen are mocked as lifeless, while the LORD is praised as maker of heaven and earth, before a warning of coming exile and a prayer pleading for correction rather than destruction. Chapter 11 turns to Judah's own broken promises, as Jeremiah proclaims the terms of the covenant it has forsaken.",
    11: "Chapter 10 closed with a prayer pleading for correction rather than full destruction. Here Jeremiah proclaims the covenant's words and its curses for disobedience, then learns that the men of his own hometown, Anathoth, are plotting to kill him for it. Chapter 12 continues with Jeremiah's protest over that betrayal and his larger question of why the wicked prosper.",
    12: "Chapter 11 ended with a plot against Jeremiah's life from his own townspeople. Here he presses that painful experience into a larger question, asking why the wicked prosper, and receives a demanding answer about harder trials still to come, alongside a conditional promise for Judah's neighboring peoples. Chapter 13 turns from questions to a dramatized sign: a ruined linen girdle acting out Judah's ruined pride.",
    13: "Chapter 12 ended with neighboring nations conditionally promised inclusion if they learn God's ways. Here Jeremiah acts out Judah's own fate instead: a linen girdle buried and later found rotten pictures ruined pride, followed by a wine-jar saying and a vivid warning of Jerusalem's coming shame. Chapter 14 turns to a different kind of national distress: a severe drought testing the land.",
    14: "Chapter 13 pictured Judah's pride ruined like a spoiled linen girdle. Here a severe drought tests the land instead, and the people's confession of sin is met not with relief but with God's refusal of prophets who promise peace without his authorization. Chapter 15 continues this refusal, declaring that not even Moses or Samuel could now turn judgment aside.",
    15: "Chapter 14 showed God rejecting prophets who promised peace during the drought. Here that refusal is stated even more starkly: not even Moses or Samuel's intercession could turn judgment away, before the chapter turns inward to Jeremiah's own raw protest and his renewed commission to keep speaking God's words. Chapter 16 continues this personal cost, as Jeremiah's own life becomes a sign of the judgment he proclaims.",
    16: "Chapter 15 ended with Jeremiah's vocation renewed despite his anguish. Here that vocation reshapes his daily life: he is told not to marry, mourn, or feast, so that his very household becomes a visible warning of coming exile, though the chapter still promises an eventual regathering beyond it. Chapter 17 turns from Jeremiah's sign-acts to a broader meditation on trust, the deceitful heart, and Jerusalem's sabbath.",
    17: "Chapter 16 showed Jeremiah's restricted life acting out Judah's coming exile. Here the focus widens to the human heart itself, contrasting trust in human strength with trust in the LORD, before a closing sermon at Jerusalem's gates calls the city to honor the sabbath instead of ordinary commerce. Chapter 18 returns to acted-out prophecy at the potter's house, picturing God's freedom to reshape any nation's future.",
    18: "Chapter 17 closed with a sermon calling Jerusalem to honor the sabbath. Here God sends Jeremiah to watch a potter reworking flawed clay, a picture of his freedom to relent or to judge depending on a nation's response, and opponents respond to this message by plotting against the prophet himself. Chapter 19 takes the potter's image further, as Jeremiah breaks a finished jar beyond repair to show that Jerusalem's coming judgment cannot be reshaped away.",
    19: "Chapter 18 pictured clay that could still be reworked while soft. Here Jeremiah buys a finished pottery jar instead and breaks it before the elders and priests at Topheth, showing that Jerusalem's judgment, like fired clay, can no longer be undone. Chapter 20 shows the cost of that broken-jar sermon landing on Jeremiah personally, as the priest Pashhur has him beaten and put in the stocks.",
    20: "Chapter 19 ended with Jeremiah breaking a jar to announce Jerusalem's irreversible judgment. Here the priest-official Pashhur answers that sermon by beating Jeremiah and locking him in the stocks, and the prophet's own anguish spills out afterward in the book's rawest lament, including a wish that he had never been born. Chapter 21 turns from Jeremiah's private suffering to a formal, public exchange with King Zedekiah himself.",
    21: "Chapter 20 closed with Jeremiah's most anguished personal lament. Here the setting shifts to the royal court: King Zedekiah sends envoys hoping for an encouraging word as Babylon's army closes in, but Jeremiah instead urges surrender and calls the royal house to practice justice for the oppressed. Chapter 22 continues addressing Judah's kings directly, reviewing the fates of Jehoiakim's predecessor, himself, and his successor.",
    22: "Chapter 21 warned Zedekiah that resistance to Babylon would fail. Here Jeremiah reviews Judah's recent kings by name, demanding justice and mercy from the royal house and condemning Jehoiakim's exploitative building projects, while pronouncing that Jehoiachin will leave for exile and never return. Chapter 23 answers this record of failed kings with the promise of a different kind of ruler, a righteous Branch from David's line.",
    23: "Chapter 22 closed naming Judah's recent kings as failures who exploited rather than protected their people. Here God condemns the shepherds who scattered the flock and promises a righteous Branch from David instead, before turning to the false prophets whose comforting dreams and borrowed words mislead the very people they claim to serve. Chapter 24 moves from these warnings about false voices to a vision clarifying who actually carries hope after the first deportation.",
    24: "Chapter 23 warned against false prophets who mislead with empty comfort. Here, after Jehoiachin's exiles have already been deported to Babylon, God shows Jeremiah two baskets of figs and overturns easy assumptions: the exiles already in Babylon are the good figs with a future, while those remaining under Zedekiah are the bad figs headed for disaster. Chapter 25 widens this same reversal into a dated, formal review of twenty-three years of ignored warnings.",
    25: "Chapter 24 pictured the Babylonian exiles, not those who stayed, as the ones with real hope. Here, in Jehoiakim's fourth year, Jeremiah reviews twenty-three years of warnings Judah refused to hear, announces Babylonian conquest followed by seventy years of service, and extends a cup of God's wrath to many nations beyond Judah. Chapter 26 shows what it actually cost Jeremiah to deliver a related message in public: a trial for his life at the temple.",
    26: "Chapter 25 pronounced judgment on many nations from a safe distance of years. Here that same kind of warning, delivered face to face at the temple, nearly gets Jeremiah killed; elders defend him by recalling the earlier prophet Micah, though another prophet, Uriah, is extradited and executed for saying much the same thing. Chapter 27 shows Jeremiah facing down a similar danger, this time by wearing a yoke to warn Judah and its neighbors against resisting Babylon.",
    27: "Chapter 26 showed Jeremiah barely surviving a death sentence for his temple warning. Here he risks confrontation again, wearing a wooden yoke to urge Judah and the envoys of neighboring nations to accept Babylonian rule rather than trust predictions of quick freedom. Chapter 28 shows exactly that kind of false prediction arriving publicly, as the prophet Hananiah breaks Jeremiah's yoke before the watching crowd.",
    28: "Chapter 27 had Jeremiah wear a yoke as a sign of submission to Babylon. Here the prophet Hananiah publicly breaks that yoke and promises a two-year deliverance, so Jeremiah answers with an iron yoke and a prediction of Hananiah's own death within the year, which the chapter reports happening. Chapter 29 takes this same conflict over false hope to the exiles already living in Babylon.",
    29: "Chapter 28 showed a false prophet's promise of quick deliverance collapsing within the year. Here Jeremiah writes directly to the exiles already in Babylon, telling them to build houses, plant gardens, and seek their captors' peace rather than wait for a rescue Hananiah's kind keeps promising, while still holding out hope for an eventual return. Chapters 30 and 31 open the book's fullest promises of restoration, the oracles the exiles were told to wait for.",
    30: "Chapter 29 told the exiles to settle into Babylon while still trusting a future return. Here that future arrives in writing: God tells Jeremiah to record promises of healing, regathering, and relief from foreign oppression, even naming the coming crisis 'the time of Jacob's trouble' from which his people will still be saved. Chapter 31 continues this same promise of restoration, reaching its high point in a new covenant written on the heart.",
    31: "Chapter 30 opened the Book of Consolation with promises of healing and regathering. Here that hope reaches its height: Israel and Judah are promised joy, planting, and a homecoming so real that even Rachel's poetic grief is answered, and God announces a new covenant in which his instruction is written on hearts rather than stone. Chapter 32 grounds this same hope in an ordinary, costly transaction: Jeremiah buying a field while Jerusalem is under siege.",
    32: "Chapter 31 promised a new covenant written on the heart. Here that promise is acted out in a very practical way: during Jerusalem's siege, with Jeremiah himself imprisoned, he buys his cousin's field at Anathoth and has the deed sealed and stored as a sign that houses and fields will be owned again in the land. Chapter 33 continues this same promise of future normal life while Jeremiah remains confined.",
    33: "Chapter 32 enacted hope through the purchase of a field during siege. Here, still shut up in the court of the prison, Jeremiah receives further promises of healing, forgiveness, celebration, and renewal for both the Davidic throne and the priestly line, pictured as reliable as day following night. Chapter 34 turns from these promises back to the present siege, where a very different test of faithfulness is unfolding.",
    34: "Chapter 33 promised that David's line and the priestly line would endure as surely as day and night. Here that same test of faithfulness plays out in the present: as Babylon attacks, Judah's leaders free their Hebrew slaves under covenant and then violently take them back, a betrayal God condemns in the strongest terms. Chapter 35 contrasts this broken covenant with a very different family's quiet, generations-long faithfulness.",
    35: "Chapter 34 condemned Judah for breaking its covenant to free Hebrew slaves. Here the Rechabites model the opposite: brought into the temple and offered wine, they refuse because their ancestor commanded a simple, disciplined way of life generations earlier, and God holds up their loyalty to shame Judah's refusal to heed his own repeated warnings. Chapter 36 returns to Jeremiah's own struggle to be heard, as his written words face a king's direct hostility.",
    36: "Chapter 35 held up the Rechabites' quiet obedience against Judah's refusal to listen. Here Jeremiah's own warnings reach their most dramatic rejection: Baruch writes them on a scroll and reads them publicly, but King Jehoiakim cuts the scroll apart and burns it, only for Jeremiah to dictate it again with more added. Chapter 37 shows Jeremiah's message facing renewed danger under a different king, Zedekiah, as the Babylonian siege itself briefly lifts.",
    37: "Chapter 36 showed a king's violence unable to destroy Jeremiah's written word. Here Zedekiah seeks Jeremiah's prayer as Babylon's army temporarily withdraws before an Egyptian advance, but Jeremiah insists Babylon will return, and his honesty earns him imprisonment on a false charge of desertion. Chapter 38 shows that imprisonment grow even more dangerous, as officials lower Jeremiah into a muddy cistern to silence him for good.",
    38: "Chapter 37 ended with Jeremiah imprisoned on a false charge. Here officials escalate further, lowering him into a muddy cistern to die, until Ebed-melech, a Cushite official, intervenes to save him, and Jeremiah still privately urges Zedekiah to surrender even though the frightened king cannot bring himself to obey. Chapter 39 shows the siege finally reaching the outcome Jeremiah had long predicted: Jerusalem's fall.",
    39: "Chapter 38 ended with Zedekiah unable to act on Jeremiah's advice to surrender. Here Babylon finally breaches the city: Zedekiah is captured fleeing, leading Judeans are executed, Jerusalem is burned, and most of its people are deported, while Jeremiah is protected by Babylonian orders and Ebed-melech is promised deliverance for trusting God. Chapter 40 follows Jeremiah immediately afterward, as he is released and joins the newly appointed governor, Gedaliah.",
    40: "Chapter 39 ended with Jerusalem's fall and Jeremiah's release from captivity. Here he joins Gedaliah, whom Babylon has appointed governor over the land's remaining population, as scattered Judeans return and begin gathering a harvest, even though a warning reaches Gedaliah that a man named Ishmael is plotting to kill him. Chapter 41 shows that warning tragically realized.",
    41: "Chapter 40 ended with Gedaliah dismissing a warning about Ishmael's plot against him. Here that plot succeeds: Ishmael murders Gedaliah and others at Mizpah, attacks visiting pilgrims, and carries off captives before Johanan's forces catch up and rescue them, leaving the survivors afraid of Babylonian retaliation. Chapter 42 shows those frightened survivors turning to Jeremiah for guidance about what to do next.",
    42: "Chapter 41 left the survivors of Gedaliah's murder fearing Babylon's revenge. Here they ask Jeremiah to seek God's direction and promise to obey whatever he says, but after ten days he tells them to stay in Judah rather than flee to Egypt, warning that the very dangers they fear will follow them there. Chapter 43 shows them breaking that promise almost immediately.",
    43: "Chapter 42 had Jeremiah warn the remnant that fleeing to Egypt would not bring safety. Here the leaders reject that word anyway and take the whole remnant, including Jeremiah and Baruch, down to Egypt, where Jeremiah buries stones at Pharaoh's palace in Tahpanhes to show that Babylon will reach them even there. Chapter 44 continues this Egyptian setting, as Jeremiah confronts the exiles' continuing idolatry directly.",
    44: "Chapter 43 showed Jeremiah announcing that Babylon would follow the remnant into Egypt. Here he confronts that same community for worshiping the 'queen of heaven,' and when the people openly defend the practice, he answers with a further warning, including a sign concerning Pharaoh Hophra's own downfall. Chapter 45 steps back from this public conflict to a brief, personal word for Jeremiah's own weary scribe, Baruch.",
    45: "Chapter 44 ended with a public warning to idolatrous exiles in Egypt. Here the focus narrows to one person: Baruch, discouraged by the weight of writing Jeremiah's prophecies years earlier, is told not to seek greatness for himself but is promised that his life will be spared amid the coming upheaval. Chapter 46 turns outward again to the first of several oracles against foreign nations, beginning with Egypt itself.",
    46: "Chapter 45 closed with a promise that Baruch's own life would be spared. Here the book turns to oracles against the nations, opening with Egypt: Pharaoh Necho's army is defeated at Carchemish, Egyptian pride is shown as fragile, yet Israel is reassured it will not be utterly destroyed as the nations around it are judged. Chapter 47 continues this sequence of judgment with a short oracle against the Philistines.",
    47: "Chapter 46 judged Egypt's pride despite its ancient power. Here a brief oracle turns to the Philistine cities of Gaza and Ashkelon, pictured overwhelmed by flood and sword imagery that will not rest until its commissioned work is finished. Chapter 48 continues the sequence with a much longer oracle against Judah's neighbor to the east, Moab.",
    48: "Chapter 47 pronounced a short judgment on the Philistine coast. Here a long oracle catalogs Moab's cities one by one, condemning its pride and its confidence in the god Chemosh, picturing shattered jars and fleeing refugees, though even here a final promise of restoration keeps judgment from being the last word. Chapter 49 continues this same pattern of judgment and hope across several more of Judah's neighbors.",
    49: "Chapter 48 closed Moab's judgment with a promise of future restoration. Here that same pattern repeats across Ammon, Edom, Damascus, the desert peoples of Kedar and Hazor, and Elam, each shown that territory, military strength, or wealth cannot exempt a nation from God's scrutiny. Chapter 50 turns this same kind of judgment onto the empire that has carried out all the others: Babylon itself.",
    50: "Chapter 49 completed a wide circuit of judgment against Judah's neighboring nations. Here the oracle turns to the greatest power of all: Babylon, the very empire God used to punish Judah, is told it will itself be overthrown, while Israel and Judah are pictured seeking their God again and exiles are invited to flee before Babylon's fall. Chapter 51 continues this same oracle against Babylon at even greater length.",
    51: "Chapter 50 began the oracle against Babylon's cruelty, idolatry, and false security. Here that oracle continues and intensifies, vindicating Zion and ending with Jeremiah instructing Seraiah to read the scroll aloud in Babylon, tie a stone to it, and sink it in the Euphrates as a sign that Babylon's own fall is just as certain. Chapter 52 closes the book with a historical account of the fall that both this oracle and the whole book have been pointing toward.",
    52: "Chapter 51 closed Jeremiah's own prophetic words with a scroll sunk in the Euphrates as a sign of Babylon's certain fall. Here a historical appendix completes the book: Zedekiah's rebellion, Jerusalem's siege and burning, the temple's stripped furnishings, and the final numbers of those deported are recorded, before Jehoiachin's unexpected release from Babylonian prison ends the book on a restrained note of hope. The next book, Lamentations, stays with this same devastation, giving voice to the grief Jerusalem's fall leaves behind.",
}

SUMMARY = {
    1: "The LORD calls Jeremiah before his birth and appoints him a prophet to the nations, though he protests that he is too young to speak (Jeremiah 1:4-10). God touches his mouth, promises him the words to speak, and shows him an almond branch and a boiling pot tilted from the north, signs of judgment advancing on Judah for its own wrongdoing (Jeremiah 1:11-16). God warns that Jeremiah will face fierce resistance, yet promises to make him as unbreakable as a fortified city and a bronze wall (Jeremiah 1:17-19).",
    2: "God recalls Israel's early devotion in the wilderness and charges Judah with abandoning the fountain of living water for broken, useless cisterns (Jeremiah 2:1-13). The chapter names devotion to other gods and political dependence on Egypt and Assyria as the same underlying betrayal (Jeremiah 2:14-19). Judah denies any wrongdoing despite the charges, even as God insists the evidence of its unfaithfulness is plain (Jeremiah 2:20-37).",
    3: "Jeremiah compares Judah and Israel's unfaithfulness to a wife worse than her own divorced sister, recalling the northern kingdom's earlier downfall (Jeremiah 3:1-11). He nevertheless calls the people to return and confess their guilt, promising shepherds after God's own heart (Jeremiah 3:12-15). The chapter closes picturing a future gathering of the nations to Jerusalem and a reunited Israel and Judah coming home together (Jeremiah 3:16-18).",
    4: "Jeremiah calls Israel and Judah to a genuine return marked by justice and renewed hearts, not empty ritual (Jeremiah 4:1-4). The tone then breaks into urgent alarm as a destroyer from the north advances toward Jerusalem, sounded by trumpets and watched for in fortified towns (Jeremiah 4:5-18). Jeremiah pictures the devastation in the language of creation undone, grieving a disaster he cannot escape even as he announces it (Jeremiah 4:19-31).",
    5: "God challenges Jeremiah to search Jerusalem for even one person who practices justice and truth, and he finds none among the poor or the powerful (Jeremiah 5:1-9). Leaders and ordinary people alike are accused of rejecting correction and exploiting the vulnerable for their own gain (Jeremiah 5:10-31). A powerful foreign nation is announced as the agent of coming judgment, though the chapter insists that Judah's ruin will not be absolute (Jeremiah 5:15-19).",
    6: "An invading army threatens Jerusalem from the north, and the people are urged to seek the ancient paths while there is still time (Jeremiah 6:1-16). They refuse the warning, and leaders offer false reassurances of peace even as disaster nears (Jeremiah 6:13-15). The chapter closes comparing the people to silver that refining cannot purify, rejected because their corruption runs too deep to remove (Jeremiah 6:27-30).",
    7: "At the temple gate, Jeremiah warns worshipers not to trust the sanctuary itself as a guarantee of safety while they steal, murder, and serve other gods (Jeremiah 7:1-11). He demands justice for immigrants, orphans, and widows, and recalls Shiloh's ruin as proof that no sanctuary is beyond judgment (Jeremiah 7:5-15). The message condemns child sacrifice at Topheth in the Valley of Hinnom and foresees devastation for a people who will not change (Jeremiah 7:29-34).",
    8: "Judgment is pictured through the humiliation of disturbed graves and a people who refuse every chance to repent (Jeremiah 8:1-7). Scribes and religious leaders wrongly claim wisdom while treating the nation's wound as a light thing (Jeremiah 8:8-12). Jeremiah grieves for his people, asking why no healing has come though a balm is available in Gilead (Jeremiah 8:18-22).",
    9: "Jeremiah longs for tears enough to weep without ceasing over the deceit and violence filling his nation (Jeremiah 9:1-9). God announces judgment and instructs professional mourners to lament for what is coming (Jeremiah 9:10-22). The chapter rejects boasting in wisdom, strength, or wealth and commends instead knowing God's justice, mercy, and righteousness (Jeremiah 9:23-26).",
    10: "The chapter contrasts idols shaped by craftsmen, unable to speak or move, with the living God who made the heavens and earth (Jeremiah 10:1-16). It turns to warn of coming exile, picturing tents suddenly struck and children scattered (Jeremiah 10:17-22). Jeremiah closes with a humble, communal prayer asking for correction in just measure rather than complete destruction (Jeremiah 10:23-25).",
    11: "Jeremiah proclaims the terms of the covenant and warns that its curses have come into view because of persistent disobedience (Jeremiah 11:1-8). God tells him not to intercede for the people, since their idolatry has multiplied as fast as their cities (Jeremiah 11:11-17). Jeremiah then learns that the men of his own hometown, Anathoth, are plotting to kill him for his message (Jeremiah 11:18-23).",
    12: "Jeremiah asks God why the wicked prosper and why the whole land suffers for their wrongdoing (Jeremiah 12:1-4). God's answer is demanding rather than comforting, warning Jeremiah that harder trials, pictured as running with horses, still lie ahead (Jeremiah 12:5-6). The chapter closes addressing Judah's neighboring nations, promising their removal from the land but also a conditional future inclusion if they learn God's ways (Jeremiah 12:14-17).",
    13: "Jeremiah buries a linen girdle near the Euphrates and later finds it ruined, a sign of Judah's pride spoiled by its own stubbornness (Jeremiah 13:1-11). A wine-jar saying announces coming disorientation, picturing a nation stumbling as if drunk (Jeremiah 13:12-14). Judah is summoned to humility before its glory is darkened, while Jerusalem's coming shame is described in deliberately disturbing terms of exposure (Jeremiah 13:15-27).",
    14: "A severe drought dries up Judah's cisterns and fields, leaving even wild animals to suffer (Jeremiah 14:1-6). The people confess their wrongdoing and plead for mercy, but God condemns prophets who promise peace without his authorization (Jeremiah 14:7-16). Jeremiah laments the combined suffering of sword, famine, and religious deception sweeping over the land (Jeremiah 14:17-22).",
    15: "God announces that even famous intercessors like Moses and Samuel could not now avert the coming judgment, because of what Manasseh did in Jerusalem (Jeremiah 15:1-9). Jeremiah protests the weight of his calling, accusing God of making him a man of strife to the whole earth (Jeremiah 15:10-18). God answers with a renewed commission, promising to make Jeremiah a fortified bronze wall if he keeps speaking faithfully (Jeremiah 15:19-21).",
    16: "Jeremiah is told not to marry, mourn, or feast, so that his own restricted life becomes a visible sign of the catastrophe coming on Judah's families (Jeremiah 16:1-9). Persistent idolatry is named as the reason exile is coming, generations deep and inherited from the fathers (Jeremiah 16:10-13). Yet the chapter still promises a future regathering so complete it will eclipse even the memory of the exodus from Egypt (Jeremiah 16:14-21).",
    17: "Judah's sin is pictured as engraved deeply into the nation, while trust in human strength is contrasted with the lasting security of trusting the LORD (Jeremiah 17:1-8). The human heart is described as deceitful above all things, prompting Jeremiah's own prayer for healing (Jeremiah 17:9-14). A final sermon at Jerusalem's gates calls the city to honor the sabbath rather than carry on ordinary commerce, with blessing or judgment depending on the answer (Jeremiah 17:19-27).",
    18: "God sends Jeremiah to watch a potter reshape spoiled clay, an image of his freedom to relent from judgment or withdraw a blessing depending on a nation's response (Jeremiah 18:1-10). Jerusalem's leaders reject this warning outright, insisting they will keep following their own devices regardless (Jeremiah 18:11-12). Opponents then plot against Jeremiah himself, prompting his anguished prayer that God remember how he stood in the breach for them (Jeremiah 18:18-23).",
    19: "God sends Jeremiah to buy a potter's earthen jar and gather elders and priests at the Valley of Hinnom to hear a message of judgment (Jeremiah 19:1-9). He denounces the bloodshed and idolatrous worship carried out at Topheth, including child sacrifice (Jeremiah 19:4-6). Breaking the jar before them signals that Jerusalem's coming destruction, unlike reworkable wet clay, cannot now be undone (Jeremiah 19:10-15).",
    20: "The priest-official Pashhur has Jeremiah beaten and locked in the stocks for his temple prophecy (Jeremiah 20:1-2). Released the next day, Jeremiah announces judgment on Pashhur by name and reframes his own ordeal as the costly burden of speaking God's word faithfully (Jeremiah 20:3-6). The chapter ends with Jeremiah's rawest lament, torn between an inner fire that compels him to speak and a despair deep enough to curse the day of his birth (Jeremiah 20:7-18).",
    21: "King Zedekiah sends envoys to Jeremiah during Babylon's siege, hoping for an encouraging answer like deliverances God gave in the past (Jeremiah 21:1-2). Jeremiah instead declares that God himself will fight against the city, and urges those who want to live to surrender to the besieging army (Jeremiah 21:3-10). The royal house is commanded to practice justice every morning, especially for the oppressed, or face the same fire-like judgment (Jeremiah 21:11-14).",
    22: "Jeremiah confronts Judah's royal house with God's demand for justice and mercy toward the vulnerable, warning that the palace itself will become a ruin without it (Jeremiah 22:1-9). He addresses the fates of three kings by name: Shallum, taken to Egypt never to return; Jehoiakim, condemned for forcing unpaid labor to build a lavish palace; and Coniah, who will be cast off and leave for exile (Jeremiah 22:10-30). The chapter contrasts this royal failure with Josiah's example of judging the cause of the poor and needy (Jeremiah 22:15-16).",
    23: "God condemns the shepherds, Judah's kings, who have scattered rather than cared for his flock, and promises to gather the remnant himself (Jeremiah 23:1-4). A righteous Branch from David is announced, a king who will reign wisely and bear the name 'THE LORD OUR RIGHTEOUSNESS' (Jeremiah 23:5-6). The chapter then turns to extended warnings against prophets whose invented dreams and borrowed words mislead the people, contrasted with God's true word, like fire and a hammer breaking rock (Jeremiah 23:16-32).",
    24: "After King Jehoiachin's deportation to Babylon, God shows Jeremiah two baskets of figs set before the temple (Jeremiah 24:1-3). The exiles already carried to Babylon are compared to good figs, promised a future heart to know the LORD and an eventual return (Jeremiah 24:4-7). Those remaining under Zedekiah or fleeing to Egypt are compared instead to figs too rotten to eat, destined for further disaster (Jeremiah 24:8-10).",
    25: "In Jehoiakim's fourth year, Jeremiah reviews twenty-three years of warnings that Judah has refused to hear despite his rising early to speak (Jeremiah 25:1-7). He announces that Babylon will devastate the land and that these nations will serve Babylon for seventy years, after which Babylon itself will be judged in turn (Jeremiah 25:8-14). Jeremiah is told to make many nations drink a cup of God's wrath, a judgment that reaches from Jerusalem to the ends of the earth (Jeremiah 25:15-29).",
    26: "Early in Jehoiakim's reign, Jeremiah preaches at the temple that it could become like ruined Shiloh if the people do not turn back, and priests and prophets seize him and demand his execution (Jeremiah 26:1-11). Jeremiah defends his mission before the officials, and elders recall that the earlier prophet Micah gave a similar warning in Hezekiah's day without being put to death (Jeremiah 26:12-19). The chapter also records the fate of another prophet, Uriah, extradited from Egypt and killed by Jehoiakim, showing how real the danger was that spared Jeremiah through Ahikam's protection (Jeremiah 26:20-24).",
    27: "Jeremiah wears a wooden yoke and urges Judah, along with envoys from several neighboring nations, to accept Babylonian rule rather than trust predictions of swift freedom (Jeremiah 27:1-11). He warns Zedekiah directly that submission, not resistance, will preserve his life and the city (Jeremiah 27:12-15). He also tells the priests and people that the temple vessels will remain under Babylon's control, contradicting prophets who promised their quick return (Jeremiah 27:16-22).",
    28: "In the temple, the prophet Hananiah announces that Babylon's yoke will soon break and that exiles and temple objects will return within two years (Jeremiah 28:1-4). He breaks the wooden yoke from Jeremiah's neck as a dramatic sign of his claim (Jeremiah 28:10-11). Jeremiah answers that an iron yoke will replace it and predicts Hananiah's death within the year, which the chapter reports happening two months later (Jeremiah 28:12-17).",
    29: "Jeremiah writes to the exiles already deported to Babylon, telling them to build houses, plant gardens, marry, and seek the peace of the city where they now live rather than wait on false hopes of quick return (Jeremiah 29:1-9). He promises that after seventy years God will fulfill his good word toward them, including the well-known assurance of 'thoughts of peace, and not of evil' (Jeremiah 29:10-14). A conflict with the false prophet Shemaiah shows that disagreement over Jeremiah's message continues even among the exiles themselves (Jeremiah 29:24-32).",
    30: "God directs Jeremiah to write down promises of restoration so that the words will last (Jeremiah 30:1-3). The chapter describes a terrifying time of anguish, 'the time of Jacob's trouble,' from which God still promises to save his people (Jeremiah 30:4-11). It closes with healing after discipline, relief from foreign oppression, and the people restored once more to covenant belonging (Jeremiah 30:12-22).",
    31: "God promises restoration to Israel and Judah with images of renewed joy, planting, and a homecoming so real that it answers even the ancestral grief pictured in Rachel weeping for her children (Jeremiah 31:1-20). The chapter's center is a new covenant in which God's instruction is written on hearts rather than tablets of stone, and sins are forgiven and remembered no more (Jeremiah 31:31-34). It closes picturing Jerusalem itself rebuilt and measured out securely, never again to be uprooted (Jeremiah 31:38-40).",
    32: "During Jerusalem's siege, with Jeremiah himself imprisoned, God tells him that his cousin Hanamel will offer to sell him a field at Anathoth, and Jeremiah buys it even though the land is about to fall to Babylon (Jeremiah 32:1-15). Documents are signed, sealed, and stored in an earthen jar before witnesses, a sign that houses, fields, and vineyards will be possessed again in the land (Jeremiah 32:9-15). Jeremiah prays for understanding, and God answers by explaining both why Jerusalem must fall and how he will restore it afterward through an everlasting covenant (Jeremiah 32:36-44).",
    33: "While Jeremiah is still confined in the court of the prison, God again promises the restoration of Judah and Jerusalem, including healing, forgiveness, and renewed celebration (Jeremiah 33:1-11). He promises that the Davidic throne and the Levitical priesthood will continue, as reliable as the fixed cycle of day and night (Jeremiah 33:14-22). Some portions of the chapter are preserved only in the longer Hebrew textual tradition, a reminder that the book's transmission has its own history (Jeremiah 33:14-26).",
    34: "As Babylon attacks, Jeremiah tells Zedekiah plainly that Jerusalem will fall and that he will be taken captive to Babylon, though he will die in peace (Jeremiah 34:1-7). A covenant to free Hebrew slaves is made during the siege but then broken when former owners force the freed people back into slavery (Jeremiah 34:8-11). The LORD condemns this reversal as a betrayal of both liberty and covenant, promising the very 'liberty' of sword, pestilence, and famine instead (Jeremiah 34:12-22).",
    35: "Jeremiah brings the Rechabite family into the temple and sets wine before them, which they refuse because their ancestor Jonadab commanded a disciplined life free of wine and permanent houses generations earlier (Jeremiah 35:1-11). God contrasts their lasting obedience to a human command with Judah's refusal to heed warning after warning from him directly (Jeremiah 35:12-16). He promises the Rechabites an enduring place in his service as a rebuke to Judah's unfaithfulness (Jeremiah 35:18-19).",
    36: "In Jehoiakim's reign, Jeremiah dictates all his messages since Josiah's day to Baruch, who writes them on a scroll and reads them publicly at the temple (Jeremiah 36:1-10). Officials bring the scroll to the king, who cuts it apart and burns it piece by piece despite pleas to stop (Jeremiah 36:20-26). Jeremiah dictates another scroll with the same words and more besides, showing that the king's violence could destroy paper but not the message itself (Jeremiah 36:27-32).",
    37: "Zedekiah seeks Jeremiah's prayer as Babylon's siege temporarily lifts before an advancing Egyptian army (Jeremiah 37:1-5). Jeremiah insists Babylon will return and destroy the city regardless, a message so unwelcome that he is accused of deserting to the enemy and imprisoned (Jeremiah 37:11-15). Zedekiah later moves him to the court of the guard, where he receives bread daily until the city's food runs out (Jeremiah 37:17-21).",
    38: "Officials persuade Zedekiah to let them lower Jeremiah into a muddy cistern for urging surrender, leaving him to sink in the mire (Jeremiah 38:1-6). Ebed-melech, a Cushite official in the palace, intervenes with the king and organizes Jeremiah's rescue (Jeremiah 38:7-13). In a private meeting, Jeremiah again urges Zedekiah to surrender to save the city, but the king, afraid of what his own people might do, cannot bring himself to obey (Jeremiah 38:14-23).",
    39: "Babylon finally breaches Jerusalem's wall; Zedekiah flees but is captured, his sons are killed before him, and he is blinded and taken to Babylon in chains (Jeremiah 39:1-7). The city is burned, its walls broken down, and most of its people deported, though some of the poorest are left on the land (Jeremiah 39:8-10). Jeremiah is protected under direct orders from Nebuchadnezzar, and God promises deliverance to Ebed-melech because he trusted him (Jeremiah 39:11-18).",
    40: "Nebuzaradan releases Jeremiah from among the captives and lets him choose where to go; he stays in Judah with Gedaliah, the governor Babylon has appointed over the land's remaining population (Jeremiah 40:1-6). Scattered Judeans return as word of a stable governor spreads, and the land yields a great harvest of wine and summer fruit (Jeremiah 40:7-12). Johanan warns Gedaliah that Ishmael is plotting to kill him, but Gedaliah refuses to believe the report or act against it (Jeremiah 40:13-16).",
    41: "Ishmael, of the royal line, murders Gedaliah along with the Jews and Babylonian soldiers with him at Mizpah (Jeremiah 41:1-3). He then kills a group of pilgrims traveling to the ruined temple and throws their bodies into a cistern, before taking the rest of the town's people captive toward Ammon (Jeremiah 41:4-10). Johanan's forces catch Ishmael and rescue the captives, but the survivors, afraid of Babylonian retaliation for Gedaliah's murder, begin moving toward Egypt (Jeremiah 41:11-18).",
    42: "Johanan and the surviving remnant ask Jeremiah to seek God's guidance, promising in advance to obey whatever answer comes (Jeremiah 42:1-6). After ten days, Jeremiah tells them to remain in Judah, promising God's protection there and warning that the sword and famine they fear will instead overtake them in Egypt (Jeremiah 42:7-17). The chapter closes accusing the people of having already decided to flee regardless of what God's answer would be (Jeremiah 42:19-22).",
    43: "The leaders reject Jeremiah's word, accuse Baruch of turning him against them, and take the whole remnant, including Jeremiah and Baruch, down to Egypt (Jeremiah 43:1-7). At Tahpanhes, Jeremiah buries large stones in the pavement at Pharaoh's palace and announces that Nebuchadnezzar will one day set his throne on that very spot (Jeremiah 43:8-10). The act challenges the remnant's assumption that crossing into Egypt would place them beyond Babylon's reach (Jeremiah 43:11-13).",
    44: "Jeremiah addresses the Judean communities settled in Egypt and condemns their continued worship of the 'queen of heaven,' tracing Jerusalem's destruction directly to this same idolatry (Jeremiah 44:1-10). The people answer that life seemed better when they made offerings to her, and they openly refuse to stop (Jeremiah 44:15-19). Jeremiah rejects their reasoning and announces further judgment, including a sign that Pharaoh Hophra himself will be delivered into his enemies' hands (Jeremiah 44:24-30).",
    45: "Jeremiah delivers a short, personal message to Baruch from the fourth year of Jehoiakim, when Baruch was writing out the prophecies and grew weary with grief (Jeremiah 45:1-3). God tells him not to seek great things for himself at a time when God is uprooting what he built across the whole land (Jeremiah 45:4-5). Yet God promises Baruch that his own life will be preserved wherever he goes, even amid the surrounding disaster (Jeremiah 45:5).",
    46: "An oracle against Egypt opens with Pharaoh Necho's army routed at Carchemish, its confident advance turned into headlong flight (Jeremiah 46:1-12). Judgment is pronounced on Egypt's gods, its cities, and even Pharaoh himself, exposing the nation's vulnerability despite its ancient power (Jeremiah 46:13-26). The closing verses turn to comfort Israel directly, promising that though other nations are fully consumed, Israel will not be utterly destroyed (Jeremiah 46:27-28).",
    47: "A brief oracle announces devastation sweeping over the Philistines like rising floodwaters, naming the cities of Gaza and Ashkelon by name (Jeremiah 47:1-5). The destruction is pictured reaching even further, shaving every head bald in mourning and cutting off the Philistines' allies (Jeremiah 47:4-5). The LORD's sword is personified as unable to rest, since it has been given a specific charge to carry out (Jeremiah 47:6-7).",
    48: "A long oracle catalogs Moab's cities one by one, condemning the nation's pride, its confidence in the god Chemosh, and its complacent settledness, 'hath not been emptied from vessel to vessel' (Jeremiah 48:1-13). The devastation is pictured through shattered jars, public weeping, and ruined vineyards, as refugees scatter to find shelter (Jeremiah 48:28-46). Even so, the oracle closes with a promise to restore Moab's fortunes 'in the latter days,' keeping judgment from being the final word (Jeremiah 48:47).",
    49: "Short oracles address Ammon for occupying land that belonged to Israel, and Edom for trusting its famous wisdom and mountain strongholds, neither of which can shield it from judgment (Jeremiah 49:1-22). Damascus is told its courage will fail it, while the desert peoples of Kedar and Hazor are warned that even their distance and mobility cannot protect them (Jeremiah 49:23-33). Elam, far to the east, is promised both the scattering of its archers and, like several of the nations before it, an eventual restoration (Jeremiah 49:34-39).",
    50: "Jeremiah's long oracle declares that Babylon, the very empire God used to defeat Judah, will itself be overthrown by a nation from the north (Jeremiah 50:1-10). Israel and Judah are pictured as a scattered flock finally seeking their own pastures and their God again, while the exiles are urged to flee Babylon before it falls (Jeremiah 50:17-20). The oracle repeatedly exposes Babylon's cruelty toward the vulnerable, its empty idols, and its false sense of permanent security (Jeremiah 50:29-32).",
    51: "The oracle against Babylon continues with a destroyer summoned against its armies and its famous idols, Bel and Merodach, shown powerless to save it (Jeremiah 51:1-19). Babylon's own vindictive history against Zion is answered with the promise that Zion itself will be vindicated, and that the nations it once oppressed will one day go free (Jeremiah 51:24-36). Jeremiah instructs the royal official Seraiah to read this scroll aloud in Babylon, then tie a stone to it and sink it in the Euphrates, a sign that Babylon will sink in just the same way (Jeremiah 51:59-64).",
    52: "A historical appendix recounts Zedekiah's rebellion, Jerusalem's siege, and its capture, including the burning of the temple and the breaking down of the city's walls (Jeremiah 52:1-14). It records the carrying off of the temple's bronze furnishings and the exact numbers of those deported in three separate removals (Jeremiah 52:17-30). The book ends on a restrained note of hope, as Babylon's king Evil-merodach releases Jehoiachin from prison and gives him a permanent place at the royal table (Jeremiah 52:31-34).",
}

print(f"WWA entries: {len(WWA)}")
for n, text in WWA.items():
    if len(text) > 600:
        print(f"TOO LONG {n}: {len(text)}")

FIGURES = {
    1: [("Jeremiah", "A young priest's son from Anathoth, appointed a prophet to the nations before his birth despite protesting that he is too young to speak (1:4-7)."),
        ("the LORD", "Touches Jeremiah's mouth, puts his own words in the prophet's mouth, and shows him the almond branch and the tilted boiling pot that explain the coming judgment (1:9-14)."),
        ("the people and kings of Judah", "The addressees of the coming judgment, warned that they will fight against Jeremiah but will not prevail because God is with him (1:18-19).")],
    2: [("the LORD", "Recalls Israel's early devotion in the wilderness and accuses Judah of trading the fountain of living water for broken cisterns and foreign alliances (2:2-13)."),
        ("Jerusalem and Judah", "Accused of abandoning God for idols and for political dependence on Egypt and Assyria, yet denies any wrongdoing despite the evidence (2:23-35)."),
        ("Egypt and Assyria", "The foreign powers Judah courts for protection instead of trusting God, pictured as the waters of the Nile and the Euphrates (2:18, 2:36).")],
    3: [("the LORD", "Compares Judah and Israel's unfaithfulness to a wife worse than her divorced sister, yet still invites both to return and confess their guilt (3:1-14)."),
        ("faithless Israel", "The northern kingdom, already judged and exiled by Assyria, held up as a warning example for Judah (3:6-10)."),
        ("treacherous Judah", "Judah itself, shown to have ignored Israel's example and sinned even more openly through false repentance (3:10-11)."),
        ("Jerusalem", "Promised a future where it is called the LORD's throne and nations gather to it, if the invitation to return is accepted (3:17).")],
    4: [("the LORD", "Calls Israel and Judah to genuine repentance marked by justice and renewed hearts, then warns of an invading army from the north (4:1-6)."),
        ("Judah and Jerusalem", "The target of the coming invasion, urged to sound the alarm and gather into fortified cities before the destroyer arrives (4:5-8)."),
        ("the northern invader", "An unnamed army compared to a lion and an eagle, advancing on Jerusalem as the specific instrument of judgment (4:7, 4:13)."),
        ("Jeremiah", "Caught between delivering the warning and his own grief, crying out in anguish at the devastation he foresees (4:19-21).")],
    5: [("the LORD", "Sends Jeremiah through Jerusalem's streets to find even one person who practices justice, and finds none among rich or poor (5:1-5)."),
        ("Jerusalem's residents and leaders", "Accused of rejecting correction, growing fat and sleek through oppression, and defending the cause of the fatherless unjustly (5:26-28)."),
        ("foreign nation", "An unnamed but powerful people summoned from far away as the agent of coming judgment (5:15-17)."),
        ("prophets and priests", "Condemned for prophesying falsely and ruling by their own means while the people love having it so (5:30-31).")],
    6: [("the LORD", "Warns of an invading army from the north and calls the people to seek the ancient, good paths before it is too late (6:1, 6:16)."),
        ("people of Benjamin and Jerusalem", "Urged to flee and sound the alarm as the besieging army closes in on the city (6:1)."),
        ("prophets and priests", "Offer false reassurance, saying 'Peace, peace,' when there is no peace at all (6:13-14)."),
        ("invading army", "A besieging force pictured cutting down trees and building siege mounds against Jerusalem itself (6:4-6).")],
    7: [("Jeremiah", "Sent to stand at the temple gate and warn worshipers that the sanctuary cannot protect those who steal, murder, and serve idols (7:1-11)."),
        ("temple worshipers", "Trust the phrase 'The temple of the LORD' as a guarantee of safety regardless of how they live (7:4, 7:9-10)."),
        ("the LORD", "Recalls Shiloh's destruction as proof no sanctuary is exempt from judgment and forbids Jeremiah even to pray for this people (7:12-16)."),
        ("Judah's rulers and people", "Condemned for baking cakes to the 'queen of heaven' and sacrificing children at Topheth in the Valley of Hinnom (7:18, 7:31).")],
    8: [("the LORD", "Pictures coming judgment as the disgrace of disturbed graves and condemns leaders who treat the nation's wound lightly (8:1-2, 8:11)."),
        ("Judah's people", "Refuse to turn back even though the time for repentance has already passed like a finished harvest (8:4-7, 8:20)."),
        ("scribes and prophets", "Wrongly claim wisdom through 'the pen of the scribes' while offering false assurances of peace (8:8-11)."),
        ("Jeremiah", "Grieves for his people, asking why no healing has come though a balm is available in Gilead (8:18-22).")],
    9: [("Jeremiah", "Longs for tears enough to weep day and night over the slain of his people and their deceitful conduct (9:1-9)."),
        ("the LORD", "Announces judgment and instructs trained mourners to lament, then redirects true boasting toward knowing him rather than wisdom, strength, or wealth (9:17-24)."),
        ("people of Judah", "Accused of deceit so constant that neighbor cannot trust neighbor, and of being circumcised in body but not in heart (9:4-6, 9:25-26)."),
        ("women called to mourn", "Professional mourners summoned to teach their daughters a wailing lament for the coming disaster (9:17-20).")],
    10: [("the LORD", "Contrasted with lifeless idols as the living God who made the heavens and earth and controls the rain and the wind (10:10-13)."),
         ("Judah and Israel", "Warned of coming exile pictured as a tent suddenly struck, even as Jeremiah prays on their behalf for just correction (10:17-20, 10:24)."),
         ("idol makers", "Craftsmen whose handmade gods must be carried because they cannot walk, exposed as futile compared to the true God (10:3-5, 10:9)."),
         ("Jeremiah", "Confesses that the way of man is not in himself and prays for correction in just measure rather than full destruction (10:23-25).")],
    11: [("the LORD", "Proclaims the covenant's terms and its curses, and tells Jeremiah not to intercede because the people's idolatry has multiplied with their cities (11:1-8, 11:13-14)."),
         ("Jeremiah", "Proclaims the covenant obediently, then discovers a plot on his own life, comparing himself to an unsuspecting lamb led to slaughter (11:6, 11:19)."),
         ("men of Anathoth", "Jeremiah's own hometown neighbors, who plot to kill him so he will stop prophesying (11:19-21)."),
         ("Judah and Jerusalem", "The covenant community whose disobedience has brought the curses written in the law into present reality (11:9-10).")],
    12: [("Jeremiah", "Asks God why the wicked prosper and the land itself suffers for their wrongdoing (12:1-4)."),
         ("the LORD", "Answers with a demanding image of running against horses, warning that harder trials still lie ahead before compassion follows (12:5-6, 12:15)."),
         ("Judah's wicked", "Planted by God yet bearing no good fruit, their own betrayal reaching even into Jeremiah's family (12:2, 12:6)."),
         ("neighboring peoples", "Promised removal from the land for evil, but also a conditional future inclusion if they learn to swear by the LORD's name (12:14-16).")],
    13: [("Jeremiah", "Buries a linen girdle near the Euphrates and later finds it ruined, acting out Judah's pride spoiled by its own stubbornness (13:1-11)."),
         ("the LORD", "Explains the ruined girdle, warns through a wine-jar saying, and pictures Jerusalem's coming shame in deliberately disturbing terms (13:12-14, 13:22-27)."),
         ("Judah and Jerusalem", "Summoned to humility before their glory is darkened on the mountains, after stubbornly refusing correction (13:15-17)."),
         ("king and queen mother", "Told to take a lowly seat, since their glorious crowns are about to come down (13:18).")],
    14: [("the LORD", "Describes the drought ravaging Judah, then refuses the prophets of peace, declaring that sword, famine, and plague are his true sentence (14:1-6, 14:13-16)."),
         ("Jeremiah", "Laments the suffering of sword and famine and pleads with God on behalf of the very people under judgment (14:17-22)."),
         ("Judah's people", "Confess their wrongdoing and plead for mercy during the drought, invoking God's name even while continuing to sin (14:7-9, 14:20-21)."),
         ("false prophets", "Promise peace and prosperity without God's authorization, a claim God condemns outright (14:13-15).")],
    15: [("the LORD", "Declares that not even Moses or Samuel could now turn judgment away, naming Manasseh's past sins as a reason, before renewing Jeremiah's own commission (15:1-4, 15:19-21)."),
         ("Jeremiah", "Protests the weight of his calling as a man of strife to the whole earth, yet still delights in God's word as his heart's joy (15:10, 15:16)."),
         ("Moses and Samuel", "Israel's great past intercessors, invoked as a measure of how fixed this judgment now is (15:1)."),
         ("Judah", "Appointed to four kinds of destruction, sword, dogs, birds, and beasts, because of what happened in Manasseh's Jerusalem (15:2-4).")],
    16: [("Jeremiah", "Told not to marry, mourn, or feast, so that his own restricted household life becomes a visible sign of the coming catastrophe (16:1-9)."),
         ("the LORD", "Names persistent idolatry, generations deep, as the reason exile is coming, yet still promises an eventual regathering (16:10-15)."),
         ("Judah's families", "Warned that marriage, funerals, and feasts will cease in the land because of the coming judgment (16:1-9)."),
         ("the nations", "Promised that they will one day recognize the futility of the idols their ancestors inherited from their fathers (16:19-21).")],
    17: [("the LORD", "Pictures Judah's sin as engraved with an iron pen and contrasts trust in human strength with the lasting security of trusting him (17:1, 17:5-8)."),
         ("Jeremiah", "Describes the human heart as deceitful above all things and prays for his own healing from the LORD who searches it (17:9-10, 17:14)."),
         ("people and kings of Judah", "Addressed through Jeremiah's gate-sermon, with blessing or judgment set before them depending on whether they keep the sabbath (17:19-25)."),
         ("Jerusalem's gate users", "Ordinary traders and farmers warned to stop carrying loads and doing business on the sabbath (17:21-22).")],
    18: [("the LORD", "Shows Jeremiah a potter reworking flawed clay, a picture of his freedom to relent from judgment or withdraw blessing depending on a nation's response (18:1-10)."),
         ("Jeremiah", "Delivers this warning faithfully, then prays in anguish after opponents plot against him for it (18:11, 18:19-23)."),
         ("the potter", "Reshapes a marred vessel on the wheel into a new one, exactly as it seems good to him (18:3-4)."),
         ("Jeremiah's opponents", "Plan to attack Jeremiah 'with the tongue' rather than heed his warning, confident that priests and wise men will always be available (18:18).")],
    19: [("the LORD", "Sends Jeremiah to buy a potter's jar and break it before elders and priests as a sign that Jerusalem's coming destruction cannot be undone (19:1-11)."),
         ("Jeremiah", "Carries out the sign-act at the Valley of Hinnom and denounces the bloodshed and child sacrifice practiced there (19:1-6)."),
         ("elders and priests", "Summoned as official witnesses to watch Jeremiah break the jar and hear the judgment it represents (19:1-2, 19:10)."),
         ("Judah's people", "Condemned for filling Topheth with innocent blood and for worship that God says never entered his mind to command (19:4-5).")],
    20: [("Pashhur son of Immer", "The priest in charge of the temple who has Jeremiah beaten and locked in the stocks for his prophecy, and is renamed 'Magormissabib' in judgment (20:1-3)."),
         ("Jeremiah", "Released from the stocks, announces judgment on Pashhur by name, then pours out the book's rawest lament over his own suffering (20:3-6, 20:14-18)."),
         ("the LORD", "The source of the fire shut up in Jeremiah's bones that he cannot hold back no matter how much he is mocked (20:9, 20:11)."),
         ("Jeremiah's persecutors", "Those who watch for Jeremiah to stumble, hoping to take revenge on him for his warnings (20:10).")],
    21: [("Zedekiah", "Judah's last king, who sends envoys to Jeremiah hoping God will again drive back Babylon's army as in the past (21:1-2)."),
         ("Jeremiah", "Answers that God himself will fight against the city, and urges anyone who wants to live to surrender to the besiegers (21:3-10)."),
         ("Pashhur son of Malchiah", "One of the two royal envoys Zedekiah sends to ask Jeremiah to inquire of the LORD (21:1)."),
         ("Zephaniah the priest", "The second envoy sent with Pashhur to seek Jeremiah's word from the LORD (21:1)."),
         ("Nebuchadnezzar", "King of Babylon, whose besieging army Jeremiah says God himself is directing against Jerusalem (21:4-7).")],
    22: [("Jeremiah", "Confronts Judah's royal house at the king's house itself, demanding justice and mercy toward the vulnerable (22:1-5)."),
         ("the LORD", "Warns that the palace will become a ruin without justice, and pronounces the fates of three kings in turn (22:5-30)."),
         ("Shallum (Jehoahaz)", "Josiah's son, taken captive to Egypt and told he will never see his native land again (22:10-12)."),
         ("Jehoiakim", "Condemned for building a lavish palace with unpaid labor and promised a burial fit for a donkey, dragged out beyond the gates (22:13-19)."),
         ("Coniah (Jehoiachin)", "Told that though he were the signet ring on God's own hand, he would still be pulled off and sent into exile childless on the throne (22:24-30).")],
    23: [("the LORD", "Condemns the shepherds who scattered his flock and promises to gather the remnant himself under a righteous Branch from David (23:1-6)."),
         ("Israel's and Judah's shepherds", "The kings and leaders of both kingdoms, pictured as shepherds who destroyed and scattered rather than cared for God's flock (23:1-2)."),
         ("future Davidic ruler", "A righteous Branch who will reign wisely and bear the name 'THE LORD OUR RIGHTEOUSNESS' (23:5-6)."),
         ("false prophets", "Share invented dreams and borrowed words as if they were God's own, contrasted with his true word, like fire and a hammer breaking rock (23:16, 23:25-29).")],
    24: [("the LORD", "Shows Jeremiah two baskets of figs and overturns easy assumptions about who is truly blessed after Jehoiachin's deportation (24:1-10)."),
         ("Jeremiah", "Receives and explains the vision, naming the exiles already in Babylon as the ones with a future hope (24:3-7)."),
         ("Jehoiachin's exiles", "Compared to good figs, promised a new heart to know the LORD and an eventual return to the land (24:5-7)."),
         ("Zedekiah and Judah's remnant", "Compared instead to rotten figs, destined for further disaster whether they stay in Jerusalem or flee to Egypt (24:8-10).")],
    25: [("Jeremiah", "Reviews twenty-three years of warnings Judah has refused to hear, from Josiah's thirteenth year to Jehoiakim's fourth (25:1-7)."),
         ("the LORD", "Announces Babylonian conquest followed by seventy years of service, after which Babylon itself will be judged (25:8-14)."),
         ("Jehoiakim", "The king in whose fourth year this dated oracle is delivered, as Nebuchadnezzar's own reign begins (25:1, 25:3)."),
         ("Nebuchadnezzar", "Named 'my servant,' the instrument God will use to devastate Judah and the surrounding nations (25:9)."),
         ("many nations", "Made to drink the cup of God's wrath in turn, from Jerusalem outward to Egypt, Philistia, Edom, Moab, Ammon, and beyond (25:15-26).")],
    26: [("Jeremiah", "Preaches at the temple that it could become like ruined Shiloh, then defends his mission before officials demanding his death (26:1-15)."),
         ("Jehoiakim", "The king under whom this trial takes place, and who later kills the prophet Uriah for the same kind of message (26:1, 26:20-23)."),
         ("priests and prophets", "Seize Jeremiah after his sermon and insist to the officials that he deserves to die (26:7-11)."),
         ("elders and officials", "Side with Jeremiah, recalling that the earlier prophet Micah gave Hezekiah a similar warning without being executed (26:16-19)."),
         ("Uriah", "Another prophet who preached the same message, fled to Egypt, and was extradited and killed by Jehoiakim (26:20-23)."),
         ("Ahikam", "The son of Shaphan whose protection keeps Jeremiah from being handed over to the people to be put to death (26:24).")],
    27: [("Jeremiah", "Wears a wooden yoke and sends word to Judah and neighboring kings urging submission to Babylon rather than trust in quick freedom (27:1-11)."),
         ("Zedekiah", "Told directly that serving the king of Babylon, not resisting him, is the way to live (27:12-15)."),
         ("the LORD", "Claims to have given all these lands to Nebuchadnezzar and warns that the temple vessels will remain under Babylon's control (27:5-8, 27:16-22)."),
         ("envoys of neighboring kings", "Ambassadors from Edom, Moab, Ammon, Tyre, and Sidon who come to Jerusalem, apparently planning a joint revolt against Babylon (27:3)."),
         ("false prophets", "Promise the temple vessels will soon return, a claim Jeremiah flatly contradicts (27:16).")],
    28: [("Hananiah son of Azzur", "A prophet who publicly breaks Jeremiah's yoke and promises Babylon's rule will end within two years (28:1-4, 28:10-11)."),
         ("Jeremiah", "Answers that an iron yoke will replace the broken wooden one and predicts Hananiah's death within the year (28:12-16)."),
         ("the LORD", "Confirms Jeremiah's word by causing Hananiah to die two months later, exactly as announced (28:16-17)."),
         ("priests and people", "Gathered in the temple to witness the public contest between Jeremiah's and Hananiah's conflicting claims (28:1, 28:5).")],
    29: [("Jeremiah", "Writes to the exiles in Babylon, telling them to build houses, plant gardens, and seek their captors' peace while waiting for God's promised return (29:1-9)."),
         ("the exiles", "The first deportees in Babylon, told to settle in for the long term rather than expect an immediate rescue (29:4-7)."),
         ("the LORD", "Promises that after seventy years he will fulfill his good word toward the exiles, including 'thoughts of peace, and not of evil' (29:10-11)."),
         ("Nebuchadnezzar", "King of Babylon, who carried this first wave of exiles away and under whose rule they are told to seek their new city's peace (29:1-3, 29:7)."),
         ("Shemaiah", "An exile in Babylon who opposes Jeremiah's letter and is condemned for prophesying falsely in the LORD's name (29:24-32)."),
         ("Elnathan and Gemariah", "Royal officials who carry Jeremiah's letter to the exiles in Babylon (29:3).")],
    30: [("the LORD", "Directs Jeremiah to record promises of restoration and describes a terrifying 'time of Jacob's trouble' from which his people will still be saved (30:1-7)."),
         ("Jeremiah", "Receives and writes down these promises of healing and regathering for a future readership (30:2)."),
         ("Israel and Judah", "Promised relief from foreign oppression, healing from their wounds, and restoration to covenant belonging (30:3, 30:17, 30:22)."),
         ("Jacob", "Invoked as the nation's ancestral name in the promise that his tents will be restored and his dwelling places pitied (30:18).")],
    31: [("the LORD", "Promises Israel and Judah renewed joy and planting, answers Rachel's grief with hope, and announces a new covenant written on the heart (31:1-20, 31:31-34)."),
         ("Israel (Ephraim)", "Addressed as a dear son whom God still remembers with mercy despite its wandering (31:9, 31:20)."),
         ("Judah", "Promised its own homecoming alongside Israel's, pictured as virgins dancing again with instruments of joy (31:4, 31:23)."),
         ("Rachel", "Pictured weeping for her exiled children, a grief God answers with the promise that they will return (31:15-17)."),
         ("Jeremiah", "The prophetic voice through whom these restoration promises, including the new covenant, are delivered (31:1).")],
    32: [("Jeremiah", "Imprisoned during the siege, buys his cousin's field at Anathoth as a sign that property will be owned again in the land (32:1-15)."),
         ("Hanamel", "Jeremiah's cousin, whose offer to sell his field becomes the occasion for this sign of future hope (32:6-9)."),
         ("Baruch", "Receives the sealed and open copies of the deed to store in an earthen jar so they will last a long time (32:12-14)."),
         ("Zedekiah", "The king under whose siege of Jerusalem this purchase takes place, with Jeremiah confined in his court (32:1-5)."),
         ("the LORD", "Explains why Jerusalem must fall for its persistent wrongdoing, yet promises an everlasting covenant of restoration afterward (32:26-42)."),
         ("witnesses", "Those who sign the deed of purchase according to the law and custom of the land (32:10, 32:12).")],
    33: [("Jeremiah", "Still confined in the court of the prison, receives further promises of healing, forgiveness, and renewal for Jerusalem (33:1-9)."),
         ("the LORD", "Invites Jeremiah to call on him and promises the Davidic throne and Levitical priesthood will endure as surely as day and night (33:3, 33:19-22)."),
         ("Davidic rulers", "Promised an unbroken line to sit on David's throne despite the coming exile (33:17, 33:21)."),
         ("Levitical priests", "Promised their ministry before God will continue without end, paired with David's throne in this promise (33:18, 33:21)."),
         ("Judah and Israel", "Promised celebration, healing, and cleansing from the very sins that brought on their present judgment (33:7-9).")],
    34: [("Jeremiah", "Tells Zedekiah plainly that Jerusalem will fall and that he will be taken to Babylon, though he will die in peace (34:1-7)."),
         ("Zedekiah", "Warned of his personal fate as Babylon's army closes in on Jerusalem's last fortified cities (34:2-5)."),
         ("Judah's slaveowners", "Make and then break a covenant to free their Hebrew slaves, re-enslaving them once Babylon's siege briefly lifts (34:8-11)."),
         ("freed Hebrew slaves", "Released under covenant law, only to be forced back into service by their former owners (34:10-11)."),
         ("the LORD", "Condemns the broken covenant as a betrayal of both liberty and his own name, announcing a different 'liberty,' to sword, famine, and plague (34:15-17).")],
    35: [("Jeremiah", "Brings the Rechabite family into the temple and sets wine before them as a test of their loyalty to their ancestor's command (35:1-5)."),
         ("Rechabites", "Refuse the wine because their ancestor Jonadab commanded a life without wine or permanent houses, a command they have kept for generations (35:6-10)."),
         ("Jaazaniah", "The Rechabite leader who answers Jeremiah and explains the family's reason for refusing the wine (35:3, 35:6)."),
         ("Jonadab son of Rechab", "The ancestor whose command, given generations earlier, the Rechabites still keep without exception (35:6-10)."),
         ("the LORD", "Contrasts the Rechabites' lasting obedience with Judah's refusal to heed his own prophets, and promises Jonadab's line an enduring place before him (35:12-16, 35:18-19).")],
    36: [("Jeremiah", "Dictates all his messages since Josiah's day to Baruch, intending the scroll to be read publicly in hope the people will still turn back (36:1-7)."),
         ("Baruch", "Writes the scroll at Jeremiah's dictation and reads it aloud at the temple, then rewrites it after the king destroys the first copy (36:4, 36:32)."),
         ("Jehoiakim", "Cuts the scroll apart with a penknife and burns it in his winter house despite officials' pleas to stop (36:22-25)."),
         ("Gemariah and court officials", "Hear the scroll read, grow afraid, and try unsuccessfully to keep the king from burning it (36:11-12, 36:25)."),
         ("the LORD", "Hides Jeremiah and Baruch from arrest and commands the scroll to be rewritten with additional words of judgment against Jehoiakim (36:26-31).")],
    37: [("Zedekiah", "Seeks Jeremiah's prayer as Babylon's siege lifts temporarily before an advancing Egyptian army (37:1-3)."),
         ("Jeremiah", "Insists Babylon will return and destroy the city, and is arrested as a deserter when he tries to leave for his own territory (37:6-15)."),
         ("Irijah", "The guard who arrests Jeremiah at the gate, accusing him of deserting to the Babylonians (37:13-14)."),
         ("Judah's officials", "Beat Jeremiah and imprison him in a dungeon for many days over the desertion accusation (37:15-16)."),
         ("Egyptian and Babylonian armies", "Egypt's advance forces Babylon's temporary withdrawal from Jerusalem, the pause during which these events occur (37:5, 37:11).")],
    38: [("Jeremiah", "Continues urging surrender from prison, is lowered into a muddy cistern for it, and is rescued, still advising Zedekiah privately to surrender (38:1-23)."),
         ("Zedekiah", "Allows officials to imprison Jeremiah, then secretly seeks his counsel, but remains too afraid of his own people to act on it (38:5, 38:14-23)."),
         ("Ebed-melech", "A Cushite palace official who pleads with the king and organizes Jeremiah's rescue from the cistern with ropes and old rags (38:7-13)."),
         ("court officials", "Persuade Zedekiah that Jeremiah weakens the soldiers' resolve and should be put to death (38:4).")],
    39: [("Zedekiah", "Captured fleeing Jerusalem, forced to watch his sons killed, then blinded and taken to Babylon in chains (39:4-7)."),
         ("Nebuchadnezzar", "The Babylonian king who receives Zedekiah at Riblah and orders his sentence carried out (39:5-7)."),
         ("Nebuzaradan", "The captain of the guard who oversees the burning of Jerusalem and the deportation of its people (39:8-10)."),
         ("Jeremiah", "Protected under Nebuchadnezzar's own direct orders not to be harmed (39:11-14)."),
         ("Ebed-melech", "Promised deliverance from the city's fall because he put his trust in the LORD (39:15-18)."),
         ("Babylonian officers", "Carry out Nebuchadnezzar's instructions, taking Jeremiah from the court of the guard and placing him in Gedaliah's care (39:13-14).")],
    40: [("Jeremiah", "Released from among the captives by Nebuzaradan and chooses to stay in Judah with Gedaliah rather than go to Babylon (40:1-6)."),
         ("Nebuzaradan", "The Babylonian captain who frees Jeremiah and lets him choose where to live (40:1-5)."),
         ("Gedaliah", "Appointed governor by Babylon over the land's remaining population, encouraging the people to settle and serve Babylon in peace (40:5-10)."),
         ("Johanan", "A Judean military leader who warns Gedaliah of Ishmael's plot and offers to kill him first (40:13-15)."),
         ("Ishmael", "Of the royal family, secretly planning to assassinate Gedaliah, though the governor does not believe the warning (40:14-16)."),
         ("Judean remnant", "Scattered Judeans who return to the land and gather a great harvest once Gedaliah's governorship offers some stability (40:11-12).")],
    41: [("Ishmael son of Nethaniah", "Murders Gedaliah and others at Mizpah, then kills visiting pilgrims and takes the rest of the town captive (41:1-10)."),
         ("Gedaliah", "Killed at a meal with Ishmael despite having dismissed the earlier warning against him (41:1-3)."),
         ("Johanan", "Leads the pursuit that catches Ishmael and rescues the captives he was taking toward Ammon (41:11-16)."),
         ("pilgrims", "Travelers heading to the ruined temple, most of whom Ishmael kills and throws into a cistern (41:4-7)."),
         ("Judean survivors", "Afraid of Babylonian retaliation for Gedaliah's murder, they begin moving toward Egypt for safety (41:17-18).")],
    42: [("Jeremiah", "Agrees to seek God's guidance for the frightened remnant and, after ten days, tells them to stay in Judah rather than flee to Egypt (42:1-17)."),
         ("Johanan", "Leads the remnant in asking Jeremiah to pray for guidance, promising in advance to obey whatever answer comes (42:1-6)."),
         ("the remnant of Judah", "Promise obedience to God's answer but are accused by the chapter's end of having already decided to flee regardless (42:5-6, 42:20)."),
         ("the LORD", "Promises protection for those who stay in Judah and warns that the very dangers feared from Babylon will instead follow the people into Egypt (42:10-17).")],
    43: [("the leaders", "Reject Jeremiah's word, accuse Baruch of turning him against them, and force the remnant down into Egypt (43:1-7)."),
         ("Jeremiah", "Taken to Egypt against his own counsel, where he buries stones at Pharaoh's palace in Tahpanhes as a sign (43:6-10)."),
         ("Baruch", "Accused by the leaders of influencing Jeremiah against the people's wish to flee to Egypt (43:3)."),
         ("Johanan", "Among the leaders who lead the remnant into Egypt in defiance of Jeremiah's warning (43:2, 43:4-5)."),
         ("Azariah", "Named alongside Johanan among the proud leaders who refuse to obey the LORD's voice through Jeremiah (43:2, 43:4)."),
         ("Nebuchadnezzar", "Announced in advance as the king who will one day set his throne on the very stones Jeremiah buries at Tahpanhes (43:10).")],
    44: [("Jeremiah", "Confronts the Judean communities in Egypt for continuing to worship the 'queen of heaven' and announces further judgment (44:1-14, 44:24-30)."),
         ("Judeans in Egypt", "Settled at Migdol, Tahpanhes, Noph, and Pathros, they openly defend their continued idolatry to Jeremiah's face (44:1, 44:15-19)."),
         ("women offering incense", "Defend making cakes and drink offerings to the 'queen of heaven,' crediting her for the good times before Jerusalem fell (44:15-19)."),
         ("the LORD", "Traces Jerusalem's destruction directly to this same idolatry and promises only a small remnant of this community will ever return (44:2-6, 44:28)."),
         ("Pharaoh Hophra", "Egypt's king, announced as the sign that will prove Jeremiah's warning true when he is delivered into his enemies' hands (44:30).")],
    45: [("Jeremiah", "Delivers God's personal word to his discouraged scribe from the fourth year of Jehoiakim, when Baruch was writing the great scroll (45:1-2)."),
         ("Baruch", "Weary and grieving over the burden of writing Jeremiah's prophecies, told not to seek greatness for himself in such a time (45:3-5)."),
         ("the LORD", "Warns that he is uprooting what he built everywhere, yet promises Baruch that his own life will be spared wherever he goes (45:4-5).")],
    46: [("Jeremiah", "Delivers this first oracle against the nations, opening with Egypt's rout at Carchemish (46:1-2)."),
         ("the LORD", "Pronounces judgment on Egypt's gods, cities, and Pharaoh, yet promises Israel that it will not be utterly destroyed like the nations around it (46:25-28)."),
         ("Pharaoh Necho", "Egypt's king, whose confident army is routed by Nebuchadnezzar at Carchemish on the Euphrates (46:2)."),
         ("Egyptian army", "Marches out looking unstoppable, then flees in terror once the battle actually begins (46:3-6, 46:21)."),
         ("Nebuchadnezzar", "God's instrument in defeating Egypt's army at Carchemish in Jehoiakim's fourth year (46:2, 46:13)."),
         ("Israel", "Comforted directly even in the midst of this judgment on Egypt, promised rescue 'from afar' and a secure, quiet life again (46:27-28).")],
    47: [("Jeremiah", "Delivers this brief oracle against the Philistines before Pharaoh's attack on Gaza (47:1)."),
         ("the LORD", "Commissions the sword of judgment against the Philistines and declares it cannot rest until its work is finished (47:6-7)."),
         ("Philistine communities", "Gaza and Ashkelon, pictured overwhelmed by a flood of destruction sweeping up from the north (47:1-5)."),
         ("Egyptian pharaoh", "His attack on Gaza supplies the occasion the heading uses to date this oracle (47:1).")],
    48: [("Jeremiah", "Delivers this long oracle naming Moab's cities one by one in judgment (48:1-28)."),
         ("the LORD", "Condemns Moab's pride and trust in Chemosh, yet promises to restore Moab's fortunes 'in the latter days' (48:29-30, 48:47)."),
         ("Moabites", "Settled and complacent, 'hath settled on his lees,' about to be poured out and scattered as refugees (48:11-12, 48:18)."),
         ("Chemosh", "Moab's national god, carried into captivity along with the priests and leaders who trusted him (48:7, 48:13).")],
    49: [("the LORD", "Addresses Ammon, Edom, Damascus, Kedar and Hazor, and Elam in turn, showing that no nation's land, wisdom, or distance can shield it from judgment (49:1-39)."),
         ("Ammonites", "Judged for occupying territory that belonged to Israel's tribe of Gad (49:1-2)."),
         ("Edomites", "Judged despite trusting in Teman's famous wisdom and their own high mountain strongholds (49:7, 49:16)."),
         ("people of Damascus", "Told their courage will fail them as panic and fear take hold of the city (49:23-24)."),
         ("Kedar and Hazor", "Desert-dwelling peoples warned that even their tents, camels, and remote distance cannot protect them (49:28-29)."),
         ("Elamites", "Promised both the scattering of their famous archers and an eventual restoration of their fortunes (49:35-36, 49:39).")],
    50: [("Jeremiah", "Delivers this long oracle declaring that Babylon, the empire God used against Judah, will itself be overthrown (50:1-3)."),
         ("the LORD", "Summons a nation from the north against Babylon and invites Israel and Judah to seek him again as they flee it (50:3-5, 50:17-20)."),
         ("Babylon (the Chaldeans)", "Once God's instrument of judgment, now condemned for its own cruelty, idolatry, and false confidence (50:29-32, 50:38)."),
         ("Israel and Judah", "Pictured as a scattered flock finally coming home and seeking the LORD their God again with weeping (50:4-6, 50:17).")],
    51: [("Jeremiah", "Continues and closes the oracle against Babylon, then instructs Seraiah to sink it, scroll and all, in the Euphrates (51:59-64)."),
         ("the LORD", "Summons a destroyer against Babylon's armies and idols and promises to repay Babylon for all it did to Zion (51:1-19, 51:24)."),
         ("Seraiah son of Neriah", "A royal official entrusted with reading the scroll aloud in Babylon before sinking it in the Euphrates as a sign (51:59-64)."),
         ("Babylon", "Condemned as a golden cup that made the whole earth drunk, now suddenly fallen and destroyed (51:7-8)."),
         ("Zion and Israel", "Promised vindication for everything Babylon did to them, and release for the nations Babylon once oppressed (51:34-36).")],
    52: [("Zedekiah", "Rebels against Babylon, is captured fleeing Jerusalem, and is blinded and taken to Babylon after watching his sons killed (52:1-11)."),
         ("Nebuchadnezzar", "The Babylonian king whose army besieges and finally captures Jerusalem (52:4-7)."),
         ("Nebuzaradan", "Oversees the burning of the temple and palace, the breaking down of the walls, and the deportation of the people (52:12-15)."),
         ("Jehoiachin", "Deported king who, after thirty-seven years in a Babylonian prison, is released and given a permanent place at the royal table (52:31-34)."),
         ("Evil-merodach (Amel-Marduk)", "The new king of Babylon who shows Jehoiachin this unexpected kindness at the book's close (52:31-34)."),
         ("Judean captives", "Numbered precisely across three separate deportations, totaling 4,600 people carried away (52:28-30).")],
}

THEMES = {
    1: {"Prophetic calling": "God appoints Jeremiah a prophet before his birth and overrules his protest that he is too young, showing that the call rests on God's choice rather than the prophet's own readiness (1:4-8).",
        "Judgment approaching": "The boiling pot tilted from the north previews an invasion that will fall on Judah because of its own wrongdoing, not merely because a foreign army happens to attack (1:13-16).",
        "Courage in witness": "God promises to make Jeremiah as unbreakable as a fortified city and an iron pillar so that fierce opposition cannot silence his message (1:17-19)."},
    2: {"Abandoned devotion": "God remembers Israel's bridal devotion in the wilderness, making its present unfaithfulness feel like the loss of a real, personal relationship rather than a broken rule (2:2-3).",
        "False sources of security": "Trusting Egypt and Assyria is treated as the same basic failure as worshiping idols, since both put confidence in something other than God (2:18, 2:36-37).",
        "Denial of wrongdoing": "Judah insists it has not sinned even as God lists specific, visible evidence against it, showing how denial can coexist with obvious guilt (2:23, 2:35)."},
    3: {"Comparing two kingdoms": "Judah is measured against the northern kingdom's earlier fall, exposing it as worse because it saw Israel's judgment and sinned anyway (3:6-11).",
        "Repentance invited": "Despite the harsh comparison, God still calls Judah to simply acknowledge its guilt and return, keeping the door open even after everything said before (3:12-14).",
        "Restored worship": "The promise of future shepherds and a city without need for the ark pictures worship renewed from the heart rather than centered on an object (3:15-17)."},
    4: {"Return in sincerity": "God calls for circumcised hearts, not just outward ritual, insisting that real repentance has to reach beneath the surface (4:1-4).",
        "Alarm over invasion": "Trumpets, signal flags, and a lion from the thicket build a mounting sense of danger that Jerusalem cannot ignore or outrun (4:5-7).",
        "Grief at devastation": "Jeremiah's vision of the earth 'without form, and void' borrows creation's own language to show how total this coming devastation will feel (4:23)."},
    5: {"Justice and truth": "The search for even one honest person in Jerusalem turns a general accusation into a specific, almost forensic indictment of the whole city (5:1-5).",
        "Consequences of defiance": "Refusing correction and hardening their faces harder than rock is named as the direct cause of the disaster about to fall (5:3, 5:19).",
        "Exploiting the vulnerable": "Becoming fat and sleek through oppressing orphans and the poor shows that Judah's sin is social and economic, not only religious (5:27-28)."},
    6: {"Ignored warnings": "Being told to seek the good, old paths and refusing outright shows a people who reject guidance even when it is freely offered (6:16-17).",
        "False peace": "Saying 'Peace, peace' when there is no peace names a specific kind of leadership failure: comforting people instead of warning them honestly (6:14).",
        "Testing and rejection": "Jeremiah is cast as a tester of metal whose people turn out to be rejected silver, too corrupted for refining to purify (6:27-30)."},
    7: {"Temple is no talisman": "Repeating 'The temple of the LORD' three times exposes a superstition that treats God's house as a magic charm rather than a place that requires faithful living (7:4).",
        "Protect the vulnerable": "Justice for the stranger, orphan, and widow is named as a condition for staying in the land, not an optional extra to religious practice (7:5-7).",
        "Reject abusive worship": "Child sacrifice at Topheth is condemned as something God never commanded and never even imagined, ruling out any claim that it served him (7:31)."},
    8: {"Refusal to turn": "Even migrating birds know their appointed seasons, but Jeremiah says his people do not know the LORD's ordained time to repent (8:7).",
        "Misused wisdom": "Scribes who handle the law 'falsely' with their pens show that religious expertise can become a tool for deception rather than truth (8:8).",
        "Collective lament": "Jeremiah's grief over his people's wound, expressed as his own personal sorrow, shows that pronouncing judgment does not require losing compassion for those judged (8:21-22)."},
    9: {"Lament for wrongdoing": "Jeremiah wishes for a traveler's lodge in the wilderness so he could leave his own people, showing how deeply their sin wears him down (9:2).",
        "Boasting rightly": "Wisdom, might, and riches are each named and each rejected as a worthy basis for pride, leaving only knowing God as something worth boasting in (9:23-24).",
        "Outward marks versus conduct": "Being circumcised in body but not in heart argues that a religious mark without a changed life accomplishes nothing (9:25-26)."},
    10: {"God versus idols": "Idols that must be nailed down so they cannot topple over are set against the living God who made the earth and controls the weather (10:4-5, 10:12-13).",
         "Human limits": "Jeremiah's admission that 'the way of man is not in himself' concedes that people cannot even direct their own steps, let alone escape judgment on their own (10:23).",
         "Coming displacement": "The image of a tent suddenly taken down pictures exile as abrupt and disorienting rather than a slow, foreseeable decline (10:20)."},
    11: {"Covenant accountability": "Reciting the covenant's blessings and curses reminds Judah that the coming judgment was agreed to by their own ancestors, not imposed without warning (11:3-5).",
         "Empty religious appeals": "God refuses to listen when the people cry out in trouble, since they ran after other gods just as numerous as their own cities in the meantime (11:11-13).",
         "Opposition to the prophet": "A plot from Jeremiah's own hometown shows that rejection of God's word can come from the people closest to the messenger, not just distant enemies (11:19-21)."},
    12: {"Questioning injustice": "Jeremiah's blunt question about why the wicked prosper gives permission to voice real doubt about fairness rather than suppress it (12:1).",
         "Endurance under pressure": "Being asked how he will keep up with horses if he is already worn out by footmen warns that present difficulty is not yet the hardest test (12:5).",
         "Judgment with possibility of return": "Even the neighboring nations removed from their land are told they can be built up again if they learn to swear by the LORD's name (12:14-16)."},
    13: {"Ruined pride": "A linen girdle, once close to the body, ruined by being buried and forgotten, pictures how intimacy with God becomes worthless when neglected (13:9-11).",
         "Urgent humility": "Judah is told to give glory to God before darkness falls, since pride left unchecked will not get a second chance once judgment arrives (13:16).",
         "Exposure and exile": "Judah's habits are called as fixed as a leopard's spots, meaning change will have to come from outside since it clearly will not come from within (13:23)."},
    14: {"Ecological suffering": "Nursing deer abandoning their young and wild donkeys panting for water show that the drought's judgment touches even creatures that never sinned (14:5-6).",
         "Confession and judgment": "The people's honest confession of guilt is met not with automatic relief but with God's continued refusal to turn judgment aside (14:7, 14:10).",
         "False assurances": "Prophets promising 'ye shall not see the sword' are condemned for speaking a vision God never gave them (14:13-14)."},
    15: {"Judgment's seriousness": "Naming Moses and Samuel, Israel's greatest intercessors, as powerless to help now shows how far beyond ordinary pleading this judgment has gone (15:1).",
         "Prophetic isolation": "Jeremiah's complaint that he sits alone under God's hand pictures the real loneliness that can come with faithfully delivering an unwelcome message (15:17).",
         "Renewed vocation": "Being told to return to God rather than let God return to him puts the responsibility for restoration back on Jeremiah even in his distress (15:19)."},
    16: {"Prophetic sign through abstention": "Jeremiah's unmarried, childless, and solitary life becomes a living preview of a society where marriage, birth, and mourning are all about to stop (16:1-9).",
         "Accountability for idolatry": "Judah is said to have done worse than its fathers, each generation following its own stubborn heart instead of learning from the last (16:12).",
         "Hope beyond exile": "The promise that people will one day swear by the LORD who brought Israel 'from the land of the north' describes a second exodus even bigger than the first (16:14-15)."},
    17: {"Misplaced trust": "The man who trusts in man is compared to a shrub in the desert, while the one who trusts the LORD is like a tree planted by water, unaffected even by drought (17:5-8).",
         "Inner motives": "Calling the heart 'deceitful above all things' warns that people, including Jeremiah himself, cannot fully trust their own self-assessment (17:9-10).",
         "Sabbath and communal practice": "Keeping or breaking the sabbath is treated as a visible test of covenant loyalty with real consequences for Jerusalem's future (17:24-27)."},
    18: {"Potter and clay": "A flawed pot reworked into a new one in the potter's own hands pictures God's freedom to reshape his plans for a nation rather than being bound to one fixed outcome (18:3-6).",
         "Conditional warning": "Both warnings of judgment and promises of blessing are described as changeable, depending on whether a nation turns from evil or from good (18:7-10).",
         "Conflict and lament": "Opponents who plot against Jeremiah still expect priests, the wise, and prophets to keep functioning as usual, showing how unwilling they are to imagine life without those institutions (18:18)."},
    19: {"Judgment enacted": "Breaking a finished, fired jar rather than reshaping wet clay marks the difference between a warning that can still be averted and one that cannot (19:10-11).",
         "Condemning violence": "Topheth is renamed 'the valley of slaughter' because the bloodshed committed there will be answered with bloodshed in return (19:6).",
         "Public witness": "Delivering this sign in front of elders and priests ensures the judgment is witnessed officially, not just spoken in private (19:1-2)."},
    20: {"Cost of truthful speech": "Jeremiah's beating and night in the stocks show that faithful prophecy can carry a direct physical price, not just social disapproval (20:1-2).",
         "Compulsion to speak": "Describing God's word as 'a burning fire shut up in my bones' pictures a calling too strong to suppress even when Jeremiah wants to quit (20:9).",
         "Extreme lament": "Cursing the day of his own birth shows the full weight of Jeremiah's suffering without softening or hiding it from the reader (20:14-18)."},
    21: {"Unwelcome counsel": "Jeremiah refuses to give Zedekiah the encouraging answer he hopes for, showing that true prophecy does not bend to what a leader wants to hear (21:2-7).",
         "Life amid judgment": "The choice set before the people, death in the city or life by surrender, insists that survival is still possible even within a judgment already decided (21:8-9).",
         "Royal justice": "The royal house is commanded to 'execute judgment in the morning,' linking the king's daily administration of justice directly to the city's fate (21:12)."},
    22: {"Judgment on kings": "Three kings in a row are named and judged individually, showing that royal office does not exempt a ruler from personal accountability (22:11-12, 22:18-19, 22:24-27).",
         "Justice over luxury": "Jehoiakim's cedar-paneled palace built with unpaid labor is condemned precisely because comfort was bought at someone else's unjust expense (22:13-14).",
         "Kingship and accountability": "Josiah's example of judging 'the cause of the poor and needy' is called the true meaning of knowing God, redefining kingship around justice rather than splendor (22:15-16)."},
    23: {"Failed shepherds": "Kings who were meant to care for God's flock are condemned instead for destroying and scattering it, inverting their own job description (23:1-2).",
         "Hope for righteous rule": "The righteous Branch's name, 'THE LORD OUR RIGHTEOUSNESS,' answers the failed kings of chapter 22 with the promise of a ruler who embodies the justice they lacked (23:5-6).",
         "Discern false prophecy": "God's word is compared to fire and a hammer breaking rock, a built-in test for telling real prophecy apart from borrowed dreams and invented messages (23:28-29)."},
    24: {"Vision as moral interpretation": "The same event, deportation to Babylon, is read as either disaster or hidden blessing depending on which basket of figs a person's situation resembles (24:1-10).",
         "Unexpected hope in exile": "Being carried off to Babylon is reinterpreted as the path to a new heart to know the LORD, reversing the assumption that exile is simply loss (24:5-7).",
         "False security at home": "Staying in Jerusalem, which looks like the safer choice, turns out to be the one that leads to further disaster (24:8-10)."},
    25: {"Warnings repeatedly ignored": "Twenty-three years of 'rising early and speaking' without being heard shows how long patience can be extended before judgment finally arrives (25:3-4).",
         "Limited duration of empire": "Fixing Babylon's rule at seventy years builds an expiration date into Judah's punishment from the very start of the sentence (25:11-12).",
         "International accountability": "The cup of wrath passed from nation to nation shows that God's justice is not limited to Judah but reaches every people in turn (25:17-26)."},
    26: {"Freedom to warn": "Jeremiah is specifically told to speak 'all the words' without diminishing anything, even knowing how dangerous the full message will be (26:2).",
         "Public testing of prophecy": "A formal trial over Jeremiah's words puts prophecy itself on public trial, deciding through due process whether his claim to speak for God is genuine (26:10-16).",
         "Danger of repression": "Uriah's extradition and execution for a nearly identical message shows concretely what could have happened to Jeremiah without Ahikam's protection (26:20-24)."},
    27: {"Yoke as political sign": "Wearing an actual wooden yoke turns Jeremiah's message into something onlookers can see as well as hear, reinforcing submission to Babylon as the unavoidable near-term reality (27:2-3).",
         "Resist comforting falsehood": "Zedekiah is warned specifically not to listen to prophets promising he will not serve Babylon, since that comfort is false (27:14-15).",
         "Humility under empire": "Submitting to Babylon's yoke, rather than resisting it, is presented as the path that actually preserves the nation rather than destroying it (27:11-12)."},
    28: {"Competing prophetic claims": "Hananiah and Jeremiah deliver opposite messages in the same temple courtyard, forcing onlookers to decide which prophet actually speaks for God (28:1-11).",
         "Dramatic symbolism": "Breaking Jeremiah's wooden yoke is answered with the announcement of an iron one, showing that a dramatic gesture does not by itself make a prophecy true (28:10-14).",
         "Accountability in speech": "Hananiah's death within the year he predicted shows that claiming to speak for God carries real consequences when the claim turns out false (28:16-17)."},
    29: {"Faithful life in exile": "Telling the exiles to build houses and plant gardens rather than wait anxiously calls them to live fully even in an unwanted, temporary-feeling situation (29:5-7).",
         "Long-term hope": "The promise of 'an expected end' after seventy years gives the exiles a horizon to hope toward without pretending the wait will be short (29:10-11).",
         "Discern conflicting voices": "Shemaiah's opposition from within Babylon shows that even exiled communities still had to sort true guidance from false (29:24-32)."},
    30: {"Hope after distress": "Naming the coming anguish 'the time of Jacob's trouble' does not minimize how bad it will be, even while promising rescue out of it (30:7).",
         "Healing of wounds": "God promises to heal wounds that others call incurable, directly answering the despair of a nation that assumes its situation cannot improve (30:12-13, 30:17).",
         "Renewed community": "Restored leadership 'from the midst of them' pictures a community governed again by its own people rather than foreign rule (30:20-21)."},
    31: {"Return and comfort": "Promising dancing, planting, and a homecoming so complete it answers Rachel's grief turns abstract hope into vivid, everyday pictures of restored life (31:4-5, 31:15-17).",
         "New covenant": "Writing God's law on hearts instead of tablets addresses the Law's own weakness, a covenant people kept breaking from the outside in (31:31-33).",
         "Renewed public life": "Measuring out the rebuilt city's boundaries turns restoration from a vague promise into a concrete, surveyed reality (31:38-40)."},
    32: {"Hope enacted by purchase": "Buying a field about to fall to Babylon only makes sense as an act of faith that the land will belong to God's people again (32:7-9, 32:15).",
         "Judgment for persistent wrongdoing": "God recounts how Israel and Judah 'have only done evil before me from their youth' since he brought them out of Egypt, explaining why judgment, not just bad luck, has arrived (32:20-21, 32:30).",
         "Restoration and covenant": "The same chapter that explains Jerusalem's fall also promises an everlasting covenant afterward, holding judgment and hope together rather than choosing one (32:36-41)."},
    33: {"Restoration after ruin": "God promises to heal and reveal 'great and mighty things' to a city already marked for destruction, refusing to let its coming ruin be the final word (33:3, 33:6-9).",
         "Renewed joy and worship": "The sounds of joy, gladness, and thanksgiving returning to ruined streets reverses the images of silence and desolation used earlier in the book (33:10-11).",
         "Steadfast promise": "Comparing God's covenant with David to the fixed cycle of day and night makes the promise's reliability as certain as the most basic fact of nature (33:20-21)."},
    34: {"Truth about defeat": "Jeremiah tells Zedekiah his exact fate in advance, refusing to soften the news even though it is addressed directly to the king himself (34:2-5).",
         "Liberation and broken promises": "Freeing slaves and then forcing them back profanes God's name specifically because it treats a covenant made in his name as disposable (34:15-16).",
         "Covenant accountability": "The announced 'liberty' of sword, famine, and plague mirrors the liberty the people refused to give, making the punishment match the crime (34:17)."},
    35: {"Faithfulness to a commitment": "The Rechabites' generations-long obedience to a human ancestor's command, with no exceptions even under pressure, sets an unusually high bar for consistency (35:8-10).",
         "Heeding instruction": "God contrasts how readily the Rechabites obeyed Jonadab with how little Judah has obeyed him, 'rising early and speaking' through prophet after prophet (35:14-15).",
         "Recognition of integrity": "Promising Jonadab's descendants an enduring place before God rewards faithfulness that had nothing to do with Israel's covenant in the first place (35:18-19)."},
    36: {"Written witness": "Recording the prophecies on a scroll preserves Jeremiah's entire ministry in one place, so that even officials who missed the original messages can still hear them (36:2-4).",
         "Royal rejection": "Jehoiakim's calm destruction of the scroll, cutting and burning it piece by piece without fear, shows contempt that goes beyond simple disagreement (36:23-24).",
         "Renewed proclamation": "Dictating the scroll again so that 'there were added besides unto them many like words' shows that destroying a physical copy cannot actually undo a message once it has been spoken (36:28, 36:32)."},
    37: {"Temporary relief is not deliverance": "Babylon's brief withdrawal before Egypt's army tempts Jerusalem to think the danger has passed, but Jeremiah insists the siege will resume (37:5-10).",
         "Injustice against a messenger": "Jeremiah is punished as a deserter for trying to attend to personal land business, showing how an honest action can be twisted into treason under suspicion (37:12-15).",
         "Endurance under confinement": "Receiving daily bread 'until all the bread in the city were spent' marks Jeremiah's imprisonment as lasting exactly as long as the siege itself (37:21)."},
    38: {"Moral courage": "Ebed-melech risks confronting the king directly on Jeremiah's behalf, when officials far more powerful than he is have already condemned the prophet to die (38:7-10).",
         "Costly truth": "Jeremiah keeps advising surrender even after nearly dying in the cistern for saying so, showing that the earlier punishment did not change his message (38:17-20).",
         "Fearful leadership": "Zedekiah's private admission that he fears what his own people might do reveals a king controlled by his officials rather than ruling them (38:19, 38:24-25)."},
    39: {"Fall of Jerusalem": "The breach of the wall, after a year and a half of siege, finally brings about exactly what Jeremiah had warned for decades (39:2-3).",
         "Different fates in defeat": "Zedekiah's capture and blinding, Jeremiah's protection, and Ebed-melech's promised safety show that the same citywide disaster did not fall on everyone the same way (39:4-7, 39:11-18).",
         "Protection of a rescuer": "Ebed-melech's deliverance is tied explicitly to his trust in God, rewarding the one official who acted to save Jeremiah's life (39:17-18)."},
    40: {"Life after conquest": "Nebuzaradan's choice to release Jeremiah rather than deport him shows that even an occupying army could recognize and respect his role (40:4-5).",
         "Fragile reconstruction": "Gedaliah's modest governorship, encouraging people to farm and gather harvest, represents a tentative return to ordinary life after total defeat (40:9-10, 40:12).",
         "Warnings amid instability": "Gedaliah's refusal to believe Johanan's warning shows how fragile this new peace really is, resting on one leader's possibly misplaced trust (40:13-16)."},
    41: {"Betrayal and violence": "Ishmael murders the very governor he was eating a meal with, a betrayal made sharper by the ordinary hospitality it violates (41:1-3).",
         "Harm to vulnerable people": "Killing pilgrims who came only to mourn at the ruined temple shows violence reaching people with no part in the political conflict at all (41:4-7).",
         "Fearful displacement": "The survivors' fear of Babylonian retaliation, not a direct accusation, is what actually sets them moving toward Egypt (41:17-18)."},
    42: {"Seeking guidance sincerely": "Asking Jeremiah to pray and promising obedience 'whether it be good, or whether it be evil' sounds like sincere submission to whatever God says (42:5-6).",
         "Trust amid vulnerability": "Being told 'be not afraid of the king of Babylon' addresses the remnant's deepest fear directly rather than dismissing it (42:11).",
         "Egypt as false refuge": "The sword and famine the remnant fears in Judah are promised to follow them to Egypt instead, undercutting the whole logic of fleeing there (42:16)."},
    43: {"Rejected counsel": "The leaders' claim that Jeremiah's word is false, spoken right after promising to obey it, exposes how quickly their earlier sincerity collapses (43:2-3).",
         "Exile within exile": "Being forced to Egypt by their own leaders, against the counsel of their own prophet, makes this departure feel like a second, self-inflicted displacement (43:5-7).",
         "Symbolic warning in Egypt": "Burying stones at Pharaoh's own palace announces that Babylon's reach will extend precisely to the place the remnant thought was safe (43:9-10)."},
    44: {"Conflict over worship": "The people defend burning incense to the 'queen of heaven' to Jeremiah's face, turning this into a direct, open confrontation rather than quiet disobedience (44:16-19).",
         "Misreading prosperity": "Crediting the goddess for 'plenty of victuals' reverses the actual history, blaming disaster on stopping idolatry rather than on the idolatry itself (44:17-18).",
         "Warnings in diaspora": "Jerusalem's destruction is cited as living proof of where this exact behavior leads, since the audience in Egypt witnessed it themselves (44:2-6)."},
    45: {"Weariness in service": "Baruch's complaint that he has found no rest gives voice to the exhaustion of faithfully serving a message no one wants to hear (45:3).",
         "Limits of ambition": "Being asked 'seekest thou great things for thyself? seek them not' redirects Baruch's expectations away from personal success and toward simple survival (45:5).",
         "Preservation of life": "Promising Baruch's life 'for a prey in all places' turns mere survival itself into a genuine gift worth receiving amid surrounding disaster (45:5)."},
    46: {"Limits of imperial power": "Egypt's army, compared to the rising Nile, is still routed and put to flight, showing that even a flood-like advance can be turned back (46:7-8, 46:21).",
         "Judgment beyond Judah": "Devoting an entire oracle to Egypt shows that God's standard of justice is not reserved for his own covenant people alone (46:13-24).",
         "Hope for Israel": "Comforting Israel in the very oracle that judges Egypt shows these two messages, judgment on the nations and hope for God's people, belong together rather than in separate books (46:27-28)."},
    47: {"Threat to coastal cities": "Naming Gaza and Ashkelon specifically turns a general warning into judgment against particular, recognizable places (47:1, 47:5).",
         "Grief and mourning": "Shaving the head bald in the standard gesture of mourning shows how total this disaster will be, with no distinction left to preserve (47:5).",
         "Sword as poetic image": "The sword's own question, 'how long will it be ere thou be quiet,' makes the weapon itself feel driven by a purpose it cannot abandon until finished (47:6-7)."},
    48: {"Pride challenged": "Moab's repeated, explicit pride is named as the reason behind its downfall, more than any single military failure (48:29).",
         "Loss and grief": "Jeremiah's own grief over Moab, 'mine heart shall sound for Moab like pipes,' shows judgment on a hostile neighbor still costing the prophet something personally (48:36).",
         "Judgment not final": "The closing promise to restore Moab's captivity 'in the latter days' means even this long oracle of destruction does not end in total erasure (48:47)."},
    49: {"No nation beyond scrutiny": "Five separate peoples, Ammon, Edom, Damascus, Kedar and Hazor, and Elam, each receive the same kind of individual judgment, ruling out any claim of exemption by distance or obscurity (49:1-39).",
         "False confidence": "Edom's high rocky strongholds and Ammon's trust in its own treasures are each named and then dismissed as insufficient protection (49:4, 49:16).",
         "Wide reach of judgment": "Reaching all the way to Elam, far beyond Mesopotamia, shows this judgment extending to the edges of the known world (49:34-38)."},
    50: {"Empire held accountable": "Babylon, the very empire God used to punish Judah, is still held fully responsible for its own cruelty rather than excused for having served God's purpose (50:14-15, 50:29).",
         "Return and covenant seeking": "Israel and Judah 'going and weeping' together as they seek the LORD pictures a reunited, repentant people rather than two separate nations (50:4-5).",
         "Judgment for oppression": "Babylon's specific crime of showing its captives 'no mercy' names cruelty toward the vulnerable as its own distinct offense, not just rebellion against God in general (50:17-18)."},
    51: {"Judgment on Babylon": "A destroyer summoned 'from the north' answers Babylon with the exact kind of judgment it once brought on others, including Judah (51:1, 51:11).",
         "Vengeance and vindication": "Zion is promised that 'the LORD hath brought forth our righteousness,' framing Babylon's fall as justice owed to Zion rather than random misfortune (51:10, 51:24).",
         "Scroll as sign-act": "Sinking the scroll in the Euphrates gives Babylon's distant fall a physical, enacted sign rather than leaving the prophecy as words alone (51:63-64)."},
    52: {"Consequences of siege": "The famine growing so severe that 'there was no bread for the people' shows the siege's cost in plain, human terms rather than only military ones (52:6).",
         "Loss of sanctuary and institutions": "Listing the temple's bronze pillars, the Sea, and its priestly leadership by name turns the temple's destruction into a specific, inventoried loss (52:17-24).",
         "A restrained note of hope": "Jehoiachin's release and honored place at the king's table close the book without erasing everything that came before, since he still lives out his days as a captive in a foreign land (52:31-34)."},
}

print(f"FIGURES chapters: {len(FIGURES)}")
for n, figs in FIGURES.items():
    if len(figs) > 6:
        print(f"TOO MANY {n}: {len(figs)}")
    for name, role in figs:
        if "/" in name:
            print(f"SLASH {n}: {name}")

print(f"THEMES chapters: {len(THEMES)}")
for n in range(1, 53):
    if n not in THEMES:
        print(f"MISSING THEMES {n}")
    if n not in FIGURES:
        print(f"MISSING FIGURES {n}")
    if n not in SUMMARY:
        print(f"MISSING SUMMARY {n}")
    if n not in WWA:
        print(f"MISSING WWA {n}")


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "24_jeremiah.json"
    data = load(path)
    for n in range(1, 53):
        key = f"Jeremiah {n}"
        entry = data[key]
        entry["summary"] = SUMMARY[n]
        entry["whereWeAre"] = WWA[n]
        entry["keyFigures"] = [{"name": name, "role": role} for name, role in FIGURES[n]]
        theme_map = THEMES[n]
        seen = set()
        for theme in entry["keyThemes"]:
            name = theme["theme"]
            if name not in theme_map:
                raise SystemExit(f"Jeremiah {n}: no explanation drafted for theme {name!r}")
            theme["explanation"] = theme_map[name]
            seen.add(name)
        missing = set(theme_map) - seen
        if missing:
            raise SystemExit(f"Jeremiah {n}: drafted themes not in source: {missing}")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


AUDIENCE_1_26 = {
    1: "Judah's first hearers would have recognized Jeremiah as unusually young for a prophetic call and would have heard the almond-branch wordplay immediately, since shaqed (almond) and shoqed (watching) sound alike only in Hebrew, not in translation.",
    3: "Hearers who remembered the northern kingdom's fall would have felt the force of being compared unfavorably to a nation they considered already judged and gone.",
    10: "Readers fluent in both Hebrew and Aramaic would have noticed the single Aramaic verse standing out from its surroundings, a line apparently meant to be repeated even to Aramaic-speaking foreigners as a rebuke of their own gods.",
    11: "Hearers from Jeremiah's own priestly circles would have felt the shock of the Anathoth plot especially sharply, since it meant rejection from the prophet's own professional and family community, not just from strangers.",
    12: "Readers who already knew the Jordan's thick riverside jungle as home to lions would have understood God's question as a warning that present hardship was mild compared to what still lay ahead.",
    17: "Later generations, especially after the exile, would have read this sermon as explaining in advance why the sabbath became such a defining mark of Jewish identity and obedience.",
    19: "Those who witnessed the broken jar would have understood immediately, from everyday experience, that fired pottery could never be put back together, making the sign impossible to misread as reversible.",
    20: "Hearers of Jeremiah's lament afterward would have recognized a prophet willing to voice despair openly rather than present a polished, triumphant front after suffering for his message.",
    21: "Zedekiah's envoys, and anyone who heard of their mission afterward, would have expected Jeremiah to repeat past deliverances like Hezekiah's, making his refusal to promise one all the more unwelcome.",
    22: "Judeans who had watched these kings reign in quick succession would have heard their own recent political history summarized and judged within a single chapter.",
    23: "Later readers facing their own disappointing leaders would have carried this chapter's hope for a righteous Branch forward as a standing promise rather than a prediction tied to one generation.",
    24: "Exiles who assumed deportation was pure disaster, and those left behind who assumed they were the fortunate ones, would both have had their expectations reversed by this vision.",
    25: "Daniel's generation, reading this prophecy decades later in exile, would have used its seventy-year figure to calculate how much longer their own captivity had left (Daniel 9:2).",
}

AUDIENCE_27_52 = {
    27: "The visiting envoys, expecting to coordinate a joint rebellion, would have been startled to hear a Judean prophet publicly urge submission to Babylon instead.",
    28: "Onlookers in the temple that day would have had to decide, in real time and with no way yet to know who was right, which of the two competing prophets actually spoke for God.",
    29: "Exiles who expected prophetic comfort to mean an imminent rescue would instead have heard instructions to settle in for a generation, a reframing of hope around patience rather than speed.",
    40: "Judeans scattered in neighboring lands who heard that a stable Babylonian-appointed governor now ruled the remnant would have recognized their cue to come home and resume ordinary farming life.",
    41: "Later generations marked this murder with their own fast in the seventh month, treating it as a loss significant enough to mourn annually alongside the temple's destruction (Zechariah 7:5).",
    42: "The ten-day wait itself would have tested the remnant's claimed sincerity, since genuine seekers of guidance had to keep their promise to obey even after the answer took longer than expected.",
    43: "Judeans who had just promised to obey whatever Jeremiah said would have heard their own broken promise narrated back to them within the same breath as their flight to Egypt.",
    44: "Jewish communities later established in places like Elephantine in southern Egypt would have inherited the same tension this chapter describes, between old household devotions and the LORD's exclusive claim.",
    45: "Readers who had just read the scroll's dramatic public rejection in chapter 36 would have understood exactly what toll that work had already taken on Baruch personally.",
    47: "Hearers aware of Philistia's long history as Israel's rival would have heard this judgment as closing out an old regional conflict rather than announcing an unfamiliar enemy.",
    48: "Listeners who recognized each named town from trade routes or old border disputes with Moab would have felt the specificity of this judgment far more than a generic warning could convey.",
    49: "Judean hearers with any of these peoples as neighbors, trading partners, or old enemies would have recognized each one by reputation before Jeremiah even finished naming its particular judgment.",
    51: "Seraiah himself, physically carrying the scroll into the very city it condemned, would have felt the risk of the assignment far more immediately than any later reader of the written account.",
}

QUOTE_FIXES_27_52 = [
    ("such as ‘the town of Judah’ (Al-Yahudu), farming and doing business.",
     "such as a settlement named ‘the town of Judah’ (Al-Yahudu), farming and doing business."),
    ("A clay seal impression reading ‘Gemaryahu son of Shaphan’ was found in the City of David.",
     "A clay seal impression named ‘Gemaryahu son of Shaphan’ was found in the City of David."),
    ("Seal impressions naming ‘Jehucal son of Shelemiah’ and ‘Gedaliah son of Pashur’ have been found in Jerusalem.",
     "A seal impression named ‘Jehucal son of Shelemiah’ and another named ‘Gedaliah son of Pashur’ have been found in Jerusalem."),
    ("A seal reading ‘belonging to Gedaliah who is over the house’ was found at Lachish.",
     "A seal named ‘belonging to Gedaliah who is over the house’ was found at Lachish."),
    ("A clay seal impression reading ‘Berekyahu son of Neriyahu the scribe’ has been published, though its origin is debated.",
     "A clay seal impression named ‘Berekyahu son of Neriyahu the scribe’ has been published, though scholars dispute whether it is authentic."),
    ("Babylonian ration tablets list oil for ‘Yaukin, king of the land of Yahud.’",
     "Babylonian ration tablets list oil for a prisoner named ‘Yaukin, king of the land of Yahud.’"),
]

HIST_MOMENT_QUOTE_FIX = (
    "Babylonian ration tablets list rations for ‘Yaukin, king of Judah.’",
    "Babylonian ration tablets list rations for a captive named ‘Yaukin, king of Judah.’",
)


def apply_chapter_context():
    path1 = ROOT / "chapter_context" / "25_jeremiah_1-26.json"
    data1 = load(path1)
    for n, text in AUDIENCE_1_26.items():
        data1[f"Jeremiah {n}"]["audience"] = text
    save(path1, data1)
    print(f"Updated {path1.relative_to(ROOT)}")

    path2 = ROOT / "chapter_context" / "26_jeremiah_27-52_lamentations.json"
    data2 = load(path2)
    for n, text in AUDIENCE_27_52.items():
        data2[f"Jeremiah {n}"]["audience"] = text
    raw2 = json.dumps(data2, ensure_ascii=False, indent=2) + "\n"
    for old, new in QUOTE_FIXES_27_52:
        if old not in raw2:
            if new in raw2:
                continue
            raise SystemExit(f"quote fix not found in file 26: {old!r}")
        raw2 = raw2.replace(old, new)
    path2.write_text(raw2, encoding="utf-8")
    print(f"Updated {path2.relative_to(ROOT)}")


def apply_historical_moments():
    path = ROOT / "historical_moments" / "11_jeremiah_lamentations.json"
    raw = path.read_text(encoding="utf-8")
    old, new = HIST_MOMENT_QUOTE_FIX
    if old not in raw:
        if new in raw:
            print("historical_moments quote fix already applied")
            return
        raise SystemExit(f"quote fix not found in historical_moments: {old!r}")
    raw = raw.replace(old, new)
    path.write_text(raw, encoding="utf-8")
    print(f"Updated {path.relative_to(ROOT)}")


STORY_PRONOUN_FIXES = [
    ("God places His words in the prophet's mouth",
     "God places his words in the prophet's mouth"),
    ("meaning He is watching over His word",
     "meaning he is watching over his word"),
    ("abandoning the living water of His covenant for useless idols",
     "abandoning the living water of his covenant for useless idols"),
    ("God remembers the early days of His relationship with Israel",
     "God remembers the early days of his relationship with Israel"),
    ("for I am married unto you.” He promises, “I will give you pastors",
     "for I am married unto you.” he promises, “I will give you pastors"),
    ("where the tabernacle once stood, which He destroyed. He tells Jeremiah not even to pray",
     "where the tabernacle once stood, which he destroyed. he tells Jeremiah not even to pray"),
    ("the covenant He made with Israel when He brought them out of Egypt",
     "the covenant he made with Israel when he brought them out of Egypt"),
    ("after punishing His people and the nations around them, He will have compassion",
     "after punishing his people and the nations around them, he will have compassion"),
    ("though God promises to sustain His rejected prophet.",
     "though God promises to sustain his rejected prophet."),
    ("Judah was meant to cling to Him like a belt",
     "Judah was meant to cling to him like a belt"),
    ("if Jeremiah stays faithful, He will make him like a bronze wall",
     "if Jeremiah stays faithful, he will make him like a bronze wall"),
    ("God contrasts confidence in human strength with trust in Him, exposes",
     "God contrasts confidence in human strength with trust in him, exposes"),
    ("The sin of Judah is written with a pen of iron, and with the point of a diamond.” Then He contrasts two kinds of people.",
     "The sin of Judah is written with a pen of iron, and with the point of a diamond.” Then he contrasts two kinds of people."),
    ("At the potter's house, God shows His authority to reshape nations",
     "At the potter's house, God shows his authority to reshape nations"),
    ("If a nation turns from evil, God will change His plans to bring disaster. But if it does evil, He will change His plans to bless it.",
     "If a nation turns from evil, God will change his plans to bring disaster. But if it does evil, he will change his plans to bless it."),
    ("Jeremiah's answer is hard. God Himself will fight against the city.",
     "Jeremiah's answer is hard. God himself will fight against the city."),
    ("God says that is what it truly means to know Him.",
     "God says that is what it truly means to know him."),
    ("pasture!” But He promises a new king:",
     "pasture!” but he promises a new king:"),
    ("God also condemns the false prophets who claim to speak for Him:",
     "God also condemns the false prophets who claim to speak for him:"),
    ("He announces a new covenant in which His law will be written on their hearts, sins will be forgiven, and His commitment to His people will endure.",
     "he announces a new covenant in which his law will be written on their hearts, sins will be forgiven, and his commitment to his people will endure."),
    ("God will break the yoke of foreign rule and bring His people home.",
     "God will break the yoke of foreign rule and bring his people home."),
    ("Jesus spoke of this new covenant in His blood, and Hebrews 8 quotes this whole passage. God says His promise to Israel is as sure as the sun, moon, and stars.",
     "Jesus spoke of this new covenant in his blood, and Hebrews 8 quotes this whole passage. God says his promise to Israel is as sure as the sun, moon, and stars."),
    ("God confirms both coming judgment and His everlasting covenant of restoration.",
     "God confirms both coming judgment and his everlasting covenant of restoration."),
    ("He will hand the city over to Babylon, but He will also bring His people back and make an everlasting covenant with them.",
     "he will hand the city over to Babylon, but he will also bring his people back and make an everlasting covenant with them."),
    ("God invites him, “Call unto me, and I will answer thee, and shew thee great and mighty things, which thou knowest not.” He promises to heal Jerusalem and fill it again with joyful voices, weddings, and songs of thanks. He repeats His promise of a righteous Branch from David's family, and says, “David shall never want a man to sit upon the throne of the house of Israel.” His covenant with David is as certain as day and night.",
     "God invites him, “Call unto me, and I will answer thee, and shew thee great and mighty things, which thou knowest not.” he promises to heal Jerusalem and fill it again with joyful voices, weddings, and songs of thanks. he repeats his promise of a righteous Branch from David's family, and says, “David shall never want a man to sit upon the throne of the house of Israel.” his covenant with David is as certain as day and night."),
    ("So He announces a different kind of liberty:",
     "So he announces a different kind of liberty:"),
    ("even though He has sent prophet after prophet.",
     "even though he has sent prophet after prophet."),
    ("everything He has spoken to him since the days of Josiah.",
     "everything he has spoken to him since the days of Josiah."),
    ("He also announces that Jehoiakim will have no son on David's throne",
     "he also announces that Jehoiakim will have no son on David's throne"),
    ("then reject His command to remain in Judah.",
     "then reject his command to remain in Judah."),
    ("God reminds him that He is about to tear down what He built, and then asks,",
     "God reminds him that he is about to tear down what he built, and then asks,"),
    ("Yet God comforts His own people:",
     "Yet God comforts his own people:"),
    ("But He will bring them back to their pasture",
     "But he will bring them back to their pasture"),
    ("God calls His people to escape:",
     "God calls his people to escape:"),
    ("and His name will be “THE LORD OUR RIGHTEOUSNESS.”",
     "and his name will be “THE LORD OUR RIGHTEOUSNESS.”"),
    ("The LORD will roar from on high, and His judgment will reach the ends of the earth.",
     "The LORD will roar from on high, and his judgment will reach the ends of the earth."),
    ("God uses their faithfulness to expose Judah's refusal to hear His repeated warnings, while promising Jonadab's descendants an enduring place before Him.",
     "God uses their faithfulness to expose Judah's refusal to hear his repeated warnings, while promising Jonadab's descendants an enduring place before him."),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "05_major_prophets.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("# Jeremiah")
    end = text.index("# Lamentations")
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
    apply_historical_moments()
    apply_story_fixes()
