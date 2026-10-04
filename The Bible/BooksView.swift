import SwiftUI

struct BooksView: View {
    @EnvironmentObject private var coordinator: NavigationCoordinator
    let books: [Book]
    @State private var searchText: String = ""
    // Shared preference across devices
    @AppStorage("bibleBooksSortAlphabetical") private var sortAlphabetically: Bool = false

    private var filteredBooks: [Book] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return books }
        return books.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var azBooks: [Book] {
        filteredBooks.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var oldTestamentBooks: [Book] {
        let matthewIndex = books.firstIndex(where: { $0.name == "Matthew" }) ?? books.endIndex
        let oldTestamentNames = Set(books[..<matthewIndex].map(\.name))
        return filteredBooks.filter { oldTestamentNames.contains($0.name) }
    }

    private var newTestamentBooks: [Book] {
        let matthewIndex = books.firstIndex(where: { $0.name == "Matthew" }) ?? books.endIndex
        let newTestamentNames = Set(books[matthewIndex...].map(\.name))
        return filteredBooks.filter { newTestamentNames.contains($0.name) }
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
                    if !oldTestamentBooks.isEmpty {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            bookRows(
                                title: "Old Testament (\(oldTestamentBooks.count))",
                                books: oldTestamentBooks
                            )
                        }
                        .padding(AppDesignMetrics.cardPadding)
                        .heroCardSurface()
                    }

                    if !newTestamentBooks.isEmpty {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            bookRows(
                                title: "New Testament (\(newTestamentBooks.count))",
                                books: newTestamentBooks
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
