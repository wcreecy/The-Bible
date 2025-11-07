import SwiftUI
import WidgetKit

struct VerseWidgetEntryView: View {
    var entry: VerseProvider.Entry

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if !entry.text.isEmpty {
                VStack(alignment: .leading) {
                    Text("\"\(entry.text)\"")
                        .font(.body)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding([.leading, .trailing, .top])
                    if !entry.book.isEmpty && entry.chapter > 0 && entry.verse > 0 {
                        Text("\(entry.book) \(entry.chapter):\(entry.verse)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding([.leading, .trailing, .bottom])
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                Text("No verse yet")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .containerBackground(Color.black, for: .widget)
    }
}
