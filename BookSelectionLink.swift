import SwiftUI

struct BookSelectionLink: View {
    @Binding var selectedBookName: String?
    @StateObject private var bibleStore = BibleStore.shared

    var body: some View {
        NavigationLink {
            List {
                if bibleStore.isReady {
                    ForEach(bibleStore.books, id: \.name) { book in
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
                } else {
                    ForEach(0..<10, id: \.self) { _ in
                        Text("Loading…")
                            .redacted(reason: .placeholder)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Select Book")
            .onAppear { bibleStore.ensureLoaded() }
        } label: {
            HStack {
                Text("Book")
                Spacer()
                Text(selectedBookName ?? (bibleStore.isReady ? "Choose…" : "Loading…"))
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
