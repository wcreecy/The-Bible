import Foundation

/// Persists recently presented game questions so consecutive rounds do not feel repetitive.
struct RecentGameQuestionStore {
    private struct StoredHistory: Codable {
        var ids: [String]
    }

    private static let storageKey = AppStorageKey.gameQuestionRecency
    private static let maximumHistoryLength = 500

    static let shared = RecentGameQuestionStore()

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Returns candidates while preferring questions outside the recent cooldown window.
    /// If the available pool is smaller than the requested count, the least-recent candidates
    /// are used as a safe fallback.
    func select<T>(
        from candidates: [T],
        game: String,
        count: Int,
        cooldown: Int,
        id: (T) -> String
    ) -> [T] {
        guard count > 0 else { return [] }

        let uniqueCandidates = candidates.reduce(into: [T]()) { result, candidate in
            guard !result.contains(where: { id($0) == id(candidate) }) else { return }
            result.append(candidate)
        }
        let recentIDs = history(for: game)
        let recentSet = Set(recentIDs.suffix(max(0, cooldown)))
        let fresh = uniqueCandidates.filter { !recentSet.contains(id($0)) }
        guard fresh.count < count else {
            return Array(fresh.prefix(count))
        }

        let fallback = recentIDs.compactMap { recentID in
            uniqueCandidates.first { id($0) == recentID }
        }
        return Array((fresh + fallback).prefix(count))
    }

    func record<T>(_ candidate: T, game: String, id: (T) -> String) {
        record([id(candidate)], game: game)
    }

    func record(_ ids: [String], game: String) {
        guard !ids.isEmpty else { return }

        var stored = history(for: game)
        for id in ids where !id.isEmpty {
            stored.removeAll { $0 == id }
            stored.append(id)
        }
        stored = Array(stored.suffix(Self.maximumHistoryLength))

        var allHistories = load()
        allHistories[game] = StoredHistory(ids: stored)
        save(allHistories)
    }

    private func history(for game: String) -> [String] {
        load()[game]?.ids ?? []
    }

    private func load() -> [String: StoredHistory] {
        guard let data = defaults.data(forKey: Self.storageKey),
              let histories = try? JSONDecoder().decode([String: StoredHistory].self, from: data) else {
            return [:]
        }
        return histories
    }

    private func save(_ histories: [String: StoredHistory]) {
        guard let data = try? JSONEncoder().encode(histories) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
