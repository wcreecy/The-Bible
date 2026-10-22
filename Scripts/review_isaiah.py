#!/usr/bin/env python3
"""Apply the completed editorial review for Isaiah to source content only."""

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def dedupe_role(role):
    """Every Key Figure role in this file was written twice: once lowercase-first with
    no trailing period, then again capitalized with one. Keep the capitalized half."""
    body = role[:-1] if role.endswith(".") else role
    for i in range(1, len(body)):
        if body[i - 1] in " ." and body[i:i + 1].isupper():
            first = body[:i].rstrip(". ")
            second = body[i:].rstrip(". ")
            if first and first.lower() == second.lower():
                return second + "."
    return role


PLACEMENT = {
    1: "Song of Solomon closed the Wisdom books with a celebration of human love. Isaiah opens a very different kind of book: a prophet's direct indictment of Judah and Jerusalem for rebellion against God, written sometime across the reigns of Uzziah through Hezekiah (1:1). Chapter 2 turns from this indictment to a vision of nations streaming to the Lord's mountain in peace.",
    2: "Chapter 1 ended by contrasting Jerusalem's present corruption with a future, purified city. Here Isaiah pictures that future directly: nations streaming to the Lord's mountain to learn his ways, followed by a sharp warning that human pride and idols will be humbled before that day arrives. Chapter 3 turns from this global vision back to Judah's own failing leaders.",
    3: "Chapter 2 warned that pride, including Judah's confidence in its own strength, would be humbled. Here that humbling becomes specific: Isaiah describes failing leadership, social disorder, and finally the humiliation of Zion's wealthy women, stripped of the finery they trusted in. Chapter 4 answers this collapse with a brief promise of cleansing for those who remain.",
    4: "Chapter 3 closed with Zion's daughters stripped of their former glory. Here a brief promise answers that judgment: survivors will be called holy, and a cloud and fire like the wilderness years will shelter Mount Zion. Chapter 5 returns to indictment with the song of the unfruitful vineyard.",
    5: "Chapter 4 promised cleansing for a surviving remnant. Here Isaiah explains what made cleansing necessary: a song pictures Israel and Judah as a carefully tended vineyard that produced only wild grapes, followed by six woes against greed, drunkenness, and corrupt judgment, and a warning of an approaching army. Chapter 6 shifts from this public indictment to Isaiah's own personal call to prophesy.",
    6: "Chapter 5 ended with judgment advancing like an invading army. Here, in the year King Uzziah died, Isaiah receives his call: a vision of the Lord enthroned in the temple, his own lips purified by a burning coal, and a commission to preach to a people who will hear without understanding. Chapter 7 puts that commission to its first test, sending Isaiah to a frightened King Ahaz.",
    7: "Chapter 6 ended with Isaiah commissioned to speak to a people who would resist his message. Here that resistance appears in King Ahaz himself, who trembles before an alliance of Aram and northern Israel instead of trusting God's word through Isaiah, who offers him the Immanuel sign anyway. Chapter 8 gives a second sign, a child's name, confirming the same message in a different form.",
    8: "Chapter 7 offered Ahaz the Immanuel sign as proof of God's presence. Here a second sign-child, named Maher-shalal-hash-baz, announces how soon Damascus and Samaria will fall, before Isaiah warns that the same Assyrian flood will reach Judah and calls his hearers to fear God rather than consult mediums. Chapter 9 answers this gathering darkness with a promise of light dawning over the very region Assyria devastates first.",
    9: "Chapter 8 ended in darkness, with Isaiah's hearers warned against seeking answers from mediums. Here light breaks over that same darkness: a child is announced whose government will bring endless peace to David's throne, though the chapter's second half shows northern Israel refusing to repent even as judgment after judgment falls. Chapter 10 explains why that judgment keeps coming: unjust lawmakers at home and Assyria's advance from outside.",
    10: "Chapter 9 showed Israel absorbing judgment after judgment without repenting. Here Isaiah names two sources of that judgment: lawmakers who legislate against the poor at home, and Assyria, God's own instrument abroad, which will itself be judged for its arrogance once its purpose is served. Chapter 11 answers Assyria's violent rule with the picture of a very different king.",
    11: "Chapter 10 promised that Assyria's oppressive rule would end. Here Isaiah describes what should follow it: a shoot from Jesse's stump, filled with the Lord's Spirit, who judges justly and ushers in a peace so complete that even the natural world is pictured at rest. Chapter 12 responds to this vision with a short song of thanksgiving.",
    12: "Chapter 11 pictured Israel's scattered people gathered and reconciled. Here the book's first major section closes with a short song of thanksgiving, inviting worshipers to draw joyfully from the wells of salvation and make God's deeds known among the nations. Chapter 13 opens a long new section of oracles against those same surrounding nations, beginning with Babylon.",
    13: "Chapter 12 closed the book's first section with a song of thanksgiving. Here a long new section begins: oracles against foreign nations, opening with Babylon, as the Lord summons distant armies and the day of the Lord brings cosmic terror down on the city's pride. Chapter 14 continues the Babylon oracle with relief for Jacob and a taunt against its fallen king.",
    14: "Chapter 13 announced Babylon's fall through cosmic, terrifying imagery. Here the oracle continues on a more personal scale: Jacob is promised rest from its oppressors while Babylon's own king is taunted as he falls from heaven-like pride to the grave, with shorter notices against Assyria and Philistia added after it. Chapter 15 moves to a different neighbor, Moab, pronouncing a similar judgment.",
    15: "Chapter 14 taunted Babylon's fallen king and briefly turned to Assyria and Philistia. Here the oracles turn to Moab, naming its towns one by one as they fall, while priests and refugees flee carrying what they can and even the prophet's own voice joins their grief. Chapter 16 continues the Moab oracle, picturing refugees seeking shelter in Judah.",
    16: "Chapter 15 showed Moab's towns falling and its people fleeing. Here those same refugees are urged to seek shelter under Judah's protection, while Isaiah laments Moab's ruined vineyards and pride before setting a three-year deadline on what remains of its glory. Chapter 17 turns from Moab to another neighboring judgment, this time against Damascus and Ephraim's failing alliance.",
    17: "Chapter 16 closed with a countdown to the loss of Moab's remaining glory. Here the oracles turn to Damascus and Ephraim, whose military alliance against Judah is shown collapsing into ruin, though a surviving remnant is still invited to look to its Maker rather than the idols that failed to protect it. Chapter 18 turns further south, addressing a land beyond the rivers of Cush.",
    18: "Chapter 17 ended with a remnant invited to turn from idols to its Maker. Here a brief oracle addresses the land beyond Cush's rivers, calling the world's attention to God's quiet watchfulness over events before a ripening power is cut down, and ending with a gift brought to Mount Zion. Chapter 19 turns next to Egypt itself, Cush's northern neighbor and ally.",
    19: "Chapter 18 closed looking toward a distant nation eventually honoring Zion. Here Egypt itself comes under judgment: its counselors fail, its economy collapses, and its people fall into confusion, yet the chapter unexpectedly ends with Egyptians worshiping the Lord alongside Assyria and Israel in shared blessing. Chapter 20 turns Egypt's judgment into something Isaiah himself must act out in public.",
    20: "Chapter 19 ended picturing Egypt eventually reconciled with Israel and Assyria. Here, in the year an Assyrian commander attacks Ashdod, Isaiah is told to act out Egypt's coming humiliation himself, walking stripped and barefoot for three years as a living warning against trusting Egypt and Cush for protection. Chapter 21 turns to a different warning, a watchman's vision of Babylon's own sudden fall.",
    21: "Chapter 20 had Isaiah himself act out a coming judgment. Here a watchman relays an urgent, almost breathless vision of Babylon's fall, followed by two brief, cryptic oracles concerning Dumah and fleeing Arabian tribes. Chapter 22 turns this same kind of warning directly onto Jerusalem, Isaiah's own city.",
    22: "Chapter 21 carried warnings of upheaval among Judah's neighbors. Here that same danger reaches Jerusalem itself: the city's frantic defensive preparations and celebrations are condemned for ignoring the God who made them, and a second oracle removes the proud steward Shebna in favor of Eliakim. Chapter 23 turns outward again, this time to the trading city of Tyre.",
    23: "Chapter 22 showed even a trusted steward's position eventually giving way. Here Tyre's entire merchant network collapses, its trading partners told to wail at the loss, though the chapter ends looking ahead seventy years to a restored Tyre whose profits are dedicated to the Lord rather than hoarded. Chapter 24 widens this kind of judgment from a single trading city to the whole earth.",
    24: "Chapter 23 closed a long series of oracles against individual nations with Tyre's eventual trade dedicated to the Lord. Here the scope suddenly widens to the whole earth, emptied and despoiled because its people have broken an enduring covenant, though scattered praise breaks through even as the judgment continues toward a vision of God reigning on Zion. Chapter 25 answers this vast judgment with a song celebrating the Lord's faithfulness and a feast for all peoples.",
    25: "Chapter 24 ended with God's reign announced over a judged and shaken world. Here a song responds with praise, celebrating the Lord's faithfulness in bringing down a fortified city and sheltering the poor, before picturing Mount Zion as the site of a feast for every people and the removal of death's own covering. Chapter 26 continues in song, turning to Judah's own secure city and a hope that reaches even beyond death.",
    26: "Chapter 25 pictured death's covering removed on Mount Zion. Here a song develops that same hope further: Judah's secure city is contrasted with proud cities brought low, a plea rises for divine help amid distress, and the hint that 'thy dead men shall live' pushes the hope of chapter 25 even further, toward a brief shelter until God's anger passes. Chapter 27 closes this section of songs with Leviathan's defeat and Israel's regathering.",
    27: "Chapter 26 closed telling God's people to shelter briefly until indignation passes. Here that waiting is rewarded: the Lord defeats Leviathan, the chaos monster of the sea, and the vineyard that once yielded only wild grapes in chapter 5 is now tended and fruitful, its scattered people gathered to worship on Jerusalem's holy mountain. Chapter 28 turns from this restoration back to present failure, a woe against the drunken leaders of Ephraim and Judah.",
    28: "Chapter 27 closed with a vision of Israel restored and gathered to worship. Here the book returns to present failure: Isaiah rebukes Ephraim and Judah's leaders for drunken mockery of instruction, exposes their false sense of safety as a 'covenant with death,' and answers it with a tested cornerstone in Zion and a farmer's lesson in patient, varied discipline. Chapter 29 turns this same warning onto Jerusalem itself, under the name Ariel.",
    29: "Chapter 28 exposed a false refuge built on indulgence and denial. Here Jerusalem, called Ariel, experiences both danger and deliverance: its besiegers vanish like a dream even as its own people are shown honoring God only outwardly, though the chapter ends promising a future reversal where the deaf hear and the oppressed find justice. Chapter 30 shows that same people seeking a different, equally misplaced refuge: Egypt's help instead of God's.",
    30: "Chapter 29 promised justice for the oppressed in a future reversal. Here Judah's leaders undercut that same hope in the present, negotiating with Egypt without ever asking what God wants, even as God still offers mercy, teaching, and healing to anyone willing to return and trust him instead. Chapter 31 repeats this same warning even more directly, against relying on Egypt's horses and chariots.",
    31: "Chapter 30 condemned Judah's leaders for seeking Egypt's help without consulting God. Here the same warning sharpens into a direct woe against anyone who trusts Egyptian horses and chariots instead of the Holy One of Israel, who is pictured both as a lion defending its prey and as hovering birds guarding Jerusalem. Chapter 32 turns from this warning about false protectors to a vision of genuinely good leadership.",
    32: "Chapter 31 promised that God himself would defend Jerusalem. Here Isaiah pictures what that defended city should look like under good leadership: a king and princes who govern with fairness, a sharp warning to complacent women that their comfortable life can still collapse, and a Spirit poured out at last that turns justice into lasting peace. Chapter 33 returns to present danger with a woe against a betraying destroyer, even as it promises Zion's eventual security.",
    33: "Chapter 32 envisioned a just king and a Spirit-given peace. Here present danger interrupts that vision: a woe falls on a treacherous destroyer as negotiations collapse and roads empty, yet the chapter still ends picturing Zion secure, with the Lord himself serving as its judge, lawgiver, and king, and its sins forgiven. Chapter 34 widens this same threat of judgment out to all the nations, especially Edom.",
    34: "Chapter 33 promised Zion's eventual security even amid present danger. Here that promise has a dark counterpart: all nations, and especially Edom, are summoned to a judgment described in cosmic terms, leaving the land desolate for wild creatures and recorded in a decree that will not be forgotten. Chapter 35 answers this devastation directly, picturing the same wilderness blossoming instead.",
    35: "Chapter 34 pictured a desolate land left to wild creatures. Here that same kind of landscape is transformed instead: the wilderness blossoms, weak hands and failing eyes are healed, and a highway called 'the way of holiness' carries the redeemed safely home to Zion. Chapter 36 shifts from this poetic vision to a historical narrative, as Assyrian officials actually reach the gates of Jerusalem.",
    36: "Chapter 35 closed with a poetic vision of a safe road home. Here history interrupts poetry: Assyrian officials reach Jerusalem after capturing Judah's fortified towns, and the Rabshakeh publicly mocks Judah's trust in both Egypt and God, demanding surrender in the people's own language. Chapter 37 shows how Hezekiah responds to that same threat with prayer rather than panic.",
    37: "Chapter 36 ended with the Rabshakeh's public threats still hanging over Jerusalem. Here Hezekiah answers those threats first with mourning and a request for Isaiah's counsel, then with prayer spread out before the Lord over Assyria's own written challenge, after which Isaiah announces deliverance and the Assyrian army is destroyed, with Sennacherib himself later killed by his own sons. Chapter 38 turns from this national crisis to Hezekiah's own personal brush with death.",
    38: "Chapter 37 ended with Jerusalem delivered from Assyrian destruction. Here a different kind of threat reaches Hezekiah himself: deathly illness, met with prayer and answered with fifteen additional years and a poetic song of thanksgiving once he recovers. Chapter 39 shows how Hezekiah uses some of those added years, welcoming envoys from Babylon in a decision that will have lasting consequences.",
    39: "Chapter 38 ended with Hezekiah grateful for fifteen added years of life. Here he spends some of that time showing Babylonian envoys his entire treasury and armory, prompting Isaiah to predict that everything Hezekiah just displayed, and his own descendants, will one day be carried off to the very nation he is now entertaining. Chapter 40 jumps ahead to address that exile directly, opening the book's long turn toward comfort.",
    40: "Chapter 39 ended predicting exile to the very nation Hezekiah had just entertained. Here the book jumps ahead to address that exile directly: Jerusalem's hardship is finally over, a highway is prepared through the wilderness, and the Lord's enduring word is set against frail human power, with renewed strength promised to the weary who wait for him. Chapter 41 continues this comfort by putting the surrounding nations on trial and reassuring Israel that it remains God's chosen servant.",
    41: "Chapter 40 promised renewed strength to those who wait on God. Here that promise gets a concrete setting: the Lord puts the nations on trial, announces a conqueror rising from the east, and reassures Israel directly as his chosen servant who need not fear, while idols are challenged to predict anything at all and fail. Chapter 42 introduces a different kind of servant, one commissioned to bring God's justice gently to those same nations.",
    42: "Chapter 41 reassured Israel as God's chosen servant. Here a different servant is introduced, one empowered by God's Spirit to bring justice to the nations gently rather than by force, prompting a global song of praise, even as the chapter's second half rebukes Israel itself as a servant who is blind and deaf to the message entrusted to it. Chapter 43 answers that rebuke with fresh reassurance, telling Israel not to fear because it remains redeemed and named by God.",
    43: "Chapter 42 rebuked Israel for failing to listen despite its calling. Here God answers that failure with reassurance rather than rejection: Israel is told not to fear because it has been redeemed and named, promised a new exodus through the wilderness even as its past failures are named honestly. Chapter 44 continues this same pattern, promising renewal for Jacob's descendants before turning to mock the idols Israel has been tempted to trust instead.",
    44: "Chapter 43 promised forgiveness and a new exodus despite Israel's failures. Here that promise continues with water and Spirit poured out on Jacob's descendants, framed by a long satire on the absurdity of carving a god from the same wood used for cooking fuel, before the Lord names Cyrus specifically as the ruler who will enable Jerusalem's rebuilding. Chapter 45 speaks to that same Cyrus directly, addressing him as God's anointed instrument.",
    45: "Chapter 44 first named Cyrus as Jerusalem's future rebuilder. Here the Lord speaks to Cyrus directly, calling him his anointed instrument and giving him victories for Israel's sake even though Cyrus does not know him, before the chapter defends the Creator's right to work through whomever he chooses and invites all the earth's peoples to turn to the one God. Chapter 46 contrasts this active, carrying God with Babylon's own gods, pictured as dead weight loaded onto animals.",
    46: "Chapter 45 ended inviting every nation to turn to the one true God. Here that invitation gets a vivid contrast: Babylon's gods Bel and Nebo are loaded as dead weight onto tired animals, while the Lord describes himself as the one who has carried Israel from birth to old age, calling stubborn hearers simply to remember. Chapter 47 continues the contrast by picturing Babylon itself, not just its gods, brought down from a queen's throne into the dust.",
    47: "Chapter 46 contrasted Babylon's helpless idols with the Lord who carries Israel. Here Babylon itself, personified as a proud queen, is cast down into the same kind of humiliation, condemned for its harsh treatment of God's people and its confidence that disaster could never reach it, while its famous astrologers prove powerless to rescue it. Chapter 48 turns this same confrontation toward Israel, exposing its own stubbornness even as it is called to leave Babylon behind.",
    48: "Chapter 47 showed Babylon's own astrologers powerless to save it. Here Israel faces a different but related confrontation: called stubborn for invoking God's name without real truthfulness, even as the Lord still declares his plan against Babylon and calls his people to leave it behind with rejoicing rather than reluctance. Chapter 49 turns from the people as a whole to a single servant's own personal calling and frustration.",
    49: "Chapter 48 called God's people to leave Babylon behind. Here one servant reflects personally on that larger mission: called from the womb yet frustrated that his work seems wasted, he receives a wider commission as light to the nations, while God promises Zion itself that her scattered children will return and she has not been forgotten. Chapter 50 continues this servant's story, answering the charge that Zion was ever truly abandoned.",
    50: "Chapter 49 promised Zion that God had not forgotten her. Here that promise is defended directly: God challenges any idea that Zion was ever sent away for a real fault of his, while the servant himself models what trusting that promise looks like, enduring violence while trusting God's vindication, and the chapter closes urging hearers to walk by the Lord's light rather than their own. Chapter 51 picks up that same call to trust by pointing back to Abraham and Sarah.",
    51: "Chapter 50 urged trust even while walking in darkness. Here that trust is grounded in memory: those seeking righteousness are pointed back to Abraham and Sarah's own small beginnings, repeated calls to 'awake' recall God's ancient victory over the sea, and Jerusalem is promised that the cup of staggering she has drunk will be taken from her and given to her oppressors instead. Chapter 52 answers this with Zion herself being told to awake and shake off her captivity.",
    52: "Chapter 51 promised Jerusalem that her cup of suffering would pass to her oppressors. Here Zion is told to act on that promise, waking and dressing in beauty to leave captivity behind, while a messenger announces good news of peace and the chapter closes by introducing a servant who will be exalted only after shocking, almost unrecognizable disfigurement. Chapter 53 continues directly from that introduction, describing the servant's suffering and vindication in full.",
    53: "Chapter 52 ended by introducing a servant disfigured beyond recognition. Here his story is told in full: rejected and acquainted with grief despite his innocence, his suffering is interpreted as bearing the iniquities of others, and the poem ends with his vindication and ongoing intercession. Chapter 54 turns from this individual suffering to Zion's own coming joy, a barren city called to sing because of what that suffering accomplished.",
    54: "Chapter 53 described the servant's suffering accomplishing something for others. Here Zion receives the benefit directly: once barren and ashamed, she is called to sing and enlarge her tent, as God compares his commitment to her with his ancient oath to Noah and promises rebuilt beauty and security no weapon can overturn. Chapter 55 extends that same promised abundance into an open invitation for anyone thirsty or poor to come and receive it.",
    55: "Chapter 54 promised Zion a rebuilt and lasting security. Here that same abundance is opened to anyone willing to receive it: the thirsty and poor are invited to food and drink without payment, called to seek the Lord while he may be found, and promised that his word accomplishes its purpose as surely as rain makes the earth grow. Chapter 56 turns this open invitation into a specific test case, welcoming foreigners and eunuchs who keep God's covenant.",
    56: "Chapter 55 opened God's grace to anyone willing to receive it. Here that openness becomes concrete policy: foreigners and eunuchs who keep the Sabbath and hold to God's covenant are promised a lasting place in a house of prayer meant for 'all people,' even as the chapter closes denouncing Israel's own blind and greedy watchmen. Chapter 57 continues that same contrast, showing the righteous quietly disappearing while idolatry flourishes unchecked.",
    57: "Chapter 56 denounced leaders too negligent to notice real danger. Here that same blindness shows itself again: the righteous are taken away and no one even registers what their loss means, while the chapter sharply denounces the community's idolatry before promising revival to the humble and contrite, though never peace to the wicked. Chapter 58 exposes a related blindness, a community that fasts sincerely while still oppressing the people around it.",
    58: "Chapter 57 promised healing to the humble but no peace to the wicked. Here that same gap between appearance and reality becomes very specific: a community fasts sincerely while still exploiting its own laborers, and God insists that the fast he actually wants loosens oppression, feeds the hungry, and shelters the homeless instead. Chapter 59 widens this same concern for justice, insisting that it is violence and injustice, not any failure of God's power, that has separated the people from him.",
    59: "Chapter 58 named practical injustice as the real obstacle to God's blessing. Here that same point is pressed further: God's power has not grown too short to save, it is the people's own violence and lies that have separated them from him, until a communal confession of failed justice leads the Lord to take up the cause of righteousness himself, promising both a redeemer and an enduring covenant Spirit. Chapter 60 answers that promised redemption with a vision of Zion rising, finally, into glory.",
    60: "Chapter 59 promised that God himself would intervene when no one else could. Here that intervention arrives as glory: Zion is summoned to rise and shine because the Lord's own glory has come, with nations and kings bringing children, wealth, and rebuilding help to her gates until violence ends and God himself becomes her everlasting light. Chapter 61 narrows this grand vision to a single anointed speaker, sent to announce that same good news directly to the poor.",
    61: "Chapter 60 pictured Zion's rising glory drawing nations to her light. Here a single anointed speaker is sent to bring that same good news directly to individuals: liberty for captives, comfort for mourners, and rebuilt ruins for a people who will be called priests of the Lord. Chapter 62 continues in that speaker's own voice, refusing to stay silent until Zion's righteousness is finally visible to everyone.",
    62: "Chapter 61 closed with a song celebrating salvation and righteousness. Here the speaker takes up that same hope as a personal commitment, refusing to stay silent until Zion's righteousness is visible and she receives a new name, while watchmen are appointed to keep calling on God and the way is prepared for her returning people. Chapter 63 turns from this patient, hopeful watching to a sudden, dramatic scene of judgment, a warrior arriving from Edom.",
    63: "Chapter 62 ended with watchmen preparing the way for Zion's restoration. Here a strikingly different figure appears first, a warrior coming from Edom with garments stained red from judgment on hostile powers, before the chapter turns to a communal prayer that recalls God's past mercies in the exodus, confesses rebellion, and pleads for his renewed presence. Chapter 64 continues that same prayer, pressing the plea further and asking God to tear the heavens open.",
    64: "Chapter 63 opened a communal prayer recalling God's past mercies. Here that prayer presses further, longing for God to tear open the heavens and act as dramatically as he once did, while the speakers confess their own uncleanness, address God as both potter and father, and lament that Zion and the temple now lie in ruins. Chapter 65 answers this long prayer directly, with God describing exactly how available he has actually been to a rebellious people.",
    65: "Chapter 64 lamented the ruined temple and pleaded for God's intervention. Here God answers directly, describing himself as available all along to a people who simply would not turn to him, even as he distinguishes his faithful servants from those who reject him and promises, beyond all this, new heavens and a new earth where even animals live at peace. Chapter 66 closes the book with one final oracle, combining that same promised joy with a final warning.",
    66: "Chapter 65 promised new heavens and a new earth beyond all present ruin. Here the book closes on that same note, combined with a final warning: God declares that no building, however grand, could ever contain him, Zion gives birth to a people suddenly and without labor, and the book ends with nations gathered from everywhere to witness God's glory, even as idolatry and wickedness still face judgment. The next book, Jeremiah, turns from Isaiah's sweeping visions to one prophet's own anguished, personal struggle to warn a nation that will not listen.",
}

