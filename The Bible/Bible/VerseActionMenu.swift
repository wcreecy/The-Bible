import SwiftData
import SwiftUI
import UIKit

/// A single entry point for sharing a verse as text or as a designed image, and optionally
/// for copying it.
struct VerseShareMenu<MenuLabel: View>: View {
    let verse: VerseActionReference
    /// Adds Copy Text to the menu when set, for rows that have no separate Copy button.
    var onCopy: (() -> Void)? = nil
    let onCreateImage: () -> Void
    /// Set when the menu lives in a context menu or swipe action. Those close as soon as an
    /// item is chosen and take any sheet of their own with them, so the screen presents it.
    var onShare: ((Bool) -> Void)? = nil
    @ViewBuilder let label: () -> MenuLabel

    @State private var shareRequest: AppLinkShareRequest?

    var body: some View {
        Menu {
            if let onCopy {
                Button(action: onCopy) {
                    Label("Copy Text", systemImage: "doc.on.doc")
                }
            }

            Button(action: { shareVerse(includingAppLink: false) }) {
                // Named for what's sent, so it reads clearly beside the link version.
                Label("Share Text", systemImage: "text.quote")
            }

            Button {
                onCreateImage()
            } label: {
                Label("Create Verse Image", systemImage: "photo.on.rectangle.angled")
            }

            Divider()
                .overlay(Color.primary.opacity(0.75))

            Button(action: { shareVerse(includingAppLink: true) }) {
                Label("Share Text with App Link", systemImage: "link")
            }

        } label: {
            label()
        }
        .accessibilityIdentifier("verseShareMenu-\(verse.bookName)-\(verse.chapterNumber)-\(verse.verseNumber)")
        .menuOrder(.fixed)
        .sheet(item: $shareRequest) { request in
            ActivityShareSheet(items: request.activityItems)
        }
    }

