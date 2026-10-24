#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Apply the completed editorial review for Revelation to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BOOK = "Revelation"


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


SUMMARY = {}
WWA = {}
KEY_FIGURES = {}
THEMES = {}
AUDIENCE = {}



SUMMARY.update({
    1: "John writes to the seven churches in Asia the Revelation of Jesus Christ, which God gave unto him, to shew unto his servants things which must shortly come to pass, and a blessing is promised to him that readeth and them that hear (Revelation 1:1–3). He sends grace and peace from him which is, and which was, and which is to come, from the seven Spirits before his throne, and from Jesus Christ, the faithful witness, the first begotten of the dead, who loved us and washed us from our sins in his own blood (Revelation 1:4–6). Christ cometh with clouds, and every eye shall see him, and the Lord says he is Alpha and Omega, the beginning and the ending (Revelation 1:7–8). John, a companion in tribulation, was in the isle that is called Patmos, and on the Lord's day he heard behind him a great voice as of a trumpet telling him to write what he saw and send it to the seven churches (Revelation 1:9–11). He turned and saw seven golden candlesticks and in the midst one like unto the Son of man, with eyes as a flame of fire, seven stars in his right hand, and a sharp twoedged sword out of his mouth (Revelation 1:12–16). John fell at his feet as dead, but Christ laid his right hand on him, told him not to fear, and said he is the first and the last, he that liveth, and was dead, and hath the keys of hell and of death (Revelation 1:17–18). The seven stars are the angels of the seven churches, and the seven candlesticks are the seven churches (Revelation 1:19–20).",
    2: "Christ, who holdeth the seven stars in his right hand and walketh in the midst of the seven golden candlesticks, tells the church at Ephesus he knows their works and labour and patience and that they tried them which say they are apostles and are not, but they have left their first love (Revelation 2:1–5). He praises their hatred of the deeds of the Nicolaitans and promises him that overcometh the tree of life (Revelation 2:6–7). To Smyrna he says he knows their tribulation and poverty, though they are rich, and tells them to fear none of those things, to be faithful unto death, and to receive a crown of life (Revelation 2:8–11). To Pergamos, which dwells where Satan's seat is, he says they hold fast his name and did not deny his faith even when Antipas, his faithful martyr, was slain, but some hold the doctrine of Balaam and of the Nicolaitans and must repent (Revelation 2:12–17). To Thyatira he praises their charity, service, faith, and patience, but rebukes them for suffering that woman Jezebel, which calleth herself a prophetess, to teach and seduce his servants (Revelation 2:18–23). He tells the rest to hold fast till he come and promises him that overcometh power over the nations and the morning star (Revelation 2:24–29).",
    3: "To the church in Sardis, Christ says it hath a name that it liveth but is dead, and tells it to be watchful and strengthen the things which remain, though a few names there have not defiled their garments and shall walk with him in white (Revelation 3:1–6). To Philadelphia he says he hath set before them an open door, for though they have a little strength, they have kept his word and not denied his name, and he will keep them from the hour of temptation and make him that overcometh a pillar in the temple of his God (Revelation 3:7–13). To Laodicea, which is neither cold nor hot, he says he will spue them out of his mouth, for they say they are rich and increased with goods and have need of nothing, and know not that they are wretched, and miserable, and poor, and blind, and naked (Revelation 3:14–17). He counsels them to buy of him gold tried in the fire, white raiment, and eyesalve, and says that as many as he loves he rebukes and chastens, so they should be zealous and repent (Revelation 3:18–19). He stands at the door and knocks, and promises that if any man open, he will come in and sup with him, and that him that overcometh shall sit with him in his throne (Revelation 3:20–22).",
    4: "After this John looked, and a door was opened in heaven, and the first voice, as of a trumpet, said Come up hither, and he was at once in the Spirit (Revelation 4:1–2). A throne was set in heaven, and one sat on it who was to look upon like a jasper and a sardine stone, with a rainbow round about the throne like unto an emerald (Revelation 4:2–3). Round about were four and twenty seats with four and twenty elders sitting, clothed in white raiment, with crowns of gold on their heads, while lightnings, thunderings, and voices proceeded out of the throne, and seven lamps of fire burned before it, which are the seven Spirits of God (Revelation 4:4–5). Before the throne was a sea of glass like unto crystal, and round about it four beasts full of eyes, like a lion, a calf, a man, and a flying eagle, each with six wings (Revelation 4:6–8). They rest not day and night, saying Holy, holy, holy, Lord God Almighty, which was, and is, and is to come (Revelation 4:8). When they give glory to him that sat on the throne, the elders fall down, cast their crowns before it, and say that he is worthy to receive glory and honour and power, for he hath created all things (Revelation 4:9–11).",
    5: "John saw in the right hand of him that sat on the throne a book written within and on the backside, sealed with seven seals, and a strong angel asked who was worthy to open it (Revelation 5:1–2). No man in heaven, nor in earth, neither under the earth was able to open the book or to look thereon, and John wept much (Revelation 5:3–4). One of the elders told him not to weep, for the Lion of the tribe of Juda, the Root of David, hath prevailed to open the book (Revelation 5:5). In the midst of the throne stood a Lamb as it had been slain, having seven horns and seven eyes, and he came and took the book out of the right hand of him that sat upon the throne (Revelation 5:6–7). The four beasts and four and twenty elders fell down before the Lamb with harps and golden vials full of odours, which are the prayers of saints, and sang a new song that he was worthy, for he was slain and redeemed us to God by his blood out of every kindred, and tongue, and people, and nation, and made us unto our God kings and priests (Revelation 5:8–10). Many angels, ten thousand times ten thousand, said with a loud voice that the Lamb is worthy, and every creature in heaven, on the earth, under the earth, and in the sea gave blessing, honour, glory, and power unto him that sitteth upon the throne and unto the Lamb for ever and ever (Revelation 5:11–14).",
})

WWA.update({
    1: "Revelation closes the New Testament and the whole Bible. After Jude's call to contend for the faith, John writes from Patmos to seven churches in Asia, tells how the risen Christ appeared to him among the golden candlesticks, and is told to write what he has seen (1:1-20). Chapters 2 and 3 give Christ's letters to the seven churches.",
    2: "Chapter 1 ended with the seven candlesticks being the seven churches, with Christ walking among them (1:20). Chapter 2 gives his letters to four of them, Ephesus, Smyrna, Pergamos, and Thyatira, each with praise, a warning, and a promise to him that overcometh (2:1-29). Chapter 3 gives the letters to the other three.",
    3: "Chapter 2 ended with the promise of the morning star to him that overcometh in Thyatira (2:28). Chapter 3 gives the last three letters, to Sardis, Philadelphia, and Laodicea, and ends with Christ at the door and the promise of a seat with him in his throne (3:1-22). Chapter 4 opens a door in heaven.",
    4: "Chapter 3 ended with the risen Christ promising that the overcomer shall sit with him in his throne (3:21). Chapter 4 opens a door in heaven, where John sees God's throne and the elders and four beasts worshipping him as Creator (4:1-11). Chapter 5 brings in the sealed book and the Lamb.",
    5: "Chapter 4 ended with the elders casting their crowns before God, who created all things (4:10-11). Chapter 5 shows a sealed book in his hand that only the Lamb is worthy to open, and heaven and earth praise God and the Lamb together (5:1-14). Chapter 6 begins as the Lamb opens the seals.",
})

KEY_FIGURES.update({
    1: [
        ("John", "Writes to the seven churches, is in Patmos for the word of God, hears the voice, falls at Christ's feet, and is told to write (1:4,9-11,17-19)."),
        ("Jesus Christ", "The faithful witness, the first begotten of the dead, and he that liveth and was dead, who holds the stars and the keys of hell and of death (1:5,13-18)."),
        ("God the Almighty and the seven Spirits", "He which is, and which was, and which is to come, who says he is Alpha and Omega, with the seven Spirits before his throne (1:4,8)."),
        ("The seven churches", "The churches in Asia to whom the book is sent, shown as the seven candlesticks (1:4,11,20)."),
        ("The angels of the seven churches", "Shown as the seven stars that Christ holds in his right hand (1:16,20)."),
    ],
    2: [
        ("Jesus Christ", "Speaks to each church, saying he knows their works, and gives each a warning and a promise (2:1,8,12,18)."),
        ("The church at Ephesus", "Laboured, tried false apostles, and hated the deeds of the Nicolaitans, but left its first love (2:2-6)."),
        ("The church at Smyrna", "Poor in tribulation yet rich, told to be faithful unto death and not to fear (2:9-10)."),
        ("The church at Pergamos", "Holds fast Christ's name where Satan's seat is, where Antipas was slain, but some hold the doctrine of Balaam (2:13-15)."),
        ("The church at Thyatira", "Praised for charity, service, faith, and patience, but rebuked for suffering the woman Jezebel (2:19-20)."),
        ("Jezebel", "A woman who calleth herself a prophetess and teaches and seduces Christ's servants, though he gave her space to repent (2:20-21)."),
    ],
    3: [
        ("Jesus Christ", "Knows the works of each church and speaks as he that is holy, he that is true, and the Amen, the faithful and true witness (3:1,7,14)."),
        ("The church at Sardis", "Has a name that it liveth but is dead, and is told to be watchful and repent (3:1-3)."),
        ("The few in Sardis", "A few names which have not defiled their garments and shall walk with Christ in white (3:4)."),
        ("The church at Philadelphia", "Has a little strength, has kept Christ's word, and has an open door that no man can shut (3:8)."),
        ("The synagogue of Satan", "Those who say they are Jews and are not, who shall come and worship before the feet of the Philadelphians (3:9)."),
        ("The church at Laodicea", "Lukewarm, rich in its own eyes, and told to buy gold, raiment, and eyesalve from Christ (3:15-18)."),
    ],
    4: [
        ("John", "Is called up through the door, is in the Spirit, and sees the throne (4:1-2)."),
        ("God on the throne", "He that sat on the throne, to whom all the worship is given, who created all things (4:2-3,9-11)."),
        ("The four and twenty elders", "Sit on seats round about the throne in white raiment, fall down, and cast their crowns before it (4:4,10)."),
        ("The four beasts", "Full of eyes and with six wings, they say Holy, holy, holy day and night (4:6-8)."),
    ],
    5: [
        ("God on the throne", "Holds in his right hand the book sealed with seven seals (5:1,7)."),
        ("The Lamb", "Stands as it had been slain, prevails to open the book, takes it, and is worshipped (5:5-9)."),
        ("The strong angel", "Asks with a loud voice who is worthy to open the book (5:2)."),
        ("John", "Weeps much because no man was found worthy, and is comforted (5:4-5)."),
        ("One of the elders", "Tells John not to weep and says the Lion of the tribe of Juda hath prevailed (5:5)."),
        ("The beasts, the elders, and the angels", "Fall down before the Lamb with harps and vials of odours and sing a new song (5:8-12)."),
    ],
})

