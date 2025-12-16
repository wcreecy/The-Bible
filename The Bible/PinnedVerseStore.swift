import Foundation
import WidgetKit
import Combine

@MainActor
final class PinnedVerseStore: ObservableObject {
    @Published var pinnedBookName: String = ""
    @Published var pinnedChapterNumber: Int = 0
    @Published var pinnedVerseNumber: Int = 0

    private let suite = "group.bible.app"

    func load() async {
        guard let shared = UserDefaults(suiteName: suite) else {
            await applyPinned(book: "", chapter: 0, verse: 0)
            return
        }
        let book = (shared.string(forKey: "pinnedVerseBook") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let chap = shared.integer(forKey: "pinnedVerseChapter")
        let verse = shared.integer(forKey: "pinnedVerseNumber")
        if book.isEmpty || chap <= 0 || verse <= 0 {
            await applyPinned(book: "", chapter: 0, verse: 0)
            return
        }
        await applyPinned(book: book, chapter: chap, verse: verse)
    }

    func set(bookName: String, chapter: Int, verse: Int, text: String) async {
        guard let shared = UserDefaults(suiteName: suite) else { return }
        shared.set(bookName, forKey: "pinnedVerseBook")
        shared.set(chapter, forKey: "pinnedVerseChapter")
        shared.set(verse, forKey: "pinnedVerseNumber")
        shared.set(text, forKey: "pinnedVerseText")

        // Apply pinned values on the next MainActor turn to avoid publishing during view updates.
        await applyPinned(book: bookName, chapter: chapter, verse: verse)

        // Yield once more to let observers process the change before reloading widgets.
        await Task.yield()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func clear() async {
        guard let shared = UserDefaults(suiteName: suite) else { return }
        shared.removeObject(forKey: "pinnedVerseBook")
        shared.removeObject(forKey: "pinnedVerseChapter")
        shared.removeObject(forKey: "pinnedVerseNumber")
        shared.removeObject(forKey: "pinnedVerseText")

        // Apply cleared values on the next MainActor turn to avoid publishing during view updates.
        await applyPinned(book: "", chapter: 0, verse: 0)

        // Yield once more to let observers process the change before reloading widgets.
        await Task.yield()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func isPinned(bookName: String, chapter: Int, verse: Int) -> Bool {
        pinnedBookName == bookName && pinnedChapterNumber == chapter && pinnedVerseNumber == verse
    }

    // Schedule the mutation on the next MainActor turn and await it, so we never publish during a view update.
    private func applyPinned(book: String, chapter: Int, verse: Int) async {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                if self.pinnedBookName != book || self.pinnedChapterNumber != chapter || self.pinnedVerseNumber != verse {
                    self.pinnedBookName = book
                    self.pinnedChapterNumber = chapter
                    self.pinnedVerseNumber = verse
                }
                continuation.resume()
            }
        }
    }
}
