import Foundation
import SwiftUI

// Tiny store that reads/writes Bible reading stats to UserDefaults as JSON.
// It provides helpers for formatting, ranking, daily totals, per-book totals,
// per-day per-book totals, chapter completion dates, and last-read info.
final class BibleStatsStore {
    static let shared = BibleStatsStore()
    private init() {}

    struct Defaults {
        static let keyTotals = "bookReadingTimes"                   // [String: Int] all-time per-book
        static let keyDailyTotals = "dailyReadingTimes"             // [String: Int] by ISO date yyyy-MM-dd
        static let keyDailyTotalsByBook = "dailyReadingTimesByBook" // [String: [String: Int]] date -> (book -> seconds)
        static let keyVisitedChapters = "visitedChapters"           // [String]
        static let keyLastRead = "lastReadEntry"                    // JSON of LastRead
        static let keySeenVersesByChapter = "seenVersesByChapter"   // [String: [Int]] keyed by "Book:Chapter"
        static let keyChapterCompletionDates = "chapterCompletionDates" // [String: Date] keyed by "Book:Chapter"
        // Swap this to your app group if desired:
        static var provider: UserDefaults { UserDefaults.standard }
    }

    // MARK: - Models

    struct LastRead: Codable, Equatable {
        let bookName: String
        let chapterNumber: Int
        let date: Date
    }

    // MARK: - Per-book totals (all-time)

    func loadTotals() -> [String: Int] {
        let defaults = Defaults.provider
        guard let data = defaults.data(forKey: Defaults.keyTotals) else { return [:] }
        do {
            let decoded = try JSONDecoder().decode([String: Int].self, from: data)
            return decoded
        } catch {
            return [:]
        }
    }

    func saveTotals(_ totals: [String: Int]) {
        let defaults = Defaults.provider
        do {
            let data = try JSONEncoder().encode(totals)
            defaults.set(data, forKey: Defaults.keyTotals)
        } catch {
            // Ignore encoding error (shouldn't happen with [String:Int])
        }
    }

