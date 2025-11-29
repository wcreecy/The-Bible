import Foundation
import SwiftUI

// Tiny store that reads/writes a [bookName: seconds] dictionary to UserDefaults as JSON.
// It also provides helpers for formatting and ranking.
final class BibleStatsStore {
    static let shared = BibleStatsStore()
    private init() {}

    struct Defaults {
        static let keyTotals = "bookReadingTimes"
        static let keyDailyTotals = "dailyReadingTimes"          // [String: Int] keyed by ISO date yyyy-MM-dd
        static let keyVisitedChapters = "visitedChapters"        // [String]
        static let keyLastRead = "lastReadEntry"                 // JSON of LastRead
        static let keySeenVersesByChapter = "seenVersesByChapter" // [String: [Int]] keyed by "Book:Chapter"
        // Swap this to your app group if desired:
        static var provider: UserDefaults { UserDefaults.standard }
    }

    // MARK: - Models

    struct LastRead: Codable, Equatable {
        let bookName: String
        let chapterNumber: Int
        let date: Date
    }

    // MARK: - Per-book totals

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

    // MARK: - Daily totals

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

        // Award streak credit when Bible reading time meets the daily goal
        let totalToday = dict[today, default: 0]
        // Read the user's goal minutes from defaults (same key used elsewhere)
        let goalMinutes = max(1, UserDefaults.standard.integer(forKey: "dailyGoalMinutes"))
        let goalSeconds = goalMinutes * 60
        if totalToday >= goalSeconds {
            // Mark the local day as goal met (idempotent)
            StreakTracker.markGoalMet(on: Date())
        }
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

    static func isoDateString(_ date: Date, calendar: Calendar = .current) -> String {
        var cal = calendar
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 1970
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        return String(format: "%04d-%02d-%02d", y, m, d)
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
            // Rough heuristic: if name exists in fallback, use that; else, assume OT for safety
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

        // If we know total verses, and now all are seen, mark chapter visited (emits notification once).
        if let total = totalVerses, total > 0, seen.count >= total {
            markVisited(bookName: bookName, chapterNumber: chapter)
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