THEMES.update({
    1: [
        "Christ is the faithful witness, the first begotten of the dead, and the prince of the kings of the earth, the first and the last, who hath the keys of hell and of death (1:5,17-18).",
        "The glorified Christ walks in the midst of the seven candlesticks and holds the seven stars in his right hand, so he is near to his churches (1:12-13,16,20).",
        "A blessing is given to him that readeth and them that hear the words of this prophecy and keep what is written, for the time is at hand (1:3).",
        "Christ loved us, washed us from our sins in his own blood, and made us kings and priests unto God (1:5-6).",
        "John calls himself a companion in tribulation, and in the kingdom and patience of Jesus Christ, and he is in Patmos for the word of God (1:9).",
    ],
    2: [
        "Each letter says I know thy works, and Christ speaks as the one who searcheth the reins and hearts (2:2,9,13,19,23).",
        "Ephesus laboured and hated false teaching but left its first love, while Thyatira had charity and service yet suffered Jezebel (2:2-5,19-20).",
        "Smyrna had tribulation and poverty yet was rich, and it is told to be faithful unto death and receive a crown of life (2:8-10).",
        "Pergamos and Thyatira are warned about the doctrine of Balaam, the Nicolaitans, and Jezebel, who led people to eat things sacrificed unto idols and commit fornication (2:14-16,20-23).",
        "Each letter promises him that overcometh a reward: the tree of life, escape from the second death, hidden manna and a white stone, and power over the nations (2:7,11,17,26-28).",
    ],
    3: [
        "Sardis has a name that it liveth but is dead, and Laodicea says it is rich and increased with goods but is wretched, and miserable, and poor, and blind, and naked (3:1,17).",
        "Sardis is told to be watchful and strengthen the things which remain, and Laodicea to be zealous and repent (3:2-3,19).",
        "Philadelphia has a little strength yet has kept his word and not denied his name, and is told to hold fast that which it hath (3:8-11).",
        "Christ says \"As many as I love, I rebuke and chasten,\" and then stands at the door and knocks, ready to sup with whoever opens (3:19-20).",
        "The promises include white raiment, a name that is not blotted out of the book of life, a pillar in the temple of God, and a seat with Christ in his throne (3:5,12,21).",
    ],
    4: [
        "A throne was set in heaven, and one sat on it, and all the worship in the chapter is given to him that sitteth on the throne (4:2-3,9-11).",
        "The four beasts rest not day and night, saying \"Holy, holy, holy, Lord God Almighty\" (4:8).",
        "The elders say that God created all things, and for his pleasure they are and were created (4:11).",
        "The four and twenty elders fall down and cast their crowns before the throne, giving up their own honour to him (4:10).",
        "God is called Lord God Almighty, which was, and is, and is to come, and he liveth for ever and ever (4:8-10).",
    ],
    5: [
        "No man in heaven, in earth, or under the earth was able to open the book, but the Lamb prevailed to open it (5:2-5).",
        "John was told of a Lion but saw a Lamb as it had been slain, so victory comes through his sacrifice (5:5-6,9).",
        "The Lamb redeemed us to God by his blood out of every kindred, and tongue, and people, and nation (5:9).",
        "He hath made us unto our God kings and priests, and we shall reign on the earth (5:10).",
        "Blessing, honour, glory, and power are given unto him that sitteth upon the throne and unto the Lamb for ever and ever (5:13).",
    ],
})

AUDIENCE.update({
    1: "Churches under pressure in Asia would have heard that the one who walks among them is alive, holds their leaders in his hand, and will be seen by every eye.",
    2: "Believers in four cities, some tempted to compromise and some facing death, would have heard Christ say he knew their works and offer the crown of life to them that overcome.",
    3: "Believers in a church that seemed dead, a small faithful one, and a rich self-satisfied one would each have heard what Christ knew of them and a promise to him that overcometh.",
    4: "Believers who were pressed to call the emperor lord would have heard that the one worthy of glory, honour, and power sits on a throne in heaven and made all things.",
    5: "Troubled readers wondering who could set the world right would have heard that the Lamb that was slain is worthy and that people from every nation are redeemed.",
})

