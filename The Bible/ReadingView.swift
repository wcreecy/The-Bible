import SwiftUI
import SwiftData

struct ReadingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var progressList: [ReadingProgress]
    @Query private var favorites: [Favorite]
    @Query private var bookmarks: [Bookmark]
    @Query private var notes: [VerseNote]

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
    @State private var topVisibleVerse: Int? = nil
    @State private var lastSavedTopVerse: Int? = nil
    @State private var showFavoriteToast: Bool = false
    @State private var favoriteToastText: String = "Added to Favorites"
    @State private var favoriteToastSymbol: String = "heart.fill"
    @State private var favoriteToastTint: Color = .pink
    @AppStorage("keepScreenOn") private var keepScreenOn: Bool = false
    @State private var showNoteSheet: Bool = false
    @State private var noteDraft: String = ""
    @State private var noteVerseForSheet: Int? = nil
    @State private var pinVerse: Int? = nil

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

    private struct VerseOffset: Equatable {
        let verse: Int
        let minY: CGFloat
    }

    private struct VerseOffsetsKey: PreferenceKey {
        static var defaultValue: [VerseOffset] = []
        static func reduce(value: inout [VerseOffset], nextValue: () -> [VerseOffset]) {
            value.append(contentsOf: nextValue())
        }
    }

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
            .sheet(isPresented: $showNoteSheet) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add Note")
                            .font(.headline)
                        TextEditor(text: $noteDraft)
                            .frame(minHeight: 160)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        Spacer()
                    }
                    .padding()
                    .navigationTitle("Note")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showNoteSheet = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                if let verseNum = noteVerseForSheet,
                                   let verse = currentChapter.verses.first(where: { $0.number == verseNum }) {
                                    saveNote(for: verse, content: noteDraft.trimmingCharacters(in: .whitespacesAndNewlines))
                                }
                                showNoteSheet = false
                            }
                            .disabled(noteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
            .appToast(isPresented: $showFavoriteToast, symbol: favoriteToastSymbol, text: favoriteToastText, tint: favoriteToastTint)
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
                            .overlay(alignment: .trailing) {
                                if pinVerse == verse.number {
                                    Image(systemName: "mappin.and.ellipse")
                                        .foregroundStyle(.blue)
                                        .padding(.trailing, 12)
                                        .transition(.opacity)
                                        .opacity(0.9)
                                    
                                }
                            }
                            .onLongPressGesture(minimumDuration: 0.5) {
                                menuVerse = verse.number
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                let generator = UISelectionFeedbackGenerator()
                                generator.selectionChanged()
                                selectedVerse = verse.number
                                currentVerse = verse.number
                                saveProgress(bookName: currentBook.name, chapter: currentChapter.number, verse: verse.number)
                                // Dismiss any open menu when tapping to select
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
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: VerseOffsetsKey.self,
                                        value: [VerseOffset(verse: verse.number, minY: geo.frame(in: .named("readingScroll")).minY)]
                                    )
                                }
                            )

                            if menuVerse == verse.number {
                                HStack(spacing: 24) {
                                    Button(action: { withAnimation(.easeInOut) { menuVerse = nil } }) { Image(systemName: "doc.on.doc") }
                                        .foregroundStyle(.blue)
                                    Button(action: { withAnimation(.easeInOut) { menuVerse = nil } }) { Image(systemName: "square.and.arrow.up") }
                                        .foregroundStyle(.blue)
                                    Button(action: {
                                        noteVerseForSheet = verse.number
                                        noteDraft = existingNote(for: verse)?.content ?? ""
                                        withAnimation(.easeInOut) { menuVerse = nil }
                                        showNoteSheet = true
                                    }) {
                                        Image(systemName: "note.text")
                                            .symbolVariant(isNoted(verse) ? .fill : .none)
                                    }
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
                    .onPreferenceChange(VerseOffsetsKey.self) { offsets in
                        // Find the verse with the smallest non-negative minY (closest to top). If none, pick the highest minY.
                        let top = offsets
                            .sorted { a, b in a.minY < b.minY }
                            .first(where: { $0.minY >= 0 }) ?? offsets.max(by: { a, b in a.minY < b.minY })
                        if let top = top {
                            topVisibleVerse = top.verse
                            if selectedVerse == nil {
                                if lastSavedTopVerse != top.verse {
                                    saveProgress(bookName: currentBook.name, chapter: currentChapter.number, verse: top.verse)
                                    lastSavedTopVerse = top.verse
                                }
                            }
                        }
                    }
                }
                .coordinateSpace(name: "readingScroll")
                .background(Color.clear.ignoresSafeArea())
                .onChange(of: currentChapterIndex) { _, _ in
                    menuVerse = nil
                    highlightedVerse = nil
                    selectedVerse = nil
                    lastSavedTopVerse = nil
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

    private func existingNote(for verse: Verse) -> VerseNote? {
        notes.first { n in
            n.bookName == currentBook.name && n.chapterNumber == currentChapter.number && n.verseNumber == verse.number
        }
    }

    private func isNoted(_ verse: Verse) -> Bool {
        existingNote(for: verse) != nil
    }

    private func saveNote(for verse: Verse, content: String) {
        if let existing = existingNote(for: verse) {
            existing.content = content
            existing.updatedAt = Date()
            try? modelContext.save()
        } else {
            let note = VerseNote(
                bookName: currentBook.name,
                chapterNumber: currentChapter.number,
                verseNumber: verse.number,
                verseText: verse.text,
                content: content,
                createdAt: Date(),
                updatedAt: Date()
            )
            modelContext.insert(note)
            try? modelContext.save()
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

