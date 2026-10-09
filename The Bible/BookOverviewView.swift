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
                OverviewHeroCard(
                    title: "Book Summary",
                    icon: "book.closed",
                    content: overview.plainEnglishSummary
                )

                OverviewHeroCard(
                    title: "Theme",
                    icon: "sparkles",
                    content: overview.overallTheme
                )
                OverviewHeroCard(
                    title: "Purpose",
                    icon: "target",
                    content: overview.purpose
                )
                OverviewHeroCard(
                    title: "Author",
                    icon: "person.fill",
                    content: overview.traditionalAuthorOrAttribution
                )
                OverviewHeroCard(
                    title: "Original Audience",
                    icon: "person.2.fill",
                    content: overview.originalAudience
                )
                OverviewHeroCard(
                    title: "Historical Context",
                    icon: "calendar",
                    content: overview.historicalContext
                )

                if !overview.movements.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Book Movements")
                            .font(.title3.weight(.semibold))

                        ForEach(overview.movements) { movement in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(movement.title)
                                    .font(.headline)
                                Text(movement.description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                if !movement.keyPassages.isEmpty {
                                    Text(movement.keyPassages.formatted(.list(type: .and)))
                                        .font(.caption)
                                        .foregroundStyle(.tint)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(AppDesignMetrics.cardPadding)
                            .heroCardSurface()
                        }
                    }
                }

                if !overview.keyFigures.isEmpty {
                    KeyFiguresSection(keyFigures: overview.keyFigures)
                }

                if !overview.interpretiveNotes.isEmpty {
                    OverviewHeroCard(
                        title: "Interpretive Notes",
                        icon: "text.book.closed",
                        content: overview.interpretiveNotes
                    )
                }
            }
            .padding()
        }
        .background(AppBackgroundView(tab: .bible))
    }

    private func loadOverview() async {
        isLoading = true
        overview = await BibleBookOverviewRepository.shared.overview(forBookNamed: bookName)
        isLoading = false
    }
}

private struct OverviewHeroCard: View {
    let title: String
    let icon: String
    let content: String

    var body: some View {
        HeroCard(
            title: title,
            icon: icon
        ) {
            Text(content)
                .font(.body)
                .foregroundStyle(.secondary)
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
                        Text(figure.description)
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

#Preview {
    NavigationStack {
        BookOverviewView(bookName: "Genesis")
    }
}
