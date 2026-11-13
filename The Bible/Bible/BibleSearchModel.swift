import SwiftData
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

    let suggestedSearches = ["love", "faith", "peace", "John 3:16", "Psalm 23", "G3056"]

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
    /// Highlighting every visible row during `body` is expensive for broad searches. Store
    /// the completed display text with the search outcome and let row rendering be a lookup.
    private var highlightedResults: [SearchResult.ID: AttributedString] = [:]
    private(set) var isSearching = false
    /// Whether matches beyond `maxResults` were left out.
    private(set) var hasMoreResults = false
    /// Set when the results are the verses using a Hebrew or Greek word (a Strong's number such
    /// as "G3056", the word in its own letters, or a transliteration English found nothing for).
    private(set) var strongsMatch: StrongsSearchMatch?
    /// Named topics and events the query matches ("Lord's Prayer"), shown above the verses.
    private(set) var termMatches: [BibleTerm] = []
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
        let translation = BibleRepository.shared.activeTranslation.abbreviation
        if isSearching { return "Searching \(translation)…" }
        guard canSearch else { return "Ready to search \(translation)" }
        if hasMoreResults { return "Showing the first \(Self.maxResults) \(translation) results" }
        return results.count == 1 ? "1 \(translation) result" : "\(results.count) \(translation) results"
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
        highlightedResults[item.id] ?? AttributedString(item.verseText)
    }

    private static func highlightedText(for item: SearchResult, tokens: [String]) -> AttributedString {
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
            highlightedResults = [:]
            hasMoreResults = false
            strongsMatch = nil
            termMatches = []
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task { [weak self] in
            if debounced {
                try? await Task.sleep(for: .milliseconds(300))
            }
            guard !Task.isCancelled else { return }
            // Topics are matched alongside the verse search and shown with any kind of result,
            // including references ("Psalm 23") and words the text never uses ("rapture").
            async let terms = BibleTermSearch.shared.matches(for: query)
            let outcome = await AppPerformance.measure(
                "SearchFirstResult",
                budget: PerformanceBudget.searchFirstResult
            ) {
                await Self.search(query: query, scope: scope, scopeBookName: scopeBookName)
            }
            let matchedTerms = await terms
            guard !Task.isCancelled, let self else { return }
            let queryTokens = BibleSearchTokenizer.tokens(in: query)
            termMatches = matchedTerms
            results = outcome.results
            // A Hebrew or Greek word isn't in the English text, so there is nothing to highlight.
            highlightedResults = outcome.strongsMatch == nil
                ? Dictionary(
                    uniqueKeysWithValues: outcome.results.map { item in
                        (item.id, Self.highlightedText(for: item, tokens: queryTokens))
                    }
                )
                : [:]
            hasMoreResults = outcome.hasMore
            strongsMatch = outcome.strongsMatch
            isSearching = false
        }
    }

    private static func search(
        query: String,
        scope: BibleSearchScope,
        scopeBookName: String?
    ) async -> (results: [SearchResult], hasMore: Bool, strongsMatch: StrongsSearchMatch?) {
        // Waits for the corpus so an early search never runs against an empty Bible.
        let books = await BibleRepository.shared.loadAllBooks()

        if let referenceResults = BibleReferenceParser.results(for: query, in: books) {
            return (referenceResults, false, nil)
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
                return ([], false, nil)
            }
            allowedBookIndices = index..<(index + 1)
        }

        // A Strong's number or a word in Greek or Hebrew letters can't be an English search.
        let translation = BibleRepository.shared.activeTranslation
        if let strongs = await StrongsSearch.search(
            query,
            allowingTransliteration: false,
            translation: translation,
            books: books,
            allowedBookIndices: allowedBookIndices,
            maxResults: maxResults
        ) {
            return (strongs.results, strongs.hasMore, strongs.match)
        }

        // One extra result reveals whether the list was cut off.
        let found = await BibleSearchIndex.shared.search(
            tokens: BibleSearchTokenizer.tokens(in: query),
            allowedBookIndices: allowedBookIndices,
            maxResults: maxResults + 1
        )

        // English found nothing; "agape" isn't in the KJV but is a Greek word.
        if found.isEmpty, let strongs = await StrongsSearch.search(
            query,
            allowingTransliteration: true,
            translation: translation,
            books: books,
            allowedBookIndices: allowedBookIndices,
            maxResults: maxResults
        ) {
            return (strongs.results, strongs.hasMore, strongs.match)
        }
        return (Array(found.prefix(maxResults)), found.count > maxResults, nil)
    }

}

/// Suggestions, progress, empty states, and results for a `BibleSearchModel`.
/// The search field and scope controls are supplied by the hosting screen.
struct BibleSearchResultsView: View {
    // Queried once here and shared by every row; each row's menu would otherwise run its own.
    @Query private var favorites: [Favorite]
    @Query private var notes: [VerseNote]
    @Query private var userNotes: [UserNote]
    @Query private var bookmarks: [Bookmark]
    @State private var verseToast = VerseActionToastState()
    @State private var showsAllTerms = false

