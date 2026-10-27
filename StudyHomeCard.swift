import Foundation
import SwiftUI

/// Home card that prepares the reader for the bookmarked or featured verse.
///
/// It places that verse first, followed by its chapter's brief summary. With no bookmark
/// or featured verse, Genesis 1 remains a book-level starting point. The full detail,
/// including key figures and themes, stays in `ChapterInsightsView`.
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
    let startVerseNumber: Int
    let verseText: String?
    let source: Source
    let onRead: () -> Void

    @State private var insights: ChapterInsights?
    @State private var overview: BibleBookOverview?
    @State private var bookStory: [BibleBookStorySection] = []
    @State private var isLoading = true
    @State private var isSummaryExpanded = false
    /// Heights of the summary at three lines and in full, to know whether it's cut off.
    @State private var collapsedSummaryHeight: CGFloat = 0
    @State private var fullSummaryHeight: CGFloat = 0

    /// Only a summary longer than three lines gets the More control.
    private var isSummaryTruncatable: Bool {
        fullSummaryHeight > collapsedSummaryHeight + 1
    }

    private var chapterReference: String { "\(bookName) \(chapterNumber)" }
    private var verseReference: String { "\(chapterReference):\(startVerseNumber)" }
    private var isVerseFocused: Bool { source != .startingPoint }
    private var cardTitle: String { "Study \(isVerseFocused ? verseReference : chapterReference)" }

    private var displayedVerseText: String? {
        guard let verseText = verseText?.trimmingCharacters(in: .whitespacesAndNewlines), !verseText.isEmpty else {
            return nil
        }
        return Self.removingSuppliedWordMarkers(verseText)
    }

    var body: some View {
        HeroCard(
            title: cardTitle,
            subtitle: source.label,
            icon: "text.book.closed",
            tint: .teal,
            trailingAccessory: {
                StudyBrowseButton {
                    Haptics.selection()
                    AppRouter.shared.open(.bibleStudy)
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if isVerseFocused, let displayedVerseText {
                    StudyVersePreview(reference: verseReference, text: displayedVerseText)
                }

                if isLoading {
                    loadingPlaceholder
                } else if let overview {
                    bookIntroduction(overview)
                } else if let insights {
                    chapterStudy(insights)
                } else {
                    Text("Study notes for \(chapterReference) aren't available yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    actionButtons(secondaryTitle: nil, secondaryAction: nil)
                }

                if chapterNumber == 1, !bookStory.isEmpty {
                    StudyBookStoryPrompt(bookName: bookName, story: bookStory)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // The book-introduction key verse opens a passage preview with Open in Bible.
        .scripturePassagePreviews()
        .task(id: chapterReference, load)
    }

    // MARK: - Chapter

    @ViewBuilder
    private func chapterStudy(_ insights: ChapterInsights) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("IN THIS CHAPTER")
            ChapterStudySummary(
                summary: insights.overallSummary,
                bookName: bookName,
                chapterNumber: chapterNumber,
                verseNumber: isVerseFocused ? startVerseNumber : nil
            )
        }

        actionButtons(secondaryTitle: "Insights", secondaryAction: openChapterInsights)
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
                sectionLabel("KEY VERSE")
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

        actionButtons(secondaryTitle: "About \(bookName)", secondaryAction: openBookOverview)
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

    private func actionButtons(
        secondaryTitle: LocalizedStringResource?,
        secondaryAction: (() -> Void)?
    ) -> some View {
        HStack(spacing: 10) {
            actionButtonContent(secondaryTitle, secondaryAction)
        }
    }

    @ViewBuilder
    private func actionButtonContent(
        _ secondaryTitle: LocalizedStringResource?,
        _ secondaryAction: (() -> Void)?
    ) -> some View {
        Button(action: onRead) {
            Label("Read verse \(startVerseNumber)", systemImage: "book.fill")
                .lineLimit(1)
        }
        .buttonStyle(.bordered)
        .tint(.teal)
        .frame(maxWidth: .infinity)

        if let secondaryTitle, let secondaryAction {
            Button(action: secondaryAction) {
                Label(secondaryTitle, systemImage: "text.book.closed")
                    .lineLimit(1)
            }
            .buttonStyle(.bordered)
            .tint(.teal)
            .frame(maxWidth: .infinity)
        }
    }

    private func openChapterInsights() {
        Haptics.selection()
        AppRouter.shared.open(
            .bibleStudyDestination(
                .chapterInsights(bookName: bookName, chapterNumber: chapterNumber)
            )
        )
    }

    private func openBookOverview() {
        Haptics.selection()
        AppRouter.shared.open(
            .bibleStudyDestination(.bookOverview(bookName: bookName))
        )
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
        bookStory = []

        // Only the no-history starting point introduces the book. A bookmark or featured
        // verse in chapter 1 still receives verse and chapter context.
        if source == .startingPoint, chapterNumber == 1 {
            overview = await BibleBookOverviewRepository.shared.overview(forBookNamed: bookName)
        }
        if chapterNumber == 1 {
            let storyOverview: BibleBookOverview?
            if let overview {
                storyOverview = overview
            } else {
                storyOverview = await BibleBookOverviewRepository.shared.overview(forBookNamed: bookName)
            }
            bookStory = storyOverview?.story ?? []
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

/// Invites someone studying a book's opening chapter to read its full narrative retelling.
private struct StudyBookStoryPrompt: View {
    let bookName: String
    let story: [BibleBookStorySection]

    var body: some View {
        NavigationLink {
            BookStoryView(bookName: bookName, story: story)
        } label: {
            Label(bookStoryPrompt, systemImage: "book.pages")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .tint(.teal)
        .accessibilityHint("Opens a narrative retelling of \(bookName)")
    }

    private var bookStoryPrompt: String {
        switch bookName {
        case "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah", "Esther", "Job", "Psalms", "Proverbs":
            "New to \(bookName)? Explore its guide."
        default:
            "New to \(bookName)? Read its story."
        }
    }
}

private struct StudyBrowseButton: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if horizontalSizeClass == .compact {
                Image(systemName: "rectangle.grid.2x2")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
            } else {
                Label("Browse", systemImage: "rectangle.grid.2x2")
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.teal)
        .accessibilityIdentifier("browseStudyButton")
        .accessibilityLabel("Browse Study")
    }
}

private struct StudyVersePreview: View {
    let reference: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            StudyCardSectionLabel(title: "VERSE")
            Text("“\(text)”")
                .font(.subheadline)
                .italic()
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Text(reference)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.teal)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct StudyCardSectionLabel: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.footnote.weight(.bold))
            .foregroundStyle(.primary)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct ChapterStudySummary: View {
    let summary: String
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int?

    private var sentences: [String] {
        summary.sentences
    }

    /// The Home card is an entry point, so it shows a compact preview; Insights has the full outline.
    private var preview: String {
        sentences.prefix(2).joined(separator: " ")
    }

    /// When the card is anchored to a verse, use the matching "What Happens" item
    /// rather than a generic opening preview of the chapter.
    private var matchingEvent: ChapterEvent? {
        guard let verseNumber,
              let events = ChapterEvent.outline(
                from: summary,
                bookName: bookName,
                chapterNumber: chapterNumber
              ) else {
            return nil
        }

        return events.first {
            $0.contains(
                bookName: bookName,
                chapterNumber: chapterNumber,
                verseNumber: verseNumber
            )
        }
    }

    var body: some View {
        SummaryBullet(text: matchingEvent?.text ?? preview, lineLimit: 3)
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
        StudyHomeCard(
            bookName: "John",
            chapterNumber: 3,
            startVerseNumber: 16,
            verseText: "For God so loved the world, that he gave his only begotten Son.",
            source: .bookmark,
            onRead: {}
        )
            .padding()
    }
}

#Preview("Starting a book") {
    ScrollView {
        StudyHomeCard(
            bookName: "Romans",
            chapterNumber: 1,
            startVerseNumber: 16,
            verseText: "For I am not ashamed of the gospel of Christ.",
            source: .verseOfDay(title: "Verse of the Day"),
            onRead: {}
        )
            .padding()
    }
}
