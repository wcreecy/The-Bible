import SwiftUI

/// A book's one page: its title and ways in, then three tabs. Chapters lists each chapter in
/// brief under the book's movements; About is what to know before reading; Where It Fits
/// links the book to the rest of the Bible.
struct BookOverviewView: View {
    let bookName: String

    private enum Tab: String, CaseIterable, Identifiable {
        case chapters = "Chapters"
        case about = "About"
        case whereItFits = "Where It Fits"

        var id: Self { self }
    }

    @State private var overview: BibleBookOverview?
    @State private var isLoading = true
    @State private var tab: Tab = .chapters
    @State private var details = ChapterOutlineDetails()
    @AppStorage(ChapterListLayout.storageKey) private var chapterLayout: ChapterListLayout = .detailed
    @State private var studyTimeSourceID = UUID()

    private var book: Book? {
        BibleData.books.first { $0.name == bookName }
    }

    private var theme: BookChapterTheme? {
        BookChapterTheme.themes[bookName]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if overview != nil || isLoading {
                    Picker("Section", selection: $tab) {
                        ForEach(Tab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                switch tab {
                case .chapters: chaptersTab
                case .about: aboutTab
                case .whereItFits: whereItFitsTab
                }
            }
            .padding()
        }
        .accessibilityIdentifier("studyBookScrollView")
        .tabBarContentClearance()
        .background(AppBackgroundView(tab: .bible))
        .environment(\.scriptureContextBook, bookName)
        .scripturePassagePreviews()
        .navigationTitle(bookName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if tab == .chapters {
                ToolbarItem(placement: .primaryAction) {
                    ChapterLayoutMenu(layout: $chapterLayout)
                }
            }
        }
        .task(id: bookName, loadOverview)
        .task(id: bookName) {
            if let book {
                details = await ChapterOutlineDetails.load(for: book)
            }
        }
        .onAppear {
            StudyTimeTracker.shared.start(studyTimeSourceID)
        }
        .onDisappear {
            StudyTimeTracker.shared.stop(studyTimeSourceID)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                if let theme {
                    BookChapterEmblem(theme: theme, size: 56)
                }
                Text(bookName)
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
            }

            if let theme = overview?.overallTheme, !theme.isEmpty {
                LinkedScriptureText(theme)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            OverviewActions(bookName: bookName, story: overview?.story ?? [])
        }
        .padding(AppDesignMetrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .heroCardSurface()
    }

    // MARK: - Tabs

    @ViewBuilder
    private var chaptersTab: some View {
        if let book {
            switch chapterLayout {
            case .simple:
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 10)], spacing: 10) {
                    ForEach(book.chapters) { chapter in
                        NavigationLink {
                            ChapterInsightsView(bookName: bookName, chapterNumber: chapter.number)
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
            case .detailed:
                ChapterOutlineList(chapterNumbers: book.chapters.map(\.number), sections: details.sections) { number in
                    NavigationLink {
                        ChapterInsightsView(bookName: bookName, chapterNumber: number)
                    } label: {
                        ChapterThemeRow(number: number, themes: details.themeNames[number] ?? [], brief: details.briefs[number])
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var aboutTab: some View {
        if let overview {
            VStack(alignment: .leading, spacing: 20) {
                InBriefSection(overview: overview)

                LabeledRowsSection(title: "Author & Purpose", icon: "pencil.line", rows: [
                    .init(title: "Author", icon: "pencil.line", content: overview.traditionalAuthorOrAttribution),
                    .init(title: "Original Audience", icon: "person.3.fill", content: overview.originalAudience),
                    .init(title: "Why It Was Written", icon: "target", content: overview.purpose)
                ])

                LabeledRowsSection(title: "Setting", icon: "map", rows: settingRows(overview))

                BookReadingGuideSection(bookName: bookName, tips: overview.readingTips)

                if !overview.keyFigures.isEmpty {
                    KeyPeopleSection(keyFigures: overview.keyFigures)
                }
            }
        } else if isLoading {
            ProgressView("Loading…").frame(maxWidth: .infinity)
        } else {
            unavailable
        }
    }

    @ViewBuilder
    private var whereItFitsTab: some View {
        if let overview {
            VStack(alignment: .leading, spacing: 20) {
                if !overview.connections.isEmpty {
                    ConnectionsSection(connections: overview.connections)
                }

                BookPlansSection(bookName: bookName)
            }
        } else if isLoading {
            ProgressView("Loading…").frame(maxWidth: .infinity)
        } else {
            unavailable
        }
    }

    private var unavailable: some View {
        ContentUnavailableView(
            "Overview Unavailable",
            systemImage: "book.closed",
            description: Text("An overview for \(bookName) could not be found.")
        )
    }

    private func settingRows(_ overview: BibleBookOverview) -> [LabeledRowsSection.Row] {
        guard let whenAndWhere = overview.whenAndWhere else { return [] }
        // A letter's history describes when it was sent and how it came about, not events it narrates.
        let isLetter = BibleStudyMetadata.genre(for: overview.name) == "Letter"
        return [
            .init(title: isLetter ? "When It Was Written" : "When It Happened", icon: "calendar", content: whenAndWhere.whenItHappened),
            .init(title: isLetter ? "How It Came to Be" : "How It Was Written", icon: "scroll", content: whenAndWhere.whenItWasWritten),
            .init(title: "Where", icon: "mappin.and.ellipse", content: whenAndWhere.location),
            .init(title: "The World at the Time", icon: "globe.europe.africa", content: whenAndWhere.worldAtTheTime)
        ]
    }

    private func loadOverview() async {
        // Returning from the story page shouldn't reload and lose the scroll position.
        guard overview?.name != bookName else { return }
        isLoading = true
        overview = await BibleBookOverviewRepository.shared.overview(forBookNamed: bookName)
        isLoading = false
    }
}

/// The book in brief: its one-line theme, summary, and key verse.
private struct InBriefSection: View {
    let overview: BibleBookOverview

    var body: some View {
        HeroCard(title: "In Brief", icon: "text.quote") {
            VStack(alignment: .leading, spacing: 8) {
                if !overview.overallTheme.isEmpty {
                    LinkedScriptureText(overview.overallTheme)
                        .font(.headline)
                }
                LinkedScriptureText(overview.plainEnglishSummary)
                    .font(.body)
                    .foregroundStyle(.secondary)

                if !overview.keyScripture.text.isEmpty {
                    Divider()
                        .padding(.vertical, 4)
                    KeyScriptureView(keyScripture: overview.keyScripture)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// The book's genre and practical tips for reading it.
private struct BookReadingGuideSection: View {
    let bookName: String
    let tips: [String]

    var body: some View {
        HeroCard(title: "How to Read This Book", icon: "text.book.closed") {
            VStack(alignment: .leading, spacing: 8) {
                Label(BibleStudyMetadata.genre(for: bookName), systemImage: "tag")
                    .font(.headline)

                if tips.isEmpty {
                    // Books without their own tips fall back to the general advice for the genre.
                    Text(BibleStudyMetadata.readingTip(for: bookName))
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(tips, id: \.self) { tip in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(.tint)
                                .accessibilityHidden(true)
                            LinkedScriptureText(tip)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Where the book fits in the Bible's larger story: what it builds on and where it is picked up later.
private struct ConnectionsSection: View {
    let connections: [BibleBookConnection]

    private var looksBack: [BibleBookConnection] {
        connections.filter { $0.direction == .back }
    }

    private var looksAhead: [BibleBookConnection] {
        connections.filter { $0.direction == .ahead }
    }

    var body: some View {
        HeroCard(title: "Builds On & Looks Ahead", icon: "point.3.connected.trianglepath.dotted") {
            VStack(alignment: .leading, spacing: 16) {
                if !looksBack.isEmpty {
                    group(title: "Builds On", icon: "arrow.uturn.backward", connections: looksBack)
                }
                if !looksBack.isEmpty && !looksAhead.isEmpty {
                    Divider()
                }
                if !looksAhead.isEmpty {
                    group(title: "Looks Ahead To", icon: "arrow.forward", connections: looksAhead)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func group(title: String, icon: String, connections: [BibleBookConnection]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)

            ForEach(connections) { connection in
                VStack(alignment: .leading, spacing: 4) {
                    Text(connection.title)
                        .font(.headline)
                    LinkedScriptureText(connection.text)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

/// The ways into the book, right under its summary: reading it, and its full story.
private struct OverviewActions: View {
    let bookName: String
    let story: [BibleBookStorySection]

    @State private var hasSavedStoryPlace = false

    var body: some View {
        // Side by side at equal widths when each label fits in its share; stacked in narrow
        // widths, for long book names, or at large text sizes.
        ViewThatFits(in: .horizontal) {
            EqualWidthHStack(spacing: 10) { buttons }
            VStack(spacing: 10) { buttons }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        Button {
            AppRouter.shared.openBibleReference(book: bookName, chapter: 1, verse: 1)
        } label: {
            Label("Start Reading", systemImage: "book.fill")
                .font(.headline)
                .lineLimit(1)
                // Full height too, so side-by-side buttons match even if their icons differ.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.glassProminent)
        .accessibilityHint("Opens \(bookName) chapter 1")

        if !story.isEmpty {
            NavigationLink {
                BookStoryView(bookName: bookName, story: story)
                    .studySheetDoneButton()
            } label: {
                Label(
                    hasSavedStoryPlace ? "Continue Retelling" : "Plain-English Retelling",
                    systemImage: hasSavedStoryPlace ? "bookmark.fill" : "book.pages"
                )
                    .font(.headline)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glass)
            .accessibilityHint(
                hasSavedStoryPlace
                    ? "Continues the retelling of \(bookName) from your saved place"
                    : "Opens a plain-English retelling of \(bookName)"
            )
            .onAppear {
                hasSavedStoryPlace = BookStoryProgress.savedSectionID(for: bookName) != nil
            }
        }
    }
}

/// Children side by side at equal widths. Its ideal width is the widest child's times the
/// count, so `ViewThatFits` only picks it when every child fits in an equal share.
private struct EqualWidthHStack: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let gaps = spacing * CGFloat(subviews.count - 1)
        let idealWidth = (sizes.map(\.width).max() ?? 0) * CGFloat(subviews.count) + gaps
        return CGSize(width: proposal.width ?? idealWidth, height: sizes.map(\.height).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let gaps = spacing * CGFloat(subviews.count - 1)
        let width = max(0, (bounds.width - gaps) / CGFloat(subviews.count))
        var x = bounds.minX
        for subview in subviews {
            subview.place(
                at: CGPoint(x: x, y: bounds.minY),
                proposal: ProposedViewSize(width: width, height: bounds.height)
            )
            x += width + spacing
        }
    }
}

/// The book's key verse, with its reference linked to a passage preview.
private struct KeyScriptureView: View {
    let keyScripture: BibleKeyScripture

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let reference = PassageReferenceParser.parse(keyScripture.reference) {
                Link(destination: reference.url) {
                    Label("Key Verse: \(reference.displayTitle)", systemImage: "quote.bubble")
                        .font(.subheadline.weight(.semibold))
                }
                .accessibilityHint("Shows a preview of the passage")
            } else {
                Label("Key Verse: \(keyScripture.reference)", systemImage: "quote.bubble")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
            }

            Text("“\(keyScripture.text)”")
                .font(.body.italic())
                .frame(maxWidth: .infinity, alignment: .leading)

            // The text is copied from the KJV when the study database is built, whatever
            // translation is being read.
            Text("King James Version")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct KeyPeopleSection: View {
    let keyFigures: [BibleBookKeyFigure]

    var body: some View {
        HeroCard(
            title: "Key People",
            icon: "person.2.fill"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(keyFigures) { figure in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(figure.name)
                            .font(.headline)
                        LinkedScriptureText(figure.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    if figure.id != keyFigures.last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}

/// A card of short labeled entries, such as the author and audience of a book.
private struct LabeledRowsSection: View {
    let title: String
    let icon: String
    let rows: [Row]

    struct Row: Identifiable {
        let title: String
        let icon: String
        let content: String
        var id: String { title }
    }

    // Skip any entries the overview data leaves blank.
    private var visibleRows: [Row] {
        rows.filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        if !visibleRows.isEmpty {
            HeroCard(title: title, icon: icon) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(visibleRows) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Label(row.title, systemImage: row.icon)
                                .font(.headline)
                            LinkedScriptureText(row.content)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if row.id != visibleRows.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        BookOverviewView(bookName: "Genesis")
    }
}
