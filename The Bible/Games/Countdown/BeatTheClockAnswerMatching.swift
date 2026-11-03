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

/// Finds every book whose text mentions a place by name.
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
        let phrasesByPlace = places.map { place in
            (id: place.id, phrases: searchPhrases(for: place.name).map { $0.joined(separator: " ") })
        }
        let allPhrases = phrasesByPlace.flatMap(\.phrases)
        let maxLength = allPhrases.map { $0.split(separator: " ").count }.max() ?? 1
        // Only phrases that begin with one of these words can match, which keeps the index small.
        let firstWords = Set(allPhrases.compactMap { $0.split(separator: " ").first.map(String.init) })

        var result: [Int: Set<String>] = [:]
        for book in books {
            let bookWords = book.chapters.flatMap { chapter in
                chapter.verses.flatMap { words(in: $0.text) }
            }

            var bookPhrases: Set<String> = []
            for start in bookWords.indices where firstWords.contains(bookWords[start]) {
                var phrase = bookWords[start]
                bookPhrases.insert(phrase)
                for offset in 1..<maxLength where start + offset < bookWords.count {
                    phrase += " " + bookWords[start + offset]
                    bookPhrases.insert(phrase)
                }
            }

            for place in phrasesByPlace where place.phrases.contains(where: bookPhrases.contains) {
                result[place.id, default: []].insert(book.name)
            }
        }
        return result
    }
}
