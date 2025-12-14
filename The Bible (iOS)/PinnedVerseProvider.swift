import Foundation
import SwiftUI
import WidgetKit

struct PinnedVerseEntry: TimelineEntry {
    let date: Date
    let book: String
    let chapter: Int
    let verse: Int
    let text: String
}

struct PinnedVerseProvider: TimelineProvider {
    typealias Entry = PinnedVerseEntry

    func placeholder(in context: Context) -> Entry {
        Entry(date: Date(), book: "John", chapter: 3, verse: 16, text: "For God so loved the world…")
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        let entry = loadCurrentEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let entry = loadCurrentEntry()
        // Static content; no auto-refresh until the app changes the pinned verse and reloads timelines.
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }

    // MARK: - Helpers

    private func loadCurrentEntry() -> Entry {
        if let (book, chapter, verse, text) = loadPinnedFromShared() {
            return Entry(date: Date(), book: book, chapter: chapter, verse: verse, text: text)
        } else {
            // No pinned verse set yet
            return Entry(date: Date(), book: "", chapter: 0, verse: 0, text: "")
        }
    }

    private func loadPinnedFromShared() -> (String, Int, Int, String)? {
        guard let shared = UserDefaults(suiteName: "group.bible.app") else { return nil }
        let book = (shared.string(forKey: "pinnedVerseBook") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let chapter = shared.integer(forKey: "pinnedVerseChapter")
        let verse = shared.integer(forKey: "pinnedVerseNumber")
        var text = (shared.string(forKey: "pinnedVerseText") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !book.isEmpty, chapter > 0, verse > 0 else { return nil }

        if text.isEmpty {
            // Fill text from BibleData if only reference was stored
            if let b = BibleData.books.first(where: { $0.name == book }),
               let c = b.chapters.first(where: { $0.number == chapter }),
               let v = c.verses.first(where: { $0.number == verse }) {
                text = v.text
            }
        }
        return (book, max(1, chapter), max(1, verse), text)
    }
}

