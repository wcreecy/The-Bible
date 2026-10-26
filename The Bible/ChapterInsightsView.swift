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

/// Some imported text repeats another field word for word (the summary).
/// This keeps only text the page doesn't already show, so each piece appears once.
private struct ChapterContentFilter {
    let narrativePlacement: String
    let backgroundRows: [ChapterBackgroundSection.Row]

    init(insights: ChapterInsights, context: ChapterReadingContext?) {
        var shown = Set<String>()
        func claim(_ text: String) -> String {
            let key = Self.normalized(text)
            guard !key.isEmpty, shown.insert(key).inserted else { return "" }
            return text
        }

        _ = claim(insights.overallSummary)
        narrativePlacement = claim(context?.narrativePlacement ?? "")

        var rows: [ChapterBackgroundSection.Row] = []
        let moment = claim(context?.firstCenturyMoment ?? "")
        if !moment.isEmpty {
            rows.append(.init(title: "The Historical Moment", icon: "calendar", content: moment))
        }
        let audience = claim(context?.originalAudience ?? "")
        if !audience.isEmpty {
            rows.append(.init(title: "The Original Audience", icon: "person.3.fill", content: audience))
        }
        for lens in context?.culturalLenses ?? [] {
            let text = claim(lens.then)
            guard !text.isEmpty else { continue }
            rows.append(.init(title: lens.title, icon: "scroll", reference: lens.reference, content: text))
        }
        backgroundRows = rows
    }

    private static func normalized(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " .!?"))
    }
}

/// Where the chapter falls in the book's story. The text itself recalls the chapter before,
/// so the link to it sits with the other chapter navigation at the bottom of the page.
private struct WhereWeAreSection: View {
    let narrativePlacement: String

