import SwiftUI

struct ReadingVerseRow: View {
    let verse: Verse
    let bookName: String
    let chapterNumber: Int
    let isHighlighted: Bool
    let isSelected: Bool
    let isFavorite: Bool
    let hasNote: Bool
    let isPinned: Bool
    let isRead: Bool
    let showsStatusIcons: Bool
    let savedHighlightColor: Color?
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
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground)
        .overlay(alignment: .topLeading) {
            if showsStatusIcons && isFavorite {
                Image(systemName: "heart.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.red)
                    .padding(5)
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if showsStatusIcons && hasNote {
                Image(systemName: "note.text")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.blue)
                    .padding(5)
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .topTrailing) {
            if showsStatusIcons && isPinned {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(5)
                    .transition(.opacity)
                    .opacity(0.9)
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if showsStatusIcons && isRead {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.green)
                    .padding(5)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(bookName) \(chapterNumber):\(verse.number), \(verse.text)")
        .accessibilityValue(accessibilityStatus)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Show verse actions") {
            onLongPress(verse.number)
        }
        .onScrollVisibilityChange(threshold: 0.6, onVisibilityChange)
        .onLongPressGesture(minimumDuration: 0.5) { onLongPress(verse.number) }
        .contentShape(Rectangle())
        .onTapGesture { onTap(verse) }
    }

    private var rowBackground: Color {
        if isHighlighted || isSelected {
            return Color.yellow.opacity(0.25)
        }
        return savedHighlightColor?.opacity(0.24) ?? .clear
    }

    private var accessibilityStatus: String {
        var statuses: [String] = []
        if isFavorite { statuses.append("Favorite") }
        if hasNote { statuses.append("Has note") }
        if isPinned { statuses.append("Bookmarked") }
        if isRead { statuses.append("Read") }
        return statuses.formatted(.list(type: .and))
    }
}
