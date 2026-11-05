import Foundation

/// Loads the Trivia questions bundled with the app. To change them, edit BibleTriviaQuestions.json.
enum BibleTriviaCatalogStore {
    // Earlier versions let people import a catalog into Application Support, which then
    // overrode the bundled file. Any leftover copy is deleted so the bundled file always wins.
    private nonisolated static let legacyImportedFileName = "BibleTriviaQuestions.json"

    nonisolated static func loadData() -> Data? {
        removeLegacyImportedCatalog()

        guard let bundledURL = Bundle.main.url(
            forResource: "BibleTriviaQuestions",
            withExtension: "json"
        ) else {
            return nil
        }
        return try? Data(contentsOf: bundledURL, options: .mappedIfSafe)
    }

    private nonisolated static func removeLegacyImportedCatalog() {
        guard let directoryURL = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return }
        try? FileManager.default.removeItem(at: directoryURL.appendingPathComponent(legacyImportedFileName))
    }
}