import Foundation
import SwiftUI
import Combine

@MainActor
final class FocusViewModel: ObservableObject {
    // Published UI state
    @Published var title: String = ""
    @Published var body: String = ""
    @Published var hasSaved: Bool = false
    @Published var savedAt: Date? = nil

    // App Group storage (match existing behavior)
    private var sharedDefaults: UserDefaults? { UserDefaults(suiteName: "group.bible.app") }

    // Live Activities toggle (read-only hint for UI)
    var liveActivitiesEnabled: Bool {
        UserDefaults.standard.bool(forKey: "liveActivitiesEnabled")
    }

    // Initialize from storage on demand
    func loadFromStorage() {
        guard let shared = sharedDefaults else {
            title = ""
            body = ""
            hasSaved = false
            savedAt = nil
            return
        }
        title = (shared.string(forKey: "focusTitle") ?? "")
        body = (shared.string(forKey: "focusBody") ?? "")
        let ts = shared.double(forKey: "focusSavedAt")
        savedAt = ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        hasSaved = hasNonWhitespaceLetters(in: title) || hasNonWhitespaceLetters(in: body)
    }

    func save() {
        guard let shared = sharedDefaults else { return }
        shared.set(title, forKey: "focusTitle")
        shared.set(body, forKey: "focusBody")
        let now = Date()
        shared.set(now.timeIntervalSince1970, forKey: "focusSavedAt")
        savedAt = now
        hasSaved = hasNonWhitespaceLetters(in: title) || hasNonWhitespaceLetters(in: body)

        // Live Activities behavior: stop Stopwatch, ensure Focus activity
        StopwatchActivityController.shared.cancel()
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        PrayerTimerActivityController.shared.ensureActivityForFocus(
            title: cleanTitle.isEmpty ? nil : cleanTitle,
            body: cleanBody.isEmpty ? nil : cleanBody
        )
    }

    func clear() {
        title = ""
        body = ""
        hasSaved = false
        savedAt = nil

        guard let shared = sharedDefaults else { return }
        shared.set("", forKey: "focusTitle")
        shared.set("", forKey: "focusBody")
        shared.removeObject(forKey: "focusSavedAt")

        // Live Activities: cancel focus activity
        PrayerTimerActivityController.shared.cancel()
    }

    private func hasNonWhitespaceLetters(in s: String) -> Bool {
        let letters = CharacterSet.letters
        return s.unicodeScalars.contains { letters.contains($0) }
    }
}
