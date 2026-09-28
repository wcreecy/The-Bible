import Foundation

@MainActor
extension iCloudSyncCoordinator {
    // Settings keys to sync across devices
    // - dailyGoalMinutes: simple Int
    // - dailyGoalHistoryChanges: JSON Data of [ { isoDate: String, minutes: Int } ]
    static let settingsKeys: [String] = [
        "dailyGoalMinutes",
        "dailyGoalHistoryChanges"
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

        default:
            break
        }
    }
}