    func sortedTop(n: Int) -> [(book: String, seconds: Int)] {
        let totals = loadTotals()
        return totals
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }
                return lhs.value > rhs.value
            }
            .prefix(n)
            .map { ($0.key, $0.value) }
    }

    func totalMax() -> Int {
        loadTotals().values.max() ?? 0
    }

    // MARK: - Daily totals (overall)

    func loadDailyTotals() -> [String: Int] {
        let defaults = Defaults.provider
        guard let data = defaults.data(forKey: Defaults.keyDailyTotals) else { return [:] }
        do {
            return try JSONDecoder().decode([String: Int].self, from: data)
        } catch {
            return [:]
        }
    }

    func saveDailyTotals(_ dict: [String: Int]) {
        let defaults = Defaults.provider
        if let data = try? JSONEncoder().encode(dict) {
            defaults.set(data, forKey: Defaults.keyDailyTotals)
        }
    }

    func addToToday(seconds: Int, calendar: Calendar = .current) {
        guard seconds > 0 else { return }
        var dict = loadDailyTotals()
        let today = Self.isoDateString(Date(), calendar: calendar)
        dict[today, default: 0] += seconds
        saveDailyTotals(dict)
    }

    func totalForLast(days: Int, including today: Date = Date(), calendar: Calendar = .current) -> Int {
        guard days > 0 else { return 0 }
        let dict = loadDailyTotals()
        var sum = 0
        for i in 0..<days {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let key = Self.isoDateString(date, calendar: calendar)
                sum += dict[key, default: 0]
            }
        }
        return sum
    }

    func totalForMonth(containing date: Date, calendar: Calendar = .current) -> Int {
        let dict = loadDailyTotals()
        let range = Self.isoKeysForMonth(containing: date, calendar: calendar)
        return range.reduce(0) { $0 + dict[$1, default: 0] }
    }

    // MARK: - Per-day per-book totals (for time-windowed top books)

    private func loadDailyTotalsByBook() -> [String: [String: Int]] {
        let defaults = Defaults.provider
        guard let data = defaults.data(forKey: Defaults.keyDailyTotalsByBook) else { return [:] }
        if let dict = try? JSONDecoder().decode([String: [String: Int]].self, from: data) {
            return dict
        }
        return [:]
    }

    private func saveDailyTotalsByBook(_ dict: [String: [String: Int]]) {
        let defaults = Defaults.provider
        if let data = try? JSONEncoder().encode(dict) {
            defaults.set(data, forKey: Defaults.keyDailyTotalsByBook)
        }
    }

    func addToToday(bookName: String, seconds: Int, calendar: Calendar = .current) {
        guard seconds > 0, !bookName.isEmpty else { return }
        var dict = loadDailyTotalsByBook()
        let today = Self.isoDateString(Date(), calendar: calendar)
        var perBook = dict[today] ?? [:]
        perBook[bookName, default: 0] += seconds
        dict[today] = perBook
        saveDailyTotalsByBook(dict)
    }

    func totalsByBookForMonth(containing date: Date, calendar: Calendar = .current) -> [String: Int] {
        let dict = loadDailyTotalsByBook()
        let keys = Self.isoKeysForMonth(containing: date, calendar: calendar)
        var result: [String: Int] = [:]
        for k in keys {
            if let per = dict[k] {
                for (book, sec) in per {
                    result[book, default: 0] += max(0, sec)
                }
            }
        }
        return result
    }

    // New: per-book totals for a rolling window of the last N days (including today)
    func totalsByBookForLast(days: Int, including today: Date = Date(), calendar: Calendar = .current) -> [String: Int] {
        guard days > 0 else { return [:] }
        let dict = loadDailyTotalsByBook()
        var result: [String: Int] = [:]
        for i in 0..<days {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let key = Self.isoDateString(date, calendar: calendar)
                if let per = dict[key] {
                    for (book, sec) in per {
                        result[book, default: 0] += max(0, sec)
                    }
                }
            }
        }
        return result
    }

    // MARK: - ISO helpers

    static func isoDateString(_ date: Date, calendar: Calendar = .current) -> String {
        var cal = calendar
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 1970
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func isoKeysForMonth(containing date: Date, calendar: Calendar = .current) -> [String] {
        var cal = calendar
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let start = cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
        let range = cal.range(of: .day, in: .month, for: start) ?? 1..<31
        return range.compactMap { day -> String? in
            cal.date(from: DateComponents(year: cal.component(.year, from: start),
                                          month: cal.component(.month, from: start),
                                          day: day)).map { isoDateString($0, calendar: cal) }
        }
    }

    // MARK: - Visited chapters

    func loadVisitedChapters() -> Set<String> {
        let defaults = Defaults.provider
        guard let data = defaults.data(forKey: Defaults.keyVisitedChapters) else { return [] }
        if let arr = try? JSONDecoder().decode([String].self, from: data) {
            return Set(arr)
        }
        return []
    }

    func saveVisitedChapters(_ set: Set<String>) {
        let defaults = Defaults.provider
        if let data = try? JSONEncoder().encode(Array(set)) {
            defaults.set(data, forKey: Defaults.keyVisitedChapters)
        }
    }

    func markVisited(bookName: String, chapterNumber: Int) {
        guard !bookName.isEmpty, chapterNumber > 0 else { return }
        var set = loadVisitedChapters()
        let key = "\(bookName):\(chapterNumber)"
        // Only insert and notify if this is the first time we mark this chapter as visited
        if !set.contains(key) {
            set.insert(key)
            saveVisitedChapters(set)
            // Notify listeners (StatsView, chapter lists) that progress changed
            NotificationCenter.default.post(name: .init("chapterProgressChanged"), object: nil)
        }
    }

    // MARK: - Chapter completion dates (first time a chapter becomes complete)

    private func loadChapterCompletionDates() -> [String: Date] {
        let defaults = Defaults.provider
        guard let data = defaults.data(forKey: Defaults.keyChapterCompletionDates) else { return [:] }
        if let dict = try? JSONDecoder().decode([String: Date].self, from: data) {
            return dict
        }
        return [:]
    }

    private func saveChapterCompletionDates(_ dict: [String: Date]) {
        let defaults = Defaults.provider
        if let data = try? JSONEncoder().encode(dict) {
            defaults.set(data, forKey: Defaults.keyChapterCompletionDates)
        }
    }

    func recordChapterCompletionDate(bookName: String, chapterNumber: Int, date: Date = Date()) {
        let key = "\(bookName):\(chapterNumber)"
        var map = loadChapterCompletionDates()
        if map[key] == nil {
            map[key] = date
            saveChapterCompletionDates(map)
        }
    }

    func chapterCompletions(inMonth date: Date, calendar: Calendar = .current) -> [(book: String, chapter: Int, date: Date)] {
        let map = loadChapterCompletionDates()
        let cal = calendar
        return map.compactMap { (key, d) in
            guard cal.isDate(d, equalTo: date, toGranularity: .month),
                  cal.isDate(d, equalTo: date, toGranularity: .year) else { return nil }
            let parts = key.split(separator: ":")
            guard parts.count == 2, let chap = Int(parts[1]) else { return nil }
            return (book: String(parts[0]), chapter: chap, date: d)
        }
    }

    // MARK: - Last read

    func loadLastRead() -> LastRead? {
        let defaults = Defaults.provider
        guard let data = defaults.data(forKey: Defaults.keyLastRead) else { return nil }
        return try? JSONDecoder().decode(LastRead.self, from: data)
    }

    func saveLastRead(bookName: String, chapterNumber: Int, date: Date = Date()) {
        let entry = LastRead(bookName: bookName, chapterNumber: chapterNumber, date: date)
        let defaults = Defaults.provider
        if let data = try? JSONEncoder().encode(entry) {
            defaults.set(data, forKey: Defaults.keyLastRead)
        }
    }

    // MARK: - OT/NT classification

    func isOT(bookName: String) -> Bool {
        // In fallbackCanon, first 39 are OT
        if let idx = BibleCanon.fallbackCanon.firstIndex(of: bookName) {
            return idx < 39
        }
        // If not found, attempt based on BibleData order if it matches fallback membership by name
        if let idx = BibleData.books.firstIndex(where: { $0.name == bookName }) {
            return idx < 39
        }
        return true
    }

    func splitOTNT(totals: [String: Int]) -> (ot: Int, nt: Int) {
        var ot = 0, nt = 0
        for (book, sec) in totals {
            if isOT(bookName: book) { ot += sec } else { nt += sec }
        }
        return (ot, nt)
    }

    // Format seconds as h:mm:ss if >= 1h, otherwise m:ss
    func format(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        } else {
            return String(format: "%d:%02d", m, sec)
        }
    }

    // MARK: - Seen verses per chapter

    private func seenKey(bookName: String, chapter: Int) -> String {
        "\(bookName):\(chapter)"
    }

    private func loadSeenMap() -> [String: [Int]] {
        let defaults = Defaults.provider
        guard let data = defaults.data(forKey: Defaults.keySeenVersesByChapter) else { return [:] }
        if let dict = try? JSONDecoder().decode([String: [Int]].self, from: data) {
            return dict
        }
        return [:]
    }

    private func saveSeenMap(_ map: [String: [Int]]) {
        let defaults = Defaults.provider
        if let data = try? JSONEncoder().encode(map) {
            defaults.set(data, forKey: Defaults.keySeenVersesByChapter)
        }
    }

    func loadSeenVerses(bookName: String, chapter: Int) -> Set<Int> {
        let map = loadSeenMap()
        let key = seenKey(bookName: bookName, chapter: chapter)
        return Set(map[key] ?? [])
    }

    func saveSeenVerses(_ set: Set<Int>, bookName: String, chapter: Int) {
        var map = loadSeenMap()
        let key = seenKey(bookName: bookName, chapter: chapter)
        map[key] = Array(set).sorted()
        saveSeenMap(map)
    }

    func markVerseSeen(bookName: String, chapter: Int, verse: Int, totalVerses: Int? = nil) {
        guard !bookName.isEmpty, chapter > 0, verse > 0 else { return }
        var seen = loadSeenVerses(bookName: bookName, chapter: chapter)
        if seen.contains(verse) { return }
        seen.insert(verse)
        saveSeenVerses(seen, bookName: bookName, chapter: chapter)

        // If we know total verses, and now all are seen, mark chapter visited (emits notification once) and record completion date.
        if let total = totalVerses, total > 0, seen.count >= total {
            markVisited(bookName: bookName, chapterNumber: chapter)
            recordChapterCompletionDate(bookName: bookName, chapterNumber: chapter, date: Date())
        }
    }

    func unmarkVerseSeen(bookName: String, chapter: Int, verse: Int) {
        guard !bookName.isEmpty, chapter > 0, verse > 0 else { return }
        var seen = loadSeenVerses(bookName: bookName, chapter: chapter)
        if !seen.contains(verse) { return }
        seen.remove(verse)
        saveSeenVerses(seen, bookName: bookName, chapter: chapter)
    }

    func isChapterComplete(bookName: String, chapter: Int, totalVerses: Int) -> Bool {
        guard totalVerses > 0 else { return false }
        let seen = loadSeenVerses(bookName: bookName, chapter: chapter)
        return seen.count >= totalVerses
    }
}

