import SwiftUI

/// Resolves a reference typed into a book filter, such as "John 3:16", to a passage
/// that exists in the corpus.
enum BibleNavigationReference {
    static func resolve(
        _ text: String,
        in books: [Book]
    ) -> (reference: ScriptureRef, book: Book, chapter: Chapter)? {
        // `BibleReferenceParser` understands both chapter-only input ("Psalms 1") and
        // verse input with common abbreviations ("Ps 1:7").
        guard let parsed = BibleReferenceParser.reference(for: text, in: books) else {
            return nil
        }
        let startVerse = parsed.verse?.number ?? parsed.chapter.verses.first?.number ?? 1
        return (
            reference: ScriptureRef(
                bookName: parsed.book.name,
                chapter: parsed.chapter.number,
                startVerse: startVerse,
                endVerse: nil
            ),
            book: parsed.book,
            chapter: parsed.chapter
        )
    }
}

/// Book list shared by the iPhone Books screen and the iPad sidebar: Old and New
/// Testament sections in canonical order, or a single A–Z section, filtered by name.
struct BibleBookSections: View {
    let books: [Book]
    let filterText: String
    let alphabetical: Bool
    var selectedBookName: String?
    let onSelect: (Book) -> Void

    private var filteredBooks: [Book] {
        let query = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return books }
        return books.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    /// Splits at Matthew, the first New Testament book in canonical order.
    private var testaments: (old: [Book], new: [Book]) {
        let matthewIndex = books.firstIndex(where: { $0.name == "Matthew" }) ?? books.endIndex
        let newTestamentNames = Set(books[matthewIndex...].map(\.name))
        let filtered = filteredBooks
        return (
            filtered.filter { !newTestamentNames.contains($0.name) },
            filtered.filter { newTestamentNames.contains($0.name) }
        )
    }

    var body: some View {
        if alphabetical {
            let sorted = filteredBooks.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            section(title: "All Books (\(sorted.count))", books: sorted)
        } else {
            let split = testaments
            section(title: "Old Testament (\(split.old.count))", books: split.old)
            section(title: "New Testament (\(split.new.count))", books: split.new)
        }
    }

    @ViewBuilder
    private func section(title: String, books: [Book]) -> some View {
        if !books.isEmpty {
            LazyVStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)

                ForEach(books) { book in
                    row(for: book, isLast: book.name == books.last?.name)
                }
            }
            .padding(AppDesignMetrics.cardPadding)
            .heroCardSurface()
        }
    }

    private func row(for book: Book, isLast: Bool) -> some View {
        let isSelected = book.name == selectedBookName
        return VStack(spacing: 0) {
            Button { onSelect(book) } label: {
                HStack {
                    Text(book.name)
                        .fontWeight(isSelected ? .semibold : .regular)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: AppDesignMetrics.selectionRowMinHeight)
                .padding(.horizontal, isSelected ? 8 : 0)
                .background(
                    Color.accentColor.opacity(isSelected ? 0.18 : 0),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            if !isLast {
                Divider()
            }
        }
    }
}

/// "Go to John 3:16" shortcut shown when the book filter text is a valid reference.
struct BibleReferenceJumpRow: View {
    let reference: ScriptureRef
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)

                Text("Go to \(reference.bookName) \(reference.chapter):\(reference.startVerse)")
                    .font(.headline)

                Spacer()
            }
            .frame(minHeight: AppDesignMetrics.selectionRowMinHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(AppDesignMetrics.cardPadding)
        .heroCardSurface()
    }
}
