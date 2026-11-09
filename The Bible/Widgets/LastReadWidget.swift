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

    private var primaryTextColor: Color {
        backgroundStyle == .parchment ? Color(red: 0.20, green: 0.15, blue: 0.08) : .white
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
                    .foregroundStyle(Color.blue)
                // The small widget has room for only the shorter title.
                ViewThatFits(in: .horizontal) {
                    Text("Continue Reading")
                    Text("Continue")
                }
                .font(isExtraLarge ? .title2.weight(.semibold) : (isLarge ? .headline.weight(.semibold) : (isMedium ? .subheadline.weight(.semibold) : .caption2.weight(.semibold))))
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
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
        .applyWidgetBackground(style: backgroundStyle)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Continue Reading widget")
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
                    .foregroundStyle(Color.blue)
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
    case blackToGray
    case blueToPurple
    case riverstone
    case oliveGold
    case amethyst
    case parchment
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
