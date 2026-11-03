import Foundation
import OSLog

/// Decoding for values the app saved earlier, such as stats, layouts, and synced data.
///
/// A plain `try?` turns unreadable data into "nothing saved", and the next save then
/// overwrites it for good. These helpers log why decoding failed, and can keep a copy of the
/// unreadable bytes first, so a bad payload is never lost without a trace.
nonisolated enum PersistedDecoding {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "The Bible",
        category: "PersistedData"
    )

    /// Failures already logged this launch, so a value that is read often logs once.
    private static let reported = NSLock()
    nonisolated(unsafe) private static var reportedFailures: Set<Int> = []

    /// Prefix for the copy kept of unreadable data: `unreadable.<key>`.
    static func backupKey(for key: String) -> String { "unreadable.\(key)" }

    /// Decodes `data`, or logs why it couldn't and returns nil. `name` identifies the value
    /// in the log; it should never include the data itself.
    static func decode<T: Decodable>(_ type: T.Type, from data: Data, name: String) -> T? {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            report(error, name: name, data: data)
            return nil
        }
    }

    /// Like `decode(_:from:name:)`, and also keeps the unreadable bytes in `defaults` under
    /// `backupKey(for:)` before the caller falls back to a default and saves over them. The
    /// first unreadable copy is kept, since later ones may already be the replacement.
    static func decode<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        key: String,
        keepingUnreadableIn defaults: UserDefaults
    ) -> T? {
        guard let decoded = decode(type, from: data, name: key) else {
            let backup = backupKey(for: key)
            if defaults.data(forKey: backup) == nil {
                defaults.set(data, forKey: backup)
                logger.notice("Kept an unreadable copy of \(key, privacy: .public) as \(backup, privacy: .public)")
            }
            return nil
        }
        return decoded
    }

    /// For values stored as JSON text (such as `@AppStorage` strings). Empty text means
    /// nothing was saved yet, and isn't a failure.
    static func decode<T: Decodable>(
        _ type: T.Type,
        fromText text: String,
        key: String,
        keepingUnreadableIn defaults: UserDefaults = .standard
    ) -> T? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard let data = text.data(using: .utf8) else {
            logger.error("\(key, privacy: .public) is not valid UTF-8 text")
            return nil
        }
        return decode(type, from: data, key: key, keepingUnreadableIn: defaults)
    }

    private static func report(_ error: Error, name: String, data: Data) {
        var hasher = Hasher()
        hasher.combine(name)
        hasher.combine(data.count)
        let id = hasher.finalize()

        reported.lock()
        let isNew = reportedFailures.insert(id).inserted
        reported.unlock()
        guard isNew else { return }

        logger.error(
            "Could not read saved \(name, privacy: .public) (\(data.count) bytes): \(String(describing: error), privacy: .public)"
        )
    }
}
