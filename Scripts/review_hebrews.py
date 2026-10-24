#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Apply the completed editorial review for Hebrews to source content only."""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BOOK = "Hebrews"


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


SUMMARY = {
    1: "God, who at sundry times and in divers manners spake in time past unto the fathers by the prophets, hath in these last days spoken unto us by his Son, whom he hath appointed heir of all things, by whom also he made the worlds (Hebrews 1:1–2). The Son is the brightness of God's glory and the express image of his person, upholding all things by the word of his power, who by himself purged our sins and sat down on the right hand of the Majesty on high (Hebrews 1:3). He was made so much better than the angels, as he hath by inheritance obtained a more excellent name (Hebrews 1:4). To the Son God says Thou art my Son, this day have I begotten thee, and let all the angels of God worship him (Hebrews 1:5–6). Of the angels he saith that they are spirits and ministers a flame of fire, but unto the Son he says Thy throne, O God, is for ever and ever (Hebrews 1:7–9). The Lord laid the foundation of the earth and remains the same, though the heavens shall perish, and he is told to sit on God's right hand until his enemies are made his footstool (Hebrews 1:10–13). The angels are all ministering spirits, sent forth to minister for them who shall be heirs of salvation (Hebrews 1:14).",
    2: "We ought to give the more earnest heed to the things we have heard, lest at any time we should let them slip (Hebrews 2:1). If the word spoken by angels was stedfast, and every transgression received a just recompence of reward, how shall we escape if we neglect so great salvation, which at the first began to be spoken by the Lord and was confirmed by them that heard him, God bearing witness with signs and wonders (Hebrews 2:2–4). The world to come was not put in subjection to angels, but one testified that man was made a little lower than the angels and crowned with glory and honour, and we see Jesus, made a little lower than the angels for the suffering of death, that he by the grace of God should taste death for every man (Hebrews 2:5–9). It became God to make the captain of their salvation perfect through sufferings, and he is not ashamed to call them brethren (Hebrews 2:10–13). Forasmuch as the children are partakers of flesh and blood, he also took part of the same, that through death he might destroy him that had the power of death, that is, the devil, and deliver them who through fear of death were all their lifetime subject to bondage (Hebrews 2:14–15). He took on him the seed of Abraham, and in all things it behoved him to be made like unto his brethren, that he might be a merciful and faithful high priest, and being tempted, he is able to succour them that are tempted (Hebrews 2:16–18).",
    3: "Holy brethren, partakers of the heavenly calling, are told to consider the Apostle and High Priest of our profession, Christ Jesus, who was faithful to him that appointed him, as also Moses in all his house (Hebrews 3:1–2). Jesus was counted worthy of more glory than Moses, inasmuch as he who hath builded the house hath more honour than the house, for Moses was faithful as a servant, but Christ as a son over his own house, whose house are we, if we hold fast the confidence and the rejoicing of the hope firm unto the end (Hebrews 3:3–6). As the Holy Ghost saith, To day if ye will hear his voice, harden not your hearts, as in the provocation, when your fathers tempted God and saw his works forty years, so that he sware in his wrath that they should not enter into his rest (Hebrews 3:7–11). The brethren are told to take heed lest there be in any of them an evil heart of unbelief, in departing from the living God, and to exhort one another daily, while it is called To day, lest any be hardened through the deceitfulness of sin (Hebrews 3:12–15). Those that provoked were they that came out of Egypt by Moses, whose carcases fell in the wilderness, and they could not enter in because of unbelief (Hebrews 3:16–19).",
    4: "Let us fear, lest a promise being left of entering into his rest, any of us should seem to come short of it, for unto us was the gospel preached as well as unto them, but the word preached did not profit them, not being mixed with faith (Hebrews 4:1–2). We which have believed do enter into rest, as God did rest the seventh day from all his works, and because they to whom it was first preached entered not in because of unbelief, he limited a certain day, saying in David, To day, after so long a time (Hebrews 4:3–7). If Jesus, that is Joshua, had given them rest, God would not afterward have spoken of another day, so there remaineth a rest to the people of God, and he that is entered into his rest hath ceased from his own works, as God did from his (Hebrews 4:8–10). Let us labour therefore to enter into that rest, lest any man fall after the same example of unbelief (Hebrews 4:11). The word of God is quick, and powerful, and sharper than any twoedged sword, and a discerner of the thoughts and intents of the heart, and all things are naked and opened unto the eyes of him with whom we have to do (Hebrews 4:12–13). We have a great high priest, that is passed into the heavens, Jesus the Son of God, who was touched with the feeling of our infirmities and was in all points tempted like as we are, yet without sin, so let us come boldly unto the throne of grace, that we may obtain mercy and find grace to help in time of need (Hebrews 4:14–16).",
    5: "Every high priest taken from among men is ordained for men in things pertaining to God, that he may offer both gifts and sacrifices for sins, and can have compassion on the ignorant and on them that are out of the way, for he himself also is compassed with infirmity and must offer for his own sins (Hebrews 5:1–3). No man taketh this honour unto himself, but he that is called of God, as was Aaron (Hebrews 5:4). So also Christ glorified not himself to be made an high priest, but God said unto him Thou art my Son, to day have I begotten thee, and Thou art a priest for ever after the order of Melchisedec (Hebrews 5:5–6). In the days of his flesh he offered up prayers and supplications with strong crying and tears unto him that was able to save him from death, and though he were a Son, yet learned he obedience by the things which he suffered, and being made perfect he became the author of eternal salvation unto all them that obey him (Hebrews 5:7–10). The writer has many things to say of Melchisedec, hard to be uttered, seeing the readers are dull of hearing, who ought to be teachers but have need of milk, and not of strong meat, which belongeth to them that are of full age, whose senses are exercised to discern both good and evil (Hebrews 5:11–14).",
    6: "Leaving the principles of the doctrine of Christ, the writer says let us go on unto perfection, not laying again the foundation of repentance from dead works, and of faith toward God, and this will we do, if God permit (Hebrews 6:1–3). It is impossible to renew again unto repentance those who were once enlightened, have tasted of the heavenly gift, were made partakers of the Holy Ghost, and have tasted the good word of God, if they shall fall away, seeing they crucify to themselves the Son of God afresh and put him to an open shame (Hebrews 6:4–6). The earth which drinketh in the rain and bringeth forth herbs receiveth blessing from God, but that which beareth thorns and briers is rejected and nigh unto cursing, whose end is to be burned (Hebrews 6:7–8). The writer is persuaded better things of the readers, for God is not unrighteous to forget their work and labour of love, in that they have ministered to the saints, and he desires them to shew the same diligence to the full assurance of hope unto the end, followers of them who through faith and patience inherit the promises (Hebrews 6:9–12). When God made promise to Abraham, because he could swear by no greater, he sware by himself, and by two immutable things, in which it is impossible for God to lie, we have a strong consolation, who have fled for refuge to lay hold upon the hope set before us (Hebrews 6:13–18). This hope we have as an anchor of the soul, both sure and stedfast, which entereth into that within the veil, whither the forerunner is for us entered, Jesus, made an high priest for ever after the order of Melchisedec (Hebrews 6:19–20).",
    7: "Melchisedec, king of Salem, priest of the most high God, met Abraham returning from the slaughter of the kings and blessed him, and Abraham gave him a tenth part of all (Hebrews 7:1–2). His name means King of righteousness and King of peace, and without father, without mother, without descent, he was made like unto the Son of God and abideth a priest continually (Hebrews 7:2–3). Abraham gave him the tenth of the spoils, and the less is blessed of the better, so that Levi also, who receiveth tithes, payed tithes in Abraham (Hebrews 7:4–10). If perfection were by the Levitical priesthood, what further need was there that another priest should rise after the order of Melchisedec, for the priesthood being changed, there is a change also of the law, and our Lord sprang out of Juda, of which tribe Moses spake nothing concerning priesthood (Hebrews 7:11–14). He is made a priest not after the law of a carnal commandment, but after the power of an endless life, for the law made nothing perfect, but the bringing in of a better hope, by the which we draw nigh unto God (Hebrews 7:15–19). Jesus was made a priest with an oath and is a surety of a better testament, and because he continueth ever, he hath an unchangeable priesthood, and is able to save to the uttermost them that come unto God by him, seeing he ever liveth to make intercession for them (Hebrews 7:20–25). Such an high priest became us, holy, harmless, undefiled, separate from sinners, who needeth not daily to offer sacrifice, for this he did once, when he offered up himself (Hebrews 7:26–28).",
    8: "The sum of what has been said is that we have such an high priest, who is set on the right hand of the throne of the Majesty in the heavens, a minister of the sanctuary and of the true tabernacle, which the Lord pitched, and not man (Hebrews 8:1–2). Every high priest is ordained to offer gifts and sacrifices, so this man must have somewhat to offer, and if he were on earth he should not be a priest, for there are priests that offer gifts according to the law, who serve unto the example and shadow of heavenly things, as Moses was admonished of God to make all things according to the pattern shewed him in the mount (Hebrews 8:3–5). Christ hath obtained a more excellent ministry, by how much he is the mediator of a better covenant, established upon better promises, for if the first had been faultless, no place should have been sought for the second (Hebrews 8:6–7). The Lord finds fault with them and says that he will make a new covenant with the house of Israel and the house of Judah, not according to the covenant made with their fathers when he led them out of the land of Egypt (Hebrews 8:8–9). He will put his laws into their mind and write them in their hearts, he will be to them a God, and they shall be to him a people, all shall know him, and he will be merciful to their unrighteousness and remember their sins no more (Hebrews 8:10–12). In that he saith A new covenant, he hath made the first old, and that which decayeth and waxeth old is ready to vanish away (Hebrews 8:13).",
    9: "The first covenant had ordinances of divine service and a worldly sanctuary, a tabernacle with the candlestick, the table, and the shewbread, and after the second veil the Holiest of all, which had the golden censer and the ark of the covenant, wherein were the golden pot that had manna, Aaron's rod that budded, and the tables of the covenant, with the cherubims of glory shadowing the mercyseat (Hebrews 9:1–5). The priests went always into the first tabernacle, but into the second the high priest alone once every year, not without blood, which he offered for himself and for the errors of the people, the Holy Ghost signifying that the way into the holiest of all was not yet made manifest, and the gifts and sacrifices could not make him that did the service perfect as pertaining to the conscience (Hebrews 9:6–10). But Christ being come an high priest of good things to come, by a greater and more perfect tabernacle not made with hands, entered in once into the holy place by his own blood, having obtained eternal redemption for us (Hebrews 9:11–12). If the blood of bulls and of goats sanctifieth to the purifying of the flesh, how much more shall the blood of Christ, who through the eternal Spirit offered himself without spot to God, purge the conscience from dead works to serve the living God (Hebrews 9:13–14). He is the mediator of the new testament, that they which are called might receive the promise of eternal inheritance, and where a testament is there must also be the death of the testator, so the first was not dedicated without blood, when Moses sprinkled the book and all the people, and without shedding of blood is no remission (Hebrews 9:15–22). The heavenly things need better sacrifices than these, for Christ is entered into heaven itself, now to appear in the presence of God for us, not that he should offer himself often, but once in the end of the world to put away sin by the sacrifice of himself (Hebrews 9:23–26). As it is appointed unto men once to die, but after this the judgment, so Christ was once offered to bear the sins of many, and unto them that look for him shall he appear the second time without sin unto salvation (Hebrews 9:27–28).",
    10: "The law having a shadow of good things to come can never with those sacrifices which they offered year by year make the comers thereunto perfect, for in those there is a remembrance again of sins every year, and it is not possible that the blood of bulls and of goats should take away sins (Hebrews 10:1–4). When Christ cometh into the world he saith Sacrifice and offering thou wouldest not, but a body hast thou prepared me, Lo, I come to do thy will, O God, and by that will we are sanctified through the offering of the body of Jesus Christ once for all (Hebrews 10:5–10). Every priest standeth daily offering the same sacrifices, but this man, after he had offered one sacrifice for sins for ever, sat down on the right hand of God, expecting till his enemies be made his footstool, and by one offering he hath perfected for ever them that are sanctified (Hebrews 10:11–14). The Holy Ghost is a witness that God will put his laws into their hearts and remember their sins and iniquities no more, and where remission of these is, there is no more offering for sin (Hebrews 10:15–18). Having boldness to enter into the holiest by the blood of Jesus, by a new and living way through the veil, that is, his flesh, and an high priest over the house of God, let us draw near with a true heart in full assurance of faith, hold fast the profession of faith without wavering, provoke one another unto love and good works, and not forsake the assembling of ourselves together (Hebrews 10:19–25). If we sin wilfully after we have received the knowledge of the truth, there remaineth no more sacrifice for sins, but a fearful looking for of judgment, and it is a fearful thing to fall into the hands of the living God (Hebrews 10:26–31). The writer calls the readers to remember the former days, when they endured a great fight of afflictions, were made a gazingstock, and took joyfully the spoiling of their goods, and tells them to cast not away their confidence, for the just shall live by faith, and we are not of them who draw back unto perdition, but of them that believe to the saving of the soul (Hebrews 10:32–39).",
    11: "Faith is the substance of things hoped for, the evidence of things not seen, and by it the elders obtained a good report, and through faith we understand that the worlds were framed by the word of God (Hebrews 11:1–3). By faith Abel offered a more excellent sacrifice than Cain, and Enoch was translated that he should not see death, for without faith it is impossible to please God, for he that cometh to God must believe that he is, and that he is a rewarder of them that diligently seek him (Hebrews 11:4–6). By faith Noah, warned of things not seen as yet, prepared an ark to the saving of his house (Hebrews 11:7). By faith Abraham obeyed and went out, not knowing whither he went, sojourned in the land of promise dwelling in tabernacles, and looked for a city which hath foundations, whose builder and maker is God, and Sara received strength to conceive seed because she judged him faithful who had promised (Hebrews 11:8–12). These all died in faith, not having received the promises, but confessed that they were strangers and pilgrims on the earth and desired a better country, that is, an heavenly, wherefore God is not ashamed to be called their God, for he hath prepared for them a city (Hebrews 11:13–16). By faith Abraham offered up Isaac, accounting that God was able to raise him up even from the dead, and Isaac, Jacob, and Joseph each by faith spoke of things to come (Hebrews 11:17–22). By faith Moses was hid three months by his parents, refused to be called the son of Pharaoh's daughter, chose rather to suffer affliction with the people of God, forsook Egypt, and kept the passover, and they passed through the Red sea (Hebrews 11:23–29). By faith the walls of Jericho fell down, and the harlot Rahab perished not with them that believed not (Hebrews 11:30–31). The time would fail to tell of Gedeon, Barak, Samson, Jephthae, David, Samuel, and the prophets, who through faith subdued kingdoms, stopped the mouths of lions, and quenched the violence of fire, while others were tortured, had trial of mockings and scourgings, were stoned, sawn asunder, and wandered in sheepskins and goatskins, of whom the world was not worthy (Hebrews 11:32–38). These all, having obtained a good report through faith, received not the promise, God having provided some better thing for us, that they without us should not be made perfect (Hebrews 11:39–40).",
    12: "Seeing we are compassed about with so great a cloud of witnesses, let us lay aside every weight and the sin which doth so easily beset us, and run with patience the race that is set before us, looking unto Jesus the author and finisher of our faith, who for the joy that was set before him endured the cross, despising the shame, and is set down at the right hand of the throne of God (Hebrews 12:1–2). The readers are to consider him that endured such contradiction of sinners, lest they be wearied and faint in their minds, for they have not yet resisted unto blood, striving against sin (Hebrews 12:3–4). Whom the Lord loveth he chasteneth, and scourgeth every son whom he receiveth, and if they endure chastening, God dealeth with them as with sons, for no chastening seemeth joyous but grievous, nevertheless afterward it yieldeth the peaceable fruit of righteousness (Hebrews 12:5–11). They are to lift up the hands which hang down, follow peace with all men and holiness, look diligently lest any root of bitterness springing up trouble them, and not be profane as Esau, who for one morsel of meat sold his birthright and found no place of repentance, though he sought it carefully with tears (Hebrews 12:12–17). They are not come unto the mount that burned with fire, blackness, darkness, tempest, the sound of a trumpet, and the voice of words, but unto mount Sion, and unto the city of the living God, the heavenly Jerusalem, and to an innumerable company of angels, and to Jesus the mediator of the new covenant, and to the blood of sprinkling that speaketh better things than that of Abel (Hebrews 12:18–24). They are not to refuse him that speaketh, for he hath promised Yet once more I shake not the earth only, but also heaven, signifying the removing of things that are shaken, that those things which cannot be shaken may remain (Hebrews 12:25–27). Receiving a kingdom which cannot be moved, they are to serve God acceptably with reverence and godly fear, for our God is a consuming fire (Hebrews 12:28–29).",
    13: "The writer says to let brotherly love continue, to be not forgetful to entertain strangers, for thereby some have entertained angels unawares, and to remember them that are in bonds, as bound with them (Hebrews 13:1–3). Marriage is honourable in all, and the bed undefiled, but whoremongers and adulterers God will judge, and the readers are to be without covetousness and content with such things as they have, for God hath said I will never leave thee, nor forsake thee (Hebrews 13:4–6). They are to remember them which have the rule over them, who have spoken unto them the word of God, and follow their faith, for Jesus Christ is the same yesterday, and to day, and for ever (Hebrews 13:7–8). They are not to be carried about with divers and strange doctrines, for it is a good thing that the heart be established with grace, not with meats (Hebrews 13:9). We have an altar whereof they have no right to eat which serve the tabernacle, for the bodies of the beasts whose blood is brought into the sanctuary are burned without the camp, wherefore Jesus also suffered without the gate, that he might sanctify the people with his own blood (Hebrews 13:10–12). Let us go forth therefore unto him without the camp, bearing his reproach, for here have we no continuing city, but we seek one to come (Hebrews 13:13–14). By him let us offer the sacrifice of praise to God continually, the fruit of lips giving thanks to his name, and to do good and to communicate forget not (Hebrews 13:15–16). The readers are to obey them that have the rule over them, for they watch for their souls, and the writer asks for their prayers (Hebrews 13:17–19). The God of peace, that brought again from the dead our Lord Jesus, that great shepherd of the sheep, through the blood of the everlasting covenant, is asked to make them perfect in every good work to do his will (Hebrews 13:20–21). The writer begs them to suffer the word of exhortation, says brother Timothy is set at liberty, sends greeting from them of Italy, and closes with grace (Hebrews 13:22–25).",
}

