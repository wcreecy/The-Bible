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

/// What the Apple Pencil popover on a book can open. The host decides how each one opens: a
/// push on iPhone, the detail pane on iPad.
struct BookPencilActions {
    /// Opens a chapter. A verse starts the reader there (Continue); nil opens the chapter at the top.
    let openChapter: (Book, Chapter, _ verse: Int?) -> Void
    let openOverview: (Book) -> Void
}

/// Book list shared by the iPhone Books screen and the iPad sidebar: Old and New
/// Testament sections in canonical order, or a single A–Z section, filtered by name.
struct BibleBookSections: View {
    let books: [Book]
    let filterText: String
    let alphabetical: Bool
    var selectedBookName: String?
    let onSelect: (Book) -> Void
    /// When set, squeezing or double-tapping the Apple Pencil over a book opens its quick actions.
    var pencilActions: BookPencilActions? = nil

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

    @State private var pencilTracker = PencilHoverTracker<String>()

    var body: some View {
        // One container, so a single Apple Pencil handler serves every book.
        VStack(alignment: .leading, spacing: 16) {
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
        .pencilPopover(for: pencilTracker) { name, dismiss in
            if let pencilActions, let book = books.first(where: { $0.name == name }) {
                BookPencilPopover(
                    book: book,
                    actions: pencilActions,
                    onOpen: { onSelect(book) },
                    dismiss: dismiss
                )
            }
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
            bookButton(for: book, isSelected: isSelected)

            if !isLast {
                Divider()
            }
        }
    }

    private func bookButton(for book: Book, isSelected: Bool) -> some View {
        rowButton(for: book, isSelected: isSelected)
            .pencilHover(book.name, in: pencilTracker)
    }

    private func rowButton(for book: Book, isSelected: Bool) -> some View {
        Group {
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
                // Apple Pencil hover (and a pointer) lights up the row under the tip.
                .hoverEffect(.highlight)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }
}

/// A book's quick actions at the Apple Pencil tip: open it, pick up where reading stopped,
/// read its overview, or jump straight to a chapter.
private struct BookPencilPopover: View {
    let book: Book
    let actions: BookPencilActions
    let onOpen: () -> Void
    let dismiss: () -> Void

    private let readChapters = BibleStatsStore.shared.loadVisitedChapters()
    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 8)]

    /// Where reading last stopped, when that was in this book.
    private var resumePoint: (chapter: Chapter, verse: Int)? {
        guard let position = ReadingPositionStore.shared.current,
              position.bookName == book.name,
              let chapter = book.chapters.first(where: { $0.number == position.chapterNumber }) else { return nil }
        return (chapter, position.verseNumber ?? 1)
    }

    private var chapterGridHeight: CGFloat {
        let rows = ceil(Double(book.chapters.count) / 6)
        return min(CGFloat(rows) * 52, 260)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(book.name)
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                action("Open", systemImage: "book") { onOpen() }

                if let resume = resumePoint {
                    action("Continue at \(resume.chapter.number):\(resume.verse)", systemImage: "play.fill") {
                        actions.openChapter(book, resume.chapter, resume.verse)
                    }
                }

                action("About \(book.name)", systemImage: "info.circle") {
                    actions.openOverview(book)
                }
            }

            Divider()

            Text("Go to chapter")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(book.chapters) { chapter in
                        let isRead = readChapters.contains("\(book.name):\(chapter.number)")
                        Button {
                            dismiss()
                            actions.openChapter(book, chapter, nil)
                        } label: {
                            Text("\(chapter.number)")
                                .font(.body.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(isRead ? Color.green : Color.primary)
                                .frame(maxWidth: .infinity, minHeight: 36)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Chapter \(chapter.number)")
                        .accessibilityValue(isRead ? "Read" : "")
                    }
                }
            }
            .frame(height: chapterGridHeight)
        }
        .padding()
        .frame(width: 330)
    }

    private func action(_ title: String, systemImage: String, perform: @escaping () -> Void) -> some View {
        Button {
            dismiss()
            perform()
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
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
