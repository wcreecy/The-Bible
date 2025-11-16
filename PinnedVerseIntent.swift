import WidgetKit
import AppIntents
import SwiftUI

// 66-book enum for a clean picker in the widget configuration
enum BookNameOption: String, AppEnum, CaseIterable, Identifiable, Codable {
    case Genesis, Exodus, Leviticus, Numbers, Deuteronomy
    case Joshua, Judges, Ruth
    case "1 Samuel" = "1 Samuel", "2 Samuel" = "2 Samuel"
    case "1 Kings" = "1 Kings", "2 Kings" = "2 Kings"
    case "1 Chronicles" = "1 Chronicles", "2 Chronicles" = "2 Chronicles"
    case Ezra, Nehemiah, Esther, Job, Psalms, Proverbs, Ecclesiastes, "Song of Solomon" = "Song of Solomon"
    case Isaiah, Jeremiah, Lamentations, Ezekiel, Daniel
    case Hosea, Joel, Amos, Obadiah, Jonah
    case Micah, Nahum, Habakkuk, Zephaniah, Haggai, Zechariah, Malachi
    case Matthew, Mark, Luke, John, Acts
    case Romans, "1 Corinthians" = "1 Corinthians", "2 Corinthians" = "2 Corinthians"
    case Galatians, Ephesians, Philippians, Colossians
    case "1 Thessalonians" = "1 Thessalonians", "2 Thessalonians" = "2 Thessalonians"
    case "1 Timothy" = "1 Timothy", "2 Timothy" = "2 Timothy"
    case Titus, Philemon, Hebrews, James
    case "1 Peter" = "1 Peter", "2 Peter" = "2 Peter"
    case "1 John" = "1 John", "2 John" = "2 John", "3 John" = "3 John"
    case Jude, Revelation

    var id: String { rawValue }

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        .init(name: "Book")
    }

    static var caseDisplayRepresentations: [BookNameOption : DisplayRepresentation] {
        Dictionary(uniqueKeysWithValues: BookNameOption.allCases.map { ($0, DisplayRepresentation(title: .init(stringLiteral: $0.rawValue))) })
    }
}

struct PinnedVerseConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Pinned Verse" }
    static var description: IntentDescription { "Select a verse to always display." }

    @Parameter(title: "Book")
    var book: BookNameOption

    @Parameter(title: "Chapter", default: 3)
    var chapter: Int

    @Parameter(title: "Verse", default: 16)
    var verse: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Show \(\.$book) \(\.$chapter):\(\.$verse)")
    }
}
