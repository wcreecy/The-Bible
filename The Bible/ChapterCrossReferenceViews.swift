import Foundation
import SwiftData
import SwiftUI

/// A preview of the chapter's cross references, each shown as a pair of passages.
struct ChapterCrossReferencesPreview: View {
    let bookName: String
    let chapterNumber: Int
    let relatedVerses: [ChapterRelatedVerse]

    @State private var pairs: [ScriptureCrossReference] = []
    @State private var isLoading = true

    var body: some View {
        HeroCard(title: "Cross References", icon: "arrow.triangle.branch") {
            if isLoading {
                ProgressView("Loading cross references…")
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if pairs.isEmpty {
                ContentUnavailableView(
                    "Cross References Unavailable",
                    systemImage: "arrow.triangle.branch",
                    description: Text("The linked passages could not be loaded.")
                )
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(pairs.prefix(2)) { pair in
                        ScriptureCrossReferenceCard(pair: pair)
                    }

                    NavigationLink {
                        ChapterCrossReferencesView(
                            bookName: bookName,
                            chapterNumber: chapterNumber,
                            relatedVerses: relatedVerses
                        )
                    } label: {
                        Label("See all \(pairs.count) cross references", systemImage: "arrow.right")
                            .font(.subheadline.weight(.semibold))
                    }
                    .accessibilityHint("Opens every cross reference for this chapter")
                }
            }
        }
        .task(id: "\(bookName)-\(chapterNumber)") {
            pairs = await ScriptureCrossReferenceLoader.load(
                bookName: bookName,
                chapterNumber: chapterNumber,
                relatedVerses: relatedVerses
            )
            isLoading = false
        }
    }
}

/// The full, grouped cross-reference list reached from the Chapter Insights preview.
struct ChapterCrossReferencesView: View {
    let bookName: String
    let chapterNumber: Int
    let relatedVerses: [ChapterRelatedVerse]

    @State private var pairs: [ScriptureCrossReference] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading cross references…")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(groupedPairs, id: \.source.reference.id) { group in
                        CrossReferenceGroup(source: group.source, pairs: group.pairs)
                    }
                }
                .padding()
            }
        }
        .background(AppBackgroundView(tab: .bible))
        .navigationTitle("Cross References")
        .navigationBarTitleDisplayMode(.inline)
        .scripturePassagePreviews()
        .task(id: "\(bookName)-\(chapterNumber)") {
            pairs = await ScriptureCrossReferenceLoader.load(
                bookName: bookName,
                chapterNumber: chapterNumber,
                relatedVerses: relatedVerses
            )
            isLoading = false
        }
    }

    private var groupedPairs: [(source: ScriptureCrossReference.Source, pairs: [ScriptureCrossReference])] {
        Dictionary(grouping: pairs, by: \.source)
            .sorted { $0.key.verseNumber < $1.key.verseNumber }
            .map { (source: $0.key, pairs: $0.value) }
    }
}

private struct CrossReferenceGroup: View {
    let source: ScriptureCrossReference.Source
    let pairs: [ScriptureCrossReference]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(source.reference.displayTitle)
                .font(.headline)

