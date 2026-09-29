import Foundation
import SwiftUI
import WidgetKit
import Combine
import SwiftData

@MainActor
final class ReadingViewModel: ObservableObject {
    // Navigation/state
    @Published var currentBook: Book
    @Published var currentChapterIndex: Int
    @Published var currentVerse: Int

    // Canonical book order
    @Published var orderedBookNames: [String] = []
    @Published var currentBookNameIndex: Int? = nil

    // UI states
    @Published var highlightedVerse: Int? = nil
    @Published var selectedVerse: Int? = nil
    @Published var menuVerse: Int? = nil
    @Published var pinVerse: Int? = nil
    @Published var topVisibleVerseID: String? = nil

    // Search
    @Published var isSearchPresented: Bool = false
    @Published var searchQuery: String = ""
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching: Bool = false

    // Reading progress
    @Published var highlightOnAppear: Bool = true
    private lazy var verseReadingTracker = VerseReadingTracker { updates in
        BibleStatsStore.shared.markVersesSeen(updates)
    }

    // Services
    let pinnedStore: PinnedVerseStore
    private let inactivityMonitor: InactivityMonitor
    private let inactivitySeconds: TimeInterval

    init(book: Book, chapter: Chapter, startVerse: Int, pinnedStore: PinnedVerseStore, inactivitySeconds: TimeInterval = 300) {
        self.currentBook = book
        self.currentChapterIndex = max(0, chapter.number - 1)
        self.currentVerse = startVerse
        self.pinnedStore = pinnedStore
        self.inactivitySeconds = inactivitySeconds
        self.inactivityMonitor = InactivityMonitor(timeout: inactivitySeconds) {
            ReadingTimeTracker.shared.pause()
        }

        loadOrderedBookNames()
        Task { @MainActor in
            await pinnedStore.load()
        }
    }

    var currentChapter: Chapter {
        if currentBook.chapters.indices.contains(currentChapterIndex) {
            return currentBook.chapters[currentChapterIndex]
        }
        return currentBook.chapters.first ?? Chapter(number: 1, verses: [])
    }

    // MARK: - Lifecycle

    func onAppear() {
        // Reading time
        ReadingTimeTracker.shared.start(bookName: currentBook.name, chapter: currentChapter.number)
        ReadingTimeTracker.shared.setCurrentLocation(bookName: currentBook.name, chapter: currentChapter.number)

        // Scroll to initial verse
        topVisibleVerseID = rowID(for: currentVerse)

        // Initial highlight
        if highlightOnAppear {
            highlightedVerse = currentVerse
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                withAnimation { self.highlightedVerse = nil }
            }
            highlightOnAppear = false
        }

