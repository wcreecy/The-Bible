import Foundation

/// Resolves typed Bible references such as "John 1", "jn 3:16", or "1 Cor 13" against the loaded canon.
/// Shared by the full Search screen and the Home search card so both interpret references the same way.
nonisolated enum BibleReferenceParser {
    /// A parsed reference, resolved to a concrete book and chapter.
    struct Reference {
        let bookIndex: Int
        let book: Book
        let chapter: Chapter
        /// Present when the query named a specific verse (e.g. "John 3:16").
        let verse: Verse?

        /// Display title such as "John 1" or "John 3:16".
        var title: String {
            if let verse {
                return "\(book.name) \(chapter.number):\(verse.number)"
            }
            return "\(book.name) \(chapter.number)"
        }
    }

    /// Resolves a "Book Chapter[:Verse]" query, or returns `nil` if it isn't one or names a book/chapter/verse that doesn't exist.
    static func reference(for query: String, in books: [Book]) -> Reference? {
        guard let parsed = parse(query),
              let bookIndex = bookIndex(matching: parsed.bookQuery, in: books) else { return nil }

        let book = books[bookIndex]
        guard let chapter = book.chapters.first(where: { $0.number == parsed.chapterNumber }) else { return nil }

        if let verseNumber = parsed.verseNumber {
            guard let verse = chapter.verses.first(where: { $0.number == verseNumber }) else { return nil }
            return Reference(bookIndex: bookIndex, book: book, chapter: chapter, verse: verse)
        }
        return Reference(bookIndex: bookIndex, book: book, chapter: chapter, verse: nil)
    }

    /// Whether the query has the shape "Book Chapter[:Verse]", regardless of whether it resolves.
    static func isReferenceShaped(_ query: String) -> Bool {
        parse(query) != nil
    }

    /// Search results for a reference query: one result for a verse reference, every verse for a chapter reference.
    /// Returns `nil` when the query is not reference-shaped, and an empty array when it is but doesn't resolve.
    static func results(for query: String, in books: [Book]) -> [SearchResult]? {
        guard isReferenceShaped(query) else { return nil }
        guard let reference = reference(for: query, in: books) else { return [] }

        let verses = reference.verse.map { [$0] } ?? reference.chapter.verses
        return verses.map { verse in
            SearchResult(
                bookIndex: reference.bookIndex,
                bookName: reference.book.name,
                chapterNumber: reference.chapter.number,
                verseNumber: verse.number,
                verseText: verse.text,
                isReferenceMatch: true
            )
        }
    }

    /// Finds the book a name or abbreviation refers to ("jn", "1 cor", "Psalm"), or `nil` if ambiguous or unknown.
    static func bookIndex(matching reference: String, in books: [Book]) -> Int? {
        let normalized = normalizeBookName(reference)
        guard !normalized.isEmpty else { return nil }

        let expanded: String
        let components = normalized.split(separator: " ").map(String.init)
        if components.count > 1, let prefixNumber = Int(components[0]) {
            let remainder = components.dropFirst().joined(separator: " ")
            expanded = "\(prefixNumber) \(aliases[remainder] ?? remainder)"
        } else {
            expanded = aliases[normalized] ?? normalized
        }

        let normalizedExpanded = normalizeBookName(expanded)
        if let exactMatch = books.firstIndex(where: { normalizeBookName($0.name) == normalizedExpanded }) {
            return exactMatch
        }

        // Allow unambiguous prefixes, matched word by word ("1 thes" -> "1 Thessalonians").
        let abbreviatedParts = normalizedExpanded.split(separator: " ")
        let prefixMatches = books.indices.filter { index in
            let bookParts = normalizeBookName(books[index].name).split(separator: " ")
            return bookParts.count == abbreviatedParts.count
                && zip(bookParts, abbreviatedParts).allSatisfy { bookPart, abbreviation in
                    bookPart.hasPrefix(abbreviation)
                }
        }
        return prefixMatches.count == 1 ? prefixMatches[0] : nil
    }

    // MARK: - Private

    private struct ParsedQuery {
        let bookQuery: String
        let chapterNumber: Int
        let verseNumber: Int?
    }

    private static let aliases: [String: String] = [
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

    private static func parse(_ query: String) -> ParsedQuery? {
        let parts = query.split(whereSeparator: \Character.isWhitespace).map(String.init)
        guard parts.count >= 2, let location = parts.last else { return nil }

        let locationParts = location.split(separator: ":", omittingEmptySubsequences: false)
        guard locationParts.count <= 2,
              let chapterNumber = Int(locationParts[0]), chapterNumber > 0 else { return nil }

        // "John 3:" (verse not typed yet) still refers to the chapter.
        var verseNumber: Int?
        if locationParts.count == 2, !locationParts[1].isEmpty {
            guard let verse = Int(locationParts[1]) else { return nil }
            verseNumber = verse
        }

        return ParsedQuery(
            bookQuery: parts.dropLast().joined(separator: " "),
            chapterNumber: chapterNumber,
            verseNumber: verseNumber
        )
    }

    private static func normalizeBookName(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