            Text("“\(source.excerpt)”")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(pairs) { pair in
                ScriptureCrossReferenceCard(pair: pair, showsSource: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ScriptureCrossReferenceCard: View {
    let pair: ScriptureCrossReference
    var showsSource = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                if showsSource {
                    ScriptureConnectionLink(
                        reference: pair.source.reference,
                        excerpt: pair.source.excerpt,
                        pair: pair
                    )
                }

                Image(systemName: "arrow.left.and.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
                    .padding(.top, 4)

                ScriptureConnectionLink(
                    reference: pair.target.reference,
                    excerpt: pair.target.excerpt,
                    pair: pair
                )
            }

            Text(pair.relationshipDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ScriptureConnectionLink: View {
    let reference: PassageReference
    let excerpt: String
    let pair: ScriptureCrossReference

    var body: some View {
        NavigationLink {
            ScriptureConnectionDetailView(pair: pair)
        } label: {
            ScriptureExcerpt(reference: reference, excerpt: excerpt)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens this Scripture connection")
    }
}

private struct ScriptureConnectionDetailView: View {
    let pair: ScriptureCrossReference

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeroCard(title: "Scripture Connection", icon: "arrow.triangle.branch") {
                    VStack(alignment: .leading, spacing: 16) {
                        ScriptureConnectionPassage(
                            reference: pair.source.reference,
                            excerpt: pair.source.excerpt
                        )

                        Image(systemName: "arrow.down")
                            .foregroundStyle(.tint)
                            .frame(maxWidth: .infinity)

                        ScriptureConnectionPassage(
                            reference: pair.target.reference,
                            excerpt: pair.target.excerpt
                        )

                        Divider()

                        ScriptureConnectionExplanation(text: pair.relationshipDescription)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .background(AppBackgroundView(tab: .bible))
        .navigationTitle("Scripture Connection")
        .navigationBarTitleDisplayMode(.inline)
        .scripturePassagePreviews()
    }
}

private struct ScriptureConnectionPassage: View {
    let reference: PassageReference
    let excerpt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(reference.displayTitle)
                .font(.headline)
                .foregroundStyle(.tint)

            Text("“\(excerpt)”")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ScriptureConnectionExplanation: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Relationship")
                .font(.subheadline.weight(.semibold))

            LinkedScriptureText(text)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ScriptureExcerpt: View {
    let reference: PassageReference
    let excerpt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(reference.displayTitle)
                .font(.subheadline.weight(.semibold))

            Text("“\(excerpt)”")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ScriptureCrossReference: Identifiable, Hashable {
    struct Source: Hashable {
        let verseNumber: Int
        let reference: PassageReference
        let excerpt: String
    }

    struct Target: Hashable {
        let reference: PassageReference
        let excerpt: String
    }

    let source: Source
    let target: Target
    let connectionExplanation: String?

    /// Prefers pair-specific editorial copy. The fallback remains careful not to
    /// invent a connection that is not represented in the source data.
    var relationshipDescription: String {
        ChapterCrossReferenceEditorialCatalog.relationshipDescription(
            bookName: source.reference.bookName,
            chapterNumber: source.reference.startChapter,
            sourceVerse: source.reference.startVerse ?? source.verseNumber,
            targetBookName: target.reference.bookName,
            targetChapterNumber: target.reference.startChapter,
            targetVerse: target.reference.startVerse ?? 0
        ) ?? connectionExplanation ?? defaultRelationshipDescription
    }

    private var defaultRelationshipDescription: String {
        switch target.reference.bookName {
        case "Genesis":
            "This connection follows the Genesis narrative, linking the same people, place, promise, or event at another point in the account."
        case "Exodus", "Numbers", "Deuteronomy", "Joshua", "Judges", "1 Samuel", "2 Samuel":
            "This later historical passage shows how a person, place, promise, or consequence from Genesis continues in Israel's story."
        case "1 Chronicles", "2 Chronicles":
            "This later historical record preserves the Genesis family line, place, or event and places it within Israel's history."
        case "Psalms", "Job", "Proverbs", "Ecclesiastes":
            "This poetic or wisdom passage reflects on an image, person, or theme introduced in Genesis and invites the two passages to be read together."
        case "Isaiah", "Jeremiah", "Ezekiel", "Hosea", "Micah", "Malachi", "Daniel":
            "This prophetic passage develops an image, place, person, or theological theme first introduced in Genesis."
        case "Matthew", "Mark", "Luke", "John", "Acts", "Romans", "1 Corinthians", "Galatians", "Ephesians", "Hebrews", "James", "1 Peter", "2 Peter", "1 John", "Jude", "Revelation":
            "This New Testament passage looks back to Genesis to interpret its people, promises, images, or themes in light of Christ and the gospel."
        default:
            "These passages are linked for a meaningful biblical connection. Read them together to see how the later passage echoes or develops the Genesis account."
        }
    }

    var id: String { "\(source.reference.id)-\(target.reference.id)" }
}

@MainActor
private enum ScriptureCrossReferenceLoader {
    static func load(
        bookName: String,
        chapterNumber: Int,
        relatedVerses: [ChapterRelatedVerse]
    ) async -> [ScriptureCrossReference] {
        let books = await BibleRepository.shared.loadAllBooks()

        return relatedVerses.flatMap { relatedVerse in
            let sourceReference = PassageReference(
                bookName: bookName,
                startChapter: chapterNumber,
                startVerse: relatedVerse.sourceVerse,
                endChapter: chapterNumber,
                endVerse: relatedVerse.sourceVerse
            )
            let source = ScriptureCrossReference.Source(
                verseNumber: relatedVerse.sourceVerse,
                reference: sourceReference,
                excerpt: excerpt(for: sourceReference, in: books)
            )

            return PassageReferenceParser.parseList(
                relatedVerse.relatedReference,
                book: bookName,
                chapter: chapterNumber
            ).map { reference in
                ScriptureCrossReference(
                    source: source,
                    target: ScriptureCrossReference.Target(
                        reference: reference,
                        excerpt: excerpt(for: reference, in: books)
                    ),
                    connectionExplanation: relatedVerse.connectionExplanation
                )
            }
        }
    }

    private static func excerpt(for reference: PassageReference, in books: [Book]) -> String {
        guard let book = books.first(where: { $0.name == reference.bookName }) else { return "Passage unavailable." }

        let verses = book.chapters
            .filter { $0.number >= reference.startChapter && $0.number <= reference.endChapter }
            .flatMap { chapter in
                chapter.verses.filter { verse in
                    guard let startVerse = reference.startVerse else { return true }
                    if chapter.number == reference.startChapter, verse.number < startVerse { return false }
                    if let endVerse = reference.endVerse,
                       chapter.number == reference.endChapter,
                       verse.number > endVerse {
                        return false
                    }
                    return true
                }
            }

        let text = verses.prefix(2).map(\.text).joined(separator: " ")
        guard !text.isEmpty else { return "Passage unavailable." }
        return text.count > 180 ? "\(text.prefix(177))…" : text
    }
}
