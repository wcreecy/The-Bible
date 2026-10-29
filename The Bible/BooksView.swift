import SwiftUI

struct BooksView: View {
    @Environment(NavigationCoordinator.self) private var coordinator
    let books: [Book]
    @State private var searchText: String = ""
    // Shared preference across devices
    @AppStorage(AppStorageKey.bibleBooksSortAlphabetical) private var sortAlphabetically: Bool = false

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
        .tabBarContentClearance()
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

                Button {
                    sortAlphabetically.toggle()
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel("Toggle book sort order")
                .accessibilityValue(sortAlphabetically ? "Alphabetical" : "Canonical")
                .accessibilityHint("Switches to \(sortAlphabetically ? "canonical" : "alphabetical") order")
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

#Preview {
    NavigationStack {
        BooksView(books: BibleData.books)
            .environment(NavigationCoordinator())
    }
}
