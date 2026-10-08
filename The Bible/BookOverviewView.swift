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
                Text(overview.plainEnglishSummary)
                    .font(.body)

                OverviewDetailSection(title: "Theme", content: overview.overallTheme)
                OverviewDetailSection(title: "Purpose", content: overview.purpose)
                OverviewDetailSection(
                    title: "Author or Attribution",
                    content: overview.traditionalAuthorOrAttribution
                )
                OverviewDetailSection(title: "Original Audience", content: overview.originalAudience)
                OverviewDetailSection(title: "Historical Context", content: overview.historicalContext)

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

                if !overview.interpretiveNotes.isEmpty {
                    OverviewDetailSection(
                        title: "Interpretive Notes",
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

private struct OverviewDetailSection: View {
    let title: LocalizedStringKey
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(content)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        BookOverviewView(bookName: "Genesis")
    }
}
