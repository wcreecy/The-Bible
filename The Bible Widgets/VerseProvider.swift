import AppIntents
import Foundation
import SwiftUI
import WidgetKit


enum VerseWidgetBackgroundOption: String, AppEnum {
    case useSettings
    case black
    case midnight
    case forest
    case burgundy
    case indigo
    case sunset
    case blackToGray
    case blueToPurple

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Widget Background"
    }

    static var caseDisplayRepresentations: [VerseWidgetBackgroundOption: DisplayRepresentation] {
        [
            .useSettings: "Match App Setting",
            .black: "Black",
            .midnight: "Midnight",
            .forest: "Forest",
            .burgundy: "Burgundy",
            .indigo: "Indigo",
            .sunset: "Sunset",
            .blackToGray: "Graphite",
            .blueToPurple: "Aurora"
        ]
    }

    var resolvedRawValue: String {
        guard self == .useSettings else { return rawValue }
        return UserDefaults(suiteName: "group.bible.app")?
            .string(forKey: "verseWidgetBackground") ?? "black"
    }
}

struct VerseWidgetAppearanceIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Widget Appearance"
    static var description = IntentDescription(
        "Choose a background for this widget, or use the choice from the app’s Settings."
    )

    @Parameter(title: "Background", default: .useSettings)
    var background: VerseWidgetBackgroundOption
}

struct VerseWidgetEntry: TimelineEntry {
    let date: Date
    let text: String
    let book: String
    let chapter: Int
    let verse: Int
    let fontColor: Color
    let backgroundStyleRaw: String
}

struct VerseProvider: AppIntentTimelineProvider {
    typealias Entry = VerseWidgetEntry
    typealias Intent = VerseWidgetAppearanceIntent

    func placeholder(in context: Context) -> Entry {
        Entry(
            date: Date(),
            text: "For God so loved the world...",
            book: "John",
            chapter: 3,
            verse: 16,
            fontColor: .primary,
            backgroundStyleRaw: VerseWidgetBackgroundOption.black.rawValue
        )
    }

    func snapshot(for configuration: Intent, in context: Context) async -> Entry {
        loadCurrentEntry(configuration: configuration)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        let entry = loadCurrentEntry(configuration: configuration)
        return Timeline(entries: [entry], policy: .after(nextAutoRefreshDate()))
    }

    private func loadCurrentEntry(configuration: Intent) -> Entry {
        let shared = UserDefaults(suiteName: "group.bible.app")
        let book = shared?.string(forKey: "verseOfDayBook") ?? "John"
        let chapter = shared?.integer(forKey: "verseOfDayChapter") ?? 1
        let verse = shared?.integer(forKey: "verseOfDayNumber") ?? 1
        let text = shared?.string(forKey: "verseOfDayText") ?? "For God so loved the world..."

        return Entry(
            date: Date(),
            text: text,
            book: book,
            chapter: chapter,
            verse: verse,
            fontColor: .primary,
            backgroundStyleRaw: configuration.background.resolvedRawValue
        )
    }

    private func nextAutoRefreshDate(from now: Date = Date()) -> Date {
        let defaults = UserDefaults.standard
        let frequency = defaults.string(forKey: "votdRefreshFrequency") ?? "custom"
        let h1 = defaults.object(forKey: "votdRefresh1Hour") as? Int ?? 6
        let m1 = defaults.object(forKey: "votdRefresh1Minute") as? Int ?? 0
        let h2 = defaults.object(forKey: "votdRefresh2Hour") as? Int ?? 18
        let m2 = defaults.object(forKey: "votdRefresh2Minute") as? Int ?? 0

        func dateForToday(hour: Int, minute: Int, from date: Date) -> Date? {
            let calendar = Calendar.current
            let base = calendar.dateComponents([.year, .month, .day], from: date)
            return calendar.date(
                from: DateComponents(
                    year: base.year,
                    month: base.month,
                    day: base.day,
                    hour: hour,
                    minute: minute,
                    second: 0
                )
            )
        }

        let calendar = Calendar.current
        if frequency == "hourly" {
            let startOfHour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
            return calendar.date(byAdding: .hour, value: 1, to: startOfHour)
                ?? now.addingTimeInterval(3_600)
        }

        guard let firstRefresh = dateForToday(hour: h1, minute: m1, from: now) else {
            return now.addingTimeInterval(3_600)
        }
        if now < firstRefresh {
            return firstRefresh
        }

        if frequency == "custom",
           let secondRefresh = dateForToday(hour: h2, minute: m2, from: now),
           now < secondRefresh {
            return secondRefresh
        }

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        return dateForToday(hour: h1, minute: m1, from: tomorrow)
            ?? now.addingTimeInterval(86_400)
    }
}
