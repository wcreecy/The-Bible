import Foundation

@MainActor
extension BibleStatsStore {
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
}