THEMES = {
    1: [("Rebellion and grief", "Judah is pictured as a child who has rebelled against the parent who raised it, and as a body already covered in untreated wounds, language meant to make the nation's condition feel urgent rather than abstract."),
        ("Worship and justice", "God rejects sacrifices and festivals offered by hands stained with injustice, insisting that true worship cannot be separated from how people treat one another."),
        ("Repentance and renewal", "The invitation to reason together and the promise that sins can become white as snow holds judgment and genuine hope together, rather than offering hope instead of judgment.")],
    2: [("Peace through teaching", "Nations beat their weapons into farm tools only after they come to learn the Lord's ways, showing that lasting peace grows out of shared instruction, not just a ceasefire."),
        ("Idolatry and misplaced confidence", "Isaiah pairs trust in idols with trust in wealth and military strength, treating all three as substitutes people lean on instead of God."),
        ("Humbling of pride", "The repeated image of a coming day that brings down everything lofty and lifted up insists that human pride, in any form, cannot survive an encounter with God.")],
    3: [("Leadership accountability", "Removing every kind of support, judges, counselors, elders, Isaiah shows a society whose collapse starts at the top, among leaders who proved unworthy of trust."),
        ("Protection of the poor", "Officials are directly charged with crushing the poor and grinding their faces, naming a specific abuse of power rather than vague wrongdoing."),
        ("Public pride and reversal", "The long list of women's jewelry and fine clothing, later replaced by rope and burning, turns public status into public shame.")],
    4: [("Hope after judgment", "Naming the Lord's branch and the fruit of the land as glorious for survivors shows that judgment in this book is never presented as the final word."),
        ("Cleansing from bloodshed", "Washing away the filth of Zion's daughters and its bloodstains pictures moral cleansing in the same physical terms used earlier for the city's sin."),
        ("Divine protection", "The cloud by day and fire by night recall the wilderness journey, picturing God's presence over Zion as the same kind of protective guidance Israel once received leaving Egypt.")],
    5: [("Failed fruit of justice", "The vineyard owner did everything right, clearing stones, planting the best vines, building a tower, yet harvested only wild grapes, a picture of effort met with willful failure rather than bad luck."),
        ("Greed and moral inversion", "The woes name people who call evil good and good evil, showing that Judah's problem runs deeper than individual sins, into a confused sense of right and wrong itself."),
        ("Judgment through invasion", "An unnamed army, summoned as easily as a whistle, stands ready to carry out the consequences the vineyard song already announced.")],
    6: [("Divine holiness", "The seraphim's repeated cry of 'holy, holy, holy' and the temple filling with smoke overwhelm Isaiah before he ever receives his commission, placing God's holiness ahead of any human task."),
        ("Cleansing and vocation", "Isaiah cannot volunteer to speak for God until a burning coal first deals with his own unclean lips, showing that calling follows cleansing, not the other way around."),
        ("Hardening and remnant", "The hard commission to preach to unresponsive ears ends with a small note of hope: a holy seed remains even in the stump of a felled tree.")],
    7: [("Faith amid threat", "Isaiah tells Ahaz to stand firm in faith or not stand at all, treating trust in God, not military calculation, as the real foundation of the king's security."),
        ("The Immanuel sign", "A child named 'God with us' is offered as proof that God's presence, not Ahaz's alliances, will determine Judah's future, even though Ahaz never asks for the sign."),
        ("Cost of reliance on empire", "Calling in Assyria for help backfires: the chapter warns that the very empire Ahaz might lean on will become the instrument of grievous consequences for Judah itself.")],
    8: [("Prophetic signs", "A child's own name becomes a public prophecy, repeated every time someone calls him by it, long before events catch up with the warning."),
        ("Trust over panic", "Isaiah tells his followers not to call conspiracy what the frightened crowd calls conspiracy, modeling a trust in God that refuses to be swept up in collective fear."),
        ("Rejecting spirit consultation", "Turning to mediums and wizards who 'peep and mutter' is rejected in favor of turning to God's own instruction and testimony, even when the future looks dark.")],
    9: [("Light and deliverance", "People walking in darkness see a great light, turning the chapter's opening image into a direct promise that gloom will not have the last word."),
        ("Righteous kingship", "Titles like 'Wonderful, Counsellor, The mighty God' describe a ruler whose government will be established with judgment and justice forever, not just for one reign."),
        ("Persistent unrepentance", "The refrain 'his hand is stretched out still,' repeated after each disaster, shows a people who keep absorbing judgment without ever turning back to God.")],
    10: [("Unjust lawmaking", "Decrees that rob the poor of justice are condemned as seriously as any other sin, showing that unfair laws, not just individual cruelty, can bring a nation under judgment."),
         ("The limits of empire", "Assyria boasts that its conquests came by its own strength, but Isaiah insists it is only a tool, like an axe that cannot swing itself, in a purpose it does not control."),
         ("Remnant and reassurance", "Zion is told not to fear the approaching oppressor, because the same Lord who used Assyria will also bring it low once its task is finished.")],
    11: [("Spirit-shaped justice", "The coming ruler judges not by what his eyes see or his ears hear, but by a Spirit-given wisdom and understanding, treating true justice as something deeper than surface appearances."),
         ("Peaceful creation", "Wolves lying down with lambs and children playing near snakes pictures a peace so thorough that even natural hostility between creatures is undone."),
         ("Gathering and unity", "Scattered Israelites return from every direction, and the old rivalry between Ephraim and Judah specifically ends, showing that the promised peace reaches into the nation's own divided history.")],
    12: [("Thanksgiving after distress", "The song assumes real anger has passed, not that it never existed, showing gratitude that comes after hardship rather than instead of it."),
         ("Joyful salvation", "Drawing water from 'the wells of salvation' turns a basic daily task into an image of joy, making salvation feel as ordinary and necessary as water itself."),
         ("Public witness", "Worshipers are told to declare God's deeds among the peoples, turning a private song of relief into a public announcement meant for an audience beyond Israel.")],
    13: [("Accountability of empires", "Babylon is summoned before the same divine courtroom any other nation would face, showing that imperial power offers no exemption from accountability."),
         ("Day-of-the-Lord imagery", "Darkened sun, moon, and stars and a shaking heaven describe Babylon's fall in the same cosmic terms later prophets use for final judgment, not just a change of government."),
         ("Imperial impermanence", "A city famous for permanence is pictured left to owls and wild goats, warning that no empire's glory lasts as long as it assumes.")],
    14: [("Downfall of arrogance", "A king who once said 'I will be like the most High' is pictured instead in the depths of the grave, turning his own boasted ascent into the measure of his fall."),
         ("Rest for the oppressed", "Jacob's promised rest from pain, turmoil, and hard service answers the preceding chapters' violence with something as simple and necessary as relief."),
         ("God's purposes amid nations", "The Lord's declared purpose against Assyria, confirmed with an oath that none can reverse it, shows that nations rise and fall within a plan larger than their own ambitions.")],
    15: [("Public grief", "Naming town after town in mourning turns a general judgment into a map of specific, recognizable losses."),
         ("Displacement", "Moabites carrying their belongings as they flee across the brook of the willows pictures judgment as something that uproots ordinary families, not just abstract cities."),
         ("Judgment's human cost", "Isaiah's own voice crying out 'my heart shall cry out for Moab' shows that pronouncing judgment on a hostile neighbor still costs the prophet real grief.")],
    16: [("Refuge and mercy", "Moab is told to send tribute and find shelter under the shadow of Zion's throne, offering a path to safety even to a nation under judgment."),
         ("Pride and vulnerability", "Moab's famous pride is named directly as the trait that leaves it unable to accept the help being described, pride and vulnerability shown as two sides of the same failure."),
         ("Compassion amid judgment", "Even while pronouncing Moab's downfall, the chapter's grief over its ruined vineyards keeps judgment from becoming a cold, satisfied verdict.")],
    17: [("False security in alliances", "Damascus and Ephraim's military partnership, meant to guarantee safety, instead becomes the very thing that falls together, exposing alliances built apart from God as fragile."),
         ("Turning from idols", "The remnant's invitation to look to its Maker, after describing fields planted with 'strange slips,' contrasts imported religious practices with the one source of real help."),
         ("God's rule over turmoil", "Roaring nations are compared to raging seas that God rebukes and scatters, insisting that even overwhelming political chaos remains under his control.")],
    18: [("Divine watchfulness", "God is pictured calmly watching 'like a clear heat upon herbs' while swift messengers rush across the world, contrasting human urgency with divine patience."),
         ("Judgment before harvest", "Cutting down the sprigs and branches before the harvest ripens pictures a power struck down at the height of its confidence, not after a long decline."),
         ("International recognition", "A gift brought from this distant, 'scattered and peeled' nation to Mount Zion anticipates nations beyond Israel eventually recognizing where true power rests.")],
    19: [("Collapse of false wisdom", "Egypt's wise counselors, famous throughout the ancient world, are shown giving advice that only deepens the nation's confusion, exposing wisdom that excludes God as no wisdom at all."),
         ("Worship beyond Israel", "The picture of Egyptians building an altar to the Lord and being called 'my people' extends worship of Israel's God well past Israel's own borders."),
         ("Reconciliation of former enemies", "A shared highway linking Egypt, Assyria, and Israel turns three historic rivals into a single blessed community, a future reconciliation the present chapter's judgments do not yet show.")],
    20: [("Embodied prophecy", "Isaiah does not just announce Egypt's coming humiliation, he wears it on his own body for three years, making the warning impossible for Judah to ignore or forget."),
         ("Reliance on foreign powers", "Judah's hope that Egypt and Cush could shield it from Assyria is exposed as misplaced before those very powers are led away captive themselves."),
         ("Humiliation of captivity", "Describing captives led away 'naked and barefoot, with their buttocks uncovered' makes captivity's shame vivid rather than abstract.")],
    21: [("Watchfulness amid upheaval", "The watchman stationed to report exactly what he sees models alert attention during a crisis whose outcome is not yet settled."),
         ("Incomplete certainty", "A cryptic exchange about the night, 'the morning cometh, and also the night,' leaves real ambiguity about what comes next rather than offering tidy resolution."),
         ("Hospitality to refugees", "Fleeing people from Kedar are met with the practical instruction to bring them bread and water, grounding a prophetic oracle in basic human care.")],
    22: [("Defenses without repentance", "Jerusalem musters weapons and breaks down houses to strengthen its wall, yet never once 'looked unto the maker thereof,' pairing frantic activity with spiritual indifference."),
         ("Stewardship and accountability", "Shebna's self-serving monument and Eliakim's promised responsibility show that even trusted positions of authority answer to a higher accountability."),
         ("Limits of human security", "Even Eliakim, held up as a reliable replacement, is warned that the support hung on him can eventually give way, denying any single human office permanent security.")],
    23: [("Fragility of commercial pride", "A city that called itself 'the crowning city, whose merchants are princes' is shown undone as easily as any other proud power, commercial success offering no special immunity."),
         ("Far-reaching consequences", "Tyre's trading partners from Tarshish to Egypt feel the shock of its fall, showing how one city's collapse ripples through an entire economic network."),
         ("Commerce and dedication", "Tyre's eventual profits being called 'holiness to the LORD' pictures even ordinary trade eventually serving a purpose beyond itself.")],
    24: [("Universal accountability", "The earth itself is charged with defiling the ground 'under the inhabitants thereof' by breaking 'the everlasting covenant,' extending accountability past any single nation to humanity as a whole."),
         ("Fragility of ordinary joy", "Simple pleasures like wine, music, and strong drink are pictured ceasing entirely, showing how completely this judgment reaches into everyday life, not just political structures."),
         ("Divine kingship", "The chapter's climax, the Lord reigning 'in mount Zion, and in Jerusalem,' answers the preceding devastation with the claim that one king's rule outlasts every collapsed empire.")],
    25: [("Protection of the vulnerable", "The Lord is praised as 'a strength to the poor, a strength to the needy in his distress,' naming protection of the vulnerable as the direct reason for this song of praise."),
         ("Inclusive banquet", "A feast of rich food prepared 'for all people' on Zion extends what might seem like a national celebration into an invitation reaching every nation."),
         ("Waiting for salvation", "The declaration 'we have waited for him' turns the chapter's hope into something already being lived out in patient expectation, not just a future promise.")],
    26: [("Trust and stability", "A mind 'stayed' on God is promised 'perfect peace,' tying inner stability directly to where trust is placed rather than to outward circumstances."),
         ("Righteous paths", "Walking in 'the way of thy judgments' is named as the path people actually wait on, making righteousness itself an object of patient hope, not just a rule to follow."),
         ("Hope beyond death", "The declaration that the dead will live and 'awake and sing' offers one of the Old Testament's clearest glimpses of hope that reaches past the grave.")],
    27: [("Victory over chaos", "Defeating Leviathan with 'his sore and great and strong sword' pictures God's victory in the same cosmic terms ancient readers used for chaos itself, not just a political enemy."),
         ("Restored vineyard", "The same vineyard pictured ruined in chapter 5 is here watered and guarded 'night and day,' turning an earlier image of judgment into one of careful restoration."),
         ("Gathering and worship", "A great trumpet calls Israel's scattered people home from Assyria and Egypt specifically to worship on Jerusalem's mountain, tying their return directly to its purpose.")],
    28: [("Leadership impaired by indulgence", "Priests and prophets are shown reeling with strong drink while trying to interpret God's message, letting indulgence directly corrupt their ability to lead."),
         ("False refuge", "Calling their false sense of safety 'a covenant with death' exposes a refuge that feels secure but cannot actually survive the judgment it claims to escape."),
         ("Wise and measured discipline", "A farmer who threshes different grains with different tools models discipline fitted carefully to its purpose, not applied the same way in every case.")],
    29: [("Judgment and deliverance", "Jerusalem's enemies are besieging it one moment and vanishing like a dream the next, holding judgment and deliverance together within a single chapter."),
         ("Empty reverence", "People who honor God 'with their lips' while their hearts stay distant are told their worship has become nothing more than rules memorized by rote."),
         ("Reversal for the marginalized", "The promise that the deaf will hear and the poor will find fresh joy in the Lord pictures the people furthest from power becoming the clearest beneficiaries of the coming change.")],
    30: [("Failed political refuge", "Judah's envoys travel all the way to Egypt for protection God never authorized, turning diplomacy without prayer into its own form of rebellion."),
         ("Returning and resting", "The offer that 'in returning and rest shall ye be saved' names simple, available responses, turning back and settling down, against Judah's frantic search for foreign help."),
         ("Restoration after distress", "A promised teacher who will no longer be hidden, and bread and water in time of affliction, show relief arriving precisely during hardship, not only after it ends.")],
    31: [("Limits of military alliances", "Egypt's horses are called 'flesh, and not spirit,' a blunt reminder that even the era's most advanced military technology cannot substitute for God's own strength."),
         ("God's protection", "The image of the Lord 'as birds flying' to defend Jerusalem pairs real tenderness with real power, protection pictured as both gentle and effective."),
         ("Repentance and idolatry", "The call to throw away idols 'which your own hands have made for a sin' ties genuine repentance to a concrete, physical act, not just a change of feeling.")],
    32: [("Just leadership", "A king who reigns in righteousness is compared to 'a hiding place from the wind' and 'rivers of water in a dry place,' describing good leadership in terms of basic relief and shelter, not just fair rulings."),
         ("Complacency challenged", "Women 'at ease' are warned that fields and vineyards can fail within a single year, challenging comfort that assumes today's security will simply continue."),
         ("Spirit and peace", "The Spirit poured out 'from on high' is directly credited with turning the wilderness fruitful and producing peace, tying the chapter's hope for justice to God's own initiative rather than human reform alone.")],
    33: [("Justice for treachery", "A destroyer who has not yet been dealt treacherously with is still promised the same treatment it has dealt out, insisting that betrayal eventually meets its own kind of justice."),
         ("Holy living", "The question 'who shall dwell with the devouring fire' is answered with a list of honest, uncorrupted conduct, tying the ability to stand before God to how a person actually lives."),
         ("Secure Zion", "Zion is pictured as 'a quiet habitation' whose stakes will never be removed, promising a stability that present danger has not yet delivered.")],
    34: [("Judgment beyond Judah", "Turning this judgment onto 'all nations' and 'all their armies' shows that Isaiah's warnings were never meant to apply to Judah's enemies alone."),
         ("Edom as symbol of hostility", "Edom, a nation with a long history of hostility toward Israel, becomes a specific, concrete example of what judgment against persistent enmity actually looks like."),
         ("Desolation imagery", "Owls, satyrs, and wild beasts taking over Edom's ruined palaces turn abandonment into a vivid, almost haunted picture of what judgment leaves behind.")],
    35: [("Courage amid fear", "Weak hands and feeble knees are told directly to be strong, pairing the promise of future healing with an immediate call to courage in the meantime."),
         ("Healing and abundance", "Blind eyes opened, deaf ears unstopped, and water bursting out in the desert combine physical healing with the land's own abundance into a single picture of restoration."),
         ("Way of holiness", "A highway reserved for 'the redeemed' and closed to 'the unclean' turns the journey home itself into a picture of who belongs in the renewed community.")],
    36: [("Pressure of propaganda", "The Rabshakeh speaks loudly in Hebrew specifically so the people on the wall can hear him, turning military pressure into a deliberate campaign of public psychological warfare."),
         ("Misrepresentation of faith", "Claiming that Hezekiah's own religious reforms have offended God twists Judah's faith against itself, misrepresenting trust in God as the very reason for coming disaster."),
         ("Public fear and restraint", "Hezekiah's officials ask the Rabshakeh to speak Aramaic instead of Hebrew specifically to protect public morale, showing real concern for how fear spreads among people who are listening.")],
    37: [("Prayer under threat", "Hezekiah's first response to Assyria's threats is to go to the temple and pray, not to issue a counter-threat, modeling where he actually places his trust under pressure."),
         ("Divine answer to arrogance", "God's response directly quotes Assyria's own boasts back at it before promising to humble them, answering arrogance on its own terms before overturning it."),
         ("Deliverance and limits of sources", "The narrative reports Jerusalem's deliverance and Sennacherib's death without fully explaining how, a reminder that even this book's own historical accounts leave some details to other sources.")],
    38: [("Prayer and mortality", "Hezekiah's prayer while facing death, 'I shall not see the LORD... in the land of the living,' voices mortality's fear honestly rather than with practiced composure."),
         ("Mercy and signs", "The shadow moving backward on the sundial gives Hezekiah a visible, physical confirmation that God's promised extra years are real and not just comforting words."),
         ("Gratitude for restored life", "Hezekiah's own written song of thanksgiving turns his recovery into worship, preserving his gratitude in his own words rather than only a narrator's report.")],
    39: [("Danger of displaying power", "Hezekiah shows Babylon's envoys 'all that was found in his treasures,' holding nothing back from visitors whose nation would later carry that same wealth away."),
         ("Coming exile", "Isaiah's prediction that Judah's treasures and descendants will go to Babylon plants, generations early by the book's own reckoning, the very crisis the book's later chapters address directly."),
         ("Limited royal perspective", "Hezekiah's relieved response, that at least peace will last in his own days, shows a king satisfied with avoiding disaster in his own lifetime rather than grieving what his descendants will face.")],
    40: [("Comfort and homecoming", "The double command 'comfort ye, comfort ye my people' opens this section by addressing suffering directly, rather than easing into it gradually."),
         ("Creator beyond idols", "Measuring the waters 'in the hollow of his hand' and weighing mountains in scales sets the Creator's scale against any idol, no comparison even seems reasonable."),
         ("Strength for the weary", "The promise that those who wait on the Lord will 'mount up with wings as eagles' answers exhaustion with renewal rather than simply demanding more endurance.")],
    41: [("Courage for the weak", "The repeated command 'fear thou not' is grounded in God's own promise to strengthen and help, addressing fear not with denial but with a stated reason not to feel it."),
         ("Water in wilderness", "Opening rivers 'in high places' and fountains 'in the midst of the valleys' pictures God meeting Israel's needs in exactly the places where resources seem least likely."),
         ("Testing false gods", "Idols are directly challenged to 'declare us things for to come,' a test they cannot pass, exposing their powerlessness through a simple, verifiable demand rather than mere assertion.")],
    42: [("Gentle justice", "A servant who will not 'cry, nor lift up, nor cause his voice to be heard in the street,' and who will not break a bruised reed, brings justice through restraint rather than force."),
         ("Light for nations", "Being given 'for a light of the Gentiles' extends the servant's mission explicitly beyond Israel, to opening blind eyes and freeing prisoners among the nations as well."),
         ("Failure to listen", "Calling Israel 'blind' and 'deaf' even though it is God's own chosen servant shows that chosen status does not automatically guarantee attentive hearing.")],
    43: [("Belonging and presence", "Being told 'I have called thee by thy name; thou art mine' grounds Israel's security in personal belonging to God, not in its own faithfulness or performance."),
         ("New exodus", "A way through the sea and a path through mighty waters recalls the exodus from Egypt, applying that same rescuing pattern to a very different captivity in Babylon."),
         ("Forgiveness despite failure", "God's declaration that he blots out transgressions 'for mine own sake' ties forgiveness to God's own character rather than anything Israel has done to earn it.")],
    44: [("Spirit and renewal", "Pouring water on the thirsty and Spirit on Jacob's descendants pictures renewal as something poured out generously, not earned through effort."),
         ("Idols made by human hands", "A craftsman who uses half a tree for fuel and the other half to carve a god he then worships exposes the self-contradiction of idol-making in blunt, almost comic detail."),
         ("Cyrus and rebuilding", "Naming a foreign king, Cyrus, as the one who will say of Jerusalem 'thou shalt be built' claims that even Israel's restoration can come through rulers who have never heard of Israel's God.")],
    45: [("Unexpected instruments", "Calling Cyrus 'my shepherd' and 'his anointed' even though 'thou hast not known me' shows God working through people who have no personal relationship with him at all."),
         ("Creator's freedom", "The image of clay questioning the potter, 'What makest thou?' defends God's freedom to shape events as he chooses, without needing to justify it to the objects he shapes."),
         ("Universal invitation", "The call for 'all the ends of the earth' to look and be saved extends an invitation that began with Cyrus, a foreign king, out to every nation on earth.")],
    46: [("Who carries whom?", "Babylon's gods must be carried on animals just to be moved at all, while the Lord says he has carried Israel every day since birth, reversing who actually does the carrying."),
         ("Futility of manufactured gods", "Idols that must be set in place and 'cannot move' from where they stand are shown unable to even save themselves, let alone the people who worship them."),
         ("Divine purpose", "God's declaration that he will do 'all my pleasure' and call 'a ravenous bird from the east' insists that his purposes, not human or imperial plans, ultimately determine what happens.")],
    47: [("Abuse of power", "Babylon is condemned specifically for showing 'no mercy' to a people already under judgment, naming cruelty toward the vulnerable as its own distinct offense."),
         ("Pride and false security", "The claim 'I shall be a lady for ever' is answered directly with sudden loss and widowhood 'in a moment,' exposing confident permanence as an illusion."),
         ("Limits of divination", "Babylon's astrologers and 'monthly prognosticators,' famous throughout the ancient world, cannot even save themselves, let alone the city that depends on them.")],
    48: [("Religious language without truth", "Swearing by the Lord's name 'but not in truth, nor in righteousness' names a specific gap between religious language and the honesty it is supposed to reflect."),
         ("God acts despite stubbornness", "God admits he has known Israel was 'obstinate' and 'an iron sinew' from birth, yet still acts for his own name's sake rather than waiting for the people to improve first."),
         ("Exodus from Babylon", "The command to 'go ye forth of Babylon' with singing deliberately echoes the earlier exodus from Egypt, turning this departure into another chapter in the same ongoing story.")],
    49: [("Calling and discouragement", "The servant's honest admission, 'I have laboured in vain,' is met not with denial but with an even larger commission, showing discouragement and expanded purpose can coexist."),
         ("Restoration and freedom", "Captives and prisoners are promised they will feed 'in the ways' and find pasture even on bare hills, pairing freedom with real, practical provision rather than release alone."),
         ("Remembered Zion", "The image of a mother unable to forget her nursing child, used to describe God's memory of Zion, makes abandonment sound almost unthinkable rather than merely unlikely.")],
    50: [("Accountability for estrangement", "God's question, 'where is the bill of your mother's divorcement?' insists that any estrangement traces back to the people's own sins, not to God abandoning them first."),
         ("Faithful endurance", "The servant's statement 'I gave my back to the smiters' describes suffering accepted deliberately, as part of faithful obedience, rather than endured helplessly."),
         ("Trust in darkness", "Hearers who 'walketh in darkness, and hath no light' are told to trust in the Lord's name specifically because no other light is currently available to them.")],
    51: [("Memory as encouragement", "Pointing back to Abraham, 'one,' and Sarah who bore a nation, turns remembered small beginnings into encouragement for a people who feel too diminished to hope."),
         ("Enduring righteousness", "God's own salvation is promised to last 'for ever,' while even the heavens are said to vanish, placing his righteousness on a scale no earthly threat can match."),
         ("Release from humiliation", "Transferring the 'cup of trembling' from Jerusalem to her tormentors turns a season of humiliation into a reversal that specifically targets those who caused it.")],
    52: [("Release from captivity", "Zion is told to loose herself from the bands of her own neck, picturing release as something she is called to actively claim, not only passively receive."),
         ("Good news and peace", "Feet described as 'beautiful upon the mountains' belong to a messenger whose only news is peace and salvation, making the act of bringing good news itself worth celebrating."),
         ("Astonishing servant", "A servant whose appearance is 'marred more than any man' is still promised that kings will shut their mouths in astonishment before him, pairing extreme disfigurement with extreme honor.")],
    53: [("Misread suffering", "Onlookers assume the servant is 'stricken, smitten of God, and afflicted' for his own wrongdoing, completely misreading suffering that the poem says was actually for someone else's sake."),
         ("Vicarious suffering", "The claim that 'he was wounded for our transgressions' describes suffering that accomplishes something for other people, not just something that happens to the sufferer himself."),
         ("Vindication after injustice", "Promising that the servant will 'see his seed' and 'divide the spoil with the strong' answers his unjust suffering with an afterward that injustice alone cannot explain.")],
    54: [("Renewed belonging", "Zion is told to forget 'the shame of thy youth' and the reproach of her widowhood, naming renewed belonging as something that specifically replaces a remembered, named shame."),
         ("Covenant peace", "Comparing this promise to God's oath never to flood the earth again ties Zion's security to a covenant already proven reliable across generations."),
         ("Rebuilt and secure Zion", "Foundations of sapphires and gates of carbuncles describe a rebuilt city whose beauty matches the scale of what was lost.")],
    55: [("Grace freely offered", "The invitation to 'buy wine and milk without money and without price' describes grace in deliberately economic terms, available to those who have nothing to pay with."),
         ("Repentance and mercy", "Calling the wicked to forsake 'his thoughts,' not only his actions, asks for a change that reaches past behavior into how a person actually thinks."),
         ("Effective divine word", "Comparing God's word to rain and snow that 'shall not return unto me void' promises that his word reliably accomplishes its purpose, the way weather reliably waters the ground.")],
    56: [("Justice and Sabbath", "Linking justice and Sabbath-keeping together treats faithful rest and fair treatment of others as two sides of the same basic obedience."),
         ("Inclusion in worship", "Promising eunuchs 'a place and a name better than of sons and of daughters' overturns earlier exclusions, making covenant faithfulness, not bodily status, the real qualification for belonging."),
         ("Negligent leadership", "Watchmen called 'blind' and compared to 'dumb dogs' that 'cannot bark' are denounced for failing at the most basic task of their office, raising an alarm.")],
    57: [("Ignored righteousness", "The righteous perishing while 'no man layeth it to heart' names a community too distracted to notice its own real losses."),
         ("Idolatry and betrayal", "Describing idolatry as adultery, 'thou hast discovered thyself to another than me,' frames unfaithfulness to God in the same terms as betrayal of a marriage."),
         ("Healing the contrite", "God's promise to dwell 'with him also that is of a contrite and humble spirit' pairs his own high and lofty dwelling with deliberate nearness to the lowest and most broken.")],
    58: [("Empty fasting", "A fast where people 'afflict their soul' while still striking others 'with the fist of wickedness' exposes a religious practice that coexists comfortably with ongoing cruelty."),
         ("Practical justice", "The fast God chooses is defined almost entirely in physical, practical terms, undoing bonds, sharing bread, housing the homeless, rather than religious ritual alone."),
         ("Sabbath as delight", "Calling the Sabbath 'a delight' rather than a burden reframes a commanded rest as something to be genuinely enjoyed, not merely endured.")],
    59: [("Sin blocks fellowship", "Insisting that God's 'hand is not shortened' redirects blame away from any limit on God's power and onto sins that have actively come between the people and him."),
         ("Communal confession", "A shared confession that 'we roar all like bears' and grope for a wall like blind men admits collective failure honestly, without singling out one group to blame."),
         ("Divine intervention", "God 'saw that there was no man' to intervene and so acted himself, putting on righteousness and salvation like armor when no human effort proved sufficient.")],
    60: [("Light to nations", "Zion's light draws nations and kings 'to the brightness of thy rising,' picturing restoration as something so visible it attracts attention from far beyond Israel's own borders."),
         ("Return and rebuilding", "Children, wealth, and even cedar wood arriving from foreign nations combine Zion's people returning with the physical material needed to rebuild what was lost."),
         ("Everlasting peace", "God replacing the sun and moon as Zion's 'everlasting light' pictures a peace secure enough that it no longer depends on anything as changeable as daylight.")],
    61: [("Good news for the oppressed", "Being anointed specifically 'to preach good tidings unto the meek' and bind up the brokenhearted directs this speaker's mission toward people usually overlooked."),
         ("Rebuilding after ruin", "Promising that 'they shall build the old wastes' turns long-ruined places into a future project, not a permanent loss."),
         ("Joyful righteousness", "Comparing righteousness to a garment and a bride's jewels pictures moral renewal as something worn with visible joy, not simply followed as a rule.")],
    62: [("Persevering prayer", "The vow to 'not hold my peace' and to 'not rest' until Zion's vindication arrives models prayer as sustained, active persistence rather than a single request."),
         ("New identity", "Being renamed Hephzibah, 'my delight is in her,' instead of Forsaken replaces an old identity defined by rejection with one defined by being wanted."),
         ("Prepared homecoming", "Watchmen set on the walls specifically to 'give him no rest' until Jerusalem is established shows preparation for homecoming as an active, ongoing task, not passive waiting.")],
    63: [("Judgment against oppression", "A warrior whose garments are stained like someone treading a winepress alone pictures judgment against Edom as thorough and solitary, with no one else to share the work or the blame."),
         ("Remembering past mercy", "Recalling how God 'bare them, and carried them all the days of old' during the wilderness years grounds the present plea in a specific, remembered history of care."),
         ("Plea for renewed presence", "Asking 'where is he that put his holy Spirit within him?' turns memory of the exodus into a direct, pointed question about where that same presence has gone now.")],
    64: [("Longing for intervention", "Asking God to tear open the heavens and come down pictures intervention as something dramatic and visible, not a quiet, gradual change."),
         ("Confession and dependence", "Calling God 'our father' and themselves clay admits total dependence on him, even while confessing that their own righteousness is 'as filthy rags.'"),
         ("Lament for ruins", "Naming 'our holy and our beautiful house' as burned turns grief over the temple's destruction into the prayer's most specific, concrete loss.")],
    65: [("Judgment and distinction", "God's statement 'I am sought of them that asked not for me' answers the previous chapter's lament by insisting he was never the one who went missing."),
         ("New creation", "Promising 'new heavens and a new earth' where 'the former shall not be remembered' pictures renewal so complete that even painful memory itself fades."),
         ("Flourishing and peace", "Long life, lasting homes, and a wolf feeding 'with the lamb' combine human flourishing and peace among animals into one unified picture of restoration.")],
    66: [("True reverence", "God's preference for 'him that is poor and of a contrite spirit' over any temple, however impressive, redefines true reverence as humility rather than architecture."),
         ("Comfort and new birth", "Zion giving birth 'before her pain came' pictures restoration arriving with startling, almost impossible suddenness rather than slow recovery."),
         ("Universal gathering and judgment", "Nations gathered 'to see my glory' alongside a closing image of unending judgment holds the book's hope and warning together right up to its final verse.")],
}

