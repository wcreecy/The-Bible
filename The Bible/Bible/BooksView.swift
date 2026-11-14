import SwiftUI

struct BooksView: View {
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
                featureTiles

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
        .overlay {
            if BibleStore.shared.loadFailed {
                BibleLoadFailedView()
            }
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

    /// Bible Study and Reading Plans side by side, matched in height; stacked when the text is
    /// large enough that half a row would crowd it.
    @ViewBuilder
    private var featureTiles: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        layout {
            StudyBibleEntryCard(books: books)

            Button {
                coordinator.push(.readingPlans)
            } label: {
                ReadingPlansEntryCard()
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens reading plans")
        }
        .fixedSize(horizontal: false, vertical: true)
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
