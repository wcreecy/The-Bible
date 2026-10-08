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
    private struct EmbeddedFigure: Decodable {
        let name: String
        let roleAndSignificance: String

        enum CodingKeys: String, CodingKey {
            case name
            case roleAndSignificance = "role_and_significance"
            case role
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            roleAndSignificance = try container.decodeIfPresent(
                String.self,
                forKey: .roleAndSignificance
            ) ?? container.decode(String.self, forKey: .role)
        }
    }

    private struct EmbeddedTheme: Decodable {
        let theme: String
        let explanationAndTakeaway: String
        let scriptureReferences: [String]

        enum CodingKeys: String, CodingKey {
            case theme
            case explanationAndTakeaway = "explanation_and_takeaway"
            case explanationAndLesson = "explanation_and_lesson"
            case explanation
            case scriptureReferences = "scripture_references"
            case references
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            theme = try container.decode(String.self, forKey: .theme)
            explanationAndTakeaway = try container.decodeIfPresent(
                String.self,
                forKey: .explanationAndTakeaway
            ) ?? container.decodeIfPresent(
                String.self,
                forKey: .explanationAndLesson
            ) ?? container.decode(String.self, forKey: .explanation)
            scriptureReferences = try container.decodeIfPresent(
                [String].self,
                forKey: .scriptureReferences
            ) ?? container.decode([String].self, forKey: .references)
        }
    }

    private struct HistoricalContext: Decodable {
        let historicalSetting: String
        let whatWasHappening: String
        let connectionToChapter: String
        let customsAndTraditions: String
        let whyItMatters: String

        enum CodingKeys: String, CodingKey {
            case historicalSetting = "historical_setting"
            case whatWasHappening = "what_was_happening"
            case connectionToChapter = "connection_to_the_chapter"
            case customsAndTraditions = "customs_and_traditions"
            case whyItMatters = "why_it_matters"
            case titleCaseHistoricalSetting = "Historical Setting"
            case titleCaseWhatWasHappening = "What Was Happening"
            case titleCaseConnectionToChapter = "Connection to the Chapter"
            case titleCaseCustomsAndTraditions = "Customs and Traditions"
            case titleCaseWhyItMatters = "Why It Matters"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            historicalSetting = try container.decodeIfPresent(
                String.self,
                forKey: .historicalSetting
            ) ?? container.decode(String.self, forKey: .titleCaseHistoricalSetting)
            whatWasHappening = try container.decodeIfPresent(
                String.self,
                forKey: .whatWasHappening
            ) ?? container.decode(String.self, forKey: .titleCaseWhatWasHappening)
            connectionToChapter = try container.decodeIfPresent(
                String.self,
                forKey: .connectionToChapter
            ) ?? container.decode(String.self, forKey: .titleCaseConnectionToChapter)
            customsAndTraditions = try container.decodeIfPresent(
                String.self,
                forKey: .customsAndTraditions
            ) ?? container.decode(String.self, forKey: .titleCaseCustomsAndTraditions)
            whyItMatters = try container.decodeIfPresent(
                String.self,
                forKey: .whyItMatters
            ) ?? container.decode(String.self, forKey: .titleCaseWhyItMatters)
        }
    }

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

        switch bookName {
        case "Exodus":
            return loadEmbeddedJSONInsights(chapterNumber: chapterNumber, database: database)
        case "Leviticus":
            return loadLeviticusInsights(chapterNumber: chapterNumber, database: database)
        case "Numbers", "Deuteronomy", "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel":
            return loadSimpleOverviewInsights(chapterNumber: chapterNumber, database: database)
        default:
            return loadInsights(chapterNumber: chapterNumber, database: database)
        }
    }

    private func databaseResourceName(forBookNamed bookName: String) -> String? {
        switch bookName {
        case "Genesis":
            "Genesis_Chapter_Overviews_50"
        case "Exodus":
            "Exodus_Chapter_Overviews_40"
        case "Leviticus":
            "Leviticus_Chapter_Overviews_27"
        case "Numbers":
            "Numbers_Chapter_Overviews_36"
        case "Deuteronomy":
            "Deuteronomy_Chapter_Overviews_34"
        case "Joshua":
            "Joshua_Chapter_Overviews_24"
        case "Judges":
            "Judges_Chapter_Overviews_21"
        case "Ruth":
            "Ruth_Chapter_Overviews_4"
        case "1 Samuel":
            "1_Samuel_Chapter_Overviews_31"
        case "2 Samuel":
            "2_Samuel_Chapter_Overviews_24"
        default:
            nil
        }
    }

    private func loadSimpleOverviewInsights(chapterNumber: Int, database: OpaquePointer) -> ChapterInsights? {
        let query = """
        SELECT book, chapter, overall_summary, key_figures, key_themes, historical_context
        FROM chapter_overviews
        WHERE chapter = ?
        LIMIT 1;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            return nil
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(chapterNumber))
        guard sqlite3_step(statement) == SQLITE_ROW,
              let context = decodeHistoricalContext(from: columnText(statement, at: 5)) else {
            return nil
        }

        let book = columnText(statement, at: 0)
        let chapter = sqlite3_column_int(statement, 1)
        return ChapterInsights(
            reference: "\(book) \(chapter)",
            overallSummary: columnText(statement, at: 2),
            historicalSetting: context.historicalSetting,
            whatWasHappening: context.whatWasHappening,
            connectionToChapter: context.connectionToChapter,
            customsAndTraditions: context.customsAndTraditions,
            whyItMatters: context.whyItMatters,
            keyFigures: decodeEmbeddedFigures(from: columnText(statement, at: 3)),
            keyThemes: decodeEmbeddedThemes(from: columnText(statement, at: 4))
        )
    }

    private func loadLeviticusInsights(chapterNumber: Int, database: OpaquePointer) -> ChapterInsights? {
        let query = """
        SELECT book, chapter, overall_summary, key_figures_json, key_themes_json,
               historical_context_json
        FROM chapter_overviews
        WHERE chapter = ?
        LIMIT 1;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            return nil
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(chapterNumber))
        guard sqlite3_step(statement) == SQLITE_ROW,
              let context = decodeHistoricalContext(from: columnText(statement, at: 5)) else {
            return nil
        }

        let book = columnText(statement, at: 0)
        let chapter = sqlite3_column_int(statement, 1)
        return ChapterInsights(
            reference: "\(book) \(chapter)",
            overallSummary: columnText(statement, at: 2),
            historicalSetting: context.historicalSetting,
            whatWasHappening: context.whatWasHappening,
            connectionToChapter: context.connectionToChapter,
            customsAndTraditions: context.customsAndTraditions,
            whyItMatters: context.whyItMatters,
            keyFigures: decodeEmbeddedFigures(from: columnText(statement, at: 3)),
            keyThemes: decodeEmbeddedThemes(from: columnText(statement, at: 4))
        )
    }

    private func decodeHistoricalContext(from json: String) -> HistoricalContext? {
        try? JSONDecoder().decode(HistoricalContext.self, from: Data(json.utf8))
    }

    private func loadEmbeddedJSONInsights(chapterNumber: Int, database: OpaquePointer) -> ChapterInsights? {
        let query = """
        SELECT reference, overall_summary, historical_setting, what_was_happening,
               historical_connection, customs_and_traditions, why_it_matters,
               key_figures_json, key_themes_json
        FROM chapters
        WHERE chapter = ?
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

        let figures = decodeEmbeddedFigures(from: columnText(statement, at: 7))
        let themes = decodeEmbeddedThemes(from: columnText(statement, at: 8))

        return ChapterInsights(
            reference: columnText(statement, at: 0),
            overallSummary: columnText(statement, at: 1),
            historicalSetting: columnText(statement, at: 2),
            whatWasHappening: columnText(statement, at: 3),
            connectionToChapter: columnText(statement, at: 4),
            customsAndTraditions: columnText(statement, at: 5),
            whyItMatters: columnText(statement, at: 6),
            keyFigures: figures,
            keyThemes: themes
        )
    }

    private func decodeEmbeddedFigures(from json: String) -> [ChapterKeyFigure] {
        let figures = (try? JSONDecoder().decode(
            [EmbeddedFigure].self,
            from: Data(json.utf8)
        )) ?? []

        return figures.enumerated().map { index, figure in
            ChapterKeyFigure(
                id: index,
                name: figure.name,
                roleAndSignificance: figure.roleAndSignificance
            )
        }
    }

    private func decodeEmbeddedThemes(from json: String) -> [ChapterKeyTheme] {
        let themes = (try? JSONDecoder().decode(
            [EmbeddedTheme].self,
            from: Data(json.utf8)
        )) ?? []

        return themes.enumerated().map { index, theme in
            ChapterKeyTheme(
                id: index,
                theme: theme.theme,
                explanation: theme.explanationAndTakeaway,
                scriptureReferences: theme.scriptureReferences
            )
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
