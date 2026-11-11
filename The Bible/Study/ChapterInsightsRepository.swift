import Foundation
import SQLite3

struct ChapterInsights: Equatable, Sendable {
    let overallSummary: String
    let readingContext: ChapterReadingContext?
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

/// A curated Scripture connection with the passage that introduces it.
struct CrossReferenceExplorerEntry: Identifiable, Equatable, Sendable {
    let id: Int
    let bookName: String
    let chapterNumber: Int
    let sourceVerse: Int
    let relatedReference: String
    let connectionExplanation: String?

    var sourceReference: String {
        "\(bookName) \(chapterNumber):\(sourceVerse)"
    }

    var sourcePassage: PassageReference {
        PassageReference(
            bookName: bookName,
            startChapter: chapterNumber,
            startVerse: sourceVerse,
            endChapter: chapterNumber,
            endVerse: sourceVerse
        )
    }

    /// The pair's own explanation, from the editorial catalog or the database, or nil
    /// when none has been written yet.
    var writtenExplanation: String? {
        guard let targetReference = PassageReferenceParser.parseList(
            relatedReference,
            book: bookName,
            chapter: chapterNumber
        ).first else {
            return connectionExplanation
        }

        return ChapterCrossReferenceEditorialCatalog.relationshipDescription(
            bookName: bookName,
            chapterNumber: chapterNumber,
            sourceVerse: sourceVerse,
            targetBookName: targetReference.bookName,
            targetChapterNumber: targetReference.startChapter,
            targetVerse: targetReference.startVerse ?? 0
        ) ?? connectionExplanation
    }

    /// The written explanation, or the shared sentence for a pair without one.
    var relationshipDescription: String {
        writtenExplanation ?? ScriptureConnectionText.unexplainedRelationship
    }

    /// A browseable category inferred from the written explanation. Nil for a pair without
    /// one, so the type filters only list connections whose explanation says how they relate.
    var connectionType: CrossReferenceConnectionType? {
        writtenExplanation.map(CrossReferenceConnectionType.classify)
    }

    /// Every Scripture connection as the explorer lists it: one per target passage, with
    /// connections already covered by a wider one left out.
    static func loadAll() async -> [CrossReferenceExplorerEntry] {
        let records = await ChapterInsightsRepository.shared.allCrossReferences()
        return ChapterCrossReferenceDeduplicator.deduplicated(expanded(records))
    }

    /// Splits each database record into one connection per target passage. The first target
    /// keeps the record's ID, so connections saved before records were split still match.
    static func expanded(_ entries: [CrossReferenceExplorerEntry]) -> [CrossReferenceExplorerEntry] {
        entries.flatMap { entry in
            let references = PassageReferenceParser.parseList(
                entry.relatedReference,
                book: entry.bookName,
                chapter: entry.chapterNumber
            )

            guard references.count > 1 else {
                return [entry]
            }

            return references.enumerated().map { index, reference in
                CrossReferenceExplorerEntry(
                    id: connectionID(recordID: entry.id, targetIndex: index, reference: reference.displayTitle),
                    bookName: entry.bookName,
                    chapterNumber: entry.chapterNumber,
                    sourceVerse: entry.sourceVerse,
                    relatedReference: reference.displayTitle,
                    connectionExplanation: entry.connectionExplanation
                )
            }
        }
    }

    /// The saved-connection ID for one target of a database record. The first target uses the
    /// record's own ID; later ones get a repeatable ID derived from the record and target.
    nonisolated static func connectionID(recordID: Int, targetIndex: Int, reference: String) -> Int {
        guard targetIndex > 0 else { return recordID }
        var value = UInt64(bitPattern: Int64(recordID))
        for scalar in reference.unicodeScalars {
            value = value &* 31 &+ UInt64(scalar.value)
        }
        value = value &* 31 &+ UInt64(targetIndex)
        return Int(truncatingIfNeeded: value)
    }
}

extension PassageReference {
    /// Whether this passage shares at least one verse with `reference`, such as a searched verse.
    func overlaps(_ reference: ScriptureRef) -> Bool {
        guard bookName.caseInsensitiveCompare(reference.bookName) == .orderedSame,
              (startChapter...endChapter).contains(reference.chapter) else { return false }
        // This passage's verses within the searched chapter; whole chapters have no verse bounds.
        let first = reference.chapter == startChapter ? (startVerse ?? 1) : 1
        let last = reference.chapter == endChapter ? (endVerse ?? .max) : .max
        let searchedLast = reference.endVerse ?? reference.startVerse
        return reference.startVerse <= last && searchedLast >= first
    }
}

/// Wording shared by every place that shows a Scripture connection.
enum ScriptureConnectionText {
    /// Shown for a connection that has no written explanation yet. It makes no claim about
    /// which books are involved, so it is true for any pair.
    nonisolated static var unexplainedRelationship: String {
        String(localized: "These passages are linked in Scripture. Read them side by side to see how they relate.")
    }
}

enum CrossReferenceConnectionType: String, CaseIterable, Identifiable, Sendable {
    case quotation
    case prophecy
    case parallelAccount
    case wordOrPhrase
    case theme

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .quotation: "Direct Quotation"
        case .prophecy: "Prophecy Fulfilled"
        case .parallelAccount: "Same Event"
        case .wordOrPhrase: "Shared Word or Phrase"
        case .theme: "Shared Theme"
        }
    }

    var systemImage: String {
        switch self {
        case .quotation: "text.quote"
        case .prophecy: "sparkles"
        case .parallelAccount: "rectangle.on.rectangle"
        case .wordOrPhrase: "textformat"
        case .theme: "circle.hexagongrid"
        }
    }

    static func classify(_ description: String) -> Self {
        let text = description.localizedLowercase

        if text.contains("fulfill") || text.contains("prophecy") || text.contains("prophetic") {
            return .prophecy
        }
        if text.contains("quotes") || text.contains("quote") || text.contains("cites") || text.contains("citation") {
            return .quotation
        }
        if text.contains("parallel account") || text.contains("same event") || text.contains("both accounts") {
            return .parallelAccount
        }
        if text.contains("word") || text.contains("phrase") || text.contains("term") || text.contains("wording") {
            return .wordOrPhrase
        }
        return .theme
    }
}

