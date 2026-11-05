import Foundation
import OSLog

nonisolated private let bibleDataLogger = Logger(
    subsystem: "The Bible",
    category: "BibleData"
)

/// The loaded Bible text, by translation. Readable from any thread, so `BibleData.books`
/// can stay synchronous.
private nonisolated final class BibleCorpusCache: @unchecked Sendable {
    private let lock = NSLock()
    private var active: BibleTranslation = BibleTranslation.saved
    private var storage: [BibleTranslation: [Book]] = [:]
    private var failed: Set<BibleTranslation> = []

    var activeTranslation: BibleTranslation {
        lock.withLock { active }
    }

    /// The active translation's books, or none until they load.
    var books: [Book] {
        lock.withLock { storage[active] ?? [] }
    }

    var loadFailed: Bool {
        lock.withLock { failed.contains(active) }
    }

    func books(for translation: BibleTranslation) -> [Book] {
        lock.withLock { storage[translation] ?? [] }
    }

    func store(_ books: [Book], for translation: BibleTranslation) {
        lock.withLock {
            if books.isEmpty {
                failed.insert(translation)
            } else {
                storage[translation] = books
                failed.remove(translation)
            }
        }
    }

    /// Makes a loaded translation active and drops the others, so only one Bible stays in memory.
    func activate(_ translation: BibleTranslation) {
        lock.withLock {
            active = translation
            storage = storage.filter { $0.key == translation }
        }
    }
}

actor BibleRepository {
    static let shared = BibleRepository()

    private nonisolated let cache = BibleCorpusCache()
    private var loadTasks: [BibleTranslation: Task<[Book], Never>] = [:]

    /// The translation `loadAllBooks()` and `BibleData.books` return.
    nonisolated var activeTranslation: BibleTranslation {
        cache.activeTranslation
    }

    nonisolated var cachedBooks: [Book] {
        cache.books
    }

    /// A translation's books if they're in memory. Only the active translation stays loaded.
    nonisolated func cachedBooks(for translation: BibleTranslation) -> [Book] {
        cache.books(for: translation)
    }

    /// Whether the last load found no usable Bible text. The next load tries again.
    nonisolated var loadFailed: Bool {
        cache.loadFailed
    }

    /// The active translation's books.
    func loadAllBooks() async -> [Book] {
        await loadAllBooks(for: cache.activeTranslation)
    }

    func loadAllBooks(for translation: BibleTranslation) async -> [Book] {
        let cached = cache.books(for: translation)
        if !cached.isEmpty { return cached }
        if let task = loadTasks[translation] { return await task.value }

        let task = Task.detached(priority: .userInitiated) {
            Self.decodeBundledBooks(for: translation)
        }
        loadTasks[translation] = task
        let books = await AppPerformance.measure("BibleDataLoad") { await task.value }
        cache.store(books, for: translation)
        loadTasks[translation] = nil
        return books
    }

    /// A translation's books for a one-time job, such as checking a catalog written against the
    /// KJV's spellings. Unlike `loadAllBooks(for:)` it keeps nothing in memory afterward, so a
    /// second whole Bible doesn't stay loaded.
    func loadBooksWithoutCaching(for translation: BibleTranslation) async -> [Book] {
        let cached = cache.books(for: translation)
        if !cached.isEmpty { return cached }
        return await Task.detached(priority: .userInitiated) {
            Self.decodeBundledBooks(for: translation)
        }.value
    }

    /// Reads a bundled translation, pre-cleaned by Scripts/clean_kjv (KJV) or
    /// Scripts/build_translation.py (the others). No books means the load failed; screens
    /// show an error instead of placeholder text.
    private nonisolated static func decodeBundledBooks(for translation: BibleTranslation) -> [Book] {
        guard let resourceURL = Bundle.main.url(forResource: translation.resourceName, withExtension: "json") else {
            bibleDataLogger.error("The bundled \(translation.abbreviation, privacy: .public) text is missing.")
            return []
        }
        do {
            let data = try Data(contentsOf: resourceURL, options: .mappedIfSafe)
            return try BibleData.decodeBooks(from: data)
        } catch {
            bibleDataLogger.error("Failed to load the bundled \(translation.abbreviation, privacy: .public) text. Error: \(String(describing: error), privacy: .public)")
            return []
        }
    }

    /// Loads a translation, then makes it the active one and saves the choice.
    /// Returns its books, or none (keeping the current translation) when it can't be read.
    func activate(_ translation: BibleTranslation) async -> [Book] {
        let books = await loadAllBooks(for: translation)
        guard !books.isEmpty else { return [] }
        cache.activate(translation)
        BibleTranslation.save(translation)
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
    /// Empty when the translation leaves the verse out (some omit Matthew 17:21, Acts 8:37, …).
    let text: String
    /// UTF-16 ranges in `text` spoken by Jesus.
    let redLetterRanges: [Range<Int>]
    /// UTF-16 ranges in `text` of words the KJV translators supplied (printed in italics).
    let suppliedWordRanges: [Range<Int>]

    /// A verse from raw KJV source text, cleaned of its markup.
    nonisolated init(number: Int, text: String) {
        let cleaned = KJVTextCleaner.clean(text)
        self.init(
            number: number,
            text: cleaned.text,
            redLetterRanges: cleaned.redLetterRanges,
            suppliedWordRanges: cleaned.suppliedWordRanges
        )
    }

    /// A verse whose text is already clean, as in the bundled KJVText.json.
    nonisolated init(number: Int, text: String, redLetterRanges: [Range<Int>], suppliedWordRanges: [Range<Int>]) {
        self.number = number
        self.text = text
        self.redLetterRanges = redLetterRanges
        self.suppliedWordRanges = suppliedWordRanges
    }

    /// The translation leaves this verse out; it keeps its number so later verses line up.
    nonisolated var isOmitted: Bool { text.isEmpty }

    /// Shown in place of an omitted verse.
    nonisolated static func omittedNote(in translation: BibleTranslation) -> String {
        "The \(translation.abbreviation) leaves out this verse, which the oldest manuscripts don’t include."
    }
}

struct Chapter: Identifiable, Hashable, Sendable {
    // Stable, allocation-free ID derived from chapter number within a book
    var id: String { "\(number)" }
    let number: Int
    let verses: [Verse]

    // Navigation paths hash their routes, and the synthesized hash would walk every verse's
    // text. Hashing a subset of the compared fields keeps equal values hashing equally.
    // Equality stays synthesized; copies of one chapter share a verse buffer and compare in O(1).
    func hash(into hasher: inout Hasher) {
        hasher.combine(number)
        hasher.combine(verses.count)
    }
}

struct Book: Identifiable, Hashable, Sendable {
    // Stable, allocation-free ID derived from the book name
    var id: String { name }
    let name: String
    let chapters: [Chapter]

    /// The number of whitespace-delimited words in the cleaned Bible text for this book.
    var wordCount: Int {
        chapters.reduce(into: 0) { count, chapter in
            count += chapter.verses.reduce(into: 0) { verseCount, verse in
                verseCount += verse.text.split(whereSeparator: { $0.isWhitespace }).count
            }
        }
    }

    // See `Chapter.hash(into:)`: hashing every chapter would hash the whole book's text.
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(chapters.count)
    }
}

