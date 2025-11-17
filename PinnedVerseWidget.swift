import SwiftUI
import WidgetKit

struct PinnedVerseWidgetEntryView: View {
    var entry: PinnedVerseEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Optional header to self-identify
            HStack(spacing: 6) {
                Image(systemName: "bookmark.fill")
                    .font(.caption2)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        Color.red.opacity(0.9),     // bookmark body
                        Color.white.opacity(0.9)    // cutout/inner
                    )

                Text("Pinned Verse")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }

            if !entry.text.isEmpty {
                Text("“\(entry.text)”")
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .lineLimit(5)
                    .multilineTextAlignment(.leading)

                Text("\(entry.book) \(entry.chapter):\(entry.verse)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                Text("Set a pinned verse in the app’s Settings.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding()
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
        .description("Always show a verse you choose in Settings.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
