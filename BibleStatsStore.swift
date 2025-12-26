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

        // Migration flag
        static let keyDidMigrateDailyKeysToLocal = "didMigrateDailyKeysToLocal"
    }

    // MARK: - Models

    struct LastRead: Codable, Equatable {
        let bookName: String
        let chapterNumber: Int
        let date: Date
    }

    // MARK: - In-memory caches

    // All caches are loaded lazily on first read and kept in memory.
    var cacheTotals: [String: Int]?
    var cacheDailyTotals: [String: Int]?
    var cacheDailyTotalsByBook: [String: [String: Int]]?
    var cacheVisitedChapters: Set<String>?
    var cacheLastRead: LastRead?
    // Internally store seenVerses as Set<Int> for fast lookups
    typealias SeenMap = [String: Set<Int>]
    var cacheSeenVersesByChapter: SeenMap?
    var cacheChapterCompletionDates: [String: Date]?

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

    // Clear all local Bible stats data (does not touch iCloud; coordinator handles that).
    func clearAllLocal() {
        let d = Defaults.provider
        d.removeObject(forKey: Defaults.keyTotals)
        d.removeObject(forKey: Defaults.keyDailyTotals)
        d.removeObject(forKey: Defaults.keyDailyTotalsByBook)
        d.removeObject(forKey: Defaults.keyVisitedChapters)
        d.removeObject(forKey: Defaults.keyLastRead)
        d.removeObject(forKey: Defaults.keySeenVersesByChapter)
        d.removeObject(forKey: Defaults.keyChapterCompletionDates)
        resetCaches()
    }

    // MARK: - JSON helpers

    func loadJSON<T: Decodable>(key: String, default defaultValue: T) -> T {
        let defaults = Defaults.provider
        guard let data = defaults.data(forKey: key) else { return defaultValue }
        return (try? JSONDecoder().decode(T.self, from: data)) ?? defaultValue
    }

    func saveJSON<T: Encodable>(_ value: T, key: String) {
        let defaults = Defaults.provider
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    // MARK: - ISO helpers

    // Local-day key (yyyy-MM-dd) aligned to the user's current time zone and startOfDay
    static func isoDateString(_ date: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        var cal = calendar
        cal.timeZone = TimeZone.autoupdatingCurrent
        let start = cal.startOfDay(for: date)
        let comps = cal.dateComponents([.year, .month, .day], from: start)
        let y = comps.year ?? 1970
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func isoKeysForMonth(containing date: Date, calendar: Calendar = .autoupdatingCurrent) -> [String] {
        var cal = calendar
        cal.timeZone = TimeZone.autoupdatingCurrent
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
}
