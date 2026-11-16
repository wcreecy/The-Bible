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

    /// One verse pair in either direction, for the lookup below.
    private nonisolated struct PairKey: Hashable, Sendable {
        let bookName: String
        let chapterNumber: Int
        let sourceVerse: Int
        let targetBookName: String
        let targetChapterNumber: Int
        let targetVerse: Int
    }

    /// Descriptions by verse pair. Scripture Connections rows look these up while drawing,
    /// so a scan of every entry for each row would be too slow. The first entry for a pair wins.
    private nonisolated static let descriptions: [PairKey: String] = Dictionary(
        entries.map {
            (
                PairKey(
                    bookName: $0.bookName,
                    chapterNumber: $0.chapterNumber,
                    sourceVerse: $0.sourceVerse,
                    targetBookName: $0.targetBookName,
                    targetChapterNumber: $0.targetChapterNumber,
                    targetVerse: $0.targetVerse
                ),
                $0.relationshipDescription
            )
        },
        uniquingKeysWith: { first, _ in first }
    )

    /// Loads the catalog now. Call off the main thread before a screen needs it, so the
    /// first lookup doesn't decode the file while drawing.
    nonisolated static func prepare() {
        _ = descriptions
    }

    nonisolated static func relationshipDescription(
        bookName: String,
        chapterNumber: Int,
        sourceVerse: Int,
        targetBookName: String,
        targetChapterNumber: Int,
        targetVerse: Int
    ) -> String? {
        // An entry for the pair as written, then for the same pair read the other way.
        descriptions[PairKey(
            bookName: bookName,
            chapterNumber: chapterNumber,
            sourceVerse: sourceVerse,
            targetBookName: targetBookName,
            targetChapterNumber: targetChapterNumber,
            targetVerse: targetVerse
        )] ?? descriptions[PairKey(
            bookName: targetBookName,
            chapterNumber: targetChapterNumber,
            sourceVerse: targetVerse,
            targetBookName: bookName,
            targetChapterNumber: chapterNumber,
            targetVerse: sourceVerse
        )]
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
