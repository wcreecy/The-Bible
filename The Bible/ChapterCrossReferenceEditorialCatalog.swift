import Foundation
import OSLog

/// Editorial relationship notes for retained Chapter Insights cross references.
/// The data lives in `ChapterCrossReferenceEditorialCatalog.json`; add pair-specific
/// explanations there as each book is reviewed.
enum ChapterCrossReferenceEditorialCatalog {
    struct Entry: Sendable, Codable {
        let bookName: String
        let chapterNumber: Int
        let sourceVerse: Int
        let targetBookName: String
        let targetChapterNumber: Int
        let targetVerse: Int
        let relationshipDescription: String
    }

    nonisolated static let resourceName = "ChapterCrossReferenceEditorialCatalog"

    nonisolated static let entries: [Entry] = loadEntries()

    nonisolated static func relationshipDescription(
        bookName: String,
        chapterNumber: Int,
        sourceVerse: Int,
        targetBookName: String,
        targetChapterNumber: Int,
        targetVerse: Int
    ) -> String? {
        entries.first {
            $0.bookName == bookName &&
            $0.chapterNumber == chapterNumber &&
            $0.sourceVerse == sourceVerse &&
            $0.targetBookName == targetBookName &&
            $0.targetChapterNumber == targetChapterNumber &&
            $0.targetVerse == targetVerse
        }?.relationshipDescription ?? entries.first {
            $0.bookName == targetBookName &&
            $0.chapterNumber == targetChapterNumber &&
            $0.sourceVerse == targetVerse &&
            $0.targetBookName == bookName &&
            $0.targetChapterNumber == chapterNumber &&
            $0.targetVerse == sourceVerse
        }?.relationshipDescription
    }

    // MARK: - Loading

    /// Anchors bundle lookup to the bundle that contains this file, so the catalog
    /// resolves in the app and in hosted unit tests alike.
    private final class BundleToken {}

    private nonisolated static func loadEntries() -> [Entry] {
        let logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "The Bible",
            category: "CrossReferenceCatalog"
        )
        let bundle = Bundle(for: BundleToken.self)
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            logger.error("The cross-reference editorial catalog resource is missing.")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Entry].self, from: data)
        } catch {
            logger.error("The cross-reference editorial catalog could not be decoded. Error: \(String(describing: error), privacy: .public)")
            return []
        }
    }
}