// The bundled KJVText.json and other translations: [{ abbrev, name?, chapters: [[verse]] }],
// where each verse is [text] ("" when the translation omits it) or [text, [redLetterStart, end, …], [suppliedStart, end, …]] (UTF-16 offsets).
private struct KJVBookDTO: Decodable {
    let abbrev: String
    let chapters: [[CleanVerseDTO]]
    let name: String?
}

private struct CleanVerseDTO: Decodable {
    let text: String
    let redLetterRanges: [Range<Int>]
    let suppliedWordRanges: [Range<Int>]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        text = try container.decode(String.self)
        let length = text.utf16.count
        redLetterRanges = container.isAtEnd ? [] : Self.ranges(try container.decode([Int].self), length: length)
        suppliedWordRanges = container.isAtEnd ? [] : Self.ranges(try container.decode([Int].self), length: length)
    }

    /// Pairs of offsets as ranges, dropping any that don't fit the text.
    private static func ranges(_ offsets: [Int], length: Int) -> [Range<Int>] {
        stride(from: 0, to: offsets.count - 1, by: 2).compactMap { index in
            let lower = offsets[index]
            let upper = offsets[index + 1]
            return lower >= 0 && lower < upper && upper <= length ? lower..<upper : nil
        }
    }
}

// The raw kjv.json source: [{ abbrev, name?, chapters: [[String]] }] with markup in the text.
private struct KJVSourceBookDTO: Decodable {
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

    /// Decodes a bundled, pre-cleaned translation such as KJVText.json.
    nonisolated static func decodeBooks(from data: Data) throws -> [Book] {
        let dtoBooks = try JSONDecoder().decode([KJVBookDTO].self, from: data)
        return dtoBooks.map { dto in
            Book(
                name: dto.name ?? BookNames.fullName(for: dto.abbrev),
                chapters: dto.chapters.enumerated().map { chapterIndex, verses in
                    Chapter(
                        number: chapterIndex + 1,
                        verses: verses.enumerated().map { verseIndex, verse in
                            Verse(
                                number: verseIndex + 1,
                                text: verse.text,
                                redLetterRanges: verse.redLetterRanges,
                                suppliedWordRanges: verse.suppliedWordRanges
                            )
                        }
                    )
                }
            )
        }
    }

    /// Decodes the raw kjv.json source, cleaning every verse. The app bundles the pre-cleaned
    /// file instead; tests use this to check that file is current.
    nonisolated static func decodeSourceBooks(from data: Data) throws -> [Book] {
        let dtoBooks = try JSONDecoder().decode([KJVSourceBookDTO].self, from: data)
        return dtoBooks.map { dto in
            Book(
                name: dto.name ?? BookNames.fullName(for: dto.abbrev),
                chapters: dto.chapters.enumerated().map { chapterIndex, texts in
                    Chapter(
                        number: chapterIndex + 1,
                        verses: texts.enumerated().map { verseIndex, text in
                            Verse(number: verseIndex + 1, text: text)
                        }
                    )
                }
            )
        }
    }
}
