import SwiftUI

struct SearchView: View {
    // MARK: - Query & Results
    @State private var query: String = ""
    @State private var results: [SearchResult] = []
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var isSearching: Bool = false
    @AppStorage("bibleRecentSearches") private var recentSearchesStorage: String = ""

    private let suggestedSearches = ["love", "faith", "peace", "John 3:16", "Psalm 23"]

    // MARK: - Scope State
    private enum SearchScope: String, CaseIterable, Identifiable {
        case all = "OT & NT"
        case ot = "OT"
        case nt = "NT"
        case specific = "Book"
        var id: String { rawValue }
    }
    @State private var scope: SearchScope = .all

    // Specific book picker state
    @State private var selectedBook: Book? = nil
    @State private var showBookPicker: Bool = false
    @State private var bookQuery: String = ""

    // MARK: - Tokenization
    private var tokens: [String] {
        query
            .lowercased()
            .split { $0.isWhitespace || $0.isPunctuation }
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private var canSearch: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var recentSearches: [String] {
        recentSearchesStorage
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
    }

    // MARK: - Canon helpers (split OT/NT by Matthew)
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

    // Books for the popover list (filtered by bookQuery)
    private var filteredBooksForPicker: [Book] {
        let q = bookQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = canon
        guard !q.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Scope controls at the top
            scopeControls

            Group {
                if canSearch {
                    if isSearching {
                        ProgressView("Searching…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    } else if results.isEmpty {
                        ContentUnavailableView(
                            "No Results",
                            systemImage: "magnifyingglass",
                            description: Text("Try different keywords or check spelling.")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    } else {
                        List(results) { item in
                            HStack(spacing: 12) {
                                Button {
                                    openInBibleTab(item)
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        if item.isReferenceMatch {
                                            Label("Direct Reference", systemImage: "arrow.up.right.square")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(Color.accentColor)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.accentColor.opacity(0.12), in: Capsule())
                                        }

                                        Text(highlightedVerseText(item))
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                            .lineLimit(3)

                                        Text("\(item.book.name) \(item.chapter.number):\(item.verse.number)")
                                            .font(.caption)
                                            .foregroundStyle(item.isReferenceMatch ? Color.accentColor : Color.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)

                                VerseActionMenu(
                                    verse: VerseActionReference(
                                        bookName: item.book.name,
                                        chapterNumber: item.chapter.number,
                                        verseNumber: item.verse.number,
                                        verseText: item.verse.text
                                    )
                                )
                            }
                            .listRowBackground(
                                item.isReferenceMatch
                                    ? Color.accentColor.opacity(0.08)
                                    : Color.clear
                            )
                        }
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                    }
                } else {
                    searchSuggestions
                }
            }
        }
        .background(AppBackgroundView(tab: .bible))
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Words or a reference")
        .onSubmit(of: .search) {
            submitSearch()
        }
        .onChange(of: query) { _, _ in
            debounceSearch()
        }
        .onChange(of: scope) { _, _ in
            // If switching away from Specific Book, clear selection visibility but keep last choice
            // Re-run search with new scope
            performSearch()
        }
        .onChange(of: selectedBook) { _, _ in
            // When a specific book changes, re-run search if scope is specific
            if scope == .specific {
                performSearch()
            }
        }
        .onAppear {
            performSearch()
        }
        // Popover for selecting a specific book (searchable & scrollable)
        .popover(isPresented: $showBookPicker, arrowEdge: .top) {
            VStack(spacing: 0) {
                HStack {
                    Text("Select a Book")
                        .font(.headline)
                    Spacer()
                    Button {
                        showBookPicker = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .imageScale(.large)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
                .padding()

                // Search field for filtering books
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search books", text: $bookQuery)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.words)
                    if !bookQuery.isEmpty {
                        Button {
                            bookQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear")
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                Divider()

                List(filteredBooksForPicker, id: \.name) { book in
                    Button {
                        selectedBook = book
                        showBookPicker = false
                    } label: {
                        HStack {
                            Text(book.name)
                            if selectedBook?.name == book.name {
                                Spacer()
                                Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(minWidth: 320, minHeight: 420)
        }
    }

    // MARK: - Scope Controls
    @ViewBuilder
    private var scopeControls: some View {
        // Segmented control for scope + conditional specific-book selector
        VStack(spacing: 8) {
            // Segmented control directly (no large backdrop)
            Picker("Scope", selection: $scope) {
                ForEach(SearchScope.allCases) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])

            HStack {
                Text(resultStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)

            if scope == .specific {
                HStack(spacing: 12) {
                    // Button that shows current selection and opens the dropdown
                    Button {
                        showBookPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "book")
                            Text(selectedBook?.name ?? "Choose a Book")
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.down")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    // Quick clear if a book is selected
                    if selectedBook != nil {
                        Button {
                            selectedBook = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .imageScale(.large)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear selected book")
                    }
                }
                .padding(.horizontal)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: scope)
    }

    private var resultStatusText: String {
        if isSearching { return "Searching…" }
        guard canSearch else { return "Ready to search" }
        return results.count == 1 ? "1 result" : "\(results.count) results"
    }

    private var searchSuggestions: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                suggestionSection(title: "Suggested", systemImage: "magnifyingglass", searches: suggestedSearches)
                if !recentSearches.isEmpty {
                    suggestionSection(title: "Recent", systemImage: "clock.arrow.circlepath", searches: recentSearches)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func suggestionSection(
        title: LocalizedStringKey,
        systemImage: String,
        searches: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            ForEach(searches, id: \.self) { search in
                Button {
                    query = search
                    saveRecentSearch(search)
                } label: {
                    Label(search, systemImage: systemImage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Open in Bible Tab
    private func openInBibleTab(_ item: SearchResult) {
        NotificationCenter.default.post(
            name: .openBibleReference,
            object: nil,
            userInfo: [
                "book": item.book.name,
                "chapter": item.chapter.number,
                "verse": item.verse.number
            ]
        )
    }

    private func submitSearch() {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        saveRecentSearch(trimmedQuery)

        if let referenceResults = resultsForReference(trimmedQuery),
           referenceResults.count == 1,
           let directResult = referenceResults.first {
            openInBibleTab(directResult)
        } else {
            performSearch()
        }
    }

    private func highlightedVerseText(_ item: SearchResult) -> AttributedString {
        var highlighted = AttributedString(item.verse.text)
        guard !item.isReferenceMatch else { return highlighted }

        for token in tokens {
            if let range = highlighted.range(
                of: token,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) {
                highlighted[range].backgroundColor = Color.accentColor.opacity(0.22)
                highlighted[range].font = .body.bold()
            }
        }

        return highlighted
    }

    // MARK: - Search Execution
    private func debounceSearch() {
        searchTask?.cancel()
        let currentQuery = query
        let currentScope = scope
        let currentSelectedBook = selectedBook
        isSearching = !currentQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        searchTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await performSearchAsync(for: currentQuery, scope: currentScope, selectedBook: currentSelectedBook)
        }
    }

    private func performSearch() {
        searchTask?.cancel()
        let current = query
        let currentScope = scope
        let currentSelectedBook = selectedBook
        isSearching = !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        Task { await performSearchAsync(for: current, scope: currentScope, selectedBook: currentSelectedBook) }
    }

    @MainActor
    private func performSearchAsync(for query: String, scope: SearchScope, selectedBook: Book?) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = trimmedQuery
            .lowercased()
            .split { $0.isWhitespace || $0.isPunctuation }
            .map(String.init)
            .filter { !$0.isEmpty }

        guard !tokens.isEmpty else {
            results = []
            isSearching = false
            return
        }

        if let referenceResults = resultsForReference(trimmedQuery) {
            results = referenceResults
            isSearching = false
            saveRecentSearch(trimmedQuery)
            return
        }

        // Decide which books to search based on scope
        let booksToSearch: [Book]
        switch scope {
        case .all:
            booksToSearch = canon
        case .ot:
            booksToSearch = otBooks
        case .nt:
            booksToSearch = ntBooks
        case .specific:
            if let b = selectedBook {
                booksToSearch = [b]
            } else {
                // No specific book selected yet
                results = []
                isSearching = false
                return
            }
        }

        // Offload heavy work off the main thread
        let maxResults = 200
        let found: [SearchResult] = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var temp: [SearchResult] = []
                outer: for book in booksToSearch {
                    for chapter in book.chapters {
                        for verse in chapter.verses {
                            let lower = verse.text.lowercased()
                            var matchesAll = true
                            for t in tokens {
                                if !lower.contains(t) { matchesAll = false; break }
                            }
                            if matchesAll {
                                temp.append(SearchResult(book: book, chapter: chapter, verse: verse))
                                if temp.count >= maxResults { break outer }
                            }
                        }
                    }
                }
                continuation.resume(returning: temp)
            }
        }

        // Update UI on main actor
        results = found
        isSearching = false
        saveRecentSearch(trimmedQuery)
    }

    private func saveRecentSearch(_ search: String) {
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var searches = recentSearches.filter {
            $0.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != .orderedSame
        }
        searches.insert(trimmed, at: 0)
        recentSearchesStorage = searches.prefix(6).joined(separator: "\n")
    }

    private func resultsForReference(_ query: String) -> [SearchResult]? {
        let parts = query.split(whereSeparator: \Character.isWhitespace).map(String.init)
        guard parts.count >= 2, let location = parts.last else { return nil }

        let locationParts = location.split(separator: ":", omittingEmptySubsequences: false)
        guard let chapterNumber = Int(locationParts[0]), chapterNumber > 0 else { return nil }
        let verseNumber = locationParts.count == 2 ? Int(locationParts[1]) : nil
        guard locationParts.count <= 2, locationParts.count == 1 || verseNumber != nil else { return nil }

        let bookQuery = parts.dropLast().joined(separator: " ")
        guard let book = bookMatchingReference(bookQuery),
              let chapter = book.chapters.first(where: { $0.number == chapterNumber }) else {
            return []
        }

        if let verseNumber {
            guard let verse = chapter.verses.first(where: { $0.number == verseNumber }) else { return [] }
            return [SearchResult(book: book, chapter: chapter, verse: verse, isReferenceMatch: true)]
        }

        return chapter.verses.map {
            SearchResult(book: book, chapter: chapter, verse: $0, isReferenceMatch: true)
        }
    }

    private func bookMatchingReference(_ reference: String) -> Book? {
        let normalized = normalizeBookName(reference)
        let aliases: [String: String] = [
            "gen": "Genesis", "ex": "Exodus", "exod": "Exodus", "lev": "Leviticus",
            "num": "Numbers", "deut": "Deuteronomy", "josh": "Joshua", "judg": "Judges",
            "ps": "Psalms", "psa": "Psalms", "psalm": "Psalms", "prov": "Proverbs",
            "eccl": "Ecclesiastes", "isa": "Isaiah", "jer": "Jeremiah", "ezek": "Ezekiel",
            "dan": "Daniel", "hos": "Hosea", "matt": "Matthew", "mk": "Mark",
            "mrk": "Mark", "lk": "Luke", "jn": "John", "jhn": "John", "acts": "Acts",
            "rom": "Romans", "cor": "Corinthians", "gal": "Galatians", "eph": "Ephesians",
            "phil": "Philippians", "col": "Colossians", "thess": "Thessalonians",
            "tim": "Timothy", "heb": "Hebrews", "jas": "James", "pet": "Peter",
            "rev": "Revelation"
        ]

        let expanded: String
        let components = normalized.split(separator: " ").map(String.init)
        if components.count > 1, let prefixNumber = Int(components[0]) {
            let remainder = components.dropFirst().joined(separator: " ")
            expanded = "\(prefixNumber) \(aliases[remainder] ?? remainder)"
        } else {
            expanded = aliases[normalized] ?? normalized
        }

        if let exactMatch = canon.first(where: {
            normalizeBookName($0.name) == normalizeBookName(expanded)
        }) {
            return exactMatch
        }

        let abbreviatedParts = normalizeBookName(expanded).split(separator: " ")
        let prefixMatches = canon.filter { book in
            let bookParts = normalizeBookName(book.name).split(separator: " ")
            return bookParts.count == abbreviatedParts.count
                && zip(bookParts, abbreviatedParts).allSatisfy { bookPart, abbreviation in
                    bookPart.hasPrefix(abbreviation)
                }
        }
        return prefixMatches.count == 1 ? prefixMatches[0] : nil
    }

    private func normalizeBookName(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct SearchResult: Identifiable, Hashable {
    let id = UUID()
    let book: Book
    let chapter: Chapter
    let verse: Verse
    let isReferenceMatch: Bool

    init(
        book: Book,
        chapter: Chapter,
        verse: Verse,
        isReferenceMatch: Bool = false
    ) {
        self.book = book
        self.chapter = chapter
        self.verse = verse
        self.isReferenceMatch = isReferenceMatch
    }
}

#Preview {
    NavigationStack { SearchView() }
}
