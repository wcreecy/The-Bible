import Foundation
import SwiftUI

struct ScriptureRef: Equatable {
    let bookName: String
    let chapter: Int
    let startVerse: Int
    let endVerse: Int?
}

enum BibleReferenceLinker {
    // Custom URL scheme for in-app scripture links
    private static let scheme = "thebible-ref"

    // Common book abbreviations mapped to canonical names (lowercased keys)
    private static let abbreviations: [String: String] = [
        // Pentateuch
        "gen": "Genesis", "ge": "Genesis", "gn": "Genesis",
        "ex": "Exodus", "exo": "Exodus",
        "lev": "Leviticus", "lv": "Leviticus",
        "num": "Numbers", "nm": "Numbers", "nu": "Numbers",
        "deut": "Deuteronomy", "deu": "Deuteronomy", "dt": "Deuteronomy",
        // History
        "jos": "Joshua", "josh": "Joshua",
        "judg": "Judges", "jdg": "Judges",
        "rut": "Ruth", "ru": "Ruth",
        "sam": "Samuel", "sa": "Samuel",
        "kgs": "Kings", "kg": "Kings",
        "chron": "Chronicles", "chr": "Chronicles",
        "ezr": "Ezra",
        "neh": "Nehemiah", "ne": "Nehemiah",
        "est": "Esther",
        // Poetry/Wisdom
        "job": "Job",
        "ps": "Psalms", "psa": "Psalms", "psalm": "Psalms",
        "prov": "Proverbs", "pr": "Proverbs",
        "eccl": "Ecclesiastes", "ecc": "Ecclesiastes",
        "song": "Song of Solomon", "so": "Song of Solomon", "sos": "Song of Solomon",
        // Major Prophets
        "isa": "Isaiah",
        "jer": "Jeremiah",
        "lam": "Lamentations",
        "eze": "Ezekiel", "ezek": "Ezekiel",
        "dan": "Daniel",
        // Minor Prophets
        "hos": "Hosea",
        "joe": "Joel",
        "amo": "Amos",
        "oba": "Obadiah",
        "jon": "Jonah",
        "mic": "Micah",
        "nah": "Nahum",
        "hab": "Habakkuk",
        "zep": "Zephaniah",
        "hag": "Haggai",
        "zec": "Zechariah",
        "mal": "Malachi",
        // Gospels/Acts
        "mat": "Matthew", "mt": "Matthew",
        "mk": "Mark", "mrk": "Mark",
        "lk": "Luke",
        "jn": "John", "jhn": "John",
        "act": "Acts", "acts": "Acts",
        // Paul
        "rom": "Romans",
        "cor": "Corinthians",
        "gal": "Galatians",
        "eph": "Ephesians",
        "phil": "Philippians",
        "col": "Colossians",
        "thess": "Thessalonians",
        "tim": "Timothy",
        "tit": "Titus",
        "phm": "Philemon",
        "heb": "Hebrews",
        // General
        "jas": "James",
        "pet": "Peter", "petr": "Peter",
        "joh": "John",
        "jud": "Jude",
        "rev": "Revelation"
    ]

    // Insert a space between leading digits and letters (e.g., "1sam" -> "1 sam")
    private static func insertSpaceBetweenLeadingDigitsAndLetters(in s: String) -> String {
        guard let first = s.first, first.isNumber else { return s }
        let digits = String(s.prefix { $0.isNumber })
        let rest = String(s.drop { $0.isNumber })
        if rest.first?.isLetter == true { return digits + " " + rest }
        return s
    }

