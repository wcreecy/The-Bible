import SwiftUI
import WidgetKit

struct PinnedVerseWidgetEntryView: View {
    @Environment(\.widgetFamily) private var widgetFamily

    var entry: PinnedVerseEntry

    private var isExtraLarge: Bool { widgetFamily == .systemExtraLarge }
    private var isLarge: Bool { widgetFamily == .systemLarge }
    private var isMedium: Bool { widgetFamily == .systemMedium }
    private var backgroundStyle: PinnedVerseWidgetBackgroundStyle {
        PinnedVerseWidgetBackgroundStyle(rawValue: entry.backgroundStyleRaw) ?? .black
    }

    private var primaryTextColor: Color {
        backgroundStyle == .parchment ? Color(red: 0.20, green: 0.15, blue: 0.08) : .white
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

                Text("\(entry.book) \(entry.chapter):\(entry.verse)")
                    .font(isExtraLarge ? .title3 : (isLarge ? .subheadline : (isMedium ? .caption : .caption2)))
                    .foregroundStyle(secondaryTextColor)
            } else {
                Text("Long‑press a verse in the app to pin it here.")
                    .font(isExtraLarge ? .largeTitle : (isLarge ? .title2 : (isMedium ? .body : .footnote)))
                    .foregroundStyle(secondaryTextColor)
            }
        }
        .padding(isExtraLarge ? 28 : (isLarge ? 22 : 16))
        .widgetURL(deepLinkURL(book: entry.book, chapter: entry.chapter, verse: entry.verse))
        .containerBackground(for: .widget) {
            PinnedVerseWidgetBackground(style: backgroundStyle)
        }
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

private enum PinnedVerseWidgetBackgroundStyle: String {
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
}

private struct PinnedVerseWidgetBackground: View {
    let style: PinnedVerseWidgetBackgroundStyle

    var body: some View {
        switch style {
        case .black:
            Color.black
        case .midnight:
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.08, blue: 0.18), Color(red: 0.08, green: 0.22, blue: 0.38)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .forest:
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.16, blue: 0.12), Color(red: 0.10, green: 0.34, blue: 0.23)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .burgundy:
            LinearGradient(
                colors: [Color(red: 0.22, green: 0.03, blue: 0.08), Color(red: 0.48, green: 0.08, blue: 0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .indigo:
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.07, blue: 0.28), Color(red: 0.28, green: 0.20, blue: 0.58)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sunset:
            LinearGradient(
                colors: [Color(red: 0.33, green: 0.07, blue: 0.18), Color(red: 0.72, green: 0.28, blue: 0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .blackToGray:
            LinearGradient(
                colors: [.black, .gray],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .blueToPurple:
            LinearGradient(
                colors: [.blue, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .riverstone:
            LinearGradient(
                colors: [Color(red: 0.02, green: 0.23, blue: 0.25), Color(red: 0.12, green: 0.31, blue: 0.37)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .oliveGold:
            LinearGradient(
                colors: [Color(red: 0.20, green: 0.27, blue: 0.16), Color(red: 0.54, green: 0.42, blue: 0.17)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .amethyst:
            LinearGradient(
                colors: [Color(red: 0.21, green: 0.07, blue: 0.31), Color(red: 0.44, green: 0.27, blue: 0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .parchment:
            Color(red: 0.91, green: 0.85, blue: 0.70)
        }
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
