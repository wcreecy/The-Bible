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

        // Compute a new random verse according to scope
        let (book, chapter, verse, text) = pickRandomVerse(scopeRaw: scopeRaw, specificBook: specificBook)

        // Persist to standard defaults (so the app UI updates)
        defaults.set(book, forKey: "verseOfDayBook")
        defaults.set(chapter, forKey: "verseOfDayChapter")
        defaults.set(verse, forKey: "verseOfDayNumber")
        defaults.set(text, forKey: "verseOfDayText")

        // Persist to shared App Group (so the widget reads the same values)
        if let shared = UserDefaults(suiteName: Self.appGroupID) {
            shared.set(book, forKey: "verseOfDayBook")
            shared.set(chapter, forKey: "verseOfDayChapter")
            shared.set(verse, forKey: "verseOfDayNumber")
            shared.set(text, forKey: "verseOfDayText")
        }

        // Reload all widget timelines
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }

    // MARK: - Helpers
    private func pickRandomVerse(scopeRaw: String, specificBook: String) -> (book: String, chapter: Int, verse: Int, text: String) {
        let allBooks = BibleData.books
        guard !allBooks.isEmpty else { return ("", 0, 0, "") }

        enum Scope { case old, new, whole, book }
        let scope: Scope
        switch scopeRaw {
        case "old": scope = .old
        case "new": scope = .new
        case "book": scope = .book
        default: scope = .whole
        }

        let oldTestament: Set<String> = [
            "Genesis","Exodus","Leviticus","Numbers","Deuteronomy",
            "Joshua","Judges","Ruth","1 Samuel","2 Samuel",
            "1 Kings","2 Kings","1 Chronicles","2 Chronicles","Ezra",
            "Nehemiah","Esther","Job","Psalms","Proverbs",
            "Ecclesiastes","Song of Solomon","Isaiah","Jeremiah","Lamentations",
            "Ezekiel","Daniel","Hosea","Joel","Amos",
            "Obadiah","Jonah","Micah","Nahum","Habakkuk",
            "Zephaniah","Haggai","Zechariah","Malachi"
        ]

        let books: [Book]
        switch scope {
        case .old:
            books = allBooks.filter { oldTestament.contains($0.name) }
        case .new:
            books = allBooks.filter { !oldTestament.contains($0.name) }
        case .book:
            if let chosen = allBooks.first(where: { $0.name == specificBook }) {
                books = [chosen]
            } else {
                books = allBooks
            }
        case .whole:
            books = allBooks
        }

        guard let book = books.randomElement(),
              let chapter = book.chapters.randomElement(),
              let verse = chapter.verses.randomElement() else {
            return ("", 0, 0, "")
        }
        return (book.name, chapter.number, verse.number, verse.text)
    }
}
