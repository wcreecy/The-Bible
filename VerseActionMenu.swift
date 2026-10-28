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

/// Passes menu feedback up to the screen's toast. It is a class so the environment value
/// stays the same object, and the menus below aren't redrawn each time the toast changes.
final class VerseActionFeedbackRelay {
    var send: (VerseActionFeedback) -> Void = { _ in }
}

extension EnvironmentValues {
    /// Receives feedback from any verse menu below that wasn't given its own `onFeedback`.
    @Entry var verseActionFeedback: VerseActionFeedbackRelay? = nil
}

/// Drives the toast a screen shows after a verse action. Keep one as `@State` and attach
/// `.verseActionToast($state)` to the screen.
struct VerseActionToastState {
    fileprivate(set) var feedback: VerseActionFeedback = .copied
    fileprivate(set) var isPresented = false

    fileprivate mutating func show(_ feedback: VerseActionFeedback) {
        self.feedback = feedback
        withAnimation(.spring()) { isPresented = true }
    }
}

private struct VerseActionToastModifier: ViewModifier {
    @Binding var state: VerseActionToastState
    let bottomPadding: CGFloat
    @State private var relay = VerseActionFeedbackRelay()

    func body(content: Content) -> some View {
        content
            .environment(\.verseActionFeedback, relay)
            .onAppear { relay.send = { state.show($0) } }
            .appToast(
                isPresented: $state.isPresented,
                symbol: state.feedback.toastSymbol,
                text: state.feedback.toastText,
                tint: state.feedback.toastTint,
                bottomPadding: bottomPadding
            )
    }
}

extension View {
    /// Shows a toast for the actions of every verse menu in this view that doesn't pass its
    /// own `onFeedback`.
    func verseActionToast(_ state: Binding<VerseActionToastState>, bottomPadding: CGFloat = 20) -> some View {
        modifier(VerseActionToastModifier(state: state, bottomPadding: bottomPadding))
    }
}

/// The saved items a verse menu reads to show its state (favorited, bookmarked, noted).
struct SavedVerseCollections {
    let favorites: [Favorite]
    let notes: [VerseNote]
    let userNotes: [UserNote]
    let bookmarks: [Bookmark]
}

/// A verse menu that queries the saved items itself. Screens that show many menus at once
/// (such as search results) should run the queries once and use `VerseActionMenuContent`.
@MainActor
struct VerseActionMenu: View {
    @Query private var favorites: [Favorite]
    @Query private var notes: [VerseNote]
    @Query private var userNotes: [UserNote]
    @Query private var bookmarks: [Bookmark]

    let verse: VerseActionReference
    var presentation: VerseActionPresentation = .menu
    var onFeedback: ((VerseActionFeedback) -> Void)?
    var onNoteEditorPresented: () -> Void = {}
    var onNoteEditorDismissed: () -> Void = {}

    var body: some View {
        VerseActionMenuContent(
            verse: verse,
            saved: SavedVerseCollections(
                favorites: favorites,
                notes: notes,
                userNotes: userNotes,
                bookmarks: bookmarks
            ),
            presentation: presentation,
            onFeedback: onFeedback,
            onNoteEditorPresented: onNoteEditorPresented,
            onNoteEditorDismissed: onNoteEditorDismissed
        )
    }
}

