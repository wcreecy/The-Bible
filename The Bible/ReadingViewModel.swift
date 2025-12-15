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

    // Initial marking guard
    @Published var hasCompletedInitialAppear: Bool = false
    @Published var suppressInitialMarking: Bool = false
    @Published var highlightOnAppear: Bool = true

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

        self.suppressInitialMarking = (startVerse > 1)
        loadOrderedBookNames()
        pinnedStore.load()
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

        // Inactivity arming
        markActivity()

        // Configure initial mass-marking suppression
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
    }

    func onDisappear() {
        inactivityMonitor.cancel()
        ReadingTimeTracker.shared.stopAndFlush()
    }

    func onScenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .active:
            ReadingTimeTracker.shared.resume()
            markActivity()
        case .inactive, .background:
            ReadingTimeTracker.shared.pause()
            inactivityMonitor.cancel()
        @unknown default:
            break
        }
    }

    func onTabChanged(_ tab: Int) {
        if tab == 1 {
            ReadingTimeTracker.shared.resume()
            markActivity()
        } else {
            ReadingTimeTracker.shared.pause()
            inactivityMonitor.cancel()
        }
    }

    // MARK: - Activity / Inactivity

    func markActivity() {
        ReadingTimeTracker.shared.resume()
        inactivityMonitor.markActivity()
    }

    // MARK: - Verse-seen marking

    func markVerseSeenIfAllowed(verse: Int, totalVerses: Int) {
        if suppressInitialMarking && !hasCompletedInitialAppear { return }
        BibleStatsStore.shared.markVerseSeen(
            bookName: currentBook.name,
            chapter: currentChapter.number,
            verse: verse,
            totalVerses: totalVerses
        )
    }

    // MARK: - Verse interactions

    func handleVerseTap(context: ModelContext, verse: Verse) {
        selectedVerse = verse.number
        currentVerse = verse.number

        // Persist Continue Reading
        ReadingProgressStore.save(in: context, bookName: currentBook.name, chapter: currentChapter.number, verse: verse.number)

        // Mirror Last Read for widget
        mirrorLastReadToAppGroup(bookName: currentBook.name, chapter: currentChapter.number, verse: verse.number, text: verse.text)

        // Update tracker location
        ReadingTimeTracker.shared.setCurrentLocation(bookName: currentBook.name, chapter: currentChapter.number)

        // Pin flash animation
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            pinVerse = verse.number
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            withAnimation(.easeOut) {
                if self.pinVerse == verse.number {
                    self.pinVerse = nil
                }
            }
        }

        // Activity
        markActivity()
    }

    func handleVerseLongPress(verseNumber: Int) {
        menuVerse = verseNumber
        markActivity()
    }

    func clearMenuIfNeeded() {
        if menuVerse != nil { menuVerse = nil }
    }

    // MARK: - Pinned verse

    func isPinned(_ verseNumber: Int) -> Bool {
        pinnedStore.isPinned(bookName: currentBook.name, chapter: currentChapter.number, verse: verseNumber)
    }

    func togglePin(verseNumber: Int, verseText: String) -> Bool {
        if isPinned(verseNumber) {
            pinnedStore.clear()
            return false
        } else {
            pinnedStore.set(bookName: currentBook.name, chapter: currentChapter.number, verse: verseNumber, text: verseText)
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
            playImpact(.light)
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
        playImpact(.heavy)
        markActivity()
    }

    func previousChapter() {
        guard let bookIdx = indexOfCurrentBookInCanonical() else { return }
        if currentChapterIndex - 1 >= 0 {
            currentChapterIndex -= 1
            currentVerse = 1
            topVisibleVerseID = rowID(for: 1)
            playImpact(.light)
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
        playImpact(.heavy)
        markActivity()
    }

    private func resetInitialMarkingAfterChapterChange() {
        menuVerse = nil
        highlightedVerse = nil
        selectedVerse = nil
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

        currentBook = targetBook
        if let idx = orderedBookNames.firstIndex(of: targetBook.name) {
            currentBookNameIndex = idx
        }
        currentChapterIndex = targetChapterIndex
        currentVerse = clampedVerse

        suppressInitialMarking = (clampedVerse > 1)
        hasCompletedInitialAppear = !suppressInitialMarking
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
        guard let shared = UserDefaults(suiteName: "group.bible.app") else { return }
        shared.set(bookName, forKey: "lastReadBook")
        shared.set(chapter, forKey: "lastReadChapter")
        shared.set(verse, forKey: "lastReadVerse")
        shared.set(text, forKey: "lastReadText")
        DebouncedWidgetReloader.shared.reload(kind: "LastReadWidget")
    }

    // MARK: - Haptics

    private func playImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        #if canImport(UIKit)
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.impactOccurred()
        #endif
    }
}
