import SwiftUI

/// A dedicated starting point for book background and chapter-level study material.
struct StudyBibleEntryCard: View {
    let books: [Book]

    var body: some View {
        NavigationLink {
            StudyBibleView(books: books)
        } label: {
            FeatureTile(
                style: .bibleStudy,
                title: "Bible Study",
                subtitle: "Book overviews, chapter insights, and connections"
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("studyBibleEntryCard")
        .accessibilityHint("Opens book overviews, chapter insights, and Scripture connections")
    }
}

/// Browse the Bible's study material independently of the reading-focused book list.
struct StudyBibleView: View {
    let books: [Book]
    var isBooksPaneHidden = false
    /// Set by the iPad split view so a chosen book is also selected in the Books pane;
    /// otherwise each book pushes its study page.
    var onSelectBook: ((Book) -> Void)?
    var requestedDestination: AppRouter.StudyDestination? = nil

    @AppStorage(AppStorageKey.lastStudiedBook) private var lastStudiedBook = ""
    @AppStorage(AppStorageKey.lastStudiedChapter) private var lastStudiedChapter = 0
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var requestedChapter: StudyChapterRequest?
    @State private var requestedBookOverview: StudyBookOverviewRequest?
    @State private var studyTimeSourceID = UUID()
    @State private var searchText = ""
    @State private var continuedBrief: String?
    @State private var testamentFilter: StudyTestamentFilter = .all
    @AppStorage(AppStorageKey.studyBooksSortAlphabetical) private var sortAlphabetically = false

    private func bookColumns(for availableWidth: CGFloat) -> [GridItem] {
        let columnCount: Int

        if horizontalSizeClass == .compact {
            columnCount = 3
        } else if isBooksPaneHidden && availableWidth >= 800 {
            columnCount = 8
        } else if availableWidth >= 800 {
            columnCount = 6
        } else if availableWidth >= 700 {
            columnCount = 5
        } else {
            columnCount = 4
        }

        return Array(
            repeating: GridItem(.flexible(), spacing: 10),
            count: columnCount
        )
    }

    private var displayedBooks: [Book] {
        let filtered = books.filter { book in
            let matchesSearch = searchText.isEmpty || book.name.localizedCaseInsensitiveContains(searchText)
            return matchesSearch && testamentFilter.includes(book)
        }

        guard sortAlphabetically else { return filtered }
        return filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var continuedBook: Book? {
        books.first { $0.name == lastStudiedBook }
    }

    private var continuedChapter: Int? {
        lastStudiedChapter > 0 ? lastStudiedChapter : nil
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if let book = continuedBook, let chapterNumber = continuedChapter {
                        ContinueStudyingCard(book: book, chapterNumber: chapterNumber, brief: continuedBrief)
                    }

                    StudyToolsSection(isCompact: horizontalSizeClass == .compact)

                    StudySectionHeader(
                        title: "Books",
                        subtitle: "An overview and chapter insights for every book."
                    )
                    .padding(.top, 8)

                    LazyVGrid(
                        columns: bookColumns(for: geometry.size.width - 32),
                        alignment: .leading,
                        spacing: 10
                    ) {
                        ForEach(displayedBooks) { book in
                            StudyBookTile(book: book, onSelect: onSelectBook)
                        }
                    }
                }
                .padding()
            }
            .tabBarContentClearance()
            .background(AppBackgroundView(tab: .bible))
            .accessibilityIdentifier("studyBibleView")
            .navigationTitle("Bible Study")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: "\(lastStudiedBook) \(lastStudiedChapter)") {
                guard let book = continuedBook, let chapter = continuedChapter else {
                    continuedBrief = nil
                    return
                }
                continuedBrief = await ChapterInsightsRepository.shared.briefSummaries(forBookNamed: book.name)[chapter]
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Find a book"
            )
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        sortAlphabetically.toggle()
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .accessibilityLabel("Toggle book sort order")
                    .accessibilityValue(sortAlphabetically ? "Alphabetical" : "Canonical")
                    .accessibilityHint("Switches to \(sortAlphabetically ? "canonical" : "alphabetical") order")

                    Menu {
                        Picker("Books", selection: $testamentFilter) {
                            ForEach(StudyTestamentFilter.allCases) { filter in
                                Text(filter.title).tag(filter)
                            }
                        }
                    } label: {
                        Label("Filter books", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
        .navigationDestination(item: $requestedChapter) { request in
            ChapterInsightsView(bookName: request.bookName, chapterNumber: request.chapterNumber)
        }
        .navigationDestination(item: $requestedBookOverview) { request in
            BookOverviewView(bookName: request.bookName)
        }
        .onAppear {
            StudyTimeTracker.shared.start(studyTimeSourceID)

            switch requestedDestination {
            case .bookOverview(let bookName):
                requestedBookOverview = StudyBookOverviewRequest(bookName: bookName)
            case .chapterInsights(let bookName, let chapterNumber):
                requestedChapter = StudyChapterRequest(
                    bookName: bookName,
                    chapterNumber: chapterNumber
                )
            case nil:
                break
            }
        }
        .onDisappear {
            StudyTimeTracker.shared.stop(studyTimeSourceID)
        }
    }
}

private struct StudyChapterRequest: Hashable, Identifiable {
    let bookName: String
    let chapterNumber: Int
    let id = UUID()
}

private struct StudyBookOverviewRequest: Hashable, Identifiable {
    let bookName: String
    let id = UUID()
}

private struct ContinueStudyingCard: View {
    let book: Book
    let chapterNumber: Int
    var brief: String?

    var body: some View {
        NavigationLink {
            ChapterInsightsView(bookName: book.name, chapterNumber: chapterNumber)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Continue Studying")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("\(book.name) \(chapterNumber)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let brief {
                        Text(brief)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(AppDesignMetrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .heroCardSurface()
        }
        .buttonStyle(.plain)
    }
}

/// The study tools that work across the whole Bible rather than one book.
private struct StudyToolsSection: View {
    let isCompact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            StudySectionHeader(title: "Study Tools", subtitle: nil)

            // Side by side on wider screens; stacked on iPhone, where each needs the full width.
            let layout = isCompact ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
            layout {
                StudyToolCard(
                    title: "Scripture Connections",
                    subtitle: "Curated links between passages",
                    icon: "arrow.triangle.branch",
                    hint: "Opens curated Scripture connections"
                ) {
                    CrossReferenceExplorerView()
                }

                StudyToolCard(
                    title: "Word Study",
                    subtitle: "The Hebrew and Greek behind the text",
                    icon: "character.book.closed",
                    hint: "Explains word study and searches original words"
                ) {
                    WordStudyGuideView()
                }
            }
        }
    }
}

private struct StudyToolCard<Destination: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let icon: String
    let hint: LocalizedStringKey
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(AppDesignMetrics.cardPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .heroCardSurface()
        }
        .buttonStyle(.plain)
        .accessibilityHint(hint)
    }
}

