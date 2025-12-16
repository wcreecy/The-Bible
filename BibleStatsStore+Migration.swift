import Foundation

@MainActor
extension BibleStatsStore {
    // MARK: - Migration

    // Call this once at app launch (before using totals) to re-bucket legacy UTC/GMT keys to local-day keys.
    func migrateDailyKeysFromGMTToLocalIfNeeded() {
        let defaults = Defaults.provider
        if defaults.bool(forKey: Defaults.keyDidMigrateDailyKeysToLocal) {
            return
        }

        // Load existing data
        let dailyTotals: [String: Int] = loadJSON(key: Defaults.keyDailyTotals, default: [:])
        let dailyByBook: [String: [String: Int]] = loadJSON(key: Defaults.keyDailyTotalsByBook, default: [:])

        // If nothing to migrate, mark and return
        if dailyTotals.isEmpty && dailyByBook.isEmpty {
            defaults.set(true, forKey: Defaults.keyDidMigrateDailyKeysToLocal)
            return
        }

        // Helper to convert a legacy yyyy-MM-dd key (interpreted at UTC noon) to a local yyyy-MM-dd key
        func convertGMTKeyToLocal(_ gmtKey: String) -> String? {
            // Build a Date at noon UTC for the given yyyy-MM-dd to avoid DST edges
            var utcCal = Calendar(identifier: .gregorian)
            utcCal.timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone.autoupdatingCurrent
            let parts = gmtKey.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { return nil }
            var comps = DateComponents()
            comps.year = parts[0]
            comps.month = parts[1]
            comps.day = parts[2]
            comps.hour = 12
            comps.minute = 0
            comps.second = 0
            guard let utcDateNoon = utcCal.date(from: comps) else { return nil }

            // Now get local startOfDay and format using current local calendar/time zone
            return Self.isoDateString(utcDateNoon, calendar: .autoupdatingCurrent)
        }

        // Migrate dailyTotals
        var migratedDaily: [String: Int] = [:]
        for (key, value) in dailyTotals {
            guard let localKey = convertGMTKeyToLocal(key) else { continue }
            migratedDaily[localKey, default: 0] += max(0, value)
        }

        // Migrate daily totals by book
        var migratedByBook: [String: [String: Int]] = [:]
        for (key, perBook) in dailyByBook {
            guard let localKey = convertGMTKeyToLocal(key) else { continue }
            var dest = migratedByBook[localKey] ?? [:]
            for (book, sec) in perBook {
                dest[book, default: 0] += max(0, sec)
            }
            migratedByBook[localKey] = dest
        }

        // Save back
        saveDailyTotals(migratedDaily)
        saveDailyTotalsByBook(migratedByBook)

        // Mark flag
        defaults.set(true, forKey: Defaults.keyDidMigrateDailyKeysToLocal)

        // Reset caches and notify
        resetCaches()
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
    }
}
