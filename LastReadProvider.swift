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
    case riverstone
    case oliveGold
    case amethyst
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
            .riverstone: "Riverstone",
            .oliveGold: "Olive & Gold",
            .amethyst: "Amethyst",
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
    /// Tells Smart Rotate when this widget belongs at the top of a stack.
    var relevance: TimelineEntryRelevance? = nil
}

/// When reading starts each day, shared through the app group so the Last Read widget
/// can rise to the top of a Smart Stack around the reader's usual time.
enum ReadingTimeHistory {
    private static let key = "readingStartMinutes"
    private static let daysKept = 14
    /// Fewer days than this isn't enough to call it a habit.
    private static let minimumDays = 3

    private static var shared: UserDefaults? { UserDefaults(suiteName: "group.bible.app") }

    /// Records the first reading of `date`'s day as minutes after midnight.
    static func recordReading(at date: Date, calendar: Calendar = .current) {
        guard let shared else { return }
        var history = shared.dictionary(forKey: key) as? [String: Int] ?? [:]
        let day = dayKey(for: date, calendar: calendar)
        guard history[day] == nil else { return }

        let parts = calendar.dateComponents([.hour, .minute], from: date)
        history[day] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        // Keys sort by date, so this keeps the most recent days.
        let recent = Set(history.keys.sorted().suffix(daysKept))
        shared.set(history.filter { recent.contains($0.key) }, forKey: key)
    }

    /// Whether reading has already started on `date`'s day on this device.
    static func hasRead(on date: Date, calendar: Calendar = .current) -> Bool {
        let history = shared?.dictionary(forKey: key) as? [String: Int] ?? [:]
        return history[dayKey(for: date, calendar: calendar)] != nil
    }

    /// The usual start time as minutes after midnight (the median of recent days),
    /// or nil until there are enough days to tell.
    static func usualStartMinutes() -> Int? {
        let history = shared?.dictionary(forKey: key) as? [String: Int] ?? [:]
        guard history.count >= minimumDays else { return nil }
        let sorted = history.values.sorted()
        return sorted[sorted.count / 2]
    }

    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
    }
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
        let now = Date()
        let refresh = Calendar.current.date(byAdding: .hour, value: 6, to: now)
            ?? now.addingTimeInterval(21_600)
        let entry = loadEntry(configuration: configuration, date: now)
        guard !entry.book.isEmpty else {
            return Timeline(entries: [entry], policy: .after(refresh))
        }

        let resting = TimelineEntryRelevance(score: Self.restingScore)
        guard let window = nextReadingWindow(after: now) else {
            return Timeline(entries: [entry.with(date: now, relevance: resting)], policy: .after(refresh))
        }

        // Same content throughout; only how strongly Smart Rotate favors it changes.
        var entries: [Entry] = []
        if window.contains(now) {
            let remaining = window.end.timeIntervalSince(now)
            entries.append(entry.with(date: now, relevance: TimelineEntryRelevance(score: Self.readingTimeScore, duration: remaining)))
        } else {
            entries.append(entry.with(date: now, relevance: resting))
            entries.append(entry.with(date: window.start, relevance: TimelineEntryRelevance(score: Self.readingTimeScore, duration: window.duration)))
        }
        entries.append(entry.with(date: window.end, relevance: resting))
        return Timeline(entries: entries, policy: .after(min(refresh, window.end)))
    }

    /// Relevance scores are compared only with this app's other widgets.
    private static let restingScore: Float = 10
    private static let readingTimeScore: Float = 60
    /// The boost starts a little before the usual time and lasts this long.
    private static let leadMinutes = 30
    private static let windowMinutes = 90

    /// The next window around the reader's usual start time, skipping today once
    /// reading has already started.
    private func nextReadingWindow(after now: Date) -> DateInterval? {
        guard let usual = ReadingTimeHistory.usualStartMinutes() else { return nil }
        let calendar = Calendar.current
        for dayOffset in 0...1 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)),
                  let start = calendar.date(byAdding: .minute, value: usual - Self.leadMinutes, to: day) else { continue }
            let window = DateInterval(start: start, duration: TimeInterval(Self.windowMinutes * 60))
            if window.end <= now { continue }
            if ReadingTimeHistory.hasRead(on: day, calendar: calendar) { continue }
            return window
        }
        return nil
    }

    private func loadEntry(configuration: Intent, date: Date = Date()) -> Entry {
        let backgroundStyleRaw = configuration.background.resolvedRawValue
        // The app mirrors its synced reading position into the app group.
        let shared = UserDefaults(suiteName: "group.bible.app")
        return Entry(
            date: date,
            text: shared?.string(forKey: "bookmarkText") ?? "",
            book: shared?.string(forKey: "bookmarkBook") ?? "",
            chapter: shared?.integer(forKey: "bookmarkChapter") ?? 0,
            verse: shared?.integer(forKey: "bookmarkVerse") ?? 0,
            backgroundStyleRaw: backgroundStyleRaw
        )
    }
}

private extension LastReadEntry {
    func with(date: Date, relevance: TimelineEntryRelevance) -> LastReadEntry {
        LastReadEntry(
            date: date,
            text: text,
            book: book,
            chapter: chapter,
            verse: verse,
            backgroundStyleRaw: backgroundStyleRaw,
            relevance: relevance
        )
    }
}
