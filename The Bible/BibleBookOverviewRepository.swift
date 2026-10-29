import Foundation
import SQLite3

struct BibleBookOverview: Equatable, Sendable {
    let name: String
    let testament: String
    let traditionalAuthorOrAttribution: String
    let originalAudience: String
    let purpose: String
    let overallTheme: String
    let plainEnglishSummary: String
    let keyScripture: BibleKeyScripture
    let movements: [BibleBookMovement]
    let keyFigures: [BibleBookKeyFigure]
    let whenAndWhere: BibleBookWhenAndWhere?
    let story: [BibleBookStorySection]
    let readingTips: [String]
    let connections: [BibleBookConnection]
}

/// How a book relates to the rest of the Bible: what it builds on, or where it is picked up later.
struct BibleBookConnection: Identifiable, Equatable, Sendable {
    enum Direction: String, Sendable {
        case back
        case ahead
    }

    let id: Int
    let direction: Direction
    let title: String
    let text: String
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

    /// The one-sentence preview shown on a book's About page.
    var previewText: String {
        openingSentence(in: summary ?? text)
    }

    /// The section's opening summary paragraph, when it has one ahead of the retelling.
    /// Unlabeled continuation paragraphs are pure story, so they never have a summary.
    var summary: String? {
        guard !passage.isEmpty, let paragraphBreak = text.range(of: "\n\n") else { return nil }
        return String(text[..<paragraphBreak.lowerBound])
    }

    /// The retelling that follows the section's summary.
    var narrative: String {
        guard summary != nil, let paragraphBreak = text.range(of: "\n\n") else { return text }
        return String(text[paragraphBreak.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func openingSentence(in text: String) -> String {
        for index in text.indices where ".!?".contains(text[index]) {
            let nextIndex = text.index(after: index)
            if nextIndex == text.endIndex || text[nextIndex].isWhitespace {
                return String(text[...index])
            }
        }

        return text
    }
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
                   original_audience, purpose, overall_theme,
                   plain_english_summary, key_scripture_reference, key_scripture_text
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
                overallTheme: Self.columnText(statement, at: 6),
                plainEnglishSummary: Self.columnText(statement, at: 7),
                keyScripture: BibleKeyScripture(
                    reference: Self.columnText(statement, at: 8),
                    text: Self.columnText(statement, at: 9)
                ),
                movements: loadMovements(forBookNamed: bookName, database: database),
                keyFigures: loadKeyFigures(forBookNamed: bookName, database: database),
                whenAndWhere: loadWhenAndWhere(forBookNamed: bookName, database: database),
                story: loadStory(forBookNamed: bookName, database: database),
                readingTips: loadReadingTips(forBookNamed: bookName, database: database),
                connections: loadConnections(forBookNamed: bookName, database: database)
            )
        }
    }

    /// Just the book's sections, for grouping its chapters.
    func movements(forBookNamed bookName: String) -> [BibleBookMovement] {
        withDatabase { loadMovements(forBookNamed: bookName, database: $0) } ?? []
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
            let passages = PersistedDecoding.decode(
                [String].self,
                from: Data(Self.columnText(statement, at: 4).utf8),
                name: "BibleInsights book movement passages"
            ) ?? []
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

    private func loadReadingTips(forBookNamed bookName: String, database: OpaquePointer) -> [String] {
        let query = """
        SELECT tip
        FROM book_reading_tips
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

        var tips: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            tips.append(Self.columnText(statement, at: 0))
        }
        return tips
    }

    private func loadConnections(forBookNamed bookName: String, database: OpaquePointer) -> [BibleBookConnection] {
        let query = """
        SELECT id, direction, title, text
        FROM book_connections
        WHERE book_name = ?
        ORDER BY direction = 'ahead', sequence;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, bookName, -1, Self.sqliteTransientDestructor())

        var connections: [BibleBookConnection] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let direction = BibleBookConnection.Direction(rawValue: Self.columnText(statement, at: 1)) else { continue }
            connections.append(
                BibleBookConnection(
                    id: Int(sqlite3_column_int(statement, 0)),
                    direction: direction,
                    title: Self.columnText(statement, at: 2),
                    text: Self.columnText(statement, at: 3)
                )
            )
        }
        return connections
    }

    private static func columnText(_ statement: OpaquePointer, at index: Int32) -> String {
        guard let text = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: text)
    }

    private nonisolated static func sqliteTransientDestructor() -> sqlite3_destructor_type {
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    }
}