SUMMARY_OVERRIDES = {
    1: ("Judah is portrayed as a rebellious child and a diseased body, while Jerusalem has become unjust (Isaiah 1:2–9). "
        "God rejects ceremonies separated from justice and invites the people to turn from evil (Isaiah 1:10–20). "
        "The chapter contrasts a corrupt, unfaithful city with a future, purified and faithful city (Isaiah 1:21–31)."),
    14: ("The passage promises relief for Jacob and taunts the fallen king of Babylon, describing royal arrogance brought down to Sheol "
         "(Isaiah 14:1–23). Further announcements concern Assyria and Philistia (Isaiah 14:24–32). The famous \"morning star\" imagery "
         "belongs immediately to this royal taunt, though later tradition has applied it to Satan (Isaiah 14:12)."),
    15: ("The oracle describes swift devastation across Moab, naming Ar, Kir, Dibon, Nebo, and other settlements (Isaiah 15:1–4). "
         "Priests and inhabitants mourn, flee, and carry their possessions away, and the prophet's own voice joins their anguish over "
         "the judgment (Isaiah 15:5–9)."),
    27: ("The Lord defeats Leviathan, the twisting sea monster, with his great and strong sword (Isaiah 27:1). He then tends a fruitful "
         "vineyard that reverses the failed vineyard of Isaiah 5 (Isaiah 27:2–6). After measured chastening and the removal of idols, "
         "Israel's scattered people are gathered to worship on Jerusalem's holy mountain (Isaiah 27:7–13)."),
    52: ("Zion is commanded to awake, put on beautiful garments, and leave captivity (Isaiah 52:1–12). A messenger announces good news "
         "and the Lord's return to Zion (Isaiah 52:7–10). The chapter closes by introducing a surprising servant who will be exalted "
         "only after shocking disfigurement, setting up the next chapter's suffering poem (Isaiah 52:13–15)."),
}

