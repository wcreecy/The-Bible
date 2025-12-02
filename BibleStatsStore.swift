import Foundation
import SwiftUI

// Cached store that reads/writes Bible reading stats to UserDefaults as JSON,
// but keeps in-memory caches to avoid repeated decoding on hot paths.
@MainActor
final class BibleStatsStore {
    static let shared = BibleStatsStore()
    private init() {
        // Lazy load on first access via getters, not here, to keep init cheap.
    }

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

    // MARK: - In-memory caches

    // All caches are loaded lazily on first read and kept in memory.
    private var cacheTotals: [String: Int]?
    private var cacheDailyTotals: [String: Int]?
    private var cacheDailyTotalsByBook: [String: [String: Int]]?
    private var cacheVisitedChapters: Set<String>?
    private var cacheLastRead: LastRead?
    // Internally store seenVerses as Set<Int> for fast lookups
    private typealias SeenMap = [String: Set<Int>]
    private var cacheSeenVersesByChapter: SeenMap?
    private var cacheChapterCompletionDates: [String: Date]?

    // MARK: - JSON helpers

    private func loadJSON<T: Decodable>(key: String, default defaultValue: T) -> T {
        let defaults = Defaults.provider
        guard let data = defaults.data(forKey: key) else { return defaultValue }
        return (try? JSONDecoder().decode(T.self, from: data)) ?? defaultValue
    }

