import Foundation
import SQLite3

/// The language a verse was written in.
enum OriginalLanguage: Sendable {
    case hebrew
    case greek
}

/// The lexicon entry behind a word's Strong's number.
struct OriginalWordEntry: Equatable, Sendable {
    let lemma: String
    let transliteration: String
    let gloss: String
    let definition: String
}

/// Why a word may be missing from some Bibles: it isn't in every text the translations follow.
enum OriginalTextVariant: Equatable, Sendable {
    /// Greek in the text behind the KJV that modern critical editions leave out.
    case traditionalGreekOnly
    /// Greek in modern critical editions that the text behind the KJV leaves out.
    case criticalGreekOnly
    /// Hebrew read from the scribes' marginal correction (the Qere), where the written text differs.
    case qere
    /// Hebrew restored from a parallel passage, because the manuscript is missing it.
    case restored
}

/// One Hebrew or Greek word of a verse, in reading order.
struct OriginalWord: Identifiable, Equatable, Sendable {
    /// The word's place in the verse, starting at 1.
    let id: Int
    let original: String
    let transliteration: String
    /// The English meaning of this word as it is used in the verse.
    let gloss: String
    /// The disambiguated Strong's number, such as "H7225G" or "G3056".
    let strongsNumber: String?
    let entry: OriginalWordEntry?
    /// Which texts have the word: N (critical) and K (the KJV's) for Greek, L, Q, or R for Hebrew.
    let source: String
    /// The word's grammar in one line ("Verb · Aorist Passive Indicative · 3rd Singular"), if known.
    let parse: String?

    /// Set when the word isn't in every text, so the sheet can say so.
    var textVariant: OriginalTextVariant? {
        switch source {
        case "K": .traditionalGreekOnly
        case "N": .criticalGreekOnly
        case "Q": .qere
        case "R": .restored
        default: nil
        }
    }

    /// The meaning in this verse ("he created"), or the dictionary's when the verse has none.
    var contextGloss: String {
        gloss.isEmpty ? (entry?.gloss ?? "") : gloss
    }

    /// The dictionary's short meaning ("to create"), or nil when it only repeats `contextGloss`
    /// ("the heavens" and "heaven", "(obj.)" and "[Obj.]").
    var dictionaryGloss: String? {
        guard let dictionary = entry?.gloss, !dictionary.isEmpty else { return nil }
        return Self.letters(contextGloss).contains(Self.letters(dictionary)) ? nil : dictionary
    }

    /// The dictionary's meaning short enough for a tile. A number with several senses glosses
    /// as "word: sense" ("tribe: staff", "to release: forgive"), and the sense after the colon
    /// is the one this word has, so the tile shows that ("staff"), or nothing when the verse's
    /// meaning already says it.
    var tileDictionaryGloss: String? {
        guard let dictionary = dictionaryGloss else { return nil }
        guard let colon = dictionary.firstIndex(of: ":") else { return dictionary }
        let sense = dictionary[dictionary.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        guard !sense.isEmpty else { return dictionary }
        return Self.letters(contextGloss).contains(Self.letters(sense)) ? nil : sense
    }

    private static func letters(_ text: String) -> String {
        text.lowercased().filter(\.isLetter)
    }

    /// An article, a conjunction, or the Hebrew object marker (which has no English): the small
    /// words that make a long verse long. The grammar line starts with the kind of word.
    var isSmallWord: Bool {
        guard let parse else { return false }
        return parse.hasPrefix("Definite article")
            || parse.hasPrefix("Conjunction")
            || parse.hasPrefix("Particle · Object indicator")
    }

    /// The number as people write it: leading zeros and the disambiguating letter dropped.
    var displayStrongsNumber: String? {
        strongsNumber.map(Self.displayNumber(for:))
    }

    /// "H0430G" as "H430".
    static func displayNumber(for strongsNumber: String) -> String {
        guard let language = strongsNumber.first else { return strongsNumber }
        let digits = strongsNumber.dropFirst().prefix { $0.isNumber }
        guard let number = Int(digits) else { return strongsNumber }
        return "\(language)\(number)"
    }
}

/// Who or what a proper name is in a verse: a person, a place, a group. Many people share a
/// name ("Zechariah" is dozens of men), so this is looked up by verse, not by word alone.
struct OriginalName: Identifiable, Equatable, Sendable {
    /// The source's type for the name.
    enum Kind: String, Sendable {
        case male = "Male"
        case female = "Female"
        case group = "Group"
        case place = "Place"
        case supernatural = "Supernatural"
        case time = "Time"
        case musical = "Musical"
        case title = "Title"
        case star = "Star"
        case language = "Language"
        case other = "Other"
    }

    let id: Int
    let name: String
    let kind: Kind
    /// "High Priest living at the time of Egypt and Wilderness"; empty for a place.
    let description: String
    let parents: String
    let siblings: String
    let partners: String
    let offspring: String
    /// The tribe or nation of a person, or the region of a place.
    let area: String
}

/// A verse, by the KJV's book, chapter, and verse numbers.
struct VerseLocation: Identifiable, Hashable, Sendable {
    let bookName: String
    let chapter: Int
    let verse: Int

