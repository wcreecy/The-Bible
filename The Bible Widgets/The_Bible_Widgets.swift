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
        .containerBackground(Color.black, for: .widget)
        .widgetURL(URL(string: "thebible://home")) // Always open Home when tapping this widget
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isEvening ? "Word of the Night widget" : "Verse of the Day widget")
    }
}
