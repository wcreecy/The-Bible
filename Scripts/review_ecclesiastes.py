#!/usr/bin/env python3
"""Apply the completed editorial review for Ecclesiastes to source content only."""

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    insights_path = ROOT / "chapter_insights/21_ecclesiastes.json"
    moments_path = ROOT / "historical_moments/09_job_song.json"
    context_path = ROOT / "chapter_context/22_ecclesiastes_song.json"
    overview_path = ROOT / "book_overviews/04_wisdom.json"
    story_path = ROOT / "book_content/04_wisdom.md"

    insights = load(insights_path)
    moments = load(moments_path)
    context = load(context_path)
    overview = load(overview_path)

    placement = {
        1: "Proverbs ended with the praise of a capable woman and its repeated call to fear the LORD. Ecclesiastes opens with a different wisdom voice, the Preacher, who tests whether any amount of toil or learning leaves lasting gain under the sun. Chapter 2 continues the search, turning from general observation to the Preacher's own experiments with pleasure and achievement.",
        2: "Chapter 1 found that increased knowledge brings grief rather than lasting answers. Here the Preacher tests pleasure, building projects, and wealth on a royal scale, and still finds no enduring gain, though he commends simple enjoyment of food and work as a gift from God. Chapter 3 turns from the Preacher's own experiments to a wider reflection on God's timing for every event.",
        3: "Chapter 2 ended by calling enjoyment of one's labor a gift from God. Here the Preacher's famous poem names a fitting time for every human activity and admits that people cannot grasp the whole of God's work, even as he trusts God will judge injustice. Chapter 4 turns from these cosmic reflections to very ordinary abuses: oppression, envy, and loneliness.",
        4: "Chapter 3 affirmed that God judges even when courts fail to. Here the Preacher looks at oppression, competitive toil, and the isolation of working without companionship, while praising the strength two people have together. Chapter 5 turns from these social observations to counsel about approaching God and money with the same clear-eyed caution.",
        5: "Chapter 4 praised companionship as a defense against isolation and hard labor. Here the Preacher warns against careless words and unpaid vows in worship, and against trusting wealth that cannot satisfy or be carried into death. Chapter 6 continues the theme of wealth's limits with the sharper case of someone who has riches but cannot enjoy them.",
        6: "Chapter 5 warned that wealth cannot buy lasting satisfaction. Here the Preacher sharpens that point with the case of a man given riches, children, and long life who still cannot enjoy any of it. Chapter 7 turns from this specific case to a string of proverb-like comparisons about wisdom, mourning, and patience.",
        7: "Chapter 6 showed that even a long, full life proves nothing if it brings no enjoyment. Here the Preacher strings together proverbs that often reverse ordinary expectations, praising mourning over feasting and patience over pride, while admitting wisdom has real limits. Chapter 8 turns from these general proverbs to the specific test case of living wisely under a king's authority.",
        8: "Chapter 7 admitted that wisdom cannot straighten everything God has made crooked. Here the Preacher counsels careful discretion under a king's absolute power and wrestles with wrongdoing that goes unpunished for a time. Chapter 9 widens the lens from one king's court to the single fate, death, that comes to everyone.",
        9: "Chapter 8 wrestled with justice delayed under human authority. Here the Preacher insists that the same fate, death, comes to the righteous and the wicked alike, and urges full-hearted enjoyment of ordinary life while it lasts, closing with a story of wisdom that saves a city yet goes unrewarded. Chapter 10 continues with more of the short, proverb-style sayings the book has already used to test wisdom's practical value.",
        10: "Chapter 9 closed with a poor wise man whose rescue of a city was quickly forgotten. Here the sayings continue in the same short, two-line style, warning that a little folly can undo a great reputation and exposing careless rulers and reckless speech. Chapter 11 turns from these warnings about folly to a final call toward generous, diligent action despite an uncertain future.",
        11: "Chapter 10 warned how a little folly can spoil a lifetime of wisdom. Here the Preacher urges generous, diligent action even without full knowledge of outcomes, and calls the young to enjoy life while remembering that God will judge their conduct. Chapter 12 closes the book with a poem on aging and death and a final summons to fear God.",
        12: "Chapter 11 called the young to enjoy life while remembering coming judgment. Here a poem pictures the body's decline in old age, dust returning to earth and the spirit to God, before a closing voice sums up the Preacher's search with a final charge to fear God and keep his commandments. The next book, Song of Solomon, turns from this search for meaning to a single sustained love poem between a bride and her beloved.",
    }

    summaries_overrides = {
        11: "The speaker urges generous, active conduct despite uncertainty: send bread upon the waters, share portions widely, and do not let unpredictable weather stop all sowing (Ecclesiastes 11:1–6). Since no one knows how God's work unfolds, the wise response is to act diligently in the morning and evening while results remain unknown (Ecclesiastes 11:6). Light and years of life are pleasant, yet dark days must be remembered (Ecclesiastes 11:7–8). Young people are invited to rejoice in their youth while remembering that God will bring conduct into judgment (Ecclesiastes 11:9–10).",
    }

    key_figures = {
        1: [
            {"name": "Qoheleth (the Preacher)", "role": "Royal-sounding first-person voice who investigates work and wisdom. He poses the book's governing questions (1:1,12–18)."},
            {"name": "Generations of people", "role": "Successive human generations in the opening poem. Their passage contrasts with recurring natural patterns (1:4,11)."},
        ],
        2: [
            {"name": "Qoheleth (the Preacher)", "role": "Tests pleasure, building projects, and wealth on a royal scale, then commends simple enjoyment of food and work as a gift from God (2:1–11, 24–26)."},
            {"name": "God", "role": "Named as the giver of the enjoyment and satisfaction that toil alone cannot produce (2:24–26)."},
            {"name": "The wise and the fool", "role": "Contrasting human types compared by the speaker. Both face mortality even though wisdom has relative value (2:12–16)."},
            {"name": "A future successor", "role": "Unidentified inheritor of the speaker's labor. The possibility of inheritance heightens anxiety about lasting control (2:18–21)."},
        ],
        3: [
            {"name": "Qoheleth (the Preacher)", "role": "Names a fitting time for every human activity and affirms that God, not human effort, judges the righteous and the wicked (3:1–17)."},
            {"name": "God", "role": "Said to make everything fitting in its time and to judge the righteous and the wicked, even when human courts fail to (3:11,17)."},
            {"name": "Human beings and animals", "role": "Living creatures subject to death. Their shared mortality exposes human limitations (3:18–21)."},
            {"name": "The wicked and the righteous", "role": "Groups invoked amid observations about courts and justice. Their contrast raises the question of divine judgment (3:16–17)."},
        ],
        4: [
            {"name": "Qoheleth (the Preacher)", "role": "Observes oppression, competitive toil, and isolation, then praises the practical strength two companions have together (4:1–12)."},
            {"name": "Oppressed people and oppressors", "role": "Groups used to expose inequality of power. Their contrast anchors the lament over unchecked suffering (4:1–3)."},
            {"name": "The solitary worker", "role": "Representative individual who works endlessly without companionship. His question exposes an aimless pursuit of wealth (4:7–8)."},
            {"name": "Companions", "role": "Partners in travel and mutual aid. Their cooperation offers practical protection (4:9–12)."},
            {"name": "A poor wise youth and an old foolish king", "role": "Contrasting figures in the concluding political reflection. They expose the instability of status and public approval (4:13–16)."},
        ],
        5: [
            {"name": "Qoheleth (the Preacher)", "role": "Warns against careless vows in worship and against trusting riches that cannot satisfy or be carried into death (5:1–17)."},
            {"name": "God", "role": "The one approached in worship and named as the giver of the days and enjoyment a person receives (5:1–7,18–20)."},
            {"name": "Worshipers who make vows", "role": "People addressed about speech before God. Their vows must not be treated lightly (5:1–7)."},
            {"name": "The poor and officials", "role": "Those harmed by oppression and those occupying administrative ranks. They illustrate structural injustice (5:8–9)."},
            {"name": "The wealthy person", "role": "Representative owner whose riches can produce anxiety or be lost. His vulnerability reveals wealth's insecurity (5:10–17)."},
        ],
        6: [
            {"name": "Qoheleth (the Preacher)", "role": "Presents the sharpened case of a man given wealth, children, and long life who still cannot enjoy any of it (6:1–6)."},
            {"name": "God", "role": "Named as the one who gives riches and honor, yet withholds the power to enjoy them in this chapter's example (6:2)."},
            {"name": "A wealthy but unsatisfied person", "role": "Hypothetical person blessed materially but denied enjoyment. He illustrates the gap between possession and contentment (6:1–2)."},
            {"name": "A person with many children and a long life", "role": "An exaggerated example of expected ancient blessings. Even these measures do not guarantee satisfaction (6:3–6)."},
            {"name": "The wise and the fool", "role": "Contrasted types used in a rhetorical question. They share limits amid unfulfilled desire (6:8)."},
        ],
        7: [
            {"name": "Qoheleth (the Preacher)", "role": "Strings together proverbs that reverse ordinary expectations and admits that complete wisdom and moral fairness both lie beyond human reach (7:1–29)."},
            {"name": "God", "role": "Said to have made humanity upright and to set prosperity and adversity over against each other (7:14,29)."},
            {"name": "The wise and fools", "role": "Contrasting types throughout the sayings. Their habits illustrate the relative value of correction and patience (7:4–12)."},
            {"name": "The righteous and the wicked", "role": "People whose outcomes do not fit simple expectations. Their contrasting fates challenge easy formulas (7:15–18)."},
            {"name": "A woman portrayed as a snare", "role": "Negative poetic figure in the speaker's frustrated search. The language reflects the argument's perspective and cannot justify a universal assertion about women (7:26–28)."},
        ],
        8: [
            {"name": "Qoheleth (the Preacher)", "role": "Counsels discretion under a king's absolute power and wrestles with wrongdoing that goes unpunished for a time (8:1–14)."},
            {"name": "God", "role": "Said to make it well with those who fear him, even though his full work remains impossible to discover (8:12,17)."},
            {"name": "The king", "role": "Ruler whose commands carry coercive power. The speaker urges discernment before royal authority (8:2–5)."},
            {"name": "The righteous and the wicked", "role": "Moral categories whose fortunes can be reversed. Their outcomes create an unresolved puzzle (8:10–14)."},
            {"name": "The wise", "role": "Those who seek explanations of events. Even their investigations cannot encompass God's work (8:16–17)."},
        ],
        9: [
            {"name": "Qoheleth (the Preacher)", "role": "Insists that one fate, death, overtakes the righteous and the wicked alike, and urges whole-hearted enjoyment of ordinary life while it lasts (9:1–10)."},
            {"name": "God", "role": "Named as the one in whose hand the righteous and the wise already rest (9:1)."},
            {"name": "The living and the dead", "role": "Human groups contrasted around awareness and earthly activity. Their contrast stresses present responsibility and mortality (9:3–10)."},
            {"name": "A poor wise man", "role": "Unidentified figure in the closing example. His overlooked rescue illustrates society's failure to honor wisdom (9:14–16)."},
            {"name": "A great king and a besieged city", "role": "Figures in the illustration of military danger. They expose the relative power of wisdom and military force (9:14–15)."},
        ],
        10: [
            {"name": "Qoheleth (the Preacher)", "role": "Continues the book's short, two-line sayings, warning that a little folly can spoil a great reputation (10:1–20)."},
            {"name": "The wise and fools", "role": "Contrasting types throughout the sayings. Their habits affect reputation, work and speech (10:1–15)."},
            {"name": "Rulers, princes and a king", "role": "Political figures in examples of good and bad administration. Their maturity and habits affect public welfare (10:4–7,16–20)."},
            {"name": "Workers", "role": "People digging, breaking walls and chopping wood. Their tasks illustrate practical risk and preparation (10:8–11)."},
        ],
        11: [
            {"name": "Qoheleth (the Preacher)", "role": "Urges generous, diligent action despite uncertainty and calls the young to enjoy life while remembering coming judgment (11:1–10)."},
            {"name": "God", "role": "Named as the one whose work cannot be fully known in advance and who will bring every youthful choice into judgment (11:5,9)."},
            {"name": "The sower", "role": "Representative worker tending crops despite uncertain weather. His labor teaches action without complete prediction (11:4–6)."},
            {"name": "The young person", "role": "Person addressed in the closing exhortation. Youthful enjoyment is paired with moral accountability (11:9–10)."},
        ],
        12: [
            {"name": "Qoheleth (the Preacher)", "role": "Pictures the body's decline in old age and is then described by a closing voice as one who taught the people knowledge with care (12:1–12)."},
            {"name": "God", "role": "Named as the Creator to be remembered in youth and as the one to whom the departing spirit returns (12:1,7)."},
            {"name": "The young person", "role": "Person urged to remember the Creator. Early attention to mortality and responsibility frames the final poem (12:1)."},
            {"name": "The closing narrator", "role": "Voice speaking about the Preacher in the third person. He evaluates the teachings and provides the book's concluding admonition (12:9–14)."},
            {"name": "The aged person", "role": "A poetic figure built from bodily and household images, such as trembling keepers and a broken bowl, that pictures the approach of death (12:2–7)."},
        ],
    }

    themes = {
        1: [
            ("Life's transience", "Generations rise and pass while the sun, wind, and rivers keep repeating the same courses, showing how brief a single lifetime looks against the natural world's endless cycles."),
            ("Limits of human achievement", "Even a king's determined, wide-ranging research cannot straighten what is already crooked, showing that effort and resources alone cannot force the world to make full sense."),
            ("Wisdom and sorrow", "Gaining more wisdom and knowledge is shown to increase grief rather than remove it, since clearer sight of the world's problems does not solve them."),
        ],
        2: [
            ("Pleasure and possessions", "Testing laughter, wine, building projects, and every luxury a king could gather still ends in the same verdict: none of it provides lasting gain."),
            ("Wisdom and mortality", "Wisdom is granted a real advantage over folly, like light over darkness, but that advantage disappears at death, since the wise and the fool are both eventually forgotten."),
            ("Work, legacy and enjoyment", "Grief over leaving one's labor to an unproven successor is set against the closing counsel that ordinary enjoyment of food and work is itself a gift from God."),
        ],
        3: [
            ("Seasons of life", "The poem's fourteen paired opposites show that contrasting experiences, from birth to death and war to peace, all have their appointed place rather than being signs that something has gone wrong."),
            ("Divine time and human limits", "God is said to make everything fitting in its time, but people cannot grasp the whole of that design, so toil is received as a gift rather than fully explained."),
            ("Justice and mortality", "Corrupt courts raise the question of justice, which the speaker answers by trusting God to judge, even as the shared mortality of humans and animals keeps the future hidden."),
        ],
        4: [
            ("Oppression without comfort", "The tears of the oppressed go unanswered because power rests entirely with their oppressors, leaving no one positioned to comfort them."),
            ("Ambition, rest and isolation", "Rivalry is named as the hidden engine behind much hard work, yet the solitary worker who never asks for whom he labors shows that ambition without companionship produces only emptiness."),
            ("Value of companionship", "Two companions can lift, warm, and defend each other in ways a solitary person cannot manage alone, and a third person makes that support even harder to break."),
            ("Fragility of popularity", "A poor but wise youth can rise above an old foolish king, yet the chapter notes how quickly a new ruler's admirers move on, showing that public approval never lasts long."),
        ],
        5: [
            ("Reverence in worship", "Listening carefully and keeping vows are valued over quick words or careless sacrifices, since rash promises made to God still have to be paid."),
            ("Oppression in public life", "Seeing one official oversee another is not a reason for shock, since layered authority can both restrain and enable the oppression it is meant to prevent."),
            ("Limits of money", "A lover of money is never satisfied, and growing wealth brings growing anxiety and dependents rather than security, since none of it can be carried into death."),
            ("Enjoyment as gift", "Finding real satisfaction in one's food, drink, and work is presented as something God gives rather than something wealth can guarantee on its own."),
        ],
        6: [
            ("Possession versus enjoyment", "Having wealth, possessions, and honor is shown to mean little when a person lacks the power to actually enjoy them, since someone else ends up receiving the benefit instead."),
            ("Quantity of life and quality of life", "Many children and a long life, the ancient world's clearest signs of blessing, are judged worthless next to a stillborn child if they never bring real satisfaction."),
            ("Unfulfilled appetite and uncertainty", "Labor keeps feeding appetite without ever fully satisfying it, and since no one can know what is truly good for their short life, even wisdom and poverty offer only limited help."),
        ],
        7: [
            ("Learning through adversity", "A house of mourning is said to teach more than a house of feasting, since facing death and correction seriously shapes character in ways celebration cannot."),
            ("Patience and wisdom", "Wisdom functions like inherited property, offering real protection, yet the speaker admits that no one can straighten everything God has made crooked."),
            ("Unpredictable moral outcomes", "Seeing the righteous perish while the wicked prolong their lives undercuts any simple formula connecting good behavior to good outcomes, and warns against both self-righteousness and excess."),
            ("Wisdom's limits and human failure", "A determined search for wisdom still falls short, since the speaker concludes that God made humanity upright, but people have pursued their own many schemes instead."),
        ],
        8: [
            ("Wisdom under authority", "A wise person reads a king's commands carefully, since royal power carries real danger and few safe ways to object once a decision is made."),
            ("Delayed justice", "Wicked people sometimes receive public honor while the righteous are treated as if they were wicked, a reversal that emboldens wrongdoing when punishment does not arrive quickly."),
            ("Joy amid unanswered questions", "Even though the wise cannot fully discover everything God does under the sun, the speaker still commends ordinary enjoyment of food, drink, and work."),
        ],
        9: [
            ("Mortality shared by all", "Death overtakes the righteous and the wicked, the clean and the unclean, alike, ending every living person's part in what happens under the sun."),
            ("Everyday joy and purposeful work", "Because death comes to all, the speaker urges enjoying food, clean clothing, marriage, and wholehearted work now, while the chance to act still exists."),
            ("Chance and fragile success", "Even the swiftest racer or strongest fighter can lose, since unforeseen events intervene in ways that no skill alone can guarantee against."),
            ("Wisdom unrecognized", "A poor wise man saves his city yet is quickly forgotten, showing that wisdom can accomplish real good even while society fails to honor the person who supplied it."),
        ],
        10: [
            ("Small folly, large consequences", "A dead fly spoiling a jar of perfume pictures how a small lapse can undo a reputation built on real wisdom, especially when fools end up in positions of honor."),
            ("Skill and preparation", "Digging, wall-breaking, and woodcutting all carry ordinary risks that foresight and a sharpened tool can reduce, making preparation itself a form of wisdom."),
            ("Responsible speech", "Words can reveal or ruin a person, since endless talk exposes folly and even a private curse against a king is warned against because words have a way of traveling."),
            ("Public leadership and neglect", "A land suffers under rulers who feast carelessly in the morning, while neglected houses and roofs show what happens when ordinary maintenance is ignored."),
        ],
        11: [
            ("Generosity and risk", "Sending bread upon the waters and sharing with several people pictures generosity offered without any guarantee of when, or whether, it will return."),
            ("Act without full knowledge", "Since no one can explain how a body is formed in the womb, the speaker concludes that people should keep working morning and evening rather than waiting for certainty about outcomes."),
            ("Enjoyment and accountability", "Years of light and youth are called genuinely pleasant, but that enjoyment is paired with the reminder that God will bring every choice into judgment."),
        ],
        12: [
            ("Remembering the Creator", "The call to remember the Creator in youth urges a response to God before the body's strength and the mind's pleasure begin to fade with age."),
            ("Aging and death", "A series of images, trembling keepers, failing grinders, and a broken bowl, pictures the body's decline until dust returns to the earth and the spirit returns to God."),
            ("Wise teaching and discernment", "The Preacher is remembered as someone who carefully taught and arranged true sayings, which are compared to goads that prod a reader toward action rather than endless, wearying study."),
            ("Reverence and accountability", "The book's search ends with a single charge, to fear God and keep his commandments, because God will judge every deed, however hidden."),
        ],
    }

    moment_overrides = {
        1: "The book opens as the words of \"the Preacher, the son of David, king in Jerusalem\" (Ecclesiastes 1:1); tradition identifies him as Solomon, reflecting late in his reign.",
        2: "The Preacher describes building houses, planting vineyards, and gathering silver, gold, singers, and servants, as a king of Jerusalem could (Ecclesiastes 2:4–9).",
        6: "The Preacher turns to a specific case: wealth, long life, and children given to someone who still cannot enjoy any of it.",
        8: "Ecclesiastes 8 turns to counsel about living safely under a king's absolute authority, before returning to the problem of justice delayed.",
        10: "The sayings continue in the same short, two-line proverb style, with no new heading, date, or named ruler.",
        12: "A closing voice describes how the Preacher \"taught the people knowledge\" and arranged his sayings with care (Ecclesiastes 12:9–10), framing the book's final poem on aging and death.",
    }

    audience_overrides = {
        1: "The first readers would have recognized the Hebrew title Qoheleth, meaning one who gathers an assembly, and would have expected a king's own reflection on whether a lifetime of wisdom and work left anything of lasting value.",
        2: "Readers who knew royal building projects and courts, Solomon's temple and palace works among them, would recognize this catalogue of houses, vineyards, and singers as the kind of excess only a king could actually attempt and test.",
        6: "Readers who measured a blessed life by wealth, many children, and a proper burial would feel the force of the Preacher's claim that none of those markers guarantee the satisfaction they are assumed to bring.",
        8: "Readers who lived under a king's unquestioned decrees, where disobeying \"the oath of God\" sworn to a ruler carried real risk, would recognize why the Preacher counsels careful discretion rather than open defiance.",
        10: "Readers already following this run of short sayings would read the jabs at careless rulers, risky labor, and loose talk as further test cases for the wisdom the book has been commending all along.",
        12: "Readers steeped in the law's call to \"fear God, and keep his commandments\" would hear the closing summons in Ecclesiastes 12:13 as the Preacher's unsettling search settling, at last, into the same covenant loyalty already expected of Israel.",
    }

    for chapter in range(1, 13):
        key = f"Ecclesiastes {chapter}"
        if chapter in summaries_overrides:
            insights[key]["summary"] = summaries_overrides[chapter]
        insights[key]["whereWeAre"] = placement[chapter]
        insights[key]["keyFigures"] = key_figures[chapter]
        insights[key]["keyThemes"] = [
            {"theme": name, "explanation": explanation, "references": old["references"]}
            for (name, explanation), old in zip(themes[chapter], insights[key]["keyThemes"])
        ]
        if chapter in moment_overrides:
            moments[key] = moment_overrides[chapter]
        if chapter in audience_overrides:
            context[key]["audience"] = audience_overrides[chapter]

    # Overview: lead with traditional authorship, use double-quoted exact KJV wording, lowercase
    # pronouns for God, and a key verse that captures the whole book's conclusion.
    book = overview["Ecclesiastes"]
    book["author"] = ("Solomon is the traditional author, writing as \"the Preacher, the son of David, king in "
                       "Jerusalem\" (Ecclesiastes 1:1) and called Qoheleth in Hebrew; many scholars instead date "
                       "the book's Hebrew style to a later writer composing in Solomon's voice.")
    book["audience"] = "Israelites and other readers wrestling with life's brevity, frustration, and unpredictability."
    book["purpose"] = ("To expose the limits of life pursued \"under the sun\" and to direct readers toward humble "
                        "enjoyment of God's gifts and reverence for God.")
    book["keyVerse"] = "Ecclesiastes 12:13"
    book["keyFigures"][0]["description"] = ("The main speaker, described as a son of David and king in Jerusalem, "
                                             "who searches for meaning \"under the sun.\"")
    book["keyFigures"][1]["description"] = ("The voice that introduces the Teacher and closes the book with the "
                                             "call to fear God and keep his commandments.")

    save(insights_path, insights)
    save(context_path, context)
    save(moments_path, moments)
    save(overview_path, overview)

    # Fix capitalized pronouns for God in the Ecclesiastes story prose (outside quotations).
    story = story_path.read_text(encoding="utf-8")
    start = story.index("# Ecclesiastes")
    end = story.index("# Song of Solomon", start)
    section = story[start:end]
    section = section.replace(
        "People cannot discover all His work, so they are encouraged to do good and receive their labor as God's gift while revering Him.",
        "People cannot discover all his work, so they are encouraged to do good and receive their labor as God's gift while revering him.",
    )
    section = section.replace("be careful how you approach Him", "be careful how you approach him")
    section = section.replace(
        "The Preacher maintains reverence for God while admitting His work cannot be fully discovered.",
        "The Preacher maintains reverence for God while admitting his work cannot be fully discovered.",
    )
    section = section.replace(
        "The conclusion calls humanity to fear God and keep His commandments, for God will judge every work.",
        "The conclusion calls humanity to fear God and keep his commandments, for God will judge every work.",
    )
    story_path.write_text(story[:start] + section + story[end:], encoding="utf-8")


if __name__ == "__main__":
    main()
