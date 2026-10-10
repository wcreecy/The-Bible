import Foundation

@MainActor
extension BibleStatsStore {
    // MARK: - Daily totals (overall)

    func loadDailyTotals() -> [String: Int] {
        if Defaults.provider.data(forKey: Defaults.keyReadingContributions) != nil {
            return derivedDailyTotals()
        }
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
}
