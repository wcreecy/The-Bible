import SwiftUI

struct BibleSplitView: View {
    let searchRequestID: Int
    let bookSelectionRequestID: Int
    let initialReaderLocation: BibleReaderLocation?

    @State private var handledSearchRequestID: Int = 0
    @State private var handledInitialReaderLocation: BibleReaderLocation?
    @State private var selectedBook: Book? = nil
    @State private var selectedChapter: Chapter? = nil
    @State private var navStartVerse: Int = 1
    @State private var searchText: String = ""
    @State private var sidebarSearch: String = ""
    @State private var detailPath = NavigationPath()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    @State private var debouncedText: String = ""
    @State private var showInspector: Bool = false
    @AppStorage("readerFontSize") private var readerFontSize: Double = 17
    @State private var readerUseTwoColumns: Bool = false

    // Shared preference for sort mode across iPhone/iPad
    @AppStorage("bibleBooksSortAlphabetical") private var sortAlphabetically: Bool = false

    private enum SearchScope: String, CaseIterable, Identifiable {
        case all = "All"
        case ot = "OT"
        case nt = "NT"
        case thisBook = "This Book"
        var id: String { rawValue }
    }
    @State private var searchScope: SearchScope = .all

    @Environment(\.horizontalSizeClass) private var hSize
    
    private struct ChapterRoute: Hashable {
        let bookName: String
        let chapterNumber: Int
    }

    private struct ReadingRoute: Hashable {
        let bookName: String
        let chapterNumber: Int
        let verseNumber: Int
    }

    private struct SearchRoute: Hashable {}

    private struct BookOverviewRoute: Hashable {
        let bookName: String
    }
    
    private struct SearchHit: Identifiable, Hashable {
        let id: String
        let book: Book
        let chapter: Chapter
        let verseNumber: Int
        let verseText: String
        
        init(book: Book, chapter: Chapter, verseNumber: Int, verseText: String) {
            self.book = book
            self.chapter = chapter
            self.verseNumber = verseNumber
            self.verseText = verseText
            self.id = "\(book.name)-\(chapter.number)-\(verseNumber)"
        }
    }
    
    private var canon: [Book] { BibleData.books }
    private var indexMap: [String: Int] {
        Dictionary(uniqueKeysWithValues: canon.enumerated().map { ($1.name, $0) })
    }
    private var matthewIndex: Int { indexMap["Matthew"] ?? Int.max }
    private var otBooks: [Book] {
        canon.filter { (indexMap[$0.name] ?? Int.max) < matthewIndex }
    }
    private var ntBooks: [Book] {
        canon.filter { (indexMap[$0.name] ?? Int.max) >= matthewIndex }
    }
    
