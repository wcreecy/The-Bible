import SwiftUI
import SwiftData
import UIKit
import WidgetKit

struct ReadingView: View {
    @Environment(\.modelContext) private var modelContext
    // Always keep newest progress first so `progressList.first` is canonical
    @Query(sort: \ReadingProgress.updatedAt, order: .reverse) private var progressList: [ReadingProgress]
    @Query private var favorites: [Favorite]
    @EnvironmentObject private var journalComposer: JournalComposer

    // Scene phase for pausing when app is not active
    @Environment(\.scenePhase) private var scenePhase

    let book: Book
    let chapter: Chapter
    let startVerse: Int

    // Current state for navigation
    @State private var currentBook: Book
    @State private var currentChapterIndex: Int
    @State private var currentVerse: Int
    @State private var currentBookNameIndex: Int? = nil

    // Ordered list of book names (canonical order)
    @State private var orderedBookNames: [String] = []

    @State private var highlightOnAppear: Bool = true
    @State private var highlightedVerse: Int? = nil
    @State private var menuVerse: Int? = nil
    @State private var selectedVerse: Int? = nil
    @State private var topVisibleVerseID: String? = nil
    @State private var showFavoriteToast: Bool = false
    @State private var favoriteToastText: String = "Added to Favorites"
    @State private var favoriteToastSymbol: String = "heart.fill"
    @State private var favoriteToastTint: Color = .pink
    @State private var pinVerse: Int? = nil

    // Track currently pinned verse for the widget (mirrors shared defaults)
    @State private var pinnedBookName: String = ""
    @State private var pinnedChapterNumber: Int = 0
    @State private var pinnedVerseNumber: Int = 0

    // Lazy BibleStore
    @StateObject private var bibleStore = BibleStore.shared

    // Reader-specific font size (independent from global app UI font)
    @AppStorage("readerFontSize") private var readerFontSize: Double = 17

    // Guard: avoid mass-marking only for deep links (when starting mid-chapter)
    @State private var hasCompletedInitialAppear: Bool = false
    @State private var suppressInitialMarking: Bool = false

    // Inactivity tracking (300s)
    private let inactivitySeconds: TimeInterval = 300
    @State private var lastActivityAt: Date = Date()
    @State private var inactivityTask: Task<Void, Never>?

    // Track current tab (listen to ContentView .switchToTab notifications)
    @State private var currentTabIndex: Int = 1 // assume Bible by default

    // Search sheet state
    @State private var showSearchSheet: Bool = false
    @State private var searchQuery: String = ""
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching: Bool = false

    init(book: Book, chapter: Chapter, startVerse: Int) {
        self.book = book
        self.chapter = chapter
        self.startVerse = startVerse
        _currentBook = State(initialValue: book)
        _currentChapterIndex = State(initialValue: max(0, chapter.number - 1))
        _currentVerse = State(initialValue: startVerse)
        _suppressInitialMarking = State(initialValue: startVerse > 1)
    }

    private var currentChapter: Chapter {
        if currentBook.chapters.indices.contains(currentChapterIndex) {
            return currentBook.chapters[currentChapterIndex]
        }
        return currentBook.chapters.first ?? chapter
    }

