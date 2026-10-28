import Foundation
import OSLog

/// Cross references excluded from Chapter Insights pending future editorial review.
/// Keep each entry in `ChapterCrossReferenceReview.json` instead of deleting it from the
/// source database so its original reference and reason for removal remain available to editors.
enum ChapterCrossReferenceReview {
    struct Entry: Hashable, Sendable, Codable {
        let bookName: String
        let chapterNumber: Int
        let sourceVerse: Int
        let relatedReference: String
        let reason: String
    }

    nonisolated static let resourceName = "ChapterCrossReferenceReview"

    nonisolated static let excludedEntries: [Entry] = loadEntries()

    nonisolated static func excludes(
        bookName: String,
        chapterNumber: Int,
        sourceVerse: Int,
        relatedReference: String
    ) -> Bool {
        excludedEntries.contains {
            $0.bookName == bookName &&
            $0.chapterNumber == chapterNumber &&
            $0.sourceVerse == sourceVerse &&
            $0.relatedReference == relatedReference
        }
    }

    // MARK: - Loading

    /// Anchors bundle lookup to the bundle that contains this file, so the list
    /// resolves in the app and in hosted unit tests alike.
    private final class BundleToken {}

    private nonisolated static func loadEntries() -> [Entry] {
        let logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "The Bible",
            category: "CrossReferenceReview"
        )
        let bundle = Bundle(for: BundleToken.self)
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            logger.error("The excluded cross-reference resource is missing.")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Entry].self, from: data)
        } catch {
            logger.error("The excluded cross-reference list could not be decoded. Error: \(String(describing: error), privacy: .public)")
            return []
        }
    }
}
