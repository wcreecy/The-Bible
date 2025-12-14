import Foundation

// Stores lightweight reading sessions and caches them in memory.
// All access is main-actor to keep it simple for SwiftUI callers.
@MainActor
final class ReadingSessionsStore {
    static let shared = ReadingSessionsStore()
    private init() {
        // Invalidate cache when external merges happen (iCloud KVS or other writers)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleExternalUpdate),
            name: .bibleStatsExternallyUpdated,
            object: nil
        )
    }

    @objc
    private func handleExternalUpdate() {
        // We are already on the main actor due to @MainActor type
        cacheAllSessions = nil
    }

    struct Session: Codable, Equatable {
        let start: Date
        let end: Date
        let book: String
        let chapter: Int?
    }

    private struct Defaults {
        static let key = "readingSessions"
        static var provider: UserDefaults { UserDefaults.standard }
    }

    // Keep a rolling window to prevent unbounded growth (raised to ~5 years for “All Time”)
    private let maxRetentionDays: Int = 1825

    // In-memory cache, lazily loaded
    private var cacheAllSessions: [Session]?

    // MARK: - Public API

    func appendSession(_ session: Session) {
        var all = loadAll()
        all.append(session)
        // Prune older than retention window using local calendar
        let cutoff = Calendar.autoupdatingCurrent.date(byAdding: .day, value: -maxRetentionDays, to: Date()) ?? Date.distantPast
        all = all.filter { $0.end >= cutoff }
        saveAll(all)
    }

    // Normalize to local start-of-day boundaries for rolling day windows.
    func sessions(inLastDays days: Int, now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> [Session] {
        guard days > 0 else { return [] }
        var cal = calendar
        cal.timeZone = TimeZone.autoupdatingCurrent
        // Compute cutoff at start of local day N days ago
        let startOfToday = cal.startOfDay(for: now)
        let cutoff = cal.date(byAdding: .day, value: -days, to: startOfToday) ?? .distantPast
        return loadAll().filter { $0.end >= cutoff }
    }

    func sessions(inMonthContaining date: Date, calendar: Calendar = .autoupdatingCurrent) -> [Session] {
        var cal = calendar
        cal.timeZone = TimeZone.autoupdatingCurrent
        let comps = cal.dateComponents([.year, .month], from: date)
        guard let start = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: start),
              let monthEnd = cal.date(byAdding: .day, value: range.count, to: start) else {
            return []
        }
        return loadAll().filter { $0.end >= start && $0.end < monthEnd }
    }

    // Clear all stored sessions (used by debug tools)
    func clearAll() {
        cacheAllSessions = []
        let defaults = Defaults.provider
        defaults.removeObject(forKey: Defaults.key)
        // Push sessions key removal to iCloud KVS for cross-device sync and notify listeners
        iCloudSyncCoordinator.shared.pushKey(Defaults.key)
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
    }

    // MARK: - Persistence + cache

    private func loadAll() -> [Session] {
        if let cached = cacheAllSessions { return cached }
        let defaults = Defaults.provider
        guard let data = defaults.data(forKey: Defaults.key) else {
            cacheAllSessions = []
            return []
        }
        if let arr = try? JSONDecoder().decode([Session].self, from: data) {
            cacheAllSessions = arr
            return arr
        }
        cacheAllSessions = []
        return []
    }

    private func saveAll(_ arr: [Session]) {
        cacheAllSessions = arr
        let defaults = Defaults.provider
        if let data = try? JSONEncoder().encode(arr) {
            defaults.set(data, forKey: Defaults.key)
        } else {
            defaults.removeObject(forKey: Defaults.key)
        }
        // Push sessions to iCloud KVS for cross-device sync and refresh listeners
        iCloudSyncCoordinator.shared.pushKey(Defaults.key)
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
    }
}

