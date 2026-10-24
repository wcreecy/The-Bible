#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Apply the completed editorial review for 1 Peter through Jude to source content only."""

import glob
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


# -*- coding: utf-8 -*-
# Each book: summaries, WWA, figures, themes (positional), audiences.
BOOKS = {}

BOOKS["1 Peter"] = dict(
    file="60_1_peter.json",
    summary={
        1: "Peter, an apostle of Jesus Christ, writes to the strangers scattered throughout Pontus, Galatia, Cappadocia, Asia, and Bithynia, elect according to the foreknowledge of God the Father, through sanctification of the Spirit, unto obedience and sprinkling of the blood of Jesus Christ (1 Peter 1:1–2). Blessed be the God and Father of our Lord Jesus Christ, which according to his abundant mercy hath begotten us again unto a lively hope by the resurrection of Jesus Christ from the dead, to an inheritance incorruptible, and undefiled, and that fadeth not away, reserved in heaven for them, who are kept by the power of God through faith unto salvation (1 Peter 1:3–5). They greatly rejoice, though now for a season they are in heaviness through manifold temptations, that the trial of their faith, much more precious than gold that perisheth, might be found unto praise and honour and glory at the appearing of Jesus Christ, whom having not seen they love (1 Peter 1:6–9). The prophets enquired and searched diligently of this salvation, searching what the Spirit of Christ which was in them did signify when it testified beforehand the sufferings of Christ and the glory that should follow (1 Peter 1:10–12). They are to gird up the loins of their mind, be sober, hope to the end, and as obedient children be holy in all manner of conversation, because it is written Be ye holy, for I am holy (1 Peter 1:13–17). They were redeemed not with corruptible things, silver and gold, but with the precious blood of Christ, as of a lamb without blemish and without spot, foreordained before the foundation of the world (1 Peter 1:18–21). Seeing they have purified their souls in obeying the truth, they are to love one another with a pure heart fervently, being born again by the word of God, which liveth and abideth for ever, for the word of the Lord endureth for ever (1 Peter 1:22–25).",
        2: "Laying aside all malice, and all guile, and hypocrisies, and envies, and all evil speakings, the believers are as newborn babes to desire the sincere milk of the word, that they may grow thereby, if so be they have tasted that the Lord is gracious (1 Peter 2:1–3). Coming to Christ, a living stone, disallowed of men but chosen of God, precious, they as lively stones are built up a spiritual house, an holy priesthood, to offer up spiritual sacrifices acceptable to God by Jesus Christ (1 Peter 2:4–5). He that believeth on the chief corner stone shall not be confounded, but to them which be disobedient the stone which the builders disallowed is made a stone of stumbling and a rock of offence (1 Peter 2:6–8). But they are a chosen generation, a royal priesthood, an holy nation, a peculiar people, that they should shew forth the praises of him who hath called them out of darkness into his marvellous light, who in time past were not a people but are now the people of God (1 Peter 2:9–10). As strangers and pilgrims they are to abstain from fleshly lusts, have their conversation honest among the Gentiles, that they may by good works glorify God in the day of visitation (1 Peter 2:11–12). They are to submit to every ordinance of man for the Lord's sake, whether to the king or to governors, as free but not using liberty for a cloke of maliciousness, honouring all men, loving the brotherhood, fearing God, and honouring the king (1 Peter 2:13–17). Servants are to be subject to their masters with all fear, not only to the good and gentle but also to the froward, for it is thankworthy if a man for conscience toward God endure grief, suffering wrongfully (1 Peter 2:18–20). Christ also suffered for us, leaving us an example, who did no sin, neither was guile found in his mouth, who when he was reviled reviled not again, and who his own self bare our sins in his own body on the tree, by whose stripes they were healed (1 Peter 2:21–24). They were as sheep going astray, but are now returned unto the Shepherd and Bishop of their souls (1 Peter 2:25).",
        3: "Wives are to be in subjection to their own husbands, that if any obey not the word they also may without the word be won by the conversation of the wives, whose adorning is not outward plaiting of the hair and wearing of gold, but the hidden man of the heart, a meek and quiet spirit, which is in the sight of God of great price, as Sara obeyed Abraham, calling him lord (1 Peter 3:1–6). Husbands are to dwell with their wives according to knowledge, giving honour unto the wife as unto the weaker vessel, and as being heirs together of the grace of life, that their prayers be not hindered (1 Peter 3:7). All are to be of one mind, having compassion one of another, loving as brethren, pitiful, courteous, not rendering evil for evil, but contrariwise blessing, for the eyes of the Lord are over the righteous and his ears are open unto their prayers (1 Peter 3:8–12). Who is he that will harm them, if they be followers of that which is good, but if they suffer for righteousness' sake, happy are they, and they are to sanctify the Lord God in their hearts and be ready always to give an answer to every man that asketh a reason of the hope that is in them with meekness and fear (1 Peter 3:13–15). Having a good conscience, that they which falsely accuse their good conversation in Christ may be ashamed, for it is better to suffer for well doing than for evil doing (1 Peter 3:16–17). Christ also hath once suffered for sins, the just for the unjust, that he might bring us to God, being put to death in the flesh but quickened by the Spirit, by which he went and preached unto the spirits in prison, which sometime were disobedient in the days of Noah, while the ark was a preparing, wherein eight souls were saved by water (1 Peter 3:18–20). Baptism doth also now save us, the answer of a good conscience toward God, by the resurrection of Jesus Christ, who is gone into heaven and is on the right hand of God, angels and authorities and powers being made subject unto him (1 Peter 3:21–22).",
        4: "Forasmuch as Christ hath suffered for us in the flesh, the believers are to arm themselves with the same mind, for he that hath suffered in the flesh hath ceased from sin, that he no longer should live to the lusts of men but to the will of God (1 Peter 4:1–2). The time past may suffice to have wrought the will of the Gentiles, when they walked in lasciviousness, lusts, excess of wine, revellings, banquetings, and abominable idolatries, wherein the Gentiles think it strange that they run not with them to the same excess of riot, speaking evil of them, who shall give account to him that is ready to judge the quick and the dead (1 Peter 4:3–6). The end of all things is at hand, so they are to be sober, watch unto prayer, have fervent charity among themselves, for charity shall cover the multitude of sins, and use hospitality one to another without grudging (1 Peter 4:7–9). As every man hath received the gift, he is to minister the same one to another, as good stewards of the manifold grace of God, that God in all things may be glorified through Jesus Christ (1 Peter 4:10–11). They are not to think it strange concerning the fiery trial which is to try them, but rejoice inasmuch as they are partakers of Christ's sufferings, and if they are reproached for the name of Christ, happy are they, for the spirit of glory and of God resteth upon them (1 Peter 4:12–14). Let none of them suffer as a murderer, or a thief, or an evildoer, or a busybody in other men's matters, yet if any man suffer as a Christian, let him not be ashamed, but glorify God on this behalf (1 Peter 4:15–16). Judgment must begin at the house of God, and if first at us, what shall the end be of them that obey not the gospel of God, so let them that suffer according to the will of God commit the keeping of their souls to him in well doing, as unto a faithful Creator (1 Peter 4:17–19).",
        5: "Peter, who is also an elder and a witness of the sufferings of Christ, exhorts the elders to feed the flock of God, taking the oversight not by constraint but willingly, not for filthy lucre but of a ready mind, neither as being lords over God's heritage but being ensamples to the flock (1 Peter 5:1–3). When the chief Shepherd shall appear, they shall receive a crown of glory that fadeth not away (1 Peter 5:4). The younger are to submit themselves unto the elder, and all are to be clothed with humility, for God resisteth the proud and giveth grace to the humble (1 Peter 5:5). They are to humble themselves under the mighty hand of God, casting all their care upon him, for he careth for them (1 Peter 5:6–7). They are to be sober and vigilant, because their adversary the devil, as a roaring lion, walketh about seeking whom he may devour, whom they are to resist stedfast in the faith, knowing that the same afflictions are accomplished in their brethren in the world (1 Peter 5:8–9). The God of all grace, who hath called us unto his eternal glory by Christ Jesus, after that they have suffered a while, make them perfect, stablish, strengthen, settle them (1 Peter 5:10–11). Peter has written briefly by Silvanus, a faithful brother, exhorting and testifying that this is the true grace of God wherein they stand, and the church that is at Babylon and Marcus his son salute them, with peace to all that are in Christ Jesus (1 Peter 5:12–14).",
    },
    wwa={
        1: "1 Peter follows James among the general letters. Peter writes to strangers scattered through the provinces of Asia Minor, blessing God for a lively hope by the resurrection of Jesus Christ, telling of the trial of their faith as gold tried with fire, and calling them to be holy and to love one another (1:1-25). Chapter 2 tells them who they are in Christ.",
        2: "Chapter 1 ended with the word of the Lord that endureth for ever (1:25). Chapter 2 tells believers to desire the milk of the word, calls them lively stones, a chosen generation and a royal priesthood, and shows how strangers and servants should live and follow Christ's example (2:1-25). Chapter 3 turns to wives, husbands, and suffering for righteousness.",
        3: "Chapter 2 ended with Christ the Shepherd and Bishop of their souls (2:25). Chapter 3 speaks to wives and husbands, calls all to be of one mind and to bless, tells them to be ready to give a reason of their hope, and shows Christ suffering for the unjust and now at God's right hand (3:1-22). Chapter 4 calls them to arm themselves with the same mind.",
        4: "Chapter 3 ended with Christ gone into heaven, angels and powers subject to him (3:22). Chapter 4 tells believers to live no longer to the lusts of men, to love and use hospitality, not to think the fiery trial strange, and to commit their souls to a faithful Creator (4:1-19). Chapter 5 gives instructions for elders and closes the letter.",
        5: "Chapter 4 ended with a call to commit the keeping of their souls to a faithful Creator in well doing (4:19). Chapter 5 tells elders to feed the flock, the younger to submit, all to cast their care on God and resist the devil, and closes with a prayer, greetings from Babylon, and peace (5:1-14). 2 Peter follows.",
    },
    figures={
        1: [
            ("Peter", "An apostle of Jesus Christ who writes to the strangers and blesses God for a lively hope (1:1,3)."),
            ("The strangers scattered abroad", "Elect according to the foreknowledge of God, kept by his power, and tried with manifold temptations (1:1-2,5-7)."),
            ("God the Father", "Hath begotten us again unto a lively hope, calls them holy, and judges every man's work without respect of persons (1:3,15-17)."),
            ("Jesus Christ", "Raised from the dead, whose precious blood redeemed them, as a lamb without blemish and without spot (1:3,18-21)."),
            ("The Holy Ghost, the Spirit of Christ", "The Spirit of Christ testified in the prophets, and the gospel was preached with the Holy Ghost sent down from heaven (1:11-12)."),
            ("The prophets", "Enquired and searched diligently of this salvation and ministered it to us (1:10-12)."),
        ],
        2: [
            ("Christ", "The living stone, chosen of God and precious, who bare our sins on the tree and is the Shepherd and Bishop of their souls (2:4,24-25)."),
            ("The believers", "Lively stones built up a spiritual house, a chosen generation, a royal priesthood, an holy nation (2:5,9)."),
            ("The disobedient", "They which stumble at the word, to whom the stone the builders disallowed is a rock of offence (2:7-8)."),
            ("The Gentiles", "Speak against the believers as evildoers but may glorify God by seeing their good works (2:12)."),
            ("The king and governors", "To whom believers are to submit for the Lord's sake (2:13-14,17)."),
            ("Servants", "Told to be subject to their masters, even the froward, and to take suffering wrongfully patiently (2:18-20)."),
        ],
        3: [
            ("Wives", "Told to be in subjection, with a meek and quiet spirit, that husbands may be won without the word (3:1-6)."),
            ("Husbands", "Told to dwell with their wives according to knowledge and give honour, that their prayers be not hindered (3:7)."),
            ("The brethren", "Told to be of one mind, to bless, and to be ready to give an answer of the hope that is in them (3:8-9,15)."),
            ("Christ", "Suffered for sins, the just for the unjust, was quickened by the Spirit, and is on the right hand of God (3:18-22)."),
            ("The spirits in prison and Noah's eight souls", "Disobedient in the days of Noah while the ark was preparing, wherein eight souls were saved by water (3:19-20)."),
            ("God", "Waited with longsuffering in the days of Noah, and his eyes are over the righteous (3:12,20)."),
        ],
        4: [
            ("Christ", "Suffered for us in the flesh, is partaker of whose sufferings the believers are, and will be glad when his glory is revealed (4:1,13)."),
            ("The believers", "Told to arm themselves with the same mind, be sober, use hospitality, and not think the fiery trial strange (4:1,7-12)."),
            ("The Gentiles", "Think it strange that believers run not with them to the same excess of riot, and speak evil of them (4:3-4)."),
            ("The Spirit of glory and of God", "Resteth upon those reproached for the name of Christ (4:14)."),
            ("God, the faithful Creator", "Ready to judge the quick and the dead, and keeps the souls of those who suffer according to his will (4:5,17-19)."),
        ],
        5: [
            ("Peter", "An elder and a witness of the sufferings of Christ, who exhorts the elders and writes by Silvanus (5:1,12)."),
            ("The elders", "Told to feed the flock of God willingly, as ensamples and not lords (5:1-3)."),
            ("The younger", "Told to submit themselves unto the elder and be clothed with humility (5:5)."),
            ("The chief Shepherd", "Shall appear and give a crown of glory that fadeth not away (5:4)."),
            ("The devil", "The adversary who walketh about as a roaring lion, seeking whom he may devour (5:8)."),
            ("The God of all grace", "Called us unto his eternal glory and will make them perfect, stablish, strengthen, settle them (5:10)."),
        ],
    },
    themes={
        1: [
            "God hath begotten us again unto a lively hope by the resurrection of Jesus Christ from the dead, to an inheritance reserved in heaven (1:3-5).",
            "The trial of their faith, much more precious than gold that perisheth, is found unto praise and honour and glory at the appearing of Jesus Christ (1:6-9).",
            "They are elect according to the foreknowledge of God the Father, kept by the power of God through faith unto salvation (1:1-5).",
            "Because God is holy, they are to be holy in all manner of conversation, redeemed with the precious blood of Christ and not with silver and gold (1:13-21).",
            "They are to love one another with a pure heart fervently, being born again by the word of God, which liveth and abideth for ever (1:22-25).",
        ],
        2: [
            "As newborn babes they are to desire the sincere milk of the word, that they may grow thereby (2:1-3).",
            "They are a chosen generation, a royal priesthood, an holy nation, a peculiar people, once not a people but now the people of God (2:4-10).",
            "They are to have their conversation honest among the Gentiles, that by good works the Gentiles may glorify God, and to submit to every ordinance of man for the Lord's sake (2:11-17).",
            "Servants are to take suffering wrongfully patiently, because Christ also suffered for us, leaving us an example that we should follow his steps (2:18-25).",
            "He his own self bare our sins in his own body on the tree, by whose stripes they were healed, and they are returned unto the Shepherd and Bishop of their souls (2:21-25).",
        ],
        3: [
            "Wives may win unbelieving husbands without the word by a chaste conversation and a meek and quiet spirit, which is of great price in the sight of God (3:1-6).",
            "Husbands are to give honour to the wife as being heirs together of the grace of life (3:7).",
            "All are to be of one mind, compassionate, not rendering evil for evil, but contrariwise blessing (3:8-12).",
            "They are to sanctify the Lord God in their hearts and be ready to give an answer of the hope that is in them with meekness and fear, having a good conscience (3:13-17).",
            "Christ hath once suffered for sins, the just for the unjust, and is gone into heaven, angels and authorities and powers being made subject unto him (3:18-22).",
        ],
        4: [
            "They are to arm themselves with the same mind as Christ, and live no longer to the lusts of men but to the will of God (4:1-6).",
            "The end of all things is at hand, so they are to be sober, have fervent charity, use hospitality, and minister their gifts as good stewards of the manifold grace of God (4:7-11).",
            "They are not to think the fiery trial strange but to rejoice as partakers of Christ's sufferings, for the spirit of glory and of God resteth upon them (4:12-14).",
            "If any suffer as a Christian, let him not be ashamed, but let none suffer as a murderer, a thief, an evildoer, or a busybody (4:15-16).",
            "Judgment begins at the house of God, and those who suffer according to God's will are to commit the keeping of their souls to a faithful Creator (4:17-19).",
        ],
        5: [
            "The elders are to feed the flock of God willingly, not as lords over God's heritage, but as ensamples to the flock (5:1-4).",
            "All are to be clothed with humility, for God resisteth the proud and giveth grace to the humble (5:5-6).",
            "They are to cast all their care upon God, for he careth for them (5:7).",
            "They are to be sober and vigilant and resist the devil stedfast in the faith (5:8-9).",
            "After they have suffered a while, the God of all grace will make them perfect, stablish, strengthen, settle them (5:10-11).",
        ],
    },
    audience={
        1: "Strangers far from home, who loved a Lord they had not seen, would have heard that their trials were like gold in the fire and that a living hope was kept for them in heaven.",
        2: "Believers who felt like outsiders in their cities would have heard that God called them a chosen people and a royal priesthood, and that Christ's patience under wrong was their pattern.",
        3: "Women married to unbelievers, and believers slandered by their neighbors, would have heard how a quiet spirit, a clear conscience, and a ready answer could win others and shame accusers.",
        4: "Believers whose old friends thought them strange would have heard not to be surprised at the fiery trial, to love one another, and to trust a faithful Creator.",
        5: "Church elders and younger members facing a roaring enemy would have heard to shepherd willingly, clothe themselves in humility, and cast their care on God.",
    },
)

