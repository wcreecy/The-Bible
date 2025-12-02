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

    // MARK: - Cache reset for external updates

    func resetCaches() {
        cacheTotals = nil
        cacheDailyTotals = nil
        cacheDailyTotalsByBook = nil
        cacheVisitedChapters = nil
        cacheLastRead = nil
        cacheSeenVersesByChapter = nil
        cacheChapterCompletionDates = nil
    }

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

    // Prefer session-based computation for the month to avoid double-counting from KVS merges.
    func totalForMonth(containing date: Date, calendar: Calendar = .current) -> Int {
        let fromSessions = totalForMonthFromSessions(containing: date, calendar: calendar)
        if fromSessions > 0 {
            return fromSessions
        }
        // Fallback to daily totals if no sessions are available (e.g., legacy data)
        let dict = loadDailyTotals()
        let range = Self.isoKeysForMonth(containing: date, calendar: calendar)
        return range.reduce(0) { $0 + dict[$1, default: 0] }
    }

    private func totalForMonthFromSessions(containing date: Date, calendar: Calendar = .current) -> Int {
        let sessions = ReadingSessionsStore.shared.sessions(inMonthContaining: date, calendar: calendar)
        var total = 0
        for s in sessions {
            total += Int(max(0, s.end.timeIntervalSince(s.start)))
        }
        return total
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

    // MARK: - OT/NT split

    // Splits a per-book totals map into Old Testament vs New Testament sums.
    // Uses the canonical order in BibleData.books, with "Matthew" as the first NT book.
    func splitOTNT(totals: [String: Int]) -> (ot: Int, nt: Int) {
        let books = BibleData.books
        // Build name -> index map
        let indexMap: [String: Int] = Dictionary(uniqueKeysWithValues: books.enumerated().map { ($1.name, $0) })
        let matthewIndex: Int? = indexMap["Matthew"]
        // If we have canonical order with Matthew present, use index comparison
        if let mIdx = matthewIndex {
            var ot = 0
            var nt = 0
            for (book, seconds) in totals {
                let idx = indexMap[book] ?? Int.max
                if idx < mIdx { ot += max(0, seconds) } else { nt += max(0, seconds) }
            }
            return (ot, nt)
        } else {
            // Fallback: hardcoded sets (covers sample data too)
            let otSet: Set<String> = [
                "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy",
                "Joshua", "Judges", "Ruth",
                "1 Samuel", "2 Samuel",
                "1 Kings", "2 Kings",
                "1 Chronicles", "2 Chronicles",
                "Ezra", "Nehemiah", "Esther",
                "Job", "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon",
                "Isaiah", "Jeremiah", "Lamentations", "Ezekiel", "Daniel",
                "Hosea", "Joel", "Amos", "Obadiah", "Jonah",
                "Micah", "Nahum", "Habakkuk", "Zephaniah",
                "Haggai", "Zechariah", "Malachi"
            ]
            var ot = 0
            var nt = 0
            for (book, seconds) in totals {
                if otSet.contains(book) { ot += max(0, seconds) } else { nt += max(0, seconds) }
            }
            return (ot, nt)
        }
    }

    // MARK: - Visited chapters (chapter-level completion)

    func loadVisitedChapters() -> Set<String> {
        if let cached = cacheVisitedChapters { return cached }
        // Stored as [String] JSON; convert to Set
        let arr: [String] = loadJSON(key: Defaults.keyVisitedChapters, default: [])
        let set = Set(arr)
        cacheVisitedChapters = set
        return set
    }

    func saveVisitedChapters(_ set: Set<String>) {
        cacheVisitedChapters = set
        let arr = Array(set).sorted()
        saveJSON(arr, key: Defaults.keyVisitedChapters)
        // Push and notify
        iCloudSyncCoordinator.shared.pushKey(Defaults.keyVisitedChapters)
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
    }

    func markVisited(bookName: String, chapterNumber: Int) {
        var set = loadVisitedChapters()
        set.insert("\(bookName):\(chapterNumber)")
        saveVisitedChapters(set)
    }

    // MARK: - Last read

    func loadLastRead() -> LastRead? {
        if let cached = cacheLastRead { return cached }
        // Decode optional LastRead (may not exist yet)
        let defaults = Defaults.provider
        guard let data = defaults.data(forKey: Defaults.keyLastRead) else { return nil }
        let decoded = try? JSONDecoder().decode(LastRead.self, from: data)
        cacheLastRead = decoded
        return decoded
    }

    func saveLastRead(bookName: String, chapterNumber: Int, date: Date) {
        let entry = LastRead(bookName: bookName, chapterNumber: chapterNumber, date: date)
        cacheLastRead = entry
        saveJSON(entry, key: Defaults.keyLastRead)
        // Push and notify
        iCloudSyncCoordinator.shared.pushKey(Defaults.keyLastRead)
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
    }

    // MARK: - Verse-level progress (seen verses + chapter completion dates)

    func loadSeenVerses(bookName: String, chapter: Int) -> Set<Int> {
        if let cached = cacheSeenVersesByChapter {
            return cached["\(bookName):\(chapter)"] ?? []
        }
        // Load [String: [Int]] from JSON and convert to Set<Int>
        let raw: [String: [Int]] = loadJSON(key: Defaults.keySeenVersesByChapter, default: [:])
        var map: SeenMap = [:]
        for (k, arr) in raw {
            map[k] = Set(arr)
        }
        cacheSeenVersesByChapter = map
        return map["\(bookName):\(chapter)"] ?? []
    }

    func saveSeenVerses(_ verses: [Int], bookName: String, chapter: Int) {
        var map = cacheSeenVersesByChapter ?? [:]
        map["\(bookName):\(chapter)"] = Set(verses)
        cacheSeenVersesByChapter = map
        // Persist as [String: [Int]] sorted
        var raw: [String: [Int]] = [:]
        for (k, set) in map {
            raw[k] = Array(set).sorted()
        }
        saveJSON(raw, key: Defaults.keySeenVersesByChapter)
        // Push and notify
        iCloudSyncCoordinator.shared.pushKey(Defaults.keySeenVersesByChapter)
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
    }

    // Convenience to mark one verse and optionally set completion date when full
    func markVerseSeen(bookName: String, chapter: Int, verse: Int, totalVerses: Int) {
        var seen = loadSeenVerses(bookName: bookName, chapter: chapter)
        if !seen.contains(verse) {
            seen.insert(verse)
            saveSeenVerses(Array(seen), bookName: bookName, chapter: chapter)
            if totalVerses > 0, seen.count >= totalVerses {
                markVisited(bookName: bookName, chapterNumber: chapter)
                setChapterCompletionDateIfNeeded(bookName: bookName, chapter: chapter, date: Date())
            }
        }
    }

    func isChapterComplete(bookName: String, chapter: Int, totalVerses: Int) -> Bool {
        let seen = loadSeenVerses(bookName: bookName, chapter: chapter)
        return totalVerses > 0 && seen.count >= totalVerses
    }

    private func setChapterCompletionDateIfNeeded(bookName: String, chapter: Int, date: Date) {
        var map = loadChapterCompletionDates()
        let key = "\(bookName):\(chapter)"
        if map[key] == nil {
            map[key] = date
            saveChapterCompletionDates(map)
        }
    }

    func loadChapterCompletionDates() -> [String: Date] {
        if let cached = cacheChapterCompletionDates { return cached }
        let dict: [String: Date] = loadJSON(key: Defaults.keyChapterCompletionDates, default: [:])
        cacheChapterCompletionDates = dict
        return dict
    }

    func saveChapterCompletionDates(_ dict: [String: Date]) {
        cacheChapterCompletionDates = dict
        saveJSON(dict, key: Defaults.keyChapterCompletionDates)
        iCloudSyncCoordinator.shared.pushKey(Defaults.keyChapterCompletionDates)
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
    }

    func chapterCompletions(inMonth date: Date, calendar: Calendar = .current) -> [String: Date] {
        let map = loadChapterCompletionDates()
        var cal = calendar
        cal.timeZone = .gmt
        let year = cal.component(.year, from: date)
        let month = cal.component(.month, from: date)
        return map.filter { (_, d) in
            let comps = cal.dateComponents([.year, .month], from: d)
            return comps.year == year && comps.month == month
        }
    }

    // MARK: - Formatting

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

    // ... rest of file unchanged ...
}

