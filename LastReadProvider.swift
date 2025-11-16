// LastReadProvider.swift
import Foundation
import SwiftUI
import WidgetKit

struct LastReadEntry: TimelineEntry {
    let date: Date
    let text: String
    let book: String
    let chapter: Int
    let verse: Int
}

struct LastReadProvider: TimelineProvider {
    typealias Entry = LastReadEntry

    func placeholder(in context: Context) -> Entry {
        Entry(date: Date(), text: "The LORD is my shepherd; I shall not want.", book: "Psalms", chapter: 23, verse: 1)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> ()) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = loadEntry()
        // Refresh occasionally; app will also trigger reloads when last read changes.
        let refresh = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date().addingTimeInterval(21600)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func loadEntry() -> Entry {
        let shared = UserDefaults(suiteName: "group.bible.app")
        let book = shared?.string(forKey: "lastReadBook") ?? ""
        let chapter = shared?.integer(forKey: "lastReadChapter") ?? 0
        let verse = shared?.integer(forKey: "lastReadVerse") ?? 0
        let text = shared?.string(forKey: "lastReadText") ?? ""
        return Entry(date: Date(), text: text, book: book, chapter: chapter, verse: verse)
    }
}