    var body: some View {
        content
            // Opt out of the app-wide .font set in ContentView so the reader can control its own size
            .environment(\.font, nil)
            .navigationTitle("\(currentBook.name) \(currentChapter.number)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        searchQuery = ""
                        searchResults = []
                        isSearching = false
                        showSearchSheet = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Search Bible")
                }
                // Tappable title: jump back to the Books list on the Bible tab
                ToolbarItem(placement: .principal) {
                    Button {
                        let h = UIImpactFeedbackGenerator(style: .light)
                        h.impactOccurred()
                        // Ask the app to switch to Bible tab and reset its navigation to BooksView
                        NotificationCenter.default.post(name: .resetBibleNavigation, object: nil)
                    } label: {
                        Text("\(currentBook.name) \(currentChapter.number)")
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to Books")
                    .accessibilityHint("Go to the list of books")
                }
            }
            .onAppear(perform: onAppear)
            .onAppear {
                // Start reading-time tracking for this book (with chapter info)
                ReadingTimeTracker.shared.start(bookName: currentBook.name, chapter: currentChapter.number)

                // Also keep current location up to date
                ReadingTimeTracker.shared.setCurrentLocation(bookName: currentBook.name, chapter: currentChapter.number)

                // Start inactivity monitoring as active
                markActivityAndScheduleInactivity()

                // Load canonical book order once
                Task { @MainActor in
                    await loadOrderedBookNames()
                }
                // Load current pinned verse state from shared defaults
                loadPinnedFromShared()

                // Configure initial marking behavior for this entry
                // Suppress only if we jump into the middle of a chapter
                suppressInitialMarking = (currentVerse > 1)
                if suppressInitialMarking {
                    hasCompletedInitialAppear = false
                    Task { @MainActor in
                        // Yield to allow initial verse cells to render
                        await Task.yield()
                        // Small delay to ensure initial batch of cells has finished appearing
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        hasCompletedInitialAppear = true
                        // Count the initially focused verse as seen (but not the whole chapter)
                        let total = currentChapter.verses.count
                        BibleStatsStore.shared.markVerseSeen(
                            bookName: currentBook.name,
                            chapter: currentChapter.number,
                            verse: currentVerse,
                            totalVerses: total
                        )
                    }
                } else {
                    // Starting at verse 1: allow initial visible verses to be marked immediately
                    hasCompletedInitialAppear = true
                }

                // One-time cleanup: if multiple ReadingProgress rows exist, keep the newest and delete the rest
                dedupeReadingProgress()
            }
            .onDisappear {
                // Stop inactivity monitoring
                cancelInactivityTask()
                // Stop and flush reading-time tracking
                ReadingTimeTracker.shared.stopAndFlush()
            }
            .onChange(of: scenePhase) { _, newPhase in
                // Pause when app not active; resume when active
                if newPhase == .active {
                    ReadingTimeTracker.shared.resume()
                    markActivityAndScheduleInactivity()
                } else {
                    ReadingTimeTracker.shared.pause()
                    cancelInactivityTask()
                }
            }
            // Listen for tab switches broadcast by ContentView
            .onReceive(NotificationCenter.default.publisher(for: .init("switchToTab"))) { note in
                if let tab = note.userInfo?["tab"] as? Int {
                    currentTabIndex = tab
                    if tab == 1 {
                        // Bible tab visible -> resume and rearm inactivity
                        ReadingTimeTracker.shared.resume()
                        markActivityAndScheduleInactivity()
                    } else {
                        // Other tab -> pause
                        ReadingTimeTracker.shared.pause()
                        cancelInactivityTask()
                    }
                }
            }
            .appToast(isPresented: $showFavoriteToast, symbol: favoriteToastSymbol, text: favoriteToastText, tint: favoriteToastTint)
            .fullScreenCover(isPresented: $showSearchSheet) {
                NavigationStack {
                    // Use a top-aligned container so the search field stays at the top
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                TextField("Search Bible (type at least two words)", text: $searchQuery)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .onChange(of: searchQuery) { _, newValue in
                                        runSearchIfEligible(query: newValue)
                                    }
                                    .submitLabel(.search)
                                    .onSubmit {
                                        runSearchIfEligible(query: searchQuery, force: true)
                                    }
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )

                            if isSearching {
                                ProgressView("Searching…")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else if searchResults.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    if eligibleWordCount(in: searchQuery) < 2 {
                                        Text("Type at least two words to search.")
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text("No results found.")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                // Use a plain List-like layout within the scroll view
                                VStack(spacing: 0) {
                                    ForEach(searchResults) { item in
                                        Button {
                                            jumpToSearchResult(item)
                                        } label: {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("\(item.bookName) \(item.chapterNumber):\(item.verseNumber)")
                                                    .font(.subheadline.weight(.semibold))
                                                Text("“\(item.verseText)”")
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(3)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.vertical, 10)
                                        }
                                        .buttonStyle(.plain)
                                        if item.id != searchResults.last?.id {
                                            Divider()
                                        }
                                    }
                                }
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                        .padding(16)
                    }
                    .navigationTitle("Search")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showSearchSheet = false }
                        }
                    }
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(currentChapter.verses) { verse in
                        Group {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(verse.text)
                                    .font(.system(size: readerFontSize))
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("\(currentBook.name) \(currentChapter.number):\(verse.number)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                        }
                        .id(rowID(for: verse.number))
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background((highlightedVerse == verse.number || selectedVerse == verse.number) ? Color.yellow.opacity(0.25) : Color.clear)
                        .animation(.easeInOut(duration: 0.6), value: highlightedVerse)
                        .animation(.easeInOut(duration: 0.2), value: selectedVerse)
                        .overlay(alignment: .trailing) {
                            if pinVerse == verse.number {
                                Image(systemName: "bookmark.fill")
                                    .foregroundStyle(.blue)
                                    .padding(.trailing, 12)
                                    .transition(.opacity)
                                    .opacity(0.9)
                            }
                        }
                        // Mark verses that appear on screen, but skip the initial programmatic layout if we deep-linked.
                        .onAppear {
                            if suppressInitialMarking && !hasCompletedInitialAppear { return }
                            let total = currentChapter.verses.count
                            BibleStatsStore.shared.markVerseSeen(
                                bookName: currentBook.name,
                                chapter: currentChapter.number,
                                verse: verse.number,
                                totalVerses: total
                            )
                        }
                        .onLongPressGesture(minimumDuration: 0.5) {
                            let generator = UIImpactFeedbackGenerator(style: .heavy)
                            generator.impactOccurred()
                            menuVerse = verse.number
                            markActivityAndScheduleInactivity()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            let generator = UISelectionFeedbackGenerator()
                            generator.selectionChanged()
                            selectedVerse = verse.number
                            currentVerse = verse.number
                            // Persist "last read" ONLY on explicit tap
                            saveProgress(bookName: currentBook.name, chapter: currentChapter.number, verse: verse.number)
                            // Keep tracker location up to date
                            ReadingTimeTracker.shared.setCurrentLocation(bookName: currentBook.name, chapter: currentChapter.number)
                            if menuVerse != nil { menuVerse = nil }
                            let haptic = UIImpactFeedbackGenerator(style: .light); haptic.impactOccurred()
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                pinVerse = verse.number
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                withAnimation(.easeOut) {
                                    if pinVerse == verse.number { pinVerse = nil }
                                }
                            }
                            markActivityAndScheduleInactivity()
                        }

                        if menuVerse == verse.number {
                            HStack(spacing: 24) {
                                Button(action: {
                                    let share = shareText(bookName: currentBook.name, chapter: currentChapter.number, verse: verse.number, text: verse.text)
                                    UIPasteboard.general.string = share
                                    favoriteToastSymbol = "doc.on.doc"
                                    favoriteToastTint = .blue
                                    favoriteToastText = "Copied to Clipboard"
                                    withAnimation(.spring()) { showFavoriteToast = true }
                                    withAnimation(.easeInOut) { menuVerse = nil }
                                    markActivityAndScheduleInactivity()
                                }) { Image(systemName: "doc.on.doc") }
                                    .foregroundStyle(.blue)

                                ShareLink(item: shareText(bookName: currentBook.name, chapter: currentChapter.number, verse: verse.number, text: verse.text)) {
                                    Image(systemName: "square.and.arrow.up")
                                }
                                .foregroundStyle(.blue)

                                Button(action: {
                                    let bookName = currentBook.name
                                    let chapterNum = currentChapter.number
                                    let verseNum = verse.number
                                    let refText = "\(bookName) \(chapterNum):\(verseNum)"
                                    openJournalForReference(text: refText)
                                    withAnimation(.easeInOut) { menuVerse = nil }
                                    markActivityAndScheduleInactivity()
                                }) {
                                    Image(systemName: "book.closed")
                                }
                                .foregroundStyle(.brown)

                                // Pin / Unpin to widget (toggle)
                                Button(action: {
                                    if isPinned(verse.number) {
                                        clearPinnedVerse()
                                        let gen = UINotificationFeedbackGenerator(); gen.notificationOccurred(.success)
                                        favoriteToastSymbol = "pin"
                                        favoriteToastTint = .red
                                        favoriteToastText = "Unpinned from Widget"
                                    } else {
                                        setPinnedVerse(bookName: currentBook.name, chapter: currentChapter.number, verse: verse.number, text: verse.text)
                                        let gen = UINotificationFeedbackGenerator(); gen.notificationOccurred(.success)
                                        favoriteToastSymbol = "pin.fill"
                                        favoriteToastTint = .red
                                        favoriteToastText = "Pinned to Widget"
                                    }
                                    withAnimation(.spring()) { showFavoriteToast = true }
                                    withAnimation(.easeInOut) { menuVerse = nil }
                                    markActivityAndScheduleInactivity()
                                }) {
                                    Image(systemName: isPinned(verse.number) ? "pin.fill" : "pin")
                                }
                                .foregroundStyle(.red)

                                Button(action: {
                                    toggleFavorite(for: verse)
                                    withAnimation(.easeInOut) { menuVerse = nil }
                                    markActivityAndScheduleInactivity()
                                }) { Image(systemName: isFavorited(verse) ? "heart.fill" : "heart") }
                                    .foregroundStyle(.red)
                            }
                            .font(.title3)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal)
                            .padding(.bottom, 6)
                            .transition(.opacity)
                        }

                        if verse.number != currentChapter.verses.count {
                            Divider()
                        }
                    }
                }
                .padding(.vertical)
                .scrollTargetLayout()
                .onChange(of: currentChapterIndex) { _, _ in
                    menuVerse = nil
                    highlightedVerse = nil
                    selectedVerse = nil
                    topVisibleVerseID = rowID(for: 1)
                    // Keep tracker location up to date on chapter change
                    ReadingTimeTracker.shared.setCurrentLocation(bookName: currentBook.name, chapter: currentChapter.number)
                    // For chapter changes we reset to verse 1; allow marking immediately
                    suppressInitialMarking = (currentVerse > 1)
                    if suppressInitialMarking {
                        hasCompletedInitialAppear = false
                        Task { @MainActor in
                            await Task.yield()
                            try? await Task.sleep(nanoseconds: 150_000_000)
                            hasCompletedInitialAppear = true
                            let total = currentChapter.verses.count
                            BibleStatsStore.shared.markVerseSeen(
                                bookName: currentBook.name,
                                chapter: currentChapter.number,
                                verse: currentVerse,
                                totalVerses: total
                            )
                        }
                    } else {
                        hasCompletedInitialAppear = true
                    }

                    // Persist progress on chapter change (verse 1 of the new chapter)
                    saveProgress(bookName: currentBook.name, chapter: currentChapter.number, verse: 1)
                    markActivityAndScheduleInactivity()
                }
                .onAppear {
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            topVisibleVerseID = rowID(for: currentVerse)
                        }
                    }
                    if highlightOnAppear {
                        highlightedVerse = currentVerse
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            withAnimation { highlightedVerse = nil }
                        }
                        highlightOnAppear = false
                    }
                    markActivityAndScheduleInactivity()
                }
                .onTapGesture {
                    if menuVerse != nil { menuVerse = nil }
                    markActivityAndScheduleInactivity()
                }
            }
            .scrollPosition(id: $topVisibleVerseID, anchor: .top)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 5, coordinateSpace: .local)
                .onChanged { _ in
                    // Any drag counts as activity; resume if paused
                    ReadingTimeTracker.shared.resume()
                    markActivityAndScheduleInactivity()
                }
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = value.translation.height
                    if abs(horizontal) > abs(vertical) && abs(horizontal) > 40 {
                        if horizontal < 0 {
                            Task { await nextChapter() }
                        } else {
                            Task { await previousChapter() }
                        }
                    }
                    // Drag ended is also activity
                    markActivityAndScheduleInactivity()
                }
        )
    }

    @MainActor
    private func onAppear() {
        // Do NOT save progress automatically on appear anymore.
        // Keep scroll positioning behavior only.
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.35)) {
                topVisibleVerseID = rowID(for: currentVerse)
            }
        }
    }

    // MARK: - Inactivity handling

    private func markActivityAndScheduleInactivity() {
        lastActivityAt = Date()
        // If user interacts and tracker is paused (due to inactivity or tab/scene), resume
        ReadingTimeTracker.shared.resume()
        scheduleInactivityTimer()
    }

    private func scheduleInactivityTimer() {
        cancelInactivityTask()
        let deadline = lastActivityAt.addingTimeInterval(inactivitySeconds)
        inactivityTask = Task { [deadline] in
            let now = Date()
            let delay = deadline.timeIntervalSince(now)
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            if Task.isCancelled { return }
            // If no newer activity, pause
            if Date() >= deadline {
                ReadingTimeTracker.shared.pause()
            }
        }
    }

    private func cancelInactivityTask() {
        inactivityTask?.cancel()
        inactivityTask = nil
    }

    // Load the canonical ordered list of book names (from BibleData, which preserves order from kjv.json)
    @MainActor
    private func loadOrderedBookNames() async {
        // If you ever want to use BibleStore/BibleLibrary, you could do:
        // let names = await bibleStore.bookNames()
        // But that may be alphabetical depending on source; BibleData preserves canonical order.
        let names = BibleData.books.map { $0.name }
        orderedBookNames = names
        // Optionally update currentBookNameIndex if needed
        if let idx = names.firstIndex(of: currentBook.name) {
            currentBookNameIndex = idx
        } else {
            currentBookNameIndex = nil
        }
    }

    // Load current pinned verse state from shared App Group defaults (used by the widget)
    private func loadPinnedFromShared() {
        guard let shared = UserDefaults(suiteName: "group.bible.app") else {
            pinnedBookName = ""
            pinnedChapterNumber = 0
            pinnedVerseNumber = 0
            return
        }
        let bookName = (shared.string(forKey: "pinnedVerseBook") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let chapterNum = shared.integer(forKey: "pinnedVerseChapter")
        let verseNum = shared.integer(forKey: "pinnedVerseNumber")
        // Optional text; if absent, we keep only the reference here
        var text = (shared.string(forKey: "pinnedVerseText") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        // If reference is incomplete, clear local mirror
        guard !bookName.isEmpty, chapterNum > 0, verseNum > 0 else {
            pinnedBookName = ""
            pinnedChapterNumber = 0
            pinnedVerseNumber = 0
            return
        }

        // Fill text from BibleData if missing (mirror provider behavior)
        if text.isEmpty {
            if let b = BibleData.books.first(where: { $0.name == bookName }),
               let c = b.chapters.first(where: { $0.number == chapterNum }),
               let v = c.verses.first(where: { $0.number == verseNum }) {
                text = v.text
            }
        }

        // Update local state mirror
        pinnedBookName = bookName
        pinnedChapterNumber = max(1, chapterNum)
        pinnedVerseNumber = max(1, verseNum)
    }

    // MARK: - Pinned verse helpers (widget)
    private func setPinnedVerse(bookName: String, chapter: Int, verse: Int, text: String) {
        guard let shared = UserDefaults(suiteName: "group.bible.app") else { return }
        shared.set(bookName, forKey: "pinnedVerseBook")
        shared.set(chapter, forKey: "pinnedVerseChapter")
        shared.set(verse, forKey: "pinnedVerseNumber")
        shared.set(text, forKey: "pinnedVerseText")
        pinnedBookName = bookName
        pinnedChapterNumber = chapter
        pinnedVerseNumber = verse
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func clearPinnedVerse() {
        guard let shared = UserDefaults(suiteName: "group.bible.app") else { return }
        shared.removeObject(forKey: "pinnedVerseBook")
        shared.removeObject(forKey: "pinnedVerseChapter")
        shared.removeObject(forKey: "pinnedVerseNumber")
        shared.removeObject(forKey: "pinnedVerseText")
        pinnedBookName = ""
        pinnedChapterNumber = 0
        pinnedVerseNumber = 0
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func isPinned(_ verseNumber: Int) -> Bool {
        pinnedBookName == currentBook.name &&
        pinnedChapterNumber == currentChapter.number &&
        pinnedVerseNumber == verseNumber
    }

    // MARK: - Progress (SwiftData)
    private func saveProgress(bookName: String, chapter: Int, verse: Int) {
        // Keep a single ReadingProgress record and bump updatedAt so the latest wins across devices.
        if let existing = progressList.first {
            existing.bookName = bookName
            existing.chapterNumber = chapter
            existing.verseNumber = verse
            existing.updatedAt = Date()
            try? modelContext.save()
        } else {
            let p = ReadingProgress()
            p.singletonKey = "global" // ensure uniqueness across devices (advisory)
            p.bookName = bookName
            p.chapterNumber = chapter
            p.verseNumber = verse
            p.updatedAt = Date()
            modelContext.insert(p)
            try? modelContext.save()
        }
    }

    // Remove any older duplicate ReadingProgress rows; keep only the newest
    private func dedupeReadingProgress() {
        guard progressList.count > 1 else { return }
        // progressList is already sorted newest first by the @Query
        let toDelete = progressList.dropFirst()
        for p in toDelete {
            modelContext.delete(p)
        }
        try? modelContext.save()
    }

    // MARK: - Navigation across chapters/books (canonical order)
    private func indexOfCurrentBookInCanonical() -> Int? {
        if let idx = currentBookNameIndex {
            return idx
        }
        return orderedBookNames.firstIndex(of: currentBook.name)
    }

    // Haptic helper
    private func playImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        #if canImport(UIKit)
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.impactOccurred()
        #endif
    }

    @MainActor
    private func nextChapter() async {
        guard let bookIdx = indexOfCurrentBookInCanonical() else { return }
        let chapters = currentBook.chapters
        if currentChapterIndex + 1 < chapters.count {
            currentChapterIndex += 1
            currentVerse = 1
            topVisibleVerseID = rowID(for: 1)
            // Persist progress for the new chapter start
            saveProgress(bookName: currentBook.name, chapter: currentChapter.number, verse: 1)
            // Light haptic for in-book chapter change
            playImpact(.light)
            return
        }
        // Move to first chapter of next book if available
        let nextBookIdx = bookIdx + 1
        guard orderedBookNames.indices.contains(nextBookIdx) else { return }
        let nextBookName = orderedBookNames[nextBookIdx]
        guard let nextBook = BibleData.books.first(where: { $0.name == nextBookName }) else { return }
        currentBook = nextBook
        currentBookNameIndex = nextBookIdx
        currentChapterIndex = 0
        currentVerse = 1
        topVisibleVerseID = rowID(for: 1)
        ReadingTimeTracker.shared.changeBook(to: currentBook.name, chapter: currentChapter.number)
        saveProgress(bookName: currentBook.name, chapter: currentChapter.number, verse: 1)
        // Heavy haptic for book change
        playImpact(.heavy)
    }

    @MainActor
    private func previousChapter() async {
        guard let bookIdx = indexOfCurrentBookInCanonical() else { return }
        if currentChapterIndex - 1 >= 0 {
            currentChapterIndex -= 1
            currentVerse = 1
            topVisibleVerseID = rowID(for: 1)
            saveProgress(bookName: currentBook.name, chapter: currentChapter.number, verse: 1)
            // Light haptic for in-book chapter change
            playImpact(.light)
            return
        }
        // Move to last chapter of previous book if available
        let prevBookIdx = bookIdx - 1
        guard orderedBookNames.indices.contains(prevBookIdx) else { return }
        let prevBookName = orderedBookNames[prevBookIdx]
        guard let prevBook = BibleData.books.first(where: { $0.name == prevBookName }) else { return }
        currentBook = prevBook
        currentBookNameIndex = prevBookIdx
        currentChapterIndex = max(0, prevBook.chapters.count - 1)
        currentVerse = 1
        topVisibleVerseID = rowID(for: 1)
        ReadingTimeTracker.shared.changeBook(to: currentBook.name, chapter: currentChapter.number)
        saveProgress(bookName: currentBook.name, chapter: currentChapter.number, verse: 1)
        // Heavy haptic for book change
        playImpact(.heavy)
    }

    // MARK: - IDs
    private func rowID(for verseNumber: Int) -> String {
        "\(currentBook.name)-\(currentChapter.number)-\(verseNumber)"
    }

    // MARK: - Journal
    private func openJournalForReference(text: String) {
        // Expect "BookName Chapter:Verse"
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let colon = trimmed.lastIndex(of: ":") else {
            journalComposer.present(initialBody: nil, verseRef: nil, showTagColors: false)
            return
        }
        let before = String(trimmed[..<colon])
        let after = String(trimmed[trimmed.index(after: colon)...])
        let parts = before.split(separator: " ")
        guard let last = parts.last, let chapterNum = Int(last) else {
            journalComposer.present(initialBody: nil, verseRef: nil, showTagColors: false)
            return
        }
        let bookName = parts.dropLast().joined(separator: " ")
        guard let verseNum = Int(after) else {
            journalComposer.present(initialBody: nil, verseRef: nil, showTagColors: false)
            return
        }
        let ref = VerseRef(book: bookName, chapter: chapterNum, verse: verseNum, translation: "KJV")
        journalComposer.present(initialBody: nil, verseRef: ref, showTagColors: false)
    }

    // MARK: - Favorites (SwiftData)
    private func isFavorited(_ verse: Verse) -> Bool {
        favorites.contains { fav in
            fav.bookName == currentBook.name &&
            fav.chapterNumber == currentChapter.number &&
            fav.verseNumber == verse.number
        }
    }

    private func toggleFavorite(for verse: Verse) {
        if let existing = favorites.first(where: {
            $0.bookName == currentBook.name &&
            $0.chapterNumber == currentChapter.number &&
            $0.verseNumber == verse.number
        }) {
            modelContext.delete(existing)
            try? modelContext.save()
            favoriteToastSymbol = "heart.slash"
            favoriteToastTint = .gray
            favoriteToastText = "Removed Favorite"
        } else {
            let fav = Favorite(
                bookName: currentBook.name,
                chapterNumber: currentChapter.number,
                verseNumber: verse.number,
                verseText: verse.text
            )
            modelContext.insert(fav)
            try? modelContext.save()
            favoriteToastSymbol = "heart.fill"
            favoriteToastTint = .pink
            favoriteToastText = "Added to Favorites"
        }
        withAnimation(.spring()) { showFavoriteToast = true }
        markActivityAndScheduleInactivity()
    }

    // MARK: - Share text helper
    private func shareText(bookName: String, chapter: Int, verse: Int, text: String) -> String {
        "“\(text)” — \(bookName) \(chapter):\(verse)"
    }
}

// MARK: - Search support

private struct SearchResult: Identifiable, Hashable {
    let id = UUID()
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
    let verseText: String
}

private extension ReadingView {
    // Only run search if at least two tokens are present (split on whitespace OR punctuation), mirroring SearchView
    private func eligibleWordCount(in text: String) -> Int {
        let tokens = text
            .lowercased()
            .split { $0.isWhitespace || $0.isPunctuation }
            .map(String.init)
            .filter { !$0.isEmpty }
        return tokens.count
    }

    private func runSearchIfEligible(query: String, force: Bool = false) {
        // Tokenize exactly like SearchView
        let tokens = query
            .lowercased()
            .split { $0.isWhitespace || $0.isPunctuation }
            .map(String.init)
            .filter { !$0.isEmpty }

        // Require at least 2 tokens unless force is true
        guard force || tokens.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true

        // Contains-ALL-tokens match, same as SearchView, but cap at 100 results
        let maxResults = 100
        DispatchQueue.global(qos: .userInitiated).async {
            var results: [SearchResult] = []
            outer: for b in BibleData.books {
                for c in b.chapters {
                    for v in c.verses {
                        let lower = v.text.lowercased()
                        var matchesAll = true
                        for t in tokens {
                            if !lower.contains(t) { matchesAll = false; break }
                        }
                        if matchesAll {
                            results.append(SearchResult(bookName: b.name, chapterNumber: c.number, verseNumber: v.number, verseText: v.text))
                            if results.count >= maxResults { break outer }
                        }
                    }
                }
            }
            DispatchQueue.main.async {
                self.searchResults = results
                self.isSearching = false
            }
        }
    }

    private func jumpToSearchResult(_ item: SearchResult) {
        // 1) Resolve target book and chapter index
        guard let targetBook = BibleData.books.first(where: { $0.name == item.bookName }) else { return }
        let targetChapterIndex = targetBook.chapters.firstIndex(where: { $0.number == item.chapterNumber }) ?? 0
        let targetChapter = targetBook.chapters[targetChapterIndex]

        // 2) Clamp the verse to the actual verse count for that chapter
        let clampedVerse = min(max(1, item.verseNumber), targetChapter.verses.count)

        // 3) Apply state together
        currentBook = targetBook
        if let idx = orderedBookNames.firstIndex(of: targetBook.name) {
            currentBookNameIndex = idx
        }
        currentChapterIndex = targetChapterIndex
        currentVerse = clampedVerse

        // Avoid initial mass-marking; we’ll manage highlight explicitly
        suppressInitialMarking = (clampedVerse > 1)
        hasCompletedInitialAppear = !suppressInitialMarking
        highlightOnAppear = false

        // 4) Defer scrolling until the new chapter is rendered
        Task { @MainActor in
            // Let SwiftUI finish updating the list for the new book/chapter
            await Task.yield()

            // Now scroll to the exact verse row ID
            withAnimation(.easeInOut(duration: 0.35)) {
                topVisibleVerseID = rowID(for: clampedVerse)
            }

            // 5) Highlight the verse for 3 seconds
            highlightedVerse = clampedVerse
            // Re-assert once more on the next run loop to be extra safe
            await Task.yield()
            highlightedVerse = clampedVerse
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            withAnimation { highlightedVerse = nil }
        }

        // 6) Update trackers and progress
        ReadingTimeTracker.shared.changeBook(to: targetBook.name, chapter: targetChapter.number)
        ReadingTimeTracker.shared.setCurrentLocation(bookName: targetBook.name, chapter: targetChapter.number)
        saveProgress(bookName: targetBook.name, chapter: targetChapter.number, verse: clampedVerse)

        // 7) Close sheet
        showSearchSheet = false
    }
}
