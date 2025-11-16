import SwiftUI
import WidgetKit

struct VerseWidgetEntryView: View {
    var entry: VerseProvider.Entry

    private var isEvening: Bool {
        let hour = Calendar.current.component(.hour, from: entry.date)
        return hour >= 18 || hour < 5
    }

    private var headerTitle: String { isEvening ? "Word of the Night" : "Verse of the Day" }
    private var headerIcon: String { isEvening ? "moon.stars" : "sun.max.fill" }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Self-identifying header so users know which widget this is
            HStack(spacing: 6) {
                Image(systemName: headerIcon)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                Text(headerTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }

            if !entry.text.isEmpty {
                Text("“\(entry.text)\"")
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(5)
                if !entry.book.isEmpty && entry.chapter > 0 && entry.verse > 0 {
                    Text("\(entry.book) \(entry.chapter):\(entry.verse)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            } else {
                Text("No verse yet")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(Color.black, for: .widget)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isEvening ? "Word of the Night widget" : "Verse of the Day widget")
    }
}
