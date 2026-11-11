import Foundation

/// A passage cited in study content: a verse, a verse range, a chapter, or a chapter range.
struct PassageReference: Identifiable, Hashable {
    let bookName: String
    let startChapter: Int
    /// `nil` when the reference names whole chapters.
    let startVerse: Int?
    let endChapter: Int
    let endVerse: Int?

    var id: String { displayTitle }

    var isSingleChapter: Bool { startChapter == endChapter }

    var displayTitle: String {
        let start = startVerse.map { "\(startChapter):\($0)" } ?? "\(startChapter)"
        switch (startVerse, endVerse) {
        case let (startVerse?, endVerse?) where isSingleChapter:
            return endVerse == startVerse
                ? "\(bookName) \(start)"
                : "\(bookName) \(start)–\(endVerse)"
        case (_, let endVerse?):
            return "\(bookName) \(start)–\(endChapter):\(endVerse)"
        case (_, nil):
            return isSingleChapter ? "\(bookName) \(start)" : "\(bookName) \(start)–\(endChapter)"
        }
    }

    // MARK: In-app link URL

    private static let scheme = "thebible"
    private static let host = "passage"

    /// Link target used inside rendered text; opened by `scripturePassagePreviews()`.
    var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = Self.host
        var items = [
            URLQueryItem(name: "book", value: bookName),
            URLQueryItem(name: "fromChapter", value: "\(startChapter)"),
            URLQueryItem(name: "toChapter", value: "\(endChapter)")
        ]
        if let startVerse { items.append(URLQueryItem(name: "fromVerse", value: "\(startVerse)")) }
        if let endVerse { items.append(URLQueryItem(name: "toVerse", value: "\(endVerse)")) }
        components.queryItems = items
        return components.url ?? URL(string: "thebible://passage")!
    }

    init(bookName: String, startChapter: Int, startVerse: Int?, endChapter: Int, endVerse: Int?) {
        self.bookName = bookName
        self.startChapter = startChapter
        self.startVerse = startVerse
        self.endChapter = endChapter
        self.endVerse = endVerse
    }

    init?(url: URL) {
        guard url.scheme == Self.scheme, url.host == Self.host,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return nil }
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        guard let book = value("book"),
              let fromChapter = value("fromChapter").flatMap(Int.init),
              let toChapter = value("toChapter").flatMap(Int.init) else { return nil }
        self.init(
            bookName: book,
            startChapter: fromChapter,
            startVerse: value("fromVerse").flatMap(Int.init),
            endChapter: toChapter,
            endVerse: value("toVerse").flatMap(Int.init)
        )
    }
}

/// Finds passage references in study text, such as "Matthew 5:3–12", "Genesis 12-50",
/// "Deuteronomy 19:15", or "Psalm 23", and validates them against the corpus.
@MainActor
enum PassageReferenceParser {
    /// Alternate spellings found in study content.
    private static let aliases = [
        "Psalm": "Psalms",
        "Song of Songs": "Song of Solomon",
        "Revelations": "Revelation"
    ]

    private static var cachedRegex: NSRegularExpression?
    private static var cachedBookCount = 0