@MainActor
struct VerseActionMenuContent: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.verseActionFeedback) private var feedbackRelay
    @State private var pinnedStore = PinnedVerseStore.shared
    @State private var persistenceFailure: PersistenceFailure?
    @State private var isShowingNoteEditor = false
    @State private var isShowingMentions = false

    let verse: VerseActionReference
    let saved: SavedVerseCollections
    var presentation: VerseActionPresentation = .menu
    var onFeedback: ((VerseActionFeedback) -> Void)?
    var onNoteEditorPresented: () -> Void = {}
    var onNoteEditorDismissed: () -> Void = {}

    /// Reports to this menu's own handler, or else to the screen's `verseActionToast`.
    private func sendFeedback(_ feedback: VerseActionFeedback) {
        if let onFeedback {
            onFeedback(feedback)
        } else {
            feedbackRelay?.send(feedback)
        }
    }

    private var favorites: [Favorite] { saved.favorites }
    private var notes: [VerseNote] { saved.notes }
    private var userNotes: [UserNote] { saved.userNotes }
    private var bookmarks: [Bookmark] { saved.bookmarks }

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

    /// The note on this verse; a note on several verses counts for each of them. A note
    /// starting at this verse wins over one that only spans it.
    private var existingNote: VerseNote? {
        let covering = notes.filter {
            $0.covers(bookName: verse.bookName, chapterNumber: verse.chapterNumber, verseNumber: verse.verseNumber)
        }
        return covering.first { $0.verseNumber == verse.verseNumber } ?? covering.first
    }

    /// How many other notes mention this verse in their text or passage.
    private var mentionCount: Int {
        NoteMentions.items(mentioning: verse, scriptureNotes: notes, userNotes: userNotes).count
    }

    var body: some View {
        actionPresentation
            .task(id: verse) {
                await pinnedStore.load()
            }
            .persistenceFailureAlert(failure: $persistenceFailure)
            .sheet(isPresented: $isShowingNoteEditor, onDismiss: onNoteEditorDismissed) {
                NavigationStack {
                    VerseNoteEditorView(verse: verse, existingNote: existingNote)
                }
            }
            .sheet(isPresented: $isShowingMentions) {
                NavigationStack {
                    NoteMentionsView(verse: verse)
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

                let mentions = mentionCount
                if mentions > 0 {
                    Button(action: { isShowingMentions = true }) {
                        Image(systemName: "link")
                            .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityLabel("Notes Mentioning This Verse")
                    .accessibilityValue(Text("\(mentions)"))
                }

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
                        .foregroundStyle(isPinned ? AnyShapeStyle(.orange) : AnyShapeStyle(.primary))
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

                Menu {
                    Button(action: {
                        onNoteEditorPresented()
                        isShowingNoteEditor = true
                    }) {
                        Label(
                            existingNote == nil ? "Add Note or Highlight" : "Edit Note or Highlight",
                            systemImage: "highlighter"
                        )
                    }
                    mentionsButton

                    Button(action: bookmark) {
                        Label(
                            isBookmarked ? "Remove Bookmark" : "Add Bookmark",
                            systemImage: isBookmarked ? "bookmark.fill" : "bookmark"
                        )
                    }

                    Divider()

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
                mentionsButton

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

    @ViewBuilder
    private var mentionsButton: some View {
        let mentions = mentionCount
        if mentions > 0 {
            Button(action: { isShowingMentions = true }) {
                Label("Notes Mentioning This Verse (\(mentions))", systemImage: "link")
            }
        }
    }

    private func toggleFavorite() {
        var added = false
        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                added = try FavoriteVerses.toggle(
                    bookName: verse.bookName,
                    chapterNumber: verse.chapterNumber,
                    verseNumber: verse.verseNumber,
                    verseText: verse.verseText,
                    favorites: favorites,
                    in: modelContext
                )
            },
            onSuccess: {
                if added {
                    Haptics.success()
                    sendFeedback(.addedFavorite)
                } else {
                    Haptics.selection()
                    sendFeedback(.removedFavorite)
                }
            },
            onFailure: { persistenceFailure = $0 }
        )
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
                    ReadingPositionStore.shared.record(
                        bookName: verse.bookName,
                        chapter: verse.chapterNumber,
                        verse: verse.verseNumber
                    )
                    ReadingPositionStore.shared.flush()
                    Haptics.success()
                    sendFeedback(.bookmarked)
                } else {
                    Bookmark.clearWidget()
                    Haptics.selection()
                    sendFeedback(.removedBookmark)
                }
            },
            onFailure: { persistenceFailure = $0 }
        )
    }

    private func togglePin() {
        Task { @MainActor in
            if isPinned {
                await pinnedStore.clear()
                sendFeedback(.unpinned)
            } else {
                await pinnedStore.set(
                    bookName: verse.bookName,
                    chapter: verse.chapterNumber,
                    verse: verse.verseNumber,
                    text: verse.verseText
                )
                sendFeedback(.pinned)
            }
            Haptics.success()
        }
    }

    private func copy() {
        UIPasteboard.general.string = verse.shareText
        Haptics.selection()
        sendFeedback(.copied)
    }
}
