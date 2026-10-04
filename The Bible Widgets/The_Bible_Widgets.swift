import SwiftUI
import WidgetKit

struct VerseWidgetEntryView: View {
    @Environment(\.widgetFamily) private var widgetFamily

    var entry: VerseProvider.Entry

    private var isExtraLarge: Bool { widgetFamily == .systemExtraLarge }
    private var isLarge: Bool { widgetFamily == .systemLarge }
    private var isMedium: Bool { widgetFamily == .systemMedium }

    private var isEvening: Bool {
        let hour = Calendar.current.component(.hour, from: entry.date)
        return hour >= 18 || hour < 5
    }

    private var headerTitle: String { isEvening ? "Word of the Night" : "Verse of the Day" }
    private var headerIcon: String { isEvening ? "moon.stars" : "sun.max.fill" }
    private var backgroundStyle: VerseWidgetBackgroundStyle {
        VerseWidgetBackgroundStyle(rawValue: entry.backgroundStyleRaw) ?? .black
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isExtraLarge ? 18 : (isLarge ? 12 : 6)) {
            // Self-identifying header so users know which widget this is
            HStack(spacing: 6) {
                Image(systemName: headerIcon)
                    .font(isExtraLarge ? .title2 : (isLarge ? .headline : (isMedium ? .subheadline : .caption2)))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        isEvening
                        ? .purple.opacity(0.9) : .yellow, // primary layer
                        .white.opacity(0.9)               // secondary layer (stars/rays where applicable)
                    )

                Text(headerTitle)
                    .font(isExtraLarge ? .title2.weight(.semibold) : (isLarge ? .headline.weight(.semibold) : (isMedium ? .subheadline.weight(.semibold) : .caption2.weight(.semibold))))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }

            if !entry.text.isEmpty {
                Text("“\(entry.text)\"")
                    .font(isExtraLarge ? .largeTitle : (isLarge ? .title2 : (isMedium ? .body : .footnote)))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(isExtraLarge || isLarge ? 6 : 5)
                    .truncationMode(.tail)
                if !entry.book.isEmpty && entry.chapter > 0 && entry.verse > 0 {
                    Text("\(entry.book) \(entry.chapter):\(entry.verse)")
                        .font(isExtraLarge ? .title3 : (isLarge ? .subheadline : (isMedium ? .caption : .caption2)))
                        .foregroundStyle(.white.opacity(0.7))
                }
            } else {
                Text("No verse yet")
                    .font(isExtraLarge ? .largeTitle : (isLarge ? .title2 : (isMedium ? .body : .footnote)))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(isExtraLarge ? 28 : (isLarge ? 22 : 16))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            VerseWidgetBackground(style: backgroundStyle)
        }
        .widgetURL(URL(string: "thebible://home")) // Always open Home when tapping this widget
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isEvening ? "Word of the Night widget" : "Verse of the Day widget")
    }
}


private enum VerseWidgetBackgroundStyle: String {
    case black
    case midnight
    case forest
    case burgundy
    case indigo
    case sunset
    case blackToGray
    case blueToPurple
}

private struct VerseWidgetBackground: View {
    let style: VerseWidgetBackgroundStyle

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
        }
    }
}
