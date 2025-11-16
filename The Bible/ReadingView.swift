import SwiftUI
import SwiftData
import UIKit

struct ReadingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var progressList: [ReadingProgress]
    @Query private var favorites: [Favorite]
    @EnvironmentObject private var journalComposer: JournalComposer

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
    @State private var topVisibleVerseID: String? = nil
    @State private var showFavoriteToast: Bool = false
    @State private var favoriteToastText: String = "Added to Favorites"
    @State private var favoriteToastSymbol: String = "heart.fill"
    @State private var favoriteToastTint: Color = .pink
    @AppStorage("keepScreenOn") private var keepScreenOn: Bool = false
    @State private var pinVerse: Int? = nil

    @StateObject private var bibleStore = BibleStore.shared

    init(book: Book, chapter: Chapter, startVerse: Int) {
        self.book = book
        self.chapter = chapter
        self.startVerse = startVerse
        _currentVerse = State(initialValue: startVerse)
    }

    private var allBooks: [Book] {
        if bibleStore.isReady { return bibleStore.books }
        return [book] // Minimal fallback before store loads
    }

    private var allChapters: [Chapter] { currentBook.chapters }

    private var currentBook: Book {
        if allBooks.indices.contains(currentBookIndex) {
            return allBooks[currentBookIndex]
        }
        // Fallback to passed-in book
        return book
    }

    private var currentChapter: Chapter {
        if allChapters.indices.contains(currentChapterIndex) {
            return allChapters[currentChapterIndex]
        }
        // Fallback to passed-in chapter
        return chapter
    }

    var body: some View {
        content
            .navigationTitle("\(currentBook.name) \(currentChapter.number)")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: onAppear)
            .onAppear {
                bibleStore.ensureLoaded()
                if keepScreenOn {
                    UIApplication.shared.isIdleTimerDisabled = true
                }
                // Initialize indices based on incoming selection
                Task { @MainActor in
                    if bibleStore.isReady {
                        if let bIdx = bibleStore.books.firstIndex(where: { $0.name == book.name }) {
                            currentBookIndex = bIdx
                            let chapters = bibleStore.books[bIdx].chapters
                            if let cIdx = chapters.firstIndex(where: { $0.number == chapter.number }) {
                                currentChapterIndex = cIdx
                            }
                        }
                    } else {
                        // Update once ready
                        Task { @MainActor in
                            while !BibleStore.shared.isReady { try? await Task.sleep(nanoseconds: 20_000_000) }
                            if let bIdx = BibleStore.shared.books.firstIndex(where: { $0.name == book.name }) {
                                currentBookIndex = bIdx
                                let chapters = BibleStore.shared.books[bIdx].chapters
                                if let cIdx = chapters.firstIndex(where: { $0.number == chapter.number }) {
                                    currentChapterIndex = cIdx
                                }
                            }
                        }
                    }
                }
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
            .onChange(of: keepScreenOn) { _, newValue in
                UIApplication.shared.isIdleTimerDisabled = newValue
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
                                Image(systemName: "mappin.circle.fill")
                                    .symbolRenderingMode(.multicolor)
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
                            nextChapter()
                        } else {
                            previousChapter()
                        }
                    }
                }
        )
    }

    private func onAppear() {
        saveProgress(bookName: currentBook.name, chapter: currentChapter.number, verse: startVerse)
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.35)) {
                topVisibleVerseID = rowID(for: currentVerse)
            }
        }
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
            if currentBookIndex > 0 {
                currentBookIndex -= 1
                currentChapterIndex = max(0, currentBook.chapters.count - 1)
            }
        }
        currentVerse = 1
        saveProgress(bookName: currentBook.name, chapter: currentChapter.number, verse: currentVerse)
    }

    private func nextChapter() {
        highlightOnAppear = false
        if currentChapterIndex < allChapters.count - 1 {
            currentChapterIndex += 1
        } else if currentBookIndex < allBooks.count - 1 {
            currentBookIndex += 1
            currentChapterIndex = 0
        } else {
            return
        }
        currentVerse = 1
        saveProgress(bookName: currentBook.name, chapter: currentChapter.number, verse: currentVerse)
    }

    private func rowID(for verse: Int) -> String {
        "\(currentBookIndex)-\(currentChapterIndex)-\(verse)"
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
}

#Preview {
    NavigationStack {
        ReadingView(book: BibleData.books.first!, chapter: BibleData.books.first!.chapters.first!, startVerse: 5)
            .modelContainer(for: [ReaderSettings.self, ReadingProgress.self], inMemory: true)
    }
}
