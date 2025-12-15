import Foundation
import WidgetKit
import Combine

@MainActor
final class PinnedVerseStore: ObservableObject {
    @Published var pinnedBookName: String = ""
    @Published var pinnedChapterNumber: Int = 0
    @Published var pinnedVerseNumber: Int = 0

    private let suite = "group.bible.app"

    func load() {
        guard let shared = UserDefaults(suiteName: suite) else {
            pinnedBookName = ""
            pinnedChapterNumber = 0
            pinnedVerseNumber = 0
            return
        }
        let book = (shared.string(forKey: "pinnedVerseBook") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let chap = shared.integer(forKey: "pinnedVerseChapter")
        let verse = shared.integer(forKey: "pinnedVerseNumber")
        if book.isEmpty || chap <= 0 || verse <= 0 {
            pinnedBookName = ""
            pinnedChapterNumber = 0
            pinnedVerseNumber = 0
            return
        }
        pinnedBookName = book
        pinnedChapterNumber = chap
        pinnedVerseNumber = verse
    }

    func set(bookName: String, chapter: Int, verse: Int, text: String) {
        guard let shared = UserDefaults(suiteName: suite) else { return }
        shared.set(bookName, forKey: "pinnedVerseBook")
        shared.set(chapter, forKey: "pinnedVerseChapter")
        shared.set(verse, forKey: "pinnedVerseNumber")
        shared.set(text, forKey: "pinnedVerseText")
        pinnedBookName = bookName
        pinnedChapterNumber = chapter
        pinnedVerseNumber = verse
        WidgetCenter.shared.reloadAllTimelines()
    }

    func clear() {
        guard let shared = UserDefaults(suiteName: suite) else { return }
        shared.removeObject(forKey: "pinnedVerseBook")
        shared.removeObject(forKey: "pinnedVerseChapter")
        shared.removeObject(forKey: "pinnedVerseNumber")
        shared.removeObject(forKey: "pinnedVerseText")
        pinnedBookName = ""
        pinnedChapterNumber = 0
        pinnedVerseNumber = 0
        WidgetCenter.shared.reloadAllTimelines()
    }

    func isPinned(bookName: String, chapter: Int, verse: Int) -> Bool {
        pinnedBookName == bookName && pinnedChapterNumber == chapter && pinnedVerseNumber == verse
    }
}
