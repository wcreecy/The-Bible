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
    let keyScripture: BibleKeyScripture
    let movements: [BibleBookMovement]
    let keyFigures: [BibleBookKeyFigure]
    let whenAndWhere: BibleBookWhenAndWhere?
    let story: [BibleBookStorySection]
}

/// The historical setting of a book: when it happened, when it was written, where, and the wider world.
struct BibleBookWhenAndWhere: Equatable, Sendable {
    let whenItHappened: String
    let whenItWasWritten: String
    let location: String
    let worldAtTheTime: String
}

/// One part of a book's story, labeled with the passage it retells (e.g. "Genesis 1-3").
struct BibleBookStorySection: Identifiable, Equatable, Sendable {
    let id: Int
    let passage: String
    let text: String
}

struct BibleKeyScripture: Equatable, Sendable {
    let reference: String
    let text: String
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

    private let databaseResourceName = "BibleInsights"

    func overview(forBookNamed bookName: String) -> BibleBookOverview? {
        withDatabase { database in
            let query = """
            SELECT id, name, testament, traditional_author_or_attribution,
                   original_audience, purpose, historical_context, overall_theme,
                   plain_english_summary, interpretive_notes, key_scripture_reference,
                   key_scripture_text
            FROM book_overviews
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

            return BibleBookOverview(
                name: Self.columnText(statement, at: 1),
                testament: Self.columnText(statement, at: 2),
                traditionalAuthorOrAttribution: Self.columnText(statement, at: 3),
                originalAudience: Self.columnText(statement, at: 4),
                purpose: Self.columnText(statement, at: 5),
                historicalContext: Self.columnText(statement, at: 6),
                overallTheme: Self.columnText(statement, at: 7),
                plainEnglishSummary: Self.columnText(statement, at: 8),
                interpretiveNotes: Self.columnText(statement, at: 9),
                keyScripture: BibleKeyScripture(
                    reference: Self.columnText(statement, at: 10),
                    text: Self.columnText(statement, at: 11)
                ),
                movements: loadMovements(forBookNamed: bookName, database: database),
                keyFigures: loadKeyFigures(forBookNamed: bookName, database: database),
                whenAndWhere: loadWhenAndWhere(forBookNamed: bookName, database: database),
                story: loadStory(forBookNamed: bookName, database: database)
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

    private func loadMovements(forBookNamed bookName: String, database: OpaquePointer) -> [BibleBookMovement] {
        let query = """
        SELECT id, sequence, title, description, key_passages_json
        FROM book_movements
        WHERE book_name = ?
        ORDER BY sequence;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, bookName, -1, Self.sqliteTransientDestructor())

        var movements: [BibleBookMovement] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let passages = (try? JSONDecoder().decode(
                [String].self,
                from: Data(Self.columnText(statement, at: 4).utf8)
            )) ?? []
            movements.append(
                BibleBookMovement(
                    id: Int(sqlite3_column_int(statement, 0)),
                    sequence: Int(sqlite3_column_int(statement, 1)),
                    title: Self.columnText(statement, at: 2),
                    description: Self.columnText(statement, at: 3),
                    keyPassages: passages
                )
            )
        }
        return movements
    }

    private func loadKeyFigures(forBookNamed bookName: String, database: OpaquePointer) -> [BibleBookKeyFigure] {
        let query = """
        SELECT id, sequence, name, description
        FROM book_key_figures
        WHERE book_name = ?
        ORDER BY sequence;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, bookName, -1, Self.sqliteTransientDestructor())

        var figures: [BibleBookKeyFigure] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            figures.append(
                BibleBookKeyFigure(
                    id: Int(sqlite3_column_int(statement, 0)),
                    sequence: Int(sqlite3_column_int(statement, 1)),
                    name: Self.columnText(statement, at: 2),
                    description: Self.columnText(statement, at: 3)
                )
            )
        }
        return figures
    }

    private func loadWhenAndWhere(forBookNamed bookName: String, database: OpaquePointer) -> BibleBookWhenAndWhere? {
        let query = """
        SELECT when_it_happened, when_it_was_written, location, world_at_the_time
        FROM book_history
        WHERE book_name = ?
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
        return BibleBookWhenAndWhere(
            whenItHappened: Self.columnText(statement, at: 0),
            whenItWasWritten: Self.columnText(statement, at: 1),
            location: Self.columnText(statement, at: 2),
            worldAtTheTime: Self.columnText(statement, at: 3)
        )
    }

    private func loadStory(forBookNamed bookName: String, database: OpaquePointer) -> [BibleBookStorySection] {
        let query = """
        SELECT id, passage, text
        FROM book_story_sections
        WHERE book_name = ?
        ORDER BY sequence;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, bookName, -1, Self.sqliteTransientDestructor())

        var sections: [BibleBookStorySection] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            sections.append(
                BibleBookStorySection(
                    id: Int(sqlite3_column_int(statement, 0)),
                    passage: Self.columnText(statement, at: 1),
                    text: Self.columnText(statement, at: 2)
                )
            )
        }
        return sections
    }

    private static func columnText(_ statement: OpaquePointer, at index: Int32) -> String {
        guard let text = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: text)
    }

    private nonisolated static func sqliteTransientDestructor() -> sqlite3_destructor_type {
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    }
}