WWA = {
    1: "Hebrews follows Philemon and opens the general letters. The writer names no one and begins with God, who spoke in time past by the prophets and in these last days by his Son, who is better than the angels (1:1-14). Chapter 2 gives the warning that comes from this and tells why the Son became a man.",
    2: "Chapter 1 ended with the Son set above the angels, who are ministering spirits for the heirs of salvation (1:14). Chapter 2 warns the readers not to let the word slip, shows Jesus made a little lower than the angels to taste death for every man, and calls him a merciful and faithful high priest (2:1-18). Chapter 3 compares him with Moses.",
    3: "Chapter 2 ended with Jesus, a merciful and faithful high priest who succours them that are tempted (2:17-18). Chapter 3 shows him worthy of more glory than Moses and warns, from Psalm 95, against the evil heart of unbelief that kept Israel from the promised rest (3:1-19). Chapter 4 speaks of that rest.",
    4: "Chapter 3 ended with Israel unable to enter the rest because of unbelief (3:19). Chapter 4 says a rest remains for the people of God, describes the word of God as quick and powerful, and calls the readers to the throne of grace through the great high priest (4:1-16). Chapter 5 explains the priesthood of Christ.",
    5: "Chapter 4 ended with the great high priest and the throne of grace (4:14-16). Chapter 5 shows how every high priest is called of God and how Christ, after the order of Melchisedec, learned obedience and became the author of eternal salvation, then rebukes the readers for being dull of hearing (5:1-14). Chapter 6 calls them on to maturity.",
    6: "Chapter 5 ended with the call to leave milk and take strong meat (5:12-14). Chapter 6 urges them to go on unto perfection, gives a stern warning about falling away, and offers the promise and oath of God as an anchor of the soul (6:1-20). Chapter 7 returns to Melchisedec.",
    7: "Chapter 6 ended with Jesus, the forerunner, made an high priest for ever after the order of Melchisedec (6:20). Chapter 7 shows Melchisedec greater than Abraham and Levi, and Jesus a priest by an endless life who saves to the uttermost (7:1-28). Chapter 8 turns to the better covenant.",
    8: "Chapter 7 ended with the Son consecrated for evermore (7:28). Chapter 8 gives the sum: a high priest in the true tabernacle, the mediator of a better covenant, and the new covenant promised by Jeremiah, which makes the first one old (8:1-13). Chapter 9 describes the tabernacle and Christ's sacrifice.",
    9: "Chapter 8 ended with the first covenant ready to vanish away (8:13). Chapter 9 describes the earthly tabernacle and the yearly work of the high priest, and then shows Christ entering once by his own blood, so the conscience is purged and he shall appear a second time (9:1-28). Chapter 10 continues with the one offering.",
    10: "Chapter 9 ended with Christ offered once to bear the sins of many (9:28). Chapter 10 shows that the blood of bulls and goats cannot take away sins, that Christ's one offering perfects them that are sanctified, and then calls the readers to draw near, hold fast, and not cast away their confidence (10:1-39). Chapter 11 turns to faith.",
    11: "Chapter 10 ended with those who believe to the saving of the soul (10:39). Chapter 11 tells what faith is and gives a long roll of those who lived by it, from Abel to the prophets, none of whom received the promise without us (11:1-40). Chapter 12 calls the readers to run the race.",
    12: "Chapter 11 ended with the elders who received not the promise, God having provided some better thing for us (11:39-40). Chapter 12 tells the readers to run with patience, looking unto Jesus, to take God's chastening as from a Father, and to remember they have come unto mount Sion (12:1-29). Chapter 13 gives the closing commands.",
    13: "Chapter 12 ended with a kingdom that cannot be moved and a God who is a consuming fire (12:28-29). Chapter 13 gives plain commands for love, hospitality, marriage, and contentment, calls the readers to go forth unto Jesus without the camp, and closes with a blessing and greetings (13:1-25). James follows.",
}

