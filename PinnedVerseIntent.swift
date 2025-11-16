import WidgetKit
import AppIntents
import SwiftUI

// 66-book enum for a clean picker in the widget configuration
enum BookNameOption: String, AppEnum, CaseIterable, Identifiable, Codable {
    case Genesis, Exodus, Leviticus, Numbers, Deuteronomy
    case Joshua, Judges, Ruth
    case oneSamuel = "1 Samuel", twoSamuel = "2 Samuel"
    case oneKings = "1 Kings", twoKings = "2 Kings"
    case oneChronicles = "1 Chronicles", twoChronicles = "2 Chronicles"
    case Ezra, Nehemiah, Esther, Job, Psalms, Proverbs, Ecclesiastes
    case songOfSolomon = "Song of Solomon"
    case Isaiah, Jeremiah, Lamentations, Ezekiel, Daniel
    case Hosea, Joel, Amos, Obadiah, Jonah
    case Micah, Nahum, Habakkuk, Zephaniah, Haggai, Zechariah, Malachi
    case Matthew, Mark, Luke, John, Acts
    case Romans, oneCorinthians = "1 Corinthians", twoCorinthians = "2 Corinthians"
    case Galatians, Ephesians, Philippians, Colossians
    case oneThessalonians = "1 Thessalonians", twoThessalonians = "2 Thessalonians"
    case oneTimothy = "1 Timothy", twoTimothy = "2 Timothy"
    case Titus, Philemon, Hebrews, James
    case onePeter = "1 Peter", twoPeter = "2 Peter"
    case oneJohn = "1 John", twoJohn = "2 John", threeJohn = "3 John"
    case Jude, Revelation

    var id: String { rawValue }

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        .init(name: "Book")
    }

    // Must be an exhaustive, literal dictionary for AppEnum
    static var caseDisplayRepresentations: [BookNameOption : DisplayRepresentation] {
        [
            .Genesis: "Genesis",
            .Exodus: "Exodus",
            .Leviticus: "Leviticus",
            .Numbers: "Numbers",
            .Deuteronomy: "Deuteronomy",

            .Joshua: "Joshua",
            .Judges: "Judges",
            .Ruth: "Ruth",

            .oneSamuel: "1 Samuel",
            .twoSamuel: "2 Samuel",

            .oneKings: "1 Kings",
            .twoKings: "2 Kings",

            .oneChronicles: "1 Chronicles",
            .twoChronicles: "2 Chronicles",

            .Ezra: "Ezra",
            .Nehemiah: "Nehemiah",
            .Esther: "Esther",
            .Job: "Job",
            .Psalms: "Psalms",
            .Proverbs: "Proverbs",
            .Ecclesiastes: "Ecclesiastes",

            .songOfSolomon: "Song of Solomon",

            .Isaiah: "Isaiah",
            .Jeremiah: "Jeremiah",
            .Lamentations: "Lamentations",
            .Ezekiel: "Ezekiel",
            .Daniel: "Daniel",

            .Hosea: "Hosea",
            .Joel: "Joel",
            .Amos: "Amos",
            .Obadiah: "Obadiah",
            .Jonah: "Jonah",

            .Micah: "Micah",
            .Nahum: "Nahum",
            .Habakkuk: "Habakkuk",
            .Zephaniah: "Zephaniah",
            .Haggai: "Haggai",
            .Zechariah: "Zechariah",
            .Malachi: "Malachi",

            .Matthew: "Matthew",
            .Mark: "Mark",
            .Luke: "Luke",
            .John: "John",
            .Acts: "Acts",

            .Romans: "Romans",
            .oneCorinthians: "1 Corinthians",
            .twoCorinthians: "2 Corinthians",

            .Galatians: "Galatians",
            .Ephesians: "Ephesians",
            .Philippians: "Philippians",
            .Colossians: "Colossians",

            .oneThessalonians: "1 Thessalonians",
            .twoThessalonians: "2 Thessalonians",

            .oneTimothy: "1 Timothy",
            .twoTimothy: "2 Timothy",

            .Titus: "Titus",
            .Philemon: "Philemon",
            .Hebrews: "Hebrews",
            .James: "James",

            .onePeter: "1 Peter",
            .twoPeter: "2 Peter",

            .oneJohn: "1 John",
            .twoJohn: "2 John",
            .threeJohn: "3 John",

            .Jude: "Jude",
            .Revelation: "Revelation"
        ]
    }
}

// MARK: - WidgetConfigurationIntent

struct PinnedVerseConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Pinned Verse" }
    static var description: IntentDescription { "Select a verse to always display." }

    @Parameter(title: "Book")
    var book: BookNameOption?

    // Simple Int parameters
    @Parameter(title: "Chapter")
    var chapter: Int?

    @Parameter(title: "Verse")
    var verse: Int?

    static var parameterSummary: some ParameterSummary {
        Summary("Show \(\.$book) \(\.$chapter):\(\.$verse)")
    }
}
