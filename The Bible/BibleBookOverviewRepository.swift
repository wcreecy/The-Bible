import Foundation
import SQLite3

struct BibleBookOverview: Equatable, Sendable {
    let name: String
    let testament: String
    let traditionalAuthorOrAttribution: String
    let originalAudience: String
    let purpose: String
    let historicalContext: String
    let overallTheme: String
    let plainEnglishSummary: String
    let interpretiveNotes: String
    let movements: [BibleBookMovement]
    let keyFigures: [BibleBookKeyFigure]
}

struct BibleBookMovement: Identifiable, Equatable, Sendable {
    let id: Int
    let sequence: Int
    let title: String
    let description: String
    let keyPassages: [String]
}

struct BibleBookKeyFigure: Identifiable, Equatable, Sendable {
    let id: Int
    let sequence: Int
    let name: String
    let description: String
}

actor BibleBookOverviewRepository {
    static let shared = BibleBookOverviewRepository()

    private let databaseResourceName = "Bible_Book_Overviews_66"

    func overview(forBookNamed bookName: String) -> BibleBookOverview? {
        guard let databaseURL = Bundle.main.url(
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

        return loadOverview(forBookNamed: bookName, database: database)
    }

    private func loadOverview(
        forBookNamed bookName: String,
        database: OpaquePointer
    ) -> BibleBookOverview? {
        let query = """
        SELECT id, name, testament, traditional_author_or_attribution,
               original_audience, purpose, historical_context, overall_theme,
               plain_english_summary, interpretive_notes
        FROM books
        WHERE name = ?
        LIMIT 1;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            return nil
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, bookName, -1, Self.sqliteTransientDestructor())

        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }

        let bookID = Int(sqlite3_column_int(statement, 0))
        return BibleBookOverview(
            name: columnText(statement, at: 1),
            testament: columnText(statement, at: 2),
            traditionalAuthorOrAttribution: columnText(statement, at: 3),
            originalAudience: columnText(statement, at: 4),
            purpose: columnText(statement, at: 5),
            historicalContext: columnText(statement, at: 6),
            overallTheme: columnText(statement, at: 7),
            plainEnglishSummary: columnText(statement, at: 8),
            interpretiveNotes: columnText(statement, at: 9),
            movements: loadMovements(forBookID: bookID, database: database),
            keyFigures: loadKeyFigures(forBookID: bookID, database: database)
        )
    }

    private func loadMovements(
        forBookID bookID: Int,
        database: OpaquePointer
    ) -> [BibleBookMovement] {
        let query = """
        SELECT id, sequence, title, description, key_passages_json
        FROM book_movements
        WHERE book_id = ?
        ORDER BY sequence;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(bookID))

        var movements: [BibleBookMovement] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let passagesJSON = columnText(statement, at: 4)
            let keyPassages = (try? JSONDecoder().decode(
                [String].self,
                from: Data(passagesJSON.utf8)
            )) ?? []

            movements.append(BibleBookMovement(
                id: Int(sqlite3_column_int(statement, 0)),
                sequence: Int(sqlite3_column_int(statement, 1)),
                title: columnText(statement, at: 2),
                description: columnText(statement, at: 3),
                keyPassages: keyPassages
            ))
        }
        return movements
    }

    private func loadKeyFigures(
        forBookID bookID: Int,
        database: OpaquePointer
    ) -> [BibleBookKeyFigure] {
        let query = """
        SELECT id, sequence, name, description
        FROM book_key_figures
        WHERE book_id = ?
        ORDER BY sequence;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(bookID))

        var keyFigures: [BibleBookKeyFigure] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            keyFigures.append(BibleBookKeyFigure(
                id: Int(sqlite3_column_int(statement, 0)),
                sequence: Int(sqlite3_column_int(statement, 1)),
                name: columnText(statement, at: 2),
                description: columnText(statement, at: 3)
            ))
        }
        return keyFigures
    }

    private func columnText(_ statement: OpaquePointer, at index: Int32) -> String {
        guard let text = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: text)
    }

    private nonisolated static func sqliteTransientDestructor() -> sqlite3_destructor_type {
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    }
}
