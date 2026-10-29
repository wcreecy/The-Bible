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
        static let keyTotals = AppStorageKey.bookReadingTimes                   // [String: Int] all-time per-book
        static let keyDailyTotals = AppStorageKey.dailyReadingTimes             // [String: Int] by ISO date yyyy-MM-dd
        static let keyDailyTotalsByBook = AppStorageKey.dailyReadingTimesByBook // [String: [String: Int]] date -> (book -> seconds)
        static let keyVisitedChapters = AppStorageKey.visitedChapters           // [String]
        static let keyLastRead = AppStorageKey.lastReadEntry                    // JSON of LastRead
        static let keySeenVersesByChapter = AppStorageKey.seenVersesByChapter   // [String: [Int]] keyed by "Book:Chapter"
        static let keyChapterCompletionDates = AppStorageKey.chapterCompletionDates // [String: Date] keyed by "Book:Chapter"
        static let keyReadingContributions = AppStorageKey.readingTimeContributionsV2
        static let keyChapterResetDates = AppStorageKey.chapterResetDates           // [String: Date] keyed by "Book:Chapter"
        static let keySeenVersesUpdatedAt = AppStorageKey.seenVersesUpdatedAt       // [String: Date] keyed by "Book:Chapter"
        static let keyReadingHistoryArchive = AppStorageKey.readingHistoryArchiveV1 // ReadingHistoryArchive: totals older than ~2 years
        // Swap this to your app group if desired:
        static var provider: UserDefaults { UserDefaults.standard }

        // Migration flag
        static let keyDidMigrateDailyKeysToLocal = AppStorageKey.didMigrateDailyKeysToLocal
    }

    // MARK: - Models

    /// Where the person stopped reading: the single synced reading position, managed by
    /// `ReadingPositionStore`. `verseNumber` is absent in entries saved by older versions.
    struct LastRead: Codable, Equatable {
        let bookName: String
        let chapterNumber: Int
        var verseNumber: Int?
        let date: Date

        init(bookName: String, chapterNumber: Int, verseNumber: Int? = nil, date: Date) {
            self.bookName = bookName
            self.chapterNumber = chapterNumber
            self.verseNumber = verseNumber
            self.date = date
        }
    }

    struct StatisticsSnapshot {
        let dailyTotals: [String: Int]
        let dailyTotalsByBook: [String: [String: Int]]
        let perBookTotals: [String: Int]
        let visitedChapters: Set<String>
        let lastRead: LastRead?
        let seenVersesByChapter: SeenMap
        let chapterCompletionDates: [String: Date]
    }

    struct HomeStatisticsSnapshot {
        let dailyTotals: [String: Int]
        let perBookTotals: [String: Int]
        let visitedChapters: Set<String>
        let lastRead: LastRead?
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
    var cacheReadingContributions: [String: [String: [String: Int]]]?

    // MARK: - Cache reset for external updates

    func resetCaches() {
        cacheTotals = nil
        cacheDailyTotals = nil
        cacheDailyTotalsByBook = nil
        cacheVisitedChapters = nil
        cacheLastRead = nil
        cacheSeenVersesByChapter = nil
        cacheChapterCompletionDates = nil
        cacheReadingContributions = nil
    }

    func statisticsSnapshot() -> StatisticsSnapshot {
        StatisticsSnapshot(
            dailyTotals: loadDailyTotals(),
            dailyTotalsByBook: loadDailyTotalsByBook(),
            perBookTotals: loadTotals(),
            visitedChapters: loadVisitedChapters(),
            lastRead: loadLastRead(),
            seenVersesByChapter: loadSeenVersesByChapter(),
            chapterCompletionDates: loadChapterCompletionDates()
        )
    }

    func homeStatisticsSnapshot() -> HomeStatisticsSnapshot {
        HomeStatisticsSnapshot(
            dailyTotals: loadDailyTotals(),
            perBookTotals: loadTotals(),
            visitedChapters: loadVisitedChapters(),
            lastRead: loadLastRead()
        )
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
        d.removeObject(forKey: Defaults.keyReadingContributions)
        d.removeObject(forKey: Defaults.keyChapterResetDates)
        d.removeObject(forKey: Defaults.keySeenVersesUpdatedAt)
        d.removeObject(forKey: Defaults.keyReadingHistoryArchive)
        resetCaches()
    }

    // MARK: - JSON helpers

    func loadJSON<T: Decodable>(key: String, default defaultValue: T) -> T {
        let defaults = Defaults.provider
        guard let data = defaults.data(forKey: key) else { return defaultValue }
        return PersistedDecoding.decode(T.self, from: data, key: key, keepingUnreadableIn: defaults) ?? defaultValue
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
