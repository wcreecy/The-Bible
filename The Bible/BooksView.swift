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
        .tabBarContentClearance()
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
                    Text("Bible Study")
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
    var isBooksPaneHidden = false
    /// Set by the iPad split view so a chosen book is also selected in the Books pane;
    /// otherwise each book pushes its study page.
    var onSelectBook: ((Book) -> Void)?

    @AppStorage("lastStudiedBook") private var lastStudiedBook = ""
    @AppStorage("lastStudiedChapter") private var lastStudiedChapter = 0
    @AppStorage("openLastStudiedChapter") private var shouldOpenLastStudiedChapter = false
    @AppStorage("openLastStudiedBookOverview") private var shouldOpenLastStudiedBookOverview = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var requestedChapter: StudyChapterRequest?
    @State private var requestedBookOverview: StudyBookOverviewRequest?
    @State private var studyTimeSourceID = UUID()
    @State private var searchText = ""
    @State private var testamentFilter: StudyTestamentFilter = .all
    @AppStorage("studyBooksSortAlphabetical") private var sortAlphabetically = false

    private func bookColumns(for availableWidth: CGFloat) -> [GridItem] {
        let columnCount: Int

        if horizontalSizeClass == .compact {
            columnCount = 3
        } else if isBooksPaneHidden && availableWidth >= 800 {
            columnCount = 8
        } else if availableWidth >= 800 {
            columnCount = 6
        } else if availableWidth >= 700 {
            columnCount = 5
        } else {
            columnCount = 4
        }

        return Array(
            repeating: GridItem(.flexible(), spacing: 10),
            count: columnCount
        )
    }

    private var displayedBooks: [Book] {
        let filtered = books.filter { book in
            let matchesSearch = searchText.isEmpty || book.name.localizedCaseInsensitiveContains(searchText)
            return matchesSearch && testamentFilter.includes(book)
        }

        guard sortAlphabetically else { return filtered }
        return filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var continuedBook: Book? {
        books.first { $0.name == lastStudiedBook }
    }

    private var continuedChapter: Int? {
        lastStudiedChapter > 0 ? lastStudiedChapter : nil
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    StudyBibleHeader()

                    if let book = continuedBook, let chapterNumber = continuedChapter {
                        ContinueStudyingCard(book: book, chapterNumber: chapterNumber)
                    }

                    LazyVGrid(
                        columns: bookColumns(for: geometry.size.width - 32),
                        alignment: .leading,
                        spacing: 10
                    ) {
                        ForEach(displayedBooks) { book in
                            StudyBookTile(book: book, onSelect: onSelectBook)
                        }
                    }
                }
                .padding()
            }
            .tabBarContentClearance()
            .background(AppBackgroundView(tab: .bible))
            .accessibilityIdentifier("studyBibleView")
            .navigationTitle("Study")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Find a book")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    BibleBookSortMenu(alphabetical: $sortAlphabetically)

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
        .navigationDestination(item: $requestedChapter) { request in
            ChapterInsightsView(bookName: request.bookName, chapterNumber: request.chapterNumber)
        }
        .navigationDestination(item: $requestedBookOverview) { request in
            BookOverviewView(bookName: request.bookName)
        }
        .onAppear {
            StudyTimeTracker.shared.start(studyTimeSourceID)

            if shouldOpenLastStudiedBookOverview, !lastStudiedBook.isEmpty {
                shouldOpenLastStudiedBookOverview = false
                requestedBookOverview = StudyBookOverviewRequest(bookName: lastStudiedBook)
            } else if shouldOpenLastStudiedChapter, !lastStudiedBook.isEmpty, lastStudiedChapter > 0 {
                shouldOpenLastStudiedChapter = false
                requestedChapter = StudyChapterRequest(
                    bookName: lastStudiedBook,
                    chapterNumber: lastStudiedChapter
                )
            }
        }
        .onDisappear {
            StudyTimeTracker.shared.stop(studyTimeSourceID)
        }
    }
}

private struct StudyChapterRequest: Hashable, Identifiable {
    let bookName: String
    let chapterNumber: Int
    let id = UUID()
}

private struct StudyBookOverviewRequest: Hashable, Identifiable {
    let bookName: String
    let id = UUID()
}

