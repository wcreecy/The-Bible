#if false
import Foundation
import SwiftData

@Model
final class ReaderSettings {
    // Minimal placeholder model for app-wide reader settings.
    // You can extend this later with real preferences (e.g., font size, theme, etc.).
    var schemaVersion: Int

    init(schemaVersion: Int = 1) {
        self.schemaVersion = schemaVersion
    }
}
#endif