    // Normalize a raw book token to a canonical BibleData book name, if possible
    private static func resolveBook(named raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // Try direct match first
        if let direct = BibleData.books.first(where: { $0.name.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            return direct.name
        }
        // Insert a space between leading digits and letters (e.g., "1kgs")
        let spaced = insertSpaceBetweenLeadingDigitsAndLetters(in: trimmed)
        // Tokenize, expand abbreviations, and title-case tokens
        let cleaned = spaced.replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        var tokens = cleaned.split { $0.isWhitespace }.map { String($0) }
        // Map abbreviations
        let mapped = tokens.enumerated().map { (idx, t) -> String in
            let lower = t.lowercased()
            if let exp = abbreviations[lower] { return exp }
            if Int(lower) != nil { return t } // keep numeric ordinals
            return t.prefix(1).uppercased() + t.dropFirst().lowercased()
        }
        let candidate = mapped.joined(separator: " ")
        if let match = BibleData.books.first(where: { $0.name.compare(candidate, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            return match.name
        }
        // Relaxed: remove spaces and compare
        let collapsed = candidate.replacingOccurrences(of: " ", with: "")
        if let match = BibleData.books.first(where: { $0.name.replacingOccurrences(of: " ", with: "").compare(collapsed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            return match.name
        }
        return nil
    }

    /// Build a regex that matches references like "John 3:16" or "1 John 4:7-8" using known book names.
    private static func referenceRegex() -> NSRegularExpression? {
        // Match a boundary (start of string or any non-alphanumeric), then a book name that may start with an optional ordinal (1-3) and optional space.
        // The book name is 1-3 tokens of letters (and periods for abbreviations). Then whitespace, then chapter:verse with optional range.
        // Capture groups:
        // 1: boundary (may be zero-width when at start of string)
        // 2: book token(s)
        // 3: chapter digits
        // 4: start verse digits
        // 5: optional end verse digits
        let pattern = "(^|[^A-Za-z0-9])((?:[1-3]\\s*)?[A-Za-z][A-Za-z.]*?(?:\\s+[A-Za-z.]+){0,2})\\s+(\\d+):(\\d+)(?:[\\-\\u2013\\u2014](\\d+))?"
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    /// Returns an AttributedString with link attributes for detected references.
    static func linkify(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        guard let regex = referenceRegex() else { return attributed }
        let ns = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
        // Walk from end to start to avoid range shifting while editing attributes
        for m in matches.reversed() {
            guard m.numberOfRanges >= 6 else { continue }
            let boundaryRange = m.range(at: 1)
            let bookRange = m.range(at: 2)
            let chapterRange = m.range(at: 3)
            let startRange = m.range(at: 4)
            let endRange = m.range(at: 5)
            let rawBook = ns.substring(with: bookRange)
            // Resolve raw token (may be shorthand) to a canonical book name
            guard let resolvedBook = resolveBook(named: rawBook) else { continue }
            let chapStr = ns.substring(with: chapterRange)
            let startStr = ns.substring(with: startRange)
            let endStr: String? = endRange.location != NSNotFound ? ns.substring(with: endRange) : nil
            guard let chapter = Int(chapStr), let start = Int(startStr) else { continue }
            let end = endStr.flatMap { Int($0) }

            // Build URL
            var comps = URLComponents()
            comps.scheme = scheme
            comps.host = "ref"
            comps.queryItems = [
                URLQueryItem(name: "book", value: resolvedBook),
                URLQueryItem(name: "chapter", value: String(chapter)),
                URLQueryItem(name: "start", value: String(start))
            ]
            if let end = end { comps.queryItems?.append(URLQueryItem(name: "end", value: String(end))) }
            guard let url = comps.url else { continue }

            // Build the hyperlink range from the beginning of the book through the end of the full match
            let overall = m.range(at: 0)
            let linkStart = bookRange.location
            let linkLength = overall.location + overall.length - linkStart
            let fullLinkRange = NSRange(location: linkStart, length: linkLength)

            if let strRange = Range(fullLinkRange, in: text) {
                if let lower = AttributedString.Index(strRange.lowerBound, within: attributed),
                   let upper = AttributedString.Index(strRange.upperBound, within: attributed) {
                    let attrRange: Range<AttributedString.Index> = lower..<upper
                    attributed[attrRange].link = url
                    attributed[attrRange].foregroundColor = .blue
                    attributed[attrRange].underlineStyle = .single
                }
            }
        }
        return attributed
    }

    /// Parse a custom in-app URL back into a ScriptureRef
    static func parse(url: URL) -> ScriptureRef? {
        guard url.scheme == scheme else { return nil }
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        var params: [String: String] = [:]
        comps.queryItems?.forEach { params[$0.name.lowercased()] = $0.value ?? "" }
        guard let book = params["book"], !book.isEmpty,
              let chapStr = params["chapter"], let chapter = Int(chapStr),
              let startStr = params["start"], let start = Int(startStr) else { return nil }
        let end: Int? = params["end"].flatMap { Int($0) }
        return ScriptureRef(bookName: book, chapter: chapter, startVerse: start, endVerse: end)
    }

    /// Load verses for a given ScriptureRef from BibleData
    static func loadVerses(for ref: ScriptureRef) -> (title: String, verses: [Verse])? {
        guard let book = BibleData.books.first(where: { $0.name.compare(ref.bookName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }),
              let chapter = book.chapters.first(where: { $0.number == ref.chapter }) else { return nil }
        let start = max(1, ref.startVerse)
        let end = ref.endVerse ?? ref.startVerse
        let lo = min(start, end)
        let hi = max(start, end)
        let selected = chapter.verses.filter { $0.number >= lo && $0.number <= hi }
        let title = "\(book.name) \(chapter.number):\(lo)\(hi != lo ? "-\(hi)" : "")"
        return (title, selected)
    }
}

