import SwiftUI
import SwiftData
import UIKit
import WidgetKit

@MainActor
struct ReadingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [Favorite]
    @Query private var verseNotes: [VerseNote]
    @Query private var bookmarks: [Bookmark]
    @Environment(\.scenePhase) private var scenePhase

    let book: Book
    let chapter: Chapter
    let startVerse: Int
    let onSearch: (() -> Void)?
    /// Called with the book currently shown, which can differ from `book` after swiping chapters.
    let onNavigateBack: ((Book) -> Void)?
    let onBookSelected: ((Book) -> Void)?

    // View model and stores
    @State private var pinnedStore: PinnedVerseStore
    @State private var viewModel: ReadingViewModel

    // Reader-specific font size (independent from global app UI font)
    @AppStorage("readerFontSize") private var readerFontSize: Double = 17
    @AppStorage(ReaderDisplaySettings.showsVerseMarkersKey) private var showsVerseMarkers: Bool = true
    @AppStorage(ReaderDisplaySettings.showsBookmarkMarkersKey) private var showsBookmarkMarkers: Bool = true
    @AppStorage(ReaderDisplaySettings.showsFavoriteMarkersKey) private var showsFavoriteMarkers: Bool = true
    @AppStorage(ReaderDisplaySettings.showsNoteMarkersKey) private var showsNoteMarkers: Bool = true
    @AppStorage(ReaderDisplaySettings.showsCrossReferenceMarkersKey) private var showsCrossReferenceMarkers: Bool = true
    // Older versions used this key for every status icon; it now controls read progress only.
    @AppStorage(ReaderDisplaySettings.showsReadProgressKey) private var showsReadProgress: Bool = false
    /// The verse whose note is open from its note marker.
    @State private var noteEditorVerse: Verse?
    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false
    @AppStorage("focusReadingEnabled") private var focusReadingEnabled = false
    @State private var isFocusModePresented = false
    // The Focus Reading setting opens Focus Mode once per visit, not every time the
    // reader reappears (for example after Focus Mode is dismissed).
    @State private var didAutoPresentFocusMode = false
    @State private var isChapterInsightsPresented = false
    @State private var chapterRelatedVerses: [ChapterRelatedVerse] = []
    @State private var crossReferenceVerse: Verse?
    @State private var seenVerseNumbers: Set<Int> = []
    @State private var seenVerseLocation: String = ""

    // Observe app-group "last read" to render bookmark icon state live

    // Toast state
    @State private var showFavoriteToast: Bool = false
    @State private var favoriteToastText: String = "Added to Favorites"
    @State private var favoriteToastSymbol: String = "heart.fill"
    @State private var favoriteToastTint: Color = .pink
    @State private var persistenceFailure: PersistenceFailure?
    @State private var isBookPickerPresented = false

    init(
        book: Book,
        chapter: Chapter,
        startVerse: Int,
        onSearch: (() -> Void)? = nil,
        onNavigateBack: ((Book) -> Void)? = nil,
        onBookSelected: ((Book) -> Void)? = nil
    ) {
        self.book = book
        self.chapter = chapter
        self.startVerse = startVerse
        self.onSearch = onSearch
        self.onNavigateBack = onNavigateBack
        self.onBookSelected = onBookSelected

        // Create a single pinned store instance and share it with the view model
        let pinned = PinnedVerseStore()
        _pinnedStore = State(initialValue: pinned)
        _viewModel = State(initialValue: ReadingViewModel(
            book: book,
            chapter: chapter,
            startVerse: startVerse,
            pinnedStore: pinned,
            inactivitySeconds: 300
        ))
    }

    private var currentChapter: Chapter { viewModel.currentChapter }

    var body: some View {
        content
            .environment(\.font, nil)
            .navigationTitle("\(viewModel.currentBook.name) \(viewModel.currentChapter.number)")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(onNavigateBack != nil)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    if let onNavigateBack {
                        Button {
                            onNavigateBack(viewModel.currentBook)
                        } label: {
                            Image(systemName: "chevron.backward")
                        }
                        .accessibilityLabel("Back to chapters")
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        if let onSearch {
                            onSearch()
                        } else {
                            AppRouter.shared.open(.bibleSearch)
                        }
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Search Bible")

                    Menu {
                        Button {
                            readerFontSize = max(12, readerFontSize - 1)
                        } label: {
                            Label("Decrease Text Size", systemImage: "textformat.size.smaller")
                        }

                        Button {
                            readerFontSize = min(30, readerFontSize + 1)
                        } label: {
                            Label("Increase Text Size", systemImage: "textformat.size.larger")
                        }

                        if readerFontSize != 17 {
                            Button("Reset Text Size") {
                                readerFontSize = 17
                            }
                        }

                        Divider()

                        Button {
                            presentFocusMode()
                        } label: {
                            Label("Enter Focus Mode", systemImage: "arrow.up.left.and.arrow.down.right")
                        }

                        Divider()

                        Button {
                            isChapterInsightsPresented = true
                        } label: {
                            Label("Chapter Insights", systemImage: "lightbulb")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Reader Options")
                    .accessibilityHint("Adjust text size or enter Focus Mode")
                }

                ToolbarItem(placement: .principal) {
                    Button {
                        let h = UIImpactFeedbackGenerator(style: .light)
                        h.impactOccurred()
                        isBookPickerPresented = true
                    } label: {
                        Text("\(viewModel.currentBook.name) \(viewModel.currentChapter.number)")
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Choose a book")
                    .accessibilityHint("Shows the list of Bible books")
                }
            }
            .sheet(isPresented: $isBookPickerPresented) {
                NavigationStack {
                    List(BibleData.books) { book in
                        Button(book.name) {
                            isBookPickerPresented = false
                            onBookSelected?(book)
                        }
                        .foregroundStyle(.primary)
                    }
                    .navigationTitle("Choose a Book")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                isBookPickerPresented = false
                            }
                        }
                    }
                }
            }
            .onAppear {
                viewModel.onAppear()
                if focusReadingEnabled && !didAutoPresentFocusMode {
                    didAutoPresentFocusMode = true
                    presentFocusMode()
                }
                saveReaderPosition(verseNumber: viewModel.currentVerse)
                refreshSeenVerses()
            }
            .onDisappear {
                saveVisibleReaderPosition()
                ReadingPositionStore.shared.flush()
                viewModel.onDisappear()
            }
            .onChange(of: startVerse) { _, verseNumber in
                viewModel.show(location: FocusVerseLocation(
                    bookName: book.name,
                    chapterNumber: chapter.number,
                    verseNumber: verseNumber
                ))
            }
            .onChange(of: showsReadProgress) { _, isEnabled in
                if isEnabled {
                    refreshSeenVerses()
                }
            }
            .onNotification(.bibleStatsExternallyUpdated) {
                refreshSeenVerses()
            }
            .onChange(of: scenePhase) { _, newPhase in
                viewModel.onScenePhaseChanged(newPhase)

                if newPhase == .inactive || newPhase == .background {
                    saveVisibleReaderPosition()
                    ReadingPositionStore.shared.flush()
                }

                // Fallback nudge on app activation (device B):
                // Ensure latest KVS values are pulled locally, then reload the Last Read widget timeline.
                if newPhase == .active {
                    NSUbiquitousKeyValueStore.default.synchronize()
                    DebouncedWidgetReloader.shared.reload(kind: "LastReadWidget")
                }
            }
            // Pause reading tracking when the app is sent to another tab.
            .onChange(of: AppRouter.shared.latest) { _, request in
                if let tab = request?.destination.targetTab {
                    viewModel.onTabChanged(tab.rawValue)
                }
            }
            .appToast(
                isPresented: $showFavoriteToast,
                symbol: favoriteToastSymbol,
                text: favoriteToastText,
                tint: favoriteToastTint
            )
            .persistenceFailureAlert(failure: $persistenceFailure)
            .onChange(of: isFocusModePresented) { _, isPresented in
                viewModel.setFocusModeActive(isPresented)
            }
            .fullScreenCover(isPresented: $isFocusModePresented) {
                FocusReadingView(
                    initialLocation: FocusVerseLocation(
                        bookName: viewModel.currentBook.name,
                        chapterNumber: viewModel.currentChapter.number,
                        verseNumber: viewModel.currentVerse
                    ),
                    readerFontSize: readerFontSize,
                    onLocationChange: { location in
                        viewModel.noteFocusLocation(location)
                        ReadingPositionStore.shared.record(
                            bookName: location.bookName,
                            chapter: location.chapterNumber,
                            verse: location.verseNumber
                        )
                    },
                    onVisibleVerseChange: { location in
                        viewModel.focusVisibleVerseChanged(location)
                    },
                    onExit: {
                        isFocusModePresented = false
                    }
                )
            }
            .sheet(item: $noteEditorVerse) { verse in
                // Opened from a verse's note marker; same editor as the verse menu.
                NavigationStack {
                    VerseNoteEditorView(
                        verse: VerseActionReference(
                            bookName: viewModel.currentBook.name,
                            chapterNumber: viewModel.currentChapter.number,
                            verseNumber: verse.number,
                            verseText: verse.text
                        ),
                        existingNote: note(for: verse.number)
                    )
                }
            }
            .sheet(isPresented: $isChapterInsightsPresented) {
                NavigationStack {
                    ChapterInsightsView(
                        bookName: viewModel.currentBook.name,
                        chapterNumber: viewModel.currentChapter.number,
                        openedFromReader: true
                    )
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                isChapterInsightsPresented = false
                            }
                        }
                    }
                }
                .environment(\.closeStudySheet) { isChapterInsightsPresented = false }
            }
            .sheet(item: $crossReferenceVerse) { verse in
                NavigationStack {
                    ChapterCrossReferencesView(
                        bookName: viewModel.currentBook.name,
                        chapterNumber: viewModel.currentChapter.number,
                        relatedVerses: chapterRelatedVerses.filter { $0.sourceVerse == verse.number }
                    )
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                crossReferenceVerse = nil
                            }
                        }

                        ToolbarItem(placement: .primaryAction) {
                            NavigationLink("All") {
                                ChapterCrossReferencesView(
                                    bookName: viewModel.currentBook.name,
                                    chapterNumber: viewModel.currentChapter.number,
                                    relatedVerses: chapterRelatedVerses
                                )
                            }
                        }
                    }
                }
            }
            .task(id: "\(viewModel.currentBook.name)-\(viewModel.currentChapter.number)") {
                chapterRelatedVerses = []
                let insights = await ChapterInsightsRepository.shared.insights(
                    forBookNamed: viewModel.currentBook.name,
                    chapterNumber: viewModel.currentChapter.number
                )
                guard !Task.isCancelled else { return }
                chapterRelatedVerses = insights?.relatedVerses ?? []
            }
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if contextualTipsEnabled {
                        ContextualTipView(
                            id: "reader.shortcuts",
                            title: "Reader shortcuts",
                            message: "Swipe left or right to change chapters. Press and hold a verse for notes, highlights, favorites, and more.",
                            systemImage: "hand.draw"
                        )
                        .padding(.bottom, 12)

                        ContextualTipView(
                            id: "reader.statusIcons",
                            title: "Understand verse icons",
                            message: "Icons beside a verse's reference show your bookmark, favorites, notes, and cross-references. Tap a note or cross-reference icon to open it. Change this in Settings › Bible Reader.",
                            systemImage: "info.circle"
                        )
                        .padding(.bottom, 12)

                        Divider()
                    }

                    ForEach(currentChapter.verses) { verse in
                        let bookName = viewModel.currentBook.name
                        let chapterNumber = viewModel.currentChapter.number
                        let readUpdate = SeenVerseUpdate(
                            bookName: bookName,
                            chapter: chapterNumber,
                            verse: verse.number,
                            totalVerses: currentChapter.verses.count
                        )

                        ReadingVerseRow(
                            verse: verse,
                            bookName: bookName,
                            chapterNumber: chapterNumber,
                            isHighlighted: viewModel.highlightedVerse == verse.number,
                            isSelected: viewModel.selectedVerse == verse.number,
                            isFavorite: isFavorited(verse),
                            hasNote: hasNote(for: verse.number),
                            isPinned: isBookmarked(verse),
                            hasCrossReferences: chapterRelatedVerses.contains { $0.sourceVerse == verse.number },
                            isRead: showsReadProgress &&
                                seenVerseLocation == verseLocationKey &&
                                seenVerseNumbers.contains(verse.number),
                            showsMarkers: showsVerseMarkers,
                            showsBookmarkMarker: showsBookmarkMarkers,
                            showsFavoriteMarker: showsFavoriteMarkers,
                            showsNoteMarker: showsNoteMarkers,
                            showsCrossReferenceMarker: showsCrossReferenceMarkers,
                            showsReadProgress: showsReadProgress,
                            savedHighlightColor: highlightColor(for: verse.number),
                            readerFontSize: readerFontSize,
                            onVisibilityChange: { isVisible in
                                viewModel.verseVisibilityChanged(readUpdate, isVisible: isVisible)
                            },
                            onTap: { v in
                                let generator = UISelectionFeedbackGenerator()
                                generator.selectionChanged()
                                viewModel.clearMenuIfNeeded()
                                // Tap now only highlights/selects (no bookmarking)
                                viewModel.handleVerseTap(context: modelContext, verse: v)
                            },
                            onLongPress: { number in
                                let generator = UIImpactFeedbackGenerator(style: .heavy)
                                generator.impactOccurred()
                                viewModel.handleVerseLongPress(verseNumber: number)
                            },
                            onOpenNote: {
                                noteEditorVerse = verse
                            },
                            onOpenCrossReferences: {
                                crossReferenceVerse = verse
                            }
                        )
                        .id(viewModel.rowID(for: verse.number))
                        .animation(.easeInOut(duration: 0.6), value: viewModel.highlightedVerse)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedVerse)

                        if viewModel.menuVerse == verse.number {
                            verseMenu(for: verse, bookName: bookName, chapterNumber: chapterNumber)
                                .transition(.opacity)
                        }

                        if verse.number != currentChapter.verses.count {
                            Divider()
                        }
                    }
                }
                .padding(AppDesignMetrics.cardPadding)
                .heroCardSurface()
                .padding(.horizontal, 16)
                .padding(.vertical)
                .scrollTargetLayout()
                .onChange(of: viewModel.currentChapterIndex) { _, _ in
                    refreshSeenVerses()
                }
                .onChange(of: viewModel.currentBook.name) { _, _ in
                    refreshSeenVerses()
                }
                .onAppear {
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            viewModel.topVisibleVerseID = viewModel.rowID(for: viewModel.currentVerse)
                        }
                    }
                    viewModel.markActivity()
                }
                .onTapGesture {
                    if viewModel.menuVerse != nil { viewModel.menuVerse = nil }
                    viewModel.markActivity()
                }
            }
            .scrollPosition(id: $viewModel.topVisibleVerseID, anchor: .top)
            .onChange(of: viewModel.topVisibleVerseID) { _, _ in
                saveVisibleReaderPosition()
            }

            // Bottom corner navigation arrows overlay
            overlayArrows
        }
        .background(AppBackgroundView(tab: .bible))
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 5, coordinateSpace: .local)
                .onChanged { _ in
                    ReadingTimeTracker.shared.resume()
                    viewModel.markActivity()
                }
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = value.translation.height
                    if abs(horizontal) > abs(vertical) && abs(horizontal) > 40 {
                        if horizontal < 0 {
                            viewModel.nextChapter()
                        } else {
                            viewModel.previousChapter()
                        }
                    }
                    viewModel.markActivity()
                }
        )
    }

    /// Hands read tracking to Focus Mode before its cover hides the reader's rows.
    private func presentFocusMode() {
        viewModel.setFocusModeActive(true)
        isFocusModePresented = true
    }

    private var verseLocationKey: String {
        "\(viewModel.currentBook.name):\(viewModel.currentChapter.number)"
    }

    private func saveVisibleReaderPosition() {
        guard let visibleID = viewModel.topVisibleVerseID,
              let verse = currentChapter.verses.first(where: {
                  viewModel.rowID(for: $0.number) == visibleID
              }) else {
            saveReaderPosition(verseNumber: viewModel.currentVerse)
            return
        }

        saveReaderPosition(verseNumber: verse.number)
    }

    private func saveReaderPosition(verseNumber: Int) {
        ReadingPositionStore.shared.record(
            bookName: viewModel.currentBook.name,
            chapter: viewModel.currentChapter.number,
            verse: verseNumber
        )
    }

    private func refreshSeenVerses() {
        guard showsReadProgress else { return }
        let bookName = viewModel.currentBook.name
        let chapterNumber = viewModel.currentChapter.number
        seenVerseNumbers = BibleStatsStore.shared.loadSeenVerses(
            bookName: bookName,
            chapter: chapterNumber
        )
        seenVerseLocation = "\(bookName):\(chapterNumber)"
    }

    /// A highlight on a single verse wins over one spanning several verses.
    private func highlightColor(for verseNumber: Int) -> Color? {
        notes(covering: verseNumber)
            .first { !$0.highlightColor.isEmpty }
            .flatMap { VerseHighlightColor(rawValue: $0.highlightColor)?.color }
    }

    /// The note to edit from this verse: one starting here, else one spanning it.
    private func note(for verseNumber: Int) -> VerseNote? {
        notes(covering: verseNumber).first
    }

    /// Notes covering the verse, those starting at it first, then the shortest span.
    private func notes(covering verseNumber: Int) -> [VerseNote] {
        verseNotes
            .filter {
                $0.covers(
                    bookName: viewModel.currentBook.name,
                    chapterNumber: viewModel.currentChapter.number,
                    verseNumber: verseNumber
                )
            }
            .sorted {
                ($0.verseNumber == verseNumber ? 0 : 1, $0.lastVerseNumber - $0.verseNumber) <
                    ($1.verseNumber == verseNumber ? 0 : 1, $1.lastVerseNumber - $1.verseNumber)
            }
    }

    private func hasNote(for verseNumber: Int) -> Bool {
        notes(covering: verseNumber).contains {
            let title = $0.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let content = $0.content.trimmingCharacters(in: .whitespacesAndNewlines)
            let seededReference = $0.reference
            return !title.isEmpty || (!content.isEmpty && content != seededReference)
        }
    }

    private func isBookmarked(_ verse: Verse) -> Bool {
        bookmarks.contains {
            $0.bookName == viewModel.currentBook.name &&
            $0.chapterNumber == viewModel.currentChapter.number &&
            $0.verseNumber == verse.number
        }
    }

    // MARK: - Overlay Arrows

    private var overlayArrows: some View {
        // Small, semi-transparent chevrons in bottom-left and bottom-right.
        // Use padding to respect safe area and provide a larger hit target.
        ZStack {
            VStack {
                Spacer()
                HStack {
                    Button(action: {
                        viewModel.previousChapter()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)
                            .padding(10) // hit target
                            .background(.ultraThinMaterial, in: Circle())
                            .opacity(0.7)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Previous chapter")
                    .padding(.leading, 12)

                    Spacer()

                    Button(action: {
                        viewModel.nextChapter()
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)
                            .padding(10) // hit target
                            .background(.ultraThinMaterial, in: Circle())
                            .opacity(0.7)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Next chapter")
                    .padding(.trailing, 12)
                }
                .padding(.bottom, 10)
            }
        }
        .allowsHitTesting(true)
    }

    // Extracted to reduce type-checking complexity
    @ViewBuilder
    private func verseMenu(for verse: Verse, bookName: String, chapterNumber: Int) -> some View {
        VerseActionMenu(
            verse: VerseActionReference(
                bookName: bookName,
                chapterNumber: chapterNumber,
                verseNumber: verse.number,
                verseText: verse.text
            ),
            presentation: .buttons,
            onFeedback: handleVerseActionFeedback
        )
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.bottom, 6)
    }

    private func handleVerseActionFeedback(_ feedback: VerseActionFeedback) {
        favoriteToastSymbol = feedback.toastSymbol
        favoriteToastTint = feedback.toastTint
        favoriteToastText = feedback.toastText

        withAnimation(.spring()) {
            showFavoriteToast = true
            viewModel.menuVerse = nil
        }
        viewModel.markActivity()
    }

    // MARK: - Favorites

    private func isFavorited(_ verse: Verse) -> Bool {
        favorites.contains { fav in
            fav.bookName == viewModel.currentBook.name &&
            fav.chapterNumber == viewModel.currentChapter.number &&
            fav.verseNumber == verse.number
        }
    }
}
