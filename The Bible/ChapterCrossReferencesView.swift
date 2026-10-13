import SwiftUI

/// A Genesis 1-only prototype for presenting cross-references as comparable Scripture passages.
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
                    ForEach(groupedPairs, id: \.source.id) { group in
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
        HStack(alignment: .top, spacing: 10) {
            if showsSource {
                ScriptureExcerpt(reference: pair.source.reference, excerpt: pair.source.excerpt)
            }

            Image(systemName: "arrow.left.and.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
                .padding(.top, 4)

            ScriptureExcerpt(reference: pair.target.reference, excerpt: pair.target.excerpt)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ScriptureExcerpt: View {
    let reference: PassageReference
    let excerpt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Link(destination: reference.url) {
                Text(reference.displayTitle)
                    .font(.subheadline.weight(.semibold))
            }
            .accessibilityHint("Shows a preview of the passage")

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
                    )
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
