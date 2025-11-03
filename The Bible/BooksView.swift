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
            List(filteredBooks) { book in
                NavigationLink(value: book) {
                    Text(book.name)
                }
            }
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