SUMMARY.update({
    6: "The Lamb opened one of the seals, and one of the four beasts said Come and see, and a white horse went forth conquering, and to conquer, with a rider who had a bow and a crown (Revelation 6:1–2). At the second seal a red horse took peace from the earth with a great sword, and at the third a black horse came with a pair of balances, and a voice said a measure of wheat for a penny and three measures of barley for a penny, and hurt not the oil and the wine (Revelation 6:3–6). At the fourth seal a pale horse came, and his name that sat on him was Death, and Hell followed with him, with power over the fourth part of the earth to kill with sword, and with hunger, and with death, and with the beasts of the earth (Revelation 6:7–8). At the fifth seal John saw under the altar the souls of them that were slain for the word of God, who cried How long, O Lord, and white robes were given them and they were told to rest yet a little season (Revelation 6:9–11). At the sixth seal there was a great earthquake, the sun became black as sackcloth of hair, the moon became as blood, and the stars of heaven fell (Revelation 6:12–14). The kings, the great men, the rich men, and every bondman and free man hid in the dens and rocks and said Fall on us, and hide us from the face of him that sitteth on the throne, and from the wrath of the Lamb, for who shall be able to stand (Revelation 6:15–17).",
    7: "After these things John saw four angels standing on the four corners of the earth, holding the four winds that the wind should not blow on the earth, nor on the sea, nor on any tree (Revelation 7:1). Another angel, having the seal of the living God, cried that they should hurt not the earth, nor the sea, nor the trees, till the servants of our God were sealed in their foreheads (Revelation 7:2–3). John heard that the number sealed was an hundred and forty and four thousand of all the tribes of the children of Israel, twelve thousand from each tribe named (Revelation 7:4–8). After this he beheld a great multitude, which no man could number, of all nations, and kindreds, and people, and tongues, standing before the throne and before the Lamb in white robes with palms in their hands, crying that salvation is to our God and to the Lamb (Revelation 7:9–10). All the angels, the elders, and the four beasts fell on their faces and worshipped God (Revelation 7:11–12). One of the elders told John that these are they which came out of great tribulation and have washed their robes and made them white in the blood of the Lamb (Revelation 7:13–14). They serve God day and night in his temple, they shall hunger no more, the Lamb shall feed them, and God shall wipe away all tears from their eyes (Revelation 7:15–17).",
    8: "When the Lamb opened the seventh seal, there was silence in heaven about the space of half an hour, and seven angels which stood before God were given seven trumpets (Revelation 8:1–2). Another angel with a golden censer was given much incense to offer with the prayers of all saints upon the golden altar, and the smoke ascended up before God, and the angel filled the censer with fire and cast it into the earth, and there were voices, thunderings, lightnings, and an earthquake (Revelation 8:3–5). The first angel sounded, and hail and fire mingled with blood were cast upon the earth, and the third part of trees was burnt up (Revelation 8:6–7). At the second trumpet a great mountain burning with fire was cast into the sea, and the third part of the sea became blood and the third part of the ships were destroyed (Revelation 8:8–9). At the third a great star called Wormwood fell upon the third part of the rivers, and many men died of the waters because they were made bitter (Revelation 8:10–11). At the fourth the third part of the sun, moon, and stars was smitten, and an angel flying through the midst of heaven cried Woe, woe, woe, to the inhabiters of the earth by reason of the other trumpets which are yet to sound (Revelation 8:12–13).",
    9: "At the fifth trumpet John saw a star fall from heaven unto the earth, and to him was given the key of the bottomless pit, which he opened, and smoke arose as the smoke of a great furnace and darkened the sun (Revelation 9:1–2). Locusts came out of the smoke with power as the scorpions of the earth have power, and they were commanded not to hurt the grass or any tree, but only those men which have not the seal of God in their foreheads, and they tormented them five months, but they should not kill them (Revelation 9:3–6). The locusts were like horses prepared unto battle, with crowns like gold, faces as the faces of men, hair as the hair of women, teeth as of lions, and tails like unto scorpions (Revelation 9:7–10). Their king is the angel of the bottomless pit, whose name in Hebrew is Abaddon and in Greek Apollyon, and one woe is past (Revelation 9:11–12). At the sixth trumpet a voice from the four horns of the golden altar told the sixth angel to loose the four angels bound in the great river Euphrates, who were prepared for an hour, and a day, and a month, and a year, to slay the third part of men (Revelation 9:13–15). The army of the horsemen was two hundred thousand thousand, and by fire, smoke, and brimstone the third part of men was killed (Revelation 9:16–19). The rest of the men repented not of the works of their hands, nor of worshipping devils and idols, nor of their murders, sorceries, fornication, or thefts (Revelation 9:20–21).",
    10: "John saw another mighty angel come down from heaven, clothed with a cloud, with a rainbow upon his head, his face as it were the sun, and his feet as pillars of fire, and in his hand a little book open (Revelation 10:1–2). He set his right foot upon the sea and his left upon the earth and cried with a loud voice as when a lion roareth, and seven thunders uttered their voices (Revelation 10:2–3). John was about to write, but a voice from heaven told him to seal up those things and write them not (Revelation 10:4). The angel lifted up his hand to heaven and sware by him that liveth for ever and ever, who created heaven, earth, and sea, that there should be time no longer, but that in the days of the seventh angel the mystery of God should be finished (Revelation 10:5–7). The voice told John to take the little book, and the angel told him to eat it up, for it would be sweet as honey in his mouth but make his belly bitter, and so it was (Revelation 10:8–10). John was told that he must prophesy again before many peoples, and nations, and tongues, and kings (Revelation 10:11).",
    11: "John was given a reed like unto a rod and told to measure the temple of God, and the altar, and them that worship therein, but to leave out the court without, for it is given unto the Gentiles, who shall tread the holy city under foot forty and two months (Revelation 11:1–2). God will give power unto his two witnesses to prophesy a thousand two hundred and threescore days, clothed in sackcloth, and they are the two olive trees and the two candlesticks standing before the God of the earth (Revelation 11:3–4). Fire proceedeth out of their mouth and devoureth their enemies, and they have power to shut heaven, to turn waters to blood, and to smite the earth with all plagues (Revelation 11:5–6). When they have finished their testimony, the beast that ascendeth out of the bottomless pit shall make war against them and kill them, and their dead bodies lie in the street of the great city, which spiritually is called Sodom and Egypt, where also our Lord was crucified (Revelation 11:7–8). Those that dwell upon the earth rejoice over them and send gifts one to another for three days and an half, and then the Spirit of life from God enters into them, they stand upon their feet, and they ascend up to heaven in a cloud (Revelation 11:9–12). The same hour a great earthquake falls the tenth part of the city, seven thousand are slain, and the remnant give glory to the God of heaven (Revelation 11:13–14). The seventh angel sounds, and great voices in heaven say that the kingdoms of this world are become the kingdoms of our Lord and of his Christ, who shall reign for ever and ever, and the elders worship God (Revelation 11:15–18). The temple of God is opened in heaven, and the ark of his testament is seen, with lightnings, voices, thunderings, an earthquake, and great hail (Revelation 11:19).",
})

WWA.update({
    6: "Chapter 5 ended with every creature praising God and the Lamb (5:13). Chapter 6 begins the opening of the seven seals: four horsemen, the cry of the slain under the altar, and the shaking of heaven and earth, ending with the question who shall be able to stand (6:1-17). Chapter 7 answers that question.",
    7: "Chapter 6 ended with the kings and great men asking who shall be able to stand before the wrath of the Lamb (6:17). Chapter 7 comes between the sixth and seventh seals and shows the servants of God sealed and a great multitude in white robes before the throne (7:1-17). Chapter 8 opens the seventh seal.",
    8: "Chapter 7 ended with God wiping away all tears from the eyes of the multitude (7:17). Chapter 8 opens the seventh seal, shows the prayers of the saints rising with incense, and tells of the first four trumpets, which strike a third part of the earth, sea, rivers, and heavenly lights (8:1-13). Chapter 9 sounds the fifth and sixth trumpets.",
    9: "Chapter 8 ended with the cry of three woes to the inhabiters of the earth (8:13). Chapter 9 brings the first woe, locusts from the bottomless pit, and the second, an army loosed from the river Euphrates, yet the rest of men repented not (9:1-21). Chapter 10 pauses before the seventh trumpet.",
    10: "Chapter 9 ended with men who still repented not of their idols and sins (9:20-21). Chapter 10 pauses between the sixth and seventh trumpets with a mighty angel, a little book, seven thunders, and John told to eat the book and prophesy again (10:1-11). Chapter 11 tells of the two witnesses and the seventh trumpet.",
    11: "Chapter 10 ended with John told to prophesy again before many peoples, nations, tongues, and kings (10:11). Chapter 11 tells of the measured temple, the two witnesses, and the seventh trumpet, when the kingdoms of this world become the kingdoms of our Lord and of his Christ (11:1-19). Chapter 12 turns to the woman and the dragon.",
})

KEY_FIGURES.update({
    6: [
        ("The Lamb", "Opens the seals one by one (6:1,3,5,7,9,12)."),
        ("The four beasts", "Each says Come and see as the first four seals are opened (6:1,3,5,7)."),
        ("The four riders", "Ride the white, red, black, and pale horses, bringing conquest, killing, famine, and Death with Hell following (6:2-8)."),
        ("The souls under the altar", "Slain for the word of God, they cry How long, O Lord, and are given white robes (6:9-11)."),
        ("The kings, great men, and every bondman and free man", "Hide in the dens and rocks from the face of him that sitteth on the throne and from the wrath of the Lamb (6:15-17)."),
    ],
    7: [
        ("The four angels", "Stand on the four corners of the earth, holding the four winds (7:1)."),
        ("The angel with the seal of the living God", "Ascends from the east and cries to the four angels to hurt not the earth until the servants are sealed (7:2-3)."),
        ("The sealed servants of God", "An hundred and forty and four thousand of the tribes of the children of Israel (7:4-8)."),
        ("The great multitude", "Of all nations, kindreds, people, and tongues, stand before the throne in white robes with palms and cry that salvation is to God and the Lamb (7:9-10)."),
        ("One of the elders", "Asks John who the multitude are and tells him they came out of great tribulation (7:13-14)."),
        ("God and the Lamb", "God dwells among the multitude and wipes away all tears, and the Lamb feeds them and leads them to living fountains (7:15-17)."),
    ],
    8: [
        ("The Lamb", "Opens the seventh seal (8:1)."),
        ("The seven angels with trumpets", "Stand before God and sound the trumpets in turn (8:2,6-12)."),
        ("The angel with the golden censer", "Offers incense with the prayers of all saints and casts fire into the earth (8:3-5)."),
        ("The saints", "Their prayers go up before God with the smoke of the incense (8:3-4)."),
        ("The angel flying through the midst of heaven", "Cries Woe, woe, woe, to the inhabiters of the earth (8:13)."),
        ("God", "Receives the prayers, and the seven angels stand before him (8:2-4)."),
    ],
    9: [
        ("The star fallen from heaven", "Is given the key of the bottomless pit and opens it (9:1-2)."),
        ("The locusts", "Given power as scorpions to torment for five months those who have not the seal of God (9:3-10)."),
        ("Abaddon, also called Apollyon", "The angel of the bottomless pit, king over the locusts (9:11)."),
        ("The sixth angel and the voice from the golden altar", "The voice tells the sixth angel to loose the four angels bound in the Euphrates (9:13-14)."),
        ("The four angels and the army of horsemen", "Loosed to slay the third part of men by fire, smoke, and brimstone (9:15-19)."),
        ("The rest of the men", "Repented not of their idols, murders, sorceries, fornication, or thefts (9:20-21)."),
    ],
    10: [
        ("The mighty angel", "Holds the little book open, sets his feet upon the sea and the earth, and swears an oath (10:1-6)."),
        ("The seven thunders", "Utter their voices, but John is told to seal up what they said (10:3-4)."),
        ("The voice from heaven", "Tells John to seal up the thunders and then to take the little book (10:4,8)."),
        ("God the Creator", "He that liveth for ever and ever, by whom the angel swears (10:6)."),
        ("John", "Takes the book, eats it, and is told to prophesy again (10:8-11)."),
    ],
    11: [
        ("John", "Is given a reed and told to measure the temple, the altar, and them that worship (11:1)."),
        ("The two witnesses", "Prophesy clothed in sackcloth, are killed, rise, and ascend to heaven (11:3-12)."),
        ("The Gentiles", "Tread the holy city under foot forty and two months (11:2)."),
        ("The beast out of the bottomless pit", "Makes war against the witnesses and kills them (11:7)."),
        ("They that dwell upon the earth", "Rejoice over the dead witnesses and send gifts one to another (11:9-10)."),
        ("The Lord and his Christ, with the elders", "The kingdoms of this world become his, and the elders worship God (11:15-18)."),
    ],
})

