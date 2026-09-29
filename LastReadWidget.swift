// LastReadWidget.swift
import SwiftUI
import WidgetKit

struct LastReadWidgetEntryView: View {
    @Environment(\.widgetFamily) private var widgetFamily

    var entry: LastReadProvider.Entry

    private var isExtraLarge: Bool { widgetFamily == .systemExtraLarge }
    private var isLarge: Bool { widgetFamily == .systemLarge }

    var body: some View {
        VStack(alignment: .leading, spacing: isExtraLarge ? 18 : (isLarge ? 12 : 6)) {
            // Self-identifying header so users know which widget this is
            HStack(spacing: 6) {
                Image(systemName: "bookmark.fill")
                    .font(isExtraLarge ? .title2 : (isLarge ? .headline : .caption2))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.blue)
                Text("Last Read")
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
                if !entry.book.isEmpty && entry.chapter > 0 && entry.verse > 0 {
                    Text("\(entry.book) \(entry.chapter):\(entry.verse)")
                        .font(isExtraLarge ? .title3 : (isLarge ? .subheadline : .caption2))
                        .foregroundStyle(.white.opacity(0.7))
                }
            } else {
                Text("No verse yet")
                    .font(isExtraLarge ? .largeTitle : (isLarge ? .title2 : .footnote))
                    .foregroundStyle(.white)
            }
        }
        .padding(isExtraLarge ? 28 : (isLarge ? 22 : 16))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(deepLinkURL(book: entry.book, chapter: entry.chapter, verse: entry.verse))
        .applyWidgetBackground()
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
    func applyWidgetBackground() -> some View {
        if #available(iOS 17.0, *) {
            return AnyView(
                self
                    .containerBackground(Color.black, for: .widget)
                    .contentMargins(.all, 0)
            )
        } else {
            return AnyView(
                self
                    .background(Color.black)
            )
        }
    }
}
