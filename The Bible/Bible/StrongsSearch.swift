import SwiftUI

/// Which dictionary entries a Strong's search matched, and how many verses use them.
struct StrongsSearchMatch: Equatable, Sendable {
    let entries: [StrongsEntry]
    /// The verses using the entries within the search's scope, including any past the result limit.
    let verseCount: Int
}

/// Finding verses by the Hebrew or Greek word behind them, from the same search field as
/// everything else: a Strong's number ("G3056", "H430"), a word in Greek or Hebrew letters
/// ("ἀγάπη"), or, when English finds nothing, a transliteration ("agape").
nonisolated enum StrongsSearch {
    enum Query: Equatable, Sendable {
        /// The 4-digit number as the database stores it, without the disambiguating letter: "G0026".
        case number(prefix: String)
        /// What `key(for:)` makes of the word.
        case word(key: String)
    }

    struct Outcome: Sendable {
        let match: StrongsSearchMatch
        let results: [SearchResult]
        let hasMore: Bool
    }

    // MARK: Reading what was typed

    /// The kind of search a text is, if any. A transliteration is only a search when the caller
    /// allows it, because "love" or "peace" should be left to the English search.
    static func parse(_ text: String, allowingTransliteration: Bool) -> Query? {
        if let number = number(in: text) {
            return .number(prefix: number)
        }
        let key = key(for: text)
        guard !key.isEmpty else { return nil }
        if usesOriginalScript(text) {
            return .word(key: key)
        }
        // A transliteration is one word; several would be an English phrase.
        let isOneWord = !text.trimmingCharacters(in: .whitespacesAndNewlines).contains(where: \.isWhitespace)
        if allowingTransliteration, isOneWord, key.count >= 3 {
            return .word(key: key)
        }
        return nil
    }

    /// "G3056", "g 3056", "Strong's H430" as "G3056" and "H0430".
    private static func number(in text: String) -> String? {
        let pattern = #/^\s*(?:strong['’]?s\s*)?([gh])\s*0*(\d{1,4})\s*$/#.ignoresCase()
        guard let match = text.firstMatch(of: pattern),
              let number = Int(match.output.2), number > 0 else { return nil }
        return match.output.1.uppercased() + String(format: "%04d", number)
    }

    /// What a word is matched on: lowercase letters only, without accents, vowel points, or
    /// macrons, and with the Greek final sigma as an ordinary one. This must stay the same as
    /// `search_key` in Scripts/build_original_words.py, which builds the keys it is compared with.
    static func key(for text: String) -> String {
        var letters = String.UnicodeScalarView()
        for scalar in text.lowercased().decomposedStringWithCanonicalMapping.unicodeScalars {
            switch scalar.properties.generalCategory {
            case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter:
                letters.append(scalar)
            default:
                break
            }
        }
        return String(letters).replacingOccurrences(of: "ς", with: "σ")
    }

    /// Whether any letter is Greek or Hebrew.
    static func usesOriginalScript(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x0370...0x03FF).contains(scalar.value)
                || (0x1F00...0x1FFF).contains(scalar.value)
                || (0x0590...0x05FF).contains(scalar.value)
        }
    }

    // MARK: Searching

    /// The entries and verses a search text finds, or nil when it isn't a Strong's search or
    /// nothing matches. `allowedBookIndices` is the search's scope (all, OT, NT, or one book) as
    /// positions in `books`.
    static func search(
        _ text: String,
        allowingTransliteration: Bool,
        translation: BibleTranslation,
        books: [Book],
        allowedBookIndices: Range<Int>?,
        maxResults: Int
    ) async -> Outcome? {
        guard let query = parse(text, allowingTransliteration: allowingTransliteration) else { return nil }

        let repository = OriginalWordsRepository.shared
        let entries: [StrongsEntry]
        switch query {
        case .number(let prefix):
            entries = await repository.strongsEntries(forNumberPrefix: prefix)
        case .word(let key):
            entries = await repository.strongsEntries(forKey: key)
        }
        guard !entries.isEmpty else { return nil }

        let locations = await repository.verses(usingAnyOf: entries.map(\.strongs), translation: translation)
        let bookIndices = Dictionary(
            books.enumerated().map { ($1.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let inScope = locations.compactMap { location -> SearchResult? in
            guard let bookIndex = bookIndices[location.bookName],
                  allowedBookIndices?.contains(bookIndex) ?? true else { return nil }
            let text = books[bookIndex].chapters.first { $0.number == location.chapter }?
                .verses.first { $0.number == location.verse }?.text ?? ""
            return SearchResult(
                bookIndex: bookIndex,
                bookName: location.bookName,
                chapterNumber: location.chapter,
                verseNumber: location.verse,
                verseText: text,
                isReferenceMatch: false
            )
        }
        guard !inScope.isEmpty else { return nil }

        return Outcome(
            match: StrongsSearchMatch(entries: entries, verseCount: inScope.count),
            results: Array(inScope.prefix(maxResults)),
            hasMore: inScope.count > maxResults
        )
    }
}

/// Above the results of a Strong's search: which entries were matched, so a verse list for
/// "agape" isn't a mystery.
struct StrongsSearchHeader: View {
    let match: StrongsSearchMatch

    /// A number can have many entries for its senses; the first few say enough.
    private let shownEntries = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Hebrew and Greek word", systemImage: "character.book.closed")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(match.entries.prefix(shownEntries)) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(entry.displayNumber)
                            .font(.caption.monospaced().weight(.semibold))
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                        Text(entry.lemma)
                            .font(.headline)
                        if !entry.transliteration.isEmpty {
                            Text(entry.transliteration)
                                .font(.subheadline)
                                .italic()
                                .foregroundStyle(.secondary)
                        }
                    }
                    if !entry.gloss.isEmpty {
                        Text(entry.gloss)
                            .font(.subheadline)
                    }
                }
            }
            if match.entries.count > shownEntries {
                Text("and \(match.entries.count - shownEntries) more entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(verseCountText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var verseCountText: LocalizedStringKey {
        match.verseCount == 1
            ? "Used in 1 verse. Open a verse’s menu and choose Hebrew or Greek Words to study it."
            : "Used in \(match.verseCount.formatted()) verses. Open a verse’s menu and choose Hebrew or Greek Words to study it."
    }
}
