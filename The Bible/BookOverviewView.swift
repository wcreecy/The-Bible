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

                KeyScriptureSection(keyScripture: overview.keyScripture)
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
                    KeyEventsSection(bookName: bookName, movements: overview.movements)
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
        .scripturePassagePreviews()
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
            LinkedScriptureText(content)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
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
            icon: "calendar"
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

#Preview {
    NavigationStack {
        BookOverviewView(bookName: "Genesis")
    }
}
