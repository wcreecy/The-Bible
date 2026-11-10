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
/// "agape" isn't a mystery. Tapping it opens the full entries and every verse using the word.
struct StrongsSearchHeader: View {
    let match: StrongsSearchMatch
    /// Opens a verse chosen in the study sheet.
    let onOpenVerse: (SearchResult) -> Void
    @State private var isShowingStudy = false

    /// A number can have many entries for its senses (H430 has H0430G, H0430H, …), all the same
    /// word. One row each for the distinct words says enough.
    private var distinctEntries: [StrongsEntry] {
        var seen = Set<String>()
        return match.entries.filter { seen.insert("\($0.displayNumber)|\($0.lemma)").inserted }
    }

    private let shownEntries = 3
    private static let collapsedLineLimit = 4

    var body: some View {
        Button {
            Haptics.selection()
            isShowingStudy = true
        } label: {
            HStack(alignment: .top, spacing: 8) {
                content
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows the full entry and every verse that uses this word")
        .accessibilityIdentifier("strongsSearchCard")
        .sheet(isPresented: $isShowingStudy) {
            StrongsStudySheet(
                match: match,
                translation: BibleRepository.shared.activeTranslation,
                onOpen: openVerse
            )
        }
    }

    private func openVerse(_ location: VerseLocation) {
        isShowingStudy = false
        let result = SearchResult(
            bookIndex: BibleData.books.firstIndex { $0.name == location.bookName } ?? 0,
            bookName: location.bookName,
            chapterNumber: location.chapter,
            verseNumber: location.verse,
            verseText: "",
            isReferenceMatch: true
        )
        // Open after the sheet starts dismissing so the reader can take over.
        DispatchQueue.main.async {
            onOpenVerse(result)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Hebrew and Greek word", systemImage: "character.book.closed")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(distinctEntries.prefix(shownEntries)) { entry in
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
                            .font(.subheadline.weight(.semibold))
                    }
                    if !entry.definition.isEmpty {
                        Text(entry.definition)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(Self.collapsedLineLimit)
                            .padding(.top, 2)
                    }
                }
            }
            if distinctEntries.count > shownEntries {
                Text("and \(distinctEntries.count - shownEntries) more entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(verseCountText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .multilineTextAlignment(.leading)
    }

    private var verseCountText: LocalizedStringKey {
        match.verseCount == 1
            ? "Used in 1 verse · Tap to study"
            : "Used in \(match.verseCount.formatted()) verses · Tap to study"
    }
}

#Preview("Strong's Search Header") {
    List {
        StrongsSearchHeader(
            match: StrongsSearchMatch(
                entries: [
                    StrongsEntry(
                        strongs: "H1834", lemma: "דַּמֶּ֫שֶׂק", transliteration: "dam.me.seq", gloss: "Damascus",
                        definition: "§ Damascus = \"silent is the sackcloth weaver\"\nan ancient trading city, capital of Syria, located in the plain east of Hermon, 130 (205 km) miles northeast of Jerusalem"
                    ),
                ],
                verseCount: 40
            ),
            onOpenVerse: { _ in }
        )
        .listRowBackground(Color.accentColor.opacity(0.08))
        Text("Search result rows follow here.")
    }
}

#Preview("Strong's Search Header, Long Definition") {
    List {
        StrongsSearchHeader(
            match: StrongsSearchMatch(
                entries: [
                    StrongsEntry(
                        strongs: "G3056", lemma: "λόγος", transliteration: "logos", gloss: "word",
                        definition: "I. Of that by which the inward thought is expressed\n1. a word, not in the grammatical sense of a mere name, but a word as embodying a conception or idea\n2. a saying, statement, declaration; with genitive attrib.; of the sayings, commands, promises, of teachers\n3. speech, discourse; of the faculty of speech; of the style of speech; of instruction\n4. subject-matter, hence, teaching, doctrine"
                    ),
                ],
                verseCount: 314
            ),
            onOpenVerse: { _ in }
        )
        .listRowBackground(Color.accentColor.opacity(0.08))
        Text("Search result rows follow here.")
    }
}
