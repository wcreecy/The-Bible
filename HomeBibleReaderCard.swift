import SwiftData
import SwiftUI

/// The iPad Home "Today's Reading" panel.
///
/// It shows the passage that matters right now — your bookmark, or the Verse of the Day in its
/// chapter — rather than keeping a place of its own. Browsing away from that passage is
/// temporary. Reading here counts like the Bible tab: reading time, read verses, and the
/// last-read position are all recorded once you interact with it.
struct HomeBibleReaderCard: View {
    enum Source: String, CaseIterable, Identifiable {
        case bookmark
        case verseOfDay

        var id: String { rawValue }

        var title: String {
            switch self {
            case .bookmark: return "Bookmark"
            case .verseOfDay: return "Verse of the Day"
            }
        }
    }

    /// Today's verse, from Home's Verse of the Day.
    let verseOfDay: HomeVerseRef?
    let onVerseAction: (VerseActionFeedback) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    // Newest first; synced devices can briefly hold more than one bookmark.
    @Query(sort: [SortDescriptor(\Bookmark.createdAt, order: .reverse)]) private var bookmarks: [Bookmark]

    @AppStorage("homeReaderSource") private var source: Source = .bookmark
    @AppStorage("homeBibleReaderContentHeight") private var preferredContentHeight: Double = 0
    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false

    // What is on screen.
    @State private var book: Book?
    @State private var chapterNumber = 1
    @State private var isLoading = true
    @State private var selectedVerse: Int?
    @State private var visibleVerses: Set<Int> = []
    @State private var scrollRequest: ScrollRequest?
    /// Where reading stopped, captured on appear; used when there is no bookmark yet.
    @State private var lastReadFallback = Passage(bookName: "Genesis", chapter: 1, verse: 1)

    @State private var session = HomeReadingSession()
    @State private var showsScripturePicker = false
    @State private var persistenceFailure: PersistenceFailure?
    @State private var currentContentHeight: CGFloat = 0
    @State private var resizeStartHeight: CGFloat?
    @State private var liveResizeHeight: CGFloat?

    private struct Passage: Equatable {
        let bookName: String
        let chapter: Int
        let verse: Int

        var reference: String { "\(bookName) \(chapter):\(verse)" }
    }

    /// A new value scrolls to `verse`, even when it is the same verse as last time.
    private struct ScrollRequest: Equatable {
        let verse: Int
        let id = UUID()
    }

    // MARK: - Source

    private var bookmark: Bookmark? { bookmarks.first }

    /// The passage the chosen source points at.
    private var target: Passage? {
        switch source {
        case .bookmark:
            if let bookmark {
                return Passage(bookName: bookmark.bookName, chapter: bookmark.chapterNumber, verse: bookmark.verseNumber)
            }
            return lastReadFallback
        case .verseOfDay:
            return verseOfDay.map {
                Passage(bookName: $0.bookName, chapter: $0.chapterNumber, verse: $0.verseNumber)
            }
        }
    }

    private var isShowingTargetChapter: Bool {
        guard let target, let book else { return false }
        return book.name == target.bookName && chapterNumber == target.chapter
    }

    private var chapter: Chapter? {
        book?.chapters.first(where: { $0.number == chapterNumber })
    }

    /// The verse at the top of the reader, used for the reading position and for moving the bookmark.
    private var topVisibleVerse: Int? {
        visibleVerses.min()
    }

    // MARK: - Chapter order

    private var canonicalBookNames: [String] {
        BibleCanon.canonicalOrder()
    }

    private var bookIndex: Int? {
        book.flatMap { canonicalBookNames.firstIndex(of: $0.name) }
    }

    private var canShowPreviousChapter: Bool {
        guard let bookIndex else { return chapterNumber > 1 }
        return chapterNumber > 1 || bookIndex > canonicalBookNames.startIndex
    }

