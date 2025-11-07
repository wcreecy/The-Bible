// This file defines the missing VerseProvider and its Entry type for widget use.
import Foundation
import SwiftUI
import WidgetKit

struct VerseWidgetEntry: TimelineEntry {
    let date: Date
    let text: String
    let book: String
    let chapter: Int
    let verse: Int
    let fontColor: Color
}

struct VerseProvider: TimelineProvider {
    typealias Entry = VerseWidgetEntry
    
    func placeholder(in context: Context) -> Entry {
        Entry(date: Date(), text: "For God so loved the world...", book: "John", chapter: 3, verse: 16, fontColor: .primary)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> ()) {
        let entry = Entry(date: Date(), text: "In the beginning was the Word...", book: "John", chapter: 1, verse: 1, fontColor: .primary)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // For demo, load from UserDefaults AppGroup (matches app and widget refresh logic)
        let shared = UserDefaults(suiteName: "group.bible.app")
        let book = shared?.string(forKey: "verseOfDayBook") ?? "John"
        let chapter = shared?.integer(forKey: "verseOfDayChapter") ?? 1
        let verse = shared?.integer(forKey: "verseOfDayNumber") ?? 1
        let text = shared?.string(forKey: "verseOfDayText") ?? "For God so loved the world..."
        let entry = Entry(date: Date(), text: text, book: book, chapter: chapter, verse: verse, fontColor: .primary)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}