BOOKS["2 Peter"] = dict(
    file="61_2_peter.json",
    summary={
        1: "Simon Peter, a servant and an apostle of Jesus Christ, writes to them that have obtained like precious faith, with grace and peace multiplied through the knowledge of God and of Jesus our Lord (2 Peter 1:1–2). His divine power hath given unto us all things that pertain unto life and godliness, and exceeding great and precious promises, that by these ye might be partakers of the divine nature, having escaped the corruption that is in the world through lust (2 Peter 1:3–4). Giving all diligence, they are to add to their faith virtue, knowledge, temperance, patience, godliness, brotherly kindness, and charity, for if these things be in them and abound, they make them neither barren nor unfruitful, but he that lacketh these things is blind (2 Peter 1:5–9). They are to give diligence to make their calling and election sure, for so an entrance shall be ministered unto them abundantly into the everlasting kingdom of our Lord and Saviour Jesus Christ (2 Peter 1:10–11). Peter will not be negligent to put them in remembrance, knowing that shortly he must put off his tabernacle, even as the Lord Jesus Christ hath shewed him, and will endeavour that they may have these things in remembrance after his decease (2 Peter 1:12–15). The apostles have not followed cunningly devised fables, but were eyewitnesses of his majesty, when he received from God the Father honour and glory, and a voice came from the excellent glory, This is my beloved Son, in whom I am well pleased, which they heard in the holy mount (2 Peter 1:16–18). They have a more sure word of prophecy, whereunto they do well to take heed, as unto a light that shineth in a dark place, for no prophecy of the scripture is of any private interpretation, but holy men of God spake as they were moved by the Holy Ghost (2 Peter 1:19–21).",
        2: "There were false prophets among the people, even as there shall be false teachers among you, who privily shall bring in damnable heresies, even denying the Lord that bought them, and many shall follow their pernicious ways, and through covetousness shall they with feigned words make merchandise of you (2 Peter 2:1–3). God spared not the angels that sinned, but cast them down to hell and delivered them into chains of darkness to be reserved unto judgment, and spared not the old world but saved Noah the eighth person, a preacher of righteousness, and turned the cities of Sodom and Gomorrha into ashes, making them an ensample unto those that after should live ungodly (2 Peter 2:4–6). He delivered just Lot, vexed with the filthy conversation of the wicked, for the Lord knoweth how to deliver the godly out of temptations, and to reserve the unjust unto the day of judgment to be punished (2 Peter 2:7–9). Chiefly them that walk after the flesh in the lust of uncleanness and despise government are presumptuous and selfwilled and are not afraid to speak evil of dignities, whereas angels bring not railing accusation against them before the Lord (2 Peter 2:10–11). These are as natural brute beasts, spots and blemishes, having eyes full of adultery, beguiling unstable souls, with an heart exercised with covetous practices, which have forsaken the right way, following the way of Balaam of Bosor, who loved the wages of unrighteousness but was rebuked by the dumb ass speaking with man's voice (2 Peter 2:12–16). They are wells without water and clouds carried with a tempest, who speak great swelling words of vanity and allure through the lusts of the flesh, promising liberty while they themselves are the servants of corruption, for of whom a man is overcome, of the same is he brought in bondage (2 Peter 2:17–19). If after they have escaped the pollutions of the world through the knowledge of the Lord and Saviour Jesus Christ they are again entangled therein and overcome, the latter end is worse with them than the beginning, as in the true proverb, The dog is turned to his own vomit again, and the sow that was washed to her wallowing in the mire (2 Peter 2:20–22).",
        3: "Peter writes this second epistle to stir up their pure minds by way of remembrance, that they may be mindful of the words spoken before by the holy prophets and of the commandment of the apostles of the Lord and Saviour (2 Peter 3:1–2). There shall come in the last days scoffers, walking after their own lusts, saying Where is the promise of his coming, for all things continue as they were from the beginning of the creation (2 Peter 3:3–4). They willingly are ignorant that by the word of God the heavens were of old, and the world that then was, being overflowed with water, perished, but the heavens and the earth which are now are kept in store, reserved unto fire against the day of judgment and perdition of ungodly men (2 Peter 3:5–7). One day is with the Lord as a thousand years, and the Lord is not slack concerning his promise, but is longsuffering to us-ward, not willing that any should perish, but that all should come to repentance (2 Peter 3:8–9). The day of the Lord will come as a thief in the night, in which the heavens shall pass away with a great noise, and the elements shall melt with fervent heat, so what manner of persons ought they to be in all holy conversation and godliness, looking for new heavens and a new earth, wherein dwelleth righteousness (2 Peter 3:10–13). They are to be diligent that they may be found of him in peace, without spot, and blameless, and to account the longsuffering of the Lord salvation, as their beloved brother Paul hath written, in whose epistles are some things hard to be understood, which they that are unlearned and unstable wrest, as they do also the other scriptures, unto their own destruction (2 Peter 3:14–16). They are to beware lest they be led away with the error of the wicked and fall from their own stedfastness, but grow in grace and in the knowledge of our Lord and Saviour Jesus Christ, to whom be glory both now and for ever (2 Peter 3:17–18).",
    },
    wwa={
        1: "2 Peter follows 1 Peter. Simon Peter, knowing his tabernacle will soon be put off, tells believers to add virtue, knowledge, and charity to their faith, reminds them that the apostles were eyewitnesses of Christ's majesty, and points them to the sure word of prophecy (1:1-21). Chapter 2 warns of false teachers.",
        2: "Chapter 1 ended with holy men of God who spake as they were moved by the Holy Ghost (1:21). Chapter 2 warns that false teachers shall bring in damnable heresies, gives the judgments on the angels, the old world, and Sodom, and the rescue of Noah and Lot, and describes the way of Balaam (2:1-22). Chapter 3 answers the scoffers.",
        3: "Chapter 2 ended with the proverb of the dog and the sow (2:22). Chapter 3 answers scoffers who ask Where is the promise of his coming, tells of the longsuffering of the Lord and the day of the Lord, and closes with a call to grow in grace and knowledge (3:1-18). 1 John follows.",
    },
    figures={
        1: [
            ("Simon Peter", "A servant and an apostle of Jesus Christ, who will stir them up by way of remembrance while he is in this tabernacle (1:1,12-15)."),
            ("Them that have obtained like precious faith", "Told to add virtue, knowledge, temperance, patience, godliness, brotherly kindness, and charity (1:1,5-7)."),
            ("Jesus Christ", "Our Lord and Saviour, with the power and coming of whom they were made acquainted, and who shewed Peter his death was near (1:1,14,16)."),
            ("God the Father", "Gave Christ honour and glory, and a voice from the excellent glory said This is my beloved Son (1:17-18)."),
            ("The apostles", "Eyewitnesses of his majesty who heard the voice in the holy mount (1:16-18)."),
            ("Holy men of God", "Spake as they were moved by the Holy Ghost (1:21)."),
        ],
        2: [
            ("The false teachers", "Privily bring in damnable heresies, deny the Lord that bought them, and through covetousness make merchandise of believers (2:1-3,10-19)."),
            ("God and the Lord", "Spared not the angels that sinned or the old world, and knoweth how to deliver the godly out of temptations (2:4-9)."),
            ("Noah", "Saved the eighth person, a preacher of righteousness (2:5)."),
            ("Lot", "Just Lot, vexed with the filthy conversation of the wicked, was delivered (2:7-8)."),
            ("Balaam of Bosor", "Loved the wages of unrighteousness and was rebuked by the dumb ass speaking with man's voice (2:15-16)."),
        ],
        3: [
            ("Peter", "Writes this second epistle to stir up their pure minds by way of remembrance (3:1)."),
            ("The beloved", "Told to be mindful of the words of the prophets and apostles and to grow in grace (3:1-2,17-18)."),
            ("The scoffers", "Walk after their own lusts and say Where is the promise of his coming (3:3-4)."),
            ("The Lord", "Not slack concerning his promise, but longsuffering, and his day will come as a thief in the night (3:8-10)."),
            ("Paul", "Our beloved brother, who hath written things hard to be understood (3:15-16)."),
            ("The unlearned and unstable", "Wrest the scriptures unto their own destruction (3:16)."),
        ],
    },
    themes={
        1: [
            "His divine power hath given us all things that pertain unto life and godliness, and exceeding great and precious promises, that we might be partakers of the divine nature (1:3-4).",
            "They are to add to faith virtue, knowledge, temperance, patience, godliness, brotherly kindness, and charity, that they be neither barren nor unfruitful (1:5-9).",
            "They are to make their calling and election sure, for so an entrance shall be ministered unto them abundantly into the everlasting kingdom (1:10-11).",
            "The apostles were eyewitnesses of his majesty and heard the voice from the excellent glory in the holy mount (1:16-18).",
            "The word of prophecy is more sure, and no prophecy of the scripture is of any private interpretation, for holy men of God spake as they were moved by the Holy Ghost (1:19-21).",
        ],
        2: [
            "False teachers privily bring in damnable heresies, and through covetousness make merchandise of believers (2:1-3).",
            "God spared not the angels that sinned, the old world, or Sodom and Gomorrha, so the judgment of the ungodly is sure (2:4-6,9).",
            "The Lord knoweth how to deliver the godly out of temptations, as he delivered Noah and just Lot (2:5,7-9).",
            "The false teachers follow the way of Balaam, loving the wages of unrighteousness, walking after the flesh, and despising government (2:10-16).",
            "They promise liberty while being the servants of corruption, for of whom a man is overcome, of the same is he brought in bondage (2:17-22).",
        ],
        3: [
            "The word of God by which the heavens were of old and by which the world that then was perished is the same by which the present heavens and earth are reserved unto fire (3:1-7).",
            "The Lord is not slack concerning his promise, but is longsuffering, not willing that any should perish, but that all should come to repentance (3:8-9).",
            "The day of the Lord will come as a thief in the night, and the heavens shall pass away with a great noise (3:7,10).",
            "Looking for new heavens and a new earth, wherein dwelleth righteousness, believers are to be in all holy conversation and godliness and found of him in peace, without spot, and blameless (3:11-14).",
            "They are to beware lest they be led away with the error of the wicked, and grow in grace and the knowledge of our Lord and Saviour Jesus Christ (3:15-18).",
        ],
    },
    audience={
        1: "Believers who would soon lose their apostle would have heard Peter urge them to grow in faith and goodness, and to trust what the apostles saw and what the prophets wrote.",
        2: "Believers surrounded by smooth teachers who loved gain would have heard that God judges false teachers and still knows how to rescue the godly.",
        3: "Believers mocked for waiting on the Lord's return would have heard that his delay is longsuffering, and that they were to live holy lives while they looked for a new heaven and earth.",
    },
)
# -*- coding: utf-8 -*-
BOOKS["1 John"] = dict(
    file="62_1_john.json",
    summary={
        1: "John and his fellow witnesses declare that which was from the beginning, which they have heard, which they have seen with their eyes, which they have looked upon, and their hands have handled, of the Word of life, for the life was manifested, and they bear witness and shew that eternal life, which was with the Father (1 John 1:1–2). They declare it that others may have fellowship with them, and truly their fellowship is with the Father, and with his Son Jesus Christ, and they write that their joy may be full (1 John 1:3–4). This is the message that God is light, and in him is no darkness at all (1 John 1:5). If we say that we have fellowship with him and walk in darkness, we lie, but if we walk in the light, as he is in the light, we have fellowship one with another, and the blood of Jesus Christ his Son cleanseth us from all sin (1 John 1:6–7). If we say that we have no sin, we deceive ourselves, but if we confess our sins, he is faithful and just to forgive us our sins and to cleanse us from all unrighteousness, and if we say that we have not sinned, we make him a liar (1 John 1:8–10).",
        2: "John writes to his little children that they sin not, and if any man sin, we have an advocate with the Father, Jesus Christ the righteous, who is the propitiation for our sins, and not for ours only but also for the sins of the whole world (1 John 2:1–2). Hereby we do know that we know him, if we keep his commandments, and he that saith I know him and keepeth not his commandments is a liar, but whoso keepeth his word, in him is the love of God perfected, and he ought himself so to walk, even as he walked (1 John 2:3–6). It is an old commandment which they had from the beginning, and a new commandment which is true in him and in them, because the darkness is past and the true light now shineth (1 John 2:7–8). He that saith he is in the light and hateth his brother is in darkness, but he that loveth his brother abideth in the light (1 John 2:9–11). He writes to little children, fathers, and young men, because their sins are forgiven, because they have known him from the beginning, and because they have overcome the wicked one (1 John 2:12–14). They are not to love the world, neither the things in the world, for the lust of the flesh, the lust of the eyes, and the pride of life are not of the Father, and the world passeth away, but he that doeth the will of God abideth for ever (1 John 2:15–17). It is the last time, and there are many antichrists, who went out from us because they were not of us, but the believers have an unction from the Holy One (1 John 2:18–21). He is a liar that denieth that Jesus is the Christ, and whosoever denieth the Son hath not the Father, so let that abide in them which they have heard from the beginning, and this is the promise that he hath promised us, eternal life (1 John 2:22–25). The anointing which they have received of him abideth in them, so they are to abide in him, that when he shall appear they may have confidence, and not be ashamed before him at his coming (1 John 2:26–29).",
        3: "Behold, what manner of love the Father hath bestowed upon us, that we should be called the sons of God, and when he shall appear we shall be like him, for we shall see him as he is, and every man that hath this hope in him purifieth himself, even as he is pure (1 John 3:1–3). Whosoever committeth sin transgresseth also the law, and Christ was manifested to take away our sins, and whosoever abideth in him sinneth not (1 John 3:4–6). He that doeth righteousness is righteous, but he that committeth sin is of the devil, for the Son of God was manifested that he might destroy the works of the devil, and in this the children of God are manifest, and the children of the devil (1 John 3:7–10). This is the message that we should love one another, not as Cain, who was of that wicked one and slew his brother, and we know that we have passed from death unto life because we love the brethren, for whosoever hateth his brother is a murderer (1 John 3:11–15). Hereby perceive we the love of God, because he laid down his life for us, and we ought to lay down our lives for the brethren, and whoso hath this world's good and seeth his brother have need and shutteth up his bowels from him cannot be said to have the love of God dwelling in him (1 John 3:16–17). They are not to love in word, neither in tongue, but in deed and in truth, and hereby they know that they are of the truth and shall assure their hearts before him (1 John 3:18–19). If our heart condemn us, God is greater than our heart and knoweth all things, and if our heart condemn us not, we have confidence toward God and receive whatsoever we ask, because we keep his commandments (1 John 3:20–22). This is his commandment, that we should believe on the name of his Son Jesus Christ and love one another, and he that keepeth his commandments dwelleth in him, and we know that he abideth in us by the Spirit which he hath given us (1 John 3:23–24).",
        4: "Beloved, believe not every spirit, but try the spirits whether they are of God, because many false prophets are gone out into the world (1 John 4:1). Every spirit that confesseth that Jesus Christ is come in the flesh is of God, and every spirit that confesseth not is not of God, and this is that spirit of antichrist (1 John 4:2–3). Little children are of God and have overcome them, because greater is he that is in them than he that is in the world, and hereby we know the spirit of truth and the spirit of error (1 John 4:4–6). Let us love one another, for love is of God, and every one that loveth is born of God, and he that loveth not knoweth not God, for God is love (1 John 4:7–8). In this was manifested the love of God toward us, that God sent his only begotten Son into the world that we might live through him, and herein is love, not that we loved God, but that he loved us and sent his Son to be the propitiation for our sins (1 John 4:9–10). If God so loved us, we ought also to love one another, for no man hath seen God at any time, but if we love one another God dwelleth in us and his love is perfected in us (1 John 4:11–12). We know that we dwell in him because he hath given us of his Spirit, and we have seen and do testify that the Father sent the Son to be the Saviour of the world, and whosoever shall confess that Jesus is the Son of God, God dwelleth in him (1 John 4:13–16). Herein is our love made perfect, that we may have boldness in the day of judgment, for there is no fear in love, but perfect love casteth out fear (1 John 4:17–18). We love him because he first loved us, and if a man say I love God and hateth his brother, he is a liar, for this commandment have we from him, that he who loveth God love his brother also (1 John 4:19–21).",
        5: "Whosoever believeth that Jesus is the Christ is born of God, and this is the love of God, that we keep his commandments, and his commandments are not grievous (1 John 5:1–3). Whatsoever is born of God overcometh the world, and this is the victory that overcometh the world, even our faith, for who is he that overcometh the world but he that believeth that Jesus is the Son of God (1 John 5:4–5). This is he that came by water and blood, even Jesus Christ, and it is the Spirit that beareth witness, and there are three that bear witness in earth, the Spirit, and the water, and the blood, and if we receive the witness of men, the witness of God is greater (1 John 5:6–9). He that believeth on the Son of God hath the witness in himself, and this is the record, that God hath given to us eternal life, and this life is in his Son, so he that hath the Son hath life and he that hath not the Son of God hath not life (1 John 5:10–12). These things are written that they may know that they have eternal life, and this is the confidence that we have in him, that if we ask any thing according to his will, he heareth us (1 John 5:13–15). If any man see his brother sin a sin not unto death, he shall ask and God shall give him life, and all unrighteousness is sin (1 John 5:16–17). Whosoever is born of God sinneth not, but keepeth himself, and that wicked one toucheth him not, and we know that we are of God and the whole world lieth in wickedness (1 John 5:18–19). The Son of God is come and hath given us an understanding that we may know him that is true, and this is the true God and eternal life, and John ends Little children, keep yourselves from idols (1 John 5:20–21).",
    },
    wwa={
        1: "1 John follows 2 Peter. John writes of the Word of life, which they have heard, seen, and handled, that their joy may be full, and tells how to walk in the light, confessing sin and trusting the blood of Jesus Christ (1:1-10). Chapter 2 gives Christ our advocate, the commandment of love, and a warning about antichrists.",
        2: "Chapter 1 ended with confession of sin and a God who is faithful and just to forgive (1:9-10). Chapter 2 names Jesus Christ the righteous as our advocate, links knowing him with keeping his commandments and loving the brethren, and warns against loving the world and against many antichrists (2:1-29). Chapter 3 speaks of the sons of God.",
        3: "Chapter 2 ended with abiding in him until he shall appear (2:28-29). Chapter 3 shows the love the Father bestowed in calling us sons of God, contrasts the children of God and of the devil, and calls them to love in deed and in truth (3:1-24). Chapter 4 tells them to try the spirits.",
        4: "Chapter 3 ended with the Spirit he hath given us (3:24). Chapter 4 tells them to try the spirits, says God is love and sent his Son, and shows that perfect love casteth out fear and shows itself in love of the brother (4:1-21). Chapter 5 gives the faith that overcometh the world.",
        5: "Chapter 4 ended with the commandment that he who loveth God love his brother also (4:21). Chapter 5 says the faith that Jesus is the Christ overcometh the world, gives the record of eternal life in the Son, teaches confidence in prayer, and ends with the warning to keep from idols (5:1-21). 2 John follows.",
    },
    figures={
        1: [
            ("John and his fellow witnesses", "Declare what they have heard, seen with their eyes, and handled of the Word of life (1:1-3)."),
            ("The Word of life, Jesus Christ", "The life that was manifested, whose blood cleanseth us from all sin (1:1-2,7)."),
            ("God the Father, who is light", "In him is no darkness at all, and he is faithful and just to forgive us our sins (1:2,5,9)."),
            ("Those who walk in the light or in darkness", "Those who say they have fellowship with him and either walk in the light or lie (1:6-7)."),
        ],
        2: [
            ("Jesus Christ the righteous", "Our advocate with the Father and the propitiation for the sins of the whole world (2:1-2)."),
            ("The Father", "In whom the love is perfected in those that keep his word, and whom the antichrist denies (2:5,15,22-23)."),
            ("Little children, fathers, and young men", "Told that their sins are forgiven, that they have known him, and that they have overcome the wicked one (2:12-14)."),
            ("He that hateth his brother", "Is in darkness and walketh in darkness (2:9-11)."),
            ("The many antichrists", "Went out from us because they were not of us and deny that Jesus is the Christ (2:18-22)."),
        ],
        3: [
            ("The Father", "Hath bestowed such love that we should be called the sons of God (3:1)."),
            ("Jesus Christ, the Son of God", "Was manifested to take away our sins and to destroy the works of the devil, and laid down his life for us (3:5,8,16)."),
            ("The children of God", "Doers of righteousness who love the brethren and have passed from death unto life (3:2,10,14)."),
            ("Cain and his brother", "Cain was of that wicked one and slew his brother because his works were evil and his brother's righteous (3:12)."),
            ("The devil", "Sinneth from the beginning, and the children of the devil are manifest (3:8,10)."),
            ("The Spirit", "Given to us, by whom we know that he abideth in us (3:24)."),
        ],
        4: [
            ("God", "Is love, sent his only begotten Son, and loved us first (4:8-10,19)."),
            ("Jesus Christ, the Son of God", "Come in the flesh, sent to be the propitiation for our sins and the Saviour of the world (4:2,9-10,14)."),
            ("The false prophets", "Gone out into the world, and their spirit confesseth not that Jesus Christ is come in the flesh (4:1-3)."),
            ("The Spirit of God", "Given to believers, so they know that they dwell in him (4:2,13)."),
            ("The beloved brethren", "Told to love one another, and not to say I love God while hating a brother (4:7,11,20-21)."),
            ("The world", "Those who are of the world, speak of the world, and are overcome by them that are of God (4:4-5)."),
        ],
        5: [
            ("Jesus Christ, the Son of God", "He that came by water and blood, whom whosoever believeth is born of God (5:1,5-6)."),
            ("God the Father", "Gave the record of his Son and hath given us eternal life in him (5:9-11)."),
            ("The Spirit, the water, and the blood", "The three that bear witness in earth (5:6-8)."),
            ("Those born of God", "Overcome the world by faith, keep his commandments, and keep themselves (5:2-4,18)."),
            ("The brother who sinneth", "One whom a believer may ask life for, if his sin is not unto death (5:16)."),
            ("The wicked one", "Toucheth not him that is born of God, while the whole world lieth in wickedness (5:18-19)."),
        ],
    },
    themes={
        1: [
            "The writers have heard, seen, and handled the Word of life, for the life was manifested and they bear witness (1:1-3).",
            "They declare it that others may have fellowship with them, and with the Father and his Son Jesus Christ, that their joy may be full (1:3-4).",
            "God is light, and in him is no darkness at all, so those who walk in the light have fellowship and are cleansed by the blood of Jesus Christ (1:5-7).",
            "If we confess our sins, he is faithful and just to forgive us and cleanse us, and to say we have not sinned is to make him a liar (1:8-10).",
        ],
        2: [
            "If any man sin we have an advocate with the Father, Jesus Christ the righteous, who is the propitiation for our sins (2:1-2).",
            "We know that we know him if we keep his commandments, and he that saith he abideth in him ought to walk even as he walked (2:3-6).",
            "He that loveth his brother abideth in the light, and he that hateth his brother is in darkness (2:7-11).",
            "They are not to love the world, for the lust of the flesh, the lust of the eyes, and the pride of life pass away, but he that doeth the will of God abideth for ever (2:15-17).",
            "Many antichrists went out from them, but the anointing from the Holy One abides in believers, who are to continue in the Son and in the Father (2:18-27).",
        ],
        3: [
            "Now are we the sons of God, and when he shall appear we shall be like him, and every man that hath this hope in him purifieth himself (3:1-3).",
            "Whosoever abideth in him sinneth not, and he that committeth sin is of the devil, for the Son of God was manifested to destroy the works of the devil (3:4-10).",
            "They are not to be as Cain, who slew his brother, for whosoever hateth his brother is a murderer, and we have passed from death unto life because we love the brethren (3:11-15).",
            "Christ laid down his life for us, so we ought to lay down our lives for the brethren, and to help a brother in need and love in deed and in truth, not in word only (3:16-18).",
            "If our heart condemn us, God is greater than our heart, and his commandment is to believe on the name of his Son Jesus Christ and love one another (3:19-24).",
        ],
        4: [
            "They are to try the spirits whether they are of God, and every spirit that confesseth that Jesus Christ is come in the flesh is of God (4:1-6).",
            "In this was manifested the love of God toward us, that God sent his only begotten Son into the world that we might live through him (4:7-10).",
            "If we love one another, God dwelleth in us and his love is perfected in us, and he that dwelleth in love dwelleth in God (4:11-16).",
            "Perfect love casteth out fear, so believers may have boldness in the day of judgment (4:17-18).",
            "If a man say I love God and hateth his brother, he is a liar, for he that loveth not his brother whom he hath seen cannot love God whom he hath not seen (4:19-21).",
        ],
        5: [
            "Whosoever believeth that Jesus is the Christ is born of God, and the love of God is that we keep his commandments, which are not grievous (5:1-5).",
            "God hath given us eternal life, and this life is in his Son, for he that hath the Son hath life (5:6-12).",
            "These things are written that believers may know that they have eternal life (5:13).",
            "This is the confidence that if we ask any thing according to his will, he heareth us (5:14-17).",
            "Whosoever is born of God sinneth not, and the readers are told Little children, keep yourselves from idols (5:18-21).",
        ],
    },
    audience={
        1: "Believers unsettled by teachers who had left them would have heard firsthand witnesses say that the Word of life was seen and touched, and that God is light.",
        2: "A church hurt by those who had gone out would have heard Christ named as advocate, and that loving the brethren and not the world marks those who abide in him.",
        3: "Believers doubting their standing would have heard that they are already God's children, that Christ laid down his life, and that real love acts in deed and in truth.",
        4: "A church pressed by false prophets would have heard to try the spirits, and that God's love in sending his Son is the pattern for loving one another.",
        5: "Believers wanting certainty would have heard that faith in the Son overcomes the world, that eternal life is theirs, and that they may ask God with confidence.",
    },
)

