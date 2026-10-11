import SwiftUI

/// Home card that prepares the reader for the chapter they're about to read.
///
/// Shows the chapter's summary, key themes (linked to their verses) and key figures,
/// with Read and Insights actions. At chapter 1 it introduces the book instead,
/// using the book overview. Only the insight fields that are written for every chapter
/// are shown here; the full detail stays in `ChapterInsightsView`.
struct StudyHomeCard: View {
    let bookName: String
    let chapterNumber: Int
    let onRead: () -> Void

    private enum Sheet: String, Identifiable {
        case chapterInsights, bookOverview
        var id: String { rawValue }
    }

    /// The card shows at most this many themes; the rest are in Chapter Insights.
    private static let maximumThemes = 3

    @State private var insights: ChapterInsights?
    @State private var overview: BibleBookOverview?
    @State private var isLoading = true
    @State private var isSummaryExpanded = false
    @State private var presentedSheet: Sheet?

    private var reference: String { "\(bookName) \(chapterNumber)" }

    var body: some View {
        HeroCard(
            title: "Study",
            subtitle: overview != nil ? "Starting \(bookName)" : reference,
            icon: "text.book.closed",
            tint: .teal
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if isLoading {
                    loadingPlaceholder
                } else if let overview {
                    bookIntroduction(overview)
                } else if let insights {
                    chapterStudy(insights)
                } else {
                    Text("Study notes for \(reference) aren't available yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    actionButtons(secondaryTitle: nil, secondarySheet: nil)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Theme and key-verse links open a passage preview with Open in Bible.
        .scripturePassagePreviews()
        .task(id: reference, load)
        .sheet(item: $presentedSheet) { sheet in
            NavigationStack {
                Group {
                    switch sheet {
                    case .chapterInsights:
                        ChapterInsightsView(bookName: bookName, chapterNumber: chapterNumber)
                    case .bookOverview:
                        BookOverviewView(bookName: bookName)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { presentedSheet = nil }
                    }
                }
            }
        }
    }

    // MARK: - Chapter

    @ViewBuilder
    private func chapterStudy(_ insights: ChapterInsights) -> some View {
        expandableText(insights.overallSummary)

        let themes = insights.keyThemes.prefix(Self.maximumThemes)
        if !themes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Themes")
                ForEach(themes) { theme in
                    themeChip(theme)
                }
            }
        }

        if !insights.keyFigures.isEmpty {
            Label {
                Text(insights.keyFigures.map(\.name).joined(separator: " · "))
                    .lineLimit(2)
            } icon: {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(.teal)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Key figures: \(insights.keyFigures.map(\.name).formatted(.list(type: .and)))")
        }

        actionButtons(secondaryTitle: "Insights", secondarySheet: .chapterInsights)
    }

    /// A theme name with its verse span; opens a preview of those verses when it has one.
    @ViewBuilder
    private func themeChip(_ theme: ChapterKeyTheme) -> some View {
        let passage = theme.scriptureReferences
            .lazy
            .flatMap { PassageReferenceParser.parseList($0, book: bookName, chapter: chapterNumber) }
            .first

        let label = HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(theme.theme)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            if let passage {
                Text(shortTitle(for: passage))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.teal)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.teal.opacity(0.12), in: Capsule())

        if let passage {
            Link(destination: passage.url) { label }
                // Keeps the label's own colors instead of tinting the whole chip.
                .buttonStyle(.plain)
                .accessibilityLabel("\(theme.theme), \(passage.displayTitle)")
                .accessibilityHint("Shows a preview of the passage")
        } else {
            label
        }
    }

    /// Drops the book name the card already shows, so "John 3:3–8" reads "3:3–8".
    private func shortTitle(for passage: PassageReference) -> String {
        let title = passage.displayTitle
        let prefix = "\(passage.bookName) "
        return title.hasPrefix(prefix) ? String(title.dropFirst(prefix.count)) : title
    }

    // MARK: - Book introduction

    @ViewBuilder
    private func bookIntroduction(_ overview: BibleBookOverview) -> some View {
        expandableText(overview.overallTheme)

        if !overview.traditionalAuthorOrAttribution.isEmpty {
            Label {
                Text(overview.traditionalAuthorOrAttribution)
            } icon: {
                Image(systemName: "pencil.line")
                    .foregroundStyle(.teal)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Author: \(overview.traditionalAuthorOrAttribution)")
        }

        if !overview.keyScripture.text.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionLabel("Key Verse")
                if let passage = PassageReferenceParser.parse(overview.keyScripture.reference) {
                    Link(destination: passage.url) {
                        Label(passage.displayTitle, systemImage: "book")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.teal)
                    }
                    .accessibilityHint("Shows a preview of the passage")
                } else {
                    Text(overview.keyScripture.reference)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.teal)
                }
                Text("“\(Self.removingSuppliedWordMarkers(overview.keyScripture.text))”")
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }

        actionButtons(secondaryTitle: "About \(bookName)", secondarySheet: .bookOverview)
    }

    /// The KJV marks translator-supplied words with braces, e.g. "{his}".
    private static func removingSuppliedWordMarkers(_ text: String) -> String {
        text.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
    }

    // MARK: - Shared pieces

    /// Three lines by default; tapping shows the rest.
    private func expandableText(_ text: String) -> some View {
        Button {
            withAnimation(.snappy) { isSummaryExpanded.toggle() }
        } label: {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(isSummaryExpanded ? nil : 3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(isSummaryExpanded ? "Shows less" : "Shows the full text")
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .accessibilityAddTraits(.isHeader)
    }

    private func actionButtons(secondaryTitle: String?, secondarySheet: Sheet?) -> some View {
        // Side by side when they fit; stacked at large text sizes.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { actionButtonContent(secondaryTitle, secondarySheet) }
            VStack(alignment: .leading, spacing: 10) { actionButtonContent(secondaryTitle, secondarySheet) }
        }
    }

    @ViewBuilder
    private func actionButtonContent(_ secondaryTitle: String?, _ secondarySheet: Sheet?) -> some View {
        Button(action: onRead) {
            Label("Read \(reference)", systemImage: "book.fill")
                .lineLimit(1)
        }
        .buttonStyle(.borderedProminent)
        .tint(.teal)

        if let secondaryTitle, let secondarySheet {
            Button {
                Haptics.selection()
                presentedSheet = secondarySheet
            } label: {
                Label(secondaryTitle, systemImage: "text.book.closed")
                    .lineLimit(1)
            }
            .buttonStyle(.bordered)
            .tint(.teal)
        }
    }

    private var loadingPlaceholder: some View {
        Text("Loading a summary of this chapter, with its key themes and the people in it.")
            .font(.subheadline)
            .redacted(reason: .placeholder)
            .accessibilityLabel("Loading study notes")
    }

    // MARK: - Loading

    private func load() async {
        isLoading = true
        isSummaryExpanded = false
        overview = nil
        insights = nil

        // Chapter 1 introduces the book; fall back to chapter insights if there's no overview.
        if chapterNumber == 1 {
            overview = await BibleBookOverviewRepository.shared.overview(forBookNamed: bookName)
        }
        if overview == nil {
            insights = await ChapterInsightsRepository.shared.insights(
                forBookNamed: bookName,
                chapterNumber: chapterNumber
            )
        }
        isLoading = false
    }
}

#Preview("Chapter") {
    ScrollView {
        StudyHomeCard(bookName: "John", chapterNumber: 3, onRead: {})
            .padding()
    }
}

#Preview("Starting a book") {
    ScrollView {
        StudyHomeCard(bookName: "Romans", chapterNumber: 1, onRead: {})
            .padding()
    }
}
