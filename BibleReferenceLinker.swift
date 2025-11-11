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

    /// Build a regex that matches references like "John 3:16" or "1 John 4:7-8" using known book names.
    private static func referenceRegex() -> NSRegularExpression? {
        // Build alternation of known book names from BibleData
        let bookNames = BibleData.books.map { NSRegularExpression.escapedPattern(for: $0.name) }
        guard !bookNames.isEmpty else { return nil }
        let booksAlt = bookNames.sorted { $0.count > $1.count }.joined(separator: "|")
        let pattern = "\\b((?:" + booksAlt + "))\\s+(\\d+):(\\d+)(?:-(\\d+))?\\b"
        // The pattern captures:
        // 1: Book name
        // 2: Chapter
        // 3: Start verse
        // 4: Optional end verse
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
            guard m.numberOfRanges >= 4 else { continue }
            let fullRange = m.range(at: 0)
            let bookRange = m.range(at: 1)
            let chapterRange = m.range(at: 2)
            let startRange = m.range(at: 3)
            let endRange = m.range(at: 4)
            let book = ns.substring(with: bookRange)
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
                URLQueryItem(name: "book", value: book),
                URLQueryItem(name: "chapter", value: String(chapter)),
                URLQueryItem(name: "start", value: String(start))
            ]
            if let end = end { comps.queryItems?.append(URLQueryItem(name: "end", value: String(end))) }
            guard let url = comps.url else { continue }

            if let strRange = Range(fullRange, in: text) {
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
