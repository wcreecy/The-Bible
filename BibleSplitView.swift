import SwiftUI

struct BibleSplitView: View {
    @State private var selectedBook: Book? = nil
    @State private var selectedChapter: Chapter? = nil
    @State private var navStartVerse: Int = 1
    @State private var searchText: String = ""
    @State private var sidebarSearch: String = ""
    @State private var detailPath = NavigationPath()
    
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
        List {
            Section {
                TextField("Search books", text: $sidebarSearch)
                    .textFieldStyle(.roundedBorder)
                    .overlay(alignment: .trailing) {
                        if !sidebarSearch.isEmpty {
                            Button {
                                sidebarSearch = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 8)
                            .accessibilityLabel("Clear search")
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
                            HStack {
                                Text(book.name)
                                if selectedBook?.name == book.name {
                                    Spacer()
                                    Image(systemName: "checkmark").foregroundStyle(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
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
                                HStack {
                                    Text(book.name)
                                    if selectedBook?.name == book.name {
                                        Spacer()
                                        Image(systemName: "checkmark").foregroundStyle(.blue)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
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
                                HStack {
                                    Text(book.name)
                                    if selectedBook?.name == book.name {
                                        Spacer()
                                        Image(systemName: "checkmark").foregroundStyle(.blue)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("New Testament (\(filteredNTBooks.count))").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Books")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
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
            }
        }
    }
    
    private struct ChaptersListView: View {
        let book: Book
        @Binding var showInspector: Bool
        var body: some View {
            List(book.chapters, id: \.number) { chapter in
                NavigationLink(value: ChapterRoute(bookName: book.name, chapterNumber: chapter.number)) {
                    Text("Chapter \(chapter.number)")
                }
            }
            .navigationTitle(book.name)
        }
    }
    
    private struct ReaderSettingsView: View {
        @Binding var fontSize: Double
        @Binding var useTwoColumns: Bool
        var body: some View {
            Form {
                Section("Text") {
                    HStack {
                        Text("Font Size")
                        Spacer()
                        Text("\(Int(fontSize)) pt").foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    Slider(value: $fontSize, in: 12...30, step: 1)
                    Button {
                        fontSize = 17
                    } label: {
                        Label("Reset to Default", systemImage: "arrow.counterclockwise")
                    }
                }
                Section("Layout") {
                    Toggle("Two-column reading", isOn: $useTwoColumns)
                }
            }
            .navigationTitle("Reading Settings")
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
                .navigationTitle("Search Results (\(results.count))")
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
                        }
                        .navigationTitle("\(book.name) \(chapter.number)")
                    } else {
                        ContentUnavailableView("Chapter not found", systemImage: "exclamationmark.triangle")
                    }
                }
                .navigationDestination(for: ReadingRoute.self) { route in
                    if let book = BibleData.books.first(where: { $0.name == route.bookName }),
                       let chapter = book.chapters.first(where: { $0.number == route.chapterNumber }) {
                        ReadingView(book: book, chapter: chapter, startVerse: route.verseNumber)
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
        // Listen for deep links from ContentView (iPad path)
        .onReceive(NotificationCenter.default.publisher(for: .openBibleReference)) { note in
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
        NavigationSplitView(columnVisibility: .constant(.all)) {
            sidebarView
        } detail: {
            detailView
        }
    }
}

#Preview {
    BibleSplitView()
}