THEMES.update({
    6: [
        "The seals are opened one by one by the Lamb, and power is given to each rider, so what follows is under his authority (6:1-8).",
        "The horsemen bring conquering, killing one another, hunger, and death, showing the cost of human violence and want (6:2-8).",
        "The souls under the altar cry How long, O Lord, holy and true, dost thou not judge and avenge our blood, and are told to rest yet for a little season (6:9-11).",
        "White robes were given unto every one of them that were slain for the word of God and for the testimony which they held (6:9-11).",
        "Kings and bondmen alike hide from the face of him that sitteth on the throne and from the wrath of the Lamb, for the great day of his wrath is come (6:12-17).",
    ],
    7: [
        "The four winds are held back until the servants of our God are sealed in their foreheads, so no harm comes until God's people are marked as his (7:1-8).",
        "The multitude cries Salvation to our God which sitteth upon the throne, and unto the Lamb, and the angels worship God with sevenfold praise (7:9-12).",
        "The great multitude is of all nations, and kindreds, and people, and tongues, so God's people are not limited to one nation (7:9).",
        "The multitude came out of great tribulation and washed their robes and made them white in the blood of the Lamb (7:13-14).",
        "God shall dwell among them, they shall hunger no more, the Lamb shall feed them, and God shall wipe away all tears from their eyes (7:15-17).",
    ],
    8: [
        "The angel offers much incense with the prayers of all saints, and the smoke ascends up before God (8:3-4).",
        "Each trumpet strikes only the third part, which shows a judgment with limits, given as a warning (8:7-12).",
        "Hail and fire, water turned to blood, and darkness recall the plagues of Egypt (8:7-12).",
        "Trees, sea, rivers, and the sun, moon, and stars are all struck, so creation suffers when men turn from God (8:7-12).",
        "An angel flying through the midst of heaven cries Woe, woe, woe, to the inhabiters of the earth, and the worst trumpets are still to come (8:13).",
    ],
    9: [
        "The locusts are given power only for five months and are commanded not to hurt the grass or trees, and the four angels are prepared for an exact hour, and a day, and a month, and a year (9:4-5,15).",
        "The locusts may hurt only those men which have not the seal of God in their foreheads (9:4).",
        "After the plagues the rest of the men repented not of the works of their hands (9:20-21).",
        "They did not stop worshipping devils and idols, and they repented not of their murders, sorceries, fornication, or thefts (9:20-21).",
        "The bottomless pit, the angel of the bottomless pit, and the bound angels show unseen powers behind the suffering (9:1-11,13-19).",
    ],
    10: [
        "The angel swears by him that liveth for ever and ever that there should be time no longer, and that the mystery of God should be finished (10:5-7).",
        "John must take the little book, eat it, and prophesy again, so the word of God must be taken in before it is given out (10:8-11).",
        "The book is sweet as honey in John's mouth but makes his belly bitter (10:9-10).",
        "John is told to seal up what the seven thunders uttered and write it not, so not everything he heard is to be written (10:4).",
        "John must prophesy again before many peoples, and nations, and tongues, and kings (10:11).",
    ],
    11: [
        "The two witnesses prophesy clothed in sackcloth, but the beast that ascendeth out of the bottomless pit makes war against them and kills them (11:3-7).",
        "After three days and an half the Spirit of life from God enters them, and they stand and ascend to heaven in a cloud while their enemies behold (11:9-12).",
        "The temple and altar are measured while the court is given to the Gentiles for forty and two months, and the witnesses prophesy a set number of days (11:1-3,6).",
        "The kingdoms of this world are become the kingdoms of our Lord, and of his Christ, and he shall reign for ever and ever (11:15-17).",
        "The elders speak of the time of the dead to be judged, of reward for the servants and saints, and of the destroying of them which destroy the earth (11:18).",
    ],
})

AUDIENCE.update({
    6: "Believers who knew war, hunger, and killing under the empire would have heard that the Lamb himself opens each seal and that their slain brothers are remembered and given white robes.",
    7: "Believers who feared they would not last through hard times would have heard that God marks his own and that people of every nation will one day worship him in white robes.",
    8: "Believers who prayed for justice would have heard that their prayers rise before God with incense and that the warnings sound only a third at a time.",
    9: "Readers who knew the fear of invading armies and locust swarms would have heard that these powers are held within limits and cannot touch those sealed by God.",
    10: "Readers who knew the prophets would have recognized John's eating of the book as his call to speak God's word again to many peoples and kings.",
    11: "Believers who might be killed for their witness would have heard that God's witnesses are raised and that the kingdoms of the world become his.",
})

SUMMARY.update({
    12: "There appeared a great wonder in heaven, a woman clothed with the sun, with the moon under her feet and upon her head a crown of twelve stars, who being with child cried, travailing in birth (Revelation 12:1–2). Another wonder appeared, a great red dragon having seven heads and ten horns and seven crowns, whose tail drew the third part of the stars of heaven, and he stood before the woman ready to devour her child as soon as it was born (Revelation 12:3–4). She brought forth a man child, who was to rule all nations with a rod of iron, and her child was caught up unto God, and the woman fled into the wilderness where she hath a place prepared of God for a thousand two hundred and threescore days (Revelation 12:5–6). There was war in heaven, and Michael and his angels fought against the dragon and his angels, who prevailed not, and the great dragon was cast out, that old serpent, called the Devil, and Satan, which deceiveth the whole world (Revelation 12:7–9). A loud voice said that now is come salvation, and strength, and the kingdom of our God, for the accuser of our brethren is cast down, and they overcame him by the blood of the Lamb, and by the word of their testimony, and they loved not their lives unto the death (Revelation 12:10–11). Woe came to the inhabiters of the earth and of the sea, for the devil is come down having great wrath, because he knoweth that he hath but a short time (Revelation 12:12). The dragon persecuted the woman, who was given two wings of a great eagle to fly into the wilderness, and the earth helped her and swallowed up the flood which the serpent cast out of his mouth (Revelation 12:13–16). Then the dragon was wroth with the woman and went to make war with the remnant of her seed, which keep the commandments of God, and have the testimony of Jesus Christ (Revelation 12:17).",
    13: "John stood upon the sand of the sea and saw a beast rise up out of the sea, having seven heads and ten horns, with ten crowns upon his horns and the name of blasphemy upon his heads, like unto a leopard, with feet as of a bear and a mouth as the mouth of a lion, and the dragon gave him his power, and his seat, and great authority (Revelation 13:1–2). One of his heads was wounded to death and the deadly wound was healed, and all the world wondered after the beast and worshipped the dragon and the beast (Revelation 13:3–4). He was given a mouth speaking great things and blasphemies and power to continue forty and two months, and he blasphemed God and made war with the saints and overcame them (Revelation 13:5–7). All that dwell upon the earth shall worship him, whose names are not written in the book of life of the Lamb slain from the foundation of the world, and here is the patience and the faith of the saints (Revelation 13:8–10). Another beast came up out of the earth with two horns like a lamb, and he spake as a dragon, exercised all the power of the first beast, and made the earth worship the first beast (Revelation 13:11–12). He did great wonders, made fire come down from heaven, deceived them that dwell on the earth, told them to make an image to the beast, and gave life unto it, so that whoever would not worship the image should be killed (Revelation 13:13–15). He caused all, small and great, rich and poor, free and bond, to receive a mark in their right hand or in their foreheads, that no man might buy or sell save he that had the mark, or the name of the beast, or the number of his name (Revelation 13:16–17). Here is wisdom, for the number of the beast is the number of a man, and his number is Six hundred threescore and six (Revelation 13:18).",
    14: "John looked, and lo, a Lamb stood on the mount Sion, and with him an hundred forty and four thousand, having his Father's name written in their foreheads (Revelation 14:1). A voice from heaven as the voice of many waters was heard, with harpers harping, and they sung a new song before the throne which no man could learn but the hundred forty and four thousand, which were redeemed from the earth, the firstfruits unto God and to the Lamb, who follow the Lamb whithersoever he goeth (Revelation 14:2–5). Another angel flew in the midst of heaven having the everlasting gospel to preach to every nation, and kindred, and tongue, and people, saying Fear God, and give glory to him, for the hour of his judgment is come (Revelation 14:6–7). A second angel said Babylon is fallen, is fallen, that great city, and a third warned that if any man worship the beast and his image and receive his mark, he shall drink of the wine of the wrath of God and be tormented with fire and brimstone (Revelation 14:8–11). Here is the patience of the saints that keep the commandments of God and the faith of Jesus, and a voice from heaven said Blessed are the dead which die in the Lord from henceforth, that they may rest from their labours (Revelation 14:12–13). One like unto the Son of man sat on a white cloud with a golden crown on his head and a sharp sickle in his hand, and the earth was reaped (Revelation 14:14–16). Another angel with a sickle gathered the vine of the earth and cast it into the great winepress of the wrath of God, which was trodden without the city, and blood came out even unto the horse bridles by the space of a thousand and six hundred furlongs (Revelation 14:17–20).",
    15: "John saw another sign in heaven, great and marvellous, seven angels having the seven last plagues, for in them is filled up the wrath of God (Revelation 15:1). He saw a sea of glass mingled with fire, and them that had gotten the victory over the beast, and over his image, and over his mark, and over the number of his name, stand on it, having the harps of God (Revelation 15:2). They sing the song of Moses the servant of God and the song of the Lamb, saying that great and marvellous are his works, Lord God Almighty, and just and true are his ways, thou King of saints (Revelation 15:3). They ask who shall not fear the Lord and glorify his name, for he only is holy, and all nations shall come and worship before him, for his judgments are made manifest (Revelation 15:4). After that the temple of the tabernacle of the testimony in heaven was opened, and the seven angels came out clothed in pure and white linen, with their breasts girded with golden girdles (Revelation 15:5–6). One of the four beasts gave the seven angels seven golden vials full of the wrath of God, who liveth for ever and ever (Revelation 15:7). The temple was filled with smoke from the glory of God, and no man was able to enter into it till the seven plagues of the seven angels were fulfilled (Revelation 15:8).",
    16: "A great voice out of the temple told the seven angels to go their ways and pour out the vials of the wrath of God upon the earth (Revelation 16:1). The first poured his vial upon the earth, and a noisome and grievous sore fell upon the men which had the mark of the beast, and the second poured his upon the sea, which became as the blood of a dead man, and every living soul died in the sea (Revelation 16:2–3). The third poured his vial upon the rivers and fountains of waters, and they became blood, and the angel of the waters said the Lord is righteous, because they have shed the blood of saints and prophets, and another out of the altar said that his judgments are true and righteous (Revelation 16:4–7). The fourth poured his vial upon the sun and men were scorched with great heat, and the fifth upon the seat of the beast, whose kingdom was full of darkness, yet men blasphemed God and repented not of their deeds (Revelation 16:8–11). The sixth poured his vial upon the great river Euphrates, and the water was dried up that the way of the kings of the east might be prepared (Revelation 16:12). Three unclean spirits like frogs came out of the mouth of the dragon, the beast, and the false prophet, working miracles, to gather the kings of the whole world to the battle of that great day of God Almighty, and Christ says Behold, I come as a thief, blessed is he that watcheth, and he gathered them into a place called in Hebrew Armageddon (Revelation 16:13–16). The seventh poured his vial into the air, and a great voice from the throne said It is done, and there was a great earthquake, the great city was divided into three parts, and great Babylon came in remembrance before God (Revelation 16:17–19). Every island fled away, and a great hail about the weight of a talent fell upon men, who blasphemed God because of the plague (Revelation 16:20–21).",
    17: "One of the seven angels which had the seven vials told John to come and see the judgment of the great whore that sitteth upon many waters, with whom the kings of the earth have committed fornication (Revelation 17:1–2). He carried John away in the spirit into the wilderness, where he saw a woman sit upon a scarlet coloured beast full of names of blasphemy, having seven heads and ten horns (Revelation 17:3). The woman was arrayed in purple and scarlet, decked with gold and precious stones and pearls, with a golden cup full of abominations, and upon her forehead was a name written, Mystery, Babylon the great, the mother of harlots and abominations of the earth (Revelation 17:4–5). John saw the woman drunken with the blood of the saints and of the martyrs of Jesus, and he wondered with great admiration (Revelation 17:6). The angel explained that the beast was, and is not, and shall ascend out of the bottomless pit and go into perdition, and that the seven heads are seven mountains on which the woman sitteth and also seven kings (Revelation 17:7–11). The ten horns are ten kings which receive power as kings one hour with the beast, give their power unto the beast, and make war with the Lamb, but the Lamb shall overcome them, for he is Lord of lords, and King of kings (Revelation 17:12–14). The waters are peoples, and multitudes, and nations, and tongues, and the ten horns shall hate the whore, make her desolate and naked, and burn her with fire, for God hath put in their hearts to fulfil his will (Revelation 17:15–17). The woman is that great city, which reigneth over the kings of the earth (Revelation 17:18).",
})

