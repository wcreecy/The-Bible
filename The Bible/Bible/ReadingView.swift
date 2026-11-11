import SwiftUI
import SwiftData
import UIKit
import WidgetKit

// The verse rows live in ReadingChapterVerseList.swift, the book picker in
// ReaderBookPickerSheet.swift, and the arrows/display popover in ReaderChrome.swift.
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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

    /// Whether the window is wide enough for every reader control to sit in the toolbar.
    /// Narrower windows (iPhone, and iPad in Split View or a small Stage Manager window)
    /// keep the title uncrowded by putting most controls in the "…" menu.
    private var usesFullToolbar: Bool {
        horizontalSizeClass == .regular
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

    // The body is built in stages (toolbar, presentations, lifecycle) so each stage is
    // type-checked on its own instead of as one long modifier chain.
    var body: some View {
        readerWithPresentations
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
                favoriteToastSymbol = "character.book.closed"
                favoriteToastTint = .accentColor
                favoriteToastText = "Now reading \(BibleStore.shared.translation.abbreviation)"
                withAnimation(.spring()) { showFavoriteToast = true }
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
            .onChange(of: isFocusModePresented) { _, isPresented in
                viewModel.setFocusModeActive(isPresented)
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

    // MARK: - Toolbar

    private var readerWithToolbar: some View {
        content
            .environment(\.font, nil)
            .navigationTitle("\(viewModel.currentBook.name) \(viewModel.currentChapter.number)")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(onNavigateBack != nil)
            .toolbar { readerToolbar }
    }

    @ToolbarContentBuilder
    private var readerToolbar: some ToolbarContent {
        // Left of the title: getting back, and how the text looks.
        ToolbarItemGroup(placement: .topBarLeading) {
            if let onNavigateBack {
                Button {
                    onNavigateBack(viewModel.currentBook)
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .accessibilityLabel("Back to chapters")
            }

            // In the full toolbar, Search joins the other actions on the right.
            if !usesFullToolbar {
                searchButton
            }
        }

        if usesFullToolbar {
            // Sets Back apart from the display controls; with no Back button there's nothing to separate.
            if onNavigateBack != nil {
                ToolbarSpacer(.fixed, placement: .topBarLeading)
            }

            ToolbarItemGroup(placement: .topBarLeading) {
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
        }

        // Right of the title: actions, with Focus Mode outermost.
        ToolbarItemGroup(placement: .topBarTrailing) {
            if usesFullToolbar {
                fullToolbarActions
            } else {
                readerOptionsMenu
            }
        }

        ToolbarItem(placement: .principal) {
            titleButton
        }
    }

    @ViewBuilder
    private var fullToolbarActions: some View {
        searchButton

        Button {
            chapterInsightsDismissal.isPresented = true
        } label: {
            Image(systemName: "lightbulb")
        }
        .accessibilityLabel("Study this chapter")
        .accessibilityHint("Opens insights for \(viewModel.currentBook.name) \(viewModel.currentChapter.number)")

        Button {
            presentFocusMode()
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
        }
        .accessibilityLabel("Enter Focus Mode")
        .accessibilityHint("Hides the toolbar and shows only the text")
    }

    private var readerOptionsMenu: some View {
        Menu {
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

            Button {
                presentFocusMode()
            } label: {
                Label("Enter Focus Mode", systemImage: "arrow.up.left.and.arrow.down.right")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .popover(isPresented: $isDisplayOptionsPresented) {
            displayOptions
        }
        .accessibilityLabel("Reader Options")
        .accessibilityHint("Enter Focus Mode, change text size or translation, or open chapter insights")
    }

    private var titleButton: some View {
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

                // The translation picker is in the "…" menu in narrow windows, so name it here.
                if !usesFullToolbar {
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

    // MARK: - Presentations

    private var readerWithPresentations: some View {
        @Bindable var chapterInsightsDismissal = chapterInsightsDismissal

        return readerWithToolbar
            .sheet(isPresented: $isBookPickerPresented) { bookPickerSheet }
            .appToast(
                isPresented: $showFavoriteToast,
                symbol: favoriteToastSymbol,
                text: favoriteToastText,
                tint: favoriteToastTint
            )
            .persistenceFailureAlert(failure: $persistenceFailure)
            .fullScreenCover(isPresented: $isFocusModePresented) {
                focusReadingCover
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
                chapterInsightsSheet
            }
            .sheet(item: $crossReferenceVerse) { verse in
                crossReferencesSheet(for: verse)
            }
    }

    private var focusReadingCover: some View {
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

    private var chapterInsightsSheet: some View {
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

    private func crossReferencesSheet(for verse: Verse) -> some View {
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

    private var bookPickerSheet: some View {
        ReaderBookPickerSheet(
            searchText: $bookPickerSearchText,
            onSelectBook: { book in open(book: book) },
            onSelectReference: { reference in open(reference: reference) },
            onCancel: { isBookPickerPresented = false }
        )
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        ZStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if contextualTipsEnabled {
                        readerTips
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
                        continueButton(nextTitle: nextTitle)
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

    @ViewBuilder
    private var readerTips: some View {
        if BibleTranslation.available.count > 1 {
            ContextualTipView(
                id: "reader.translations",
                title: "Choose a translation",
                message: usesFullToolbar
                    ? "Tap the translation button at the top left to read another version. Your saved verses keep the translation they were saved in."
                    : "Tap the ellipsis button at the top right, then Translation, to read another version. Your saved verses keep the translation they were saved in.",
                systemImage: "character.book.closed"
            )
            .padding(.bottom, 12)
        }

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
            message: "Icons beside a verse's reference show your bookmark, favorites, notes, and Scripture connections. Tap a note or Scripture connection icon to open it. Change this in Settings › Bible Reader.",
            systemImage: "info.circle"
        )
        .padding(.bottom, 12)

        Divider()
    }

    private func continueButton(nextTitle: String) -> some View {
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

    // MARK: - Actions

    private func open(book: Book) {
        isBookPickerPresented = false
        bookPickerSearchText = ""
        onBookSelected?(book)
    }

    private func open(reference: ReaderBookPickerSheet.ResolvedReference) {
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