private enum StudyTestamentFilter: String, CaseIterable, Identifiable {
    case all
    case oldTestament
    case newTestament
    case law
    case history
    case poetry
    case majorProphets
    case minorProphets
    case gospels
    case epistles

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "All Books"
        case .oldTestament: "Old Testament"
        case .newTestament: "New Testament"
        case .law: "Law"
        case .history: "History"
        case .poetry: "Poetry"
        case .majorProphets: "Major Prophets"
        case .minorProphets: "Minor Prophets"
        case .gospels: "Gospels"
        case .epistles: "Epistles"
        }
    }

    func includes(_ book: Book) -> Bool {
        switch self {
        case .all: true
        case .oldTestament: BibleStudyMetadata.testament(for: book.name) == "Old Testament"
        case .newTestament: BibleStudyMetadata.testament(for: book.name) == "New Testament"
        case .law, .history, .poetry, .majorProphets, .minorProphets, .gospels, .epistles:
            BibleStudyMetadata.studyFilter(for: book.name) == self
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

    fileprivate static func studyFilter(for bookName: String) -> StudyTestamentFilter? {
        switch bookName {
        case "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy":
            .law
        case "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel", "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah", "Esther", "Acts":
            .history
        case "Job", "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon":

            .poetry
        case "Isaiah", "Jeremiah", "Lamentations", "Ezekiel", "Daniel":
            .majorProphets
        case "Hosea", "Joel", "Amos", "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk", "Zephaniah", "Haggai", "Zechariah", "Malachi":
            .minorProphets
        case "Matthew", "Mark", "Luke", "John":
            .gospels
        case "Romans", "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians", "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians", "1 Timothy", "2 Timothy", "Titus", "Philemon", "Hebrews", "James", "1 Peter", "2 Peter", "1 John", "2 John", "3 John", "Jude":
            .epistles
        default:
            nil
        }
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
    let onSelect: ((Book) -> Void)?

    private var verseCount: Int {
        book.chapters.reduce(into: 0) { count, chapter in
            count += chapter.verses.count
        }
    }

    private var chapterCountLabel: String {
        "\(book.chapters.count) \(book.chapters.count == 1 ? "chapter" : "chapters")"
    }

    var body: some View {
        Group {
            if let onSelect {
                Button { onSelect(book) } label: { tile }
            } else {
                NavigationLink {
                    StudyBookView(book: book)
                } label: {
                    tile
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(book.name), \(chapterCountLabel), \(verseCount) verses")
    }

    private var tile: some View {
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
}

/// A book's study page: its overview and its chapters, each opening Chapter Insights.
struct StudyBookView: View {
    let book: Book

    @AppStorage(ChapterListLayout.storageKey) private var chapterLayout: ChapterListLayout = .detailed
    @State private var details = ChapterOutlineDetails()
    @State private var overallTheme: String?
    @State private var isShowingOverview = false
    @State private var headerHeight: CGFloat = 0
    @State private var isHeaderScrolledAway = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = [GridItem(.adaptive(minimum: 52), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                StudyBookHeader(bookName: book.name, overallTheme: overallTheme, onOpenOverview: openOverview)
                    .onGeometryChange(for: CGFloat.self, of: \.size.height) { headerHeight = $0 }

                HeroCard(title: "Chapter Insights", icon: "lightbulb.max") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(chapterLayout.helperText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        switch chapterLayout {
                        case .simple: numberGrid
                        case .detailed: themedChapters
                        }
                    }
                }
            }
            .padding()
        }
        // Once most of the full header has scrolled out of view, a compact bar takes
        // its place. It floats over the content rather than insetting it, so showing
        // or hiding it never shifts the scroll position.
        .onScrollGeometryChange(for: Bool.self) { geometry in
            let scrolled = geometry.contentOffset.y + geometry.contentInsets.top
            return headerHeight > 0 && scrolled > headerHeight * 0.75
        } action: { _, isScrolledAway in
            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.25)) {
                isHeaderScrolledAway = isScrolledAway
            }
        }
        .tabBarContentClearance()
        .overlay(alignment: .top) {
            if isHeaderScrolledAway {
                CompactStudyBookHeader(bookName: book.name, onOpenOverview: openOverview)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .background(AppBackgroundView(tab: .bible))
        .navigationTitle(book.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ChapterLayoutMenu(layout: $chapterLayout)
            }
        }
        .navigationDestination(isPresented: $isShowingOverview) {
            BookOverviewView(bookName: book.name)
        }
        .task(id: book.name) {
            details = await ChapterOutlineDetails.load(for: book)
        }
        .task(id: book.name) {
            overallTheme = await BibleBookOverviewRepository.shared
                .overview(forBookNamed: book.name)?
                .overallTheme
        }
    }

    private func openOverview() {
        isShowingOverview = true
    }

    private var numberGrid: some View {
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

    private var themedChapters: some View {
        ChapterOutlineList(chapterNumbers: book.chapters.map(\.number), sections: details.sections) { number in
            NavigationLink {
                ChapterInsightsView(bookName: book.name, chapterNumber: number)
            } label: {
                ChapterThemeRow(number: number, themes: details.themeNames[number] ?? [])
            }
            .buttonStyle(.plain)
        }
    }
}

/// The top of a book's study page: the book's emblem and title, a taste of its
/// overall theme, and a prominent button into the full book overview.
private struct StudyBookHeader: View {
    let bookName: String
    let overallTheme: String?
    let onOpenOverview: () -> Void

    private var theme: BookChapterTheme? {
        BookChapterTheme.themes[bookName]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                if let theme {
                    BookChapterEmblem(theme: theme, size: 56)
                }

                Text(bookName)
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(titleStyle)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
            }

            if let overallTheme, !overallTheme.isEmpty {
                Text(overallTheme)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onOpenOverview) {
                Label("Explore \(bookName)", systemImage: "book.closed.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Who wrote \(bookName), when and where, and the story of the whole book")
        }
        .padding(AppDesignMetrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .heroCardSurface()
    }

    private var titleStyle: AnyShapeStyle {
        if let theme {
            AnyShapeStyle(LinearGradient(colors: theme.colors, startPoint: .leading, endPoint: .trailing))
        } else {
            AnyShapeStyle(.primary)
        }
    }
}

/// A one-row version of StudyBookHeader that stays pinned once the full header
/// scrolls away, keeping the book overview one tap away. Also used by ChaptersView.
struct CompactStudyBookHeader: View {
    let bookName: String
    let onOpenOverview: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if let theme = BookChapterTheme.themes[bookName] {
                BookChapterEmblem(theme: theme, size: 28)
            }

            Text(bookName)
                .font(.system(.title3, design: .serif, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 8)

            Button("Explore \(bookName)", systemImage: "book.closed.fill", action: onOpenOverview)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .accessibilityLabel("Explore \(bookName)")
                .accessibilityHint("Opens the book overview")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
