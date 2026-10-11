import Foundation

/// Prayer timer stats sync.
///
/// - `prayerContributionsV1`: JSON `[day: [device: seconds]]`. Each device only adds to
///   its own entries, so copies merge by keeping the larger value per day and device.
/// - `prayerLastSessionV1`: JSON `{ seconds, endedAt }`. The most recent session wins.
///
/// Both are cleared everywhere by the reading stats reset epoch.
@MainActor
extension iCloudSyncCoordinator {
    static var prayerStatsKeys: [String] {
        [PrayerStatsStore.contributionsKey, PrayerStatsStore.lastSessionKey]
    }

    // Local -> KVS
    func mirrorPrayerStatsKeyToKVS(_ key: String) {
        let store = PrayerStatsStore.shared

        switch key {
        case PrayerStatsStore.contributionsKey:
            // Publish the union, so entries only another device has written are kept.
            let remote = decode(kvs.data(forKey: key), as: PrayerStatsStore.Contributions.self) ?? [:]
            let merged = PrayerStatsStore.merged(store.loadContributions(), remote)
            guard !merged.isEmpty, merged != remote,
                  let data = try? JSONEncoder().encode(merged) else { return }
            kvs.set(data, forKey: key)

        case PrayerStatsStore.lastSessionKey:
            let remote = decode(kvs.data(forKey: key), as: PrayerStatsStore.LastSession.self)
            guard let newest = PrayerStatsStore.newer(store.loadLastSession(), remote),
                  newest != remote,
                  let data = try? JSONEncoder().encode(newest) else { return }
            kvs.set(data, forKey: key)

        default:
            break
        }
    }

    // KVS -> Local
    func mergePrayerStatsIncoming(forKey key: String) {
        let store = PrayerStatsStore.shared
        var changedLocally = false

        switch key {
        case PrayerStatsStore.contributionsKey:
            guard let remote = decode(kvs.data(forKey: key), as: PrayerStatsStore.Contributions.self) else { return }
            let local = store.loadContributions()
            let merged = PrayerStatsStore.merged(local, remote)
            if merged != local {
                store.saveContributions(merged)
                changedLocally = true
            }
            // This device had entries the cloud copy lacked; republish the union.
            if merged != remote, let data = try? JSONEncoder().encode(merged) {
                kvs.set(data, forKey: key)
                enqueueKeyForSync(key)
            }

        case PrayerStatsStore.lastSessionKey:
            guard let remote = decode(kvs.data(forKey: key), as: PrayerStatsStore.LastSession.self) else { return }
            let local = store.loadLastSession()
            let newest = PrayerStatsStore.newer(local, remote)
            if let newest, newest != local {
                store.saveLastSession(newest)
                changedLocally = true
            }
            if let newest, newest != remote, let data = try? JSONEncoder().encode(newest) {
                kvs.set(data, forKey: key)
                enqueueKeyForSync(key)
            }

        default:
            break
        }

        if changedLocally {
            NotificationCenter.default.post(name: .prayerStatsUpdated, object: nil)
        }
    }

    /// Clears prayer stats on this device and in iCloud, as part of a reading stats reset.
    func clearPrayerStats() {
        PrayerStatsStore.shared.clearLocal()
        for key in Self.prayerStatsKeys {
            kvs.removeObject(forKey: key)
        }
    }
}
