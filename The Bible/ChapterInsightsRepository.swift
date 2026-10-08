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

    func insights(forBookNamed bookName: String, chapterNumber: Int) -> ChapterInsights? {
        guard let databaseResourceName = databaseResourceName(forBookNamed: bookName),
              let databaseURL = Bundle.main.url(
                forResource: databaseResourceName,
                withExtension: "sqlite"
              ) else {
            return nil
        }

        var database: OpaquePointer?
        guard sqlite3_open_v2(
            databaseURL.path,
            &database,
            SQLITE_OPEN_READONLY,
            nil
        ) == SQLITE_OK, let database else {
            return nil
        }
        defer { sqlite3_close(database) }

        return loadInsights(chapterNumber: chapterNumber, database: database)
    }

    private func databaseResourceName(forBookNamed bookName: String) -> String? {
        switch bookName {
        case "Genesis":
            "Genesis_Chapter_Overviews_50"
        default:
            nil
        }
    }

    private func loadInsights(chapterNumber: Int, database: OpaquePointer) -> ChapterInsights? {
        let query = """
        SELECT chapter_id, reference, overall_summary, historical_setting,
               what_was_happening, connection_to_chapter, customs_and_traditions,
               why_it_matters
        FROM chapters
        WHERE chapter_number = ?
        LIMIT 1;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            return nil
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(chapterNumber))

        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }

        let chapterID = Int(sqlite3_column_int(statement, 0))
        return ChapterInsights(
            reference: columnText(statement, at: 1),
            overallSummary: columnText(statement, at: 2),
            historicalSetting: columnText(statement, at: 3),
            whatWasHappening: columnText(statement, at: 4),
            connectionToChapter: columnText(statement, at: 5),
            customsAndTraditions: columnText(statement, at: 6),
            whyItMatters: columnText(statement, at: 7),
            keyFigures: loadKeyFigures(forChapterID: chapterID, database: database),
            keyThemes: loadKeyThemes(forChapterID: chapterID, database: database)
        )
    }

    private func loadKeyFigures(forChapterID chapterID: Int, database: OpaquePointer) -> [ChapterKeyFigure] {
        let query = """
        SELECT figure_id, name, role_and_significance
        FROM key_figures
        WHERE chapter_id = ?
        ORDER BY display_order;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(chapterID))

        var figures: [ChapterKeyFigure] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            figures.append(ChapterKeyFigure(
                id: Int(sqlite3_column_int(statement, 0)),
                name: columnText(statement, at: 1),
                roleAndSignificance: columnText(statement, at: 2)
            ))
        }
        return figures
    }

    private func loadKeyThemes(forChapterID chapterID: Int, database: OpaquePointer) -> [ChapterKeyTheme] {
        let query = """
        SELECT theme_id, theme, explanation, scripture_references_json
        FROM key_themes
        WHERE chapter_id = ?
        ORDER BY display_order;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(chapterID))

        var themes: [ChapterKeyTheme] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let referencesJSON = columnText(statement, at: 3)
            let scriptureReferences = (try? JSONDecoder().decode(
                [String].self,
                from: Data(referencesJSON.utf8)
            )) ?? []

            themes.append(ChapterKeyTheme(
                id: Int(sqlite3_column_int(statement, 0)),
                theme: columnText(statement, at: 1),
                explanation: columnText(statement, at: 2),
                scriptureReferences: scriptureReferences
            ))
        }
        return themes
    }

    private func columnText(_ statement: OpaquePointer, at index: Int32) -> String {
        guard let text = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: text)
    }
}
