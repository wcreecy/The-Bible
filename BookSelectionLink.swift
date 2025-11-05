import SwiftUI

struct BookSelectionLink: View {
    @Binding var selectedBookName: String?

    var body: some View {
        NavigationLink {
            List(BibleData.books, id: \.name) { book in
                Button {
                    selectedBookName = book.name
                } label: {
                    HStack {
                        Text(book.name)
                        Spacer()
                        if selectedBookName == book.name {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .accessibilityIdentifier("book_\(book.name)")
                .buttonStyle(.plain)
            }
            .navigationTitle("Select Book")
        } label: {
            HStack {
                Text("Book")
                Spacer()
                Text(selectedBookName ?? "Choose…")
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedBook: String? = nil

        var body: some View {
            NavigationStack {
                Form {
                    BookSelectionLink(selectedBookName: $selectedBook)
                }
                .navigationTitle("Preview")
            }
        }
    }
    PreviewWrapper()
}