KEY_FIGURES = {
    1: [
        ("God", "Spake in time past by the prophets and hath in these last days spoken by his Son, to whom he says Thou art my Son (1:1-2,5)."),
        ("The Son", "Heir of all things, the brightness of God's glory, who purged our sins and sat down on the right hand of the Majesty on high (1:2-3)."),
        ("The angels", "Told to worship the Son, and are ministering spirits sent forth for the heirs of salvation (1:6-7,14)."),
        ("The prophets", "Those by whom God spake unto the fathers in time past (1:1)."),
    ],
    2: [
        ("Jesus", "Made a little lower than the angels for the suffering of death, who tasted death for every man and is a merciful and faithful high priest (2:9,14-18)."),
        ("God", "Made the captain of their salvation perfect through sufferings and bore witness with signs and wonders (2:4,10)."),
        ("Them that heard the Lord", "Those who confirmed to us the salvation first spoken by the Lord (2:3)."),
        ("The children and the seed of Abraham", "Partakers of flesh and blood, whom Jesus calls brethren and helps (2:11-16)."),
        ("The devil", "He that had the power of death, whom Jesus destroys through death (2:14)."),
    ],
    3: [
        ("Jesus", "The Apostle and High Priest of our profession, counted worthy of more glory than Moses (3:1-3)."),
        ("Moses", "Faithful in all his house as a servant (3:2,5)."),
        ("The holy brethren", "Partakers of the heavenly calling, told to take heed lest there be an evil heart of unbelief (3:1,12)."),
        ("The Holy Ghost", "Saith To day if ye will hear his voice, harden not your hearts (3:7)."),
        ("The fathers who provoked in the wilderness", "Came out of Egypt by Moses, but their carcases fell in the wilderness because of unbelief (3:8-11,16-19)."),
        ("God", "Built all things, was grieved forty years, and sware they should not enter into his rest (3:4,10-11)."),
    ],
    4: [
        ("Jesus the Son of God", "A great high priest, passed into the heavens, touched with the feeling of our infirmities (4:14-15)."),
        ("God", "Rested the seventh day, promised a rest, and gave a word that is quick and powerful (4:3-4,12)."),
        ("The fathers who entered not", "Heard the gospel but it profited them not, for they believed not (4:2,6)."),
        ("Joshua", "Called Jesus in the text, who did not give them the final rest (4:8)."),
        ("David", "In whom God spoke again of a day called To day (4:7)."),
        ("The readers", "Told to labour to enter into that rest and to come boldly unto the throne of grace (4:11,16)."),
    ],
    5: [
        ("Every high priest", "Taken from among men, ordained to offer gifts and sacrifices, and compassed with infirmity (5:1-3)."),
        ("Aaron", "Called of God to the honour of the priesthood (5:4)."),
        ("Christ", "Glorified not himself, offered up prayers with strong crying and tears, learned obedience, and became the author of eternal salvation (5:5-9)."),
        ("God", "Said unto Christ Thou art my Son, and called him an high priest after the order of Melchisedec (5:5-6,10)."),
        ("Melchisedec", "The order after which Christ is a priest for ever (5:6,10)."),
        ("The readers", "Dull of hearing, who ought to be teachers but need milk and not strong meat (5:11-14)."),
    ],
    6: [
        ("The readers", "Told to go on unto perfection, show diligence to the end, and be followers of them who inherit the promises (6:1,11-12)."),
        ("Those who fall away", "Once enlightened, they crucify the Son of God afresh and are nigh unto cursing (6:4-8)."),
        ("God", "Not unrighteous to forget their work, and he confirmed his promise by an oath (6:10,13-18)."),
        ("Abraham", "Patiently endured and obtained the promise (6:13-15)."),
        ("Jesus", "The forerunner entered within the veil, made an high priest for ever after the order of Melchisedec (6:19-20)."),
    ],
    7: [
        ("Melchisedec", "King of Salem and priest of the most high God, who met Abraham and blessed him, a priest continually (7:1-3)."),
        ("Abraham", "Gave Melchisedec a tenth part of all and was blessed by him (7:1-2,4-6)."),
        ("Levi and the sons of Levi", "Receive tithes under the law, yet Levi payed tithes in Abraham (7:5,9-10)."),
        ("Jesus", "Sprang out of Juda, a priest after the power of an endless life, who ever liveth to make intercession (7:14-17,24-25)."),
        ("God", "Sware and will not repent, Thou art a priest for ever (7:20-21)."),
        ("Them that come unto God by him", "Those whom he is able to save to the uttermost (7:25)."),
    ],
    8: [
        ("Jesus", "An high priest set on the right hand of the Majesty, minister of the true tabernacle and mediator of a better covenant (8:1-2,6)."),
        ("God, the Lord", "Pitched the true tabernacle and promised a new covenant with the house of Israel and the house of Judah (8:2,8-12)."),
        ("The earthly priests", "Offer gifts according to the law and serve unto the example and shadow of heavenly things (8:4-5)."),
        ("Moses", "Admonished of God to make all things according to the pattern shewed him in the mount (8:5)."),
        ("The fathers led out of Egypt", "Continued not in the covenant (8:9)."),
        ("The house of Israel and the house of Judah", "The people with whom the new covenant is made (8:8,10)."),
    ],
    9: [
        ("Christ", "Entered once into the holy place by his own blood, offered himself without spot, and shall appear the second time (9:11-14,24-28)."),
        ("The high priest", "Entered the second tabernacle alone once every year, not without blood (9:7)."),
        ("The priests", "Went always into the first tabernacle accomplishing the service (9:6)."),
        ("Moses", "Sprinkled the book, the people, the tabernacle, and the vessels with blood (9:19-21)."),
        ("The Holy Ghost", "Signified that the way into the holiest was not yet made manifest (9:8)."),
        ("Them which are called", "Receive the promise of eternal inheritance through his death (9:15)."),
    ],
    10: [
        ("Christ", "Came to do God's will, offered one sacrifice for sins for ever, and sat down on the right hand of God (10:5-12)."),
        ("God", "Prepared a body for Christ and promised to remember sins no more (10:5,15-17)."),
        ("The priests of the law", "Stand daily offering the same sacrifices, which can never take away sins (10:11)."),
        ("The brethren", "Told to draw near, hold fast, provoke one another, and cast not away their confidence (10:19-25,35)."),
        ("Them that sin wilfully", "Trodden under foot the Son of God and done despite unto the Spirit of grace (10:26-29)."),
        ("The Holy Ghost", "A witness that God will remember their sins no more (10:15-17)."),
    ],
    11: [
        ("Abel, Enoch, and Noah", "Abel offered a more excellent sacrifice, Enoch was translated, and Noah prepared an ark (11:4-7)."),
        ("Abraham, Sara, Isaac, Jacob, and Joseph", "Obeyed, sojourned, received strength, and spoke of things to come, looking for a city whose builder and maker is God (11:8-22)."),
        ("Moses and his parents", "His parents hid him, and he refused to be called Pharaoh's daughter's son and kept the passover (11:23-29)."),
        ("Rahab", "The harlot who received the spies with peace and perished not (11:31)."),
        ("Gedeon, Barak, Samson, Jephthae, David, Samuel, and the prophets", "Through faith subdued kingdoms, stopped the mouths of lions, and some were tortured and slain (11:32-38)."),
        ("God", "A rewarder of them that diligently seek him, who hath prepared a city and provided some better thing for us (11:6,16,40)."),
    ],
    12: [
        ("Jesus", "The author and finisher of our faith, who endured the cross and is set down at the right hand of the throne of God (12:2-3)."),
        ("God, the Father of spirits", "Chastens whom he loveth for our profit, that we might be partakers of his holiness (12:6-10)."),
        ("The readers", "Told to run with patience, lift up the hands which hang down, and follow peace and holiness (12:1,12-14)."),
        ("Esau", "Sold his birthright for one morsel of meat and found no place of repentance (12:16-17)."),
        ("Moses and Israel at Sinai", "Heard the voice of words and feared exceedingly (12:18-21)."),
        ("The angels and the church of the firstborn", "The company at mount Sion to which the readers have come (12:22-24)."),
    ],
    13: [
        ("The readers", "Told to let brotherly love continue, entertain strangers, be content, and go forth unto Jesus without the camp (13:1-6,13)."),
        ("Jesus Christ", "The same yesterday, and to day, and for ever, who suffered without the gate to sanctify the people (13:8,12)."),
        ("God", "Hath said I will never leave thee, and is the God of peace who brought again from the dead our Lord Jesus (13:5,20)."),
        ("Them that have the rule", "Spoke the word of God, and watch for the souls of the readers (13:7,17)."),
        ("The writer", "Asks for prayer and begs them to suffer the word of exhortation (13:18-22)."),
        ("Timothy", "Brother Timothy is set at liberty (13:23)."),
    ],
}

