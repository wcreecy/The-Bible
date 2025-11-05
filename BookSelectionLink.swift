import SwiftUI

struct BookSelectionLink: View {
    @Binding var selectedBookName: String?

    var body: some View {
        NavigationLink {
            List {
                ForEach(BibleData.books, id: \.name) { book in
                    HStack {
                        Text(book.name)
                        Spacer()
                        if selectedBookName == book.name {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selectedBookName = book.name }
                    .accessibilityIdentifier("book_\(book.name)")
                }
            }
            .listStyle(.insetGrouped)
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

private struct BookSelectionLinkPreviewWrapper: View {
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

#Preview {
    BookSelectionLinkPreviewWrapper()
}
