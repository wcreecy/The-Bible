import Foundation

@MainActor
final class DailyGoalHistoryStore {
    static let shared = DailyGoalHistoryStore()
    private init() {}

    private struct Change: Codable, Equatable {
        let isoDate: String   // yyyy-MM-dd (local day)
        let minutes: Int
    }

    private let historyKey = "dailyGoalHistoryChanges"

    private var cache: [Change]? = nil

    private var defaults: UserDefaults { .standard }

    private func load() -> [Change] {
        if let cache { return cache }
        guard let data = defaults.data(forKey: historyKey) else {
            cache = []
            return []
        }
        let decoded = (try? JSONDecoder().decode([Change].self, from: data)) ?? []
        let sorted = decoded.sorted { $0.isoDate < $1.isoDate }
        cache = sorted
        return sorted
    }

    private func save(_ changes: [Change]) {
        cache = changes.sorted { $0.isoDate < $1.isoDate }
        if let data = try? JSONEncoder().encode(cache) {
            defaults.set(data, forKey: historyKey)
        }
        // Push via your existing iCloud KVS coordinator so other devices receive it
        iCloudSyncCoordinator.shared.pushKey(historyKey)
        // Notify listeners that goal evaluation context changed
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
    }

    // Ensure there’s at least one baseline record so past days evaluate consistently.
    // Seed with the current @AppStorage value, effective from a very early date.
    func ensureSeededIfNeeded() {
        var items = load()
        guard items.isEmpty else { return }
        let minutes = max(1, UserDefaults.standard.integer(forKey: "dailyGoalMinutes"))
        let seed = Change(isoDate: "1970-01-01", minutes: minutes)
        items.append(seed)
        save(items)
    }

    // Record a new goal minutes value, effective on the local day of `date`.
    func recordChange(minutes: Int, at date: Date = Date()) {
        let mins = max(1, minutes)
        let iso = BibleStatsStore.isoDateString(date)
        var items = load()
        if let idx = items.firstIndex(where: { $0.isoDate == iso }) {
            items[idx] = Change(isoDate: iso, minutes: mins)
        } else {
            items.append(Change(isoDate: iso, minutes: mins))
        }
        save(items)
    }

    // Goal seconds for a given date (local day) based on the most recent change <= that date.
    func goalSeconds(on date: Date) -> Int {
        ensureSeededIfNeeded()
        let iso = BibleStatsStore.isoDateString(date)
        let items = load()
        // Find last change whose isoDate <= iso
        if let change = items.filter({ $0.isoDate <= iso }).max(by: { $0.isoDate < $1.isoDate }) {
            return max(1, change.minutes) * 60
        }
        // Fallback to current setting if somehow no history
        let mins = max(1, UserDefaults.standard.integer(forKey: "dailyGoalMinutes"))
        return mins * 60
    }
}

