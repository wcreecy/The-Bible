import SwiftUI

struct BooksView: View {
    @Environment(NavigationCoordinator.self) private var coordinator
    let books: [Book]
    @State private var searchText: String = ""
    // Shared preference across devices
    @AppStorage("bibleBooksSortAlphabetical") private var sortAlphabetically: Bool = false

    private var scriptureReference: (reference: ScriptureRef, book: Book, chapter: Chapter)? {
        BibleNavigationReference.resolve(searchText, in: books)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                StudyBibleEntryCard(books: books)

                if let match = scriptureReference {
                    BibleReferenceJumpRow(reference: match.reference, action: openScriptureReference)
                }

                BibleBookSections(
                    books: books,
                    filterText: searchText,
                    alphabetical: sortAlphabetically,
                    onSelect: { coordinator.push(.book($0)) }
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical)
        }
        .background(AppBackgroundView(tab: .bible))
        .navigationTitle("Books")
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Books or a reference"
        )
        .onSubmit(of: .search, openScriptureReference)
        .tint(.accentColor)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    coordinator.push(.search)
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("Search Bible text")

                BibleBookSortMenu(alphabetical: $sortAlphabetically)
            }
        }
    }

    private func openScriptureReference() {
        guard let match = scriptureReference else { return }
        searchText = ""
        coordinator.push(.reader(
            book: match.book,
            chapter: match.chapter,
            startVerse: match.reference.startVerse
        ))
    }
}

/// A dedicated starting point for book background and chapter-level study material.
struct StudyBibleEntryCard: View {
    let books: [Book]

    var body: some View {
        NavigationLink {
            StudyBibleView(books: books)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "graduationcap.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Study the Bible")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Explore book overviews and chapter insights")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(AppDesignMetrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .heroCardSurface()
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens book overviews and chapter insights")
    }
}

/// Browse the Bible's study material independently of the reading-focused book list.
struct StudyBibleView: View {
    let books: [Book]

    @AppStorage("lastStudiedBook") private var lastStudiedBook = ""
    @AppStorage("lastStudiedChapter") private var lastStudiedChapter = 0
    @State private var searchText = ""
    @State private var testamentFilter: StudyTestamentFilter = .all

    private let bookColumns = Array(
        repeating: GridItem(.flexible(), spacing: 10),
        count: 3
    )

    private var displayedBooks: [Book] {
        books.filter { book in
            let matchesSearch = searchText.isEmpty || book.name.localizedCaseInsensitiveContains(searchText)
            return matchesSearch && testamentFilter.includes(book)
        }
    }

    private var continuedBook: Book? {
        books.first { $0.name == lastStudiedBook }
    }

    private var continuedChapter: Int? {
        lastStudiedChapter > 0 ? lastStudiedChapter : nil
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                StudyBibleHeader()

                if let book = continuedBook, let chapterNumber = continuedChapter {
                    ContinueStudyingCard(book: book, chapterNumber: chapterNumber)
                }

                LazyVGrid(columns: bookColumns, alignment: .leading, spacing: 10) {
                    ForEach(displayedBooks) { book in
                        StudyBookTile(book: book)
                    }
                }
            }
            .padding()
        }
        .background(AppBackgroundView(tab: .bible))
        .navigationTitle("Study")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Find a book")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Books", selection: $testamentFilter) {
                        ForEach(StudyTestamentFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                } label: {
                    Label("Filter books", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
    }
}

private enum StudyTestamentFilter: String, CaseIterable, Identifiable {
    case all
    case oldTestament
    case newTestament

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "All Books"
        case .oldTestament: "Old Testament"
        case .newTestament: "New Testament"
        }
    }

    func includes(_ book: Book) -> Bool {
        switch self {
        case .all: true
        case .oldTestament: BibleStudyMetadata.testament(for: book.name) == "Old Testament"
        case .newTestament: BibleStudyMetadata.testament(for: book.name) == "New Testament"
        }
    }
}

enum BibleStudyMetadata {
    private static let newTestamentBooks: Set<String> = [
        "Matthew", "Mark", "Luke", "John", "Acts", "Romans", "1 Corinthians", "2 Corinthians",
        "Galatians", "Ephesians", "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians",
        "1 Timothy", "2 Timothy", "Titus", "Philemon", "Hebrews", "James", "1 Peter", "2 Peter",
        "1 John", "2 John", "3 John", "Jude", "Revelation"
    ]

