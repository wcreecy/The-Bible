#!/usr/bin/env python3
"""Apply the completed editorial review for Song of Solomon to source content only."""

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent


def load(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    insights_path = ROOT / "chapter_insights/22_song_of_solomon.json"
    context_path = ROOT / "chapter_context/22_ecclesiastes_song.json"
    overview_path = ROOT / "book_overviews/04_wisdom.json"

    insights = load(insights_path)
    context = load(context_path)
    overview = load(overview_path)

    placement = {
        1: "Ecclesiastes closed by directing weary searchers to fear God above every earthly pursuit. Song of Solomon opens a very different kind of wisdom book, a sustained love poem in which a woman and her beloved exchange praise and desire. Chapter 2 continues their voices into springtime imagery and the woman's repeated warning not to rush love.",
        2: "Chapter 1 introduced the woman and her beloved trading praise for one another's beauty. Here their voices continue through springtime imagery, culminating in the woman's declaration of mutual belonging and her warning not to awaken love before its time. Chapter 3 turns from this daylight scene to a nighttime search and a royal wedding procession.",
        3: "Chapter 2 ended with the woman and her beloved delighting in a shared springtime. Here she first searches the night streets for him, then the poem shifts abruptly to Solomon's guarded wedding procession arriving from the wilderness. Chapter 4 turns from that public spectacle back to the man's own extended praise of his beloved.",
        4: "Chapter 3 closed with Solomon's splendid wedding procession. Here the man returns to intimate praise, describing his beloved from head to toe and picturing her as an enclosed garden and sealed spring, until she invites him in. Chapter 5 answers that invitation, then turns to a night of separation and searching.",
        5: "Chapter 4 ended with the woman inviting her beloved into her garden. Here he answers that invitation, but the chapter quickly turns to a night of missed connection: he comes to her door, she hesitates, and he is gone before she can open it. Chapter 6 picks up the search the daughters of Jerusalem offer to join.",
        6: "Chapter 5 left the woman searching the city for her beloved after he had withdrawn from her door. Here she answers that she already knows where he is, in his garden, and the man responds with another extended, admiring description of her. Chapter 7 continues that praise, moving further through images of her body and an invitation to the countryside.",
        7: "Chapter 6 closed with a call to the Shulammite and a question about why others want to gaze at her. Here the man answers with another sweeping description of her beauty, and she responds by inviting him into the fields and vineyards. Chapter 8, the book's last, gathers the poem's themes of timing, permanence, and desire into a closing exchange.",
        8: "Chapter 7 ended with the woman inviting her beloved into the vineyards. Here the book closes with its most direct statement about love's strength, a family's concern for a younger sister's future, a contrast between Solomon's rented vineyard and the woman's own, and a final call for the beloved to hurry back. The next book, Isaiah, turns from this celebration of human love to the voice of a prophet confronting Judah's unfaithfulness to God.",
    }

    summaries_overrides = {
        6: ("The daughters of Jerusalem ask where the beloved has gone and offer to seek him (Song of Solomon 6:1). "
            "The woman responds that he has gone to his garden and repeats their mutual belonging (Song of Solomon 6:2–3). "
            "A male voice praises her as beautiful as Tirzah and Jerusalem and awe-inspiring as an army with banners; "
            "he describes her hair, teeth, and cheeks and declares her unique among queens, concubines, and maidens "
            "(Song of Solomon 6:4–10). A brief garden scene follows, and the closing call addresses the Shulammite, "
            "with an answering question about why others wish to gaze at her (Song of Solomon 6:11–13)."),
    }

    key_figures = {
        1: [
            {"name": "The woman", "role": "Principal poetic voice expressing desire, self-description, and affection. Her words set the pattern for the book's two main speakers (1:2–8)."},
            {"name": "The beloved man", "role": "Addressed as a shepherd-like lover and answers her opening praise with his own (1:9–17)."},
            {"name": "Daughters of Jerusalem", "role": "Addressed by the woman throughout the poem as a listening chorus (1:4–5)."},
            {"name": "The woman's brothers", "role": "Assigned her vineyard-keeping work, leaving her no time to care for her own appearance (1:6)."},
            {"name": "Solomon", "role": "Named in the heading that associates the whole collection with him (1:1)."},
        ],
        2: [
            {"name": "The woman", "role": "Celebrates love, gives the recurring refrain, and voices desire and reciprocal belonging (2:1,16)."},
            {"name": "The beloved man", "role": "Praised as an apple tree and a gazelle-like visitor, and speaks the invitation into springtime (2:3,8–13)."},
            {"name": "Daughters of Jerusalem", "role": "Hear the woman's solemn refrain not to awaken love before its time (2:7)."},
            {"name": "The unnamed voices who catch foxes", "role": "A plural voice within the vineyard imagery, instructing that the little foxes spoiling the vines be caught; the speakers' identity is not specified (2:15)."},
        ],
        3: [
            {"name": "The woman", "role": "Searches for her beloved at night and brings him to her mother's house once she finds him (3:1–4)."},
            {"name": "The beloved man", "role": "Sought and found in the nighttime scene; his presence resolves the woman's searching (3:4)."},
            {"name": "City watchmen", "role": "Encounter the woman on her search through the city streets (3:3)."},
            {"name": "Daughters of Jerusalem (Zion)", "role": "Receive the warning not to awaken love and the invitation to see Solomon's royal display (3:5,11)."},
            {"name": "Solomon", "role": "Arrives in a guarded, richly furnished litter escorted by sixty of Israel's mightiest soldiers, crowned by his mother on his wedding day (3:6–11)."},
            {"name": "Solomon's mother", "role": "Crowns Solomon for his wedding day; her own name is not supplied here (3:11)."},
        ],
        4: [
            {"name": "The beloved man", "role": "Speaks the extended praise and addresses the woman as his bride, establishing admiration through garden and body imagery (4:1–11)."},
            {"name": "The woman", "role": "Addressed throughout as the enclosed garden and sealed spring, and speaks the closing invitation that gives the poem a reciprocal conclusion (4:12–16)."},
            {"name": "David", "role": "Named only in the metaphor of the tower of David, a recognizable image rather than an active participant (4:4)."},
        ],
        5: [
            {"name": "The woman", "role": "Narrates the unanswered visit, the watchmen's assault, and her praise of her lover. Her first-person perspective communicates longing, distress, and loyalty (5:2–16)."},
            {"name": "The beloved man", "role": "Speaks at the opening and at the woman's door, then becomes the subject of her extended praise; his withdrawal creates the separation scene (5:1–6)."},
            {"name": "City watchmen", "role": "Beat and wound the woman and remove her veil; their conduct is depicted as harm, not modeled as acceptable (5:7)."},
            {"name": "Daughters of Jerusalem", "role": "Ask why the beloved is unlike others, prompting the woman's extended description of him (5:9)."},
            {"name": "Friends", "role": "Addressed in the invitation to eat and drink; they serve as a communal audience whose specific identities are not given (5:1)."},
        ],
        6: [
            {"name": "Daughters of Jerusalem", "role": "Ask where the beloved has gone and offer to help look for him (6:1)."},
            {"name": "The woman", "role": "Affirms where her beloved is and repeats their reciprocal belonging, countering the chapter's opening anxiety (6:2–3)."},
            {"name": "The beloved man", "role": "Praises the woman using city, garden, and royal court images, and describes her as uniquely cherished (6:4–10)."},
            {"name": "The Shulammite", "role": "Named in the closing verse as the one the chorus calls to return, likely identifying the woman herself (6:13)."},
            {"name": "Queens, concubines, and maidens", "role": "Groups named in the man's comparison to heighten the contrast with the beloved's uniqueness (6:8–9)."},
        ],
        7: [
            {"name": "The woman", "role": "Praised in the opening and speaks the invitation to the countryside; her voice expresses desire and initiative (7:10–13)."},
            {"name": "The beloved man", "role": "Describes the woman's beauty and expresses longing, offering a principal example of the poem's sensual praise (7:1–9)."},
            {"name": "The prince's daughter", "role": "Honorific address to the woman as she dances; it does not establish a confirmed royal genealogy (7:1)."},
        ],
        8: [
            {"name": "The woman", "role": "Expresses affection, declares love's power, and asserts control of her own vineyard, supplying the book's culminating claims about love (8:1–2,6–7,12)."},
            {"name": "The beloved man", "role": "Addressee of her longing and of the closing invitation, embodying the reciprocal relationship at the poem's center (8:13–14)."},
            {"name": "Daughters of Jerusalem", "role": "Hear the recurring warning about awakening love, returning as the poem's listening audience (8:4)."},
            {"name": "The younger sister", "role": "Appears in a family discussion about her future, introducing concerns about protection and maturity (8:8–9)."},
            {"name": "The unnamed brothers or family speakers", "role": "Ask what to do for the younger sister, reflecting household oversight; the precise voice assignment is uncertain (8:8–9)."},
            {"name": "Solomon", "role": "Named in connection with a vineyard leased to keepers, providing a contrast between commercial value and the woman's personal claim about love (8:11–12)."},
        ],
    }

    themes = {
        1: [
            ("Love expressed openly", "The woman speaks first and without hesitation, asking directly for her beloved's kisses and praising his love as better than wine, setting the book's pattern of open, mutual desire."),
            ("Dignity amid social scrutiny", "She explains that her sun-darkened skin came from vineyard work her brothers assigned her, defending her worth rather than accepting the daughters' possible judgment of her appearance."),
            ("Seeking closeness", "Her question about where her beloved pastures his flock shows a desire for his actual presence, not just distant admiration, and the answer she receives keeps that pursuit active."),
            ("Poetic celebration of beauty", "The beloved's comparison of her to a prized mare among Pharaoh's chariots, and her answering praise of him, show both voices using lavish, affectionate imagery to honor each other."),
        ],
        2: [
            ("Mutual belonging", "The declaration \"my beloved is mine, and I am his\" states the relationship as a settled, reciprocal claim rather than one-sided longing."),
            ("Love and timing", "The charge not to stir up or awaken love until it pleases warns against forcing intimacy before its proper season."),
            ("Love and renewal", "The beloved's invitation into springtime, with rain past and flowers blooming, ties the couple's affection to the natural world's own renewal."),
            ("Protecting what is growing", "The call to catch the little foxes that spoil the vines pictures small threats that can damage a tender, still-developing love if left unchecked."),
        ],
        3: [
            ("Longing and reunion", "The woman's restless night search through the city streets, followed by her relief at finding her beloved, shows how acutely his absence is felt and how fully his presence satisfies."),
            ("Love and its timing", "The repeated charge not to awaken love before its time returns here, reinforcing that genuine love cannot be rushed into being."),
            ("Private love and public celebration", "The sudden shift from a quiet, personal search to Solomon's grand, guarded wedding procession places intimate affection and public royal celebration side by side."),
            ("Security and vulnerability", "The city watchmen who meet the woman alone at night and the sixty armed men who guard Solomon's litter both show how much protection ordinary movement and royal travel required."),
        ],
        4: [
            ("Affirming the beloved", "The man's head-to-toe praise, comparing her to doves, goats, and towers, affirms her beauty as complete and without flaw."),
            ("Poetic language of desire", "Calling her captivating with a single glance and praising her words and fragrance shows desire expressed through elevated, sensory comparison rather than plain description."),
            ("The protected garden", "Picturing her as an enclosed garden and sealed spring presents her purity and devotion as something kept exclusively for him."),
            ("Invitation and reciprocity", "Her answering invitation for the winds to spread the garden's fragrance and for him to enter turns his praise into a mutual, welcomed exchange."),
        ],
        5: [
            ("Missed encounter and longing", "Her hesitation to rise when he knocks, followed by his withdrawal before she can open the door, turns a moment of nearness into renewed absence and regret."),
            ("Violence and vulnerability", "The watchmen's decision to strike her and remove her veil shows real harm coming to a woman who was simply searching for the one she loves."),
            ("Affection beyond absence", "Even without finding him, she answers the daughters' question with an elaborate, loving description, showing her devotion holds steady despite his absence."),
            ("Beloved and friend", "Calling him \"altogether lovely\" and \"my friend\" joins romantic desire with the closeness of true friendship."),
        ],
        6: [
            ("Mutual commitment", "Repeating \"I am my beloved's, and my beloved is mine\" reaffirms the settled, reciprocal bond already declared in chapter 2."),
            ("Uniqueness of the beloved", "Comparing her favorably to queens, concubines, and maidens declares that none of them, however many, equal her in the man's eyes."),
            ("Praise through comparison", "Describing her as beautiful as Tirzah and awe-inspiring as an army with banners uses grand, almost overwhelming imagery to express the effect of her beauty."),
            ("Public attention and personal identity", "The closing call for the Shulammite to return, met by a question about why everyone wants to look at her, raises the tension between being admired by a crowd and being known personally by one beloved."),
        ],
        7: [
            ("Embodied admiration", "The man's detailed praise, moving from her feet to her head, treats her physical body itself as worthy of sustained, specific admiration."),
            ("Mutual desire", "Her answer, \"I am my beloved's, and his desire is toward me,\" shows that the attraction runs both ways rather than being directed at her alone."),
            ("Love in ordinary landscapes", "Her invitation to walk out among the vineyards and villages shows their love expressed through shared, everyday activity rather than only through grand occasions."),
            ("Sensory abundance", "Blossoming vines, fragrant mandrakes, and stored fruits pile up sensory images that picture love as rich, plentiful, and ready to be enjoyed."),
        ],
        8: [
            ("Love's strength", "Calling love \"strong as death\" with a flame no flood can quench presents love's power as equal to the most unstoppable forces people know."),
            ("Love cannot be bought", "Declaring that all a man's wealth could never purchase love insists that genuine devotion has a worth no price can match or substitute for."),
            ("Maturity and family concern", "The family's question about how to protect a sister too young for marriage shows real concern for timing and readiness before love and marriage begin."),
            ("Personal agency and belonging", "Contrasting Solomon's rented-out vineyard with her own vineyard, which she controls herself, lets the woman claim ownership of her own love rather than treating it as someone else's property."),
            ("Desire continues", "The closing call for her voice and her invitation for him to hurry like a young deer end the book still in active longing rather than settled, finished contentment."),
        ],
    }

    audience_overrides = {
        3: "Readers familiar with royal wedding customs would recognize the sixty-guard escort and costly litter as marks of real royal status, framing the woman's earlier search at night as the private counterpart to this public spectacle.",
    }

    for chapter in range(1, 9):
        key = f"Song of Solomon {chapter}"
        if chapter in summaries_overrides:
            insights[key]["summary"] = summaries_overrides[chapter]
        insights[key]["whereWeAre"] = placement[chapter]
        insights[key]["keyFigures"] = key_figures[chapter]
        insights[key]["keyThemes"] = [
            {"theme": name, "explanation": explanation, "references": old["references"]}
            for (name, explanation), old in zip(themes[chapter], insights[key]["keyThemes"])
        ]
        if chapter in audience_overrides:
            context[key]["audience"] = audience_overrides[chapter]

    # Overview: lead with traditional authorship, exact KJV wording in double quotes, and a key
    # verse that captures the book's own climactic statement about love.
    book = overview["Song of Solomon"]
    book["author"] = ("Solomon is the traditional author, as \"the song of songs, which is Solomon's\" "
                       "(Song of Solomon 1:1) states; the collection of poems may gather multiple voices "
                       "performed under his name.")
    book["keyVerse"] = "Song of Solomon 8:6"

    save(insights_path, insights)
    save(context_path, context)
    save(overview_path, overview)


if __name__ == "__main__":
    main()
