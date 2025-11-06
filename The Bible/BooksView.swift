import SwiftUI

struct BooksView: View {
    let books: [Book]
    @State private var searchText: String = ""

    private var filteredBooks: [Book] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return books }
        return books.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        Group {
            let canon = BibleData.books
            let indexMap = Dictionary(uniqueKeysWithValues: canon.enumerated().map { ($1.name, $0) })
            let matthewIndex = indexMap["Matthew"] ?? Int.max
            let otBooks = filteredBooks.filter { (indexMap[$0.name] ?? Int.max) < matthewIndex }
            let ntBooks = filteredBooks.filter { (indexMap[$0.name] ?? Int.max) >= matthewIndex }

            List {
                if !otBooks.isEmpty {
                    Section {
                        ForEach(otBooks) { book in
                            NavigationLink(value: book) {
                                Text(book.name)
                            }
                        }
                    } header: {
                        Text("Old Testament (\(otBooks.count))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if !ntBooks.isEmpty {
                    Section {
                        ForEach(ntBooks) { book in
                            NavigationLink(value: book) {
                                Text(book.name)
                            }
                        }
                    } header: {
                        Text("New Testament (\(ntBooks.count))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationDestination(for: Book.self) { book in
                ChaptersView(book: book)
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search books")
    }
}

#Preview {
    NavigationStack {
        BooksView(books: BibleData.books)
    }
}
