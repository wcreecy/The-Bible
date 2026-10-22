import Foundation
import OSLog

nonisolated private let bibleDataLogger = Logger(
    subsystem: "The Bible",
    category: "BibleData"
)

private nonisolated final class BibleCorpusCache: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Book] = []

    var books: [Book] {
        lock.withLock { storage }
    }

    func store(_ books: [Book]) {
        lock.withLock { storage = books }
    }
}

actor BibleRepository {
    static let shared = BibleRepository()

    private nonisolated let cache = BibleCorpusCache()
    private var loadTask: Task<[Book], Never>?

    nonisolated var cachedBooks: [Book] {
        cache.books
    }

    func loadAllBooks() async -> [Book] {
        let cached = cache.books
        if !cached.isEmpty { return cached }
        if let loadTask { return await loadTask.value }

        let resourceURL = Bundle.main.url(forResource: "kjv", withExtension: "json")
        let task = Task.detached(priority: .userInitiated) {
            guard let resourceURL else {
                bibleDataLogger.error("The bundled Bible corpus resource is missing; using fallback data.")
                return BibleData.fallbackBooks
            }
            do {
                let data = try Data(contentsOf: resourceURL, options: .mappedIfSafe)
                return try BibleData.decodeBooks(from: data)
            } catch {
                bibleDataLogger.error("Failed to load the bundled Bible corpus; using fallback data. Error: \(String(describing: error), privacy: .public)")
                return BibleData.fallbackBooks
            }
        }
        loadTask = task
        let books = await AppPerformance.measure("BibleDataLoad") { await task.value }
        cache.store(books)
        loadTask = nil
        return books
    }

    func loadBook(named name: String) async -> Book? {
        await loadAllBooks().first { $0.name == name }
    }

    func bookNames() async -> [String] {
        await loadAllBooks().map(\.name)
    }
}

struct Verse: Identifiable, Hashable, Sendable {
    // Stable, allocation-free ID derived from verse number within a chapter
    var id: String { "\(number)" }
    let number: Int
    /// Verse text with the source's translator markup removed (see `KJVTextCleaner`).
    let text: String
    /// UTF-16 ranges in `text` spoken by Jesus.
    let redLetterRanges: [Range<Int>]
    /// UTF-16 ranges in `text` of words the KJV translators supplied (printed in italics).
    let suppliedWordRanges: [Range<Int>]

    nonisolated init(number: Int, text: String) {
        self.number = number
        let cleaned = KJVTextCleaner.clean(text)
        self.text = cleaned.text
        self.redLetterRanges = cleaned.redLetterRanges
        self.suppliedWordRanges = cleaned.suppliedWordRanges
    }
}

/// Removes the KJV source's markup in one pass so verse text reads cleanly everywhere,
/// recording where the marked words were:
/// - U+E000…U+E001 bracket the words of Jesus → `redLetterRanges`.
/// - `{are}`-style braces mark words the translators supplied → kept, `suppliedWordRanges`.
/// - `{word: or, alternative}`-style braces are footnotes → removed.
/// Ranges are UTF-16 offsets into the cleaned text.
nonisolated enum KJVTextCleaner {
    struct Result {
        let text: String
        let redLetterRanges: [Range<Int>]
        let suppliedWordRanges: [Range<Int>]
    }

    private static let redLetterStart: Character = "\u{E000}"
    private static let redLetterEnd: Character = "\u{E001}"

    static func clean(_ raw: String) -> Result {
        // Fast path for verses without markup.
        guard raw.contains(where: { $0 == "{" || $0 == "}" || $0 == redLetterStart || $0 == redLetterEnd }) else {
            return Result(text: raw, redLetterRanges: [], suppliedWordRanges: [])
        }

        let characters = Array(raw)
        var output: [Character] = []
        var length = 0  // UTF-16 length of `output`
        var supplied: [Range<Int>] = []
        var redLetter: [Range<Int>] = []
        var redLetterOpen: Int?
        // Length right after the most recent footnote while only plain text has followed it.
        // A stray "}" then means the footnote ran on, so that text is dropped.
        var lengthAfterFootnote: (characters: Int, utf16: Int)?

        func append(_ character: Character) {
            let next: Character
            if character.isWhitespace {
                guard let last = output.last, !last.isWhitespace else { return }
                next = " "
            } else {
                next = character
            }
            output.append(next)
            length += next.utf16.count
        }

        func removeTrailingWhitespace() {
            while let last = output.last, last.isWhitespace {
                output.removeLast()
                length -= last.utf16.count
            }
        }

        var index = 0
        while index < characters.count {
            let character = characters[index]

            if character == redLetterStart {
                redLetterOpen = length
                index += 1
                continue
            }
            if character == redLetterEnd {
                if let start = redLetterOpen, length > start { redLetter.append(start..<length) }
                redLetterOpen = nil
                index += 1
                continue
            }

            if character == "{", let close = matchingBrace(in: characters, openingAt: index) {
                let content = characters[(index + 1)..<close]
                if content.contains(":") {
                    // Footnote: drop it along with the space before it.
                    removeTrailingWhitespace()
                    lengthAfterFootnote = (output.count, length)
                } else {
                    let start = length
                    for inner in content where inner != "{" && inner != "}" {
                        append(inner)
                    }
                    if length > start { supplied.append(start..<length) }
                    lengthAfterFootnote = nil
                }
                index = close + 1
                continue
            }

            if character == "{" || character == "}" {
                // Unbalanced brace. After a footnote it marks text that leaked out of it.
                if character == "}", let saved = lengthAfterFootnote {
                    output.removeLast(output.count - saved.characters)
                    length = saved.utf16
                }
                lengthAfterFootnote = nil
                index += 1
                continue
            }

            append(character)
            index += 1
        }

        removeTrailingWhitespace()
        if let start = redLetterOpen, length > start { redLetter.append(start..<length) }

        func clamped(_ ranges: [Range<Int>]) -> [Range<Int>] {
            ranges.compactMap { range in
                let upper = min(range.upperBound, length)
                return upper > range.lowerBound ? range.lowerBound..<upper : nil
            }
        }
        return Result(
            text: String(output),
            redLetterRanges: clamped(redLetter),
            suppliedWordRanges: clamped(supplied)
        )
    }

    /// Index of the brace closing the one at `openIndex`, allowing nested braces.
    private static func matchingBrace(in characters: [Character], openingAt openIndex: Int) -> Int? {
        var depth = 0
        for index in openIndex..<characters.count {
            if characters[index] == "{" { depth += 1 }
            if characters[index] == "}" {
                depth -= 1
                if depth == 0 { return index }
            }
        }
        return nil
    }
}

