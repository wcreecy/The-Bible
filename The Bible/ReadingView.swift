import SwiftUI
import SwiftData

struct ReadingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var progressList: [ReadingProgress]
    @Query private var favorites: [Favorite]
    @Query private var bookmarks: [Bookmark]

    let book: Book
    let chapter: Chapter
    let startVerse: Int

    @State private var currentChapterIndex: Int = 0
    @State private var currentVerse: Int
    @State private var currentBookIndex: Int = 0
    @State private var highlightOnAppear: Bool = true
    @State private var highlightedVerse: Int? = nil
    @State private var menuVerse: Int? = nil
    @State private var selectedVerse: Int? = nil
    @State private var showFavoriteToast: Bool = false
    @State private var favoriteToastText: String = "Added to Favorites"
    @State private var favoriteToastSymbol: String = "heart.fill"
    @State private var favoriteToastTint: Color = .pink
    @AppStorage("keepScreenOn") private var keepScreenOn: Bool = false

    init(book: Book, chapter: Chapter, startVerse: Int) {
        self.book = book
        self.chapter = chapter
        self.startVerse = startVerse
        _currentVerse = State(initialValue: startVerse)

        // Initialize indices based on incoming selection to avoid defaulting to Genesis 1:1
        let books = BibleData.books
        if let bIdx = books.firstIndex(where: { $0.name == book.name }) {
            _currentBookIndex = State(initialValue: bIdx)
            let chapters = books[bIdx].chapters
            if let cIdx = chapters.firstIndex(where: { $0.number == chapter.number }) {
                _currentChapterIndex = State(initialValue: cIdx)
            }
        }
    }

    private var allBooks: [Book] { BibleData.books }

    private var allChapters: [Chapter] { currentBook.chapters }

    private var currentBook: Book { allBooks[currentBookIndex] }

    private var currentChapter: Chapter { allChapters[currentChapterIndex] }

    var body: some View {
        content
            .navigationTitle("\(currentBook.name) \(currentChapter.number)")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: onAppear)
            .onAppear {
                if keepScreenOn {
                    UIApplication.shared.isIdleTimerDisabled = true
                }
            }
            .onDisappear {
                // Restore default behavior when leaving the reader
                UIApplication.shared.isIdleTimerDisabled = false
            }
            .onChange(of: keepScreenOn) { _, newValue in
                UIApplication.shared.isIdleTimerDisabled = newValue
            }
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(currentChapter.verses) { verse in
                            Group {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(verse.text)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text("\(currentBook.name) \(currentChapter.number):\(verse.number)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal)
                            }
                            .id(verseID(for: verse.number))
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background((highlightedVerse == verse.number || selectedVerse == verse.number) ? Color.yellow.opacity(0.25) : Color.clear)
                            .animation(.easeInOut(duration: 0.6), value: highlightedVerse)
                            .animation(.easeInOut(duration: 0.2), value: selectedVerse)
                            .onLongPressGesture(minimumDuration: 0.5) {
                                menuVerse = verse.number
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                let generator = UISelectionFeedbackGenerator()
                                generator.selectionChanged()
                                selectedVerse = verse.number
                                // Dismiss any open menu when tapping to select
                                if menuVerse != nil { menuVerse = nil }
                            }

                            if menuVerse == verse.number {
                                HStack(spacing: 24) {
                                    Button(action: { withAnimation(.easeInOut) { menuVerse = nil } }) { Image(systemName: "doc.on.doc") }
                                        .foregroundStyle(.blue)
                                    Button(action: { withAnimation(.easeInOut) { menuVerse = nil } }) { Image(systemName: "square.and.arrow.up") }
                                        .foregroundStyle(.blue)
                                    Button(action: { withAnimation(.easeInOut) { menuVerse = nil } }) { Image(systemName: "note.text") }
                                        .foregroundStyle(.blue)
                                    Button(action: {
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred()
                                        if isBookmarked(verse) {
                                            removeBookmark(for: verse)
                                            favoriteToastSymbol = "bookmark.slash.fill"
                                            favoriteToastTint = .red
                                            favoriteToastText = "Removed from Favorites"
                                            withAnimation(.spring()) { showFavoriteToast = true }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                                withAnimation(.easeOut) { showFavoriteToast = false }
                                            }
                                        } else {
                                            let added = addBookmark(for: verse)
                                            if added {
                                                favoriteToastSymbol = "bookmark.fill"
                                                favoriteToastTint = .blue
                                                favoriteToastText = "Bookmarked \(currentBook.name) \(currentChapter.number):\(verse.number)"
                                                withAnimation(.spring()) { showFavoriteToast = true }
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                                    withAnimation(.easeOut) { showFavoriteToast = false }
                                                }
                                            }
                                        }
                                        withAnimation(.easeInOut) { menuVerse = nil }
                                    }) { Image(systemName: isBookmarked(verse) ? "bookmark.fill" : "bookmark") }
                                        .foregroundStyle(.blue)
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

                            // Divider between verses
                            if verse.number != currentChapter.verses.count {
                                Divider()
                            }
                        }
                    }
                    .padding(.vertical)
                }
                .background(Color.clear.ignoresSafeArea())
                .onChange(of: currentChapterIndex) { _, _ in
                    menuVerse = nil
                    highlightedVerse = nil
                    selectedVerse = nil
                    // When chapter changes, scroll to the top
                    DispatchQueue.main.async {
                        withAnimation { proxy.scrollTo(verseID(for: 1), anchor: .top) }
                    }
                }
                .onAppear {
                    DispatchQueue.main.async {
                        withAnimation { proxy.scrollTo(verseID(for: currentVerse), anchor: .top) }
                    }
                    if highlightOnAppear {
                        highlightedVerse = currentVerse
                        // Clear highlight after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation { highlightedVerse = nil }
                        }
                        // Ensure we don't highlight on subsequent chapter changes/swipes
                        highlightOnAppear = false
                    }
                }
                .onTapGesture {
                    if menuVerse != nil { menuVerse = nil }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showFavoriteToast {
                HStack(spacing: 8) {
                    Image(systemName: favoriteToastSymbol)
                        .foregroundStyle(favoriteToastTint)
                    Text(favoriteToastText)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(.quaternary, lineWidth: 0.5)
                )
                .padding(.bottom, 20)
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = value.translation.height
                    // Only act on mostly-horizontal swipes with sufficient distance
                    if abs(horizontal) > abs(vertical) && abs(horizontal) > 40 {
                        if horizontal < 0 {
                            // Swipe left: next chapter
                            nextChapter()
                        } else {
                            // Swipe right: previous chapter
                            previousChapter()
                        }
                    }
                }
        )
    }

    private func onAppear() {
        // Update progress to the current location
        saveProgress(bookName: currentBook.name, chapter: currentChapter.number, verse: startVerse)
    }

    private func saveProgress(bookName: String, chapter: Int, verse: Int) {
        let progress = progressList.first ?? ReadingProgress(bookName: bookName, chapterNumber: chapter, verseNumber: verse)
        if progressList.isEmpty { modelContext.insert(progress) }
        progress.bookName = bookName
        progress.chapterNumber = chapter
        progress.verseNumber = verse
        try? modelContext.save()
    }

    private func previousChapter() {
        highlightOnAppear = false
        guard currentChapterIndex > 0 || currentBookIndex > 0 else { return }
        if currentChapterIndex > 0 {
            currentChapterIndex -= 1
        } else {
            // Move to previous book's last chapter
            currentBookIndex -= 1
            currentChapterIndex = max(0, currentBook.chapters.count - 1)
        }
        currentVerse = 1
        saveProgress(bookName: currentBook.name, chapter: currentChapter.number, verse: currentVerse)
    }

    private func nextChapter() {
        highlightOnAppear = false
        if currentChapterIndex < allChapters.count - 1 {
            currentChapterIndex += 1
        } else if currentBookIndex < allBooks.count - 1 {
            // Move to next book's first chapter
            currentBookIndex += 1
            currentChapterIndex = 0
        } else {
            return
        }
        currentVerse = 1
        saveProgress(bookName: currentBook.name, chapter: currentChapter.number, verse: currentVerse)
    }

    private func verseID(for number: Int) -> String {
        "\(currentBookIndex)-\(currentChapterIndex)-\(number)"
    }

    private func isFavorited(_ verse: Verse) -> Bool {
        favorites.contains { fav in
            fav.bookName == currentBook.name &&
            fav.chapterNumber == currentChapter.number &&
            fav.verseNumber == verse.number
        }
    }

    private func isBookmarked(_ verse: Verse) -> Bool {
        bookmarks.contains { bm in
            bm.bookName == currentBook.name &&
            bm.chapterNumber == currentChapter.number &&
            bm.verseNumber == verse.number
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
    
    @discardableResult
    private func addBookmark(for verse: Verse) -> Bool {
        // Avoid duplicate bookmarks for the same verse
        if isBookmarked(verse) { return false }
        let bookmark = Bookmark(
            bookName: currentBook.name,
            chapterNumber: currentChapter.number,
            verseNumber: verse.number,
            verseText: verse.text
        )
        modelContext.insert(bookmark)
        try? modelContext.save()
        return true
    }
    
    private func removeBookmark(for verse: Verse) {
        if let existing = bookmarks.first(where: { $0.bookName == currentBook.name && $0.chapterNumber == currentChapter.number && $0.verseNumber == verse.number }) {
            modelContext.delete(existing)
            try? modelContext.save()
        }
    }
}

#Preview {
    NavigationStack {
        ReadingView(book: BibleData.books.first!, chapter: BibleData.books.first!.chapters.first!, startVerse: 5)
            .modelContainer(for: [ReaderSettings.self, ReadingProgress.self], inMemory: true)
    }
}
