import SwiftUI

struct BibleSplitView: View {
    @State private var selectedBook: Book? = nil
    @State private var selectedChapter: Chapter? = nil
    @State private var navStartVerse: Int = 1
    @State private var searchText: String = ""
    @State private var detailPath = NavigationPath()
    
    @State private var debouncedText: String = ""
    @State private var showInspector: Bool = false
    @AppStorage("readerFontSize") private var readerFontSize: Double = 17
    @State private var readerUseTwoColumns: Bool = false

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
            if !otBooks.isEmpty {
                Section {
                    ForEach(otBooks, id: \.name) { book in
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
                    Text("Old Testament (\(otBooks.count))").font(.footnote).foregroundStyle(.secondary)
                }
            }
            if !ntBooks.isEmpty {
                Section {
                    ForEach(ntBooks, id: \.name) { book in
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
                    Text("New Testament (\(ntBooks.count))").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Books")
    }
    
    private struct SearchResultsList: View {
        let results: [SearchHit]
        var body: some View {
            if results.isEmpty {
                ContentUnavailableView("No results", systemImage: "magnifyingglass", description: Text("Type at least two words to search Bible text."))
            } else {
                List(results) { hit in
                    NavigationLink(value: ReadingRoute(bookName: hit.book.name, chapterNumber: hit.chapter.number, verseNumber: hit.verseNumber)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(hit.book.name) \(hit.chapter.number):\(hit.verseNumber)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(hit.verseText)
                                .font(.body)
                                .lineLimit(3)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .navigationTitle("Search")
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
    
    @ViewBuilder
    private var detailView: some View {
        NavigationStack(path: $detailPath) {
            Group {
                if shouldSearch {
                    SearchResultsList(results: searchResults)
                } else if let book = selectedBook {
                    ChaptersListView(book: book, showInspector: $showInspector)
                } else {
                    ContentUnavailableView("Select a Book", systemImage: "book")
                }
            }
            .task(id: searchText) {
                // Debounce input by 300ms
                try? await Task.sleep(nanoseconds: 300_000_000)
                if !Task.isCancelled {
                    debouncedText = searchText
                }
            }
            .navigationDestination(for: ChapterRoute.self) { route in
                // Resolve book and chapter
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
                        // Propagate a base font size to all text in the reader
                        .font(.system(size: readerFontSize))
                        .toolbar {
                            ToolbarItem(placement: .primaryAction) {
                                Button {
                                    showInspector.toggle()
                                } label: {
                                    Label("Reading Settings", systemImage: "slider.horizontal.3")
                                }
                                .keyboardShortcut(",", modifiers: [.command])
                            }
                        }
                } else {
                    ContentUnavailableView("Passage not found", systemImage: "exclamationmark.triangle")
                }
            }
        }
//        Removed entire toolbar block here
//        .toolbar {
//            ToolbarItem(placement: .primaryAction) {
//                Button {
//                    showInspector.toggle()
//                } label: {
//                    Label("Reading Settings", systemImage: "slider.horizontal.3")
//                }
//                .keyboardShortcut(",", modifiers: [.command])
//            }
//        }
        .inspector(isPresented: $showInspector) {
            ReaderSettingsView(fontSize: $readerFontSize, useTwoColumns: $readerUseTwoColumns)
                .inspectorColumnWidth(min: 240, ideal: 300, max: 400)
        }
        .sheet(
            isPresented: Binding(
                get: { hSize == .compact && showInspector },
                set: { newValue in if hSize == .compact { showInspector = newValue } }
            )
        ) {
            NavigationStack {
                ReaderSettingsView(fontSize: $readerFontSize, useTwoColumns: $readerUseTwoColumns)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showInspector = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .id(selectedBook?.name ?? "__no_book__")
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search Bible text")
        .searchScopes($searchScope) {
            ForEach(SearchScope.allCases) { scope in
                Text(scope.rawValue)
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
