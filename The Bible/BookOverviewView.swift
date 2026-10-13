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
            VStack(alignment: .leading, spacing: 20) {
                SummarySection(overview: overview)

                if !overview.story.isEmpty {
                    StoryPreviewSection(bookName: bookName, story: overview.story)
                }

                LabeledRowsSection(title: "Who", icon: "person.2.fill", rows: [
                    .init(title: "Author", icon: "pencil.line", content: overview.traditionalAuthorOrAttribution),
                    .init(title: "Original Audience", icon: "person.3.fill", content: overview.originalAudience)
                ])

                LabeledRowsSection(title: "When & Where", icon: "map", rows: whenAndWhereRows(overview))

                LabeledRowsSection(title: "Why It Was Written", icon: "target", rows: [
                    .init(title: "Purpose", icon: "scope", content: overview.purpose),
                    .init(title: "Reading Notes", icon: "text.book.closed", content: overview.interpretiveNotes)
                ])

                if !overview.movements.isEmpty {
                    KeyEventsSection(bookName: bookName, movements: overview.movements)
                }

                if !overview.keyFigures.isEmpty {
                    KeyFiguresSection(keyFigures: overview.keyFigures)
                }

                KeyScriptureSection(keyScripture: overview.keyScripture)
            }
            .padding()
        }
        .background(AppBackgroundView(tab: .bible))
        .environment(\.scriptureContextBook, bookName)
        .scripturePassagePreviews()
    }

    /// Falls back to the short historical-context note for any book without a When & Where section.
    private func whenAndWhereRows(_ overview: BibleBookOverview) -> [LabeledRowsSection.Row] {
        guard let whenAndWhere = overview.whenAndWhere else {
            return [.init(title: "Historical Context", icon: "calendar", content: overview.historicalContext)]
        }
        return [
            .init(title: "When It Happened", icon: "calendar", content: whenAndWhere.whenItHappened),
            .init(title: "When It Was Written", icon: "scroll", content: whenAndWhere.whenItWasWritten),
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

/// The book summary, headed by its one-line theme.
private struct SummarySection: View {
    let overview: BibleBookOverview

    var body: some View {
        HeroCard(title: "Summary", icon: "book.closed") {
            VStack(alignment: .leading, spacing: 8) {
                if !overview.overallTheme.isEmpty {
                    LinkedScriptureText(overview.overallTheme)
                        .font(.headline)
                }
                LinkedScriptureText(overview.plainEnglishSummary)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// The opening of the book's story, with a link to read all of it.
private struct StoryPreviewSection: View {
    let bookName: String
    let story: [BibleBookStorySection]

    var body: some View {
        HeroCard(title: "The Story of \(bookName)", icon: "book.pages") {
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

private struct KeyScriptureSection: View {
    let keyScripture: BibleKeyScripture

    var body: some View {
        HeroCard(title: "Key Scripture", icon: "quote.bubble") {
            VStack(alignment: .leading, spacing: 8) {
                if let reference = PassageReferenceParser.parse(keyScripture.reference) {
                    Link(destination: reference.url) {
                        Label(reference.displayTitle, systemImage: "book")
                            .font(.headline)
                    }
                    .accessibilityHint("Shows a preview of the passage")
                } else {
                    Text(keyScripture.reference)
                        .font(.headline)
                        .foregroundStyle(.tint)
                }

                Text("“\(keyScripture.text)”")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct KeyEventsSection: View {
    let bookName: String
    let movements: [BibleBookMovement]

    var body: some View {
        HeroCard(
            title: "Key Events",
            icon: "list.number"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(movements) { movement in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(movement.title)
                            .font(.headline)
                        LinkedScriptureText(movement.description)
                            .font(.body)
                            .foregroundStyle(.secondary)

                        if !movement.keyPassages.isEmpty {
                            PassageReferenceChips(references: movement.keyPassages, book: bookName)
                        }
                    }

                    if movement.id != movements.last?.id {
                        Divider()
                    }
                }
            }
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
