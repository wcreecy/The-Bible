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
            let canon = BibleData.books
            let indexMap = Dictionary(uniqueKeysWithValues: canon.enumerated().map { ($1.name, $0) })
            let matthewIndex = indexMap["Matthew"] ?? Int.max
            let otBooks = filteredBooks.filter { (indexMap[$0.name] ?? Int.max) < matthewIndex }
            let ntBooks = filteredBooks.filter { (indexMap[$0.name] ?? Int.max) >= matthewIndex }

            LazyVStack(alignment: .leading, spacing: 0) {
                if sortAlphabetically {
                    bookRows(title: "All Books (\(azBooks.count))", books: azBooks)
                } else {
                    bookRows(title: "Old Testament (\(otBooks.count))", books: otBooks)

                    if !otBooks.isEmpty && !ntBooks.isEmpty {
                        Divider()
                            .padding(.vertical, 4)
                    }

                    bookRows(title: "New Testament (\(ntBooks.count))", books: ntBooks)
                }
            }
            .padding(AppDesignMetrics.cardPadding)
            .heroCardSurface()
            .padding(.horizontal, 16)
            .padding(.vertical)
        }
        .background(AppBackgroundView(tab: .bible))
        .navigationTitle("Books")
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search books")
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
}

#Preview {
    NavigationStack {
        BooksView(books: BibleData.books)
            .environmentObject(NavigationCoordinator())
    }
}
