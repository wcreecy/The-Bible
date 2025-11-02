import WidgetKit
import SwiftUI

struct BibleVerseWidgetEntry: TimelineEntry {
    let date: Date
    let verseText: String
    let reference: String
}

struct BibleVerseProvider: TimelineProvider {
    func placeholder(in context: Context) -> BibleVerseWidgetEntry {
        BibleVerseWidgetEntry(
            date: Date(),
            verseText: "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life.",
            reference: "John 3:16"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BibleVerseWidgetEntry) -> Void) {
        let entry = randomBibleVerseEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BibleVerseWidgetEntry>) -> Void) {
        let entry = randomBibleVerseEntry()
        // Refresh every hour
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }

    private func randomBibleVerseEntry() -> BibleVerseWidgetEntry {
        // Attempt to get a random verse from BibleData
        if let book = BibleData.books.randomElement(),
           let chapter = book.chapters.randomElement(),
           let verse = chapter.verses.randomElement() {
            let verseText = verse.text
            let reference = "\(book.name) \(chapter.number):\(verse.number)"
            return BibleVerseWidgetEntry(date: Date(), verseText: verseText, reference: reference)
        } else {
            // Fallback sample verse
            return BibleVerseWidgetEntry(
                date: Date(),
                verseText: "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life.",
                reference: "John 3:16"
            )
        }
    }
}

struct BibleVerseWidgetEntryView: View {
    let entry: BibleVerseWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                VStack(alignment: .leading) {
                    Text(entry.verseText)
                        .italic()
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .lineLimit(5)
                        .minimumScaleFactor(0.6)
                    Spacer()
                    Text(entry.reference)
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                        .foregroundColor(.secondary)
                }
                .padding(12)
            case .systemMedium:
                VStack(alignment: .leading) {
                    Text(entry.verseText)
                        .italic()
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .lineLimit(8)
                        .minimumScaleFactor(0.6)
                    Spacer()
                    Text(entry.reference)
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundColor(.secondary)
                }
                .padding(16)
            case .systemLarge:
                VStack(alignment: .leading) {
                    Text(entry.verseText)
                        .italic()
                        .font(.system(size: 18, weight: .regular, design: .serif))
                        .lineLimit(12)
                        .minimumScaleFactor(0.6)
                    Spacer()
                    Text(entry.reference)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundColor(.secondary)
                }
                .padding(20)
            default:
                VStack(alignment: .leading) {
                    Text(entry.verseText)
                        .italic()
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .lineLimit(8)
                        .minimumScaleFactor(0.6)
                    Spacer()
                    Text(entry.reference)
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundColor(.secondary)
                }
                .padding(16)
            }
        }
        .contentMarginsDisabled()
        .ifAvailableiOS17 {
            $0.containerBackground(for: .widget) {
                Color("WidgetBackground")
            }
        }
        .widgetURL(URL(string: "bibleapp://verse"))
    }
}

@main
struct BibleVerseWidget: Widget {
    let kind: String = "BibleVerseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BibleVerseProvider()) { entry in
            BibleVerseWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Daily Bible Verse")
        .description("Shows a random Bible verse that refreshes every hour.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Helpers

extension View {
    @ViewBuilder
    func ifAvailableiOS17<Content: View>(_ transform: (Self) -> Content) -> some View {
#if compiler(>=5.9)
        transform(self)
#else
        self
#endif
    }
}