    /// Built from the loaded corpus; rebuilt if the corpus finished loading after first use.
    private static var regex: NSRegularExpression? {
        let books = BibleData.books
        if let cachedRegex, cachedBookCount == books.count { return cachedRegex }
        guard !books.isEmpty else { return nil }

        // Longest names first so "1 John" wins over "John" and "Psalms" over "Psalm".
        let names = (books.map(\.name) + aliases.keys)
            .sorted { $0.count > $1.count }
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: "|")
        let pattern = #"(?<![A-Za-z0-9])("# + names
            + #")\s+(\d{1,3})(?::(\d{1,3}))?(?:\s*[-–—]\s*(\d{1,3})(?::(\d{1,3}))?)?(?![0-9:])"#
        cachedRegex = try? NSRegularExpression(pattern: pattern)
        cachedBookCount = books.count
        return cachedRegex
    }

    /// Parses a string that is entirely a reference, such as a list entry.
    static func parse(_ text: String) -> PassageReference? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let match = matches(in: trimmed).first,
              match.range == trimmed.startIndex..<trimmed.endIndex else { return nil }
        return match.reference
    }

    /// Parses a reference-list entry, filling in what the study data leaves out using the
    /// book and chapter being shown. Handles entries such as "1:2-4" (no book), "20-23"
    /// (verses only), "Leviticus 1:1:1–3" (doubled chapter), and "3:11-13,40-45" (several
    /// passages), which becomes one reference per passage.
    static func parseList(_ text: String, book contextBook: String?, chapter contextChapter: Int?) -> [PassageReference] {
        if let reference = parse(text) { return [reference] }

        var entry = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // "Leviticus 1:1:1–3" → "Leviticus 1:1–3"
        entry = entry.replacingOccurrences(
            of: #"(\d+):\1:(\d)"#,
            with: "$1:$2",
            options: .regularExpression
        )

        // Split off a leading book name; the rest is chapter/verse locations.
        var bookName = contextBook
        var locations = entry
        if let leading = leadingBookName(in: entry) {
            bookName = leading.book
            locations = leading.remainder
        } else if let first = entry.first, !first.isNumber {
            return []
        }
        guard let bookName else { return [] }

        var chapter = contextChapter
        var references: [PassageReference] = []
        for part in locations.split(whereSeparator: { $0 == "," || $0 == ";" }) {
            let piece = part.trimmingCharacters(in: .whitespaces)
            guard let firstCharacter = piece.first, firstCharacter.isNumber else { continue }
            let candidate: String
            if piece.contains(":") {
                // "3:11-13" names its own chapter, which later pieces inherit.
                chapter = piece.split(separator: ":").first.flatMap { Int($0) } ?? chapter
                candidate = "\(bookName) \(piece)"
            } else if let chapter {
                // "40-45" continues in the current chapter.
                candidate = "\(bookName) \(chapter):\(piece)"
            } else {
                candidate = "\(bookName) \(piece)"
            }
            if let reference = parse(candidate) {
                references.append(reference)
            }
        }
        return references
    }

    /// A book name at the start of `text` (including spellings such as "Psalm") and the text after it.
    private static func leadingBookName(in text: String) -> (book: String, remainder: String)? {
        let names = (BibleData.books.map(\.name) + aliases.keys).sorted { $0.count > $1.count }
        for name in names where text.hasPrefix(name + " ") {
            let remainder = text.dropFirst(name.count).trimmingCharacters(in: .whitespaces)
            return (aliases[name] ?? name, remainder)
        }
        return nil
    }

    /// Every valid reference in `text` with its location.
    static func matches(in text: String) -> [(range: Range<String.Index>, reference: PassageReference)] {
        guard let regex else { return [] }
        let nsRange = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: nsRange).compactMap { match in
            guard let range = Range(match.range, in: text),
                  let reference = reference(from: match, in: text) else { return nil }
            return (range, reference)
        }
    }

    /// The text with every reference turned into a link to its preview. With a `contextBook`,
    /// references that leave out the book name, such as "(3:9)", link into that book.
    static func linkified(_ text: String, contextBook: String? = nil) -> AttributedString {
        var attributed = AttributedString()
        var cursor = text.startIndex
        for match in allMatches(in: text, contextBook: contextBook) {
            attributed += AttributedString(text[cursor..<match.range.lowerBound])
            // Keep each reference on one line instead of breaking it at a space or dash.
            var link = AttributedString(
                text[match.range]
                    .replacingOccurrences(of: " ", with: "\u{00A0}")
                    .replacingOccurrences(of: "–", with: "–\u{2060}")
                    .replacingOccurrences(of: "-", with: "\u{2011}")
            )
            link.link = match.reference.url
            attributed += link
            cursor = match.range.upperBound
        }
        attributed += AttributedString(text[cursor...])
        return attributed
    }

    private static let continuationRegex = try? NSRegularExpression(
        pattern: #"^\s*[,;]\s*(\d{1,3})(?::(\d{1,3}))?(?:\s*[-–—]\s*(\d{1,3}))?(?![0-9:])"#
    )
    private static let bareChapterVerseRegex = try? NSRegularExpression(
        pattern: #"(?<![\w:.\-–—])(\d{1,3}):(\d{1,3})(?:\s*[-–—]\s*(\d{1,3}))?(?![0-9:])"#
    )

    /// Full references plus the short forms around them, sorted by position: entries that
    /// continue a list ("Ruth 1:1; 3:2, 7") and, with a `contextBook`, bare "3:9" references.
    private static func allMatches(
        in text: String,
        contextBook: String?
    ) -> [(range: Range<String.Index>, reference: PassageReference)] {
        let named = matches(in: text)
        let namedRanges = named.map(\.range)
        var found = named + named.flatMap { continuations(after: $0, in: text, avoiding: namedRanges) }

        if let contextBook, let bareChapterVerseRegex {
            let nsRange = NSRange(text.startIndex..., in: text)
            for match in bareChapterVerseRegex.matches(in: text, range: nsRange) {
                guard let range = Range(match.range, in: text),
                      !found.contains(where: { $0.range.overlaps(range) }),
                      let chapter = number(at: 1, of: match, in: text),
                      let verse = number(at: 2, of: match, in: text) else { continue }
                let reference = PassageReference(
                    bookName: contextBook,
                    startChapter: chapter,
                    startVerse: verse,
                    endChapter: chapter,
                    endVerse: max(verse, number(at: 3, of: match, in: text) ?? verse)
                )
                guard isValid(reference) else { continue }
                found.append((range, reference))
                found += continuations(after: (range, reference), in: text, avoiding: namedRanges)
            }
        }
        return found.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    /// The list entries that follow a reference: "; 3:2" names a new chapter and verse in the
    /// same book, while ", 7" is another verse in the same chapter (or another chapter).
    private static func continuations(
        after match: (range: Range<String.Index>, reference: PassageReference),
        in text: String,
        avoiding namedRanges: [Range<String.Index>]
    ) -> [(range: Range<String.Index>, reference: PassageReference)] {
        guard let continuationRegex else { return [] }
        var results: [(range: Range<String.Index>, reference: PassageReference)] = []
        var previous = match.reference
        var cursor = match.range.upperBound
        while cursor < text.endIndex {
            let nsRange = NSRange(cursor..., in: text)
            guard let next = continuationRegex.firstMatch(in: text, range: nsRange),
                  let first = number(at: 1, of: next, in: text),
                  let numberRange = Range(next.range(at: 1), in: text),
                  let fullRange = Range(next.range, in: text),
                  // In "Genesis 12–50, 1 Samuel 3" the "1" starts the next reference.
                  !namedRanges.contains(where: { $0.overlaps(fullRange) }) else { break }
            let second = number(at: 2, of: next, in: text)
            let rangeEnd = number(at: 3, of: next, in: text)

            let reference: PassageReference
            if let verse = second {
                reference = PassageReference(
                    bookName: previous.bookName, startChapter: first, startVerse: verse,
                    endChapter: first, endVerse: max(verse, rangeEnd ?? verse)
                )
            } else if previous.endVerse != nil {
                reference = PassageReference(
                    bookName: previous.bookName, startChapter: previous.endChapter, startVerse: first,
                    endChapter: previous.endChapter, endVerse: max(first, rangeEnd ?? first)
                )
            } else {
                reference = PassageReference(
                    bookName: previous.bookName, startChapter: first, startVerse: nil,
                    endChapter: max(first, rangeEnd ?? first), endVerse: nil
                )
            }
            guard isValid(reference) else { break }
            // Link only the numbers, not the separator before them.
            results.append((numberRange.lowerBound..<fullRange.upperBound, reference))
            previous = reference
            cursor = fullRange.upperBound
        }
        return results
    }

    private static func number(at index: Int, of match: NSTextCheckingResult, in text: String) -> Int? {
        guard let range = Range(match.range(at: index), in: text) else { return nil }
        return Int(text[range])
    }

    private static func reference(from match: NSTextCheckingResult, in text: String) -> PassageReference? {
        func group(_ index: Int) -> String? {
            guard let range = Range(match.range(at: index), in: text) else { return nil }
            return String(text[range])
        }
        func number(_ index: Int) -> Int? { group(index).flatMap(Int.init) }

        guard let rawBook = group(1),
              let chapter = number(2) else { return nil }
        let bookName = aliases[rawBook] ?? rawBook
        let verse = number(3)
        let rangeFirst = number(4)
        let rangeSecond = number(5)

        let endChapter: Int
        let endVerse: Int?
        switch (verse, rangeFirst, rangeSecond) {
        case let (_, to?, toVerse?):        // "John 3:16–4:2" or "Genesis 1–2:3"
            endChapter = to
            endVerse = toVerse
        case let (verse?, to?, nil):        // "Matthew 5:3–12"
            endChapter = chapter
            endVerse = max(verse, to)
        case let (verse?, nil, nil):        // "Deuteronomy 19:15"
            endChapter = chapter
            endVerse = verse
        case let (nil, to?, nil):           // "Genesis 12–50"
            endChapter = to
            endVerse = nil
        default:                            // "Psalm 23"
            endChapter = chapter
            endVerse = nil
        }

        let reference = PassageReference(
            bookName: bookName,
            startChapter: chapter,
            startVerse: verse,
            endChapter: endChapter,
            endVerse: endVerse
        )
        return isValid(reference) ? reference : nil
    }

    private static func isValid(_ reference: PassageReference) -> Bool {
        guard let book = BibleData.books.first(where: { $0.name == reference.bookName }),
              reference.startChapter >= 1,
              reference.endChapter >= reference.startChapter,
              reference.endChapter <= book.chapters.count else { return false }
        if let startVerse = reference.startVerse,
           startVerse > book.chapters[reference.startChapter - 1].verses.count { return false }
        if let endVerse = reference.endVerse,
           endVerse > book.chapters[reference.endChapter - 1].verses.count { return false }
        return true
    }
}
