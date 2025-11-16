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

struct PinnedVerseProvider: AppIntentTimelineProvider {
    typealias Entry = PinnedVerseEntry
    typealias Intent = PinnedVerseConfiguration

    func placeholder(in context: Context) -> Entry {
        Entry(date: Date(), book: "John", chapter: 3, verse: 16, text: "For God so loved the world…")
    }

    func snapshot(for configuration: Intent, in context: Context) async -> Entry {
        let (book, chapter, verse, text) = lookup(configuration: configuration)
        return Entry(date: Date(), book: book, chapter: chapter, verse: verse, text: text)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        let (book, chapter, verse, text) = lookup(configuration: configuration)
        let entry = Entry(date: Date(), book: book, chapter: chapter, verse: verse, text: text)
        // Static content; no auto-refresh until user reconfigures
        return Timeline(entries: [entry], policy: .never)
    }

    // Resolve the selected verse text from BibleData safely
    private func lookup(configuration: Intent) -> (String, Int, Int, String) {
        let bookName = configuration.book.rawValue
        let chapter = max(1, configuration.chapter)
        let verse = max(1, configuration.verse)

        guard let book = BibleData.books.first(where: { $0.name == bookName }) else {
            return (bookName, chapter, verse, "")
        }
        guard let c = book.chapters.first(where: { $0.number == chapter }) else {
            return (bookName, chapter, verse, "")
        }
        guard let v = c.verses.first(where: { $0.number == verse }) else {
            return (bookName, chapter, verse, "")
        }
        return (bookName, chapter, verse, v.text)
    }
}
