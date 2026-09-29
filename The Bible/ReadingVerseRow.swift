import SwiftUI

struct ReadingVerseRow: View {
    let verse: Verse
    let bookName: String
    let chapterNumber: Int
    let isHighlighted: Bool
    let isSelected: Bool
    let isPinned: Bool
    let isRead: Bool
    let readerFontSize: Double

    let onVisibilityChange: (Bool) -> Void
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
            .padding(.trailing, isRead ? 20 : 0)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((isHighlighted || isSelected) ? Color.yellow.opacity(0.25) : Color.clear)
        .overlay(alignment: .trailing) {
            if isPinned {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(Color.accentColor)
                    .padding(.trailing, 12)
                    .transition(.opacity)
                    .opacity(0.9)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if isRead {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.trailing, 12)
                    .padding(.bottom, 8)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityValue(isRead ? "Read" : "")
        .onScrollVisibilityChange(threshold: 0.6, onVisibilityChange)
        .onLongPressGesture(minimumDuration: 0.5) { onLongPress(verse.number) }
        .contentShape(Rectangle())
        .onTapGesture { onTap(verse) }
    }
}

