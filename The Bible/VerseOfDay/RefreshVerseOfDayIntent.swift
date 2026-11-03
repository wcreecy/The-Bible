import Foundation
import AppIntents
import WidgetKit

struct RefreshVerseOfDayIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh Verse of the Day"
    static var description = IntentDescription("Refresh the Verse of the Day and update the widget.")
    static var openAppWhenRun: Bool = false

    // Update this to your real App Group identifier and enable it in both app and widget targets.
    private static let appGroupID = "group.bible.app"

    func perform() async throws -> some IntentResult {
        // Read current scope from standard defaults (app settings live here)
        let defaults = UserDefaults.standard
        let scopeRaw = defaults.string(forKey: "verseOfDayScope") ?? "whole"
        let specificBook = defaults.string(forKey: "verseOfDaySpecificBook") ?? ""

        let allBooks = await BibleRepository.shared.loadAllBooks()
        // Prefer a verse that hasn't been shown lately; with nothing else left, any verse will do.
        let recent = Set(VerseOfDaySelector.History.recent())
        guard let selection = VerseOfDaySelector.select(
            from: allBooks,
            scopeRaw: scopeRaw,
            specificBook: specificBook,
            avoiding: { recent.contains($0.historyKey) }
        ) ?? VerseOfDaySelector.select(
            from: allBooks,
            scopeRaw: scopeRaw,
            specificBook: specificBook
        ) else {
            return .result()
        }
        VerseOfDaySelector.History.record(selection)

        // Persist to standard defaults (so the app UI updates)
        defaults.set(selection.bookName, forKey: "verseOfDayBook")
        defaults.set(selection.chapterNumber, forKey: "verseOfDayChapter")
        defaults.set(selection.verseNumber, forKey: "verseOfDayNumber")
        defaults.set(selection.text, forKey: "verseOfDayText")

        // Persist to shared App Group (so the widget reads the same values)
        if let shared = UserDefaults(suiteName: Self.appGroupID) {
            shared.set(selection.bookName, forKey: "verseOfDayBook")
            shared.set(selection.chapterNumber, forKey: "verseOfDayChapter")
            shared.set(selection.verseNumber, forKey: "verseOfDayNumber")
            shared.set(selection.text, forKey: "verseOfDayText")
            shared.set(Date(), forKey: "verseOfDayChangedAt")
        }

        // Reload only the Verse widget timelines (debounce not available in intents; rate-limits still apply)
        WidgetCenter.shared.reloadTimelines(ofKind: "VerseWidget")
        return .result()
    }

}
