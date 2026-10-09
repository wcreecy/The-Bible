import Foundation

@MainActor
extension iCloudSyncCoordinator {
    // Settings keys to sync across devices
    // - dailyGoalMinutes: simple Int, last writer wins by timestamp
    // - dailyGoalHistoryChanges: JSON Data of [ { isoDate: String, minutes: Int } ], merged as a union
    static let settingsKeys: [String] = [
        "dailyGoalMinutes",
        "dailyGoalHistoryChanges"
    ]

    private struct GoalChange: Codable, Equatable {
        let isoDate: String
        let minutes: Int
    }

    // Local -> KVS
    func mirrorSettingsKeyToKVS(_ key: String) {
        guard Self.settingsKeys.contains(key) else { return }

        switch key {
        case "dailyGoalMinutes":
            // Only publish when this device made the most recent change. Background
            // pushes otherwise overwrite a newer goal chosen on another device.
            let localTimestamp = readLocalTimestamp(for: key)
            let remoteTimestamp = readRemoteTimestamp(for: key)
            let hasRemote = kvs.object(forKey: key) != nil
            guard localTimestamp > remoteTimestamp || (!hasRemote && defaults.object(forKey: key) != nil) else {
                return
            }
            let local = defaults.integer(forKey: key)
            if (kvs.object(forKey: key) as? NSNumber)?.intValue != local {
                kvs.set(local, forKey: key)
            }
            if localTimestamp > 0 {
                kvs.set(localTimestamp, forKey: tsKey(for: key))
            }

        case "dailyGoalHistoryChanges":
            // Publish the union so entries recorded only on another device are kept.
            guard let merged = mergedGoalHistory() else { return }
            if kvs.data(forKey: key) != merged {
                kvs.set(merged, forKey: key)
            }
            let localTimestamp = readLocalTimestamp(for: key)
            if localTimestamp > readRemoteTimestamp(for: key) {
                kvs.set(localTimestamp, forKey: tsKey(for: key))
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
            guard kvs.object(forKey: key) != nil else { break }
            let remoteTimestamp = readRemoteTimestamp(for: key)
            let localTimestamp = readLocalTimestamp(for: key)
            let remoteVal = Int(kvs.longLong(forKey: key))

            if remoteTimestamp > localTimestamp || (remoteTimestamp == 0 && localTimestamp == 0) {
                if defaults.integer(forKey: key) != remoteVal {
                    defaults.set(remoteVal, forKey: key)
                }
                if remoteTimestamp > 0 {
                    defaults.set(remoteTimestamp, forKey: tsKey(for: key))
                }
                BibleStatsStore.shared.resetCaches()
                NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
            } else if localTimestamp > remoteTimestamp {
                // This device's goal is newer; republish it.
                mirrorSettingsKeyToKVS(key)
                enqueueKeyForSync(key)
            }

        case "dailyGoalHistoryChanges":
            guard kvs.data(forKey: key) != nil, let merged = mergedGoalHistory() else { break }
            if defaults.data(forKey: key) != merged {
                defaults.set(merged, forKey: key)
                DailyGoalHistoryStore.shared.invalidateCache()
                BibleStatsStore.shared.resetCaches()
                NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
            }
            if kvs.data(forKey: key) != merged {
                kvs.set(merged, forKey: key)
                enqueueKeyForSync(key)
            }

        default:
            break
        }
    }

    /// Union of local and remote goal history by date. For the same date, the side
    /// written most recently wins so all devices converge on the latest choice.
    private func mergedGoalHistory() -> Data? {
        let key = "dailyGoalHistoryChanges"
        let localData = defaults.data(forKey: key)
        let remoteData = kvs.data(forKey: key)
        guard localData != nil || remoteData != nil else { return nil }

        let localArr = decode(localData, as: [GoalChange].self) ?? []
        let remoteArr = decode(remoteData, as: [GoalChange].self) ?? []
        let localIsNewer = readLocalTimestamp(for: key) > readRemoteTimestamp(for: key)

        var merged: [String: GoalChange] = [:]
        let (older, newer) = localIsNewer ? (remoteArr, localArr) : (localArr, remoteArr)
        for change in older { merged[change.isoDate] = change }
        for change in newer { merged[change.isoDate] = change }

        let sorted = merged.values.sorted { $0.isoDate < $1.isoDate }
        return try? JSONEncoder().encode(sorted)
    }
}
