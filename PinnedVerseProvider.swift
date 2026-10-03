import AppIntents
import Foundation
import WidgetKit


enum PinnedVerseWidgetBackgroundOption: String, AppEnum {
    case useSettings
    case black
    case midnight
    case forest
    case burgundy
    case indigo
    case sunset

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Widget Background"
    }

    static var caseDisplayRepresentations: [PinnedVerseWidgetBackgroundOption: DisplayRepresentation] {
        [
            .useSettings: "Match App Setting",
            .black: "Black",
            .midnight: "Midnight",
            .forest: "Forest",
            .burgundy: "Burgundy",
            .indigo: "Indigo",
            .sunset: "Sunset"
        ]
    }

    var resolvedRawValue: String {
        guard self == .useSettings else { return rawValue }
        return UserDefaults(suiteName: "group.bible.app")?
            .string(forKey: "pinnedVerseWidgetBackground") ?? "black"
    }
}

struct PinnedVerseWidgetAppearanceIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Widget Appearance"
    static var description = IntentDescription(
        "Choose a background for this widget, or use the choice from the app’s Settings."
    )

    @Parameter(title: "Background", default: .useSettings)
    var background: PinnedVerseWidgetBackgroundOption
}

struct PinnedVerseEntry: TimelineEntry {
    let date: Date
    let book: String
    let chapter: Int
    let verse: Int
    let text: String
    let backgroundStyleRaw: String
}

struct PinnedVerseProvider: AppIntentTimelineProvider {
    typealias Entry = PinnedVerseEntry
    typealias Intent = PinnedVerseWidgetAppearanceIntent

    func placeholder(in context: Context) -> Entry {
        Entry(
            date: Date(),
            book: "John",
            chapter: 3,
            verse: 16,
            text: "For God so loved the world…",
            backgroundStyleRaw: PinnedVerseWidgetBackgroundOption.black.rawValue
        )
    }

    func snapshot(for configuration: Intent, in context: Context) async -> Entry {
        loadCurrentEntry(configuration: configuration)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        Timeline(
            entries: [loadCurrentEntry(configuration: configuration)],
            policy: .never
        )
    }

    private func loadCurrentEntry(configuration: Intent) -> Entry {
        let backgroundStyleRaw = configuration.background.resolvedRawValue

        guard let (book, chapter, verse, text) = loadPinnedFromShared() else {
            return Entry(
                date: Date(),
                book: "",
                chapter: 0,
                verse: 0,
                text: "",
                backgroundStyleRaw: backgroundStyleRaw
            )
        }

        return Entry(
            date: Date(),
            book: book,
            chapter: chapter,
            verse: verse,
            text: text,
            backgroundStyleRaw: backgroundStyleRaw
        )
    }

    private func loadPinnedFromShared() -> (String, Int, Int, String)? {
        guard let shared = UserDefaults(suiteName: "group.bible.app") else {
            return nil
        }

        let book = (shared.string(forKey: "pinnedVerseBook") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let chapter = shared.integer(forKey: "pinnedVerseChapter")
        let verse = shared.integer(forKey: "pinnedVerseNumber")
        var text = (shared.string(forKey: "pinnedVerseText") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !book.isEmpty, chapter > 0, verse > 0 else {
            return nil
        }

        if text.isEmpty,
           let bibleBook = BibleData.books.first(where: { $0.name == book }),
           let bibleChapter = bibleBook.chapters.first(where: { $0.number == chapter }),
           let bibleVerse = bibleChapter.verses.first(where: { $0.number == verse }) {
            text = bibleVerse.text
        }

        return (book, max(1, chapter), max(1, verse), text)
    }
}
