import SwiftUI

struct SearchHomeCard: View {
    let onOpenResult: (SearchResult) -> Void

    @State private var query = ""
    @State private var results: [SearchResult] = []

    private var searchTokens: [String] {
        query
            .lowercased()
            .split { $0.isWhitespace || $0.isPunctuation }
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Search the Bible", systemImage: "magnifyingglass")
                .font(.headline)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search words or a reference", text: $query)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(true)
                    .submitLabel(.search)

                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if !results.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(results) { result in
                        Button {
                            Haptics.selection()
                            onOpenResult(result)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(result.bookName) \(result.chapterNumber):\(result.verseNumber)")
                                    .font(.subheadline.weight(.semibold))
                                Text(result.verseText)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)

                        if result.id != results.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding()
        .heroCardSurface()
        .task(id: query) {
            await updateResults()
        }
    }

    @MainActor
    private func updateResults() async {
        if let referenceResults = resultsForReference(query) {
            results = referenceResults
            return
        }

        let bookSuggestion = resultForBookSuggestion(query)
        if let bookSuggestion {
            results = [bookSuggestion]
        }

        let tokens = searchTokens
        guard !tokens.isEmpty else {
            results = []
            return
        }

        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }

        let textResults = await BibleSearchIndex.shared.search(
            tokens: tokens,
            allowedBookIndices: nil,
            maxResults: 5
        )
        let combinedResults = (bookSuggestion.map { [$0] } ?? []) + textResults
        results = Array(combinedResults.prefix(5))
    }

    private func resultsForReference(_ query: String) -> [SearchResult]? {
        let parts = query.split(whereSeparator: \Character.isWhitespace).map(String.init)
        guard parts.count >= 2, let location = parts.last else { return nil }

        let locationParts = location.split(
            omittingEmptySubsequences: false,
            whereSeparator: { $0 == ":" || $0 == "." || $0 == ";" }
        )
        guard let chapterNumber = Int(locationParts[0]), chapterNumber > 0 else { return nil }
        let verseNumber = locationParts.count == 2 ? Int(locationParts[1]) : nil
        guard locationParts.count <= 2, locationParts.count == 1 || verseNumber != nil else { return nil }

        let bookQuery = parts.dropLast().joined(separator: " ")
        guard let book = bookMatchingReference(bookQuery),
              let chapter = book.chapters.first(where: { $0.number == chapterNumber }) else {
            return []
        }

        let bookIndex = BibleData.books.firstIndex(where: { $0.name == book.name }) ?? 0
        if let verseNumber {
            guard let verse = chapter.verses.first(where: { $0.number == verseNumber }) else { return [] }
            return [SearchResult(
                bookIndex: bookIndex,
                bookName: book.name,
                chapterNumber: chapter.number,
                verseNumber: verse.number,
                verseText: verse.text,
                isReferenceMatch: true
            )]
        }

        return chapter.verses.prefix(5).map { verse in
            SearchResult(
                bookIndex: bookIndex,
                bookName: book.name,
                chapterNumber: chapter.number,
                verseNumber: verse.number,
                verseText: verse.text,
                isReferenceMatch: true
            )
        }
    }

    private func resultForBookSuggestion(_ query: String) -> SearchResult? {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.contains(where: { $0.isWhitespace || $0.isNumber }),
              let book = bookMatchingReference(trimmedQuery),
              let chapter = book.chapters.first,
              let verse = chapter.verses.first else {
            return nil
        }

        let bookIndex = BibleData.books.firstIndex(where: { $0.name == book.name }) ?? 0
        return SearchResult(
            bookIndex: bookIndex,
            bookName: book.name,
            chapterNumber: chapter.number,
            verseNumber: verse.number,
            verseText: verse.text,
            isReferenceMatch: true
        )
    }

    private func bookMatchingReference(_ reference: String) -> Book? {
        let normalized = normalizeBookName(reference)
        let aliases: [String: String] = [
            "gen": "Genesis", "ex": "Exodus", "exod": "Exodus", "lev": "Leviticus",
            "num": "Numbers", "deut": "Deuteronomy", "josh": "Joshua", "judg": "Judges",
            "ps": "Psalms", "psa": "Psalms", "psalm": "Psalms", "prov": "Proverbs",
            "eccl": "Ecclesiastes", "isa": "Isaiah", "jer": "Jeremiah", "ezek": "Ezekiel",
            "dan": "Daniel", "hos": "Hosea", "matt": "Matthew", "mk": "Mark",
            "mrk": "Mark", "lk": "Luke", "jn": "John", "jhn": "John", "acts": "Acts",
            "rom": "Romans", "cor": "Corinthians", "gal": "Galatians", "eph": "Ephesians",
            "phil": "Philippians", "col": "Colossians", "thess": "Thessalonians",
            "tim": "Timothy", "heb": "Hebrews", "jas": "James", "pet": "Peter",
            "rev": "Revelation"
        ]

        let components = normalized.split(separator: " ").map(String.init)
        let expanded: String
        if components.count > 1, let prefixNumber = Int(components[0]) {
            let remainder = components.dropFirst().joined(separator: " ")
            expanded = "\(prefixNumber) \(aliases[remainder] ?? remainder)"
        } else {
            expanded = aliases[normalized] ?? normalized
        }

        if let exactMatch = BibleData.books.first(where: {
            normalizeBookName($0.name) == normalizeBookName(expanded)
        }) {
            return exactMatch
        }

        let abbreviatedParts = normalizeBookName(expanded).split(separator: " ")
        let prefixMatches = BibleData.books.filter { book in
            let bookParts = normalizeBookName(book.name).split(separator: " ")
            return bookParts.count == abbreviatedParts.count
                && zip(bookParts, abbreviatedParts).allSatisfy { bookPart, abbreviation in
                    bookPart.hasPrefix(abbreviation)
                }
        }
        return prefixMatches.count == 1 ? prefixMatches[0] : nil
    }

    private func normalizeBookName(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