AUDIENCE_OVERRIDES = {
    6: "Jesus and Paul later quoted the commission given in this vision (Matthew 13:14–15; Acts 28:25–27), applying Isaiah's call to hardened hearing in their own day.",
    8: "Readers who knew Hebrew naming customs would recognize Mahershalalhashbaz's name itself as a walking prophecy, proclaiming ‘swift is the plunder, speedy is the prey’ every time it was spoken.",
    12: "Readers would recognize this as a psalm-like response meant for communal singing, similar in form to Israel's temple songs of thanksgiving.",
    14: "Readers familiar with royal funeral taunts in the ancient Near East would recognize the mocking tone toward a fallen king as a deliberate reversal of the honor such kings expected in death.",
    15: "Readers who knew Moab as a familiar neighboring kingdom across the Dead Sea, often at odds with Judah, would recognize each named town as a real place whose fall meant real devastation, not abstract poetry.",
    20: "Readers who saw Isaiah's three years of public, humiliating undress would recognize a living warning: this is exactly how Egypt and Cush's captives would be led away, stripped of dignity along with their clothes.",
    21: "Readers accustomed to Isaiah's oracles against foreign nations would recognize the watchman's urgent, breathless report as a distinct literary style within that series, built for dramatic tension rather than calm, factual reporting.",
    23: "Readers who depended on Phoenician trade networks for goods moving through the Mediterranean would feel the force of a coming collapse in commerce that reached far beyond Tyre's own borders.",
    24: "Readers who had just followed a sequence of oracles against individual nations (13–23) would recognize this sudden shift to the whole earth as a deliberate widening of scope, often called the ‘Isaiah Apocalypse’ by later readers.",
    26: "Readers already singing psalms of trust in difficult times would recognize this as another entry in that tradition, climaxing in one of the Old Testament's clearest hints that the dead will live again (26:19).",
    30: "Readers who knew Zoan and Hanes as real Egyptian cities, not just names, would recognize how far Judah's leaders had actually traveled to buy protection they could not really purchase.",
    32: "Readers accustomed to Isaiah pairing hope for good leadership with warnings to complacent citizens would recognize this chapter's two halves as another example of that same pattern.",
    35: "Readers who knew the hardship of desert travel would recognize the promise of blossoming wilderness and a safe, dedicated road as a vivid reversal of danger into welcome.",
    41: "Readers would recognize God addressing Israel with covenant language already familiar from Abraham's story, ‘the seed of Abraham my friend,’ reassuring a fearful people that their identity as God's chosen remains secure even amid political upheaval.",
    42: "Readers across centuries have debated whether this servant is Israel, the prophet himself, or a future individual; Matthew's Gospel later resolved that question for Christian readers by applying it directly to Jesus.",
    43: "Readers living through forced exile would hear ‘Fear not: for I have redeemed thee’ as a direct, personal reassurance that their scattering was not the end of the story God had written for them.",
    44: "Readers who later saw Cyrus's decree recorded in Ezra 1 would recognize this naming, generations in advance by tradition's reckoning, as a striking claim about God's control over history's rulers.",
    45: "Readers startled to hear a foreign king called God's anointed, a title elsewhere reserved for Israel's own kings, would recognize the passage's larger claim that the LORD's reach extends over rulers who do not even know him.",
    48: "Readers still settled in Babylon would hear this as a direct, practical command to act, not simply a future hope to anticipate passively.",
    50: "Readers following the servant's story across these chapters would recognize his submission to violence here as a turning point, preparing for the fuller description of his suffering in chapter 53.",
    61: "Readers in the synagogue at Nazareth, familiar with this passage's hope for release and restoration, would have been startled when Jesus applied its fulfillment to himself in their own hearing (Luke 4:21).",
    63: "Readers who remembered Edom's long hostility toward Israel would recognize the garments red not with dye but with the blood of judgment, a vivid image of a reckoning finally arriving.",
    65: "Later readers, including the author of Revelation, returned to this promise of new heavens and a new earth (Revelation 21:1) as the clearest Old Testament anticipation of a creation remade rather than merely repaired.",
}


