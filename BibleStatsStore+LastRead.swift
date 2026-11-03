import Foundation

@MainActor
extension BibleStatsStore {
    // MARK: - Last read

    func loadLastRead() -> LastRead? {
        if let cached = cacheLastRead { return cached }
        // Decode optional LastRead (may not exist yet)
        let defaults = Defaults.provider
        guard let data = defaults.data(forKey: Defaults.keyLastRead) else { return nil }
        let decoded = PersistedDecoding.decode(LastRead.self, from: data, key: Defaults.keyLastRead, keepingUnreadableIn: defaults)
        cacheLastRead = decoded
        return decoded
    }

    /// Saves and syncs the reading position. Reading-position updates are frequent, so
    /// callers that only move the position pass `notify: false`; `ReadingPositionStore` is
    /// observable, so its readers update without the app-wide stats announcement.
    func saveLastRead(bookName: String, chapterNumber: Int, verseNumber: Int? = nil, date: Date, notify: Bool = true) {
        let entry = LastRead(bookName: bookName, chapterNumber: chapterNumber, verseNumber: verseNumber, date: date)
        cacheLastRead = entry
        saveJSON(entry, key: Defaults.keyLastRead)
        iCloudSyncCoordinator.shared.pushKey(Defaults.keyLastRead)
        if notify {
            AppDataChanges.shared.bibleStatsChanged()
        }
    }

    func clearLastRead() {
        cacheLastRead = nil
        Defaults.provider.removeObject(forKey: Defaults.keyLastRead)
        iCloudSyncCoordinator.shared.pushKey(Defaults.keyLastRead)
    }
}
