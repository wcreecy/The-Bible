import SwiftUI
import WidgetKit

struct PinnedVerseWidgetEntryView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    @Environment(\.widgetRenderingMode) private var renderingMode

    var entry: PinnedVerseEntry

    private var isExtraLarge: Bool { widgetFamily == .systemExtraLarge }
    private var isLarge: Bool { widgetFamily == .systemLarge }
    private var isMedium: Bool { widgetFamily == .systemMedium }
    private var backgroundStyle: WidgetBackgroundStyle {
        WidgetBackgroundStyle(rawValue: entry.backgroundStyleRaw) ?? .black
    }

    private var primaryTextColor: Color {
        backgroundStyle.primaryTextColor(in: renderingMode)
    }

    private var secondaryTextColor: Color {
        primaryTextColor.opacity(0.7)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isExtraLarge ? 18 : (isLarge ? 12 : 6)) {
            // Optional header to self-identify
            HStack(spacing: 6) {
                Image(systemName: "pin.fill")
                    .font(isExtraLarge ? .title2 : (isLarge ? .headline : (isMedium ? .subheadline : .caption2)))
                    .foregroundStyle(.red)
                    .widgetAccentable()

                Text("Pinned Verse")
                    .font(isExtraLarge ? .title2.weight(.semibold) : (isLarge ? .headline.weight(.semibold) : (isMedium ? .subheadline.weight(.semibold) : .caption2.weight(.semibold))))
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(1)
            }

            if !entry.text.isEmpty {
                Text("“\(entry.text)”")
                    .font(isExtraLarge ? .largeTitle : (isLarge ? .title2 : (isMedium ? .body : .footnote)))
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(isExtraLarge || isLarge ? 6 : 5)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)

                Text("\(entry.book) \(entry.chapter):\(entry.verse) · \(WidgetTranslationTag.pinned)")
                    .font(isExtraLarge ? .title3 : (isLarge ? .subheadline : (isMedium ? .caption : .caption2)))
                    .foregroundStyle(secondaryTextColor)
            } else {
                Text("Long‑press a verse in the app to pin it here.")
                    .font(isExtraLarge ? .largeTitle : (isLarge ? .title2 : (isMedium ? .body : .footnote)))
                    .foregroundStyle(secondaryTextColor)
            }
        }
        .padding(isExtraLarge ? 28 : (isLarge ? 22 : 16))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(deepLinkURL(book: entry.book, chapter: entry.chapter, verse: entry.verse))
        .containerBackground(for: .widget) {
            WidgetBackgroundView(style: backgroundStyle)
        }
        // The heading names the widget, so VoiceOver reads it followed by the verse and reference.
        .accessibilityElement(children: .combine)
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
        AppIntentConfiguration(
            kind: kind,
            intent: PinnedVerseWidgetAppearanceIntent.self,
            provider: PinnedVerseProvider()
        ) { (entry: PinnedVerseEntry) in
            PinnedVerseWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Pinned Verse")
        .description("Long‑press a verse in the app to pin it to this widget.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}
