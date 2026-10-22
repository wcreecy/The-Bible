import SwiftUI

/// Normalizes search text into complete words for both indexing and querying.
enum BibleSearchTokenizer {
    nonisolated static func tokens(in text: String) -> [String] {
        text
            .lowercased()
            .split { $0.isWhitespace || $0.isPunctuation }
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    nonisolated static func matches(_ queryTokens: [String], verseWords: Set<String>) -> Bool {
        queryTokens.allSatisfy { queryToken in
            verseWords.contains { $0.hasPrefix(queryToken) }
        }
    }
}

/// Which part of the Bible a text search covers.
enum BibleSearchScope: String, CaseIterable, Identifiable {
    case all = "OT & NT"
    case ot = "OT"
    case nt = "NT"
    case book = "Book"

    var id: String { rawValue }
}

/// Shared Bible text search used by the iPhone Search screen and the iPad Bible tab.
/// Searches run off the main thread against `BibleSearchIndex`, are debounced while
/// typing, and are cancelled when the query or scope changes.
@MainActor
@Observable
final class BibleSearchModel {
    static let maxResults = 200
    private static let recentSearchesKey = AppStorageKey.bibleRecentSearches
    private static let recentSearchLimit = 6

    let suggestedSearches = ["love", "faith", "peace", "John 3:16", "Psalm 23"]

    var query = "" {
        didSet {
            // Some hardware keyboard layouts send ";" for Shift-;. A semicolon is not
            // meaningful in a Bible reference, so treat it as ":".
            let normalized = query.replacingOccurrences(of: ";", with: ":")
            if normalized != query {
                query = normalized
                return
            }
            if query != oldValue {
                scheduleSearch(debounced: true)
            }
        }
    }

    var scope: BibleSearchScope = .all {
        didSet {
            if scope != oldValue { scheduleSearch(debounced: false) }
        }
    }

    /// The book searched when `scope` is `.book`.
    var scopeBook: Book? {
        didSet {
            if scope == .book, scopeBook?.name != oldValue?.name {
                scheduleSearch(debounced: false)
            }
        }
    }

    private(set) var results: [SearchResult] = []
    private(set) var isSearching = false
    /// Whether matches beyond `maxResults` were left out.
    private(set) var hasMoreResults = false
    private(set) var recentSearches: [String] = []

    private var searchTask: Task<Void, Never>?

    init() {
        recentSearches = (UserDefaults.standard.string(forKey: Self.recentSearchesKey) ?? "")
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
    }

    var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSearch: Bool { !trimmedQuery.isEmpty }

    /// A book scope with no book chosen yet has nothing to search.
    var needsBookSelection: Bool { scope == .book && scopeBook == nil }

    var tokens: [String] { BibleSearchTokenizer.tokens(in: query) }

    var statusText: String {
        if isSearching { return "Searching…" }
        guard canSearch else { return "Ready to search" }
        if hasMoreResults { return "Showing the first \(Self.maxResults) results" }
        return results.count == 1 ? "1 result" : "\(results.count) results"
    }

    /// The single verse a reference query names, if any (e.g. "John 3:16").
    func directReferenceResult() -> SearchResult? {
        guard let results = BibleReferenceParser.results(for: trimmedQuery, in: BibleData.books),
              results.count == 1 else { return nil }
        return results.first
    }

    func saveRecentSearch(_ search: String? = nil) {
        let trimmed = (search ?? query).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var searches = recentSearches.filter {
            $0.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != .orderedSame
        }
        searches.insert(trimmed, at: 0)
        recentSearches = Array(searches.prefix(Self.recentSearchLimit))
        UserDefaults.standard.set(recentSearches.joined(separator: "\n"), forKey: Self.recentSearchesKey)
    }

    func highlightedText(for item: SearchResult) -> AttributedString {
        var highlighted = AttributedString(item.verseText)
        guard !item.isReferenceMatch else { return highlighted }

        for token in tokens {
            var searchRange = highlighted.startIndex..<highlighted.endIndex
            while let range = highlighted[searchRange].range(
                of: token,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) {
                highlighted[range].backgroundColor = Color.accentColor.opacity(0.22)
                highlighted[range].font = .body.bold()
                searchRange = range.upperBound..<highlighted.endIndex
            }
        }
        return highlighted
    }

