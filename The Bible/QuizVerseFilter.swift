import Foundation

/// Decides which verses make fair Bible Quiz questions.
///
/// - Verses whose exact words appear in more than one book are never asked, because
///   more than one answer would be correct ("And the LORD spake unto Moses, saying,").
/// - Timed modes skip genealogies, name lists, and census counts, which can't be told
///   apart in a few seconds (1 Chronicles 1–9, Numbers 1, Ezra 2, Luke 3).
/// - Hard (8 seconds) also skips verses too long to read in time.
///
/// Checking every verse takes a few hundred milliseconds, so it runs once per launch,
/// off the main thread, when the quiz opens (`prepare()`).
@MainActor
enum QuizVerseFilter {
    private static var analysis: VerseAnalysis?
    private static var preparation: Task<VerseAnalysis, Never>?

    /// Analyzes the Bible in the background so starting a quiz doesn't wait for it.
    static func prepare() async {
        if analysis != nil { return }
        if let preparation {
            _ = await preparation.value
            return
        }
        let books = BibleData.books
        let task = Task.detached(priority: .utility) { VerseAnalysis(books: books) }
        preparation = task
        let result = await task.value
        if analysis == nil { analysis = result }
        preparation = nil
    }

    static func isQuizzable(_ text: String, difficulty: String) -> Bool {
        let analysis = currentAnalysis()
        let key = VerseAnalysis.normalized(text)
        if analysis.repeatedInSeveralBooks.contains(key) { return false }
        guard difficulty != "easy" else { return true }
        if analysis.lists.contains(key) { return false }
        if difficulty == "hard" && analysis.tooLongForHard.contains(key) { return false }
        return true
    }

    /// The quiz can start before preparation finishes; in that case analyze right away.
    private static func currentAnalysis() -> VerseAnalysis {
        if let analysis { return analysis }
        let result = VerseAnalysis(books: BibleData.books)
        analysis = result
        return result
    }
}

/// Normalized verse texts sorted into the groups the quiz skips.
private nonisolated struct VerseAnalysis: Sendable {
    static let hardMaximumWords = 40

    var repeatedInSeveralBooks: Set<String> = []
    var lists: Set<String> = []
    var tooLongForHard: Set<String> = []

    init(books: [Book]) {
        var bookByText: [String: String] = [:]
        for book in books {
            for chapter in book.chapters {
                for verse in chapter.verses {
                    let key = Self.normalized(verse.text)
                    if let firstBook = bookByText[key] {
                        if firstBook != book.name { repeatedInSeveralBooks.insert(key) }
                        continue
                    }
                    bookByText[key] = book.name

                    let words = Self.words(in: verse.text)
                    if Self.isList(verse.text, words: words) { lists.insert(key) }
                    if words.count > Self.hardMaximumWords { tooLongForHard.insert(key) }
                }
            }
        }
    }

    static func normalized(_ text: String) -> String {
        text.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: " .,;:"))
    }

    // MARK: - Lists and genealogies

    /// Capitalized words that are common in ordinary verses and don't indicate a list.
    private static let commonCapitalized: Set<String> = [
        "And", "The", "I", "O", "LORD", "GOD", "God", "Lord", "He", "But", "For", "Now",
        "Then", "So", "In", "Thus", "Behold", "Jesus", "Christ", "Spirit", "Holy", "Israel",
        "My", "Thou", "Ye", "Let", "If", "When", "This", "These", "Therefore", "All", "Of",
        "Is", "Who", "What", "Why", "How", "Not", "A", "Wherefore", "Moreover", "Also", "Yea",
        "Lo", "Hear", "Blessed", "Woe", "Amen", "Selah", "Father", "Son", "Most", "High",
        "Almighty", "Jerusalem", "Egypt", "Moses", "David", "Lord's", "God's", "LORD's", "Israel's"
    ]

    private static let numberWords: Set<String> = [
        "thousand", "hundred", "threescore", "fourscore", "score", "twenty", "thirty",
        "forty", "fifty", "sixty", "seventy", "eighty", "ninety"
    ]

    private static func isList(_ text: String, words: [String]) -> Bool {
        let lower = Array(text.lowercased().utf8)
        if occurrences(of: "begat", in: lower) > 0 { return true }
        if occurrences(of: "son of ", in: lower) >= 2 { return true }
        if occurrences(of: "sons of ", in: lower) >= 2 { return true }
        // "Shallum his son, Mibsam his son, Mishma his son."
        let listedSons = occurrences(of: "his son,", in: lower) + occurrences(of: "his son.", in: lower)
            + occurrences(of: "his son;", in: lower) + occurrences(of: "his son:", in: lower)
        if listedSons >= 2 { return true }
        // Census totals: "threescore and two thousand and seven hundred".
        if words.filter({ numberWords.contains($0.lowercased()) }).count >= 3 { return true }

        let names = words.dropFirst().filter {
            ($0.first?.isUppercase ?? false) && !commonCapitalized.contains($0)
        }
        let nameShare = Double(names.count) / Double(max(1, words.count))
        if names.count >= 4 && nameShare >= 0.25 { return true }
        // Short name lists: "Adam, Sheth, Enosh,"
        if names.count >= 2 && nameShare >= 0.6 { return true }
        // "Of the tribe of Zebulun, Gaddiel the son of Sodi."
        if names.count >= 3 && nameShare >= 0.2 && occurrences(of: "son of", in: lower) > 0 { return true }
        return false
    }

    private static func words(in text: String) -> [String] {
        text.split { !$0.isLetter && $0 != "'" }.map(String.init)
    }

    /// Counts non-overlapping matches by comparing UTF-8 bytes, which is much faster than
    /// Foundation's string search across 31,000 verses.
    private static func occurrences(of needle: StaticString, in bytes: [UInt8]) -> Int {
        let pattern = UnsafeBufferPointer(start: needle.utf8Start, count: needle.utf8CodeUnitCount)
        guard !pattern.isEmpty, bytes.count >= pattern.count else { return 0 }
        var count = 0
        var index = 0
        let last = bytes.count - pattern.count
        while index <= last {
            if bytes[index] == pattern[0] && bytes[index..<(index + pattern.count)].elementsEqual(pattern) {
                count += 1
                index += pattern.count
            } else {
                index += 1
            }
        }
        return count
    }
}
