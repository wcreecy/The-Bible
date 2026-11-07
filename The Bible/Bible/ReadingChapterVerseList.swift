import SwiftUI
import SwiftData
import UIKit

/// The reader's verse rows for one chapter. The saved-item queries live here, filtered to that
/// chapter, so the reader indexes only this chapter's favorites, notes, and bookmarks rather
/// than every one saved.
struct ReadingChapterVerseList: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [Favorite]
    @Query private var verseNotes: [VerseNote]
    @Query private var bookmarks: [Bookmark]

    @AppStorage(ReaderDisplaySettings.showsVerseMarkersKey) private var showsVerseMarkers: Bool = true
    @AppStorage(ReaderDisplaySettings.showsBookmarkMarkersKey) private var showsBookmarkMarkers: Bool = true
    @AppStorage(ReaderDisplaySettings.showsPinnedVerseMarkerKey) private var showsPinnedVerseMarker: Bool = true
    @AppStorage(ReaderDisplaySettings.showsFavoriteMarkersKey) private var showsFavoriteMarkers: Bool = true
    @AppStorage(ReaderDisplaySettings.showsNoteMarkersKey) private var showsNoteMarkers: Bool = true
    @AppStorage(ReaderDisplaySettings.showsCrossReferenceMarkersKey) private var showsCrossReferenceMarkers: Bool = true

    let bookName: String
    let chapterNumber: Int
    let viewModel: ReadingViewModel
    let pinnedStore: PinnedVerseStore
    let crossReferences: [ChapterRelatedVerse]
    /// Verses already read in this chapter; empty while read progress is off.
    let readVerseNumbers: Set<Int>
    let showsReadProgress: Bool
    let readerFontSize: Double
    let showsFullReferences: Bool
    let onOpenNote: (Verse) -> Void
    let onOpenCrossReferences: (Verse) -> Void
    let onVerseActionFeedback: (VerseActionFeedback) -> Void

    init(
        bookName: String,
        chapterNumber: Int,
        viewModel: ReadingViewModel,
        pinnedStore: PinnedVerseStore,
        crossReferences: [ChapterRelatedVerse],
        readVerseNumbers: Set<Int>,
        showsReadProgress: Bool,
        readerFontSize: Double,
        showsFullReferences: Bool,
        onOpenNote: @escaping (Verse) -> Void,
        onOpenCrossReferences: @escaping (Verse) -> Void,
        onVerseActionFeedback: @escaping (VerseActionFeedback) -> Void
    ) {
        self.bookName = bookName
        self.chapterNumber = chapterNumber
        self.viewModel = viewModel
        self.pinnedStore = pinnedStore
        self.crossReferences = crossReferences
        self.readVerseNumbers = readVerseNumbers
        self.showsReadProgress = showsReadProgress
        self.readerFontSize = readerFontSize
        self.showsFullReferences = showsFullReferences
        self.onOpenNote = onOpenNote
        self.onOpenCrossReferences = onOpenCrossReferences
        self.onVerseActionFeedback = onVerseActionFeedback

        // Rebuilt whenever the reader moves to another chapter, which re-creates this view.
        _favorites = Query(filter: #Predicate<Favorite> {
            $0.bookName == bookName && $0.chapterNumber == chapterNumber
        })
        _verseNotes = Query(filter: #Predicate<VerseNote> {
            $0.bookName == bookName && $0.chapterNumber == chapterNumber
        })
        _bookmarks = Query(filter: #Predicate<Bookmark> {
            $0.bookName == bookName && $0.chapterNumber == chapterNumber
        })
    }

    var body: some View {
        let verses = viewModel.currentChapter.verses
        // Build this once per update instead of scanning the saved items for every verse.
        let chapterStatus = ReadingChapterStatusIndex(
            favorites: favorites,
            notes: verseNotes,
            bookmarks: bookmarks,
            crossReferences: crossReferences,
            bookName: bookName,
            chapterNumber: chapterNumber
        )

        ForEach(verses) { verse in
            let readUpdate = SeenVerseUpdate(
                bookName: bookName,
                chapter: chapterNumber,
                verse: verse.number,
                totalVerses: verses.count
            )

            ReadingVerseRow(
                verse: verse,
                bookName: bookName,
                chapterNumber: chapterNumber,
                isHighlighted: viewModel.highlightedVerse == verse.number,
                isSelected: viewModel.selectedVerse == verse.number,
                isFavorite: chapterStatus.favoriteVerseNumbers.contains(verse.number),
                hasNote: chapterStatus.hasNote(verse.number),
                isPinned: chapterStatus.bookmarkedVerseNumbers.contains(verse.number),
                isCurrentlyPinned: pinnedStore.isPinned(
                    bookName: bookName,
                    chapter: chapterNumber,
                    verse: verse.number
                ),
                hasCrossReferences: chapterStatus.crossReferenceVerseNumbers.contains(verse.number),
                isRead: readVerseNumbers.contains(verse.number),
                showsMarkers: showsVerseMarkers,
                showsBookmarkMarker: showsBookmarkMarkers,
                showsPinnedVerseMarker: showsPinnedVerseMarker,
                showsFavoriteMarker: showsFavoriteMarkers,
                showsNoteMarker: showsNoteMarkers,
                showsCrossReferenceMarker: showsCrossReferenceMarkers,
                showsReadProgress: showsReadProgress,
                savedHighlightColor: chapterStatus.highlightColor(for: verse.number),
                readerFontSize: readerFontSize,
                showsFullReference: showsFullReferences,
                onVisibilityChange: { isVisible in
                    viewModel.verseVisibilityChanged(readUpdate, isVisible: isVisible)
                },
                onTap: { v in
                    let generator = UISelectionFeedbackGenerator()
                    generator.selectionChanged()
                    // Tapping a verse that is already selected opens its actions,
                    // the same as a long press; a third tap closes them.
                    let opensActions = viewModel.selectedVerse == v.number
                        && viewModel.menuVerse != v.number
                    viewModel.clearMenuIfNeeded()
                    // Tap otherwise only highlights/selects (no bookmarking)
                    viewModel.handleVerseTap(context: modelContext, verse: v)
                    if opensActions {
                        viewModel.handleVerseLongPress(verseNumber: v.number)
                    }
                },
                onLongPress: { number in
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.impactOccurred()
                    viewModel.handleVerseLongPress(verseNumber: number)
                },
                onOpenNote: {
                    onOpenNote(verse)
                },
                onOpenCrossReferences: {
                    onOpenCrossReferences(verse)
                }
            )
            .id(viewModel.rowID(for: verse.number))
            .animation(.easeInOut(duration: 0.6), value: viewModel.highlightedVerse)
            .animation(.easeInOut(duration: 0.2), value: viewModel.selectedVerse)

            if viewModel.menuVerse == verse.number {
                VerseActionMenu(
                    verse: VerseActionReference(
                        bookName: bookName,
                        chapterNumber: chapterNumber,
                        verseNumber: verse.number,
                        verseText: verse.text
                    ),
                    presentation: .buttons,
                    onFeedback: onVerseActionFeedback
                )
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .padding(.bottom, 6)
                .transition(.opacity)
            }

            if verse.number != verses.count {
                Divider()
            }
        }
    }
}

