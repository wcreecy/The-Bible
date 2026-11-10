import Foundation
import SQLite3

/// A dictionary entry that a search matched: "G26, ἀγάπη (agapē), love".
struct StrongsEntry: Identifiable, Equatable, Sendable {
    /// The disambiguated number, such as "G0026" or "H0430G".
    let strongs: String
    let lemma: String
    let transliteration: String
    let gloss: String

    var id: String { strongs }
    var displayNumber: String { OriginalWord.displayNumber(for: strongs) }
}

/// Looking up dictionary entries, and the verses using them, for a search.
extension OriginalWordsRepository {
    /// The entries for a number. "H430" is every sense of it (H0430G, H0430H, …), because one
    /// Strong's number has several entries when the extended numbering tells its meanings apart.
    func strongsEntries(forNumberPrefix prefix: String) -> [StrongsEntry] {
        entries(whereClause: "strongs LIKE ?1", value: prefix + "%")
    }

    /// The entries whose dictionary form or transliteration has this search key (see
    /// `StrongsSearch.key(for:)`), so "ἀγάπη", "agapē", and "agape" all find G26.
    func strongsEntries(forKey key: String) -> [StrongsEntry] {
        entries(whereClause: "lemma_key = ?1 OR translit_key = ?1", value: key)
    }

    private func entries(whereClause: String, value: String) -> [StrongsEntry] {
        withDatabase { database in
            let query = """
            SELECT strongs, lemma, translit, gloss FROM lexicon
            WHERE \(whereClause)
            ORDER BY strongs LIMIT 12;
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
                  let statement else { return [StrongsEntry]() }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_text(statement, 1, value, -1, Self.sqliteTransientDestructor())

            var entries: [StrongsEntry] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                entries.append(
                    StrongsEntry(
                        strongs: Self.columnText(statement, at: 0),
                        lemma: Self.columnText(statement, at: 1),
                        transliteration: Self.columnText(statement, at: 2),
                        gloss: Self.columnText(statement, at: 3)
                    )
                )
            }
            return entries
        } ?? []
    }

    /// Every verse using any of these numbers, once each, in Bible order. Greek words count only
    /// where the translation's Greek text has them, as in `usage(of:translation:)`.
    func verses(usingAnyOf strongsNumbers: [String], translation: BibleTranslation) -> [VerseLocation] {
        guard !strongsNumbers.isEmpty else { return [] }
        let greekSource = String(translation.greekTextSource)
        let placeholders = strongsNumbers.indices.map { "?\($0 + 2)" }.joined(separator: ",")

        return withDatabase { database in
            let query = """
            SELECT DISTINCT word.book, word.chapter, word.verse
            FROM words AS word JOIN forms AS form ON form.id = word.form
            WHERE form.strongs IN (\(placeholders))
              AND (form.strongs NOT LIKE 'G%' OR instr(form.source, ?1) > 0)
            ORDER BY word.book, word.chapter, word.verse;
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
                  let statement else { return [VerseLocation]() }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_text(statement, 1, greekSource, -1, Self.sqliteTransientDestructor())
            for (index, number) in strongsNumbers.enumerated() {
                sqlite3_bind_text(statement, Int32(index + 2), number, -1, Self.sqliteTransientDestructor())
            }

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
        } ?? []
    }
}
