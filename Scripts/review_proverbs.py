#!/usr/bin/env python3
"""Apply the completed editorial review for Proverbs to source content only."""

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    insights_path = ROOT / "chapter_insights/20_proverbs.json"
    moments_path = ROOT / "historical_moments/09_job_song.json"
    context_path = ROOT / "chapter_context/21_proverbs.json"
    overview_path = ROOT / "book_overviews/04_wisdom.json"
    story_path = ROOT / "book_content/04_wisdom.md"

    insights = load(insights_path)
    moments = load(moments_path)
    context = load(context_path)
    overview = load(overview_path)

    placement = {
        1: "Psalm 150 closed the book of Psalms with praise for the LORD. Proverbs 1 opens a different kind of wisdom book: short instructions for daily living, beginning with a father's warning against violent companions and Wisdom's public call. Chapter 2 continues the father's appeal, urging his son to search for wisdom as for treasure.",
        2: "In chapter 1 a father warned his son against violent companions and wisdom called out in the streets. Here the father urges his son to search for wisdom like hidden treasure, since it guards against crooked speech and the unfaithful woman. Chapter 3 continues the same appeal, adding trust in the LORD and honor for him from one's wealth.",
        3: "Chapter 2 promised that wisdom protects those who seek it. Here the father adds trust in the LORD, honor from one's possessions, and acceptance of correction, then praises wisdom as more valuable than silver or gold. Chapter 4 continues the appeal by recalling how the father himself was taught wisdom as a boy.",
        4: "Chapter 3 praised wisdom's worth above silver and gold. Here the father recalls his own father's teaching and passes it on, contrasting the bright path of the righteous with the darkness of the wicked. Chapter 5 turns from that general contrast to a specific danger: the lure of adultery.",
        5: "Chapter 4 urged the son to guard his heart and keep to a straight path. Here the father applies that warning to a specific danger, the adulterous woman, and calls for faithfulness to the wife of one's youth. Chapter 6 turns to other practical dangers: rash pledges, laziness, and mischief, before returning to the same warning about adultery.",
        6: "Chapter 5 warned against the adulterous woman and praised faithfulness in marriage. Here the father gives other practical warnings, against rash pledges and laziness, and then returns to the danger of adultery, comparing it to carrying fire against one's body. Chapter 7 tells a single vivid scene of exactly that temptation.",
        7: "Chapter 6 compared adultery to carrying fire against one's body. Here the father recounts watching from his window as a young man is drawn in by a seductive woman's words, a scene that makes the earlier warning concrete. Chapter 8 shifts from this warning about Folly's lure to Wisdom's own public invitation.",
        8: "Chapter 7 showed how a foolish young man is drawn to ruin by a seductive woman's words. Here Wisdom herself speaks publicly, inviting everyone to truth and describing her presence when God founded the world. Chapter 9 closes the opening section by picturing Wisdom and Folly as two women each inviting guests to a house.",
        9: "Chapter 8 pictured Wisdom calling publicly and present at creation. Here the opening section ends with Wisdom and Folly each inviting the simple into their houses, one offering life and the other hiding death. Chapter 10 begins a long new collection of short, two-line sayings credited directly to Solomon.",
        10: "Chapters 1–9 were an extended father's appeal to choose wisdom. Here a new heading, \"the proverbs of Solomon,\" begins a long collection of short, two-line sayings contrasting the wise and the foolish. Chapter 11 continues this same collection with sayings on honesty and community.",
        11: "Chapter 10 opened Solomon's collection of short sayings contrasting wise and foolish conduct. Here the sayings turn to honest business, humility, and how a city fares under righteous or wicked citizens. Chapter 12 continues the same collection with sayings on diligence and truthful speech.",
        12: "Chapter 11 considered how honesty and generosity shape a community. Here the sayings address receiving correction, diligent work, and truthful speech, closing with comfort for anxious hearts. Chapter 13 continues the collection with sayings on teachability and family responsibility.",
        13: "Chapter 12 praised truthful, healing speech and diligent labor. Here the sayings contrast a teachable child with a scoffer, patient diligence with idle desire, and close with instruction on discipline and inheritance. Chapter 14 continues the collection, often contrasting wisdom and folly within the same household.",
        14: "Chapter 13 closed with sayings on family discipline and inheritance. Here the sayings warn that appearances can mislead and describe the social cost of anger, contempt for the poor, and poor leadership. Chapter 15 continues the collection, opening with the effect of gentle or harsh speech.",
        15: "Chapter 14 warned that outward appearances, like a seemingly right road or a hidden grief, can mislead. Here the sayings open with how a soft answer turns away wrath and go on to stress that the LORD sees every heart. Chapter 16 continues the collection, pairing human planning with the LORD's direction.",
        16: "Chapter 15 stressed that the LORD watches every heart and favors humility over outward display. Here the sayings pair human planning with the LORD's evaluation and move on to just judgments and the responsibilities of kings. Chapter 17 continues the collection with sayings on family peace and fair judgment.",
        17: "Chapter 16 addressed just judgments, honest weights, and the responsibilities of kings. Here the sayings judge a peaceful home with little better than a quarrelsome house full of plenty, and go on to loyal friendship and restrained speech. Chapter 18 continues the collection, contrasting isolation with relational stability.",
        18: "Chapter 17 valued a peaceful home and dependable friends above wealth and conflict. Here the sayings contrast quarrelsome isolation with careful listening and note that words can nourish or destroy. Chapter 19 continues the collection with sayings on integrity, poverty, and riches.",
        19: "Chapter 18 showed that a person's words carry the power to nourish or destroy. Here the sayings value integrity over wealth gained by crooked speech and address false witnesses and the social pressures of poverty and riches. Chapter 20 continues the collection, opening with a warning against intoxication.",
        20: "Chapter 19 weighed integrity against the pressures that poverty and riches create. Here the sayings open with a warning against intoxication and go on to commercial honesty, reliable witnesses, and fair leadership. Chapter 21 continues the collection, opening with the LORD's control over the hearts of kings.",
        21: "Chapter 20 commended honest leadership, trade, and testimony. Here the sayings open by declaring that the LORD directs even a king's decisions and that justice matters more than sacrifice. Chapter 22 continues the collection through verse 16, where a new heading, \"the words of the wise,\" begins.",
        22: "Chapter 21 insisted that justice and righteousness matter more than ritual sacrifice. Here the sayings value a good name above riches and address raising children and lending, until a new heading at verse 17, \"the words of the wise,\" opens a fresh collection on trust and justice for the poor. Chapter 23 continues this new collection.",
        23: "Chapter 22 began \"the words of the wise\" with counsel on trust, boundaries, and protecting the poor. Here that same collection continues with warnings about dining with the powerful, exhausting pursuit of wealth, and the dangers of drunkenness. Chapter 24 closes \"the words of the wise\" and opens a second short collection with the same title.",
        24: "Chapter 23 warned against drunkenness and destructive appetite within \"the words of the wise.\" Here that collection closes with a warning against envy and violence, and a fresh heading at verse 23 opens a second collection against partiality in court and neglectful laziness. Chapter 25 opens a much larger collection, proverbs of Solomon copied out by Hezekiah's scribes.",
        25: "Chapter 24 closed the two short collections called \"the words of the wise.\" Here a heading credits Hezekiah's scribes with copying out further proverbs of Solomon, beginning with sayings on courtly humility and careful speech. Chapter 26 continues this Hezekiah collection with sayings on fools and sluggards.",
        26: "Chapter 25 opened the Hezekiah collection with sayings on rulers and careful speech. Here the sayings expose the habits of fools, sluggards, and gossips, including the paired advice on answering a fool that only makes sense case by case. Chapter 27 continues the collection with sayings on friendship and stewardship.",
        27: "Chapter 26 exposed the habits of the fool and the sluggard. Here the sayings warn against boasting about tomorrow, praise a friend's honest correction, and close by urging regular attention to flocks and herds. Chapter 28 continues the Hezekiah collection, turning to righteous and wicked leadership.",
        28: "Chapter 27 urged attentive care for household flocks and herds rather than presumption about the future. Here the sayings contrast the boldness of the righteous with the unease of the wicked and confront oppressive rulers and dishonest wealth. Chapter 29 closes the Hezekiah collection with sayings on correction and government.",
        29: "Chapter 28 confronted oppressive rulers and praised honest confession. Here the Hezekiah collection closes with sayings on repeated refusal of correction, fair government, and trust in the LORD rather than human opinion. Chapter 30 turns to a different voice, the otherwise unknown sage Agur.",
        30: "Chapters 25–29 gathered Solomon's proverbs as copied out by Hezekiah's scribes. Here an otherwise unknown sage, Agur son of Jakeh, speaks humbly about the limits of human knowledge and prays for neither poverty nor riches, before a series of numbered sayings about nature and human conduct. Chapter 31 closes the book with the words of King Lemuel and the praise of a capable woman.",
        31: "Chapter 30 gave Agur's humble sayings about human limits and contentment. Here King Lemuel's mother teaches him to rule with self-control and defend the poor, and an alphabetic poem praises a capable woman's diligence, generosity, and reverence for the LORD. The next book, Ecclesiastes, returns to a single voice weighing whether life's labor has lasting meaning.",
    }

    summaries = {
        1: "The opening identifies Proverbs as instruction in wisdom, discipline, justice, and discernment, with reverence for the LORD as its foundation (Proverbs 1:1–7). A parent warns a son not to join violent companions who promise quick riches, since their schemes eventually entrap them (Proverbs 1:8–19). Wisdom, depicted as a woman calling out in public, challenges those who reject correction and warns that hardened refusal has consequences (Proverbs 1:20–33).",
        2: "A father urges his child to receive instruction and seek wisdom as diligently as treasure, since understanding comes from the LORD (Proverbs 2:1–8). Wisdom protects against crooked speech, corrupt companions, and the unfaithful woman who abandons her marriage covenant (Proverbs 2:9–19). The chapter closes by contrasting the futures of the upright and the wicked in the land (Proverbs 2:20–22).",
        3: "Parental teaching commends steadfast love, trust in the LORD rather than one's own understanding, and honoring God with one's wealth (Proverbs 3:1–12). Wisdom is celebrated as more valuable than silver or gold and pictured as a tree of life (Proverbs 3:13–20). The chapter then calls for neighborly generosity, peaceable conduct, and refusal to envy violent people (Proverbs 3:21–35).",
        4: "The teacher recalls instruction received from his own father and urges the next generation to acquire wisdom even at personal cost (Proverbs 4:1–9). He contrasts the bright path of righteous living with the darkness of wicked conduct (Proverbs 4:10–19). The closing appeal asks the listener to guard the heart, reject deceptive speech, and keep a steady course (Proverbs 4:20–27).",
        5: "The father warns against adulterous involvement, describing the temptation as sweet at first but bitter and ruinous in the end (Proverbs 5:1–14). He then pictures water drawn from one's own cistern as an image of exclusive marital intimacy, calling the son to delight in the wife of his youth (Proverbs 5:15–20). The LORD's awareness of every path and the way wrongdoing entangles its doer close the warning (Proverbs 5:21–23).",
        6: "The chapter opens with practical warnings against an ill-considered pledge, laziness, and using deceit to harm neighbors (Proverbs 6:1–19). A father's and mother's teaching is compared to a lamp that guides and corrects (Proverbs 6:20–23). The long closing warning addresses adultery, comparing sexual betrayal to carrying fire against one's body (Proverbs 6:24–35).",
        7: "The speaker urges the son to keep instruction close, describing wisdom as a sister and understanding as a near companion (Proverbs 7:1–5). He recounts watching from a window as a young man without judgment approaches a dangerous street at dusk (Proverbs 7:6–9). A woman entices him with promises of pleasure, and he follows her without grasping the danger (Proverbs 7:10–27).",
        8: "Wisdom calls openly at gates and crossroads, inviting all people to learn truth, prudence, and justice rather than valuing silver above instruction (Proverbs 8:1–21). Wisdom then speaks of her presence before and during the ordering of the created world (Proverbs 8:22–31). The concluding appeal declares blessed those who listen and warns that rejecting wisdom brings harm (Proverbs 8:32–36).",
        9: "Wisdom prepares a feast and sends out a public invitation to the inexperienced, urging them to leave folly and walk in understanding (Proverbs 9:1–6). The middle section contrasts how mockers and wise people respond to correction, returning to the fear of the LORD as the beginning of wisdom (Proverbs 9:7–12). Folly, also personified as a woman, offers stolen pleasure while concealing the deadly end of her guests (Proverbs 9:13–18).",
        10: "A new heading introduces proverbs attributed to Solomon (Proverbs 10:1). Short contrasting sayings address wise and foolish children, honest and dishonest gain, diligent and negligent work, and truthful speech (Proverbs 10:2–10). Later sayings describe how speech can nourish others or cause harm and trace the lasting effects of righteousness or wickedness (Proverbs 10:11–32).",
        11: "These compact proverbs link honest business weights with integrity, humility with wisdom, and uprightness with guidance (Proverbs 11:1–8). The sayings then explore how speech and conduct affect an entire community, stressing discretion, reliable counsel, and a city's flourishing under just citizens (Proverbs 11:9–14). Generosity, misplaced confidence in riches, and the broader outcomes of righteous and wicked living occupy the chapter's close (Proverbs 11:15–31).",
        12: "This collection praises receiving correction, diligence, truthful speech, and humane treatment of animals while condemning deceptive schemes and careless words (Proverbs 12:1–12). Its sayings contrast lazy wishes with responsible labor and the truthful witness with the liar (Proverbs 12:13–22). It closes by commending prudent speech, encouraging words for anxious hearts, and the reliable path of righteousness (Proverbs 12:23–28).",
        13: "The sayings contrast a teachable child with a scoffer (Proverbs 13:1), guarded speech with reckless talk (Proverbs 13:2–3), and patient diligence with idle desire (Proverbs 13:4–11). They address hope deferred, correction, keeping company with wise people, and the lasting consequences of one's conduct (Proverbs 13:12–21). The closing verses consider family inheritance, discipline, and provision (Proverbs 13:22–25).",
        14: "Proverbs about building or ruining a household open a chapter that repeatedly contrasts genuine knowledge with foolish self-confidence (Proverbs 14:1–9). Several sayings warn that appearances may mislead: a seemingly right road can end badly, and outward laughter may hide grief (Proverbs 14:10–16). The chapter also describes the social damage of anger, contempt for the poor, and unwise leadership, while praising compassion and reverence for the LORD (Proverbs 14:17–35).",
        15: "Gentle speech that turns away anger opens this collection, while harsh words inflame conflict (Proverbs 15:1–2). The chapter emphasizes that the LORD sees people's ways, welcomes the prayer of the upright, and values justice and humility over outward display (Proverbs 15:3–11). It closes by joining contentment, deliberate speech, correction, and reverence for the LORD (Proverbs 15:12–33).",
        16: "The sayings repeatedly pair human planning with the LORD's evaluation and direction (Proverbs 16:1–9). They consider just judgments, honest weights, the responsibilities of kings, and the power of wise speech (Proverbs 16:10–15; Proverbs 16:20–24). Pride, gossip, violence, self-control, and perceived chance receive further attention (Proverbs 16:16–33).",
        17: "A peaceful home with little is judged better than a wealthy house full of strife (Proverbs 17:1). The collection addresses family relationships, betrayal, bribery, honest judgment, and the cost of provoking disputes (Proverbs 17:2–16). Later sayings value dependable friends, cheerful hearts, restrained speech, and wise silence (Proverbs 17:17–28).",
        18: "The chapter contrasts isolation and quarrelsomeness with understanding, careful listening, and relational stability (Proverbs 18:1–8). It warns about laziness, misplaced confidence in wealth, and answering before hearing the facts (Proverbs 18:9–17). Words may nourish or destroy, and closing sayings address disputes, marriage, and faithful friendship (Proverbs 18:18–24).",
        19: "The chapter values integrity over wealth joined to crooked speech and questions whether desire without knowledge can lead safely (Proverbs 19:1–3). Its sayings deal with false witnesses, the social pressures surrounding poverty and riches, and patient discretion in conflict (Proverbs 19:4–12). Household relationships, parental correction, and the limits of human plans form the chapter's close (Proverbs 19:13–29).",
        20: "The chapter begins by warning against intoxication and commending honorable avoidance of needless quarrels (Proverbs 20:1–3). Its proverbs address laziness, commercial dishonesty, unreliable witnesses, and fair leadership (Proverbs 20:4–19). Children, integrity, revenge, honest scales, and the need for self-examination appear near the close (Proverbs 20:20–30).",
        21: "The LORD's sovereignty over royal decisions opens the chapter, which declares that justice and righteousness matter more than sacrifice (Proverbs 21:1–3). A long sequence contrasts diligence with haste, generosity with neglect, and patient wisdom with uncontrolled anger (Proverbs 21:4–23). Later sayings criticize pride, false witnesses, empty religious performance, and confidence in military preparation without regard for the LORD (Proverbs 21:24–31).",
        22: "The opening sayings value a good reputation over riches and connect humility and reverence with wise living (Proverbs 22:1–5). The chapter continues with advice about training children, generosity, lending, and the costs of oppression (Proverbs 22:6–16). At 22:17 the style changes to an appeal to hear \"the words of the wise,\" followed by instruction about trust, protecting the poor, and skilled work (Proverbs 22:17–29).",
        23: "Continuing \"the words of the wise,\" this chapter gives counsel about eating at a ruler's table without being captivated by luxury, avoiding exhausting pursuit of wealth, and resisting exploitative hosts (Proverbs 23:1–8). It commands care for the poor and fatherless, a child's willingness to learn, and the cultivation of a truthful heart (Proverbs 23:9–19). A vivid closing passage warns against habitual drunkenness and destructive appetites (Proverbs 23:20–35).",
        24: "The collection warns against envying evildoers and argues that a household is established by wisdom rather than violent schemes (Proverbs 24:1–9). It urges rescuing those in danger, fearing God, and refusing to rejoice in an enemy's fall (Proverbs 24:10–22). A fresh heading at 24:23 adds sayings against partiality in court and depicts a neglected field as a lesson in diligence (Proverbs 24:23–34).",
        25: "A heading attributes these proverbs to Solomon and says the men of King Hezekiah copied them (Proverbs 25:1). The sayings address the searching work of rulers, courtly humility, conflict resolution, and cautious speech (Proverbs 25:2–15). They praise moderation and fidelity in friendship, warn against false testimony, and urge giving food and drink even to an enemy (Proverbs 25:16–28).",
        26: "A sequence of comparisons warns against honoring fools, becoming trapped in foolish arguments, and entrusting important work to unreliable messengers (Proverbs 26:1–12). Sayings then expose excuses for laziness (Proverbs 26:13–16). The closing group condemns meddling in quarrels, deceptive joking, gossip, and flattery that conceals malice (Proverbs 26:17–28).",
        27: "The chapter begins by discouraging boasts about tomorrow and self-praise, then praises frank correction from a true friend (Proverbs 27:1–10). It describes the strain caused by foolishness and quarrels, the value of foresight, and the way people sharpen one another (Proverbs 27:11–22). The final passage urges regular attention to flocks, herds, and household resources (Proverbs 27:23–27).",
        28: "These sayings contrast the courage of the righteous with the unease of the wicked and connect lawful conduct with communal order (Proverbs 28:1–9). They warn against hiding wrongdoing and praise confession and turning away from it (Proverbs 28:10–14). The chapter's second half confronts exploitative rulers, dishonest wealth, favoritism, and oppression of the poor (Proverbs 28:15–28).",
        29: "The chapter opens with a warning about repeated refusal of correction and then treats fair government as a source of public joy rather than distress (Proverbs 29:1–4). Sayings warn about flattery, uncontrolled anger, poor leadership, and the importance of hearing the cause of the poor (Proverbs 29:5–16). The close links discipline, restraint, justice, and trust in the LORD rather than fear of human opinion (Proverbs 29:17–27).",
        30: "The heading names Agur son of Jakeh, whose precise identity and location remain uncertain (Proverbs 30:1). He speaks humbly about the limits of human knowledge and the purity of God's words, then asks for freedom from falsehood and from extremes of riches and poverty (Proverbs 30:2–9). A series of numbered sayings observes human arrogance, mysteries in nature, and small creatures that display wisdom (Proverbs 30:10–33).",
        31: "The opening records advice taught to King Lemuel by his mother: avoid conduct that ruins rulers, resist drinking that clouds judgment, and speak up for the vulnerable (Proverbs 31:1–9). A separate alphabetic poem then honors an accomplished woman whose work provides for her household, supports commerce, opens her hand to the poor, and speaks with wisdom (Proverbs 31:10–31).",
    }

    key_figures = {
        1: [
            {"name": "Solomon", "role": "Named in the superscription as David's son and king of Israel. The opening associates the collection with Solomonic wisdom (1:1)."},
            {"name": "The father", "role": "Warns his son against joining violent companions who promise quick, dishonest riches (1:8–19)."},
            {"name": "Wisdom (personified)", "role": "A woman who calls out in the streets and gates, warning that hardened refusal of her invitation brings consequences (1:20–33)."},
            {"name": "Violent sinners", "role": "Would-be companions seeking illicit gain. Their invitation forms the negative example (1:10–19)."},
        ],
        2: [
            {"name": "The father", "role": "Urges his son to receive instruction and search for wisdom as for hidden treasure (2:1–8)."},
            {"name": "The son", "role": "Addressee of the instruction, warned against corrupt companions and the unfaithful woman (2:9–19)."},
        ],
        3: [
            {"name": "The father", "role": "Teaches his son to trust the LORD, honor him with his wealth, and accept correction (3:1–12)."},
            {"name": "The son", "role": "Addressee who is urged to treasure wisdom above silver or gold (3:13–18)."},
            {"name": "The LORD", "role": "The one the son must trust and revere; his discipline is a sign of love (3:5–12)."},
        ],
        4: [
            {"name": "The father", "role": "Recalls how he himself was taught wisdom and passes that teaching to his son (4:1–9)."},
            {"name": "The son", "role": "Urged to guard his heart and keep to the bright path of the righteous (4:20–27)."},
            {"name": "The teacher's father", "role": "Recalled as the one who first taught the speaker wisdom as a boy (4:3–4)."},
        ],
        5: [
            {"name": "The father", "role": "Warns his son against the adulterous woman and calls him to faithfulness with the wife of his youth (5:1–20)."},
            {"name": "The son", "role": "Addressee warned that the LORD sees his path and that wrongdoing entangles its doer (5:21–23)."},
            {"name": "The adulterous woman (literary portrayal)", "role": "A figure in the warning against illicit intimacy; the text does not identify a historical person (5:3–6)."},
        ],
        6: [
            {"name": "The father", "role": "Warns against rash pledges, laziness, and deceit, and returns to the danger of adultery (6:1–35)."},
            {"name": "The son", "role": "Addressee told to learn diligence from the ant and to avoid the seven things the LORD hates (6:6–19)."},
            {"name": "The mother", "role": "Named alongside the father as a source of instruction, her teaching compared to a guiding lamp (6:20)."},
            {"name": "The adulterous woman (literary portrayal)", "role": "Figure in the closing warning against illicit intimacy; the text does not identify a historical person (6:24–35)."},
        ],
        7: [
            {"name": "The father", "role": "Recounts watching from his window as a young man is drawn into temptation, and warns his son to avoid the same path (7:1–27)."},
            {"name": "The young man", "role": "Observed approaching a dangerous street at dusk without judgment, then enticed and led astray (7:6–23)."},
            {"name": "The seductive woman (literary portrayal)", "role": "Entices the young man with promises of pleasure; the text does not identify a historical person (7:10–21)."},
        ],
        8: [
            {"name": "Wisdom (personified)", "role": "A public speaker, represented as a woman, who invites all to understanding and describes her presence at creation (8:1–36)."},
            {"name": "The LORD", "role": "The one by whose work Wisdom says she was present when the world was founded (8:22–31)."},
            {"name": "Rulers and judges", "role": "Public authorities said to govern rightly because of wisdom (8:15–16)."},
        ],
        9: [
            {"name": "Wisdom (personified)", "role": "A hostess who prepares a feast and sends servants to invite the simple into understanding (9:1–6)."},
            {"name": "Folly (personified)", "role": "A competing hostess who offers stolen pleasure while hiding the deadly end of her guests (9:13–18)."},
            {"name": "The wise and the mocker", "role": "Contrasting types of hearers whose different responses to correction illustrate wisdom's value (9:7–12)."},
        ],
        10: [
            {"name": "Solomon", "role": "Named source of the new collection of short sayings that begins this chapter (10:1)."},
            {"name": "The wise and the foolish", "role": "Contrasting figures in the sayings, whose speech and conduct illustrate rival ways of life."},
            {"name": "The righteous and the wicked", "role": "Moral categories whose differing choices bring differing consequences for themselves and others."},
        ],
        11: [
            {"name": "The wise and the foolish", "role": "Contrasting figures whose speech and conduct illustrate rival ways of life."},
            {"name": "The righteous and the wicked", "role": "Moral categories whose differing choices affect themselves and their community."},
            {"name": "Neighbors and citizens", "role": "The surrounding community, shown flourishing or suffering because of honest or destructive conduct (11:9–14)."},
        ],
        12: [
            {"name": "The wise and the foolish", "role": "Contrasting figures whose speech and conduct illustrate rival ways of life."},
            {"name": "The righteous and the wicked", "role": "Moral categories whose differing choices bring differing consequences."},
            {"name": "Workers and witnesses", "role": "Examples of diligent labor and honest testimony held up against laziness and lies (12:11, 17–19)."},
        ],
        13: [
            {"name": "The wise and the foolish", "role": "Contrasting figures whose speech and conduct illustrate rival ways of life."},
            {"name": "The righteous and the wicked", "role": "Moral categories whose differing choices bring differing consequences."},
            {"name": "Parents and children", "role": "Addressed on teachability, discipline, and the inheritance passed between generations (13:1, 22–24)."},
        ],
        14: [
            {"name": "The wise and the foolish", "role": "Contrasting figures whose speech and conduct illustrate rival ways of life."},
            {"name": "The righteous and the wicked", "role": "Moral categories whose differing choices bring differing consequences."},
            {"name": "Kings and the poor", "role": "Connected in the sayings on governing well and treating vulnerable people with compassion (14:28, 31, 35)."},
        ],
        15: [
            {"name": "The wise and the foolish", "role": "Contrasting figures whose speech and conduct illustrate rival ways of life."},
            {"name": "The righteous and the wicked", "role": "Moral categories whose differing choices bring differing consequences."},
            {"name": "Parents and children", "role": "Family instruction and responses to correction, including a son's effect on a father's or mother's joy (15:5, 20)."},
        ],
        16: [
            {"name": "The wise and the foolish", "role": "Contrasting figures whose speech and conduct illustrate rival ways of life."},
            {"name": "The righteous and the wicked", "role": "Moral categories whose differing choices bring differing consequences."},
            {"name": "Kings and rulers", "role": "Judicial decisions and royal duties described as under the LORD's authority (16:10–15)."},
        ],
        17: [
            {"name": "The wise and the foolish", "role": "Contrasting figures whose speech and conduct illustrate rival ways of life."},
            {"name": "The righteous and the wicked", "role": "Moral categories whose differing choices bring differing consequences."},
            {"name": "Friends and family members", "role": "Relationships that supply the examples for loyalty and conflict (17:1, 17, 21)."},
        ],
        18: [
            {"name": "The wise and the foolish", "role": "Contrasting figures whose speech and conduct illustrate rival ways of life."},
            {"name": "The righteous and the wicked", "role": "Moral categories whose differing choices bring differing consequences."},
            {"name": "Friends and disputants", "role": "Relationships and fair hearing feature in the instruction on trust and conflict (18:13, 17, 24)."},
        ],
        19: [
            {"name": "The wise and the foolish", "role": "Contrasting figures whose speech and conduct illustrate rival ways of life."},
            {"name": "The righteous and the wicked", "role": "Moral categories whose differing choices bring differing consequences."},
            {"name": "The poor and the rich", "role": "Economic status and the treatment of neighbors recur through the chapter (19:1, 4–7, 17)."},
        ],
        20: [
            {"name": "The wise and the foolish", "role": "Contrasting figures whose speech and conduct illustrate rival ways of life."},
            {"name": "The righteous and the wicked", "role": "Moral categories whose differing choices bring differing consequences."},
            {"name": "Kings, buyers, and sellers", "role": "Public justice and honest trade are discussed together (20:8, 10, 14, 28)."},
        ],
        21: [
            {"name": "The wise and the foolish", "role": "Contrasting figures whose speech and conduct illustrate rival ways of life."},
            {"name": "The righteous and the wicked", "role": "Moral categories whose differing choices bring differing consequences."},
            {"name": "Kings and needy people", "role": "Royal power and response to the poor are subjects of the sayings (21:1, 13)."},
        ],
        22: [
            {"name": "The wise and the foolish", "role": "Contrasting figures whose speech and conduct illustrate rival ways of life."},
            {"name": "The righteous and the wicked", "role": "Moral categories whose differing choices bring differing consequences."},
            {"name": "The poor and their oppressors", "role": "Justice at the city gate and vulnerability to exploitation are emphasized (22:22–23)."},
        ],
        23: [
            {"name": "The wise and the foolish", "role": "Contrasting figures whose speech and conduct illustrate rival ways of life."},
            {"name": "The righteous and the wicked", "role": "Moral categories whose differing choices bring differing consequences."},
            {"name": "The ruler and his guest", "role": "A teaching scenario cautioning against seductive wealth and hospitality (23:1–3)."},
        ],
        24: [
            {"name": "The wise and the foolish", "role": "Contrasting figures whose speech and conduct illustrate rival ways of life."},
            {"name": "The righteous and the wicked", "role": "Moral categories whose differing choices bring differing consequences."},
            {"name": "Judges and neighbors", "role": "Addressed on fair judgment and timely aid to those in danger (24:11–12, 23–26)."},
        ],
        25: [
            {"name": "Solomon", "role": "Named source of the proverbs in the heading, presented as part of the Solomonic collection (25:1)."},
            {"name": "The men of Hezekiah", "role": "Royal scribes credited with copying out this further collection of Solomon's sayings (25:1)."},
            {"name": "Kings and courtiers", "role": "Public figures whose humility and judgment are examined in several sayings (25:2–7)."},
        ],
        26: [
            {"name": "The wise and the foolish", "role": "Contrasting figures whose speech and conduct illustrate rival ways of life."},
            {"name": "The righteous and the wicked", "role": "Moral categories whose differing choices bring differing consequences."},
            {"name": "The fool and the sluggard", "role": "Recurring literary types whose habits dramatize unwise conduct (26:1–16)."},
        ],
        27: [
            {"name": "The wise and the foolish", "role": "Contrasting figures whose speech and conduct illustrate rival ways of life."},
            {"name": "The righteous and the wicked", "role": "Moral categories whose differing choices bring differing consequences."},
            {"name": "Friends and shepherds", "role": "Social and pastoral roles that supply illustrations of loyalty and stewardship (27:6, 23–27)."},
        ],
        28: [
            {"name": "The wise and the foolish", "role": "Contrasting figures whose speech and conduct illustrate rival ways of life."},
            {"name": "The righteous and the wicked", "role": "Moral categories whose differing choices bring differing consequences."},
            {"name": "Rulers and the poor", "role": "Government and economic integrity, with the sayings condemning predatory power (28:15–16, 27)."},
        ],
        29: [
            {"name": "The wise and the foolish", "role": "Contrasting figures whose speech and conduct illustrate rival ways of life."},
            {"name": "The righteous and the wicked", "role": "Moral categories whose differing choices bring differing consequences."},
            {"name": "Rulers and the poor", "role": "Public figures and vulnerable neighbors whose treatment of one another reveals a regime's justice (29:2, 7, 14)."},
        ],
        30: [
            {"name": "Agur son of Jakeh", "role": "Named speaker of the collection, voicing prayers and observations on human limits (30:1–9)."},
            {"name": "The LORD", "role": "The divine source of pure words and providence to whom Agur's humility is directed (30:4–9)."},
            {"name": "The poor and the needy", "role": "Named in Agur's social warnings; their oppression is condemned (30:14)."},
        ],
        31: [
            {"name": "King Lemuel", "role": "Royal son who receives his mother's instruction on just and sober rule (31:1–9)."},
            {"name": "Lemuel's mother", "role": "Unnamed source of the royal counsel, teaching just leadership and defense of the poor (31:1–9)."},
            {"name": "The capable wife (poetic portrait)", "role": "An idealized woman praised for work, generosity, judgment, and reverence for the LORD (31:10–31)."},
            {"name": "The poor and needy", "role": "Recipients of the capable wife's help and of the legal defense Lemuel is urged to provide (31:8–9, 20)."},
        ],
    }

    themes = {
        1: [
            ("Purpose of instruction", "The opening verses state that Proverbs aims to give wisdom, discipline, and discernment, with reverence for the LORD as the starting point for all of it."),
            ("Resisting predatory pressure", "The father's first warning names a concrete danger: companions who promise quick riches through violence but end up trapped by their own schemes."),
            ("Responding to wisdom", "Wisdom's public call shows that rejecting correction has consequences; those who refuse to listen now will one day call for help and find none."),
        ],
        2: [
            ("Active search for wisdom", "The father compares seeking wisdom to searching for silver or hidden treasure, work that takes real effort rather than passive waiting."),
            ("Discernment and protection", "Wisdom entering the heart guards against crooked speech and companions whose paths are twisted."),
            ("Faithfulness in relationships", "The chapter singles out the woman who has abandoned her marriage covenant as the clearest picture of wisdom's opposite."),
        ],
        3: [
            ("Trust and direction", "Trusting the LORD rather than leaning on one's own understanding is presented as the key to a straight path through life."),
            ("The worth of wisdom", "Wisdom is called more valuable than silver or fine gold and is pictured as a tree of life for those who hold onto her."),
            ("Justice toward neighbors", "Practical commands against withholding help, plotting harm, or envying violent people apply wisdom directly to how a person treats others."),
        ],
        4: [
            ("Wisdom across generations", "The teacher passes on what his own father taught him, showing that wisdom is meant to travel from parent to child."),
            ("Contrasting ways of life", "The righteous path is like dawn growing brighter, while the wicked walk in darkness without knowing what makes them stumble."),
            ("Guarding one's inner life", "The command to keep the heart with all diligence treats inner conviction, not just outward behavior, as the source of a person's conduct."),
        ],
        5: [
            ("Temptation and consequence", "The adulterous woman's words are sweet at first, but the father insists her end is as bitter as wormwood."),
            ("Marital fidelity", "The image of drinking only from one's own cistern calls for exclusive devotion to the wife of one's youth."),
            ("Moral accountability", "The LORD's awareness of every path means that wrongdoing is never truly hidden from him."),
        ],
        6: [
            ("Prudence and diligence", "The ant's unsupervised, seasonal labor models the diligence the father wants his son to practice instead of laziness."),
            ("Integrity in community", "The list of things the LORD hates centers on dishonesty and discord that damage trust between neighbors."),
            ("Fidelity and costly choices", "Carrying fire against one's body pictures how adultery burns the one who risks it, not just the people around him."),
        ],
        7: [
            ("Internalized instruction", "Describing wisdom as a sister and understanding as a near companion urges the son to hold onto the teaching as closely as family."),
            ("Recognizing persuasion", "The young man's fate turns on his failure to recognize flattering, confident speech as a warning sign rather than an invitation."),
            ("The peril of unwise choices", "Following the woman without grasping where the path leads shows how a single uninformed decision can lead to ruin."),
        ],
        8: [
            ("Wisdom's public invitation", "Wisdom calls out at gates and crossroads rather than in secret, open to anyone willing to listen."),
            ("Wisdom and creation", "Describing wisdom as present before the mountains and the deep ties ordinary moral instruction to the order built into creation itself."),
            ("Listening and life", "The chapter ends by tying hearing wisdom directly to finding life, and refusing her to loving death."),
        ],
        9: [
            ("Two invitations", "Wisdom and Folly each build a house and invite the same simple passersby, forcing a choice between two very different outcomes."),
            ("Teachability", "How a mocker and a wise person each respond to correction reveals which invitation they are likely to accept."),
            ("Reverence and knowledge", "The fear of the LORD is named again as the beginning of wisdom, tying the whole scene back to the book's opening claim."),
        ],
        10: [
            ("Integrity and provision", "Honest gain and diligent work are repeatedly connected to lasting provision, while dishonest shortcuts come to nothing."),
            ("Speech and character", "A person's words are shown either nourishing others or causing harm, making speech a direct test of character."),
            ("Long-term moral direction", "The sayings trace how righteousness and wickedness lead to different lasting outcomes rather than just momentary results."),
        ],
        11: [
            ("Honesty in commerce", "False balances are called an abomination to the LORD, tying ordinary business dealings directly to his moral standards."),
            ("Community well-being", "Discretion, reliable counsel, and the conduct of citizens are shown to determine whether an entire city rises or falls."),
            ("Generosity and wealth", "Generosity is pictured as a kind of increase, while hoarding what should be shared is shown to bring eventual loss."),
        ],
        12: [
            ("Teachability and correction", "Loving correction rather than resenting it is treated as a basic mark of the wise."),
            ("Labor and responsibility", "Diligent work is set against careless wishing, with steady labor shown as the only path that actually provides."),
            ("Truthful, healing speech", "Truthful words are described as healing and lasting, while lying speech is only for a moment."),
        ],
        13: [
            ("Openness to instruction", "A teachable child accepts a father's correction, while a scoffer refuses to listen even to rebuke."),
            ("Hope and companionship", "Hope deferred makes the heart sick, and the company a person keeps either sharpens or corrupts their character."),
            ("Household responsibility", "Inheritance and discipline are both framed as responsibilities a household owes to the next generation."),
        ],
        14: [
            ("Discernment beyond appearances", "A road that seems right can still end in death, so the sayings warn against trusting first impressions alone."),
            ("Treatment of vulnerable people", "Mocking the poor is treated as an insult to their Maker, while compassion toward them honors the LORD."),
            ("National and household integrity", "The same wisdom that builds a house is shown to build or ruin a nation, since righteousness exalts a people."),
        ],
        15: [
            ("Speech and conflict", "A gentle answer turns away wrath, while harsh words are shown to stir up the very anger they provoke."),
            ("Integrity over display", "The LORD is said to delight more in honest, humble living than in sacrifices offered without justice."),
            ("Humility and instruction", "The fear of the LORD is tied to instruction in wisdom, and both are said to come before honor."),
        ],
        16: [
            ("Planning and dependence", "People may plan their own way, but the LORD directs the outcome, placing every plan under his authority."),
            ("Justice in leadership and trade", "Honest weights and just judgments are both described as the LORD's business, not just human convention."),
            ("Humility and self-control", "Pride is said to come before a fall, while ruling one's own spirit is valued above conquering a city."),
        ],
        17: [
            ("Peace over abundance", "A dry meal eaten in peace is judged better than a house full of feasting mixed with strife."),
            ("Justice and fair judgment", "Acquitting the guilty and condemning the just are both called an abomination to the LORD."),
            ("Friendship and measured speech", "A true friend loves at all times, and even a fool who stays silent can be thought wise."),
        ],
        18: [
            ("Listening before answering", "Answering a matter before hearing it out is named as both foolish and shameful."),
            ("The force of words", "Life and death are said to be in the power of the tongue, giving ordinary speech real weight."),
            ("Trust and companionship", "The LORD's name is pictured as a strong tower for the righteous, and a loyal friend is valued above a brother."),
        ],
        19: [
            ("Integrity amid inequality", "Walking in integrity while poor is called better than being a fool with crooked lips, regardless of wealth."),
            ("Wisdom in relationships", "Patience and discretion are shown repairing what hasty words and favoritism would otherwise ruin."),
            ("Instruction and divine purpose", "Receiving correction now is tied to the LORD's larger purpose, even when a person's own plans do not work out."),
        ],
        20: [
            ("Temperance and peacemaking", "Wine is called a mocker, and avoiding needless strife is treated as honorable rather than weak."),
            ("Honest work and trade", "Laziness at plowing time and false weights in the market are both condemned as forms of the same dishonesty."),
            ("Fairness and restraint", "Refusing to repay evil for evil and trusting the LORD for vindication are commended over taking revenge."),
        ],
        21: [
            ("Justice before ritual", "Doing justice and judgment is called more acceptable to the LORD than sacrifice offered without it."),
            ("Responsibility and generosity", "Diligent planning and generosity toward the poor are set against hasty greed that leads only to want."),
            ("Limits of power", "Even a well-prepared horse cannot guarantee victory, since safety ultimately belongs to the LORD."),
        ],
        22: [
            ("Character beyond wealth", "A good name is valued above great riches, since both rich and poor meet together before the LORD who made them."),
            ("Justice for the vulnerable", "Robbing the poor or oppressing the afflicted is warned against because the LORD himself will plead their cause."),
            ("Hearing wise instruction", "The appeal to hear \"the words of the wise\" treats careful listening as the doorway into the rest of the chapter's counsel."),
        ],
        23: [
            ("Wealth and appetite", "Resisting a ruler's luxury and the exhausting pursuit of riches are both treated as tests of self-control."),
            ("Instruction and justice", "Care for the fatherless and a child's willingness to learn are joined together as expressions of a truthful heart."),
            ("Warning against drunkenness", "The detailed picture of a drunkard's confusion and craving warns that habitual drinking enslaves rather than satisfies."),
        ],
        24: [
            ("Wisdom builds enduring life", "A household is said to be built by wisdom and understanding, not by the violent schemes envy might suggest."),
            ("Responsibility toward others", "Failing to rescue those being led toward death is treated as a real failure, not a neutral act of staying uninvolved."),
            ("Justice and diligence", "Partiality in judgment and a neglected field are both pictured as failures of the same basic diligence and fairness."),
        ],
        25: [
            ("Responsible authority", "Searching out a matter is called the honor of kings, placing careful judgment at the center of good rule."),
            ("Discretion in disputes", "Settling a matter directly with one's neighbor, rather than exposing a secret, is urged to protect both reputation and relationship."),
            ("Kindness and self-control", "Feeding a hungry enemy and ruling one's own spirit are both held up as forms of strength greater than retaliation."),
        ],
        26: [
            ("Context-sensitive correction", "The paired, seemingly contradictory advice about answering a fool shows that wisdom requires judging each situation rather than applying one fixed rule."),
            ("Folly and laziness", "The sluggard's excuses, like fearing a lion in the road, expose how foolishness dresses up avoidance as caution."),
            ("Deceptive speech", "Flattery and gossip are shown doing real harm precisely because they disguise malice as friendliness."),
        ],
        27: [
            ("Humility about tomorrow", "Boasting about tomorrow is discouraged because no one can be certain what a single day will bring."),
            ("Loyal friendship", "The wounds of a true friend are called faithful, since honest correction serves a person better than flattering silence."),
            ("Practical stewardship", "Knowing the state of one's flocks models attentive, ongoing care rather than assuming wealth will simply last."),
        ],
        28: [
            ("Integrity and confession", "Covering sin is said to bring no success, while confessing and forsaking it brings mercy."),
            ("Justice under rulers", "The people's joy or mourning is tied directly to whether the righteous or the wicked hold authority over them."),
            ("Wealth and fairness", "Increasing wealth through usury or favoritism is condemned because it exploits rather than serves others."),
        ],
        29: [
            ("Correction and restraint", "A person who stiffens their neck against repeated correction is warned that sudden, irreversible ruin can follow."),
            ("Justice in government", "Whether the righteous or the wicked hold power is again shown to decide whether a people rejoices or groans."),
            ("Fear and trust", "The fear of man is called a snare, while trusting the LORD is the only safety the chapter offers from it."),
        ],
        30: [
            ("Humility before divine knowledge", "Agur's confession that he is \"more brutish than any man\" sets the tone for a chapter that prizes humility over claimed expertise."),
            ("Contentment and truth", "Agur's prayer for neither poverty nor riches shows that contentment, not accumulation, is what guards a person from denying or dishonoring God."),
            ("Learning from observation", "Small creatures like ants and conies are offered as living lessons in wisdom learned simply by watching the world closely."),
        ],
        31: [
            ("Just use of authority", "Lemuel's mother ties sober judgment directly to a ruler's duty to defend the poor and the voiceless."),
            ("Diligence and generosity", "The capable wife's constant work provides for her household while her open hand reaches beyond it to the poor."),
            ("Wisdom above appearances", "The poem's climax values reverence for the LORD over the beauty and favor it has just finished describing in detail."),
        ],
    }

    audiences = {
        7: "Readers who already knew the father's earlier warnings about the adulterous woman (chapters 2, 5, and 6) would recognize this scene as that same danger acted out in vivid, memorable detail rather than as a report of one identified incident.",
        8: "Later readers, Jewish and Christian alike, treasured this chapter for how it ties everyday wisdom to creation itself; many Christian readers have also heard an echo of Christ in Wisdom's nearness to God before the world began.",
        10: "Readers moving from chapters 1–9 into this new heading would recognize the shift from one sustained father's appeal to a long series of independent, two-line sayings meant to be weighed one at a time rather than read as a single argument.",
        25: "Readers in and after Hezekiah's reign, a time of religious reform and renewed interest in Judah's written heritage, would have recognized this heading as evidence that older royal wisdom was still being gathered and valued generations after Solomon.",
        29: "Readers who had followed the sayings on rulers and the poor since chapter 25 would hear this chapter's close as the climax of that theme, tying a ruler's justice and a people's trust in the LORD together one final time.",
        31: "Readers familiar with Hebrew acrostic poems, such as several psalms, would recognize the alphabetic structure of verses 10–31 as a deliberate literary form meant to present the capable woman as a complete, well-rounded picture from A to Z.",
    }

    explained_references_overrides = {
        16: [
            {"verse": 20, "reference": "", "explanation": ""},
        ],
    }

    for chapter in range(1, 32):
        key = f"Proverbs {chapter}"
        insights[key]["summary"] = summaries[chapter]
        insights[key]["whereWeAre"] = placement[chapter]
        insights[key]["keyFigures"] = key_figures[chapter]
        insights[key]["keyThemes"] = [
            {"theme": name, "explanation": explanation, "references": old["references"]}
            for (name, explanation), old in zip(themes[chapter], insights[key]["keyThemes"])
        ]
        if chapter in audiences:
            context[key]["audience"] = audiences[chapter]

    # explainedReferences is untouched except where noted; drop the placeholder entry above.
    del explained_references_overrides

    # Fix the run-together citation in Proverbs 16's summary was already handled by writing
    # the summary text above with a semicolon-separated parenthetical.

    save(insights_path, insights)
    save(context_path, context)
    save(moments_path, moments)
    save(overview_path, overview)

    # Fix capitalized pronouns for God in the Proverbs story prose (outside quotations).
    story = story_path.read_text(encoding="utf-8")
    start = story.index("# Proverbs")
    end = story.index("# Ecclesiastes", start)
    section = story[start:end]
    section = section.replace("to honor and trust Him with deep respect", "to honor and trust him with deep respect")
    section = section.replace("making a loan to God Himself", "making a loan to God himself")
    section = section.replace("And He cares more about how we live", "And he cares more about how we live")
    story_path.write_text(story[:start] + section + story[end:], encoding="utf-8")


if __name__ == "__main__":
    main()
