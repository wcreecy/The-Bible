import AppIntents
import Foundation
import WidgetKit


enum LastReadWidgetBackgroundOption: String, AppEnum {
    case useSettings
    case black
    case midnight
    case forest
    case burgundy
    case indigo
    case sunset
    case blackToGray
    case blueToPurple
    case parchment

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Widget Background"
    }

    static var caseDisplayRepresentations: [LastReadWidgetBackgroundOption: DisplayRepresentation] {
        [
            .useSettings: "Match App Setting",
            .black: "Black",
            .midnight: "Midnight",
            .forest: "Forest",
            .burgundy: "Burgundy",
            .indigo: "Indigo",
            .sunset: "Sunset",
            .blackToGray: "Graphite",
            .blueToPurple: "Aurora",
            .parchment: "Parchment"
        ]
    }

    var resolvedRawValue: String {
        guard self == .useSettings else { return rawValue }
        return UserDefaults(suiteName: "group.bible.app")?
            .string(forKey: "lastReadWidgetBackground") ?? "black"
    }
}

struct LastReadWidgetAppearanceIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Widget Appearance"
    static var description = IntentDescription(
        "Choose a background for this widget, or use the choice from the app’s Settings."
    )

    @Parameter(title: "Background", default: .useSettings)
    var background: LastReadWidgetBackgroundOption
}

struct LastReadEntry: TimelineEntry {
    let date: Date
    let text: String
    let book: String
    let chapter: Int
    let verse: Int
    let backgroundStyleRaw: String
}

struct LastReadProvider: AppIntentTimelineProvider {
    typealias Entry = LastReadEntry
    typealias Intent = LastReadWidgetAppearanceIntent

    func placeholder(in context: Context) -> Entry {
        Entry(
            date: Date(),
            text: "The LORD is my shepherd; I shall not want.",
            book: "Psalms",
            chapter: 23,
            verse: 1,
            backgroundStyleRaw: LastReadWidgetBackgroundOption.black.rawValue
        )
    }

    func snapshot(for configuration: Intent, in context: Context) async -> Entry {
        loadEntry(configuration: configuration)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        let entry = loadEntry(configuration: configuration)
        let refresh = Calendar.current.date(byAdding: .hour, value: 6, to: Date())
            ?? Date().addingTimeInterval(21_600)
        return Timeline(entries: [entry], policy: .after(refresh))
    }

    private func loadEntry(configuration: Intent) -> Entry {
        let backgroundStyleRaw = configuration.background.resolvedRawValue
        // The app mirrors its synced reading position into the app group.
        let shared = UserDefaults(suiteName: "group.bible.app")
        return Entry(
            date: Date(),
            text: shared?.string(forKey: "lastReadText") ?? "",
            book: shared?.string(forKey: "lastReadBook") ?? "",
            chapter: shared?.integer(forKey: "lastReadChapter") ?? 0,
            verse: shared?.integer(forKey: "lastReadVerse") ?? 0,
            backgroundStyleRaw: backgroundStyleRaw
        )
    }
}
