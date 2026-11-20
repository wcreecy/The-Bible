import Foundation

// MARK: - Answer matching

/// Turns typed text into a canonical book name and ranks autocomplete suggestions.
enum BibleBookNameMatcher {
    private static let ordinalPrefixes: [String: String] = [
        "i": "1", "1st": "1", "first": "1",
        "ii": "2", "2nd": "2", "second": "2",
        "iii": "3", "3rd": "3", "third": "3"
    ]

    /// Common alternate names, keyed and valued by normalized form.
    private static let aliases: [String: String] = [
        "psalm": "psalms",
        "songofsongs": "songofsolomon",
        "canticles": "songofsolomon",
        "revelations": "revelation",
        "actsoftheapostles": "acts"
    ]

    /// Lowercases, turns a leading "I", "II", "First", etc. into a digit, and drops spaces and punctuation.
    static func normalized(_ text: String) -> String {
        var words = text.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
        if words.count > 1, let digit = ordinalPrefixes[words[0]] {
            words[0] = digit
        }
        return words.joined()
    }

    static func canonicalName(for input: String, in bookNames: [String]) -> String? {
        var key = normalized(input)
        guard !key.isEmpty else { return nil }
        key = aliases[key] ?? key
        return bookNames.first { normalized($0) == key }
    }

    /// Books matching the typed text in canonical order: names that start with it,
    /// then names with a word that starts with it, then names that contain it.
    static func suggestions(for input: String, in bookNames: [String]) -> [String] {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = normalized(text)
        guard !key.isEmpty else { return [] }
        let lowercasedText = text.lowercased()

        var startsWith: [String] = []
        var wordStartsWith: [String] = []
        var contains: [String] = []
        for name in bookNames {
            if normalized(name).hasPrefix(key) {
                startsWith.append(name)
            } else if name.lowercased().split(separator: " ").contains(where: { $0.hasPrefix(lowercasedText) }) {
                wordStartsWith.append(name)
            } else if name.localizedCaseInsensitiveContains(text) {
                contains.append(name)
            }
        }
        return startsWith + wordStartsWith + contains
    }
}

/// Where one name is mentioned in one book: how many verses, and the first of them.
nonisolated struct BeatTheClockMention: Equatable, Sendable {
    var verseCount: Int
    let firstChapter: Int
    let firstVerse: Int
}

/// Finds every book whose text mentions a person or place by name, and where.
nonisolated enum BeatTheClockAnswerIndex {
    /// Drops a description in parentheses, e.g. "Jordan (river)" → "Jordan", then
    /// splits into lowercased words. Hyphenated names also get a joined form because
    /// the KJV usually writes them as one word ("Kadesh-barnea" → "kadeshbarnea").
    static func searchPhrases(for name: String) -> [[String]] {
        let base = name.components(separatedBy: " (").first ?? name
        var phrases = [words(in: base)]
        if base.contains("-") {
            phrases.append(words(in: base.replacingOccurrences(of: "-", with: "")))
        }
        return phrases.filter { !$0.isEmpty }
    }

    static func words(in text: String) -> [String] {
        text.lowercased().split { !$0.isLetter }.map(String.init)
    }

    static func booksMentioning(_ places: [(id: Int, name: String)], in books: [Book]) -> [Int: Set<String>] {
        mentions(of: places, in: books).mapValues { Set($0.keys) }
    }

    /// For each name, the books that mention it, with how many verses and the first one.
    static func mentions(of names: [(id: Int, name: String)], in books: [Book]) -> [Int: [String: BeatTheClockMention]] {
        // Each search phrase, with the names it stands for.
        var idsByPhrase: [String: [Int]] = [:]
        for name in names {
            for phrase in searchPhrases(for: name.name).map({ $0.joined(separator: " ") }) {
                idsByPhrase[phrase, default: []].append(name.id)
            }
        }
        let maxLength = idsByPhrase.keys.map { $0.split(separator: " ").count }.max() ?? 1
        // Only phrases that begin with one of these words can match, which keeps the work small.
        let firstWords = Set(idsByPhrase.keys.compactMap { $0.split(separator: " ").first.map(String.init) })

        var result: [Int: [String: BeatTheClockMention]] = [:]
        for book in books {
            for chapter in book.chapters {
                for verse in chapter.verses {
                    // Each verse on its own, so a multi-word name can't match across a verse boundary.
                    let verseWords = words(in: verse.text)
                    var matchedIDs: Set<Int> = []
                    for start in verseWords.indices where firstWords.contains(verseWords[start]) {
                        var phrase = verseWords[start]
                        matchedIDs.formUnion(idsByPhrase[phrase] ?? [])
                        for offset in 1..<max(maxLength, 1) where start + offset < verseWords.count {
                            phrase += " " + verseWords[start + offset]
                            matchedIDs.formUnion(idsByPhrase[phrase] ?? [])
                        }
                    }
                    for id in matchedIDs {
                        if result[id]?[book.name] != nil {
                            result[id]?[book.name]?.verseCount += 1
                        } else {
                            result[id, default: [:]][book.name] = BeatTheClockMention(
                                verseCount: 1,
                                firstChapter: chapter.number,
                                firstVerse: verse.number
                            )
                        }
                    }
                }
            }
        }
        return result
    }
}
