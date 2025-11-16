// LastReadWidget.swift
import SwiftUI
import WidgetKit

struct LastReadWidgetEntryView: View {
    var entry: LastReadProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Self-identifying header so users know which widget this is
            HStack(spacing: 6) {
                Image(systemName: "book")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                Text("Last Read")
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
                if !entry.book.isEmpty && entry.chapter > 0 && entry.verse > 0 {
                    Text("\(entry.book) \(entry.chapter):\(entry.verse)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            } else {
                Text("No verse yet")
                    .font(.footnote)
                    .foregroundStyle(.white)
            }
        }
        .padding()
        .widgetURL(deepLinkURL(book: entry.book, chapter: entry.chapter, verse: entry.verse))
        .background(Color.black) // Fallback for older systems
        .applyiOS17WidgetStyling()
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

#if compiler(>=5.9)
// iOS 17-only styling for widgets, compiled only with SDKs that have these APIs
@available(iOS 17.0, *)
private extension View {
    func applyiOS17WidgetStyling() -> some View {
        self
            .containerBackground(for: .widget) {
                Color.black
            }
            .contentMargins(.all, 0)
    }
}
#else
// Fallback for older compilers/SDKs (no-op)
private extension View {
    func applyiOS17WidgetStyling() -> some View {
        self
    }
}
#endif
