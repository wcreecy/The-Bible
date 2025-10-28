import SwiftUI

struct BooksView: View {
    let books: [Book]

    var body: some View {
        List(books) { book in
            NavigationLink(value: book) {
                Text(book.name)
            }
        }
        .navigationDestination(for: Book.self) { book in
            ChaptersView(book: book)
        }
    }
}

#Preview {
    NavigationStack {
        BooksView(books: BibleData.books)
    }
}
