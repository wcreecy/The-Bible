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

    // NOTE: Keys must be lowercase. For numbered books, only map the word part (e.g., "cor" -> "Corinthians").
    private static let abbreviations: [String: String] = [
        // Genesis
        "gen": "Genesis", "ge": "Genesis", "gn": "Genesis",

        // Exodus
        "exo": "Exodus", "ex": "Exodus",

        // Leviticus
        "lev": "Leviticus", "levi": "Leviticus", "lv": "Leviticus",

        // Numbers
        "num": "Numbers", "numb": "Numbers", "nm": "Numbers", "nu": "Numbers",

        // Deuteronomy
        "deu": "Deuteronomy", "deut": "Deuteronomy", "dt": "Deuteronomy",

        // Joshua
        "jos": "Joshua", "josh": "Joshua",

        // Judges
        "judg": "Judges", "jdg": "Judges", 

        // Ruth
        "rut": "Ruth", "ru": "Ruth",

        // Samuel (handles 1/2 via leading number)
        "sam": "Samuel", "samu": "Samuel", "sa": "Samuel",

        // Kings (handles 1/2 via leading number)
        "kin": "Kings", "king": "Kings", "kgs": "Kings", "kg": "Kings",

        // Chronicles (handles 1/2 via leading number)
        "chron": "Chronicles", "chroni": "Chronicles", "chr": "Chronicles",

        // Ezra
        "ezr": "Ezra", "ez": "Ezra",

        // Nehemiah
        "neh": "Nehemiah", "nehe": "Nehemiah", "ne": "Nehemiah",

        // Esther
        "est": "Esther",

        // Job
        "job": "Job",

        // Psalms
        "ps": "Psalms", "psa": "Psalms", "psalm": "Psalms",

        // Proverbs
        "prov": "Proverbs", "proverb": "Proverbs", "pr": "Proverbs",

        // Ecclesiastes
        "ecc": "Ecclesiastes", "eccl": "Ecclesiastes", "eccle": "Ecclesiastes",

        // Song of Solomon
        "song": "Song of Solomon", "so": "Song of Solomon", "sos": "Song of Solomon",

        // Isaiah
        "isa": "Isaiah", "isaia": "Isaiah",

        // Jeremiah
        "jer": "Jeremiah", "jerem": "Jeremiah",

        // Lamentations
        "lam": "Lamentations", "lamen": "Lamentations",

        // Ezekiel
        "eze": "Ezekiel", "ezek": "Ezekiel", "zeke": "Ezekiel", "exek": "Ezekiel",

        // Daniel
        "dan": "Daniel", "dani": "Daniel",

        // Hosea
        "hos": "Hosea",

        // Joel
        "joe": "Joel",

        // Amos
        "amo": "Amos",

        // Obadiah
        "ob": "Obadiah", "oba": "Obadiah", "obad": "Obadiah",

        // Jonah
        "jon": "Jonah", "jona": "Jonah",

        // Micah
        "mic": "Micah",

        // Nahum
        "na": "Nahum", "nah": "Nahum",

        // Habakkuk
        "hab": "Habakkuk", "habak": "Habakkuk", "habakk": "Habakkuk", "habakka": "Habakkuk",

        // Zephaniah
        "zep": "Zephaniah", "zeph": "Zephaniah",

        // Haggai
        "hag": "Haggai", "hagg": "Haggai", "hagga": "Haggai",

        // Zechariah
        "zec": "Zechariah", "zech": "Zechariah", "zecha": "Zechariah",

        // Malachi
        "mal": "Malachi", "mala": "Malachi", "malac": "Malachi",

        // Matthew
        "mat": "Matthew", "mt": "Matthew", "matt": "Matthew", "matth": "Matthew",

        // Mark
        "mk": "Mark", "mrk": "Mark", "mar": "Mark",

        // Luke
        "lk": "Luke", "luk": "Luke",

        // John (Gospel)
        "jn": "John", "jhn": "John", 

        // Acts
        "act": "Acts", "acts": "Acts",

        // Romans
        "rom": "Romans", "roma": "Romans",

        // Corinthians (handles 1/2 via leading number)
        "cor": "Corinthians", "corinth": "Corinthians", "corin": "Corinthians",

        // Galatians
        "gal": "Galatians", "gala": "Galatians", "galat": "Galatians",

        // Ephesians
        "eph": "Ephesians", "ephe": "Ephesians", "ephes": "Ephesians",

        // Philippians
        "phil": "Philippians", "phill": "Philippians", "philip": "Philippians",

        // Colossians
        "col": "Colossians", "colo": "Colossians", "coloss": "Colossians",

        // Thessalonians (handles 1/2 via leading number)
        "thess": "Thessalonians", "thes": "Thessalonians",

        // Timothy (handles 1/2 via leading number)
        "tim": "Timothy", "timo": "Timothy",

        // Titus
        "tit": "Titus",

        // Philemon
        "phm": "Philemon", "phile": "Philemon",

        // Hebrews
        "heb": "Hebrews", "hebr": "Hebrews",

        // James
        "jas": "James", "jam": "James", "jame": "James",

        // Peter (handles 1/2 via leading number)
        "pet": "Peter", "pete": "Peter", "petr": "Peter",

        // John (Epistles; handles 1/2/3 via leading number)
        "jo": "John", "joh": "John",

        // Jude
        "jud": "Jude",

        // Revelation
        "rev": "Revelation", "revel": "Revelation", "revelations": "Revelation"
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
            let skip = raw.distance(from: raw.startIndex, to: trimmed.startIndex)
            return (direct, skip)
        }
        let rawChars = Array(raw)
        var tokens: [(text: String, start: Int, end: Int)] = []
        var i = 0
        let n = rawChars.count
        while i < n {
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
        for k in 0..<tokens.count {
            let candidate = tokens[k...].map { $0.text }.joined(separator: " ")
            if let resolved = resolveBook(named: candidate) {
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

            let adjustedBookStart = bookRange.location + innerSkip
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
