import SwiftUI

struct BooksView: View {
    @Environment(NavigationCoordinator.self) private var coordinator
    let books: [Book]
    @State private var searchText: String = ""
    // Shared preference across devices
    @AppStorage("bibleBooksSortAlphabetical") private var sortAlphabetically: Bool = false

    private var scriptureReference: (reference: ScriptureRef, book: Book, chapter: Chapter)? {
        BibleNavigationReference.resolve(searchText, in: books)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                StudyBibleEntryCard(books: books)

                if let match = scriptureReference {
                    BibleReferenceJumpRow(reference: match.reference, action: openScriptureReference)
                }

                BibleBookSections(
                    books: books,
                    filterText: searchText,
                    alphabetical: sortAlphabetically,
                    onSelect: { coordinator.push(.book($0)) }
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical)
        }
        .background(AppBackgroundView(tab: .bible))
        .navigationTitle("Books")
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Books or a reference"
        )
        .onSubmit(of: .search, openScriptureReference)
        .tint(.accentColor)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    coordinator.push(.search)
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("Search Bible text")

                BibleBookSortMenu(alphabetical: $sortAlphabetically)
            }
        }
    }

    private func openScriptureReference() {
        guard let match = scriptureReference else { return }
        searchText = ""
        coordinator.push(.reader(
            book: match.book,
            chapter: match.chapter,
            startVerse: match.reference.startVerse
        ))
    }
}

/// A dedicated starting point for book background and chapter-level study material.
struct StudyBibleEntryCard: View {
    let books: [Book]

    var body: some View {
        NavigationLink {
            StudyBibleView(books: books)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "graduationcap.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Study the Bible")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Explore book overviews and chapter insights")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(AppDesignMetrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .heroCardSurface()
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens book overviews and chapter insights")
    }
}

/// Browse the Bible's study material independently of the reading-focused book list.
struct StudyBibleView: View {
    let books: [Book]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                StudyBibleHeader()

                ForEach(books) { book in
                    StudyBookRow(book: book)
                }
            }
            .padding()
        }
        .background(AppBackgroundView(tab: .bible))
        .navigationTitle("Study")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct StudyBibleHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Explore Scripture")
                .font(.title2.weight(.bold))
            Text("Choose a book to read its overview or explore chapter insights.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }
}

private struct StudyBookRow: View {
    let book: Book

    var body: some View {
        NavigationLink {
            StudyBookView(book: book)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "book.closed")
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(book.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("\(book.chapters.count) chapters")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(AppDesignMetrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .heroCardSurface()
        }
        .buttonStyle(.plain)
    }
}

private struct StudyBookView: View {
    let book: Book

    private let columns = [GridItem(.adaptive(minimum: 52), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                NavigationLink {
                    BookOverviewView(bookName: book.name)
                } label: {
                    StudyOverviewCard(bookName: book.name)
                }
                .buttonStyle(.plain)

                HeroCard(title: "Chapter Insights", icon: "lightbulb.max") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose a chapter to explore its themes, people, background, and cross references.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(book.chapters) { chapter in
                                NavigationLink {
                                    ChapterInsightsView(
                                        bookName: book.name,
                                        chapterNumber: chapter.number
                                    )
                                } label: {
                                    Text(chapter.number, format: .number)
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                                }
                                .accessibilityLabel("Chapter \(chapter.number) insights")
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(AppBackgroundView(tab: .bible))
        .navigationTitle(book.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct StudyOverviewCard: View {
    let bookName: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "text.book.closed")
                .font(.title2)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 3) {
                Text("About \(bookName)")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("Read the book overview, story, setting, and key people")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(AppDesignMetrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .heroCardSurface()
    }
}

#Preview {
    NavigationStack {
        BooksView(books: BibleData.books)
            .environment(NavigationCoordinator())
    }
}