    var body: some View {
        if !narrativePlacement.isEmpty {
            HeroCard(title: "Where We Are", icon: "mappin.and.ellipse") {
                LinkedScriptureText(narrativePlacement)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// The chapter's events as a numbered outline when the summary cites verse ranges, otherwise the summary itself.
private struct ChapterSummaryCard: View {
    let bookName: String
    let chapterNumber: Int
    let summary: String

    @State private var showsFullSummary = false

    private var events: [ChapterEvent]? {
        ChapterEvent.outline(from: summary, bookName: bookName, chapterNumber: chapterNumber)
    }

    private var sentences: [String] {
        summary.sentences
    }

    private var displayedSentences: [String] {
        guard summary.count > 650, !showsFullSummary else { return sentences }
        return Array(sentences.prefix(5))
    }

    var body: some View {
        if let events {
            HeroCard(title: "What Happens", icon: "list.number") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(events) { event in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(event.id + 1, format: .number)
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.tint)
                                .frame(minWidth: 18, alignment: .trailing)

                            VStack(alignment: .leading, spacing: 6) {
                                LinkedScriptureText(event.text)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if let reference = event.reference {
                                    PassageReferenceChips(
                                        references: [reference],
                                        book: bookName,
                                        chapter: chapterNumber
                                    )
                                }
                            }
                        }

                        if event.id != events.last?.id {
                            Divider()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            HeroCard(title: "Summary", icon: "text.book.closed") {
                if summary.count <= 650 {
                    LinkedScriptureText(summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ChapterInsightBullets(items: displayedSentences)

                        if !showsFullSummary, sentences.count > displayedSentences.count {
                            Button("Show full summary") {
                                showsFullSummary = true
                            }
                            .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
        }
    }
}

/// One step in a chapter's outline, ending at a sentence that cites its verses.
struct ChapterEvent: Identifiable {
    let id: Int
    var text: String
    let reference: String?

    /// Builds an outline from summary sentences ending in a citation, such as
    /// "Sisera flees into Jael's tent, where Jael kills him (Judges 4:17–24)."
    /// Returns nil when fewer than two sentences cite their verses.
    static func outline(from summary: String, bookName: String, chapterNumber: Int) -> [ChapterEvent]? {
        var events: [ChapterEvent] = []
        var pending: [String] = []

        for sentence in summary.sentences {
            if let citation = sentence.trailingCitation(bookName: bookName, chapterNumber: chapterNumber) {
                pending.append(citation.text)
                events.append(ChapterEvent(id: events.count, text: pending.joined(separator: " "), reference: citation.reference))
                pending = []
            } else {
                pending.append(sentence)
            }
        }

        guard events.count >= 2 else { return nil }
        // Closing sentences without a citation belong with the last event.
        if !pending.isEmpty {
            events[events.count - 1].text += " " + pending.joined(separator: " ")
        }
        return events
    }

    /// Whether this outline item cites the supplied verse, including chapter-wide and
    /// multi-chapter citations such as "Numbers 2" or "Numbers 2:3–3:1".
    func contains(bookName: String, chapterNumber: Int, verseNumber: Int) -> Bool {
        guard let reference else { return false }

        return PassageReferenceParser.parseList(reference, book: bookName, chapter: chapterNumber).contains { passage in
            guard passage.bookName == bookName,
                  passage.startChapter <= chapterNumber,
                  chapterNumber <= passage.endChapter else {
                return false
            }

            let firstVerse = passage.startChapter == chapterNumber ? passage.startVerse ?? 1 : 1
            let lastVerse = passage.endChapter == chapterNumber ? passage.endVerse ?? .max : .max
            return (firstVerse...lastVerse).contains(verseNumber)
        }
    }
}

/// The chapter's own background: its historical moment, audience, and customs, without
/// repeating anything shown elsewhere on the page.
private struct ChapterBackgroundSection: View {
    struct Row: Identifiable {
        let title: String
        let icon: String
        var reference = ""
        let content: String
        var id: String { title + reference }
    }

    let rows: [Row]

    var body: some View {
        if !rows.isEmpty {
            HeroCard(title: "Historical & Cultural Background", icon: "building.columns") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(rows) { row in
                        VStack(alignment: .leading, spacing: 6) {
                            Label(row.title, systemImage: row.icon)
                                .font(.headline)

                            if !row.reference.isEmpty {
                                LinkedScriptureText(row.reference)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.tint)
                            }

                            if row.content.paragraphs.count > 1 {
                                ChapterInsightBullets(items: row.content.paragraphs)
                            } else {
                                LinkedScriptureText(row.content)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if row.id != rows.last?.id {
                            Divider()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// Opens the chapter in the reader, previews the chapters before and after, and links to the book overview.
private struct ChapterNavigationSection: View {
    let location: ChapterLocation
    let previous: ChapterLocation?
    let previousSummary: String?
    let next: ChapterLocation?
    let nextSummary: String?
    let onSelect: (ChapterLocation) -> Void
    let onRead: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: onRead) {
                Label("Read \(location.title)", systemImage: "book.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Opens this chapter in the reader")

            if previous != nil || next != nil {
                VStack(alignment: .leading, spacing: 12) {
                    if let next {
                        NeighborChapterLink(
                            label: "Up Next",
                            location: next,
                            summary: nextSummary,
                            icon: "chevron.right",
                            action: { onSelect(next) }
                        )
                    }
                    if let previous {
                        if next != nil {
                            Divider()
                        }
                        NeighborChapterLink(
                            label: "Previous",
                            location: previous,
                            summary: previousSummary,
                            icon: "chevron.left",
                            action: { onSelect(previous) }
                        )
                    }
                }
                .padding(AppDesignMetrics.cardPadding)
                .heroCardSurface()
            }

            AboutBookLink(bookName: location.bookName)
        }
    }
}

/// A link to the chapter before or after, previewed by the opening of its summary.
private struct NeighborChapterLink: View {
    let label: String
    let location: ChapterLocation
    let summary: String?
    let icon: String
    let action: () -> Void

    private var opening: String? {
        guard let summary else { return nil }
        let first = summary.sentences.first ?? summary
        return first.trailingCitation(bookName: location.bookName, chapterNumber: location.chapterNumber)?.text ?? first
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(label): \(location.title)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                    if let opening {
                        Text(opening)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows insights for \(location.title)")
    }
}

/// Opens the book overview, where the book's history and full story are kept.
private struct AboutBookLink: View {
    let bookName: String

    var body: some View {
        NavigationLink {
            BookOverviewView(bookName: bookName)
                .studySheetDoneButton(placement: .topBarTrailing)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "book.closed")
                    .font(.title2)
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text("About \(bookName)")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Who wrote it, when and where, and the story of the whole book")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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

private struct ChapterInsightBullets: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(.tint)
                        .padding(.top, 6)

                    LinkedScriptureText(item)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct ChapterInsightList<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        HeroCard(title: title, icon: icon) {
            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A preview of the chapter's cross references, each shown as a pair of passages.
struct ChapterCrossReferencesPreview: View {
    let bookName: String
    let chapterNumber: Int
    let relatedVerses: [ChapterRelatedVerse]

    @State private var pairs: [ScriptureCrossReference] = []
    @State private var isLoading = true

    var body: some View {
        HeroCard(title: "Cross References", icon: "arrow.triangle.branch") {
            if isLoading {
                ProgressView("Loading cross references…")
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if pairs.isEmpty {
                ContentUnavailableView(
                    "Cross References Unavailable",
                    systemImage: "arrow.triangle.branch",
                    description: Text("The linked passages could not be loaded.")
                )
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(pairs.prefix(2)) { pair in
                        ScriptureCrossReferenceCard(pair: pair)
                    }

                    NavigationLink {
                        ChapterCrossReferencesView(
                            bookName: bookName,
                            chapterNumber: chapterNumber,
                            relatedVerses: relatedVerses
                        )
                    } label: {
                        Label("See all \(pairs.count) cross references", systemImage: "arrow.right")
                            .font(.subheadline.weight(.semibold))
                    }
                    .accessibilityHint("Opens every cross reference for this chapter")
                }
            }
        }
        .task(id: "\(bookName)-\(chapterNumber)") {
            pairs = await ScriptureCrossReferenceLoader.load(
                bookName: bookName,
                chapterNumber: chapterNumber,
                relatedVerses: relatedVerses
            )
            isLoading = false
        }
    }
}

/// The full, grouped cross-reference list reached from the Chapter Insights preview.
struct ChapterCrossReferencesView: View {
    let bookName: String
    let chapterNumber: Int
    let relatedVerses: [ChapterRelatedVerse]

    @State private var pairs: [ScriptureCrossReference] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading cross references…")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(groupedPairs, id: \.source.reference.id) { group in
                        CrossReferenceGroup(source: group.source, pairs: group.pairs)
                    }
                }
                .padding()
            }
        }
        .background(AppBackgroundView(tab: .bible))
        .navigationTitle("Cross References")
        .navigationBarTitleDisplayMode(.inline)
        .scripturePassagePreviews()
        .task(id: "\(bookName)-\(chapterNumber)") {
            pairs = await ScriptureCrossReferenceLoader.load(
                bookName: bookName,
                chapterNumber: chapterNumber,
                relatedVerses: relatedVerses
            )
            isLoading = false
        }
    }

    private var groupedPairs: [(source: ScriptureCrossReference.Source, pairs: [ScriptureCrossReference])] {
        Dictionary(grouping: pairs, by: \.source)
            .sorted { $0.key.verseNumber < $1.key.verseNumber }
            .map { (source: $0.key, pairs: $0.value) }
    }
}

private struct CrossReferenceGroup: View {
    let source: ScriptureCrossReference.Source
    let pairs: [ScriptureCrossReference]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(source.reference.displayTitle)
                .font(.headline)

            Text("“\(source.excerpt)”")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(pairs) { pair in
                ScriptureCrossReferenceCard(pair: pair, showsSource: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ScriptureCrossReferenceCard: View {
    let pair: ScriptureCrossReference
    var showsSource = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                if showsSource {
                    ScriptureConnectionLink(
                        reference: pair.source.reference,
                        excerpt: pair.source.excerpt,
                        pair: pair
                    )
                }

                Image(systemName: "arrow.left.and.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
                    .padding(.top, 4)

                ScriptureConnectionLink(
                    reference: pair.target.reference,
                    excerpt: pair.target.excerpt,
                    pair: pair
                )
            }

            Text(pair.relationshipDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ScriptureConnectionLink: View {
    let reference: PassageReference
    let excerpt: String
    let pair: ScriptureCrossReference

    var body: some View {
        NavigationLink {
            ScriptureConnectionDetailView(pair: pair)
        } label: {
            ScriptureExcerpt(reference: reference, excerpt: excerpt)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens this Scripture connection")
    }
}

private struct ScriptureConnectionDetailView: View {
    let pair: ScriptureCrossReference

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeroCard(title: "Scripture Connection", icon: "arrow.triangle.branch") {
                    VStack(alignment: .leading, spacing: 16) {
                        ScriptureConnectionPassage(
                            reference: pair.source.reference,
                            excerpt: pair.source.excerpt
                        )

                        Image(systemName: "arrow.down")
                            .foregroundStyle(.tint)
                            .frame(maxWidth: .infinity)

                        ScriptureConnectionPassage(
                            reference: pair.target.reference,
                            excerpt: pair.target.excerpt
                        )

                        Divider()

                        ScriptureConnectionExplanation(text: pair.relationshipDescription)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .background(AppBackgroundView(tab: .bible))
        .navigationTitle("Scripture Connection")
        .navigationBarTitleDisplayMode(.inline)
        .scripturePassagePreviews()
    }
}

private struct ScriptureConnectionPassage: View {
    let reference: PassageReference
    let excerpt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(reference.displayTitle)
                .font(.headline)
                .foregroundStyle(.tint)

            Text("“\(excerpt)”")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ScriptureConnectionExplanation: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Relationship")
                .font(.subheadline.weight(.semibold))

            LinkedScriptureText(text)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ScriptureExcerpt: View {
    let reference: PassageReference
    let excerpt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(reference.displayTitle)
                .font(.subheadline.weight(.semibold))

            Text("“\(excerpt)”")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ScriptureCrossReference: Identifiable, Hashable {
    struct Source: Hashable {
        let verseNumber: Int
        let reference: PassageReference
        let excerpt: String
    }

    struct Target: Hashable {
        let reference: PassageReference
        let excerpt: String
    }

    let source: Source
    let target: Target
    let connectionExplanation: String?

    /// Prefers pair-specific editorial copy. The fallback remains careful not to
    /// invent a connection that is not represented in the source data.
    var relationshipDescription: String {
        ChapterCrossReferenceEditorialCatalog.relationshipDescription(
            bookName: source.reference.bookName,
            chapterNumber: source.reference.startChapter,
            sourceVerse: source.reference.startVerse ?? source.verseNumber,
            targetBookName: target.reference.bookName,
            targetChapterNumber: target.reference.startChapter,
            targetVerse: target.reference.startVerse ?? 0
        ) ?? connectionExplanation ?? defaultRelationshipDescription
    }

    private var defaultRelationshipDescription: String {
        switch target.reference.bookName {
        case "Genesis":
            "This connection follows the Genesis narrative, linking the same people, place, promise, or event at another point in the account."
        case "Exodus", "Numbers", "Deuteronomy", "Joshua", "Judges", "1 Samuel", "2 Samuel":
            "This later historical passage shows how a person, place, promise, or consequence from Genesis continues in Israel's story."
        case "1 Chronicles", "2 Chronicles":
            "This later historical record preserves the Genesis family line, place, or event and places it within Israel's history."
        case "Psalms", "Job", "Proverbs", "Ecclesiastes":
            "This poetic or wisdom passage reflects on an image, person, or theme introduced in Genesis and invites the two passages to be read together."
        case "Isaiah", "Jeremiah", "Ezekiel", "Hosea", "Micah", "Malachi", "Daniel":
            "This prophetic passage develops an image, place, person, or theological theme first introduced in Genesis."
        case "Matthew", "Mark", "Luke", "John", "Acts", "Romans", "1 Corinthians", "Galatians", "Ephesians", "Hebrews", "James", "1 Peter", "2 Peter", "1 John", "Jude", "Revelation":
            "This New Testament passage looks back to Genesis to interpret its people, promises, images, or themes in light of Christ and the gospel."
        default:
            "These passages are linked for a meaningful biblical connection. Read them together to see how the later passage echoes or develops the Genesis account."
        }
    }

    var id: String { "\(source.reference.id)-\(target.reference.id)" }
}

@MainActor
private enum ScriptureCrossReferenceLoader {
    static func load(
        bookName: String,
        chapterNumber: Int,
        relatedVerses: [ChapterRelatedVerse]
    ) async -> [ScriptureCrossReference] {
        let books = await BibleRepository.shared.loadAllBooks()

        return relatedVerses.flatMap { relatedVerse in
            let sourceReference = PassageReference(
                bookName: bookName,
                startChapter: chapterNumber,
                startVerse: relatedVerse.sourceVerse,
                endChapter: chapterNumber,
                endVerse: relatedVerse.sourceVerse
            )
            let source = ScriptureCrossReference.Source(
                verseNumber: relatedVerse.sourceVerse,
                reference: sourceReference,
                excerpt: excerpt(for: sourceReference, in: books)
            )

            return PassageReferenceParser.parseList(
                relatedVerse.relatedReference,
                book: bookName,
                chapter: chapterNumber
            ).map { reference in
                ScriptureCrossReference(
                    source: source,
                    target: ScriptureCrossReference.Target(
                        reference: reference,
                        excerpt: excerpt(for: reference, in: books)
                    ),
                    connectionExplanation: relatedVerse.connectionExplanation
                )
            }
        }
    }

    private static func excerpt(for reference: PassageReference, in books: [Book]) -> String {
        guard let book = books.first(where: { $0.name == reference.bookName }) else { return "Passage unavailable." }

        let verses = book.chapters
            .filter { $0.number >= reference.startChapter && $0.number <= reference.endChapter }
            .flatMap { chapter in
                chapter.verses.filter { verse in
                    guard let startVerse = reference.startVerse else { return true }
                    if chapter.number == reference.startChapter, verse.number < startVerse { return false }
                    if let endVerse = reference.endVerse,
                       chapter.number == reference.endChapter,
                       verse.number > endVerse {
                        return false
                    }
                    return true
                }
            }

        let text = verses.prefix(2).map(\.text).joined(separator: " ")
        guard !text.isEmpty else { return "Passage unavailable." }
        return text.count > 180 ? "\(text.prefix(177))…" : text
    }
}

private extension String {
    /// Splits off a closing citation such as " (Judges 4:17–24)." and returns the sentence
    /// without it, or nil when the sentence doesn't end in a reference.
    func trailingCitation(bookName: String, chapterNumber: Int) -> (text: String, reference: String)? {
        guard let match = firstMatch(of: #/\s*\(([^()]+)\)([.!?]?)["”’]?\s*$/#) else { return nil }
        let reference = String(match.1).trimmingCharacters(in: .whitespaces)
        guard !PassageReferenceParser.parseList(reference, book: bookName, chapter: chapterNumber).isEmpty else {
            return nil
        }
        let text = String(self[..<match.range.lowerBound]) + String(match.2)
        return (text, reference)
    }

    var paragraphs: [String] {
        components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var sentences: [String] {
        var results: [String] = []
        enumerateSubstrings(
            in: startIndex..<endIndex,
            options: [.bySentences, .substringNotRequired]
        ) { _, range, _, _ in
            let sentence = String(self[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                results.append(sentence)
            }
        }
        return results.isEmpty ? [self] : results
    }
}

#Preview {
    NavigationStack {
        ChapterInsightsView(bookName: "Genesis", chapterNumber: 1)
    }
}
