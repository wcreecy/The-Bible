import SwiftUI
import SwiftData

struct ReadingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var progressList: [ReadingProgress]

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
                                    Button(action: {}) { Image(systemName: "doc.on.doc") }
                                        .foregroundStyle(.blue)
                                    Button(action: {}) { Image(systemName: "square.and.arrow.up") }
                                        .foregroundStyle(.blue)
                                    Button(action: {}) { Image(systemName: "note.text") }
                                        .foregroundStyle(.blue)
                                    Button(action: {}) { Image(systemName: "bookmark") }
                                        .foregroundStyle(.blue)
                                    Button(action: {}) { Image(systemName: "heart") }
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
}

#Preview {
    NavigationStack {
        ReadingView(book: BibleData.books.first!, chapter: BibleData.books.first!.chapters.first!, startVerse: 5)
            .modelContainer(for: [ReaderSettings.self, ReadingProgress.self], inMemory: true)
    }
}

