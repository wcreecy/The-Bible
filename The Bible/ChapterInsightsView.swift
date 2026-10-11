import Foundation
import SwiftUI

struct ChapterInsightsView: View {
    let bookName: String
    let chapterNumber: Int

    @State private var insights: ChapterInsights?
    @State private var isLoading = true

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
                                LinkedScriptureText(theme.explanation)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

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

                ChapterInsightCard(title: "Historical Setting", icon: "calendar", content: insights.historicalSetting)
                ChapterInsightBulletList(
                    title: "What Was Happening",
                    icon: "clock.arrow.circlepath",
                    content: insights.whatWasHappening
                )
                ChapterInsightCard(title: "Connection to the Chapter", icon: "link", content: insights.connectionToChapter)
                ChapterInsightBulletList(
                    title: "Customs and Traditions",
                    icon: "scroll",
                    content: insights.customsAndTraditions
                )
                ChapterInsightCard(title: "Why It Matters", icon: "heart.text.square", content: insights.whyItMatters)
            }
            .padding()
        }
        .background(AppBackgroundView(tab: .bible))
        .scripturePassagePreviews()
    }

    private func loadInsights() async {
        isLoading = true
        insights = await ChapterInsightsRepository.shared.insights(
            forBookNamed: bookName,
            chapterNumber: chapterNumber
        )
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

private struct ChapterInsightCard: View {
    let title: String
    let icon: String
    let content: String

    var body: some View {
        HeroCard(title: title, icon: icon) {
            LinkedScriptureText(content)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ChapterInsightBulletList: View {
    let title: String
    let icon: String
    let content: String

    private var items: [String] {
        content.paragraphs
    }

    var body: some View {
        HeroCard(title: title, icon: icon) {
            if items.count > 1 {
                ChapterInsightBullets(items: items)
            } else {
                LinkedScriptureText(content)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
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
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppDesignMetrics.cardPadding)
            .heroCardSurface()
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