def fix_story_pronouns(section):
    """Lowercase pronouns for God/Jesus outside quotes and outside the bold title spans
    (which the checker exempts as title-case headings)."""
    PRONOUN = re.compile(r"(?<=[a-z,;:—] )(His|Him|Himself)\b")
    bold_spans = []

    def protect(m):
        bold_spans.append(m.group(0))
        return f"\x00{len(bold_spans) - 1}\x00"

    protected = re.sub(r"\*\*[^*]+\*\*", protect, section)
    fixed = PRONOUN.sub(lambda m: m.group(0).lower(), protected)

    # Bare "He" and proper-noun-preceded "Himself" that the checker's regex cannot see,
    # but which refer to God or Jesus in the narrator's own prose (not inside quotations).
    manual = [
        ("blood. He tells them what He really wants", "blood. he tells them what he really wants"),
        ("the widow.” Then He makes an amazing offer", "the widow.” Then he makes an amazing offer"),
        ("down like a forest. And He promises that", "down like a forest. And he promises that"),
        ("the way he came. He will not shoot", "the way he came. he will not shoot"),
        ("to shepherd his people. He introduces a servant", "to shepherd his people. he introduces a servant"),
        ("how great God is. He has measured the oceans in the palm of his hand.",
         "how great God is. he has measured the oceans in the palm of his hand."),
        ("neither is weary?” He gives strength", "neither is weary?” he gives strength"),
        ("for I am thy God.” He challenges the", "for I am thy God.” he challenges the"),
        ("they cannot. Then He introduces his servant", "they cannot. Then he introduces his servant"),
        ("He exposes idols as powerless and names Cyrus", "he exposes idols as powerless and names Cyrus"),
        ("declaring that He alone is God and Savior", "declaring that he alone is God and Savior"),
        ("shall not overflow thee.” He will bring them home", "shall not overflow thee.” he will bring them home"),
        ("me from every direction. He tells them, “R", "me from every direction. he tells them, “R"),
        ("will do a new thing.” And He promises forgiveness", "will do a new thing.” And he promises forgiveness"),
        ("and create darkness.” He calls the whole world", "and create darkness.” he calls the whole world"),
        ("is the opposite. He has carried his people since birth",
         "is the opposite. he has carried his people since birth"),
        ("since birth, and He promises, “even to your old age",
         "since birth, and he promises, “even to your old age"),
        ("speaks to stubborn Israel. He told them what", "speaks to stubborn Israel. he told them what"),
        ("to their idols. He has tested them", "to their idols. he has tested them"),
        ("as a river.” Now He calls them to leave Babylon", "as a river.” Now he calls them to leave Babylon"),
        ("from the Chaldeans.” But He warns, “There is no peace",
         "from the Chaldeans.” But he warns, “There is no peace"),
        ("so He can surely comfort Zion", "so he can surely comfort Zion"),
        ("LORD.” God answers that He is the one who comforts them",
         "LORD.” God answers that he is the one who comforts them"),
        ("an enduring covenant. He invites the thirsty", "an enduring covenant. he invites the thirsty"),
        ("prayer for all peoples. He condemns selfish leaders",
         "prayer for all peoples. he condemns selfish leaders"),
        ("Jesus quoted this when He drove the money changers",
         "Jesus quoted this when he drove the money changers"),
        ("to revive the humble. He says, “Peace, peace", "to revive the humble. he says, “Peace, peace"),
        ("their workers. Then He describes the kind of fast",
         "their workers. Then he describes the kind of fast"),
        ("so He acts Himself. He puts on righteousness", "so he acts himself. he puts on righteousness"),
        ("like a helmet, and He comes to repay his enemies",
         "like a helmet, and he comes to repay his enemies"),
        ("The warrior answers that He has trampled the nations in his anger",
         "The warrior answers that he has trampled the nations in his anger"),
        ("This is the LORD Himself bringing judgment", "This is the LORD himself bringing judgment"),
        ("seek Him. He promises new heavens", "seek him. he promises new heavens"),
        ("answers Isaiah's prayer. He says He has been ready",
         "answers Isaiah's prayer. he says he has been ready"),
        ("Him will be judged. But He will not destroy everyone.",
         "him will be judged. But he will not destroy everyone."),
        ("tremble at His word. He promises Jerusalem's comfort",
         "tremble at his word. he promises Jerusalem's comfort"),
        ("No building can hold Him. What He looks for is a humble heart",
         "No building can hold him. What he looks for is a humble heart"),
        ("in a single day, and He will comfort His people",
         "in a single day, and he will comfort his people"),
        ("his mother comforteth.” Then He will come with fire",
         "his mother comforteth.” Then he will come with fire"),
        ("fire to judge the wicked. He will gather all nations",
         "fire to judge the wicked. he will gather all nations"),
        ("they will see His glory. He will send messengers",
         "they will see his glory. he will send messengers"),
        ("“as birds flying,” and Assyria will fall", "“as birds flying,” and Assyria will fall"),
        ("God Himself will defend Jerusalem", "God himself will defend Jerusalem"),
        ("the Lord Himself acts in righteousness", "the Lord himself acts in righteousness"),
    ]
    for find, replace in manual:
        if find in fixed:
            fixed = fixed.replace(find, replace, 1)

    def restore(m):
        return bold_spans[int(m.group(1))]

    return re.sub(r"\x00(\d+)\x00", restore, fixed)


