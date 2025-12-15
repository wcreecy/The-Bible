import SwiftUI

struct ReadingVerseRow: View {
    let verse: Verse
    let bookName: String
    let chapterNumber: Int
    let isHighlighted: Bool
    let isSelected: Bool
    let isPinned: Bool
    let readerFontSize: Double

    let onAppear: (Int) -> Void
    let onTap: (Verse) -> Void
    let onLongPress: (Int) -> Void

    var body: some View {
        Group {
            VStack(alignment: .leading, spacing: 6) {
                Text(verse.text)
                    .font(.system(size: readerFontSize))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(bookName) \(chapterNumber):\(verse.number)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((isHighlighted || isSelected) ? Color.yellow.opacity(0.25) : Color.clear)
        .overlay(alignment: .trailing) {
            if isPinned {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(.blue)
                    .padding(.trailing, 12)
                    .transition(.opacity)
                    .opacity(0.9)
            }
        }
        .onAppear { onAppear(verse.number) }
        .onLongPressGesture(minimumDuration: 0.5) { onLongPress(verse.number) }
        .contentShape(Rectangle())
        .onTapGesture { onTap(verse) }
    }
}

