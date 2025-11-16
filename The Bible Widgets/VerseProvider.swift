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
        let entry = loadCurrentEntry()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = loadCurrentEntry()
        let nextRefresh = nextAutoRefreshDate()
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    // MARK: - Helpers

    private func loadCurrentEntry() -> Entry {
        let shared = UserDefaults(suiteName: "group.bible.app")
        let book = shared?.string(forKey: "verseOfDayBook") ?? "John"
        let chapter = shared?.integer(forKey: "verseOfDayChapter") ?? 1
        let verse = shared?.integer(forKey: "verseOfDayNumber") ?? 1
        let text = shared?.string(forKey: "verseOfDayText") ?? "For God so loved the world..."
        return Entry(date: Date(), text: text, book: book, chapter: chapter, verse: verse, fontColor: .primary)
    }

    private func nextAutoRefreshDate(from now: Date = Date()) -> Date {
        let defaults = UserDefaults.standard
        let h1 = defaults.integer(forKey: "votdRefresh1Hour")
        let m1 = defaults.integer(forKey: "votdRefresh1Minute")
        let h2 = defaults.integer(forKey: "votdRefresh2Hour")
        let m2 = defaults.integer(forKey: "votdRefresh2Minute")

        func dateForToday(hour: Int, minute: Int, from now: Date) -> Date? {
            let cal = Calendar.current
            let base = cal.dateComponents([.year, .month, .day], from: now)
            return cal.date(from: DateComponents(year: base.year, month: base.month, day: base.day, hour: hour, minute: minute, second: 0))
        }

        let cal = Calendar.current
        guard let t1 = dateForToday(hour: h1, minute: m1, from: now),
              let t2 = dateForToday(hour: h2, minute: m2, from: now) else {
            // Fallback: refresh later today
            return now.addingTimeInterval(3600)
        }
        if now < t1 { return t1 }
        if now < t2 { return t2 }
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now) ?? now
        return dateForToday(hour: h1, minute: m1, from: tomorrow) ?? now.addingTimeInterval(86400)
    }
}
