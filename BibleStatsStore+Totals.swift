import Foundation

@MainActor
extension BibleStatsStore {
    // MARK: - Per-book totals (all-time)

    func loadTotals() -> [String: Int] {
        if Defaults.provider.data(forKey: Defaults.keyReadingContributions) != nil {
            // Reading older than the retention cutoff lives in the archive.
            var totals = archivedBookTotals()
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
}
