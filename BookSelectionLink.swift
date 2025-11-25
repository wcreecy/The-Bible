import SwiftUI

struct BookSelectionLink: View {
    @Binding var selectedBookName: String?
    @StateObject private var bibleStore = BibleStore.shared
    @State private var bookNames: [String] = []

    var body: some View {
        NavigationLink {
            List {
                if bookNames.isEmpty {
                    ForEach(0..<10, id: \.self) { _ in
                        Text("Loading…")
                            .redacted(reason: .placeholder)
                    }
                } else {
                    ForEach(bookNames, id: \.self) { name in
                        HStack {
                            Text(name)
                            Spacer()
                            if selectedBookName == name {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedBookName = name }
                        .accessibilityIdentifier("book_\(name)")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Select Book")
            .task {
                if bookNames.isEmpty {
                    // Load names asynchronously (fast, and uses per-book files if available).
                    let names = await bibleStore.bookNames()
                    // Fallback to static order if async result is empty
                    if names.isEmpty {
                        bookNames = BibleData.books.map { $0.name }
                    } else {
                        bookNames = names
                    }
                }
            }
        } label: {
            HStack {
                Text("Book")
                Spacer()
                Text(selectedBookName ?? "Select Book")
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