THEMES = {
    1: [
        "God, who at sundry times and in divers manners spake by the prophets, hath in these last days spoken unto us by his Son (1:1-2).",
        "The Son is heir of all things, made the worlds, is the brightness of God's glory, and is called God on a throne for ever and ever (1:2-3,8-12).",
        "The Son by himself purged our sins and sat down on the right hand of the Majesty on high (1:3).",
        "The Son has a more excellent name than the angels, and all the angels of God are told to worship him (1:4-14).",
        "The heavens shall perish but the Son remaineth, and the angels are ministering spirits sent for the heirs of salvation (1:10-14).",
    ],
    2: [
        "The readers are told to give earnest heed lest they let the word slip, for there is no escape if they neglect so great salvation (2:1-4).",
        "Jesus was made a little lower than the angels and crowned with glory and honour, so he tasted death for every man (2:5-9).",
        "Through death he destroyed the devil and delivered them who through fear of death were all their lifetime subject to bondage (2:14-15).",
        "He is not ashamed to call them brethren, for both he that sanctifieth and they who are sanctified are all of one (2:10-13).",
        "He is a merciful and faithful high priest, and having suffered being tempted, he is able to succour them that are tempted (2:17-18).",
    ],
    3: [
        "Jesus is counted worthy of more glory than Moses, as he who builded the house has more honour than the house (3:1-6).",
        "Moses was faithful as a servant, but Christ as a son over his own house, whose house are we (3:5-6).",
        "Israel hardened their hearts in the provocation, and the readers are told to take heed lest there be in them an evil heart of unbelief (3:7-12).",
        "The brethren are to exhort one another daily, while it is called To day, lest any be hardened through the deceitfulness of sin (3:12-13).",
        "We are made partakers of Christ, if we hold the beginning of our confidence stedfast unto the end (3:6,14).",
    ],
    4: [
        "There remaineth a rest to the people of God, and he that is entered into his rest hath ceased from his own works (4:1-11).",
        "The gospel did not profit those who heard it without faith, and the readers are to labour to enter into that rest (4:2-11).",
        "The word of God is quick, and powerful, and sharper than any twoedged sword, a discerner of the thoughts and intents of the heart (4:12-13).",
        "Jesus is a great high priest touched with the feeling of our infirmities, tempted in all points like as we are, yet without sin (4:14-15).",
        "The readers are told to come boldly unto the throne of grace, that they may obtain mercy and find grace to help in time of need (4:16).",
    ],
    5: [
        "No man taketh the honour of the priesthood unto himself, but he that is called of God, as was Aaron, and so Christ was called (5:1-6).",
        "A high priest can have compassion on the ignorant because he is compassed with infirmity (5:1-3).",
        "Christ offered up prayers with strong crying and tears, and learned obedience by the things which he suffered (5:7-8).",
        "Being made perfect, he became the author of eternal salvation unto all them that obey him (5:9-10).",
        "The readers are dull of hearing and need milk, but strong meat belongeth to them of full age (5:11-14).",
    ],
    6: [
        "The writer says let us go on unto perfection, leaving the principles of the doctrine of Christ (6:1-3).",
        "Those once enlightened who fall away crucify to themselves the Son of God afresh, and the thorn-bearing ground is nigh unto cursing (6:4-8).",
        "The writer is persuaded better things of the readers, for God is not unrighteous to forget their labour of love (6:9-12).",
        "God confirmed his promise by an oath, so by two immutable things, in which it is impossible for God to lie, we have strong consolation (6:13-18).",
        "The hope is an anchor of the soul, sure and stedfast, and Jesus the forerunner has entered within the veil (6:19-20).",
    ],
    7: [
        "Christ is a priest after the order of Melchisedec, not after the order of Aaron, so the priesthood is changed (7:1-17).",
        "The law made nothing perfect, but the bringing in of a better hope, by the which we draw nigh unto God (7:11-19).",
        "Jesus is made a priest after the power of an endless life, and because he continueth ever he hath an unchangeable priesthood (7:15-17,23-24).",
        "Jesus was made a priest with an oath and is a surety of a better testament (7:20-22).",
        "He is able to save to the uttermost them that come unto God by him, seeing he ever liveth to make intercession for them (7:25).",
    ],
    8: [
        "Christ is a minister of the sanctuary and the true tabernacle, which the Lord pitched, and not man, while the earthly priests serve a shadow (8:1-5).",
        "He hath obtained a more excellent ministry, being the mediator of a better covenant established upon better promises (8:6).",
        "The new covenant promised by Jeremiah puts God's laws into their mind and writes them in their hearts (8:7-12).",
        "God promises to be merciful to their unrighteousness and remember their sins no more (8:12).",
        "In that he saith A new covenant, he hath made the first old, which is ready to vanish away (8:13).",
    ],
    9: [
        "The first tabernacle and its sacrifices could not make the worshipper perfect as pertaining to the conscience (9:1-10).",
        "Christ entered once into the holy place by his own blood, having obtained eternal redemption for us (9:11-14,24-28).",
        "Where a testament is there must be the death of the testator, and without shedding of blood is no remission (9:15-22).",
        "The blood of Christ purges the conscience from dead works to serve the living God, so that those called receive the promise of eternal inheritance (9:14-15).",
        "Christ now appears in the presence of God for us and shall appear the second time without sin unto salvation (9:24-28).",
    ],
    10: [
        "The law has a shadow of good things to come, and it is not possible that the blood of bulls and of goats should take away sins (10:1-4,11).",
        "By the will of God we are sanctified through the offering of the body of Jesus Christ once for all, and by one offering he hath perfected for ever them that are sanctified (10:5-18).",
        "Having boldness to enter into the holiest by the blood of Jesus, believers are to draw near, hold fast, provoke one another, and not forsake the assembling of themselves (10:19-25).",
        "If we sin wilfully after we have received the knowledge of the truth there remaineth no more sacrifice for sins, for it is a fearful thing to fall into the hands of the living God (10:26-31).",
        "The readers took joyfully the spoiling of their goods and are told to cast not away their confidence, for the just shall live by faith (10:32-39).",
    ],
    11: [
        "Faith is the substance of things hoped for, the evidence of things not seen, and without faith it is impossible to please God (11:1-3,6).",
        "By faith Noah prepared an ark, Abraham went out not knowing whither he went, and Moses chose to suffer affliction with the people of God (11:7-31).",
        "The patriarchs confessed they were strangers and pilgrims on the earth and desired a better country, that is, an heavenly (11:13-16).",
        "Some through faith subdued kingdoms, while others were tortured, mocked, stoned, and sawn asunder, of whom the world was not worthy (11:32-38).",
        "These all received not the promise, God having provided some better thing for us, that they without us should not be made perfect (11:39-40).",
    ],
    12: [
        "The readers are to lay aside every weight and run with patience the race set before us, looking unto Jesus the author and finisher of our faith (12:1-3).",
        "Whom the Lord loveth he chasteneth, and afterward it yieldeth the peaceable fruit of righteousness (12:4-11).",
        "They are to follow peace with all men and holiness, lest any root of bitterness trouble them or any be profane as Esau (12:12-17).",
        "They are not come unto the mount that burned with fire, but unto mount Sion, the city of the living God, and to Jesus the mediator of the new covenant (12:18-24).",
        "They receive a kingdom which cannot be moved, so are to serve God acceptably with reverence and godly fear, for our God is a consuming fire (12:25-29).",
    ],
    13: [
        "The readers are told to let brotherly love continue and to entertain strangers, for some have entertained angels unawares (13:1-3).",
        "Marriage is honourable in all, and the readers are to be without covetousness and content, for God hath said I will never leave thee (13:4-6).",
        "They are to remember them that have the rule, follow their faith, and not be carried about with strange doctrines, for Jesus Christ is the same yesterday, to day, and for ever (13:7-9,17).",
        "They are to go forth unto Jesus without the camp, bearing his reproach, for here have we no continuing city, but we seek one to come (13:10-14).",
        "By him they are to offer the sacrifice of praise continually, and the God of peace is asked to make them perfect in every good work (13:15-21).",
    ],
}

