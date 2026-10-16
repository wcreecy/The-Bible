import SwiftUI
import SwiftData
import UIKit

/// Saved Verses: favorite verses and highlighted verses, one list at a time.
struct FavoritesView: View {
    /// The two lists, chosen with the switch at the top.
    enum SavedList: String, CaseIterable, Identifiable {
        case favorites
        case highlights

        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .favorites: "Favorites"
            case .highlights: "Highlights"
            }
        }
    }

    /// How the list is ordered.
    enum SortOrder: String, CaseIterable, Identifiable {
        case recent
        case bibleOrder

        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .recent: "Recently Saved"
            case .bibleOrder: "Bible Order"
            }
        }
    }

    /// The single toast this screen shows.
    private enum ToastMessage: Equatable {
        case removed(count: Int)
        case copied
    }

    /// A group of rows: one untitled group for Recently Saved, one per book for Bible Order.
    private struct FavoriteSection: Identifiable {
        let title: String?
        let favorites: [Favorite]
        var id: String { title ?? "all" }
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Favorite.createdAt, order: .reverse)]) private var favorites: [Favorite]
    @Query(filter: #Predicate<VerseNote> { $0.highlightColor != "" }) private var highlights: [VerseNote]
    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false
    @AppStorage("favoritesSortOrder") private var sortOrder: SortOrder = .recent

    /// Not saved, so Saved Verses always opens on Favorites.
    @State private var shownList: SavedList = .favorites
    @State private var searchText: String = ""
    @State private var removedFavorites: [RemovedFavorite] = []
    @State private var toastMessage: ToastMessage?
    @State private var persistenceFailure: PersistenceFailure?

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var countSubtitle: String {
        Self.verseCount(favorites.count)
    }

    private static func verseCount(_ count: Int) -> String {
        count == 1 ? String(localized: "1 verse") : String(localized: "\(count) verses")
    }

    /// The count for the list on screen.
    private var shownCount: Int {
        shownList == .favorites ? favorites.count : highlights.count
    }

    var body: some View {
        Group {
            switch shownList {
            case .favorites:
                favoritesContent
            case .highlights:
                SavedHighlightsView(
                    notes: highlights,
                    searchText: searchText,
                    sortOrder: sortOrder,
                    bookNames: bookNames
                )
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker("Show", selection: $shownList.animation(.snappy)) {
                ForEach(SavedList.allCases) { list in
                    Text(list.title).tag(list)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(AppBackgroundView(tab: .more))
        .navigationTitle("Saved Verses")
        .navigationSubtitle(shownCount == 0 ? "" : Self.verseCount(shownCount))
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarContent }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: shownList == .favorites ? "Search favorites" : "Search highlights and notes"
        )
        .appToast(
            isPresented: isShowingToast,
            symbol: toastMessage == .copied ? "doc.on.doc" : "heart.slash",
            text: toastText,
            tint: .secondary,
            actionTitle: isShowingRemovalToast ? String(localized: "Undo") : nil,
            action: toastAction
        )
        .persistenceFailureAlert(failure: $persistenceFailure)
    }

    @ViewBuilder
    private var favoritesContent: some View {
        // Computed once per update and shared by the list and its delete handlers.
        let sections = makeSections(from: filteredFavorites())

        Group {
            if favorites.isEmpty {
                ContentUnavailableView(
                    "No Favorites",
                    systemImage: "heart",
                    description: Text("Long-press a verse and tap the heart to save it here.")
                )
            } else if sections.isEmpty && isSearching {
                ContentUnavailableView(
                    "No Matches",
                    systemImage: "magnifyingglass",
                    description: Text("Try a reference like “John 3” or words from the verse.")
                )
            } else {
                favoritesList(sections: sections)
            }
        }
    }

    // MARK: - List

    private func favoritesList(sections: [FavoriteSection]) -> some View {
        List {
            if contextualTipsEnabled {
                ContextualTipView(
                    id: "favorites.management",
                    title: "Open and manage favorites",
                    message: "Tap a favorite to open its verse. Long-press for Copy and Share, or swipe to share or remove it, with an option to undo.",
                    systemImage: "heart.text.clipboard"
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            if !isSearching {
                flashcardsRow
            }

            ForEach(sections) { section in
                Section {
                    ForEach(section.favorites) { favorite in
                        row(for: favorite)
                    }
                    .onDelete { offsets in
                        remove(offsets.map { section.favorites[$0] })
                    }
                    .listRowBackground(HeroCardListRowBackground())
                } header: {
                    if let title = section.title {
                        Text(title)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var flashcardsRow: some View {
        Section {
            NavigationLink {
                FavoritesFlashcardsView()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Practice as Flashcards")
                            .font(.headline)
                        Text("Memorize your \(countSubtitle)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "rectangle.on.rectangle.angled")
                        .foregroundStyle(.tint)
                }
            }
        }
        .listRowBackground(HeroCardListRowBackground())
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if shownCount > 0 {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Sort By", selection: $sortOrder) {
                        ForEach(SortOrder.allCases) { order in
                            Text(order.title).tag(order)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
            }
        }
        // Editing removes several favorites at once; highlights are removed one at a time.
        if shownList == .favorites && !favorites.isEmpty {
            ToolbarItem(placement: .primaryAction) { EditButton() }
        }
    }

    // MARK: - Row

    private func row(for favorite: Favorite) -> some View {
        Button {
            openInBibleTab(favorite)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(favorite.reference)
                    .font(.headline)
                Text(favorite.currentVerseText)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Text("Saved \(favorite.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the verse in the Bible")
        .contextMenu {
            Button("Open in Bible", systemImage: "book") { openInBibleTab(favorite) }
            Button("Copy", systemImage: "doc.on.doc") { copy(favorite) }
            ShareLink(item: favorite.shareText) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Divider()
            Button("Remove Favorite", systemImage: "heart.slash", role: .destructive) { remove([favorite]) }
        }
        .swipeActions(edge: .leading) {
            ShareLink(item: favorite.shareText) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing) {
            Button("Remove", systemImage: "heart.slash", role: .destructive) { remove([favorite]) }
        }
    }

    // MARK: - Filtering and grouping

    private func filteredFavorites() -> [Favorite] {
        guard let query = SavedVerseSearchQuery(searchText, bookNames: bookNames) else { return favorites }
        return favorites.filter { query.matches($0) }
    }

    private func makeSections(from list: [Favorite]) -> [FavoriteSection] {
        guard !list.isEmpty else { return [] }
        switch sortOrder {
        case .recent:
            return [FavoriteSection(title: nil, favorites: list)]
        case .bibleOrder:
            let bookIndex = Dictionary(bookNames.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
            let sorted = list.sorted {
                let lhs = (bookIndex[$0.bookName] ?? .max, $0.chapterNumber, $0.verseNumber)
                let rhs = (bookIndex[$1.bookName] ?? .max, $1.chapterNumber, $1.verseNumber)
                return lhs < rhs
            }
            var sections: [FavoriteSection] = []
            for favorite in sorted {
                if let last = sections.last, last.title == favorite.bookName {
                    sections[sections.count - 1] = FavoriteSection(title: last.title, favorites: last.favorites + [favorite])
                } else {
                    sections.append(FavoriteSection(title: favorite.bookName, favorites: [favorite]))
                }
            }
            return sections
        }
    }

    /// Book names in Bible order, or the saved verses' own books while the Bible is loading.
    private var bookNames: [String] {
        let names = BibleData.books.map(\.name)
        return names.isEmpty ? Array(Set(favorites.map(\.bookName) + highlights.map(\.bookName))).sorted() : names
    }

    // MARK: - Actions

    // Switches to the Bible tab and opens the verse.
    private func openInBibleTab(_ fav: Favorite) {
        AppRouter.shared.openBibleReference(
            book: fav.bookName,
            chapter: fav.chapterNumber,
            verse: fav.verseNumber
        )
    }

    private func copy(_ favorite: Favorite) {
        UIPasteboard.general.string = favorite.shareText
        Haptics.success()
        toastMessage = .copied
    }

    private func remove(_ items: [Favorite]) {
        guard !items.isEmpty else { return }
        let removalSnapshot = items.map { RemovedFavorite($0) }

        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                for item in items {
                    modelContext.delete(item)
                }
                try modelContext.save()
            },
            onSuccess: {
                removedFavorites = removalSnapshot
                Haptics.selection()
                toastMessage = .removed(count: removalSnapshot.count)
            },
            onFailure: { persistenceFailure = $0 }
        )
    }

    private var isShowingToast: Binding<Bool> {
        Binding(
            get: { toastMessage != nil },
            set: { if !$0 { toastMessage = nil } }
        )
    }

    private var toastAction: (() -> Void)? {
        guard isShowingRemovalToast else { return nil }
        return { undoFavoriteRemoval() }
    }

    private var isShowingRemovalToast: Bool {
        if case .removed = toastMessage { return true }
        return false
    }

    private var toastText: String {
        switch toastMessage {
        case .copied: String(localized: "Copied")
        case .removed(let count): count == 1 ? String(localized: "Favorite removed") : String(localized: "Favorites removed")
        case nil: ""
        }
    }

    private func undoFavoriteRemoval() {
        let favoritesToRestore = removedFavorites

        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                for favorite in favoritesToRestore {
                    modelContext.insert(favorite.model)
                }
                try modelContext.save()
            },
            onSuccess: {
                removedFavorites = []
                Haptics.success()
            },
            onFailure: { persistenceFailure = $0 }
        )
    }
}

/// Parses a Saved Verses search. A query that starts with a book name ("1 John", "John 3:16")
/// narrows to that book, with the next numbers taken as chapter and verse. Anything else
/// must appear in the verse text, a highlight's note, or the book name, and bare numbers
/// must equal the chapter or a verse, so "1" doesn't match every reference that merely
/// contains a 1.
struct SavedVerseSearchQuery {
    let book: String?
    let numbers: [Int]
    let words: [String]

    @MainActor
    init?(_ text: String, bookNames: [String]) {
        var query = text.lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard !query.isEmpty else { return nil }

        // Longest matching book name first, so "1 John" wins over "John".
        var matchedBook: String?
        for name in bookNames.sorted(by: { $0.count > $1.count }) {
            let lower = name.lowercased()
            // Also accept the singular "Psalm".
            let forms = lower.hasSuffix("s") ? [lower, String(lower.dropLast())] : [lower]
            if let form = forms.first(where: { query == $0 || query.hasPrefix($0 + " ") || query.hasPrefix($0 + ":") }) {
                matchedBook = name
                query = String(query.dropFirst(form.count))
                break
            }
        }

        let tokens = query.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        book = matchedBook
        numbers = tokens.compactMap { Int($0) }
        words = tokens.filter { Int($0) == nil }
    }

    @MainActor
    func matches(_ favorite: Favorite) -> Bool {
        matches(
            bookName: favorite.bookName,
            chapter: favorite.chapterNumber,
            verses: favorite.verseNumber...favorite.verseNumber,
            texts: [favorite.currentVerseText]
        )
    }

    /// `verses` is the range a highlight covers; a searched verse anywhere in it matches.
    func matches(bookName: String, chapter: Int, verses: ClosedRange<Int>, texts: [String]) -> Bool {
        if let book {
            guard bookName == book else { return false }
            if numbers.count > 0, chapter != numbers[0] { return false }
            if numbers.count > 1, !verses.contains(numbers[1]) { return false }
        } else if !numbers.allSatisfy({ $0 == chapter || verses.contains($0) }) {
            return false
        }
        let searchable = texts.map { $0.lowercased() } + [bookName.lowercased()]
        return words.allSatisfy { word in searchable.contains { $0.contains(word) } }
    }
}

private struct RemovedFavorite {
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
    let verseText: String
    let createdAt: Date

    init(_ favorite: Favorite) {
        bookName = favorite.bookName
        chapterNumber = favorite.chapterNumber
        verseNumber = favorite.verseNumber
        verseText = favorite.verseText
        createdAt = favorite.createdAt
    }

    var model: Favorite {
        Favorite(
            bookName: bookName,
            chapterNumber: chapterNumber,
            verseNumber: verseNumber,
            verseText: verseText,
            createdAt: createdAt
        )
    }
}

#Preview {
    let container = try! ModelContainer(for: Favorite.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    for (book, chapter, verse, text) in [
        ("John", 3, 16, "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life."),
        ("Psalms", 23, 1, "The LORD is my shepherd; I shall not want."),
        ("Philippians", 4, 13, "I can do all things through Christ which strengtheneth me."),
    ] {
        container.mainContext.insert(Favorite(bookName: book, chapterNumber: chapter, verseNumber: verse, verseText: text))
    }
    return NavigationStack {
        FavoritesView()
    }
    .modelContainer(container)
}
