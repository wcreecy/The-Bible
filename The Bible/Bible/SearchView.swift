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

/// A fixed-size set of verse positions. Combining sets is a bitwise AND and walking one
/// yields positions in ascending order, so no hashing or sorting is needed.
nonisolated struct EntryBitSet: Sendable {
    private var blocks: [UInt64]

    init(capacity: Int) {
        blocks = Array(repeating: 0, count: (capacity + 63) / 64)
    }

    var isEmpty: Bool { !blocks.contains { $0 != 0 } }

    mutating func insert(_ position: Int) {
        blocks[position >> 6] |= 1 << UInt64(position & 63)
    }

    mutating func formIntersection(_ other: EntryBitSet) {
        for index in blocks.indices {
            blocks[index] &= other.blocks[index]
        }
    }

    /// Calls `body` with each position in ascending order until it returns false.
    func forEachEntryID(_ body: (Int) -> Bool) {
        for (blockIndex, block) in blocks.enumerated() {
            var remaining = block
            while remaining != 0 {
                let position = (blockIndex << 6) + remaining.trailingZeroBitCount
                if !body(position) { return }
                remaining &= remaining - 1
            }
        }
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
        guard let matches = matchingEntries(for: searchTokens, in: index) else { return [] }
        var results: [SearchResult] = []
        results.reserveCapacity(min(maxResults, 32))

        // Bits are visited in ascending entry order, which is canonical Bible order, so the
        // first page comes out already sorted and the scan stops as soon as it is full.
        matches.forEachEntryID { entryID in
            if Task.isCancelled { return false }
            let entry = index.entries[entryID]
            if let allowedBookIndices, !allowedBookIndices.contains(entry.bookIndex) {
                return true
            }
            append(entry, to: &results)
            return results.count < maxResults
        }
        return Task.isCancelled ? [] : results
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

    /// The verses containing a word that starts with every token, or nil when there are none.
    private func matchingEntries(for tokens: [String], in index: Index) -> EntryBitSet? {
        var matches: EntryBitSet?

        for token in tokens {
            guard let tokenMatches = entries(forPrefix: token, in: index) else { return nil }

            if var current = matches {
                current.formIntersection(tokenMatches)
                guard !current.isEmpty else { return nil }
                matches = current
            } else {
                matches = tokenMatches
            }
        }

        return matches
    }

    /// The verses containing a word that starts with `prefix`, or nil when there are none.
    private func entries(forPrefix prefix: String, in index: Index) -> EntryBitSet? {
        var matches = EntryBitSet(capacity: index.entries.count)
        var foundWord = false
        var wordIndex = lowerBound(of: prefix, in: index.sortedWords)

        while wordIndex < index.sortedWords.count {
            let word = index.sortedWords[wordIndex]
            guard word.hasPrefix(prefix) else { break }
            foundWord = true
            for entryID in index.postingsByWord[word, default: []] {
                matches.insert(entryID)
            }
            wordIndex += 1
        }
        return foundWord ? matches : nil
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
