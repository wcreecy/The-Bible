import Foundation

@MainActor
extension iCloudSyncCoordinator {
    // Settings keys to sync across devices
    // - dailyGoalMinutes: simple Int
    // - dailyGoalHistoryChanges: JSON Data of [ { isoDate: String, minutes: Int } ]
    // - tagDisplayNameMap: [String: String]
    // - tagColorMap: [String: [Double]] (RGBA components)
    static let settingsKeys: [String] = [
        "dailyGoalMinutes",
        "dailyGoalHistoryChanges",
        "tagDisplayNameMap",
        "tagColorMap"
    ]

    // Local -> KVS
    func mirrorSettingsKeyToKVS(_ key: String) {
        guard Self.settingsKeys.contains(key) else { return }

        switch key {
        case "dailyGoalMinutes":
            let local = defaults.integer(forKey: key)
            let remoteObj = kvs.object(forKey: key) as? NSNumber
            let remote = remoteObj?.intValue
            if remote == nil || remote != local {
                kvs.set(local, forKey: key)
            }

        case "dailyGoalHistoryChanges":
            // Stored as Data (JSON array of { isoDate, minutes })
            if let localData = defaults.data(forKey: key) {
                let remoteData = kvs.data(forKey: key)
                if remoteData != localData {
                    kvs.set(localData, forKey: key)
                }
            }

        case "tagDisplayNameMap":
            // Stored as [String: String] in UserDefaults
            let local = (defaults.dictionary(forKey: key) as? [String: String]) ?? [:]
            // KVS returns Any?; coerce to [String: String] if possible
            let remote = kvs.dictionary(forKey: key) as? [String: String] ?? [:]
            if local != remote {
                kvs.set(local, forKey: key)
            }

        case "tagColorMap":
            // Stored as [String: [Double]] in UserDefaults (RGBA)
            let local = (defaults.dictionary(forKey: key) as? [String: [Double]]) ?? [:]
            let remote = kvs.dictionary(forKey: key) as? [String: [Double]] ?? [:]
            if local != remote {
                kvs.set(local, forKey: key)
            }

        default:
            break
        }
    }

    // KVS -> Local
    func mergeSettingsIncoming(forKey key: String) {
        guard Self.settingsKeys.contains(key) else { return }

        switch key {
        case "dailyGoalMinutes":
            let remoteVal = Int(kvs.longLong(forKey: key))
            if defaults.integer(forKey: key) != remoteVal {
                defaults.set(remoteVal, forKey: key)
            }

        case "dailyGoalHistoryChanges":
            // Merge remote and local history arrays by isoDate (union).
            // For duplicates, prefer the remote entry.
            struct GoalChange: Codable, Equatable { let isoDate: String; let minutes: Int }

            guard let remoteData = kvs.data(forKey: key) else { break }
            let localData = defaults.data(forKey: key)

            // If we have no local data, just accept remote wholesale.
            guard let localData else {
                defaults.set(remoteData, forKey: key)
                // Notify readers that evaluation context changed
                BibleStatsStore.shared.resetCaches()
                NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
                break
            }

            // Decode both sides; if decoding fails, prefer remote.
            let decoder = JSONDecoder()
            let localArr = (try? decoder.decode([GoalChange].self, from: localData)) ?? []
            let remoteArr = (try? decoder.decode([GoalChange].self, from: remoteData)) ?? []

            // Union by isoDate; remote wins on conflicts.
            var merged: [String: GoalChange] = Dictionary(uniqueKeysWithValues: localArr.map { ($0.isoDate, $0) })
            for r in remoteArr { merged[r.isoDate] = r }

            // Sort by isoDate ascending for stability
            let mergedArr = merged.values.sorted { $0.isoDate < $1.isoDate }
            if let encoded = try? JSONEncoder().encode(mergedArr) {
                defaults.set(encoded, forKey: key)
            } else {
                // Fallback: if encoding fails, at least set the remote payload.
                defaults.set(remoteData, forKey: key)
            }

            // Notify readers that evaluation context changed
            BibleStatsStore.shared.resetCaches()
            NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)

        case "tagDisplayNameMap":
            // Prefer exact type match; ignore malformed payloads
            if let remote = kvs.dictionary(forKey: key) as? [String: String] {
                let local = (defaults.dictionary(forKey: key) as? [String: String]) ?? [:]
                if local != remote {
                    defaults.set(remote, forKey: key)
                    // Also refresh in-memory cache inside TagDisplayNameStore if needed
                    NotificationCenter.default.post(name: .init("TagDisplayNameMapDidChange"), object: nil)
                }
            }

        case "tagColorMap":
            if let remote = kvs.dictionary(forKey: key) as? [String: [Double]] {
                let local = (defaults.dictionary(forKey: key) as? [String: [Double]]) ?? [:]
                if local != remote {
                    defaults.set(remote, forKey: key)
                    // Also refresh in-memory cache inside TagColorStore if needed
                    NotificationCenter.default.post(name: .init("TagColorMapDidChange"), object: nil)
                }
            }

        default:
            break
        }
    }
}
