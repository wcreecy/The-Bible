import Foundation
import SwiftUI

/// Home card that prepares the reader for the chapter they're about to read.
///
/// Shows the chapter's summary, key themes (linked to their verses) and key figures,
/// with Read and Insights actions. At chapter 1 it introduces the book instead,
/// using the book overview. Only the insight fields that are written for every chapter
/// are shown here; the full detail stays in `ChapterInsightsView`.
struct StudyHomeCard: View {
    /// Why the card is showing this chapter; named in the subtitle so the choice isn't a mystery.
    enum Source: Equatable {
        case bookmark
        /// `title` is the Verse of the Day card's current title, so the two read the same.
        case verseOfDay(title: String)
        case startingPoint

        var label: String {
            switch self {
            case .bookmark: "From your bookmark"
            case .verseOfDay(let title): "From \(title)"
            case .startingPoint: "Start here"
            }
        }
    }

    let bookName: String
    let chapterNumber: Int
    let source: Source
    let onRead: () -> Void

    private enum Sheet: String, Identifiable {
        case chapterInsights
        case bookOverview

        var id: String { rawValue }
    }

    /// The card shows at most this many themes; the rest are in Chapter Insights.
    private static let maximumThemes = 3

    @State private var insights: ChapterInsights?
    @State private var overview: BibleBookOverview?
    @State private var isLoading = true
    @State private var isSummaryExpanded = false
    /// Heights of the summary at three lines and in full, to know whether it's cut off.
    @State private var collapsedSummaryHeight: CGFloat = 0
    @State private var fullSummaryHeight: CGFloat = 0
    @State private var presentedSheet: Sheet?

    /// Only a summary longer than three lines gets the More control.
    private var isSummaryTruncatable: Bool {
        fullSummaryHeight > collapsedSummaryHeight + 1
    }

    private var reference: String { "\(bookName) \(chapterNumber)" }

    var body: some View {
        HeroCard(
            title: "Study \(reference)",
            subtitle: source.label,
            icon: "text.book.closed",
            tint: .teal,
            trailingAccessory: {
                Button {
                    Haptics.selection()
                    AppRouter.shared.open(.bibleStudy)
                } label: {
                    Image(systemName: "rectangle.grid.2x2")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.teal)
                .frame(width: 44, height: 44)
                .accessibilityIdentifier("browseStudyButton")
                .accessibilityLabel("Browse Study")
            }
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
            .environment(\.closeStudySheet) { presentedSheet = nil }
        }
    }

    // MARK: - Chapter

