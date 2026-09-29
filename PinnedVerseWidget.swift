import SwiftUI
import WidgetKit

struct PinnedVerseWidgetEntryView: View {
    @Environment(\.widgetFamily) private var widgetFamily

    var entry: PinnedVerseEntry

    private var isExtraLarge: Bool { widgetFamily == .systemExtraLarge }
    private var isLarge: Bool { widgetFamily == .systemLarge }

    var body: some View {
        VStack(alignment: .leading, spacing: isExtraLarge ? 18 : (isLarge ? 12 : 6)) {
            // Optional header to self-identify
            HStack(spacing: 6) {
                Image(systemName: "pin.fill")
                    .font(isExtraLarge ? .title2 : (isLarge ? .headline : .caption2))
                    .foregroundStyle(.red)

                Text("Pinned Verse")
                    .font(isExtraLarge ? .title2.weight(.semibold) : (isLarge ? .headline.weight(.semibold) : .caption2.weight(.semibold)))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }

            if !entry.text.isEmpty {
                Text("“\(entry.text)”")
                    .font(isExtraLarge ? .largeTitle : (isLarge ? .title2 : .footnote))
                    .foregroundStyle(.white)
                    .lineLimit(isExtraLarge || isLarge ? 6 : 5)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)

                Text("\(entry.book) \(entry.chapter):\(entry.verse)")
                    .font(isExtraLarge ? .title3 : (isLarge ? .subheadline : .caption2))
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                Text("Long‑press a verse in the app to pin it here.")
                    .font(isExtraLarge ? .largeTitle : (isLarge ? .title2 : .footnote))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(isExtraLarge ? 28 : (isLarge ? 22 : 16))
        .widgetURL(deepLinkURL(book: entry.book, chapter: entry.chapter, verse: entry.verse))
        .containerBackground(Color.black, for: .widget)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pinned Verse widget")
    }

    private func deepLinkURL(book: String, chapter: Int, verse: Int) -> URL? {
        guard !book.isEmpty, chapter > 0, verse > 0 else { return nil }
        var comps = URLComponents()
        comps.scheme = "thebible"
        comps.host = "open"
        comps.queryItems = [
            URLQueryItem(name: "book", value: book),
            URLQueryItem(name: "chapter", value: "\(chapter)"),
            URLQueryItem(name: "verse", value: "\(verse)")
        ]
        return comps.url
    }
}

struct PinnedVerseWidget: Widget {
    let kind: String = "PinnedVerseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PinnedVerseProvider()) { (entry: PinnedVerseEntry) in
            PinnedVerseWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Pinned Verse")
        .description("Long‑press a verse in the app to pin it to this widget.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}