WWA.update({
    12: "Chapter 11 ended with the temple of God opened in heaven and the ark of his testament seen (11:19). Chapter 12 turns to a woman clothed with the sun, her child, and the great red dragon, with war in heaven and the dragon cast down to the earth (12:1-17). Chapter 13 shows the two beasts the dragon uses.",
    13: "Chapter 12 ended with the dragon going to make war with the remnant of the woman's seed (12:17). Chapter 13 shows two beasts, one out of the sea and one out of the earth, who demand worship, make war on the saints, and mark all who would buy or sell (13:1-18). Chapter 14 shows the Lamb with his people on mount Sion.",
    14: "Chapter 13 ended with the number of the beast and the mark needed to buy or sell (13:16-18). Chapter 14 shows the Lamb on mount Sion with the hundred forty and four thousand, three angels with warnings, and the harvest and the winepress of God's wrath (14:1-20). Chapter 15 introduces the seven last plagues.",
    15: "Chapter 14 ended with the great winepress of the wrath of God (14:19-20). Chapter 15 shows the seven angels with the seven last plagues and those who won the victory over the beast singing the song of Moses and the song of the Lamb by a sea of glass (15:1-8). Chapter 16 pours out the seven vials.",
    16: "Chapter 15 ended with the temple filled with smoke and the seven angels holding vials full of God's wrath (15:7-8). Chapter 16 pours out the seven vials, gathers the kings at Armageddon, and ends with the great voice saying It is done and great Babylon remembered before God (16:1-21). Chapter 17 explains the great whore.",
    17: "Chapter 16 ended with great Babylon coming in remembrance before God (16:19). Chapter 17 shows an angel explaining the great whore on the scarlet beast, the seven heads and ten horns, and the Lamb who overcomes the kings (17:1-18). Chapter 18 tells of Babylon's fall.",
})

KEY_FIGURES.update({
    12: [
        ("The woman clothed with the sun", "Travails in birth, brings forth a man child, and flees into the wilderness to a place prepared of God (12:1-2,5-6,14)."),
        ("The man child", "Is to rule all nations with a rod of iron and is caught up unto God and his throne (12:5)."),
        ("The great red dragon, that old serpent, the Devil, and Satan", "Seeks to devour the child, is cast out of heaven, and persecutes the woman and makes war with her seed (12:3-4,9,13,17)."),
        ("Michael and his angels", "Fight against the dragon and his angels in heaven (12:7)."),
        ("The brethren who overcame", "Overcame him by the blood of the Lamb, by the word of their testimony, and by not loving their lives unto the death (12:10-11)."),
        ("The remnant of her seed", "Those who keep the commandments of God and have the testimony of Jesus Christ, against whom the dragon makes war (12:17)."),
    ],
    13: [
        ("The dragon", "Gives the beast his power, his seat, and great authority (13:2,4)."),
        ("The beast out of the sea", "Speaks blasphemies, makes war with the saints, and is worshipped by all that dwell upon the earth (13:1-8)."),
        ("The beast out of the earth", "Has two horns like a lamb but speaks as a dragon, does wonders, makes an image, and causes all to take the mark (13:11-17)."),
        ("The saints", "Overcome by the first beast, they are called to patience and faith (13:7,10)."),
        ("They that dwell upon the earth", "Worship the dragon and the beast, except those whose names are written in the book of life (13:3-4,8,12)."),
        ("The Lamb", "Slain from the foundation of the world, he keeps the book of life (13:8)."),
    ],
    14: [
        ("The Lamb", "Stands on the mount Sion and is followed by the hundred forty and four thousand whithersoever he goeth (14:1,4)."),
        ("The hundred forty and four thousand", "Redeemed from the earth, they sing a new song and have his Father's name in their foreheads (14:1-5)."),
        ("The three angels", "Preach the everlasting gospel, announce Babylon's fall, and warn those who worship the beast (14:6-11)."),
        ("One like unto the Son of man", "Sits on a white cloud with a golden crown and a sharp sickle and reaps the earth (14:14-16)."),
        ("The angels of the harvest", "One out of the temple and one from the altar gather the vine of the earth and cast it into the winepress (14:17-19)."),
        ("Those who worship the beast", "Shall drink of the wine of the wrath of God and have no rest day nor night (14:9-11)."),
    ],
    15: [
        ("The seven angels with the seven last plagues", "Come out of the temple in white linen with golden girdles and receive the vials (15:1,6-7)."),
        ("Those who gained the victory over the beast", "Stand on the sea of glass with the harps of God and sing (15:2-3)."),
        ("God, the Lord God Almighty and King of saints", "Is praised for his just and true ways and holiness, and his wrath fills the vials (15:3-4,7)."),
        ("One of the four beasts", "Gives the seven angels seven golden vials (15:7)."),
        ("All nations", "Shall come and worship before him, for his judgments are made manifest (15:4)."),
    ],
    16: [
        ("The seven angels with the vials", "Pour out the vials of the wrath of God in turn (16:1-4,8,10,12,17)."),
        ("The men which had the mark of the beast", "Suffer sores, scorching heat, and darkness, yet blaspheme God and repent not (16:2,9-11,21)."),
        ("The angel of the waters and the voice from the altar", "Say the Lord is righteous and his judgments true (16:5-7)."),
        ("The dragon, the beast, and the false prophet", "Three unclean spirits like frogs come out of their mouths to gather the kings (16:13-14)."),
        ("The kings of the earth and of the east", "Gathered to the battle of that great day of God Almighty at Armageddon (16:12,14,16)."),
        ("Christ", "Says Behold, I come as a thief, and blesses him that watcheth (16:15)."),
    ],
    17: [
        ("The angel with the vials", "Shows John the judgment of the great whore and explains the mystery (17:1,7-18)."),
        ("John", "Is carried in the spirit into the wilderness and wonders with great admiration (17:3,6)."),
        ("The great whore, Babylon the great", "Sits upon many waters, is drunken with the blood of the saints, and is hated and burned by the ten horns (17:1-6,16)."),
        ("The scarlet coloured beast", "Carries the woman, has seven heads and ten horns, and goes into perdition (17:3,7-8,11)."),
        ("The ten kings", "Give their power unto the beast, make war with the Lamb, and turn on the whore (17:12-14,16)."),
        ("The Lamb and those with him", "Overcomes the kings, for he is Lord of lords and King of kings, and his people are called, and chosen, and faithful (17:14)."),
    ],
})

