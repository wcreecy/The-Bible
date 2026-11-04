import SwiftUI
import SwiftData
import UIKit
import WidgetKit

@MainActor
struct ReadingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    let book: Book
    let chapter: Chapter
    let startVerse: Int
    let onSearch: (() -> Void)?
    /// Called with the book currently shown, which can differ from `book` after swiping chapters.
    let onNavigateBack: ((Book) -> Void)?
    let onBookSelected: ((Book) -> Void)?
    /// Opens a typed chapter or verse from the book picker.
    let onReferenceSelected: ((Book, Chapter, Int) -> Void)?

    // View model and stores
    @State private var pinnedStore: PinnedVerseStore
    @State private var viewModel: ReadingViewModel

    // Reader-specific font size (independent from global app UI font)
    @AppStorage(AppStorageKey.readerFontSize) private var readerFontSize: Double = 17
    // Older versions used this key for every status icon; it now controls read progress only.
    @AppStorage(ReaderDisplaySettings.showsReadProgressKey) private var showsReadProgress: Bool = false
    /// The verse whose note is open from its note marker.
    @State private var noteEditorVerse: Verse?
    @AppStorage(AppStorageKey.contextualTipsEnabled) private var contextualTipsEnabled = false
    @AppStorage(AppStorageKey.focusReadingEnabled) private var focusReadingEnabled = false
    @State private var isFocusModePresented = false
    // The Focus Reading setting opens Focus Mode once per visit, not every time the
    // reader reappears (for example after Focus Mode is dismissed).
    @State private var didAutoPresentFocusMode = false
    @State private var chapterInsightsDismissal = StudySheetDismissal()
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
    @State private var bookPickerSearchText = ""
    @State private var isDisplayOptionsPresented = false
    @AppStorage(AppStorageKey.readerShowsFullReferences) private var showsFullReferences = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// False until the reader has scrolled to the verse it was opened at, so the chapter's first
    /// verses aren't shown for a moment before it jumps there.
    @State private var isInitialPositionReady: Bool
    /// Plays the slide-in of a new chapter; the direction follows the swipe.
    @State private var chapterSlideTrigger = 0
    @State private var chapterSlideDirection: CGFloat = 1
    /// The floating chapter arrows step aside while the text is moving. Only the arrows read
    /// it, so the start and end of each scroll don't redraw the whole reader.
    @State private var scrollActivity = ReaderScrollActivity()

    init(
        book: Book,
        chapter: Chapter,
        startVerse: Int,
        onSearch: (() -> Void)? = nil,
        onNavigateBack: ((Book) -> Void)? = nil,
        onBookSelected: ((Book) -> Void)? = nil,
        onReferenceSelected: ((Book, Chapter, Int) -> Void)? = nil
    ) {
        self.book = book
        self.chapter = chapter
        self.startVerse = startVerse
        self.onSearch = onSearch
        self.onNavigateBack = onNavigateBack
        self.onBookSelected = onBookSelected
        self.onReferenceSelected = onReferenceSelected

        // Create a single pinned store instance and share it with the view model
        let pinned = PinnedVerseStore.shared
        _pinnedStore = State(initialValue: pinned)
        _isInitialPositionReady = State(initialValue: startVerse <= 1)
        _viewModel = State(initialValue: ReadingViewModel(
            book: book,
            chapter: chapter,
            startVerse: startVerse,
            pinnedStore: pinned,
            inactivitySeconds: 300
        ))
    }

    private var currentChapter: Chapter { viewModel.currentChapter }

    private var displayOptions: some View {
        ReaderDisplayOptions(
            fontSize: $readerFontSize,
            showsFullReferences: $showsFullReferences
        )
    }

    private var searchButton: some View {
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
    }

    var body: some View {
        @Bindable var chapterInsightsDismissal = chapterInsightsDismissal

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

                    if UIDevice.current.userInterfaceIdiom == .phone {
                        searchButton
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    if UIDevice.current.userInterfaceIdiom != .phone {
                        searchButton
                    }

                    if UIDevice.current.userInterfaceIdiom != .phone {
                        Button {
                            chapterInsightsDismissal.isPresented = true
                        } label: {
                            Image(systemName: "lightbulb")
                        }
                        .accessibilityLabel("Study this chapter")
                        .accessibilityHint("Opens insights for \(viewModel.currentBook.name) \(viewModel.currentChapter.number)")
                    }

                    // On iPhone these two live in the "…" menu, to keep the toolbar uncrowded.
                    if UIDevice.current.userInterfaceIdiom != .phone {
                        TranslationToolbarMenu()

                        Button {
                            isDisplayOptionsPresented = true
                        } label: {
                            Image(systemName: "textformat.size")
                        }
                        .accessibilityLabel("Text Size and Display")
                        .popover(isPresented: $isDisplayOptionsPresented) {
                            displayOptions
                        }
                    }

                    Menu {
                        Button {
                            presentFocusMode()
                        } label: {
                            Label("Enter Focus Mode", systemImage: "arrow.up.left.and.arrow.down.right")
                        }

                        if UIDevice.current.userInterfaceIdiom == .phone {
                            Button {
                                isDisplayOptionsPresented = true
                            } label: {
                                Label("Text Size & Display", systemImage: "textformat.size")
                            }

                            TranslationMenuSection()

                            Divider()

                            Button {
                                chapterInsightsDismissal.isPresented = true
                            } label: {
                                Label("Chapter Insights", systemImage: "lightbulb")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    // The iPad has its own text size button with this popover.
                    .popover(isPresented: UIDevice.current.userInterfaceIdiom == .phone ? $isDisplayOptionsPresented : .constant(false)) {
                        displayOptions
                    }
                    .accessibilityLabel("Reader Options")
                    .accessibilityHint("Enter Focus Mode, change text size or translation, or open chapter insights")
                }

                ToolbarItem(placement: .principal) {
                    Button {
                        let h = UIImpactFeedbackGenerator(style: .light)
                        h.impactOccurred()
                        isBookPickerPresented = true
                    } label: {
                        VStack(spacing: 0) {
                            HStack(spacing: 4) {
                                Text("\(viewModel.currentBook.name) \(viewModel.currentChapter.number)")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                // Shows that the title opens the book picker.
                                Image(systemName: "chevron.down")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                            }

                            // The translation picker is in the "…" menu on iPhone, so name it here.
                            if UIDevice.current.userInterfaceIdiom == .phone {
                                Text(BibleStore.shared.translation.abbreviation)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Choose a book")
                    .accessibilityHint("Shows the list of Bible books")
                }
            }
            .sheet(isPresented: $isBookPickerPresented) { bookPickerSheet }
            .onAppear {
                viewModel.onAppear()
                if focusReadingEnabled && !didAutoPresentFocusMode {
                    didAutoPresentFocusMode = true
                    presentFocusMode()
                }
                saveReaderPosition(verseNumber: viewModel.currentVerse)
                refreshSeenVerses()
            }
            .task(id: "\(book.name)-\(chapter.number)-\(startVerse)") {
                // Install the initial target only after the reader receives its final width.
                // Setting a scroll position during the navigation transition can otherwise
                // preserve the transition's temporary horizontal geometry.
                await Task.yield()
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                viewModel.positionInitialVerse()

                await Task.yield()
                guard !Task.isCancelled else { return }
                viewModel.showInitialHighlight()

                // Give the scroll a moment to land before the text is shown.
                try? await Task.sleep(for: .milliseconds(40))
                guard !Task.isCancelled else { return }
                isInitialPositionReady = true
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
            .onChange(of: AppDataChanges.shared.bibleStats) {
                refreshSeenVerses()
            }
            .onChange(of: BibleStore.shared.translation) {
                viewModel.translationChanged()
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
            .sheet(isPresented: $chapterInsightsDismissal.isPresented) {
                NavigationStack {
                    ChapterInsightsView(
                        bookName: viewModel.currentBook.name,
                        chapterNumber: viewModel.currentChapter.number,
                        openedFromReader: true
                    )
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                            chapterInsightsDismissal.dismiss()
                            }
                        }
                    }
                }
                .environment(\.studySheetDismissal, chapterInsightsDismissal)
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

                    ReadingChapterVerseList(
                        bookName: viewModel.currentBook.name,
                        chapterNumber: viewModel.currentChapter.number,
                        viewModel: viewModel,
                        pinnedStore: pinnedStore,
                        crossReferences: chapterRelatedVerses,
                        readVerseNumbers: showsReadProgress && seenVerseLocation == verseLocationKey
                            ? seenVerseNumbers
                            : [],
                        showsReadProgress: showsReadProgress,
                        readerFontSize: readerFontSize,
                        showsFullReferences: showsFullReferences,
                        onOpenNote: { verse in noteEditorVerse = verse },
                        onOpenCrossReferences: { verse in crossReferenceVerse = verse },
                        onVerseActionFeedback: handleVerseActionFeedback
                    )

                    // The way forward at the end of a chapter, without a swipe or the small arrows.
                    if let nextTitle = viewModel.nextChapterTitle {
                        Divider()

                        Button {
                            changeChapter(forward: true)
                        } label: {
                            HStack {
                                Text("Continue to \(nextTitle)")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                            .frame(minHeight: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens the next chapter")
                    }
                }
                // Lets an opening verse menu push the text below it down smoothly.
                .animation(.easeInOut(duration: 0.2), value: viewModel.menuVerse)
                .padding(AppDesignMetrics.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .heroCardSurface()
                .padding(.horizontal, 16)
                .padding(.vertical)
                // On iPhone, pin the content to the scroll view's visible width. `scrollPosition`'s
                // `.top` anchor also targets the horizontal center, so a stale measurement during
                // a navigation transition could otherwise leave the card shifted sideways. On iPad,
                // the reader lives in a NavigationSplitView detail column; sizing relative to its
                // outer container can extend the card beneath the Books column.
                .readerCardWidth()
                .scrollTargetLayout()
                .onChange(of: viewModel.currentChapterIndex) { _, _ in
                    refreshSeenVerses()
                }
                .onChange(of: viewModel.currentBook.name) { _, _ in
                    refreshSeenVerses()
                }
                .onAppear {
                    viewModel.markActivity()
                }
                .onTapGesture {
                    if viewModel.menuVerse != nil { viewModel.menuVerse = nil }
                    viewModel.markActivity()
                }
            }
            .scrollPosition(id: $viewModel.topVisibleVerseID, anchor: .top)
            .tabBarContentClearance()
            .onScrollPhaseChange { _, phase in
                scrollActivity.isScrolling = phase != .idle
            }
            // A new chapter slides in from the side it was swiped toward.
            .keyframeAnimator(initialValue: ChapterSlide(), trigger: chapterSlideTrigger) { view, slide in
                view
                    .offset(x: slide.offset)
                    .opacity(slide.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.offset) {
                    LinearKeyframe(reduceMotion ? 0 : 36 * chapterSlideDirection, duration: 0.01)
                    CubicKeyframe(0, duration: 0.25)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0, duration: 0.01)
                    CubicKeyframe(1, duration: 0.25)
                }
            }
            // Hidden only while a verse deep in the chapter is being scrolled to.
            .opacity(isInitialPositionReady ? 1 : 0)
            .animation(.easeOut(duration: 0.15), value: isInitialPositionReady)

            // Bottom corner navigation arrows overlay
            ReaderChapterArrows(
                scrollActivity: scrollActivity,
                onPrevious: { changeChapter(forward: false) },
                onNext: { changeChapter(forward: true) }
            )
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
                    // A clearly sideways swipe; a diagonal scroll shouldn't change chapters.
                    if abs(horizontal) > 80 && abs(horizontal) > abs(vertical) * 2 {
                        changeChapter(forward: horizontal < 0)
                    }
                    viewModel.markActivity()
                }
        )
    }

    private var bookPickerSheet: some View {
        NavigationStack {
            List {
                if let reference = bookPickerReference {
                    Section {
                        Button {
                            open(reference: reference)
                        } label: {
                            Label("Go to \(reference.reference.formattedReference)", systemImage: "arrow.right.circle.fill")
                        }
                    }
                }

                Section {
                    ForEach(filteredBooksForPicker) { book in
                        Button(book.name) {
                            open(book: book)
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .searchable(text: $bookPickerSearchText, prompt: "Book or reference")
            .onSubmit(of: .search) {
                if let reference = bookPickerReference {
                    open(reference: reference)
                }
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

    private var bookPickerReference: (reference: ScriptureRef, book: Book, chapter: Chapter)? {
        BibleNavigationReference.resolve(bookPickerSearchText, in: BibleData.books)
    }

    private var filteredBooksForPicker: [Book] {
        let query = bookPickerSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return BibleData.books }
        if let reference = bookPickerReference { return [reference.book] }

        let names = BibleBookNameMatcher.suggestions(for: query, in: BibleData.books.map(\.name))
        return names.compactMap { name in BibleData.books.first(where: { $0.name == name }) }
    }

    private func open(book: Book) {
        isBookPickerPresented = false
        bookPickerSearchText = ""
        onBookSelected?(book)
    }

    private func open(reference: (reference: ScriptureRef, book: Book, chapter: Chapter)) {
        isBookPickerPresented = false
        bookPickerSearchText = ""
        onReferenceSelected?(reference.book, reference.chapter, reference.reference.startVerse)
    }

    /// Moves to the next or previous chapter, sliding the new one in from that side. Nothing
    /// slides when there is no chapter that way (the first or last of the Bible).
    private func changeChapter(forward: Bool) {
        let book = viewModel.currentBook.name
        let chapterIndex = viewModel.currentChapterIndex

        if forward {
            viewModel.nextChapter()
        } else {
            viewModel.previousChapter()
        }

        guard viewModel.currentBook.name != book || viewModel.currentChapterIndex != chapterIndex else { return }
        chapterSlideDirection = forward ? 1 : -1
        chapterSlideTrigger += 1
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
        viewModel.saveVisiblePosition()
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

    /// The editor needs the existing note for the selected verse only, so it fetches just this
    /// chapter's notes when the editor opens rather than keeping every note queried.
    private func note(for verseNumber: Int) -> VerseNote? {
        let bookName = viewModel.currentBook.name
        let chapterNumber = viewModel.currentChapter.number
        let descriptor = FetchDescriptor<VerseNote>(predicate: #Predicate {
            $0.bookName == bookName && $0.chapterNumber == chapterNumber
        })
        let chapterNotes = (try? modelContext.fetch(descriptor)) ?? []
        return chapterNotes
            .filter { $0.covers(bookName: bookName, chapterNumber: chapterNumber, verseNumber: verseNumber) }
            .sorted {
                ($0.verseNumber == verseNumber ? 0 : 1, $0.lastVerseNumber - $0.verseNumber) <
                    ($1.verseNumber == verseNumber ? 0 : 1, $1.lastVerseNumber - $1.verseNumber)
            }
            .first
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

}

/// The values a new chapter animates from as it slides in.
private struct ChapterSlide {
    var offset: CGFloat = 0
    var opacity: Double = 1
}

/// Text size and display choices. A popover stays open while the slider moves, which the
/// toolbar menu it replaces couldn't do.
private struct ReaderDisplayOptions: View {
    @Binding var fontSize: Double
    @Binding var showsFullReferences: Bool

    private static let defaultFontSize = 17.0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "textformat.size.smaller")
                    .accessibilityHidden(true)
                Slider(value: $fontSize, in: 12...30, step: 1) {
                    Text("Text Size")
                }
                .accessibilityValue(Text("\(Int(fontSize)) points"))
                Image(systemName: "textformat.size.larger")
                    .accessibilityHidden(true)
            }

            if fontSize != Self.defaultFontSize {
                Button("Reset Text Size") {
                    fontSize = Self.defaultFontSize
                }
            }

            Divider()

            Toggle("Full reference on each verse", isOn: $showsFullReferences)
        }
        .padding()
        .frame(minWidth: 300)
        .presentationCompactAdaptation(.popover)
    }
}

private extension View {
    @ViewBuilder
    func readerCardWidth() -> some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            containerRelativeFrame(.horizontal)
        } else {
            self
        }
    }
}

/// Chapter-local saved-data index for the reader. It replaces repeated whole-collection
/// searches while keeping the existing marker and note precedence rules intact.
/// The reader's verse rows for one chapter. The saved-item queries live here, filtered to that
/// chapter, so the reader indexes only this chapter's favorites, notes, and bookmarks rather
/// than every one saved.
private struct ReadingChapterVerseList: View {
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

/// Whether the reader's text is moving. A reference type, so writing it from the scroll
/// view doesn't invalidate the reader; only views that read it redraw.
@MainActor
@Observable
private final class ReaderScrollActivity {
    var isScrolling = false
}

/// Small, semi-transparent chapter arrows in the bottom corners, hidden while scrolling.
private struct ReaderChapterArrows: View {
    let scrollActivity: ReaderScrollActivity
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        let isScrolling = scrollActivity.isScrolling

        VStack {
            Spacer()
            HStack {
                arrow("chevron.left", label: "Previous chapter", action: onPrevious)
                    .padding(.leading, 12)

                Spacer()

                arrow("chevron.right", label: "Next chapter", action: onNext)
                    .padding(.trailing, 12)
            }
            .padding(.bottom, 10)
        }
        .opacity(isScrolling ? 0 : 1)
        .allowsHitTesting(!isScrolling)
        .animation(.easeInOut(duration: 0.2), value: isScrolling)
    }

    private func arrow(_ systemImage: String, label: LocalizedStringResource, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44) // hit target
                .background(.ultraThinMaterial, in: Circle())
                .opacity(0.7)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}

private struct ReadingChapterStatusIndex {
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
