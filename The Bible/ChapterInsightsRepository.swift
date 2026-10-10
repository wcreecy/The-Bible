import Foundation
import SQLite3

struct ChapterInsights: Equatable, Sendable {
    let reference: String
    let overallSummary: String
    let historicalSetting: String
    let whatWasHappening: String
    let connectionToChapter: String
    let customsAndTraditions: String
    let whyItMatters: String
    let keyFigures: [ChapterKeyFigure]
    let keyThemes: [ChapterKeyTheme]
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
                )
            )
        }
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
            let references = (try? JSONDecoder().decode(
                [String].self,
                from: Data(Self.columnText(statement, at: 3).utf8)
            )) ?? []
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

    private static func columnText(_ statement: OpaquePointer, at index: Int32) -> String {
        guard let text = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: text)
    }

    private nonisolated static func sqliteTransientDestructor() -> sqlite3_destructor_type {
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    }
}