        // Inactivity and reading-progress tracking
        verseReadingTracker.setActive(true)
        markActivity()
    }

    func onDisappear() {
        inactivityMonitor.cancel()
        verseReadingTracker.stop()
        ReadingTimeTracker.shared.stopAndFlush()
    }

    func onScenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .active:
            verseReadingTracker.setActive(true)
            ReadingTimeTracker.shared.resume()
            markActivity()
        case .inactive, .background:
            verseReadingTracker.setActive(false)
            ReadingTimeTracker.shared.pause()
            inactivityMonitor.cancel()
        @unknown default:
            break
        }
    }

    func onTabChanged(_ tab: Int) {
        if tab == 1 {
            verseReadingTracker.setActive(true)
            ReadingTimeTracker.shared.resume()
            markActivity()
        } else {
            verseReadingTracker.setActive(false)
            ReadingTimeTracker.shared.pause()
            inactivityMonitor.cancel()
        }
    }

    // MARK: - Activity / Inactivity

    func markActivity() {
        ReadingTimeTracker.shared.resume()
        inactivityMonitor.markActivity()
    }

    // MARK: - Verse reading progress

    func verseVisibilityChanged(_ update: SeenVerseUpdate, isVisible: Bool) {
        guard update.bookName == currentBook.name,
              update.chapter == currentChapter.number else { return }
        verseReadingTracker.visibilityChanged(update, isVisible: isVisible)
    }

    func recordDirectEngagement(with update: SeenVerseUpdate) {
        verseReadingTracker.recordDirectEngagement(update)
    }

    // MARK: - Verse interactions

    func handleVerseTap(context: ModelContext, verse: Verse) {
        // Tap should only select/highlight the verse (no bookmarking)
        selectedVerse = verse.number
        currentVerse = verse.number

        // Update tracker location
        ReadingTimeTracker.shared.setCurrentLocation(bookName: currentBook.name, chapter: currentChapter.number)

        recordDirectEngagement(with: SeenVerseUpdate(
            bookName: currentBook.name,
            chapter: currentChapter.number,
            verse: verse.number,
            totalVerses: currentChapter.verses.count
        ))

        // Activity
        markActivity()
    }

    func handleVerseLongPress(verseNumber: Int) {
        menuVerse = verseNumber
        recordDirectEngagement(with: SeenVerseUpdate(
            bookName: currentBook.name,
            chapter: currentChapter.number,
            verse: verseNumber,
            totalVerses: currentChapter.verses.count
        ))
        markActivity()
    }

    func clearMenuIfNeeded() {
        if menuVerse != nil { menuVerse = nil }
    }

    // MARK: - Bookmark (Continue Reading / Last Read)

    func bookmarkVerse(context: ModelContext, verse: Verse) throws {
        // Persist Continue Reading before updating its mirrors.
        try ReadingProgressStore.save(in: context, bookName: currentBook.name, chapter: currentChapter.number, verse: verse.number)

        // Mirror Last Read for widget (App Group + iCloud KVS)
        mirrorLastReadToAppGroup(bookName: currentBook.name, chapter: currentChapter.number, verse: verse.number, text: verse.text)

        // Also persist Stats "Last Read" (cross‑device, used by StatsView)
        BibleStatsStore.shared.saveLastRead(bookName: currentBook.name, chapterNumber: currentChapter.number, date: Date())

        // Update tracker location
        ReadingTimeTracker.shared.setCurrentLocation(bookName: currentBook.name, chapter: currentChapter.number)

        // Activity
        markActivity()
    }

    // MARK: - Pinned verse

    func isPinned(_ verseNumber: Int) -> Bool {
        pinnedStore.isPinned(bookName: currentBook.name, chapter: currentChapter.number, verse: verseNumber)
    }

    func togglePin(verseNumber: Int, verseText: String) async -> Bool {
        if isPinned(verseNumber) {
            await pinnedStore.clear()
            return false
        } else {
            await pinnedStore.set(bookName: currentBook.name, chapter: currentChapter.number, verse: verseNumber, text: verseText)
            return true
        }
    }

    // MARK: - Navigation

    func nextChapter() {
        guard let bookIdx = indexOfCurrentBookInCanonical() else { return }
        let chapters = currentBook.chapters
        if currentChapterIndex + 1 < chapters.count {
            currentChapterIndex += 1
            currentVerse = 1
            topVisibleVerseID = rowID(for: 1)
            Haptics.selection()
            ReadingTimeTracker.shared.setCurrentLocation(bookName: currentBook.name, chapter: currentChapter.number)
            resetInitialMarkingAfterChapterChange()
            markActivity()
            return
        }
        // Next book
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
        resetInitialMarkingAfterChapterChange()
        Haptics.selection()
        markActivity()
    }

    func previousChapter() {
        guard let bookIdx = indexOfCurrentBookInCanonical() else { return }
        if currentChapterIndex - 1 >= 0 {
            currentChapterIndex -= 1
            currentVerse = 1
            topVisibleVerseID = rowID(for: 1)
            Haptics.selection()
            ReadingTimeTracker.shared.setCurrentLocation(bookName: currentBook.name, chapter: currentChapter.number)
            resetInitialMarkingAfterChapterChange()
            markActivity()
            return
        }
        // Previous book
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
        resetInitialMarkingAfterChapterChange()
        Haptics.selection()
        markActivity()
    }

    private func resetInitialMarkingAfterChapterChange() {
        verseReadingTracker.resetVisibility()
        menuVerse = nil
        highlightedVerse = nil
        selectedVerse = nil
    }

    private func indexOfCurrentBookInCanonical() -> Int? {
        if let idx = currentBookNameIndex { return idx }
        return orderedBookNames.firstIndex(of: currentBook.name)
    }

    private func loadOrderedBookNames() {
        let names = BibleData.books.map { $0.name }
        orderedBookNames = names
        currentBookNameIndex = names.firstIndex(of: currentBook.name)
    }

    // MARK: - IDs

    func rowID(for verseNumber: Int) -> String {
        "\(currentBook.name)-\(currentChapter.number)-\(verseNumber)"
    }

    // MARK: - Search

    struct SearchResult: Identifiable, Hashable {
        let id = UUID()
        let bookName: String
        let chapterNumber: Int
        let verseNumber: Int
        let verseText: String
    }

    func eligibleWordCount(in text: String) -> Int {
        let tokens = text
            .lowercased()
            .split { $0.isWhitespace || $0.isPunctuation }
            .map(String.init)
            .filter { !$0.isEmpty }
        return tokens.count
    }

    func runSearchIfEligible(query: String, force: Bool = false) {
        let tokens = query
            .lowercased()
            .split { $0.isWhitespace || $0.isPunctuation }
            .map(String.init)
            .filter { !$0.isEmpty }

        guard force || tokens.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
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
                            results.append(.init(bookName: b.name, chapterNumber: c.number, verseNumber: v.number, verseText: v.text))
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

    func jumpToSearchResult(_ item: SearchResult) {
        guard let targetBook = BibleData.books.first(where: { $0.name == item.bookName }) else { return }
        let targetChapterIndex = targetBook.chapters.firstIndex(where: { $0.number == item.chapterNumber }) ?? 0
        let targetChapter = targetBook.chapters[targetChapterIndex]
        let clampedVerse = min(max(1, item.verseNumber), targetChapter.verses.count)

        verseReadingTracker.resetVisibility()
        currentBook = targetBook
        if let idx = orderedBookNames.firstIndex(of: targetBook.name) {
            currentBookNameIndex = idx
        }
        currentChapterIndex = targetChapterIndex
        currentVerse = clampedVerse

        highlightOnAppear = false

        Task { @MainActor in
            await Task.yield()
            withAnimation(.easeInOut(duration: 0.35)) {
                topVisibleVerseID = rowID(for: clampedVerse)
            }
            highlightedVerse = clampedVerse
            await Task.yield()
            highlightedVerse = clampedVerse
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            withAnimation { highlightedVerse = nil }
        }

        ReadingTimeTracker.shared.changeBook(to: targetBook.name, chapter: targetChapter.number)
        ReadingTimeTracker.shared.setCurrentLocation(bookName: targetBook.name, chapter: targetChapter.number)

        isSearchPresented = false
    }

    // MARK: - Widget mirroring (Last Read)

    private func mirrorLastReadToAppGroup(bookName: String, chapter: Int, verse: Int, text: String) {
        // Local device: App Group (for widgets on this device)
        if let shared = UserDefaults(suiteName: "group.bible.app") {
            shared.set(bookName, forKey: "lastReadBook")
            shared.set(chapter, forKey: "lastReadChapter")
            shared.set(verse, forKey: "lastReadVerse")
            shared.set(text, forKey: "lastReadText")
        }

        // Cross-device: iCloud KVS (so other devices’ widgets can read without launching the app)
        let kvs = NSUbiquitousKeyValueStore.default
        kvs.set(bookName, forKey: "lastReadBook")
        kvs.set(Int64(chapter), forKey: "lastReadChapter")
        kvs.set(Int64(verse), forKey: "lastReadVerse")
        kvs.set(text, forKey: "lastReadText")
        kvs.synchronize()

        // Nudge widgets locally
        DebouncedWidgetReloader.shared.reload(kind: "LastReadWidget")
    }
}

