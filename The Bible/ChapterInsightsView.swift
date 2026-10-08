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
                ChapterInsightCard(
                    title: insights.reference,
                    icon: "text.book.closed",
                    content: insights.overallSummary
                )

                if !insights.keyThemes.isEmpty {
                    ChapterInsightList(title: "Key Themes", icon: "sparkles") {
                        ForEach(insights.keyThemes) { theme in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(theme.theme)
                                    .font(.headline)
                                Text(theme.explanation)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                if !theme.scriptureReferences.isEmpty {
                                    Text(theme.scriptureReferences.formatted(.list(type: .and)))
                                        .font(.caption)
                                        .foregroundStyle(.tint)
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
                                Text(figure.roleAndSignificance)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                ChapterInsightCard(title: "Historical Setting", icon: "calendar", content: insights.historicalSetting)
                ChapterInsightCard(title: "What Was Happening", icon: "clock.arrow.circlepath", content: insights.whatWasHappening)
                ChapterInsightCard(title: "Connection to the Chapter", icon: "link", content: insights.connectionToChapter)
                ChapterInsightCard(title: "Customs and Traditions", icon: "scroll", content: insights.customsAndTraditions)
                ChapterInsightCard(title: "Why It Matters", icon: "heart.text.square", content: insights.whyItMatters)
            }
            .padding()
        }
        .background(AppBackgroundView(tab: .bible))
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

private struct ChapterInsightCard: View {
    let title: String
    let icon: String
    let content: String

    var body: some View {
        HeroCard(title: title, icon: icon) {
            Text(content)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
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

#Preview {
    NavigationStack {
        ChapterInsightsView(bookName: "Genesis", chapterNumber: 1)
    }
}
