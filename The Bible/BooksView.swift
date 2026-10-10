import SwiftUI

struct BooksView: View {
    @EnvironmentObject private var coordinator: NavigationCoordinator
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

#Preview {
    NavigationStack {
        BooksView(books: BibleData.books)
            .environmentObject(NavigationCoordinator())
    }
}