private struct StudySectionHeader: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StudyBookTile: View {
    let book: Book
    let onSelect: ((Book) -> Void)?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The book's name with a leading number held to the name ("1 Corinthians").
    private var tileName: String {
        guard let first = book.name.first, first.isNumber else { return book.name }
        return book.name.replacingOccurrences(of: " ", with: "\u{00A0}", options: [], range: book.name.range(of: " "))
    }

    private var chapterCountLabel: String {
        "\(book.chapters.count) \(book.chapters.count == 1 ? "chapter" : "chapters")"
    }

    var body: some View {
        Group {
            if let onSelect {
                Button { onSelect(book) } label: { tile }
            } else {
                NavigationLink {
                    StudyBookView(book: book)
                } label: {
                    tile
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("studyBookTile-\(book.name)")
        .accessibilityLabel("\(book.name), \(chapterCountLabel)")
    }

    private var tile: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let theme = BookChapterTheme.themes[book.name] {
                BookChapterEmblem(theme: theme, size: 32)
            }

            Text(tileName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                // Names that can't wrap between words (Deuteronomy, 1 Thessalonians) shrink a
                // little to stay on one line rather than break mid-word or strand the number.
                .lineLimit(tileName.contains(" ") ? 2 : 1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 0)

            Text(chapterCountLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: dynamicTypeSize.isAccessibilitySize ? nil : 118,
            alignment: .topLeading
        )
        .padding(12)
        .heroCardSurface()
    }
}

/// A book's study page. It is the same page as the book overview: its chapters, what to
/// know before reading, and where it fits.
struct StudyBookView: View {
    let book: Book

    var body: some View {
        BookOverviewView(bookName: book.name)
    }
}

/// A one-row header that stays pinned once the reading chapter list's full header
/// scrolls away, keeping the book overview one tap away. Used by ChaptersView.
struct CompactStudyBookHeader: View {
    let bookName: String
    let onOpenOverview: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    title
                    overviewButton
                }
            } else {
                HStack(spacing: 10) {
                    title
                    Spacer(minLength: 8)
                    overviewButton
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .heroCardSurface()
        // A container, so the header's identifier doesn't replace the button's own.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("compactStudyBookHeader")
    }

    private var title: some View {
        HStack(spacing: 10) {
            if let theme = BookChapterTheme.themes[bookName] {
                BookChapterEmblem(theme: theme, size: 28)
            }

            Text(bookName)
                .font(.system(.title3, design: .serif, weight: .bold))
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var overviewButton: some View {
        Button("View \(bookName) Overview", systemImage: "book.closed.fill", action: onOpenOverview)
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            .accessibilityIdentifier("compactStudyBookOverviewButton")
            .accessibilityLabel("View \(bookName) Overview")
            .accessibilityHint("Opens the book overview")
    }
}
