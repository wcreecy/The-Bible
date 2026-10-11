import SwiftData
import SwiftUI
import UIKit

struct VerseActionReference: Hashable {
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
    let verseText: String

    var shareText: String {
        "\(verseText)\n\(bookName) \(chapterNumber):\(verseNumber)"
    }
}

enum VerseActionPresentation {
    case buttons
    case focus
    case menu
}

enum VerseActionFeedback {
    case addedFavorite
    case removedFavorite
    case bookmarked
    case removedBookmark
    case pinned
    case unpinned
    case copied

    // Toast shown for each action, shared by every screen that hosts a verse menu.

    var toastSymbol: String {
        switch self {
        case .addedFavorite: "heart.fill"
        case .removedFavorite: "heart.slash"
        case .bookmarked: "bookmark.fill"
        case .removedBookmark: "bookmark"
        case .pinned: "pin.fill"
        case .unpinned: "pin"
        case .copied: "doc.on.doc"
        }
    }

    var toastText: String {
        switch self {
        case .addedFavorite: String(localized: "Added to Favorites")
        case .removedFavorite: String(localized: "Removed Favorite")
        case .bookmarked: String(localized: "Bookmarked")
        case .removedBookmark: String(localized: "Removed Bookmark")
        case .pinned: String(localized: "Pinned to Widget")
        case .unpinned: String(localized: "Unpinned from Widget")
        case .copied: String(localized: "Copied to Clipboard")
        }
    }

    var toastTint: Color {
        switch self {
        case .addedFavorite: .pink
        case .removedFavorite, .removedBookmark: .secondary
        case .bookmarked, .copied: .accentColor
        case .pinned, .unpinned: .red
        }
    }
}

