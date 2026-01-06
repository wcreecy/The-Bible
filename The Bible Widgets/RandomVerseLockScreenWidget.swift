import SwiftUI
import WidgetKit

struct RandomVerseEntry: TimelineEntry {
    let date: Date
    let book: String
    let chapter: Int
    let verse: Int
    let text: String
}

struct RandomVerseProvider: TimelineProvider {
    typealias Entry = RandomVerseEntry

    func placeholder(in context: Context) -> Entry {
        RandomVerseEntry(date: Date(), book: "John", chapter: 3, verse: 16, text: "For God so loved the world…")
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(randomEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let entry = randomEntry()
        // Refresh hourly by default; adjust if you want daily at midnight instead.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    // MARK: - Helpers

    private func randomEntry() -> RandomVerseEntry {
        let books = BibleData.books
        guard !books.isEmpty else {
            return RandomVerseEntry(date: Date(), book: "", chapter: 0, verse: 0, text: "")
        }
        let book = books.randomElement()!
        guard let chapter = book.chapters.randomElement(),
              let verse = chapter.verses.randomElement() else {
            return RandomVerseEntry(date: Date(), book: "", chapter: 0, verse: 0, text: "")
        }
        return RandomVerseEntry(date: Date(), book: book.name, chapter: chapter.number, verse: verse.number, text: verse.text)
    }
}

struct RandomVerseLockScreenView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RandomVerseEntry

    // Build the content once, then apply background adoption in body.
    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            // Single-line: Book N:M – text
            Text(inlineText)
                .font(.caption2)
                .minimumScaleFactor(0.7)
                .widgetURL(deepLinkURL())
        case .accessoryCircular:
            ZStack {
                // Keep it simple: reference in the circle
                VStack(spacing: 0) {
                    Text(shortBookAbbrev(entry.book))
                        .font(.system(size: 8, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("\(entry.chapter):\(entry.verse)")
                        .font(.system(size: 10, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .widgetURL(deepLinkURL())
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 4) {
                Text("\(entry.book) \(entry.chapter):\(entry.verse)")
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("“\(entry.text)”")
                    .font(.caption2)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
            }
            .widgetURL(deepLinkURL())
        default:
            // Fallback for any future families
            VStack(alignment: .leading, spacing: 4) {
                Text("\(entry.book) \(entry.chapter):\(entry.verse)")
                    .font(.caption2.weight(.semibold))
                Text(entry.text)
                    .font(.caption2)
                    .lineLimit(3)
            }
            .widgetURL(deepLinkURL())
        }
    }

    var body: some View {
        // Adopt the iOS 17+ background API to remove the system overlay on devices.
        if #available(iOSApplicationExtension 17.0, *) {
            if family == .accessoryCircular || family == .accessoryRectangular {
                // Opt into the system’s tinted background for accessory widgets.
                content
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                // Keep inline (and other) appearance unchanged while adopting the API.
                content
                    .containerBackground(for: .widget) { Color.clear }
            }
        } else {
            content
        }
    }

    private var inlineText: String {
        guard !entry.book.isEmpty, entry.chapter > 0, entry.verse > 0 else { return "Bible verse" }
        let ref = "\(entry.book) \(entry.chapter):\(entry.verse)"
        let snippet = entry.text
        return "\(ref) — \(snippet)"
    }

    private func shortBookAbbrev(_ name: String) -> String {
        // Very compact abbreviation for circular
        let parts = name.split(separator: " ")
        if parts.count == 1 {
            return String(parts[0].prefix(3)).uppercased()
        }
        // Preserve leading number for numbered books
        if let first = parts.first, first.allSatisfy({ $0.isNumber }) {
            let rest = parts.dropFirst().first.map { String($0.prefix(3)).uppercased() } ?? ""
            return "\(first) \(rest)"
        }
        return String(parts.first!.prefix(3)).uppercased()
    }

    private func deepLinkURL() -> URL? {
        guard !entry.book.isEmpty, entry.chapter > 0, entry.verse > 0 else { return nil }
        var comps = URLComponents()
        comps.scheme = "thebible"
        comps.host = "open"
        comps.queryItems = [
            URLQueryItem(name: "book", value: entry.book),
            URLQueryItem(name: "chapter", value: "\(entry.chapter)"),
            URLQueryItem(name: "verse", value: "\(entry.verse)")
        ]
        return comps.url
    }
}

struct RandomVerseLockScreenWidget: Widget {
    let kind = "RandomVerseLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RandomVerseProvider()) { entry in
            RandomVerseLockScreenView(entry: entry)
        }
        .configurationDisplayName("Random Verse")
        .description("Shows a random Bible verse on your Lock Screen.")
        .supportedFamilies([
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}