    var id: String { "\(bookName) \(chapter):\(verse)" }
    var reference: String { id }
}

/// How often a word is used, by Strong's number.
struct OriginalWordUsage: Equatable, Sendable {
    /// Every use, counting a word that appears twice in a verse twice.
    let wordCount: Int
    let verseCount: Int
    let first: VerseLocation?
}

/// The Hebrew and Greek words behind each verse, from OriginalWords.sqlite. The data comes
/// from STEPBible.org and Tyndale House Cambridge (CC BY 4.0); Scripts/build_original_words.py
/// builds the database and Scripts/data/README.md describes the sources.
actor OriginalWordsRepository {
    static let shared = OriginalWordsRepository()

    private let databaseResourceName = "OriginalWords"

    /// The words of a verse, in order. Empty when the verse has none or the database is missing.
    ///
    /// Greek words are tagged with the texts they appear in, so the list follows the reader's
    /// translation: the KJV and WEB follow the traditional text, the ASV the critical one.
    func words(
        bookName: String,
        chapter: Int,
        verse: Int,
        translation: BibleTranslation
    ) -> [OriginalWord] {
        guard let bookIndex = OriginalWordsBooks.index(of: bookName) else { return [] }
        let greekSource = translation.greekTextSource

        return withDatabase { database in
            let query = """
            SELECT word.position, form.original, form.translit, form.gloss, form.strongs, form.source,
                   lexicon.lemma, lexicon.translit, lexicon.gloss, lexicon.definition, parse.description
            FROM words AS word
            JOIN forms AS form ON form.id = word.form
            LEFT JOIN lexicon ON lexicon.strongs = form.strongs
            LEFT JOIN parses AS parse ON parse.id = form.parse
            WHERE word.book = ? AND word.chapter = ? AND word.verse = ?
            ORDER BY word.position;
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
                  let statement else {
                return [OriginalWord]()
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_int(statement, 1, Int32(bookIndex))
            sqlite3_bind_int(statement, 2, Int32(chapter))
            sqlite3_bind_int(statement, 3, Int32(verse))

            var words: [OriginalWord] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                let strongs = Self.optionalColumnText(statement, at: 4)
                // Greek sources are N, K, or NK; Hebrew ones (L, Q, R) have no variants to choose.
                let source = Self.columnText(statement, at: 5)
                if strongs?.first == "G", !source.contains(greekSource) { continue }

                let entry = Self.optionalColumnText(statement, at: 6).map { lemma in
                    OriginalWordEntry(
                        lemma: lemma,
                        transliteration: Self.columnText(statement, at: 7),
                        gloss: Self.columnText(statement, at: 8),
                        definition: Self.columnText(statement, at: 9)
                    )
                }
                words.append(
                    OriginalWord(
                        id: Int(sqlite3_column_int(statement, 0)),
                        original: Self.columnText(statement, at: 1),
                        transliteration: Self.columnText(statement, at: 2),
                        gloss: Self.columnText(statement, at: 3),
                        strongsNumber: strongs,
                        entry: entry,
                        source: source,
                        parse: Self.optionalColumnText(statement, at: 10)
                    )
                )
            }
            return words
        } ?? []
    }

    /// Who a name is in one verse, by the Strong's number of the word. Only the verse says which
    /// person is meant, so a word that isn't a name in that verse (or whose verse the names
    /// data numbers differently) has none. Matching by number alone would label every "heart"
    /// with the name that shares its number.
    func names(forStrongs strongsNumber: String, in verse: VerseLocation) -> [OriginalName] {
        guard let bookIndex = OriginalWordsBooks.index(of: verse.bookName) else { return [] }

        return withDatabase { database in
            let query = """
            SELECT name.id, name.name, name.kind, name.description, name.parents, name.siblings,
                   name.partners, name.offspring, name.area
            FROM name_verses AS link JOIN names AS name ON name.id = link.name
            WHERE link.strongs = ? AND link.book = ? AND link.chapter = ? AND link.verse = ?
            ORDER BY name.id;
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
                  let statement else { return [OriginalName]() }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_text(statement, 1, strongsNumber, -1, Self.sqliteTransientDestructor())
            sqlite3_bind_int(statement, 2, Int32(bookIndex))
            sqlite3_bind_int(statement, 3, Int32(verse.chapter))
            sqlite3_bind_int(statement, 4, Int32(verse.verse))

            var names: [OriginalName] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                names.append(
                    OriginalName(
                        id: Int(sqlite3_column_int(statement, 0)),
                        name: Self.columnText(statement, at: 1),
                        kind: OriginalName.Kind(rawValue: Self.columnText(statement, at: 2)) ?? .other,
                        description: Self.columnText(statement, at: 3),
                        parents: Self.columnText(statement, at: 4),
                        siblings: Self.columnText(statement, at: 5),
                        partners: Self.columnText(statement, at: 6),
                        offspring: Self.columnText(statement, at: 7),
                        area: Self.columnText(statement, at: 8)
                    )
                )
            }
            return names
        } ?? []
    }

