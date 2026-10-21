import SwiftUI

/// iPad Bible tab: a split view built from the same pieces as the iPhone flow —
/// the shared book list, chapter grid, reader, and search.
struct BibleSplitView: View {
    let searchRequestID: Int
    let studyRequestID: Int
    let studyDestination: AppRouter.StudyDestination?
    let initialReaderLocation: BibleReaderLocation?

    @State private var handledSearchRequestID: Int = 0
    @State private var handledStudyRequestID: Int = 0
    @State private var handledInitialReaderLocation: BibleReaderLocation?
    @State private var selectedBook: Book?
    @State private var sidebarSearch: String = ""
    @State private var detailPath = NavigationPath()
    @State private var isShowingBookOverview = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var searchModel = BibleSearchModel()
    /// While on, choosing a book opens its study page instead of its chapter grid. Not
    /// saved, so the tab always opens for reading.
    @State private var isStudyMode = false

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

    /// A book's study page, above the Bible Study home so Back returns there.
    private struct StudyBookRoute: Hashable {
        let bookName: String
    }

    private struct ChapterInsightsRoute: Hashable {
        let bookName: String
        let chapterNumber: Int
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
        .onAppear(perform: openStudyIfRequested)
        .onChange(of: studyRequestID) { _, _ in
            openStudyIfRequested()
        }
    }

    private func openStudyIfRequested() {
        guard studyRequestID > handledStudyRequestID else { return }
        handledStudyRequestID = studyRequestID

        guard let studyDestination else {
            setStudyMode(true)
            return
        }

        searchModel.query = ""
        isShowingBookOverview = false
        detailPath = NavigationPath()
        withAnimation(.snappy) { isStudyMode = true }
        Haptics.selection()

        Task { @MainActor in
            await Task.yield()
            var path = NavigationPath()
            switch studyDestination {
            case .bookOverview(let bookName):
                path.append(OverviewRoute(bookName: bookName))
            case .chapterInsights(let bookName, let chapterNumber):
                path.append(ChapterInsightsRoute(bookName: bookName, chapterNumber: chapterNumber))
            }
            detailPath = path
        }
    }

    /// Switches modes, keeping the selected book: its study page and its chapter grid
    /// swap places.
    private func setStudyMode(_ isOn: Bool) {
        searchModel.query = ""
        isShowingBookOverview = false
        detailPath = NavigationPath()
        withAnimation(.snappy) { isStudyMode = isOn }
        Haptics.selection()

        guard let bookName = selectedBook?.name else { return }
        Task { @MainActor in
            // Changing modes replaces the detail stack; install the book's page after it.
            await Task.yield()
            detailPath = bookPath(for: bookName)
        }
    }

    /// The detail stack showing a book. Reading mode shows its chapter grid at the root;
    /// Study mode puts its study page above the Bible Study home.
    private func bookPath(for bookName: String) -> NavigationPath {
        var path = NavigationPath()
        if isStudyMode {
            path.append(StudyBookRoute(bookName: bookName))
        }
        return path
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    sortAlphabetically.toggle()
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel("Toggle book sort order")
                .accessibilityValue(sortAlphabetically ? "Alphabetical" : "Canonical")
                .accessibilityHint("Switches to \(sortAlphabetically ? "canonical" : "alphabetical") order")
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

            // Pinned above the scrolling book list so they stay reachable.
            VStack(alignment: .leading, spacing: 16) {
                sidebarSearchField

                Button {
                    setStudyMode(!isStudyMode)
                } label: {
                    StudyBibleSidebarCard(isActive: isStudyMode)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isStudyMode ? .isSelected : [])
                .accessibilityHint(isStudyMode ? "Turns off Study mode so books open for reading" : "Books open their study pages until you turn it off")
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if let match = sidebarReference {
                        BibleReferenceJumpRow(reference: match.reference, action: openSidebarReference)
                    }

                    BibleBookSections(
                        books: books,
                        filterText: sidebarSearch,
                        alphabetical: sortAlphabetically,
                        // On the Bible Study home, no book is open.
                        selectedBookName: isStudyMode && detailPath.isEmpty ? nil : selectedBook?.name,
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
        } else if isStudyMode {
            StudyBibleView(
                books: books,
                isBooksPaneHidden: columnVisibility == .detailOnly,
                onSelectBook: select
            )
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
                .navigationDestination(for: StudyBookRoute.self) { route in
                    if let book = books.first(where: { $0.name == route.bookName }) {
                        StudyBookView(book: book)
                    }
                }
                .navigationDestination(for: ChapterInsightsRoute.self) { route in
                    ChapterInsightsView(bookName: route.bookName, chapterNumber: route.chapterNumber)
                }
                .navigationDestination(for: ReadingRoute.self) { route in
                    readingDestination(for: route)
                }
        }
        .background(AppBackgroundView(tab: .bible))
        // Changing modes, or choosing another book to read, starts the detail stack
        // fresh. Study mode keeps one stack, since its books open above the Bible Study home.
        .id(isStudyMode ? "study" : "read-\(selectedBook?.name ?? "__no_book__")")
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
            detailPath = bookPath(for: location.bookName)
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
                    // Return to the chapter grid, or study page, for the book being read.
                    selectedBook = currentBook
                    detailPath = bookPath(for: currentBook.name)
                },
                onBookSelected: { newBook in
                    selectedBook = newBook
                    detailPath = bookPath(for: newBook.name)
                }
            )
            .id("\(route.bookName)-\(route.chapterNumber)-\(route.verseNumber)")
        } else {
            ContentUnavailableView("Passage not found", systemImage: "exclamationmark.triangle")
        }
    }

    // MARK: - Actions

    private func select(_ book: Book) {
        if isStudyMode {
            selectedBook = book
            searchModel.query = ""
            detailPath = bookPath(for: book.name)
            return
        }

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
        detailPath = bookPath(for: match.book.name)
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
            detailPath = bookPath(for: bookName)
            detailPath.append(ReadingRoute(bookName: bookName, chapterNumber: chapter, verseNumber: verse))
        }
    }
}

/// Turns Study mode on and off; stays highlighted while it's on.
private struct StudyBibleSidebarCard: View {
    let isActive: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "graduationcap.fill")
                .foregroundStyle(isActive ? AnyShapeStyle(.white) : AnyShapeStyle(.tint))
                .frame(width: 28, height: 28)
                .background(isActive ? Color.accentColor : .clear, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(isActive ? "Studying" : "Bible Study")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(isActive ? "Books open their study pages" : "Overviews and insights")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: isActive ? "xmark.circle.fill" : "chevron.right")
                .font(isActive ? .body : .caption.weight(.semibold))
                .foregroundStyle(isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                .accessibilityHidden(true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(SurfaceStyle(isActive: isActive))
        .contentShape(.rect(cornerRadius: AppDesignMetrics.cardCornerRadius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Bible Study")
        .accessibilityValue(isActive ? "On" : "Off")
    }
}

/// The standard card surface, or a tinted, outlined one while Study mode is on.
private struct SurfaceStyle: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        if isActive {
            content
                .glassEffect(
                    .regular.tint(Color.accentColor.opacity(0.25)),
                    in: .rect(cornerRadius: AppDesignMetrics.cardCornerRadius)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.7), lineWidth: 1.5)
                }
        } else {
            content.heroCardSurface()
        }
    }
}

#Preview {
    BibleSplitView(
        searchRequestID: 0,
        studyRequestID: 0,
        studyDestination: nil,
        initialReaderLocation: nil
    )
}