THEMES.update({
    12: [
        "The dragon, called that old serpent, the Devil, and Satan, tries to devour the child and makes war with the remnant of the woman's seed, so the suffering of God's people has a spiritual cause (12:3-9,13-17).",
        "The child is caught up unto God, the dragon is cast out, and a loud voice says Now is come salvation, and strength, and the kingdom of our God (12:5,9-10).",
        "They overcame him by the blood of the Lamb, and by the word of their testimony, and they loved not their lives unto the death (12:11).",
        "The woman has a place prepared of God, is given two wings of a great eagle, and is nourished, and the earth helps her (12:6,14-16).",
        "The devil has great wrath because he knoweth that he hath but a short time (12:12).",
    ],
    13: [
        "The beast has a deadly wound that is healed, receives power from the dragon, and is worshipped, which copies Christ's death and rising (13:3-4,11-15).",
        "All the world worships the dragon and the beast, and an image is made that must be worshipped on pain of death (13:4,8,12,15).",
        "Here is the patience and the faith of the saints, who are told that he that killeth with the sword must be killed with the sword (13:9-10).",
        "Power was given unto the beast to continue forty and two months, so his authority is allowed and limited (13:5-7).",
        "No man might buy or sell save he that had the mark, so faithfulness could cost a person his living (13:16-17).",
    ],
    14: [
        "The Lamb stands on mount Sion with those who have his Father's name in their foreheads and follow him whithersoever he goeth (14:1-5).",
        "An angel with the everlasting gospel calls every nation to fear God, give glory to him, and worship him that made heaven, and earth, and the sea (14:6-7).",
        "A second angel says Babylon is fallen, and a third warns that those who worship the beast and receive his mark shall drink of the wine of the wrath of God (14:8-11).",
        "Here is the patience of the saints, and the dead which die in the Lord rest from their labours, and their works do follow them (14:12-13).",
        "The harvest and the winepress picture the end, when the earth is reaped and the grapes are cast into the great winepress of the wrath of God (14:14-20).",
    ],
    15: [
        "The victors sing that God's ways are just and true, and that he only is holy (15:3-4).",
        "Those who had gotten the victory over the beast stand on the sea of glass with the harps of God and sing (15:2-4).",
        "The sea, the song of Moses, and the plagues recall how God delivered Israel from Egypt (15:2-3).",
        "All nations shall come and worship before him, for his judgments are made manifest (15:4).",
        "The temple is filled with smoke from the glory of God, and no man could enter till the seven plagues were fulfilled (15:5-8).",
    ],
    16: [
        "The angel of the waters says the Lord is righteous, and another from the altar says his judgments are true and righteous (16:5-7).",
        "Men blasphemed God and repented not of their deeds after the fourth, fifth, and seventh vials (16:9,11,21).",
        "Three unclean spirits like frogs, working miracles, gather the kings of the earth to the battle of that great day of God Almighty (16:13-16).",
        "Christ says Behold, I come as a thief, and blesses him that watcheth and keepeth his garments (16:15).",
        "A great voice from the throne says It is done, and great Babylon came in remembrance before God (16:17-19).",
    ],
    17: [
        "The great whore makes the kings of the earth drunk with the wine of her fornication, and she is decked with gold, precious stones, and pearls (17:1-5,18).",
        "The woman is drunken with the blood of the saints, and with the blood of the martyrs of Jesus (17:6).",
        "The ten horns hate the whore, make her desolate and naked, and burn her with fire, so evil turns on itself (17:16-17).",
        "The ten kings make war with the Lamb, and the Lamb shall overcome them, for he is Lord of lords, and King of kings (17:14).",
        "God hath put in their hearts to fulfil his will, until the words of God shall be fulfilled (17:17).",
    ],
})

AUDIENCE.update({
    12: "Believers who felt hunted for their faith would have heard that a great enemy was already cast down and that God had made a safe place for his people.",
    13: "Believers in cities that honored the emperor as a god would have heard how the dragon's two beasts demand worship and what it could cost to refuse.",
    14: "Faithful believers weary of persecution would have heard that the Lamb stands with his people and that the dead who die in the Lord rest from their labours.",
    15: "Believers who knew the story of Moses at the sea would have heard that the victors over the beast sing his song and that God's ways are just and true.",
    16: "Readers watching evil grow bolder would have heard that God's wrath is poured out in fair judgment and that they should watch and keep their garments.",
    17: "Believers living under a city that ruled the kings of the earth would have heard an angel explain that her power was shown for what it was and would not last.",
})

