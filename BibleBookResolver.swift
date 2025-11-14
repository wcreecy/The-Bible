import Foundation

enum BibleBookResolver {
    // Map common abbreviations to canonical forms
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

    private static func insertSpaceBetweenLeadingDigitsAndLetters(in s: String) -> String {
        guard let first = s.first, first.isNumber else { return s }
        let digits = String(s.prefix { $0.isNumber })
        let rest = String(s.drop { $0.isNumber })
        if rest.first?.isLetter == true { return digits + " " + rest }
        return s
    }

    static func resolveBook(named raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // Direct match
        if let direct = BibleData.books.first(where: { $0.name.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            return direct.name
        }
        // Insert space for ordinals like "1kgs"
        let spaced = insertSpaceBetweenLeadingDigitsAndLetters(in: trimmed)
        let cleaned = spaced.replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        var tokens = cleaned.split { $0.isWhitespace }.map { String($0) }
        let mapped = tokens.enumerated().map { (_, t) -> String in
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
}
