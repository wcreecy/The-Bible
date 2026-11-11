import Foundation
import SwiftUI

/// Some imported text repeats another field word for word (the summary).
/// This keeps only text the page doesn't already show, so each piece appears once.
struct ChapterContentFilter {
    let narrativePlacement: String
    let backgroundRows: [ChapterBackgroundSection.Row]

    init(insights: ChapterInsights, context: ChapterReadingContext?) {
        var shown = Set<String>()
        func claim(_ text: String) -> String {
            let key = Self.normalized(text)
            guard !key.isEmpty, shown.insert(key).inserted else { return "" }
            return text
        }

        _ = claim(insights.overallSummary)
        narrativePlacement = claim(context?.narrativePlacement ?? "")

        var rows: [ChapterBackgroundSection.Row] = []
        let moment = claim(context?.firstCenturyMoment ?? "")
        if !moment.isEmpty {
            rows.append(.init(title: "The Historical Moment", icon: "calendar", content: moment))
        }
        let audience = claim(context?.originalAudience ?? "")
        if !audience.isEmpty {
            rows.append(.init(title: "The Original Audience", icon: "person.3.fill", content: audience))
        }
        for lens in context?.culturalLenses ?? [] {
            let text = claim(lens.then)
            guard !text.isEmpty else { continue }
            rows.append(.init(title: lens.title, icon: "scroll", reference: lens.reference, content: text))
        }
        backgroundRows = rows
    }

    private static func normalized(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " .!?"))
    }
}

/// Where the chapter falls in the book's story. The text itself recalls the chapter before,
/// so the link to it sits with the other chapter navigation at the bottom of the page.
struct WhereWeAreSection: View {
    let narrativePlacement: String

