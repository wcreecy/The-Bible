import Foundation

struct ScriptureRef: Equatable {
    let bookName: String
    let chapter: Int
    let startVerse: Int
    let endVerse: Int?
}

enum BibleReferenceLinker {
    static var debugEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "linkifyDebugEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "linkifyDebugEnabled") }
    }
    private static func debugLog(_ msg: @autoclosure () -> String) {
        if debugEnabled { print("[Linkify] \(msg())") }
    }

    private static let scheme = "thebible-ref"

    private static let cachedRegex: NSRegularExpression? = {
        let pattern = "(^|[^A-Za-z0-9])((?:[1-3]\\s*)?[A-Za-z][A-Za-z.]*?(?:\\s+[A-Za-z.]+){0,2})\\s+(\\d+):(\\d+)(?:[\\-\\u2013\\u2014](\\d+))?"
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    private static let abbreviations: [String: String] = [
        "gen": "Genesis", "ge": "Genesis", "gn": "Genesis",
        "ex": "Exodus", "exo": "Exodus",
        "lev": "Leviticus", "lv": "Leviticus",
        "num": "Numbers", "nm": "Numbers", "nu": "Numbers",
        "deut": "Deuteronomy", "deu": "Deuteronomy", "dt": "Deuteronomy",
        "jos": "Joshua", "josh": "Joshua",
        "judg": "Judges", "jdg": "Judges",
        "rut": "Ruth", "ru": "Ruth",
        "sam": "Samuel", "sa": "Samuel",
        "kgs": "Kings", "kg": "Kings",
        "chron": "Chronicles", "chr": "Chronicles",
        "ezr": "Ezra",
        "neh": "Nehemiah", "ne": "Nehemiah",
        "est": "Esther",
        "job": "Job",
        "ps": "Psalms", "psa": "Psalms", "psalm": "Psalms",
        "prov": "Proverbs", "pr": "Proverbs",
        "eccl": "Ecclesiastes", "ecc": "Ecclesiastes",
        "song": "Song of Solomon", "so": "Song of Solomon", "sos": "Song of Solomon",
        "isa": "Isaiah",
        "jer": "Jeremiah",
        "lam": "Lamentations",
        "eze": "Ezekiel", "ezek": "Ezekiel",
        "dan": "Daniel",
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
        "mat": "Matthew", "mt": "Matthew",
        "mk": "Mark", "mrk": "Mark",
        "lk": "Luke",
        "jn": "John", "jhn": "John",
        "act": "Acts", "acts": "Acts",
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
        "jas": "James",
        "pet": "Peter", "petr": "Peter",
        "joh": "John",
        "jud": "Jude",
        "rev": "Revelation"
    ]

    private static func insertSpaceBetweenLeadingDigitsAndLetters(in s: String) -> String {
        guard let first = s.first, first.isNumber else { return s }
        let digits = String(s.prefix { $0.isNumber })
        let rest = String(s.drop { $0.isNumber })
        if rest.first?.isLetter == true { return digits + " " + rest }
        return s
    }

    private static func resolveBook(named raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let direct = BibleData.books.first(where: { $0.name.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            return direct.name
        }
        let spaced = insertSpaceBetweenLeadingDigitsAndLetters(in: trimmed)
        let cleaned = spaced.replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        let tokens = cleaned.split { $0.isWhitespace }.map { String($0) }
        let mapped = tokens.map { t -> String in
            let lower = t.lowercased()
            if let exp = abbreviations[lower] { return exp }
            if Int(lower) != nil { return t }
            return t.prefix(1).uppercased() + t.dropFirst().lowercased()
        }
        let candidate = mapped.joined(separator: " ")
        if let match = BibleData.books.first(where: { $0.name.compare(candidate, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            return match.name
        }
        let collapsed = candidate.replacingOccurrences(of: " ", with: "")
        if let match = BibleData.books.first(where: { $0.name.replacingOccurrences(of: " ", with: "").compare(collapsed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            return match.name
        }
        return nil
    }

    // Return (resolvedName, leadingCharactersToSkipInsideRaw)
    private static func resolveBookBySuffixPeeling(raw: String) -> (String, Int)? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let direct = resolveBook(named: trimmed) {
            // No skip needed; we used the full raw
            // Compute skip as difference between raw's leading whitespace and trimmed's
            let skip = raw.distance(from: raw.startIndex, to: trimmed.startIndex)
            return (direct, skip)
        }
        // Work with original raw to compute byte/utf16 offsets reliably
        // Tokenize by whitespace on the original raw
        let rawChars = Array(raw)
        // Build tokens with their start indices in raw
        var tokens: [(text: String, start: Int, end: Int)] = []
        var i = 0
        let n = rawChars.count
        while i < n {
            // skip spaces
            while i < n, rawChars[i].isWhitespace { i += 1 }
            if i >= n { break }
            let start = i
            while i < n, !rawChars[i].isWhitespace { i += 1 }
            let end = i
            if start < end {
                let t = String(rawChars[start..<end])
                tokens.append((t, start, end))
            }
        }
        guard tokens.count > 1 else { return nil }
        // Try suffixes tokens[k...]
        for k in 0..<tokens.count {
            let candidate = tokens[k...].map { $0.text }.joined(separator: " ")
            if let resolved = resolveBook(named: candidate) {
                // leading skip in raw is tokens[k].start
                let skip = tokens[k].start
                return (resolved, skip)
            }
        }
        return nil
    }

    static func linkify(_ text: String) -> AttributedString {
        debugLog("Input: “\(text)”")
        var attributed = AttributedString(text)
        guard let regex = cachedRegex else {
            debugLog("No regex compiled.")
            return attributed
        }
        let ns = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
        debugLog("Found \(matches.count) candidate matches")

        for m in matches.reversed() {
            guard m.numberOfRanges >= 6 else {
                debugLog("Match missing expected ranges")
                continue
            }
            let bookRange = m.range(at: 2)
            let chapterRange = m.range(at: 3)
            let startRange = m.range(at: 4)
            let endRange = m.range(at: 5)

            let rawBook = ns.substring(with: bookRange)

            var resolvedBook: String? = resolveBook(named: rawBook)
            var innerSkip: Int = 0
            if resolvedBook == nil {
                if let (peeled, skip) = resolveBookBySuffixPeeling(raw: rawBook) {
                    resolvedBook = peeled
                    innerSkip = skip
                    debugLog("Resolved with suffix peeling: “\(rawBook)” -> “\(peeled)” (skip \(skip))")
                } else {
                    debugLog("Could not resolve book token: “\(rawBook)”")
                    continue
                }
            }

            let chapStr = ns.substring(with: chapterRange)
            let startStr = ns.substring(with: startRange)
            let endStr: String? = endRange.location != NSNotFound ? ns.substring(with: endRange) : nil
            guard let chapter = Int(chapStr) else {
                debugLog("Invalid chapter int: “\(chapStr)” for book \(resolvedBook!)")
                continue
            }
            guard let start = Int(startStr) else {
                debugLog("Invalid start verse int: “\(startStr)” for \(resolvedBook!) \(chapter)")
                continue
            }
            let end = endStr.flatMap { Int($0) }

            var comps = URLComponents()
            comps.scheme = scheme
            comps.host = "ref"
            comps.queryItems = [
                URLQueryItem(name: "book", value: resolvedBook!),
                URLQueryItem(name: "chapter", value: String(chapter)),
                URLQueryItem(name: "start", value: String(start))
            ]
            if let end = end { comps.queryItems?.append(URLQueryItem(name: "end", value: String(end))) }
            guard let url = comps.url else {
                debugLog("Failed to build URL for \(resolvedBook!) \(chapter):\(start)\(end != nil ? "-\(end!)" : "")")
                continue
            }

            // Adjust link start inside the captured book range by innerSkip
            let adjustedBookStart = bookRange.location + innerSkip
            // Determine last numeric range
            let lastNumericRange: NSRange = (endRange.location != NSNotFound) ? endRange : startRange
            let linkStart = adjustedBookStart
            let linkEndExclusive = lastNumericRange.location + lastNumericRange.length
            let linkLength = max(0, linkEndExclusive - linkStart)
            guard linkLength > 0 else {
                debugLog("Computed zero-length link range for \(resolvedBook!) \(chapter)")
                continue
            }
            let fullLinkRange = NSRange(location: linkStart, length: linkLength)

            if let strRange = Range(fullLinkRange, in: text),
               let lower = AttributedString.Index(strRange.lowerBound, within: attributed),
               let upper = AttributedString.Index(strRange.upperBound, within: attributed) {
                let attrRange: Range<AttributedString.Index> = lower..<upper
                attributed[attrRange].link = url
                debugLog("Linked “\(ns.substring(with: fullLinkRange))” -> \(url.absoluteString)")
            } else {
                debugLog("Failed to convert NSRange to String Range for link")
            }
        }
        return attributed
    }

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
