import SwiftUI

struct BookOverviewView: View {
    let bookName: String

    @State private var overview: BibleBookOverview?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading overview…")
            } else if let overview {
                overviewContent(overview)
            } else {
                ContentUnavailableView(
                    "Overview Unavailable",
                    systemImage: "book.closed",
                    description: Text("An overview for \(bookName) could not be found.")
                )
            }
        }
        .navigationTitle("About \(bookName)")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: bookName, loadOverview)
    }

    private func overviewContent(_ overview: BibleBookOverview) -> some View {
        ScrollView {
            // Ordered to build context before reading: what the book is, who wrote it
            // and why, the world it came from, how to approach it, then what's inside.
            VStack(alignment: .leading, spacing: 20) {
                AtAGlanceSection(overview: overview)

                LabeledRowsSection(title: "Background", icon: "person.2.fill", rows: [
                    .init(title: "Author", icon: "pencil.line", content: overview.traditionalAuthorOrAttribution),
                    .init(title: "Original Audience", icon: "person.3.fill", content: overview.originalAudience),
                    .init(title: "Why It Was Written", icon: "target", content: overview.purpose)
                ])

                LabeledRowsSection(title: "Setting", icon: "map", rows: settingRows(overview))

                if !overview.connections.isEmpty {
                    ConnectionsSection(connections: overview.connections)
                }

                BookReadingGuideSection(bookName: bookName, tips: overview.readingTips)

                if !overview.story.isEmpty {
                    BookStructureSection(bookName: bookName, sections: overview.story)
                }

                if !overview.keyFigures.isEmpty {
                    KeyFiguresSection(keyFigures: overview.keyFigures)
                }

                if !overview.story.isEmpty {
                    StoryPreviewSection(bookName: bookName, story: overview.story)
                }

                StartReadingButton(bookName: bookName)
            }
            .padding()
        }
        .tabBarContentClearance()
        .background(AppBackgroundView(tab: .bible))
        .environment(\.scriptureContextBook, bookName)
        .scripturePassagePreviews()
    }

    private func settingRows(_ overview: BibleBookOverview) -> [LabeledRowsSection.Row] {
        guard let whenAndWhere = overview.whenAndWhere else { return [] }
        return [
            .init(title: "When It Happened", icon: "calendar", content: whenAndWhere.whenItHappened),
            .init(title: "How It Was Written", icon: "scroll", content: whenAndWhere.whenItWasWritten),
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
private struct AtAGlanceSection: View {
    let overview: BibleBookOverview

    var body: some View {
        HeroCard(title: "At a Glance", icon: "book.closed") {
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
        HeroCard(title: "Connections Across the Bible", icon: "point.3.connected.trianglepath.dotted") {
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

/// A detailed outline of the book, one entry per part of its story.
private struct BookStructureSection: View {
    let bookName: String
    let sections: [BibleBookStorySection]

    var body: some View {
        HeroCard(title: "Book Structure", icon: "list.number") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                    let outline = OutlineEntry(passage: section.passage)

                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(index + 1, format: .number)
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.tint)
                            .frame(minWidth: 20, alignment: .trailing)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(outline.title)
                                .font(.headline)
                            if let reference = outline.reference {
                                PassageReferenceChips(references: [reference], book: bookName)
                            }
                        }
                    }

                    if section.id != sections.last?.id {
                        Divider()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Splits a story label such as "Sin Enters the World (Genesis 3:1–5:32)" into its title and reference.
    private struct OutlineEntry {
        let title: String
        let reference: String?

        init(passage: String) {
            guard passage.hasSuffix(")"),
                  let open = passage.range(of: " (", options: .backwards) else {
                title = passage
                reference = nil
                return
            }
            title = String(passage[..<open.lowerBound])
            reference = String(passage[open.upperBound..<passage.index(before: passage.endIndex)])
        }
    }
}

/// Opens the book at its first chapter.
private struct StartReadingButton: View {
    let bookName: String

    var body: some View {
        Button {
            AppRouter.shared.openBibleReference(book: bookName, chapter: 1, verse: 1)
        } label: {
            Label("Start Reading \(bookName)", systemImage: "book.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityHint("Opens \(bookName) chapter 1")
    }
}

/// The opening of the book's story, with a link to read all of it.
private struct StoryPreviewSection: View {
    let bookName: String
    let story: [BibleBookStorySection]

    var body: some View {
        HeroCard(title: "Go Deeper: The Story of \(bookName)", icon: "book.pages") {
            VStack(alignment: .leading, spacing: 12) {
                if let opening = story.first {
                    Text(opening.previewText)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                NavigationLink {
                    BookStoryView(bookName: bookName, story: story)
                        .studySheetDoneButton()
                } label: {
                    Label("Read the Story", systemImage: "arrow.right.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
            }
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
        }
    }
}

private struct KeyFiguresSection: View {
    let keyFigures: [BibleBookKeyFigure]

    var body: some View {
        HeroCard(
            title: "Key Figures",
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