SUMMARY.update({
    18: "Another angel came down from heaven having great power, and the earth was lightened with his glory, and he cried that Babylon the great is fallen, is fallen, and is become the habitation of devils, for all nations have drunk of the wine of the wrath of her fornication and the merchants of the earth are waxed rich through the abundance of her delicacies (Revelation 18:1–3). Another voice from heaven said Come out of her, my people, that ye be not partakers of her sins, for her sins have reached unto heaven and God hath remembered her iniquities (Revelation 18:4–5). She saith in her heart I sit a queen, and am no widow, and shall see no sorrow, therefore her plagues shall come in one day, death, and mourning, and famine, and she shall be utterly burned with fire (Revelation 18:6–8). The kings of the earth shall bewail her, standing afar off, saying Alas, alas, that great city Babylon, for in one hour is thy judgment come (Revelation 18:9–10). The merchants of the earth shall weep and mourn, for no man buyeth their merchandise any more, which includes gold, silver, pearls, fine linen, purple, silk, ivory, cinnamon, wine, wheat, horses, chariots, and slaves, and souls of men (Revelation 18:11–17). Every shipmaster and sailor cried and cast dust on their heads, for in one hour she is made desolate (Revelation 18:17–19). Heaven and the holy apostles and prophets are told to rejoice, for God hath avenged them on her (Revelation 18:20). A mighty angel took up a stone like a great millstone and cast it into the sea, saying Thus with violence shall that great city Babylon be thrown down, and shall be found no more at all (Revelation 18:21–23). In her was found the blood of prophets, and of saints, and of all that were slain upon the earth (Revelation 18:24).",
    19: "John heard a great voice of much people in heaven saying Alleluia, salvation, and glory, and honour, and power, unto the Lord our God, for true and righteous are his judgments, for he hath judged the great whore and avenged the blood of his servants (Revelation 19:1–3). The four and twenty elders and the four beasts fell down and worshipped God that sat on the throne, saying Amen; Alleluia, and a voice from the throne said Praise our God, all ye his servants (Revelation 19:4–5). A great multitude said Alleluia, for the Lord God omnipotent reigneth, and the marriage of the Lamb is come, and his wife hath made herself ready, arrayed in fine linen, which is the righteousness of saints (Revelation 19:6–8). The angel told John to write Blessed are they which are called unto the marriage supper of the Lamb, and when John fell at his feet to worship him, he said See thou do it not, I am thy fellowservant, worship God (Revelation 19:9–10). Heaven opened, and John saw a white horse, and he that sat upon it was called Faithful and True, with eyes as a flame of fire, on his head many crowns, clothed with a vesture dipped in blood, and his name is called The Word of God (Revelation 19:11–13). The armies in heaven followed him upon white horses, out of his mouth goeth a sharp sword that he should smite the nations, and on his vesture and thigh is a name written, King of kings, and Lord of lords (Revelation 19:14–16). An angel standing in the sun called all the fowls to the supper of the great God, and the beast and the kings of the earth and their armies gathered to make war against him that sat on the horse (Revelation 19:17–19). The beast was taken, and with him the false prophet, and both were cast alive into a lake of fire burning with brimstone, and the remnant were slain with the sword of him that sat upon the horse (Revelation 19:20–21).",
    20: "John saw an angel come down from heaven with the key of the bottomless pit and a great chain, who laid hold on the dragon, that old serpent, which is the Devil, and Satan, bound him a thousand years, cast him into the bottomless pit, and set a seal upon him that he should deceive the nations no more till the thousand years were fulfilled (Revelation 20:1–3). John saw thrones, and judgment was given unto them that sat on them, and the souls of them that were beheaded for the witness of Jesus and had not worshipped the beast lived and reigned with Christ a thousand years (Revelation 20:4). The rest of the dead lived not again until the thousand years were finished, and this is the first resurrection, and on him that hath part in it the second death hath no power, but they shall be priests of God and of Christ (Revelation 20:5–6). When the thousand years are expired, Satan shall be loosed to deceive the nations, Gog and Magog, and gather them to battle, and they compassed the camp of the saints and the beloved city, but fire came down from God out of heaven and devoured them (Revelation 20:7–9). The devil that deceived them was cast into the lake of fire and brimstone, where the beast and the false prophet are, and shall be tormented day and night for ever and ever (Revelation 20:10). John saw a great white throne, and him that sat on it, from whose face the earth and the heaven fled away, and the dead, small and great, stood before God (Revelation 20:11–12). The books were opened, and another book, which is the book of life, and the dead were judged out of those things which were written in the books, according to their works (Revelation 20:12–13). Death and hell were cast into the lake of fire, which is the second death, and whosoever was not found written in the book of life was cast into the lake of fire (Revelation 20:14–15).",
    21: "John saw a new heaven and a new earth, for the first heaven and the first earth were passed away, and there was no more sea (Revelation 21:1). He saw the holy city, new Jerusalem, coming down from God out of heaven, prepared as a bride adorned for her husband (Revelation 21:2). A great voice out of heaven said Behold, the tabernacle of God is with men, and he will dwell with them, and God shall wipe away all tears from their eyes, and there shall be no more death, neither sorrow, nor crying, neither any more pain (Revelation 21:3–4). He that sat upon the throne said Behold, I make all things new, and It is done, I am Alpha and Omega, the beginning and the end, and he promised the water of life freely to him that is athirst, and that he that overcometh shall inherit all things (Revelation 21:5–7). But the fearful, and unbelieving, and abominable, and murderers, and sorcerers, and idolaters, and all liars shall have their part in the lake which burneth with fire and brimstone, which is the second death (Revelation 21:8). One of the seven angels showed John the bride, the Lamb's wife, the holy Jerusalem, having the glory of God, with a wall great and high, twelve gates with the names of the twelve tribes, and twelve foundations with the names of the twelve apostles of the Lamb (Revelation 21:9–14). The angel measured the city with a golden reed, and it lieth foursquare, twelve thousand furlongs, the city of pure gold like clear glass, with twelve gates of twelve pearls and foundations garnished with all manner of precious stones (Revelation 21:15–21). John saw no temple therein, for the Lord God Almighty and the Lamb are the temple of it, and the city had no need of the sun, for the glory of God did lighten it, and the Lamb is the light thereof (Revelation 21:22–23). The nations of them which are saved shall walk in the light of it, its gates shall not be shut by day, and there shall in no wise enter into it any thing that defileth, but they which are written in the Lamb's book of life (Revelation 21:24–27).",
    22: "The angel showed John a pure river of water of life, clear as crystal, proceeding out of the throne of God and of the Lamb, and on either side of the river was the tree of life, which bare twelve manner of fruits, and the leaves were for the healing of the nations (Revelation 22:1–2). There shall be no more curse, the throne of God and of the Lamb shall be in it, his servants shall serve him, see his face, and have his name in their foreheads, and they shall reign for ever and ever (Revelation 22:3–5). The angel said these sayings are faithful and true, and Christ said Behold, I come quickly, blessed is he that keepeth the sayings of the prophecy of this book (Revelation 22:6–7). John fell down to worship before the feet of the angel, who said See thou do it not, I am thy fellowservant, worship God, and told him to seal not the sayings of the book, for the time is at hand (Revelation 22:8–10). Christ said I come quickly, and my reward is with me, to give every man according as his work shall be, I am Alpha and Omega, the first and the last (Revelation 22:11–13). Blessed are they that do his commandments, that they may have right to the tree of life and enter in through the gates into the city, for without are dogs, and sorcerers, and murderers, and idolaters, and whosoever loveth and maketh a lie (Revelation 22:14–15). Jesus sent his angel to testify these things in the churches, and he is the root and the offspring of David, and the bright and morning star (Revelation 22:16). The Spirit and the bride say Come, and let him that heareth say Come, and whosoever will, let him take the water of life freely (Revelation 22:17). Whoever adds to or takes away from the words of this book will have the plagues added or his part taken out of the book of life, and he which testifieth these things saith Surely I come quickly, and John answers Even so, come, Lord Jesus, with the grace of our Lord Jesus Christ with them all (Revelation 22:18–21).",
})

WWA.update({
    18: "Chapter 17 ended with the woman as that great city, which reigneth over the kings of the earth (17:18). Chapter 18 tells of the angel's cry that Babylon the great is fallen, the call to come out of her, and the mourning of the kings, merchants, and sailors, and ends with the millstone cast into the sea (18:1-24). Chapter 19 turns to heaven's praise.",
    19: "Chapter 18 ended with the blood of prophets and saints found in Babylon (18:24). Chapter 19 shows heaven praising God for his true and righteous judgments, announces the marriage supper of the Lamb, and tells of the rider Faithful and True who overcomes the beast and the false prophet (19:1-21). Chapter 20 tells of the dragon's end.",
    20: "Chapter 19 ended with the beast and the false prophet cast into the lake of fire (19:20). Chapter 20 tells of Satan bound a thousand years, the saints reigning with Christ, Satan's last rebellion, and the dead judged at the great white throne (20:1-15). Chapter 21 shows the new heaven and new earth.",
    21: "Chapter 20 ended with death and hell cast into the lake of fire (20:14-15). Chapter 21 shows a new heaven and a new earth and the holy city, new Jerusalem, where God dwells with men and wipes away all tears (21:1-27). Chapter 22 closes the book with the river of life and Christ's promise to come quickly.",
    22: "Chapter 21 ended with only those written in the Lamb's book of life entering the city (21:27). Chapter 22 gives the river and tree of life, Christ's promises to come quickly, the warning not to add to or take from the book, and the closing prayer Even so, come, Lord Jesus (22:1-21). This is the last chapter of the Bible.",
})

KEY_FIGURES.update({
    18: [
        ("The angel with great power", "Comes down from heaven, lightens the earth with his glory, and cries that Babylon is fallen (18:1-2)."),
        ("Another voice from heaven", "Tells God's people to come out of her that they be not partakers of her sins (18:4-8)."),
        ("Babylon the great", "Glorified herself and lived deliciously, saying I sit a queen, and is burned with fire (18:2-8)."),
        ("The kings of the earth", "Committed fornication with her and bewail her, standing afar off (18:9-10)."),
        ("The merchants, shipmasters, and sailors", "Waxed rich through her and weep and cast dust on their heads (18:11-19)."),
        ("The mighty angel", "Takes up a stone like a great millstone and casts it into the sea (18:21)."),
    ],
    19: [
        ("The great multitude in heaven", "Cry Alleluia, praise God for his true and righteous judgments, and announce the marriage of the Lamb (19:1-7)."),
        ("The four and twenty elders and the four beasts", "Fall down and worship God, saying Amen; Alleluia (19:4)."),
        ("The angel who speaks to John", "Says Blessed are they which are called unto the marriage supper, and tells John to worship God (19:9-10)."),
        ("John", "Falls at the angel's feet to worship him and is told to worship God (19:10)."),
        ("Faithful and True, with the armies of heaven", "The rider on the white horse, called The Word of God, who smites the nations, followed by the armies in heaven (19:11-16)."),
        ("The beast, the false prophet, and the kings", "Gather to make war against him that sat on the horse, and the beast and false prophet are cast into the lake of fire (19:19-21)."),
    ],
    20: [
        ("The angel with the key and the chain", "Lays hold on the dragon, binds him, casts him into the bottomless pit, and seals it (20:1-3)."),
        ("The dragon, that old serpent, the Devil, and Satan", "Is bound a thousand years, loosed a little season, and finally cast into the lake of fire (20:2-3,7-10)."),
        ("Those who reigned with Christ", "The souls of them that were beheaded for the witness of Jesus, who lived and reigned with him a thousand years (20:4-6)."),
        ("The nations, Gog and Magog", "Deceived by Satan, they compass the camp of the saints and are devoured by fire from heaven (20:8-9)."),
        ("Him that sat on the great white throne", "The one from whose face the earth and heaven fled away, before whom the dead stand (20:11-12)."),
        ("The dead, with death and hell", "Judged out of the books according to their works, as death and hell deliver up their dead and are cast into the lake of fire (20:12-14)."),
    ],
    21: [
        ("John", "Sees the new heaven, new earth, and holy city, and is told to write (21:1-2,5)."),
        ("God on the throne", "Dwells with men, wipes away all tears, makes all things new, and says It is done (21:3-6)."),
        ("The Lamb", "The husband of the bride, the temple of the city, and its light (21:9,22-23)."),
        ("One of the seven angels", "Shows John the bride and measures the city with a golden reed (21:9-17)."),
        ("The nations of them which are saved", "Walk in the light of the city, and the kings of the earth bring their glory into it (21:24-26)."),
        ("The fearful, unbelieving, and liars", "Shall have their part in the lake which burneth with fire and brimstone, the second death (21:8,27)."),
    ],
    22: [
        ("The angel", "Shows John the river of life and refuses his worship, saying he is a fellowservant (22:1,8-9)."),
        ("John", "Falls down to worship before the angel and answers Even so, come, Lord Jesus (22:8,20)."),
        ("God and the Lamb", "The river proceeds from their throne, and the servants serve them (22:1,3)."),
        ("The servants of God", "Serve him, see his face, bear his name in their foreheads, and reign for ever and ever (22:3-5)."),
        ("Jesus", "Says I come quickly, calls himself Alpha and Omega, and says he is the root and the offspring of David and the bright and morning star (22:7,12-13,16,20)."),
        ("The Spirit and the bride", "Say Come, and invite whosoever will to take the water of life freely (22:17)."),
    ],
})