AUDIENCE = {
    1: "Believers who honored the angels of Sinai would have heard that God's last word came through a Son who stands higher than every angel.",
    2: "Second-generation believers who had never seen Jesus would have heard that the message is sure and that he shared their flesh so he can help when they are tempted.",
    3: "Believers tempted to go back would have heard that Jesus is worthy of more glory than Moses and that Israel's hard hearts in the wilderness were a warning.",
    4: "Weary believers would have heard that God's rest still stands open and that they could come boldly to the throne of grace.",
    5: "Believers who knew the priests of the law would have heard that Christ was called of God like Aaron, and that they had grown slow to learn.",
    6: "Believers tempted to give up would have heard a sharp warning together with the promise that God's oath is an anchor of the soul.",
    7: "Readers who honored the sons of Levi would have heard that a priest after Melchisedec lives for ever and saves to the uttermost.",
    8: "Readers who loved the tabernacle would have heard that a better covenant had come and that the old one was ready to vanish away.",
    9: "Readers who knew the yearly entry behind the veil would have heard that Christ went in once by his own blood and that the conscience is now purged.",
    10: "Believers who had been mocked and robbed would have heard to draw near with boldness and to hold on to their confidence.",
    11: "Believers who felt alone would have heard a long roll of men and women who trusted God without seeing the promise come.",
    12: "Weary runners would have heard to look to Jesus, take God's chastening as a father's care, and remember the mountain they had come to.",
    13: "A congregation hearing the close of the sermon would have heard plain commands for daily love and a blessing from the God of peace.",
}


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "58_hebrews.json"
    data = load(path)
    for n in range(1, 14):
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