BOOKS["2 John"] = dict(
    file="63_2_john.json",
    summary={
        1: "The elder writes unto the elect lady and her children, whom he loves in the truth, and not he only but also all they that have known the truth, for the truth's sake, which dwelleth in us and shall be with us for ever (2 John 1:1–2). Grace, mercy, and peace are with them from God the Father and from the Lord Jesus Christ, the Son of the Father, in truth and love (2 John 1:3). He rejoiced greatly that he found of her children walking in truth, and he beseeches her, not as though he wrote a new commandment, but that which they had from the beginning, that we love one another, and this is love, that we walk after his commandments (2 John 1:4–6). Many deceivers are entered into the world, who confess not that Jesus Christ is come in the flesh, and this is a deceiver and an antichrist (2 John 1:7). They are to look to themselves that they lose not those things which they have wrought but receive a full reward, for whosoever transgresseth and abideth not in the doctrine of Christ hath not God, but he that abideth in it hath both the Father and the Son (2 John 1:8–9). If there come any unto them and bring not this doctrine, they are not to receive him into their house, neither bid him God speed, for he that biddeth him God speed is partaker of his evil deeds (2 John 1:10–11). The elder has many things to write but will not with paper and ink, trusting to come unto them and speak face to face, that their joy may be full, and the children of her elect sister greet her (2 John 1:12–13).",
    },
    wwa={
        1: "2 John follows 1 John and is a short letter from the elder to the elect lady and her children. It joins love and truth, warns against deceivers who confess not that Jesus Christ is come in the flesh, and tells believers not to receive them into the house (1:1-13). 3 John follows.",
    },
    figures={
        1: [
            ("The elder", "Writes to the elect lady, rejoices that her children walk in truth, and hopes to speak face to face (1:1,4,12)."),
            ("The elect lady and her children", "Loved in the truth, told to love one another and walk after his commandments (1:1,5-6)."),
            ("God the Father and the Lord Jesus Christ", "The Father and the Son, from whom grace, mercy, and peace come, and whom he that abideth in the doctrine hath (1:3,9)."),
            ("The deceivers", "Many entered into the world, who confess not that Jesus Christ is come in the flesh (1:7)."),
            ("He that biddeth God speed to such a teacher", "Becomes partaker of his evil deeds (1:10-11)."),
            ("The children of her elect sister", "Send their greetings (1:13)."),
        ],
    },
    themes={
        1: [
            "The elder loves the elect lady and her children in the truth, and grace, mercy, and peace are with them in truth and love (1:1-3).",
            "This is love, that we walk after his commandments, which is the commandment they had from the beginning (1:4-6).",
            "Many deceivers are entered into the world who confess not that Jesus Christ is come in the flesh, so believers are to abide in the doctrine of Christ (1:7-9).",
            "If there come any who bring not this doctrine, they are not to receive him into their house or bid him God speed (1:10-11).",
            "The elder hopes to speak face to face, that their joy may be full, and warns them to look to themselves that they receive a full reward (1:8,12-13).",
        ],
    },
    audience={
        1: "A house church that welcomed travelling teachers would have heard to keep their love joined to the truth about Christ, and to refuse hospitality to those who denied it.",
    },
)

