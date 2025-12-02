import SwiftUI
import SwiftData
import UIKit
import WidgetKit

struct ReadingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var progressList: [ReadingProgress]
    @Query private var favorites: [Favorite]
    @EnvironmentObject private var journalComposer: JournalComposer

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
            .onAppear(perform: onAppear)
            .onAppear {
                // Start reading-time tracking for this book (with chapter info)
                ReadingTimeTracker.shared.start(bookName: currentBook.name, chapter: currentChapter.number)

                // Also keep current location up to date
                ReadingTimeTracker.shared.setCurrentLocation(bookName: currentBook.name, chapter: currentChapter.number)

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
            }
            .onDisappear {
                // Stop and flush reading-time tracking
                ReadingTimeTracker.shared.stopAndFlush()
            }
            .appToast(isPresented: $showFavoriteToast, symbol: favoriteToastSymbol, text: favoriteToastText, tint: favoriteToastTint)
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
                                }) {
                                    Image(systemName: isPinned(verse.number) ? "pin.fill" : "pin")
                                }
                                .foregroundStyle(.red)

                                Button(action: {
                                    toggleFavorite(for: verse)
                                    withAnimation(.easeInOut) { menuVerse = nil }
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
                }
                .onTapGesture {
                    if menuVerse != nil { menuVerse = nil }
                }
            }
            .scrollPosition(id: $topVisibleVerseID, anchor: .top)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
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
        // Keep a single ReadingProgress record (replace or update)
        if let existing = progressList.first {
            existing.bookName = bookName
            existing.chapterNumber = chapter
            existing.verseNumber = verse
            try? modelContext.save()
        } else {
            let p = ReadingProgress()
            modelContext.insert(p)
            try? modelContext.save()
        }
    }

    // MARK: - Navigation across chapters/books (canonical order)
    private func indexOfCurrentBookInCanonical() -> Int? {
        if let idx = currentBookNameIndex {
            return idx
        }
        return orderedBookNames.firstIndex(of: currentBook.name)
    }

    @MainActor
    private func nextChapter() async {
        guard let bookIdx = indexOfCurrentBookInCanonical() else { return }
        let chapters = currentBook.chapters
        if currentChapterIndex + 1 < chapters.count {
            currentChapterIndex += 1
            currentVerse = 1
            topVisibleVerseID = rowID(for: 1)
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
    }

    @MainActor
    private func previousChapter() async {
        guard let bookIdx = indexOfCurrentBookInCanonical() else { return }
        if currentChapterIndex - 1 >= 0 {
            currentChapterIndex -= 1
            currentVerse = 1
            topVisibleVerseID = rowID(for: 1)
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
    }

    // MARK: - Share text helper
    private func shareText(bookName: String, chapter: Int, verse: Int, text: String) -> String {
        "“\(text)” — \(bookName) \(chapter):\(verse)"
    }
}
