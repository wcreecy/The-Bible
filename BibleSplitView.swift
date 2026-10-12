import SwiftUI

/// iPad Bible tab: a split view built from the same pieces as the iPhone flow —
/// the shared book list, chapter grid, reader, and search.
struct BibleSplitView: View {
    let searchRequestID: Int
    let initialReaderLocation: BibleReaderLocation?

    @State private var handledSearchRequestID: Int = 0
    @State private var handledInitialReaderLocation: BibleReaderLocation?
    @State private var selectedBook: Book?
    @State private var sidebarSearch: String = ""
    @State private var detailPath = NavigationPath()
    @State private var isShowingBookOverview = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var searchModel = BibleSearchModel()

    // Shared preference for sort mode across iPhone/iPad
    @AppStorage("bibleBooksSortAlphabetical") private var sortAlphabetically: Bool = false

    private struct ReadingRoute: Hashable {
        let bookName: String
        let chapterNumber: Int
        let verseNumber: Int
    }

    private struct SearchRoute: Hashable {}

    private struct OverviewRoute: Hashable {
        let bookName: String
    }

    private var books: [Book] { BibleData.books }

    private var sidebarReference: (reference: ScriptureRef, book: Book, chapter: Chapter)? {
        BibleNavigationReference.resolve(sidebarSearch, in: books)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarView
        } detail: {
            detailView
        }
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        VStack(spacing: 0) {
            HStack {
                BibleBookSortMenu(alphabetical: $sortAlphabetically)
                    .frame(width: 44, height: 44)

                Spacer()

                Text("Books")
                    .font(.headline)

                Spacer()

                Button {
                    columnVisibility = .detailOnly
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .accessibilityLabel("Hide Books pane")
                .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    sidebarSearchField

                    if let match = sidebarReference {
                        BibleReferenceJumpRow(reference: match.reference, action: openSidebarReference)
                    }

                    BibleBookSections(
                        books: books,
                        filterText: sidebarSearch,
                        alphabetical: sortAlphabetically,
                        selectedBookName: selectedBook?.name,
                        onSelect: select
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .background(AppBackgroundView(tab: .bible))
        .toolbar(.hidden, for: .navigationBar)
    }

    private var sidebarSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Books or a reference", text: $sidebarSearch)
                .textFieldStyle(.plain)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.words)
                .submitLabel(.go)
                .onSubmit(openSidebarReference)

            if !sidebarSearch.isEmpty {
                Button {
                    sidebarSearch = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(.secondary.opacity(0.2), lineWidth: 1)
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailRoot: some View {
        if searchModel.canSearch {
            BibleSearchResultsView(
                model: searchModel,
                bookSelectionMessage: "Select a book in the sidebar to search within it.",
                onOpen: { result in
                    openReader(bookName: result.bookName, chapter: result.chapterNumber, verse: result.verseNumber)
                }
            )
            .background(AppBackgroundView(tab: .bible))
            .navigationTitle(searchModel.statusText)
            .navigationBarTitleDisplayMode(.inline)
        } else if let book = selectedBook {
            ChaptersView(
                book: book,
                onSelectChapter: { chapter in
                    detailPath.append(ReadingRoute(bookName: book.name, chapterNumber: chapter.number, verseNumber: 1))
                },
                onSelectOverview: {
                    detailPath.append(OverviewRoute(bookName: book.name))
                }
            )
        } else {
            ContentUnavailableView("Select a Book", systemImage: "book")
        }
    }

    private var detailView: some View {
        NavigationStack(path: $detailPath) {
            detailRoot
                .navigationDestination(for: SearchRoute.self) { _ in
                    SearchView()
                }
                .navigationDestination(for: OverviewRoute.self) { route in
                    BookOverviewView(bookName: route.bookName)
                        .onAppear {
                            isShowingBookOverview = true
                        }
                        .onDisappear {
                            if selectedBook?.name == route.bookName {
                                isShowingBookOverview = false
                            }
                        }
                }
                .navigationDestination(for: ReadingRoute.self) { route in
                    readingDestination(for: route)
                }
        }
        .background(AppBackgroundView(tab: .bible))
        // Choosing another book starts that book's detail stack fresh.
        .id(selectedBook?.name ?? "__no_book__")
        .searchable(
            text: $searchModel.query,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Search Bible text"
        )
        .searchScopes($searchModel.scope) {
            ForEach(BibleSearchScope.allCases) { scope in
                Text(scope == .book ? "This Book" : scope.rawValue).tag(scope)
            }
        }
        .onSubmit(of: .search) {
            searchModel.saveRecentSearch()
            if let direct = searchModel.directReferenceResult() {
                openReader(bookName: direct.bookName, chapter: direct.chapterNumber, verse: direct.verseNumber)
            }
        }
        .onAppear {
            searchModel.scopeBook = selectedBook
        }
        .onChange(of: selectedBook?.name) { _, _ in
            searchModel.scopeBook = selectedBook
        }
        .task(id: searchRequestID) {
            guard searchRequestID != 0, searchRequestID != handledSearchRequestID else { return }
            handledSearchRequestID = searchRequestID
            detailPath.append(SearchRoute())
        }
        .task(id: initialReaderLocation) {
            guard let location = initialReaderLocation,
                  location != handledInitialReaderLocation else { return }
            handledInitialReaderLocation = location
            // Changing the selected book replaces the detail stack's identity.
            // Yield before installing the reader route into the new stack.
            selectBookForReader(named: location.bookName)
            await Task.yield()
            detailPath = NavigationPath()
            detailPath.append(ReadingRoute(
                bookName: location.bookName,
                chapterNumber: location.chapterNumber,
                verseNumber: location.verseNumber
            ))
        }
        // App-wide requests to open a verse arrive through `initialReaderLocation`,
        // which ContentView sets when it handles `AppRouter` requests.
    }

    @ViewBuilder
    private func readingDestination(for route: ReadingRoute) -> some View {
        if let book = books.first(where: { $0.name == route.bookName }),
           let chapter = book.chapters.first(where: { $0.number == route.chapterNumber }) {
            ReadingView(
                book: book,
                chapter: chapter,
                startVerse: route.verseNumber,
                onSearch: {
                    detailPath.append(SearchRoute())
                },
                onNavigateBack: { currentBook in
                    // Return to the chapter grid for the book being read.
                    selectedBook = currentBook
                    detailPath = NavigationPath()
                },
                onBookSelected: { newBook in
                    selectedBook = newBook
                    detailPath = NavigationPath()
                }
            )
            .id("\(route.bookName)-\(route.chapterNumber)-\(route.verseNumber)")
        } else {
            ContentUnavailableView("Passage not found", systemImage: "exclamationmark.triangle")
        }
    }

    // MARK: - Actions

    private func select(_ book: Book) {
        let shouldKeepOverviewOpen = isShowingBookOverview
        selectedBook = book
        searchModel.query = ""
        detailPath = NavigationPath()

        guard shouldKeepOverviewOpen else { return }
        Task { @MainActor in
            // The selected book changes the detail stack's identity. Install the new
            // overview route after the replacement stack is ready.
            await Task.yield()
            detailPath.append(OverviewRoute(bookName: book.name))
        }
    }

    private func selectBookForReader(named bookName: String) {
        searchModel.query = ""
        if selectedBook?.name != bookName {
            selectedBook = books.first(where: { $0.name == bookName })
        }
    }

    private func openSidebarReference() {
        guard let match = sidebarReference else { return }
        sidebarSearch = ""
        selectedBook = match.book
        searchModel.query = ""
        detailPath = NavigationPath()
        detailPath.append(ReadingRoute(
            bookName: match.book.name,
            chapterNumber: match.chapter.number,
            verseNumber: match.reference.startVerse
        ))
    }

    /// Opens a passage from search results, keeping the book selection in step.
    private func openReader(bookName: String, chapter: Int, verse: Int) {
        selectBookForReader(named: bookName)
        Task { @MainActor in
            // The book change may replace the detail stack; install the route after it.
            await Task.yield()
            detailPath = NavigationPath()
            detailPath.append(ReadingRoute(bookName: bookName, chapterNumber: chapter, verseNumber: verse))
        }
    }
}

#Preview {
    BibleSplitView(
        searchRequestID: 0,
        initialReaderLocation: nil
    )
}
