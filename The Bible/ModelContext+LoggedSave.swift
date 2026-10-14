import Foundation
import OSLog
import SwiftData

extension ModelContext {
    private static let persistenceLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "The Bible",
        category: "Persistence"
    )

    /// Saves pending changes, logging a failure instead of silently discarding it.
    /// Returns whether the save succeeded, for callers that must not continue after a failure.
    @discardableResult
    func saveLoggingErrors(file: StaticString = #fileID, line: UInt = #line) -> Bool {
        do {
            try save()
            return true
        } catch {
            let location = "\(file):\(line)"
            Self.persistenceLogger.error(
                "SwiftData save failed at \(location, privacy: .public): \(String(describing: error), privacy: .public)"
            )
            return false
        }
    }
}