BOOKS["3 John"] = dict(
    file="64_3_john.json",
    summary={
        1: "The elder writes unto the wellbeloved Gaius, whom he loves in the truth, wishing above all things that he may prosper and be in health, even as his soul prospereth (3 John 1:1–2). He rejoiced greatly when the brethren came and testified of the truth that is in Gaius, even as he walketh in the truth, for he hath no greater joy than to hear that his children walk in truth (3 John 1:3–4). Gaius doeth faithfully whatsoever he doeth to the brethren and to strangers, who have borne witness of his charity before the church, and he will do well to bring them forward on their journey after a godly sort, because for his name's sake they went forth, taking nothing of the Gentiles, so we ought to receive such, that we might be fellowhelpers to the truth (3 John 1:5–8). The elder wrote unto the church, but Diotrephes, who loveth to have the preeminence among them, receiveth us not, and if the elder comes, he will remember his deeds, prating against us with malicious words, and neither doth he himself receive the brethren, and forbiddeth them that would, and casteth them out of the church (3 John 1:9–10). Gaius is told to follow not that which is evil but that which is good, for he that doeth good is of God, but he that doeth evil hath not seen God, and Demetrius hath good report of all men and of the truth itself (3 John 1:11–12). The elder had many things to write but will not with ink and pen, trusting shortly to see Gaius and speak face to face, and he closes with peace and greetings from the friends (3 John 1:13–14).",
    },
    wwa={
        1: "3 John follows 2 John and is the elder's letter to the wellbeloved Gaius. It praises him for walking in truth and for kindness to the brethren and strangers, tells of Diotrephes who loveth the preeminence, and commends Demetrius (1:1-14). Jude follows.",
    },
    figures={
        1: [
            ("The elder", "Writes to Gaius, rejoices that his children walk in truth, and will remember the deeds of Diotrephes (1:1,4,10)."),
            ("Gaius", "The wellbeloved, who walks in the truth and doeth faithfully to the brethren and to strangers (1:1,3,5)."),
            ("The brethren and strangers", "They testified of Gaius' truth and went forth for his name's sake, taking nothing of the Gentiles (1:3,5-7)."),
            ("Diotrephes", "Loveth to have the preeminence, receiveth not the elder, prates with malicious words, and casteth them out of the church (1:9-10)."),
            ("Demetrius", "Hath good report of all men and of the truth itself (1:12)."),
            ("The church", "Before which Gaius's charity was witnessed, and from which Diotrephes casts out those who would receive the brethren (1:6,9-10)."),
        ],
    },
    themes={
        1: [
            "The elder has no greater joy than to hear that his children walk in truth, and Gaius walketh in the truth (1:3-4).",
            "Gaius is to bring the brethren forward on their journey, for we ought to receive such, that we might be fellowhelpers to the truth (1:5-8).",
            "Diotrephes loveth to have the preeminence, receiveth not the elder, and casteth out those who would receive the brethren (1:9-10).",
            "Gaius is told to follow not that which is evil but that which is good, for he that doeth good is of God, and Demetrius hath good report (1:11-12).",
            "The elder hopes shortly to see Gaius and speak face to face, and sends peace and greetings from the friends (1:13-14).",
        ],
    },
    audience={
        1: "A host who opened his home to travelling believers would have heard the elder's thanks, and a church under a leader who loved first place would have heard what to follow and what to refuse.",
    },
)

