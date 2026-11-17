import Foundation

@MainActor
extension BibleStatsStore {
    typealias ReadingContributions = [String: [String: [String: Int]]]

    /// Identifies this install in per-device stats (reading and prayer contributions).
    var installationID: String {
        let key = "readingStatsInstallationID"
        if let value = Defaults.provider.string(forKey: key) { return value }
        let value = UUID().uuidString
        Defaults.provider.set(value, forKey: key)
        return value
    }

    func loadReadingContributions() -> ReadingContributions {
        if let cached = cacheReadingContributions { return cached }
        var decoded: ReadingContributions = loadJSON(key: Defaults.keyReadingContributions, default: [:])
        if decoded.isEmpty {
            let legacy = loadJSON(key: Defaults.keyDailyTotalsByBook, default: [String: [String: Int]]())
            for (day, books) in legacy {
                for (book, seconds) in books where seconds > 0 {
                    decoded[day, default: [:]][book, default: [:]]["legacy", default: 0] = seconds
                }
            }
            if !decoded.isEmpty {
                saveJSON(decoded, key: Defaults.keyReadingContributions)
            }
        }
        cacheReadingContributions = decoded
        return decoded
    }

    func addReadingTime(bookName: String, seconds: Int, on date: Date, calendar: Calendar = .autoupdatingCurrent) {
        guard seconds > 0, !bookName.isEmpty else { return }
        var contributions = loadReadingContributions()
        let day = Self.isoDateString(date, calendar: calendar)
        contributions[day, default: [:]][bookName, default: [:]][installationID, default: 0] += seconds
        cacheReadingContributions = contributions
        saveJSON(contributions, key: Defaults.keyReadingContributions)
        cacheHasReadingContributions = true
        iCloudSyncCoordinator.shared.pushKey(Defaults.keyReadingContributions)
        AppDataChanges.shared.bibleStatsChanged()
    }

    /// Seconds per book per day, summed across devices. Cached until the contributions change.
    func derivedDailyTotalsByBook() -> [String: [String: Int]] {
        let contributions = loadReadingContributions()
        if let cached = cacheDerivedDailyTotalsByBook { return cached }
        let totals = contributions.mapValues { books in
            books.mapValues { devices in devices.values.reduce(0) { $0 + max(0, $1) } }
        }
        cacheDerivedDailyTotalsByBook = totals
        return totals
    }

    /// Seconds per day, summed across books and devices. Cached until the contributions change.
    func derivedDailyTotals() -> [String: Int] {
        let byBook = derivedDailyTotalsByBook()
        if let cached = cacheDerivedDailyTotals { return cached }
        let totals = byBook.mapValues { books in
            books.values.reduce(0) { $0 + max(0, $1) }
        }
        cacheDerivedDailyTotals = totals
        return totals
    }
}
