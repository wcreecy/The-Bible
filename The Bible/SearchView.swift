import SwiftUI

struct SearchView: View {
    @State private var model = BibleSearchModel()
    @FocusState private var isSearchFieldFocused: Bool
    @AppStorage(AppStorageKey.contextualTipsEnabled) private var contextualTipsEnabled = false

    // Specific book picker state
    @State private var showBookPicker: Bool = false
    @State private var bookQuery: String = ""

    // Books for the popover list (filtered by bookQuery)
    private var filteredBooksForPicker: [Book] {
        let q = bookQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return BibleData.books }
        return BibleData.books.filter { $0.name.localizedCaseInsensitiveContains(q) }
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

            prominentSearchField

            // Scope controls below the search field
            scopeControls

            BibleSearchResultsView(model: model, onOpen: openInBibleTab)
        }
        .tabBarContentClearance()
        .background(AppBackgroundView(tab: .bible))
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isSearchFieldFocused = true
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
                        .textInputAutocapitalization(.sentences)
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
                        model.scopeBook = book
                        showBookPicker = false
                    } label: {
                        HStack {
                            Text(book.name)
                            if model.scopeBook?.name == book.name {
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

    private var prominentSearchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search words or a reference", text: $model.query)
                .focused($isSearchFieldFocused)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(true)
                .submitLabel(.search)
                .onSubmit(submitSearch)

            if !model.query.isEmpty {
                Button {
                    model.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .font(.body)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Bible search")
    }

    // MARK: - Scope Controls
    @ViewBuilder
    private var scopeControls: some View {
        // Segmented control for scope + conditional specific-book selector
        VStack(spacing: 8) {
            Picker("Scope", selection: $model.scope) {
                ForEach(BibleSearchScope.allCases) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])

            HStack {
                Text(model.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)

            if model.scope == .book {
                HStack(spacing: 12) {
                    // Button that shows current selection and opens the dropdown
                    Button {
                        showBookPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "book")
                            Text(model.scopeBook?.name ?? "Choose a Book")
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
                    if model.scopeBook != nil {
                        Button {
                            model.scopeBook = nil
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
        .animation(.easeInOut, value: model.scope)
    }

    // MARK: - Open in Bible Tab
    private func openInBibleTab(_ item: SearchResult) {
        isSearchFieldFocused = false
        Task { @MainActor in
            // Release the search field before replacing Home's navigation
            // hierarchy with the Bible tab.
            await Task.yield()
            AppRouter.shared.openBibleReference(
                book: item.bookName,
                chapter: item.chapterNumber,
                verse: item.verseNumber
            )
        }
    }

    private func submitSearch() {
        model.saveRecentSearch()
        if let directResult = model.directReferenceResult() {
            openInBibleTab(directResult)
        }
    }
}

struct SearchResult: Identifiable, Hashable, Sendable {
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

actor BibleSearchIndex {
    static let shared = BibleSearchIndex()

    private struct Entry: Sendable {
        let bookIndex: Int
        let bookName: String
        let chapterNumber: Int
        let verseNumber: Int
        let verseText: String
    }

    private struct Index: Sendable {
        let entries: [Entry]
        /// Each complete word points to its canonically ordered verse positions.
        let postingsByWord: [String: [Int]]
        /// Sorted once at build time so prefix queries can visit only matching terms.
        let sortedWords: [String]
    }

    private var index: Index?
    private var indexBuildTask: Task<Index, Never>?

    func search(
        tokens: [String],
        allowedBookIndices: Range<Int>?,
        maxResults: Int
    ) async -> [SearchResult] {
        let index = await indexedVerses()
        let searchTokens = Array(Set(tokens)).sorted { $0.count > $1.count }
        guard let entryIDs = matchingEntryIDs(for: searchTokens, in: index) else { return [] }
        var results: [SearchResult] = []
        results.reserveCapacity(min(maxResults, 32))

        // Prefix searches such as "the" can match thousands of verses. Sorting every
        // matching ID just to display the first page is wasteful; entries are already in
        // canonical order, so scan until the requested page is full for broad result sets.
        if entryIDs.count > maxResults * 4 {
            for (entryID, entry) in index.entries.enumerated() {
                if Task.isCancelled { return [] }
                guard entryIDs.contains(entryID) else { continue }
                if let allowedBookIndices, !allowedBookIndices.contains(entry.bookIndex) {
                    continue
                }
                append(entry, to: &results)
                if results.count == maxResults { break }
            }
        } else {
            for entryID in entryIDs.sorted() {
                if Task.isCancelled { return [] }
                let entry = index.entries[entryID]
                if let allowedBookIndices, !allowedBookIndices.contains(entry.bookIndex) {
                    continue
                }
                append(entry, to: &results)
                if results.count == maxResults { break }
            }
        }
        return results
    }

    private func append(_ entry: Entry, to results: inout [SearchResult]) {
        results.append(SearchResult(
            bookIndex: entry.bookIndex,
            bookName: entry.bookName,
            chapterNumber: entry.chapterNumber,
            verseNumber: entry.verseNumber,
            verseText: entry.verseText,
            isReferenceMatch: false
        ))
    }

    private func matchingEntryIDs(for tokens: [String], in index: Index) -> Set<Int>? {
        var matchingIDs: Set<Int>?

        for token in tokens {
            let tokenIDs = entryIDs(forPrefix: token, in: index)
            guard !tokenIDs.isEmpty else { return nil }

            if let currentIDs = matchingIDs {
                let intersection = currentIDs.intersection(tokenIDs)
                guard !intersection.isEmpty else { return nil }
                matchingIDs = intersection
            } else {
                matchingIDs = tokenIDs
            }
        }

        return matchingIDs
    }

    private func entryIDs(forPrefix prefix: String, in index: Index) -> Set<Int> {
        var ids: Set<Int> = []
        var wordIndex = lowerBound(of: prefix, in: index.sortedWords)

        while wordIndex < index.sortedWords.count {
            let word = index.sortedWords[wordIndex]
            guard word.hasPrefix(prefix) else { break }
            ids.formUnion(index.postingsByWord[word, default: []])
            wordIndex += 1
        }
        return ids
    }

    private func lowerBound(of value: String, in sortedWords: [String]) -> Int {
        var lower = 0
        var upper = sortedWords.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if sortedWords[middle] < value {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower
    }

    private func indexedVerses() async -> Index {
        if let index { return index }

        let task: Task<Index, Never>
        if let indexBuildTask {
            task = indexBuildTask
        } else {
            // Wait for the corpus rather than reading the synchronous snapshot, which is
            // empty during launch and would otherwise be cached as an empty index.
            let books = await BibleRepository.shared.loadAllBooks()
            let newTask = Task.detached(priority: .userInitiated) {
                var entries: [Entry] = []
                var postingsByWord: [String: [Int]] = [:]

                for (bookIndex, book) in books.enumerated() {
                    for chapter in book.chapters {
                        for verse in chapter.verses {
                            let entryID = entries.count
                            entries.append(Entry(
                                bookIndex: bookIndex,
                                bookName: book.name,
                                chapterNumber: chapter.number,
                                verseNumber: verse.number,
                                verseText: verse.text
                            ))
                            for word in Set(BibleSearchTokenizer.tokens(in: verse.text)) {
                                postingsByWord[word, default: []].append(entryID)
                            }
                        }
                    }
                }

                return Index(
                    entries: entries,
                    postingsByWord: postingsByWord,
                    sortedWords: postingsByWord.keys.sorted()
                )
            }
            indexBuildTask = newTask
            task = newTask
        }

        let built = await AppPerformance.measure("BibleSearchIndexBuild") { await task.value }
        index = built
        indexBuildTask = nil
        return built
    }
}

#Preview {
    NavigationStack { SearchView() }
}