    private func shareVerse(includingAppLink: Bool) {
        if let onShare {
            onShare(includingAppLink)
        } else {
            shareRequest = AppLinkShareRequest(
                text: verse.shareText,
                includesAppLink: includingAppLink
            )
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
    /// Adds Chapter Insights to the Focus Mode menu.
    var onShowChapterInsights: (() -> Void)?
    /// Adds Scripture Connections to the menu, for a verse that has some.
    var onShowCrossReferences: (() -> Void)?
    /// Whether `.buttons` starts with the one-tap highlight colors.
    var showsHighlightColors = true

    init(
        verse: VerseActionReference,
        presentation: VerseActionPresentation = .menu,
        showsHighlightColors: Bool = true,
        onFeedback: ((VerseActionFeedback) -> Void)? = nil,
        onShowChapterInsights: (() -> Void)? = nil,
        onShowCrossReferences: (() -> Void)? = nil
    ) {
        self.verse = verse
        self.presentation = presentation
        self.showsHighlightColors = showsHighlightColors
        self.onFeedback = onFeedback
        self.onShowChapterInsights = onShowChapterInsights
        self.onShowCrossReferences = onShowCrossReferences

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
            showsHighlightColors: showsHighlightColors,
            onFeedback: onFeedback,
            onShowChapterInsights: onShowChapterInsights,
            onShowCrossReferences: onShowCrossReferences
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
    @State private var shareRequest: AppLinkShareRequest?
    @State private var isShowingCompare = false
    @State private var isShowingOriginalWords = false

    let verse: VerseActionReference
    let saved: SavedVerseCollections
    var presentation: VerseActionPresentation = .menu
    /// Whether `.buttons` starts with the one-tap highlight colors.
    var showsHighlightColors = true
    var onFeedback: ((VerseActionFeedback) -> Void)?
    var onShowChapterInsights: (() -> Void)?
    var onShowCrossReferences: (() -> Void)?

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
            .sheet(isPresented: $isShowingNoteEditor) {
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
            .sheet(item: $shareRequest) { request in
                ActivityShareSheet(items: request.activityItems)
            }
    }

    @ViewBuilder
    private var actionPresentation: some View {
        switch presentation {
        case .buttons:
            // One-tap highlight colors, then the most-used actions: the three ways to keep a
            // verse and Share. The rest are in More, with text labels.
            VStack(spacing: 4) {
                if showsHighlightColors {
                    highlightColorStrip
                }

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
                            .foregroundStyle(isBookmarked ? AnyShapeStyle(Color.bookmarkTint) : AnyShapeStyle(.primary))
                    }
                    .accessibilityLabel(bookmarkActionTitle)
                    .frame(maxWidth: .infinity)

                    // The study pages for this verse's chapter, a tap away from the row.
                    if let onShowChapterInsights {
                        Button(action: onShowChapterInsights) {
                            Image(systemName: "lightbulb")
                        }
                        .accessibilityLabel("Chapter Insights")
                        .frame(maxWidth: .infinity)
                    }

                    if let onShowCrossReferences {
                        Button(action: onShowCrossReferences) {
                            Image(systemName: "arrow.triangle.branch")
                        }
                        .accessibilityLabel("Scripture Connections")
                        .frame(maxWidth: .infinity)
                    }

                    // Every icon in this row is primary until its action is on (a red heart, a
                    // filled bookmark), so color always means "this verse has it".
                    VerseShareMenu(verse: verse, onCopy: copy, onCreateImage: showImageComposer) {
                        Image(systemName: "square.and.arrow.up")
                            .frame(minWidth: 40, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .foregroundStyle(.primary)
                    .accessibilityLabel("Share")
                    .frame(maxWidth: .infinity)

                    Menu {
                        menuItems(omitting: [.note, .favorite, .bookmark, .copy, .share, .chapterInsights, .crossReferences])
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .frame(minWidth: 40, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .foregroundStyle(.primary)
                    .accessibilityLabel("More verse actions")
                    .frame(maxWidth: .infinity)
                }
                .font(.title3)
                .buttonStyle(VerseActionButtonStyle())
            }

        case .focus:
            // One menu keeps Focus Mode's bar to a few controls.
            Menu {
                menuItems()
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("More verse actions")
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
                    menuItems(omitting: [.favorite, .share])
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(minWidth: 40, minHeight: 44)
                        .contentShape(Rectangle())
                }
                // Tinted like the heart and Share beside it.
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel("Verse actions")
            }
            .font(.title3)
            .buttonStyle(VerseActionButtonStyle())

        case .menu:
            Menu {
                menuItems()
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
            }
            .accessibilityLabel("Verse actions")
        }
    }

    // MARK: Highlight colors

    private var currentHighlight: VerseHighlightColor? {
        existingNote.flatMap { VerseHighlightColor(rawValue: $0.highlightColor) }
    }

    /// The highlight colors, tapped to highlight the verse at once. Tapping the current color
    /// again removes it. Notes still open from the note button.
    private var highlightColorStrip: some View {
        HStack(spacing: 14) {
            ForEach(VerseHighlightColor.allCases) { color in
                let isSelected = currentHighlight == color
                Button {
                    setHighlight(isSelected ? nil : color)
                } label: {
                    Circle()
                        .fill(color.color.opacity(0.75))
                        .frame(width: 26, height: 26)
                        .overlay {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .overlay(Circle().strokeBorder(.primary.opacity(isSelected ? 0.5 : 0.15), lineWidth: 1))
                        .frame(minWidth: 40, minHeight: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .hoverEffect(.lift)
                // Resting the Apple Pencil on a color shows it on the verse before it's applied.
                .onHover { isHovering in
                    if isHovering {
                        HighlightPreview.shared.show(
                            color.color,
                            bookName: verse.bookName,
                            chapterNumber: verse.chapterNumber,
                            verseNumber: verse.verseNumber
                        )
                    } else {
                        HighlightPreview.shared.clear()
                    }
                }
                .accessibilityLabel(Text("Highlight \(Text(color.name))"))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityHint(isSelected ? "Removes the highlight" : "")
            }
        }
        .frame(maxWidth: .infinity)
        .onDisappear { HighlightPreview.shared.clear() }
    }

    /// Highlights the verse in `color`, or removes its highlight when `color` is nil. The
    /// highlight lives on the verse's note, as it does from the note editor: a new verse gets
    /// a highlight-only note, and removing the highlight from one deletes it.
    private func setHighlight(_ color: VerseHighlightColor?) {
        let note = existingNote
        let addsHighlight = color != nil && (note?.highlightColor.isEmpty ?? true)

        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                if let note {
                    if color == nil && !Self.hasWrittenText(note) {
                        modelContext.delete(note)
                    } else {
                        note.highlightColor = color?.rawValue ?? ""
                        note.updatedAt = Date()
                    }
                } else if let color {
                    let newNote = VerseNote(
                        bookName: verse.bookName,
                        chapterNumber: verse.chapterNumber,
                        verseNumber: verse.verseNumber,
                        verseText: verse.verseText,
                        highlightColor: color.rawValue
                    )
                    newNote.translation = verse.translation.rawValue
                    modelContext.insert(newNote)
                } else {
                    return
                }
                try modelContext.save()
            },
            onSuccess: {
                if addsHighlight {
                    TodayChallengeStore.shared.recordVerseHighlightSaved()
                }
                Haptics.selection()
            },
            onFailure: { persistenceFailure = $0 }
        )
    }

    /// Whether a note has writing of its own, beyond the highlight and the verse reference.
    private static func hasWrittenText(_ note: VerseNote) -> Bool {
        let title = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = note.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return !title.isEmpty || (!content.isEmpty && content != note.reference)
    }

    // MARK: Shared action titles and menu items

    /// Actions that some presentations show as buttons beside the menu instead of in it.
    nonisolated enum InlineAction: Hashable {
        case note, favorite, bookmark, copy, share, chapterInsights, crossReferences
    }

    /// Every verse action, in the one order all verse menus share: keeping the verse, sharing
    /// it, studying it, then the widget. Actions already shown as buttons are left out.
    @ViewBuilder
    private func menuItems(omitting shown: Set<InlineAction> = []) -> some View {
        Section {
            if !shown.contains(.note) { noteMenuButton }
            if !shown.contains(.favorite) { favoriteMenuButton }
            if !shown.contains(.bookmark) { bookmarkMenuButton }
        }
        Section {
            if !shown.contains(.copy) { copyMenuButton }
            if !shown.contains(.share) { shareMenuButton }
        }
        Section {
            compareMenuButton
            wordStudyMenuButton
            mentionsButton
            if let onShowChapterInsights, !shown.contains(.chapterInsights) {
                Button(action: onShowChapterInsights) {
                    Label("Chapter Insights", systemImage: "lightbulb")
                }
            }
            if let onShowCrossReferences, !shown.contains(.crossReferences) {
                Button(action: onShowCrossReferences) {
                    Label("Scripture Connections", systemImage: "arrow.triangle.branch")
                }
            }
        }
        Section {
            pinMenuButton
        }
    }

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
        isPinned ? "Remove from Widget" : "Show on Widget"
    }

    private var noteMenuButton: some View {
        Button {
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
            Label(pinActionTitle, systemImage: isPinned ? "rectangle.slash" : "widget.small")
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

    /// Shown inside another menu, so the share sheet is presented from here instead.
    private var shareMenuButton: some View {
        VerseShareMenu(verse: verse, onCreateImage: showImageComposer, onShare: { includingAppLink in
            shareRequest = AppLinkShareRequest(
                text: verse.shareText,
                includesAppLink: includingAppLink
            )
        }) {
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