    /// The words using one Strong's number, in the Greek text the translation follows.
    static let usageFilter = "form.strongs = ?1 AND (form.strongs NOT LIKE 'G%' OR instr(form.source, ?2) > 0)"

    /// How often a word is used. Greek words count only where the translation's Greek text has
    /// them, so the KJV and the ASV can differ by a few.
    func usage(of strongsNumber: String, translation: BibleTranslation) -> OriginalWordUsage? {
        let greekSource = String(translation.greekTextSource)

        return withDatabase { database in
            let countQuery = """
            SELECT COUNT(*), COUNT(DISTINCT word.book * 1000000 + word.chapter * 1000 + word.verse)
            FROM words AS word JOIN forms AS form ON form.id = word.form
            WHERE \(Self.usageFilter);
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, countQuery, -1, &statement, nil) == SQLITE_OK,
                  let statement else { return nil }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_text(statement, 1, strongsNumber, -1, Self.sqliteTransientDestructor())
            sqlite3_bind_text(statement, 2, greekSource, -1, Self.sqliteTransientDestructor())
            guard sqlite3_step(statement) == SQLITE_ROW else { return nil }

            let wordCount = Int(sqlite3_column_int(statement, 0))
            let verseCount = Int(sqlite3_column_int(statement, 1))
            guard wordCount > 0 else { return nil }

            return OriginalWordUsage(
                wordCount: wordCount,
                verseCount: verseCount,
                first: Self.verseLocations(
                    using: strongsNumber, greekSource: greekSource, limit: 1, in: database
                ).first
            )
        }
    }

    /// Every verse using a word, in Bible order.
    func verses(using strongsNumber: String, translation: BibleTranslation) -> [VerseLocation] {
        let greekSource = String(translation.greekTextSource)
        return withDatabase { database in
            Self.verseLocations(using: strongsNumber, greekSource: greekSource, limit: -1, in: database)
        } ?? []
    }

    private static func verseLocations(
        using strongsNumber: String,
        greekSource: String,
        limit: Int32,
        in database: OpaquePointer
    ) -> [VerseLocation] {
        let query = """
        SELECT DISTINCT word.book, word.chapter, word.verse
        FROM words AS word JOIN forms AS form ON form.id = word.form
        WHERE \(usageFilter)
        ORDER BY word.book, word.chapter, word.verse
        LIMIT ?3;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
              let statement else { return [] }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, strongsNumber, -1, sqliteTransientDestructor())
        sqlite3_bind_text(statement, 2, greekSource, -1, sqliteTransientDestructor())
        sqlite3_bind_int(statement, 3, limit)

        var locations: [VerseLocation] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let bookIndex = Int(sqlite3_column_int(statement, 0))
            guard OriginalWordsBooks.names.indices.contains(bookIndex - 1) else { continue }
            locations.append(
                VerseLocation(
                    bookName: OriginalWordsBooks.names[bookIndex - 1],
                    chapter: Int(sqlite3_column_int(statement, 1)),
                    verse: Int(sqlite3_column_int(statement, 2))
                )
            )
        }
        return locations
    }

    func withDatabase<T>(_ operation: (OpaquePointer) -> T?) -> T? {
        guard let databaseURL = Bundle.main.url(forResource: databaseResourceName, withExtension: "sqlite") else {
            return nil
        }

        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let database else {
            return nil
        }
        defer { sqlite3_close(database) }

        return operation(database)
    }

    nonisolated static func sqliteTransientDestructor() -> sqlite3_destructor_type {
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    }

    static func columnText(_ statement: OpaquePointer, at index: Int32) -> String {
        guard let text = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: text)
    }

    static func optionalColumnText(_ statement: OpaquePointer, at index: Int32) -> String? {
        guard let text = sqlite3_column_text(statement, index) else { return nil }
        let value = String(cString: text)
        return value.isEmpty ? nil : value
    }
}

extension BibleTranslation {
    /// Which Greek text this translation follows, as the letter OriginalWords.sqlite tags its
    /// Greek words with: K is the text behind the KJV, N the modern critical text.
    nonisolated var greekTextSource: Character {
        switch self {
        case .kjv, .web: "K"
        case .asv: "N"
        }
    }
}

/// The 1-based number OriginalWords.sqlite stores for a book: its place in the KJV's order.
enum OriginalWordsBooks {
    static let names = [
        "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua", "Judges", "Ruth",
        "1 Samuel", "2 Samuel", "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra",
        "Nehemiah", "Esther", "Job", "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon",
        "Isaiah", "Jeremiah", "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel", "Amos",
        "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk", "Zephaniah", "Haggai", "Zechariah",
        "Malachi", "Matthew", "Mark", "Luke", "John", "Acts", "Romans", "1 Corinthians",
        "2 Corinthians", "Galatians", "Ephesians", "Philippians", "Colossians", "1 Thessalonians",
        "2 Thessalonians", "1 Timothy", "2 Timothy", "Titus", "Philemon", "Hebrews", "James",
        "1 Peter", "2 Peter", "1 John", "2 John", "3 John", "Jude", "Revelation",
    ]

    static func index(of bookName: String) -> Int? {
        names.firstIndex(of: bookName).map { $0 + 1 }
    }
}