def main():
    insights_path = ROOT / "chapter_insights/23_isaiah.json"
    context_path_1 = ROOT / "chapter_context/23_isaiah_1-33.json"
    context_path_2 = ROOT / "chapter_context/24_isaiah_34-66.json"
    story_path = ROOT / "book_content/05_major_prophets.md"

    insights = load(insights_path)
    context1 = load(context_path_1)
    context2 = load(context_path_2)

    for chapter in range(1, 67):
        key = f"Isaiah {chapter}"
        insights[key]["whereWeAre"] = PLACEMENT[chapter]
        insights[key]["keyThemes"] = [
            {"theme": name, "explanation": explanation, "references": old["references"]}
            for (name, explanation), old in zip(THEMES[chapter], insights[key]["keyThemes"])
        ]
        if chapter in SUMMARY_OVERRIDES:
            insights[key]["summary"] = SUMMARY_OVERRIDES[chapter]
        for figure in insights[key]["keyFigures"]:
            figure["role"] = dedupe_role(figure["role"])
            if "/" in figure["name"]:
                first, second = figure["name"].split("/", 1)
                figure["name"] = f"{first} ({second})"
        context = context1 if key in context1 else context2
        if chapter in AUDIENCE_OVERRIDES:
            context[key]["audience"] = AUDIENCE_OVERRIDES[chapter]

    # Remove the one remaining "debated" filler phrase left after deduplication.
    for figure in insights["Isaiah 41"]["keyFigures"]:
        if figure["name"] == "unnamed eastern victor":
            figure["role"] = "Figure often connected with Cyrus in the broader context, though unnamed in this chapter."

    # Fix the two single-quoted glosses that are not exact KJV wording.
    for entry in context1["Isaiah 27"]["culture"]:
        if entry["title"] == "Leviathan the serpent":
            entry["text"] = entry["text"].replace(
                "describe Baal defeating Lotan, ‘the twisting serpent’—nearly",
                "describe Baal defeating Lotan, meaning ‘the twisting serpent’—nearly",
            )
    for entry in context2["Isaiah 37"]["culture"]:
        if entry["title"] == "Sennacherib's annals":
            entry["text"] = entry["text"].replace(
                "boast of shutting Hezekiah up ‘like a bird in a cage,’",
                "boast of shutting Hezekiah up literally ‘like a bird in a cage,’",
            )

    save(insights_path, insights)
    save(context_path_1, context1)
    save(context_path_2, context2)

    story = story_path.read_text(encoding="utf-8")
    start = story.index("# Isaiah")
    end = story.index("# Jeremiah", start)
    section = story[start:end]
    fixed_section = fix_story_pronouns(section)
    story_path.write_text(story[:start] + fixed_section + story[end:], encoding="utf-8")


if __name__ == "__main__":
    main()
