import Foundation
import SwiftData
import SwiftUI

struct ChapterInsightsView: View {
    /// Previous and next links change the chapter in place, so a sheet keeps its Done button
    /// and moving through a book doesn't build a long back stack.
    @State private var location: ChapterLocation
    @State private var insights: ChapterInsights?
    @State private var neighborSummaries: [ChapterLocation: String] = [:]
    @State private var isLoading = true
    @State private var studyTimeSourceID = UUID()
    /// The chapter `insights` was loaded for; returning from a pushed page shouldn't reload.
    @State private var loadedLocation: ChapterLocation?
    @AppStorage(AppStorageKey.lastStudiedBook) private var lastStudiedBook = ""
    @AppStorage(AppStorageKey.lastStudiedChapter) private var lastStudiedChapter = 0
    @Environment(\.dismiss) private var dismiss
    /// The chapter open in the reader beneath this sheet, if the reader presented it.
    private let readerLocation: ChapterLocation?

    /// Pass `openedFromReader` when the reader presents this page for its current chapter,
    /// so Read returns to the reader (keeping its place) instead of reopening the chapter.
    init(bookName: String, chapterNumber: Int, openedFromReader: Bool = false) {
        let location = ChapterLocation(bookName: bookName, chapterNumber: chapterNumber)
        _location = State(initialValue: location)
        readerLocation = openedFromReader ? location : nil
    }

    private var bookName: String { location.bookName }
    private var chapterNumber: Int { location.chapterNumber }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading chapter insights…")
            } else if let insights {
                insightsContent(insights)
            } else {
                ContentUnavailableView(
                    "Chapter Insights Unavailable",
                    systemImage: "text.book.closed",
                    description: Text("Insights for \(location.title) have not been added yet.")
                )
            }
        }
        .navigationTitle(location.title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: location, loadInsights)
        .onChange(of: location, initial: true) { _, newLocation in
            lastStudiedBook = newLocation.bookName
            lastStudiedChapter = newLocation.chapterNumber
        }
        .onAppear {
            StudyTimeTracker.shared.start(studyTimeSourceID)
        }
        .onDisappear {
            StudyTimeTracker.shared.stop(studyTimeSourceID)
        }
    }

    // Ordered the way a reader takes in a chapter: where it falls in the story, what happens,
    // who is involved, the world behind it, what it means, where Scripture picks it up, then
    // the way on to the chapters around it.
    private func insightsContent(_ insights: ChapterInsights) -> some View {
        let context = insights.readingContext
        let content = ChapterContentFilter(insights: insights, context: context)
        let previous = location.previous
        let next = location.next

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                WhereWeAreSection(narrativePlacement: content.narrativePlacement)

                ChapterSummaryCard(
                    bookName: bookName,
                    chapterNumber: chapterNumber,
                    summary: insights.overallSummary
                )

                if !insights.keyFigures.isEmpty {
                    ChapterInsightList(title: "Key People", icon: "person.2.fill") {
                        ForEach(insights.keyFigures) { figure in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(figure.name)
                                    .font(.headline)
                                LinkedScriptureText(figure.roleAndSignificance)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                ChapterBackgroundSection(rows: content.backgroundRows)

                if !insights.keyThemes.isEmpty {
                    ChapterInsightList(title: "Key Themes", icon: "sparkles") {
                        ForEach(insights.keyThemes) { theme in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(theme.theme)
                                    .font(.headline)
                                if !theme.explanation.isEmpty {
                                    LinkedScriptureText(theme.explanation)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                if !theme.scriptureReferences.isEmpty {
                                    PassageReferenceChips(
                                        references: theme.scriptureReferences,
                                        book: bookName,
                                        chapter: chapterNumber
                                    )
                                }
                            }
                        }
                    }
                }

                if !insights.relatedVerses.isEmpty {
                    ChapterCrossReferencesPreview(
                        bookName: bookName,
                        chapterNumber: chapterNumber,
                        relatedVerses: insights.relatedVerses
                    )
                }

                // Quotations in the study text were written against the KJV, whatever
                // translation is being read.
                Text("Verses quoted in these notes are from the King James Version.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ChapterNavigationSection(
                    location: location,
                    previous: previous,
                    previousSummary: previous.flatMap { neighborSummaries[$0] },
                    next: next,
                    nextSummary: next.flatMap { neighborSummaries[$0] },
                    onSelect: { location = $0 },
                    onRead: readChapter
                )
            }
            .padding()
        }
        // A new chapter starts fresh, scrolled to the top.
        .id(location)
        .background(AppBackgroundView(tab: .bible))
        .environment(\.scriptureContextBook, bookName)
        .scripturePassagePreviews()
    }

    private func readChapter() {
        dismiss()
        // The reader underneath already shows this chapter; closing returns to it in place.
        guard location != readerLocation else { return }
        AppRouter.shared.openBibleReference(book: bookName, chapter: chapterNumber, verse: 1)
    }

    private func loadInsights() async {
        guard loadedLocation != location else { return }
        let requested = location
        isLoading = insights == nil
        let loaded = await ChapterInsightsRepository.shared.insights(
            forBookNamed: requested.bookName,
            chapterNumber: requested.chapterNumber
        )
        var summaries: [ChapterLocation: String] = [:]
        for neighbor in [requested.previous, requested.next].compactMap({ $0 }) {
            summaries[neighbor] = await ChapterInsightsRepository.shared.summary(
                forBookNamed: neighbor.bookName,
                chapterNumber: neighbor.chapterNumber
            )
        }
        // Ignore a result for a chapter the reader has already moved past.
        guard requested == location else { return }
        insights = loaded.map {
            ChapterCrossReferenceDeduplicator.deduplicated(
                $0,
                bookName: requested.bookName,
                chapterNumber: requested.chapterNumber
            )
        }
        neighborSummaries = summaries
        loadedLocation = requested
        isLoading = false
    }
}

/// A chapter of a book, with its neighbors across book boundaries.
struct ChapterLocation: Hashable {
    let bookName: String
    let chapterNumber: Int

    var title: String { "\(bookName) \(chapterNumber)" }

    var previous: ChapterLocation? {
        let books = BibleData.books
        guard let index = books.firstIndex(where: { $0.name == bookName }) else { return nil }
        if chapterNumber > 1 {
            return ChapterLocation(bookName: bookName, chapterNumber: chapterNumber - 1)
        }
        guard index > 0, let last = books[index - 1].chapters.last else { return nil }
        return ChapterLocation(bookName: books[index - 1].name, chapterNumber: last.number)
    }

    var next: ChapterLocation? {
        let books = BibleData.books
        guard let index = books.firstIndex(where: { $0.name == bookName }) else { return nil }
        if chapterNumber < books[index].chapters.count {
            return ChapterLocation(bookName: bookName, chapterNumber: chapterNumber + 1)
        }
        guard index + 1 < books.count, let first = books[index + 1].chapters.first else { return nil }
        return ChapterLocation(bookName: books[index + 1].name, chapterNumber: first.number)
    }
}

#Preview {
    NavigationStack {
        ChapterInsightsView(bookName: "Genesis", chapterNumber: 1)
    }
}