@MainActor
final class VerseReadingTracker {
    private let dwellNanoseconds: UInt64
    private let batchNanoseconds: UInt64
    private let commit: (Set<SeenVerseUpdate>) -> Void

    private var isActive = false
    private var visibleUpdates: Set<SeenVerseUpdate> = []
    private var dwellTasks: [SeenVerseUpdate: Task<Void, Never>] = [:]
    private var recognizedUpdates: Set<SeenVerseUpdate> = []
    private var pendingUpdates: Set<SeenVerseUpdate> = []
    private var batchTask: Task<Void, Never>?

    init(
        dwellDuration: TimeInterval = 5,
        batchDuration: TimeInterval = 1,
        commit: @escaping (Set<SeenVerseUpdate>) -> Void
    ) {
        dwellNanoseconds = Self.nanoseconds(for: dwellDuration)
        batchNanoseconds = Self.nanoseconds(for: batchDuration)
        self.commit = commit
    }

    func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active

        if active {
            for update in visibleUpdates {
                scheduleDwell(for: update)
            }
        } else {
            cancelDwellTasks()
            flush()
        }
    }

    func visibilityChanged(_ update: SeenVerseUpdate, isVisible: Bool) {
        if isVisible {
            visibleUpdates.insert(update)
            scheduleDwell(for: update)
        } else {
            visibleUpdates.remove(update)
            dwellTasks.removeValue(forKey: update)?.cancel()
        }
    }

    func recordDirectEngagement(_ update: SeenVerseUpdate) {
        dwellTasks.removeValue(forKey: update)?.cancel()
        enqueue(update)
    }

    func resetVisibility() {
        visibleUpdates.removeAll()
        cancelDwellTasks()
        flush()
    }

    func stop() {
        isActive = false
        resetVisibility()
    }

    private func scheduleDwell(for update: SeenVerseUpdate) {
        guard isActive,
              visibleUpdates.contains(update),
              recognizedUpdates.contains(update) == false,
              dwellTasks[update] == nil else { return }

        dwellTasks[update] = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: dwellNanoseconds)
            } catch {
                return
            }

            guard isActive, visibleUpdates.contains(update) else { return }
            dwellTasks[update] = nil
            enqueue(update)
        }
    }

    private func enqueue(_ update: SeenVerseUpdate) {
        guard recognizedUpdates.insert(update).inserted else { return }
        pendingUpdates.insert(update)
        guard batchTask == nil else { return }

        batchTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: batchNanoseconds)
            } catch {
                return
            }
            flush()
        }
    }

    private func flush() {
        batchTask?.cancel()
        batchTask = nil
        guard pendingUpdates.isEmpty == false else { return }
        let updates = pendingUpdates
        pendingUpdates.removeAll()
        commit(updates)
    }

    private func cancelDwellTasks() {
        for task in dwellTasks.values {
            task.cancel()
        }
        dwellTasks.removeAll()
    }

    private static func nanoseconds(for duration: TimeInterval) -> UInt64 {
        UInt64(max(0, duration) * 1_000_000_000)
    }
}
