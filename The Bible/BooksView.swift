import SwiftUI

struct BooksView: View {
    private static let canonicalIndexByName = Dictionary(
        uniqueKeysWithValues: BibleData.books.enumerated().map { ($1.name, $0) }
    )
    private static let matthewIndex = canonicalIndexByName["Matthew"] ?? Int.max

    @EnvironmentObject private var coordinator: NavigationCoordinator
    let books: [Book]
    private let oldTestamentBooks: [Book]
    private let newTestamentBooks: [Book]
    @State private var searchText: String = ""
    @State private var displayedBooks: [Book]
    @State private var displayedOldTestamentBooks: [Book]
    @State private var displayedNewTestamentBooks: [Book]
    // Shared preference across devices
    @AppStorage("bibleBooksSortAlphabetical") private var sortAlphabetically: Bool = false

    init(books: [Book]) {
        self.books = books
        let oldTestamentBooks = books.filter {
            (Self.canonicalIndexByName[$0.name] ?? Int.max) < Self.matthewIndex
        }
        let newTestamentBooks = books.filter {
            (Self.canonicalIndexByName[$0.name] ?? Int.max) >= Self.matthewIndex
        }
        self.oldTestamentBooks = oldTestamentBooks
        self.newTestamentBooks = newTestamentBooks
        _displayedBooks = State(initialValue: books)
        _displayedOldTestamentBooks = State(initialValue: oldTestamentBooks)
        _displayedNewTestamentBooks = State(initialValue: newTestamentBooks)
    }

    private var azBooks: [Book] {
        displayedBooks.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var scriptureReference: (reference: ScriptureRef, book: Book, chapter: Chapter)? {
        guard let reference = BibleReferenceLinker.parse(searchText),
              let book = books.first(where: { $0.name == reference.bookName }),
              let chapter = book.chapters.first(where: { $0.number == reference.chapter }),
              chapter.verses.contains(where: { $0.number == reference.startVerse }) else {
            return nil
        }
        return (reference, book, chapter)
    }

    private func updateDisplayedBooks(for searchText: String) {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            displayedBooks = books
            displayedOldTestamentBooks = oldTestamentBooks
            displayedNewTestamentBooks = newTestamentBooks
            return
        }

        displayedBooks = books.filter { $0.name.localizedCaseInsensitiveContains(query) }
        displayedOldTestamentBooks = oldTestamentBooks.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
        displayedNewTestamentBooks = newTestamentBooks.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    @ViewBuilder
    private func bookRows(title: String, books: [Book]) -> some View {
        if !books.isEmpty {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)

            ForEach(books) { book in
                Button { coordinator.push(.book(book)) } label: {
                    HStack {
                        Text(book.name)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: AppDesignMetrics.selectionRowMinHeight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)

                if book.name != books.last?.name {
                    Divider()
                }
            }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if let match = scriptureReference {
                    Button(action: openScriptureReference) {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.tint)

                            Text("Go to \(match.reference.bookName) \(match.reference.chapter):\(match.reference.startVerse)")
                                .font(.headline)

                            Spacer()
                        }
                        .frame(minHeight: AppDesignMetrics.selectionRowMinHeight)
                    }
                    .buttonStyle(.plain)
                    .padding(AppDesignMetrics.cardPadding)
                    .heroCardSurface()
                }

                if sortAlphabetically {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        bookRows(title: "All Books (\(azBooks.count))", books: azBooks)
                    }
                    .padding(AppDesignMetrics.cardPadding)
                    .heroCardSurface()
                } else {
                    if !displayedOldTestamentBooks.isEmpty {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            bookRows(
                                title: "Old Testament (\(displayedOldTestamentBooks.count))",
                                books: displayedOldTestamentBooks
                            )
                        }
                        .padding(AppDesignMetrics.cardPadding)
                        .heroCardSurface()
                    }

                    if !displayedNewTestamentBooks.isEmpty {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            bookRows(
                                title: "New Testament (\(displayedNewTestamentBooks.count))",
                                books: displayedNewTestamentBooks
                            )
                        }
                        .padding(AppDesignMetrics.cardPadding)
                        .heroCardSurface()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical)
        }
        .background(AppBackgroundView(tab: .bible))
        .navigationTitle("Books")
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Books or a reference"
        )
        .onSubmit(of: .search, openScriptureReference)
        .onChange(of: searchText) { _, newValue in
            updateDisplayedBooks(for: newValue)
        }
        .tint(.accentColor)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    coordinator.push(.search)
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("Search Bible text")

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

    private func openScriptureReference() {
        guard let match = scriptureReference else { return }
        searchText = ""
        coordinator.push(.reader(
            book: match.book,
            chapter: match.chapter,
            startVerse: match.reference.startVerse
        ))
    }
}

#Preview {
    NavigationStack {
        BooksView(books: BibleData.books)
            .environmentObject(NavigationCoordinator())
    }
}