/// Chapter-local saved-data index for the reader. It replaces repeated whole-collection
/// searches while keeping the existing marker and note precedence rules intact.
struct ReadingChapterStatusIndex {
    let favoriteVerseNumbers: Set<Int>
    let bookmarkedVerseNumbers: Set<Int>
    let crossReferenceVerseNumbers: Set<Int>
    private let notesByVerse: [Int: [VerseNote]]

    init(
        favorites: [Favorite],
        notes: [VerseNote],
        bookmarks: [Bookmark],
        crossReferences: [ChapterRelatedVerse],
        bookName: String,
        chapterNumber: Int
    ) {
        favoriteVerseNumbers = Set(favorites.compactMap {
            $0.bookName == bookName && $0.chapterNumber == chapterNumber ? $0.verseNumber : nil
        })
        bookmarkedVerseNumbers = Set(bookmarks.compactMap {
            $0.bookName == bookName && $0.chapterNumber == chapterNumber ? $0.verseNumber : nil
        })
        crossReferenceVerseNumbers = Set(crossReferences.map(\.sourceVerse))

        var indexedNotes: [Int: [VerseNote]] = [:]
        for note in notes where note.bookName == bookName && note.chapterNumber == chapterNumber {
            for verseNumber in note.verseNumber...note.lastVerseNumber {
                indexedNotes[verseNumber, default: []].append(note)
            }
        }
        for (verseNumber, coveringNotes) in indexedNotes {
            indexedNotes[verseNumber] = coveringNotes.sorted {
                ($0.verseNumber == verseNumber ? 0 : 1, $0.lastVerseNumber - $0.verseNumber) <
                    ($1.verseNumber == verseNumber ? 0 : 1, $1.lastVerseNumber - $1.verseNumber)
            }
        }
        notesByVerse = indexedNotes
    }

    func hasNote(_ verseNumber: Int) -> Bool {
        notesByVerse[verseNumber, default: []].contains {
            let title = $0.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let content = $0.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return !title.isEmpty || (!content.isEmpty && content != $0.reference)
        }
    }

    func highlightColor(for verseNumber: Int) -> Color? {
        notesByVerse[verseNumber, default: []]
            .first { !$0.highlightColor.isEmpty }
            .flatMap { VerseHighlightColor(rawValue: $0.highlightColor)?.color }
    }
}