BOOKS["Jude"] = dict(
    file="65_jude.json",
    summary={
        1: "Jude, the servant of Jesus Christ and brother of James, writes to them that are sanctified by God the Father, and preserved in Jesus Christ, called, with mercy, peace, and love multiplied (Jude 1:1–2). When he gave all diligence to write of the common salvation, it was needful to exhort them to earnestly contend for the faith which was once delivered unto the saints, because certain men crept in unawares, ungodly men, turning the grace of our God into lasciviousness and denying the only Lord God and our Lord Jesus Christ (Jude 1:3–4). He puts them in remembrance that the Lord, having saved the people out of the land of Egypt, afterward destroyed them that believed not, and that the angels which kept not their first estate are reserved in everlasting chains under darkness, and Sodom and Gomorrha and the cities about them are set forth for an example, suffering the vengeance of eternal fire (Jude 1:5–7). These dreamers defile the flesh, despise dominion, and speak evil of dignities, yet Michael the archangel, when contending with the devil about the body of Moses, durst not bring against him a railing accusation, but said The Lord rebuke thee (Jude 1:8–10). They have gone in the way of Cain, ran greedily after the error of Balaam for reward, and perished in the gainsaying of Core, and they are spots in the feasts of charity, clouds without water, trees whose fruit withereth, raging waves of the sea, and wandering stars (Jude 1:11–13). Enoch, the seventh from Adam, prophesied that the Lord cometh with ten thousands of his saints to execute judgment upon all, and these are murmurers and complainers, walking after their own lusts (Jude 1:14–16). The beloved are to remember the words of the apostles, who told them there should be mockers in the last time, who separate themselves, sensual, having not the Spirit (Jude 1:17–19). They are to build up themselves on their most holy faith, pray in the Holy Ghost, keep themselves in the love of God, look for the mercy of our Lord Jesus Christ unto eternal life, have compassion of some, and save others with fear, pulling them out of the fire (Jude 1:20–23). Unto him that is able to keep them from falling and to present them faultless before the presence of his glory with exceeding joy, to the only wise God our Saviour, be glory and majesty, dominion and power, both now and ever (Jude 1:24–25).",
    },
    wwa={
        1: "Jude follows 3 John and is the last of the general letters before Revelation. Jude urges believers to contend earnestly for the faith once delivered unto the saints, gives examples of judgment on the ungodly, and closes with a call to keep themselves in the love of God and praise to him who is able to keep them from falling (1:1-25). Revelation follows.",
    },
    figures={
        1: [
            ("Jude", "The servant of Jesus Christ and brother of James, who exhorts them to earnestly contend for the faith (1:1,3)."),
            ("The sanctified and called", "Preserved in Jesus Christ, told to build up themselves, pray in the Holy Ghost, and keep themselves in the love of God (1:1,20-21)."),
            ("The ungodly men crept in unawares", "Turn the grace of God into lasciviousness, deny the only Lord God, defile the flesh, and walk after their own lusts (1:4,8,16)."),
            ("Michael the archangel", "Durst not bring a railing accusation against the devil but said The Lord rebuke thee (1:9)."),
            ("Enoch", "The seventh from Adam, who prophesied that the Lord cometh with ten thousands of his saints (1:14-15)."),
            ("The Lord", "Destroyed them that believed not, reserves the angels in chains, and is able to keep them from falling (1:5-6,24)."),
        ],
    },
    themes={
        1: [
            "Jude exhorts them to earnestly contend for the faith which was once delivered unto the saints, because ungodly men crept in unawares (1:3-4).",
            "The ungodly turn the grace of our God into lasciviousness and deny the only Lord God and our Lord Jesus Christ (1:4).",
            "The Lord destroyed those who believed not, kept the angels in chains, and made Sodom and Gomorrha an example of the vengeance of eternal fire (1:5-16).",
            "The beloved are to keep themselves in the love of God, and he is able to keep them from falling (1:20-21,24-25).",
            "They are to have compassion of some, making a difference, and save others with fear, pulling them out of the fire (1:22-23).",
        ],
    },
    audience={
        1: "Believers whose church had been quietly infiltrated would have heard a plain warning with old examples, and a call to stay in the love of God and rescue the wavering.",
    },
)


