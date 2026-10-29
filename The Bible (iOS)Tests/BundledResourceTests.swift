import Foundation
import Testing
@testable import Bible

struct BundledResourceTests {
    /// Verse Match and Word Search read this file, which lives in the widget folder.
    @Test
    func lockScreenVersesShipWithTheApp() throws {
        let url = try #require(Bundle.main.url(forResource: "LockScreenVerses", withExtension: "json"))
        let verses = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [Any])
        #expect(!verses.isEmpty)
    }
}