    // MARK: - Searching

    private func scheduleSearch(debounced: Bool) {
        searchTask?.cancel()
        let query = trimmedQuery
        let scope = scope
        let scopeBookName = scopeBook?.name

        guard !BibleSearchTokenizer.tokens(in: query).isEmpty else {
            results = []
            hasMoreResults = false
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task { [weak self] in
            if debounced {
                try? await Task.sleep(for: .milliseconds(300))
            }
            guard !Task.isCancelled else { return }
            let outcome = await AppPerformance.measure(
                "SearchFirstResult",
                budget: PerformanceBudget.searchFirstResult
            ) {
                await Self.search(query: query, scope: scope, scopeBookName: scopeBookName)
            }
            guard !Task.isCancelled, let self else { return }
            results = outcome.results
            hasMoreResults = outcome.hasMore
            isSearching = false
        }
    }

    private static func search(
        query: String,
        scope: BibleSearchScope,
        scopeBookName: String?
    ) async -> (results: [SearchResult], hasMore: Bool) {
        // Waits for the corpus so an early search never runs against an empty Bible.
        let books = await BibleRepository.shared.loadAllBooks()

        if let referenceResults = BibleReferenceParser.results(for: query, in: books) {
            return (referenceResults, false)
        }

        let matthewIndex = books.firstIndex { $0.name == "Matthew" } ?? books.count
        let allowedBookIndices: Range<Int>?
        switch scope {
        case .all:
            allowedBookIndices = nil
        case .ot:
            allowedBookIndices = 0..<matthewIndex
        case .nt:
            allowedBookIndices = matthewIndex..<books.count
        case .book:
            guard let scopeBookName,
                  let index = books.firstIndex(where: { $0.name == scopeBookName }) else {
                return ([], false)
            }
            allowedBookIndices = index..<(index + 1)
        }

        // One extra result reveals whether the list was cut off.
        let found = await BibleSearchIndex.shared.search(
            tokens: BibleSearchTokenizer.tokens(in: query),
            allowedBookIndices: allowedBookIndices,
            maxResults: maxResults + 1
        )
        return (Array(found.prefix(maxResults)), found.count > maxResults)
    }

}

/// Suggestions, progress, empty states, and results for a `BibleSearchModel`.
/// The search field and scope controls are supplied by the hosting screen.
struct BibleSearchResultsView: View {
    let model: BibleSearchModel
    var bookSelectionMessage: LocalizedStringKey = "Choose a book to search."
    let onOpen: (SearchResult) -> Void

    var body: some View {
        if !model.canSearch {
            suggestions
        } else if model.needsBookSelection {
            ContentUnavailableView(
                "Choose a Book",
                systemImage: "book",
                description: Text(bookSelectionMessage)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.isSearching && model.results.isEmpty {
            ProgressView("Searching…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.results.isEmpty {
            ContentUnavailableView(
                "No Results",
                systemImage: "magnifyingglass",
                description: Text("Try different keywords or check spelling.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(model.results) { item in
                    BibleSearchResultRow(
                        item: item,
                        highlightedText: model.highlightedText(for: item),
                        onOpen: { open(item) }
                    )
                }

                if model.hasMoreResults {
                    Text("Showing the first \(BibleSearchModel.maxResults) results. Add words or narrow the scope to see more specific matches.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
    }

    private func open(_ item: SearchResult) {
        model.saveRecentSearch()
        onOpen(item)
    }

    private var suggestions: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                suggestionSection(title: "Suggested", systemImage: "magnifyingglass", searches: model.suggestedSearches)
                if !model.recentSearches.isEmpty {
                    suggestionSection(title: "Recent", systemImage: "clock.arrow.circlepath", searches: model.recentSearches)
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
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)

            ForEach(searches, id: \.self) { search in
                Button {
                    model.query = search
                    model.saveRecentSearch(search)
                } label: {
                    Text(search)
                        .font(.subheadline.weight(.regular))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.035))
        }
    }
}

struct BibleSearchResultRow: View {
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
