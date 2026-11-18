import SwiftUI

/// The reader's "Choose a Book" sheet. Typing a reference such as "John 3:16" offers to open it
/// directly; otherwise the list narrows to matching book names. With nothing typed, books are
/// grouped by kind, and the list opens at the book being read, marked.
struct ReaderBookPickerSheet: View {
    typealias ResolvedReference = (reference: ScriptureRef, book: Book, chapter: Chapter)

    /// Owned by the reader so the query survives dismissing with Cancel.
    @Binding var searchText: String
    /// The book being read, marked in the list and scrolled to when the sheet opens.
    var currentBookName: String? = nil
    let onSelectBook: (Book) -> Void
    let onSelectReference: (ResolvedReference) -> Void
    let onCancel: () -> Void
    @State private var pencilTracker = PencilHoverTracker<String>()

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
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

                    if isBrowsing {
                        ForEach(groups) { group in
                            Section {
                                ForEach(group.books) { book in
                                    bookRow(book)
                                }
                            } header: {
                                groupHeader(group)
                            }
                        }
                    } else {
                        Section {
                            ForEach(filteredBooks) { book in
                                bookRow(book)
                            }
                        }
                    }
                }
                .onAppear {
                    // Open near the book being read, rather than always at Genesis.
                    guard isBrowsing, let currentBookName else { return }
                    proxy.scrollTo(currentBookName, anchor: .center)
                }
                .pencilPopover(for: pencilTracker) { bookName, dismiss in
                    if let book = BibleData.books.first(where: { $0.name == bookName }) {
                        PencilActionList(dismiss: dismiss) {
                            Button {
                                dismiss()
                                onSelectBook(book)
                            } label: {
                                Label("Open \(book.name)", systemImage: "book")
                            }
                        }
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

    // MARK: - Rows

    private func bookRow(_ book: Book) -> some View {
        ReaderBookPickerRow(
            book: book,
            isCurrent: book.name == currentBookName,
            pencilTracker: pencilTracker,
            onSelect: { onSelectBook(book) }
        )
        .id(book.name)
    }

    private func groupHeader(_ group: PickerGroup) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let testament = group.testamentLabel {
                Text(testament)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 6)
            }
            Text("\(group.group.title) (\(group.books.count))")
        }
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Grouping

    /// Nothing typed, so the whole list is shown, grouped.
    private var isBrowsing: Bool {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var groups: [PickerGroup] {
        var seenTestaments: Set<Testament> = []
        return BibleBookGroup.grouping(BibleData.books).map { entry in
            // The first group of each testament carries the testament's name.
            let isFirstInTestament = seenTestaments.insert(entry.group.testament).inserted
            let label = isFirstInTestament ? (entry.group.testament == .old ? "OLD TESTAMENT" : "NEW TESTAMENT") : nil
            return PickerGroup(group: entry.group, books: entry.books, testamentLabel: label)
        }
    }

    private struct PickerGroup: Identifiable {
        let group: BibleBookGroup
        let books: [Book]
        let testamentLabel: String?
        var id: BibleBookGroup { group }
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

private struct ReaderBookPickerRow: View {
    let book: Book
    let isCurrent: Bool
    let pencilTracker: PencilHoverTracker<String>
    let onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(book.name)
                    .fontWeight(isCurrent ? .semibold : .regular)
                    .foregroundStyle(isCurrent ? Color.accentColor : .primary)
                Spacer(minLength: 0)
                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .background(
                Color.accentColor.opacity(isHovering ? 0.14 : 0),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .pencilHover(book.name, in: pencilTracker)
        .onHover { isHovering = $0 }
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
        .accessibilityHint(isCurrent ? "The book you are reading" : "")
    }
}
