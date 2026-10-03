// LastReadWidget.swift
import SwiftUI
import WidgetKit

struct LastReadWidgetEntryView: View {
    @Environment(\.widgetFamily) private var widgetFamily

    var entry: LastReadProvider.Entry

    private var isExtraLarge: Bool { widgetFamily == .systemExtraLarge }
    private var isLarge: Bool { widgetFamily == .systemLarge }
    private var isMedium: Bool { widgetFamily == .systemMedium }
    private var backgroundStyle: LastReadWidgetBackgroundStyle {
        LastReadWidgetBackgroundStyle(rawValue: entry.backgroundStyleRaw) ?? .black
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isExtraLarge ? 18 : (isLarge ? 12 : 6)) {
            // Self-identifying header so users know which widget this is
            HStack(spacing: 6) {
                Image(systemName: "bookmark.fill")
                    .font(isExtraLarge ? .title2 : (isLarge ? .headline : (isMedium ? .subheadline : .caption2)))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.blue)
                Text("Last Read")
                    .font(isExtraLarge ? .title2.weight(.semibold) : (isLarge ? .headline.weight(.semibold) : (isMedium ? .subheadline.weight(.semibold) : .caption2.weight(.semibold))))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }

            if !entry.text.isEmpty {
                Text("“\(entry.text)”")
                    .font(isExtraLarge ? .largeTitle : (isLarge ? .title2 : (isMedium ? .body : .footnote)))
                    .foregroundStyle(.white)
                    .lineLimit(isExtraLarge || isLarge ? 6 : 5)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                if !entry.book.isEmpty && entry.chapter > 0 && entry.verse > 0 {
                    Text("\(entry.book) \(entry.chapter):\(entry.verse)")
                        .font(isExtraLarge ? .title3 : (isLarge ? .subheadline : (isMedium ? .caption : .caption2)))
                        .foregroundStyle(.white.opacity(0.7))
                }
            } else {
                Text("No verse yet")
                    .font(isExtraLarge ? .largeTitle : (isLarge ? .title2 : (isMedium ? .body : .footnote)))
                    .foregroundStyle(.white)
            }
        }
        .padding(isExtraLarge ? 28 : (isLarge ? 22 : 16))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(deepLinkURL(book: entry.book, chapter: entry.chapter, verse: entry.verse))
        .applyWidgetBackground(style: backgroundStyle)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Last Read widget")
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

private extension View {
    // Use the widget-aware background on iOS 17+, and a fallback on iOS 16.
    @ViewBuilder
    func applyWidgetBackground(style: LastReadWidgetBackgroundStyle) -> some View {
        if #available(iOS 17.0, *) {
            self
                .containerBackground(for: .widget) {
                    LastReadWidgetBackground(style: style)
                }
                .contentMargins(.all, 0)
        } else {
            self.background(LastReadWidgetBackground(style: style))
        }
    }
}

private enum LastReadWidgetBackgroundStyle: String {
    case black
    case midnight
    case forest
    case burgundy
    case indigo
    case sunset
}

private struct LastReadWidgetBackground: View {
    let style: LastReadWidgetBackgroundStyle

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
        }
    }
}