struct Chapter: Identifiable, Hashable, Sendable {
    // Stable, allocation-free ID derived from chapter number within a book
    var id: String { "\(number)" }
    let number: Int
    let verses: [Verse]
}

struct Book: Identifiable, Hashable, Sendable {
    // Stable, allocation-free ID derived from the book name
    var id: String { name }
    let name: String
    let chapters: [Chapter]
}

// DTOs matching the provided KJV JSON structure: [{ abbrev: String, chapters: [[String]], name?: String }]
private struct KJVBookDTO: Decodable {
    let abbrev: String
    let chapters: [[String]]
    let name: String?
}

private nonisolated enum BookNames {
    // Map common abbreviations to full names.
    static let map: [String: String] = [
        // Old Testament
        "gn": "Genesis", "ex": "Exodus", "lev": "Leviticus", "num": "Numbers", "de": "Deuteronomy",
        "jos": "Joshua", "jdg": "Judges", "ru": "Ruth",
        "1sa": "1 Samuel", "2sa": "2 Samuel",
        "1ki": "1 Kings", "2ki": "2 Kings",
        "1ch": "1 Chronicles", "2ch": "2 Chronicles",
        "ezr": "Ezra", "ne": "Nehemiah", "es": "Esther",
        "job": "Job", "ps": "Psalms", "pr": "Proverbs", "ec": "Ecclesiastes", "so": "Song of Solomon",
        "is": "Isaiah", "je": "Jeremiah", "la": "Lamentations", "eze": "Ezekiel", "da": "Daniel",
        "ho": "Hosea", "joe": "Joel", "am": "Amos", "ob": "Obadiah", "jon": "Jonah",
        "mic": "Micah", "na": "Nahum", "hab": "Habakkuk", "zep": "Zephaniah",
        "hag": "Haggai", "zec": "Zechariah", "mal": "Malachi",
        // New Testament
        "mt": "Matthew", "mr": "Mark", "lu": "Luke", "joh": "John",
        "ac": "Acts", "ro": "Romans",
        "1co": "1 Corinthians", "2co": "2 Corinthians",
        "ga": "Galatians", "eph": "Ephesians", "php": "Philippians", "col": "Colossians",
        "1th": "1 Thessalonians", "2th": "2 Thessalonians",
        "1ti": "1 Timothy", "2ti": "2 Timothy",
        "tit": "Titus", "phm": "Philemon",
        "heb": "Hebrews", "jas": "James",
        "1pe": "1 Peter", "2pe": "2 Peter",
        "1jo": "1 John", "2jo": "2 John", "3jo": "3 John",
        "jude": "Jude", "re": "Revelation"
    ]

    static func fullName(for abbrev: String) -> String {
        map[abbrev.lowercased()] ?? abbrev.uppercased()
    }
}

enum BibleData {
    // Compatibility view for synchronous call sites. It never performs I/O or decoding;
    // the repository is the sole owner of the corpus and publishes this snapshot.
    static var books: [Book] {
        BibleRepository.shared.cachedBooks
    }

    nonisolated static func decodeBooks(from data: Data) throws -> [Book] {
        let dtoBooks = try JSONDecoder().decode([KJVBookDTO].self, from: data)
        return dtoBooks.map { dto in
            let fullName = dto.name ?? BookNames.fullName(for: dto.abbrev)
            return Book(
                name: fullName,
                chapters: dto.chapters.enumerated().map { chapterIndex, versesArray in
                    Chapter(
                        number: chapterIndex + 1,
                        verses: versesArray.enumerated().map { verseIndex, text in
                            Verse(number: verseIndex + 1, text: text)
                        }
                    )
                }
            )
        }
    }

    nonisolated static let fallbackBooks: [Book] = [
            Book(
                name: "Genesis",
                chapters: [
                    Chapter(number: 1, verses: (1...31).map { Verse(number: $0, text: "Genesis 1:\($0) text") }),
                    Chapter(number: 2, verses: (1...25).map { Verse(number: $0, text: "Genesis 2:\($0) text") }),
                    Chapter(number: 3, verses: (1...24).map { Verse(number: $0, text: "Genesis 3:\($0) text") })
                ]
            ),
            Book(
                name: "Exodus",
                chapters: [
                    Chapter(number: 1, verses: (1...22).map { Verse(number: $0, text: "Exodus 1:\($0) text") }),
                    Chapter(number: 2, verses: (1...25).map { Verse(number: $0, text: "Exodus 2:\($0) text") })
                ]
            ),
            Book(
                name: "Matthew",
                chapters: [
                    Chapter(number: 1, verses: (1...25).map { Verse(number: $0, text: "Matthew 1:\($0) text") }),
                    Chapter(number: 2, verses: (1...23).map { Verse(number: $0, text: "Matthew 2:\($0) text") })
                ]
            )
    ]
}
