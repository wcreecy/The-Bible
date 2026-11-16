import Foundation
import SQLite3

/// A read-only SQLite database bundled with the app (OriginalWords.sqlite, BibleInsights.sqlite).
///
/// The connection opens on first use and stays open, so a screen that runs several queries
/// doesn't reopen the file and re-read its schema for each one. Each repository that owns one
/// is an actor, so a connection is only ever used from one thread at a time.
nonisolated final class BundledSQLiteDatabase {
    private let resourceName: String
    private var connection: OpaquePointer?
    /// Set once opening fails, so a missing or damaged file isn't retried on every query.
    private var isUnavailable = false

    init(resourceName: String) {
        self.resourceName = resourceName
    }

    deinit {
        if let connection {
            sqlite3_close(connection)
        }
    }

    /// Runs `operation` with the open connection, or returns nil when the database can't open.
    func withConnection<T>(_ operation: (OpaquePointer) -> T?) -> T? {
        guard let connection = openIfNeeded() else { return nil }
        return operation(connection)
    }

    private func openIfNeeded() -> OpaquePointer? {
        if let connection { return connection }
        guard !isUnavailable,
              let url = Bundle.main.url(forResource: resourceName, withExtension: "sqlite") else {
            isUnavailable = true
            return nil
        }

        var opened: OpaquePointer?
        guard sqlite3_open_v2(url.path, &opened, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let opened else {
            // SQLite can return a handle even when opening fails; it still has to be closed.
            sqlite3_close(opened)
            isUnavailable = true
            return nil
        }
        connection = opened
        return opened
    }
}

/// Column and binding helpers shared by the repositories that read a `BundledSQLiteDatabase`.
protocol BundledSQLiteReading {}

extension BundledSQLiteReading {
    /// Tells SQLite to copy bound text, since Swift strings don't outlive the call.
    nonisolated static func sqliteTransientDestructor() -> sqlite3_destructor_type {
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    }

    /// A text column, or an empty string when it is NULL.
    nonisolated static func columnText(_ statement: OpaquePointer, at index: Int32) -> String {
        guard let text = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: text)
    }

    /// A text column, or nil when it is NULL or empty.
    nonisolated static func optionalColumnText(_ statement: OpaquePointer, at index: Int32) -> String? {
        guard let text = sqlite3_column_text(statement, index) else { return nil }
        let value = String(cString: text)
        return value.isEmpty ? nil : value
    }
}
