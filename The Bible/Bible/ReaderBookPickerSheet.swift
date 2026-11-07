import SwiftUI

/// The reader's "Choose a Book" sheet. Typing a reference such as "John 3:16" offers to open it
/// directly; otherwise the list narrows to matching book names.
struct ReaderBookPickerSheet: View {
    typealias ResolvedReference = (reference: ScriptureRef, book: Book, chapter: Chapter)

    /// Owned by the reader so the query survives dismissing with Cancel.
    @Binding var searchText: String
    let onSelectBook: (Book) -> Void
    let onSelectReference: (ResolvedReference) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if let reference {
                    Section {
                        Button {
                            onSelectReference(reference)
                        } label: {
                            Label("Go to \(reference.reference.formattedReference)", systemImage: "arrow.right.circle.fill")
                        }
                    }
                }

                Section {
                    ForEach(filteredBooks) { book in
                        Button(book.name) {
                            onSelectBook(book)
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Book or reference")
            .onSubmit(of: .search) {
                if let reference {
                    onSelectReference(reference)
                }
            }
            .navigationTitle("Choose a Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }

    private var reference: ResolvedReference? {
        BibleNavigationReference.resolve(searchText, in: BibleData.books)
    }

    private var filteredBooks: [Book] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return BibleData.books }
        if let reference { return [reference.book] }

        let names = BibleBookNameMatcher.suggestions(for: query, in: BibleData.books.map(\.name))
        return names.compactMap { name in BibleData.books.first(where: { $0.name == name }) }
    }
}