def apply_chapter_context():
    path = ROOT / "chapter_context" / "40_hebrews_james.json"
    data = load(path)
    for n in range(1, 14):
        data[f"{BOOK} {n}"]["audience"] = AUDIENCE[n]
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_book_overview():
    path = ROOT / "book_overviews" / "09_general_letters_revelation.json"
    data = load(path)
    book = data[BOOK]
    book["author"] = "Credited to Paul in the KJV title, though the letter itself names no writer (Hebrews 13:22-23)."
    for key in ("purpose", "theme", "summary"):
        book[key] = book[key].replace("of His priesthood", "of his priesthood").replace("that He fulfills", "that he fulfills")
    for movement in book["movements"]:
        movement["description"] = movement["description"].replace("and His once-for-all", "and his once-for-all")
    book["keyVerse"] = "Hebrews 4:14"
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


# Sentence-initial or ambiguous "He" lines that need rewording rather than lowercasing.
STORY_REWORDS = [
    ("He is “the brightness of his glory", "The Son is “the brightness of his glory"),
    ("and He holds everything together", "and he holds everything together"),
    ("After He “purged our sins,” He “sat down", "After he “purged our sins,” he “sat down"),
    ("every man.” He shared our flesh and blood so that through death He might destroy", "every man.” Jesus shared our flesh and blood so that through death he might destroy"),
    ("He was made like His brothers in every way so He could be", "Jesus was made like his brothers in every way so he could be"),
    ("Because He understands,", "Because he understands,"),
    ("as He called Aaron", "as he called Aaron"),
    ("and He became “the author", "and he became “the author"),
    ("Jesus came from the tribe of Judah, not Levi. He became a priest", "Jesus came from the tribe of Judah, not Levi. Jesus became a priest"),
    ("” He is exactly the high priest we need", "” Jesus is exactly the high priest we need"),
    ("” He does not need to offer sacrifices", "” Jesus does not need to offer sacrifices"),
    ("” He serves in the true tabernacle", "” Jesus serves in the true tabernacle"),
]