AUTHORS = {
    "1 Peter": "Peter the apostle, writing with Silvanus (1 Peter 1:1; 5:12).",
    "2 Peter": "Simon Peter, a servant and an apostle of Jesus Christ (2 Peter 1:1).",
    "1 John": "Traditionally associated with John the apostle; the letter itself does not name its writer (1 John 1:1-3).",
    "2 John": "The elder, traditionally identified with John the apostle (2 John 1:1).",
    "3 John": "The elder, traditionally identified with John the apostle (3 John 1:1).",
    "Jude": "Jude, a servant of Jesus Christ and brother of James, traditionally understood as a brother of Jesus (Jude 1:1).",
}
KEY_VERSES = {"1 Peter": "1 Peter 1:3"}


def apply_chapter_insights():
    for book, info in BOOKS.items():
        path = ROOT / "chapter_insights" / info["file"]
        data = load(path)
        for n in info["summary"]:
            entry = data[f"{book} {n}"]
            entry["summary"] = info["summary"][n]
            entry["whereWeAre"] = info["wwa"][n]
            entry["keyFigures"] = [{"name": a, "role": b} for a, b in info["figures"][n]]
            if len(entry["keyThemes"]) != len(info["themes"][n]):
                raise SystemExit(f"{book} {n}: theme count mismatch")
            for theme, explanation in zip(entry["keyThemes"], info["themes"][n]):
                theme["explanation"] = explanation
                refs = []
                for ref in theme["references"]:
                    refs.extend(json.loads(ref) if ref.startswith("[") else [ref])
                theme["references"] = refs
            if len(entry["whereWeAre"]) > 600 or len(entry["keyFigures"]) > 6:
                raise SystemExit(f"{book} {n}: WWA {len(entry['whereWeAre'])} chars or too many figures")
        if len([k for k in data if k.startswith(book + " ")]) != len(info["summary"]):
            raise SystemExit(f"{book}: chapter count mismatch")
        save(path, data)
        print(f"Updated {path.relative_to(ROOT)}")


