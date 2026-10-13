import Foundation
import SwiftUI

struct ChapterInsightsView: View {
    let bookName: String
    let chapterNumber: Int

    @State private var insights: ChapterInsights?
    @State private var isLoading = true
    /// The chapter `insights` was loaded for; returning from a pushed page shouldn't reload.
    @State private var loadedChapterKey: String?

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
                    description: Text("Insights for \(bookName) \(chapterNumber) have not been added yet.")
                )
            }
        }
        .navigationTitle("Chapter Insights")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(bookName)-\(chapterNumber)", loadInsights)
    }

    private func insightsContent(_ insights: ChapterInsights) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ChapterSummaryCard(
                    title: insights.reference,
                    summary: insights.overallSummary
                )

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

                if bookName == "Genesis", chapterNumber == 1, !insights.relatedVerses.isEmpty {
                    ChapterCrossReferencesPreview(
                        bookName: bookName,
                        chapterNumber: chapterNumber,
                        relatedVerses: insights.relatedVerses
                    )
                } else if !insights.relatedVerses.isEmpty {
                    ChapterInsightList(title: "Related Verses", icon: "arrow.triangle.branch") {
                        ForEach(relatedVerseGroups(insights.relatedVerses), id: \.verse) { group in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(bookName) \(chapterNumber):\(group.verse)")
                                    .font(.headline)
                                PassageReferenceChips(
                                    references: group.references,
                                    book: bookName,
                                    chapter: chapterNumber
                                )
                            }
                        }
                    }
                }

                if !insights.keyFigures.isEmpty {
                    ChapterInsightList(title: "Key Figures", icon: "person.2.fill") {
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

                ChapterBackgroundSection(insights: insights)

                AboutBookLink(bookName: bookName)
            }
            .padding()
        }
        .background(AppBackgroundView(tab: .bible))
        .environment(\.scriptureContextBook, bookName)
        .scripturePassagePreviews()
    }

    /// Groups related references under the chapter verse they relate to, in verse order.
    private func relatedVerseGroups(_ relatedVerses: [ChapterRelatedVerse]) -> [(verse: Int, references: [String])] {
        Dictionary(grouping: relatedVerses, by: \.sourceVerse)
            .sorted { $0.key < $1.key }
            .map { (verse: $0.key, references: $0.value.map(\.relatedReference)) }
    }

    private func loadInsights() async {
        let key = "\(bookName)-\(chapterNumber)"
        guard loadedChapterKey != key else { return }
        isLoading = true
        insights = await ChapterInsightsRepository.shared.insights(
            forBookNamed: bookName,
            chapterNumber: chapterNumber
        )
        loadedChapterKey = key
        isLoading = false
    }
}

private struct ChapterSummaryCard: View {
    let title: String
    let summary: String

    @State private var showsFullSummary = false

    private var sentences: [String] {
        summary.sentences
    }

    private var displayedSentences: [String] {
        guard summary.count > 650, !showsFullSummary else { return sentences }
        return Array(sentences.prefix(5))
    }

    var body: some View {
        HeroCard(title: title, icon: "text.book.closed") {
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

/// The chapter's own historical background in one card. Background that applies to the
/// whole book lives on the book overview instead, so many chapters show only a few entries.
private struct ChapterBackgroundSection: View {
    let insights: ChapterInsights

    private struct Row: Identifiable {
        let title: String
        let icon: String
        let content: String
        /// Multi-paragraph content reads better as a bulleted list.
        var isBulleted = false
        var id: String { title }
    }

    private var rows: [Row] {
        [
            Row(title: "Setting", icon: "calendar", content: insights.historicalSetting),
            Row(title: "What Was Happening", icon: "clock.arrow.circlepath", content: insights.whatWasHappening, isBulleted: true),
            Row(title: "Connection to the Chapter", icon: "link", content: insights.connectionToChapter),
            Row(title: "Customs and Traditions", icon: "scroll", content: insights.customsAndTraditions, isBulleted: true),
            Row(title: "Why It Matters", icon: "heart.text.square", content: insights.whyItMatters)
        ]
        .filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        if !rows.isEmpty {
            HeroCard(title: "Background", icon: "building.columns") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(rows) { row in
                        VStack(alignment: .leading, spacing: 6) {
                            Label(row.title, systemImage: row.icon)
                                .font(.headline)

                            if row.isBulleted, row.content.paragraphs.count > 1 {
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
            }
        }
    }
}

/// Opens the book overview, where the book's history and full story are kept.
private struct AboutBookLink: View {
    let bookName: String

    var body: some View {
        NavigationLink {
            BookOverviewView(bookName: bookName)
                .studySheetDoneButton()
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

/// A Genesis 1-only prototype for presenting cross-references as comparable Scripture passages.
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
        HStack(alignment: .top, spacing: 10) {
            if showsSource {
                ScriptureExcerpt(reference: pair.source.reference, excerpt: pair.source.excerpt)
            }

            Image(systemName: "arrow.left.and.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
                .padding(.top, 4)

            ScriptureExcerpt(reference: pair.target.reference, excerpt: pair.target.excerpt)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ScriptureExcerpt: View {
    let reference: PassageReference
    let excerpt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Link(destination: reference.url) {
                Text(reference.displayTitle)
                    .font(.subheadline.weight(.semibold))
            }
            .accessibilityHint("Shows a preview of the passage")

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
                    )
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
