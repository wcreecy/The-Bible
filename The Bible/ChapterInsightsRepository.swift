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
            case nameOrGroup = "name_or_group"
            case roleAndSignificance = "role_and_significance"
            case role
            case significance
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decodeIfPresent(String.self, forKey: .name)
                ?? container.decode(String.self, forKey: .nameOrGroup)

            if let roleAndSignificance = try container.decodeIfPresent(
                String.self,
                forKey: .roleAndSignificance
            ) {
                self.roleAndSignificance = roleAndSignificance
            } else {
                let role = try container.decodeIfPresent(String.self, forKey: .role)
                let significance = try container.decodeIfPresent(String.self, forKey: .significance)
                self.roleAndSignificance = [role, significance]
                    .compactMap { $0 }
                    .joined(separator: " ")
            }
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
            case alternateConnectionToChapter = "connection_to_chapter"
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
            ) ?? container.decodeIfPresent(
                String.self,
                forKey: .alternateConnectionToChapter
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
        case "Revelation", "2 Thessalonians", "1 Timothy", "2 Timothy", "Titus", "Hebrews", "Philemon", "James",
             "1 Peter", "2 Peter", "2 John", "3 John", "Jude":
            return loadStructuredInsights(
                bookName: bookName,
                chapterNumber: chapterNumber,
                database: database
            )
        case "Numbers", "Deuteronomy", "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel", "1 Kings", "2 Kings",
             "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah", "Esther", "1 John", "Job", "Psalms", "Proverbs",
             "Ecclesiastes", "Song of Solomon", "Isaiah", "Jeremiah", "Lamentations":
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
        case "1 Kings":
            "1_Kings_Chapter_Overviews_22"
        case "2 Kings":
            "2_Kings_Chapter_Overviews_25"
        case "1 Chronicles":
            "1_Chronicles_Chapter_Overviews_29"
        case "2 Chronicles":
            "2_Chronicles_Chapter_Overviews_36"
        case "Ezra":
            "Ezra_Chapter_Overviews_10"
        case "Nehemiah":
            "Nehemiah_Chapter_Overviews_13"
        case "Esther":
            "Esther_Chapter_Overviews_10"
        case "Job":
            "Job_Chapter_Overviews_42"
        case "Psalms":
            "Psalms_Chapter_Overviews_150"
        case "Proverbs":
            "Proverbs_Chapter_Overviews_31"
        case "Ecclesiastes":
            "Ecclesiastes_Chapter_Overviews_12"
        case "Song of Solomon":
            "Song_of_Solomon_Chapter_Overviews_8"
        case "Isaiah":
            "Isaiah_Chapter_Overviews_66"
        case "Jeremiah":
            "Jeremiah_Chapter_Overviews_52"
        case "Lamentations":
            "Lamentations_Chapter_Overviews_5"
        case "Revelation":
            "Revelation_Chapter_Overviews_22"
        case "2 Thessalonians":
            "2_Thessalonians_Chapter_Overviews_3"
        case "1 Timothy":
            "1_Timothy_Chapter_Overviews_6"
        case "2 Timothy":
            "2_Timothy_Chapter_Overviews_4"
        case "Titus":
            "Titus_Chapter_Overviews_3"
        case "Hebrews":
            "Hebrews_Chapter_Overviews_13"
        case "Philemon":
            "Philemon_Chapter_Overviews_1"
        case "James":
            "James_Chapter_Overviews_5"
        case "1 Peter":
            "1_Peter_Chapter_Overviews_5"
        case "2 Peter":
            "2_Peter_Chapter_Overviews_3"
        case "1 John":
            "1_John_Chapter_Overviews_5"
        case "2 John":
            "2_John_Chapter_Overviews_1"
        case "3 John":
            "3_John_Chapter_Overviews_1"
        case "Jude":
            "Jude_Chapter_Overviews_1"
        default:
            nil
        }
    }

    private func loadStructuredInsights(
        bookName: String,
        chapterNumber: Int,
        database: OpaquePointer
    ) -> ChapterInsights? {
        let query = """
        SELECT title, summary, historical_setting, connection_to_chapter, why_it_matters
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

        return ChapterInsights(
            reference: "\(bookName) \(chapterNumber): \(columnText(statement, at: 0))",
            overallSummary: columnText(statement, at: 1),
            historicalSetting: columnText(statement, at: 2),
            whatWasHappening: loadRevelationStatements(
                chapterNumber: chapterNumber,
                database: database
            ),
            connectionToChapter: columnText(statement, at: 3),
            customsAndTraditions: loadRevelationCustoms(
                chapterNumber: chapterNumber,
                database: database
            ),
            whyItMatters: columnText(statement, at: 4),
            keyFigures: loadRevelationFigures(chapterNumber: chapterNumber, database: database),
            keyThemes: loadRevelationThemes(chapterNumber: chapterNumber, database: database)
        )
    }

    private func loadRevelationFigures(
        chapterNumber: Int,
        database: OpaquePointer
    ) -> [ChapterKeyFigure] {
        let query = """
        SELECT id, name, role_in_chapter, significance
        FROM key_figures
        WHERE chapter = ?
        ORDER BY seq;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(chapterNumber))
        var figures: [ChapterKeyFigure] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let details = [columnText(statement, at: 2), columnText(statement, at: 3)]
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            figures.append(ChapterKeyFigure(
                id: Int(sqlite3_column_int(statement, 0)),
                name: columnText(statement, at: 1),
                roleAndSignificance: details
            ))
        }
        return figures
    }

    private func loadRevelationThemes(
        chapterNumber: Int,
        database: OpaquePointer
    ) -> [ChapterKeyTheme] {
        let query = """
        SELECT id, theme, explanation, takeaway
        FROM key_themes
        WHERE chapter = ?
        ORDER BY seq;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(chapterNumber))
        var themes: [ChapterKeyTheme] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let explanation = [columnText(statement, at: 2), columnText(statement, at: 3)]
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n")

            themes.append(ChapterKeyTheme(
                id: Int(sqlite3_column_int(statement, 0)),
                theme: columnText(statement, at: 1),
                explanation: explanation,
                scriptureReferences: []
            ))
        }
        return themes
    }

    private func loadRevelationStatements(
        chapterNumber: Int,
        database: OpaquePointer
    ) -> String {
        let query = """
        SELECT statement
        FROM what_was_happening
        WHERE chapter = ?
        ORDER BY seq;
        """
        return loadRevelationTextList(
            query: query,
            chapterNumber: chapterNumber,
            database: database,
            formatter: { columnText($0, at: 0) }
        )
    }

    private func loadRevelationCustoms(
        chapterNumber: Int,
        database: OpaquePointer
    ) -> String {
        let query = """
        SELECT item, explanation
        FROM customs_and_traditions
        WHERE chapter = ?
        ORDER BY seq;
        """
        return loadRevelationTextList(
            query: query,
            chapterNumber: chapterNumber,
            database: database,
            formatter: { "\(columnText($0, at: 0)): \(columnText($0, at: 1))" }
        )
    }

    private func loadRevelationTextList(
        query: String,
        chapterNumber: Int,
        database: OpaquePointer,
        formatter: (OpaquePointer) -> String
    ) -> String {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            return ""
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(chapterNumber))
        var entries: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            entries.append(formatter(statement))
        }
        return entries.joined(separator: "\n\n")
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