    private var canShowNextChapter: Bool {
        guard let book else { return false }
        if chapterNumber < book.chapters.count { return true }
        guard let bookIndex else { return false }
        return bookIndex < canonicalBookNames.index(before: canonicalBookNames.endIndex)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(AppDesignMetrics.cardPadding)

            Divider()

            reader
                .containerRelativeFrame(.vertical, alignment: .top) { availableHeight, _ in
                    readerContentHeight(availableHeight: availableHeight)
                }
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    currentContentHeight = height
                }
                .contentShape(Rectangle())
                .simultaneousGesture(chapterSwipeGesture)

            resizeHandle

            Divider()

            chapterControls
                .padding(AppDesignMetrics.cardPadding)
        }
        .heroCardSurface()
        .task {
            if let lastRead = ReadingPositionStore.shared.current {
                lastReadFallback = Passage(
                    bookName: lastRead.bookName,
                    chapter: lastRead.chapterNumber,
                    verse: lastRead.verseNumber ?? 1
                )
            }
            await showTarget()
        }
        .onChange(of: source) { _, _ in
            Task { await showTarget() }
        }
        .onChange(of: target) { _, newTarget in
            // A bookmark moved within this chapter only changes the highlight.
            guard let newTarget, !isShowingTargetChapter else { return }
            Task { await show(newTarget, scrollTo: newTarget.verse) }
        }
        .onChange(of: visibleVerses) { _, _ in
            recordPositionIfReading()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                session.pause()
                ReadingPositionStore.shared.flush()
            }
        }
        .onDisappear {
            session.stop()
        }
        .sheet(isPresented: $showsScripturePicker) {
            NavigationStack {
                ScripturePickerView(
                    initialBook: book?.name ?? "Genesis",
                    initialChapter: chapterNumber,
                    initialVerse: topVisibleVerse ?? 1
                ) { bookName, chapterNumber, verseNumber in
                    Task {
                        await show(Passage(bookName: bookName, chapter: chapterNumber, verse: verseNumber), scrollTo: verseNumber)
                        noteInteraction()
                    }
                }
            }
        }
        .persistenceFailureAlert(failure: $persistenceFailure)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Today's Reading")
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "book.pages.fill")
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text("Today's Reading")
                    .font(.headline)
                Spacer()
                Button {
                    openInBibleTab(at: selectedVerse ?? topVisibleVerse ?? 1)
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel("Open in Bible")
                .disabled(book == nil)
            }

            Picker("Show", selection: $source) {
                ForEach(Source.allCases) { source in
                    Text(source.title).tag(source)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Button {
                showsScripturePicker = true
            } label: {
                HStack(spacing: 6) {
                    Text(book.map { "\($0.name) \(chapterNumber)" } ?? "Choose a Passage")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Choose another passage to read")

            sourceStatus

            if contextualTipsEnabled {
                ContextualTipView(
                    id: "home.todaysReading",
                    title: "Today's Reading",
                    message: "Read from your bookmark or the Verse of the Day. Tap a verse for actions, swipe to change chapters, and drag the handle to resize.",
                    systemImage: "hand.draw"
                )
            }
        }
    }

    /// Explains how the passage on screen relates to the chosen source, with a way back.
    @ViewBuilder
    private var sourceStatus: some View {
        switch source {
        case .bookmark:
            if bookmark == nil {
                statusText("No bookmark yet, so this is where you last read. Bookmark a verse to keep your place here.")
            } else if let bookmark, !isShowingTargetChapter, book != nil {
                VStack(alignment: .leading, spacing: 8) {
                    statusText("Your bookmark is at \(bookmark.bookName) \(bookmark.chapterNumber):\(bookmark.verseNumber).")
                    HStack(spacing: 10) {
                        Button("Move Bookmark Here", systemImage: "bookmark.fill", action: moveBookmarkHere)
                            .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                            .controlSize(.small)
                        Button("Back to Bookmark") {
                            Task { await showTarget() }
                        }
                        .buttonStyle(.plain)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                    }
                }
            }
        case .verseOfDay:
            if verseOfDay == nil {
                statusText("Today's verse is still loading.")
            } else if !isShowingTargetChapter, book != nil {
                Button("Back to Verse of the Day") {
                    Task { await showTarget() }
                }
                .buttonStyle(.plain)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            }
        }
    }

    private func statusText(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Reader

    @ViewBuilder
    private var reader: some View {
        if isLoading {
            ProgressView("Loading chapter…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let book, let chapter {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(chapter.verses) { verse in
                            verseRow(verse, bookName: book.name, chapter: chapter)
                                .id(verse.number)
                        }
                    }
                    .padding(AppDesignMetrics.cardPadding)
                }
                .id("\(book.name)-\(chapter.number)")
                .onScrollPhaseChange { _, phase in
                    if phase == .interacting {
                        noteInteraction()
                    }
                }
                .onAppear {
                    scroll(using: proxy)
                }
                .onChange(of: scrollRequest) { _, _ in
                    scroll(using: proxy)
                }
            }
        } else {
            ContentUnavailableView(
                "Chapter Unavailable",
                systemImage: "book.closed",
                description: Text("Choose another Bible passage.")
            )
        }
    }

    private func verseRow(_ verse: Verse, bookName: String, chapter: Chapter) -> some View {
        let isTargetVerse = target == Passage(bookName: bookName, chapter: chapter.number, verse: verse.number)
        let isSelected = selectedVerse == verse.number
        let update = SeenVerseUpdate(
            bookName: bookName,
            chapter: chapter.number,
            verse: verse.number,
            totalVerses: chapter.verses.count
        )

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(verse.number)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isTargetVerse ? Color.accentColor : .secondary)
                    .frame(minWidth: 20, alignment: .trailing)

                Text(verse.text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isSelected {
                HStack {
                    VerseActionMenu(
                        verse: VerseActionReference(
                            bookName: bookName,
                            chapterNumber: chapter.number,
                            verseNumber: verse.number,
                            verseText: verse.text
                        ),
                        presentation: .buttons,
                        onFeedback: onVerseAction
                    )
                    Spacer(minLength: 0)
                }
                .padding(.leading, 28)
                .transition(.opacity)
            }
        }
        .padding(.vertical, isTargetVerse || isSelected ? 6 : 0)
        .padding(.horizontal, isTargetVerse || isSelected ? 8 : 0)
        .background {
            if isTargetVerse || isSelected {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(isSelected ? 0.14 : 0.08))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.selection()
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedVerse = isSelected ? nil : verse.number
            }
            session.recordEngagement(update)
            noteInteraction()
        }
        .onScrollVisibilityChange(threshold: 0.6) { isVisible in
            if isVisible {
                visibleVerses.insert(verse.number)
            } else {
                visibleVerses.remove(verse.number)
            }
            session.verseVisibilityChanged(update, isVisible: isVisible)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Verse \(verse.number). \(verse.text)")
        .accessibilityHint(isSelected ? "Tap to hide verse actions" : "Tap for verse actions")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Controls

    private var resizeHandle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.body.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .contentShape(Rectangle())
            .gesture(resizeGesture)
            .accessibilityLabel("Resize Bible reader")
            .accessibilityHint("Drag up or down to change the reader height")
            .accessibilityAdjustableAction { direction in
                resizeReader(for: direction)
            }
    }

    private var chapterControls: some View {
        HStack {
            Button {
                Task { await showAdjacentChapter(forward: false) }
            } label: {
                Label("Previous", systemImage: "chevron.left")
            }
            .disabled(!canShowPreviousChapter)

            Spacer()

            Button {
                Task { await showAdjacentChapter(forward: true) }
            } label: {
                HStack(spacing: 4) {
                    Text("Next")
                    Image(systemName: "chevron.right")
                }
            }
            .disabled(!canShowNextChapter)
        }
        .font(.caption.weight(.semibold))
    }

    // MARK: - Navigation

    @MainActor
    private func showTarget() async {
        guard let target else {
            if book == nil { isLoading = false }
            return
        }
        await show(target, scrollTo: target.verse)
    }

    @MainActor
    private func show(_ passage: Passage, scrollTo verse: Int?) async {
        let previousBookName = book?.name
        if previousBookName != passage.bookName {
            isLoading = true
            let loaded = await BibleRepository.shared.loadBook(named: passage.bookName)
            isLoading = false
            guard let loaded else { return }
            book = loaded
        }
        guard let book else { return }

        let number = min(max(passage.chapter, 1), book.chapters.count)
        if previousBookName != book.name || number != chapterNumber {
            session.chapterChanged()
            visibleVerses = []
        }
        chapterNumber = number
        selectedVerse = nil
        if let verse {
            scrollRequest = ScrollRequest(verse: verse)
        }
    }

    @MainActor
    private func showAdjacentChapter(forward: Bool) async {
        guard let book, forward ? canShowNextChapter : canShowPreviousChapter else { return }

        if forward, chapterNumber < book.chapters.count {
            await show(Passage(bookName: book.name, chapter: chapterNumber + 1, verse: 1), scrollTo: 1)
        } else if !forward, chapterNumber > 1 {
            await show(Passage(bookName: book.name, chapter: chapterNumber - 1, verse: 1), scrollTo: 1)
        } else if let bookIndex {
            let name = canonicalBookNames[forward ? bookIndex + 1 : bookIndex - 1]
            guard let adjacent = await BibleRepository.shared.loadBook(named: name) else { return }
            await show(Passage(bookName: name, chapter: forward ? 1 : adjacent.chapters.count, verse: 1), scrollTo: 1)
        }

        Haptics.selection()
        noteInteraction()
    }

    private func scroll(using proxy: ScrollViewProxy) {
        guard let verse = scrollRequest?.verse else { return }
        Task { @MainActor in
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(verse, anchor: .top)
            }
        }
    }

    // MARK: - Reading

    /// Any interaction means the reader is reading; timing and read verses start or resume.
    private func noteInteraction() {
        guard let book else { return }
        session.markActivity(bookName: book.name, chapter: chapterNumber)
        recordPositionIfReading()
    }

    private func recordPositionIfReading() {
        guard session.isActive, let book, let verse = topVisibleVerse else { return }
        ReadingPositionStore.shared.record(bookName: book.name, chapter: chapterNumber, verse: verse)
    }

    private func moveBookmarkHere() {
        guard let book, let chapter else { return }
        let verseNumber = topVisibleVerse ?? 1
        let verseText = chapter.verses.first(where: { $0.number == verseNumber })?.text ?? ""

        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                try Bookmark.move(
                    to: book.name,
                    chapter: chapter.number,
                    verse: verseNumber,
                    verseText: verseText,
                    in: modelContext
                )
                try modelContext.save()
            },
            onSuccess: {
                Haptics.success()
                onVerseAction(.bookmarked)
            },
            onFailure: { persistenceFailure = $0 }
        )
    }

    private func openInBibleTab(at verseNumber: Int) {
        guard let book else { return }
        let bookName = book.name
        let chapterNumber = chapterNumber
        Haptics.selection()
        NotificationCenter.default.post(
            name: .switchToTab,
            object: nil,
            userInfo: [
                "tab": AppTab.bible.rawValue,
                "tabName": AppTab.bible.name
            ]
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(
                name: .openBibleReference,
                object: nil,
                userInfo: [
                    "book": bookName,
                    "chapter": chapterNumber,
                    "verse": verseNumber,
                    "relayed": true
                ]
            )
        }
    }

    // MARK: - Sizing

    private static let minimumContentHeight: CGFloat = 240
    private static let maximumContentHeight: CGFloat = 900

    private func readerContentHeight(availableHeight: CGFloat) -> CGFloat {
        if let liveResizeHeight {
            return clampedContentHeight(liveResizeHeight)
        }

        if preferredContentHeight > 0 {
            return clampedContentHeight(CGFloat(preferredContentHeight))
        }

        // The default adapts to the window so the chapter controls remain visible.
        return clampedContentHeight(min(520, availableHeight - 440))
    }

    private func clampedContentHeight(_ height: CGFloat) -> CGFloat {
        min(Self.maximumContentHeight, max(Self.minimumContentHeight, height))
    }

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let startHeight = resizeStartHeight ?? currentContentHeight
                if resizeStartHeight == nil {
                    resizeStartHeight = startHeight
                }
                liveResizeHeight = clampedContentHeight(startHeight + value.translation.height)
            }
            .onEnded { value in
                let startHeight = resizeStartHeight ?? currentContentHeight
                let finalHeight = clampedContentHeight(startHeight + value.translation.height)
                preferredContentHeight = Double(finalHeight)
                resizeStartHeight = nil
                liveResizeHeight = nil
                Haptics.selection()
            }
    }

    private func resizeReader(for direction: AccessibilityAdjustmentDirection) {
        let startingHeight = preferredContentHeight > 0
            ? CGFloat(preferredContentHeight)
            : currentContentHeight
        let adjustment: CGFloat

        switch direction {
        case .increment:
            adjustment = 60
        case .decrement:
            adjustment = -60
        @unknown default:
            return
        }

        preferredContentHeight = Double(clampedContentHeight(startingHeight + adjustment))
        Haptics.selection()
    }

    private var chapterSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height),
                      abs(value.translation.width) > 60 else {
                    return
                }
                Task { await showAdjacentChapter(forward: value.translation.width < 0) }
            }
    }
}

