import SwiftUI

/// Chapter-specific context that helps readers interpret a passage in its literary, cultural,
/// and scriptural setting. Every chapter has an imported context in BibleInsights.sqlite;
/// `context(forBookNamed:chapterNumber:)` supplies fuller hand-written context for Romans 9–10,
/// which takes precedence over the imported version.
struct ChapterReadingContext: Equatable, Sendable {
    struct CulturalLens: Identifiable, Equatable, Sendable {
        let title: String
        let reference: String
        let then: String
        let whyItMatters: String

        var id: String { title }
    }

    struct ScriptureConnection: Identifiable, Equatable, Sendable {
        let reference: String
        let explanation: String

        var id: String { reference }
    }

    let narrativePlacement: String
    let firstCenturyMoment: String
    let originalAudience: String
    let culturalLenses: [CulturalLens]
    let scriptureConnections: [ScriptureConnection]

    static func context(forBookNamed bookName: String, chapterNumber: Int) -> Self? {
        guard bookName == "Romans" else { return nil }

        if chapterNumber == 9 {
            return Self(
            narrativePlacement: "Romans 9 begins Paul’s extended discussion of Israel in Romans 9–11. Romans 1–8 has argued that God’s righteousness is revealed through faith for both Jews and Gentiles, ending with the assurance that nothing can separate believers from God’s love (Romans 8:31–39). Paul now faces the question that assurance raises: if many Israelites have not embraced the gospel, has God’s word failed? He answers by tracing God’s promises through Israel’s Scriptures (Romans 9:6–29). The chapter closes with Israel’s stumbling and Gentile faith (Romans 9:30–33), setting up Romans 10 and Romans 11.",
            firstCenturyMoment: "Romans was written in the mid-first century, probably in the late 50s, to believers in Rome under imperial rule. Rome had recently experienced Claudius’s expulsion of Jews, mentioned in Acts 18:2; the scale, exact date, and direct effect on the churches remain debated. By the time Paul wrote, Priscilla and Aquila were again in Rome (Romans 16:3–5). That background makes questions of Jewish and Gentile identity especially understandable, though Paul does not name a single local event as the cause of Romans 9.",
            originalAudience: "Paul addresses the believers in Rome (Romans 1:7), a community that likely included people of both Jewish and Gentile background. He expects readers to follow a dense chain of Scripture from Genesis, Exodus, Hosea, and Isaiah (Romans 9:7–29). Jewish hearers would recognize these as texts about Israel’s ancestors, exodus, covenant history, judgment, and restoration; Gentile hearers were being taught how their faith related to Israel’s God and Scriptures. Romans 9 asks both groups to consider God’s faithfulness without treating Israel’s privileges or Gentile inclusion as grounds for pride.",
            culturalLenses: [
                CulturalLens(
                    title: "Israel’s covenant privileges were public markers of a people",
                    reference: "Romans 9:4–5",
                    then: "Paul names Israel’s adoption, glory, covenants, law, worship, promises, ancestors, and the Messiah’s human descent. These terms gather Israel’s biblical story, not a list of private religious benefits. “The service of God” refers to the worship God gave Israel through the tabernacle and later temple, including priestly service and sacrifices. In the first-century Jewish world, descent from the patriarchs, the Law, and shared worship were major ways a people remembered their covenant identity, even for Jews living outside Judea.",
                    whyItMatters: "Paul begins with honor for Israel before explaining Gentile inclusion and Israel’s stumbling. This keeps Romans 9 from sounding as though Paul is replacing Israel with a new people who have no connection to its Scriptures. The chapter’s hard questions arise precisely because Israel’s history and promises matter. Modern readers can miss that Paul is reasoning within Israel’s story and treats the Messiah as “concerning the flesh” descended from Israel (Romans 9:5)."
                ),
                CulturalLens(
                    title: "Potter and clay were familiar prophetic language",
                    reference: "Romans 9:20–21",
                    then: "A potter shaping clay was an ordinary craft image, but Paul’s wording also echoes Israel’s Scriptures. Isaiah uses the image when people challenge their Maker (Isaiah 29:16; 45:9), and Jeremiah watches a potter reshape a vessel while explaining God’s dealings with a nation (Jeremiah 18:1–10). The image does not describe a single technical rule of ancient pottery; it is a biblical way of contrasting the Creator’s authority with the creature’s limited position.",
                    whyItMatters: "Paul uses the image while answering an imagined objection: “Why doth he yet find fault?” His point is that people are not in a position to put God on trial as if they controlled the purposes revealed in Scripture. Reading the prophetic background also keeps the metaphor connected to God’s dealings with peoples and to calls for repentance, rather than treating the clay image as a complete explanation of every question about fate or responsibility."
                )
            ],
            scriptureConnections: []
        )
        }

        guard chapterNumber == 10 else { return nil }

        return Self(
            narrativePlacement: "Romans 10 sits in Paul’s extended, grief-filled argument about Israel in Romans 9–11. After describing Israel’s pursuit of righteousness without recognizing God’s righteousness, Paul explains the nearness and public proclamation of the gospel. Romans 11 will return to Israel’s continuing place in God’s purposes.",
            firstCenturyMoment: "Paul writes to a mixed Jewish and Gentile community in Rome. The questions in this chapter concern covenant identity, faithfulness to Israel’s Scriptures, and who may call on Israel’s God—not simply private religious effort.",
            originalAudience: "",
            culturalLenses: [
                CulturalLens(
                    title: "Scripture was heard in community",
                    reference: "Romans 10:14–17",
                    then: "In the ancient Mediterranean world, many people encountered sacred texts through public reading, teaching, and proclamation rather than private ownership of a scroll.",
                    whyItMatters: "Paul’s chain—sent, preach, hear, believe—treats the messenger and the gathered hearing of the message as essential to how faith takes root."
                ),
                CulturalLens(
                    title: "“Lord” carries scriptural weight",
                    reference: "Romans 10:9, 13",
                    then: "Greek-speaking Jews commonly encountered Israel’s Scriptures in a translation that used kyrios, “Lord,” where the divine name appears.",
                    whyItMatters: "When Paul moves from “Jesus is Lord” to Joel’s promise that everyone who calls on the Lord will be saved, he is making a strong claim about Jesus within Israel’s scriptural language of worship and salvation."
                )
            ],
            scriptureConnections: [
                ScriptureConnection(
                    reference: "Deuteronomy 30:14 · Romans 10:8",
                    explanation: "Moses describes God’s command as near—“in your mouth and in your heart.” Paul reuses that language to say the proclaimed word of faith is near, not an unreachable achievement."
                ),
                ScriptureConnection(
                    reference: "Joel 2:32 · Romans 10:13",
                    explanation: "Joel’s promise of calling on the Lord comes from a prophecy of rescue. Paul uses it to ground the chapter’s wide invitation: there is no distinction in access to salvation."
                ),
                ScriptureConnection(
                    reference: "Isaiah 52:7 · Romans 10:15",
                    explanation: "Isaiah celebrates a messenger announcing good news of God’s reign and restoration. Paul applies that image to the necessary sending and preaching of the gospel."
                )
            ]
        )
    }
}

/// Old Testament passages the chapter quotes or echoes, with how they are used.
struct ChapterScriptureConnectionsCard: View {
    let connections: [ChapterReadingContext.ScriptureConnection]

    var body: some View {
        HeroCard(title: "Scripture Connections", icon: "arrow.triangle.branch") {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(connections) { connection in
                    VStack(alignment: .leading, spacing: 6) {
                        LinkedScriptureText(connection.reference)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        LinkedScriptureText(connection.explanation)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
