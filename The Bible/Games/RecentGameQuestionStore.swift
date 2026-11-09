import Foundation

/// Persists recently presented game questions so consecutive rounds do not feel repetitive.
struct RecentGameQuestionStore {
    private struct StoredHistory: Codable {
        var ids: [String]
        /// IDs shown in the current pass through the pool. Only games using `selectCycling` set this.
        var passIDs: [String]?
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

        var seenIDs = Set<String>()
        let uniqueCandidates = candidates.filter { candidate in
            seenIDs.insert(id(candidate)).inserted
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

    /// Deals candidates like cards from a deck, so every candidate is shown once before any
    /// repeats. Picks within a pass are random, so games don't bring back the same groups.
    /// When fewer than `count` remain, those are dealt, a new pass begins, and the rest of
    /// the game is drawn from the half of the pool shown longest ago. The leftovers count as
    /// shown in the new pass too, so they wait a full pass before coming back.
    ///
    /// Use a separate `game` key for each pool; pools sharing a key reset each other's passes.
    func selectCycling<T>(
        from candidates: [T],
        game: String,
        count: Int,
        id: (T) -> String
    ) -> [T] {
        guard count > 0 else { return [] }

        var seenIDs = Set<String>()
        let uniqueCandidates = candidates.filter { candidate in
            seenIDs.insert(id(candidate)).inserted
        }

        var allHistories = load()
        var stored = allHistories[game] ?? StoredHistory(ids: [])
        // Players with history from before passes were tracked start with everything they've seen counted.
        let passSet = Set(stored.passIDs ?? stored.ids)
        let remaining = uniqueCandidates.filter { !passSet.contains(id($0)) }.shuffled()
        guard remaining.count < count else {
            if stored.passIDs == nil {
                stored.passIDs = stored.ids
                allHistories[game] = stored
                save(allHistories)
            }
            // Early in a pass, hold back questions from the end of the last pass so they
            // don't come straight back. They're still dealt before this pass ends.
            let recentIDs = Set(stored.ids.suffix(uniqueCandidates.count / 2))
            let rested = remaining.filter { !recentIDs.contains(id($0)) }
            let held = remaining.filter { recentIDs.contains(id($0)) }
            return Array((rested + held).prefix(count))
        }

        // Start a new pass. Top up from the older half of the pool so the new pass doesn't
        // open with questions that were just shown.
        let lastSeen = Dictionary(
            stored.ids.enumerated().map { ($1, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        let shownThisPass = uniqueCandidates
            .filter { passSet.contains(id($0)) }
            .sorted { (lastSeen[id($0)] ?? -1) < (lastSeen[id($1)] ?? -1) }
        let needed = count - remaining.count
        let topUp = shownThisPass
            .prefix(max(needed, shownThisPass.count / 2))
            .shuffled()
            .prefix(needed)

        stored.passIDs = []
        allHistories[game] = stored
        save(allHistories)
        return (remaining + topUp).shuffled()
    }

    func record<T>(_ candidate: T, game: String, id: (T) -> String) {
        record([id(candidate)], game: game)
    }

    func record(_ ids: [String], game: String) {
        guard !ids.isEmpty else { return }

        var allHistories = load()
        var stored = allHistories[game] ?? StoredHistory(ids: [])
        for id in ids where !id.isEmpty {
            stored.ids.removeAll { $0 == id }
            stored.ids.append(id)

            // Track progress through the current pass for games using `selectCycling`.
            if stored.passIDs?.contains(id) == false {
                stored.passIDs?.append(id)
            }
        }
        stored.ids = Array(stored.ids.suffix(Self.maximumHistoryLength))

        allHistories[game] = stored
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