THEMES.update({
    18: [
        "Babylon says I sit a queen, and shall see no sorrow, yet her ruin comes in one hour, which shows how proud and rich systems fall (18:2-3,7-19).",
        "God's people are told Come out of her, my people, that ye be not partakers of her sins, and that ye receive not of her plagues (18:4-5).",
        "The merchandise list ends with slaves, and souls of men, so her wealth was built on the lives of people (18:11-13).",
        "In her was found the blood of prophets, and of saints, and of all that were slain upon the earth, and God hath avenged them on her (18:20,24).",
        "The words in one hour come again and again, showing that her judgment is sudden and complete (18:8,10,17,19,21-23).",
    ],
    19: [
        "The multitude cries Alleluia because true and righteous are his judgments, for he hath judged the great whore and avenged the blood of his servants (19:1-4).",
        "The Lord God omnipotent reigneth, and heaven calls for gladness and honour to him (19:6-7).",
        "The marriage of the Lamb is come, and his wife is arrayed in fine linen, which is the righteousness of saints (19:7-9).",
        "The angel says See thou do it not, I am thy fellowservant, worship God (19:10).",
        "The rider called Faithful and True judges and makes war in righteousness and overcomes the beast and the false prophet (19:11-21).",
    ],
    20: [
        "Satan is bound, loosed for a little season, and then cast into the lake of fire, so his power is limited and ends (20:1-3,7-10).",
        "Those beheaded for the witness of Jesus live and reign with Christ, and the second death hath no power on them (20:4-6).",
        "The dead are judged out of the books according to their works (20:11-13).",
        "Whosoever was not found written in the book of life was cast into the lake of fire (20:12,15).",
        "Death and hell are cast into the lake of fire, which is the end of death (20:14).",
    ],
    21: [
        "The tabernacle of God is with men, and he will dwell with them, and they shall be his people (21:2-3,22-23).",
        "God shall wipe away all tears, and there shall be no more death, sorrow, crying, or pain, for the former things are passed away (21:4).",
        "He that sat upon the throne says Behold, I make all things new, and It is done (21:5-6).",
        "The holy city has a great wall, twelve gates, and twelve foundations, and nothing that defileth shall enter it (21:9-27).",
        "The water of life is offered freely to him that is athirst, while the fearful, unbelieving, and liars have their part in the lake of fire (21:6-8,27).",
    ],
    22: [
        "The river of the water of life and the tree of life return, and there shall be no more curse (22:1-3).",
        "God's servants shall serve him, see his face, and bear his name in their foreheads (22:3-5).",
        "Christ says three times, I come quickly, and blesses him that keepeth the sayings of this book (22:7,12,20).",
        "John again falls down to worship the angel and is told to worship God (22:8-9).",
        "The Spirit and the bride say Come, and whosoever will may take the water of life freely (22:17).",
    ],
})

AUDIENCE.update({
    18: "Believers who saw the empire's trade and wealth would have heard that the city's riches would end in one hour and that God would answer the blood of the saints.",
    19: "Believers mocked for their faith would have heard a shout of Alleluia and met the judge who comes on a white horse, the Word of God, whose name is King of kings.",
    20: "Believers who feared the dragon would have heard that he is bound, loosed, and finally cast into the lake of fire, and that the dead are judged before God.",
    21: "Weary believers who had lost loved ones and comfort would have heard that God will dwell with them, wipe away all tears, and make all things new.",
    22: "Believers hearing the book read aloud in worship would have heard Christ's promise to come quickly and the invitation to come and take the water of life freely.",
})



def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "66_revelation.json"
    data = load(path)
    for n in range(1, 23):
        entry = data[f"{BOOK} {n}"]
        entry["summary"] = SUMMARY[n]
        entry["whereWeAre"] = WWA[n]
        entry["keyFigures"] = [{"name": a, "role": b} for a, b in KEY_FIGURES[n]]
        if len(entry["keyThemes"]) != len(THEMES[n]):
            raise SystemExit(f"{BOOK} {n}: theme count mismatch")
        for theme, explanation in zip(entry["keyThemes"], THEMES[n]):
            theme["explanation"] = explanation
            refs = []
            for ref in theme["references"]:
                refs.extend(json.loads(ref) if ref.startswith("[") else [ref])
            theme["references"] = refs
        if len(entry["whereWeAre"]) > 600 or len(entry["keyFigures"]) > 6:
            raise SystemExit(f"{BOOK} {n}: WWA {len(entry['whereWeAre'])} chars or too many figures")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


CULTURE_FIXES = {
    4: [("Domitian liked to be addressed as ‘our Lord and God’ (Suetonius).",
         "Domitian liked to be called both lord and god (Suetonius).")],
    22: [("Paul wrote the Aramaic prayer Maranatha, ‘Our Lord, come’ (1 Corinthians 16:22).",
          "Paul wrote the Aramaic prayer Maranatha, which means Our Lord, come (1 Corinthians 16:22).")],
}


def apply_chapter_context():
    path = ROOT / "chapter_context" / "42_revelation.json"
    data = load(path)
    for n in range(1, 23):
        data[f"{BOOK} {n}"]["audience"] = AUDIENCE[n]
    for n, fixes in CULTURE_FIXES.items():
        for old, new in fixes:
            hits = 0
            for entry in data[f"{BOOK} {n}"]["culture"]:
                if old in entry["text"]:
                    entry["text"] = entry["text"].replace(old, new)
                    hits += 1
            applied = any(new in entry["text"] for entry in data[f"{BOOK} {n}"]["culture"])
            if hits != 1 and not (hits == 0 and applied):
                raise SystemExit(f"culture fix matched {hits} times: {old!r}")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_historical_moments():
    path = ROOT / "historical_moments" / "18_thessalonians_revelation.json"
    data = load(path)
    key = f"{BOOK} 1"
    old = "; some scholars prefer the late 60s."
    if old in data[key]:
        data[key] = data[key].replace(old, ".")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_book_overview():
    path = ROOT / "book_overviews" / "09_general_letters_revelation.json"
    data = load(path)
    book = data[BOOK]
    book["author"] = "John the apostle, according to long Christian tradition, who wrote on the island of Patmos (Revelation 1:1, 4, 9)."
    book["theme"] = book["theme"].replace("dwell with His people", "dwell with his people")
    for figure in book["keyFigures"]:
        figure["name"] = figure["name"].replace("'Jezebel'", "Jezebel")
        figure["description"] = figure["description"].replace("Pergamum", "Pergamos")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_FIXES = [
    ("protection of His servants", "protection of his servants"),
    ("ark of His covenant", "ark of his covenant"),
    ("among His people", "among his people"),
    ("lives with His people forever", "lives with his people forever"),
    ("He held seven stars in His right hand", "Jesus held seven stars in his right hand"),
    ("“one like unto the Son of man.” His hair", "“one like unto the Son of man.” his hair"),
    ("” His feet were like glowing bronze, and His voice was", "” his feet were like glowing bronze, and his voice was"),
    ("came out of His mouth, and His face shone", "came out of his mouth, and his face shone"),
    ("John fell at His feet as though dead. But Jesus laid His right hand", "John fell at his feet as though dead. But Jesus laid his right hand"),
    ("death.” He explains that the seven stars", "death.” Jesus explains that the seven stars"),
    ("fall down before Him and sing", "fall down before him and sing"),
    ("John sees the Lamb with His people", "John sees the Lamb with his people"),
    ("who have His name and His Father's name", "who have his name and his Father's name"),
    ("follow Him on white horses. From His mouth", "follow him on white horses. From his mouth"),
    ("gather to fight Him.", "gather to fight him."),
    ("will serve Him, “And", "will serve him, “And"),
    ("Jesus Himself speaks", "Jesus himself speaks"),
    ("but its meaning has been widely debated.", "but Christians have understood it in different ways."),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "09_general_letters_revelation.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("\n# Revelation") + 1
    section = text[start:]
    for old, new in STORY_FIXES:
        if section.count(old) == 0 and section.count(new) >= 1:
            continue
        if section.count(old) != 1:
            raise SystemExit(f"story fix matched {section.count(old)} times: {old!r}")
        section = section.replace(old, new)
    path.write_text(text[:start] + section, encoding="utf-8")
    print(f"Updated {path.relative_to(ROOT)}")


if __name__ == "__main__":
    apply_chapter_insights()
    apply_chapter_context()
    apply_historical_moments()
    apply_book_overview()
    apply_story_fixes()
