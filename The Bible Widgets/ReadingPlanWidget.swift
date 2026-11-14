import SwiftUI
import WidgetKit

/// What the app writes for this widget (`ReadingPlanWidgetMirror.Snapshot` in the app).
struct ReadingPlanWidgetSnapshot: Codable, Equatable {
    let planID: String
    let planTitle: String
    let dayNumber: Int
    let dayCount: Int
    let dayTitle: String
    let readings: [String]
    let completedDays: Int
    let isFinished: Bool
    let bookName: String
    let chapter: Int
    let verse: Int
}

struct ReadingPlanEntry: TimelineEntry {
    let date: Date
    let snapshot: ReadingPlanWidgetSnapshot?
    let backgroundStyleRaw: String
}

struct ReadingPlanProvider: AppIntentTimelineProvider {
    typealias Entry = ReadingPlanEntry
    typealias Intent = LastReadWidgetAppearanceIntent

    func placeholder(in context: Context) -> Entry {
        Entry(date: Date(), snapshot: .sample, backgroundStyleRaw: LastReadWidgetBackgroundOption.black.rawValue)
    }

    func snapshot(for configuration: Intent, in context: Context) async -> Entry {
        let entry = loadEntry(configuration: configuration)
        return context.isPreview && entry.snapshot == nil
            ? Entry(date: entry.date, snapshot: .sample, backgroundStyleRaw: entry.backgroundStyleRaw)
            : entry
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        // The app reloads this widget whenever plan progress changes.
        Timeline(entries: [loadEntry(configuration: configuration)], policy: .never)
    }

    private func loadEntry(configuration: Intent) -> Entry {
        let shared = UserDefaults(suiteName: "group.bible.app")
        let snapshot = shared?.data(forKey: "readingPlanWidget")
            .flatMap { try? JSONDecoder().decode(ReadingPlanWidgetSnapshot.self, from: $0) }
        return Entry(date: Date(), snapshot: snapshot, backgroundStyleRaw: configuration.background.resolvedRawValue)
    }
}

struct ReadingPlanWidgetEntryView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    @Environment(\.widgetRenderingMode) private var renderingMode

    let entry: ReadingPlanEntry

    private var isSmall: Bool { widgetFamily == .systemSmall }
    private var isLarge: Bool { widgetFamily == .systemLarge || widgetFamily == .systemExtraLarge }
    private var backgroundStyle: WidgetBackgroundStyle {
        WidgetBackgroundStyle(rawValue: entry.backgroundStyleRaw) ?? .black
    }
    private var primaryTextColor: Color { backgroundStyle.primaryTextColor(in: renderingMode) }
    private var secondaryTextColor: Color { primaryTextColor.opacity(0.7) }

    var body: some View {
        VStack(alignment: .leading, spacing: isLarge ? 12 : 6) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.checkmark")
                    .foregroundStyle(Color.blue)
                    .widgetAccentable()
                Text(isSmall ? "Plan" : "Reading Plan")
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(1)
            }
            .font((isLarge ? Font.headline : .caption).weight(.semibold))

            if let snapshot = entry.snapshot {
                if snapshot.isFinished {
                    finishedContent(snapshot)
                } else {
                    dayContent(snapshot)
                }
            } else {
                Text("Start a reading plan in the app.")
                    .font(isLarge ? .title3 : .footnote)
                    .foregroundStyle(primaryTextColor)
            }
        }
        .padding(isLarge ? 22 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(url)
        .containerBackground(for: .widget) {
            WidgetBackgroundView(style: backgroundStyle)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func dayContent(_ snapshot: ReadingPlanWidgetSnapshot) -> some View {
        Text("Day \(snapshot.dayNumber) of \(snapshot.dayCount)")
            .font((isLarge ? Font.subheadline : .caption2).weight(.semibold))
            .foregroundStyle(Color.blue)
            .widgetAccentable()

        Text(snapshot.dayTitle)
            .font(isLarge ? .title2.weight(.bold) : (isSmall ? .subheadline.weight(.bold) : .headline))
            .foregroundStyle(primaryTextColor)
            .lineLimit(isSmall ? 3 : 2)
            .minimumScaleFactor(0.8)

        if !isSmall {
            let summary = snapshot.readings.joined(separator: " · ")
            if summary != snapshot.dayTitle {
                Text(summary)
                    .font(isLarge ? .body : .caption)
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(isLarge ? 4 : 1)
            }
        }

        Spacer(minLength: 0)

        VStack(alignment: .leading, spacing: 4) {
            if !isSmall {
                Text(snapshot.planTitle)
                    .font(.caption)
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(1)
            }
            ProgressView(value: Double(snapshot.completedDays), total: Double(max(1, snapshot.dayCount)))
                .tint(.blue)
                .widgetAccentable()
        }
    }

    @ViewBuilder
    private func finishedContent(_ snapshot: ReadingPlanWidgetSnapshot) -> some View {
        Image(systemName: "checkmark.seal.fill")
            .font(isLarge ? .largeTitle : .title2)
            .foregroundStyle(.green)
            .widgetAccentable()
        Text("You finished \(snapshot.planTitle)!")
            .font(isLarge ? .title3.weight(.bold) : .subheadline.weight(.bold))
            .foregroundStyle(primaryTextColor)
            .lineLimit(3)
        Spacer(minLength: 0)
        Text("Choose your next plan")
            .font(.caption)
            .foregroundStyle(secondaryTextColor)
    }

    /// Opens the next reading, or the plans list when there isn't one.
    private var url: URL? {
        var components = URLComponents()
        components.scheme = "thebible"
        components.host = "plan"
        if let snapshot = entry.snapshot {
            components.queryItems = [URLQueryItem(name: "id", value: snapshot.planID)]
                + (snapshot.isFinished ? [] : [URLQueryItem(name: "read", value: "1")])
        }
        return components.url
    }
}

struct ReadingPlanWidget: Widget {
    let kind = "ReadingPlanWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: LastReadWidgetAppearanceIntent.self,
            provider: ReadingPlanProvider()
        ) { entry in
            ReadingPlanWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Reading Plan")
        .description("Shows today's reading in your plan.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private extension ReadingPlanWidgetSnapshot {
    static let sample = ReadingPlanWidgetSnapshot(
        planID: "gospel-of-john",
        planTitle: "The Gospel of John",
        dayNumber: 6,
        dayCount: 21,
        dayTitle: "The Bread of Life",
        readings: ["John 6"],
        completedDays: 5,
        isFinished: false,
        bookName: "John",
        chapter: 6,
        verse: 1
    )
}

#Preview(as: .systemMedium) {
    ReadingPlanWidget()
} timeline: {
    ReadingPlanEntry(date: .now, snapshot: .sample, backgroundStyleRaw: "black")
}