def apply_chapter_context():
    path = ROOT / "chapter_context" / "41_peter_jude.json"
    data = load(path)
    for book, info in BOOKS.items():
        for n, text in info["audience"].items():
            data[f"{book} {n}"]["audience"] = text
    for entry in data["1 John 1"]["culture"]:
        entry["text"] = entry["text"].replace("‘sons of light’ and ‘sons of darkness.’", "the sons of light and the sons of darkness.")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


def apply_historical_moments():
    old = " The letter's authorship was questioned in the early church."
    old2 = " The letter’s authorship was questioned in the early church."
    for name in glob.glob(str(ROOT / "historical_moments" / "*.json")):
        path = Path(name)
        data = load(path)
        if "2 Peter 1" in data and ("authorship" in data["2 Peter 1"]):
            data["2 Peter 1"] = data["2 Peter 1"].replace(old, "").replace(old2, "")
            save(path, data)
            print(f"Updated {path.relative_to(ROOT)}")


def unquote(text):
    return re.sub(r"(?<![A-Za-z])'([^']+?)'(?![A-Za-z])", r"\1", text)


def apply_book_overviews():
    path = ROOT / "book_overviews" / "09_general_letters_revelation.json"
    data = load(path)
    for book in BOOKS:
        entry = data[book]
        entry["author"] = AUTHORS[book]
        if book in KEY_VERSES:
            entry["keyVerse"] = KEY_VERSES[book]
        for key in ("audience", "purpose", "theme", "summary"):
            entry[key] = unquote(entry[key])
        for figure in entry["keyFigures"]:
            figure["name"] = unquote(figure["name"])
            figure["description"] = unquote(figure["description"])
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_REWORDS = [
    ("To those who reject Him, He is “The stone", "To those who reject him, he is “The stone"),
    ("” He “did no sin", "” Christ “did no sin"),
    ("Instead, He trusted God.", "Instead, he trusted God."),
    ("He has given them “exceeding great", "God has given them “exceeding great"),
    ("He did not spare the ancient world", "God did not spare the ancient world"),
    ("And He turned Sodom", "And he turned Sodom"),
    ("when He appears", "when he appears"),
    ("and He in them", "and he in them"),
    ("the Spirit He has given", "the Spirit he has given"),
    ("afterward He destroyed", "afterward he destroyed"),
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
                parts[i] = re.sub(r"(?<=[a-z,;:—] )(His|Him|Himself)\b", lambda m: m.group(0).lower(), part)
        out.append(prefix + "".join(parts))
    return "\n".join(out)


def apply_story_fixes():
    path = ROOT / "book_content" / "09_general_letters_revelation.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("\n# 1 Peter") + 1
    end = text.index("\n# Revelation") + 1
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
    apply_historical_moments()
    apply_book_overviews()
    apply_story_fixes()