    var body: some View {
        if !narrativePlacement.isEmpty {
            HeroCard(title: "Where We Are", icon: "mappin.and.ellipse") {
                LinkedScriptureText(narrativePlacement)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// The chapter's events as a numbered outline when the summary cites verse ranges, otherwise the summary itself.
struct ChapterSummaryCard: View {
    let bookName: String
    let chapterNumber: Int
    let summary: String

    @State private var showsFullSummary = false

    private var events: [ChapterEvent]? {
        ChapterEvent.outline(from: summary, bookName: bookName, chapterNumber: chapterNumber)
    }

    private var sentences: [String] {
        summary.sentences
    }

    private var displayedSentences: [String] {
        guard summary.count > 650, !showsFullSummary else { return sentences }
        return Array(sentences.prefix(5))
    }

    var body: some View {
        if let events {
            HeroCard(title: "What Happens", icon: "list.number") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(events) { event in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(event.id + 1, format: .number)
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.tint)
                                .frame(minWidth: 18, alignment: .trailing)

                            VStack(alignment: .leading, spacing: 6) {
                                LinkedScriptureText(event.text)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if let reference = event.reference {
                                    PassageReferenceChips(
                                        references: [reference],
                                        book: bookName,
                                        chapter: chapterNumber
                                    )
                                }
                            }
                        }

                        if event.id != events.last?.id {
                            Divider()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            HeroCard(title: "Summary", icon: "text.book.closed") {
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
}

/// One step in a chapter's outline, ending at a sentence that cites its verses.
struct ChapterEvent: Identifiable {
    let id: Int
    var text: String
    let reference: String?

    /// Builds an outline from summary sentences ending in a citation, such as
    /// "Sisera flees into Jael's tent, where Jael kills him (Judges 4:17–24)."
    /// Returns nil when fewer than two sentences cite their verses.
    static func outline(from summary: String, bookName: String, chapterNumber: Int) -> [ChapterEvent]? {
        var events: [ChapterEvent] = []
        var pending: [String] = []

        for sentence in summary.sentences {
            if let citation = sentence.trailingCitation(bookName: bookName, chapterNumber: chapterNumber) {
                pending.append(citation.text)
                events.append(ChapterEvent(id: events.count, text: pending.joined(separator: " "), reference: citation.reference))
                pending = []
            } else {
                pending.append(sentence)
            }
        }

        guard events.count >= 2 else { return nil }
        // Closing sentences without a citation belong with the last event.
        if !pending.isEmpty {
            events[events.count - 1].text += " " + pending.joined(separator: " ")
        }
        return events
    }

    /// Whether this outline item cites the supplied verse, including chapter-wide and
    /// multi-chapter citations such as "Numbers 2" or "Numbers 2:3–3:1".
    func contains(bookName: String, chapterNumber: Int, verseNumber: Int) -> Bool {
        guard let reference else { return false }

        return PassageReferenceParser.parseList(reference, book: bookName, chapter: chapterNumber).contains { passage in
            guard passage.bookName == bookName,
                  passage.startChapter <= chapterNumber,
                  chapterNumber <= passage.endChapter else {
                return false
            }

            let firstVerse = passage.startChapter == chapterNumber ? passage.startVerse ?? 1 : 1
            let lastVerse = passage.endChapter == chapterNumber ? passage.endVerse ?? .max : .max
            return (firstVerse...lastVerse).contains(verseNumber)
        }
    }
}

/// The chapter's own background: its historical moment, audience, and customs, without
/// repeating anything shown elsewhere on the page.
struct ChapterBackgroundSection: View {
    struct Row: Identifiable {
        let title: String
        let icon: String
        var reference = ""
        let content: String
        var id: String { title + reference }
    }

    let rows: [Row]

    var body: some View {
        if !rows.isEmpty {
            HeroCard(title: "Historical & Cultural Background", icon: "building.columns") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(rows) { row in
                        VStack(alignment: .leading, spacing: 6) {
                            Label(row.title, systemImage: row.icon)
                                .font(.headline)

                            if !row.reference.isEmpty {
                                LinkedScriptureText(row.reference)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.tint)
                            }

                            if row.content.paragraphs.count > 1 {
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
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// Opens the chapter in the reader, previews the chapters before and after, and links to the book overview.
struct ChapterNavigationSection: View {
    let location: ChapterLocation
    let previous: ChapterLocation?
    let previousSummary: String?
    let next: ChapterLocation?
    let nextSummary: String?
    let onSelect: (ChapterLocation) -> Void
    let onRead: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: onRead) {
                Label("Read \(location.title)", systemImage: "book.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Opens this chapter in the reader")

            if previous != nil || next != nil {
                VStack(alignment: .leading, spacing: 12) {
                    if let next {
                        NeighborChapterLink(
                            label: "Up Next",
                            location: next,
                            summary: nextSummary,
                            icon: "chevron.right",
                            action: { onSelect(next) }
                        )
                    }
                    if let previous {
                        if next != nil {
                            Divider()
                        }
                        NeighborChapterLink(
                            label: "Previous",
                            location: previous,
                            summary: previousSummary,
                            icon: "chevron.left",
                            action: { onSelect(previous) }
                        )
                    }
                }
                .padding(AppDesignMetrics.cardPadding)
                .heroCardSurface()
            }

            AboutBookLink(bookName: location.bookName)
        }
    }
}

/// A link to the chapter before or after, previewed by the opening of its summary.
struct NeighborChapterLink: View {
    let label: String
    let location: ChapterLocation
    let summary: String?
    let icon: String
    let action: () -> Void

    private var opening: String? {
        guard let summary else { return nil }
        let first = summary.sentences.first ?? summary
        return first.trailingCitation(bookName: location.bookName, chapterNumber: location.chapterNumber)?.text ?? first
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(label): \(location.title)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                    if let opening {
                        Text(opening)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows insights for \(location.title)")
    }
}

/// Opens the book overview, where the book's history and full story are kept.
struct AboutBookLink: View {
    let bookName: String

    var body: some View {
        NavigationLink {
            BookOverviewView(bookName: bookName)
                .studySheetDoneButton(placement: .topBarTrailing)
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

struct ChapterInsightBullets: View {
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

struct ChapterInsightList<Content: View>: View {
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
    /// Splits off a closing citation such as " (Judges 4:17–24)." and returns the sentence
    /// without it, or nil when the sentence doesn't end in a reference.
    func trailingCitation(bookName: String, chapterNumber: Int) -> (text: String, reference: String)? {
        guard let match = firstMatch(of: #/\s*\(([^()]+)\)([.!?]?)["”’]?\s*$/#) else { return nil }
        let reference = String(match.1).trimmingCharacters(in: .whitespaces)
        guard !PassageReferenceParser.parseList(reference, book: bookName, chapter: chapterNumber).isEmpty else {
            return nil
        }
        let text = String(self[..<match.range.lowerBound]) + String(match.2)
        return (text, reference)
    }

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