    @ViewBuilder
    private func chapterStudy(_ insights: ChapterInsights) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("IN BRIEF")
            ChapterStudySummary(summary: insights.overallSummary)
        }

        if let figure = insights.keyFigures.first {
            KeyFigurePreview(figure: figure)
        }

        let themes = insights.keyThemes.prefix(Self.maximumThemes)
        if !themes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("THEMES")
                ForEach(themes) { theme in
                    themeChip(theme)
                }
            }
        }

        actionButtons(secondaryTitle: "Chapter Insights", secondarySheet: .chapterInsights)
    }

    /// A full-width theme row that opens a preview of its first linked passage.
    private func themeChip(_ theme: ChapterKeyTheme) -> some View {
        let passage = theme.scriptureReferences
            .lazy
            .flatMap { PassageReferenceParser.parseList($0, book: bookName, chapter: chapterNumber) }
            .first

        return StudyThemeRow(
            title: theme.theme,
            passage: passage,
            passageTitle: passage.map(shortTitle(for:))
        )
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
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("IN BRIEF")
            expandableText(overview.overallTheme)
        }

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

    /// Three lines by default, with a More control when there's more to show.
    @ViewBuilder
    private func expandableText(_ text: String) -> some View {
        let showsToggle = isSummaryTruncatable || isSummaryExpanded

        if showsToggle {
            Button {
                withAnimation(.snappy) { isSummaryExpanded.toggle() }
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    measuredSummary(text)

                    Label(
                        isSummaryExpanded ? "Less" : "More",
                        systemImage: isSummaryExpanded ? "chevron.up" : "chevron.down"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.teal)
                    // The button's hint already says what tapping does.
                    .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(isSummaryExpanded ? "Shows less" : "Shows the full text")
        } else {
            measuredSummary(text)
        }
    }

    /// The summary, measured at three lines and at full length at the same width,
    /// so the More control appears only when text is actually cut off.
    private func measuredSummary(_ text: String) -> some View {
        let summary = Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)

        return summary
            .lineLimit(isSummaryExpanded ? nil : 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                if !isSummaryExpanded { collapsedSummaryHeight = height }
            }
            .background {
                summary
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .hidden()
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { fullSummaryHeight = $0 }
            }
    }

    private func sectionLabel(_ title: LocalizedStringKey) -> some View {
        StudyCardSectionLabel(title: title)
    }

    private func actionButtons(secondaryTitle: String?, secondarySheet: Sheet?) -> some View {
        HStack(spacing: 10) {
            actionButtonContent(secondaryTitle, secondarySheet)
        }
    }

    @ViewBuilder
    private func actionButtonContent(_ secondaryTitle: String?, _ secondarySheet: Sheet?) -> some View {
        Button(action: onRead) {
            Label("Read", systemImage: "book.fill")
                .lineLimit(1)
        }
        .buttonStyle(.bordered)
        .tint(.teal)
        .frame(maxWidth: .infinity)

        if secondaryTitle != nil, let secondarySheet {
            Button {
                Haptics.selection()
                presentedSheet = secondarySheet
            } label: {
                Label("Insights", systemImage: "text.book.closed")
                    .lineLimit(1)
            }
            .buttonStyle(.bordered)
            .tint(.teal)
            .frame(maxWidth: .infinity)
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
        collapsedSummaryHeight = 0
        fullSummaryHeight = 0
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

private struct KeyFigurePreview: View {
    let figure: ChapterKeyFigure

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            StudyCardSectionLabel(title: "KEY FIGURE")
            Label(figure.name, systemImage: "person.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(figure.roleAndSignificance)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct StudyThemeRow: View {
    let title: String
    let passage: PassageReference?
    let passageTitle: String?

    var body: some View {
        if let passage, let passageTitle {
            Link(destination: passage.url) {
                rowContent(passageTitle: passageTitle)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityLabel("\(title), \(passage.displayTitle)")
            .accessibilityHint("Shows a preview of the passage")
        } else {
            rowContent(passageTitle: nil)
        }
    }

    private func rowContent(passageTitle: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•")
                .font(.subheadline)
                .foregroundStyle(.teal)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            if let passageTitle {
                Text(passageTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.teal)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.teal.opacity(0.12), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct StudyCardSectionLabel: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.footnote.weight(.bold))
            .foregroundStyle(.primary)
            .textCase(.uppercase)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct ChapterStudySummary: View {
    let summary: String

    @State private var showsFullSummary = false
    @State private var collapsedSummaryHeight: CGFloat = 0
    @State private var fullSummaryHeight: CGFloat = 0

    private var sentences: [String] {
        summary.sentences
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsFullSummary, summary.count > 650 {
                ForEach(Array(sentences.enumerated()), id: \.offset) { _, sentence in
                    SummaryBullet(text: sentence)
                }
            } else {
                SummaryBullet(text: summary, lineLimit: showsFullSummary ? nil : 3)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                        if !showsFullSummary {
                            collapsedSummaryHeight = height
                        }
                    }
                    .background {
                        SummaryBullet(text: summary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .hidden()
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                                fullSummaryHeight = height
                            }
                    }
            }

            if fullSummaryHeight > collapsedSummaryHeight + 1 || showsFullSummary {
                Button {
                    withAnimation(.snappy) {
                        showsFullSummary.toggle()
                    }
                } label: {
                    Label(
                        showsFullSummary ? "Less" : "More",
                        systemImage: showsFullSummary ? "chevron.up" : "chevron.down"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.teal)
                }
                .buttonStyle(.plain)
                .accessibilityHint(showsFullSummary ? "Shows a three-line summary preview" : "Shows all summary points")
            }
        }
    }
}

private struct SummaryBullet: View {
    let text: String
    var lineLimit: Int?

    init(text: String, lineLimit: Int? = nil) {
        self.text = text
        self.lineLimit = lineLimit
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 5))
                .foregroundStyle(.teal)
                .padding(.top, 6)

            LinkedScriptureText(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(lineLimit)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private extension String {
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

#Preview("Chapter") {
    ScrollView {
        StudyHomeCard(bookName: "John", chapterNumber: 3, source: .bookmark, onRead: {})
            .padding()
    }
}

#Preview("Starting a book") {
    ScrollView {
        StudyHomeCard(bookName: "Romans", chapterNumber: 1, source: .verseOfDay(title: "Verse of the Day"), onRead: {})
            .padding()
    }
}