    private var filteredSidebarQuery: String {
        sidebarSearch.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var sidebarReference: ScriptureRef? {
        guard let reference = BibleReferenceLinker.parse(sidebarSearch),
              let book = canon.first(where: { $0.name == reference.bookName }),
              let chapter = book.chapters.first(where: { $0.number == reference.chapter }),
              chapter.verses.contains(where: { $0.number == reference.startVerse }) else {
            return nil
        }
        return reference
    }
    private var filteredOTBooks: [Book] {
        let base = otBooks
        let q = filteredSidebarQuery
        guard !q.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }
    private var filteredNTBooks: [Book] {
        let base = ntBooks
        let q = filteredSidebarQuery
        guard !q.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    private var filteredAllBooksAZ: [Book] {
        let q = filteredSidebarQuery
        let base = canon
        let filtered = q.isEmpty ? base : base.filter { $0.name.localizedCaseInsensitiveContains(q) }
        return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private var shouldSearch: Bool {
        let words = debouncedText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.count >= 2
    }
    
    private var searchResults: [SearchHit] {
        guard shouldSearch else { return [] }
        let needle = debouncedText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Determine which books to search based on scope
        let booksToSearch: [Book]
        switch searchScope {
        case .all:
            booksToSearch = BibleData.books
        case .ot:
            booksToSearch = otBooks
        case .nt:
            booksToSearch = ntBooks
        case .thisBook:
            if let book = selectedBook { booksToSearch = [book] } else { booksToSearch = [] }
        }

        var results: [SearchHit] = []
        for book in booksToSearch {
            for chapter in book.chapters {
                for verse in chapter.verses {
                    if verse.text.lowercased().contains(needle) {
                        results.append(SearchHit(book: book, chapter: chapter, verseNumber: verse.number, verseText: verse.text))
                    }
                }
            }
        }
        return results
    }
    
    @ViewBuilder
    private var sidebarView: some View {
        // Sidebar: Books only
        VStack(spacing: 0) {
            HStack {
                Menu {
                    Button {
                        sortAlphabetically = false
                    } label: {
                        Label("Canonical", systemImage: "list.number")
                    }
                    .disabled(!sortAlphabetically)

                    Button {
                        sortAlphabetically = true
                    } label: {
                        Label("A–Z", systemImage: "textformat.abc")
                    }
                    .disabled(sortAlphabetically)
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel("Sort")
                .accessibilityHint("Choose canonical or alphabetical order")
                .frame(width: 44, height: 44)

                Spacer()

                Text("Books")
                    .font(.headline)

                Spacer()

                Button {
                    columnVisibility = .detailOnly
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .accessibilityLabel("Hide Books pane")
                .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 8)

            List {
            Section {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Books or a reference", text: $sidebarSearch)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.go)
                        .onSubmit(openSidebarReference)

                    if !sidebarSearch.isEmpty {
                        Button {
                            sidebarSearch = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(.secondary.opacity(0.2), lineWidth: 1)
                }
            }
            .listRowBackground(Color.clear)

            if let reference = sidebarReference {
                Section {
                    Button(action: openSidebarReference) {
                        Label(
                            "Go to \(reference.bookName) \(reference.chapter):\(reference.startVerse)",
                            systemImage: "arrow.right.circle.fill"
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            if sortAlphabetically {
                // Single A–Z section
                Section {
                    ForEach(filteredAllBooksAZ, id: \.name) { book in
                        Button {
                            selectedBook = book
                            selectedChapter = nil
                            navStartVerse = 1
                            searchText = ""
                            detailPath = NavigationPath()
                        } label: {
                            Text(book.name)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(
                            Color.accentColor.opacity(selectedBook?.name == book.name ? 0.18 : 0)
                        )
                    }
                } header: {
                    Text("All Books (\(filteredAllBooksAZ.count))").font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                // Canonical OT/NT grouping
                if !filteredOTBooks.isEmpty {
                    Section {
                        ForEach(filteredOTBooks, id: \.name) { book in
                            Button {
                                selectedBook = book
                                selectedChapter = nil
                                navStartVerse = 1
                                searchText = ""
                                detailPath = NavigationPath()
                            } label: {
                                Text(book.name)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(
                                Color.accentColor.opacity(selectedBook?.name == book.name ? 0.18 : 0)
                            )
                        }
                    } header: {
                        Text("Old Testament (\(filteredOTBooks.count))").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if !filteredNTBooks.isEmpty {
                    Section {
                        ForEach(filteredNTBooks, id: \.name) { book in
                            Button {
                                selectedBook = book
                                selectedChapter = nil
                                navStartVerse = 1
                                searchText = ""
                                detailPath = NavigationPath()
                            } label: {
                                Text(book.name)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(
                                Color.accentColor.opacity(selectedBook?.name == book.name ? 0.18 : 0)
                            )
                        }
                    } header: {
                        Text("New Testament (\(filteredNTBooks.count))").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func openSidebarReference() {
        guard let reference = sidebarReference,
              let book = canon.first(where: { $0.name == reference.bookName }),
              let chapter = book.chapters.first(where: { $0.number == reference.chapter }) else {
            return
        }

        selectedBook = book
        selectedChapter = chapter
        navStartVerse = reference.startVerse
        searchText = ""
        sidebarSearch = ""
        detailPath = NavigationPath()
        detailPath.append(ReadingRoute(
            bookName: book.name,
            chapterNumber: chapter.number,
            verseNumber: reference.startVerse
        ))
    }
    
    private struct ChaptersListView: View {
        let book: Book
        @Binding var showInspector: Bool
        var body: some View {
            List {
                if let theme = BookChapterTheme.themes[book.name] {
                    ThemedBookChaptersHeader(title: book.name, theme: theme)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                NavigationLink(value: BookOverviewRoute(bookName: book.name)) {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("About \(book.name)")
                                .font(.headline)
                            Text("Background, themes, and key passages")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "book.closed.fill")
                            .font(.title3)
                            .foregroundStyle(.tint)
                    }
                }
                .listRowBackground(HeroCardListRowBackground())
                .accessibilityHint("Open an overview of \(book.name)")

                ForEach(book.chapters, id: \.number) { chapter in
                    NavigationLink(value: ChapterRoute(bookName: book.name, chapterNumber: chapter.number)) {
                        Text("Chapter \(chapter.number)")
                    }
                    .listRowBackground(HeroCardListRowBackground())
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackgroundView(tab: .bible))
            // The themed header in the list supplies the book title.
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    struct BookChapterTheme {
        let primarySymbol: String
        let accentSymbol: String?
        let colors: [Color]

        static let themes: [String: BookChapterTheme] = [
            "Genesis": .init(primarySymbol: "sun.max.fill", accentSymbol: "leaf.fill", colors: [.orange, .yellow, .green]),
            "Exodus": .init(primarySymbol: "water.waves", accentSymbol: "figure.walk", colors: [.blue, .cyan, .teal]),
            "Leviticus": .init(primarySymbol: "flame.fill", accentSymbol: nil, colors: [.red, .orange, .yellow]),
            "Numbers": .init(primarySymbol: "list.number", accentSymbol: nil, colors: [.indigo, .blue, .cyan]),
            "Deuteronomy": .init(primarySymbol: "book.closed.fill", accentSymbol: nil, colors: [.brown, .orange, .yellow]),
            "Joshua": .init(primarySymbol: "shield.fill", accentSymbol: nil, colors: [.blue, .indigo, .purple]),
            "Judges": .init(primarySymbol: "scale.3d", accentSymbol: nil, colors: [.purple, .indigo, .blue]),
            "Ruth": .init(primarySymbol: "heart.fill", accentSymbol: nil, colors: [.pink, .red, .orange]),
            "1 Samuel": .init(primarySymbol: "crown.fill", accentSymbol: nil, colors: [.yellow, .orange, .brown]),
            "2 Samuel": .init(primarySymbol: "crown.fill", accentSymbol: nil, colors: [.orange, .red, .pink]),
            "1 Kings": .init(primarySymbol: "crown.fill", accentSymbol: nil, colors: [.yellow, .orange, .red]),
            "2 Kings": .init(primarySymbol: "crown.fill", accentSymbol: nil, colors: [.orange, .red, .purple]),
            "1 Chronicles": .init(primarySymbol: "clock.arrow.circlepath", accentSymbol: nil, colors: [.brown, .orange, .yellow]),
            "2 Chronicles": .init(primarySymbol: "clock.arrow.circlepath", accentSymbol: nil, colors: [.orange, .yellow, .green]),
            "Ezra": .init(primarySymbol: "building.columns.fill", accentSymbol: nil, colors: [.brown, .orange, .yellow]),
            "Nehemiah": .init(primarySymbol: "hammer.fill", accentSymbol: nil, colors: [.gray, .blue, .teal]),
            "Esther": .init(primarySymbol: "sparkles", accentSymbol: nil, colors: [.purple, .pink, .yellow]),
            "Job": .init(primarySymbol: "cloud.bolt.rain.fill", accentSymbol: nil, colors: [.gray, .blue, .indigo]),
            "Psalms": .init(primarySymbol: "music.note", accentSymbol: nil, colors: [.purple, .pink, .red]),
            "Proverbs": .init(primarySymbol: "lightbulb.fill", accentSymbol: nil, colors: [.yellow, .orange, .red]),
            "Ecclesiastes": .init(primarySymbol: "hourglass", accentSymbol: nil, colors: [.brown, .gray, .blue]),
            "Song of Solomon": .init(primarySymbol: "heart.fill", accentSymbol: nil, colors: [.pink, .red, .purple]),
            "Isaiah": .init(primarySymbol: "megaphone.fill", accentSymbol: nil, colors: [.blue, .indigo, .purple]),
            "Jeremiah": .init(primarySymbol: "drop.fill", accentSymbol: nil, colors: [.blue, .indigo, .gray]),
            "Lamentations": .init(primarySymbol: "cloud.rain.fill", accentSymbol: nil, colors: [.gray, .blue, .indigo]),
            "Ezekiel": .init(primarySymbol: "eye.fill", accentSymbol: nil, colors: [.teal, .blue, .indigo]),
            "Daniel": .init(primarySymbol: "pawprint.fill", accentSymbol: nil, colors: [.orange, .yellow, .brown]),
            "Hosea": .init(primarySymbol: "heart.circle.fill", accentSymbol: nil, colors: [.pink, .red, .purple]),
            "Joel": .init(primarySymbol: "cloud.bolt.fill", accentSymbol: nil, colors: [.gray, .blue, .purple]),
            "Amos": .init(primarySymbol: "bell.fill", accentSymbol: nil, colors: [.orange, .yellow, .red]),
            "Obadiah": .init(primarySymbol: "bird.fill", accentSymbol: nil, colors: [.blue, .cyan, .teal]),
            "Jonah": .init(primarySymbol: "fish.fill", accentSymbol: nil, colors: [.blue, .cyan, .teal]),
            "Micah": .init(primarySymbol: "scale.3d", accentSymbol: nil, colors: [.purple, .indigo, .blue]),
            "Nahum": .init(primarySymbol: "cloud.bolt.fill", accentSymbol: nil, colors: [.gray, .blue, .indigo]),
            "Habakkuk": .init(primarySymbol: "questionmark.circle.fill", accentSymbol: nil, colors: [.indigo, .purple, .pink]),
            "Zephaniah": .init(primarySymbol: "sun.max.fill", accentSymbol: nil, colors: [.orange, .yellow, .red]),
            "Haggai": .init(primarySymbol: "hammer.fill", accentSymbol: nil, colors: [.brown, .orange, .yellow]),
            "Zechariah": .init(primarySymbol: "eye.fill", accentSymbol: nil, colors: [.purple, .blue, .teal]),
            "Malachi": .init(primarySymbol: "flame.fill", accentSymbol: nil, colors: [.red, .orange, .yellow]),
            "Matthew": .init(primarySymbol: "person.crop.circle.badge.checkmark", accentSymbol: nil, colors: [.blue, .indigo, .purple]),
            "Mark": .init(primarySymbol: "bolt.fill", accentSymbol: nil, colors: [.orange, .yellow, .red]),
            "Luke": .init(primarySymbol: "cross.case.fill", accentSymbol: nil, colors: [.green, .teal, .blue]),
            "John": .init(primarySymbol: "heart.fill", accentSymbol: nil, colors: [.pink, .red, .purple]),
            "Acts": .init(primarySymbol: "figure.walk", accentSymbol: nil, colors: [.blue, .cyan, .teal]),
            "Romans": .init(primarySymbol: "building.columns.fill", accentSymbol: nil, colors: [.orange, .red, .purple]),
            "1 Corinthians": .init(primarySymbol: "person.2.fill", accentSymbol: nil, colors: [.blue, .indigo, .purple]),
            "2 Corinthians": .init(primarySymbol: "person.2.fill", accentSymbol: nil, colors: [.purple, .indigo, .blue]),
            "Galatians": .init(primarySymbol: "link", accentSymbol: nil, colors: [.green, .teal, .blue]),
            "Ephesians": .init(primarySymbol: "shield.fill", accentSymbol: nil, colors: [.blue, .indigo, .purple]),
            "Philippians": .init(primarySymbol: "hands.clap.fill", accentSymbol: nil, colors: [.yellow, .orange, .pink]),
            "Colossians": .init(primarySymbol: "circle.grid.cross.fill", accentSymbol: nil, colors: [.blue, .teal, .green]),
            "1 Thessalonians": .init(primarySymbol: "sun.and.horizon.fill", accentSymbol: nil, colors: [.orange, .yellow, .pink]),
            "2 Thessalonians": .init(primarySymbol: "sun.and.horizon.fill", accentSymbol: nil, colors: [.yellow, .orange, .red]),
            "1 Timothy": .init(primarySymbol: "person.crop.circle.badge.checkmark", accentSymbol: nil, colors: [.blue, .indigo, .teal]),
            "2 Timothy": .init(primarySymbol: "person.crop.circle.badge.checkmark", accentSymbol: nil, colors: [.indigo, .purple, .blue]),
            "Titus": .init(primarySymbol: "person.crop.circle", accentSymbol: nil, colors: [.teal, .blue, .indigo]),
            "Philemon": .init(primarySymbol: "envelope.fill", accentSymbol: nil, colors: [.blue, .cyan, .teal]),
            "Hebrews": .init(primarySymbol: "scroll.fill", accentSymbol: nil, colors: [.brown, .orange, .yellow]),
            "James": .init(primarySymbol: "hammer.fill", accentSymbol: nil, colors: [.orange, .red, .brown]),
            "1 Peter": .init(primarySymbol: "key.fill", accentSymbol: nil, colors: [.blue, .cyan, .teal]),
            "2 Peter": .init(primarySymbol: "key.fill", accentSymbol: nil, colors: [.teal, .blue, .indigo]),
            "1 John": .init(primarySymbol: "heart.fill", accentSymbol: nil, colors: [.pink, .red, .purple]),
            "2 John": .init(primarySymbol: "heart.fill", accentSymbol: nil, colors: [.purple, .pink, .red]),
            "3 John": .init(primarySymbol: "heart.fill", accentSymbol: nil, colors: [.red, .pink, .purple]),
            "Jude": .init(primarySymbol: "shield.fill", accentSymbol: nil, colors: [.blue, .indigo, .purple]),
            "Revelation": .init(primarySymbol: "crown.fill", accentSymbol: nil, colors: [.purple, .pink, .yellow])
        ]
    }

    struct ThemedBookChaptersHeader: View {
        let title: String
        let theme: BookChapterTheme

        var body: some View {
            HStack(spacing: 16) {
                BookChapterEmblem(theme: theme)

                Text(title)
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: theme.colors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(AppDesignMetrics.cardPadding)
            .heroCardSurface()
            .accessibilityElement(children: .combine)
        }
    }

    private struct BookChapterEmblem: View {
        let theme: BookChapterTheme

        var body: some View {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: theme.colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: theme.primarySymbol)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(y: theme.accentSymbol == nil ? 0 : -8)

                if let accentSymbol = theme.accentSymbol {
                    Image(systemName: accentSymbol)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white.opacity(0.94))
                        .offset(x: 12, y: 12)
                }
            }
            .frame(width: 72, height: 72)
            .accessibilityHidden(true)
        }
    }

    // Added: Search results list view used by DetailRootContent
    private struct SearchResultsList: View {
        let results: [BibleSplitView.SearchHit]
        @Binding var path: NavigationPath

        var body: some View {
            if results.isEmpty {
                ContentUnavailableView("No results", systemImage: "magnifyingglass")
            } else {
                List(results) { hit in
                    Button {
                        path.append(BibleSplitView.ReadingRoute(
                            bookName: hit.book.name,
                            chapterNumber: hit.chapter.number,
                            verseNumber: hit.verseNumber
                        ))
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(hit.book.name) \(hit.chapter.number):\(hit.verseNumber)")
                                .font(.headline)
                            Text(hit.verseText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                .scrollContentBackground(.hidden)
                .background(AppBackgroundView(tab: .bible))
                .navigationTitle("Search Results (\(results.count))")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    // Split the large conditional into a small helper view to reduce inference pressure
    @ViewBuilder
    private func DetailRootContent() -> some View {
        if shouldSearch {
            SearchResultsList(results: searchResults, path: $detailPath)
        } else if let book = selectedBook {
            ChaptersListView(book: book, showInspector: $showInspector)
        } else {
            ContentUnavailableView("Select a Book", systemImage: "book")
        }
    }
    
    @ViewBuilder
    private var detailView: some View {
        NavigationStack(path: $detailPath) {
            DetailRootContent()
                .navigationDestination(for: ChapterRoute.self) { route in
                    if let book = BibleData.books.first(where: { $0.name == route.bookName }),
                       let chapter = book.chapters.first(where: { $0.number == route.chapterNumber }) {
                        List(chapter.verses, id: \.number) { verse in
                            NavigationLink(value: ReadingRoute(bookName: book.name, chapterNumber: chapter.number, verseNumber: verse.number)) {
                                VStack(alignment: .leading) {
                                    Text("Verse \(verse.number)")
                                        .font(.headline)
                                    let preview = String(verse.text.prefix(120)) + (verse.text.count > 120 ? "…" : "")
                                    Text(preview)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(HeroCardListRowBackground())
                        }
                        .scrollContentBackground(.hidden)
                        .background(AppBackgroundView(tab: .bible))
                        .navigationTitle("\(book.name) \(chapter.number)")
                        .navigationBarTitleDisplayMode(.inline)
                    } else {
                        ContentUnavailableView("Chapter not found", systemImage: "exclamationmark.triangle")
                    }
                }
                .navigationDestination(for: SearchRoute.self) { _ in
                    SearchView()
                }
                .navigationDestination(for: BookOverviewRoute.self) { route in
                    BookOverviewView(bookName: route.bookName)
                }
                .navigationDestination(for: ReadingRoute.self) { route in
                    if let book = BibleData.books.first(where: { $0.name == route.bookName }),
                       let chapter = book.chapters.first(where: { $0.number == route.chapterNumber }) {
                        ReadingView(
                            book: book,
                            chapter: chapter,
                            startVerse: route.verseNumber,
                            onSearch: {
                                detailPath.append(SearchRoute())
                            },
                            onNavigateBack: { _ in
                                selectedBook = book
                                detailPath = NavigationPath()
                                detailPath.append(ChapterRoute(
                                    bookName: book.name,
                                    chapterNumber: chapter.number
                                ))
                            },
                            onBookSelected: { selectedBook in
                                self.selectedBook = selectedBook
                                detailPath = NavigationPath()
                            }
                        )
                            .id("\(route.bookName)-\(route.chapterNumber)-\(route.verseNumber)")
                            // Safety net: ensure tracker is active for split-view navigation as well.
                            .onAppear {
                                ReadingTimeTracker.shared.start(bookName: book.name, chapter: chapter.number)
                                ReadingTimeTracker.shared.setCurrentLocation(bookName: book.name, chapter: chapter.number)
                                ReadingTimeTracker.shared.resume()
                            }
                            .onDisappear {
                                ReadingTimeTracker.shared.stopAndFlush()
                            }
                            .toolbar {
                                ToolbarItemGroup(placement: .topBarTrailing) {
                                    Button {
                                        readerFontSize = max(12, readerFontSize - 1)
                                    } label: {
                                        Image(systemName: "textformat.size.smaller")
                                    }
                                    .accessibilityLabel("Decrease font size")

                                    Button {
                                        readerFontSize = min(30, readerFontSize + 1)
                                    } label: {
                                        Image(systemName: "textformat.size.larger")
                                    }
                                    .accessibilityLabel("Increase font size")
                                }
                            }
                    } else {
                        ContentUnavailableView("Passage not found", systemImage: "exclamationmark.triangle")
                    }
                }
        }
        .background(AppBackgroundView(tab: .bible))
        .id(selectedBook?.name ?? "__no_book__")
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search Bible text")
        .searchScopes($searchScope) {
            ForEach(SearchScope.allCases) { scope in
                Text(scope.rawValue)
            }
        }
        // Move debounce task to the NavigationStack level to simplify the inner builder
        .task(id: searchText) {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if !Task.isCancelled {
                debouncedText = searchText
            }
        }
        .task(id: searchRequestID) {
            guard searchRequestID != 0, searchRequestID != handledSearchRequestID else { return }
            handledSearchRequestID = searchRequestID
            detailPath.append(SearchRoute())
        }
        .task(id: bookSelectionRequestID) {
            guard bookSelectionRequestID != 0 else { return }
            selectedBook = nil
            selectedChapter = nil
            searchText = ""
            sidebarSearch = ""
            detailPath = NavigationPath()
        }
        .task(id: initialReaderLocation) {
            guard let location = initialReaderLocation,
                  location != handledInitialReaderLocation,
                  let book = BibleData.books.first(where: { $0.name == location.bookName }) else {
                return
            }

            handledInitialReaderLocation = location
            selectedBook = book
            selectedChapter = nil
            navStartVerse = location.verseNumber
            searchText = ""

            // Changing the selected book replaces the detail stack's identity.
            // Yield before installing the reader route into the new stack.
            await Task.yield()
            detailPath = NavigationPath()
            detailPath.append(ReadingRoute(
                bookName: book.name,
                chapterNumber: location.chapterNumber,
                verseNumber: location.verseNumber
            ))
        }
        // Listen for deep links from ContentView (iPad path)
        .onReceive(NotificationCenter.default.publisher(for: .openBibleReference)) { note in
            // ContentView is the single router for app-wide requests. It relays the
            // request after switching to the Bible tab, so handling the original
            // notification here as well could reset this stack twice.
            guard note.userInfo?["relayed"] as? Bool == true else { return }
            guard
                let bookName = note.userInfo?["book"] as? String,
                let chapterNum = note.userInfo?["chapter"] as? Int,
                let verseNum = note.userInfo?["verse"] as? Int,
                let book = BibleData.books.first(where: { $0.name == bookName })
            else { return }

            selectedBook = book
            selectedChapter = nil
            navStartVerse = verseNum
            searchText = ""
            DispatchQueue.main.async {
                detailPath = NavigationPath()
                detailPath.append(ReadingRoute(bookName: book.name, chapterNumber: chapterNum, verseNumber: verseNum))
            }
        }
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarView
        } detail: {
            detailView
        }
    }
}

#Preview {
    BibleSplitView(
        searchRequestID: 0,
        bookSelectionRequestID: 0,
        initialReaderLocation: nil
    )
}
