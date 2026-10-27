import SwiftUI

/// UserDefaults keys for what the reader shows on each verse.
enum ReaderDisplaySettings {
    /// Master switch for the verse markers. On by default.
    static let showsVerseMarkersKey = AppStorageKey.showsVerseMarkers
    /// Individual marker visibility preferences. All are on by default.
    static let showsBookmarkMarkersKey = AppStorageKey.showsBookmarkMarkers
    static let showsPinnedVerseMarkerKey = AppStorageKey.showsPinnedVerseMarker
    static let showsFavoriteMarkersKey = AppStorageKey.showsFavoriteMarkers
    static let showsNoteMarkersKey = AppStorageKey.showsNoteMarkers
    static let showsCrossReferenceMarkersKey = AppStorageKey.showsCrossReferenceMarkers
    /// Read progress. Keeps the older all-icons key so existing choices carry over.
    static let showsReadProgressKey = AppStorageKey.showsReadVerseCheckmarks
}

struct ReadingVerseRow: View {
    let verse: Verse
    let bookName: String
    let chapterNumber: Int
    let isHighlighted: Bool
    let isSelected: Bool
    let isFavorite: Bool
    let hasNote: Bool
    let isPinned: Bool
    let isCurrentlyPinned: Bool
    let hasCrossReferences: Bool
    let isRead: Bool
    /// Master switch for markers beside the reference.
    let showsMarkers: Bool
    let showsBookmarkMarker: Bool
    let showsPinnedVerseMarker: Bool
    let showsFavoriteMarker: Bool
    let showsNoteMarker: Bool
    let showsCrossReferenceMarker: Bool
    /// A faint edge on verses already read.
    let showsReadProgress: Bool
    let savedHighlightColor: Color?
    let readerFontSize: Double

    // Preserve the reader's size preference while scaling its 17-point baseline with Dynamic Type.
    @ScaledMetric(relativeTo: .body) private var defaultReaderFontSize: CGFloat = 17
    @AppStorage(RedLetterText.suppliedWordsInItalicsKey) private var italicizesSuppliedWords = false

    let onVisibilityChange: (Bool) -> Void
    let onTap: (Verse) -> Void
    let onLongPress: (Int) -> Void
    /// Opens the verse's note; used by the note marker.
    let onOpenNote: () -> Void
    /// Opens the Scripture connections associated with this verse.
    let onOpenCrossReferences: () -> Void

    var body: some View {
        Group {
            VStack(alignment: .leading, spacing: 6) {
                Text(verse.attributedText(italicizingSuppliedWords: italicizesSuppliedWords))
                    .font(.system(size: defaultReaderFontSize + CGFloat(readerFontSize - 17)))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                // Markers sit on the reference line, in caption size, so they scale with
                // Dynamic Type and never cover the verse text.
                HStack(spacing: 8) {
                    Text("\(bookName) \(chapterNumber):\(verse.number)")
                        .foregroundStyle(.secondary)

                    if showsMarkers {
                        markers
                    }
                }
                .font(.caption)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground)
        .overlay(alignment: .leading) {
            if showsReadProgress && isRead {
                Capsule()
                    .fill(Color.green.opacity(0.4))
                    .frame(width: 3)
                    .padding(.vertical, 6)
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
        .accessibilityActions {
            if hasNote {
                Button("Open note", action: onOpenNote)
            }
            if hasCrossReferences {
                Button("Show cross references", action: onOpenCrossReferences)
            }
        }
        .onScrollVisibilityChange(threshold: 0.6, onVisibilityChange)
        .onLongPressGesture(minimumDuration: 0.5) { onLongPress(verse.number) }
        .contentShape(Rectangle())
        .onTapGesture { onTap(verse) }
    }

    @ViewBuilder
    private var markers: some View {
        if showsCrossReferenceMarker && hasCrossReferences {
            Button(action: onOpenCrossReferences) {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle().inset(by: -10))
            .accessibilityHidden(true)
        }
        if showsNoteMarker && hasNote {
            Button(action: onOpenNote) {
                Image(systemName: "note.text")
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            // A larger touch area than the small icon, without changing the layout.
            .contentShape(Rectangle().inset(by: -10))
                .accessibilityHidden(true)
        }
        if showsFavoriteMarker && isFavorite {
            Image(systemName: "heart.fill")
                .foregroundStyle(.red)
                .accessibilityHidden(true)
        }
        if showsBookmarkMarker && isPinned {
            Image(systemName: "bookmark.fill")
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
        }
        if showsPinnedVerseMarker && isCurrentlyPinned {
            Image(systemName: "pin.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
        }
    }

    private var rowBackground: Color {
        if isHighlighted || isSelected {
            return Color.yellow.opacity(0.25)
        }
        return savedHighlightColor?.opacity(0.24) ?? .clear
    }

    private var accessibilityStatus: String {
        var statuses: [String] = []
        // Saved markers are always announced, even when hidden on screen.
        if isPinned { statuses.append("Bookmarked") }
        if isCurrentlyPinned { statuses.append("Pinned") }
        if isFavorite { statuses.append("Favorite") }
        if hasNote { statuses.append("Has note") }
        if hasCrossReferences { statuses.append("Has cross references") }
        if showsReadProgress && isRead { statuses.append("Read") }
        return statuses.formatted(.list(type: .and))
    }
}