/// Reading-time and read-verse tracking for the Home panel.
///
/// It only runs after the reader interacts, and pauses after a couple of idle minutes, so
/// leaving Home open does not count as reading. It shares `ReadingTimeTracker` with the
/// Bible tab and only pauses or stops a session that is still its own.
@MainActor
private final class HomeReadingSession {
    private(set) var isActive = false
    private var location: (bookName: String, chapter: Int)?

    private lazy var verseTracker = VerseReadingTracker { updates in
        BibleStatsStore.shared.markVersesSeen(updates)
    }
    private lazy var inactivityMonitor = InactivityMonitor(timeout: 120) { [weak self] in
        self?.pause()
    }

    func markActivity(bookName: String, chapter: Int) {
        location = (bookName, chapter)
        let tracker = ReadingTimeTracker.shared
        tracker.start(bookName: bookName, chapter: chapter)
        tracker.setCurrentLocation(bookName: bookName, chapter: chapter)
        tracker.resume()
        verseTracker.setActive(true)
        isActive = true
        inactivityMonitor.markActivity()
    }

    func verseVisibilityChanged(_ update: SeenVerseUpdate, isVisible: Bool) {
        verseTracker.visibilityChanged(update, isVisible: isVisible)
    }

    func recordEngagement(_ update: SeenVerseUpdate) {
        verseTracker.recordDirectEngagement(update)
    }

    func chapterChanged() {
        verseTracker.resetVisibility()
    }

    /// After inactivity, or when the app leaves the foreground.
    func pause() {
        guard isActive else { return }
        isActive = false
        inactivityMonitor.cancel()
        verseTracker.setActive(false)
        if let location, ReadingTimeTracker.shared.isTiming(bookName: location.bookName, chapter: location.chapter) {
            ReadingTimeTracker.shared.pause()
        }
    }

    /// When the panel leaves the screen.
    func stop() {
        inactivityMonitor.cancel()
        verseTracker.stop()
        if isActive, let location,
           ReadingTimeTracker.shared.isTiming(bookName: location.bookName, chapter: location.chapter) {
            ReadingTimeTracker.shared.stopAndFlush()
        }
        isActive = false
        ReadingPositionStore.shared.flush()
    }
}
