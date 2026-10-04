import SwiftUI

struct SearchView: View {
    // MARK: - Query & Results
    @State private var query: String = ""
    @State private var results: [SearchResult] = []
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var isSearching: Bool = false
    @AppStorage("bibleRecentSearches") private var recentSearchesStorage: String = ""
    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false

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
            if contextualTipsEnabled {
                ContextualTipView(
                    id: "search.references",
                    title: "Search words or references",
                    message: "Search for words such as love or faith, or enter a reference such as John 3:16. Use the scope controls to narrow the results.",
                    systemImage: "magnifyingglass"
                )
                .padding(.horizontal)
                .padding(.vertical, 12)
            }

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
                            SearchResultRow(
                                item: item,
                                highlightedText: highlightedVerseText(item),
                                onOpen: { openInBibleTab(item) }
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
                "book": item.bookName,
                "chapter": item.chapterNumber,
                "verse": item.verseNumber
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
        var highlighted = AttributedString(item.verseText)
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
        searchTask = Task {
            await performSearchAsync(for: current, scope: currentScope, selectedBook: currentSelectedBook)
        }
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

        // Restrict the immutable index without copying Book or Chapter values.
        let allowedBookIndices: Range<Int>?
        switch scope {
        case .all:
            allowedBookIndices = nil
        case .ot:
            allowedBookIndices = 0..<matthewIndex
        case .nt:
            allowedBookIndices = matthewIndex..<canon.count
        case .specific:
            if let selectedBook,
               let bookIndex = indexMap[selectedBook.name] {
                allowedBookIndices = bookIndex..<(bookIndex + 1)
            } else {
                // No specific book selected yet
                results = []
                isSearching = false
                return
            }
        }

        let found = await BibleSearchIndex.shared.search(
            tokens: tokens,
            allowedBookIndices: allowedBookIndices,
            maxResults: 200
        )

        // Update UI on main actor
        guard !Task.isCancelled else { return }
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
            return [SearchResult(
                bookIndex: indexMap[book.name] ?? 0,
                bookName: book.name,
                chapterNumber: chapter.number,
                verseNumber: verse.number,
                verseText: verse.text,
                isReferenceMatch: true
            )]
        }

        return chapter.verses.map { verse in
            SearchResult(
                bookIndex: indexMap[book.name] ?? 0,
                bookName: book.name,
                chapterNumber: chapter.number,
                verseNumber: verse.number,
                verseText: verse.text,
                isReferenceMatch: true
            )
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

private struct SearchResultRow: View {
    let item: SearchResult
    let highlightedText: AttributedString
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 6) {
                    if item.isReferenceMatch {
                        Label("Direct Reference", systemImage: "arrow.up.right.square")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                    }

                    Text(highlightedText)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(3)

                    Text("\(item.bookName) \(item.chapterNumber):\(item.verseNumber)")
                        .font(.caption)
                        .foregroundStyle(item.isReferenceMatch ? Color.accentColor : Color.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            VerseActionMenu(
                verse: VerseActionReference(
                    bookName: item.bookName,
                    chapterNumber: item.chapterNumber,
                    verseNumber: item.verseNumber,
                    verseText: item.verseText
                )
            )
        }
        .listRowBackground(
            item.isReferenceMatch
                ? Color.accentColor.opacity(0.08)
                : Color.clear
        )
    }
}

private struct SearchResult: Identifiable, Hashable, Sendable {
    let bookIndex: Int
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
    let verseText: String
    let isReferenceMatch: Bool

    var id: String {
        "\(bookIndex):\(chapterNumber):\(verseNumber)"
    }
}

private actor BibleSearchIndex {
    static let shared = BibleSearchIndex()

    private struct SourceEntry: Sendable {
        let bookIndex: Int
        let bookName: String
        let chapterNumber: Int
        let verseNumber: Int
        let verseText: String
    }

    private struct Entry: Sendable {
        let bookIndex: Int
        let bookName: String
        let chapterNumber: Int
        let verseNumber: Int
        let verseText: String
        let normalizedText: String
    }

    private var entries: [Entry]?
    private var sourceTask: Task<[SourceEntry], Never>?

    func search(
        tokens: [String],
        allowedBookIndices: Range<Int>?,
        maxResults: Int
    ) async -> [SearchResult] {
        let entries = await indexedVerses()
        let searchTokens = Array(Set(tokens)).sorted { $0.count > $1.count }
        var results: [SearchResult] = []
        results.reserveCapacity(min(maxResults, 32))

        for entry in entries {
            if Task.isCancelled { return [] }
            if let allowedBookIndices, !allowedBookIndices.contains(entry.bookIndex) {
                continue
            }
            guard searchTokens.allSatisfy(entry.normalizedText.contains) else { continue }

            results.append(SearchResult(
                bookIndex: entry.bookIndex,
                bookName: entry.bookName,
                chapterNumber: entry.chapterNumber,
                verseNumber: entry.verseNumber,
                verseText: entry.verseText,
                isReferenceMatch: false
            ))
            if results.count == maxResults { break }
        }
        return results
    }

    private func indexedVerses() async -> [Entry] {
        if let entries { return entries }

        let task: Task<[SourceEntry], Never>
        if let sourceTask {
            task = sourceTask
        } else {
            let newTask = Task { @MainActor in
                BibleData.books.enumerated().flatMap { bookIndex, book in
                    book.chapters.flatMap { chapter in
                        chapter.verses.map { verse in
                            SourceEntry(
                                bookIndex: bookIndex,
                                bookName: book.name,
                                chapterNumber: chapter.number,
                                verseNumber: verse.number,
                                verseText: verse.text
                            )
                        }
                    }
                }
            }
            sourceTask = newTask
            task = newTask
        }

        let source = await task.value
        let built = source.map { source in
            Entry(
                bookIndex: source.bookIndex,
                bookName: source.bookName,
                chapterNumber: source.chapterNumber,
                verseNumber: source.verseNumber,
                verseText: source.verseText,
                normalizedText: source.verseText.lowercased()
            )
        }
        entries = built
        return built
    }
}

#Preview {
    NavigationStack { SearchView() }
}