    private func saveJSON<T: Encodable>(_ value: T, key: String) {
        let defaults = Defaults.provider
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    // MARK: - Per-book totals (all-time)

    func loadTotals() -> [String: Int] {
        if let cached = cacheTotals { return cached }
        let decoded: [String: Int] = loadJSON(key: Defaults.keyTotals, default: [:])
        cacheTotals = decoded
        return decoded
    }

    func saveTotals(_ totals: [String: Int]) {
        cacheTotals = totals
        saveJSON(totals, key: Defaults.keyTotals)
        // Optional: push totals to iCloud KVS for faster propagation
        iCloudSyncCoordinator.shared.pushKey(Defaults.keyTotals)
        // Notify listeners that aggregates changed
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
    }

    // MARK: - Daily totals (overall)

    func loadDailyTotals() -> [String: Int] {
        if let cached = cacheDailyTotals { return cached }
        let decoded: [String: Int] = loadJSON(key: Defaults.keyDailyTotals, default: [:])
        cacheDailyTotals = decoded
        return decoded
    }

    func saveDailyTotals(_ dict: [String: Int]) {
        cacheDailyTotals = dict
        saveJSON(dict, key: Defaults.keyDailyTotals)
        // Push and notify
        iCloudSyncCoordinator.shared.pushKey(Defaults.keyDailyTotals)
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
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
        if let cached = cacheDailyTotalsByBook { return cached }
        let dict: [String: [String: Int]] = loadJSON(key: Defaults.keyDailyTotalsByBook, default: [:])
        cacheDailyTotalsByBook = dict
        return dict
    }

    private func saveDailyTotalsByBook(_ dict: [String: [String: Int]]) {
        cacheDailyTotalsByBook = dict
        saveJSON(dict, key: Defaults.keyDailyTotalsByBook)
        // Push and notify
        iCloudSyncCoordinator.shared.pushKey(Defaults.keyDailyTotalsByBook)
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
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

    // Per-book totals for a rolling window of the last N days (including today)
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
        cal.timeZone = .gmt
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 1970
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func isoKeysForMonth(containing date: Date, calendar: Calendar = .current) -> [String] {
        var cal = calendar
        cal.timeZone = .gmt
        let year = cal.component(.year, from: date)
        let month = cal.component(.month, from: date)
        guard let start = cal.date(from: DateComponents(year: year, month: month)),
              let range = cal.range(of: .day, in: .month, for: start) else {
            return []
        }
        return range.compactMap { day -> String? in
            cal.date(from: DateComponents(year: year, month: month, day: day)).map { isoDateString($0, calendar: cal) }
        }
    }

    // MARK: - Visited chapters

    func loadVisitedChapters() -> Set<String> {
        if let cached = cacheVisitedChapters { return cached }
        let arr: [String] = loadJSON(key: Defaults.keyVisitedChapters, default: [])
        let set = Set(arr)
        cacheVisitedChapters = set
        return set
    }

    func saveVisitedChapters(_ set: Set<String>) {
        cacheVisitedChapters = set
        saveJSON(Array(set), key: Defaults.keyVisitedChapters)
        // Push and notify
        iCloudSyncCoordinator.shared.pushKey(Defaults.keyVisitedChapters)
        NotificationCenter.default.post(name: .chapterProgressChanged, object: nil)
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
    }

    func markVisited(bookName: String, chapterNumber: Int) {
        guard !bookName.isEmpty, chapterNumber > 0 else { return }
        var set = loadVisitedChapters()
        let key = "\(bookName):\(chapterNumber)"
        if !set.contains(key) {
            set.insert(key)
            saveVisitedChapters(set)
        }
    }

    // MARK: - Chapter completion dates

    private func loadChapterCompletionDates() -> [String: Date] {
        if let cached = cacheChapterCompletionDates { return cached }
        let dict: [String: Date] = loadJSON(key: Defaults.keyChapterCompletionDates, default: [:])
        cacheChapterCompletionDates = dict
        return dict
    }

    private func saveChapterCompletionDates(_ dict: [String: Date]) {
        cacheChapterCompletionDates = dict
        saveJSON(dict, key: Defaults.keyChapterCompletionDates)
        // Push and notify
        iCloudSyncCoordinator.shared.pushKey(Defaults.keyChapterCompletionDates)
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
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
        if let cached = cacheLastRead { return cached }
        let decoded: LastRead? = {
            let defaults = Defaults.provider
            guard let data = defaults.data(forKey: Defaults.keyLastRead) else { return nil }
            return try? JSONDecoder().decode(LastRead.self, from: data)
        }()
        cacheLastRead = decoded
        return decoded
    }

    func saveLastRead(bookName: String, chapterNumber: Int, date: Date = Date()) {
        let entry = LastRead(bookName: bookName, chapterNumber: chapterNumber, date: date)
        cacheLastRead = entry
        saveJSON(entry, key: Defaults.keyLastRead)
        // Push and notify
        iCloudSyncCoordinator.shared.pushKey(Defaults.keyLastRead)
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
    }

    // MARK: - OT/NT classification

    func isOT(bookName: String) -> Bool {
        if let idx = BibleCanon.fallbackCanon.firstIndex(of: bookName) {
            return idx < 39
        }
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

    // MARK: - Seen verses per chapter (cached)

    private func seenKey(bookName: String, chapter: Int) -> String {
        "\(bookName):\(chapter)"
    }

    // Returns cached map; lazily loads and converts arrays to sets once.
    private func loadSeenMap() -> SeenMap {
        if let cached = cacheSeenVersesByChapter { return cached }
        let dictArrays: [String: [Int]] = loadJSON(key: Defaults.keySeenVersesByChapter, default: [:])
        let converted: SeenMap = dictArrays.mapValues { Set($0) }
        cacheSeenVersesByChapter = converted
        return converted
    }

    private func saveSeenMap(_ map: SeenMap) {
        cacheSeenVersesByChapter = map
        // Convert sets to sorted arrays for storage
        let toStore: [String: [Int]] = map.mapValues { Array($0).sorted() }
        saveJSON(toStore, key: Defaults.keySeenVersesByChapter)
        // Push seen verses to iCloud KVS immediately for faster cross-device updates
        iCloudSyncCoordinator.shared.pushKey(Defaults.keySeenVersesByChapter)
        // Notify any open views locally to refresh immediately
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
        // Also let chapter-level listeners update (e.g., StatsView book/chapter cards)
        NotificationCenter.default.post(name: .chapterProgressChanged, object: nil)
    }

    func loadSeenVerses(bookName: String, chapter: Int) -> Set<Int> {
        let map = loadSeenMap()
        let key = seenKey(bookName: bookName, chapter: chapter)
        return map[key] ?? []
    }

    func saveSeenVerses(_ set: Set<Int>, bookName: String, chapter: Int) {
        var map = loadSeenMap()
        let key = seenKey(bookName: bookName, chapter: chapter)
        map[key] = set
        saveSeenMap(map)
    }

    func markVerseSeen(bookName: String, chapter: Int, verse: Int, totalVerses: Int? = nil) {
        guard !bookName.isEmpty, chapter > 0, verse > 0 else { return }
        var map = loadSeenMap()
        let key = seenKey(bookName: bookName, chapter: chapter)
        var seen = map[key] ?? Set<Int>()
        if seen.contains(verse) { return }
        seen.insert(verse)
        map[key] = seen
        saveSeenMap(map)

        if let total = totalVerses, total > 0, seen.count >= total {
            markVisited(bookName: bookName, chapterNumber: chapter)
            recordChapterCompletionDate(bookName: bookName, chapterNumber: chapter, date: Date())
        }
    }

    func unmarkVerseSeen(bookName: String, chapter: Int, verse: Int) {
        guard !bookName.isEmpty, chapter > 0, verse > 0 else { return }
        var map = loadSeenMap()
        let key = seenKey(bookName: bookName, chapter: chapter)
        var seen = map[key] ?? Set<Int>()
        if !seen.contains(verse) { return }
        seen.remove(verse)
        map[key] = seen
        saveSeenMap(map)
    }

    func isChapterComplete(bookName: String, chapter: Int, totalVerses: Int) -> Bool {
        guard totalVerses > 0 else { return false }
        let key = seenKey(bookName: bookName, chapter: chapter)
        let seen = loadSeenMap()[key] ?? []
        return seen.count >= totalVerses
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let chapterProgressChanged = Notification.Name("chapterProgressChanged")
}
