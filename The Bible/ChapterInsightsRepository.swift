import Foundation
import SQLite3

struct ChapterInsights: Equatable, Sendable {
    let reference: String
    let overallSummary: String
    let readingContext: ChapterReadingContext?
    let historicalSetting: String
    let whatWasHappening: String
    let connectionToChapter: String
    let customsAndTraditions: String
    let whyItMatters: String
    let keyFigures: [ChapterKeyFigure]
    let keyThemes: [ChapterKeyTheme]
    let relatedVerses: [ChapterRelatedVerse]
}

struct ChapterKeyFigure: Identifiable, Equatable, Sendable {
    let id: Int
    let name: String
    let roleAndSignificance: String
}

struct ChapterKeyTheme: Identifiable, Equatable, Sendable {
    let id: Int
    let theme: String
    let explanation: String
    let scriptureReferences: [String]
}

/// A cross-reference from a verse in the chapter to a related passage elsewhere in Scripture.
struct ChapterRelatedVerse: Identifiable, Equatable, Sendable {
    let id: Int
    let sourceVerse: Int
    let relatedReference: String
    let connectionExplanation: String?
}

actor ChapterInsightsRepository {
    static let shared = ChapterInsightsRepository()

    private let databaseResourceName = "BibleInsights"

    func insights(forBookNamed bookName: String, chapterNumber: Int) -> ChapterInsights? {
        withDatabase { database in
            let query = """
            SELECT reference, overall_summary, historical_setting, what_was_happening,
                   connection_to_chapter, customs_and_traditions, why_it_matters
            FROM chapter_insights
            WHERE book_name = ? AND chapter_number = ?
            LIMIT 1;
            """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
                  let statement else {
                return nil
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, bookName, -1, Self.sqliteTransientDestructor())
            sqlite3_bind_int(statement, 2, Int32(chapterNumber))

            guard sqlite3_step(statement) == SQLITE_ROW else { return nil }

            return ChapterInsights(
                reference: Self.columnText(statement, at: 0),
                overallSummary: Self.columnText(statement, at: 1),
                readingContext: loadReadingContext(
                    forBookNamed: bookName,
                    chapterNumber: chapterNumber,
                    database: database
                ),
                historicalSetting: Self.columnText(statement, at: 2),
                whatWasHappening: Self.columnText(statement, at: 3),
                connectionToChapter: Self.columnText(statement, at: 4),
                customsAndTraditions: Self.columnText(statement, at: 5),
                whyItMatters: Self.columnText(statement, at: 6),
                keyFigures: loadKeyFigures(
                    forBookNamed: bookName,
                    chapterNumber: chapterNumber,
                    database: database
                ),
                keyThemes: loadKeyThemes(
                    forBookNamed: bookName,
                    chapterNumber: chapterNumber,
                    database: database
                ),
                relatedVerses: loadRelatedVerses(
                    forBookNamed: bookName,
                    chapterNumber: chapterNumber,
                    database: database
                )
            )
        }
    }

    private func loadReadingContext(
        forBookNamed bookName: String,
        chapterNumber: Int,
        database: OpaquePointer
    ) -> ChapterReadingContext? {
        let contextQuery = """
        SELECT in_story, historical_moment, original_audience
        FROM chapter_reading_contexts
        WHERE book_name = ? AND chapter_number = ?
        LIMIT 1;
        """

        var contextStatement: OpaquePointer?
        guard sqlite3_prepare_v2(database, contextQuery, -1, &contextStatement, nil) == SQLITE_OK,
              let contextStatement else {
            return nil
        }
        defer { sqlite3_finalize(contextStatement) }

        sqlite3_bind_text(contextStatement, 1, bookName, -1, Self.sqliteTransientDestructor())
        sqlite3_bind_int(contextStatement, 2, Int32(chapterNumber))

        guard sqlite3_step(contextStatement) == SQLITE_ROW else { return nil }

        return ChapterReadingContext(
            narrativePlacement: Self.columnText(contextStatement, at: 0),
            firstCenturyMoment: Self.columnText(contextStatement, at: 1),
            originalAudience: Self.columnText(contextStatement, at: 2),
            interpretiveClues: loadInterpretiveClues(
                forBookNamed: bookName,
                chapterNumber: chapterNumber,
                database: database
            ),
            culturalLenses: loadCulturalLenses(
                forBookNamed: bookName,
                chapterNumber: chapterNumber,
                database: database
            ),
            scriptureConnections: []
        )
    }

    private func loadInterpretiveClues(
        forBookNamed bookName: String,
        chapterNumber: Int,
        database: OpaquePointer
    ) -> [ChapterReadingContext.InterpretiveClue] {
        let query = """
        SELECT title, scripture_reference, explanation
        FROM chapter_interpretive_clues
        WHERE book_name = ? AND chapter_number = ?
        ORDER BY sequence;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, bookName, -1, Self.sqliteTransientDestructor())
        sqlite3_bind_int(statement, 2, Int32(chapterNumber))

        var clues: [ChapterReadingContext.InterpretiveClue] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            clues.append(
                ChapterReadingContext.InterpretiveClue(
                    title: Self.columnText(statement, at: 0),
                    reference: Self.columnText(statement, at: 1),
                    explanation: Self.columnText(statement, at: 2)
                )
            )
        }
        return clues
    }

    private func loadCulturalLenses(
        forBookNamed bookName: String,
        chapterNumber: Int,
        database: OpaquePointer
    ) -> [ChapterReadingContext.CulturalLens] {
        let query = """
        SELECT title, scripture_reference, then_text, why_it_matters
        FROM chapter_cultural_lenses
        WHERE book_name = ? AND chapter_number = ?
        ORDER BY sequence;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, bookName, -1, Self.sqliteTransientDestructor())
        sqlite3_bind_int(statement, 2, Int32(chapterNumber))

        var lenses: [ChapterReadingContext.CulturalLens] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            lenses.append(
                ChapterReadingContext.CulturalLens(
                    title: Self.columnText(statement, at: 0),
                    reference: Self.columnText(statement, at: 1),
                    then: Self.columnText(statement, at: 2),
                    whyItMatters: Self.columnText(statement, at: 3)
                )
            )
        }
        return lenses
    }

    private func withDatabase<T>(_ operation: (OpaquePointer) -> T?) -> T? {
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

    private func loadKeyFigures(
        forBookNamed bookName: String,
        chapterNumber: Int,
        database: OpaquePointer
    ) -> [ChapterKeyFigure] {
        let query = """
        SELECT id, name, role_and_significance
        FROM chapter_key_figures
        WHERE book_name = ? AND chapter_number = ?
        ORDER BY sequence;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, bookName, -1, Self.sqliteTransientDestructor())
        sqlite3_bind_int(statement, 2, Int32(chapterNumber))

        var figures: [ChapterKeyFigure] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            figures.append(
                ChapterKeyFigure(
                    id: Int(sqlite3_column_int(statement, 0)),
                    name: Self.columnText(statement, at: 1),
                    roleAndSignificance: Self.columnText(statement, at: 2)
                )
            )
        }
        return figures
    }

    private func loadKeyThemes(
        forBookNamed bookName: String,
        chapterNumber: Int,
        database: OpaquePointer
    ) -> [ChapterKeyTheme] {
        let query = """
        SELECT id, theme, explanation, scripture_references_json
        FROM chapter_key_themes
        WHERE book_name = ? AND chapter_number = ?
        ORDER BY sequence;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, bookName, -1, Self.sqliteTransientDestructor())
        sqlite3_bind_int(statement, 2, Int32(chapterNumber))

        var themes: [ChapterKeyTheme] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let references = Self.decodeReferences(Self.columnText(statement, at: 3))
            themes.append(
                ChapterKeyTheme(
                    id: Int(sqlite3_column_int(statement, 0)),
                    theme: Self.columnText(statement, at: 1),
                    explanation: Self.columnText(statement, at: 2),
                    scriptureReferences: references
                )
            )
        }
        return themes
    }

    private func loadRelatedVerses(
        forBookNamed bookName: String,
        chapterNumber: Int,
        database: OpaquePointer
    ) -> [ChapterRelatedVerse] {
        let query = """
        SELECT related.id, related.source_verse, related.related_reference, connection.explanation
        FROM chapter_related_verses AS related
        LEFT JOIN chapter_scripture_connections AS connection
            ON connection.book_name = related.book_name
            AND connection.chapter_number = related.chapter_number
            AND connection.source_verse = related.source_verse
            AND connection.related_reference = related.related_reference
        WHERE related.book_name = ? AND related.chapter_number = ?
        ORDER BY related.sequence;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, bookName, -1, Self.sqliteTransientDestructor())
        sqlite3_bind_int(statement, 2, Int32(chapterNumber))

        var relatedVerses: [ChapterRelatedVerse] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            relatedVerses.append(
                ChapterRelatedVerse(
                    id: Int(sqlite3_column_int(statement, 0)),
                    sourceVerse: Int(sqlite3_column_int(statement, 1)),
                    relatedReference: Self.columnText(statement, at: 2),
                    connectionExplanation: Self.optionalColumnText(statement, at: 3)
                )
            )
        }
        return relatedVerses
    }

    /// Most rows store a JSON array of references, but some store a single JSON string.
    private static func decodeReferences(_ json: String) -> [String] {
        let data = Data(json.utf8)
        if let references = try? JSONDecoder().decode([String].self, from: data) {
            return references
        }
        if let reference = try? JSONDecoder().decode(String.self, from: data), !reference.isEmpty {
            return [reference]
        }
        return []
    }

    private static func columnText(_ statement: OpaquePointer, at index: Int32) -> String {
        guard let text = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: text)
    }

    private static func optionalColumnText(_ statement: OpaquePointer, at index: Int32) -> String? {
        guard let text = sqlite3_column_text(statement, index) else { return nil }
        let value = String(cString: text)
        return value.isEmpty ? nil : value
    }

    private nonisolated static func sqliteTransientDestructor() -> sqlite3_destructor_type {
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    }
}