@MainActor
struct VerseActionMenu: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [Favorite]
    @Query private var notes: [VerseNote]
    @Query private var bookmarks: [Bookmark]
    @State private var pinnedStore = PinnedVerseStore()
    @State private var persistenceFailure: PersistenceFailure?
    @State private var isShowingNoteEditor = false

    let verse: VerseActionReference
    var presentation: VerseActionPresentation = .menu
    var onFeedback: (VerseActionFeedback) -> Void = { _ in }

    private var isFavorite: Bool {
        favorites.contains {
            $0.bookName == verse.bookName &&
            $0.chapterNumber == verse.chapterNumber &&
            $0.verseNumber == verse.verseNumber
        }
    }

    private var matchingBookmarks: [Bookmark] {
        bookmarks.filter {
            $0.bookName == verse.bookName &&
            $0.chapterNumber == verse.chapterNumber &&
            $0.verseNumber == verse.verseNumber
        }
    }

    private var isBookmarked: Bool { !matchingBookmarks.isEmpty }

    private var isPinned: Bool {
        pinnedStore.isPinned(
            bookName: verse.bookName,
            chapter: verse.chapterNumber,
            verse: verse.verseNumber
        )
    }

    private var existingNote: VerseNote? {
        notes.first {
            $0.bookName == verse.bookName &&
            $0.chapterNumber == verse.chapterNumber &&
            $0.verseNumber == verse.verseNumber
        }
    }

    var body: some View {
        actionPresentation
            .task(id: verse) {
                await pinnedStore.load()
            }
            .persistenceFailureAlert(failure: $persistenceFailure)
            .sheet(isPresented: $isShowingNoteEditor) {
                NavigationStack {
                    VerseNoteEditorView(verse: verse, existingNote: existingNote)
                }
            }
    }

    @ViewBuilder
    private var actionPresentation: some View {
        switch presentation {
        case .buttons:
            HStack(spacing: 20) {
                Button(action: { isShowingNoteEditor = true }) {
                    Image(systemName: "highlighter")
                        .foregroundStyle(existingNote == nil ? AnyShapeStyle(.primary) : AnyShapeStyle(Color.accentColor))
                }
                .accessibilityLabel(existingNote == nil ? "Add Note or Highlight" : "Edit Note or Highlight")

                Button(action: toggleFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorite ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
                }
                .accessibilityLabel(isFavorite ? "Remove from Favorites" : "Add to Favorites")

                Button(action: bookmark) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(isBookmarked ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.primary))
                }
                .accessibilityLabel(isBookmarked ? "Remove Bookmark" : "Add Bookmark")

                Button(action: togglePin) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .foregroundStyle(isPinned ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
                }
                .accessibilityLabel(isPinned ? "Unpin from Widget" : "Pin to Widget")

                Button(action: copy) {
                    Image(systemName: "doc.on.doc")
                }
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel("Copy")

                ShareLink(item: verse.shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel("Share")
            }
            .font(.title3)
            .buttonStyle(.plain)

        case .focus:
            HStack(spacing: 18) {
                Button(action: toggleFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorite ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
                }
                .accessibilityLabel(isFavorite ? "Remove from Favorites" : "Add to Favorites")

                Button(action: bookmark) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(isBookmarked ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.primary))
                }
                .accessibilityLabel(isBookmarked ? "Remove Bookmark" : "Add Bookmark")

                Menu {
                    Button(action: copy) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }

                    ShareLink(item: verse.shareText) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    Button(action: togglePin) {
                        Label(
                            isPinned ? "Unpin from Widget" : "Pin to Widget",
                            systemImage: isPinned ? "pin.fill" : "pin"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More verse actions")
            }
            .buttonStyle(.plain)

        case .menu:
            Menu {
                Button(action: { isShowingNoteEditor = true }) {
                    Label(
                        existingNote == nil ? "Add Note or Highlight" : "Edit Note or Highlight",
                        systemImage: "highlighter"
                    )
                }

                Button(action: toggleFavorite) {
                    Label(
                        isFavorite ? "Remove from Favorites" : "Add to Favorites",
                        systemImage: isFavorite ? "heart.fill" : "heart"
                    )
                }

                Button(action: bookmark) {
                    Label(
                        isBookmarked ? "Remove Bookmark" : "Add Bookmark",
                        systemImage: isBookmarked ? "bookmark.fill" : "bookmark"
                    )
                }

                Button(action: togglePin) {
                    Label(
                        isPinned ? "Unpin from Widget" : "Pin to Widget",
                        systemImage: isPinned ? "pin.fill" : "pin"
                    )
                }

                Button(action: copy) {
                    Label("Copy", systemImage: "doc.on.doc")
                }

                ShareLink(item: verse.shareText) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
            }
            .accessibilityLabel("Verse actions")
        }
    }

    private func toggleFavorite() {
        // Synced devices can briefly hold duplicates; removing one would leave the verse favorited.
        let existing = favorites.filter {
            $0.bookName == verse.bookName &&
            $0.chapterNumber == verse.chapterNumber &&
            $0.verseNumber == verse.verseNumber
        }
        if !existing.isEmpty {
            ModelContextPersistence.perform(
                in: modelContext,
                operation: {
                    for favorite in existing {
                        modelContext.delete(favorite)
                    }
                    try modelContext.save()
                },
                onSuccess: {
                    Haptics.selection()
                    onFeedback(.removedFavorite)
                },
                onFailure: { persistenceFailure = $0 }
            )
        } else {
            ModelContextPersistence.perform(
                in: modelContext,
                operation: {
                    modelContext.insert(
                        Favorite(
                            bookName: verse.bookName,
                            chapterNumber: verse.chapterNumber,
                            verseNumber: verse.verseNumber,
                            verseText: verse.verseText
                        )
                    )
                    try modelContext.save()
                },
                onSuccess: {
                    Haptics.success()
                    onFeedback(.addedFavorite)
                },
                onFailure: { persistenceFailure = $0 }
            )
        }
    }

    private func bookmark() {
        // Synced devices can briefly hold duplicates; removing one would leave the verse bookmarked.
        let existing = matchingBookmarks

        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                if existing.isEmpty {
                    try Bookmark.move(
                        to: verse.bookName,
                        chapter: verse.chapterNumber,
                        verse: verse.verseNumber,
                        verseText: verse.verseText,
                        in: modelContext
                    )
                } else {
                    existing.forEach(modelContext.delete)
                }
                try modelContext.save()
            },
            onSuccess: {
                if existing.isEmpty {
                    Haptics.success()
                    onFeedback(.bookmarked)
                } else {
                    Haptics.selection()
                    onFeedback(.removedBookmark)
                }
            },
            onFailure: { persistenceFailure = $0 }
        )
    }

    private func togglePin() {
        Task { @MainActor in
            if isPinned {
                await pinnedStore.clear()
                onFeedback(.unpinned)
            } else {
                await pinnedStore.set(
                    bookName: verse.bookName,
                    chapter: verse.chapterNumber,
                    verse: verse.verseNumber,
                    text: verse.verseText
                )
                onFeedback(.pinned)
            }
            Haptics.success()
        }
    }

    private func copy() {
        UIPasteboard.general.string = verse.shareText
        Haptics.selection()
        onFeedback(.copied)
    }
}
