import AppIntents
import Foundation
import WidgetKit


enum PinnedVerseWidgetBackgroundOption: String, AppEnum {
    case black
    case midnight
    case forest
    case burgundy
    case indigo
    case sunset
    case blackToGray
    case blueToPurple
    case riverstone
    case oliveGold
    case amethyst
    case parchment

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Widget Background"
    }

    static var caseDisplayRepresentations: [PinnedVerseWidgetBackgroundOption: DisplayRepresentation] {
        [
            .black: "Black",
            .midnight: "Midnight",
            .forest: "Forest",
            .burgundy: "Burgundy",
            .indigo: "Indigo",
            .sunset: "Sunset",
            .blackToGray: "Graphite",
            .blueToPurple: "Aurora",
            .riverstone: "Riverstone",
            .oliveGold: "Olive & Gold",
            .amethyst: "Amethyst",
            .parchment: "Parchment"
        ]
    }

    var resolvedRawValue: String { rawValue }
}

struct PinnedVerseWidgetAppearanceIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Widget Appearance"
    static var description = IntentDescription(
        "Choose a background for this widget."
    )

    @Parameter(title: "Background", default: .black)
    var background: PinnedVerseWidgetBackgroundOption
}

struct PinnedVerseEntry: TimelineEntry {
    let date: Date
    let book: String
    let chapter: Int
    let verse: Int
    let text: String
    let backgroundStyleRaw: String
    /// Tells Smart Rotate when this widget belongs at the top of a stack.
    var relevance: TimelineEntryRelevance? = nil
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
        var entry = loadCurrentEntry(configuration: configuration)
        // A pinned verse doesn't change on its own, so it stays at a low, steady score
        // and lets the time-sensitive widgets take the top of a stack when they matter.
        entry.relevance = TimelineEntryRelevance(score: entry.book.isEmpty ? 0 : 5)
        return Timeline(entries: [entry], policy: .never)
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
        // Pinning always saves the verse text, so the widget never needs the full Bible.
        let text = (shared.string(forKey: "pinnedVerseText") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !book.isEmpty, chapter > 0, verse > 0 else {
            return nil
        }

        return (book, max(1, chapter), max(1, verse), text)
    }
}
