#!/usr/bin/env python3
"""Apply the completed editorial review for John to source content only."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


WWA = {
    1: ("Luke's Gospel ended with the disciples worshiping the ascended Jesus and waiting in "
        "Jerusalem with great joy (Luke 24:50-53). John opens his own account from a different "
        "starting point, going back before creation itself: the eternal Word who was with God and "
        "was God becomes flesh, John the Baptist testifies that Jesus is the Lamb of God, and the "
        "first disciples, Andrew, Simon, Philip, and Nathanael, begin following him (1:1-51). That "
        "gathering of the first witnesses leads into chapter 2's first public sign at a wedding in "
        "Cana."),
    2: ("Chapter 1 ended with Jesus promising Nathanael that he would see heaven opened (1:50-51). "
        "Chapter 2 shows the first of John's signs fulfilling that promise: Jesus turns water into "
        "wine at a wedding in Cana, causing his disciples to believe, then travels to Jerusalem at "
        "Passover and drives merchants from the temple, speaking of raising its destroyed structure "
        "in three days (2:1-25). That early clash over the temple sets up chapter 3's private "
        "conversation with a member of the very council that oversees it, Nicodemus."),
    3: ("Chapter 2 ended with Jesus not entrusting himself to people whose belief rested only on "
        "seeing signs, since he knew what was in their hearts (2:23-25). Chapter 3 shows one such "
        "believer going deeper: Nicodemus comes to Jesus by night and is told he must be born again, "
        "and the chapter closes with John the Baptist insisting that his own ministry must decrease "
        "while Jesus' increases (3:1-36). That theme of Jesus growing while others step back "
        "continues in chapter 4, where Jesus leaves Judea and meets a Samaritan woman instead."),
    4: ("Chapter 3 ended with John the Baptist declaring that whoever believes in the Son has "
        "everlasting life (3:36). Chapter 4 shows that life reaching an unlikely recipient: a "
        "Samaritan woman at Jacob's well believes after Jesus reveals knowledge of her own life, her "
        "whole town comes to faith through her testimony, and a Galilean official believes Jesus' "
        "word alone that his dying son will live (4:1-54). That pattern of faith growing from a "
        "single word continues in chapter 5, where a healed man's recovery becomes evidence in a "
        "harder dispute."),
    5: ("Chapter 4 ended with a royal official believing Jesus' word and his whole household coming "
        "to faith once the boy recovered (4:50-53). Chapter 5 tests belief in a harder setting: "
        "Jesus heals a man disabled for thirty-eight years at the pool of Bethesda on the Sabbath, "
        "and when Jewish authorities object, he defends his authority as inseparable from the "
        "Father's own work of giving life and judging (5:1-47). That claim to divine authority sets "
        "up chapter 6's sign of multiplying bread to feed a hungry crowd."),
    6: ("Chapter 5 ended with Jesus challenging people who search the Scriptures yet refuse to come "
        "to him for life (5:39-47). Chapter 6 offers that life in a visible sign: Jesus feeds a crowd "
        "of thousands, walks on the sea to his disciples at night, and then teaches in Capernaum "
        "that he himself is the bread of life, a saying so hard that many disciples leave while "
        "Peter speaks for the Twelve in staying (6:1-71). That division carries into chapter 7, "
        "where Jesus' own brothers do not yet believe in him either."),
    7: ("Chapter 6 ended with Peter confessing that the Twelve have nowhere else to go, since Jesus "
        "has the words of eternal life, even though one of them would betray him (6:66-71). Chapter "
        "7 shows that same mixed response spreading wider: Jesus' own brothers urge him to show "
        "himself publicly, he goes up to the Feast of Tabernacles privately instead, and his "
        "teaching in the temple divides the crowd over whether he is the Messiah (7:1-52). That "
        "division reaches its sharpest point in chapter 8, where the dispute turns to judgment and "
        "mercy."),
    8: ("Chapter 7 ended with Nicodemus asking whether the law permits judging a man without first "
        "giving him a hearing (7:50-51). Chapter 8 opens with that question tested on a woman "
        "accused of adultery, whom Jesus declines to condemn, before he calls himself the light of "
        "the world and debates his identity with opponents who ultimately take up stones against him "
        "(8:1-59). That mounting hostility sets up chapter 9's healing of a blind man, which becomes "
        "its own trial-like interrogation."),
    9: ("Chapter 8 ended with opponents trying to stone Jesus after his claim, \"Before Abraham was, "
        "I am\" (8:58-59). Chapter 9 shows that same hostility turned on an ordinary man instead: "
        "Jesus heals someone blind from birth, and the man's growing honesty under repeated "
        "questioning leads the Pharisees to expel him from the synagogue even as Jesus himself seeks "
        "him out (9:1-41). That image of true and false sight leads directly into chapter 10's "
        "picture of a shepherd whose sheep recognize his voice."),
    10: ("Chapter 9 ended with Jesus saying that people who claim to see yet refuse to see him "
         "remain guilty in their blindness (9:39-41). Chapter 10 explains that contrast with the "
         "image of a shepherd: Jesus calls himself the good shepherd who lays down his life for the "
         "sheep, and at the Feast of Dedication he tells opponents who press him for a plain answer "
         "that he and the Father are one, provoking another attempt to stone him (10:1-42). That "
         "claim to unity with the Father is tested directly in chapter 11, where Jesus delays going "
         "to a dying friend."),
    11: ("Chapter 10 ended with many believing in Jesus across the Jordan, remembering that "
         "everything John the Baptist had said about him was true (10:40-42). Chapter 11 puts that "
         "developing faith to its hardest test: Jesus deliberately delays going to the dying "
         "Lazarus, arrives after he has been four days in the tomb, and calls him back to life, a "
         "sign so public that the chief priests and Pharisees begin plotting Jesus' own death to "
         "stop it (11:1-57). That plot sets up chapter 12's account of his last journey toward it, "
         "beginning with his own anointing for burial."),
    12: ("Chapter 11 ended with the council deciding that Jesus must die, so that he no longer moved "
         "about publicly among the Jews (11:53-54). Chapter 12 shows him returning anyway: Mary "
         "anoints Jesus for burial at Bethany six days before Passover, he enters Jerusalem to "
         "crowds waving palm branches, and when Greek pilgrims ask to see him he speaks of a grain "
         "of wheat that must die to bear fruit, ending with a summary of why many still do not "
         "believe (12:1-50). That reflection on unbelief gives way in chapter 13 to Jesus' own "
         "private farewell meal with the disciples who did believe."),
    13: ("Chapter 12 ended with Jesus explaining that he came to save the world, not to judge it, "
         "even as many continued not to believe (12:44-50). Chapter 13 turns to those who did "
         "believe: before the Passover, Jesus washes his disciples' feet as an example of humble "
         "service, identifies Judas as his betrayer, and gives a new commandment to love one "
         "another, even predicting that Peter will deny him three times that night (13:1-38). That "
         "prediction of departure and denial opens the farewell discourse chapter 14 continues."),
    14: ("Chapter 13 ended with Jesus telling Peter he cannot yet follow where Jesus is going, right "
         "after predicting Peter's three denials (13:36-38). Chapter 14 answers that coming absence "
         "with comfort: Jesus promises a place in his Father's house, says he himself is the way, "
         "the truth, and the life, and promises another Comforter, the Holy Spirit, who will remain "
         "with the disciples after he is gone (14:1-31). That promise continues in chapter 15's "
         "image of a vine that keeps bearing fruit even after the gardener prunes it."),
    15: ("Chapter 14 ended with Jesus telling the disciples to rise and go, since his time with them "
         "was ending (14:30-31). Chapter 15 pictures how they will keep bearing fruit without him "
         "physically present: Jesus calls himself the true vine and his disciples the branches, "
         "commands them to love one another as he has loved them, and warns that the world's hatred "
         "toward them will mirror the hatred it showed him first (15:1-27). That warning sets up "
         "chapter 16's fuller explanation of the persecution still to come."),
    16: ("Chapter 15 ended with Jesus warning that the world would hate his disciples without a "
         "cause, just as it had hated him (15:18-25). Chapter 16 explains why that hatred is still "
         "worth facing: Jesus warns of coming exclusion and persecution, promises that his departure "
         "will bring the Comforter who guides the disciples into truth, and compares their coming "
         "grief to childbirth pain that will turn into joy (16:1-33). That promise of joy leads "
         "straight into chapter 17's prayer, where Jesus asks the Father to keep that same joy "
         "complete in them."),
    17: ("Chapter 16 ended with Jesus telling the disciples to take courage, since he has already "
         "overcome the world (16:33). Chapter 17 shows him turning from speaking to them to praying "
         "for them: Jesus asks the Father to glorify him, prays that the disciples he is leaving "
         "behind be kept and made holy, and extends that same prayer to everyone who will later "
         "believe through their message (17:1-26). That prayer gives way in chapter 18 to the night "
         "he is taken from them by force."),
    18: ("Chapter 17 ended with Jesus praying that his followers would be with him one day to see "
         "his glory (17:24-26). Chapter 18 shows that prayer interrupted by arrest: Judas arrives "
         "with soldiers in a garden across the Kidron, Peter strikes a servant's ear before Jesus "
         "restrains him, Jesus is questioned by Annas while Peter denies him three times nearby, and "
         "before Pilate he says his kingdom is not of this world even as the crowd demands Barabbas "
         "instead (18:1-40). That demand sets up chapter 19's account of the crucifixion Pilate "
         "ultimately allows."),
    19: ("Chapter 18 ended with Pilate offering to release Jesus and the crowd shouting for Barabbas "
         "instead (18:39-40). Chapter 19 carries that choice to its conclusion: Pilate has Jesus "
         "flogged, mocked, and finally crucified between two others, Jesus entrusts his mother to "
         "the beloved disciple from the cross, and after he dies a soldier's spear confirms it "
         "before Joseph of Arimathea and Nicodemus bury him in a nearby garden tomb (19:1-42). That "
         "burial sets up chapter 20's discovery, after the Sabbath, that the tomb stands empty."),
    20: ("Chapter 19 ended with Joseph of Arimathea and Nicodemus laying Jesus' body in a new tomb "
         "close to where he had been crucified (19:41-42). Chapter 20 answers that burial directly: "
         "Mary Magdalene finds the tomb empty while it is still dark, meets the risen Jesus in the "
         "garden, and that evening Jesus appears to the gathered disciples and, a week later, to the "
         "previously absent Thomas, who confesses him as Lord and God (20:1-31). John then states "
         "his purpose in writing, which chapter 21's epilogue adds one more appearance to confirm."),
    21: ("Chapter 20 closed with John explaining that he wrote these signs so readers might believe "
         "and have life in Jesus' name (20:30-31). John's epilogue adds one more appearance: seven "
         "disciples fish all night without success until the risen Jesus directs them to a huge "
         "catch, then restores Peter by asking three times whether he loves him and commanding him "
         "to feed his sheep, before the beloved disciple is identified as the witness behind this "
         "Gospel (21:1-25). That testimony is where the book of Acts will pick up, describing what "
         "the same witnesses did next."),
}

KEY_FIGURES = {
    1: [
        ("Jesus",
         "Is identified as the eternal Word made flesh, is named the Lamb of God by John the "
         "Baptist, and calls his first disciples, including Philip and, through Andrew and Philip, "
         "Simon and Nathanael (1:1-51)."),
        ("John the Baptist",
         "Denies being the Messiah, Elijah, or the Prophet, and instead points two of his own "
         "disciples toward Jesus as the Lamb of God (1:19-34,35-37)."),
        ("Andrew",
         "One of John's former disciples who follows Jesus first, then brings his brother Simon to "
         "meet him (1:40-42)."),
        ("Simon Peter",
         "Is brought to Jesus by his brother Andrew and is given the new name Cephas, meaning a "
         "stone (1:41-42)."),
        ("Philip",
         "Is called directly by Jesus and then finds Nathanael to tell him about the one Moses and "
         "the prophets wrote about (1:43-45)."),
        ("Nathanael",
         "Doubts that anything good can come from Nazareth, but confesses Jesus as the Son of God "
         "and King of Israel once Jesus reveals he saw him under the fig tree (1:46-49)."),
    ],
    2: [
        ("Jesus",
         "Turns water into wine at a wedding in Cana, his first sign, then drives merchants from "
         "the Jerusalem temple and speaks of raising the temple of his own body in three days "
         "(2:1-22)."),
        ("Jesus' mother",
         "Tells Jesus the wedding has run out of wine and instructs the servants to do whatever he "
         "says (2:3-5)."),
        ("Servants",
         "Fill the stone jars with water at Jesus' direction and then serve it to the guests as "
         "wine (2:7-8)."),
        ("Disciples",
         "Witness the sign at Cana and believe in Jesus, and later remember his saying about the "
         "temple after his resurrection (2:11,22)."),
        ("Temple merchants and money changers",
         "Conduct business in the temple courts until Jesus drives them out with a whip of cords, "
         "accusing them of making his Father's house a marketplace (2:14-16)."),
    ],
    3: [
        ("Jesus",
         "Tells Nicodemus he must be born again to see God's kingdom and explains that God gave his "
         "only Son so that whoever believes in him would have everlasting life (3:1-21)."),
        ("Nicodemus",
         "A Pharisee and ruler of the Jews who comes to Jesus by night and struggles to understand "
         "how a grown man can be born again (3:1-9)."),
        ("John the Baptist",
         "Tells his own disciples that Jesus must increase while he decreases, rejoicing rather "
         "than competing when crowds go to Jesus instead (3:25-30)."),
        ("John's disciples",
         "Report to John that Jesus is baptizing and that everyone is going to him instead (3:26)."),
        ("Moses",
         "Cited by Jesus as the one who lifted up the bronze serpent in the wilderness, a picture of "
         "the Son of man being lifted up to give life (3:14)."),
    ],
    4: [
        ("Jesus",
         "Offers a Samaritan woman living water, reveals knowledge of her past, and heals a royal "
         "official's son from a distance by his word alone (4:1-54)."),
        ("Samaritan woman",
         "Comes to draw water at Jacob's well, is told everything she ever did, and leaves her "
         "water jar to tell her whole town about Jesus (4:7-29)."),
        ("Samaritan townspeople",
         "Come out to see Jesus because of the woman's testimony, then believe for themselves after "
         "hearing him (4:39-42)."),
        ("Royal official",
         "Asks Jesus to come heal his dying son, then believes Jesus' word alone and starts home "
         "before learning his son has already recovered (4:46-50)."),
        ("Official's son",
         "Recovers from his fever at the exact hour Jesus spoke the word of healing, though he is at "
         "a distance from Jesus the whole time (4:51-53)."),
        ("Jesus' disciples",
         "Return from buying food to find Jesus talking with the Samaritan woman, and are later "
         "told that the fields are already ripe for a spiritual harvest (4:27,35)."),
    ],
    5: [
        ("Jesus",
         "Heals a man disabled for thirty-eight years at the pool of Bethesda and defends the "
         "healing by claiming his own work is inseparable from the Father's (5:1-30)."),
        ("Disabled man",
         "Has been unable to walk for thirty-eight years and is healed by Jesus at the pool of "
         "Bethesda on the Sabbath (5:5-9)."),
        ("Judean authorities",
         "Challenge Jesus over healing on the Sabbath and over his claim to work alongside God as "
         "his Father, intensifying their opposition (5:16-18)."),
        ("John the Baptist",
         "Cited by Jesus as an earlier witness to his identity, though Jesus says his own works "
         "testify to more than John's words alone did (5:33-36)."),
        ("Moses",
         "Invoked by Jesus as the very one whose writings will accuse his listeners, since they "
         "refuse to believe the one Moses wrote about (5:45-47)."),
    ],
    6: [
        ("Jesus",
         "Feeds a crowd of thousands, walks on the sea to his disciples, and teaches that he "
         "himself is the bread of life, a saying that costs him many followers (6:1-71)."),
        ("Large crowd",
         "Eats the bread Jesus multiplies and tries to make him king by force, then later follows "
         "him across the lake seeking more signs (6:14-15,24-26)."),
        ("Disciples and the Twelve",
         "Witness the feeding and the walking on water, and later split over Jesus' hard teaching "
         "about eating his flesh and drinking his blood (6:19,60-66)."),
        ("Simon Peter",
         "Speaks for the Twelve when Jesus asks if they too will leave, confessing that Jesus alone "
         "has the words of eternal life (6:67-69)."),
        ("Judas son of Simon Iscariot",
         "Is named by Jesus as the one who will betray him, even while still counted among the "
         "Twelve (6:70-71)."),
        ("Moses",
         "Invoked by the crowd as the one who gave their ancestors manna, a comparison Jesus "
         "corrects by saying it was his Father, not Moses, who gave the true bread from heaven "
         "(6:31-32)."),
    ],
    7: [
        ("Jesus",
         "Goes up to the Feast of Tabernacles privately after refusing his brothers' demand for a "
         "public display, then teaches openly in the temple and invites the thirsty to come to him "
         "(7:1-39)."),
        ("Jesus' brothers",
         "Urge Jesus to go show himself publicly at the feast, a request John notes they make "
         "without yet believing in him themselves (7:3-5)."),
        ("Crowds and Judean authorities",
         "Debate whether Jesus is a good man, a deceiver, or the Messiah, while authorities look for "
         "a way to arrest him (7:12-13,25-27,40-43)."),
        ("Temple officers",
         "Are sent to arrest Jesus but return empty-handed, telling the chief priests and Pharisees "
         "that no man ever spoke like this man (7:32,45-46)."),
        ("Nicodemus",
         "Asks his fellow council members whether the law judges a man without first hearing him, "
         "drawing their scorn in return (7:50-52)."),
    ],
    8: [
        ("Jesus",
         "Declines to condemn a woman accused of adultery, calls himself the light of the world, "
         "and tells opponents that before Abraham was, he is (8:1-59)."),
        ("Woman accused of adultery",
         "Is brought to Jesus by scribes and Pharisees as a test, and is told by Jesus to go and sin "
         "no more once her accusers leave (8:3-11)."),
        ("Scribes and Pharisees",
         "Bring the accused woman to Jesus to test him, then leave one by one once he tells whoever "
         "is without sin to cast the first stone (8:3-9)."),
        ("Pharisees and other opponents",
         "Debate Jesus' testimony about himself, his parentage, and his claim to exist before "
         "Abraham, ultimately picking up stones to throw at him (8:13,19,48,58-59)."),
        ("Abraham",
         "Claimed as their father by Jesus' opponents, who are told that doing Abraham's works, not "
         "merely claiming his descent, is what would prove it (8:39-40)."),
        ("The Father",
         "Repeatedly invoked by Jesus as the one who sent him and who testifies on his behalf "
         "(8:16-18,42)."),
    ],
    9: [
        ("Jesus",
         "Heals a man born blind by making mud and sending him to wash in the pool of Siloam, then "
         "later finds the expelled man and receives his confession of faith (9:1-7,35-38)."),
        ("Man born blind",
         "Receives his sight, grows bolder under repeated interrogation about how it happened, and "
         "is finally cast out of the synagogue for defending Jesus (9:8-34)."),
        ("Pharisees",
         "Interrogate the healed man and his parents over and over because the healing happened on "
         "the Sabbath, and expel the man when he will not back down (9:13-34)."),
        ("Man's parents",
         "Confirm that their son was born blind but refuse to say how he was healed, afraid of "
         "being expelled from the synagogue themselves (9:18-23)."),
        ("Disciples",
         "Ask Jesus whose sin caused the man's blindness, prompting his answer that the man was "
         "born blind so God's works could be displayed in him (9:1-3)."),
    ],
    10: [
        ("Jesus",
         "Calls himself the gate for the sheep and the good shepherd who lays down his life for "
         "them, then tells opponents at the Feast of Dedication that he and the Father are one "
         "(10:1-42)."),
        ("Sheep",
         "Hear the shepherd's voice and follow him, pictured as secure in his hand and his Father's, "
         "unable to be snatched away by anyone (10:3-5,27-29)."),
        ("Hired hand and thieves",
         "Images Jesus uses for those who abandon or exploit the sheep, in contrast to the good "
         "shepherd who actually lays down his life for them (10:1,10,12-13)."),
        ("Judean opponents",
         "Press Jesus to say plainly whether he is the Christ, then try to stone and arrest him once "
         "he claims unity with the Father (10:24,31,39)."),
        ("John the Baptist",
         "Remembered by believers across the Jordan, who note that everything John said about Jesus "
         "turned out to be true (10:41-42)."),
    ],
    11: [
        ("Jesus",
         "Deliberately delays going to the dying Lazarus, weeps with the mourners once he arrives, "
         "and calls Lazarus out of the tomb alive after four days (11:1-44)."),
        ("Lazarus",
         "Dies and lies four days in the tomb before Jesus calls him back to life, becoming the sign "
         "that finally moves the authorities to plot Jesus' death (11:14,43-44,53)."),
        ("Martha",
         "Tells Jesus her brother would not have died if he had come sooner, yet confesses Jesus as "
         "the Christ, the Son of God, even before Lazarus is raised (11:21-27)."),
        ("Mary",
         "Falls at Jesus' feet weeping over her brother's death, moving Jesus himself to weep "
         "alongside her (11:32-35)."),
        ("Caiaphas",
         "Argues to the council that it is better for one man to die for the people, a statement "
         "John says unintentionally prophesies Jesus' death (11:49-51)."),
        ("Chief priests and Pharisees",
         "Convene a council after the raising of Lazarus and decide, following Caiaphas's argument, "
         "that Jesus must die (11:47-53)."),
    ],
    12: [
        ("Jesus",
         "Is anointed for burial at Bethany, enters Jerusalem to a crowd's praise, and tells Greek "
         "pilgrims that his hour to be glorified through death has finally come (12:1-36)."),
        ("Mary of Bethany",
         "Anoints Jesus' feet with a pound of costly perfume and wipes them with her hair, an act "
         "Jesus defends as preparation for his burial (12:3-7)."),
        ("Martha and Lazarus",
         "Host the supper at Bethany where Martha serves and the living, raised Lazarus sits at the "
         "table as a witness in his own right (12:2)."),
        ("Judas Iscariot",
         "Objects to the cost of Mary's perfume, though John notes he says so not out of concern "
         "for the poor but because he used to steal from the money bag (12:4-6)."),
        ("Crowds",
         "Spread palm branches and shout praise as Jesus enters Jerusalem, hailing him as the King "
         "of Israel (12:12-13)."),
        ("Some Greeks",
         "Ask Philip, who tells Andrew, for a chance to see Jesus, prompting his words about a grain "
         "of wheat that must die to bear fruit (12:20-24)."),
    ],
    13: [
        ("Jesus",
         "Washes his disciples' feet as an example, identifies Judas as his betrayer, gives a new "
         "commandment to love one another, and predicts Peter's three denials (13:1-38)."),
        ("Simon Peter",
         "Resists having his feet washed, then asks to be washed completely, and promises to lay "
         "down his life for Jesus only to be told he will deny him three times (13:6-9,37-38)."),
        ("Judas Iscariot",
         "Is identified as the betrayer when Jesus hands him a piece of bread, then leaves the meal "
         "immediately into the night (13:26-30)."),
        ("Beloved disciple",
         "Reclines close to Jesus at the table and, at Peter's signal, asks him who the betrayer is "
         "(13:23-25)."),
        ("Other disciples",
         "Watch Jesus wash their feet without yet understanding its meaning and receive his new "
         "commandment to love one another (13:12-17,34-35)."),
    ],
    14: [
        ("Jesus",
         "Comforts his troubled disciples with the promise of his Father's house, calls himself the "
         "way, the truth, and the life, and promises the Comforter will remain with them (14:1-31)."),
        ("Thomas",
         "Asks how the disciples can know the way to where Jesus is going, prompting Jesus' "
         "statement that he himself is the way, the truth, and the life (14:5-6)."),
        ("Philip",
         "Asks Jesus to show them the Father, prompting Jesus' answer that whoever has seen him has "
         "already seen the Father (14:8-9)."),
        ("Judas (not Iscariot)",
         "Asks why Jesus will show himself to the disciples but not to the world, prompting Jesus' "
         "teaching that obedience, not spectacle, is how his presence is known (14:22-24)."),
        ("The Father",
         "Identified throughout the chapter as the one Jesus is going to, the one he represents, and "
         "the one who will send the Comforter in his name (14:2,9,26)."),
        ("Holy Spirit (the Comforter)",
         "Promised by Jesus as another Comforter who will remain with the disciples forever, "
         "teaching them and bringing everything Jesus said back to their memory (14:16-17,26)."),
    ],
    15: [
        ("Jesus",
         "Calls himself the true vine, tells the disciples to remain in his love as friends rather "
         "than servants, and warns that the world will hate them as it hated him (15:1-27)."),
        ("The Father",
         "Pictured as the vinegrower who prunes the branches so they bear more fruit, and whose own "
         "commandments Jesus has kept by remaining in his love (15:1-2,10)."),
        ("Disciples",
         "Are called branches who can do nothing apart from Jesus, and friends rather than servants "
         "because Jesus has told them everything he heard from the Father (15:4-5,14-15)."),
        ("The Comforter (the Spirit of truth)",
         "Promised by Jesus to come from the Father and testify about him alongside the disciples' "
         "own testimony (15:26)."),
        ("The world",
         "Pictured as hating the disciples because it hated Jesus first, since they no longer belong "
         "to it the way they once did (15:18-19)."),
    ],
    16: [
        ("Jesus",
         "Warns the disciples of coming persecution, promises the Comforter will guide them into "
         "truth once he departs, and tells them to take courage since he has overcome the world "
         "(16:1-33)."),
        ("Disciples",
         "Struggle to understand Jesus' talk of going away, then confess belief in him, only to be "
         "warned that they will soon scatter and leave him alone (16:17-18,29-32)."),
        ("The Comforter (the Spirit of truth)",
         "Will come once Jesus departs to convict the world and guide the disciples into all truth, "
         "speaking only what he hears from the Father and the Son (16:7-13)."),
        ("The Father",
         "The one Jesus says he is returning to, and the one who will give the disciples whatever "
         "they ask of him in Jesus' name (16:23,28)."),
    ],
    17: [
        ("Jesus",
         "Prays to be glorified, prays for the disciples the Father gave him, and extends that same "
         "prayer to everyone who will later believe through their message (17:1-26)."),
        ("The Father",
         "Addressed throughout the prayer as the one who gave Jesus his disciples, his work, and his "
         "glory, and who is asked to keep and sanctify them (17:1-2,6,11)."),
        ("Disciples",
         "Are the ones Jesus prays will be kept from the evil one, made holy in the truth, and sent "
         "into the world just as the Father sent him (17:11,15,17-18)."),
        ("Future believers",
         "Named explicitly as everyone who will believe through the disciples' message, made the "
         "direct object of Jesus' prayer for unity (17:20)."),
        ("The world",
         "The setting Jesus prays his disciples will remain in and be sent into, rather than a place "
         "from which they should simply be removed (17:15,18)."),
    ],
    18: [
        ("Jesus",
         "Identifies himself to the arresting party, restrains Peter's violence, is questioned by "
         "Annas, and tells Pilate that his kingdom is not of this world (18:1-38)."),
        ("Judas Iscariot",
         "Leads the armed party of soldiers and officers to the garden where he knows Jesus often "
         "meets with his disciples (18:2-3)."),
        ("Simon Peter",
         "Strikes off the ear of the high priest's servant Malchus with a sword, then denies knowing "
         "Jesus three times beside a charcoal fire in the high priest's courtyard (18:10,17,25-27)."),
        ("Annas",
         "Questions Jesus first, before Caiaphas, since he is the father-in-law of the sitting high "
         "priest (18:13,19-23)."),
        ("Caiaphas",
         "The high priest that year, to whom Jesus is sent bound after Annas questions him "
         "(18:13-14,24)."),
        ("Pilate",
         "Questions Jesus about his kingship, declares he finds no case against him, and offers to "
         "release him before the crowd demands Barabbas instead (18:29-40)."),
    ],
    19: [
        ("Jesus",
         "Is flogged, mocked, and crucified between two others, entrusts his mother to the beloved "
         "disciple, and dies after declaring, \"It is finished\" (19:1-30)."),
        ("Pontius Pilate",
         "Has Jesus flogged, yields to the crowd's pressure despite finding no guilt in him, and "
         "insists the inscription over the cross stay as written (19:1,16,19-22)."),
        ("Roman soldiers",
         "Mock Jesus with a crown of thorns and purple robe, crucify him, divide his garments, and "
         "pierce his side after he dies (19:2-3,23-24,34)."),
        ("Jesus' mother and the beloved disciple",
         "Stand together near the cross, where Jesus gives each into the other's care, telling his "
         "mother, \"Behold thy son,\" and the disciple, \"Behold thy mother\" (19:25-27)."),
        ("Joseph of Arimathea and Nicodemus",
         "Two secret followers who come forward openly to claim Jesus' body and bury it, Nicodemus "
         "bringing a hundred pounds of myrrh and aloes (19:38-40)."),
        ("Chief priests",
         "Press Pilate to crucify Jesus and then object to the wording of the inscription naming "
         "him King of the Jews (19:6,21)."),
    ],
    20: [
        ("Jesus",
         "Appears risen first to Mary Magdalene, then to the gathered disciples, breathing on them "
         "and giving them his peace, and finally to Thomas, who confesses him as Lord and God "
         "(20:1-29)."),
        ("Mary Magdalene",
         "Finds the tomb empty while it is still dark, then is the first to see and speak with the "
         "risen Jesus, mistaking him at first for the gardener (20:1,11-16)."),
        ("Simon Peter",
         "Runs to the tomb with the beloved disciple and goes in first, seeing the linen cloths "
         "lying by themselves (20:3-7)."),
        ("Beloved disciple",
         "Outruns Peter to the tomb and, upon entering, is the first to see and believe (20:4,8)."),
        ("Disciples",
         "Are shown Jesus' hands and side and receive his commission and the Holy Spirit when he "
         "appears to them that evening (20:19-23)."),
        ("Thomas",
         "Refuses to believe the other disciples' report without seeing the wounds himself, then "
         "confesses, \"My Lord and my God,\" once the risen Jesus lets him do exactly that "
         "(20:24-28)."),
    ],
    21: [
        ("Jesus",
         "Appears on the shore of the Sea of Tiberias, fills the disciples' empty net, and restores "
         "Peter by asking three times whether he loves him (21:1-19)."),
        ("Simon Peter",
         "Leads the failed night of fishing, swims to shore once he recognizes Jesus, and is asked "
         "three times whether he loves him before being told to feed Jesus' sheep (21:3,7,15-17)."),
        ("Beloved disciple",
         "Is the first to recognize that the man on the shore is the Lord, and becomes the subject "
         "of a rumor, later corrected, that he would not die (21:7,20-23)."),
        ("Thomas",
         "Is named among the seven disciples present for this final resurrection appearance by the "
         "sea (21:2)."),
        ("Nathanael",
         "Reappears among the seven disciples fishing, last seen confessing Jesus as Son of God back "
         "in chapter 1 (21:2)."),
        ("Sons of Zebedee and two other disciples",
         "Make up the rest of the seven disciples fishing that night, present for the catch and the "
         "meal without any individual action of their own (21:2)."),
    ],
}

THEMES = {
    1: {
        "The Word and revelation":
            "John opens by calling Jesus the eternal Word who was with God and was God, the one "
            "through whom everything was made and who became flesh to reveal God's glory (1:1-18).",
        "Witness and belief":
            "John the Baptist denies being the Messiah himself and instead points to Jesus as the "
            "Lamb of God, modeling a witness that leads others to believe rather than drawing "
            "attention to himself (1:19-34).",
        "Calling and invitation":
            "Andrew brings his brother Simon, and Philip invites the skeptical Nathanael, showing "
            "that an ordinary invitation from someone who already believes is often how new "
            "disciples first come to Jesus (1:35-51).",
        "Fulfillment of Israel's hope":
            "Nathanael confesses Jesus as Son of God and King of Israel the moment Jesus reveals "
            "knowledge of him under the fig tree, and Jesus promises he will see even greater things "
            "than that (1:45-51).",
    },
    2: {
        "Signs and belief":
            "Turning water into wine at Cana is the first of John's signs, an act that reveals "
            "Jesus' glory and leads his disciples to believe in him (2:1-11).",
        "Worship and integrity":
            "Jesus drives merchants and money changers from the temple, refusing to let his "
            "Father's house become a marketplace (2:13-17).",
        "Temple and resurrection":
            "When asked for a sign proving his authority, Jesus speaks of destroying and raising up "
            "the temple of his own body, a statement his disciples only understood after his "
            "resurrection (2:18-22).",
        "Knowledge of the human heart":
            "Jesus does not entrust himself to people whose belief rests only on seeing signs, "
            "because he already knows what is in every human heart (2:23-25).",
    },
    3: {
        "New birth and the Spirit":
            "Jesus tells Nicodemus that no one can see God's kingdom without being born again, of "
            "water and the Spirit, confusing a teacher of Israel who expects a more straightforward "
            "answer (3:3-8).",
        "Divine love and belief":
            "John says God loved the world enough to give his only Son, so that whoever believes in "
            "him would not perish but have everlasting life (3:14-21).",
        "Humble witness":
            "Told that Jesus is baptizing more people than he is, John the Baptist rejoices rather "
            "than competes, saying Jesus must increase while he himself decreases (3:22-30).",
        "Response to the Son":
            "John the Baptist says that whoever believes on the Son has everlasting life, while "
            "whoever does not obey him remains under God's wrath (3:31-36).",
    },
    4: {
        "Living water":
            "Jesus offers a Samaritan woman water that will become in her a spring welling up to "
            "eternal life, reframing her request for an ordinary drink (4:7-15).",
        "Worship in spirit and truth":
            "Jesus tells the woman that true worshippers will worship the Father in spirit and "
            "truth, not merely at one sacred mountain or another (4:19-26).",
        "Witness across boundaries":
            "The Samaritan woman's testimony brings her whole town to Jesus, crossing a divide "
            "between Jews and Samaritans that normally kept the two groups apart (4:28-42).",
        "Trusting Jesus' word":
            "A royal official believes Jesus' word that his son will live before he has any proof, "
            "and his whole household comes to faith once the boy recovers at the exact hour Jesus "
            "spoke (4:46-54).",
    },
    5: {
        "Healing and mercy":
            "Jesus heals a man who had been disabled for thirty-eight years simply by telling him "
            "to get up and walk, without the man even knowing who had healed him at first (5:1-9).",
        "Sabbath dispute":
            "Healing on the Sabbath draws accusations from Jewish authorities, and Jesus responds "
            "by saying his Father is still working, so he works too (5:10-18).",
        "Life and judgment":
            "Jesus says the Father has given him authority to give life and to execute judgment, "
            "since the Father and Son work in complete agreement (5:19-30).",
        "Scripture and testimony":
            "Jesus tells people who search the Scriptures for eternal life that those same "
            "Scriptures testify about him, yet they refuse to come to him (5:31-47).",
    },
    6: {
        "Abundance and the sign":
            "Jesus feeds thousands from five loaves and two fish, a sign so impressive the crowd "
            "wants to make him king by force, prompting him to withdraw alone (6:1-15).",
        "Bread of life":
            "Jesus tells the crowd that he himself is the bread of life, and that whoever comes to "
            "him will never hunger again, in contrast to the manna their ancestors ate and still "
            "died (6:26-40).",
        "Difficult teaching":
            "Jesus' language about eating his flesh and drinking his blood is hard enough that many "
            "who had been following him turn back and no longer walk with him (6:51-59).",
        "Perseverance and confession":
            "When Jesus asks if the Twelve will also leave, Peter answers that they have nowhere "
            "else to go, since Jesus has the words of eternal life (6:60-71).",
    },
    7: {
        "Timing and mission":
            "Jesus tells his own unbelieving brothers that his time has not yet come, then goes up "
            "to the festival privately rather than on their public terms (7:1-13).",
        "Judgment and appearances":
            "Jesus tells the crowd to stop judging by appearances and to judge with right judgment, "
            "after they accuse him of breaking the law by healing on the Sabbath (7:14-24).",
        "Living water and Spirit":
            "On the festival's last and greatest day, Jesus invites anyone thirsty to come to him, "
            "a saying John explains refers to the Spirit believers would later receive (7:37-39).",
        "Division over Jesus":
            "The crowd splits over whether Jesus is the Christ, and even the officers sent to "
            "arrest him return empty-handed, saying no one ever spoke the way he does (7:40-52).",
    },
    8: {
        "Mercy and judgment in a disputed passage":
            "In a passage absent from the earliest manuscripts but included in the KJV, Jesus "
            "tells a woman's accusers that whoever is without sin may cast the first stone, and "
            "then tells her to go and sin no more (8:1-11).",
        "Light of the world":
            "Jesus calls himself the light of the world, promising that whoever follows him will "
            "never walk in darkness but will have the light of life (8:12-20).",
        "Freedom and truth":
            "Jesus tells believers that knowing the truth will make them free, provoking an "
            "argument with hearers who insist they have never been anyone's slaves (8:31-36).",
        "Identity and conflict":
            "Jesus' claim, \"Before Abraham was, I am,\" is understood as claiming God's own "
            "eternal name, provoking his opponents to try to stone him on the spot (8:48-59).",
    },
    9: {
        "Suffering without easy blame":
            "Asked whose sin caused a man's blindness from birth, Jesus rejects the assumption that "
            "suffering always traces back to someone's specific sin, saying instead that God's works "
            "would be displayed in him (9:1-5).",
        "Healing and witness":
            "Jesus makes mud, sends the blind man to wash in the pool of Siloam, and the man "
            "returns able to see, with no ability yet to explain who healed him or how (9:6-12).",
        "Sabbath and authority":
            "Because the healing happened on the Sabbath, Pharisees interrogate the healed man and "
            "his parents repeatedly, growing angrier as the man's answers grow bolder (9:13-34).",
        "Sight and blindness":
            "Jesus says he came so that the blind would see and those who claim to see would be "
            "shown blind, a judgment the Pharisees recognize is aimed at them (9:35-41).",
    },
    10: {
        "Good shepherd's care":
            "Jesus contrasts himself as the good shepherd who lays down his life for the sheep with "
            "hired hands who abandon them and thieves who come only to steal and destroy (10:1-18).",
        "One flock":
            "Jesus says he has other sheep not of this fold that he must also bring in, so that "
            "there will be one flock under one shepherd (10:14-16).",
        "Hearing and security":
            "Jesus says his sheep hear his voice and follow him, and that no one is able to snatch "
            "them out of his hand or his Father's (10:25-30).",
        "Claims and controversy":
            "When Jesus says he and the Father are one, his opponents take up stones again, "
            "convinced he is claiming to be God (10:31-39).",
    },
    11: {
        "Resurrection and life":
            "Jesus tells the grieving Martha that he himself is the resurrection and the life, and "
            "that whoever believes in him will live even after dying (11:17-27).",
        "Compassion and grief":
            "Seeing Mary and the mourners weeping, Jesus himself weeps, showing that his power over "
            "death does not erase real grief in the moment (11:28-37).",
        "The sign at the tomb":
            "Jesus orders the stone removed, prays aloud for the crowd's sake, and calls Lazarus "
            "out of the tomb alive after four days of being dead (11:38-44).",
        "Power and opposition":
            "Caiaphas argues that it is better for one man to die for the people, unintentionally "
            "prophesying Jesus' death as the council plots to kill him (11:45-57).",
    },
    12: {
        "Costly devotion":
            "Mary anoints Jesus' feet with expensive perfume worth a year's wages, and Jesus "
            "defends her lavish gift as preparation for his burial despite Judas's objection "
            "(12:1-8).",
        "Kingship and peace":
            "Jesus enters Jerusalem riding a young donkey rather than a warhorse, fulfilling "
            "Zechariah's picture of a humble king coming in peace (12:12-19).",
        "Fruitfulness through death":
            "Jesus compares his coming death to a grain of wheat that must fall into the ground and "
            "die before it can bear much fruit (12:20-33).",
        "Light and belief":
            "John closes the public ministry by noting that many still would not believe despite "
            "all Jesus' signs, even as Jesus insists he came as light so that no one who believes in "
            "him should remain in darkness (12:35-50).",
    },
    13: {
        "Servant leadership":
            "Jesus washes his disciples' feet, a servant's task, and tells them to do the same for "
            "one another, since no servant is greater than his master (13:1-17).",
        "Betrayal and foreknowledge":
            "Jesus identifies his betrayer by handing Judas a piece of bread, showing that he goes "
            "to his death knowingly rather than being caught by surprise (13:18-30).",
        "Love as discipleship":
            "Jesus gives a new commandment, to love one another as he has loved them, saying this "
            "love, not any outward sign, is what will identify them as his disciples (13:31-35).",
        "Confidence and weakness":
            "Peter confidently promises to lay down his life for Jesus, only to be told plainly "
            "that he will deny Jesus three times before the rooster crows (13:36-38).",
    },
    14: {
        "Hope amid departure":
            "Jesus tells his troubled disciples not to let their hearts be troubled, since he is "
            "going to prepare a place for them in his Father's house (14:1-7).",
        "Revealing the Father":
            "Jesus tells Philip that whoever has seen him has seen the Father, since he and the "
            "Father are so united that his own words and works are the Father's (14:8-14).",
        "Love and obedience":
            "Jesus says that loving him means keeping his commandments, and promises that he will "
            "ask the Father to send another Comforter to remain with the disciples forever "
            "(14:15-24).",
        "Spirit and peace":
            "Jesus promises a peace unlike anything the world can give, and tells the disciples not "
            "to be troubled or afraid even though he is leaving them (14:25-31).",
    },
    15: {
        "Abiding and fruitfulness":
            "Jesus calls himself the true vine and says branches that do not remain in him can do "
            "nothing, while those who do remain bear much fruit (15:1-8).",
        "Love and friendship":
            "Jesus tells the disciples he no longer calls them servants but friends, since he has "
            "shared with them everything he heard from the Father (15:9-17).",
        "Opposition and identity":
            "Jesus warns that the world will hate his disciples exactly as it hated him first, since "
            "they do not belong to the world any more than he does (15:18-25).",
        "Spirit and witness":
            "Jesus promises that the Comforter, the Spirit of truth, will testify about him, and "
            "that the disciples themselves will also bear witness (15:26-27).",
    },
    16: {
        "Witness under persecution":
            "Jesus warns that opponents will expel his followers from synagogues and even kill them "
            "while believing they are serving God, so the warning itself will keep them from being "
            "caught off guard (16:1-4).",
        "Spirit's guiding role":
            "Jesus says it is actually better for the disciples that he goes away, since only then "
            "will the Comforter come to guide them into all truth (16:5-15).",
        "Sorrow into joy":
            "Jesus compares the disciples' coming grief to a woman's labor pain, promising that like "
            "her sorrow it will turn into a joy no one can take away (16:16-24).",
        "Peace amid trouble":
            "Jesus tells the disciples they will have trouble in the world, but to take courage, "
            "since he has already overcome the world (16:25-33).",
    },
    17: {
        "Eternal life as knowing God":
            "Jesus defines eternal life itself as knowing the only true God and Jesus Christ, whom "
            "God has sent (17:1-5).",
        "Protection and consecration":
            "Jesus prays that the Father would keep the disciples he is leaving behind and make "
            "them holy through the truth of God's word (17:6-19).",
        "Unity and witness":
            "Jesus prays that all who believe would be as united as he and the Father are, so that "
            "the world would believe the Father sent him (17:20-23).",
        "Glory and love":
            "Jesus prays that the disciples would one day see his glory and know that the same love "
            "the Father had for him has been in them all along (17:24-26).",
    },
    18: {
        "Surrender over violence":
            "Jesus stops Peter from fighting with a sword, choosing to go willingly with his "
            "arrestors rather than resist the suffering his Father has given him (18:1-11).",
        "Truthful witness and denial":
            "While Jesus answers his questioners honestly before Annas, Peter denies even knowing "
            "him three times beside a charcoal fire in the courtyard (18:12-27).",
        "Kingship and truth":
            "Jesus tells Pilate that his kingdom is not of this world and that he came to bear "
            "witness to the truth, leaving Pilate to ask, dismissively, what truth even is "
            "(18:28-38).",
        "Injustice in the trial":
            "Even after declaring Jesus innocent, Pilate still offers the crowd a choice between "
            "Jesus and Barabbas, and they choose to free the convicted criminal instead (18:38-40).",
    },
    19: {
        "Kingship in humiliation":
            "Soldiers mock Jesus with a crown of thorns and a purple robe, not realizing that the "
            "sign Pilate orders over his cross, naming him King of the Jews, states the literal "
            "truth (19:1-22).",
        "Care amid suffering":
            "Even while dying, Jesus arranges for his own mother's care, entrusting her to the "
            "beloved disciple as if to a son (19:25-27).",
        "Completion and Scripture":
            "Jesus declares, \"It is finished,\" and dies, and John connects both the unbroken "
            "bones and the pierced side to Scriptures written long before (19:28-37).",
        "Burial and devotion":
            "Joseph of Arimathea and Nicodemus, two men previously cautious about being associated "
            "with Jesus, now openly provide a tomb and an extravagant amount of burial spices for "
            "his body (19:38-42).",
    },
    20: {
        "Empty tomb and testimony":
            "Mary Magdalene is the first to see the risen Jesus, mistaking him for the gardener "
            "until he speaks her name, and she becomes the first to carry the news to the other "
            "disciples (20:1-18).",
        "Peace and mission":
            "The risen Jesus appears among the fearful disciples, gives them his peace, and sends "
            "them out just as the Father had sent him (20:19-23).",
        "Doubt and confession":
            "Thomas insists he will not believe without seeing the wounds himself, and when Jesus "
            "lets him do exactly that, Thomas responds with the Gospel's clearest confession, \"My "
            "Lord and my God\" (20:24-29).",
        "Purpose of the Gospel":
            "John states plainly that he wrote these signs so that readers might believe Jesus is "
            "the Christ, the Son of God, and have life in his name (20:30-31).",
    },
    21: {
        "Recognition through provision":
            "The disciples recognize the risen Jesus on the shore only after he fills their empty "
            "nets with a catch too large to haul in, echoing how he first called some of them to "
            "follow him (21:1-14).",
        "Love and shepherding":
            "Jesus asks Peter three times whether he loves him, matching Peter's three earlier "
            "denials, and each time commands him to feed and care for his sheep (21:15-17).",
        "Personal discipleship":
            "When Peter asks about the beloved disciple's future, Jesus tells him that is not his "
            "concern and simply repeats the call that matters, \"Follow thou me\" (21:18-23).",
        "Witness and written testimony":
            "The Gospel closes by identifying the beloved disciple as the witness behind this "
            "testimony and noting that Jesus did far more than any book could ever contain "
            "(21:24-25).",
    },
}


def apply_chapter_insights():
    path = ROOT / "chapter_insights" / "43_john.json"
    data = load(path)
    for n in range(1, 22):
        key = f"John {n}"
        entry = data[key]
        entry["whereWeAre"] = WWA[n]
        if n == 14:
            entry["summary"] = entry["summary"].replace(
                "he promises another Advocate, the Holy Spirit, who will teach and remind the "
                "disciples",
                "he promises another Comforter, the Holy Spirit, who will teach and remind the "
                "disciples",
            )
        if n == 15:
            entry["summary"] = entry["summary"].replace(
                "the Advocate, the Spirit of truth, will testify about him",
                "the Comforter, the Spirit of truth, will testify about him",
            )
        if n == 16:
            entry["summary"] = entry["summary"].replace(
                "his departure will lead to the Advocate's coming",
                "his departure will lead to the Comforter's coming",
            )
        entry["keyFigures"] = [{"name": name, "role": role} for name, role in KEY_FIGURES[n]]
        theme_map = THEMES[n]
        seen = set()
        for theme in entry["keyThemes"]:
            name = theme["theme"]
            if name not in theme_map:
                raise SystemExit(f"John {n}: no explanation drafted for theme {name!r}")
            theme["explanation"] = theme_map[name]
            seen.add(name)
        missing = set(theme_map) - seen
        if missing:
            raise SystemExit(f"John {n}: drafted themes not in source: {missing}")
        if len(entry["keyFigures"]) > 6:
            raise SystemExit(f"John {n}: {len(entry['keyFigures'])} key figures (max 6)")
        if len(entry["whereWeAre"]) > 600:
            raise SystemExit(f"John {n}: whereWeAre is {len(entry['whereWeAre'])} characters (max 600)")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


AUDIENCE_FIXES = {
    3: ("Readers who knew that most rabbis taught publicly rather than meeting individually at "
        "night would have recognized Nicodemus's visit under cover of darkness as a sign of his own "
        "caution and divided loyalty."),
    6: ("Readers who already knew the manna story from Exodus would have recognized Jesus "
        "deliberately echoing and then surpassing it, offering himself as bread that does not need "
        "to fall from heaven every morning to keep working."),
    7: ("Readers who knew that pilgrims normally traveled to Jerusalem's festivals openly, in "
        "groups, would have recognized Jesus' private, delayed arrival as a deliberate change from "
        "his brothers' public expectations for him."),
    8: ("Readers who knew that the temple treasury stood in the same court where the festival's "
        "great lamps had just been lit would have felt the force of Jesus calling himself the light "
        "of the world in that exact location, right after the festival's own light imagery had "
        "ended."),
    9: ("Readers who knew that the man's own neighbors struggled to recognize him and that his "
        "parents feared official retaliation would have felt how much courage it took for the "
        "healed man himself to keep insisting on what had happened to him."),
    10: ("Readers keeping a winter feast that remembered the temple's rescue from desecration two "
         "centuries earlier would have recognized extra weight in Jesus using that same season and "
         "location to describe himself as the one true shepherd protecting his flock."),
    11: ("Readers who knew that Jewish tradition held a soul might linger near its body for up to "
         "three days would have recognized Lazarus's fourth day in the tomb as placing his death "
         "and resurrection beyond any doubt that he had only fainted."),
    12: ("Readers who knew that nard this costly normally represented a full year's wages would "
         "have felt the force of Mary using the whole jar at once, and the depth of Judas's own "
         "objection to that kind of expense."),
    18: ("Readers who knew that Annas had held the high priesthood himself and had seen five of his "
         "own sons and his son-in-law Caiaphas later hold the same office would have recognized why "
         "Jesus was questioned at his house first, informally, before the formal proceedings under "
         "Caiaphas began."),
    20: ("Readers who knew that Jewish law normally required multiple witnesses to establish a "
         "fact would have recognized the risen Jesus appearing separately to Mary, to the gathered "
         "disciples, and finally to Thomas as building exactly that kind of layered testimony."),
    21: ("Readers who remembered Peter's own three denials around a charcoal fire would have "
         "recognized Jesus' three questions beside another charcoal fire on this same shore as "
         "deliberately giving Peter three chances to answer for the three times he had failed."),
}


def apply_chapter_context():
    path = ROOT / "chapter_context" / "34_john.json"
    data = load(path)
    for n, new_audience in AUDIENCE_FIXES.items():
        key = f"John {n}"
        old_audience = data[key]["audience"]
        data[key]["audience"] = new_audience
        if old_audience == new_audience:
            raise SystemExit(f"John {n}: audience fix made no change")
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


OVERVIEW_FIXES = [
    ("To lead readers to believe that Jesus is the Messiah, the Son of God, and to have life in "
     "His name.",
     "To lead readers to believe that Jesus is the Messiah, the Son of God, and to have life in "
     "his name."),
    ("promising the Holy Spirit and calling them to love and abide in Him.",
     "promising the Holy Spirit and calling them to love and abide in him."),
    ("A Pharisee who comes to Jesus at night and later helps bury Him.",
     "A Pharisee who comes to Jesus at night and later helps bury him."),
    ("The disciple who doubts the resurrection until he sees Jesus and confesses, 'My Lord and my "
     "God.'",
     "The disciple who doubts the resurrection until he sees Jesus and confesses, \"My Lord and my "
     "God.\""),
    ("The Roman governor who asks 'What is truth?' and hands Jesus over to be crucified.",
     "The Roman governor who asks \"What is truth?\" and hands Jesus over to be crucified."),
]


def apply_book_overview():
    path = ROOT / "book_overviews" / "07_gospels_acts.json"
    data = load(path)
    john = data["John"]
    text = json.dumps(john, ensure_ascii=False)
    for old, new in OVERVIEW_FIXES:
        if old not in text:
            raise SystemExit(f"John overview: fix not found: {old!r}")
    john["purpose"] = john["purpose"].replace(*OVERVIEW_FIXES[0])
    john["movements"][1]["description"] = john["movements"][1]["description"].replace(*OVERVIEW_FIXES[1])
    for figure in john["keyFigures"]:
        if figure["name"] == "Nicodemus":
            figure["description"] = figure["description"].replace(*OVERVIEW_FIXES[2])
        if figure["name"] == "Thomas":
            figure["description"] = figure["description"].replace(*OVERVIEW_FIXES[3])
        if figure["name"] == "Pontius Pilate":
            figure["description"] = figure["description"].replace(*OVERVIEW_FIXES[4])
    save(path, data)
    print(f"Updated {path.relative_to(ROOT)}")


STORY_PRONOUN_FIXES = [
    ("identifies Him and His first disciples begin following Him.",
     "identifies him and his first disciples begin following him."),
    ("Jesus performs His first sign,", "Jesus performs his first sign,"),
    ("Jesus reveals God's salvation to a Samaritan woman, heals a child, and declares His "
     "authority",
     "Jesus reveals God's salvation to a Samaritan woman, heals a child, and declares his "
     "authority"),
    ("Jesus feeds a vast crowd, walks upon the sea, and teaches that He alone gives the lasting "
     "life",
     "Jesus feeds a vast crowd, walks upon the sea, and teaches that he alone gives the lasting "
     "life"),
    ("and declares that He is the light of the world.",
     "and declares that he is the light of the world."),
    ("Jesus gives sight to a man born blind and teaches that He is the good shepherd who knows "
     "and protects His people.",
     "Jesus gives sight to a man born blind and teaches that he is the good shepherd who knows "
     "and protects his people."),
    ("During His final evening with the disciples, Jesus demonstrates humble service, announces "
     "His betrayal,",
     "During his final evening with the disciples, Jesus demonstrates humble service, announces "
     "his betrayal,"),
    ("Jesus teaches His disciples to remain in Him, warns of persecution,",
     "Jesus teaches his disciples to remain in him, warns of persecution,"),
    ("Judas betrays Jesus, Peter denies knowing Him, and Jewish leaders bring Jesus before the "
     "Roman governor to demand His execution.",
     "Judas betrays Jesus, Peter denies knowing him, and Jewish leaders bring Jesus before the "
     "Roman governor to demand his execution."),
    ("Jesus dies upon the cross, fulfilling the work He came to accomplish, and His body is "
     "placed in a nearby tomb.",
     "Jesus dies upon the cross, fulfilling the work he came to accomplish, and his body is "
     "placed in a nearby tomb."),
    ("the risen Jesus appears to His followers, and Thomas comes to believe after seeing Him.",
     "the risen Jesus appears to his followers, and Thomas comes to believe after seeing him."),
    ("The risen Jesus meets His disciples beside the Sea of Tiberias, provides a miraculous catch "
     "of fish, and renews Peter's responsibility to care for His followers.",
     "The risen Jesus meets his disciples beside the Sea of Tiberias, provides a miraculous catch "
     "of fish, and renews Peter's responsibility to care for his followers."),
    ("The Word came into the world He made, but",
     "The Word came into the world he made, but"),
    ("The next day, two of John's disciples follow Jesus. He turns and asks, “What seek ye?” "
     "They spend the day with Him.",
     "The next day, two of John's disciples follow Jesus. he turns and asks, “What seek ye?” "
     "They spend the day with him."),
    ("When Jesus tells Nathanael He saw him under a fig tree",
     "When Jesus tells Nathanael he saw him under a fig tree"),
    ("Jesus' mother tells Him, then tells the servants,",
     "Jesus' mother tells him, then tells the servants,"),
    ("He makes a whip of cords, drives them all out,",
     "he makes a whip of cords, drives them all out,"),
    ("When the leaders demand a sign, He says, “Destroy this temple,",
     "When the leaders demand a sign, he says, “Destroy this temple,"),
    ("They think He means the building, which took forty-six years to build,",
     "They think he means the building, which took forty-six years to build,"),
    ("Tired, He sits by Jacob's well at noon.",
     "Tired, he sits by Jacob's well at noon."),
    ("and He asks her for a drink.",
     "and he asks her for a drink."),
    ("Jesus says that if she knew who He was, she would ask Him for “living water.”",
     "Jesus says that if she knew who he was, she would ask him for “living water.”"),
    ("When He tells her to call her husband, she says she has none.",
     "When he tells her to call her husband, she says she has none."),
    ("He answers that she has had five husbands,",
     "he answers that she has had five husbands,"),
    ("She says the Messiah will explain everything when He comes.",
     "She says the Messiah will explain everything when he comes."),
    ("Meanwhile Jesus tells His disciples, “Lift up your eyes,",
     "Meanwhile Jesus tells his disciples, “Lift up your eyes,"),
    ("They try even harder to kill Him, because He is “making himself equal with God.”",
     "They try even harder to kill him, because he is “making himself equal with God.”"),
    ("Jesus explains that the Son does what He sees the Father doing.",
     "Jesus explains that the Son does what he sees the Father doing."),
    ("He tells them, “Search the scriptures;",
     "he tells them, “Search the scriptures;"),
    ("He tests Philip by asking where they could buy bread for so many.",
     "he tests Philip by asking where they could buy bread for so many."),
    ("The people want to make Him king by force, so He slips away to the mountain alone.",
     "The people want to make him king by force, so he slips away to the mountain alone."),
    ("but He says, “It is I; be not afraid.”",
     "but he says, “It is I; be not afraid.”"),
    ("As soon as they take Him into the boat, they reach the shore.",
     "As soon as they take him into the boat, they reach the shore."),
    ("The next day the crowd finds Him in Capernaum.",
     "The next day the crowd finds him in Capernaum."),
    ("Jesus replies that He chose all twelve, “and one of you is a devil.” He means Judas "
     "Iscariot, who would betray Him.",
     "Jesus replies that he chose all twelve, “and one of you is a devil.” he means Judas "
     "Iscariot, who would betray him."),
    ("Jesus' brothers do not believe in Him. They urge Him to go to Jerusalem for the Feast of "
     "Tabernacles to show Himself. He goes later, in secret. Halfway through the feast, He begins "
     "teaching openly in the temple. People argue about Him.",
     "Jesus' brothers do not believe in him. They urge him to go to Jerusalem for the Feast of "
     "Tabernacles to show himself. he goes later, in secret. Halfway through the feast, he begins "
     "teaching openly in the temple. People argue about him."),
    ("The leaders send officers to arrest Him.",
     "The leaders send officers to arrest him."),
    ("John explains that He meant the Holy Spirit.",
     "John explains that he meant the Holy Spirit."),
    ("They want to trap Him. Jesus stoops and writes on the ground with His finger. When they "
     "keep asking, He stands and says,",
     "They want to trap him. Jesus stoops and writes on the ground with his finger. When they "
     "keep asking, he stands and says,"),
    ("To those who believe, He says, “If ye continue in my word,",
     "To those who believe, he says, “If ye continue in my word,"),
    ("His listeners insist they are Abraham's children",
     "his listeners insist they are Abraham's children"),
    ("He tells them that if God were their Father they would love Him.",
     "he tells them that if God were their Father they would love him."),
    ("Finally He says, “Verily, verily,",
     "Finally he says, “Verily, verily,"),
    ("They understand what He is claiming and pick up stones to kill Him, but He slips away.",
     "They understand what he is claiming and pick up stones to kill him, but he slips away."),
    ("His disciples ask, “who did sin,",
     "his disciples ask, “who did sin,"),
    ("He spits on the ground, makes mud,",
     "he spits on the ground, makes mud,"),
    ("He reasons that if Jesus were not from God, He could do nothing.",
     "He reasons that if Jesus were not from God, he could do nothing."),
    ("“Lord, I believe,” he says, and worships Him.",
     "“Lord, I believe,” he says, and worships him."),
    ("Jesus says He came so that the blind might see",
     "Jesus says he came so that the blind might see"),
    ("Then Jesus describes Himself as a shepherd.",
     "Then Jesus describes himself as a shepherd."),
    ("but Jesus knows His sheep and lays down His life for them.",
     "but Jesus knows his sheep and lays down his life for them."),
    ("He has other sheep too, not of this fold,",
     "he has other sheep too, not of this fold,"),
    ("the leaders surround Him: “If thou be the Christ,",
     "the leaders surround him: “If thou be the Christ,"),
    ("He says His works already tell them.",
     "he says his works already tell them."),
    ("Then He says, “I and my Father are one.”",
     "Then he says, “I and my Father are one.”"),
    ("Again they pick up stones, and again He escapes,",
     "Again they pick up stones, and again he escapes,"),
    ("going back across the Jordan, where many believe in Him.",
     "going back across the Jordan, where many believe in him."),
    ("Jesus loves all three, yet He waits two more days.",
     "Jesus loves all three, yet he waits two more days."),
    ("Then He tells His disciples, “Our friend Lazarus sleepeth,”",
     "Then he tells his disciples, “Our friend Lazarus sleepeth,”"),
    ("Martha meets Him: “Lord, if thou hadst been here,",
     "Martha meets him: “Lord, if thou hadst been here,"),
    ("He asks, “Believest thou this?”",
     "he asks, “Believest thou this?”"),
    ("Then He cries with a loud voice, “Lazarus, come forth.”",
     "Then he cries with a loud voice, “Lazarus, come forth.”"),
    ("From that day, they plot to kill Him.",
     "From that day, they plot to kill him."),
    ("crowds carrying palm branches meet Jesus as He rides into Jerusalem on a young donkey,",
     "crowds carrying palm branches meet Jesus as he rides into Jerusalem on a young donkey,"),
    ("He says, “The hour is come, that the Son of man should be glorified.”",
     "he says, “The hour is come, that the Son of man should be glorified.”"),
    ("He is troubled but will not ask to be spared,",
     "he is troubled but will not ask to be spared,"),
    ("A voice from heaven answers Him.",
     "A voice from heaven answers him."),
    ("Jesus gets up, takes off His outer garment, wraps a towel around His waist,",
     "Jesus gets up, takes off his outer garment, wraps a towel around his waist,"),
    ("and begins washing His disciples' feet, the job of the lowest servant.",
     "and begins washing his disciples' feet, the job of the lowest servant."),
    ("Then Peter asks Him to wash his hands and head too.",
     "Then Peter asks him to wash his hands and head too."),
    ("Jesus says it is the one He gives a piece of bread to, and He gives it to Judas.",
     "Jesus says it is the one he gives a piece of bread to, and he gives it to Judas."),
    ("Jesus tells him he will deny Him three times before the rooster crows.",
     "Jesus tells him he will deny him three times before the rooster crows."),
    ("He promises that He will not leave them alone.",
     "he promises that he will not leave them alone."),
    ("Then He says, “Arise, let us go hence.”",
     "Then he says, “Arise, let us go hence.”"),
    ("He warns that the world will hate them because it hated Him first.",
     "he warns that the world will hate them because it hated him first."),
    ("But it is better for them that He goes away, because then the Comforter will come. He "
     "will convict the world of sin, righteousness, and judgment, and He will",
     "But it is better for them that he goes away, because then the Comforter will come. he "
     "will convict the world of sin, righteousness, and judgment, and he will"),
    ("Then Jesus lifts His eyes to heaven and prays.",
     "Then Jesus lifts his eyes to heaven and prays."),
    ("He prays for His disciples, who will stay in the world:",
     "he prays for his disciples, who will stay in the world:"),
    ("Then He prays for everyone who will believe through their message,",
     "Then he prays for everyone who will believe through their message,"),
    ("When He answers, “I am he,” they step back and fall to the ground.",
     "When he answers, “I am he,” they step back and fall to the ground."),
    ("He tells them to let His disciples go.",
     "he tells them to let his disciples go."),
    ("Inside, Annas questions Jesus, and an officer slaps Him. They send Him to Caiaphas.",
     "Inside, Annas questions Jesus, and an officer slaps him. They send him to Caiaphas."),
    ("He says He came “that I should bear witness unto the truth.",
     "he says he came “that I should bear witness unto the truth."),
    ("and offers to release Him. They shout for Barabbas instead,",
     "and offers to release him. They shout for Barabbas instead,"),
    ("The soldiers put a crown of thorns and a purple robe on Him and slap Him.",
     "The soldiers put a crown of thorns and a purple robe on him and slap him."),
    ("Pilate brings Him out and says, “Behold the man!”",
     "Pilate brings him out and says, “Behold the man!”"),
    ("They say He must die “because he made himself the Son of God.”",
     "They say he must die “because he made himself the Son of God.”"),
    ("When Pilate claims power over Him, Jesus says,",
     "When Pilate claims power over him, Jesus says,"),
    ("Pilate tries to release Him, but the leaders warn,",
     "Pilate tries to release him, but the leaders warn,"),
    ("So Pilate hands Him over to be crucified.",
     "So Pilate hands him over to be crucified."),
    ("Carrying His own cross, Jesus goes out to “a place called the place of a skull,",
     "Carrying his own cross, Jesus goes out to “a place called the place of a skull,"),
    ("They crucify Him between two others.",
     "They crucify him between two others."),
    ("The soldiers divide His clothes. His coat is woven in one piece without a seam,",
     "The soldiers divide his clothes. His coat is woven in one piece without a seam,"),
    ("Near the cross stand His mother, her sister, Mary the wife of Cleophas,",
     "Near the cross stand his mother, her sister, Mary the wife of Cleophas,"),
    ("Seeing His mother and the disciple He loved, Jesus says,",
     "Seeing his mother and the disciple he loved, Jesus says,"),
    ("They lift a sponge of vinegar to His mouth.",
     "They lift a sponge of vinegar to his mouth."),
    ("Then He says, “It is finished:",
     "Then he says, “It is finished:"),
    ("He is already dead, so they do not break His legs.",
     "he is already dead, so they do not break his legs."),
    ("a soldier pierces His side with a spear,",
     "a soldier pierces his side with a spear,"),
    ("She turns and sees Jesus standing there but thinks He is the gardener.",
     "She turns and sees Jesus standing there but thinks he is the gardener."),
    ("She begs Him to tell her where He has put the body.",
     "She begs him to tell her where he has put the body."),
    ("and sends her to tell His brothers.",
     "and sends her to tell his brothers."),
    ("He shows them His hands and His side, and they are overjoyed.",
     "he shows them his hands and his side, and they are overjoyed."),
    ("He breathes on them and says, “Receive ye the Holy Ghost.”",
     "he breathes on them and says, “Receive ye the Holy Ghost.”"),
    ("They answer no. He tells them, “Cast the net on the right side of the ship,",
     "They answer no. he tells them, “Cast the net on the right side of the ship,"),
    ("He asks a second time, and Peter answers the same.",
     "he asks a second time, and Peter answers the same."),
    ("Then He tells Peter that when he is old,",
     "Then he tells Peter that when he is old,"),
]


def apply_story_fixes():
    path = ROOT / "book_content" / "07_gospels_acts.md"
    text = path.read_text(encoding="utf-8")
    start = text.index("# John")
    end = text.index("# Acts")
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
