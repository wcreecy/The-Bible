import Foundation

@MainActor
extension BibleStatsStore {
    // MARK: - Per-book totals (all-time)

    func loadTotals() -> [String: Int] {
        if Defaults.provider.data(forKey: Defaults.keyReadingContributions) != nil {
            var totals: [String: Int] = [:]
            for books in derivedDailyTotalsByBook().values {
                for (book, seconds) in books {
                    totals[book, default: 0] += max(0, seconds)
                }
            }
            return totals
        }
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
}