    /// Topics shown before "Show All"; broad words such as "prayer" match many.
    private static let collapsedTermCount = 3

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
        } else if model.isSearching && model.results.isEmpty && model.termMatches.isEmpty {
            ProgressView("Searching…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.results.isEmpty && model.termMatches.isEmpty {
            ContentUnavailableView(
                "No Results",
                systemImage: "magnifyingglass",
                description: Text("Try different keywords or check spelling.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let saved = SavedVerseCollections(
                favorites: favorites,
                notes: notes,
                userNotes: userNotes,
                bookmarks: bookmarks
            )
            List {
                if !model.termMatches.isEmpty {
                    termsSection
                }

                Section {
                    if let match = model.strongsMatch {
                        StrongsSearchHeader(match: match, onOpenVerse: onOpen)
                            .listRowBackground(Color.accentColor.opacity(0.08))
                    }

                    ForEach(model.results) { item in
                        BibleSearchResultRow(
                            item: item,
                            saved: saved,
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
                } header: {
                    // Only needed to separate verses from topics.
                    if !model.termMatches.isEmpty && !model.results.isEmpty {
                        Label("Verses", systemImage: "text.quote")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .verseActionToast($verseToast)
            // Topic rows open a preview of their whole passage.
            .scripturePassagePreviews()
            .onChange(of: model.termMatches) {
                showsAllTerms = false
            }
        }
    }

    private var termsSection: some View {
        let terms = model.termMatches
        let visibleTerms = showsAllTerms ? terms : Array(terms.prefix(Self.collapsedTermCount))
        return Section {
            ForEach(visibleTerms) { term in
                BibleTermRow(term: term)
            }

            if terms.count > Self.collapsedTermCount {
                Button(showsAllTerms ? "Show Fewer Topics" : "Show All \(terms.count) Topics") {
                    withAnimation { showsAllTerms.toggle() }
                }
                .font(.subheadline.weight(.semibold))
            }
        } header: {
            Label("Topics", systemImage: "text.book.closed")
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

/// A named topic or event. Tapping the text previews its main passage; each passage chip
/// below previews that passage.
struct BibleTermRow: View {
    let term: BibleTerm

    /// Handled by `scripturePassagePreviews()` on the list, which shows the passage sheet.
    @Environment(\.openURL) private var openURL

    var body: some View {
        // Separate styled buttons (not nested) so the list routes each tap to the one touched
        // instead of treating the whole row as one button.
        VStack(alignment: .leading, spacing: 10) {
            Button {
                if let passage = term.primaryPassage {
                    openURL(passage.url)
                }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(term.category)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)

                        Text(term.term)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(term.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            // Plain, not borderless: a borderless button tints its whole label with the accent color.
            .buttonStyle(.plain)
            .accessibilityHint("Shows a preview of the main passage")

            BibleTermPassageChips(term: term) { passage in
                openURL(passage.url)
            }
        }
        .padding(.vertical, 4)
    }
}

/// One tappable chip per passage of a topic, wrapping onto more lines as needed.
struct BibleTermPassageChips: View {
    let term: BibleTerm
    let onSelect: (PassageReference) -> Void

    var body: some View {
        PassageFlowLayout(spacing: 8) {
            ForEach(term.passages) { passage in
                Button {
                    onSelect(passage)
                } label: {
                    Text(passage.displayTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(1)
                        // Keeps the chip at its text's width instead of wrapping into a tall capsule.
                        .fixedSize()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows a preview of this passage")
            }
        }
    }
}

struct BibleSearchResultRow: View {
    let item: SearchResult
    let saved: SavedVerseCollections
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

                    if item.isOmitted {
                        Text(Verse.omittedNote(in: BibleRepository.shared.activeTranslation))
                            .font(.subheadline.italic())
                            .foregroundStyle(.secondary)
                    } else {
                        Text(highlightedText)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .lineLimit(3)
                    }

                    Text("\(item.bookName) \(item.chapterNumber):\(item.verseNumber)")
                        .font(.caption)
                        .foregroundStyle(item.isReferenceMatch ? Color.accentColor : Color.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            // An omitted verse has nothing to save or share.
            if !item.isOmitted {
                VerseActionMenuContent(
                    verse: VerseActionReference(
                        bookName: item.bookName,
                        chapterNumber: item.chapterNumber,
                        verseNumber: item.verseNumber,
                        verseText: item.verseText
                    ),
                    saved: saved
                )
            }
        }
        .listRowBackground(
            item.isReferenceMatch
                ? Color.accentColor.opacity(0.08)
                : Color.clear
        )
    }
}
