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

                if !insights.relatedVerses.isEmpty {
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
