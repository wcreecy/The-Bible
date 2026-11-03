import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class FocusViewModel {
    /// The saved focus, as stored in the app group and shown in the Live Activity.
    /// Edits in progress live in the card's draft until they are saved.
    private(set) var title: String = ""
    private(set) var body: String = ""
    private(set) var savedAt: Date? = nil

    var hasSaved: Bool {
        hasNonWhitespaceLetters(in: title) || hasNonWhitespaceLetters(in: body)
    }

    // App Group storage (match existing behavior)
    private var sharedDefaults: UserDefaults? { UserDefaults(suiteName: "group.bible.app") }

    // Initialize from storage on demand
    func loadFromStorage() {
        guard let shared = sharedDefaults else {
            title = ""
            body = ""
            savedAt = nil
            return
        }
        title = (shared.string(forKey: "focusTitle") ?? "")
        body = (shared.string(forKey: "focusBody") ?? "")
        let ts = shared.double(forKey: "focusSavedAt")
        savedAt = ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    func save(title newTitle: String, body newBody: String) {
        let cleanTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = newBody.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = Date()
        title = cleanTitle
        body = cleanBody
        savedAt = now

        if let shared = sharedDefaults {
            shared.set(cleanTitle, forKey: "focusTitle")
            shared.set(cleanBody, forKey: "focusBody")
            shared.set(now.timeIntervalSince1970, forKey: "focusSavedAt")
        }

        // Keep the saved focus visible in the prayer Live Activity.
        PrayerTimerActivityController.shared.showFocus(
            title: cleanTitle.isEmpty ? nil : cleanTitle,
            body: cleanBody.isEmpty ? nil : cleanBody
        )
    }

    func clear() {
        title = ""
        body = ""
        savedAt = nil

        if let shared = sharedDefaults {
            shared.set("", forKey: "focusTitle")
            shared.set("", forKey: "focusBody")
            shared.removeObject(forKey: "focusSavedAt")
        }

        PrayerTimerActivityController.shared.clearFocus()
    }

    func hasNonWhitespaceLetters(in s: String) -> Bool {
        let letters = CharacterSet.letters
        return s.unicodeScalars.contains { letters.contains($0) }
    }
}
