import SwiftUI

/// UserDefaults keys for what the reader shows on each verse.
enum ReaderDisplaySettings {
    /// Master switch for the verse markers. On by default.
    static let showsVerseMarkersKey = AppStorageKey.showsVerseMarkers
    /// Individual marker visibility preferences. All start on (see `AppSettingsDefaults`).
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
    /// Briefly true when the reader opens at this verse, so the eye lands on it.
    let isHighlighted: Bool
    /// The verse the reader tapped to keep their place.
    let isSelected: Bool
    let isFavorite: Bool
    let hasNote: Bool
    let isBookmarked: Bool
    /// The verse shown on the Pinned Verse widget.
    let isPinnedToWidget: Bool
    let hasCrossReferences: Bool
    /// The passages this verse's connections point to, previewed when the Pencil hovers over the
    /// connections marker.
    var crossReferenceTargets: [String] = []
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
    /// Shows "Genesis 1:1" under each verse; otherwise just "Verse 1".
    var showsFullReference = true

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
    let onPencilHoverChange: (Bool) -> Void

    var body: some View {
        if verse.isOmitted {
            omittedVerseRow
        } else {
            verseRow
        }
    }

    /// A verse the translation leaves out keeps its place, so the numbering reads right.
    /// It still counts as seen, so the chapter can be completed.
    private var omittedVerseRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Verse.omittedNote(in: BibleRepository.shared.activeTranslation))
                .font(.subheadline)
                .italic()
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(showsFullReference ? "\(bookName) \(chapterNumber):\(verse.number)" : "Verse \(verse.number)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .onScrollVisibilityChange(threshold: 0.6, onVisibilityChange)
    }

    private var verseRow: some View {
        Group {
            VStack(alignment: .leading, spacing: 6) {
                Text(verse.attributedText(italicizingSuppliedWords: italicizesSuppliedWords))
                    .font(.system(size: defaultReaderFontSize + CGFloat(readerFontSize - 17)))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                // Markers sit on the reference line, in caption size, so they scale with
                // Dynamic Type and never cover the verse text.
                HStack(spacing: 8) {
                    Text(showsFullReference ? "\(bookName) \(chapterNumber):\(verse.number)" : "Verse \(verse.number)")
                        .foregroundStyle(.secondary)

                    if showsMarkers {
                        markers
                    }
                }
                .font(.caption)

                if let note = BibleRepository.shared.activeTranslation
                    .reorderNote(book: bookName, chapter: chapterNumber, verse: verse.number) {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground)
        .background {
            HighlightPreviewWash(bookName: bookName, chapterNumber: chapterNumber, verseNumber: verse.number)
        }
        // "You are here" after opening at this verse: an orange glow that fades. Orange marks
        // the reader's place and is never a highlight color, so neither is mistaken for one.
        .overlay {
            if isHighlighted {
                Rectangle()
                    .fill(Self.placeColor.opacity(0.18))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .leading) {
            if isSelected {
                // The kept place: a soft bar down the edge, like a finger on the page.
                Capsule()
                    .fill(Self.placeColor.opacity(0.55))
                    .frame(width: 4)
                    .padding(.vertical, 4)
                    .accessibilityHidden(true)
            } else if showsReadProgress && isRead {
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
                Button("Show Scripture connections", action: onOpenCrossReferences)
            }
        }
        .onScrollVisibilityChange(threshold: 0.6, onVisibilityChange)
        .onLongPressGesture(minimumDuration: 0.5) { onLongPress(verse.number) }
        .contentShape(Rectangle())
        .hoverEffect(.highlight)
        .onHover(perform: onPencilHoverChange)
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
            .passageHoverPreview(isEnabled: !crossReferenceTargets.isEmpty) {
                crossReferenceTargets.flatMap {
                    PassageReferenceParser.parseList($0, book: bookName, chapter: chapterNumber)
                }
            }
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
        if showsBookmarkMarker && isBookmarked {
            Image(systemName: "bookmark.fill")
                .foregroundStyle(Color.bookmarkTint)
                .accessibilityHidden(true)
        }
        if showsPinnedVerseMarker && isPinnedToWidget {
            Image(systemName: "widget.small")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
        }
    }

    /// The color of "your place": the verse the reader opened at, and the verse tapped to keep
    /// one's place. None of the highlight colors is orange.
    static let placeColor = Color.orange

    /// A saved highlight keeps its color. Otherwise the kept place gets a light gray tint,
    /// which no highlight color uses.
    private var rowBackground: Color {
        if let savedHighlightColor {
            return savedHighlightColor.opacity(0.24)
        }
        return isSelected ? Color.secondary.opacity(0.12) : .clear
    }

    private var accessibilityStatus: String {
        var statuses: [String] = []
        if isSelected { statuses.append("Marked") }
        // Saved markers are always announced, even when hidden on screen.
        if isBookmarked { statuses.append("Bookmarked") }
        if isPinnedToWidget { statuses.append("Pinned") }
        if isFavorite { statuses.append("Favorite") }
        if hasNote { statuses.append("Has note") }
        if hasCrossReferences { statuses.append("Has Scripture connections") }
        if showsReadProgress && isRead { statuses.append("Read") }
        return statuses.formatted(.list(type: .and))
    }
}
