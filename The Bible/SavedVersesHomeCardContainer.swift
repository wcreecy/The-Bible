import SwiftUI
import SwiftData

/// Keeps saved-verse queries and preview construction out of the large Home view's
/// invalidation boundary. Changes to saved verses now update this card alone.
struct SavedVersesHomeCardContainer: View {
    @Query private var favorites: [Favorite]
    @Query(filter: #Predicate<VerseNote> { $0.highlightColor != "" }) private var highlights: [VerseNote]
    @AppStorage("homeSavedVersePinID") private var savedVersePinID = ""
    @AppStorage("homeSavedVersePinDay") private var savedVersePinDay = 0
    @State private var previewOffset = 0

    let onOpenSavedVerses: () -> Void
    let onOpenVerse: (SavedVerseHomePreview) -> Void

    private var previews: [SavedVerseHomePreview] {
        favorites.map { favorite in
            SavedVerseHomePreview(
                reference: "\(favorite.bookName) \(favorite.chapterNumber):\(favorite.verseNumber)",
                text: favorite.verseText,
                kind: .favorite,
                date: favorite.createdAt,
                bookName: favorite.bookName,
                chapterNumber: favorite.chapterNumber,
                verseNumber: favorite.verseNumber,
                highlightColor: nil
            )
        } + highlights.map { highlight in
            SavedVerseHomePreview(
                reference: highlight.reference,
                text: highlight.verseText,
                kind: .highlight,
                date: highlight.createdAt ?? highlight.updatedAt ?? .distantPast,
                bookName: highlight.bookName,
                chapterNumber: highlight.chapterNumber,
                verseNumber: highlight.verseNumber,
                highlightColor: VerseHighlightColor(rawValue: highlight.highlightColor)
            )
        }
    }

    private var pinnedPreview: SavedVerseHomePreview.DailyPin? {
        savedVersePinID.isEmpty ? nil : .init(id: savedVersePinID, day: savedVersePinDay)
    }

    var body: some View {
        let preview = SavedVerseHomePreview.dailyPreview(
            from: previews,
            rotationOffset: previewOffset,
            pinned: pinnedPreview
        )

        SavedVersesHomeCard(
            preview: preview,
            favoriteCount: favorites.count,
            highlightCount: highlights.count,
            onOpenSavedVerses: onOpenSavedVerses,
            onRefresh: {
                savedVersePinID = ""
                previewOffset += 1
            },
            onOpenVerse: onOpenVerse
        )
        .onChange(of: "\(preview?.pinID ?? "")|\(SavedVerseHomePreview.dayIndex(for: .now))", initial: true) {
            pin(preview)
        }
    }

    private func pin(_ preview: SavedVerseHomePreview?) {
        let day = SavedVerseHomePreview.dayIndex(for: .now)
        guard let preview, preview.pinID != savedVersePinID || day != savedVersePinDay else { return }
        savedVersePinID = preview.pinID
        savedVersePinDay = day
    }
}