actor ChapterInsightsRepository {
    static let shared = ChapterInsightsRepository()

    private let databaseResourceName = "BibleInsights"

    func insights(forBookNamed bookName: String, chapterNumber: Int) -> ChapterInsights? {
        withDatabase { database in
            let query = """
            SELECT overall_summary
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
                overallSummary: Self.columnText(statement, at: 0),
                readingContext: loadReadingContext(
                    forBookNamed: bookName,
                    chapterNumber: chapterNumber,
                    database: database
                ),
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

    /// Loads the complete, reviewed collection used by the Cross-Reference Explorer.
    func allCrossReferences() -> [CrossReferenceExplorerEntry] {
        withDatabase { database in
            let query = """
            SELECT related.id, related.book_name, related.chapter_number,
                   related.source_verse, related.related_reference, connection.explanation
            FROM chapter_related_verses AS related
            LEFT JOIN chapter_scripture_connections AS connection
                ON connection.book_name = related.book_name
                AND connection.chapter_number = related.chapter_number
                AND connection.source_verse = related.source_verse
                AND connection.related_reference = related.related_reference
            ORDER BY related.id;
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
                  let statement else {
                return [CrossReferenceExplorerEntry]()
            }
            defer { sqlite3_finalize(statement) }

            var entries: [CrossReferenceExplorerEntry] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                let bookName = Self.columnText(statement, at: 1)
                let chapterNumber = Int(sqlite3_column_int(statement, 2))
                let sourceVerse = Int(sqlite3_column_int(statement, 3))
                let relatedReference = Self.columnText(statement, at: 4)
                guard !ChapterCrossReferenceReview.excludes(
                    bookName: bookName,
                    chapterNumber: chapterNumber,
                    sourceVerse: sourceVerse,
                    relatedReference: relatedReference
                ) else {
                    continue
                }

                entries.append(
                    CrossReferenceExplorerEntry(
                        id: Int(sqlite3_column_int(statement, 0)),
                        bookName: bookName,
                        chapterNumber: chapterNumber,
                        sourceVerse: sourceVerse,
                        relatedReference: relatedReference,
                        connectionExplanation: Self.optionalColumnText(statement, at: 5)
                    )
                )
            }
            return entries
        } ?? []
    }

    /// Just the chapter's summary, for previewing neighboring chapters.
    func summary(forBookNamed bookName: String, chapterNumber: Int) -> String? {
        withDatabase { database in
            let query = """
            SELECT overall_summary
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
            let summary = Self.columnText(statement, at: 0)
            return summary.isEmpty ? nil : summary
        }
    }

    /// Every chapter's key theme names in a book, in order, keyed by chapter number, for
    /// previewing chapters in a list.
    func themeNames(forBookNamed bookName: String) -> [Int: [String]] {
        withDatabase { database in
            let query = """
            SELECT chapter_number, theme
            FROM chapter_key_themes
            WHERE book_name = ?
            ORDER BY chapter_number, id;
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
                  let statement else {
                return nil
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, bookName, -1, Self.sqliteTransientDestructor())

            var themes: [Int: [String]] = [:]
            while sqlite3_step(statement) == SQLITE_ROW {
                let theme = Self.columnText(statement, at: 1)
                guard !theme.isEmpty else { continue }
                themes[Int(sqlite3_column_int(statement, 0)), default: []].append(theme)
            }
            return themes
        } ?? [:]
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
            culturalLenses: loadCulturalLenses(
                forBookNamed: bookName,
                chapterNumber: chapterNumber,
                database: database
            )
        )
    }

    private func loadCulturalLenses(
        forBookNamed bookName: String,
        chapterNumber: Int,
        database: OpaquePointer
    ) -> [ChapterReadingContext.CulturalLens] {
        let query = """
        SELECT title, scripture_reference, then_text
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
                    then: Self.columnText(statement, at: 2)
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
            let sourceVerse = Int(sqlite3_column_int(statement, 1))
            let relatedReference = Self.columnText(statement, at: 2)
            guard !ChapterCrossReferenceReview.excludes(
                bookName: bookName,
                chapterNumber: chapterNumber,
                sourceVerse: sourceVerse,
                relatedReference: relatedReference
            ) else {
                continue
            }

            relatedVerses.append(
                ChapterRelatedVerse(
                    id: Int(sqlite3_column_int(statement, 0)),
                    sourceVerse: sourceVerse,
                    relatedReference: relatedReference,
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