def lower_divine(text):
    """Lowercase His/Him/Himself outside double quotes, leaving bold titles alone."""
    out = []
    for line in text.split("\n"):
        prefix = ""
        body = line
        if line.startswith("**"):
            marker = "** — "
            cut = line.find(marker)
            if cut == -1:
                out.append(line)
                continue
            prefix, body = line[: cut + len(marker)], line[cut + len(marker):]
        parts = re.split(r"(“[^”]*”)", body)
        for i, part in enumerate(parts):
            if not part.startswith("“"):
                parts[i] = re.sub(r"\b(His|Him|Himself)\b", lambda m: m.group(0).lower(), part)
        out.append(prefix + "".join(parts))
    return "\n".join(out)


def apply_story_fixes():
    path = ROOT / "book_content" / "09_general_letters_revelation.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("# Hebrews")
    end = text.index("\n# James", start) + 1
    section = text[start:end]
    for old, new in STORY_REWORDS:
        if section.count(old) == 0 and section.count(new) >= 1:
            continue
        if section.count(old) != 1:
            raise SystemExit(f"story fix matched {section.count(old)} times: {old!r}")
        section = section.replace(old, new)
    section = lower_divine(section)
    path.write_text(text[:start] + section + text[end:], encoding="utf-8")
    print(f"Updated {path.relative_to(ROOT)}")


if __name__ == "__main__":
    apply_chapter_insights()
    apply_chapter_context()
    apply_book_overview()
    apply_story_fixes()
