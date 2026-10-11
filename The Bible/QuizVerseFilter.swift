import Foundation

/// Decides which verses make fair Bible Quiz questions.
///
/// - Verses whose words appear in more than one book are never asked, because more than
///   one answer would be correct ("And the LORD spake unto Moses, saying,"). Punctuation
///   is ignored, and near-copies count too, such as parallels between Matthew and Luke.
/// - Genealogies, name lists, census counts, and verses under six words are skipped,
///   since they can't be placed (1 Chronicles 1–9, Numbers 1, "Abram; the same Abraham.").
/// - Hard also skips verses too long to read in its time limit.
///
/// Checking every verse takes a moment, so it runs once per launch, off the main thread,
/// when the quiz opens (`prepare()`). The quiz waits for it before starting.
@MainActor
enum QuizVerseFilter {
    private static var analysis: VerseAnalysis?
    private static var preparation: Task<VerseAnalysis, Never>?

    static var isReady: Bool { analysis != nil }

    /// Analyzes the Bible in the background so the quiz never does it on the main thread.
    static func prepare() async {
        if analysis != nil { return }
        if let preparation {
            _ = await preparation.value
            return
        }
        let task = Task.detached(priority: .userInitiated) {
            VerseAnalysis(books: await BibleRepository.shared.loadAllBooks())
        }
        preparation = task
        let result = await task.value
        if analysis == nil { analysis = result }
        preparation = nil
    }

    /// `chapter` and `verse` are 1-based. Before `prepare()` finishes, every verse passes.
    static func isQuizzable(book: String, chapter: Int, verse: Int, difficulty: String) -> Bool {
        guard let analysis else { return true }
        let flags = analysis.flags(book: book, chapter: chapter, verse: verse)
        if !flags.isDisjoint(with: [.repeated, .nearDuplicate, .list, .tooShort]) { return false }
        if difficulty == "hard" && flags.contains(.tooLongForHard) { return false }
        return true
    }
}

/// Reasons each verse may be skipped, stored by book, chapter, and verse.
private nonisolated struct VerseAnalysis: Sendable {
    struct Flags: OptionSet, Sendable {
        let rawValue: UInt8

        static let repeated = Flags(rawValue: 1 << 0)
        static let nearDuplicate = Flags(rawValue: 1 << 1)
        static let list = Flags(rawValue: 1 << 2)
        static let tooShort = Flags(rawValue: 1 << 3)
        static let tooLongForHard = Flags(rawValue: 1 << 4)
    }

    static let minimumWords = 6
    static let hardMaximumWords = 35
    /// A verse is a near-copy when this share of its four-word phrases appear in one verse of another book.
    static let nearDuplicateShare = 0.8
    /// Phrases found in more verses than this ("and it came to") say nothing about the source.
    static let commonPhraseLimit = 40

    private var flagsByBook: [String: [[Flags]]] = [:]

    func flags(book: String, chapter: Int, verse: Int) -> Flags {
        guard let chapters = flagsByBook[book], chapters.indices.contains(chapter - 1) else { return [] }
        let verses = chapters[chapter - 1]
        return verses.indices.contains(verse - 1) ? verses[verse - 1] : []
    }

    init(books: [Book]) {
        var flags: [[[Flags]]] = []
        var locations: [(book: Int, chapter: Int, verse: Int)] = []
        var texts: [String] = []
        var phrases: [[UInt64]] = []
        var bookByText: [String: Int] = [:]
        var vocabulary: [String: UInt64] = [:]
        let multipleBooks = -1

        for (bookIndex, book) in books.enumerated() {
            var bookFlags: [[Flags]] = []
            for (chapterIndex, chapter) in book.chapters.enumerated() {
                var chapterFlags: [Flags] = []
                for (verseIndex, verse) in chapter.verses.enumerated() {
                    let lowercased = Self.lowercasedWords(in: verse.text)
                    let text = lowercased.joined(separator: " ")
                    if let firstBook = bookByText[text], firstBook != bookIndex {
                        bookByText[text] = multipleBooks
                    } else if bookByText[text] == nil {
                        bookByText[text] = bookIndex
                    }

                    var verseFlags: Flags = []
                    let words = Self.words(in: verse.text)
                    if Self.isList(verse.text, words: words) { verseFlags.insert(.list) }
                    if words.count < Self.minimumWords { verseFlags.insert(.tooShort) }
                    if words.count > Self.hardMaximumWords { verseFlags.insert(.tooLongForHard) }
                    chapterFlags.append(verseFlags)

                    // Each four-word phrase packs four 16-bit word IDs into one number.
                    let ids = lowercased.map { word -> UInt64 in
                        if let id = vocabulary[word] { return id }
                        let id = UInt64(vocabulary.count) & 0xFFFF
                        vocabulary[word] = id
                        return id
                    }
                    var versePhrases: Set<UInt64> = []
                    if ids.count >= 4 {
                        for start in 0...(ids.count - 4) {
                            versePhrases.insert(ids[start] << 48 | ids[start + 1] << 32 | ids[start + 2] << 16 | ids[start + 3])
                        }
                    }

                    locations.append((bookIndex, chapterIndex, verseIndex))
                    texts.append(text)
                    phrases.append(Array(versePhrases))
                }
                bookFlags.append(chapterFlags)
            }
            flags.append(bookFlags)
        }

        var versesByPhrase: [UInt64: [Int32]] = [:]
        for (index, versePhrases) in phrases.enumerated() {
            for phrase in versePhrases {
                versesByPhrase[phrase, default: []].append(Int32(index))
            }
        }

        for (index, location) in locations.enumerated() {
            if bookByText[texts[index]] == multipleBooks {
                flags[location.book][location.chapter][location.verse].insert(.repeated)
                continue
            }

            let telling = phrases[index].compactMap { versesByPhrase[$0] }.filter { $0.count <= Self.commonPhraseLimit }
            guard telling.count >= 3 else { continue }
            var shared: [Int32: Int] = [:]
            for verses in telling {
                for other in verses where locations[Int(other)].book != location.book {
                    shared[other, default: 0] += 1
                }
            }
            if let most = shared.values.max(), Double(most) >= Self.nearDuplicateShare * Double(telling.count) {
                flags[location.book][location.chapter][location.verse].insert(.nearDuplicate)
            }
        }

        for (bookIndex, book) in books.enumerated() {
            flagsByBook[book.name] = flags[bookIndex]
        }
    }

    /// Lowercased words with punctuation removed, so "saying," and "saying:" match.
    private static func lowercasedWords(in text: String) -> [String] {
        text.lowercased().split { !$0.isLetter }.map(String.init)
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
