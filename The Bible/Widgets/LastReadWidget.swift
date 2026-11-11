// LastReadWidget.swift
import SwiftUI
import WidgetKit

struct LastReadWidgetEntryView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    @Environment(\.widgetRenderingMode) private var renderingMode

    var entry: LastReadProvider.Entry

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
            // Self-identifying header so users know which widget this is
            HStack(spacing: 6) {
                Image(systemName: entry.isBookmark ? "bookmark.fill" : "book.fill")
                    .font(isExtraLarge ? .title2 : (isLarge ? .headline : (isMedium ? .subheadline : .caption2)))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(entry.isBookmark ? Color.bookmarkTint : Color.blue)
                    .widgetAccentable()
                // The small widget has room for only the shorter title.
                ViewThatFits(in: .horizontal) {
                    Text("Continue Reading")
                    Text("Continue")
                }
                .font(isExtraLarge ? .title2.weight(.semibold) : (isLarge ? .headline.weight(.semibold) : (isMedium ? .subheadline.weight(.semibold) : .caption2.weight(.semibold))))
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
                .accessibilityLabel("Continue Reading")
            }

            if entry.book.isEmpty || entry.chapter <= 0 {
                Text("Start reading to see your place here.")
                    .font(isExtraLarge ? .largeTitle : (isLarge ? .title2 : (isMedium ? .body : .footnote)))
                    .foregroundStyle(primaryTextColor)
            } else if entry.isBookmark {
                bookmarkContent
            } else {
                readingContent
            }
        }
        .padding(isExtraLarge ? 28 : (isLarge ? 22 : 16))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(deepLinkURL(book: entry.book, chapter: entry.chapter, verse: entry.verse))
        .containerBackground(for: .widget) {
            WidgetBackgroundView(style: backgroundStyle)
        }
        // The heading names the widget, so VoiceOver reads it followed by the passage.
        .accessibilityElement(children: .combine)
    }

    /// The bookmark leads: its exact verse, as the Bookmark widget used to show it.
    @ViewBuilder
    private var bookmarkContent: some View {
        if !entry.text.isEmpty {
            Text("“\(entry.text)”")
                .font(isExtraLarge ? .largeTitle : (isLarge ? .title2 : (isMedium ? .body : .footnote)))
                .foregroundStyle(primaryTextColor)
                .lineLimit(isExtraLarge || isLarge ? 6 : 5)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
        }
        // The small widget keeps the reference on one line by leaving out the translation.
        Text(widgetFamily == .systemSmall
             ? "\(entry.book) \(entry.chapter):\(entry.verse)"
             : "\(entry.book) \(entry.chapter):\(entry.verse) · \(WidgetTranslationTag.tag(for: entry.translation))")
            .font(isExtraLarge ? .title3 : (isLarge ? .subheadline : (isMedium ? .caption : .caption2)))
            .foregroundStyle(secondaryTextColor)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    /// The reader has moved on from the bookmark: the chapter leads, since its verse is only
    /// approximate. Medium and larger add the bookmark row, as the Home card does.
    @ViewBuilder
    private var readingContent: some View {
        // Only the chapter is named; tapping still opens near where reading stopped.
        Text("\(entry.book) \(entry.chapter)")
            .font(isExtraLarge ? .largeTitle.weight(.bold) : (isLarge ? .title.weight(.bold) : (isMedium ? .title3.weight(.bold) : .headline)))
            .foregroundStyle(primaryTextColor)
            .lineLimit(1)
            .minimumScaleFactor(0.7)

        if !entry.text.isEmpty {
            Text("“\(entry.text)”")
                .font(isExtraLarge ? .title2 : (isLarge ? .title3 : (isMedium ? .subheadline : .footnote)))
                .foregroundStyle(primaryTextColor.opacity(0.9))
                .lineLimit(isExtraLarge || isLarge ? 4 : (isMedium ? 2 : 3))
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
        }

        if widgetFamily != .systemSmall, let reference = entry.bookmarkReference {
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(Color.bookmarkTint)
                    .widgetAccentable()
                Text(reference)
                    .fontWeight(.semibold)
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(1)
                    .layoutPriority(1)
                if let text = entry.bookmarkText, !text.isEmpty {
                    Text("“\(text)”")
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .font(isExtraLarge ? .title3 : (isLarge ? .subheadline : .caption))
        }
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
