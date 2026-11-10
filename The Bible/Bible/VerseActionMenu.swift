import SwiftData
import SwiftUI
import UIKit

struct VerseActionReference: Hashable, Identifiable {
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
    let verseText: String
    /// The translation `verseText` is in. A saved verse passes the one it was saved in.
    var translation: BibleTranslation = BibleRepository.shared.activeTranslation

    var id: String {
        "\(bookName)|\(chapterNumber)|\(verseNumber)|\(verseText)"
    }

    var shareText: String {
        "\(verseText)\n\(bookName) \(chapterNumber):\(verseNumber) \(translation.abbreviation)"
    }
}

/// A single entry point for sharing a verse as text or as a designed image, and optionally
/// for copying it.
struct VerseShareMenu<MenuLabel: View>: View {
    let verse: VerseActionReference
    /// Adds Copy Text to the menu when set, for rows that have no separate Copy button.
    var onCopy: (() -> Void)? = nil
    let onCreateImage: () -> Void
    @ViewBuilder let label: () -> MenuLabel

    var body: some View {
        Menu {
            if let onCopy {
                Button(action: onCopy) {
                    Label("Copy Text", systemImage: "doc.on.doc")
                }
            }

            ShareLink(item: verse.shareText) {
                Label("Share Verse", systemImage: "text.quote")
            }

            Button {
                onCreateImage()
            } label: {
                Label("Create Verse Image", systemImage: "photo.on.rectangle.angled")
            }
        } label: {
            label()
        }
    }
}

/// Gives each icon in an inline verse action row a comfortable touch target without changing
/// how the icons look.
private struct VerseActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minWidth: 40, minHeight: 44)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

enum VerseActionPresentation {
    case buttons
    case focus
    case menu
    /// Favorite and share sit on the card; everything else is in a "more" menu.
    case cardActions
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

