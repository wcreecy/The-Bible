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

    init(book: Book, chapter: Chapter, startVerse: Int) {
        self.book = book
        self.chapter = chapter
        self.startVerse = startVerse
        _currentBook = State(initialValue: book)
        _currentChapterIndex = State(initialValue: max(0, chapter.number - 1))
        _currentVerse = State(initialValue: startVerse)
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
                // Load canonical book order once
                Task { @MainActor in
                    await loadOrderedBookNames()
                }
                // Load current pinned verse state from shared defaults
                loadPinnedFromShared()
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
                            saveProgress(bookName: currentBook.name, chapter: currentChapter.number, verse: verse.number)
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
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        withAnimation(.easeOut) { showFavoriteToast = false }
                                    }
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
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        withAnimation(.easeOut) { showFavoriteToast = false }
                                    }
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
                }
                .onAppear {
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            topVisibleVerseID = rowID(for: currentVerse)
                        }
                    }
                    if highlightOnAppear {
                        highlightedVerse = currentVerse
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
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
        saveProgress(bookName: currentBook.name, chapter: currentChapter.number, verse: startVerse)
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.35)) {
                topVisibleVerseID = rowID(for: currentVerse)
            }
        }
    }

    // Load canonical book names and set the current index
    @MainActor
    private func loadOrderedBookNames() async {
        let names = await bibleStore.bookNames()
        // Order according to BibleData order (fallback to names order for any unknowns)
        let canonical = BibleData.books.map { $0.name }
        let pos = Dictionary(uniqueKeysWithValues: canonical.enumerated().map { ($1, $0) })
        let ordered = names.sorted { (a, b) in
            (pos[a] ?? Int.max) < (pos[b] ?? Int.max)
        }
        orderedBookNames = ordered.isEmpty ? canonical : ordered
        currentBookNameIndex = orderedBookNames.firstIndex(of: currentBook.name) ?? currentBookNameIndex
    }

    @MainActor
    private func saveProgress(bookName: String, chapter: Int, verse: Int) {
        let progress = progressList.first ?? ReadingProgress(bookName: bookName, chapterNumber: chapter, verseNumber: verse)
        if progressList.isEmpty { modelContext.insert(progress) }
        progress.bookName = bookName
        progress.chapterNumber = chapter
        progress.verseNumber = verse
        try? modelContext.save()
    }

    // Navigation helpers

    @MainActor
    private func previousChapter() async {
        highlightOnAppear = false
        if currentChapterIndex > 0 {
            currentChapterIndex -= 1
            currentVerse = 1
            saveProgress(bookName: currentBook.name, chapter: currentChapter.number, verse: currentVerse)
            return
        }
        // Move to previous book's last chapter
        guard let idx = currentBookNameIndex, idx > 0 else { return }
        let prevIdx = idx - 1
        let prevName = orderedBookNames[prevIdx]
        if let newBook = await bibleStore.book(named: prevName) {
            currentBook = newBook
            currentBookNameIndex = prevIdx
            currentChapterIndex = max(0, newBook.chapters.count - 1)
            currentVerse = 1
            saveProgress(bookName: currentBook.name, chapter: currentChapter.number, verse: currentVerse)
        }
    }

    @MainActor
    private func nextChapter() async {
        if currentChapterIndex < max(0, currentBook.chapters.count - 1) {
            currentChapterIndex += 1
            currentVerse = 1
            saveProgress(bookName: currentBook.name, chapter: currentChapter.number, verse: currentVerse)
            return
        }
        // Move to next book's first chapter
        guard let idx = currentBookNameIndex, idx < max(0, orderedBookNames.count - 1) else { return }
        let nextIdx = idx + 1
        let nextName = orderedBookNames[nextIdx]
        if let newBook = await bibleStore.book(named: nextName) {
            currentBook = newBook
            currentBookNameIndex = nextIdx
            currentChapterIndex = 0
            currentVerse = 1
            saveProgress(bookName: currentBook.name, chapter: currentChapter.number, verse: currentVerse)
        }
    }

    private func rowID(for verse: Int) -> String {
        "\(currentBookNameIndex ?? 0)-\(currentChapterIndex)-\(verse)"
    }

    private func isFavorited(_ verse: Verse) -> Bool {
        favorites.contains { fav in
            fav.bookName == currentBook.name &&
            fav.chapterNumber == currentChapter.number &&
            fav.verseNumber == verse.number
        }
    }

    private func toggleFavorite(for verse: Verse) {
        if let existing = favorites.first(where: { $0.bookName == currentBook.name && $0.chapterNumber == currentChapter.number && $0.verseNumber == verse.number }) {
            modelContext.delete(existing)
            try? modelContext.save()
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            favoriteToastSymbol = "xmark.circle.fill"
            favoriteToastTint = .red
            favoriteToastText = "Removed Favorite \(currentBook.name) \(currentChapter.number):\(verse.number)"
            withAnimation(.spring()) { showFavoriteToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut) { showFavoriteToast = false }
            }
        } else {
            let fav = Favorite(
                bookName: currentBook.name,
                chapterNumber: currentChapter.number,
                verseNumber: verse.number,
                verseText: verse.text
            )
            modelContext.insert(fav)
            try? modelContext.save()
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            favoriteToastSymbol = "heart.fill"
            favoriteToastTint = .pink
            favoriteToastText = "Favorited \(currentBook.name) \(currentChapter.number):\(verse.number)"
            withAnimation(.spring()) { showFavoriteToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut) { showFavoriteToast = false }
            }
        }
    }
    
    private func openJournalForReference(text: String) {
        journalComposer.present(initialBody: text, verseRef: nil, showTagColors: false)
    }

    // MARK: - Pin to widget

    private func isPinned(_ verseNumber: Int) -> Bool {
        pinnedBookName == currentBook.name &&
        pinnedChapterNumber == currentChapter.number &&
        pinnedVerseNumber == verseNumber
    }

    private func loadPinnedFromShared() {
        guard let shared = UserDefaults(suiteName: "group.bible.app") else {
            pinnedBookName = ""; pinnedChapterNumber = 0; pinnedVerseNumber = 0
            return
        }
        pinnedBookName = shared.string(forKey: "pinnedVerseBook") ?? ""
        pinnedChapterNumber = shared.integer(forKey: "pinnedVerseChapter")
        pinnedVerseNumber = shared.integer(forKey: "pinnedVerseNumber")
        // If no valid values, reset to empty
        if pinnedBookName.isEmpty || pinnedChapterNumber <= 0 || pinnedVerseNumber <= 0 {
            pinnedBookName = ""; pinnedChapterNumber = 0; pinnedVerseNumber = 0
        }
    }

    private func setPinnedVerse(bookName: String, chapter: Int, verse: Int, text: String) {
        if let shared = UserDefaults(suiteName: "group.bible.app") {
            shared.set(bookName, forKey: "pinnedVerseBook")
            shared.set(chapter, forKey: "pinnedVerseChapter")
            shared.set(verse, forKey: "pinnedVerseNumber")
            shared.set(text, forKey: "pinnedVerseText")
        }
        // Update local state for immediate UI reflection
        pinnedBookName = bookName
        pinnedChapterNumber = chapter
        pinnedVerseNumber = verse
        WidgetCenter.shared.reloadTimelines(ofKind: "PinnedVerseWidget")
    }

    private func clearPinnedVerse() {
        if let shared = UserDefaults(suiteName: "group.bible.app") {
            shared.removeObject(forKey: "pinnedVerseBook")
            shared.removeObject(forKey: "pinnedVerseChapter")
            shared.removeObject(forKey: "pinnedVerseNumber")
            shared.removeObject(forKey: "pinnedVerseText")
        }
        pinnedBookName = ""
        pinnedChapterNumber = 0
        pinnedVerseNumber = 0
        WidgetCenter.shared.reloadTimelines(ofKind: "PinnedVerseWidget")
    }
}

#Preview {
    NavigationStack {
        ReadingView(book: BibleData.books.first!, chapter: BibleData.books.first!.chapters.first!, startVerse: 5)
            .modelContainer(for: [ReaderSettings.self, ReadingProgress.self], inMemory: true)
    }
}