    static func testament(for bookName: String) -> String {
        newTestamentBooks.contains(bookName) ? "New Testament" : "Old Testament"
    }

    static func genre(for bookName: String) -> String {
        switch bookName {
        case "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy": "Law"
        case "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel", "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah", "Esther", "Acts": "History"
        case "Job", "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon": "Wisdom & Poetry"
        case "Isaiah", "Jeremiah", "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel", "Amos", "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk", "Zephaniah", "Haggai", "Zechariah", "Malachi": "Prophecy"
        case "Matthew", "Mark", "Luke", "John": "Gospel"
        case "Revelation": "Apocalyptic"
        default: "Letter"
        }
    }

    static func readingTip(for bookName: String) -> String {
        switch genre(for: bookName) {
        case "Law": "Read for God’s covenant and the way it shaped Israel’s life together."
        case "History": "Follow the people, setting, and turning points that move the larger story forward."
        case "Wisdom & Poetry": "Read slowly; imagery and parallel lines often carry the point."
        case "Prophecy": "Notice both the original setting and the call to faithfulness and hope."
        case "Gospel": "Watch what Jesus does and says, and how people respond to him."
        case "Apocalyptic": "Read its symbols as a vision of hope and God’s ultimate reign."
        default: "Follow the author’s argument from beginning to end before isolating individual verses."
        }
    }
}

private struct ContinueStudyingCard: View {
    let book: Book
    let chapterNumber: Int

    var body: some View {
        NavigationLink {
            ChapterInsightsView(bookName: book.name, chapterNumber: chapterNumber)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Continue Studying")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("\(book.name) \(chapterNumber)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(AppDesignMetrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .heroCardSurface()
        }
        .buttonStyle(.plain)
    }
}

private struct StudyBibleHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Explore Scripture")
                .font(.title2.weight(.bold))
            Text("Choose a book to read its overview or explore chapter insights.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }
}

private struct StudyBookTile: View {
    let book: Book

    private var verseCount: Int {
        book.chapters.reduce(into: 0) { count, chapter in
            count += chapter.verses.count
        }
    }

    private var chapterCountLabel: String {
        "\(book.chapters.count) \(book.chapters.count == 1 ? "chapter" : "chapters")"
    }

    var body: some View {
        NavigationLink {
            StudyBookView(book: book)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                if let theme = BookChapterTheme.themes[book.name] {
                    BookChapterEmblem(theme: theme, size: 32)
                }

                Text(book.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2, reservesSpace: true)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 2) {
                    Text(chapterCountLabel)
                    Text("\(verseCount) verses")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .frame(
                maxWidth: .infinity,
                minHeight: 154,
                maxHeight: 154,
                alignment: .topLeading
            )
            .padding(12)
            .heroCardSurface()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(book.name), \(chapterCountLabel), \(verseCount) verses")
    }
}

private struct StudyBookView: View {
    let book: Book

    private let columns = [GridItem(.adaptive(minimum: 52), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                NavigationLink {
                    BookOverviewView(bookName: book.name)
                } label: {
                    StudyOverviewCard(bookName: book.name)
                }
                .buttonStyle(.plain)

                HeroCard(title: "Chapter Insights", icon: "lightbulb.max") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose a chapter to explore its themes, people, background, and cross references.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(book.chapters) { chapter in
                                NavigationLink {
                                    ChapterInsightsView(
                                        bookName: book.name,
                                        chapterNumber: chapter.number
                                    )
                                } label: {
                                    Text(chapter.number, format: .number)
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                                }
                                .accessibilityLabel("Chapter \(chapter.number) insights")
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(AppBackgroundView(tab: .bible))
        .navigationTitle(book.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct StudyOverviewCard: View {
    let bookName: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "text.book.closed")
                .font(.title2)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 3) {
                Text("About \(bookName)")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("Read the book overview, story, setting, and key people")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(AppDesignMetrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .heroCardSurface()
    }
}

#Preview {
    NavigationStack {
        BooksView(books: BibleData.books)
            .environment(NavigationCoordinator())
    }
}