    init(
        verse: VerseActionReference,
        presentation: VerseActionPresentation = .menu,
        onFeedback: ((VerseActionFeedback) -> Void)? = nil,
        onNoteEditorPresented: @escaping () -> Void = {},
        onNoteEditorDismissed: @escaping () -> Void = {}
    ) {
        self.verse = verse
        self.presentation = presentation
        self.onFeedback = onFeedback
        self.onNoteEditorPresented = onNoteEditorPresented
        self.onNoteEditorDismissed = onNoteEditorDismissed

        // Favorites and bookmarks matter only for this verse. Notes stay unfiltered: a note
        // anywhere can mention this verse, and the mention count needs them all.
        let bookName = verse.bookName
        let chapterNumber = verse.chapterNumber
        let verseNumber = verse.verseNumber
        _favorites = Query(filter: #Predicate<Favorite> {
            $0.bookName == bookName && $0.chapterNumber == chapterNumber && $0.verseNumber == verseNumber
        })
        _bookmarks = Query(filter: #Predicate<Bookmark> {
            $0.bookName == bookName && $0.chapterNumber == chapterNumber && $0.verseNumber == verseNumber
        })
    }

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
    @State private var imageComposerVerse: VerseActionReference?
    @State private var isShowingCompare = false
    @State private var isShowingOriginalWords = false

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
            .sheet(isPresented: $isShowingCompare) {
                NavigationStack {
                    VerseCompareView(
                        bookName: verse.bookName,
                        chapter: verse.chapterNumber,
                        verse: verse.verseNumber
                    )
                }
            }
            .sheet(isPresented: $isShowingOriginalWords) {
                NavigationStack {
                    OriginalWordsView(
                        bookName: verse.bookName,
                        chapter: verse.chapterNumber,
                        verse: verse.verseNumber,
                        translation: verse.translation
                    )
                }
            }
            .fullScreenCover(item: $imageComposerVerse) { verse in
                VerseImageComposerView(verse: verse)
            }
    }

    @ViewBuilder
    private var actionPresentation: some View {
        switch presentation {
        case .buttons:
            // The most-used actions: the three ways to keep a verse, then Share. The rest are in
            // More, with text labels.
            HStack(spacing: 0) {
                Button(action: { isShowingNoteEditor = true }) {
                    Image(systemName: "highlighter")
                        .foregroundStyle(existingNote == nil ? AnyShapeStyle(.primary) : AnyShapeStyle(Color.accentColor))
                }
                .accessibilityLabel(noteActionTitle)
                .frame(maxWidth: .infinity)

                Button(action: toggleFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorite ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
                }
                .accessibilityLabel(favoriteActionTitle)
                .frame(maxWidth: .infinity)

                // The one bookmark: where the reader stopped, shown first by Continue Reading.
                Button(action: bookmark) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(isBookmarked ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.primary))
                }
                .accessibilityLabel(bookmarkActionTitle)
                .frame(maxWidth: .infinity)

                VerseShareMenu(verse: verse, onCopy: copy, onCreateImage: showImageComposer) {
                    Image(systemName: "square.and.arrow.up")
                        .frame(minWidth: 40, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel("Share")
                .frame(maxWidth: .infinity)

                Menu {
                    compareMenuButton
                    wordStudyMenuButton
                    mentionsButton
                    pinMenuButton
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(minWidth: 40, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel("More verse actions")
                .frame(maxWidth: .infinity)
            }
            .font(.title3)
            .buttonStyle(VerseActionButtonStyle())

        case .focus:
            HStack(spacing: 18) {
                Button(action: toggleFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorite ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
                }
                .accessibilityLabel(favoriteActionTitle)

                Menu {
                    noteMenuButton(notifiesPresentation: true)
                    mentionsButton
                    bookmarkMenuButton

                    compareMenuButton
                    wordStudyMenuButton

                    Divider()

                    copyMenuButton
                    shareMenuButton
                    pinMenuButton
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More verse actions")
            }
            .buttonStyle(.plain)

        case .cardActions:
            HStack(spacing: 8) {
                Button(action: toggleFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorite ? AnyShapeStyle(.red) : AnyShapeStyle(Color.accentColor))
                }
                .accessibilityLabel(favoriteActionTitle)

                VerseShareMenu(verse: verse, onCreateImage: showImageComposer) {
                    Image(systemName: "square.and.arrow.up")
                        .frame(minWidth: 40, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel("Share")

                Menu {
                    noteMenuButton(notifiesPresentation: false)
                    mentionsButton
                    bookmarkMenuButton
                    pinMenuButton
                    compareMenuButton
                    wordStudyMenuButton
                    copyMenuButton
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(minWidth: 40, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Verse actions")
            }
            .font(.title3)
            .buttonStyle(VerseActionButtonStyle())

        case .menu:
            Menu {
                noteMenuButton(notifiesPresentation: false)
                mentionsButton
                favoriteMenuButton
                bookmarkMenuButton
                pinMenuButton
                compareMenuButton
                wordStudyMenuButton
                copyMenuButton
                shareMenuButton
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
            }
            .accessibilityLabel("Verse actions")
        }
    }

    // MARK: Shared action titles and menu items

    private var noteActionTitle: LocalizedStringKey {
        existingNote == nil ? "Add Note or Highlight" : "Edit Note or Highlight"
    }

    private var favoriteActionTitle: LocalizedStringKey {
        isFavorite ? "Remove from Favorites" : "Add to Favorites"
    }

    private var bookmarkActionTitle: LocalizedStringKey {
        isBookmarked ? "Remove Bookmark" : "Add Bookmark"
    }

    private var pinActionTitle: LocalizedStringKey {
        isPinned ? "Unpin from Widget" : "Pin to Widget"
    }

    /// Only the Focus Mode menu tells its host when the note editor opens.
    private func noteMenuButton(notifiesPresentation: Bool) -> some View {
        Button {
            if notifiesPresentation { onNoteEditorPresented() }
            isShowingNoteEditor = true
        } label: {
            Label(noteActionTitle, systemImage: "highlighter")
        }
    }

    private var favoriteMenuButton: some View {
        Button(action: toggleFavorite) {
            Label(favoriteActionTitle, systemImage: isFavorite ? "heart.fill" : "heart")
        }
    }

    private var bookmarkMenuButton: some View {
        Button(action: bookmark) {
            Label(bookmarkActionTitle, systemImage: isBookmarked ? "bookmark.fill" : "bookmark")
        }
    }

    private var pinMenuButton: some View {
        Button(action: togglePin) {
            Label(pinActionTitle, systemImage: isPinned ? "pin.fill" : "pin")
        }
    }

    /// Only offered when there is more than one translation to compare.
    @ViewBuilder
    private var compareMenuButton: some View {
        if BibleTranslation.available.count > 1 {
            Button { isShowingCompare = true } label: {
                Label("Compare Translations", systemImage: "rectangle.split.3x1")
            }
        }
    }

    /// The Hebrew (Old Testament) or Greek (New Testament) words behind the verse.
    private var wordStudyMenuButton: some View {
        let title: LocalizedStringKey = Canon.isOld(verse.bookName) ? "Hebrew Words" : "Greek Words"
        return Button { isShowingOriginalWords = true } label: {
            Label(title, systemImage: "character.book.closed")
        }
    }

    private var copyMenuButton: some View {
        Button(action: copy) {
            Label("Copy", systemImage: "doc.on.doc")
        }
    }

    private var shareMenuButton: some View {
        VerseShareMenu(verse: verse, onCreateImage: showImageComposer) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }

    private func showImageComposer() {
        imageComposerVerse = verse
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
                    translation: verse.translation,
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
                        translation: verse.translation,
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
                    text: verse.verseText,
                    translation: verse.translation
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

#if DEBUG
#Preview("Reader row") {
    VerseActionMenu(
        verse: VerseActionReference(
            bookName: "John",
            chapterNumber: 3,
            verseNumber: 16,
            verseText: "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life."
        ),
        presentation: .buttons
    )
    .padding()
    .modelContainer(for: [Favorite.self, VerseNote.self, UserNote.self, Bookmark.self], inMemory: true)
}
#endif
