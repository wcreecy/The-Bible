import Foundation
import Testing
@testable import Bible

/// The app bundles KJVText.json, pre-cleaned from the raw kjv.json by Scripts/clean_kjv.
/// These fail when kjv.json changes without re-running that script.
@MainActor
struct KJVTextBundleTests {
    /// The raw source, copied into this test bundle only (not the app).
    private var sourceURL: URL? {
        Bundle(for: KJVTextBundleToken.self).url(forResource: "kjv", withExtension: "json")
    }

    @Test
    func bundledTextMatchesACleanOfTheSource() throws {
        let sourceURL = try #require(sourceURL, "The raw kjv.json should be in the test bundle.")
        let bundledURL = try #require(Bundle.main.url(forResource: "KJVText", withExtension: "json"))

        let bundled = try BibleData.decodeBooks(from: Data(contentsOf: bundledURL))
        let source = try BibleData.decodeSourceBooks(from: Data(contentsOf: sourceURL))

        #expect(bundled.count == 66)
        #expect(bundled.flatMap(\.chapters).flatMap(\.verses).count == 31_102)
        // Equality compares every verse's text and marked-word ranges.
        #expect(
            bundled == source,
            "KJVText.json is out of date. Run Scripts/clean_kjv (see its header) after editing kjv.json."
        )
    }

    @Test
    func rawSourceIsNotShippedInTheApp() {
        #expect(Bundle.main.url(forResource: "kjv", withExtension: "json") == nil)
    }
}

/// Locates this test bundle.
private final class KJVTextBundleToken {}
